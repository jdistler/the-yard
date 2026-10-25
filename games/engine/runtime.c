/* yard: the one program on the cabinet. It runs carts, small games written in Lua.
 *
 *   yard                 the menu (the cart marked system = true, normally carts/yard)
 *   yard <cart> [-fast]  one cart, then exit
 *   yard --list          print the carts it can see
 *   yard --check <cart>  load a cart, run its first frames headless, report (used by tools/yard)
 *
 * A cart is a folder: info.lua (the label on the box) and main.lua (the game). Carts see the
 * API in api.c and the library in engine/lib, and nothing else: no files, no processes, no
 * modules beyond their own folder. A cart that errors, loops forever, or eats memory gets a
 * gentle screen and goes back to the menu. It cannot touch the cabinet.
 *
 * The menu opens a cart by running this program again as a child, so a cart that falls over
 * takes nothing with it, and a test script's title= sections work per cart.
 */
#include <dirent.h>
#include <stdint.h>
#include <errno.h>
#include <fcntl.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#include "api.h"
#include "gfx.h"
#include "lib_lua.h"
#include "lua/lauxlib.h"
#include "lua/lualib.h"
#include "sfx.h"

#define CART_MAX 32
#define EXIT_STUMBLED 3

typedef struct {
    char id[33];
    char dir[512];
    char title[33];
    char native[33];
    int order, system, w, h;
    lua_State *L; /* the info state, kept by the menu for icons and stats */
} cart_t;

static cart_t carts[CART_MAX];
static int ncarts;
static char self_exe[512], self_dir[512];

const char *api_cart_dir = ".";
size_t api_img_bytes;
static size_t mem_used, mem_cap = 32u << 20;
size_t api_mem_cap(void) { return mem_cap > mem_used ? mem_cap - mem_used : 0; }

/* ------------------------------------------------------------------ the sandboxed state */

static long long steps_left;
static const char *phase = "start";

static void *cart_alloc(void *ud, void *ptr, size_t osize, size_t nsize)
{
    (void)ud;
    if (!ptr)
        osize = 0;
    if (nsize == 0) {
        free(ptr);
        mem_used -= osize;
        return NULL;
    }
    if (nsize > osize && mem_used + api_img_bytes + (nsize - osize) > mem_cap)
        return NULL; /* Lua turns this into "not enough memory" */
    ptr = realloc(ptr, nsize);
    if (ptr)
        mem_used += nsize - osize;
    return ptr;
}

/* Count VM instructions; a callback that runs far past a frame's worth is stuck. */
#define HOOK_EVERY 100000
static void watchdog(lua_State *L, lua_Debug *ar)
{
    (void)ar;
    steps_left -= HOOK_EVERY;
    if (steps_left < 0) {
        steps_left = 1LL << 40; /* let the error itself run */
        lua_pushfstring(L, "%s() ran far too long: is there a loop that never ends?", phase);
        lua_error(L);
    }
}

static void budget(const char *what, long long steps)
{
    phase = what;
    steps_left = steps;
}

static int l_log(lua_State *L)
{
    luaL_Buffer b;
    int n = lua_gettop(L);
    luaL_buffinit(L, &b);
    for (int i = 1; i <= n; i++) {
        if (i > 1)
            luaL_addchar(&b, ' ');
        luaL_tolstring(L, i, NULL);
        luaL_addvalue(&b);
    }
    luaL_pushresult(&b);
    cab_log("%s", lua_tostring(L, -1));
    return 0;
}

static int name_ok(const char *s, int max)
{
    int n = 0;
    for (; s[n]; n++)
        if (!((s[n] >= 'a' && s[n] <= 'z') || (s[n] >= '0' && s[n] <= '9') || s[n] == '_' || s[n] == '-'))
            return 0;
    return n > 0 && n <= max;
}

static int load_cart_file(lua_State *L, const char *dir, const char *file);

/* import("name"): run <cart>/name.lua once and hand back what it returns. */
static int l_import(lua_State *L)
{
    const char *name = luaL_checkstring(L, 1);
    char path[600];
    if (!name_ok(name, 32))
        return luaL_error(L, "import '%s': a file name in the cart's folder, without .lua", name);
    lua_getfield(L, LUA_REGISTRYINDEX, "yard.imported");
    lua_getfield(L, -1, name);
    if (!lua_isnil(L, -1))
        return 1;
    lua_pop(L, 1);
    snprintf(path, sizeof path, "%s.lua", name);
    if (load_cart_file(L, api_cart_dir, path) != LUA_OK)
        return lua_error(L);
    lua_call(L, 0, 1);
    if (lua_isnil(L, -1)) {
        lua_pop(L, 1);
        lua_pushboolean(L, 1);
    }
    lua_pushvalue(L, -1);
    lua_setfield(L, -3, name);
    return 1;
}

/* A chunk of text from inside the cart: data files (levels, words) that are not code. */
/* ------------------------------------------------------------------ cart files: folders and the pack
 *
 * A cart lives either in a folder (the PC, a card) or inside yard.pak beside this program
 * (the cabinet). yard.pak is one file of fixed size, so an update rewrites the same disk
 * blocks it always had (tools/yard deploy). Layout, little-endian:
 *   "YARDPAK1", u32 entries, u32 used bytes, then per entry: u16 name length, name
 *   ("keep/main.lua"), u32 length, u32 crc32, data. Zero padding after "used bytes".
 * Every entry's crc32 is checked when the pack is opened; a cart with a bad entry is skipped. */
#define PAK_MAX 1024
static unsigned char *pak;
static struct {
    char name[72];
    const unsigned char *data;
    uint32_t len;
} pak_files[PAK_MAX];
static int pak_n;

static uint32_t crc32_of(const unsigned char *p, size_t n)
{
    uint32_t c = 0xffffffffu;
    for (size_t i = 0; i < n; i++) {
        c ^= p[i];
        for (int k = 0; k < 8; k++)
            c = (c >> 1) ^ (0xedb88320u & (0u - (c & 1)));
    }
    return ~c;
}

static uint32_t rd32(const unsigned char *p) { return p[0] | p[1] << 8 | p[2] << 16 | (uint32_t)p[3] << 24; }

static char pak_bad[CART_MAX][33];
static int pak_nbad;

