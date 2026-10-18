// dragsrc: a scripted drag source for testing dragpile inside a nested Hyprland.
//
// It maps a window, presses a virtual pointer on it, starts a wl_data_device drag offering
// text/uri-list (with a bright red drag icon, so a screenshot shows whether the plugin hid it),
// then plays a motion script and releases. With --accept the window also takes the drop.
//
// usage: dragsrc [--accept] [--no-icon] [--script FILE] URI...
// Script lines: "move DX DY MS" glides by (DX, DY) over MS milliseconds; "wait MS"; "release".
// Each step prints "t=<ms> <step>" so a runner can line screenshots up with motion.

#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <math.h>
#include <poll.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

#include <wayland-client.h>
#include "xdg-shell-client-protocol.h"
#include "wlr-virtual-pointer-unstable-v1-client-protocol.h"

static struct wl_display*                         display;
static struct wl_compositor*                      compositor;
static struct wl_shm*                             shm;
static struct xdg_wm_base*                        wm;
static struct wl_seat*                            seat;
static struct wl_pointer*                         pointer;
static struct wl_data_device_manager*             ddm;
static struct wl_data_device*                     device;
static struct zwlr_virtual_pointer_manager_v1*    vpm;
static struct zwlr_virtual_pointer_v1*            vp;
static struct wl_surface*                         surface;
static struct xdg_surface*                        xsurface;
static struct xdg_toplevel*                       toplevel;
static int                                        winW = 0, winH = 0;
static bool                                       configured = false, entered = false, dragging = false, finished = false;
static uint32_t                                   pressSerial = 0;
static bool                                       accept = false, withIcon = true, drive = false;
static char**                                     uris;
static int                                        uriCount;
static struct timespec                            t0;

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

static struct wl_buffer* make_buffer(int w, int h, uint32_t argb) {
    const int stride = w * 4, size = stride * h;
    int       fd     = memfd_create("dragsrc", MFD_CLOEXEC);
    if (fd < 0 || ftruncate(fd, size) < 0)
        exit(1);
    uint32_t* data = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    for (int i = 0; i < w * h; i++)
        data[i] = argb;
    munmap(data, size);
    struct wl_shm_pool* pool = wl_shm_create_pool(shm, fd, size);
    struct wl_buffer*   buf  = wl_shm_pool_create_buffer(pool, 0, w, h, stride, WL_SHM_FORMAT_ARGB8888);
    wl_shm_pool_destroy(pool);
    close(fd);
    return buf;
}

static void src_target(void* d, struct wl_data_source* s, const char* mime) {
    printf("t=%ld source.target %s\n", now_ms(), mime ? mime : "(none)");
}
static void src_send(void* d, struct wl_data_source* s, const char* mime, int32_t fd) {
    printf("t=%ld source.send %s\n", now_ms(), mime);
    for (int i = 0; i < uriCount; i++) {
        (void)!write(fd, uris[i], strlen(uris[i]));
        (void)!write(fd, "\r\n", 2);
    }
    close(fd);
}
static void src_cancelled(void* d, struct wl_data_source* s) {
    printf("t=%ld source.cancelled\n", now_ms());
    finished = true;
}
static void src_dnd_drop_performed(void* d, struct wl_data_source* s) {
    printf("t=%ld source.drop_performed\n", now_ms());
}
static void src_dnd_finished(void* d, struct wl_data_source* s) {
    printf("t=%ld source.dnd_finished\n", now_ms());
    finished = true;
}
static void src_action(void* d, struct wl_data_source* s, uint32_t a) {}
static const struct wl_data_source_listener src_listener = {src_target, src_send, src_cancelled, src_dnd_drop_performed, src_dnd_finished, src_action};

// As a drop target (--accept): take whatever is offered over our own window.
static struct wl_data_offer* offer;
static uint32_t              enterSerial;
static void                  offer_offer(void* d, struct wl_data_offer* o, const char* mime) {}
static void                  offer_source_actions(void* d, struct wl_data_offer* o, uint32_t a) {}
static void                  offer_action(void* d, struct wl_data_offer* o, uint32_t a) {}
static const struct wl_data_offer_listener offer_listener = {offer_offer, offer_source_actions, offer_action};

