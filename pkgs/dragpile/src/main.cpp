// dragpile: draws the files of a drag-and-drop as a small pile of cards that chases the cursor,
// for any Wayland client. The compositor is the only place that sees every drag, its data and
// the pointer at frame rate, so the plugin hooks Hyprland's wl_data_device implementation,
// reads the drag's text/uri-list itself, and draws in place of the client's drag icon.

#include <algorithm>
#include <cerrno>
#include <fcntl.h>
#include <string>
#include <unistd.h>
#include <vector>

#include <glib.h>

#include <hyprland/src/Compositor.hpp>
#include <hyprland/src/debug/HyprCtl.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/helpers/time/Time.hpp>
#include <hyprland/src/managers/EventManager.hpp>
#include <hyprland/src/managers/input/InputManager.hpp>
#include <hyprland/src/output/Monitor.hpp>
#include <hyprland/src/pointer/cursor/CursorShapeOverrideController.hpp>
#include <hyprland/src/protocols/core/Compositor.hpp>
#include <hyprland/src/protocols/types/DataDevice.hpp>
#include <hyprutils/os/FileDescriptor.hpp>
#include <hyprutils/string/VarList.hpp>

// The drag state (m_dnd) and the hooked functions are private members.
#define private public
#include <hyprland/src/protocols/core/DataDevice.hpp>
#undef private

#include "Pile.hpp"
#include "globals.hpp"

APICALL EXPORT std::string PLUGIN_API_VERSION() {
    return HYPRLAND_API_VERSION;
}

using namespace Hyprutils::OS;

typedef void (*FInitiateDrag)(CWLDataDeviceProtocol*, WP<CWLDataSourceResource>, SP<CWLSurfaceResource>, SP<CWLSurfaceResource>);
typedef void (*FRenderDND)(CWLDataDeviceProtocol*, PHLMONITOR, const Time::steady_tp&);
typedef void (*FVoid)(CWLDataDeviceProtocol*);

static struct {
    CFunctionHook* initiate = nullptr;
    CFunctionHook* render   = nullptr;
    CFunctionHook* drop     = nullptr;
    CFunctionHook* abort    = nullptr;
} g_hooks;

// One drag at a time, as the protocol allows.
static bool g_dragActive = false;
static bool g_demo       = false;

static struct {
    int              fd    = -1;
    wl_event_source* src   = nullptr;
    wl_event_source* timer = nullptr;
    std::string      buf;
} g_read;

static wl_event_source* g_demoTimer = nullptr;

static void             postEvent(const std::string& name, const std::string& data) {
    if (g_pEventManager)
        g_pEventManager->postEvent(SHyprIPCEvent{name, data});
}

static void cancelRead() {
    if (g_read.src)
        wl_event_source_remove(g_read.src);
    if (g_read.timer)
        wl_event_source_remove(g_read.timer);
    if (g_read.fd >= 0)
        close(g_read.fd);
    g_read = {};
}

// text/uri-list: one URI per line, CRLF by the spec but LF in practice, '#' starts a comment.
// Only local files make a pile; a drag of web links keeps the client's own icon.
static std::vector<std::string> localPaths(const std::string& list) {
    std::vector<std::string> out;
    size_t                   start = 0;
    while (start < list.size()) {
        size_t end = list.find('\n', start);
        if (end == std::string::npos)
            end = list.size();
        std::string line = list.substr(start, end - start);
        start            = end + 1;

        while (!line.empty() && (line.back() == '\r' || line.back() == '\0' || line.back() == ' '))
            line.pop_back();
        if (line.empty() || line[0] == '#')
            continue;

        gchar* host = nullptr;
        gchar* path = g_filename_from_uri(line.c_str(), &host, nullptr);
        if (path && (!host || std::string_view{host} == "localhost"))
            out.emplace_back(path);
        g_free(path);
        g_free(host);
    }
    return out;
}

