import QtQuick
import QtQuick.Effects
import "."

Item {
    id: root

    property string customCover: ""
    property var tracks: []
    property string playlistTitle: ""
    property real radius: 12
    property color accentColor: Theme.accent

    implicitWidth: 160
    implicitHeight: 160

    readonly property var validTracks: {
        if (!tracks) return [];
        var res = [];
        var len = tracks.length || 0;
        for (var i = 0; i < len; i++) {
            var t = tracks[i];
            if (t && (t.image || t.cover || t.thumbnail)) {
                res.push(t);
            }
        }
        return res;
    }

    readonly property bool hasCustomCover: customCover !== "" && customCover !== undefined
    readonly property bool isCollage: !hasCustomCover && validTracks.length >= 4
    readonly property bool isSingleTrackCover: !hasCustomCover && validTracks.length >= 1 && validTracks.length < 4
    readonly property bool isEmptyPlaylist: !hasCustomCover && validTracks.length === 0

    // Deterministic Gradient Palette based on title hash (SimpMusic Skill #68)
    readonly property var gradientColors: {
        var str = root.playlistTitle || "Nutsty";
        var hash = 0;
        for (var i = 0; i < str.length; i++) {
            hash = str.charCodeAt(i) + ((hash << 5) - hash);
        }
        var palettes = [
            { c1: "#312e81", c2: "#4338ca" }, // Indigo
            { c1: "#4c1d95", c2: "#6d28d9" }, // Purple
            { c1: "#701a75", c2: "#a21caf" }, // Fuchsia
            { c1: "#831843", c2: "#be185d" }, // Pink
            { c1: "#14532d", c2: "#15803d" }, // Emerald
            { c1: "#134e4a", c2: "#0f766e" }, // Teal
            { c1: "#1e3a8a", c2: "#1d4ed8" }, // Blue
            { c1: "#7c2d12", c2: "#c2410c" }  // Orange Amber
        ];
        return palettes[Math.abs(hash) % palettes.length];
    }

    // Mask for concentric rounded corners (Must be declared before container with static layer)
    Rectangle {
        id: maskRect
        anchors.fill: parent
        radius: root.radius
        color: "#ffffff"
        visible: false
        layer.enabled: true
        layer.smooth: true
        smooth: true
        antialiasing: true
    }

    Item {
        id: container
        anchors.fill: parent
        layer.enabled: root.radius > 0
        layer.smooth: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: maskRect
            autoPaddingEnabled: false
        }

        // 1. Custom Cover
        Image {
            anchors.fill: parent
            source: root.hasCustomCover ? root.customCover : ""
            fillMode: Image.PreserveAspectCrop
            visible: root.hasCustomCover
            asynchronous: true
            cache: true
        }

        // 2. 2x2 Collage Grid
        Grid {
            id: collageGrid
            anchors.fill: parent
            columns: 2
            rows: 2
            spacing: 0
            visible: root.isCollage

            Repeater {
                model: 4
                delegate: Image {
                    width: root.width / 2
                    height: root.height / 2
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    source: {
                        if (!root.isCollage) return "";
                        var t = root.validTracks[index];
                        return t ? (t.image || t.cover || t.thumbnail || "") : "";
                    }
                }
            }
        }

        // 3. Single Track Cover (1-3 tracks)
        Image {
            anchors.fill: parent
            source: root.isSingleTrackCover && root.validTracks.length > 0 ? (root.validTracks[0].image || root.validTracks[0].cover || "") : ""
            fillMode: Image.PreserveAspectCrop
            visible: root.isSingleTrackCover
            asynchronous: true
            cache: true
        }

        // 4. Empty Playlist Generative Gradient + Monogram
        Rectangle {
            anchors.fill: parent
            visible: root.isEmptyPlaylist
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.gradientColors.c1 }
                GradientStop { position: 1.0; color: root.gradientColors.c2 }
            }

            Column {
                anchors.centerIn: parent
                spacing: 6

                AppIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: "../assets/icons/folder-music-symbolic.svg"
                    iconSize: Math.max(22, root.width * 0.22)
                    color: Qt.rgba(255, 255, 255, 0.85)
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: {
                        var t = (root.playlistTitle || "N").trim();
                        return t.length > 0 ? t.charAt(0).toUpperCase() : "N";
                    }
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(16, root.width * 0.16)
                    font.weight: Font.DemiBold
                    color: Qt.rgba(255, 255, 255, 0.75)
                }
            }
        }
    }

    // Hairline border
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.color: Qt.rgba(255, 255, 255, 0.1)
        border.width: 1
    }
}
