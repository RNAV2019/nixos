#include "Cards.hpp"

#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <format>
#include <optional>
#include <span>
#include <sys/eventfd.h>
#include <sys/stat.h>
#include <unistd.h>

#include <glib.h>
#include <hyprgraphics/image/Image.hpp>

// Glyphs on the 24 grid, drawn as round-capped strokes. File, folder, image and archive marks
// are the shell's own (home/quickshell/Commons/IconPaths.qml, boards 16a-16g); audio and video
// are Lucide's music and film (ISC, https://lucide.dev).
static const char* glyphPath(eFileKind kind) {
    switch (kind) {
        case KIND_DIR: return "M3 7C3 5.9 3.9 5 5 5L9 5L11 7L19 7C20.1 7 21 7.9 21 9L21 17C21 18.1 20.1 19 19 19L5 19C3.9 19 3 18.1 3 17L3 7";
        case KIND_IMAGE:
            return "M6.33 4L17.67 4A3.33 3.33 0 0 1 21 7.33L21 16.67A3.33 3.33 0 0 1 17.67 20L6.33 20A3.33 3.33 0 0 1 3 16.67L3 7.33A3.33 3.33 0 0 1 6.33 4ZM4 17L9 12L13 "
                   "16L15.5 13.5L20 18M15.5 8.5L15.51 8.5";
        case KIND_PDF:
        case KIND_TEXT: return "M14 3L7 3C5.9 3 5 3.9 5 5L5 19C5 20.1 5.9 21 7 21L17 21C18.1 21 19 20.1 19 19L19 8L14 3M14 3L14 8L19 8M9 13L15 13M9 17L13 17";
        case KIND_ARCHIVE:
            return "M14 3L7 3C5.9 3 5 3.9 5 5L5 19C5 20.1 5.9 21 7 21L17 21C18.1 21 19 20.1 19 19L19 8L14 3M14 3L14 8L19 8M11 6L12 6M11 9L12 9M11 12L12 12M10.5 15L12.5 15L12.5 "
                   "18L10.5 18L10.5 15";
        case KIND_AUDIO: return "M9 18V5l12-2v13M9 18a3 3 0 1 1-6 0a3 3 0 1 1 6 0ZM21 16a3 3 0 1 1-6 0a3 3 0 1 1 6 0Z";
        case KIND_VIDEO: return "M5 3h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2ZM7 3v18M3 7.5h4M3 12h18M3 16.5h4M17 3v18M17 7.5h4M17 16.5h4";
        default: return "M14 3L7 3C5.9 3 5 3.9 5 5L5 19C5 20.1 5.9 21 7 21L17 21C18.1 21 19 20.1 19 19L19 8L14 3M14 3L14 8L19 8";
    }
}

static std::string lowerExt(const std::string& path) {
    const auto slash = path.find_last_of('/');
    const auto dot   = path.find_last_of('.');
    if (dot == std::string::npos || (slash != std::string::npos && dot < slash))
        return "";
    std::string ext = path.substr(dot + 1);
    std::ranges::transform(ext, ext.begin(), [](unsigned char c) { return std::tolower(c); });
    return ext;
}

static bool oneOf(const std::string& ext, std::initializer_list<const char*> list) {
    return std::ranges::any_of(list, [&](const char* e) { return ext == e; });
}

eFileKind classify(const std::string& path) {
    struct stat st{};
    if (stat(path.c_str(), &st) == 0 && S_ISDIR(st.st_mode))
        return KIND_DIR;

    const auto ext = lowerExt(path);
    if (oneOf(ext, {"png", "jpg", "jpeg", "gif", "webp", "bmp", "avif", "heic", "heif", "svg", "tif", "tiff", "jxl"}))
        return KIND_IMAGE;
    if (ext == "pdf")
        return KIND_PDF;
    if (oneOf(ext, {"zip", "tar", "gz", "tgz", "xz", "7z", "rar", "bz2", "zst", "apk", "deb", "rpm"}))
        return KIND_ARCHIVE;
    if (oneOf(ext, {"mp3", "flac", "ogg", "opus", "wav", "m4a", "aac", "wma"}))
        return KIND_AUDIO;
    if (oneOf(ext, {"mp4", "mkv", "webm", "mov", "avi", "m4v", "wmv"}))
        return KIND_VIDEO;
    if (oneOf(ext, {"txt", "md", "nix", "rs", "qml", "js", "ts", "json", "toml", "yaml", "yml", "py", "sh", "fish", "c", "h", "cpp", "hpp", "go", "lua", "css", "html", "csv",
                    "log", "conf", "ini", "bib", "tex", "typ", "doc", "docx", "odt", "rtf"}))
        return KIND_TEXT;
    return KIND_FILE;
}

