/* The Lua API a cart sees. Every function here is reachable from a cart and from nowhere
 * else: carts get no io, no os, no require, no debug. See CARTS.md for the reference.
 *
 * Colors are integers. 0xRRGGBB is opaque. 0xAARRGGBB with AA from 01 to FF is see-through.
 * Coordinates are logical pixels of the cart's own picture (240x320 or 384x512).
 */
#include "api.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "gfx.h"
#include "lua/lauxlib.h"
#include "sfx.h"

/* ------------------------------------------------------------------ helpers */

gcol api_color(lua_State *L, int i)
{
    lua_Integer v = luaL_checkinteger(L, i);
    Uint32 c = (Uint32)v;
    if (!(c >> 24))
        c |= 0xff000000u;
    return c;
}

static gcol opt_color(lua_State *L, int i, gcol def) { return lua_isnoneornil(L, i) ? def : api_color(L, i); }

static float num(lua_State *L, int i) { return (float)luaL_checknumber(L, i); }
static float optnum(lua_State *L, int i, float d) { return (float)luaL_optnumber(L, i, d); }

static int button_of(lua_State *L, int i)
{
    static const struct {
        const char *name;
        int b;
    } map[] = {{"up", CAB_UP},     {"down", CAB_DOWN}, {"left", CAB_LEFT}, {"right", CAB_RIGHT},
               {"low", CAB_LOW},   {"tl", CAB_TL},     {"tr", CAB_TR},     {"1p", CAB_1P},
               {"2p", CAB_2P},     {"start", CAB_START}, {"select", CAB_SELECT}};
    const char *s = luaL_checkstring(L, i);
    for (unsigned k = 0; k < sizeof map / sizeof map[0]; k++)
        if (!strcmp(s, map[k].name))
            return map[k].b;
    return luaL_error(L, "no button named '%s' (the deck has up down left right low tl tr 1p 2p)", s);
}

/* ------------------------------------------------------------------ colors */

static int l_rgb(lua_State *L)
{
    int r = (int)luaL_checkinteger(L, 1), g = (int)luaL_checkinteger(L, 2), b = (int)luaL_checkinteger(L, 3);
    lua_pushinteger(L, (lua_Integer)(RGB(r & 255, g & 255, b & 255) & 0xffffff));
    return 1;
}

static int l_rgba(lua_State *L)
{
    int r = (int)luaL_checkinteger(L, 1), g = (int)luaL_checkinteger(L, 2), b = (int)luaL_checkinteger(L, 3);
    int a = (int)luaL_checkinteger(L, 4);
    a = a < 1 ? 1 : a > 255 ? 255 : a;
    lua_pushinteger(L, (lua_Integer)RGBA(r & 255, g & 255, b & 255, a));
    return 1;
}

static int l_hex(lua_State *L)
{
    const char *s = luaL_checkstring(L, 1);
    unsigned long v;
    if (*s == '#')
        s++;
    v = strtoul(s, NULL, 16);
    if (strlen(s) == 3)
        v = ((v & 0xf00) << 12 | (v & 0xf00) << 8) | ((v & 0xf0) << 8 | (v & 0xf0) << 4) | ((v & 0xf) << 4 | (v & 0xf));
    lua_pushinteger(L, (lua_Integer)(v & 0xffffffff));
    return 1;
}

static int l_alpha(lua_State *L)
{
    gcol c = api_color(L, 1);
    int a = (int)luaL_checkinteger(L, 2);
    a = a < 1 ? 1 : a > 255 ? 255 : a;
    lua_pushinteger(L, (lua_Integer)col_alpha(c, a));
    return 1;
}

static void push_color(lua_State *L, gcol c)
{
    lua_pushinteger(L, (lua_Integer)(COL_A(c) == 255 ? (c & 0xffffff) : c));
}

static int l_mix(lua_State *L)
{
    push_color(L, col_mix(api_color(L, 1), api_color(L, 2), num(L, 3)));
    return 1;
}

static int l_shade(lua_State *L)
{
    push_color(L, col_scale(api_color(L, 1), num(L, 2)));
    return 1;
}

static int l_hsv(lua_State *L)
{
    push_color(L, col_hsv(num(L, 1), optnum(L, 2, 1), optnum(L, 3, 1)));
    return 1;
}

/* ------------------------------------------------------------------ random */

static int l_rnd(lua_State *L)
{
    if (lua_isnoneornil(L, 1))
        lua_pushnumber(L, rng_f());
    else if (lua_isnoneornil(L, 2))
        lua_pushnumber(L, rng_f() * luaL_checknumber(L, 1));
    else
        lua_pushnumber(L, rng_range(num(L, 1), num(L, 2)));
    return 1;
}

static int l_rndi(lua_State *L)
{
    lua_pushinteger(L, rng_int((int)luaL_checkinteger(L, 1), (int)luaL_checkinteger(L, 2)));
    return 1;
}

/* math.random, but from the engine's seeded generator so a seed replays a game exactly. */
static int l_mrandom(lua_State *L)
{
    int n = lua_gettop(L);
    if (n == 0)
        lua_pushnumber(L, rng_f());
    else if (n == 1)
        lua_pushinteger(L, rng_int(1, (int)luaL_checkinteger(L, 1)));
    else
        lua_pushinteger(L, rng_int((int)luaL_checkinteger(L, 1), (int)luaL_checkinteger(L, 2)));
    return 1;
}

