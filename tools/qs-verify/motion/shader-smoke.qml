// Smoke test for Shaders/roundedclip.frag.qsb: renders two red stages clipped to rounded
// rects and saves PNGs for shader-smoke.sh to inspect (@OUT@ is substituted by the script).
//   stage 1: item == box (100x100, radius 30)
//   stage 2: item 200x160, box 100x60 at origin (40, 50), radius 20
import QtQuick

Window {
    id: win

    width: 400
    height: 200
    visible: true
    color: "transparent"

    Item {
        id: stage1

        width: 100
        height: 100

        Rectangle {
            id: src1

            anchors.fill: parent
            color: "red"
            layer.enabled: true
            visible: false
        }
        ShaderEffect {
            property real aa: 1
            property vector2d boxOrigin: Qt.vector2d(0, 0)
            property vector2d boxSize: Qt.vector2d(100, 100)
            property vector2d itemSize: Qt.vector2d(100, 100)
            property real radius: 30
            property variant source: src1

            anchors.fill: parent
            fragmentShader: Qt.resolvedUrl("../../../home/quickshell/Shaders/roundedclip.frag.qsb")
        }
    }
    Item {
        id: stage2

        x: 150
        width: 200
        height: 160

        Rectangle {
            id: src2

            anchors.fill: parent
            color: "red"
            layer.enabled: true
            visible: false
        }
        ShaderEffect {
            property real aa: 1
            property vector2d boxOrigin: Qt.vector2d(40, 50)
            property vector2d boxSize: Qt.vector2d(100, 60)
            property vector2d itemSize: Qt.vector2d(200, 160)
            property real radius: 20
            property variant source: src2

            anchors.fill: parent
            fragmentShader: Qt.resolvedUrl("../../../home/quickshell/Shaders/roundedclip.frag.qsb")
        }
    }
    // stage 3: hills.frag, three layers of the same half-transparent red over a 100x40 track,
    // fully played, full amplitude: the bottom row is under all three, so alpha is 1 - 0.5^3 and
    // the colour (un-premultiplied in the PNG) is still pure red. Fails if the colour is
    // multiplied by alpha twice.
    Item {
        id: stage3

        x: 150
        y: 170
        width: 100
        height: 30

        ShaderEffect {
            property real amplitude: 1
            property color ink0: Qt.rgba(1, 0, 0, 0.5)
            property color ink1: Qt.rgba(1, 0, 0, 0.5)
            property color ink2: Qt.rgba(1, 0, 0, 0.5)
            property size itemSize: Qt.size(100, 30)
            property real phase: 0
            property real progress: 1

            anchors.fill: parent
            fragmentShader: Qt.resolvedUrl("../../../home/quickshell/Shaders/hills.frag.qsb")
        }
    }
    Timer {
        interval: 500
        running: true

        onTriggered: stage1.grabToImage(function (r) {
            r.saveToFile("@OUT@.1.png");
            stage2.grabToImage(function (r2) {
                r2.saveToFile("@OUT@.2.png");
                stage3.grabToImage(function (r3) {
                    r3.saveToFile("@OUT@.3.png");
                    Qt.quit();
                });
            });
        })
    }
}