static void dev_data_offer(void* d, struct wl_data_device* dev, struct wl_data_offer* o) {
    wl_data_offer_add_listener(o, &offer_listener, NULL);
}
static void dev_enter(void* d, struct wl_data_device* dev, uint32_t serial, struct wl_surface* s, wl_fixed_t x, wl_fixed_t y, struct wl_data_offer* o) {
    offer       = o;
    enterSerial = serial;
    if (accept && o) {
        wl_data_offer_accept(o, serial, "text/uri-list");
        wl_data_offer_set_actions(o, WL_DATA_DEVICE_MANAGER_DND_ACTION_COPY, WL_DATA_DEVICE_MANAGER_DND_ACTION_COPY);
    }
}
static void dev_leave(void* d, struct wl_data_device* dev) {}
static void dev_motion(void* d, struct wl_data_device* dev, uint32_t t, wl_fixed_t x, wl_fixed_t y) {}
static void dev_drop(void* d, struct wl_data_device* dev) {
    printf("t=%ld device.drop\n", now_ms());
    if (accept && offer) {
        int fds[2];
        pipe(fds);
        wl_data_offer_receive(offer, "text/uri-list", fds[1]);
        close(fds[1]);
        wl_display_roundtrip(display);
        char    buf[4096];
        ssize_t n = read(fds[0], buf, sizeof(buf) - 1);
        close(fds[0]);
        printf("t=%ld device.received %zd bytes\n", now_ms(), n);
        wl_data_offer_finish(offer);
    }
}
static void dev_selection(void* d, struct wl_data_device* dev, struct wl_data_offer* o) {}
static const struct wl_data_device_listener dev_listener = {dev_data_offer, dev_enter, dev_leave, dev_motion, dev_drop, dev_selection};

static void ptr_enter(void* d, struct wl_pointer* p, uint32_t serial, struct wl_surface* s, wl_fixed_t x, wl_fixed_t y) {
    entered = true;
}
static void ptr_leave(void* d, struct wl_pointer* p, uint32_t serial, struct wl_surface* s) {}
static void ptr_motion(void* d, struct wl_pointer* p, uint32_t t, wl_fixed_t x, wl_fixed_t y) {}
static void ptr_button(void* d, struct wl_pointer* p, uint32_t serial, uint32_t t, uint32_t button, uint32_t state) {
    if (state != WL_POINTER_BUTTON_STATE_PRESSED || dragging)
        return;
    pressSerial = serial;
    dragging    = true;

    struct wl_data_source* src = wl_data_device_manager_create_data_source(ddm);
    wl_data_source_add_listener(src, &src_listener, NULL);
    wl_data_source_offer(src, "text/uri-list");
    wl_data_source_offer(src, "text/plain;charset=utf-8");
    wl_data_source_set_actions(src, WL_DATA_DEVICE_MANAGER_DND_ACTION_COPY | WL_DATA_DEVICE_MANAGER_DND_ACTION_MOVE);

    struct wl_surface* icon = NULL;
    if (withIcon) {
        icon = wl_compositor_create_surface(compositor);
        wl_surface_attach(icon, make_buffer(40, 40, 0xffff0000), 0, 0);
        wl_surface_damage(icon, 0, 0, 40, 40);
        wl_surface_commit(icon);
    }
    wl_data_device_start_drag(device, src, surface, icon, serial);
    printf("t=%ld start_drag\n", now_ms());
}
static void ptr_axis(void* d, struct wl_pointer* p, uint32_t t, uint32_t a, wl_fixed_t v) {}
static void ptr_frame(void* d, struct wl_pointer* p) {}
static void ptr_axis_source(void* d, struct wl_pointer* p, uint32_t s) {}
static void ptr_axis_stop(void* d, struct wl_pointer* p, uint32_t t, uint32_t a) {}
static void ptr_axis_discrete(void* d, struct wl_pointer* p, uint32_t a, int32_t v) {}
static const struct wl_pointer_listener ptr_listener = {ptr_enter, ptr_leave, ptr_motion, ptr_button, ptr_axis, ptr_frame, ptr_axis_source, ptr_axis_stop, ptr_axis_discrete};

