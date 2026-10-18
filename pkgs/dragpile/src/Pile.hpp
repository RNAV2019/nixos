#pragma once

#include <chrono>
#include <functional>
#include <optional>
#include <string>
#include <vector>

#include <hyprland/src/helpers/math/Math.hpp>
#include <hyprland/src/helpers/memory/Memory.hpp>
#include <hyprland/src/desktop/DesktopTypes.hpp>
#include <hyprland/src/render/Texture.hpp>

#include <wayland-server-core.h>

#include "Cards.hpp"

// The pile of file cards that trails the cursor while files are dragged. All positions are
// global layout coordinates and all angles are clockwise degrees, as Penpot reports them.
class CPile {
  public:
    using Clock = std::chrono::steady_clock;

    CPile();
    ~CPile();

    // A drag offering text/uri-list started; the list is still being read.
    void pending();
    // The list arrived with at least one local file.
    void begin(std::vector<std::string>&& paths);
    // The list held no local files (or never came): give the drag back to the client's icon.
    void abandon();
    // The drag ended. A drop sinks the pile into the cursor; a cancel sends it home first.
    void end(bool dropped);

    bool        hidesClientIcon() const;
    bool        idle() const;
    void        render(PHLMONITOR monitor);
    // Something moved or arrived: make sure a frame gets drawn where the pile is.
    void        poke();
    std::string describe() const;

    // Where the pointer is, touch included. Set by the plugin.
    std::function<Vector2D()> m_cursor;

  private:
    enum eState : uint8_t {
        STATE_IDLE = 0,
        STATE_PENDING,
        STATE_LIVE,
        STATE_DROPPED,
        STATE_CANCELLED,
    };

    struct SCard {
        std::string           path;
        eFileKind             kind = KIND_FILE;
        SP<Render::ITexture>  tex;
        bool                  thumbnail = false;
        Vector2D              pos, vel;
        double                ang = 0, angVel = 0;
        Vector2D              restOff;
        double                restAng = 0;
    };

    void                    setState(eState s);
    double                  stateAge() const;
    void                    advance();
    void                    integrate(double dt);
    void                    uploadResults();
    void                    rebuildBadge();
    Vector2D                frontTarget(const Vector2D& cursor);
    void                    updateFlip(const Vector2D& cursor);
    CBox                    extents() const;
    void                    damage(const CBox& box);
    void                    reset();

    eState                  m_state = STATE_IDLE;
    Clock::time_point       m_since;
    std::optional<Clock::time_point> m_lastStep;
    uint64_t                m_drag = 0;

    std::vector<SCard>      m_cards; // front first
    size_t                  m_count = 0;
    Vector2D                m_home;  // where the front card sat when the drag began
    bool                    m_flipX = false, m_flipY = false;
    SCardStyle              m_style;

    double                  m_scale = 0.6, m_scaleVel = 0;
    double                  m_alpha = 0;

    SP<Render::ITexture>    m_badgeTex;
    Vector2D                m_badgeSize; // logical, without CARD_PAD
    size_t                  m_badgeCount = 0;
    double                  m_badgeScale = 1, m_badgeVel = 0;

    CBox                    m_lastExtents;
    bool                    m_settled = false;

    UP<CCardWorker>         m_worker;
    std::vector<SCardResult> m_ready;
    wl_event_source*        m_workerSource = nullptr;

    friend int onWorkerReady(int fd, uint32_t mask, void* data);
};

inline UP<CPile> g_pPile;
