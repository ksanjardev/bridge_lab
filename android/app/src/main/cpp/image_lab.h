/*
 * image_lab.h: the C API that Dart calls through dart:ffi.
 *
 * This header is the single source of truth. ffigen reads it and generates
 * image_lab_bindings.g.dart, so adding a function here and running
 *   dart run ffigen --config ffigen.yaml
 * is all it takes to call it from Dart.
 *
 * Conventions:
 *  - Pixels are RGBA, 4 bytes each, row by row.
 *  - Functions return 0 on success and a negative code on error. C has no
 *    exceptions that could cross the FFI boundary.
 *  - The caller (Dart) owns all buffers. This library never frees or keeps them.
 */

#pragma once
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifndef IMAGE_LAB_API
#define IMAGE_LAB_API __attribute__((visibility("default"))) __attribute__((used))
#endif

/// Returns a static string, so Dart must not free it.
IMAGE_LAB_API const char* image_lab_version(void);

/// Box blur on RGBA pixels (4 bytes each). Returns 0 on success, negative on error.
/// There are no exceptions across FFI, so errors are return codes.
IMAGE_LAB_API int32_t box_blur_rgba(const uint8_t* src, uint8_t* dst,
        int32_t width, int32_t height,
        int32_t radius);

/// filter: 0 = blur, 1 = pixelate, 2 = grayscale, 3 = sepia.
/// amount: blur radius or pixel block size (ignored by grayscale and sepia).
IMAGE_LAB_API int32_t filter_rgba(const uint8_t* src, uint8_t* dst,
        int32_t width, int32_t height,
        int32_t filter, int32_t amount);

#ifdef __cplusplus
}
#endif