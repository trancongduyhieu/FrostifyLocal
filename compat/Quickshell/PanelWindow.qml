import QtQuick
import QtQuick.Window

Window {
    id: root
    default property alias contentData: root.data
    flags: Qt.FramelessWindowHint | Qt.WindowTransparentForInput | Qt.WindowDoesNotAcceptFocus | Qt.Tool
    color: "transparent"
    visible: true

    width: (screen && screen.geometry) ? screen.geometry.width : Screen.width
    height: (screen && screen.geometry) ? screen.geometry.height : Screen.height
    x: (screen && screen.geometry) ? screen.geometry.x : 0
    y: (screen && screen.geometry) ? screen.geometry.y : 0

    property var screen: null
    property var mask: null
    property var exclusionMode: null

    property PanelAnchors anchors: PanelAnchors {}
}
