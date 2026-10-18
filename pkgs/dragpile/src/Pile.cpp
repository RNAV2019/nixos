#include "Pile.hpp"
#include "globals.hpp"

#include <algorithm>
#include <cmath>
#include <format>

#include <hyprland/src/Compositor.hpp>
#include <hyprland/src/output/Monitor.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include <hyprland/src/render/pass/TexPassElement.hpp>
#include <hyprland/src/state/MonitorState.hpp>

#include <pango/pangocairo.h>

using namespace std::chrono_literals;

// Resting layout by depth, front card first, as board 16d sets three of them out: the card
// directly behind leans left, the next one right. Depths past the board's alternate outward.
struct SRest {
    double x, y, ang;
};
static constexpr SRest REST[] = {
    {0, 0, 0}, {-18, 6, -11}, {16, 4, 12}, {5, 9, 5}, {-9, -3, -6},
};

// A stable per-file wobble on the resting layout, so a pile looks tossed together rather than
// stamped, yet never reshuffles while it is being dragged.
static double jitter(const std::string& path, int salt) {
    const size_t h = std::hash<std::string>{}(path + char('a' + salt));
    return ((h % 2001) / 1000.0) - 1.0;
}

static SRest restFor(size_t depth, const std::string& path) {
    SRest r;
    if (depth < std::size(REST))
        r = REST[depth];
    else {
        const double side = depth % 2 ? -1 : 1;
        r                 = {side * (8 + 3.0 * (depth % 3)), 2.0 + 2.0 * (depth % 4), side * (4 + depth % 5)};
    }
    if (depth > 0) {
        r.x += 2 * jitter(path, 0);
        r.y += 2 * jitter(path, 1);
        r.ang += 2 * jitter(path, 2);
    }
    return r;
}

// One semi-implicit spring step toward `target`; damping is the ratio to critical.
static void spring(double& x, double& v, double target, double k, double zeta, double h) {
    const double c = 2 * zeta * std::sqrt(k);
    v += (k * (target - x) - c * v) * h;
    x += v * h;
}

static uint32_t color(const SP<Config::Values::CColorValue>& v) {
    return (uint32_t)v->value();
}

int onWorkerReady(int fd, uint32_t mask, void* data) {
    auto* pile = (CPile*)data;
    for (auto& r : pile->m_worker->takeResults())
        pile->m_ready.emplace_back(r);
    pile->poke();
    return 0;
}

CPile::CPile() {
    m_worker       = makeUnique<CCardWorker>();
    m_workerSource = wl_event_loop_add_fd(g_pCompositor->m_wlEventLoop, m_worker->eventFd(), WL_EVENT_READABLE, onWorkerReady, this);
}

CPile::~CPile() {
    if (m_workerSource)
        wl_event_source_remove(m_workerSource);
    for (auto& r : m_ready)
        cairo_surface_destroy(r.surface);
    m_worker.reset();
}

void CPile::setState(eState s) {
    m_state   = s;
    m_since   = Clock::now();
    m_settled = false;
}

double CPile::stateAge() const {
    return std::chrono::duration<double>(Clock::now() - m_since).count();
}

bool CPile::idle() const {
    return m_state == STATE_IDLE;
}

bool CPile::hidesClientIcon() const {
    // Hold the client's own icon back briefly while the list is read, so it never flashes up
    // under the pile; a source that takes longer than that gets its icon back until it answers.
    if (m_state == STATE_PENDING)
        return stateAge() < 0.2;
    return m_state == STATE_LIVE;
}

void CPile::reset() {
    m_cards.clear();
    m_badgeTex.reset();
    m_badgeCount = 0;
    m_count      = 0;
    m_lastStep.reset();
    m_lastExtents = {};
    for (auto& r : m_ready)
        cairo_surface_destroy(r.surface);
    m_ready.clear();
}

void CPile::pending() {
    if (m_state != STATE_IDLE) {
        damage(m_lastExtents);
        reset();
    }
    m_worker->dropQueued();
    setState(STATE_PENDING);
}

void CPile::abandon() {
    m_worker->dropQueued();
    damage(m_lastExtents);
    reset();
    setState(STATE_IDLE);
}