static void finishRead() {
    std::string list = std::move(g_read.buf);
    cancelRead();
    if (!g_dragActive)
        return;

    auto paths = localPaths(list);
    postEvent("dragstart", std::to_string(paths.size()));
    if (paths.empty())
        g_pPile->abandon();
    else
        g_pPile->begin(std::move(paths));
}

static int onUriReadable(int fd, uint32_t mask, void*) {
    char buf[4096];
    while (true) {
        const ssize_t n = read(fd, buf, sizeof(buf));
        if (n > 0) {
            g_read.buf.append(buf, n);
            if (g_read.buf.size() > (1u << 20)) {
                finishRead();
                return 0;
            }
            continue;
        }
        if (n < 0 && (errno == EAGAIN || errno == EWOULDBLOCK) && !(mask & WL_EVENT_HANGUP))
            return 0;
        if (n < 0 && errno == EINTR)
            continue;
        finishRead();
        return 0;
    }
}

static int onUriTimeout(void*) {
    finishRead();
    return 0;
}

static void startRead(const SP<IDataSource>& source) {
    cancelRead();
    int fds[2];
    if (pipe2(fds, O_CLOEXEC | O_NONBLOCK) != 0) {
        g_pPile->abandon();
        return;
    }
    // The source writes the list into the pipe and closes it, exactly as for a drop target.
    source->send("text/uri-list", CFileDescriptor{fds[1]});
    g_read.fd    = fds[0];
    g_read.src   = wl_event_loop_add_fd(g_pCompositor->m_wlEventLoop, fds[0], WL_EVENT_READABLE, onUriReadable, nullptr);
    g_read.timer = wl_event_loop_add_timer(g_pCompositor->m_wlEventLoop, onUriTimeout, nullptr);
    wl_event_source_timer_update(g_read.timer, 1500);
}

static void endDrag(bool dropped) {
    if (!g_dragActive || !g_pPile)
        return;
    g_dragActive = false;
    cancelRead();
    g_pPile->end(dropped);
    postEvent("dragend", dropped ? "dropped" : "cancelled");
}

static void stopDemo() {
    if (g_demoTimer)
        wl_event_source_remove(g_demoTimer);
    g_demoTimer = nullptr;
    g_demo      = false;
}

static void hkInitiateDrag(CWLDataDeviceProtocol* self, WP<CWLDataSourceResource> source, SP<CWLSurfaceResource> icon, SP<CWLSurfaceResource> origin) {
    ((FInitiateDrag)g_hooks.initiate->m_original)(self, source, icon, origin);

    if (!self->dndActive() || !g_pPile)
        return;

    if (g_demo) {
        stopDemo();
        g_pPile->abandon();
    }

    g_dragActive = true;

    if (const auto shape = g_config.cursor->value(); !shape.empty())
        Pointer::Cursor::overrideController->setOverride(shape, Pointer::Cursor::CURSOR_OVERRIDE_DND);

    const auto src     = source.lock();
    const auto mimes   = src ? src->mimes() : std::vector<std::string>{};
    const bool hasUris = std::ranges::find(mimes, "text/uri-list") != mimes.end();
    // Chromium drags a tab out of its strip as a system drag carrying only this type, with a
    // preview of the tab as the icon. That icon becomes a single card on the pile's springs.
    const bool isTab = std::ranges::find(mimes, "chromium/x-window-drag") != mimes.end();

    if (src && isTab && icon && g_config.enabled->value() && g_config.tabDrags->value()) {
        postEvent("dragstart", "0");
        g_pPile->beginIcon(icon);
        return;
    }

    if (!src || !hasUris || !g_config.enabled->value()) {
        postEvent("dragstart", "0");
        return;
    }

    g_pPile->pending();
    startRead(src);
}