static void pak_open(const char *path)
{
    FILE *f = fopen(path, "rb");
    unsigned char head[16];
    uint32_t count, used;
    size_t o = 16;
    if (!f)
        return;
    if (fread(head, 1, 16, f) != 16 || memcmp(head, "YARDPAK1", 8)) {
        cab_log("yard: %s is not a cart pack", path);
        fclose(f);
        return;
    }
    count = rd32(head + 8);
    used = rd32(head + 12);
    if (used < 16 || used > (64u << 20) || count > PAK_MAX || !(pak = malloc(used))) {
        cab_log("yard: %s: a broken header", path);
        fclose(f);
        return;
    }
    memcpy(pak, head, 16);
    if (fread(pak + 16, 1, used - 16, f) != used - 16) {
        cab_log("yard: %s is shorter than its header says", path);
        fclose(f);
        free(pak);
        pak = NULL;
        return;
    }
    fclose(f);
    for (uint32_t i = 0; i < count; i++) {
        unsigned nl;
        uint32_t len, crc;
        if (o + 2 > used)
            break;
        nl = pak[o] | pak[o + 1] << 8;
        if (nl == 0 || nl >= sizeof pak_files[0].name || o + 2 + nl + 8 > used)
            break;
        memcpy(pak_files[pak_n].name, pak + o + 2, nl);
        pak_files[pak_n].name[nl] = 0;
        o += 2 + nl;
        len = rd32(pak + o);
        crc = rd32(pak + o + 4);
        o += 8;
        if (len > used - o)
            break;
        pak_files[pak_n].data = pak + o;
        pak_files[pak_n].len = len;
        if (crc32_of(pak + o, len) != crc) {
            /* Remember the cart so the scan skips it whole. */
            char id[33];
            const char *slash = strchr(pak_files[pak_n].name, '/');
            snprintf(id, sizeof id, "%.*s", slash ? (int)(slash - pak_files[pak_n].name) : 32, pak_files[pak_n].name);
            cab_log("yard: %s: %s fails its checksum", path, pak_files[pak_n].name);
            if (pak_nbad < CART_MAX)
                snprintf(pak_bad[pak_nbad++], 33, "%s", id);
        } else
            pak_n++;
        o += len;
    }
}

static const char *pak_dir_id(const char *dir) { return strncmp(dir, "pak:", 4) ? NULL : dir + 4; }

/* The bytes of dir/name, malloc'd and NUL-terminated, or NULL. */
static unsigned char *cart_read(const char *dir, const char *name, size_t *len)
{
    const char *id = pak_dir_id(dir);
    unsigned char *buf;
    if (id) {
        char full[120];
        snprintf(full, sizeof full, "%s/%s", id, name);
        for (int i = 0; i < pak_n; i++)
            if (!strcmp(pak_files[i].name, full)) {
                buf = malloc(pak_files[i].len + 1);
                if (!buf)
                    return NULL;
                memcpy(buf, pak_files[i].data, pak_files[i].len);
                buf[pak_files[i].len] = 0;
                *len = pak_files[i].len;
                return buf;
            }
        return NULL;
    } else {
        char path[700];
        FILE *f;
        long n;
        snprintf(path, sizeof path, "%s/%s", dir, name);
        f = fopen(path, "rb");
        if (!f)
            return NULL;
        fseek(f, 0, SEEK_END);
        n = ftell(f);
        fseek(f, 0, SEEK_SET);
        if (n < 0 || n > (8L << 20) || !(buf = malloc((size_t)n + 1))) {
            fclose(f);
            return NULL;
        }
        if (fread(buf, 1, (size_t)n, f) != (size_t)n) {
            free(buf);
            fclose(f);
            return NULL;
        }
        fclose(f);
        buf[n] = 0;
        *len = (size_t)n;
        return buf;
    }
}

/* For api.c: a file of the running cart. */
unsigned char *api_read(const char *name, size_t *len) { return cart_read(api_cart_dir, name, len); }

static int cart_has(const char *dir, const char *name)
{
    size_t n;
    unsigned char *b = cart_read(dir, name, &n);
    free(b);
    return b != NULL;
}

/* readtext("words.txt"): a data file from inside the cart (levels, words): text, not code. */
static int l_readtext(lua_State *L)
{
    const char *name = luaL_checkstring(L, 1);
    size_t n;
    unsigned char *b;
    if (!name[0] || strstr(name, "..") || name[0] == '/' || strlen(name) > 64)
        return luaL_error(L, "readtext '%s': a file name in the cart's folder", name);
    b = cart_read(api_cart_dir, name, &n);
    if (!b)
        return luaL_error(L, "readtext '%s': no such file in the cart", name);
    lua_pushlstring(L, (const char *)b, n);
    free(b);
    return 1;
}

static const char *cart_id_of_dir(const char *dir)
{
    const char *s = strrchr(dir, '/');
    if (pak_dir_id(dir))
        return pak_dir_id(dir);
    return s ? s + 1 : dir;
}

/* Load a file of Lua text with a short name for messages: "keep/main.lua:12: ...". */
static int load_cart_file(lua_State *L, const char *dir, const char *file)
{
    char shown[96];
    size_t n;
    unsigned char *buf;
    int rc;
    snprintf(shown, sizeof shown, "@%.40s/%.40s", cart_id_of_dir(dir), file);
    buf = cart_read(dir, file, &n);
    if (!buf) {
        lua_pushfstring(L, "%s: missing", shown + 1);
        return LUA_ERRFILE;
    }
    rc = luaL_loadbufferx(L, (const char *)buf, n, shown, "t");
    free(buf);
    return rc;
}

static int panic(lua_State *L)
{
    cab_log("yard: lua panic: %s", lua_tostring(L, -1));
    return 0;
}

static lua_State *new_state(void)
{
    static const luaL_Reg libs[] = {{LUA_GNAME, luaopen_base},       {LUA_COLIBNAME, luaopen_coroutine},
                                    {LUA_TABLIBNAME, luaopen_table}, {LUA_STRLIBNAME, luaopen_string},
                                    {LUA_MATHLIBNAME, luaopen_math}, {LUA_UTF8LIBNAME, luaopen_utf8},
                                    {NULL, NULL}};
    static const char *banned[] = {"dofile", "loadfile", "load", "require", "collectgarbage", NULL};
    lua_State *L = lua_newstate(cart_alloc, NULL);
    if (!L)
        return NULL;
    lua_atpanic(L, panic);
    for (const luaL_Reg *l = libs; l->func; l++) {
        luaL_requiref(L, l->name, l->func, 1);
        lua_pop(L, 1);
    }
    for (int i = 0; banned[i]; i++) {
        lua_pushnil(L);
        lua_setglobal(L, banned[i]);
    }
    /* string.dump would hand out bytecode; nothing else in string reaches outside. */
    lua_getglobal(L, "string");
    lua_pushnil(L);
    lua_setfield(L, -2, "dump");
    lua_pop(L, 1);
    lua_newtable(L);
    lua_setfield(L, LUA_REGISTRYINDEX, "yard.imported");
    lua_register(L, "log", l_log);
    lua_register(L, "print", l_log);
    lua_register(L, "import", l_import);
    lua_register(L, "readtext", l_readtext);
    api_open(L);
    lua_sethook(L, watchdog, LUA_MASKCOUNT, HOOK_EVERY);
    return L;
}

