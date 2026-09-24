import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtQuick.Effects
import "."

Rectangle {
    id: root
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.65)
    visible: false
    z: 10006

    property var playlist: null
    property var currentTrack: null
    property bool isPlaying: false
    property var availableTracks: []
    property color accentColor: Theme.accent

    property string trackSearchQuery: ""
    property var onlineSearchResults: []
    property bool isSearchingOnline: false
    property var addedTrackKeys: ({}) // trackKey -> true for instant UI feedback

    signal closeRequested()
    signal trackAddRequested(var track)
    signal previewTrackRequested(var track)

    function isSameTrack(a, b) {
        if (!a || !b) return false;
        if (a.videoId && b.videoId && a.videoId === b.videoId) return true;
        if (a.path && b.path && a.path === b.path) return true;
        if (a.id && b.id && a.id === b.id) return true;
        return (a.title && b.title && a.title === b.title && a.artist === b.artist);
    }

    function getTrackKey(t) {
        if (!t) return "";
        if (t.videoId) return "yt_" + t.videoId;
        if (t.path) {
            if (t.path.startsWith("ytdl://")) return "yt_" + t.path.replace("ytdl://", "");
            return "local_" + t.path;
        }
        if (t.id) return "id_" + t.id;
        return (t.title || "") + "_" + (t.artist || "");
    }

    function isTrackInPlaylist(t) {
        var key = getTrackKey(t);
        if (!key) return false;
        if (addedTrackKeys[key]) return true;
        if (!root.playlist || !root.playlist.tracks) return false;
        var trks = root.playlist.tracks;
        var len = trks.length || 0;
        for (var i = 0; i < len; i++) {
            if (getTrackKey(trks[i]) === key) return true;
        }
        return false;
    }

    function openModal(pl) {
        root.playlist = pl || null;
        root.trackSearchQuery = "";
        root.onlineSearchResults = [];
        root.isSearchingOnline = false;
        root.addedTrackKeys = {};
        root.visible = true;
        searchInput.text = "";
        searchInput.forceActiveFocus();
    }

    function closeModal() {
        searchInput.focus = false;
        root.visible = false;
        root.closeRequested();
    }

    function performOnlineSearch() {
        var q = root.trackSearchQuery.trim();
        if (!q) {
            root.onlineSearchResults = [];
            root.isSearchingOnline = false;
            return;
        }
        root.isSearchingOnline = true;
        var xhr = new XMLHttpRequest();
        var url = "http://127.0.0.1:17890/api/filter_search?q=" + encodeURIComponent(q) + "&filter=songs";
        xhr.open("GET", url, true);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                root.isSearchingOnline = false;
                if (xhr.status === 200) {
                    try {
                        var res = JSON.parse(xhr.responseText);
                        if (Array.isArray(res)) {
                            root.onlineSearchResults = res;
                        }
                    } catch(e) {
                        console.log("PlaylistTrackSearchModal search parse error:", e);
                    }
                }
            }
        };
        xhr.send();
    }

    Timer {
        id: searchDebounceTimer
        interval: 200
        repeat: false
        onTriggered: root.performOnlineSearch()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.closeModal()
    }

    // Modal Card
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(540, parent.width - 32)
        height: Math.min(560, parent.height - 48)
        radius: 18
        color: Qt.rgba(0.08, 0.09, 0.13, 0.96)
        border.color: Qt.rgba(255, 255, 255, 0.14)
        border.width: 1

        MouseArea {
            anchors.fill: parent
            // Prevent clicks from dismissing
        }

        // Top-Right Close Button (Pinned firmly to top-right corner of modal card - ui-layout-design-rules)
        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 18
            z: 20
            width: 32
            height: 32
            radius: 16
            color: closeArea.containsMouse ? Qt.rgba(255, 255, 255, 0.14) : Qt.rgba(255, 255, 255, 0.06)
            border.color: Qt.rgba(255, 255, 255, 0.10)
            border.width: 1

            Behavior on color { ColorAnimation { duration: 120 } }

            AppIcon {
                anchors.centerIn: parent
                source: "../assets/icons/window-close-symbolic.svg"
                iconSize: 12
                color: closeArea.containsMouse ? "#ffffff" : Qt.rgba(255, 255, 255, 0.75)
            }

            MouseArea {
                id: closeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeModal()
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            // Header Row: Title and Playlist Name
            ColumnLayout {
                Layout.fillWidth: true
                Layout.rightMargin: 40 // Give clearance for pinned top-right close button
                spacing: 3

                Text {
                    text: I18n.tr("Thêm bài hát vào danh sách phát", "Add Songs to Playlist")
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    color: "#ffffff"
                }

                Text {
                    text: root.playlist ? (root.playlist.title || root.playlist.name || "") : ""
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: root.accentColor
                    elide: Text.ElideRight
                    visible: text.length > 0
                }
            }

            // Search Bar Pill
            Rectangle {
                Layout.fillWidth: true
                height: 42
                radius: 21
                color: Qt.rgba(1, 1, 1, 0.07)
                border.color: searchInput.activeFocus 
                              ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.5) 
                              : Qt.rgba(1, 1, 1, 0.10)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 12
                    spacing: 10

                    AppIcon {
                        source: "../assets/icons/system-search-symbolic.svg"
                        iconSize: 16
                        color: searchInput.activeFocus ? root.accentColor : Qt.rgba(1, 1, 1, 0.5)
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        color: "#ffffff"
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        clip: true
                        selectByMouse: true

                        function updateQuery() {
                            var pt = (searchInput.preeditText !== undefined && searchInput.preeditText !== null) ? String(searchInput.preeditText).trim() : "";
                            var t = (searchInput.text !== undefined && searchInput.text !== null) ? String(searchInput.text).trim() : "";
                            var q = (pt.length > 0) ? (t + " " + pt).replace(/\s+/g, " ").trim() : t;
                            root.trackSearchQuery = q;
                            searchDebounceTimer.restart();
                        }

                        onTextChanged: updateQuery()
                        onPreeditTextChanged: updateQuery()
                        onInputMethodComposingChanged: updateQuery()
                        onAccepted: root.performOnlineSearch()

                        Text {
                            anchors.fill: parent
                            text: I18n.tr("Nhập tên bài hát hoặc ca sĩ...", "Search song or artist name...")
                            color: Qt.rgba(1, 1, 1, 0.4)
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            visible: !searchInput.text && !searchInput.inputMethodComposing
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    // Clear button
                    MouseArea {
                        visible: searchInput.text.length > 0
                        width: 22
                        height: 22
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            searchInput.text = "";
                            root.trackSearchQuery = "";
                            root.onlineSearchResults = [];
                        }

                        AppIcon {
                            anchors.centerIn: parent
                            source: "../assets/icons/window-close-symbolic.svg"
                            iconSize: 11
                            color: Qt.rgba(1, 1, 1, 0.6)
                        }
                    }
                }
            }

            // Searching indicator
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.isSearchingOnline ? 18 : 0
                visible: root.isSearchingOnline
                clip: true

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    CircularSpinner {
                        size: 14
                        strokeWidth: 2.0
                        color: root.accentColor
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: I18n.tr("Đang tìm bài hát trực tuyến...", "Searching online songs...")
                        color: Qt.rgba(1, 1, 1, 0.6)
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Results List
            ListView {
                id: resultsList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                model: {
                    var q = root.trackSearchQuery.trim();
                    if (q.length > 0) {
                        if (root.onlineSearchResults && root.onlineSearchResults.length > 0) {
                            return root.onlineSearchResults;
                        }
                        // Instant local search filter while typing
                        var qLower = q.toLowerCase();
                        var locals = (root.availableTracks || []).filter(function(t) {
                            return (t.title && t.title.toLowerCase().indexOf(qLower) !== -1) ||
                                   (t.name && t.name.toLowerCase().indexOf(qLower) !== -1) ||
                                   (t.artist && t.artist.toLowerCase().indexOf(qLower) !== -1);
                        });
                        return locals;
                    }
                    return [];
                }

                delegate: Rectangle {
                    id: rowCard
                    width: resultsList.width
                    height: 56
                    radius: 10
                    readonly property var trk: modelData
                    readonly property bool inPl: root.isTrackInPlaylist(trk)
                    color: rowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent"

                    Behavior on color { ColorAnimation { duration: 100 } }

                    // Double-click row area to add track (leaves 90px on right for prevBtn and addBtn)
                    MouseArea {
                        id: rowMouse
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.rightMargin: 90
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton
                        cursorShape: Qt.PointingHandCursor
                        onDoubleClicked: {
                            if (!rowCard.inPl) {
                                var k = root.getTrackKey(trk);
                                if (k) {
                                    var updated = Object.assign({}, root.addedTrackKeys);
                                    updated[k] = true;
                                    root.addedTrackKeys = updated;
                                }
                                root.trackAddRequested(trk);
                            }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 12
                        spacing: 10

                        // Cover Artwork
                        RoundedImage {
                            width: 42
                            height: 42
                            radius: 8
                            source: trk ? (trk.image || trk.cover || trk.thumbnail || "") : ""
                            initialsText: trk ? (trk.title || trk.name || "") : ""
                            placeholderColor: Qt.rgba(1, 1, 1, 0.08)
                        }

                        // Title & Artist
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: trk ? (trk.title || trk.name || "") : ""
                                color: "#ffffff"
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: trk ? (trk.artist || "") : ""
                                color: Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                        }

                        // Duration
                        Text {
                            text: {
                                if (!trk || !trk.duration) return "";
                                if (typeof trk.duration === "number") {
                                    var m = Math.floor(trk.duration / 60);
                                    var s = Math.floor(trk.duration % 60);
                                    return m + ":" + (s < 10 ? "0" : "") + s;
                                }
                                return String(trk.duration);
                            }
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: Theme.textMuted
                        }

                        // Preview / Listen Button (Audition track before adding!)
                        Rectangle {
                            id: prevBtn
                            width: 34
                            height: 34
                            radius: 17
                            z: 2
                            readonly property bool isThisPlaying: (root.currentTrack && root.isSameTrack(root.currentTrack, trk) && root.isPlaying)
                            color: isThisPlaying 
                                   ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.25)
                                   : (prevMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.14) : Qt.rgba(255, 255, 255, 0.06))
                            border.color: isThisPlaying ? root.accentColor : Qt.rgba(255, 255, 255, 0.12)
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            AppIcon {
                                anchors.centerIn: parent
                                source: prevBtn.isThisPlaying ? "../assets/icons/media-playback-pause-symbolic.svg" : "../assets/icons/media-playback-start-symbolic.svg"
                                iconSize: 13
                                color: prevBtn.isThisPlaying ? root.accentColor : (prevMouse.containsMouse ? "#ffffff" : Qt.rgba(255, 255, 255, 0.8))
                            }

                            MouseArea {
                                id: prevMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                preventStealing: true
                                onClicked: {
                                    root.previewTrackRequested(trk);
                                }
                            }
                        }

                        // Add / Added Button
                        Rectangle {
                            id: addBtn
                            width: 34
                            height: 34
                            radius: 17
                            z: 2
                            color: rowCard.inPl 
                                   ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.25)
                                   : (addMouse.containsMouse ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.35) : Qt.rgba(1, 1, 1, 0.08))
                            border.color: rowCard.inPl ? root.accentColor : Qt.rgba(255, 255, 255, 0.12)
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            AppIcon {
                                anchors.centerIn: parent
                                source: rowCard.inPl ? "../assets/icons/emblem-ok-symbolic.svg" : "../assets/icons/list-add-symbolic.svg"
                                iconSize: 14
                                color: rowCard.inPl ? root.accentColor : (addMouse.containsMouse ? "#ffffff" : Qt.rgba(255, 255, 255, 0.75))
                            }

                            MouseArea {
                                id: addMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: rowCard.inPl ? Qt.ArrowCursor : Qt.PointingHandCursor
                                preventStealing: true
                                onClicked: {
                                    if (!rowCard.inPl) {
                                        var k = root.getTrackKey(trk);
                                        if (k) {
                                            var updated = Object.assign({}, root.addedTrackKeys);
                                            updated[k] = true;
                                            root.addedTrackKeys = updated;
                                        }
                                        root.trackAddRequested(trk);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Empty State Prompt (ui-layout-design-rules)
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: resultsList.count === 0 && !root.isSearchingOnline

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 52
                        height: 52
                        radius: 26
                        color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.12)
                        border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.25)
                        border.width: 1

                        AppIcon {
                            anchors.centerIn: parent
                            source: root.trackSearchQuery.trim().length === 0 
                                    ? "../assets/icons/system-search-symbolic.svg" 
                                    : "../assets/icons/dialog-information-symbolic.svg"
                            iconSize: 22
                            color: root.accentColor
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.trackSearchQuery.trim().length === 0
                              ? I18n.tr("Tìm kiếm bài hát yêu thích", "Search for your favorite songs")
                              : I18n.tr("Không tìm thấy bài hát nào", "No songs found")
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.bold: true
                        color: "#ffffff"
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.trackSearchQuery.trim().length === 0
                              ? I18n.tr("Nhập tên bài hát hoặc nghệ sĩ để tìm kiếm, nghe thử và thêm vào danh sách", "Type song or artist to search, preview, and add to playlist")
                              : I18n.tr("Hãy thử tìm kiếm với từ khóa khác", "Try searching with different keywords")
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: Qt.rgba(1, 1, 1, 0.5)
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }
}