void CPile::begin(std::vector<std::string>&& paths) {
    if (paths.empty()) {
        abandon();
        return;
    }

    if (m_state != STATE_IDLE && m_state != STATE_PENDING) {
        damage(m_lastExtents);
        reset();
    }

    m_drag++;
    m_count = paths.size();

    double scale = 1;
    for (const auto& m : State::monitorState()->monitors())
        scale = std::max(scale, (double)m->m_scale);

    m_style.size        = g_config.cardSize->value();
    m_style.radius      = g_config.cardRadius->value();
    m_style.scale       = scale;
    m_style.glyphSize   = g_config.glyphSize->value();
    m_style.glyphStroke = g_config.glyphStroke->value();
    m_style.card        = color(g_config.colCard);
    m_style.border      = color(g_config.colBorder);
    m_style.thumbnails  = g_config.thumbnails->value();
    m_style.maxDecodeBytes          = (int64_t)g_config.thumbnailMaxMb->value() << 20;
    m_style.glyph.fill(color(g_config.colGlyph));
    m_style.glyph[KIND_DIR]     = color(g_config.colGlyphFolder);
    m_style.glyph[KIND_IMAGE]   = color(g_config.colGlyphImage);
    m_style.glyph[KIND_PDF]     = color(g_config.colGlyphPdf);
    m_style.glyph[KIND_ARCHIVE] = color(g_config.colGlyphArchive);
    m_style.glyph[KIND_AUDIO]   = color(g_config.colGlyphAudio);
    m_style.glyph[KIND_VIDEO]   = color(g_config.colGlyphVideo);

    const size_t visible = std::min(paths.size(), (size_t)std::max<int64_t>(1, g_config.maxCards->value()));
    const auto   cursor  = m_cursor();

    m_flipX = m_flipY = false;
    updateFlip(cursor);
    m_home = frontTarget(cursor);

    m_cards.clear();
    std::vector<SCardJob> jobs;
    for (size_t i = 0; i < visible; ++i) {
        SCard c;
        c.path         = paths[i];
        c.kind         = classify(paths[i]);
        const auto r   = restFor(i, paths[i]);
        c.restOff      = {r.x, r.y};
        c.restAng      = r.ang;
        c.pos          = m_home;
        jobs.push_back({m_drag, i, c.path, c.kind, m_style});
        m_cards.emplace_back(std::move(c));
    }
    m_worker->submit(std::move(jobs));

    m_scale      = 0.6;
    m_scaleVel   = 0;
    m_alpha      = 0;
    m_badgeScale = 0.6;
    m_badgeVel   = 0;
    m_lastStep.reset();
    setState(STATE_LIVE);
    poke();
}

void CPile::end(bool dropped) {
    if (m_state == STATE_PENDING || (m_state == STATE_LIVE && m_alpha <= 0)) {
        abandon();
        return;
    }
    if (m_state != STATE_LIVE)
        return;
    setState(dropped ? STATE_DROPPED : STATE_CANCELLED);
    poke();
}

// Swap the pile to the pointer's other side when it would leave the monitor under the pointer,
// and back once it fits again with room to spare, so it never flickers at the threshold.
void CPile::updateFlip(const Vector2D& cursor) {
    PHLMONITOR mon;
    for (const auto& m : State::monitorState()->monitors()) {
        if (CBox{m->m_position, m->m_size}.containsPoint(cursor)) {
            mon = m;
            break;
        }
    }
    if (!mon)
        return;

    const double margin = 12, hysteresis = 32;
    const double right  = mon->m_position.x + mon->m_size.x - margin;
    const double bottom = mon->m_position.y + mon->m_size.y - margin;
    const double reachX = cursor.x + g_config.offsetX->value() + m_style.size + 20;
    const double reachY = cursor.y + g_config.offsetY->value() + m_style.size + 12;

    if (!m_flipX && reachX > right)
        m_flipX = true;
    else if (m_flipX && reachX + hysteresis < right)
        m_flipX = false;

    if (!m_flipY && reachY > bottom)
        m_flipY = true;
    else if (m_flipY && reachY + hysteresis < bottom)
        m_flipY = false;
}

Vector2D CPile::frontTarget(const Vector2D& cursor) {
    // Board 16d: the front card's top-left sits (9, 21.5) from the arrow's tip. Near the right
    // or bottom edge the pile swaps to the other side of the pointer instead of leaving the screen.
    const double half = m_style.size / 2.0;
    const double dx   = g_config.offsetX->value() + half;
    const double dy   = g_config.offsetY->value() + half;
    return {cursor.x + (m_flipX ? -dx : dx), cursor.y + (m_flipY ? -dy : dy)};
}

void CPile::uploadResults() {
    for (auto& r : m_ready) {
        if (r.drag == m_drag && r.index < m_cards.size() && (r.thumbnail || !m_cards[r.index].thumbnail)) {
            m_cards[r.index].tex       = g_pHyprRenderer->createTexture(r.surface);
            m_cards[r.index].thumbnail = r.thumbnail;
        }
        cairo_surface_destroy(r.surface);
    }
    m_ready.clear();
}