/* ------------------------------------------------------------------ saves */

/* <name>.sav in the current directory (the cabinet's /data/Games): lines "key value",
 * value a whole number or a word. Unknown or broken lines are dropped on load. */
static const char *stock_names[] = {"PacMan", "PacManFast", "PacManPlus", "PacManPlusFast", "SuperPacMan",
                                    "PacandPal", "PacLand", "DigDug", "DigDugII", "Galaga", "Galaxian",
                                    "Mappy", "PacMania", "Rompers", "NS1", "NS86", "probe", NULL};

static int save_name_ok(const char *s)
{
    if (!name_ok(s, 32))
        return 0;
    for (int i = 0; stock_names[i]; i++)
        if (!strcasecmp(s, stock_names[i]))
            return 0;
    return 1;
}

static int word_ok(const char *s)
{
    int n = 0;
    for (; s[n]; n++)
        if (!((s[n] >= 'a' && s[n] <= 'z') || (s[n] >= 'A' && s[n] <= 'Z') || (s[n] >= '0' && s[n] <= '9') ||
              s[n] == '_' || s[n] == '-' || s[n] == '.'))
            return 0;
    return n > 0 && n <= 32;
}

/* Push a table {keys = {k1, k2, ...}, values = {k = v}} read from name.sav. */
static void save_read(lua_State *L, const char *name)
{
    char path[64], line[160], key[48], val[64];
    FILE *f;
    int n = 0;
    lua_newtable(L); /* values */
    lua_newtable(L); /* key order */
    if (!save_name_ok(name))
        return;
    snprintf(path, sizeof path, "%s.sav", name);
    f = fopen(path, "r");
    if (!f)
        return;
    while (fgets(line, sizeof line, f) && n < 256) {
        char extra[4];
        char *end;
        long long v;
        if (sscanf(line, "%47s %63s %3s", key, val, extra) != 2 || !name_ok(key, 32) || !word_ok(val))
            continue;
        lua_getfield(L, -2, key);
        if (lua_isnil(L, -1)) {
            lua_pushstring(L, key);
            lua_rawseti(L, -3, ++n);
        }
        lua_pop(L, 1);
        v = strtoll(val, &end, 10);
        if (!*end && (val[0] == '-' || (val[0] >= '0' && val[0] <= '9'))) {
            if (v < -1000000000LL || v > 1000000000LL)
                continue; /* an impossible number loads as missing */
            lua_pushinteger(L, (lua_Integer)v);
        } else
            lua_pushstring(L, val);
        lua_setfield(L, -3, key);
    }
    fclose(f);
}

static char save_file[33];

static int l_save_get(lua_State *L)
{
    const char *k = luaL_checkstring(L, 1);
    lua_getfield(L, LUA_REGISTRYINDEX, "yard.save");
    lua_getfield(L, -1, k);
    if (lua_isnil(L, -1)) {
        lua_settop(L, 2);
        return 1;
    }
    if (lua_type(L, 2) == LUA_TNUMBER && lua_type(L, -1) != LUA_TNUMBER) {
        lua_settop(L, 2); /* a word where a number belongs: the default */
        return 1;
    }
    return 1;
}

static int l_save_set(lua_State *L)
{
    const char *k = luaL_checkstring(L, 1);
    if (!name_ok(k, 32))
        return luaL_error(L, "save key '%s': lower-case letters, digits, _ and -", k);
    if (lua_isinteger(L, 2) || (lua_isnumber(L, 2) && lua_type(L, 2) == LUA_TNUMBER)) {
        lua_Number v = lua_tonumber(L, 2);
        if (v < -1e9 || v > 1e9)
            return luaL_error(L, "save %s: %f is out of range", k, v);
        lua_settop(L, 1);
        lua_pushinteger(L, (lua_Integer)floor(v));
    } else if (lua_isnil(L, 2)) {
        lua_settop(L, 2);
    } else {
        const char *w = luaL_checkstring(L, 2);
        if (!word_ok(w))
            return luaL_error(L, "save %s: '%s' is not one word (letters, digits, _ - .)", k, w);
        lua_settop(L, 2);
    }
    lua_getfield(L, LUA_REGISTRYINDEX, "yard.save");
    lua_getfield(L, LUA_REGISTRYINDEX, "yard.saveorder");
    lua_getfield(L, 3, k);
    if (lua_isnil(L, -1) && !lua_isnil(L, 2)) {
        lua_pushvalue(L, 1);
        lua_rawseti(L, 4, (lua_Integer)lua_rawlen(L, 4) + 1);
    }
    lua_pop(L, 1);
    lua_pushvalue(L, 2);
    lua_setfield(L, 3, k);
    return 0;
}

static void fsync_dir(void)
{
    int fd = open(".", O_RDONLY | O_DIRECTORY);
    if (fd >= 0) {
        fsync(fd);
        close(fd);
    }
}

/* Write the whole save at once: a temporary file, fsync, rename, fsync the folder. */
static int l_save_write(lua_State *L)
{
    char path[64], tmp[80];
    FILE *f;
    int n, ok;
    if (!save_file[0])
        return luaL_error(L, "this cart has no save name (info.lua save = \"...\")");
    snprintf(path, sizeof path, "%s.sav", save_file);
    snprintf(tmp, sizeof tmp, "%s.tmp", path);
    f = fopen(tmp, "w");
    if (!f) {
        lua_pushboolean(L, 0);
        return 1;
    }
    lua_getfield(L, LUA_REGISTRYINDEX, "yard.save");
    lua_getfield(L, LUA_REGISTRYINDEX, "yard.saveorder");
    n = (int)lua_rawlen(L, -1);
    for (int i = 1; i <= n; i++) {
        lua_rawgeti(L, -1, i);
        lua_getfield(L, -3, lua_tostring(L, -1));
        if (lua_isinteger(L, -1))
            fprintf(f, "%s %lld\n", lua_tostring(L, -2), (long long)lua_tointeger(L, -1));
        else if (lua_isstring(L, -1))
            fprintf(f, "%s %s\n", lua_tostring(L, -2), lua_tostring(L, -1));
        lua_pop(L, 2);
    }
    ok = fflush(f) == 0 && fsync(fileno(f)) == 0;
    ok = fclose(f) == 0 && ok;
    if (!ok || rename(tmp, path) != 0) {
        unlink(tmp);
        lua_pushboolean(L, 0);
        return 1;
    }
    fsync_dir();
    lua_pushboolean(L, 1);
    return 1;
}

