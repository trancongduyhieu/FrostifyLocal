import QtQuick
import QtQuick.Layouts
import "."

Rectangle {
    id: root
    height: 88
    color: "#000000"

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

    signal playPauseClicked()
    signal nextClicked()
    signal prevClicked()
    signal toggleShuffle()
    signal toggleRepeat()
    signal seekRequested(real seconds)
    signal reqVolumeChange(real newVol)
    signal openDetailsRequested()

    function fmtTime(sec) {
        if (!sec || sec < 0) return "0:00";
        var m = Math.floor(sec / 60);
        var s = Math.floor(sec % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    Item {
        anchors.fill: parent

        // ==========================================
        // 1. LEFT SECTION (Mini cover + Track info)
        // Fixed width: 280px, anchored strictly to left
        // ==========================================
        RowLayout {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 280
            spacing: 14

            Rectangle {
                Layout.preferredWidth: 56
                Layout.preferredHeight: 56
                radius: 4
                color: "#282828"
                clip: true

                Image {
                    id: miniCover
                    anchors.fill: parent
                    source: root.currentTrack && root.currentTrack.image ? root.currentTrack.image : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                }

                Rectangle {
                    anchors.fill: parent
                    visible: !miniCover.visible
                    color: "#282828"
                    SpotifyIcon {
                        anchors.centerIn: parent
                        source: "../assets/icons/folder-music-symbolic.svg"
                        iconSize: 22
                        color: Theme.textSecondary
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openDetailsRequested()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text {
                    Layout.fillWidth: true
                    text: root.currentTrack ? root.currentTrack.name : "No track selected"
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.bold: true
                    color: titleH.hovered ? "#ffffff" : Theme.textPrimary
                    elide: Text.ElideRight

                    HoverHandler { id: titleH }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openDetailsRequested()
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: root.currentTrack ? root.currentTrack.artist : "Spotify Desktop"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: Theme.textSecondary
                    elide: Text.ElideRight
                }
            }
        }

        // =========================================================================
        // 2. CENTER CONTROLS (STRICTLY CENTERED IN WINDOW VIA anchors.centerIn: parent)
        // =========================================================================
        Item {
            id: centerControls
            anchors.centerIn: parent
            width: Math.min(Math.max(460, parent.width * 0.44), 680)
            height: parent.height

            // Top Row: Playback Action Buttons
            Row {
                id: buttonsRow
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 12
                spacing: 24

                // --- Shuffle Button ---
                Item {
                    width: 32; height: 32
                    HoverHandler { id: shufHover }

                    SpotifyIcon {
                        anchors.centerIn: parent
                        source: "../assets/icons/media-playlist-shuffle-symbolic.svg"
                        iconSize: 16
                        color: root.isShuffle ? Theme.spotifyGreen : (shufHover.hovered ? "#ffffff" : "#b3b3b3")
                    }

                    // Green Active Indicator Dot
                    Rectangle {
                        width: 4; height: 4; radius: 2
                        color: Theme.spotifyGreen
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2
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
                    width: 32; height: 32
                    HoverHandler { id: prevHover }

                    SpotifyIcon {
                        anchors.centerIn: parent
                        source: "../assets/icons/media-skip-backward-symbolic.svg"
                        iconSize: 18
                        color: prevHover.hovered ? "#ffffff" : "#b3b3b3"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.prevClicked()
                    }
                }

                // --- Play / Pause Button (White Circle) ---
                Rectangle {
                    width: 36
                    height: 36
                    radius: 18
                    color: playHover.hovered ? "#ffffff" : "#f0f0f0"
                    scale: playHover.hovered ? 1.06 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }
                    HoverHandler { id: playHover }

                    SpotifyIcon {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: root.isPlaying ? 0 : 1
                        source: root.isPlaying ? "../assets/icons/media-playback-pause-symbolic.svg" : "../assets/icons/media-playback-start-symbolic.svg"
                        iconSize: 16
                        color: "#000000"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.playPauseClicked()
                    }
                }

                // --- Next Button ---
                Item {
                    width: 32; height: 32
                    HoverHandler { id: nextHover }

                    SpotifyIcon {
                        anchors.centerIn: parent
                        source: "../assets/icons/media-skip-forward-symbolic.svg"
                        iconSize: 18
                        color: nextHover.hovered ? "#ffffff" : "#b3b3b3"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.nextClicked()
                    }
                }

                // --- Repeat Button ---
                Item {
                    width: 32; height: 32
                    HoverHandler { id: repHover }

                    SpotifyIcon {
                        anchors.centerIn: parent
                        source: "../assets/icons/media-playlist-repeat-symbolic.svg"
                        iconSize: 16
                        color: root.isRepeat ? Theme.spotifyGreen : (repHover.hovered ? "#ffffff" : "#b3b3b3")
                    }

                    // Green Active Indicator Dot
                    Rectangle {
                        width: 4; height: 4; radius: 2
                        color: Theme.spotifyGreen
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2
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

            // Bottom Row: Progress Scrubber
            RowLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: buttonsRow.bottom
                anchors.topMargin: 8
                spacing: 10

                Text {
                    text: root.fmtTime(root.currentTime)
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: Theme.textSecondary
                }

                Rectangle {
                    id: scrubTrack
                    Layout.fillWidth: true
                    height: 4
                    radius: 2
                    color: "#4d4d4d"

                    Rectangle {
                        id: progressFill
                        height: parent.height
                        radius: 2
                        color: scrubHover.hovered ? Theme.spotifyGreen : "#ffffff"
                        width: parent.width * Math.min(1.0, Math.max(0.0, root.totalDuration > 0 ? (root.currentTime / root.totalDuration) : 0))
                    }

                    // Interactive Thumb on Hover
                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        color: "#ffffff"
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.max(0, Math.min(parent.width - 12, progressFill.width - 6))
                        visible: scrubHover.hovered
                    }

                    HoverHandler { id: scrubHover }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (root.totalDuration > 0) {
                                var ratio = Math.max(0.0, Math.min(1.0, mouse.x / scrubTrack.width));
                                root.seekRequested(ratio * root.totalDuration);
                            }
                        }
                    }
                }

                Text {
                    text: root.fmtTime(root.totalDuration)
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: Theme.textSecondary
                }
            }
        }

        // ==========================================
        // 3. RIGHT SECTION (Lyrics, Queue, Volume)
        // Fixed width: 260px, anchored strictly to right
        // ==========================================
        RowLayout {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 260
            spacing: 14

            Item { Layout.fillWidth: true }


            // Queue button
            Item {
                width: 32; height: 32
                HoverHandler { id: queueH }

                SpotifyIcon {
                    anchors.centerIn: parent
                    source: "../assets/icons/view-queue-symbolic.svg"
                    iconSize: 16
                    color: root.isQueueActive ? Theme.spotifyGreen : (queueH.hovered ? "#ffffff" : "#b3b3b3")
                }

                Rectangle {
                    width: 4; height: 4; radius: 2
                    color: Theme.spotifyGreen
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.isQueueActive
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openDetailsRequested()
                }
            }

            // Volume Section: Speaker Icon + Slider
            RowLayout {
                spacing: 8

                Item {
                    width: 24; height: 24
                    HoverHandler { id: volIconHover }

                    SpotifyIcon {
                        anchors.centerIn: parent
                        source: root.volume === 0 ? "../assets/icons/audio-volume-muted-symbolic.svg" : "../assets/icons/audio-volume-high-symbolic.svg"
                        iconSize: 16
                        color: volIconHover.hovered ? "#ffffff" : "#b3b3b3"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.volume > 0) {
                                root.prevVolume = root.volume;
                                root.volume = 0;
                                root.reqVolumeChange(0);
                            } else {
                                var restore = root.prevVolume > 0 ? root.prevVolume : 80;
                                root.volume = restore;
                                root.reqVolumeChange(restore);
                            }
                        }
                    }
                }

                Rectangle {
                    id: volTrack
                    Layout.preferredWidth: 90
                    height: 4
                    radius: 2
                    color: "#4d4d4d"

                    Rectangle {
                        id: volFill
                        height: parent.height
                        radius: 2
                        color: volH.hovered ? Theme.spotifyGreen : "#ffffff"
                        width: parent.width * (root.volume / 100.0)
                    }

                    Rectangle {
                        width: 10
                        height: 10
                        radius: 5
                        color: "#ffffff"
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.max(0, Math.min(parent.width - 10, volFill.width - 5))
                        visible: volH.hovered
                    }

                    HoverHandler { id: volH }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            var newVol = Math.max(0, Math.min(100, (mouse.x / volTrack.width) * 100));
                            root.volume = newVol;
                            root.reqVolumeChange(newVol);
                        }
                    }
                }
            }
        }
    }
}
