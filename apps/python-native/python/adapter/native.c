/*
 * CPython adapter of the diagrams.mbt Python binding.
 *
 * Copyright 2026 moonrockz. Licensed under the Apache License, Version 2.0.
 *
 * This file is the only C code of the binding. It links the C that the MoonBit
 * native backend generates for the `foreign_library` package
 * `moonrockz/diagrams-python-native/ffi` into the extension module
 * `diagrams_mbt._native`.
 *
 * Boundary (version 2, see apps/python-native/bridge/record.mbt):
 * - The adapter uses the generated `moonbit_init` and the exports
 *   `diagrams_py_abi_version` and `diagrams_py_call`. From the runtime it uses
 *   `moonbit_make_bytes_raw`, `moonbit_decref`, `Moonbit_array_length`, and,
 *   in mimalloc builds, `moonbit_cycle_collection_threshold`,
 *   `moonbit_collect_cycles` and mimalloc's `mi_register_deferred_free`.
 * - `call(request: tuple) -> tuple` encodes the request into a malloc buffer
 *   with the GIL held, detaches from Python, takes the runtime lock, copies
 *   the request into a MoonBit `Bytes`, calls `diagrams_py_call`, copies the
 *   response into a malloc buffer, releases both MoonBit values, releases the
 *   runtime lock and only then attaches to Python again. It decodes the
 *   response into Python values after that. No Python object points into
 *   MoonBit memory, and MoonBit never sees a Python object.
 * - Ownership was measured on the pinned compiler, because the MoonBit
 *   documentation does not state it for `#export_name` functions: an export
 *   borrows its `Bytes` argument and returns a new reference. So the adapter
 *   releases the argument and the result, each one time.
 *
 * Synchronization (OpenSpec change add-portable-tree-queries-and-python-
 * traversal, decision GIL-1):
 * - The MoonBit runtime has process-global state (cycle-collector buffers,
 *   top-level values) and non-atomic reference counts. One process-wide
 *   runtime lock serializes every runtime access: initialization, allocation,
 *   reference counts, cycle collection, registries and the call counters.
 * - A thread never waits for the runtime lock while it holds the GIL, and it
 *   releases the runtime lock before it attaches to Python again. No Python
 *   API is called while the thread is detached or holds the runtime lock.
 * - mimalloc calls a registered deferred-free function from allocation slow
 *   paths, and with `force` set when a thread exits (heap abandon) and at
 *   process exit. Those calls can come from a thread that does not hold the
 *   runtime lock. In mimalloc builds the adapter replaces the runtime's
 *   callback with `guarded_deferred_free`, which collects cycles only when
 *   the current thread holds the runtime lock. Otherwise it skips; the
 *   buffered cycles stay for the next collection under the lock.
 * - The lock instrumentation (entries, maximum concurrent holders, contended
 *   acquisitions, current waiters, wait and hold time, callback counts) uses
 *   C11 atomics, so `_lock_stats()` reads it without the runtime lock. The
 *   call and initialization counters are plain values under the runtime lock.
 * - The module declares no support for multiple interpreters and keeps the
 *   GIL in free-threaded builds.
 */

#define PY_SSIZE_T_CLEAN
#ifndef Py_LIMITED_API
#define Py_LIMITED_API 0x030C0000
#endif
#include <Python.h>

#include <stdatomic.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#if defined(_WIN32)
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#else
#include <pthread.h>
#include <time.h>
#endif

#include "moonbit.h"

/* The boundary version that this adapter understands. */
#ifndef DIAGRAMS_PY_EXPECTED_ABI
#define DIAGRAMS_PY_EXPECTED_ABI 2
#endif

/* The build must state the allocator of the linked runtime: 1 for mimalloc,
   0 for the system allocator. */
#ifndef DIAGRAMS_PY_MIMALLOC
#error "define DIAGRAMS_PY_MIMALLOC to 1 (mimalloc runtime) or 0 (system allocator)"
#endif

/* The deepest nesting of non-empty tuples and lists, as in record.mbt. */
#define RECORD_MAX_DEPTH 64

