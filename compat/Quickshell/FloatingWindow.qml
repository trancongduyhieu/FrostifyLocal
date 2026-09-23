import QtQuick
import QtQuick.Window

Window {
    id: root
    default property alias contentData: root.data
    flags: Qt.Window | Qt.FramelessWindowHint
    color: "transparent"
    visible: true

    property real implicitWidth: 1280
    property real implicitHeight: 820

    // Auto-fit screen: Constrain initial width & height to available screen dimensions
    // so window buttons never get clipped on lower resolutions (800x600, 1024x768, 1280x720)
    width: Math.min(root.implicitWidth > 0 ? root.implicitWidth : 1280, Math.max(760, (Screen.desktopAvailableWidth || 800) - 16))
    height: Math.min(root.implicitHeight > 0 ? root.implicitHeight : 820, Math.max(500, (Screen.desktopAvailableHeight || 600) - 30))

    // Auto-center window on screen
    x: Math.max(0, Math.round(((Screen.desktopAvailableWidth || 800) - width) / 2))
    y: Math.max(0, Math.round(((Screen.desktopAvailableHeight || 600) - height) / 2))

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
}