/* ------------------------------------------------------------------ gfx */

static int l_clear(lua_State *L)
{
    gfx_clear(api_color(L, 1));
    return 0;
}
static int l_pixel(lua_State *L)
{
    gfx_pixel((int)num(L, 1), (int)num(L, 2), api_color(L, 3));
    return 0;
}
static int l_rect(lua_State *L)
{
    gfx_rect((int)floorf(num(L, 1)), (int)floorf(num(L, 2)), (int)roundf(num(L, 3)), (int)roundf(num(L, 4)),
             api_color(L, 5));
    return 0;
}
static int l_frame(lua_State *L)
{
    gfx_frame_rect((int)num(L, 1), (int)num(L, 2), (int)num(L, 3), (int)num(L, 4), (int)num(L, 5), api_color(L, 6));
    return 0;
}
static int l_vgrad(lua_State *L)
{
    gfx_vgrad((int)num(L, 1), (int)num(L, 2), (int)num(L, 3), (int)num(L, 4), api_color(L, 5), api_color(L, 6));
    return 0;
}
static int l_hgrad(lua_State *L)
{
    gfx_hgrad((int)num(L, 1), (int)num(L, 2), (int)num(L, 3), (int)num(L, 4), api_color(L, 5), api_color(L, 6));
    return 0;
}
static int l_circle(lua_State *L)
{
    gfx_circle(num(L, 1), num(L, 2), num(L, 3), api_color(L, 4));
    return 0;
}
static int l_ellipse(lua_State *L)
{
    gfx_ellipse(num(L, 1), num(L, 2), num(L, 3), num(L, 4), api_color(L, 5));
    return 0;
}
static int l_ring(lua_State *L)
{
    gfx_ring(num(L, 1), num(L, 2), num(L, 3), num(L, 4), api_color(L, 5));
    return 0;
}
static int l_rrect(lua_State *L)
{
    gfx_rrect(num(L, 1), num(L, 2), num(L, 3), num(L, 4), num(L, 5), api_color(L, 6));
    return 0;
}
static int l_tri(lua_State *L)
{
    gfx_tri(num(L, 1), num(L, 2), num(L, 3), num(L, 4), num(L, 5), num(L, 6), api_color(L, 7));
    return 0;
}
static int read_points(lua_State *L, int i, float *xy, int max)
{
    int n;
    luaL_checktype(L, i, LUA_TTABLE);
    n = (int)lua_rawlen(L, i);
    if (n % 2 || n < 6 || n > max * 2)
        luaL_error(L, "a polygon wants 3 to %d points as {x1, y1, x2, y2, ...}", max);
    for (int k = 0; k < n; k++) {
        lua_rawgeti(L, i, k + 1);
        xy[k] = (float)luaL_checknumber(L, -1);
        lua_pop(L, 1);
    }
    return n / 2;
}
static int l_poly(lua_State *L)
{
    float xy[128];
    int n = read_points(L, 1, xy, 64);
    gfx_poly(xy, n, api_color(L, 2));
    return 0;
}
static int l_line(lua_State *L)
{
    gfx_line(num(L, 1), num(L, 2), num(L, 3), num(L, 4), num(L, 5), api_color(L, 6));
    return 0;
}
static int l_glow(lua_State *L)
{
    gfx_glow(num(L, 1), num(L, 2), num(L, 3), api_color(L, 4));
    return 0;
}
static int l_star(lua_State *L)
{
    gfx_star(num(L, 1), num(L, 2), num(L, 3), num(L, 4), api_color(L, 5));
    return 0;
}
static int l_heart(lua_State *L)
{
    gfx_heart(num(L, 1), num(L, 2), num(L, 3), api_color(L, 4));
    return 0;
}
static int l_circle_o(lua_State *L)
{
    gfx_circle_o(num(L, 1), num(L, 2), num(L, 3), api_color(L, 4), api_color(L, 5), optnum(L, 6, 2));
    return 0;
}
static int l_ellipse_o(lua_State *L)
{
    gfx_ellipse_o(num(L, 1), num(L, 2), num(L, 3), num(L, 4), api_color(L, 5), api_color(L, 6), optnum(L, 7, 2));
    return 0;
}
static int l_rrect_o(lua_State *L)
{
    gfx_rrect_o(num(L, 1), num(L, 2), num(L, 3), num(L, 4), num(L, 5), api_color(L, 6), api_color(L, 7),
                optnum(L, 8, 2));
    return 0;
}
static int l_dim(lua_State *L)
{
    gfx_dim(num(L, 1));
    return 0;
}
static int l_shake(lua_State *L)
{
    gfx_shake(num(L, 1));
    return 0;
}
static int l_flash(lua_State *L)
{
    gfx_flash(api_color(L, 1), (int)luaL_checkinteger(L, 2));
    return 0;
}
static int l_offset(lua_State *L)
{
    gfx_offset((int)optnum(L, 1, 0), (int)optnum(L, 2, 0));
    return 0;
}
static int l_clip(lua_State *L)
{
    if (lua_isnoneornil(L, 1))
        gfx_noclip();
    else
        gfx_clip((int)num(L, 1), (int)num(L, 2), (int)num(L, 3), (int)num(L, 4));
    return 0;
}

