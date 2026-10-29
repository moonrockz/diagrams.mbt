# JPEG adaptation notice

`jpeg_fixed.mbt` adapts `src/jpeg_encode.mbt` and the JPEG quantization/zigzag
constants from `src/jpeg_tables.mbt` in published `mizchi/image@0.4.3`.

Original author: mizchi.
Repository: https://github.com/mizchi/image-mbt
Published archive SHA-256:
`324e9fac91790655d9ce67e6edc76f7831ace4ab3b197c8657aab23ae7f0cdcb`.
License: Apache License 2.0. The complete license is at the repository root
in `LICENSE`.

Changes replace floating RGB conversion and the platform-dependent cosine DCT
with exact integer color conversion and a pinned integer DCT basis. The public
wrapper validates image bounds and quality before invoking the encoder.
