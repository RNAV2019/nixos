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
    Timer {
        interval: 500
        running: true

        onTriggered: stage1.grabToImage(function (r) {
            r.saveToFile("@OUT@.1.png");
            stage2.grabToImage(function (r2) {
                r2.saveToFile("@OUT@.2.png");
                Qt.quit();
            });
        })
    }
}