/* Text: gfx.text(str, x, y, size, color, align, outline, font). align "left" "center" "right". */
static int align_of(lua_State *L, int i)
{
    const char *a = luaL_optstring(L, i, "left");
    return !strcmp(a, "center") ? 1 : !strcmp(a, "right") ? 2 : 0;
}
/* gfx.text(str, x, y, size, color, align, outline, font), or gfx.text(str, x, y, {size =,
 * color =, align =, outline =, font =}). Returns the width drawn. */
static int l_text(lua_State *L)
{
    int size = 16, font = 0, al = 0;
    gcol c = 0xffffffffu, ink = 0;
    const char *s;
    float x = num(L, 2), y = num(L, 3), w;
    lua_settop(L, 8);
    if (lua_istable(L, 4)) {
        lua_getfield(L, 4, "size");
        size = (int)luaL_optinteger(L, -1, 16);
        lua_getfield(L, 4, "font");
        font = (int)luaL_optinteger(L, -1, 0);
        lua_getfield(L, 4, "color");
        c = opt_color(L, -1, 0xffffffffu);
        lua_getfield(L, 4, "outline");
        ink = opt_color(L, -1, 0);
        lua_getfield(L, 4, "align");
        al = align_of(L, -1);
        lua_pop(L, 5);
    } else {
        size = (int)luaL_optinteger(L, 4, 16);
        c = opt_color(L, 5, 0xffffffffu);
        al = align_of(L, 6);
        ink = opt_color(L, 7, 0);
        font = (int)luaL_optinteger(L, 8, 0);
    }
    s = luaL_tolstring(L, 1, NULL);
    w = gfx_ttf(font, size, x, y, c, ink, al, s);
    lua_pushnumber(L, w);
    return 1;
}
static int l_textw(lua_State *L)
{
    const char *s;
    lua_settop(L, 3);
    s = luaL_tolstring(L, 1, NULL);
    lua_pushnumber(L, gfx_ttf_width((int)luaL_optinteger(L, 3, 0), (int)luaL_optinteger(L, 2, 16), s));
    return 1;
}
static int l_lineh(lua_State *L)
{
    lua_pushinteger(L, gfx_ttf_line((int)luaL_optinteger(L, 2, 0), (int)luaL_optinteger(L, 1, 16)));
    return 1;
}
/* The 8x8 pixel font: gfx.pixtext(str, x, y, scale, color, align, outline). */
static int l_pixtext(lua_State *L)
{
    const char *s;
    lua_settop(L, 7);
    s = luaL_tolstring(L, 1, NULL);
    int scale = (int)luaL_optinteger(L, 4, 1), al = align_of(L, 6);
    gcol c = opt_color(L, 5, 0xffffffffu), ink = opt_color(L, 7, 0);
    int w = gfx_text_w(scale, "%s", s);
    int x = (int)num(L, 2) - (al == 1 ? w / 2 : al == 2 ? w : 0), y = (int)num(L, 3);
    if (COL_A(ink))
        gfx_text_o(x, y, scale, c, ink, "%s", s);
    else
        gfx_text(x, y, scale, c, "%s", s);
    lua_pushinteger(L, w);
    return 1;
}
static int l_pixtextw(lua_State *L)
{
    lua_settop(L, 2);
    lua_pushinteger(L, gfx_text_w((int)luaL_optinteger(L, 2, 1), "%s", luaL_tolstring(L, 1, NULL)));
    return 1;
}
static int l_font(lua_State *L)
{
    size_t n;
    const char *data = luaL_checklstring(L, 1, &n);
    int id = gfx_font_add((const unsigned char *)data, (int)n);
    if (id < 0)
        return luaL_error(L, "that font did not load (TrueType, under 8 fonts)");
    lua_pushinteger(L, id);
    return 1;
}

/* ------------------------------------------------------------------ toon */

static int l_toon(lua_State *L)
{
    float keep_t = toon_t;
    gcol keep_ink = toon_ink;
    luaL_checktype(L, 1, LUA_TFUNCTION);
    toon_t = optnum(L, 2, 2.f);
    toon_ink = opt_color(L, 3, HEX(0x3a2a44));
    for (int pass = 0; pass < 2; pass++) {
        toon_pass = pass;
        lua_pushvalue(L, 1);
        lua_call(L, 0, 0);
    }
    toon_pass = 1;
    toon_t = keep_t;
    toon_ink = keep_ink;
    return 0;
}
static int l_toon_fill(lua_State *L)
{
    lua_pushboolean(L, toon_pass == 1);
    return 1;
}
static int l_t_circle(lua_State *L)
{
    toon_circle(num(L, 1), num(L, 2), num(L, 3), api_color(L, 4));
    return 0;
}
static int l_t_ellipse(lua_State *L)
{
    toon_ellipse(num(L, 1), num(L, 2), num(L, 3), num(L, 4), api_color(L, 5));
    return 0;
}
static int l_t_rrect(lua_State *L)
{
    toon_rrect(num(L, 1), num(L, 2), num(L, 3), num(L, 4), num(L, 5), api_color(L, 6));
    return 0;
}
static int l_t_line(lua_State *L)
{
    toon_line(num(L, 1), num(L, 2), num(L, 3), num(L, 4), num(L, 5), api_color(L, 6));
    return 0;
}
static int l_t_tri(lua_State *L)
{
    toon_tri(num(L, 1), num(L, 2), num(L, 3), num(L, 4), num(L, 5), num(L, 6), api_color(L, 7));
    return 0;
}
static int l_t_poly(lua_State *L)
{
    float xy[128];
    int n = read_points(L, 1, xy, 64);
    toon_poly(xy, n, api_color(L, 2));
    return 0;
}