/* save.all(): a copy of every key, for a cart that wants to walk them. */
static int l_save_all(lua_State *L)
{
    lua_newtable(L);
    lua_getfield(L, LUA_REGISTRYINDEX, "yard.save");
    lua_pushnil(L);
    while (lua_next(L, -2)) {
        lua_pushvalue(L, -2);
        lua_insert(L, -2);
        lua_settable(L, -5);
    }
    lua_pop(L, 1);
    return 1;
}

static void open_save(lua_State *L, const char *name)
{
    static const luaL_Reg fns[] = {
        {"get", l_save_get}, {"set", l_save_set}, {"write", l_save_write}, {"all", l_save_all}, {NULL, NULL}};
    snprintf(save_file, sizeof save_file, "%s", name && save_name_ok(name) ? name : "");
    save_read(L, save_file);
    lua_setfield(L, LUA_REGISTRYINDEX, "yard.saveorder");
    lua_setfield(L, LUA_REGISTRYINDEX, "yard.save");
    luaL_newlib(L, fns);
    lua_setglobal(L, "save");
}

/* ------------------------------------------------------------------ the card slot */

static int l_card_here(lua_State *L)
{
    lua_pushboolean(L, cab_ext_root() != NULL);
    return 1;
}
static int l_card_read(lua_State *L)
{
    char buf[4096];
    int n = cab_ext_read(luaL_checkstring(L, 1), buf, sizeof buf);
    if (n < 0)
        lua_pushnil(L);
    else
        lua_pushlstring(L, buf, (size_t)(n < (int)sizeof buf ? n : (int)sizeof buf - 1));
    return 1;
}
static int l_card_write(lua_State *L)
{
    size_t n;
    const char *s = luaL_checklstring(L, 2, &n);
    if (n > 4096)
        return luaL_error(L, "card files are at most 4096 bytes");
    lua_pushboolean(L, cab_ext_write(luaL_checkstring(L, 1), s, (int)n) == 0);
    return 1;
}

/* ------------------------------------------------------------------ finding carts */

static void find_self(void)
{
    ssize_t n = readlink("/proc/self/exe", self_exe, sizeof self_exe - 1);
    char *slash;
    if (n < 0)
        n = 0;
    self_exe[n] = 0;
    snprintf(self_dir, sizeof self_dir, "%s", self_exe);
    slash = strrchr(self_dir, '/');
    if (slash)
        *slash = 0;
    else
        snprintf(self_dir, sizeof self_dir, ".");
}

static int is_dir(const char *p)
{
    struct stat st;
    return stat(p, &st) == 0 && S_ISDIR(st.st_mode);
}

static void run_lib(lua_State *L);
static void open_game_table(lua_State *L, cart_t *c);

/* Read info.lua into its own state and keep the returned table as the global "info". The
 * label gets the library too (pal, plural, ...), so its icon can draw like the game. */
static int load_info(cart_t *c, char *err, size_t errn)
{
    char path[600];
    lua_State *L = new_state();
    if (!L) {
        snprintf(err, errn, "no memory");
        return -1;
    }
    api_cart_dir = c->dir;
    c->w = 240;
    c->h = 320;
    snprintf(c->title, sizeof c->title, "%s", c->id);
    open_game_table(L, c);
    run_lib(L);
    budget("info.lua", 20000000);
    (void)path;
    if (load_cart_file(L, c->dir, "info.lua") != LUA_OK || lua_pcall(L, 0, 1, 0) != LUA_OK) {
        snprintf(err, errn, "%s", lua_tostring(L, -1));
        lua_close(L);
        return -1;
    }
    if (!lua_istable(L, -1)) {
        snprintf(err, errn, "%s/info.lua must return a table", c->id);
        lua_close(L);
        return -1;
    }
    lua_pushvalue(L, -1);
    lua_setglobal(L, "info");
    lua_getfield(L, -1, "title");
    snprintf(c->title, sizeof c->title, "%s", lua_isstring(L, -1) ? lua_tostring(L, -1) : c->id);
    lua_pop(L, 1);
    lua_getfield(L, -1, "native");
    snprintf(c->native, sizeof c->native, "%s", lua_isstring(L, -1) ? lua_tostring(L, -1) : "");
    lua_pop(L, 1);
    lua_getfield(L, -1, "order");
    c->order = (int)luaL_optinteger(L, -1, 50);
    lua_pop(L, 1);
    lua_getfield(L, -1, "system");
    c->system = lua_toboolean(L, -1);
    lua_pop(L, 1);
    lua_getfield(L, -1, "size");
    c->w = 240;
    c->h = 320;
    if (lua_isstring(L, -1) && !strcmp(lua_tostring(L, -1), "large")) {
        c->w = 384;
        c->h = 512;
    }
    lua_pop(L, 2);
    c->L = L;
    return 0;
}

static void scan_dir(const char *where)
{
    char root[4096];
    DIR *d;
    if (!realpath(where, root))
        return;
    d = opendir(root);
    struct dirent *e;
    if (!d)
        return;
    while ((e = readdir(d)) && ncarts < CART_MAX) {
        cart_t *c = &carts[ncarts];
        char info[600], err[300];
        int dup = 0;
        if (!name_ok(e->d_name, 32))
            continue;
        for (int i = 0; i < ncarts; i++)
            dup |= !strcmp(carts[i].id, e->d_name);
        if (dup)
            continue; /* the first folder on the path wins */
        memset(c, 0, sizeof *c);
        snprintf(c->id, sizeof c->id, "%.32s", e->d_name);
        if (strlen(root) + strlen(e->d_name) + 2 > sizeof c->dir)
            continue;
        snprintf(c->dir, sizeof c->dir, "%s/%s", root, e->d_name);
        (void)info;
        if (!cart_has(c->dir, "info.lua"))
            continue;
        if (load_info(c, err, sizeof err) != 0) {
            cab_log("yard: skipping cart %s: %s", c->id, err);
            continue;
        }
        ncarts++;
    }
    closedir(d);
}

