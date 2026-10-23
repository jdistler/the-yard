# Builds rksend against the system libusb runtime. No libusb-1.0-0-dev package
# is needed: the header is vendored in inc/ (libusb 1.0.27, LGPL-2.1).
LIBUSB ?= $(firstword $(wildcard /lib/x86_64-linux-gnu/libusb-1.0.so.0 /usr/lib/x86_64-linux-gnu/libusb-1.0.so.0 /usr/lib/libusb-1.0.so.0))

rksend: rksend.c inc/libusb.h
	gcc -O2 -Wall -Iinc -o $@ rksend.c $(LIBUSB)

clean:
	rm -f rksend

.PHONY: clean
