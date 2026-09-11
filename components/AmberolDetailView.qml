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
    Layout.fillHeight: true
    implicitWidth: 360
    implicitHeight: 600

    property var track: null
    property real currentTime: 0.0
    property bool isPlaying: false
    property var activeLyrics: []
    property int currentLyricIndex: -1

    property string compactTab: "lyrics" // "lyrics" or "art"

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

    property var songDetails: null
    property var audioSpecs: null
    readonly property bool isDetailsLoading: !songDetails || songDetailsProc.running

    signal viewAlbumRequested(var alb)
    signal startRadioRequested(var trk)
    signal downloadTrackRequested(var trk)
    signal openFolderRequested(var trk)
    signal copyLinkRequested(string text)
    signal rateSongRequested(string videoId, string rating)
    signal songDisliked(var trk)
    signal openArtistRequested(string artistName, string channelId)

    property var artistAvatarsMap: ({})
    property var dislikedSongsMap: ({})

    FileView {
        id: artistAvatarsFileView
        path: Quickshell.env("HOME") + "/.cache/frostify/artist_avatars.json"
        watchChanges: true
        onFileChanged: {
            reload();
            try {
                var txt = text();
                if (txt && txt.length > 2) artistAvatarsMap = JSON.parse(txt);
            } catch (e) {}
        }
    }

    FileView {
        id: dislikedFileView
        path: Quickshell.env("HOME") + "/.config/noctalia/frostify_disliked_songs.json"
        watchChanges: true
        onFileChanged: {
            reload();
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

    readonly property string cachedArtistAvatar: {
        var aName = (root.track && root.track.artist) ? root.track.artist.toLowerCase().trim() : "";
        if (aName && artistAvatarsMap && artistAvatarsMap[aName]) {
            return artistAvatarsMap[aName];
        }
        return "";
    }

    property string currentLikeStatus: "INDIFFERENT"
    property int localLikesCount: (songDetails && songDetails.likes) ? songDetails.likes : 0
    property int localDislikesCount: (songDetails && songDetails.dislikes) ? songDetails.dislikes : 0

    onSongDetailsChanged: {
        if (songDetails) {
            currentLikeStatus = songDetails.likeStatus || "INDIFFERENT";
            localLikesCount = songDetails.likes || 0;
            localDislikesCount = songDetails.dislikes || 0;
        } else {
            var vid = track ? (track.videoId || (track.path && track.path.startsWith("ytdl://") ? track.path.replace("ytdl://", "") : "")) : "";
            currentLikeStatus = (vid && isTrackDisliked(vid)) ? "DISLIKE" : "INDIFFERENT";
            localLikesCount = 0;
            localDislikesCount = 0;
        }
    }

    function toggleLike() {
        if (!songDetails || !songDetails.videoId) return;
        var newStatus = (currentLikeStatus === "LIKE") ? "INDIFFERENT" : "LIKE";
        if (newStatus === "LIKE") {
            localLikesCount += 1;
            if (currentLikeStatus === "DISLIKE" && localDislikesCount > 0) {
                localDislikesCount -= 1;
            }
        } else {
            if (localLikesCount > 0) localLikesCount -= 1;
        }
        currentLikeStatus = newStatus;
        rateSongRequested(songDetails.videoId, newStatus);
    }

    function toggleDislike() {
        if (!songDetails || !songDetails.videoId) return;
        var newStatus = (currentLikeStatus === "DISLIKE") ? "INDIFFERENT" : "DISLIKE";
        if (newStatus === "DISLIKE") {
            localDislikesCount += 1;
            if (currentLikeStatus === "LIKE" && localLikesCount > 0) {
                localLikesCount -= 1;
            }
            currentLikeStatus = newStatus;
            rateSongRequested(songDetails.videoId, "DISLIKE");
            songDisliked(track);
        } else {
            if (localDislikesCount > 0) localDislikesCount -= 1;
            currentLikeStatus = newStatus;
            rateSongRequested(songDetails.videoId, "INDIFFERENT");
        }
    }

    function scrollArtDown() {
        artScrollArea.contentY = Math.min(artScrollArea.contentHeight - artScrollArea.height, artScrollArea.contentY + 340);
    }

    function fetchSongDetails() {
        songDetails = null;
        if (!track) return;
        var vid = track.videoId || "";
        if (!vid && track.path && track.path.startsWith("ytdl://")) {
            vid = track.path.replace("ytdl://", "");
        }
        if (!vid && (track.title || track.name)) {
            vid = (track.title || track.name) + " " + (track.artist || "");
        }
        if (vid) {
            songDetailsProc.running = false;
            songDetailsProc.command = [
                "python3", "-u",
                Quickshell.env("HOME") + "/Applications/FrostifyLocal/backend/ytmusic_helper.py",
                "song_details", vid
            ];
            songDetailsProc.running = true;
        }
        fetchAudioSpecs();
    }

    function fetchAudioSpecs() {
        audioSpecsProc.running = false;
        audioSpecsProc.command = [
            "python3", "-u",
            Quickshell.env("HOME") + "/Applications/FrostifyLocal/backend/player_daemon.py",
            "audio_specs"
        ];
        audioSpecsProc.running = true;
    }

    onTrackChanged: {
        songDetails = null;
        var vid = track ? (track.videoId || (track.path && track.path.startsWith("ytdl://") ? track.path.replace("ytdl://", "") : "")) : "";
        currentLikeStatus = (vid && isTrackDisliked(vid)) ? "DISLIKE" : "INDIFFERENT";
        localLikesCount = 0;
        localDislikesCount = 0;

        fetchLyrics();
        fetchSongDetails();
        delayedAudioSpecsTimer.restart();
    }
    onCurrentTimeChanged: updateActiveLyric(false)
    onActiveLyricsChanged: Qt.callLater(function() { updateActiveLyric(true); })
    onVisibleChanged: {
        if (visible) {
            fetchLyrics();
            fetchSongDetails();
            delayedAudioSpecsTimer.restart();
            Qt.callLater(function() { updateActiveLyric(true); });
        }
    }
    
    onWidthChanged: console.log("AmberolDetailView width:", width, "isCompact:", isCompact)
    Component.onCompleted: {
        console.log("AmberolDetailView COMPLETED width:", width, "height:", height, "isCompact:", isCompact)
        try {
            var aTxt = artistAvatarsFileView.text();
            if (aTxt && aTxt.length > 2) artistAvatarsMap = JSON.parse(aTxt);
        } catch(e) {}
        try {
            var dTxt = dislikedFileView.text();
            if (dTxt && dTxt.length > 2) dislikedSongsMap = JSON.parse(dTxt);
        } catch(e) {}
        fetchLyrics();
        fetchSongDetails();
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

    Process {
        id: songDetailsProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    var obj = JSON.parse(data);
                    if (obj && typeof obj === "object") {
                        root.songDetails = obj;
                    }
                } catch(e) {
                    console.log("songDetailsProc error:", e);
                }
            }
        }
    }

    Process {
        id: audioSpecsProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    var obj = JSON.parse(data);
                    if (obj && typeof obj === "object") {
                        root.audioSpecs = obj;
                    }
                } catch(e) {
                    console.log("audioSpecsProc error:", e);
                }
            }
        }
    }

    Timer {
        id: delayedAudioSpecsTimer
        interval: 1200
        repeat: false
        onTriggered: fetchAudioSpecs()
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

    property bool allowClose: false
    Timer {
        interval: 600
        running: true
        repeat: false
        onTriggered: root.allowClose = true
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
                    onClicked: mouse => {
                        if (root.allowClose) {
                            root.closeRequested();
                        }
                    }
                }
            }

            Text {
                Layout.leftMargin: 8
                text: root.isCompact ? "Now Playing" : "Now Playing Details & Synced Lyrics"
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.bold: true
                color: Theme.textSecondary
            }

            Item { Layout.fillWidth: true }

            // Segmented pill switch when compact: [Lyrics | Art]
            Rectangle {
                visible: root.isCompact
                width: 140
                height: 30
                radius: 15
                color: "#181818"
                border.color: "#282828"
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 15
                        color: root.compactTab === "lyrics" ? Theme.spotifyGreen : (lyrH.hovered ? "#242424" : "transparent")
                        Behavior on color { ColorAnimation { duration: 100 } }
                        HoverHandler { id: lyrH }

                        Text {
                            anchors.centerIn: parent
                            text: "Lyrics"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: root.compactTab === "lyrics" ? "#000000" : Theme.textSecondary
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.compactTab = "lyrics"
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 15
                        color: root.compactTab === "art" ? Theme.spotifyGreen : (artH.hovered ? "#242424" : "transparent")
                        Behavior on color { ColorAnimation { duration: 100 } }
                        HoverHandler { id: artH }

                        Text {
                            anchors.centerIn: parent
                            text: "Artwork"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: root.compactTab === "art" ? "#000000" : Theme.textSecondary
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.compactTab = "art"
                        }
                    }
                }
            }
        }

        // Compact Header when window is narrow and showing lyrics
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            spacing: 12
            visible: root.isCompact && root.compactTab === "lyrics"

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

        // Main Layout: Two Columns (Wide) or Full Lyrics / Full Art (Compact)
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.isCompact ? 0 : 28

            // Left: Large Amberol Cover Card & Detailed Song Metadata Inspector (Visible when wide OR when compactTab == 'art')
            Flickable {
                id: artScrollArea
                visible: !root.isCompact || root.compactTab === "art"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 320
                Layout.maximumWidth: root.isCompact ? 360 : 320
                Layout.minimumWidth: 260
                contentWidth: width
                contentHeight: artContentCol.height + 30
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                ColumnLayout {
                    id: artContentCol
                    width: artScrollArea.width
                    spacing: 14
                    Layout.alignment: Qt.AlignHCenter

                    // 1. Large Cover Art (260x260 in compact, 280x280 wide)
                    Rectangle {
                        width: root.isCompact ? 260 : 280
                        height: width
                        Layout.preferredWidth: width
                        Layout.preferredHeight: height
                        Layout.alignment: Qt.AlignHCenter
                        radius: 12
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
                            asynchronous: true
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

                    // 2. Track Title & Artist Info
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: root.isCompact ? 260 : 280
                        Layout.maximumWidth: 320
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 4

                        Text {
                            Layout.fillWidth: true
                            text: root.track ? (root.track.title || root.track.name || "No track selected") : "No track selected"
                            font.family: Theme.fontFamily
                            font.pixelSize: 19
                            font.bold: true
                            color: Theme.textPrimary
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            horizontalAlignment: root.isCompact ? Text.AlignHCenter : Text.AlignLeft
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.track ? (root.track.artist || "Unknown Artist") : "Unknown Artist"
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            color: Theme.spotifyGreen
                            font.bold: true
                            elide: Text.ElideRight
                            horizontalAlignment: root.isCompact ? Text.AlignHCenter : Text.AlignLeft
                        }

                        // Badges Row: [CODEC & BITRATE] [SOURCE] [YEAR]
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.alignment: root.isCompact ? Qt.AlignHCenter : Qt.AlignLeft
                            spacing: 6

                            // Codec Pill
                            Rectangle {
                                height: 20
                                width: codecText.implicitWidth + 12
                                radius: 4
                                color: Qt.rgba(0.12, 0.12, 0.14, 0.9)
                                border.color: Qt.rgba(1, 1, 1, 0.15)
                                border.width: 1

                                Text {
                                    id: codecText
                                    anchors.centerIn: parent
                                    text: (root.audioSpecs ? root.audioSpecs.codec : "AAC") + " • " + (root.audioSpecs ? root.audioSpecs.bitrate_str : "192 kbps")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: "#1ed760"
                                }
                            }

                            // Source Pill
                            Rectangle {
                                height: 20
                                width: srcText.implicitWidth + 12
                                radius: 4
                                color: Qt.rgba(0.12, 0.12, 0.14, 0.9)
                                border.color: Qt.rgba(1, 1, 1, 0.12)
                                border.width: 1

                                Text {
                                    id: srcText
                                    anchors.centerIn: parent
                                    text: (root.track && root.track.isLocal) ? "LOCAL" : "YT MUSIC"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: Theme.textSecondary
                                }
                            }

                            // Year Pill (if available)
                            Rectangle {
                                visible: !!yearText.text
                                height: 20
                                width: yearText.implicitWidth + 12
                                radius: 4
                                color: Qt.rgba(0.12, 0.12, 0.14, 0.9)
                                border.color: Qt.rgba(1, 1, 1, 0.12)
                                border.width: 1

                                Text {
                                    id: yearText
                                    anchors.centerIn: parent
                                    text: root.songDetails && root.songDetails.year ? root.songDetails.year : (root.track && root.track.year ? root.track.year : "")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: Theme.textSecondary
                                }
                            }
                        }
                    }

                    // 3. Audio Engine Specs Card (Dark Glass Grid 2x2)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredWidth: root.isCompact ? 260 : 280
                        Layout.maximumWidth: 320
                        Layout.preferredHeight: 96
                        Layout.alignment: Qt.AlignHCenter
                        radius: 8
                        color: "#161618"
                        border.color: "#28282c"
                        border.width: 1

                        GridLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            columns: 2
                            rowSpacing: 10
                            columnSpacing: 16

                            // 1. Codec
                            ColumnLayout {
                                spacing: 2
                                Text {
                                    text: "CODEC"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    font.bold: true
                                    color: Theme.textMuted
                                }
                                Text {
                                    text: root.audioSpecs ? root.audioSpecs.codec : "AAC"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: Theme.textPrimary
                                }
                            }

                            // 2. Bitrate
                            ColumnLayout {
                                spacing: 2
                                Text {
                                    text: "BITRATE"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    font.bold: true
                                    color: Theme.textMuted
                                }
                                Text {
                                    text: root.audioSpecs ? root.audioSpecs.bitrate_str : "192 kbps"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: Theme.textPrimary
                                }
                            }

                            // 3. Sample Rate
                            ColumnLayout {
                                spacing: 2
                                Text {
                                    text: "SAMPLE RATE"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    font.bold: true
                                    color: Theme.textMuted
                                }
                                Text {
                                    text: root.audioSpecs ? root.audioSpecs.sample_rate_str : "44.1 kHz"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: Theme.textPrimary
                                }
                            }

                            // 4. Channels
                            ColumnLayout {
                                spacing: 2
                                Text {
                                    text: "CHANNELS"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    font.bold: true
                                    color: Theme.textMuted
                                }
                                Text {
                                    text: root.audioSpecs ? root.audioSpecs.channels : "Stereo (2ch)"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: Theme.textPrimary
                                }
                            }
                        }
                    }

                    // 4. SimpMusic Artist Card (Avatar, Label "Nghệ sĩ", Name & Subscribers)
                    Rectangle {
                        id: artistCard
                        Layout.fillWidth: true
                        Layout.preferredWidth: root.isCompact ? 260 : 280
                        Layout.maximumWidth: 320
                        Layout.preferredHeight: 164
                        Layout.alignment: Qt.AlignHCenter
                        radius: 12
                        color: "#161618"
                        border.color: artistCardMouse.containsMouse ? "#3e3e46" : "#28282c"
                        border.width: 1
                        clip: true
                        visible: (root.songDetails && (root.songDetails.author || root.songDetails.authorThumbnail)) || (root.track && root.track.artist)

                        // Shimmer placeholder when avatar is not yet loaded
                        Rectangle {
                            anchors.fill: artistImg
                            color: "#202024"
                            visible: artistImg.status !== Image.Ready
                            
                            SequentialAnimation on opacity {
                                running: artistImg.status !== Image.Ready
                                loops: Animation.Infinite
                                NumberAnimation { from: 0.35; to: 0.70; duration: 900; easing.type: Easing.InOutQuad }
                                NumberAnimation { from: 0.70; to: 0.35; duration: 900; easing.type: Easing.InOutQuad }
                            }
                        }

                        // Artist Banner / Thumbnail image
                        Image {
                            id: artistImg
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: 108
                            source: (root.songDetails && root.songDetails.authorThumbnail) ? root.songDetails.authorThumbnail : root.cachedArtistAvatar
                            fillMode: Image.PreserveAspectCrop
                            clip: true
                            asynchronous: true
                        }

                        // Smooth gradient scrim on top of photo
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: 108
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.60) }
                                GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.08) }
                                GradientStop { position: 1.0; color: Qt.rgba(0.08, 0.08, 0.09, 1.0) }
                            }
                        }

                        // Top-left "Nghệ sĩ" Badge
                        Text {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.margins: 10
                            text: "Nghệ sĩ"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: "#ffffff"
                        }

                        // Bottom Info: Artist Name & Subscribers
                        ColumnLayout {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 10
                            spacing: 3

                            // Shimmer placeholder state when loading
                            ColumnLayout {
                                visible: root.isDetailsLoading
                                spacing: 6

                                Rectangle {
                                    width: 130
                                    height: 14
                                    radius: 4
                                    color: "#38383e"
                                    SequentialAnimation on opacity {
                                        running: root.isDetailsLoading
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 0.35; to: 0.70; duration: 800; easing.type: Easing.InOutQuad }
                                        NumberAnimation { from: 0.70; to: 0.35; duration: 800; easing.type: Easing.InOutQuad }
                                    }
                                }

                                Rectangle {
                                    width: 80
                                    height: 11
                                    radius: 3
                                    color: "#28282c"
                                    SequentialAnimation on opacity {
                                        running: root.isDetailsLoading
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 0.35; to: 0.70; duration: 800; easing.type: Easing.InOutQuad }
                                        NumberAnimation { from: 0.70; to: 0.35; duration: 800; easing.type: Easing.InOutQuad }
                                    }
                                }
                            }

                            // Loaded real info
                            ColumnLayout {
                                visible: !root.isDetailsLoading
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    text: (root.songDetails && root.songDetails.author) ? root.songDetails.author : ""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: "#ffffff"
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: (root.songDetails && root.songDetails.subscribers) ? root.songDetails.subscribers : ""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    color: Theme.textMuted
                                    elide: Text.ElideRight
                                    visible: text !== ""
                                }
                            }
                        }

                        MouseArea {
                            id: artistCardMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                var aName = (root.songDetails && root.songDetails.author) ? root.songDetails.author : (root.track ? (root.track.artist || "") : "");
                                var aChannel = (root.songDetails && root.songDetails.channelId) ? root.songDetails.channelId : "";
                                if (aName) {
                                    root.openArtistRequested(aName, aChannel);
                                }
                            }
                        }
                    }

                    // 5. SimpMusic Info & Description Card (Release Date, Views, Interactive Likes/Dislikes, Description)
                    Rectangle {
                        id: infoDescCard
                        Layout.fillWidth: true
                        Layout.preferredWidth: root.isCompact ? 260 : 280
                        Layout.maximumWidth: 320
                        Layout.preferredHeight: (root.isDetailsLoading ? descShimmerCol.implicitHeight : descRealCol.implicitHeight) + 24
                        Layout.alignment: Qt.AlignHCenter
                        radius: 12
                        color: "#161618"
                        border.color: "#28282c"
                        border.width: 1

                        property bool isExpanded: false

                        ColumnLayout {
                            id: descCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 12
                            spacing: 8

                            // --- SHIMMER SKELETON STATE (when root.isDetailsLoading) ---
                            ColumnLayout {
                                id: descShimmerCol
                                Layout.fillWidth: true
                                visible: root.isDetailsLoading
                                spacing: 10

                                // 1. Release date shimmer
                                Rectangle {
                                    width: 110
                                    height: 12
                                    radius: 3
                                    color: "#28282c"
                                    SequentialAnimation on opacity {
                                        running: root.isDetailsLoading
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 0.35; to: 0.70; duration: 800; easing.type: Easing.InOutQuad }
                                        NumberAnimation { from: 0.70; to: 0.35; duration: 800; easing.type: Easing.InOutQuad }
                                    }
                                }

                                // 2. View count shimmer
                                Rectangle {
                                    width: 150
                                    height: 20
                                    radius: 4
                                    color: "#38383e"
                                    SequentialAnimation on opacity {
                                        running: root.isDetailsLoading
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 0.35; to: 0.70; duration: 800; easing.type: Easing.InOutQuad }
                                        NumberAnimation { from: 0.70; to: 0.35; duration: 800; easing.type: Easing.InOutQuad }
                                    }
                                }

                                // 3. Interactive Likes & Dislikes Row shimmer
                                RowLayout {
                                    spacing: 10

                                    Rectangle {
                                        width: 76
                                        height: 28
                                        radius: 14
                                        color: "#242428"
                                        SequentialAnimation on opacity {
                                            running: root.isDetailsLoading
                                            loops: Animation.Infinite
                                            NumberAnimation { from: 0.35; to: 0.70; duration: 800; easing.type: Easing.InOutQuad }
                                            NumberAnimation { from: 0.70; to: 0.35; duration: 800; easing.type: Easing.InOutQuad }
                                        }
                                    }

                                    Rectangle {
                                        width: 84
                                        height: 28
                                        radius: 14
                                        color: "#242428"
                                        SequentialAnimation on opacity {
                                            running: root.isDetailsLoading
                                            loops: Animation.Infinite
                                            NumberAnimation { from: 0.35; to: 0.70; duration: 800; easing.type: Easing.InOutQuad }
                                            NumberAnimation { from: 0.70; to: 0.35; duration: 800; easing.type: Easing.InOutQuad }
                                        }
                                    }
                                }

                                // 4. Like/Dislike Ratio mini bar shimmer
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 3
                                    radius: 1.5
                                    color: "#28282c"
                                    SequentialAnimation on opacity {
                                        running: root.isDetailsLoading
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 0.35; to: 0.70; duration: 800; easing.type: Easing.InOutQuad }
                                        NumberAnimation { from: 0.70; to: 0.35; duration: 800; easing.type: Easing.InOutQuad }
                                    }
                                }

                                // 5. Description Header shimmer
                                Rectangle {
                                    width: 50
                                    height: 12
                                    radius: 3
                                    color: "#38383e"
                                    SequentialAnimation on opacity {
                                        running: root.isDetailsLoading
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 0.35; to: 0.70; duration: 800; easing.type: Easing.InOutQuad }
                                        NumberAnimation { from: 0.70; to: 0.35; duration: 800; easing.type: Easing.InOutQuad }
                                    }
                                }

                                // 6. Description Paragraph shimmer (staggered lines)
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 11
                                        radius: 3
                                        color: "#28282c"
                                        SequentialAnimation on opacity {
                                            running: root.isDetailsLoading
                                            loops: Animation.Infinite
                                            NumberAnimation { from: 0.35; to: 0.70; duration: 800; easing.type: Easing.InOutQuad }
                                            NumberAnimation { from: 0.70; to: 0.35; duration: 800; easing.type: Easing.InOutQuad }
                                        }
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: Math.max(120, (infoDescCard.width - 24) * 0.85)
                                        height: 11
                                        radius: 3
                                        color: "#28282c"
                                        SequentialAnimation on opacity {
                                            running: root.isDetailsLoading
                                            loops: Animation.Infinite
                                            NumberAnimation { from: 0.35; to: 0.70; duration: 800; easing.type: Easing.InOutQuad }
                                            NumberAnimation { from: 0.70; to: 0.35; duration: 800; easing.type: Easing.InOutQuad }
                                        }
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: Math.max(90, (infoDescCard.width - 24) * 0.58)
                                        height: 11
                                        radius: 3
                                        color: "#28282c"
                                        SequentialAnimation on opacity {
                                            running: root.isDetailsLoading
                                            loops: Animation.Infinite
                                            NumberAnimation { from: 0.35; to: 0.70; duration: 800; easing.type: Easing.InOutQuad }
                                            NumberAnimation { from: 0.70; to: 0.35; duration: 800; easing.type: Easing.InOutQuad }
                                        }
                                    }
                                }
                            }

                            // --- LOADED REAL CONTENT (when !root.isDetailsLoading) ---
                            ColumnLayout {
                                id: descRealCol
                                Layout.fillWidth: true
                                visible: !root.isDetailsLoading
                                spacing: 8

                                // 1. Release date
                                Text {
                                    Layout.fillWidth: true
                                    text: {
                                        var d = (root.songDetails && (root.songDetails.dateText || root.songDetails.publishDate)) ? (root.songDetails.dateText || root.songDetails.publishDate) : ((root.track && root.track.year) ? root.track.year : "");
                                        return d ? ("Phát hành lúc " + d) : "Đã phát hành";
                                    }
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    color: Theme.textMuted
                                }

                                // 2. View Count
                                Text {
                                    Layout.fillWidth: true
                                    text: ((root.songDetails && root.songDetails.viewsStr && root.songDetails.viewsStr !== "--") ? root.songDetails.viewsStr : "0") + " lượt xem"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: "#ffffff"
                                }

                                // 3. Interactive Likes & Dislikes Row
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    // Like interactive button
                                    Rectangle {
                                        height: 28
                                        Layout.preferredWidth: likeRow.implicitWidth + 16
                                        radius: 14
                                        color: root.currentLikeStatus === "LIKE" ? Qt.rgba(0.12, 0.84, 0.38, 0.20) : (likeH.hovered ? "#242428" : "#1a1a1d")
                                        border.color: root.currentLikeStatus === "LIKE" ? "#1ed760" : "#2c2c30"
                                        border.width: 1

                                        RowLayout {
                                            id: likeRow
                                            anchors.centerIn: parent
                                            spacing: 5

                                            SpotifyIcon {
                                                source: "../assets/icons/thumb-up-symbolic.svg"
                                                iconSize: 12
                                                color: root.currentLikeStatus === "LIKE" ? "#1ed760" : "#ffffff"
                                            }

                                            Text {
                                                text: root.localLikesCount > 0 ? (root.songDetails && root.songDetails.likesStr ? root.songDetails.likesStr : "" + root.localLikesCount) + " thích" : "Thích"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 11
                                                font.bold: true
                                                color: root.currentLikeStatus === "LIKE" ? "#1ed760" : "#ffffff"
                                            }
                                        }

                                        HoverHandler { id: likeH }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.toggleLike()
                                        }
                                    }

                                    // Dislike interactive button
                                    Rectangle {
                                        height: 28
                                        Layout.preferredWidth: dislikeRow.implicitWidth + 16
                                        radius: 14
                                        color: root.currentLikeStatus === "DISLIKE" ? Qt.rgba(1.0, 0.25, 0.25, 0.20) : (dislikeH.hovered ? "#242428" : "#1a1a1d")
                                        border.color: root.currentLikeStatus === "DISLIKE" ? "#ff4444" : "#2c2c30"
                                        border.width: 1

                                        RowLayout {
                                            id: dislikeRow
                                            anchors.centerIn: parent
                                            spacing: 5

                                            SpotifyIcon {
                                                source: "../assets/icons/thumb-down-symbolic.svg"
                                                iconSize: 12
                                                color: root.currentLikeStatus === "DISLIKE" ? "#ff4444" : "#ffffff"
                                            }

                                            Text {
                                                text: root.localDislikesCount > 0 ? (root.songDetails && root.songDetails.dislikesStr ? root.songDetails.dislikesStr : "" + root.localDislikesCount) + " không thích" : "Không thích"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 11
                                                font.bold: true
                                                color: root.currentLikeStatus === "DISLIKE" ? "#ff4444" : Theme.textSecondary
                                            }
                                        }

                                        HoverHandler { id: dislikeH }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.toggleDislike()
                                        }
                                    }

                                    Item { Layout.fillWidth: true }
                                }

                                // Like/Dislike Ratio mini bar
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 3
                                    radius: 1.5
                                    color: "#282828"

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: parent.width * (root.songDetails ? (root.songDetails.likeRatio / 100.0) : 1.0)
                                        radius: 1.5
                                        color: "#1ed760"
                                    }
                                }

                                // 4. Description Header
                                Text {
                                    text: "Mô tả"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: "#ffffff"
                                }

                                // 5. Description Content Text
                                Text {
                                    id: descText
                                    Layout.fillWidth: true
                                    text: (root.songDetails && root.songDetails.description) ? root.songDetails.description : "Không có mô tả cho bài hát này."
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    lineHeight: 1.3
                                    color: Theme.textSecondary
                                    wrapMode: Text.Wrap
                                    maximumLineCount: infoDescCard.isExpanded ? 100 : 4
                                    elide: infoDescCard.isExpanded ? Text.ElideNone : Text.ElideRight
                                }

                                // Expand / Collapse button
                                Text {
                                    visible: descText.lineCount > 4 || (root.songDetails && root.songDetails.description && root.songDetails.description.length > 150)
                                    text: infoDescCard.isExpanded ? "Thu gọn ▲" : "Xem thêm ▼"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: Theme.spotifyGreen

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: infoDescCard.isExpanded = !infoDescCard.isExpanded
                                    }
                                }
                            }
                        }
                    }

                    // 6. Album & Release Details Box (Clean, zero SimpMusic text)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredWidth: root.isCompact ? 260 : 280
                        Layout.maximumWidth: 320
                        Layout.preferredHeight: albRow.implicitHeight + 16
                        Layout.alignment: Qt.AlignHCenter
                        radius: 10
                        color: albH.hovered ? "#1c1c20" : "#161618"
                        border.color: "#28282c"
                        border.width: 1

                        RowLayout {
                            id: albRow
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            SpotifyIcon {
                                source: "../assets/icons/media-optical-audio-symbolic.svg"
                                iconSize: 18
                                color: Theme.spotifyGreen
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: (root.songDetails && root.songDetails.albumBrowseId) ? "ALBUM" : "ALBUM / SINGLE"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    font.bold: true
                                    color: Theme.textMuted
                                }

                                Rectangle {
                                    visible: root.isDetailsLoading && (!root.track || !root.track.album)
                                    width: 120
                                    height: 12
                                    radius: 3
                                    color: "#28282c"
                                    SequentialAnimation on opacity {
                                        running: root.isDetailsLoading && (!root.track || !root.track.album)
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 0.35; to: 0.70; duration: 800; easing.type: Easing.InOutQuad }
                                        NumberAnimation { from: 0.70; to: 0.35; duration: 800; easing.type: Easing.InOutQuad }
                                    }
                                }

                                Text {
                                    visible: !(root.isDetailsLoading && (!root.track || !root.track.album))
                                    Layout.fillWidth: true
                                    text: root.track && root.track.album ? root.track.album : (root.songDetails && root.songDetails.album ? root.songDetails.album : "Single")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: Theme.textPrimary
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        HoverHandler { id: albH }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: (root.songDetails && root.songDetails.albumBrowseId) ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (root.songDetails && root.songDetails.albumBrowseId) {
                                    root.viewAlbumRequested({
                                        "browseId": root.songDetails.albumBrowseId,
                                        "title": root.songDetails.album || "Album",
                                        "artist": (root.songDetails.artist || "")
                                    });
                                }
                            }
                        }
                    }

                    // 6. Quick Action Chips Row
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: root.isCompact ? 260 : 280
                        Layout.maximumWidth: 320
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8

                        // Action 1: Download or Open folder
                        Rectangle {
                            Layout.fillWidth: true
                            height: 32
                            radius: 16
                            color: actDlH.hovered ? "#282828" : "#1a1a1c"
                            border.color: "#2c2c30"
                            border.width: 1

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6

                                SpotifyIcon {
                                    source: (root.track && root.track.isLocal) ? "../assets/icons/folder-music-symbolic.svg" : "../assets/icons/download-symbolic.svg"
                                    iconSize: 13
                                    color: "#ffffff"
                                }

                                Text {
                                    text: (root.track && root.track.isLocal) ? "Thư mục" : "Tải bài"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: "#ffffff"
                                }
                            }

                            HoverHandler { id: actDlH }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.track && root.track.isLocal) {
                                        root.openFolderRequested(root.track);
                                    } else {
                                        root.downloadTrackRequested(root.track);
                                    }
                                }
                            }
                        }

                        // Action 2: Start Radio
                        Rectangle {
                            Layout.fillWidth: true
                            height: 32
                            radius: 16
                            color: actRadH.hovered ? "#282828" : "#1a1a1c"
                            border.color: "#2c2c30"
                            border.width: 1

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6

                                SpotifyIcon {
                                    source: "../assets/icons/radio-symbolic.svg"
                                    iconSize: 13
                                    color: "#ffffff"
                                }

                                Text {
                                    text: "Radio"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: "#ffffff"
                                }
                            }

                            HoverHandler { id: actRadH }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.startRadioRequested(root.track)
                            }
                        }

                        // Action 3: Copy Link
                        Rectangle {
                            Layout.fillWidth: true
                            height: 32
                            radius: 16
                            color: actCpH.hovered ? "#282828" : "#1a1a1c"
                            border.color: "#2c2c30"
                            border.width: 1

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6

                                SpotifyIcon {
                                    source: "../assets/icons/edit-select-all-symbolic.svg"
                                    iconSize: 12
                                    color: "#ffffff"
                                }

                                Text {
                                    text: "Sao chép"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: "#ffffff"
                                }
                            }

                            HoverHandler { id: actCpH }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var link = (root.track && root.track.videoId)
                                        ? ("https://music.youtube.com/watch?v=" + root.track.videoId)
                                        : (root.track ? (root.track.path || "") : "");
                                    root.copyLinkRequested(link);
                                }
                            }
                        }
                    }

                    Item { Layout.preferredHeight: 12 }
                }
            }

            // Right: Amberol Synced Lyrics Flow
            Rectangle {
                id: lyricsCard
                visible: !root.isCompact || root.compactTab === "lyrics"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: root.isCompact ? 200 : 300
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
