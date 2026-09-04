import QtQuick
import qs.Commons

// A compact value picker: one row showing the current value, which expands
// into the choices below it. Panels are too narrow for a popup menu, and an
// inline list keeps the card a single surface.
Item {
  id: root

  property string label: ""
  // Either an array of strings, or of { text, value } objects.
  property var options: []
  property string value: ""
  property bool enabled: true
  property bool expanded: false

  signal selected(string value)

  function _text(o) {
    return o !== null && typeof o === "object" ? o.text : String(o);
  }
  function _value(o) {
    return o !== null && typeof o === "object" ? o.value : String(o);
  }

  // Collapse when the control goes away or loses its choices.
  onEnabledChanged: if (!enabled)
    expanded = false
  onOptionsChanged: expanded = false

  implicitHeight: header.implicitHeight + (expanded ? list.implicitHeight + Theme.spacingXs : 0)
  opacity: enabled ? 1 : 0.4

  Behavior on implicitHeight {
    NumberAnimation {
      duration: Theme.animFast
      easing.type: Easing.InOutQuad
    }
  }

  clip: true

  PanelRow {
    id: header

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    enabled: root.enabled && root.options.length > 0
    selected: root.expanded
    onClicked: root.expanded = !root.expanded

    Text {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: root.label
      color: Theme.subtle
      font.family: Theme.uiFont
      font.pixelSize: Theme.fontSize
    }

    Row {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Theme.spacingMd

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.value
        color: Theme.text
        // Modes, rates and scales are figures; keep their columns aligned.
        font.family: Theme.monoFont
        font.pixelSize: Theme.fontSize
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.expanded ? Icons.expandLess : Icons.expandMore
        color: Theme.muted
        font.family: Theme.iconFont
        font.pixelSize: Theme.fontSizeSmall
      }
    }
  }

  Column {
    id: list

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: header.bottom
    anchors.topMargin: Theme.spacingXs
    visible: root.expanded

    Repeater {
      model: root.options

      PanelRow {
        id: option

        required property var modelData

        readonly property string optionValue: root._value(modelData)

        width: list.width
        implicitHeight: Theme.panelRowHeight - 4
        selected: optionValue === root.value

        onClicked: {
          root.expanded = false;
          if (optionValue !== root.value)
            root.selected(optionValue);
        }

        Text {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: root._text(option.modelData)
          color: option.selected ? Theme.text : Theme.subtle
          font.family: Theme.monoFont
          font.pixelSize: Theme.fontSize
        }
      }
    }
  }
}
