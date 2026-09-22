import QtQuick
import QtQuick.Window

Window {
    id: root
    default property alias contentData: root.data
    flags: Qt.FramelessWindowHint | Qt.WindowTransparentForInput | Qt.WindowDoesNotAcceptFocus | Qt.Tool
    color: "transparent"
    visible: true

    property var screen: null
    property var mask: null
    property var exclusionMode: null

    property var anchors: QtObject {
        property bool top: true
        property bool bottom: true
        property bool left: true
        property bool right: true
    }
}
