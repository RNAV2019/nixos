// Smoke test for the shell's shaders: renders two red stages clipped to rounded rects
// (roundedclip), the hills, the lock clock's glass and the lock's island patch, and saves PNGs for shader-smoke.sh to
// inspect (@OUT@ is substituted by the script).
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
    // stage 4: lockglass.frag with every effect off but the see-through: a white block covering
    // the top half of a 100x40 item as the digits, a blue backdrop. Blue where the digits are,
    // nothing below them.
    Item {
        id: stage4

        y: 110
        width: 100
        height: 40

        Item {
            id: src4

            anchors.fill: parent
            layer.enabled: true
            visible: false

            Rectangle {
                width: 100
                height: 20
                color: "white"
            }
        }
        Rectangle {
            id: back4

            anchors.fill: parent
            color: "blue"
            layer.enabled: true
            visible: false
        }
        ShaderEffect {
            property variant backdrop: back4
            property real bend: 0
            property real bevel: 4
            property real film: 0
            property variant glyphs: src4
            property color ink: "red"
            property size itemSize: Qt.size(100, 40)
            property point light: Qt.point(-0.6, -0.8)
            property real lighten: 1
            property real milk: 0
            property real relief: 1
            property real rim: 1
            property real shine: 0
            property variant soft: src4
            property real soften: 0
            property real solid: 0
            property color tint: "green"
            property real washAngle: 0
            property point washCentre: Qt.point(0, 0)
            property real washCore: 0.5
            property real washDepth: 0
            property size washRadii: Qt.size(10, 10)

            anchors.fill: parent
            fragmentShader: Qt.resolvedUrl("../../../home/quickshell/Shaders/lockglass.frag.qsb")
        }
    }
    // stage 5: lockpatch.frag over a red capture and a blue wallpaper, a 60x20 island at (20, 10)
    // with no shadow: blue inside the island, red outside it.
    Item {
        id: stage5

        x: 110
        y: 110
        width: 100
        height: 40

        Rectangle {
            id: cap5

            anchors.fill: parent
            color: "red"
            layer.enabled: true
            visible: false
        }
        Rectangle {
            id: wall5

            anchors.fill: parent
            color: "blue"
            layer.enabled: true
            visible: false
        }
        ShaderEffect {
            property real aa: 1
            property real amount: 1
            property point boxOrigin: Qt.point(20, 10)
            property size boxSize: Qt.size(60, 20)
            property variant capture: cap5
            property point discCentre: Qt.point(0, 0)
            property real discRadius: 0
            property size itemSize: Qt.size(100, 40)
            property point offset: Qt.point(0, 4)
            property real radius: 10
            property real sigma: 6
            property real strength: 0
            property variant wallpaper: wall5

            anchors.fill: parent
            fragmentShader: Qt.resolvedUrl("../../../home/quickshell/Shaders/lockpatch.frag.qsb")
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
                    stage4.grabToImage(function (r4) {
                        r4.saveToFile("@OUT@.4.png");
                        stage5.grabToImage(function (r5) {
                            r5.saveToFile("@OUT@.5.png");
                            Qt.quit();
                        });
                    });
                });
            });
        })
    }
}