void CPile::rebuildBadge() {
    m_badgeCount = m_count;
    m_badgeTex.reset();
    if (m_count < 2)
        return;

    const std::string text  = m_count > 99 ? "99+" : std::to_string(m_count);
    const double      S     = m_style.scale;
    const double      h     = g_config.badgeSize->value();
    const double      ring  = 2;

    auto*             probe = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, 1, 1);
    auto*             pcr   = cairo_create(probe);
    PangoLayout*      layout = pango_cairo_create_layout(pcr);
    auto*             font   = pango_font_description_from_string(g_config.badgeFont->value().c_str());
    pango_font_description_set_weight(font, PANGO_WEIGHT_BOLD);
    pango_font_description_set_absolute_size(font, g_config.badgeFontSize->value() * PANGO_SCALE);
    pango_layout_set_font_description(layout, font);
    pango_layout_set_text(layout, text.c_str(), -1);
    PangoRectangle ink, logical;
    pango_layout_get_pixel_extents(layout, &ink, &logical);

    const double w     = std::max(h, (double)logical.width + 12);
    m_badgeSize        = {w + 2 * ring, h + 2 * ring};
    const double fullW = m_badgeSize.x + 2 * CARD_PAD, fullH = m_badgeSize.y + 2 * CARD_PAD;

    auto*        surf = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, std::ceil(fullW * S), std::ceil(fullH * S));
    auto*        cr   = cairo_create(surf);
    cairo_scale(cr, S, S);
    cairo_translate(cr, CARD_PAD + ring, CARD_PAD + ring);

    auto stadium = [&](double inset) {
        const double r = h / 2.0 + inset;
        cairo_new_sub_path(cr);
        cairo_arc(cr, w - h / 2.0, h / 2.0, r, -M_PI / 2, M_PI / 2);
        cairo_arc(cr, h / 2.0, h / 2.0, r, M_PI / 2, 3 * M_PI / 2);
        cairo_close_path(cr);
    };

    // The ring is the surface colour, so the badge reads as cut out of whatever is behind it.
    const auto rgba = [&](uint32_t c) { cairo_set_source_rgba(cr, ((c >> 16) & 0xff) / 255.0, ((c >> 8) & 0xff) / 255.0, (c & 0xff) / 255.0, ((c >> 24) & 0xff) / 255.0); };
    stadium(ring);
    rgba(color(g_config.colBadgeRing));
    cairo_fill(cr);
    stadium(0);
    rgba(color(g_config.colBadge));
    cairo_fill(cr);

    pango_cairo_update_layout(cr, layout);
    pango_layout_get_pixel_extents(layout, &ink, &logical);
    rgba(color(g_config.colBadgeText));
    // Centre on the ink, not the line box, so digits sit optically centred like the board's.
    cairo_move_to(cr, (w - ink.width) / 2.0 - ink.x, (h - ink.height) / 2.0 - ink.y);
    pango_cairo_show_layout(cr, layout);

    cairo_destroy(cr);
    cairo_surface_flush(surf);
    m_badgeTex = g_pHyprRenderer->createTexture(surf);
    cairo_surface_destroy(surf);

    pango_font_description_free(font);
    g_object_unref(layout);
    cairo_destroy(pcr);
    cairo_surface_destroy(probe);

    m_badgeScale = 0.6;
}

