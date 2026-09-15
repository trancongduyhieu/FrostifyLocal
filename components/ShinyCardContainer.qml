import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "."

Item {
    id: root

    property real radius: 16
    property real borderWidth: 1.5
    property color accentColor: Theme.accentColor
    property color subtleAccentColor: Qt.lighter(accentColor, 1.35)
    property int duration: 4000
    property bool isHovered: cardMouse.containsMouse

    default property alias contentData: innerContent.data

    implicitWidth: 760
    implicitHeight: 194

    // 1. DYNAMIC BACKGROUND SURFACE (Option 2: Gradient Mesh blending with accentColor)
    Rectangle {
        id: cardSurface
        anchors.fill: parent
        radius: root.radius
        color: Qt.rgba(0.06, 0.07, 0.10, 0.82)
        clip: true

        // Horizontal Soft Gradient from Left (Avatar) to Right
        Rectangle {
            anchors.fill: parent
            radius: root.radius
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0.0
                    color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, root.isHovered ? 0.22 : 0.14)
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
                GradientStop {
                    position: 0.50
                    color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, root.isHovered ? 0.06 : 0.02)
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
                GradientStop {
                    position: 1.0
                    color: "transparent"
                }
            }
        }

        // Soft Radial Glow behind Avatar on the left
        Rectangle {
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 150
            height: 150
            radius: 75
            color: root.accentColor
            opacity: root.isHovered ? 0.26 : 0.15
            Behavior on opacity { NumberAnimation { duration: 300 } }
            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blurMax: 48
                blur: 1.0
            }
        }

        // Static subtle base border
        Rectangle {
            anchors.fill: parent
            radius: root.radius
            color: "transparent"
            border.color: root.isHovered ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.25) : Qt.rgba(1, 1, 1, 0.08)
            border.width: root.borderWidth
            Behavior on border.color { ColorAnimation { duration: 200 } }
        }
    }

    // 2. HOLLOW BORDER MASK (Pure stroke 1.5px, center is 100% transparent, ZERO light leaks from center)
    Shape {
        id: hollowBorderMask
        anchors.fill: parent
        visible: false
        layer.enabled: true

        ShapePath {
            strokeWidth: root.borderWidth
            strokeColor: "#ffffff"
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathRectangle {
                x: root.borderWidth / 2
                y: root.borderWidth / 2
                width: hollowBorderMask.width - root.borderWidth
                height: hollowBorderMask.height - root.borderWidth
                radius: root.radius
            }
        }
    }

    // 3. ROTATING BEAM (Masked strictly to hollow border stroke!)
    Item {
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: hollowBorderMask
            autoPaddingEnabled: false
        }

        Item {
            id: beamContainer
            anchors.centerIn: parent
            width: Math.max(root.width, root.height) * 1.6
            height: width

            Shape {
                anchors.fill: parent
                ShapePath {
                    strokeColor: "transparent"
                    fillGradient: ConicalGradient {
                        centerX: beamContainer.width / 2
                        centerY: beamContainer.height / 2
                        angle: 0

                        GradientStop { position: 0.00; color: "transparent" }
                        GradientStop { position: 0.04; color: root.accentColor }
                        GradientStop { position: 0.08; color: "#ffffff" }
                        GradientStop { position: 0.12; color: root.subtleAccentColor }
                        GradientStop { position: 0.18; color: "transparent" }
                        GradientStop { position: 1.00; color: "transparent" }
                    }
                    startX: 0; startY: 0
                    PathLine { x: beamContainer.width; y: 0 }
                    PathLine { x: beamContainer.width; y: beamContainer.height }
                    PathLine { x: 0; y: beamContainer.height }
                    PathLine { x: 0; y: 0 }
                }
            }

            NumberAnimation on rotation {
                from: 0
                to: 360
                duration: root.duration
                loops: Animation.Infinite
                running: true
            }
        }
    }

    // 4. INNER CONTENT SLOT
    Item {
        id: innerContent
        anchors.fill: parent
        anchors.margins: root.borderWidth
    }

    MouseArea {
        id: cardMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
}