/* MoonBit symbols. `moonbit_init` is generated for a foreign library. */
extern void moonbit_init(void);
extern int32_t diagrams_py_abi_version(void);
extern moonbit_bytes_t diagrams_py_call(moonbit_bytes_t request);

#if DIAGRAMS_PY_MIMALLOC
#if defined(_MSC_VER) || defined(__MINGW32__)
#define DIAGRAMS_CDECL __cdecl
#else
#define DIAGRAMS_CDECL
#endif
/* ABI-compatible with mimalloc.h and with the declaration in runtime.c. */
typedef void(DIAGRAMS_CDECL diagrams_deferred_free_fun)(
    bool force, unsigned long long heartbeat, void *arg);
extern void mi_register_deferred_free(diagrams_deferred_free_fun *fn,
                                      void *arg);
extern int32_t moonbit_cycle_collection_threshold(void);
extern void moonbit_collect_cycles(void);
#endif

/* ------------------------------------------------------------------------ */
/* Runtime lock                                                             */
/* ------------------------------------------------------------------------ */

#if defined(_WIN32)
static SRWLOCK runtime_lock = SRWLOCK_INIT;
static int lock_try(void) {
  return TryAcquireSRWLockExclusive(&runtime_lock) ? 1 : 0;
}
static void lock_wait(void) { AcquireSRWLockExclusive(&runtime_lock); }
static void lock_release(void) { ReleaseSRWLockExclusive(&runtime_lock); }
static uint64_t now_ns(void) {
  LARGE_INTEGER frequency;
  LARGE_INTEGER counter;
  QueryPerformanceFrequency(&frequency);
  QueryPerformanceCounter(&counter);
  return (uint64_t)((double)counter.QuadPart * 1e9 /
                    (double)frequency.QuadPart);
}
#else
static pthread_mutex_t runtime_lock = PTHREAD_MUTEX_INITIALIZER;
static int lock_try(void) {
  return pthread_mutex_trylock(&runtime_lock) == 0 ? 1 : 0;
}
static void lock_wait(void) {
  if (pthread_mutex_lock(&runtime_lock) != 0) {
    abort();
  }
}
static void lock_release(void) {
  if (pthread_mutex_unlock(&runtime_lock) != 0) {
    abort();
  }
}
static uint64_t now_ns(void) {
#if defined(__APPLE__)
  /* CLOCK_MONOTONIC has microsecond resolution on macOS. This clock counts
     nanoseconds, like Python's time.perf_counter there. */
  return clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
#else
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (uint64_t)ts.tv_sec * 1000000000ull + (uint64_t)ts.tv_nsec;
#endif
}
#endif

/* True while the current thread holds the runtime lock. */
static _Thread_local int holds_runtime_lock = 0;

/* Lock instrumentation. Atomics, so it can be read without the lock. */
static atomic_ullong stat_entries;
static atomic_ullong stat_contended;
static atomic_llong stat_waiting;
static atomic_llong stat_inside;
static atomic_llong stat_max_inside;
static atomic_ullong stat_wait_ns;
static atomic_ullong stat_held_ns;
static atomic_ullong stat_gil_ns;
static atomic_ullong stat_bytes_in;
static atomic_ullong stat_bytes_out;
static atomic_ullong stat_deferred_locked;
static atomic_ullong stat_deferred_skipped;
static atomic_ullong stat_deferred_collected;

/* Runtime state. The runtime lock protects it. */
static int runtime_ready = 0;
static long runtime_init_count = 0;
static unsigned long long runtime_calls = 0;
static int32_t runtime_abi_version = 0;

/* Time at which the current holder took the lock. Only the holder uses it. */
static uint64_t held_since = 0;

