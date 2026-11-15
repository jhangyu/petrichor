#if defined(__ANDROID__)
// Declare newer-than-minSdk bionic calls (mallopt) as weak; each call site is
// guarded by __builtin_available.
#define __ANDROID_UNAVAILABLE_SYMBOLS_ARE_WEAK__
#endif

#include "radar_webp.h"

#include <webp/decode.h>
#include <webp/encode.h>

#if defined(__APPLE__)
#include <malloc/malloc.h>
#elif defined(__ANDROID__) || defined(__GLIBC__) || defined(_WIN32)
#include <malloc.h>
#endif

#define RADAR_WEBP_BYTES_PER_PIXEL 4
#define RADAR_WEBP_MAX_LEVEL 9

// libwebp's lossless encoder and decoder allocate and free tens of MB per
// 2048 px frame. The system allocator keeps those freed pages resident in its
// per-thread/per-CPU caches, so every thread that ever ran a codec call holds
// ~50 MB more (measured: .claude/tmp/webp-impl/native-build-opus/r2/). Hand the
// freed pages back to the OS after each call. Each C library has its own call
// for this; there is no portable one.
static void release_free_heap(void) {
#if defined(__APPLE__)
  malloc_zone_pressure_relief(NULL, 0);
#elif defined(__ANDROID__)
  if (__builtin_available(android 28, *)) mallopt(M_PURGE, 0);
#elif defined(__GLIBC__)
  malloc_trim(0);
#elif defined(_WIN32)
  _heapmin();
#else
#error "release_free_heap: no allocator purge call known for this C library"
#endif
}

static int encoding_error_code(WebPEncodingError error) {
  switch (error) {
    case VP8_ENC_ERROR_OUT_OF_MEMORY:
    case VP8_ENC_ERROR_BITSTREAM_OUT_OF_MEMORY:
      return RADAR_WEBP_E_OUT_OF_MEMORY;
    case VP8_ENC_ERROR_BAD_DIMENSION:
      return RADAR_WEBP_E_INVALID_ARG;
    default:
      return RADAR_WEBP_E_ENCODE;
  }
}

static int encode(const uint8_t* rgba, int width, int height, int stride,
                  int level, uint8_t** out, size_t* out_size) {
  WebPConfig config;
  if (!WebPConfigInit(&config) || !WebPConfigLosslessPreset(&config, level)) {
    return RADAR_WEBP_E_VERSION;
  }
  WebPPicture picture;
  if (!WebPPictureInit(&picture)) return RADAR_WEBP_E_VERSION;
  picture.use_argb = 1;
  picture.width = width;
  picture.height = height;
  if (!WebPPictureImportRGBA(&picture, rgba, stride)) {
    const WebPEncodingError error = picture.error_code;
    WebPPictureFree(&picture);
    return encoding_error_code(error);
  }
  WebPMemoryWriter writer;
  WebPMemoryWriterInit(&writer);
  picture.writer = WebPMemoryWrite;
  picture.custom_ptr = &writer;
  const int ok = WebPEncode(&config, &picture);
  const WebPEncodingError error = picture.error_code;
  WebPPictureFree(&picture);
  if (!ok) {
    WebPMemoryWriterClear(&writer);
    return encoding_error_code(error);
  }
  // Ownership of writer.mem passes to the caller (radar_webp_free).
  *out = writer.mem;
  *out_size = writer.size;
  return RADAR_WEBP_OK;
}

int radar_webp_encode_lossless_rgba(const uint8_t* rgba, int width, int height,
                                    int stride, int level, uint8_t** out,
                                    size_t* out_size) {
  if (rgba == NULL || out == NULL || out_size == NULL || width <= 0 ||
      height <= 0 || width > WEBP_MAX_DIMENSION ||
      height > WEBP_MAX_DIMENSION ||
      stride < width * RADAR_WEBP_BYTES_PER_PIXEL || level < 0 ||
      level > RADAR_WEBP_MAX_LEVEL) {
    return RADAR_WEBP_E_INVALID_ARG;
  }
  return encode(rgba, width, height, stride, level, out, out_size);
}

int radar_webp_get_info(const uint8_t* data, size_t size, int* width,
                        int* height) {
  if (data == NULL || size == 0 || width == NULL || height == NULL) {
    return RADAR_WEBP_E_INVALID_ARG;
  }
  return WebPGetInfo(data, size, width, height) ? RADAR_WEBP_OK
                                                : RADAR_WEBP_E_BITSTREAM;
}

static int decode(const uint8_t* data, size_t size, uint8_t* out,
                  size_t out_size, int stride) {
  int width = 0;
  int height = 0;
  if (!WebPGetInfo(data, size, &width, &height)) return RADAR_WEBP_E_BITSTREAM;
  if (stride < width * RADAR_WEBP_BYTES_PER_PIXEL ||
      out_size < (size_t)stride * (size_t)height) {
    return RADAR_WEBP_E_BUFFER_TOO_SMALL;
  }
  WebPDecoderConfig config;
  if (!WebPInitDecoderConfig(&config)) return RADAR_WEBP_E_VERSION;
  config.output.colorspace = MODE_rgbA;
  config.output.is_external_memory = 1;
  config.output.u.RGBA.rgba = out;
  config.output.u.RGBA.stride = stride;
  config.output.u.RGBA.size = out_size;
  const VP8StatusCode status = WebPDecode(data, size, &config);
  if (status == VP8_STATUS_OK) return RADAR_WEBP_OK;
  return status == VP8_STATUS_OUT_OF_MEMORY ? RADAR_WEBP_E_OUT_OF_MEMORY
                                            : RADAR_WEBP_E_DECODE;
}

int radar_webp_decode_rgba_into(const uint8_t* data, size_t size, uint8_t* out,
                                size_t out_size, int stride) {
  if (data == NULL || size == 0 || out == NULL || stride <= 0) {
    return RADAR_WEBP_E_INVALID_ARG;
  }
  const int code = decode(data, size, out, out_size, stride);
  release_free_heap();
  return code;
}

// Called last on every successful encode, after the caller freed its pixels.
void radar_webp_free(void* ptr) {
  WebPFree(ptr);
  release_free_heap();
}
