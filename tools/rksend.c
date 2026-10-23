#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <libusb.h>

static int done;
static void cb(struct libusb_transfer *t) { (void)t; done = 1; }

int main(int argc, char **argv) {
    if (argc != 5) { fprintf(stderr, "usage: rksend <addr> <index hex> <wire file> <timeout ms>\n"); return 64; }
    int want = atoi(argv[1]);
    unsigned idx = strtoul(argv[2], NULL, 16);
    unsigned tmo = atoi(argv[4]);
    FILE *f = fopen(argv[3], "rb");
    if (!f) return 1;
    fseek(f, 0, SEEK_END); long n = ftell(f); rewind(f);
    unsigned char *wire = malloc(n);
    if (fread(wire, 1, n, f) != (size_t)n) return 1;
    fclose(f);

    libusb_context *ctx = NULL;
    if (libusb_init(&ctx)) return 2;
    libusb_device_handle *h = libusb_open_device_with_vid_pid(ctx, 0x2207, 0x301a);
    if (!h) { printf("no 2207:301a\n"); return 3; }
    int addr = libusb_get_device_address(libusb_get_device(h));
    struct libusb_device_descriptor d;
    libusb_get_device_descriptor(libusb_get_device(h), &d);
    printf("addr=%d bcdUSB=%04x index=0x%03x wire=%ld\n", addr, d.bcdUSB, idx, n);
    fflush(stdout);
    if (addr != want) { printf("expected addr %d, stopping\n", want); return 4; }
    if (libusb_kernel_driver_active(h, 0) == 1) { printf("driver bound, stopping\n"); return 5; }
    if (libusb_claim_interface(h, 0)) { printf("claim failed\n"); return 6; }

    long sent = 0; int chunk = 0;
    unsigned char *buf = malloc(8 + 4096);
    while (sent < n) {
        int len = (n - sent) > 4096 ? 4096 : (int)(n - sent);
        libusb_fill_control_setup(buf, 0x40, 0x0C, 0, idx, len);
        memcpy(buf + 8, wire + sent, len);
        struct libusb_transfer *t = libusb_alloc_transfer(0);
        libusb_fill_control_transfer(t, h, buf, cb, NULL, tmo);
        done = 0;
        if (libusb_submit_transfer(t)) { printf("chunk %d submit failed\n", chunk); return 7; }
        while (!done) {
            struct timeval tv = { 1, 0 };
            libusb_handle_events_timeout(ctx, &tv);
        }
        printf("chunk %d len=%d actual=%d status=%d\n", chunk, len, t->actual_length, t->status);
        fflush(stdout);
        if (t->status != LIBUSB_TRANSFER_COMPLETED || t->actual_length != len) {
            printf("STOP at chunk %d, sent %ld of %ld\n", chunk, sent + t->actual_length, n);
            return 8;
        }
        libusb_free_transfer(t);
        sent += len; chunk++;
    }
    printf("OK index 0x%03x all %ld bytes, %d chunks\n", idx, n, chunk);
    libusb_release_interface(h, 0);
    libusb_close(h);
    libusb_exit(ctx);
    return 0;
}