static void hkRenderDND(CWLDataDeviceProtocol* self, PHLMONITOR monitor, const Time::steady_tp& when) {
    if (!g_pPile) {
        ((FRenderDND)g_hooks.render->m_original)(self, monitor, when);
        return;
    }

    // A drop the hooks somehow missed still ends the pile.
    if (g_dragActive && !self->dndActive())
        endDrag(true);

    if (g_pPile->hidesClientIcon()) {
        // Keep the hidden icon's frame callbacks coming, or animated icons stall their client.
        if (const auto surf = self->m_dnd.dndSurface.lock(); surf && surf->m_current.texture)
            surf->frame(when);
    } else
        ((FRenderDND)g_hooks.render->m_original)(self, monitor, when);

    g_pPile->render(monitor);
}

static void hkDropDrag(CWLDataDeviceProtocol* self) {
    ((FVoid)g_hooks.drop->m_original)(self);
    // An unsuccessful drop goes through abortDrag, which has already ended the drag as a cancel.
    endDrag(true);
}

static void hkAbortDrag(CWLDataDeviceProtocol* self) {
    endDrag(false);
    ((FVoid)g_hooks.abort->m_original)(self);
}

static int onDemoTimeout(void*) {
    stopDemo();
    g_pPile->end(false);
    return 0;
}

// hyprctl dragpile                      the pile's state, as JSON
// hyprctl dragpile demo <path> ...      a pile without a drag, for tuning; ends by itself
// hyprctl dragpile end drop|cancel      end a demo pile now
static std::string onHyprctl(eHyprCtlOutputFormat, std::string request) {
    Hyprutils::String::CVarList args(request, 0, ' ');
    const std::string           verb = args.size() > 1 ? args[1] : "";

    if (verb.empty() || verb == "state")
        return g_pPile->describe();

    if (verb == "demo") {
        if (g_dragActive)
            return "error: a real drag is in progress";
        std::vector<std::string> paths;
        for (size_t i = 2; i < args.size(); ++i) {
            if (!args[i].empty())
                paths.emplace_back(args[i]);
        }
        if (paths.empty())
            return "error: give at least one path";
        stopDemo();
        g_demo = true;
        g_pPile->pending();
        g_pPile->begin(std::move(paths));
        g_demoTimer = wl_event_loop_add_timer(g_pCompositor->m_wlEventLoop, onDemoTimeout, nullptr);
        wl_event_source_timer_update(g_demoTimer, 6000);
        return "ok";
    }

    if (verb == "end") {
        if (!g_demo)
            return "error: no demo pile";
        stopDemo();
        g_pPile->end(args.size() > 2 && args[2] == "drop");
        return "ok";
    }

    return "error: unknown request; use state, demo <paths...> or end drop|cancel";
}

static CFunctionHook* hookByName(const std::string& name, void* destination) {
    for (const auto& match : HyprlandAPI::findFunctionsByName(PHANDLE, name)) {
        if (match.demangled.find("CWLDataDeviceProtocol::" + name + "(") == std::string::npos)
            continue;
        return HyprlandAPI::createFunctionHook(PHANDLE, match.address, destination);
    }
    return nullptr;
}

template <typename T>
static void addValue(SP<T>& slot, SP<T> value) {
    slot = std::move(value);
    HyprlandAPI::addConfigValueV2(PHANDLE, slot);
}

