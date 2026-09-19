import QtQuick
import QtQuick.Effects
import "."

Item {
    id: root

    // Core Properties
    property url source: ""
    property real radius: 8
    property int fillMode: Image.PreserveAspectCrop
    property bool asynchronous: true
    property bool cache: true

    // Fallback & Placeholder Properties
    property string fallbackIcon: ""
    property color fallbackIconColor: Theme.accent
    property int fallbackIconSize: 18
    property color placeholderColor: "#202024"

    // Optional Border Properties
    property color borderColor: "transparent"
    property real borderWidth: 0

    // Readonly status & dimensions aliases
    readonly property int status: img.status
    readonly property real paintedWidth: img.paintedWidth
    readonly property real paintedHeight: img.paintedHeight

    implicitWidth: 44
    implicitHeight: 44

    // 1. Placeholder Background (Active when image is not ready or failed)
    Rectangle {
        id: placeholder
        anchors.fill: parent
        radius: root.radius
        color: root.placeholderColor
        visible: img.status !== Image.Ready
    }

    // 2. Fallback AppIcon (Centered in placeholder when no image or loading)
    AppIcon {
        id: fallback
        anchors.centerIn: parent
        source: root.fallbackIcon
        iconSize: root.fallbackIconSize
        color: root.fallbackIconColor
        visible: img.status !== Image.Ready && root.fallbackIcon !== ""
    }

    // 3. Main Image with MultiEffect Mask (0 byte VRAM when not ready or radius is 0)
    Image {
        id: img
        anchors.fill: parent
        source: root.source
        fillMode: root.fillMode
        sourceSize: {
            var w = root.width > 0 ? root.width : root.implicitWidth;
            var h = root.height > 0 ? root.height : root.implicitHeight;
            return Qt.size(Math.max(16, Math.round(w * 2)), Math.max(16, Math.round(h * 2)));
        }
        asynchronous: root.asynchronous
        cache: root.cache
        smooth: true
        visible: status === Image.Ready

        onStatusChanged: {
            if (status === Image.Error) {
                var srcStr = String(source);
                if (srcStr.indexOf("maxresdefault.jpg") !== -1) {
                    source = srcStr.replace("maxresdefault.jpg", "hqdefault.jpg");
                }
            }
        }

        layer.enabled: img.status === Image.Ready && root.radius > 0 && root.width > 0 && root.height > 0
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: maskRect
            autoPaddingEnabled: false
        }
    }

    // 4. Shared Mask Source for GPU MultiEffect Shader
    Rectangle {
        id: maskRect
        anchors.fill: parent
        radius: root.radius
        color: "#ffffff"
        visible: false
        layer.enabled: img.status === Image.Ready && root.radius > 0 && root.width > 0 && root.height > 0
    }

    // 5. Hairline Border Overlay
    Rectangle {
        id: borderRect
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.color: root.borderColor
        border.width: root.borderWidth
        visible: root.borderWidth > 0 && root.borderColor.a > 0
        z: 2
    }
}