/* Takes the runtime lock. Call it only while detached from Python. */
static void runtime_enter(void) {
  if (!lock_try()) {
    uint64_t start = now_ns();
    atomic_fetch_add(&stat_contended, 1);
    atomic_fetch_add(&stat_waiting, 1);
    lock_wait();
    atomic_fetch_sub(&stat_waiting, 1);
    atomic_fetch_add(&stat_wait_ns, now_ns() - start);
  }
  holds_runtime_lock = 1;
  atomic_fetch_add(&stat_entries, 1);
  long long inside = atomic_fetch_add(&stat_inside, 1) + 1;
  long long seen = atomic_load(&stat_max_inside);
  while (inside > seen &&
         !atomic_compare_exchange_weak(&stat_max_inside, &seen, inside)) {
  }
  held_since = now_ns();
}

/* Releases the runtime lock. Call it before attaching to Python again. */
static void runtime_exit(void) {
  atomic_fetch_add(&stat_held_ns, now_ns() - held_since);
  atomic_fetch_sub(&stat_inside, 1);
  holds_runtime_lock = 0;
  lock_release();
}

#if DIAGRAMS_PY_MIMALLOC
/* mimalloc calls this from allocation slow paths (any thread that allocates
   from this mimalloc), and with `force` set on heap abandon at thread exit,
   on the out-of-memory retry and at process exit. Collect cycles only on the
   thread that holds the runtime lock, with the trigger of the runtime's own
   callback. */
static void DIAGRAMS_CDECL guarded_deferred_free(bool force,
                                                 unsigned long long heartbeat,
                                                 void *arg) {
  (void)heartbeat;
  (void)arg;
  if (!holds_runtime_lock) {
    atomic_fetch_add(&stat_deferred_skipped, 1);
    return;
  }
  atomic_fetch_add(&stat_deferred_locked, 1);
  if (force || moonbit_cycle_collection_threshold()) {
    atomic_fetch_add(&stat_deferred_collected, 1);
    moonbit_collect_cycles();
  }
}
#endif

/* Initializes the runtime once per process. Call it with the lock held. */
static void ensure_runtime_locked(void) {
  if (runtime_ready) {
    return;
  }
  moonbit_init();
#if DIAGRAMS_PY_MIMALLOC
  /* Replaces the callback that moonbit_init may have registered. */
  mi_register_deferred_free(guarded_deferred_free, NULL);
#endif
  runtime_abi_version = diagrams_py_abi_version();
  runtime_ready = 1;
  runtime_init_count += 1;
}

/* ------------------------------------------------------------------------ */
/* Owned C buffers                                                          */
/* ------------------------------------------------------------------------ */

typedef struct {
  unsigned char *data;
  size_t len;
  size_t cap;
} buffer_t;

static int buffer_reserve(buffer_t *b, size_t extra) {
  if (extra > SIZE_MAX - b->len) {
    PyErr_NoMemory();
    return -1;
  }
  size_t need = b->len + extra;
  if (need <= b->cap) {
    return 0;
  }
  size_t cap = b->cap ? b->cap : 256;
  while (cap < need) {
    cap = cap > SIZE_MAX / 2 ? need : cap * 2;
  }
  unsigned char *data = (unsigned char *)realloc(b->data, cap);
  if (data == NULL) {
    PyErr_NoMemory();
    return -1;
  }
  b->data = data;
  b->cap = cap;
  return 0;
}

static int buffer_byte(buffer_t *b, unsigned char value) {
  if (buffer_reserve(b, 1) < 0) {
    return -1;
  }
  b->data[b->len++] = value;
  return 0;
}

static int buffer_u32(buffer_t *b, uint32_t value) {
  if (buffer_reserve(b, 4) < 0) {
    return -1;
  }
  for (int i = 0; i < 4; i++) {
    b->data[b->len++] = (unsigned char)(value >> (8 * i));
  }
  return 0;
}

static int buffer_bytes(buffer_t *b, const void *data, size_t len) {
  if (buffer_reserve(b, len) < 0) {
    return -1;
  }
  if (len > 0) {
    memcpy(b->data + b->len, data, len);
  }
  b->len += len;
  return 0;
}

/* ------------------------------------------------------------------------ */
/* Encoding Python values (GIL held)                                        */
/* ------------------------------------------------------------------------ */

