import QtQuick
import qs.Commons

// The card of an activity that brings none of its own: the chip, its title and its subtitle.
Item {
  id: root

  required property var activity

  implicitWidth: Theme.activityCardWidth
  implicitHeight: 68

  CardHeader {
    icon: root.activity ? root.activity.icon : ""
    tint: root.activity ? root.activity.chipColor : Theme.accent
    title: root.activity ? root.activity.title : ""
    caption: root.activity ? root.activity.subtitle : ""
  }
}