/* ------------------------------------------------------------------ images and layers */

/* One userdata type for all three: a PNG, pixel art, or a layer (a surface you paint into). */
typedef struct {
    gsprite *spr; /* PNG or art */
    gsurf *surf;  /* layer */
} img_ud;

#define IMG_MT "yard.image"

static img_ud *check_img(lua_State *L, int i) { return (img_ud *)luaL_checkudata(L, i, IMG_MT); }

static void img_dims(img_ud *u, const Uint32 **px, int *w, int *h)
{
    if (u->surf) {
        *px = u->surf->px;
        *w = u->surf->w;
        *h = u->surf->h;
    } else if (u->spr) {
        *px = u->spr->px;
        *w = u->spr->w;
        *h = u->spr->h;
    } else {
        *px = NULL;
        *w = *h = 0;
    }
}

static size_t img_bytes(img_ud *u)
{
    const Uint32 *px;
    int w, h;
    img_dims(u, &px, &w, &h);
    return (size_t)w * h * 4;
}

/* Images live outside Lua's heap, so the cart's memory cap counts them here. A cart that
 * makes a layer every frame gets its old ones collected before it is told no. */
static void img_room(lua_State *L, size_t want)
{
    if (api_img_bytes + want <= api_mem_cap())
        return;
    lua_gc(L, LUA_GCCOLLECT);
    if (api_img_bytes + want > api_mem_cap())
        luaL_error(L, "out of picture memory (%d KB of layers and images are alive)", (int)(api_img_bytes >> 10));
}

static void img_count(img_ud *u) { api_img_bytes += img_bytes(u); }

static int img_gc(lua_State *L)
{
    img_ud *u = check_img(L, 1);
    api_img_bytes -= img_bytes(u);
    gfx_sprite_free(u->spr);
    gfx_surf_free(u->surf);
    u->spr = NULL;
    u->surf = NULL;
    return 0;
}

static img_ud *new_img(lua_State *L)
{
    img_ud *u = (img_ud *)lua_newuserdatauv(L, sizeof *u, 0);
    u->spr = NULL;
    u->surf = NULL;
    luaL_setmetatable(L, IMG_MT);
    return u;
}

static int img_w(lua_State *L)
{
    const Uint32 *px;
    int w, h;
    img_dims(check_img(L, 1), &px, &w, &h);
    lua_pushinteger(L, w);
    return 1;
}
static int img_h(lua_State *L)
{
    const Uint32 *px;
    int w, h;
    img_dims(check_img(L, 1), &px, &w, &h);
    lua_pushinteger(L, h);
    return 1;
}

/* layer:paint(fn): clear it to see-through (or to a color), point drawing at it, call fn. */
static int img_paint(lua_State *L)
{
    img_ud *u = check_img(L, 1);
    if (!u->surf)
        return luaL_error(L, "only a layer can be painted into");
    luaL_checktype(L, 2, LUA_TFUNCTION);
    if (lua_isnoneornil(L, 3))
        gfx_surf_clear(u->surf);
    else {
        gcol c = api_color(L, 3) | 0xff000000u;
        for (int i = 0; i < u->surf->w * u->surf->h; i++)
            u->surf->px[i] = c;
    }
    gfx_target(u->surf);
    lua_pushvalue(L, 2);
    if (lua_pcall(L, 0, 0, 0) != LUA_OK) {
        gfx_target(NULL);
        return lua_error(L);
    }
    gfx_target(NULL);
    return 0;
}

static int l_layer(lua_State *L)
{
    int w = (int)luaL_checkinteger(L, 1), h = (int)luaL_checkinteger(L, 2);
    img_ud *u;
    if (w < 1 || h < 1 || w > 1024 || h > 1024)
        return luaL_error(L, "a layer is 1 to 1024 pixels on a side");
    img_room(L, (size_t)w * h * 4);
    u = new_img(L);
    u->surf = gfx_surf_new(w, h);
    if (!u->surf)
        return luaL_error(L, "out of memory for a %dx%d layer", w, h);
    gfx_surf_clear(u->surf);
    img_count(u);
    return 1;
}


static int path_ok(const char *name)
{
    if (!name[0] || name[0] == '/' || strstr(name, ".."))
        return 0;
    for (const char *p = name; *p; p++)
        if (!((*p >= 'a' && *p <= 'z') || (*p >= 'A' && *p <= 'Z') || (*p >= '0' && *p <= '9') || *p == '_' ||
              *p == '-' || *p == '.' || *p == '/'))
            return 0;
    return 1;
}

