import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io
import "."

Rectangle {
    id: root
    color: "#121212"
    radius: Theme.radiusCard
    Layout.fillWidth: true
    Layout.fillHeight: true
    implicitWidth: 800
    implicitHeight: 600

    property var track: null
    property real currentTime: 0.0
    property bool isPlaying: false
    property var activeLyrics: []
    property int currentLyricIndex: -1

    readonly property bool isCompact: root.width < 720

    signal closeRequested()
    signal seekRequested(real seconds)

    function updateActiveLyric(forceScroll) {
        if (!activeLyrics || activeLyrics.length === 0) {
            currentLyricIndex = -1;
            return;
        }
        var cur = root.currentTime;
        var found = -1;
        for (var i = 0; i < activeLyrics.length; i++) {
            var t = activeLyrics[i].time;
            var nextT = (i + 1 < activeLyrics.length) ? activeLyrics[i + 1].time : 999999;
            if (cur >= t && cur < nextT) {
                found = i;
                break;
            }
        }
        if (found !== -1) {
            var changed = (currentLyricIndex !== found);
            currentLyricIndex = found;
            if (changed || forceScroll) {
                lyricsView.positionViewAtIndex(found, ListView.Center);
            }
        }
    }

    function fetchLyrics() {
        activeLyrics = [];
        currentLyricIndex = -1;
        var songTitle = (track && (track.title || track.name)) ? (track.title || track.name) : "";
        var songArtist = (track && track.artist) ? track.artist : "";
        var songVid = (track && track.videoId) ? track.videoId : "";
        var songPath = (track && (track.path || track.file_path || track.filePath)) ? (track.path || track.file_path || track.filePath) : "";
        if (songTitle !== "") {
            console.log("Fetching lyrics for track:", songTitle, "by", songArtist);
            lyricsProc.running = false;
            lyricsProc.command = [
                "python3", "-u",
                Quickshell.env("HOME") + "/Applications/FrostifyLocal/backend/lyrics_helper.py",
                songTitle, songArtist, songVid, songPath
            ];
            lyricsProc.running = true;
        }
    }

    onTrackChanged: fetchLyrics()
    onCurrentTimeChanged: updateActiveLyric(false)
    onActiveLyricsChanged: Qt.callLater(function() { updateActiveLyric(true); })
    onVisibleChanged: {
        if (visible) {
            fetchLyrics();
            Qt.callLater(function() { updateActiveLyric(true); });
        }
    }
    
    onWidthChanged: console.log("AmberolDetailView width:", width, "isCompact:", isCompact)
    Component.onCompleted: {
        console.log("AmberolDetailView COMPLETED width:", width, "height:", height, "isCompact:", isCompact)
        fetchLyrics();
    }


    Process {
        id: lyricsProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    var arr = JSON.parse(data);
                    root.activeLyrics = arr;
                    console.log("AmberolDetailView loaded lyrics count:", arr.length);
                    Qt.callLater(function() { root.updateActiveLyric(true); });
                } catch(e) {
                    console.log("Parse error:", e);
                    root.activeLyrics = [];
                }
            }
        }
    }

    // Dynamic subtle album art background tint
    Image {
        id: bgBlur
        anchors.fill: parent
        source: root.track && root.track.image ? root.track.image : ""
        fillMode: Image.PreserveAspectCrop
        opacity: 0.14
        visible: status === Image.Ready
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.06, 0.06, 0.08, 0.90)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.isCompact ? 12 : 24
        spacing: root.isCompact ? 10 : 16

        // Top Bar: Back button with Amberol symbolic icon
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 36

            Rectangle {
                width: 36
                height: 36
                radius: 18
                color: backH.hovered ? "#2e2e2e" : "#1f1f1f"
                Behavior on color { ColorAnimation { duration: 120 } }
                HoverHandler { id: backH }

                SpotifyIcon {
                    anchors.centerIn: parent
                    source: "../assets/icons/go-previous-symbolic.svg"
                    iconSize: 16
                    color: Theme.textPrimary
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }

            Text {
                Layout.leftMargin: 12
                text: "Now Playing Details & Synced Lyrics"
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.bold: true
                color: Theme.textSecondary
            }

            Item { Layout.fillWidth: true }
        }

        // Compact Header when window is narrow
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            spacing: 12
            visible: root.isCompact

            Rectangle {
                width: 52
                height: 52
                radius: 8
                color: "#181818"
                clip: true

                Image {
                    anchors.fill: parent
                    source: root.track && root.track.image ? root.track.image : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                }
                Rectangle {
                    anchors.fill: parent
                    visible: !(root.track && root.track.image)
                    color: "#282830"
                    Text {
                        anchors.centerIn: parent
                        text: root.track && root.track.artist ? root.track.artist.charAt(0).toUpperCase() : "A"
                        font.family: Theme.fontFamily
                        font.pixelSize: 22
                        font.bold: true
                        color: "#666677"
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    text: root.track ? root.track.name : "No track"
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    font.bold: true
                    color: Theme.textPrimary
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: root.track ? root.track.artist : "Unknown Artist"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: Theme.spotifyGreen
                    font.bold: true
                    elide: Text.ElideRight
                }
            }
        }

        // Main Layout: Two Columns (Wide) or Full Lyrics (Compact)
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.isCompact ? 0 : 28

            // Left: Large Amberol Cover Card & Metadata (Only when wide)
            ColumnLayout {
                visible: !root.isCompact
                Layout.preferredWidth: root.isCompact ? 0 : 320
                Layout.maximumWidth: root.isCompact ? 0 : 320
                Layout.minimumWidth: root.isCompact ? 0 : 320
                Layout.fillWidth: false
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignTop
                spacing: 16

                Rectangle {
                    width: 300
                    height: 300
                    Layout.preferredWidth: 300
                    Layout.preferredHeight: 300
                    radius: 14
                    color: "#181818"
                    border.color: "#282828"
                    border.width: 1
                    clip: true

                    Image {
                        id: mainCover
                        anchors.fill: parent
                        source: root.track && root.track.image ? root.track.image : ""
                        fillMode: Image.PreserveAspectCrop
                        visible: status === Image.Ready
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: !mainCover.visible
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#2d2d3a" }
                            GradientStop { position: 1.0; color: "#141418" }
                        }
                        Text {
                            anchors.centerIn: parent
                            text: root.track && root.track.artist ? root.track.artist.charAt(0).toUpperCase() : "A"
                            font.family: Theme.fontFamily
                            font.pixelSize: 72
                            font.bold: true
                            color: "#444455"
                        }
                    }
                }

                // Track Title & Artist Info
                ColumnLayout {
                    Layout.preferredWidth: 300
                    Layout.maximumWidth: 300
                    spacing: 4

                    Text {
                        Layout.preferredWidth: 300
                        text: root.track ? root.track.name : "No track selected"
                        font.family: Theme.fontFamily
                        font.pixelSize: 20
                        font.bold: true
                        color: Theme.textPrimary
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.preferredWidth: 300
                        text: root.track ? root.track.artist : "Unknown Artist"
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        color: Theme.spotifyGreen
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.preferredWidth: 300
                        text: root.track && root.track.album ? root.track.album : "Single / SimpMusic"
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: Theme.textSecondary
                        elide: Text.ElideRight
                    }
                }

                Item { Layout.fillHeight: true }
            }

            // Right: Amberol Synced Lyrics Flow
            Rectangle {
                id: lyricsCard
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 300
                radius: 14
                color: "#161618"
                border.color: "#28282c"
                border.width: 1
                clip: true

                Component.onCompleted: console.log("LYRICS CARD COMPLETED: width=", width, "height=", height, "x=", x, "y=", y)
                onWidthChanged: console.log("LYRICS CARD WIDTH:", width, "x:", x)
                onHeightChanged: console.log("LYRICS CARD HEIGHT:", height, "y:", y)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 12

                    // Lyrics Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "LYRICS"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.bold: true
                            color: Theme.textSecondary
                            font.letterSpacing: 1.5
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: root.activeLyrics.length > 0 ? (root.activeLyrics.length + " lines synced") : "Searching..."
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: Theme.textMuted
                        }
                    }

                    // Synced Lyrics ListView
                    ListView {
                        id: lyricsView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 16
                        model: root.activeLyrics

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                        }

                        delegate: Item {
                            id: lyricRow
                            width: Math.max(100, lyricsView.width - 24)
                            height: Math.max(38, lyricTxt.paintedHeight + 16)

                            property bool isCurrentLine: index === root.currentLyricIndex

                            HoverHandler { id: lineHover }

                            // Left Spotify green bar for active line
                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.topMargin: 4
                                anchors.bottomMargin: 4
                                width: 3
                                radius: 1.5
                                color: Theme.spotifyGreen
                                visible: lyricRow.isCurrentLine
                            }

                            Text {
                                id: lyricTxt
                                anchors.left: parent.left
                                anchors.leftMargin: lyricRow.isCurrentLine ? 16 : 8
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.text || ""
                                font.family: Theme.fontFamily
                                font.pixelSize: lyricRow.isCurrentLine ? 24 : 16
                                font.bold: lyricRow.isCurrentLine
                                color: lyricRow.isCurrentLine ? "#ffffff" : (lineHover.hovered ? "#ffffff" : "#888888")
                                wrapMode: Text.Wrap
                                Behavior on font.pixelSize { NumberAnimation { duration: 120 } }
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData && modelData.time !== undefined) {
                                        root.seekRequested(modelData.time);
                                        root.currentLyricIndex = index;
                                        lyricsView.positionViewAtIndex(index, ListView.Center);
                                    }
                                }
                            }
                        }

                        // Empty Lyrics Fallback
                        Text {
                            anchors.centerIn: parent
                            text: "Đang tải hoặc không có lời bài hát (Synced Lyrics) cho bài này."
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            color: Theme.textSecondary
                            visible: root.activeLyrics.length === 0
                        }
                    }
                }
            }
        }
    }
}
