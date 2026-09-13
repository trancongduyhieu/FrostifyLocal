import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtQuick.Effects
import QtMultimedia
import Quickshell
import Quickshell.Io
import "."

Item {
    id: root

    property var track: null
    property real currentTime: 0.0
    property real totalDuration: 1.0
    property bool isPlaying: false
    property var queueTracks: []
    property string playingPlaylistTitle: "Queue"
    property color accentColor: Theme.accentGreen
    property Item backgroundSourceItem: null

    property string activeTab: "lyrics" // "up_next" | "lyrics" | "related"
    property string mediaMode: "song" // "song" | "video"

    property var activeLyrics: []
    property int currentLyricIndex: -1
    property bool hasLyrics: false
    property bool isLoadingLyrics: false

    property var relatedData: null
    property bool isLoadingRelated: false
    property string lastRelatedTrackId: ""
    property string videoStreamUrl: ""
    property bool isLoadingVideo: false

    property string currentLikeStatus: "INDIFFERENT"
    property var dislikedSongsMap: ({})

    signal seekRequested(real seconds)
    signal playTrackRequested(var trk, int index)
    signal trackContextMenuRequested(var trk, real globalX, real globalY, bool isQueue)
    signal playlistSelected(var pl)
    signal artistSelected(string name, string channelId)
    signal collapseRequested()
    signal rateSongRequested(string videoId, string rating)
    signal songDisliked(var trk)
    signal downloadRequested(var trk)

    FileView {
        id: dislikedFileView
        path: Quickshell.env("HOME") + "/.config/noctalia/nutsty_disliked_songs.json"
        watchChanges: true
        onFileChanged: {
            reload();
            try {
                var txt = text();
                if (txt && txt.length > 2) dislikedSongsMap = JSON.parse(txt);
            } catch (e) {}
        }
        Component.onCompleted: {
            try {
                var txt = text();
                if (txt && txt.length > 2) dislikedSongsMap = JSON.parse(txt);
            } catch (e) {}
        }
    }

    function isTrackDisliked(vid) {
        if (!vid || !dislikedSongsMap) return false;
        var clean = String(vid).replace("ytdl://", "").replace("yt_", "");
        return !!dislikedSongsMap[clean];
    }

    function toggleLike() {
        if (!root.track) return;
        var vid = root.track.videoId || (root.track.path && root.track.path.startsWith("ytdl://") ? root.track.path.replace("ytdl://", "") : "");
        if (!vid) return;
        var newStatus = (currentLikeStatus === "LIKE") ? "INDIFFERENT" : "LIKE";
        currentLikeStatus = newStatus;
        root.rateSongRequested(vid, newStatus);
    }

    function dislikeCurrentTrack() {
        if (!root.track) return;
        currentLikeStatus = "DISLIKE";
        var vid = root.track.videoId || (root.track.path && root.track.path.startsWith("ytdl://") ? root.track.path.replace("ytdl://", "") : "");
        if (vid) {
            root.rateSongRequested(vid, "DISLIKE");
        }
        root.songDisliked(root.track);
    }

    function downloadCurrentTrack() {
        if (!root.track) return;
        root.downloadRequested(root.track);
    }

    onTrackChanged: {
        if (!root.track) {
            currentLikeStatus = "INDIFFERENT";
            return;
        }
        var vid = root.track.videoId || (root.track.path && root.track.path.startsWith("ytdl://") ? root.track.path.replace("ytdl://", "") : "");
        currentLikeStatus = (vid && isTrackDisliked(vid)) ? "DISLIKE" : "INDIFFERENT";
        fetchLyrics();
        fetchRelatedContent();
        if (root.mediaMode === "video") {
            resolveVideoUrl();
        }
    }

    onCurrentTimeChanged: {
        updateActiveLyric(false);
    }

    Timer {
        id: userScrollTimer
        interval: 3500
        repeat: false
    }

    function getHighResImage(url) {
        if (!url || typeof url !== "string") return "";
        if (url.indexOf("googleusercontent.com") !== -1 || url.indexOf("ggpht.com") !== -1) {
            if (/=w\d+-h\d+/.test(url)) {
                return url.replace(/=w\d+-h\d+[^=]*$/, "=w1080-h1080-l90-rj");
            } else if (url.indexOf("=") !== -1) {
                return url.split("=")[0] + "=w1080-h1080-l90-rj";
            } else {
                return url + "=w1080-h1080-l90-rj";
            }
        }
        if (url.indexOf("i.ytimg.com") !== -1) {
            return url.replace(/(hqdefault|mqdefault|sddefault|default)\.jpg/, "maxresdefault.jpg");
        }
        return url;
    }

    function fetchLyrics() {
        activeLyrics = [];
        currentLyricIndex = -1;
        hasLyrics = false;
        isLoadingLyrics = true;

        var songTitle = (track && (track.title || track.name)) ? (track.title || track.name) : "";
        var songArtist = (track && track.artist) ? track.artist : "";
        var songVid = (track && track.videoId) ? track.videoId : "";
        var songPath = (track && (track.path || track.file_path || track.filePath)) ? (track.path || track.file_path || track.filePath) : "";

        if (songTitle !== "") {
            lyricsProc.running = false;
            lyricsProc.command = [
                "python3", "-u",
                Quickshell.env("HOME") + "/Applications/FrostifyLocal/backend/lyrics_helper.py",
                songTitle, songArtist, songVid, songPath
            ];
            lyricsProc.running = true;
        } else {
            isLoadingLyrics = false;
            hasLyrics = false;
            if (activeTab === "lyrics") activeTab = "up_next";
        }
    }

    Process {
        id: lyricsProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (!data || data.trim() === "") return;
                try {
                    var parsed = JSON.parse(data);
                    if (Array.isArray(parsed) && parsed.length > 0) {
                        root.activeLyrics = parsed;
                        root.hasLyrics = true;
                        root.isLoadingLyrics = false;
                        Qt.callLater(function() { root.updateActiveLyric(true); });
                        if (root.activeTab !== "up_next" && root.activeTab !== "related") {
                            root.activeTab = "lyrics";
                        }
                    } else {
                        root.activeLyrics = [];
                        root.hasLyrics = false;
                        root.isLoadingLyrics = false;
                        if (root.activeTab === "lyrics") {
                            root.activeTab = "up_next";
                        }
                    }
                } catch (e) {
                    root.activeLyrics = [];
                    root.hasLyrics = false;
                    root.isLoadingLyrics = false;
                    if (root.activeTab === "lyrics") {
                        root.activeTab = "up_next";
                    }
                }
            }
        }
        onExited: (code, status) => {
            root.isLoadingLyrics = false;
            if (!root.hasLyrics && root.activeTab === "lyrics") {
                root.activeTab = "up_next";
            }
        }
    }

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
        if (found === -1 && cur < activeLyrics[0].time) {
            found = 0;
        }
        if (found !== -1) {
            currentLyricIndex = found;
            lyricsView.currentIndex = found;
            if (forceScroll || (!lyricsView.moving && !lyricsView.dragging && !lyricsView.flicking && !userScrollTimer.running)) {
                lyricsView.positionViewAtIndex(found, ListView.Center);
            }
        }
    }

    function fetchRelatedContent() {
        if (!track) return;
        var vid = track.videoId || "";
        var title = track.title || track.name || "";
        var artist = track.artist || "";
        var tId = vid || (title + "_" + artist);
        if (tId === lastRelatedTrackId && relatedData) return;

        lastRelatedTrackId = tId;
        isLoadingRelated = true;
        relatedProc.running = false;
        relatedProc.command = [
            "python3", "-u",
            Quickshell.env("HOME") + "/Applications/FrostifyLocal/backend/ytmusic_helper.py",
            "song_related", vid, title, artist
        ];
        relatedProc.running = true;
    }

    Process {
        id: relatedProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (!data || data.trim() === "") return;
                try {
                    var parsed = JSON.parse(data);
                    root.relatedData = parsed;
                    root.isLoadingRelated = false;
                } catch (e) {
                    root.isLoadingRelated = false;
                }
            }
        }
        onExited: (code, status) => {
            root.isLoadingRelated = false;
        }
    }

    function resolveVideoUrl() {
        if (!track || !track.videoId) {
            videoStreamUrl = "";
            return;
        }
        isLoadingVideo = true;
        videoUrlProc.running = false;
        videoUrlProc.command = [
            "python3", "-u",
            Quickshell.env("HOME") + "/Applications/FrostifyLocal/backend/ytmusic_helper.py",
            "get_url", track.videoId
        ];
        videoUrlProc.running = true;
    }

    Process {
        id: videoUrlProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (!data || data.trim() === "") return;
                try {
                    var parsed = JSON.parse(data);
                    if (parsed && parsed.stream_url) {
                        root.videoStreamUrl = parsed.stream_url;
                        videoPlayer.source = parsed.stream_url;
                        videoPlayer.play();
                    }
                    root.isLoadingVideo = false;
                } catch (e) {
                    root.isLoadingVideo = false;
                }
            }
        }
        onExited: (code, status) => {
            root.isLoadingVideo = false;
        }
    }

    // Media Player for In-App Video Playback
    MediaPlayer {
        id: videoPlayer
        audioOutput: AudioOutput { muted: true }
        videoOutput: inAppVideoOut

        onPlaybackStateChanged: {
            if (root.isPlaying && playbackState === MediaPlayer.PausedState) {
                videoPlayer.play();
            } else if (!root.isPlaying && playbackState === MediaPlayer.PlayingState) {
                videoPlayer.pause();
            }
        }
    }

    // Keep video playback synchronized with audio
    Timer {
        interval: 1000
        running: root.mediaMode === "video" && root.isPlaying
        repeat: true
        onTriggered: {
            if (videoPlayer.playbackState === MediaPlayer.PlayingState) {
                var diff = (videoPlayer.position / 1000.0) - root.currentTime;
                if (Math.abs(diff) > 1.2) {
                    videoPlayer.position = root.currentTime * 1000.0;
                }
            }
        }
    }

    // =========================================================================
    // MAIN 2-COLUMN SPLIT SCREEN (50% Left Artwork/Video | 50% Right Tabs)
    // =========================================================================
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.width >= 1200 ? 48 : 24
        anchors.rightMargin: root.width >= 1200 ? 48 : 24
        anchors.topMargin: 12
        anchors.bottomMargin: 84
        spacing: root.width >= 1200 ? 48 : 28

        // =====================================================================
        // COLUMN 1: LEFT AREA (Mode Switcher + Big Artwork / Video + Song Title)
        // =====================================================================
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: parent.width * 0.46
            spacing: 16
            Layout.alignment: Qt.AlignHCenter

            // 1. Mode Switcher Pill [ Bài hát | Video ] (Song vs Video)
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 38

                Rectangle {
                    id: modeSwitcherPill
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 170
                    height: 36
                    radius: 18
                    color: Qt.rgba(0.08, 0.09, 0.12, 0.85)
                    border.color: Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 3
                        spacing: 2

                        // Song Pill
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 15
                            color: root.mediaMode === "song" ? Qt.rgba(1, 1, 1, 0.18) : (songH.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                            border.color: root.mediaMode === "song" ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.5) : "transparent"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                            HoverHandler { id: songH }

                            Text {
                                anchors.centerIn: parent
                                text: "Bài hát"
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.bold: root.mediaMode === "song"
                                color: root.mediaMode === "song" ? "#ffffff" : Theme.textSecondary
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.mediaMode = "song";
                                    videoPlayer.pause();
                                }
                            }
                        }

                        // Video Pill
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 15
                            color: root.mediaMode === "video" ? Qt.rgba(1, 1, 1, 0.18) : (vidH.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                            border.color: root.mediaMode === "video" ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.5) : "transparent"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                            HoverHandler { id: vidH }

                            Text {
                                anchors.centerIn: parent
                                text: "Video"
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.bold: root.mediaMode === "video"
                                color: root.mediaMode === "video" ? "#ffffff" : Theme.textSecondary
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.mediaMode = "video";
                                    if (!root.videoStreamUrl) {
                                        root.resolveVideoUrl();
                                    } else {
                                        videoPlayer.play();
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 2. Central Media Display: Big Square Artwork OR 16:9 Video
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignCenter

                // --- 2A. Song Artwork Mode ---
                Item {
                    id: songArtworkWrapper
                    visible: root.mediaMode === "song"
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 24, Math.min(parent.height - 24, 460))
                    height: width

                    Rectangle {
                        id: coverShadow
                        anchors.fill: parent
                        radius: 16
                        color: "#000000"
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: coverShadow
                        source: coverShadow
                        shadowEnabled: true
                        shadowColor: "#80000000"
                        shadowVerticalOffset: 6
                        shadowBlur: 0.65
                    }

                    Rectangle {
                        id: coverMask
                        anchors.fill: parent
                        radius: 16
                        color: "#ffffff"
                        visible: false
                        layer.enabled: true
                    }

                    Item {
                        anchors.fill: parent
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: coverMask
                            autoPaddingEnabled: false
                        }

                        Image {
                            id: bigCoverImg
                            anchors.fill: parent
                            source: root.track && root.track.image ? root.getHighResImage(root.track.image) : ""
                            fillMode: Image.PreserveAspectCrop
                            scale: (implicitWidth > 0 && implicitHeight > 0 && (implicitWidth / implicitHeight > 1.3)) ? 1.48 : 1.0
                            transformOrigin: Item.Center
                            asynchronous: true
                            onStatusChanged: {
                                if (status === Image.Error && root.track && root.track.image && source !== root.track.image) {
                                    source = root.track.image;
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: bigCoverImg.status !== Image.Ready
                            color: "#18181b"
                            AppIcon {
                                anchors.centerIn: parent
                                source: "../assets/icons/media-optical-audio-symbolic.svg"
                                iconSize: 48
                                color: Theme.textMuted
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 16
                        color: "transparent"
                        border.color: Qt.rgba(1, 1, 1, 0.16)
                        border.width: 1
                        z: 2
                    }
                }

                // --- 2B. Embedded Video Mode ---
                Item {
                    id: videoWrapper
                    visible: root.mediaMode === "video"
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 16, 560)
                    height: width * 9.0 / 16.0

                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        color: "#000000"
                        clip: true

                        VideoOutput {
                            id: inAppVideoOut
                            anchors.fill: parent
                            fillMode: VideoOutput.PreserveAspectCrop
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: root.isLoadingVideo || (!root.videoStreamUrl)
                            color: "#121214"

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 10

                                CircularSpinner {
                                    Layout.alignment: Qt.AlignHCenter
                                    size: 32
                                    strokeWidth: 3
                                    color: root.accentColor
                                    running: visible
                                }

                                Text {
                                    text: "Đang tải video trực tuyến..."
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    color: Theme.textSecondary
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 14
                            color: "transparent"
                            border.color: Qt.rgba(1, 1, 1, 0.18)
                            border.width: 1
                        }
                    }
                }
            }

            // 3. Track Details Row (Title, Artist, Like / Action Buttons)
            ColumnLayout {
                Layout.fillWidth: true
                Layout.maximumWidth: 460
                Layout.alignment: Qt.AlignHCenter
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: root.track ? (root.track.title || root.track.name || "") : "No track playing"
                    font.family: Theme.fontFamily
                    font.pixelSize: 22
                    font.bold: true
                    color: "#ffffff"
                    elide: Text.ElideRight
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: root.track ? (root.track.artist || "Unknown Artist") : ""
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.bold: true
                        color: Qt.rgba(1, 1, 1, 0.65)
                        elide: Text.ElideRight

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.track && root.track.artist) {
                                    root.artistSelected(root.track.artist, root.track.channelId || "");
                                }
                            }
                        }
                    }

                    RowLayout {
                        spacing: 8

                        // 1. Like Button
                        Rectangle {
                            id: likeBtn
                            width: 32; height: 32
                            radius: 8
                            color: root.currentLikeStatus === "LIKE" 
                                   ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.22)
                                   : (likeH.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                            border.width: 1
                            border.color: root.currentLikeStatus === "LIKE" ? root.accentColor : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            HoverHandler { id: likeH }

                            AppIcon {
                                anchors.centerIn: parent
                                source: "../assets/icons/thumb-up-symbolic.svg"
                                iconSize: 16
                                color: root.currentLikeStatus === "LIKE" ? root.accentColor : (likeH.hovered ? "#ffffff" : Theme.textSecondary)
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleLike()
                            }
                        }

                        // 2. Dislike Button (Permanent Blacklist)
                        Rectangle {
                            id: dislikeBtn
                            width: 32; height: 32
                            radius: 8
                            color: root.currentLikeStatus === "DISLIKE"
                                   ? Qt.rgba(1.0, 0.25, 0.25, 0.22)
                                   : (dislikeH.hovered ? Qt.rgba(1.0, 0.25, 0.25, 0.10) : "transparent")
                            border.width: 1
                            border.color: root.currentLikeStatus === "DISLIKE" ? "#ff4444" : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            HoverHandler { id: dislikeH }

                            AppIcon {
                                anchors.centerIn: parent
                                source: "../assets/icons/thumb-down-symbolic.svg"
                                iconSize: 16
                                color: root.currentLikeStatus === "DISLIKE" ? "#ff4444" : (dislikeH.hovered ? "#ff6666" : Theme.textSecondary)
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.dislikeCurrentTrack()
                            }
                        }

                        // 3. Download Button
                        Rectangle {
                            id: dlBtn
                            width: 32; height: 32
                            radius: 8
                            color: dlH.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }

                            HoverHandler { id: dlH }

                            AppIcon {
                                anchors.centerIn: parent
                                source: "../assets/icons/download-symbolic.svg"
                                iconSize: 16
                                color: dlH.hovered ? "#ffffff" : Theme.textSecondary
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.downloadCurrentTrack()
                            }
                        }

                        // 4. Plus (+) Add to Playlist / Queue Button
                        Rectangle {
                            id: plusBtn
                            width: 32; height: 32
                            radius: 8
                            color: plusH.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }

                            HoverHandler { id: plusH }

                            AppIcon {
                                anchors.centerIn: parent
                                source: "../assets/icons/list-add-symbolic.svg"
                                iconSize: 16
                                color: plusH.hovered ? "#ffffff" : Theme.textSecondary
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.track) {
                                        var pt = plusBtn.mapToItem(null, 0, plusBtn.height + 4);
                                        root.trackContextMenuRequested(root.track, pt.x, pt.y, false);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 4 }
        }

        // =====================================================================
        // COLUMN 2: RIGHT AREA (Tabs Bar: [ UP NEXT | LYRICS | RELATED ])
        // =====================================================================
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: parent.width * 0.54
            spacing: 12

            // 1. YouTube Music Tab Switcher Bar
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 44

                RowLayout {
                    id: tabsRow
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 28

                    // TAB 1: UP NEXT
                    Item {
                        id: upNextTabItem
                        height: 36
                        width: upNextTxt.implicitWidth + 8

                        Text {
                            id: upNextTxt
                            anchors.centerIn: parent
                            text: "UP NEXT"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.bold: true
                            font.letterSpacing: 0.6
                            color: root.activeTab === "up_next" ? "#ffffff" : (upNextMouse.containsMouse ? "#ffffff" : Theme.textSecondary)
                        }

                        MouseArea {
                            id: upNextMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activeTab = "up_next"
                        }
                    }

                    // TAB 2: LYRICS
                    Item {
                        id: lyricsTabItem
                        height: 36
                        width: lyricsTxt.implicitWidth + 8
                        opacity: root.hasLyrics ? 1.0 : (root.isLoadingLyrics ? 0.7 : 0.35)
                        enabled: root.hasLyrics || root.isLoadingLyrics

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                id: lyricsTxt
                                anchors.verticalCenter: parent.verticalCenter
                                text: "LYRICS"
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.bold: true
                                font.letterSpacing: 0.6
                                color: root.activeTab === "lyrics" ? "#ffffff" : (lyricsMouse.containsMouse ? "#ffffff" : Theme.textSecondary)
                            }

                            CircularSpinner {
                                anchors.verticalCenter: parent.verticalCenter
                                size: 10
                                strokeWidth: 1.5
                                color: root.accentColor
                                running: root.isLoadingLyrics
                                visible: root.isLoadingLyrics
                            }
                        }

                        MouseArea {
                            id: lyricsMouse
                            anchors.fill: parent
                            hoverEnabled: root.hasLyrics || root.isLoadingLyrics
                            cursorShape: (root.hasLyrics || root.isLoadingLyrics) ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (root.hasLyrics || root.isLoadingLyrics) {
                                    root.activeTab = "lyrics";
                                }
                            }
                        }
                    }

                    // TAB 3: RELATED
                    Item {
                        id: relatedTabItem
                        height: 36
                        width: relatedTxt.implicitWidth + 8

                        Text {
                            id: relatedTxt
                            anchors.centerIn: parent
                            text: "RELATED"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.bold: true
                            font.letterSpacing: 0.6
                            color: root.activeTab === "related" ? "#ffffff" : (relatedMouse.containsMouse ? "#ffffff" : Theme.textSecondary)
                        }

                        MouseArea {
                            id: relatedMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.activeTab = "related";
                                if (!root.relatedData) {
                                    root.fetchRelatedContent();
                                }
                            }
                        }
                    }
                }

                // Active Tab Sliding Indicator Bar
                Rectangle {
                    id: tabIndicator
                    anchors.bottom: parent.bottom
                    height: 2.5
                    radius: 1.25
                    color: root.accentColor

                    readonly property var currentTabObj: {
                        if (root.activeTab === "up_next") return upNextTabItem;
                        if (root.activeTab === "lyrics") return lyricsTabItem;
                        return relatedTabItem;
                    }

                    x: currentTabObj ? currentTabObj.x : 0
                    width: currentTabObj ? currentTabObj.width : 50

                    Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                }
            }

            // 2. Tab Content Stack: [ UP NEXT | LYRICS | RELATED ]
            StackLayout {
                id: tabContentStack
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: root.activeTab === "up_next" ? 0 : (root.activeTab === "lyrics" ? 1 : 2)

                // =============================================================
                // TAB 1 VIEW: UP NEXT (Playing Queue)
                // =============================================================
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: "Playing from"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    color: Theme.textMuted
                                }

                                Text {
                                    text: root.playingPlaylistTitle || "Automix Queue"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: "#ffffff"
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        ListView {
                            id: queueListView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 4
                            model: root.queueTracks

                            delegate: Rectangle {
                                id: qRow
                                width: queueListView.width
                                height: 52
                                radius: 8
                                readonly property bool isCurrent: root.track && (modelData.id === root.track.id || (modelData.videoId && modelData.videoId === root.track.videoId))
                                color: isCurrent 
                                       ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.16) 
                                       : (qRowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                                border.color: isCurrent ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.40) : "transparent"
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 12
                                    spacing: 12

                                    Rectangle {
                                        Layout.preferredWidth: 36
                                        Layout.preferredHeight: 36
                                        radius: 6
                                        color: "#222224"
                                        clip: true

                                        Image {
                                            anchors.fill: parent
                                            source: modelData.image || ""
                                            fillMode: Image.PreserveAspectCrop
                                            scale: (implicitWidth > 0 && implicitHeight > 0 && (implicitWidth / implicitHeight > 1.3)) ? 1.48 : 1.0
                                            transformOrigin: Item.Center
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            color: Qt.rgba(0, 0, 0, 0.55)
                                            visible: qRow.isCurrent && root.isPlaying

                                            Row {
                                                anchors.centerIn: parent
                                                spacing: 2
                                                Repeater {
                                                    model: 3
                                                    Rectangle {
                                                        width: 2.5
                                                        height: 10 + (index % 2) * 5
                                                        radius: 1.2
                                                        color: root.accentColor
                                                        SequentialAnimation on height {
                                                            running: qRow.isCurrent && root.isPlaying
                                                            loops: Animation.Infinite
                                                            NumberAnimation { from: 4; to: 14; duration: 320 + index * 120; easing.type: Easing.InOutQuad }
                                                            NumberAnimation { from: 14; to: 4; duration: 320 + index * 120; easing.type: Easing.InOutQuad }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.title || modelData.name || "Unknown"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 13
                                            font.bold: true
                                            color: qRow.isCurrent ? root.accentColor : "#ffffff"
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.artist || "Unknown Artist"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 11
                                            color: Theme.textSecondary
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Text {
                                        text: {
                                            if (modelData && modelData.duration && modelData.duration !== "--:--") return modelData.duration;
                                            if (qRow.isCurrent && root.totalDuration > 0) {
                                                var m = Math.floor(root.totalDuration / 60);
                                                var s = Math.floor(root.totalDuration % 60);
                                                return m + ":" + (s < 10 ? "0" : "") + s;
                                            }
                                            return "";
                                        }
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        color: Theme.textMuted
                                    }
                                }

                                MouseArea {
                                    id: qRowMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => {
                                        if (mouse.button === Qt.RightButton) {
                                            var gPos = mapToItem(root, mouse.x, mouse.y);
                                            root.trackContextMenuRequested(modelData, gPos.x, gPos.y, true);
                                        } else {
                                            root.playTrackRequested(modelData, index);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // =============================================================
                // TAB 2 VIEW: LYRICS (Seamless Full-Height Kinetic Bokeh Stream)
                // =============================================================
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ListView {
                        id: lyricsView
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        clip: false
                        spacing: 22
                        topMargin: 24
                        bottomMargin: height * 0.45
                        currentIndex: root.currentLyricIndex
                        preferredHighlightBegin: height * 0.38
                        preferredHighlightEnd: height * 0.38
                        highlightRangeMode: ListView.NoHighlightRange
                        highlightMoveDuration: 600
                        highlightMoveVelocity: -1
                        model: root.activeLyrics

                        onMovementStarted: userScrollTimer.restart()
                        onMovementEnded: userScrollTimer.restart()
                        onFlickStarted: userScrollTimer.restart()
                        onFlickEnded: userScrollTimer.restart()

                        delegate: Item {
                            id: lyricRow
                            width: Math.max(100, lyricsView.width - 24)
                            height: Math.max(48, lyricContentItem.implicitHeight + 16)

                            readonly property int dist: Math.abs(index - root.currentLyricIndex)
                            readonly property bool isCurrent: dist === 0
                            readonly property real nextTime: (index + 1 < root.activeLyrics.length) ? root.activeLyrics[index + 1].time : (modelData.time + 6.0)
                            readonly property real duration: Math.max(0.6, nextTime - modelData.time)
                            readonly property real lineProgress: isCurrent ? Math.min(1.0, Math.max(0.0, (root.currentTime - modelData.time) / duration)) : 0.0

                            // SimpMusic & Apple Music Parametric Formulas
                            // Farther lines dissolve into deep bokeh blur
                            readonly property real targetBlur: isCurrent ? 0.0 : (dist === 1 ? 0.35 : (dist === 2 ? 0.70 : 1.0))
                            readonly property real targetOpacity: isCurrent ? 1.0 : (dist === 1 ? 0.45 : (dist === 2 ? 0.18 : Math.max(0.02, 0.08 - 0.03 * (dist - 3))))
                            readonly property int targetFontSize: isCurrent ? 28 : (dist === 1 ? 24 : (dist === 2 ? 21 : 18))

                            opacity: lineHover.hovered ? 0.95 : targetOpacity
                            scale: (isCurrent || lineHover.hovered) ? 1.0 : 0.97
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                            Behavior on scale { NumberAnimation { duration: 200 } }

                            HoverHandler { id: lineHover }

                            layer.enabled: !lineHover.hovered && targetBlur > 0.01 && dist <= 4
                            layer.effect: MultiEffect {
                                blurEnabled: true
                                blur: lyricRow.targetBlur
                                blurMax: 48
                            }

                            function formatKaraokeWords(rawText, progress) {
                                if (!rawText) return "";
                                var words = rawText.trim().split(/\s+/);
                                if (words.length <= 1) {
                                    return "<span style='color:#ffffff; font-weight:bold;'>" + rawText + "</span>";
                                }

                                var total = words.length;
                                var currentFloat = progress * total;
                                var activeIdx = Math.min(total - 1, Math.floor(currentFloat));
                                var fraction = Math.max(0.0, Math.min(1.0, currentFloat - activeIdx));

                                var parts = [];
                                for (var i = 0; i < total; i++) {
                                    var w = words[i];
                                    if (i < activeIdx) {
                                        parts.push("<span style='color:#ffffff; font-weight:bold;'>" + w + "</span>");
                                    } else if (i === activeIdx) {
                                        var r = Math.round(180 + (255 - 180) * fraction);
                                        var g = Math.round(185 + (255 - 185) * fraction);
                                        var b = Math.round(195 + (255 - 195) * fraction);
                                        var hex = "#" + ((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1);
                                        parts.push("<span style='color:" + hex + "; font-weight:bold;'>" + w + "</span>");
                                    } else {
                                        parts.push("<span style='color:#a0a4b2; font-weight:bold;'>" + w + "</span>");
                                    }
                                }
                                return parts.join(" ");
                            }

                            Item {
                                id: lyricContentItem
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                implicitHeight: Math.max(36, lyricRow.isCurrent ? activeTxt.paintedHeight : nonActiveTxt.paintedHeight)

                                Text {
                                    id: activeTxt
                                    visible: lyricRow.isCurrent
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    textFormat: Text.RichText
                                    text: lyricRow.formatKaraokeWords(modelData.text || "", lyricRow.lineProgress)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 28
                                    font.weight: Font.Bold
                                    wrapMode: Text.Wrap
                                    lineHeight: 1.28
                                }

                                Text {
                                    id: nonActiveTxt
                                    visible: !lyricRow.isCurrent
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    text: modelData.text || ""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: lyricRow.targetFontSize
                                    font.weight: Font.Bold
                                    color: lineHover.hovered ? "#ffffff" : "#c4c8d4"
                                    wrapMode: Text.Wrap
                                    lineHeight: 1.25
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData && modelData.time !== undefined) {
                                        userScrollTimer.restart();
                                        root.seekRequested(modelData.time);
                                    }
                                }
                            }
                        }
                    }
                }

                // =============================================================
                // TAB 3 VIEW: RELATED (You Might Also Like + Recommended Playlists)
                // =============================================================
                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: width
                    contentHeight: relatedContentCol.height + 40
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: relatedContentCol
                        width: parent.width
                        spacing: 24

                        // Section 1: You might also like
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                text: "You might also like"
                                font.family: Theme.fontFamily
                                font.pixelSize: 16
                                font.bold: true
                                color: "#ffffff"
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Repeater {
                                    model: (root.relatedData && root.relatedData.you_might_also_like) ? root.relatedData.you_might_also_like.slice(0, 6) : 0

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 50
                                        radius: 8
                                        color: relTrackMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03)
                                        border.color: Qt.rgba(1, 1, 1, 0.06)
                                        border.width: 1

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 12
                                            spacing: 10

                                            Rectangle {
                                                Layout.preferredWidth: 36
                                                Layout.preferredHeight: 36
                                                radius: 6
                                                color: "#222"
                                                clip: true

                                                Image {
                                                    anchors.fill: parent
                                                    source: modelData.image || ""
                                                    fillMode: Image.PreserveAspectCrop
                                                    scale: (implicitWidth > 0 && implicitHeight > 0 && (implicitWidth / implicitHeight > 1.3)) ? 1.48 : 1.0
                                                    transformOrigin: Item.Center
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.title || modelData.name || ""
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 13
                                                    font.bold: true
                                                    color: "#ffffff"
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.artist || ""
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 11
                                                    color: Theme.textSecondary
                                                    elide: Text.ElideRight
                                                }
                                            }

                                            Text {
                                                text: modelData.duration || ""
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 11
                                                color: Theme.textMuted
                                            }
                                        }

                                        MouseArea {
                                            id: relTrackMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.playTrackRequested(modelData, -1);
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Section 2: Recommended playlists (Horizontal Carousel)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            visible: root.relatedData && root.relatedData.recommended_playlists && root.relatedData.recommended_playlists.length > 0

                            Text {
                                text: "Recommended playlists"
                                font.family: Theme.fontFamily
                                font.pixelSize: 16
                                font.bold: true
                                color: "#ffffff"
                            }

                            Flickable {
                                Layout.fillWidth: true
                                height: 180
                                contentWidth: recPlRow.implicitWidth
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                RowLayout {
                                    id: recPlRow
                                    spacing: 14

                                    Repeater {
                                        model: (root.relatedData && root.relatedData.recommended_playlists) ? root.relatedData.recommended_playlists : []

                                        Rectangle {
                                            Layout.preferredWidth: 130
                                            Layout.preferredHeight: 175
                                            radius: 10
                                            color: recPlMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03)
                                            border.color: Qt.rgba(1, 1, 1, 0.08)
                                            border.width: 1

                                            ColumnLayout {
                                                anchors.fill: parent
                                                anchors.margins: 8
                                                spacing: 6

                                                Rectangle {
                                                    Layout.preferredWidth: 114
                                                    Layout.preferredHeight: 114
                                                    radius: 8
                                                    color: "#222"
                                                    clip: true

                                                    Image {
                                                        anchors.fill: parent
                                                        source: modelData.image || ""
                                                        fillMode: Image.PreserveAspectCrop
                                                    }
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.title || ""
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 12
                                                    font.bold: true
                                                    color: "#ffffff"
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 2
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.description || "Playlist"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 10
                                                    color: Theme.textMuted
                                                    elide: Text.ElideRight
                                                }
                                            }

                                            MouseArea {
                                                id: recPlMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.playlistSelected(modelData)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Section 3: Similar artists
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            visible: root.relatedData && root.relatedData.similar_artists && root.relatedData.similar_artists.length > 0

                            Text {
                                text: "Similar artists"
                                font.family: Theme.fontFamily
                                font.pixelSize: 16
                                font.bold: true
                                color: "#ffffff"
                            }

                            Flickable {
                                Layout.fillWidth: true
                                height: 130
                                contentWidth: artRow.implicitWidth
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                RowLayout {
                                    id: artRow
                                    spacing: 16

                                    Repeater {
                                        model: (root.relatedData && root.relatedData.similar_artists) ? root.relatedData.similar_artists : []

                                        ColumnLayout {
                                            Layout.preferredWidth: 90
                                            spacing: 6
                                            Layout.alignment: Qt.AlignHCenter

                                            Rectangle {
                                                Layout.preferredWidth: 76
                                                Layout.preferredHeight: 76
                                                Layout.alignment: Qt.AlignHCenter
                                                radius: 38
                                                color: "#222"
                                                clip: true

                                                Image {
                                                    anchors.fill: parent
                                                    source: modelData.image || ""
                                                    fillMode: Image.PreserveAspectCrop
                                                }

                                                Rectangle {
                                                    anchors.fill: parent
                                                    radius: 38
                                                    color: "transparent"
                                                    border.color: simArtMouse.containsMouse ? root.accentColor : Qt.rgba(1, 1, 1, 0.15)
                                                    border.width: 1
                                                }
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.name || ""
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 11
                                                font.bold: true
                                                color: simArtMouse.containsMouse ? root.accentColor : "#ffffff"
                                                elide: Text.ElideRight
                                                horizontalAlignment: Text.AlignHCenter
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.subscribers || "Nghệ sĩ"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 10
                                                color: Theme.textMuted
                                                elide: Text.ElideRight
                                                horizontalAlignment: Text.AlignHCenter
                                            }

                                            MouseArea {
                                                id: simArtMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.artistSelected(modelData.name, modelData.channelId || "")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
