// Force-included (tools/build_libwebp.py) into libwebp's src/utils/utils.c, the
// only libwebp file on our encode/decode path that calls the C allocator.
// Routes libwebp's heap to the per-call arena in radar_webp.c.
// stdlib.h comes first so its own malloc/calloc/free declarations stay intact.
#ifndef RADAR_WEBP_LIBWEBP_ALLOC_H_
#define RADAR_WEBP_LIBWEBP_ALLOC_H_

#include <stdlib.h>

#ifdef WEBP_USE_THREAD
#error "radar_webp's per-call arena is thread-local state: with WEBP_USE_THREAD libwebp allocates on its own worker threads, where no arena is active, and the allocator would abort."
#endif

void* radar_webp_arena_malloc(size_t size);
void* radar_webp_arena_calloc(size_t count, size_t size);
void radar_webp_arena_free(void* ptr);

#define malloc radar_webp_arena_malloc
#define calloc radar_webp_arena_calloc
#define free radar_webp_arena_free

#endif  // RADAR_WEBP_LIBWEBP_ALLOC_H_
