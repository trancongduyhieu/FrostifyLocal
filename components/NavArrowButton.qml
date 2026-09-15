import QtQuick
import QtQuick.Effects
import "."

Rectangle {
    id: navBtn
    property string direction: "left" // "left" or "right"
    property color accentColor: (typeof win !== "undefined" && win.accentColor) ? win.accentColor : Theme.accent
    property real btnSize: 30
    property real iconSize: 13
    property bool canScroll: true

    signal clicked()

    width: btnSize
    height: btnSize
    radius: btnSize / 2
    opacity: canScroll ? 1.0 : 0.28
    enabled: canScroll
    scale: (btnMouse.containsMouse && enabled) ? 1.06 : 1.0

    color: (btnMouse.containsMouse && enabled)
        ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.28)
        : Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.12)
    border.width: 1
    border.color: (btnMouse.containsMouse && enabled)
        ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.75)
        : Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.30)

    Behavior on color { ColorAnimation { duration: 200 } }
    Behavior on border.color { ColorAnimation { duration: 200 } }
    Behavior on scale { NumberAnimation { duration: 120 } }
    Behavior on opacity { NumberAnimation { duration: 150 } }

    AppIcon {
        anchors.centerIn: parent
        source: "../assets/icons/go-previous-symbolic.svg"
        rotation: navBtn.direction === "right" ? 180 : 0
        iconSize: navBtn.iconSize
        color: navBtn.accentColor
        Behavior on color { ColorAnimation { duration: 250 } }
    }

    MouseArea {
        id: btnMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: navBtn.clicked()
    }
}
