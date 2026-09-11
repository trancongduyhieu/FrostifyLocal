import QtQuick
import QtQuick.Layouts

Rectangle {
    id: row
    height: 48
    radius: 8
    color: isCurrentTrack ? Qt.rgba(168/255, 85/255, 247/255, 0.20) : (mouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
    border.color: isCurrentTrack ? "#a855f7" : "transparent"
    border.width: 1

    property int indexNumber: 1
    property string trackTitle: ""
    property string trackArtist: ""
    property string trackSource: ""
    property string trackPath: ""
    property bool isCurrentTrack: false
    property bool isPlaying: false
    property var rawTrack: null
    property bool isQueueItem: false

    readonly property string trackVideoId: {
        if (rawTrack && rawTrack.videoId) return rawTrack.videoId;
        if (trackPath && trackPath.startsWith("ytdl://")) return trackPath.replace("ytdl://", "");
        return "";
    }
    readonly property bool isDownloading: (typeof downloadManager !== "undefined" && downloadManager) ? downloadManager.isDownloading(trackVideoId) : false
    readonly property real downloadProgress: (typeof downloadManager !== "undefined" && downloadManager) ? downloadManager.getProgress(trackVideoId) : -1
    readonly property bool isDownloaded: {
        if (typeof downloadManager !== "undefined" && downloadManager && downloadManager.isDownloaded(trackVideoId)) return true;
        if (trackVideoId && typeof win !== "undefined" && win.allTracks) {
            var vId = trackVideoId;
            var tName = (trackTitle || "").toLowerCase().trim();
            return win.allTracks.some(t => (vId && t.videoId === vId) || (tName && (t.title || t.name || "").toLowerCase().trim() === tName));
        }
        return false;
    }

    signal trackClicked()
    signal contextMenuRequested(var track, real globalX, real globalY, bool isQueue)

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 14
        spacing: 12

        // Play icon or Index number
        Item {
            width: 24
            height: 24

            SpotifyIcon {
                anchors.centerIn: parent
                visible: mouseArea.containsMouse || row.isCurrentTrack
                source: (row.isCurrentTrack && row.isPlaying)
                        ? "../assets/icons/media-playback-pause-symbolic.svg"
                        : "../assets/icons/media-playback-start-symbolic.svg"
                iconSize: 14
                color: row.isCurrentTrack ? Theme.spotifyGreen : Theme.textPrimary
            }

            Text {
                anchors.centerIn: parent
                visible: !mouseArea.containsMouse && !row.isCurrentTrack
                text: String(row.indexNumber)
                color: Theme.textSecondary
                font.pixelSize: 12
                font.family: Theme.fontFamily
            }
        }

        // Title and Artist
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: row.trackTitle
                color: row.isCurrentTrack ? "#f3e8ff" : "#ffffff"
                font.pixelSize: 13
                font.bold: row.isCurrentTrack
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: row.trackArtist
                color: "#a1a1aa"
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }

        // Download State Indicator
        Item {
            width: 22
            height: 22
            visible: row.isDownloading || row.isDownloaded

            DownloadingSpinner {
                anchors.centerIn: parent
                visible: row.isDownloading
                running: row.isDownloading
                iconSize: 15
                progress: row.downloadProgress
                color: "#00c853"
            }

            SpotifyIcon {
                anchors.centerIn: parent
                visible: row.isDownloaded && !row.isDownloading
                source: "../assets/icons/emblem-ok-symbolic.svg"
                iconSize: 13
                color: "#00a0cb"
            }
        }

        // Source Pill
        Rectangle {
            width: row.trackSource === "SimpMusic" ? 76 : 70
            height: 20
            radius: 10
            color: row.trackSource === "SimpMusic" ? Qt.rgba(168/255, 85/255, 247/255, 0.2) : Qt.rgba(56/255, 189/255, 248/255, 0.2)
            border.color: row.trackSource === "SimpMusic" ? "#a855f7" : "#38bdf8"
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: row.trackSource
                color: row.trackSource === "SimpMusic" ? "#d8b4fe" : "#7dd3fc"
                font.pixelSize: 10
                font.bold: true
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (win && win.isContextMenuActive) {
                mouse.accepted = true;
                return;
            }
            if (mouse.button === Qt.RightButton) {
                var pt = row.mapToItem(null, mouse.x, mouse.y);
                row.contextMenuRequested(row.rawTrack || {
                    title: row.trackTitle,
                    name: row.trackTitle,
                    artist: row.trackArtist,
                    path: row.trackPath,
                    source: row.trackSource
                }, pt.x, pt.y, row.isQueueItem);
            } else {
                row.trackClicked();
            }
        }
        onDoubleClicked: mouse => {
            if (win && win.isContextMenuActive) {
                mouse.accepted = true;
                return;
            }
            if (mouse.button === Qt.LeftButton) {
                row.trackClicked();
            }
        }
    }
}
