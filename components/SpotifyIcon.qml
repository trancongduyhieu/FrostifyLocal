import QtQuick
import QtQuick.Effects

Item {
    id: root
    property string source: ""
    property color color: "#b3b3b3"
    property real iconSize: 16

    implicitWidth: iconSize
    implicitHeight: iconSize

    Image {
        id: rawIcon
        anchors.fill: parent
        source: root.source
        sourceSize: Qt.size(root.iconSize * 2, root.iconSize * 2)
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: false
    }

    MultiEffect {
        anchors.fill: rawIcon
        source: rawIcon
        colorization: 1.0
        colorizationColor: root.color
        Behavior on colorizationColor { ColorAnimation { duration: 100 } }
    }
}