static int l_image(lua_State *L)
{
    const char *name = luaL_checkstring(L, 1);
    img_ud *u;
    size_t n;
    unsigned char *file;
    int w, h;
    if (!path_ok(name))
        return luaL_error(L, "image '%s': a name inside the cart's folder, letters digits _ - . /", name);
    file = api_read(name, &n);
    if (!file)
        return luaL_error(L, "image '%s': no such file in the cart", name);
    if (!gfx_image_size(file, (int)n, &w, &h)) {
        free(file);
        return luaL_error(L, "image '%s' is not a PNG", name);
    }
    if (w > 2048 || h > 2048) {
        free(file);
        return luaL_error(L, "image '%s' is %dx%d; 2048 a side at most", name, w, h);
    }
    img_room(L, (size_t)w * h * 4);
    u = new_img(L);
    u->spr = gfx_image_mem(file, (int)n);
    free(file);
    if (!u->spr)
        return luaL_error(L, "image '%s' did not load (PNG only)", name);
    img_count(u);
    return 1;
}

/* gfx.art({"..kk..", ...}, {k = 0x3a2a44, ...}): pixel art from strings. */
static int l_art(lua_State *L)
{
    const char *rows[64];
    char keys[64];
    gcol pal[64];
    int nrows, nk = 0;
    img_ud *u;
    luaL_checktype(L, 1, LUA_TTABLE);
    luaL_checktype(L, 2, LUA_TTABLE);
    nrows = (int)lua_rawlen(L, 1);
    if (nrows < 1 || nrows > 64)
        return luaL_error(L, "art wants 1 to 64 rows");
    for (int i = 0; i < nrows; i++) {
        lua_rawgeti(L, 1, i + 1);
        rows[i] = luaL_checkstring(L, -1);
        lua_pop(L, 1); /* the string stays alive in the table */
    }
    lua_pushnil(L);
    while (lua_next(L, 2) && nk < 63) {
        const char *k = luaL_checkstring(L, -2);
        keys[nk] = k[0];
        pal[nk] = api_color(L, -1);
        nk++;
        lua_pop(L, 1);
    }
    keys[nk] = 0;
    u = new_img(L);
    u->spr = gfx_sprite_make(rows, nrows, keys, pal);
    if (!u->spr)
        return luaL_error(L, "art did not build (rows up to 64 wide)");
    img_count(u);
    return 1;
}

/* gfx.draw(img, x, y, [opts]): opts.scale (or sx, sy), rot, ox, oy (0..1 of the part), flip,
 * alpha, tint, quad = {sx, sy, sw, sh}. */
static int l_draw(lua_State *L)
{
    img_ud *u = check_img(L, 1);
    const Uint32 *px;
    int w, h, qx = 0, qy = 0, qw, qh, alpha = 255;
    float kx = 1, ky = 1, rot = 0, ox = 0, oy = 0;
    gcol tint = 0;
    img_dims(u, &px, &w, &h);
    qw = w;
    qh = h;
    if (lua_istable(L, 4)) {
        lua_getfield(L, 4, "quad");
        if (lua_istable(L, -1)) {
            lua_rawgeti(L, -1, 1);
            qx = (int)lua_tointeger(L, -1);
            lua_rawgeti(L, -2, 2);
            qy = (int)lua_tointeger(L, -1);
            lua_rawgeti(L, -3, 3);
            qw = (int)lua_tointeger(L, -1);
            lua_rawgeti(L, -4, 4);
            qh = (int)lua_tointeger(L, -1);
            lua_pop(L, 4);
        }
        lua_pop(L, 1);
        lua_getfield(L, 4, "scale");
        if (lua_isnumber(L, -1))
            kx = ky = (float)lua_tonumber(L, -1);
        lua_pop(L, 1);
        lua_getfield(L, 4, "sx");
        if (lua_isnumber(L, -1))
            kx = (float)lua_tonumber(L, -1);
        lua_pop(L, 1);
        lua_getfield(L, 4, "sy");
        if (lua_isnumber(L, -1))
            ky = (float)lua_tonumber(L, -1);
        lua_pop(L, 1);
        lua_getfield(L, 4, "rot");
        rot = (float)luaL_optnumber(L, -1, 0);
        lua_pop(L, 1);
        lua_getfield(L, 4, "ox");
        ox = (float)luaL_optnumber(L, -1, 0) * qw;
        lua_pop(L, 1);
        lua_getfield(L, 4, "oy");
        oy = (float)luaL_optnumber(L, -1, 0) * qh;
        lua_pop(L, 1);
        lua_getfield(L, 4, "flip");
        if (lua_toboolean(L, -1))
            kx = -kx;
        lua_pop(L, 1);
        lua_getfield(L, 4, "alpha");
        alpha = (int)luaL_optinteger(L, -1, 255);
        lua_pop(L, 1);
        lua_getfield(L, 4, "tint");
        if (!lua_isnil(L, -1))
            tint = api_color(L, -1);
        lua_pop(L, 1);
    }
    if (kx < 0) {
        /* A flip mirrors around the origin point: keep the picture where it was asked. */
        ox = qw - ox;
    }
    gfx_image_draw(px, w, h, qx, qy, qw, qh, num(L, 2), num(L, 3), kx, ky, rot, ox, oy, alpha, tint);
    return 0;
}

