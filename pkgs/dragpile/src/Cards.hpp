#pragma once

#include <array>
#include <atomic>
#include <condition_variable>
#include <cstdint>
#include <deque>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include <cairo/cairo.h>

enum eFileKind : uint8_t {
    KIND_FILE = 0,
    KIND_DIR,
    KIND_IMAGE,
    KIND_PDF,
    KIND_TEXT,
    KIND_ARCHIVE,
    KIND_AUDIO,
    KIND_VIDEO,
    KIND_COUNT,
};

// Colours are 0xAARRGGBB, as Hyprland's colour options store them.
struct SCardStyle {
    double                         size        = 46;
    double                         radius      = 10;
    double                         scale       = 1;
    double                         glyphSize   = 22;
    double                         glyphStroke = 1.6;
    uint32_t                       card        = 0xff1e1c1a;
    uint32_t                       border      = 0x38e6e4de;
    std::array<uint32_t, KIND_COUNT> glyph{};
    bool                           thumbnails     = true;
    int64_t                        maxDecodeBytes = 64ll << 20;
};

// Transparent margin around every card, so a rotated card keeps antialiased edges.
constexpr double CARD_PAD = 3;

struct SCardJob {
    uint64_t    drag  = 0;
    size_t      index = 0;
    std::string path;
    eFileKind   kind = KIND_FILE;
    SCardStyle  style;
};

struct SCardResult {
    uint64_t         drag      = 0;
    size_t           index     = 0;
    cairo_surface_t* surface   = nullptr; // owned by whoever takes the result
    bool             thumbnail = false;
};

eFileKind classify(const std::string& path);

// The card body: a rounded plate with a hairline, filled by the thumbnail when one is given and
// otherwise carrying the kind's glyph. Returns an ARGB32 surface of (size + 2 * CARD_PAD) * scale.
cairo_surface_t* renderCard(const SCardStyle& style, eFileKind kind, cairo_surface_t* thumb);

// Transparent margin around the client-icon card, room for its soft shadow.
constexpr double ICON_PAD = 16;

// A client's drag icon as a card: its image stretched to (w, h) logical px under the pile's
// rounded corners and hairline, over a soft drop shadow. Returns an ARGB32 surface of
// (w + 2 * ICON_PAD, h + 2 * ICON_PAD) * scale.
cairo_surface_t* renderIconCard(const SCardStyle& style, double w, double h, cairo_surface_t* image);

// Builds cards off the compositor thread. Each job yields a glyph card at once and, if a
// thumbnail can be had, a second result that replaces it. Results are signalled on an eventfd.
class CCardWorker {
  public:
    CCardWorker();
    ~CCardWorker();

    void                     submit(std::vector<SCardJob>&& jobs);
    void                     dropQueued();
    std::vector<SCardResult> takeResults();
    int                      eventFd() const;

  private:
    void                     run();
    void                     publish(SCardResult&& r);

    std::thread              m_thread;
    std::mutex               m_mutex;
    std::condition_variable  m_cv;
    std::deque<SCardJob>     m_glyphQueue, m_thumbQueue;
    std::vector<SCardResult> m_results;
    std::atomic<bool>        m_stop    = false;
    std::atomic<uint64_t>    m_minDrag = 0;
    int                      m_eventFd = -1;
};