typedef struct {
  PyObject *seq; /* strong reference */
  Py_ssize_t index;
  Py_ssize_t count;
} encode_frame_t;

static int encode_length(buffer_t *b, unsigned char tag, Py_ssize_t len,
                         const char *what) {
  if (len < 0 || (unsigned long long)len > 0x7FFFFFFFull) {
    PyErr_Format(PyExc_OverflowError, "%s is too large for the boundary",
                 what);
    return -1;
  }
  if (buffer_byte(b, tag) < 0) {
    return -1;
  }
  return buffer_u32(b, (uint32_t)len);
}

/* Writes a scalar value or a container header. Sets *count to the number of
   items of a non-empty tuple or list, otherwise to 0. */
static int encode_one(buffer_t *b, PyObject *value, Py_ssize_t *count) {
  *count = 0;
  if (value == Py_None) {
    return buffer_byte(b, 0);
  }
  if (value == Py_False) {
    return buffer_byte(b, 1);
  }
  if (value == Py_True) {
    return buffer_byte(b, 2);
  }
  if (PyBool_Check(value)) {
    PyErr_SetString(PyExc_TypeError, "unexpected bool value");
    return -1;
  }
  if (PyLong_Check(value)) {
    int overflow = 0;
    long long number = PyLong_AsLongLongAndOverflow(value, &overflow);
    if (overflow != 0) {
      PyErr_SetString(PyExc_OverflowError,
                      "int is outside the signed 64-bit range");
      return -1;
    }
    if (number == -1 && PyErr_Occurred()) {
      return -1;
    }
    if (buffer_byte(b, 3) < 0 || buffer_reserve(b, 8) < 0) {
      return -1;
    }
    uint64_t bits = (uint64_t)number;
    for (int i = 0; i < 8; i++) {
      b->data[b->len++] = (unsigned char)(bits >> (8 * i));
    }
    return 0;
  }
  if (PyUnicode_Check(value)) {
    /* A lone surrogate raises UnicodeEncodeError here, before MoonBit runs. */
    Py_ssize_t size = 0;
    const char *utf8 = PyUnicode_AsUTF8AndSize(value, &size);
    if (utf8 == NULL || encode_length(b, 4, size, "str") < 0) {
      return -1;
    }
    return buffer_bytes(b, utf8, (size_t)size);
  }
  if (PyBytes_Check(value)) {
    char *data = NULL;
    Py_ssize_t size = 0;
    if (PyBytes_AsStringAndSize(value, &data, &size) < 0 ||
        encode_length(b, 5, size, "bytes") < 0) {
      return -1;
    }
    return buffer_bytes(b, data, (size_t)size);
  }
  if (PyTuple_Check(value) || PyList_Check(value)) {
    Py_ssize_t size =
        PyTuple_Check(value) ? PyTuple_Size(value) : PyList_Size(value);
    if (size < 0 || encode_length(b, 6, size, "tuple") < 0) {
      return -1;
    }
    *count = size;
    return 0;
  }
  PyErr_Format(PyExc_TypeError, "unsupported boundary value of type %R",
               (PyObject *)Py_TYPE(value));
  return -1;
}