void CPile::integrate(double dt) {
    const bool   physics = g_config.physics->value();
    const auto   cursor  = m_cursor();
    const double age     = stateAge();

    // Pose targets for this state.
    Vector2D     front;
    double       scaleTarget = 1;
    bool         converge    = false;
    if (m_state == STATE_LIVE) {
        updateFlip(cursor);
        front = frontTarget(cursor);
        if (m_alpha < 1 && m_cards.front().tex)
            m_alpha = std::min(1.0, m_alpha + dt / 0.09);
    } else if (m_state == STATE_DROPPED) {
        front       = cursor;
        scaleTarget = 0.35;
        converge    = true;
        m_alpha     = std::max(0.0, m_alpha - dt / 0.16);
    } else {
        front = m_home;
        if (age > 0.24)
            m_alpha = std::max(0.0, m_alpha - dt / 0.14);
    }

    const double k       = g_config.stiffness->value();
    const double zeta    = g_config.damping->value();
    const double falloff = g_config.followFalloff->value();
    const double tk      = g_config.tiltStiffness->value();
    const double tz      = g_config.tiltDamping->value();
    const double tMax    = g_config.tiltMax->value();
    const double lean    = g_config.tiltLean->value();
    const double stretch = g_config.maxStretch->value() * m_scale;
    const double sx = m_flipX ? -1 : 1, sy = m_flipY ? -1 : 1;

    if (!physics) {
        m_scale = scaleTarget;
        for (size_t d = 0; d < m_cards.size(); ++d) {
            auto& c = m_cards[d];
            c.pos   = converge || d == 0 ? front : m_cards[0].pos + c.restOff * m_scale;
            c.vel   = {};
            c.ang   = c.restAng;
        }
        m_badgeScale = 1;
        return;
    }

    // Fixed 4 ms sub-steps keep the springs stable through a long frame.
    double left = std::min(dt, 0.1);
    while (left > 0) {
        const double h = std::min(0.004, left);
        left -= h;

        spring(m_scale, m_scaleVel, scaleTarget, 420, 0.62, h);
        spring(m_badgeScale, m_badgeVel, 1, 520, 0.5, h);

        for (size_t d = 0; d < m_cards.size(); ++d) {
            auto&    c = m_cards[d];

            Vector2D target;
            if (d == 0 || converge)
                target = front;
            else {
                // Each card chases the one in front of it, holding its resting offset, so a
                // fast move strings the pile out and it gathers back up as the pointer slows.
                const auto& ahead = m_cards[d - 1];
                target            = ahead.pos + (c.restOff - ahead.restOff) * m_scale;

                // Cards leave the stack one after another as the pile fans out.
                if (m_state == STATE_LIVE && age < 0.03 * d) {
                    c.pos = ahead.pos;
                    c.vel = ahead.vel;
                    continue;
                }
            }

            const double kd = k * std::pow(falloff, (double)d);
            spring(c.pos.x, c.vel.x, target.x, kd, zeta, h);
            spring(c.pos.y, c.vel.y, target.y, kd, zeta, h);

            // A rope, not just a spring: a card may trail its place by so much and no further, so
            // a fast fling stretches the pile without scattering it. The outward part of its
            // velocity is dropped at the limit, as a taut string would.
            if (d > 0 && !converge && stretch > 0) {
                const Vector2D off = c.pos - target;
                const double   len = off.size();
                if (len > stretch) {
                    const Vector2D dir = off / len;
                    c.pos              = target + dir * stretch;
                    const double out   = c.vel.x * dir.x + c.vel.y * dir.y;
                    if (out > 0)
                        c.vel = c.vel - dir * out;
                }
            }

            // Held by the corner nearest the pointer, a card swings against its travel: moving
            // right turns it clockwise, moving down turns it back.
            const double swing = std::clamp(lean * (sy * c.vel.x - sx * c.vel.y), -tMax, tMax);
            const double angT  = (converge ? c.restAng * 0.5 : c.restAng) + swing;
            spring(c.ang, c.angVel, angT, tk, tz, h);
        }
    }
}

void CPile::advance() {
    const auto now = Clock::now();
    if (m_lastStep && now - *m_lastStep < 500us)
        return;

    const double dt = m_lastStep ? std::chrono::duration<double>(now - *m_lastStep).count() : 0;
    m_lastStep      = now;

    uploadResults();
    if (m_state == STATE_LIVE && m_badgeCount != m_count)
        rebuildBadge();

    if (!m_cards.empty())
        integrate(dt);

    if ((m_state == STATE_DROPPED || m_state == STATE_CANCELLED) && m_alpha <= 0) {
        damage(m_lastExtents);
        reset();
        setState(STATE_IDLE);
        return;
    }

    const CBox box = extents();

    bool       settled = std::abs(m_scale - (m_state == STATE_DROPPED ? 0.35 : 1)) < 0.001 && std::abs(m_scaleVel) < 0.01 && std::abs(m_badgeScale - 1) < 0.001 &&
        std::abs(m_badgeVel) < 0.01 && (m_alpha >= 1 || m_alpha <= 0);
    for (const auto& c : m_cards)
        settled = settled && std::abs(c.vel.x) < 0.5 && std::abs(c.vel.y) < 0.5 && std::abs(c.angVel) < 0.05;

    if (!settled || box != m_lastExtents) {
        CBox both = m_lastExtents.empty() ? box : CBox{std::min(box.x, m_lastExtents.x), std::min(box.y, m_lastExtents.y),
                                                      std::max(box.x + box.w, m_lastExtents.x + m_lastExtents.w) - std::min(box.x, m_lastExtents.x),
                                                      std::max(box.y + box.h, m_lastExtents.y + m_lastExtents.h) - std::min(box.y, m_lastExtents.y)};
        damage(both);
    }
    m_lastExtents = box;
    m_settled     = settled;
}