static void wm_ping(void* d, struct xdg_wm_base* w, uint32_t serial) {
    xdg_wm_base_pong(w, serial);
}
static const struct xdg_wm_base_listener wm_listener = {wm_ping};

static void xs_configure(void* d, struct xdg_surface* s, uint32_t serial) {
    xdg_surface_ack_configure(s, serial);
    int w = winW > 0 ? winW : 800, h = winH > 0 ? winH : 600;
    wl_surface_attach(surface, make_buffer(w, h, 0xff2a2f3a), 0, 0);
    wl_surface_damage(surface, 0, 0, w, h);
    wl_surface_commit(surface);
    configured = true;
}
static const struct xdg_surface_listener xs_listener = {xs_configure};

static void tl_configure(void* d, struct xdg_toplevel* t, int32_t w, int32_t h, struct wl_array* states) {
    if (w > 0)
        winW = w;
    if (h > 0)
        winH = h;
}
static void tl_close(void* d, struct xdg_toplevel* t) {}
static const struct xdg_toplevel_listener tl_listener = {tl_configure, tl_close};

static void reg_global(void* d, struct wl_registry* r, uint32_t name, const char* iface, uint32_t v) {
    if (!strcmp(iface, wl_compositor_interface.name))
        compositor = wl_registry_bind(r, name, &wl_compositor_interface, 4);
    else if (!strcmp(iface, wl_shm_interface.name))
        shm = wl_registry_bind(r, name, &wl_shm_interface, 1);
    else if (!strcmp(iface, xdg_wm_base_interface.name)) {
        wm = wl_registry_bind(r, name, &xdg_wm_base_interface, 1);
        xdg_wm_base_add_listener(wm, &wm_listener, NULL);
    } else if (!strcmp(iface, wl_seat_interface.name))
        seat = wl_registry_bind(r, name, &wl_seat_interface, 5);
    else if (!strcmp(iface, wl_data_device_manager_interface.name))
        ddm = wl_registry_bind(r, name, &wl_data_device_manager_interface, 3);
    else if (!strcmp(iface, zwlr_virtual_pointer_manager_v1_interface.name))
        vpm = wl_registry_bind(r, name, &zwlr_virtual_pointer_manager_v1_interface, 1);
}
static void reg_remove(void* d, struct wl_registry* r, uint32_t name) {}
static const struct wl_registry_listener reg_listener = {reg_global, reg_remove};

static void pump(int ms) {
    const long until = now_ms() + ms;
    while (now_ms() < until) {
        wl_display_flush(display);
        struct pollfd p = {wl_display_get_fd(display), POLLIN, 0};
        if (poll(&p, 1, 2) > 0)
            wl_display_dispatch(display);
        else
            wl_display_dispatch_pending(display);
    }
}

static void vmove(double dx, double dy) {
    zwlr_virtual_pointer_v1_motion(vp, stamp(), wl_fixed_from_double(dx), wl_fixed_from_double(dy));
    zwlr_virtual_pointer_v1_frame(vp);
    wl_display_flush(display);
}

// Glide with an ease-in-out profile at about 240 Hz, the way a hand moves a mouse.
static void glide(double dx, double dy, int ms) {
    const int steps = ms / 4 > 0 ? ms / 4 : 1;
    double    done  = 0;
    for (int i = 1; i <= steps; i++) {
        const double u = (double)i / steps;
        const double e = u < 0.5 ? 4 * u * u * u : 1 - pow(-2 * u + 2, 3) / 2;
        vmove(dx * (e - done), dy * (e - done));
        done = e;
        pump(4);
    }
}