/* Encodes `value` with an explicit stack. Lists become record lists. */
static int encode_value(buffer_t *b, PyObject *value) {
  encode_frame_t frames[RECORD_MAX_DEPTH];
  int depth = 0;
  Py_ssize_t count = 0;
  Py_INCREF(value);
  if (encode_one(b, value, &count) < 0) {
    Py_DECREF(value);
    return -1;
  }
  if (count == 0) {
    Py_DECREF(value);
    return 0;
  }
  frames[depth++] = (encode_frame_t){value, 0, count};
  while (depth > 0) {
    encode_frame_t *frame = &frames[depth - 1];
    if (frame->index == frame->count) {
      Py_DECREF(frame->seq);
      depth--;
      continue;
    }
    PyObject *item;
    if (PyTuple_Check(frame->seq)) {
      item = PyTuple_GetItem(frame->seq, frame->index);
    } else {
      if (PyList_Size(frame->seq) != frame->count) {
        PyErr_SetString(PyExc_RuntimeError,
                        "list changed size during boundary encoding");
        goto fail;
      }
      item = PyList_GetItem(frame->seq, frame->index);
    }
    if (item == NULL) {
      goto fail;
    }
    frame->index++;
    Py_INCREF(item);
    if (encode_one(b, item, &count) < 0) {
      Py_DECREF(item);
      goto fail;
    }
    if (count == 0) {
      Py_DECREF(item);
      continue;
    }
    if (depth == RECORD_MAX_DEPTH) {
      Py_DECREF(item);
      PyErr_SetString(PyExc_ValueError,
                      "boundary value is nested more than 64 levels deep");
      goto fail;
    }
    frames[depth++] = (encode_frame_t){item, 0, count};
  }
  return 0;
fail:
  while (depth > 0) {
    Py_DECREF(frames[--depth].seq);
  }
  return -1;
}

/* ------------------------------------------------------------------------ */
/* Decoding the response (GIL held)                                         */
/* ------------------------------------------------------------------------ */

typedef struct {
  PyObject *tuple; /* owned until it is complete and placed */
  Py_ssize_t index;
  Py_ssize_t count;
} decode_frame_t;

static PyObject *malformed(const char *what) {
  PyErr_Format(PyExc_RuntimeError, "malformed boundary response: %s", what);
  return NULL;
}

static PyObject *decode_value(const unsigned char *data, size_t len) {
  decode_frame_t frames[RECORD_MAX_DEPTH];
  int depth = 0;
  size_t at = 0;
  PyObject *result = NULL;
  while (result == NULL) {
    if (at >= len) {
      malformed("the record ends early");
      goto fail;
    }
    unsigned char tag = data[at++];
    PyObject *value = NULL;
    uint32_t length = 0;
    if (tag >= 4 && tag <= 6) {
      if (len - at < 4) {
        malformed("the record ends early");
        goto fail;
      }
      for (int i = 0; i < 4; i++) {
        length |= (uint32_t)data[at++] << (8 * i);
      }
      if (length > len - at) {
        malformed("a length exceeds the record");
        goto fail;
      }
    }
    switch (tag) {
    case 0:
      value = Py_NewRef(Py_None);
      break;
    case 1:
      value = Py_NewRef(Py_False);
      break;
    case 2:
      value = Py_NewRef(Py_True);
      break;
    case 3: {
      if (len - at < 8) {
        malformed("the record ends early");
        goto fail;
      }
      uint64_t bits = 0;
      for (int i = 0; i < 8; i++) {
        bits |= (uint64_t)data[at++] << (8 * i);
      }
      value = PyLong_FromLongLong((long long)bits);
      break;
    }
    case 4:
      value = PyUnicode_DecodeUTF8((const char *)data + at,
                                   (Py_ssize_t)length, "strict");
      at += length;
      break;
    case 5:
      value = PyBytes_FromStringAndSize((const char *)data + at,
                                        (Py_ssize_t)length);
      at += length;
      break;
    case 6:
      if (length == 0) {
        value = PyTuple_New(0);
        break;
      }
      if (depth == RECORD_MAX_DEPTH) {
        malformed("the record is nested too deeply");
        goto fail;
      }
      {
        PyObject *tuple = PyTuple_New((Py_ssize_t)length);
        if (tuple == NULL) {
          goto fail;
        }
        frames[depth++] = (decode_frame_t){tuple, 0, (Py_ssize_t)length};
      }
      continue;
    default:
      malformed("unknown tag");
      goto fail;
    }
    if (value == NULL) {
      goto fail;
    }
    while (value != NULL) {
      if (depth == 0) {
        result = value;
        break;
      }
      decode_frame_t *frame = &frames[depth - 1];
      /* PyTuple_SetItem steals `value`. */
      if (PyTuple_SetItem(frame->tuple, frame->index++, value) < 0) {
        goto fail;
      }
      if (frame->index == frame->count) {
        value = frame->tuple;
        depth--;
      } else {
        value = NULL;
      }
    }
  }
  if (at != len) {
    Py_DECREF(result);
    return malformed("trailing bytes");
  }
  return result;
fail:
  while (depth > 0) {
    Py_DECREF(frames[--depth].tuple);
  }
  return NULL;
}

