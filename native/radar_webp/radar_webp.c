#include "radar_webp.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <webp/decode.h>
#include <webp/encode.h>

#define RADAR_WEBP_BYTES_PER_PIXEL 4
#define RADAR_WEBP_MAX_LEVEL 9

// libwebp's lossless encoder and decoder allocate tens of MB per 2048 px frame
// (encode: 76 allocations, 76 MB in total; decode: 39, 16 MB). Freed through
// the system allocator, those pages stay resident in its caches (~50 MB per
// thread that ever ran a codec call). So every encode/decode call gives libwebp
// a private arena instead: allocations bump through anonymous page mappings,
// free is a no-op, and the whole arena is unmapped when the call returns, which
// hands every page back to the OS at once. libwebp reaches the arena through
// libwebp_alloc.h, force-included into its allocator file by
// tools/build_radar_webp.py. Measurements: .claude/tmp/heap-uniform/.
#define RADAR_WEBP_ARENA_CHUNK_BYTES ((size_t)64 << 20)
// Windows' allocation granularity; a multiple of every page size we target.
#define RADAR_WEBP_ARENA_GRANULE_BYTES ((size_t)64 << 10)
#define RADAR_WEBP_ARENA_ALIGN ((size_t)_Alignof(max_align_t))

typedef struct ArenaChunk {
  struct ArenaChunk* next;
  size_t bytes;
} ArenaChunk;

typedef struct {
  ArenaChunk* chunks;
  char* next_free;
  char* end;
} Arena;

// The arena of the codec call running on this thread; NULL outside a call.
// A Dart FFI call runs start to end on one OS thread.
static _Thread_local Arena* active_arena;

static size_t round_up(size_t value, size_t multiple) {
  return (value + multiple - 1) / multiple * multiple;
}

// The C library offers no call that returns pages to the OS (a malloc'd block
// stays resident after free on macOS at every size from 1 to 256 MB:
// .claude/tmp/heap-uniform/freetest.log), so the arena maps pages itself:
// POSIX mmap everywhere but Windows, which has VirtualAlloc instead.
// Unmapping a mapping we created can only fail on a bug (bad address/length),
// so a failure stops the process instead of leaking silently.
#if defined(_WIN32)
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

static void* map_pages(size_t bytes) {
  return VirtualAlloc(NULL, bytes, MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE);
}

static void unmap_pages(void* pages, size_t bytes) {
  (void)bytes;
  if (!VirtualFree(pages, 0, MEM_RELEASE)) abort();
}
#else
#include <sys/mman.h>

static void* map_pages(size_t bytes) {
  void* pages = mmap(NULL, bytes, PROT_READ | PROT_WRITE,
                     MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  return pages == MAP_FAILED ? NULL : pages;
}

static void unmap_pages(void* pages, size_t bytes) {
  if (munmap(pages, bytes) != 0) abort();
}
#endif

static void* arena_alloc(Arena* arena, size_t size) {
  // libwebp caps one allocation at WEBP_MAX_ALLOCABLE_MEMORY (2^34 on 64-bit,
  // just under 2^31 on 32-bit), so these roundings cannot overflow.
  // A zero-byte request is served as one byte so it returns a non-NULL pointer.
  if (size == 0) size = 1;
  size = round_up(size, RADAR_WEBP_ARENA_ALIGN);
  if ((size_t)(arena->end - arena->next_free) < size) {
    const size_t header = round_up(sizeof(ArenaChunk), RADAR_WEBP_ARENA_ALIGN);
    size_t bytes = round_up(header + size, RADAR_WEBP_ARENA_GRANULE_BYTES);
    if (bytes < RADAR_WEBP_ARENA_CHUNK_BYTES) bytes = RADAR_WEBP_ARENA_CHUNK_BYTES;
    ArenaChunk* const chunk = map_pages(bytes);
    if (chunk == NULL) return NULL;
    chunk->next = arena->chunks;
    chunk->bytes = bytes;
    arena->chunks = chunk;
    arena->next_free = (char*)chunk + header;
    arena->end = (char*)chunk + bytes;
  }
  void* const ptr = arena->next_free;
  arena->next_free += size;
  return ptr;
}

static void arena_begin(Arena* arena) {
  arena->chunks = NULL;
  arena->next_free = NULL;
  arena->end = NULL;
  active_arena = arena;
}

static void arena_end(Arena* arena) {
  active_arena = NULL;
  ArenaChunk* chunk = arena->chunks;
  while (chunk != NULL) {
    ArenaChunk* const next = chunk->next;
    unmap_pages(chunk, chunk->bytes);
    chunk = next;
  }
}

// libwebp's malloc/calloc/free (libwebp_alloc.h). Every exported function that
// can reach a libwebp allocation opens an arena first; an allocation outside
// one is a bug in this file and stops the process.
void* radar_webp_arena_malloc(size_t size) {
  if (active_arena == NULL) abort();
  return arena_alloc(active_arena, size);
}

void* radar_webp_arena_calloc(size_t count, size_t size) {
  if (active_arena == NULL) abort();
  if (size != 0 && count > SIZE_MAX / size) return NULL;
  // Arena memory is never reused and comes from fresh anonymous mappings,
  // which the OS hands out zero-filled.
  return arena_alloc(active_arena, count * size);
}

// Freed blocks are reclaimed all at once by arena_end.
void radar_webp_arena_free(void* ptr) { (void)ptr; }

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
  // writer.mem lives in the arena, which is unmapped when the call returns, so
  // the caller gets a C-library copy (released by radar_webp_free).
  uint8_t* const copy = malloc(writer.size);
  if (copy == NULL) return RADAR_WEBP_E_OUT_OF_MEMORY;
  memcpy(copy, writer.mem, writer.size);
  *out = copy;
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
  Arena arena;
  arena_begin(&arena);
  const int code = encode(rgba, width, height, stride, level, out, out_size);
  arena_end(&arena);
  return code;
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
  Arena arena;
  arena_begin(&arena);
  const int code = decode(data, size, out, out_size, stride);
  arena_end(&arena);
  return code;
}

void radar_webp_free(void* ptr) { free(ptr); }
