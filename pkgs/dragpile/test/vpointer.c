// vpointer: a scripted pointer for driving real applications in a nested compositor, through
// zwlr_virtual_pointer_v1. It maps no window of its own, so whatever is under the pointer gets
// the presses and starts its own drags.
//
// usage: vpointer [--extent W H] [--script FILE | STEP...]
//
// Absolute positions are in layout px of a W x H layout (default 1280 x 800), which is what
// zwlr_virtual_pointer_v1.motion_absolute maps onto every output together. Steps, one per line
// in FILE or one per argument:
//   abs X Y            jump to (X, Y)
//   glide X Y MS       glide to (X, Y) over MS ms, eased in and out, at about 250 Hz
//   move DX DY MS      glide by (DX, DY) over MS ms
//   down | up          press or release the left button ("down right" for another button)
//   click              down, 40 ms, up
//   wait MS
// Each step prints "t=<ms> <step>" on stdout, so a runner can line screenshots up with motion.

#define _GNU_SOURCE
#include <math.h>
#include <poll.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include <wayland-client.h>
#include "wlr-virtual-pointer-unstable-v1-client-protocol.h"

static struct wl_display*                      display;
static struct wl_seat*                         seat;
static struct zwlr_virtual_pointer_manager_v1* vpm;
static struct zwlr_virtual_pointer_v1*         vp;
static struct timespec                         t0;
static double                                  extW = 1280, extH = 800;
static double                                  curX = -1, curY = -1;

static long now_ms(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return (t.tv_sec - t0.tv_sec) * 1000 + (t.tv_nsec - t0.tv_nsec) / 1000000;
}

static uint32_t stamp(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec * 1000 + t.tv_nsec / 1000000;
}

static void reg_global(void* d, struct wl_registry* r, uint32_t name, const char* iface, uint32_t v) {
    if (!strcmp(iface, wl_seat_interface.name) && !seat)
        seat = wl_registry_bind(r, name, &wl_seat_interface, 1);
    else if (!strcmp(iface, zwlr_virtual_pointer_manager_v1_interface.name))
        vpm = wl_registry_bind(r, name, &zwlr_virtual_pointer_manager_v1_interface, 1);
}
static void                              reg_remove(void* d, struct wl_registry* r, uint32_t name) {}
static const struct wl_registry_listener reg_listener = {reg_global, reg_remove};

static void pump(int ms) {
    const long until = now_ms() + ms;
    do {
        wl_display_flush(display);
        struct pollfd p = {wl_display_get_fd(display), POLLIN, 0};
        if (poll(&p, 1, 1) > 0)
            wl_display_dispatch(display);
        else
            wl_display_dispatch_pending(display);
    } while (now_ms() < until);
}

static void warp(double x, double y) {
    x = fmin(fmax(x, 0), extW - 1);
    y = fmin(fmax(y, 0), extH - 1);
    // The protocol takes integers in [0, extent]; work at 1/16 px so glides stay smooth.
    zwlr_virtual_pointer_v1_motion_absolute(vp, stamp(), (uint32_t)lround(x * 16), (uint32_t)lround(y * 16), (uint32_t)(extW * 16), (uint32_t)(extH * 16));
    zwlr_virtual_pointer_v1_frame(vp);
    wl_display_flush(display);
    curX = x;
    curY = y;
}

static void glide(double x, double y, int ms) {
    if (curX < 0) {
        warp(x, y);
        return;
    }
    const double x0 = curX, y0 = curY;
    const int    steps = ms / 4 > 0 ? ms / 4 : 1;
    const long   start = now_ms();
    for (int i = 1; i <= steps; i++) {
        const double u = (double)i / steps;
        const double e = u < 0.5 ? 4 * u * u * u : 1 - pow(-2 * u + 2, 3) / 2;
        warp(x0 + (x - x0) * e, y0 + (y - y0) * e);
        // Hold the schedule to the clock, not to the step count, so a slow step doesn't stretch it.
        const long due = start + (long)(ms * u);
        pump(due > now_ms() ? (int)(due - now_ms()) : 0);
    }
}

static void button(uint32_t code, bool down) {
    zwlr_virtual_pointer_v1_button(vp, stamp(), code, down ? WL_POINTER_BUTTON_STATE_PRESSED : WL_POINTER_BUTTON_STATE_RELEASED);
    zwlr_virtual_pointer_v1_frame(vp);
    wl_display_flush(display);
}

static uint32_t buttonCode(const char* rest) {
    if (strstr(rest, "right"))
        return 0x111;
    if (strstr(rest, "middle"))
        return 0x112;
    return 0x110; // BTN_LEFT
}

static void step(const char* line) {
    double x, y;
    int    ms;
    while (*line == ' ' || *line == '\t')
        line++;
    if (!*line || *line == '#' || *line == '\n')
        return;
    char shown[128];
    snprintf(shown, sizeof(shown), "%s", line);
    shown[strcspn(shown, "\n")] = 0;
    printf("t=%ld %s\n", now_ms(), shown);

    if (sscanf(line, "abs %lf %lf", &x, &y) == 2)
        warp(x, y), pump(4);
    else if (sscanf(line, "glide %lf %lf %d", &x, &y, &ms) == 3)
        glide(x, y, ms);
    else if (sscanf(line, "move %lf %lf %d", &x, &y, &ms) == 3)
        glide(curX + x, curY + y, ms);
    else if (sscanf(line, "wait %d", &ms) == 1)
        pump(ms);
    else if (!strncmp(line, "down", 4))
        button(buttonCode(line + 4), true), pump(4);
    else if (!strncmp(line, "up", 2))
        button(buttonCode(line + 2), false), pump(4);
    else if (!strncmp(line, "click", 5)) {
        button(buttonCode(line + 5), true);
        pump(40);
        button(buttonCode(line + 5), false);
        pump(4);
    } else
        fprintf(stderr, "vpointer: unknown step: %s\n", shown);
}

int main(int argc, char** argv) {
    const char* script = NULL;
    int         i      = 1;
    for (; i < argc; i++) {
        if (!strcmp(argv[i], "--extent") && i + 2 < argc) {
            extW = atof(argv[++i]);
            extH = atof(argv[++i]);
        } else if (!strcmp(argv[i], "--script") && i + 1 < argc)
            script = argv[++i];
        else
            break;
    }
    setvbuf(stdout, NULL, _IOLBF, 0);
    clock_gettime(CLOCK_MONOTONIC, &t0);

    display = wl_display_connect(NULL);
    if (!display) {
        fprintf(stderr, "vpointer: no wayland display\n");
        return 1;
    }
    struct wl_registry* reg = wl_display_get_registry(display);
    wl_registry_add_listener(reg, &reg_listener, NULL);
    wl_display_roundtrip(display);
    if (!seat || !vpm) {
        fprintf(stderr, "vpointer: compositor lacks wl_seat or zwlr_virtual_pointer_manager_v1\n");
        return 1;
    }
    vp = zwlr_virtual_pointer_manager_v1_create_virtual_pointer(vpm, seat);
    wl_display_roundtrip(display);

    if (script) {
        FILE* f = !strcmp(script, "-") ? stdin : fopen(script, "r");
        if (!f) {
            perror(script);
            return 1;
        }
        char line[256];
        while (fgets(line, sizeof(line), f))
            step(line);
    }
    for (; i < argc; i++)
        step(argv[i]);

    pump(50);
    zwlr_virtual_pointer_v1_destroy(vp);
    wl_display_roundtrip(display);
    printf("t=%ld done\n", now_ms());
    return 0;
}