/* ------------------------------------------------------------------------ */
/* Detached runtime work                                                    */
/* ------------------------------------------------------------------------ */

/* Runs one request. Call it while detached. On return, `out` is a malloc
   buffer that the caller frees, or NULL when malloc failed. */
static void runtime_call(const unsigned char *request, size_t request_len,
                         unsigned char **out, size_t *out_len) {
  *out = NULL;
  *out_len = 0;
  runtime_enter();
  ensure_runtime_locked();
  /* A new MoonBit Bytes value with one reference, which the adapter owns. */
  moonbit_bytes_t input = moonbit_make_bytes_raw((int32_t)request_len);
  if (request_len > 0) {
    memcpy(input, request, request_len);
  }
  /* The export borrows `input` and returns a new reference. */
  moonbit_bytes_t output = diagrams_py_call(input);
  moonbit_decref(input);
  runtime_calls += 1;
  size_t length = (size_t)Moonbit_array_length(output);
  unsigned char *copy = (unsigned char *)malloc(length ? length : 1);
  if (copy != NULL) {
    memcpy(copy, output, length);
    *out = copy;
    *out_len = length;
  }
  moonbit_decref(output);
  runtime_exit();
}

/* ------------------------------------------------------------------------ */
/* Module functions                                                         */
/* ------------------------------------------------------------------------ */

PyDoc_STRVAR(call_doc,
             "call(request: tuple, /) -> tuple\n"
             "\n"
             "Run one private boundary operation. `request` is (op, *args).\n"
             "Returns (0, value) or (1, code, message). Internal; use\n"
             "diagrams_mbt._boundary.call.");

static PyObject *native_call(PyObject *module, PyObject *request) {
  (void)module;
  if (!PyTuple_Check(request)) {
    PyErr_SetString(PyExc_TypeError, "request must be a tuple");
    return NULL;
  }
  uint64_t gil_start = now_ns();
  buffer_t encoded = {NULL, 0, 0};
  if (encode_value(&encoded, request) < 0) {
    free(encoded.data);
    return NULL;
  }
  if (encoded.len > 0x7FFFFFFFu) {
    free(encoded.data);
    PyErr_SetString(PyExc_OverflowError,
                    "request is too large for the boundary");
    return NULL;
  }
  unsigned char *response = NULL;
  size_t response_len = 0;
  uint64_t gil_held = now_ns() - gil_start;
  Py_BEGIN_ALLOW_THREADS
  runtime_call(encoded.data, encoded.len, &response, &response_len);
  Py_END_ALLOW_THREADS
  gil_start = now_ns();
  free(encoded.data);
  atomic_fetch_add(&stat_bytes_in, (unsigned long long)encoded.len);
  if (response == NULL) {
    return PyErr_NoMemory();
  }
  atomic_fetch_add(&stat_bytes_out, (unsigned long long)response_len);
  PyObject *result = decode_value(response, response_len);
  free(response);
  atomic_fetch_add(&stat_gil_ns, gil_held + (now_ns() - gil_start));
  return result;
}

PyDoc_STRVAR(lock_stats_doc,
             "_lock_stats() -> dict\n"
             "\n"
             "Runtime-lock instrumentation. Read without the runtime lock.");

