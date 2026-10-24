# make TARGET=pc   native build for playing and testing on this PC (windowed, keyboard)
# make TARGET=cab  armhf build for the cabinet; run it through ./build.sh cab (the Docker toolchain)
#
# Two programs come out: yard (the cart runtime: engine + Lua + the embedded library) and orb
# (the one native OpenGL game). probe is the hardware probe. Carts are not compiled: they
# are folders of Lua in carts/, which tools/yard checks and packs.
TARGET ?= pc
OUT := out/$(TARGET)

CFLAGS += -std=gnu99 -O2 -Wall -Wextra -Iengine -D_REENTRANT
LUA_CFLAGS := -std=gnu99 -O2 -Wall -DLUA_USE_POSIX -Iengine/lua
ifeq ($(TARGET),cab)
  CC := arm-linux-gnueabihf-gcc
  ROOTFS ?= /rootfs
  ARCH := -march=armv7-a -mfpu=neon-vfpv4 -mfloat-abi=hard
  CFLAGS += $(ARCH) -DCAB_CABINET -I/opt/sdl2/include
  LUA_CFLAGS += $(ARCH)
  # Link against the cabinet's own SDL2, so API newer than 2.0.7 fails here, not on the cabinet.
  # Its own dependencies need the cabinet's glibc 2.29 (e.g. log@GLIBC_2.29), so don't resolve those here;
  # check_binary.sh verifies what our binary itself requires.
  LDLIBS := $(ROOTFS)/usr/lib/libSDL2-2.0.so.0.7.0 -lm -Wl,--allow-shlib-undefined
else
  CFLAGS += -g -I../build/sdl2-2.0.7-include
  LUA_CFLAGS += -g
  LDLIBS := /lib/x86_64-linux-gnu/libSDL2-2.0.so.0 -lm
endif

ENGINE := engine/cab.c engine/cab_gl.c engine/gfx.c engine/sfx.c
ENGINE_H := $(wildcard engine/*.h engine/*.inc engine/fonts/*.h)
LUA_SRC := $(filter-out engine/lua/lua.c engine/lua/luac.c engine/lua/onelua.c engine/lua/ltests.c,$(wildcard engine/lua/*.c))
LUA_OBJ := $(LUA_SRC:engine/lua/%.c=$(OUT)/lua/%.o)
# The carts the dev build links by name (out/pc/keep runs carts/keep), for tests and play.sh.
LINKS := $(patsubst carts/%/info.lua,%,$(wildcard carts/*/info.lua))
LINKS := $(filter-out yard orb,$(LINKS))

all: $(OUT)/yard $(OUT)/orb $(OUT)/probe $(if $(filter pc,$(TARGET)),links)

engine/lib_lua.h: $(wildcard engine/lib/*.lua) tools/bin2c.py
	python3 tools/bin2c.py

$(OUT)/lua/%.o: engine/lua/%.c | $(OUT)/lua
	$(CC) $(LUA_CFLAGS) -c -o $@ $<

$(OUT)/yard: engine/runtime.c engine/api.c $(ENGINE) $(ENGINE_H) engine/lib_lua.h $(LUA_OBJ) | $(OUT)
	$(CC) $(CFLAGS) -o $@ engine/runtime.c engine/api.c $(ENGINE) $(LUA_OBJ) $(LDLIBS)

$(OUT)/orb: native/orb/orb.c $(ENGINE) $(ENGINE_H) | $(OUT)
	$(CC) $(CFLAGS) -o $@ native/orb/orb.c $(ENGINE) $(LDLIBS)

$(OUT)/probe: native/probe/probe.c $(ENGINE) $(ENGINE_H) | $(OUT)
	$(CC) $(CFLAGS) -o $@ native/probe/probe.c $(ENGINE) $(LDLIBS)

links: $(OUT)/yard
	@for c in $(LINKS); do ln -sf yard $(OUT)/$$c; done

$(OUT) $(OUT)/lua:
	mkdir -p $@

clean:
	rm -rf out

.PHONY: all clean links

