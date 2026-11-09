import QtQuick

// Says so, once, if this window is not drawn on the GPU. The shell's blur, clip, shadow and morph
// are all shaders: on Qt's software renderer they do nothing, and on a software GL driver
// (llvmpipe) they work but every frame is drawn on the CPU. Neither should happen on a machine with
// a working driver, so it is only ever a symptom (a broken Mesa, QT_QUICK_BACKEND=software or
// LIBGL_ALWAYS_SOFTWARE set in the session). One per shell is enough: the bar carries it.
Item {
  id: guard

  property bool told: false

  function check() {
    if (guard.told || GraphicsInfo.api === GraphicsInfo.Unknown)
      return;
    guard.told = true;
    if (GraphicsInfo.api === GraphicsInfo.Software)
      console.warn("render: Qt Quick is on the software renderer; nothing in the shell is drawn on the GPU");
    else
      console.info("render: scene graph on the GPU (api " + GraphicsInfo.api + ")");
  }

  GraphicsInfo.onApiChanged: guard.check()
  Component.onCompleted: guard.check()
}