static PyObject *lock_stats(PyObject *module, PyObject *unused) {
  (void)module;
  (void)unused;
  return Py_BuildValue(
      "{s:K,s:K,s:L,s:L,s:L,s:K,s:K,s:K,s:K,s:K,s:K,s:K,s:K,s:s}", "entries",
      (unsigned long long)atomic_load(&stat_entries), "contended",
      (unsigned long long)atomic_load(&stat_contended), "waiting",
      (long long)atomic_load(&stat_waiting), "inside",
      (long long)atomic_load(&stat_inside), "max_inside",
      (long long)atomic_load(&stat_max_inside), "wait_ns",
      (unsigned long long)atomic_load(&stat_wait_ns), "held_ns",
      (unsigned long long)atomic_load(&stat_held_ns), "gil_ns",
      (unsigned long long)atomic_load(&stat_gil_ns), "bytes_in",
      (unsigned long long)atomic_load(&stat_bytes_in), "bytes_out",
      (unsigned long long)atomic_load(&stat_bytes_out), "deferred_locked",
      (unsigned long long)atomic_load(&stat_deferred_locked),
      "deferred_skipped",
      (unsigned long long)atomic_load(&stat_deferred_skipped),
      "deferred_collected",
      (unsigned long long)atomic_load(&stat_deferred_collected), "allocator",
      DIAGRAMS_PY_MIMALLOC ? "mimalloc" : "system");
}

PyDoc_STRVAR(runtime_info_doc,
             "_runtime_info() -> dict\n"
             "\n"
             "Counters of the process-wide MoonBit runtime, read under the\n"
             "runtime lock.");

static PyObject *runtime_info(PyObject *module, PyObject *unused) {
  (void)module;
  (void)unused;
  long init_count = 0;
  unsigned long long calls = 0;
  int32_t version = 0;
  Py_BEGIN_ALLOW_THREADS
  runtime_enter();
  init_count = runtime_init_count;
  calls = runtime_calls;
  version = runtime_abi_version;
  runtime_exit();
  Py_END_ALLOW_THREADS
  return Py_BuildValue("{s:l,s:K,s:i,s:s}", "init_count", init_count, "calls",
                       calls, "abi_version", (int)version, "allocator",
                       DIAGRAMS_PY_MIMALLOC ? "mimalloc" : "system");
}

static PyMethodDef module_methods[] = {
    {"call", native_call, METH_O, call_doc},
    {"_lock_stats", lock_stats, METH_NOARGS, lock_stats_doc},
    {"_runtime_info", runtime_info, METH_NOARGS, runtime_info_doc},
    {NULL, NULL, 0, NULL},
};

static int module_exec(PyObject *module) {
  int32_t version = 0;
  /* Initialization takes the runtime lock like every other entry, and
     waits for it detached. */
  Py_BEGIN_ALLOW_THREADS
  runtime_enter();
  ensure_runtime_locked();
  version = runtime_abi_version;
  runtime_exit();
  Py_END_ALLOW_THREADS
  if (version != DIAGRAMS_PY_EXPECTED_ABI) {
    PyErr_Format(PyExc_ImportError,
                 "diagrams_mbt: MoonBit boundary version %d, adapter "
                 "expects %d",
                 (int)version, (int)DIAGRAMS_PY_EXPECTED_ABI);
    return -1;
  }
  if (PyModule_AddIntConstant(module, "ABI_VERSION", version) < 0) {
    return -1;
  }
  if (PyModule_AddIntConstant(module, "RECORD_MAX_DEPTH", RECORD_MAX_DEPTH) <
      0) {
    return -1;
  }
  return 0;
}

static PyModuleDef_Slot module_slots[] = {
    {Py_mod_exec, (void *)module_exec},
    /* One MoonBit runtime exists for each process. */
    {Py_mod_multiple_interpreters, Py_MOD_MULTIPLE_INTERPRETERS_NOT_SUPPORTED},
#ifdef Py_mod_gil
    /* Free-threaded builds must keep the GIL for this module. */
    {Py_mod_gil, Py_MOD_GIL_USED},
#endif
    {0, NULL},
};

static struct PyModuleDef module_def = {
    PyModuleDef_HEAD_INIT,
    "diagrams_mbt._native",
    "In-process diagrams.mbt operations through the MoonBit native backend "
    "(private boundary).",
    0,
    module_methods,
    module_slots,
    NULL,
    NULL,
    NULL,
};

PyMODINIT_FUNC PyInit__native(void) { return PyModuleDef_Init(&module_def); }