/* Copy a layer onto the target as it is: blit is opaque, blit_key skips untouched pixels. */
static int l_blit(lua_State *L)
{
    img_ud *u = check_img(L, 1);
    if (!u->surf)
        return luaL_error(L, "blit takes a layer; use gfx.draw for images");
    gfx_blit(u->surf, (int)num(L, 2), (int)num(L, 3));
    return 0;
}
static int l_blit_key(lua_State *L)
{
    img_ud *u = check_img(L, 1);
    if (!u->surf)
        return luaL_error(L, "blit_key takes a layer");
    gfx_blit_key(u->surf, (int)num(L, 2), (int)num(L, 3));
    return 0;
}

/* ------------------------------------------------------------------ light */

static int l_light_begin(lua_State *L)
{
    gfx_light_begin((int)optnum(L, 1, 0), (int)optnum(L, 2, 0), (int)optnum(L, 3, (float)gfx_screen.w),
                    (int)optnum(L, 4, (float)gfx_screen.h), optnum(L, 5, 0.1f));
    return 0;
}
static int l_light_add(lua_State *L)
{
    gfx_light_add(num(L, 1), num(L, 2), num(L, 3), optnum(L, 4, 1));
    return 0;
}
static int l_light_fill(lua_State *L)
{
    gfx_light_fill(num(L, 1));
    return 0;
}
static int l_light_apply(lua_State *L)
{
    gfx_light_apply(opt_color(L, 1, 0xff00000eu));
    return 0;
}
static int l_iris(lua_State *L)
{
    gfx_iris(num(L, 1), num(L, 2), num(L, 3), opt_color(L, 4, 0xff000000u));
    return 0;
}

/* ------------------------------------------------------------------ input */

static int l_down(lua_State *L)
{
    lua_pushboolean(L, cab_down(0, button_of(L, 1)));
    return 1;
}
static int l_pressed(lua_State *L)
{
    lua_pushboolean(L, cab_pressed(0, button_of(L, 1)));
    return 1;
}
static int l_released(lua_State *L)
{
    int b = button_of(L, 1);
    lua_pushboolean(L, !cab_down(0, b) && cab_was_down(0, b));
    return 1;
}
/* The verb: any of the three right-hand buttons, as the walk-up band asks. */
static int l_action(lua_State *L)
{
    lua_pushboolean(L, cab_pressed(0, CAB_LOW) || cab_pressed(0, CAB_TL) || cab_pressed(0, CAB_TR));
    return 1;
}
static int l_action_down(lua_State *L)
{
    lua_pushboolean(L, cab_down(0, CAB_LOW) || cab_down(0, CAB_TL) || cab_down(0, CAB_TR));
    return 1;
}
static int l_dir(lua_State *L)
{
    lua_pushinteger(L, cab_down(0, CAB_RIGHT) - cab_down(0, CAB_LEFT));
    lua_pushinteger(L, cab_down(0, CAB_DOWN) - cab_down(0, CAB_UP));
    return 2;
}
static int l_any(lua_State *L)
{
    lua_pushboolean(L, cab_human_any());
    return 1;
}
static int l_quitting(lua_State *L)
{
    lua_pushnumber(L, cab_quit_progress());
    return 1;
}
static int l_bot(lua_State *L)
{
    cab_bot(button_of(L, 1), lua_isnoneornil(L, 2) ? 1 : lua_toboolean(L, 2));
    return 0;
}
static int l_bot_clear(lua_State *L)
{
    (void)L;
    cab_bot_clear();
    return 0;
}

/* ------------------------------------------------------------------ sound */

static int wave_of(lua_State *L, int i)
{
    const char *w = luaL_optstring(L, i, "tri");
    if (!strcmp(w, "sine"))
        return W_SINE;
    if (!strcmp(w, "tri"))
        return W_TRI;
    if (!strcmp(w, "square"))
        return W_SQUARE;
    if (!strcmp(w, "saw"))
        return W_SAW;
    if (!strcmp(w, "noise"))
        return W_NOISE;
    return luaL_error(L, "no wave named '%s' (sine tri square saw noise)", w);
}

static int l_tone(lua_State *L)
{
    sfx_tone(wave_of(L, 1), num(L, 2), optnum(L, 3, 0.15f), optnum(L, 4, 0.3f));
    return 0;
}
static int l_note(lua_State *L)
{
    sfx_note(wave_of(L, 1), (int)luaL_checkinteger(L, 2), optnum(L, 3, 0.2f), optnum(L, 4, 0.3f));
    return 0;
}
static int l_slide(lua_State *L)
{
    sfx_slide(wave_of(L, 1), num(L, 2), num(L, 3), optnum(L, 4, 0.2f), optnum(L, 5, 0.3f));
    return 0;
}
static int l_noise(lua_State *L)
{
    sfx_noise(optnum(L, 1, 0.1f), optnum(L, 2, 0.2f), optnum(L, 3, 8000));
    return 0;
}
static int l_arp(lua_State *L)
{
    int m[8], n;
    luaL_checktype(L, 2, LUA_TTABLE);
    n = (int)lua_rawlen(L, 2);
    if (n > 8)
        n = 8;
    for (int i = 0; i < n; i++) {
        lua_rawgeti(L, 2, i + 1);
        m[i] = (int)luaL_checkinteger(L, -1);
        lua_pop(L, 1);
    }
    sfx_arp(wave_of(L, 1), m, n, optnum(L, 3, 0.08f), optnum(L, 4, 0.3f));
    return 0;
}
static float field_num(lua_State *L, int t, const char *k, float d)
{
    float v;
    lua_getfield(L, t, k);
    v = (float)luaL_optnumber(L, -1, d);
    lua_pop(L, 1);
    return v;
}
static int l_play(lua_State *L)
{
    sfx_t s;
    luaL_checktype(L, 1, LUA_TTABLE);
    memset(&s, 0, sizeof s);
    lua_getfield(L, 1, "wave");
    s.wave = wave_of(L, -1);
    lua_pop(L, 1);
    s.hz = field_num(L, 1, "hz", 440);
    s.hz_end = field_num(L, 1, "hz_end", 0);
    s.dur = field_num(L, 1, "dur", 0.2f);
    s.vol = field_num(L, 1, "vol", 0.3f);
    s.attack = field_num(L, 1, "attack", 0.004f);
    s.release = field_num(L, 1, "release", s.dur * 0.6f);
    s.duty = field_num(L, 1, "duty", 0.5f);
    s.vib_hz = field_num(L, 1, "vib_hz", 0);
    s.vib_depth = field_num(L, 1, "vib_depth", 0);
    s.pan = field_num(L, 1, "pan", 0);
    sfx_play(&s);
    return 0;
}
static int l_master(lua_State *L)
{
    sfx_master(num(L, 1));
    return 0;
}
static int l_limit(lua_State *L)
{
    sfx_limit((int)luaL_checkinteger(L, 1));
    return 0;
}

