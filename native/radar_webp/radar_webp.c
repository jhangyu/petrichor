#include "radar_webp.h"

#include <webp/decode.h>
#include <webp/encode.h>

#define RADAR_WEBP_BYTES_PER_PIXEL 4
#define RADAR_WEBP_MAX_LEVEL 9

int radar_webp_encode_lossless_rgba(const uint8_t* rgba, int width, int height,
                                    int stride, int level, uint8_t** out,
                                    size_t* out_size) {
  if (rgba == NULL || out == NULL || out_size == NULL || width <= 0 ||
      height <= 0 || stride < width * RADAR_WEBP_BYTES_PER_PIXEL || level < 0 ||
      level > RADAR_WEBP_MAX_LEVEL) {
    return RADAR_WEBP_E_INVALID_ARG;
  }
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
    WebPPictureFree(&picture);
    return RADAR_WEBP_E_OUT_OF_MEMORY;
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
    return error == VP8_ENC_ERROR_OUT_OF_MEMORY ||
                   error == VP8_ENC_ERROR_BITSTREAM_OUT_OF_MEMORY
               ? RADAR_WEBP_E_OUT_OF_MEMORY
               : RADAR_WEBP_E_ENCODE;
  }
  // Ownership of writer.mem passes to the caller (radar_webp_free).
  *out = writer.mem;
  *out_size = writer.size;
  return RADAR_WEBP_OK;
}

int radar_webp_get_info(const uint8_t* data, size_t size, int* width,
                        int* height) {
  if (data == NULL || size == 0 || width == NULL || height == NULL) {
    return RADAR_WEBP_E_INVALID_ARG;
  }
  return WebPGetInfo(data, size, width, height) ? RADAR_WEBP_OK
                                                : RADAR_WEBP_E_BITSTREAM;
}

int radar_webp_decode_rgba_into(const uint8_t* data, size_t size, uint8_t* out,
                                size_t out_size, int stride) {
  if (data == NULL || size == 0 || out == NULL || stride <= 0) {
    return RADAR_WEBP_E_INVALID_ARG;
  }
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

void radar_webp_free(void* ptr) { WebPFree(ptr); }
