/* The cart API (api.c) and the host's side of it (runtime.c). */
#ifndef API_H
#define API_H

#include "gfx.h"
#include "lua/lua.h"

/* Register gfx, toon, input, sfx, music, particles, and the color and random helpers. */
void api_open(lua_State *L);
/* A color argument: 0xRRGGBB is opaque, 0xAARRGGBB with AA > 0 blends. */
gcol api_color(lua_State *L, int i);
/* The cart's folder, for gfx.image and import. */
extern const char *api_cart_dir;
/* Bytes held by layers and images, which Lua's own count does not see. */
extern size_t api_img_bytes;
/* Bytes a cart may still use before its memory cap. */
size_t api_mem_cap(void);
/* A file of the running cart, from its folder or the pack: malloc'd, NUL-terminated. */
unsigned char *api_read(const char *name, size_t *len);
#endif
