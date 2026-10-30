import QtQuick
import Quickshell

// Every source of live activities and moments, started once with the shell. A new source is a
// file in this directory (an Activity, or an Instantiator of them, like DemoSource) added here.
Scope {
  id: root

  DemoSource {}
}
