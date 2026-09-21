import QtQuick
import QtQuick.Window

Window {
    id: root
    default property alias contentData: root.data
    flags: Qt.Window | Qt.FramelessWindowHint
    color: "transparent"
    visible: true
    width: root.implicitWidth > 0 ? root.implicitWidth : 1280
    height: root.implicitHeight > 0 ? root.implicitHeight : 820

    signal closed()
    onClosing: closeEvent => {
        root.closed();
    }
}