static void setColor(cairo_t* cr, uint32_t argb) {
    cairo_set_source_rgba(cr, ((argb >> 16) & 0xff) / 255.0, ((argb >> 8) & 0xff) / 255.0, (argb & 0xff) / 255.0, ((argb >> 24) & 0xff) / 255.0);
}

static void roundedRect(cairo_t* cr, double x, double y, double w, double h, double r) {
    r = std::clamp(r, 0.0, std::min(w, h) / 2.0);
    cairo_new_sub_path(cr);
    cairo_arc(cr, x + w - r, y + r, r, -M_PI / 2, 0);
    cairo_arc(cr, x + w - r, y + h - r, r, 0, M_PI / 2);
    cairo_arc(cr, x + r, y + h - r, r, M_PI / 2, M_PI);
    cairo_arc(cr, x + r, y + r, r, M_PI, 3 * M_PI / 2);
    cairo_close_path(cr);
}

static void paintGlyph(cairo_t* cr, const SCardStyle& style, eFileKind kind) {
    const uint32_t color = style.glyph[kind];
    const int      px    = std::max(1, (int)std::lround(style.glyphSize * style.scale));
    // The stroke is given in card pixels at glyph size; the path is on the 24 grid.
    const double strokeGrid = style.glyphStroke * 24.0 / style.glyphSize;
    const auto   svg        = std::format(R"(<svg xmlns="http://www.w3.org/2000/svg" width="{0}" height="{0}" viewBox="0 0 24 24"><path d="{1}" fill="none" )"
                                                   R"(stroke="#{2:06x}" stroke-opacity="{3:.3f}" stroke-width="{4:.3f}" stroke-linecap="round" stroke-linejoin="round"/></svg>)",
                                          px, glyphPath(kind), color & 0xffffff, ((color >> 24) & 0xff) / 255.0, strokeGrid);

    Hyprgraphics::CImage image(std::span<const uint8_t>{(const uint8_t*)svg.data(), svg.size()}, Hyprgraphics::IMAGE_FORMAT_SVG, {(double)px, (double)px});
    if (!image.success())
        return;

    const double off = (style.size - style.glyphSize) / 2.0;
    cairo_save(cr);
    cairo_translate(cr, off, off);
    cairo_scale(cr, 1.0 / style.scale, 1.0 / style.scale);
    cairo_set_source_surface(cr, image.cairoSurface()->cairo(), 0, 0);
    cairo_paint(cr);
    cairo_restore(cr);
}

cairo_surface_t* renderCard(const SCardStyle& style, eFileKind kind, cairo_surface_t* thumb) {
    const double full = style.size + 2 * CARD_PAD;
    const int    px   = std::max(1, (int)std::ceil(full * style.scale));
    auto*        surf = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, px, px);
    auto*        cr   = cairo_create(surf);

    cairo_scale(cr, style.scale, style.scale);
    cairo_translate(cr, CARD_PAD, CARD_PAD);

    roundedRect(cr, 0, 0, style.size, style.size, style.radius);
    setColor(cr, style.card);
    cairo_fill(cr);

    if (thumb) {
        const double tw = cairo_image_surface_get_width(thumb), th = cairo_image_surface_get_height(thumb);
        if (tw > 0 && th > 0) {
            // Cover-fit: fill the plate and crop the long side, as board 16d does.
            const double k = std::max(style.size / tw, style.size / th);
            cairo_save(cr);
            roundedRect(cr, 0, 0, style.size, style.size, style.radius);
            cairo_clip(cr);
            cairo_translate(cr, (style.size - tw * k) / 2.0, (style.size - th * k) / 2.0);
            cairo_scale(cr, k, k);
            cairo_set_source_surface(cr, thumb, 0, 0);
            cairo_pattern_set_filter(cairo_get_source(cr), CAIRO_FILTER_GOOD);
            cairo_paint(cr);
            cairo_restore(cr);
        }
    } else
        paintGlyph(cr, style, kind);

    roundedRect(cr, 0.5, 0.5, style.size - 1, style.size - 1, style.radius - 0.5);
    cairo_set_line_width(cr, 1);
    setColor(cr, style.border);
    cairo_stroke(cr);

    cairo_destroy(cr);
    cairo_surface_flush(surf);
    return surf;
}