static void scan_pak(void)
{
    for (int i = 0; i < pak_n && ncarts < CART_MAX; i++) {
        char id[33], err[300];
        const char *slash = strchr(pak_files[i].name, '/');
        cart_t *c = &carts[ncarts];
        int skip = 0;
        if (!slash || strcmp(slash + 1, "info.lua"))
            continue;
        snprintf(id, sizeof id, "%.*s", (int)(slash - pak_files[i].name), pak_files[i].name);
        if (!name_ok(id, 32))
            continue;
        for (int k = 0; k < ncarts; k++)
            skip |= !strcmp(carts[k].id, id);
        for (int k = 0; k < pak_nbad; k++)
            skip |= !strcmp(pak_bad[k], id);
        if (skip)
            continue;
        memset(c, 0, sizeof *c);
        snprintf(c->id, sizeof c->id, "%s", id);
        snprintf(c->dir, sizeof c->dir, "pak:%s", id);
        if (load_info(c, err, sizeof err) != 0) {
            cab_log("yard: skipping cart %s: %s", c->id, err);
            continue;
        }
        ncarts++;
    }
}

static int by_order(const void *a, const void *b)
{
    const cart_t *x = a, *y = b;
    return x->order != y->order ? x->order - y->order : strcmp(x->id, y->id);
}

/* YARD_CARTS, then the cabinet's yard.d/carts beside this program, then the tree's games/carts
 * when running from games/out/pc, then a card's yard/carts. */
static void scan_carts(void)
{
    char p[600];
    const char *env = getenv("YARD_CARTS"), *ext;
    if (env && env[0])
        scan_dir(env);
    snprintf(p, sizeof p, "%s/yard.d/carts", self_dir);
    if (is_dir(p))
        scan_dir(p);
    env = getenv("YARD_PAK");
    snprintf(p, sizeof p, "%s/yard.pak", self_dir);
    pak_open(env && env[0] ? env : p);
    scan_pak();
    snprintf(p, sizeof p, "%s/../../carts", self_dir);
    if (is_dir(p))
        scan_dir(p);
    ext = cab_ext_root();
    if (ext) {
        snprintf(p, sizeof p, "%s/yard/carts", ext);
        if (is_dir(p))
            scan_dir(p);
    }
    qsort(carts, (size_t)ncarts, sizeof carts[0], by_order);
}

static cart_t *find_cart(const char *id)
{
    for (int i = 0; i < ncarts; i++)
        if (!strcmp(carts[i].id, id))
            return &carts[i];
    return NULL;
}

/* ------------------------------------------------------------------ running a cart */

static lua_State *G;     /* the running cart */
static cart_t *running;
static int want_quit, fast, frame_no;
static char err_text[2048];

static int l_quit(lua_State *L)
{
    (void)L;
    want_quit = 1;
    return 0;
}

static void open_game_table(lua_State *L, cart_t *c)
{
    char sel[64];
    lua_newtable(L);
    lua_pushstring(L, c->id);
    lua_setfield(L, -2, "id");
    lua_pushstring(L, c->title);
    lua_setfield(L, -2, "title");
    lua_pushinteger(L, c->w);
    lua_setfield(L, -2, "w");
    lua_pushinteger(L, c->h);
    lua_setfield(L, -2, "h");
    lua_pushboolean(L, fast);
    lua_setfield(L, -2, "fast");
    lua_pushboolean(L, getenv("CAB_AUTOPLAY") != NULL);
    lua_setfield(L, -2, "autoplay");
    lua_pushboolean(L, cab_scripted());
    lua_setfield(L, -2, "scripted");
    lua_pushboolean(L, getenv("YARD_DEV") != NULL);
    lua_setfield(L, -2, "dev");
    /* <ID>_SELFTEST or YARD_SELFTEST: a cart's own quick self-check (test.py quick). */
    snprintf(sel, sizeof sel, "%s_SELFTEST", c->id);
    for (char *p = sel; *p; p++)
        if (*p >= 'a' && *p <= 'z')
            *p -= 32;
    lua_pushboolean(L, getenv(sel) != NULL || getenv("CART_SELFTEST") != NULL);
    lua_setfield(L, -2, "selftest");
    lua_pushinteger(L, 0);
    lua_setfield(L, -2, "frame");
    lua_pushcfunction(L, l_quit);
    lua_setfield(L, -2, "quit");
    lua_setglobal(L, "game");
}

/* Call a global function by name if the cart has one. Returns 0, or -1 with err_text set. */
static int call_global(lua_State *L, const char *fn, long long steps)
{
    int top = lua_gettop(L);
    lua_getglobal(L, "__yard_traceback");
    lua_getglobal(L, fn);
    if (!lua_isfunction(L, -1)) {
        lua_settop(L, top);
        return 0;
    }
    budget(strncmp(fn, "__yard_", 7) ? fn : fn + 7, steps);
    if (lua_pcall(L, 0, 0, top + 1) != LUA_OK) {
        const char *m = lua_tostring(L, -1);
        if (m && !strcmp(m, "not enough memory"))
            snprintf(err_text, sizeof err_text, "%s() used up the game's memory (%zu MB). Is a list growing every frame?",
                     phase, mem_cap >> 20);
        else
            snprintf(err_text, sizeof err_text, "%s", m ? m : "an error");
        lua_settop(L, top);
        toon_pass = 1;
        gfx_target(NULL);
        gfx_noclip();
        gfx_offset(0, 0);
        return -1;
    }
    lua_settop(L, top);
    return 0;
}

static int traceback(lua_State *L)
{
    const char *msg = lua_tostring(L, 1);
    luaL_traceback(L, L, msg ? msg : "an error", 1);
    return 1;
}

static void run_lib(lua_State *L)
{
    for (unsigned i = 0; i < sizeof lib_files / sizeof lib_files[0]; i++) {
        char name[64];
        snprintf(name, sizeof name, "=lib/%s.lua", lib_files[i].name);
        budget("the library", 50000000);
        if (luaL_loadbufferx(L, (const char *)lib_files[i].src, lib_files[i].len, name, "t") != LUA_OK ||
            lua_pcall(L, 0, 0, 0) != LUA_OK) {
            cab_log("yard: library %s: %s", lib_files[i].name, lua_tostring(L, -1));
            lua_pop(L, 1);
        }
    }
}