static void button(bool down) {
    zwlr_virtual_pointer_v1_button(vp, stamp(), 0x110 /* BTN_LEFT */, down ? WL_POINTER_BUTTON_STATE_PRESSED : WL_POINTER_BUTTON_STATE_RELEASED);
    zwlr_virtual_pointer_v1_frame(vp);
    wl_display_flush(display);
}

int main(int argc, char** argv) {
    const char* script = NULL;
    int         i      = 1;
    for (; i < argc; i++) {
        if (!strcmp(argv[i], "--accept"))
            accept = true;
        else if (!strcmp(argv[i], "--no-icon"))
            withIcon = false;
        else if (!strcmp(argv[i], "--drive"))
            drive = true;
        else if (!strcmp(argv[i], "--script") && i + 1 < argc)
            script = argv[++i];
        else
            break;
    }
    uris     = argv + i;
    uriCount = argc - i;
    setvbuf(stdout, NULL, _IOLBF, 0);
    clock_gettime(CLOCK_MONOTONIC, &t0);

    display = wl_display_connect(NULL);
    if (!display) {
        fprintf(stderr, "no wayland display\n");
        return 1;
    }
    struct wl_registry* reg = wl_display_get_registry(display);
    wl_registry_add_listener(reg, &reg_listener, NULL);
    wl_display_roundtrip(display);
    if (!compositor || !shm || !wm || !seat || !ddm || !vpm) {
        fprintf(stderr, "missing globals (vpm=%p ddm=%p)\n", (void*)vpm, (void*)ddm);
        return 1;
    }

    pointer = wl_seat_get_pointer(seat);
    wl_pointer_add_listener(pointer, &ptr_listener, NULL);
    device = wl_data_device_manager_get_data_device(ddm, seat);
    wl_data_device_add_listener(device, &dev_listener, NULL);
    vp = zwlr_virtual_pointer_manager_v1_create_virtual_pointer(vpm, seat);

    // --drive: no window and no drag of our own; the script presses on whatever is under the
    // pointer, so a real application starts the drag.
    if (!drive) {
    surface  = wl_compositor_create_surface(compositor);
    xsurface = xdg_wm_base_get_xdg_surface(wm, surface);
    xdg_surface_add_listener(xsurface, &xs_listener, NULL);
    toplevel = xdg_surface_get_toplevel(xsurface);
    xdg_toplevel_add_listener(toplevel, &tl_listener, NULL);
    xdg_toplevel_set_app_id(toplevel, "dragsrc");
    wl_surface_commit(surface);
    while (!configured)
        wl_display_dispatch(display);
    pump(300);

    // Nudge the pointer so the window gets an enter, then press.
    vmove(1, 1);
    pump(100);
    vmove(-1, -1);
    pump(100);
    printf("t=%ld press (entered=%d)\n", now_ms(), entered);
    button(true);
    pump(150);
    if (!dragging) {
        fprintf(stderr, "drag did not start\n");
        return 2;
    }
    }

    FILE* f = script ? fopen(script, "r") : NULL;
    char  line[256];
    bool  released = false;
    while (f && fgets(line, sizeof(line), f)) {
        double dx, dy;
        int    ms;
        if (sscanf(line, "move %lf %lf %d", &dx, &dy, &ms) == 3) {
            printf("t=%ld move %.0f %.0f %d\n", now_ms(), dx, dy, ms);
            glide(dx, dy, ms);
        } else if (sscanf(line, "wait %d", &ms) == 1) {
            printf("t=%ld wait %d\n", now_ms(), ms);
            pump(ms);
        } else if (!strncmp(line, "press", 5)) {
            printf("t=%ld press\n", now_ms());
            button(true);
            pump(30);
        } else if (!strncmp(line, "release", 7)) {
            printf("t=%ld release\n", now_ms());
            button(false);
            released = true;
        }
    }
    if (!released && !drive) {
        printf("t=%ld release\n", now_ms());
        button(false);
    }

    for (int k = 0; k < 400 && !finished; k++)
        pump(5);
    pump(600);
    printf("t=%ld done\n", now_ms());
    return 0;
}
