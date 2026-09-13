import QtQuick
import QtQuick.Effects
import "."

Item {
    id: root

    // =========================================================================
    // Properties & Configuration (SimpMusic Liquid Glass Formula)
    // =========================================================================
    property Item backgroundSourceItem: null
    property real radius: 16
    property real displacement: 6.0
    property real aberration: 0.04
    property real bevelWidth: 12.0
    property color tintColor: Qt.rgba(0.06, 0.07, 0.09, 0.55)
    property bool interactive: false

    default property alias contentData: contentContainer.data

    implicitWidth: 160
    implicitHeight: 48

    // Coordinate mapping to track where this glass sits inside backgroundSourceItem
    readonly property point globalOffset: {
        if (!backgroundSourceItem) return Qt.point(0, 0);
        // Explicitly create reactive binding dependencies on geometry of self, parent and source
        var _rx = root.x, _ry = root.y, _rw = root.width, _rh = root.height;
        var _px = root.parent ? (root.parent.x + root.parent.y + root.parent.width + root.parent.height) : 0;
        var _sx = backgroundSourceItem.width + backgroundSourceItem.height;
        return root.mapToItem(backgroundSourceItem, 0, 0);
    }

    onGlobalOffsetChanged: console.log("[LiquidGlass] globalOffset updated to:", globalOffset.x, globalOffset.y)

    // Capture the background item as a GPU texture with linear filtering
    ShaderEffectSource {
        id: bgSource
        sourceItem: root.backgroundSourceItem
        recursive: false
        live: true
        hideSource: false
        visible: false
        smooth: true
        mipmap: true
    }

    // Hardware-accelerated GLSL Liquid Glass Refraction Shader with 9-Tap Frosted Blur
    ShaderEffect {
        id: glassShader
        anchors.fill: parent

        property variant source: bgSource
        property vector2d u_resolution: Qt.vector2d(root.width, root.height)
        property real u_radius: root.radius
        property real u_displacement: root.displacement
        property real u_aberration: root.aberration
        property real u_bevelWidth: root.bevelWidth
        property color u_tint: root.tintColor
        property vector2d u_sourceSize: Qt.vector2d(
            root.backgroundSourceItem ? Math.max(1, root.backgroundSourceItem.width) : 1,
            root.backgroundSourceItem ? Math.max(1, root.backgroundSourceItem.height) : 1
        )
        property vector2d u_sourceOffset: Qt.vector2d(root.globalOffset.x, root.globalOffset.y)

        fragmentShader: Qt.resolvedUrl("../assets/shaders/liquid_glass.frag.qsb")
        visible: root.backgroundSourceItem !== null
    }

    // Fallback when no backgroundSourceItem is provided
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        visible: root.backgroundSourceItem === null
        color: root.tintColor
    }

    // Content container (text, icons, buttons inside the glass)
    Item {
        id: contentContainer
        anchors.fill: parent
        z: 10
    }
}
