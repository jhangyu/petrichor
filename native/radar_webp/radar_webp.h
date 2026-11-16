// C shim over libwebp for radar frames: lossless RGBA encode and RGBA decode.
// Built into one shared library together with libwebp by tools/build_radar_webp.py.
// Dart binds it in lib/data/radar/radar_webp.dart.
#ifndef RADAR_WEBP_H_
#define RADAR_WEBP_H_

#include <stddef.h>
#include <stdint.h>

#if defined(_WIN32)
#define RADAR_WEBP_EXPORT __declspec(dllexport)
#else
#define RADAR_WEBP_EXPORT __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Return codes. 0 is success; every failure is negative.
enum {
  RADAR_WEBP_OK = 0,
  // A pointer is NULL, width/height <= 0 or > 16383 (encode), stride <
  // width * 4, size == 0,
  // or level is outside 0..9.
  RADAR_WEBP_E_INVALID_ARG = -1,
  // libwebp rejected its own config/picture/decoder init (header/library
  // version mismatch).
  RADAR_WEBP_E_VERSION = -2,
  // libwebp could not allocate memory.
  RADAR_WEBP_E_OUT_OF_MEMORY = -3,
  // WebPEncode failed for a reason other than memory.
  RADAR_WEBP_E_ENCODE = -4,
  // The input bytes are not a readable WebP bitstream (header parse failed).
  RADAR_WEBP_E_BITSTREAM = -5,
  // The caller's output buffer is smaller than stride * height, or stride is
  // smaller than width * 4 of the decoded image.
  RADAR_WEBP_E_BUFFER_TOO_SMALL = -6,
  // The header parsed but decoding the image data failed (truncated or
  // corrupt payload).
  RADAR_WEBP_E_DECODE = -7,
};

// Encodes width x height RGBA (rows `stride` bytes apart) as lossless WebP at
// compression `level` 0..9 (WebPConfigLosslessPreset). Pixels with alpha 0
// decode with alpha 0; their RGB is not preserved. On success *out holds the
// bitstream (release with radar_webp_free) and *out_size its length.
RADAR_WEBP_EXPORT int radar_webp_encode_lossless_rgba(
    const uint8_t* rgba, int width, int height, int stride, int level,
    uint8_t** out, size_t* out_size);

// Reads the canvas size of a WebP bitstream without decoding it.
RADAR_WEBP_EXPORT int radar_webp_get_info(const uint8_t* data, size_t size,
                                          int* width, int* height);

// Decodes a WebP bitstream into the caller's buffer as PREMULTIPLIED RGBA
// (libwebp MODE_rgbA, matching Flutter's ui.PixelFormat.rgba8888), rows
// `stride` bytes apart. out_size must be at least stride * height.
RADAR_WEBP_EXPORT int radar_webp_decode_rgba_into(const uint8_t* data,
                                                  size_t size, uint8_t* out,
                                                  size_t out_size, int stride);

// Releases a buffer returned by radar_webp_encode_lossless_rgba. NULL is a
// no-op. Only for buffers this library allocated.
RADAR_WEBP_EXPORT void radar_webp_free(void* ptr);

#ifdef __cplusplus
}
#endif

#endif  // RADAR_WEBP_H_