CBox CPile::extents() const {
    double x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
    auto   add = [&](const Vector2D& c, double half) {
        x0 = std::min(x0, c.x - half);
        y0 = std::min(y0, c.y - half);
        x1 = std::max(x1, c.x + half);
        y1 = std::max(y1, c.y + half);
    };
    const double full = (m_style.size + 2 * CARD_PAD) * m_scale;
    for (const auto& c : m_cards) {
        const double a = c.ang * M_PI / 180.0;
        add(c.pos, full / 2.0 * (std::abs(std::cos(a)) + std::abs(std::sin(a))));
    }
    if (!m_cards.empty() && m_badgeTex) {
        // The badge rides the front card's top-right corner; cover it generously.
        add(m_cards.front().pos, full / 2.0 * 1.42 + std::max(m_badgeSize.x, m_badgeSize.y) * m_scale);
    }
    if (x1 < x0)
        return {};
    return CBox{x0, y0, x1 - x0, y1 - y0}.expand(2);
}

void CPile::damage(const CBox& box) {
    if (box.empty() || !g_pHyprRenderer)
        return;
    g_pHyprRenderer->damageBox(box);
}

void CPile::poke() {
    if (m_state == STATE_IDLE)
        return;
    m_settled = false;
    if (!m_lastExtents.empty())
        damage(m_lastExtents);
    else if (m_cursor) {
        const auto c = m_cursor();
        damage(CBox{c.x - 160, c.y - 160, 320, 320});
    }
}

static double toBoxRot(double clockwiseDeg) {
    return clockwiseDeg * M_PI / 180.0;
}

void CPile::render(PHLMONITOR monitor) {
    if (m_state == STATE_IDLE || m_state == STATE_PENDING || !monitor)
        return;

    advance();
    if (m_state == STATE_IDLE || m_alpha <= 0 || m_cards.empty())
        return;

    const double full = (m_style.size + 2 * CARD_PAD) * m_scale;

    auto         draw = [&](const SP<Render::ITexture>& tex, const Vector2D& centre, const Vector2D& size, double ang) {
        CBox box = CBox{centre.x - size.x / 2.0, centre.y - size.y / 2.0, size.x, size.y}.translate(-monitor->m_position).scale(monitor->m_scale);
        box.x    = std::round(box.x);
        box.y    = std::round(box.y);
        box.rot  = toBoxRot(ang);

        CTexPassElement::SRenderData data;
        data.tex = tex;
        data.box = box;
        data.a   = m_alpha;
        g_pHyprRenderer->m_renderPass.add(makeUnique<CTexPassElement>(std::move(data)));
    };

    for (size_t i = m_cards.size(); i-- > 0;) {
        const auto& c = m_cards[i];
        if (c.tex)
            draw(c.tex, c.pos, {full, full}, c.ang);
    }

    if (m_badgeTex && m_cards.front().tex) {
        // Board 16d: the badge's centre is the front card's top-right corner, 2 px down.
        const auto&  f    = m_cards.front();
        const double a    = f.ang * M_PI / 180.0;
        const double half = m_style.size / 2.0 * m_scale;
        // Distance from the corner to the badge's middle on its long side, so a wide "12" grows inward.
        const double lx = half - (m_badgeSize.x - m_badgeSize.y) / 2.0 * m_scale, ly = -half + 2 * m_scale;
        const Vector2D centre = f.pos + Vector2D{lx * std::cos(a) - ly * std::sin(a), lx * std::sin(a) + ly * std::cos(a)};
        const double   bs     = m_scale * m_badgeScale;
        draw(m_badgeTex, centre, {(m_badgeSize.x + 2 * CARD_PAD) * bs, (m_badgeSize.y + 2 * CARD_PAD) * bs}, f.ang);
    }
}

std::string CPile::describe() const {
    static constexpr const char* NAMES[] = {"idle", "pending", "live", "dropped", "cancelled"};
    std::string                  paths;
    for (const auto& c : m_cards) {
        std::string esc;
        for (char ch : c.path) {
            if (ch == '"' || ch == '\\')
                esc += '\\';
            esc += ch;
        }
        paths += std::format("{}\"{}\"", paths.empty() ? "" : ",", esc);
    }
    return std::format(R"({{"state":"{}","count":{},"visible":{},"settled":{},"paths":[{}]}})", NAMES[m_state], m_count, m_cards.size(), m_settled ? "true" : "false", paths);
}
