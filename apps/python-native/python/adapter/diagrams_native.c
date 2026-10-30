/*
 * CPython adapter for the diagrams.mbt Python native-binding spike.
 *
 * Copyright 2026 moonrockz. Licensed under the Apache License, Version 2.0.
 *
 * This file is the only C code of the spike. It links the static archive that
 * moon builds for the native `foreign_library` package
 * `moonrockz/diagrams-python-native/ffi` into the extension module
 * `diagrams_native._diagrams_native`.
 *
 * Boundary rules (see the change prove-python-native-binding):
 * - The adapter uses three MoonBit symbols: the generated `moonbit_init` and
 *   the two `diagrams_py_*` exports. From the runtime it uses only
 *   `moonbit_make_bytes_raw`, `moonbit_decref` and `Moonbit_array_length`.
 * - Values cross as UTF-8 bytes. The adapter copies each buffer at the
 *   boundary. No Python object points into MoonBit memory after a call.
 * - Ownership was measured on the pinned compiler, because the MoonBit
 *   documentation does not state it for `#export_name` functions: the export
 *   borrows its `Bytes` argument and returns a new reference. So the adapter
 *   releases the argument and the result, each one time, after the call. A
 *   change in the convention shows as a double free in the sanitizer build or
 *   as allocator growth in the measurement task.
 * - The runtime is initialized one time for each process and never torn down.
 * - The GIL stays held during a call, so calls are serialized.
 */

#define PY_SSIZE_T_CLEAN
#ifndef Py_LIMITED_API
#define Py_LIMITED_API 0x030C0000
#endif
#include <Python.h>

#include <stdint.h>
#include <string.h>

#include "moonbit.h"

/* The boundary version that this adapter understands. */
#ifndef DIAGRAMS_PY_EXPECTED_ABI
#define DIAGRAMS_PY_EXPECTED_ABI 1
#endif

/* MoonBit symbols. `moonbit_init` is generated for a foreign library. */
extern void moonbit_init(void);
extern int32_t diagrams_py_abi_version(void);
extern moonbit_bytes_t diagrams_py_render_svg(moonbit_bytes_t utf8_source);

/* Process-wide state. The GIL protects it. */
static int runtime_ready = 0;
static long runtime_init_count = 0;
static unsigned long long render_calls = 0;

static int ensure_runtime(void) {
  if (!runtime_ready) {
    moonbit_init();
    runtime_ready = 1;
    runtime_init_count += 1;
  }
  return 0;
}

PyDoc_STRVAR(render_svg_json_doc,
             "render_svg_json(source: str, /) -> str\n"
             "\n"
             "Render Mermaid source with the MoonBit renderer in this process\n"
             "and return the versioned JSON result. Internal; use\n"
             "diagrams_native.render_svg.");

static PyObject *render_svg_json(PyObject *module, PyObject *source) {
  (void)module;
  if (!PyUnicode_Check(source)) {
    PyErr_SetString(PyExc_TypeError, "source must be str");
    return NULL;
  }
  /* The str owns this buffer. A lone surrogate raises UnicodeEncodeError
     here, before MoonBit is called. */
  Py_ssize_t size = 0;
  const char *utf8 = PyUnicode_AsUTF8AndSize(source, &size);
  if (utf8 == NULL) {
    return NULL;
  }
  if (size > INT32_MAX) {
    PyErr_SetString(PyExc_OverflowError,
                    "source is larger than a MoonBit Bytes value");
    return NULL;
  }

  /* A new MoonBit Bytes value with one reference, which the adapter owns. */
  moonbit_bytes_t input = moonbit_make_bytes_raw((int32_t)size);
  if (size > 0) {
    memcpy(input, utf8, (size_t)size);
  }
  /* The export borrows `input` and returns a new reference. */
  moonbit_bytes_t output = diagrams_py_render_svg(input);
  moonbit_decref(input);
  render_calls += 1;

  int32_t length = Moonbit_array_length(output);
  PyObject *result =
      PyUnicode_DecodeUTF8((const char *)output, (Py_ssize_t)length, "strict");
  /* Release the result on every path, also when decoding failed. */
  moonbit_decref(output);
  return result;
}

PyDoc_STRVAR(runtime_info_doc,
             "_runtime_info() -> dict\n"
             "\n"
             "Diagnostic counters of the process-wide MoonBit runtime.");

static PyObject *runtime_info(PyObject *module, PyObject *unused) {
  (void)module;
  (void)unused;
  return Py_BuildValue("{s:l,s:K,s:i}", "init_count", runtime_init_count,
                       "render_calls", render_calls, "abi_version",
                       (int)diagrams_py_abi_version());
}

static PyMethodDef module_methods[] = {
    {"render_svg_json", render_svg_json, METH_O, render_svg_json_doc},
    {"_runtime_info", runtime_info, METH_NOARGS, runtime_info_doc},
    {NULL, NULL, 0, NULL},
};

static int module_exec(PyObject *module) {
  if (ensure_runtime() < 0) {
    return -1;
  }
  int32_t version = diagrams_py_abi_version();
  if (version != DIAGRAMS_PY_EXPECTED_ABI) {
    PyErr_Format(PyExc_ImportError,
                 "diagrams_native: MoonBit boundary version %d, adapter "
                 "expects %d",
                 (int)version, (int)DIAGRAMS_PY_EXPECTED_ABI);
    return -1;
  }
  if (PyModule_AddIntConstant(module, "ABI_VERSION", version) < 0) {
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
    "diagrams_native._diagrams_native",
    "In-process Mermaid-to-SVG rendering through the MoonBit native backend "
    "(feasibility spike).",
    0,
    module_methods,
    module_slots,
    NULL,
    NULL,
    NULL,
};

PyMODINIT_FUNC PyInit__diagrams_native(void) {
  return PyModuleDef_Init(&module_def);
}
