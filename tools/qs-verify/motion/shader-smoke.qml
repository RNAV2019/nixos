// Smoke test for Shaders/roundedclip.frag.qsb: renders a red square clipped to a
// rounded rect and saves a PNG for shader-smoke.sh to inspect.
// Run via shader-smoke.sh.
import QtQuick

Window {
    id: win
    width: 100
    height: 100
    visible: true
    color: "transparent"

    Item {
        id: stage
        width: 100
        height: 100

        Rectangle {
            id: src
            anchors.fill: parent
            color: "red"
            visible: false
            layer.enabled: true
        }
        ShaderEffect {
            property real aa: 1
            property vector2d boxOrigin: Qt.vector2d(0, 0)
            property vector2d boxSize: Qt.vector2d(100, 100)
            property real radius: 30
            property variant source: src

            anchors.fill: parent
            fragmentShader: Qt.resolvedUrl("../../../home/quickshell/Shaders/roundedclip.frag.qsb")
        }
    }
    Timer {
        interval: 500
        running: true
        onTriggered: stage.grabToImage(function (r) {
            r.saveToFile("/tmp/qs-shader-smoke.png");
            Qt.quit();
        })
    }
}