/* music.play{bpm = 120, steps = 4, {"C5 . E5 .", wave = "tri", vol = 0.1, ...}, ...}
 * The song is copied: two slots, so the audio thread never reads one being rewritten. */
static sfx_song song_slot[2];
static char song_text[2][6][1024];
static int song_next;

static int l_music_play(lua_State *L)
{
    sfx_song *s;
    int k, n;
    if (lua_isnoneornil(L, 1)) {
        music_stop();
        return 0;
    }
    luaL_checktype(L, 1, LUA_TTABLE);
    k = song_next;
    song_next ^= 1;
    s = &song_slot[k];
    memset(s, 0, sizeof *s);
    s->bpm = field_num(L, 1, "bpm", 120);
    s->steps_per_beat = (int)field_num(L, 1, "steps", 4);
    n = (int)lua_rawlen(L, 1);
    if (n > 6)
        n = 6;
    for (int t = 0; t < n; t++) {
        sfx_track *tr = &s->tr[t];
        lua_rawgeti(L, 1, t + 1);
        luaL_checktype(L, -1, LUA_TTABLE);
        lua_rawgeti(L, -1, 1);
        snprintf(song_text[k][t], sizeof song_text[k][t], "%s", luaL_checkstring(L, -1));
        lua_pop(L, 1);
        tr->notes = song_text[k][t];
        lua_getfield(L, -1, "wave");
        tr->wave = wave_of(L, -1);
        lua_pop(L, 1);
        tr->vol = field_num(L, -1, "vol", 0.1f);
        tr->release = field_num(L, -1, "release", 0.1f);
        tr->attack = field_num(L, -1, "attack", 0.005f);
        tr->transpose = (int)field_num(L, -1, "transpose", 0);
        tr->duty = field_num(L, -1, "duty", 0.5f);
        tr->pan = field_num(L, -1, "pan", 0);
        lua_pop(L, 1);
    }
    s->ntracks = n;
    music_play(s);
    return 0;
}
static int l_music_stop(lua_State *L)
{
    (void)L;
    music_stop();
    return 0;
}
static int l_music_volume(lua_State *L)
{
    music_volume(num(L, 1));
    return 0;
}
static int l_music_tempo(lua_State *L)
{
    music_tempo(num(L, 1));
    return 0;
}
static int l_music_step(lua_State *L)
{
    lua_pushinteger(L, music_step());
    return 1;
}

/* ------------------------------------------------------------------ particles */

static int kind_of(lua_State *L, int i)
{
    const char *k = luaL_optstring(L, i, "dot");
    static const char *names[] = {"dot", "glow", "star", "heart", "square", "ring", "text"};
    for (int n = 0; n < 7; n++)
        if (!strcmp(k, names[n]))
            return n;
    return luaL_error(L, "no particle kind '%s' (dot glow star heart square ring)", k);
}
static int l_p_spawn(lua_State *L)
{
    gpart *p = part_spawn(num(L, 1), num(L, 2), num(L, 3), num(L, 4), (int)luaL_checkinteger(L, 5), num(L, 6),
                          api_color(L, 7), kind_of(L, 8));
    p->grav = optnum(L, 9, 0);
    p->drag = optnum(L, 10, 0.98f);
    p->spin = optnum(L, 11, 0);
    return 0;
}
static int l_p_burst(lua_State *L)
{
    part_burst(num(L, 1), num(L, 2), (int)luaL_checkinteger(L, 3), num(L, 4), (int)luaL_checkinteger(L, 5), num(L, 6),
               api_color(L, 7), kind_of(L, 8));
    return 0;
}
static int l_p_text(lua_State *L)
{
    part_text(num(L, 1), num(L, 2), api_color(L, 3), luaL_checkstring(L, 4));
    return 0;
}
int api_particles_drawn;
static int l_p_draw(lua_State *L)
{
    (void)L;
    part_draw();
    api_particles_drawn = 1;
    return 0;
}
static int l_p_clear(lua_State *L)
{
    (void)L;
    part_clear();
    return 0;
}
static int l_p_count(lua_State *L)
{
    lua_pushinteger(L, part_count());
    return 1;
}

