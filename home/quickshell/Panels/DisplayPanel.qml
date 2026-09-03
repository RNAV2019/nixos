import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services
import qs.Ui

// Drag the map to rearrange, then adjust one monitor at a time below it.
// The card scrolls nothing: a drag gesture inside a Flickable is ambiguous, so
// the content sizes itself instead.
PanelContent {
  id: root

  readonly property var monitors: Displays.monitors
  readonly property var outputs: Displays.activeMonitors

  property string selectedName: ""

  readonly property var selected: {
    var m = Displays.find(selectedName);
    if (m)
      return m;
    // Fall back to the focused monitor so the panel always has a subject.
    for (var i = 0; i < outputs.length; i++) {
      if (outputs[i].focused)
        return outputs[i];
    }
    return outputs.length > 0 ? outputs[0] : null;
  }

  readonly property bool selectedIsInternal: selected !== null && /^(eDP|LVDS|DSI)/i.test(selected.name)
  readonly property bool canDisableSelected: selected !== null && !selected.disabled && outputs.length > 1

  // Poll faster only while the panel is open, as the other panels do.
  onActiveChanged: {
    if (active)
      Displays.subscribe();
    else
      Displays.unsubscribe();
  }

  preferredWidth: Theme.panelWidthWidest
  scrollable: false
  bodyHeight: column.implicitHeight

  // ---- layout maths -------------------------------------------------------

  // Snapshot the live layout as editable rules, one per output.
  function _rules() {
    var out = [];
    for (var i = 0; i < monitors.length; i++) {
      var m = monitors[i];
      out.push({
        output: m.name,
        width: m.width,
        height: m.height,
        refreshRate: m.refreshRate,
        x: m.x,
        y: m.y,
        scale: m.scale,
        disabled: m.disabled,
        mirror: m.mirrorOf
      });
    }
    return out;
  }

  function _find(rules, name) {
    for (var i = 0; i < rules.length; i++) {
      if (rules[i].output === name)
        return rules[i];
    }
    return null;
  }

  // Hyprland accepts negative coordinates, but a layout anchored at the origin
  // keeps the numbers readable and the map stable between edits.
  function _normalise(rules) {
    var minX = Infinity, minY = Infinity;
    for (var i = 0; i < rules.length; i++) {
      if (rules[i].disabled || rules[i].mirror !== "")
        continue;
      minX = Math.min(minX, rules[i].x);
      minY = Math.min(minY, rules[i].y);
    }
    if (!isFinite(minX))
      return;
    for (var j = 0; j < rules.length; j++) {
      rules[j].x -= minX;
      rules[j].y -= minY;
    }
  }

  function _commit(rules) {
    _normalise(rules);

    var applied = [];
    for (var i = 0; i < rules.length; i++) {
      var r = rules[i];
      applied.push({
        output: r.output,
        mode: r.width + "x" + r.height + "@" + Math.round(r.refreshRate),
        position: Math.round(r.x) + "x" + Math.round(r.y),
        scale: r.scale,
        disabled: r.disabled,
        mirror: r.mirror
      });
    }
    Displays.apply(applied);
  }

  function moveMonitor(name, x, y) {
    var rules = _rules();
    var r = _find(rules, name);
    if (!r)
      return;
    r.x = x;
    r.y = y;
    _commit(rules);
  }

  function updateSelected(change) {
    if (!selected)
      return;
    var rules = _rules();
    var r = _find(rules, selected.name);
    if (!r)
      return;
    for (var key in change)
      r[key] = change[key];
    _commit(rules);
  }

  // ---- presets ------------------------------------------------------------

  function isInternal(name) {
    return /^(eDP|LVDS|DSI)/i.test(name);
  }

  // Lay the enabled outputs out left to right, top-aligned. The internal
  // panel leads, so an external lands to the right of the laptop rather than
  // wherever the connector name sorts.
  function _tile(rules) {
    var order = [];
    for (var n = 0; n < rules.length; n++) {
      if (isInternal(rules[n].output))
        order.push(rules[n]);
    }
    for (var p = 0; p < rules.length; p++) {
      if (!isInternal(rules[p].output))
        order.push(rules[p]);
    }

    var cursor = 0;
    for (var i = 0; i < order.length; i++) {
      var r = order[i];
      r.mirror = "";
      if (r.disabled)
        continue;
      r.x = cursor;
      r.y = 0;
      cursor += Math.round(r.width / (r.scale > 0 ? r.scale : 1));
    }
  }

  function presetExtend() {
    var rules = _rules();
    for (var i = 0; i < rules.length; i++)
      rules[i].disabled = false;
    _tile(rules);
    _commit(rules);
  }

  function presetMirror() {
    var rules = _rules();
    if (rules.length < 2)
      return;

    // Mirror onto the internal panel where there is one, so the laptop stays
    // the source and the external follows.
    var sourceName = rules[0].output;
    for (var i = 0; i < rules.length; i++) {
      if (isInternal(rules[i].output)) {
        sourceName = rules[i].output;
        break;
      }
    }

    for (var j = 0; j < rules.length; j++) {
      var r = rules[j];
      r.disabled = false;
      if (r.output === sourceName) {
        r.x = 0;
        r.y = 0;
        r.mirror = "";
      } else {
        r.mirror = sourceName;
      }
    }
    _commit(rules);
  }

  function presetOnly(wantInternal) {
    var rules = _rules();

    var any = false;
    for (var i = 0; i < rules.length; i++) {
      if (isInternal(rules[i].output) === wantInternal) {
        any = true;
        break;
      }
    }
    // Never black out every output.
    if (!any)
      return;

    for (var j = 0; j < rules.length; j++)
      rules[j].disabled = isInternal(rules[j].output) !== wantInternal;
    _tile(rules);
    _commit(rules);
  }

  // ---- mode options -------------------------------------------------------

  readonly property var resolutionOptions: {
    if (!selected)
      return [];
    var seen = {};
    var out = [];
    for (var i = 0; i < selected.modes.length; i++) {
      var m = selected.modes[i];
      var key = m.width + "x" + m.height;
      if (seen[key])
        continue;
      seen[key] = true;
      out.push(key);
    }
    return out;
  }

  readonly property string selectedResolution: selected ? selected.width + "x" + selected.height : ""

  readonly property var refreshOptions: {
    if (!selected)
      return [];
    var out = [];
    var seen = {};
    for (var i = 0; i < selected.modes.length; i++) {
      var m = selected.modes[i];
      if (m.width + "x" + m.height !== selectedResolution)
        continue;
      var hz = String(Math.round(m.refreshRate));
      if (seen[hz])
        continue;
      seen[hz] = true;
      out.push({
        text: hz + " Hz",
        value: hz
      });
    }
    return out;
  }

  readonly property string selectedRefresh: selected ? String(Math.round(selected.refreshRate)) : ""

  readonly property var scaleOptions: [
    {
      text: "100%",
      value: "1"
    },
    {
      text: "125%",
      value: "1.25"
    },
    {
      text: "150%",
      value: "1.5"
    },
    {
      text: "175%",
      value: "1.75"
    },
    {
      text: "200%",
      value: "2"
    }
  ]

  readonly property string selectedScale: selected ? String(selected.scale) : ""

  // Pick the highest rate the chosen resolution offers, because the current
  // rate may not exist at the new one.
  function setResolution(res) {
    var parts = res.split("x");
    var width = parseInt(parts[0]);
    var height = parseInt(parts[1]);

    var best = 0;
    for (var i = 0; i < selected.modes.length; i++) {
      var m = selected.modes[i];
      if (m.width === width && m.height === height)
        best = Math.max(best, m.refreshRate);
    }

    updateSelected({
      width: width,
      height: height,
      refreshRate: best
    });
  }

  // ---- content ------------------------------------------------------------

  ColumnLayout {
    id: column

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    spacing: Theme.spacingMd

    RowLayout {
      Layout.fillWidth: true

      SectionHeader {
        title: "Displays"
        Layout.fillWidth: true
      }

      Text {
        text: DisplayProfiles.label
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        elide: Text.ElideLeft
        Layout.maximumWidth: root.preferredWidth / 2
      }
    }

    DisplayCanvas {
      Layout.fillWidth: true
      Layout.preferredHeight: Theme.displayCanvasHeight

      monitors: root.monitors
      selected: root.selected ? root.selected.name : ""

      onSelectRequested: function (name) {
        root.selectedName = name;
      }
      onMoved: function (name, x, y) {
        root.moveMonitor(name, x, y);
      }
    }

    RowLayout {
      Layout.fillWidth: true
      visible: root.monitors.length > 1
      spacing: Theme.spacingSm

      PanelButton {
        label: "Extend"
        onClicked: root.presetExtend()
      }
      PanelButton {
        label: "Mirror"
        onClicked: root.presetMirror()
      }
      PanelButton {
        label: "Laptop"
        onClicked: root.presetOnly(true)
      }
      PanelButton {
        label: "External"
        onClicked: root.presetOnly(false)
      }
      Item {
        Layout.fillWidth: true
      }
    }

    Separator {
      Layout.fillWidth: true
      visible: root.selected !== null
    }

    RowLayout {
      Layout.fillWidth: true
      visible: root.selected !== null

      SectionHeader {
        title: root.selected ? root.selected.name : ""
        Layout.fillWidth: true
      }

      Text {
        text: root.selected ? root.selected.description : ""
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        elide: Text.ElideRight
        Layout.maximumWidth: root.preferredWidth / 2
      }
    }

    PanelSelect {
      Layout.fillWidth: true
      visible: root.selected !== null

      label: "Resolution"
      options: root.resolutionOptions
      value: root.selectedResolution
      enabled: root.selected !== null && !root.selected.disabled
      onSelected: function (v) {
        root.setResolution(v);
      }
    }

    PanelSelect {
      Layout.fillWidth: true
      visible: root.selected !== null

      label: "Refresh rate"
      options: root.refreshOptions
      value: root.selectedRefresh + " Hz"
      enabled: root.selected !== null && !root.selected.disabled
      onSelected: function (v) {
        root.updateSelected({
          refreshRate: parseFloat(v)
        });
      }
    }

    PanelSelect {
      Layout.fillWidth: true
      visible: root.selected !== null

      label: "Scale"
      options: root.scaleOptions
      value: root.selected ? Math.round(root.selected.scale * 100) + "%" : ""
      enabled: root.selected !== null && !root.selected.disabled
      onSelected: function (v) {
        root.updateSelected({
          scale: parseFloat(v)
        });
      }
    }

    RowLayout {
      Layout.fillWidth: true
      Layout.topMargin: Theme.spacingXs
      visible: root.selected !== null
      spacing: Theme.spacingLg

      Text {
        text: "Enabled"
        color: Theme.subtle
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        Layout.fillWidth: true
      }

      PanelToggle {
        checked: root.selected !== null && !root.selected.disabled
        // The last enabled output cannot be switched off.
        enabled: root.selected !== null && (root.selected.disabled || root.canDisableSelected)
        onToggled: function (v) {
          root.updateSelected({
            disabled: !v
          });
        }
      }
    }

    // Only the internal panel has a backlight. External brightness would need
    // DDC/CI over i2c, which is not set up on this machine.
    RowLayout {
      Layout.fillWidth: true
      visible: root.selectedIsInternal && Brightness.available
      spacing: Theme.spacingLg

      Text {
        text: Icons.brightness
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLarge
        Layout.preferredWidth: 20
      }

      PanelSlider {
        Layout.fillWidth: true
        value: Brightness.value
        onMoved: function (v) {
          Brightness.set(v);
        }
      }

      Text {
        text: Math.round(Brightness.value * 100) + "%"
        color: Theme.subtle
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        Layout.preferredWidth: 36
        horizontalAlignment: Text.AlignRight
      }
    }
  }
}
