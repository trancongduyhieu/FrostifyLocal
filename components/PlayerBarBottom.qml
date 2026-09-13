import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "."

Item {
    id: root
    implicitWidth: 600
    implicitHeight: 66
    height: 66

    property real radius: 16
    property Item backgroundSourceItem: null
    property var currentTrack: null
    property bool isPlaying: false
    property real currentTime: 0.0
    property real totalDuration: 1.0
    property real volume: 100.0
    property real prevVolume: 100.0
    property bool isShuffle: false
    property bool isRepeat: false
    property bool isLyricsActive: false
    property bool isQueueActive: false
    property bool isScrubbingProgress: false
    property real scrubTime: 0.0
    property bool isScrubbingVolume: false
    property bool isLoadingAudio: false

    signal playPauseClicked()
    signal nextClicked()
    signal prevClicked()
    signal toggleShuffle()
    signal toggleRepeat()
    signal seekRequested(real seconds)
    signal reqVolumeChange(real newVol)
    signal openDetailsRequested()
    signal queueClicked()
    signal openArtistRequested(string artistName, string channelId)

    function fmtTime(sec) {
        if (!sec || sec < 0) return "0:00";
        var m = Math.floor(sec / 60);
        var s = Math.floor(sec % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    // Outer Multi-tier Cinematic Depth Drop Shadow
    Rectangle {
        id: shadowShape
        anchors.fill: parent
        radius: root.radius
        color: "#000000"
        visible: false
    }

    MultiEffect {
        anchors.fill: shadowShape
        source: shadowShape
        shadowEnabled: true
        shadowColor: "#66000000"
        shadowVerticalOffset: 2
        shadowBlur: 0.50
        z: 1
    }

    // Liquid Glass Capsule Container (SimpMusic Rounded Corner 16dp)
    LiquidGlass {
        id: glassDock
        anchors.fill: parent
        radius: root.radius
        displacement: 18.0
        aberration: 0.03
        bevelWidth: 24.0
        tintColor: Qt.rgba(0.04, 0.05, 0.07, 0.65)
        backgroundSourceItem: root.backgroundSourceItem
        z: 2

        // =====================================================================
        // 1. LEFT SECTION (Mini cover + Track title & artist)
        // =====================================================================
        RowLayout {
            id: leftSection
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: centerSection.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -2
            spacing: 10

            // Mini Cover Artwork (38x38)
            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                radius: 8
                color: "#222222"
                clip: true

                Image {
                    id: miniCover
                    anchors.fill: parent
                    source: (root.currentTrack && root.currentTrack.image) ? root.currentTrack.image : ""
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                }

                Rectangle {
                    anchors.fill: parent
                    visible: !miniCover.visible
                    color: "#282828"
                    AppIcon {
                        anchors.centerIn: parent
                        source: "../assets/icons/folder-music-symbolic.svg"
                        iconSize: 18
                        color: Theme.textSecondary
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openDetailsRequested()
                }
            }

            // Track Title and Artist (with Ping-Pong Loop & Matching Colors)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                // Title Container with Ping-Pong Marquee Loop
                Item {
                    id: titleContainer
                    Layout.fillWidth: true
                    implicitHeight: titleText.implicitHeight
                    clip: true

                    Text {
                        id: titleText
                        text: root.currentTrack ? root.currentTrack.name : "Nutsty Desktop"
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                        color: titleH.hovered ? "#ffffff" : Theme.textPrimary
                        x: 0

                        readonly property real overflowDist: Math.max(0, implicitWidth - titleContainer.width)
                        readonly property bool needsScroll: overflowDist > 6

                        SequentialAnimation {
                            id: titleAnim
                            running: titleText.needsScroll
                            loops: Animation.Infinite

                            PauseAnimation { duration: 1800 }
                            NumberAnimation {
                                target: titleText
                                property: "x"
                                to: -titleText.overflowDist
                                duration: Math.max(1200, titleText.overflowDist * 28)
                                easing.type: Easing.InOutQuad
                            }
                            PauseAnimation { duration: 1800 }
                            NumberAnimation {
                                target: titleText
                                property: "x"
                                to: 0
                                duration: Math.max(1200, titleText.overflowDist * 28)
                                easing.type: Easing.InOutQuad
                            }
                        }

                        onNeedsScrollChanged: if (!needsScroll) x = 0
                        onTextChanged: x = 0

                        HoverHandler { id: titleH }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openDetailsRequested()
                        }
                    }
                }

                // Artist Container with Ping-Pong Marquee Loop & Matching Color
                Item {
                    id: artistContainer
                    Layout.fillWidth: true
                    implicitHeight: artistLabel.implicitHeight
                    clip: true

                    Text {
                        id: artistLabel
                        text: {
                            if (!root.currentTrack) return "Ready to play";
                            var raw = String(root.currentTrack.artist || "").trim();
                            var clean = raw.split(/\s*•\s*/)[0].replace(/\s*\d+([.,]\d+)?[KMBkmb]?\s*(views|plays|lượt xem|lượt nghe).*/i, "").trim();
                            return clean || raw || "Nutsty Desktop";
                        }
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        // User explicitly requested: "tên nghệ sĩ cùng màu với tên bài hát"
                        color: (root.currentTrack && artistMouse.containsMouse) ? Theme.accentGreen : Theme.textPrimary
                        x: 0

                        readonly property real overflowDist: Math.max(0, implicitWidth - artistContainer.width)
                        readonly property bool needsScroll: overflowDist > 6

                        SequentialAnimation {
                            id: artistAnim
                            running: artistLabel.needsScroll
                            loops: Animation.Infinite

                            PauseAnimation { duration: 2000 }
                            NumberAnimation {
                                target: artistLabel
                                property: "x"
                                to: -artistLabel.overflowDist
                                duration: Math.max(1200, artistLabel.overflowDist * 28)
                                easing.type: Easing.InOutQuad
                            }
                            PauseAnimation { duration: 2000 }
                            NumberAnimation {
                                target: artistLabel
                                property: "x"
                                to: 0
                                duration: Math.max(1200, artistLabel.overflowDist * 28)
                                easing.type: Easing.InOutQuad
                            }
                        }

                        onNeedsScrollChanged: if (!needsScroll) x = 0
                        onTextChanged: x = 0

                        MouseArea {
                            id: artistMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: root.currentTrack ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (root.currentTrack && root.currentTrack.artist) {
                                    root.openArtistRequested(artistLabel.text, root.currentTrack.channelId || "");
                                }
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // 2. CENTER SECTION (Playback Controls)
        // =====================================================================
        Row {
            id: centerSection
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -2
            spacing: 8

            // --- Shuffle Button ---
            Item {
                width: 28; height: 28
                anchors.verticalCenter: parent.verticalCenter
                HoverHandler { id: shufHover }

                AppIcon {
                    anchors.centerIn: parent
                    source: "../assets/icons/media-playlist-shuffle-symbolic.svg"
                    iconSize: 15
                    color: root.isShuffle ? Theme.accentGreen : (shufHover.hovered ? "#ffffff" : "#b3b3b3")
                }

                Rectangle {
                    width: 3; height: 3; radius: 1.5
                    color: Theme.accentGreen
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.isShuffle
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleShuffle()
                }
            }

            // --- Prev Button ---
            Item {
                width: 30; height: 30
                anchors.verticalCenter: parent.verticalCenter
                opacity: root.currentTrack ? 1.0 : 0.4
                Behavior on opacity { NumberAnimation { duration: 150 } }
                HoverHandler { id: prevHover; enabled: !!root.currentTrack }

                AppIcon {
                    anchors.centerIn: parent
                    source: "../assets/icons/media-skip-backward-symbolic.svg"
                    iconSize: 17
                    color: prevHover.hovered ? "#ffffff" : "#b3b3b3"
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !!root.currentTrack
                    cursorShape: root.currentTrack ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.prevClicked()
                }
            }

            // --- Play / Pause Button (Clean Circle) ---
            Rectangle {
                id: playPauseBtn
                width: 36
                height: 36
                radius: 18
                anchors.verticalCenter: parent.verticalCenter
                opacity: root.currentTrack ? 1.0 : 0.65
                Behavior on opacity { NumberAnimation { duration: 150 } }
                color: (playHover.hovered && root.currentTrack) ? "#ffffff" : "#f0f0f0"
                scale: (playHover.hovered && root.currentTrack) ? 1.06 : 1.0
                Behavior on scale { NumberAnimation { duration: 100 } }
                HoverHandler { id: playHover; enabled: !!root.currentTrack }

                CircularSpinner {
                    anchors.centerIn: parent
                    size: 18
                    strokeWidth: 2.2
                    color: "#111111"
                    visible: root.isLoadingAudio
                }

                AppIcon {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: (!root.isPlaying && !root.isLoadingAudio) ? 1.5 : 0
                    source: root.isPlaying ? "../assets/icons/media-playback-pause-symbolic.svg" : "../assets/icons/media-playback-start-symbolic.svg"
                    iconSize: 17
                    color: "#111111"
                    visible: !root.isLoadingAudio
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !!root.currentTrack
                    cursorShape: root.currentTrack ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.playPauseClicked()
                }
            }

            // --- Next Button ---
            Item {
                width: 30; height: 30
                anchors.verticalCenter: parent.verticalCenter
                opacity: root.currentTrack ? 1.0 : 0.4
                Behavior on opacity { NumberAnimation { duration: 150 } }
                HoverHandler { id: nextHover; enabled: !!root.currentTrack }

                AppIcon {
                    anchors.centerIn: parent
                    source: "../assets/icons/media-skip-forward-symbolic.svg"
                    iconSize: 17
                    color: nextHover.hovered ? "#ffffff" : "#b3b3b3"
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !!root.currentTrack
                    cursorShape: root.currentTrack ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.nextClicked()
                }
            }

            // --- Repeat Button ---
            Item {
                width: 28; height: 28
                anchors.verticalCenter: parent.verticalCenter
                HoverHandler { id: repHover }

                AppIcon {
                    anchors.centerIn: parent
                    source: "../assets/icons/media-playlist-repeat-symbolic.svg"
                    iconSize: 15
                    color: root.isRepeat ? Theme.accentGreen : (repHover.hovered ? "#ffffff" : "#b3b3b3")
                }

                Rectangle {
                    width: 3; height: 3; radius: 1.5
                    color: Theme.accentGreen
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.isRepeat
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleRepeat()
                }
            }
        }

        // =====================================================================
        // 3. RIGHT SECTION (Queue, Volume - Zero MIC, Minimalist Clean)
        // =====================================================================
        Row {
            id: rightSection
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.left: centerSection.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -2
            spacing: 8
            layoutDirection: Qt.RightToLeft

            // Volume Section (Slider + Speaker Icon)
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                layoutDirection: Qt.LeftToRight

                Item {
                    width: 26; height: 26
                    anchors.verticalCenter: parent.verticalCenter
                    HoverHandler { id: volIconH }

                    AppIcon {
                        anchors.centerIn: parent
                        source: root.volume === 0 ? "../assets/icons/audio-volume-muted-symbolic.svg" : "../assets/icons/audio-volume-high-symbolic.svg"
                        iconSize: 16
                        color: volIconH.hovered ? "#ffffff" : "#b3b3b3"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.volume > 0) {
                                root.prevVolume = root.volume;
                                root.reqVolumeChange(0);
                            } else {
                                root.reqVolumeChange(root.prevVolume > 0 ? root.prevVolume : 100);
                            }
                        }
                    }
                }

                // Volume Bar
                Item {
                    id: volSlider
                    width: 52
                    height: 18
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: volMouse.containsMouse || root.isScrubbingVolume ? 4 : 2.5
                        radius: height / 2
                        color: Qt.rgba(1, 1, 1, 0.20)
                        Behavior on height { NumberAnimation { duration: 120 } }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: Math.max(0, parent.width * (root.volume / 100.0))
                            radius: parent.radius
                            color: volMouse.containsMouse || root.isScrubbingVolume ? Theme.accentGreen : Qt.rgba(1, 1, 1, 0.85)
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        Rectangle {
                            width: 7; height: 7; radius: 3.5
                            color: "#ffffff"
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.min(parent.width - width, Math.max(0, parent.width * (root.volume / 100.0) - width / 2))
                            opacity: volMouse.containsMouse || root.isScrubbingVolume ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                        }
                    }

                    MouseArea {
                        id: volMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        function updateVolPos(mouseX) {
                            var frac = Math.max(0.0, Math.min(1.0, mouseX / width));
                            var newVol = Math.round(frac * 100);
                            if (newVol !== root.volume) {
                                root.reqVolumeChange(newVol);
                            }
                        }

                        onPressed: mouse => {
                            root.isScrubbingVolume = true;
                            updateVolPos(mouse.x);
                        }
                        onPositionChanged: mouse => {
                            if (root.isScrubbingVolume) updateVolPos(mouse.x);
                        }
                        onReleased: mouse => {
                            if (root.isScrubbingVolume) {
                                updateVolPos(mouse.x);
                                root.isScrubbingVolume = false;
                            }
                        }
                        onCanceled: root.isScrubbingVolume = false
                    }
                }
            }

            // Queue button
            Item {
                width: 28; height: 28
                anchors.verticalCenter: parent.verticalCenter
                HoverHandler { id: queueH }

                AppIcon {
                    anchors.centerIn: parent
                    source: "../assets/icons/view-queue-symbolic.svg"
                    iconSize: 15
                    color: root.isQueueActive ? Theme.accentGreen : (queueH.hovered ? "#ffffff" : "#b3b3b3")
                }

                Rectangle {
                    width: 3; height: 3; radius: 1.5
                    color: Theme.accentGreen
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.isQueueActive
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.queueClicked()
                }
            }
        }

        // =====================================================================
        // 4. SLIM PROGRESS BAR AT BOTTOM EDGE (Emerald Green, Scrubbing & Time Tooltip)
        // =====================================================================
        Item {
            id: progressBarContainer
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 2
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.right: parent.right
            anchors.rightMargin: 24
            height: 10
            z: 20

            property real progressFraction: {
                if (root.isScrubbingProgress) {
                    return root.totalDuration > 0 ? (root.scrubTime / root.totalDuration) : 0.0;
                }
                return (root.totalDuration > 0) ? Math.min(1.0, Math.max(0.0, root.currentTime / root.totalDuration)) : 0.0;
            }

            // Time Tooltip Bubble (Visible on Hover / Scrubbing)
            Rectangle {
                anchors.bottom: parent.top
                anchors.bottomMargin: 4
                x: Math.min(parent.width - width, Math.max(0, parent.width * progressBarContainer.progressFraction - width / 2))
                width: timeLabelText.implicitWidth + 12
                height: 18
                radius: 9
                color: Qt.rgba(0.08, 0.09, 0.12, 0.88)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.22)
                visible: progressMouse.containsMouse || root.isScrubbingProgress
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 120 } }

                Text {
                    id: timeLabelText
                    anchors.centerIn: parent
                    text: root.fmtTime(root.isScrubbingProgress ? root.scrubTime : root.currentTime) + " / " + root.fmtTime(root.totalDuration)
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    color: "#ffffff"
                }
            }

            Rectangle {
                id: progressBg
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                height: progressMouse.containsMouse || root.isScrubbingProgress ? 3.5 : 2.0
                radius: height / 2
                color: "transparent"
                Behavior on height { NumberAnimation { duration: 120 } }

                // Clean White Elapsed Fill (SimpMusic Style)
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.max(0, parent.width * progressBarContainer.progressFraction)
                    radius: parent.radius
                    color: "#ffffff"
                }

                // Scrub Handle Dot
                Rectangle {
                    width: 6; height: 6; radius: 3
                    color: "#ffffff"
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.min(parent.width - width, Math.max(0, parent.width * progressBarContainer.progressFraction - width / 2))
                    opacity: progressMouse.containsMouse || root.isScrubbingProgress ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }
            }

            MouseArea {
                id: progressMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: !!root.currentTrack && root.totalDuration > 0

                function updateScrubPos(mouseX) {
                    var frac = Math.max(0.0, Math.min(1.0, mouseX / width));
                    root.scrubTime = frac * root.totalDuration;
                }

                onPressed: mouse => {
                    root.isScrubbingProgress = true;
                    updateScrubPos(mouse.x);
                }
                onPositionChanged: mouse => {
                    if (root.isScrubbingProgress) updateScrubPos(mouse.x);
                }
                onReleased: mouse => {
                    if (root.isScrubbingProgress) {
                        updateScrubPos(mouse.x);
                        root.seekRequested(root.scrubTime);
                        root.isScrubbingProgress = false;
                    }
                }
                onCanceled: root.isScrubbingProgress = false
            }
        }
    }
}