/* ------------------------------------------------------------------ registration */

static void reg(lua_State *L, const char *name, const luaL_Reg *fns)
{
    lua_newtable(L);
    luaL_setfuncs(L, fns, 0);
    lua_setglobal(L, name);
}

/* toon(fn, t, ink) is a call on the toon table: toon.circle and friends live inside it. */
static int l_toon_call(lua_State *L)
{
    lua_remove(L, 1);
    return l_toon(L);
}

void api_open(lua_State *L)
{
    static const luaL_Reg gfx_fns[] = {
        {"clear", l_clear},     {"pixel", l_pixel},       {"rect", l_rect},         {"frame", l_frame},
        {"vgrad", l_vgrad},     {"hgrad", l_hgrad},       {"circle", l_circle},     {"ellipse", l_ellipse},
        {"ring", l_ring},       {"rrect", l_rrect},       {"tri", l_tri},           {"poly", l_poly},
        {"line", l_line},       {"glow", l_glow},         {"star", l_star},         {"heart", l_heart},
        {"circle_o", l_circle_o}, {"ellipse_o", l_ellipse_o}, {"rrect_o", l_rrect_o}, {"dim", l_dim},
        {"shake", l_shake},     {"flash", l_flash},       {"offset", l_offset},     {"clip", l_clip},
        {"text", l_text},       {"textw", l_textw},       {"lineh", l_lineh},       {"pixtext", l_pixtext},
        {"pixtextw", l_pixtextw}, {"font", l_font},       {"layer", l_layer},
        {"image", l_image},     {"art", l_art},           {"draw", l_draw},         {"blit", l_blit},
        {"blit_key", l_blit_key}, {"iris", l_iris}, {NULL, NULL}};
    static const luaL_Reg light_fns[] = {{"begin", l_light_begin}, {"add", l_light_add}, {"fill", l_light_fill},
                                         {"apply", l_light_apply}, {NULL, NULL}};
    static const luaL_Reg toon_fns[] = {{"fill", l_toon_fill}, {"circle", l_t_circle}, {"ellipse", l_t_ellipse},
                                        {"rrect", l_t_rrect},  {"line", l_t_line},     {"tri", l_t_tri},
                                        {"poly", l_t_poly},    {NULL, NULL}};
    static const luaL_Reg input_fns[] = {{"down", l_down},         {"pressed", l_pressed}, {"released", l_released},
                                         {"action", l_action},     {"action_down", l_action_down}, {"dir", l_dir},
                                         {"any", l_any},           {"quitting", l_quitting}, {"bot", l_bot},
                                         {"bot_clear", l_bot_clear}, {NULL, NULL}};
    static const luaL_Reg sfx_fns[] = {{"tone", l_tone}, {"note", l_note},     {"slide", l_slide},   {"noise", l_noise},
                                       {"arp", l_arp},   {"play", l_play},     {"master", l_master}, {"limit", l_limit},
                                       {NULL, NULL}};
    static const luaL_Reg music_fns[] = {{"play", l_music_play},     {"stop", l_music_stop}, {"volume", l_music_volume},
                                         {"tempo", l_music_tempo},   {"step", l_music_step}, {NULL, NULL}};
    static const luaL_Reg part_fns[] = {{"spawn", l_p_spawn}, {"burst", l_p_burst}, {"text", l_p_text},
                                        {"draw", l_p_draw},   {"clear", l_p_clear}, {"count", l_p_count},
                                        {NULL, NULL}};
    static const luaL_Reg img_methods[] = {{"w", img_w}, {"h", img_h}, {"paint", img_paint}, {NULL, NULL}};
    luaL_newmetatable(L, IMG_MT);
    lua_pushcfunction(L, img_gc);
    lua_setfield(L, -2, "__gc");
    luaL_newlib(L, img_methods);
    lua_setfield(L, -2, "__index");
    lua_pop(L, 1);
    reg(L, "gfx", gfx_fns);
    reg(L, "toon", toon_fns);
    lua_getglobal(L, "toon");
    lua_newtable(L);
    lua_pushcfunction(L, l_toon_call);
    lua_setfield(L, -2, "__call");
    lua_setmetatable(L, -2);
    lua_pop(L, 1);
    reg(L, "input", input_fns);
    reg(L, "sfx", sfx_fns);
    reg(L, "music", music_fns);
    reg(L, "particles", part_fns);
    reg(L, "light", light_fns);
    lua_register(L, "rgb", l_rgb);
    lua_register(L, "rgba", l_rgba);
    lua_register(L, "hex", l_hex);
    lua_register(L, "alpha", l_alpha);
    lua_register(L, "mix", l_mix);
    lua_register(L, "shade", l_shade);
    lua_register(L, "hsv", l_hsv);
    lua_register(L, "rnd", l_rnd);
    lua_register(L, "rndi", l_rndi);
    lua_getglobal(L, "math");
    lua_pushcfunction(L, l_mrandom);
    lua_setfield(L, -2, "random");
    lua_pushnil(L);
    lua_setfield(L, -2, "randomseed");
    lua_pop(L, 1);
}