/* Every .lua file's change time in the cart folder, summed: hot reload watches this. */
static long long cart_stamp(const char *dir)
{
    DIR *d = pak_dir_id(dir) ? NULL : opendir(dir);
    struct dirent *e;
    long long sum = 0;
    if (!d)
        return 0;
    while ((e = readdir(d))) {
        char p[800];
        struct stat st;
        size_t n = strlen(e->d_name);
        if (n < 5 || strcmp(e->d_name + n - 4, ".lua"))
            continue;
        snprintf(p, sizeof p, "%s/%s", dir, e->d_name);
        if (stat(p, &st) == 0)
            sum += (long long)st.st_mtime * 1000 + (long long)(st.st_mtim.tv_nsec / 1000000) + (long long)st.st_size;
    }
    closedir(d);
    return sum;
}

static void open_yard_table(lua_State *L);

static lua_State *boot_cart(cart_t *c)
{
    lua_State *L = new_state();
    if (!L) {
        snprintf(err_text, sizeof err_text, "not enough memory to start");
        return NULL;
    }
    api_cart_dir = c->dir;
    lua_pushcfunction(L, traceback);
    lua_setglobal(L, "__yard_traceback");
    open_game_table(L, c);
    {
        /* The label, for the cart's own use (its title on screen, its tint). */
        budget("info.lua", 20000000);
        if (load_cart_file(L, c->dir, "info.lua") == LUA_OK && lua_pcall(L, 0, 1, 0) == LUA_OK && lua_istable(L, -1)) {
            lua_getfield(L, -1, "save");
            open_save(L, lua_isstring(L, -1) ? lua_tostring(L, -1) : NULL);
            lua_pop(L, 1);
            lua_setglobal(L, "info");
        } else {
            lua_pop(L, 1);
            open_save(L, NULL);
        }
    }
    {
        static const luaL_Reg card_fns[] = {
            {"here", l_card_here}, {"read", l_card_read}, {"write", l_card_write}, {NULL, NULL}};
        luaL_newlib(L, card_fns);
        lua_setglobal(L, "card");
    }
    if (c->system)
        open_yard_table(L);
    run_lib(L);
    lua_getglobal(L, "__yard_traceback");
    budget("main.lua", 200000000);
    if (load_cart_file(L, c->dir, "main.lua") != LUA_OK || lua_pcall(L, 0, 0, -2) != LUA_OK) {
        snprintf(err_text, sizeof err_text, "%s", lua_tostring(L, -1));
        lua_close(L);
        return NULL;
    }
    lua_pop(L, 1);
    return L;
}

/* The gentle screen. Shown until a button (after a second) or five seconds. */
static void wrap_line(char *s, int width, int y0)
{
    int y = y0;
    char *p = s;
    while (*p && y < cab_h - 20) {
        char line[80];
        int n = 0, last_space = -1;
        while (p[n] && p[n] != '\n' && n < 79) {
            line[n] = p[n];
            line[n + 1] = 0;
            if (p[n] == ' ')
                last_space = n;
            if (gfx_text_w(1, "%s", line) > width) {
                if (last_space > 0)
                    n = last_space;
                break;
            }
            n++;
        }
        line[n] = 0;
        gfx_text(14, y, 1, HEX(0xffe8f0), "%s", line);
        y += 10;
        p += n;
        while (*p == ' ' || *p == '\n')
            p++;
    }
}

static void draw_oops(int t)
{
    char shown[2048];
    float bob = sinf(t * 0.08f) * 2;
    gfx_vgrad(0, 0, cab_w, cab_h, HEX(0x2a1840), HEX(0x4a2050));
    gfx_ttf(0, 28, cab_w / 2.f, 26 + bob, HEX(0xffd257), HEX(0x1a1230), 1, "Oops!");
    gfx_ttf(0, 14, cab_w / 2.f, 62, HEX(0xfff6ea), 0, 1, "This game tripped.");
    gfx_ttf(0, 14, cab_w / 2.f, 80, HEX(0xc0b8ff), 0, 1, t > 60 ? "Press a button to go back." : "One moment...");
    gfx_rrect(8, 108, cab_w - 16, cab_h - 124, 6, HEXA(0x000000, 120));
    snprintf(shown, sizeof shown, "%s", err_text);
    wrap_line(shown, cab_w - 28, 116);
}

static int oops(int seconds)
{
    int stay = getenv("YARD_DEV") != NULL;
    long long stamp = stay && running ? cart_stamp(running->dir) : 0;
    cab_log("%s error: %s", running ? running->id : "yard", err_text);
    music_stop();
    sfx_slide(W_TRI, 520, 180, 0.4f, 0.25f);
    for (int t = 0; cab_poll(); t++) {
        draw_oops(t);
        gfx_present();
        if (stay) {
            if (t % 20 == 0 && cart_stamp(running->dir) != stamp)
                return 1; /* edited: reload */
            continue;
        }
        if ((t > 60 && (cab_pressed(0, CAB_LOW) || cab_pressed(0, CAB_TL) || cab_pressed(0, CAB_TR))) ||
            t > seconds * 60)
            break;
    }
    return 0;
}

static void push_frame(lua_State *L, int n)
{
    lua_getglobal(L, "game");
    lua_pushinteger(L, n);
    lua_setfield(L, -2, "frame");
    lua_pop(L, 1);
}

static double now_ms(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1000.0 + ts.tv_nsec / 1e6;
}

/* Frame budgets in VM instructions. A Cortex-A7 runs very roughly 20 to 40 million Lua
 * instructions a second, so these are far past any real frame: only a stuck loop meets them. */
#define STEPS_INIT 400000000LL
#define STEPS_FRAME 150000000LL

