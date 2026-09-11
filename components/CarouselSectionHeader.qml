import QtQuick
import QtQuick.Layouts
import "."

RowLayout {
    id: root
    Layout.fillWidth: true

    property string title: ""
    property int titlePixelSize: 22
    property color titleColor: "#ffffff"
    property var targetFlickable: null
    property real stepSize: 480
    property int animationDuration: 280

    Text {
        Layout.fillWidth: true
        text: root.title
        font.family: Theme.fontFamily
        font.pixelSize: root.titlePixelSize
        font.bold: true
        color: root.titleColor
    }

    NumberAnimation {
        id: scrollAnim
        target: root.targetFlickable
        property: "contentX"
        duration: root.animationDuration
        easing.type: Easing.OutCubic
    }

    // Prev Button (<)
    Rectangle {
        width: 32
        height: 32
        radius: 16
        color: prevMouse.containsMouse ? "#38383c" : "#222226"
        opacity: (root.targetFlickable && root.targetFlickable.contentX > 10) ? 1.0 : 0.35
        visible: root.targetFlickable ? (root.targetFlickable.contentWidth > root.targetFlickable.width) : false
        Behavior on color { ColorAnimation { duration: 100 } }
        Behavior on opacity { NumberAnimation { duration: 150 } }

        SpotifyIcon {
            anchors.centerIn: parent
            source: "../assets/icons/go-previous-symbolic.svg"
            iconSize: 14
            color: "#ffffff"
        }

        MouseArea {
            id: prevMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (!root.targetFlickable) return;
                var targetX = Math.max(0, root.targetFlickable.contentX - root.stepSize);
                scrollAnim.stop();
                scrollAnim.target = root.targetFlickable;
                scrollAnim.to = targetX;
                scrollAnim.restart();
            }
        }
    }

    // Next Button (>)
    Rectangle {
        width: 32
        height: 32
        radius: 16
        color: nextMouse.containsMouse ? "#38383c" : "#222226"
        opacity: (root.targetFlickable && (root.targetFlickable.contentX < (root.targetFlickable.contentWidth - root.targetFlickable.width - 10))) ? 1.0 : 0.35
        visible: root.targetFlickable ? (root.targetFlickable.contentWidth > root.targetFlickable.width) : false
        Behavior on color { ColorAnimation { duration: 100 } }
        Behavior on opacity { NumberAnimation { duration: 150 } }

        SpotifyIcon {
            anchors.centerIn: parent
            source: "../assets/icons/go-previous-symbolic.svg"
            rotation: 180
            iconSize: 14
            color: "#ffffff"
        }

        MouseArea {
            id: nextMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (!root.targetFlickable) return;
                var maxX = Math.max(0, root.targetFlickable.contentWidth - root.targetFlickable.width);
                var targetX = Math.min(maxX, root.targetFlickable.contentX + root.stepSize);
                scrollAnim.stop();
                scrollAnim.target = root.targetFlickable;
                scrollAnim.to = targetX;
                scrollAnim.restart();
            }
        }
    }
}
