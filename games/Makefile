# make TARGET=pc   native build for playing/testing on this PC (windowed, keyboard)
# make TARGET=cab  armhf build for the cabinet; run through ./build.sh cab (Docker toolchain)
GAMES := probe keep lamp yard orb tea chest
TARGET ?= pc
OUT := out/$(TARGET)

CFLAGS += -std=gnu99 -O2 -Wall -Wextra -Icommon -D_REENTRANT
ifeq ($(TARGET),cab)
  CC := arm-linux-gnueabihf-gcc
  ROOTFS ?= /rootfs
  CFLAGS += -march=armv7-a -mfpu=neon-vfpv4 -mfloat-abi=hard -DCAB_CABINET -I/opt/sdl2/include
  # Link against the cabinet's own SDL2, so API newer than 2.0.7 fails here, not on the cabinet.
  # Its own dependencies need the cabinet's glibc 2.29 (e.g. log@GLIBC_2.29), so don't resolve those here;
  # check_binary.sh verifies what our binary itself requires.
  LDLIBS := $(ROOTFS)/usr/lib/libSDL2-2.0.so.0.7.0 -lm -Wl,--allow-shlib-undefined
else
  CFLAGS += -g -I../build/sdl2-2.0.7-include
  LDLIBS := /lib/x86_64-linux-gnu/libSDL2-2.0.so.0 -lm
endif

all: $(GAMES:%=$(OUT)/%)

$(OUT)/%: %/*.c common/*.c common/*.h | $(OUT)
	$(CC) $(CFLAGS) -o $@ $(filter %.c,$^) $(LDLIBS)

$(OUT):
	mkdir -p $@

clean:
	rm -rf out

stress:
	./stress.sh

.PHONY: all clean stress