/* Run one cart until it quits. Returns the exit code for the menu. */
static int run_cart(cart_t *c, int check_frames)
{
    int dev = getenv("YARD_DEV") != NULL, stats = getenv("YARD_STATS") != NULL;
    long long stamp;
    double t_up = 0, t_draw = 0, t_peak = 0;
    int rc = 0;
    running = c;
    if (gfx_init(c->title, c->w, c->h) != 0)
        return 1;
    sfx_init();
    sfx_master(0.32f);
    rng_seed_auto();
restart:
    want_quit = 0;
    frame_no = 0;
    part_clear();
    music_stop();
    stamp = dev ? cart_stamp(c->dir) : 0;
    G = boot_cart(c);
    if (!G || call_global(G, "__yard_init", STEPS_INIT) != 0) {
        if (G)
            lua_close(G);
        G = NULL;
        if (check_frames) {
            fprintf(stdout, "error: %s\n", err_text);
            cab_shutdown();
            return EXIT_STUMBLED;
        }
        if (oops(5))
            goto restart;
        cab_shutdown();
        return EXIT_STUMBLED;
    }
    while (!want_quit && cab_poll()) {
        double t0 = now_ms(), t1, t2;
        push_frame(G, frame_no);
        if (call_global(G, "__yard_update", STEPS_FRAME) != 0)
            goto fell;
        t1 = now_ms();
        part_update();
        if (call_global(G, "__yard_draw", STEPS_FRAME) != 0)
            goto fell;
        t2 = now_ms();
        gfx_present();
        frame_no++;
        t_up += t1 - t0;
        t_draw += t2 - t1;
        if (t2 - t0 > t_peak)
            t_peak = t2 - t0;
        if (stats && frame_no % 300 == 0) {
            cab_log("stats %s frame %d update %.2fms draw %.2fms peak %.2fms lua %zuKB images %zuKB", c->id, frame_no,
                    t_up / 300, t_draw / 300, t_peak, mem_used >> 10, api_img_bytes >> 10);
            t_up = t_draw = t_peak = 0;
        }
        if (check_frames && frame_no >= check_frames)
            break;
        if (dev && frame_no % 30 == 0 && cart_stamp(c->dir) != stamp) {
            cab_log("%s reload", c->id);
            lua_close(G);
            G = NULL;
            goto restart;
        }
    }
    call_global(G, "__yard_quit", STEPS_INIT);
    if (check_frames)
        fprintf(stdout, "ok: %d frames, lua %zu KB, images %zu KB\n", frame_no, mem_used >> 10, api_img_bytes >> 10);
    lua_close(G);
    G = NULL;
    cab_shutdown();
    return rc;
fell:
    lua_close(G);
    G = NULL;
    if (check_frames) {
        fprintf(stdout, "error: %s\n", err_text);
        cab_shutdown();
        return EXIT_STUMBLED;
    }
    if (oops(5))
        goto restart;
    cab_shutdown();
    return EXIT_STUMBLED;
}

/* ------------------------------------------------------------------ the menu's extra powers */

static int l_yard_carts(lua_State *L)
{
    int n = 0;
    lua_newtable(L);
    for (int i = 0; i < ncarts; i++) {
        cart_t *c = &carts[i];
        if (c->system)
            continue;
        lua_newtable(L);
        lua_pushstring(L, c->id);
        lua_setfield(L, -2, "id");
        lua_pushstring(L, c->title);
        lua_setfield(L, -2, "title");
        /* Copy the plain fields of the label across. */
        lua_getglobal(c->L, "info");
        lua_pushnil(c->L);
        while (lua_next(c->L, -2)) {
            if (lua_type(c->L, -2) == LUA_TSTRING) {
                const char *k = lua_tostring(c->L, -2);
                if (lua_type(c->L, -1) == LUA_TSTRING) {
                    lua_pushstring(L, lua_tostring(c->L, -1));
                    lua_setfield(L, -2, k);
                } else if (lua_type(c->L, -1) == LUA_TNUMBER) {
                    lua_pushinteger(L, lua_tointeger(c->L, -1));
                    lua_setfield(L, -2, k);
                }
            }
            lua_pop(c->L, 1);
        }
        lua_pop(c->L, 1);
        lua_rawseti(L, -2, ++n);
    }
    return 1;
}

/* yard.stat(id): the line the cart's label makes from its own save, or nil. */
static int l_yard_stat(lua_State *L)
{
    cart_t *c = find_cart(luaL_checkstring(L, 1));
    lua_State *C;
    int top;
    if (!c) {
        lua_pushnil(L);
        return 1;
    }
    C = c->L;
    top = lua_gettop(C);
    lua_getglobal(C, "info");
    lua_getfield(C, -1, "stat");
    if (lua_isfunction(C, -1)) {
        lua_getfield(C, -2, "save");
        save_read(C, lua_isstring(C, -1) ? lua_tostring(C, -1) : c->id);
        lua_pop(C, 1);             /* the key order */
        lua_remove(C, -2);         /* the save name */
        api_cart_dir = c->dir;
        budget("info.stat", 20000000);
        if (lua_pcall(C, 1, 1, 0) == LUA_OK && lua_isstring(C, -1))
            lua_pushstring(L, lua_tostring(C, -1));
        else
            lua_pushnil(L);
    } else
        lua_pushnil(L);
    lua_settop(C, top);
    return 1;
}

/* yard.icon(id, x, y, lit, t): the label's own little picture. */
static int l_yard_icon(lua_State *L)
{
    cart_t *c = find_cart(luaL_checkstring(L, 1));
    lua_State *C;
    int top;
    if (!c)
        return 0;
    C = c->L;
    top = lua_gettop(C);
    lua_getglobal(C, "info");
    lua_getfield(C, -1, "icon");
    if (lua_isfunction(C, -1)) {
        lua_pushnumber(C, luaL_checknumber(L, 2));
        lua_pushnumber(C, luaL_checknumber(L, 3));
        lua_pushboolean(C, lua_toboolean(L, 4));
        lua_pushnumber(C, luaL_optnumber(L, 5, 0));
        budget("info.icon", 20000000);
        if (lua_pcall(C, 4, 0, 0) != LUA_OK) {
            cab_log("yard: %s icon: %s", c->id, lua_tostring(C, -1));
            lua_pushnil(C);
            lua_setfield(C, -3, "icon"); /* once is enough */
        }
    }
    lua_settop(C, top);
    budget("update", STEPS_FRAME); /* back to the menu's own budget */
    return 0;
}

static int spawn(cart_t *c)
{
    char path[600];
    pid_t pid;
    int st = 0;
    if (c->native[0]) {
        if (!name_ok(c->native, 32))
            return 127;
        snprintf(path, sizeof path, "%s/%s", self_dir, c->native);
        if (access(path, X_OK) != 0)
            return 127;
    } else
        snprintf(path, sizeof path, "%s", self_exe);
    pid = fork();
    if (pid < 0)
        return 127;
    if (pid == 0) {
        if (c->native[0])
            execl(path, c->native, fast ? "-fast" : (char *)NULL, (char *)NULL);
        else
            execl(path, "yard", c->id, fast ? "-fast" : (char *)NULL, (char *)NULL);
        _exit(127);
    }
    while (waitpid(pid, &st, 0) < 0 && errno == EINTR)
        ;
    if (WIFEXITED(st))
        return WEXITSTATUS(st);
    return EXIT_STUMBLED;
}

static int launch_pipe = -1;