// One box-blur pass over `count` lines of A8 data, `len` samples each, `step` bytes apart.
static void boxBlur(uint8_t* data, int len, int count, int step, int pitch, int r, std::vector<uint8_t>& line) {
    line.resize(len);
    for (int n = 0; n < count; ++n) {
        uint8_t* p   = data + (size_t)n * pitch;
        int      sum = 0;
        for (int i = -r; i <= r; ++i)
            sum += p[(size_t)std::clamp(i, 0, len - 1) * step];
        for (int i = 0; i < len; ++i) {
            line[i] = sum / (2 * r + 1);
            sum += p[(size_t)std::min(i + r + 1, len - 1) * step] - p[(size_t)std::max(i - r, 0) * step];
        }
        for (int i = 0; i < len; ++i)
            p[(size_t)i * step] = line[i];
    }
}

cairo_surface_t* renderIconCard(const SCardStyle& style, double w, double h, cairo_surface_t* image) {
    const double S  = style.scale;
    const int    pw = std::max(1, (int)std::ceil((w + 2 * ICON_PAD) * S));
    const int    ph = std::max(1, (int)std::ceil((h + 2 * ICON_PAD) * S));
    const double r  = std::min(style.radius, std::min(w, h) / 2.0);

    // The shadow: the card's silhouette nudged down and blurred by three box passes, which come
    // close enough to a gaussian at this size.
    auto* shadow = cairo_image_surface_create(CAIRO_FORMAT_A8, pw, ph);
    {
        auto* cr = cairo_create(shadow);
        cairo_scale(cr, S, S);
        roundedRect(cr, ICON_PAD, ICON_PAD + 4, w, h, r);
        cairo_set_source_rgba(cr, 0, 0, 0, 1);
        cairo_fill(cr);
        cairo_destroy(cr);
        cairo_surface_flush(shadow);

        uint8_t*             data   = cairo_image_surface_get_data(shadow);
        const int            stride = cairo_image_surface_get_stride(shadow);
        const int            br     = std::max(1, (int)std::lround(3.5 * S));
        std::vector<uint8_t> line;
        for (int pass = 0; pass < 3; ++pass) {
            boxBlur(data, pw, ph, 1, stride, br, line);
            boxBlur(data, ph, pw, stride, 1, br, line);
        }
        cairo_surface_mark_dirty(shadow);
    }

    auto* surf = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, pw, ph);
    auto* cr   = cairo_create(surf);
    cairo_set_source_rgba(cr, 0, 0, 0, 0.34);
    cairo_mask_surface(cr, shadow, 0, 0);
    cairo_surface_destroy(shadow);

    cairo_scale(cr, S, S);
    cairo_translate(cr, ICON_PAD, ICON_PAD);

    roundedRect(cr, 0, 0, w, h, r);
    setColor(cr, style.card);
    cairo_fill(cr);

    const double iw = cairo_image_surface_get_width(image), ih = cairo_image_surface_get_height(image);
    if (iw > 0 && ih > 0) {
        cairo_save(cr);
        roundedRect(cr, 0, 0, w, h, r);
        cairo_clip(cr);
        cairo_scale(cr, w / iw, h / ih);
        cairo_set_source_surface(cr, image, 0, 0);
        cairo_pattern_set_filter(cairo_get_source(cr), CAIRO_FILTER_GOOD);
        cairo_paint(cr);
        cairo_restore(cr);
    }

    roundedRect(cr, 0.5, 0.5, w - 1, h - 1, r - 0.5);
    cairo_set_line_width(cr, 1);
    setColor(cr, style.border);
    cairo_stroke(cr);

    cairo_destroy(cr);
    cairo_surface_flush(surf);
    return surf;
}

// The freedesktop thumbnail cache: md5 of the canonical file URI, largest flavour first. A
// thumbnail older than the file is stale and skipped.
static std::optional<std::string> cachedThumbnail(const std::string& path) {
    struct stat file{};
    if (stat(path.c_str(), &file) != 0)
        return std::nullopt;

    gchar* uri = g_filename_to_uri(path.c_str(), nullptr, nullptr);
    if (!uri)
        return std::nullopt;
    gchar*            md5 = g_compute_checksum_for_string(G_CHECKSUM_MD5, uri, -1);
    const std::string name = std::string(md5) + ".png";
    g_free(md5);
    g_free(uri);

    const char* cacheHome = std::getenv("XDG_CACHE_HOME");
    const char* home      = std::getenv("HOME");
    std::string base      = cacheHome && *cacheHome ? std::string(cacheHome) : std::string(home ? home : "") + "/.cache";
    base += "/thumbnails/";

    for (const char* flavour : {"x-large", "large", "xx-large", "normal"}) {
        const auto  candidate = base + flavour + "/" + name;
        struct stat thumb{};
        if (stat(candidate.c_str(), &thumb) == 0 && thumb.st_mtime >= file.st_mtime)
            return candidate;
    }
    return std::nullopt;
}

