#pragma once

#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/config/values/types/BoolValue.hpp>
#include <hyprland/src/config/values/types/ColorValue.hpp>
#include <hyprland/src/config/values/types/FloatValue.hpp>
#include <hyprland/src/config/values/types/IntValue.hpp>
#include <hyprland/src/config/values/types/StringValue.hpp>

inline HANDLE PHANDLE = nullptr;

// Every option lives under plugin:dragpile:, so in a Lua config it is
// hl.config({ plugin = { dragpile = { card_size = 46, col = { card = "rgba(1e1c1aff)" } } } }).
struct SDragpileConfig {
    SP<Config::Values::CBoolValue>   enabled, physics, thumbnails, tabDrags;
    SP<Config::Values::CIntValue>    cardSize, cardRadius, maxCards, glyphSize, badgeSize, badgeFontSize, thumbnailMaxMb;
    SP<Config::Values::CFloatValue>  offsetX, offsetY, stiffness, damping, followFalloff, maxStretch, tiltMax, tiltLean, tiltStiffness, tiltDamping, glyphStroke;
    SP<Config::Values::CStringValue> badgeFont, cursor;
    SP<Config::Values::CColorValue>  colCard, colBorder, colBadge, colBadgeRing, colBadgeText, colGlyph, colGlyphFolder, colGlyphImage, colGlyphPdf, colGlyphArchive,
        colGlyphAudio, colGlyphVideo;
};

inline SDragpileConfig g_config;