/* yard.launch(id): close the window, run the cart, open the window again.
 * Returns "ok", "missing" (it would not start), or "stumbled" (it fell over). */
static int l_yard_launch(lua_State *L)
{
    cart_t *c = find_cart(luaL_checkstring(L, 1));
    int code;
    if (!c || c->system) {
        lua_pushstring(L, "missing");
        return 1;
    }
    music_stop();
    cab_shutdown();
    if (launch_pipe >= 0) {
        /* On the cabinet, libMali.so/libgbm.so leaks two 1024x768x4 DRM GEM shmem buffers (6.0 MiB)
         * every time SDL_Init runs again in the same process. Exit the menu process before the cart
         * starts so the kernel closes the DRM fd and reclaims all shmem and pak/Lua memory; the tiny
         * pre-SDL parent loop in main() spawns the cart and then forks a fresh menu process. */
        char spec[80];
        int n = snprintf(spec, sizeof spec, "%s:%s", c->native[0] ? "native" : "cart",
                         c->native[0] ? c->native : c->id);
        if (n > 0 && (size_t)n < sizeof spec) {
            ssize_t w = write(launch_pipe, spec, (size_t)n);
            (void)w;
        }
        close(launch_pipe);
        _exit(0);
    }
    code = spawn(c);
    if (gfx_init(running->title, running->w, running->h) != 0) {
        cab_log("yard: could not reopen the window");
        exit(1);
    }
    sfx_init();
    sfx_master(0.32f);
    lua_pushstring(L, code == 0 ? "ok" : code == 127 ? "missing" : "stumbled");
    return 1;
}

static int l_yard_card(lua_State *L)
{
    lua_pushboolean(L, cab_ext_root() != NULL);
    return 1;
}

static void open_yard_table(lua_State *L)
{
    static const luaL_Reg fns[] = {{"carts", l_yard_carts}, {"stat", l_yard_stat}, {"icon", l_yard_icon},
                                   {"launch", l_yard_launch}, {"card", l_yard_card}, {NULL, NULL}};
    luaL_newlib(L, fns);
    lua_setglobal(L, "yard");
}

/* ------------------------------------------------------------------ main */

/* The log. On the cabinet it is /data/Games/yard.log, so a play test leaves a trace to read back from a
 * dump: what each process found at start, each cart opened, and the frame times every 300 frames. Over
 * 256 KB it moves to yard.log.1 and starts again. YARD_LOG names another file (on the PC too). */
static void open_log(void)
{
    const char *path = getenv("YARD_LOG");
    char old[600];
    struct stat st;
    FILE *f;
#ifdef CAB_CABINET
    if (!path || !*path)
        path = "/data/Games/yard.log";
    setenv("YARD_STATS", "1", 0);
#endif
    if (!path || !*path)
        return;
    if (stat(path, &st) == 0 && st.st_size > 256 * 1024) {
        snprintf(old, sizeof old, "%s.1", path);
        rename(path, old);
    }
    cab_log_open(path);
    f = fopen("/proc/meminfo", "r");
    if (f) {
        char line[128];
        long avail = -1, total = -1;
        while (fgets(line, sizeof line, f)) {
            sscanf(line, "MemTotal: %ld", &total);
            sscanf(line, "MemAvailable: %ld", &avail);
        }
        fclose(f);
        cab_log("yard: pid %d, memory %ld kB of %ld kB available", (int)getpid(), avail, total);
    }
}

int main(int argc, char **argv)
{
    const char *want = NULL;
    int check = 0;
    cart_t *c;
    find_self();
    fast = cab_fast(argc, argv);
    if (getenv("YARD_MEM_MB") && atoi(getenv("YARD_MEM_MB")) > 0)
        mem_cap = (size_t)atoi(getenv("YARD_MEM_MB")) << 20;
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "-fast"))
            continue;
        if (!strcmp(argv[i], "--list")) {
            scan_carts();
            for (int k = 0; k < ncarts; k++)
                printf("%-10s %-10s %s%s\n", carts[k].id, carts[k].title, carts[k].dir,
                       carts[k].system ? "  (menu)" : carts[k].native[0] ? "  (native)" : "");
            return 0;
        }
        if (!strcmp(argv[i], "--check")) {
            check = getenv("YARD_CHECK_FRAMES") ? atoi(getenv("YARD_CHECK_FRAMES")) : 300;
            if (check < 1)
                check = 300;
            continue;
        }
        want = argv[i];
    }
    /* Called as a link named after a cart (out/pc/keep -> yard): run that cart. */
    if (!want) {
        const char *base = strrchr(argv[0], '/');
        base = base ? base + 1 : argv[0];
        if (strcmp(base, "yard") && name_ok(base, 32))
            want = base;
    }
#ifdef CAB_CABINET
    if (!want && !check && !getenv("CAB_SCRIPT") && !getenv("CAB_CTL")) {
        for (;;) {
            int pfd[2], st = 0;
            char spec[80];
            ssize_t n;
            pid_t pid;
            cart_t target;
            if (pipe(pfd) != 0)
                break;
            pid = fork();
            if (pid < 0) {
                close(pfd[0]);
                close(pfd[1]);
                break;
            }
            if (pid == 0) {
                close(pfd[0]);
                launch_pipe = pfd[1];
                break;
            }
            close(pfd[1]);
            n = read(pfd[0], spec, sizeof spec - 1);
            close(pfd[0]);
            while (waitpid(pid, &st, 0) < 0 && errno == EINTR)
                ;
            if (n <= 0)
                return WIFEXITED(st) ? WEXITSTATUS(st) : 0;
            spec[n] = 0;
            memset(&target, 0, sizeof target);
            if (!strncmp(spec, "native:", 7))
                snprintf(target.native, sizeof target.native, "%s", spec + 7);
            else if (!strncmp(spec, "cart:", 5))
                snprintf(target.id, sizeof target.id, "%s", spec + 5);
            if (target.native[0] || target.id[0])
                (void)spawn(&target);
        }
    }
#endif
    open_log();
    scan_carts();
    cab_log("yard: start %s, %d carts", want ? want : "the menu", ncarts);
    if (want) {
        c = find_cart(want);
        if (!c) {
            cab_log("yard: no cart named %s", want);
            return 127;
        }
        if (c->native[0])
            return spawn(c);
        return run_cart(c, check);
    }
    for (int i = 0; i < ncarts; i++)
        if (carts[i].system)
            return run_cart(&carts[i], check);
    cab_log("yard: no menu cart (info.lua with system = true) on the cart path");
    return 127;
}
