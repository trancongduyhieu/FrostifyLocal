import QtQuick
import QtQuick.Layouts
import "."

Item {
    id: root
    width: 24
    height: 24

    property bool running: true
    property real progress: -1 // 0 - 100, if < 0 just spin
    property color color: "#00c853" // Bright Spotify Accent Green
    property real iconSize: 18

    Item {
        id: spinnerContainer
        anchors.fill: parent

        SpotifyIcon {
            id: spinIcon
            anchors.centerIn: parent
            source: "../assets/icons/process-working-symbolic.svg"
            iconSize: root.iconSize
            color: root.color

            NumberAnimation on rotation {
                from: 0
                to: 360
                duration: 950
                loops: Animation.Infinite
                running: root.running && root.visible
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.progress >= 0 && root.width >= 32
        text: Math.round(root.progress) + "%"
        color: Theme.textPrimary
        font.family: Theme.fontFamily
        font.pixelSize: 9
        font.bold: true
    }
}
