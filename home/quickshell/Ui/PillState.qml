import QtQuick
import qs.Commons

// One state's contents in a pill with several; they cross-fade, so a new state replaces the
// last where it stands. Hidden once faded out, and takes no input while the pill is melting
// back (`open`) or the state is on its way out.
Item {
  property bool shown: false
  property bool open: true

  opacity: shown ? 1 : 0
  visible: opacity > 0
  enabled: open && opacity > 0.5

  Behavior on opacity {
    Morph {
      duration: Theme.morphContent * 2
    }
  }
}