static bool decodable(const std::string& path) {
    return oneOf(lowerExt(path), {"png", "jpg", "jpeg", "webp", "bmp", "svg", "jxl", "avif"});
}

CCardWorker::CCardWorker() {
    m_eventFd = eventfd(0, EFD_CLOEXEC | EFD_NONBLOCK);
    m_thread  = std::thread([this] { run(); });
}

CCardWorker::~CCardWorker() {
    m_stop = true;
    m_cv.notify_all();
    if (m_thread.joinable())
        m_thread.join();
    for (auto& r : m_results)
        cairo_surface_destroy(r.surface);
    if (m_eventFd >= 0)
        close(m_eventFd);
}

int CCardWorker::eventFd() const {
    return m_eventFd;
}

void CCardWorker::submit(std::vector<SCardJob>&& jobs) {
    if (jobs.empty())
        return;
    std::lock_guard lk(m_mutex);
    m_minDrag = jobs.front().drag;
    m_glyphQueue.clear();
    m_thumbQueue.clear();
    for (auto& j : jobs)
        m_glyphQueue.emplace_back(std::move(j));
    m_cv.notify_all();
}

void CCardWorker::dropQueued() {
    std::lock_guard lk(m_mutex);
    m_minDrag = m_minDrag + 1;
    m_glyphQueue.clear();
    m_thumbQueue.clear();
}

std::vector<SCardResult> CCardWorker::takeResults() {
    uint64_t drained = 0;
    while (read(m_eventFd, &drained, sizeof(drained)) > 0) {
        ;
    }

    std::vector<SCardResult> out;
    {
        std::lock_guard lk(m_mutex);
        out.swap(m_results);
    }
    std::erase_if(out, [this](SCardResult& r) {
        if (r.drag >= m_minDrag)
            return false;
        cairo_surface_destroy(r.surface);
        return true;
    });
    return out;
}

void CCardWorker::publish(SCardResult&& r) {
    {
        std::lock_guard lk(m_mutex);
        m_results.emplace_back(std::move(r));
    }
    const uint64_t one = 1;
    (void)!write(m_eventFd, &one, sizeof(one));
}

void CCardWorker::run() {
    while (!m_stop) {
        SCardJob job;
        bool     thumbPass = false;
        {
            std::unique_lock lk(m_mutex);
            m_cv.wait(lk, [this] { return m_stop || !m_glyphQueue.empty() || !m_thumbQueue.empty(); });
            if (m_stop)
                return;
            // Every glyph card goes out before any thumbnail work, so the pile appears at once.
            if (!m_glyphQueue.empty()) {
                job = std::move(m_glyphQueue.front());
                m_glyphQueue.pop_front();
            } else {
                job = std::move(m_thumbQueue.front());
                m_thumbQueue.pop_front();
                thumbPass = true;
            }
        }

        if (job.drag < m_minDrag)
            continue;

        if (!thumbPass) {
            publish({job.drag, job.index, renderCard(job.style, job.kind, nullptr), false});
            if (job.style.thumbnails && job.kind != KIND_DIR) {
                std::lock_guard lk(m_mutex);
                if (job.drag >= m_minDrag)
                    m_thumbQueue.emplace_back(std::move(job));
            }
            continue;
        }

        std::optional<std::string> source = cachedThumbnail(job.path);
        if (!source && job.kind == KIND_IMAGE && decodable(job.path)) {
            struct stat st{};
            if (stat(job.path.c_str(), &st) == 0 && st.st_size <= job.style.maxDecodeBytes)
                source = job.path;
        }
        if (!source || job.drag < m_minDrag)
            continue;

        const double         edge = std::ceil(job.style.size * job.style.scale * 2);
        Hyprgraphics::CImage image(*source, {edge, edge});
        if (!image.success() || !image.cairoSurface())
            continue;

        publish({job.drag, job.index, renderCard(job.style, job.kind, image.cairoSurface()->cairo()), true});
    }
}
