import QtQuick
import QtQuick.Window

Window {
    id: root
    default property alias contentData: root.data
    flags: Qt.Window | Qt.FramelessWindowHint
    color: "#0c0d14"
    visible: true
    property real implicitWidth: 1280
    property real implicitHeight: 820
    width: root.implicitWidth > 0 ? root.implicitWidth : 1280
    height: root.implicitHeight > 0 ? root.implicitHeight : 820

    property bool maximized: root.visibility === Window.Maximized
    property bool fullscreen: root.visibility === Window.FullScreen

    onMaximizedChanged: {
        if (maximized && root.visibility !== Window.Maximized) {
            root.showMaximized();
        } else if (!maximized && root.visibility === Window.Maximized) {
            root.showNormal();
        }
    }

    signal closed()
    onClosing: closeEvent => {
        root.closed();
    }

    Component.onCompleted: {
        root.show();
        root.raise();
        root.requestActivate();
    }

    // Solid dark acrylic base foundation to prevent black or invisible rendering on Windows VM
    Rectangle {
        anchors.fill: parent
        color: "#0c0d14"
        z: -9999
    }
}