static void registerConfig() {
    using namespace Config::Values;
    auto& c = g_config;
    addValue(c.enabled, makeShared<CBoolValue>("plugin:dragpile:enabled", "Draw a pile of cards for file drags", true));
    addValue(c.physics, makeShared<CBoolValue>("plugin:dragpile:physics", "Animate the pile with springs; off snaps it to the cursor", true));
    addValue(c.thumbnails, makeShared<CBoolValue>("plugin:dragpile:thumbnails", "Use thumbnails and image previews where available", true));
    addValue(c.tabDrags, makeShared<CBoolValue>("plugin:dragpile:tab_drags", "Draw a browser tab drag's preview as a card on the pile's springs", true));
    addValue(c.cardSize, makeShared<CIntValue>("plugin:dragpile:card_size", "Card edge, in logical px", 46));
    addValue(c.cardRadius, makeShared<CIntValue>("plugin:dragpile:card_radius", "Card corner radius", 10));
    addValue(c.maxCards, makeShared<CIntValue>("plugin:dragpile:max_cards", "Most cards drawn; the badge carries the full count", 5));
    addValue(c.glyphSize, makeShared<CIntValue>("plugin:dragpile:glyph_size", "File-type glyph edge", 22));
    addValue(c.badgeSize, makeShared<CIntValue>("plugin:dragpile:badge_size", "Count badge diameter", 20));
    addValue(c.badgeFontSize, makeShared<CIntValue>("plugin:dragpile:badge_font_size", "Count text size, in px", 11));
    addValue(c.thumbnailMaxMb, makeShared<CIntValue>("plugin:dragpile:thumbnail_max_mb", "Largest image decoded directly when no cached thumbnail exists", 64));
    addValue(c.offsetX, makeShared<CFloatValue>("plugin:dragpile:offset_x", "Front card's left edge, right of the pointer's tip", 9.F));
    addValue(c.offsetY, makeShared<CFloatValue>("plugin:dragpile:offset_y", "Front card's top edge, below the pointer's tip", 21.5F));
    addValue(c.stiffness, makeShared<CFloatValue>("plugin:dragpile:stiffness", "Front card's spring stiffness", 800.F));
    addValue(c.damping, makeShared<CFloatValue>("plugin:dragpile:damping", "Damping ratio; below 1 overshoots", 0.68F));
    addValue(c.followFalloff, makeShared<CFloatValue>("plugin:dragpile:follow_falloff", "Stiffness kept by each card further back", 0.85F));
    addValue(c.maxStretch, makeShared<CFloatValue>("plugin:dragpile:max_stretch", "Furthest a card trails its place in the pile, in px", 22.F));
    addValue(c.tiltMax, makeShared<CFloatValue>("plugin:dragpile:tilt_max", "Largest swing from motion, in degrees", 9.F));
    addValue(c.tiltLean, makeShared<CFloatValue>("plugin:dragpile:tilt_lean", "Degrees of swing per px/s of speed", 0.0055F));
    addValue(c.tiltStiffness, makeShared<CFloatValue>("plugin:dragpile:tilt_stiffness", "Swing spring stiffness", 180.F));
    addValue(c.tiltDamping, makeShared<CFloatValue>("plugin:dragpile:tilt_damping", "Swing damping ratio", 0.45F));
    addValue(c.glyphStroke, makeShared<CFloatValue>("plugin:dragpile:glyph_stroke", "Glyph stroke width at glyph size", 1.6F));
    addValue(c.badgeFont, makeShared<CStringValue>("plugin:dragpile:badge_font", "Count font family", "Inter"));
    addValue(c.cursor, makeShared<CStringValue>("plugin:dragpile:cursor", "Cursor shape during a drag, e.g. default; empty keeps Hyprland's", ""));
    // Defaults are board 16d (Ariadne); a theme should set its own.
    addValue(c.colCard, makeShared<CColorValue>("plugin:dragpile:col.card", "Card fill", 0xff1e1c1a));
    addValue(c.colBorder, makeShared<CColorValue>("plugin:dragpile:col.border", "Card hairline", 0x38e6e4de));
    addValue(c.colBadge, makeShared<CColorValue>("plugin:dragpile:col.badge", "Count badge fill", 0xff3eddb8));
    addValue(c.colBadgeRing, makeShared<CColorValue>("plugin:dragpile:col.badge_ring", "Ring around the badge", 0xff0a0a0a));
    addValue(c.colBadgeText, makeShared<CColorValue>("plugin:dragpile:col.badge_text", "Count text", 0xff002018));
    addValue(c.colGlyph, makeShared<CColorValue>("plugin:dragpile:col.glyph", "Glyph for plain files and text", 0xff8a8a86));
    addValue(c.colGlyphFolder, makeShared<CColorValue>("plugin:dragpile:col.glyph_folder", "Folder glyph", 0xff3eddb8));
    addValue(c.colGlyphImage, makeShared<CColorValue>("plugin:dragpile:col.glyph_image", "Image glyph, before its preview loads", 0xff7cc4c0));
    addValue(c.colGlyphPdf, makeShared<CColorValue>("plugin:dragpile:col.glyph_pdf", "PDF glyph", 0xffe0563b));
    addValue(c.colGlyphArchive, makeShared<CColorValue>("plugin:dragpile:col.glyph_archive", "Archive glyph", 0xffd99f66));
    addValue(c.colGlyphAudio, makeShared<CColorValue>("plugin:dragpile:col.glyph_audio", "Audio glyph", 0xffd8a8bc));
    addValue(c.colGlyphVideo, makeShared<CColorValue>("plugin:dragpile:col.glyph_video", "Video glyph", 0xff8c94a9));
}

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    PHANDLE = handle;

    if (std::string{__hyprland_api_get_hash()} != __hyprland_api_get_client_hash()) {
        HyprlandAPI::addNotification(PHANDLE, "[dragpile] Built against different Hyprland headers; not loading", CHyprColor{1.0, 0.2, 0.2, 1.0}, 5000);
        throw std::runtime_error("[dragpile] version mismatch");
    }

    registerConfig();

    g_hooks.initiate = hookByName("initiateDrag", (void*)&hkInitiateDrag);
    g_hooks.render   = hookByName("renderDND", (void*)&hkRenderDND);
    g_hooks.drop     = hookByName("dropDrag", (void*)&hkDropDrag);
    g_hooks.abort    = hookByName("abortDrag", (void*)&hkAbortDrag);
    if (!g_hooks.initiate || !g_hooks.render || !g_hooks.drop || !g_hooks.abort) {
        HyprlandAPI::addNotification(PHANDLE, "[dragpile] Could not find Hyprland's drag functions; not loading", CHyprColor{1.0, 0.2, 0.2, 1.0}, 5000);
        throw std::runtime_error("[dragpile] hook targets missing");
    }

    g_pPile           = makeUnique<CPile>();
    g_pPile->m_cursor = [] {
        if (PROTO::data && PROTO::data->m_dnd.touchPos)
            return *PROTO::data->m_dnd.touchPos;
        return g_pInputManager->getMouseCoordsInternal();
    };

    // The pointer moving is what keeps frames coming while the pile chases it.
    static auto P1 = Event::bus()->m_events.input.mouse.move.listen([](Vector2D, Event::SCallbackInfo&) {
        if (g_pPile && !g_pPile->idle())
            g_pPile->poke();
    });
    static auto P2 = Event::bus()->m_events.input.touch.motion.listen([](ITouch::SMotionEvent, Event::SCallbackInfo&) {
        if (g_pPile && !g_pPile->idle())
            g_pPile->poke();
    });

    bool hooked = g_hooks.initiate->hook() && g_hooks.render->hook() && g_hooks.drop->hook() && g_hooks.abort->hook();
    if (!hooked) {
        HyprlandAPI::addNotification(PHANDLE, "[dragpile] Hooking failed; not loading", CHyprColor{1.0, 0.2, 0.2, 1.0}, 5000);
        throw std::runtime_error("[dragpile] hook failed");
    }

    HyprlandAPI::registerHyprCtlCommand(PHANDLE, SHyprCtlCommand{.name = "dragpile", .exact = false, .fn = onHyprctl});

    HyprlandAPI::reloadConfig();

    return {"dragpile", "A cursor-chasing pile of file cards for every drag and drop", "Ryan Navsaria", "0.1"};
}

APICALL EXPORT void PLUGIN_EXIT() {
    stopDemo();
    cancelRead();
    g_pPile.reset();
}
