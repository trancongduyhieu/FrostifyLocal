import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtQuick.Effects
import "."

Rectangle {
    id: root
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.70)
    visible: false
    z: 10006

    property var currentTrack: null
    property string resolvedCover: ""
    property var availableTracks: []
    property string userAvatar: ""
    property string userName: ""
    property color accentColor: Theme.accent

    property var attachedTrack: null
    property bool isPickingTrack: false
    property string trackSearchQuery: ""
    property var onlineSearchResults: []
    property bool isSearchingOnline: false
    property string activeNoteText: ""

    signal closeRequested()
    signal noteSubmitted(string text, var track)

    function updateActiveNoteText() {
        var pt = (noteInput.preeditText !== undefined && noteInput.preeditText !== null) ? String(noteInput.preeditText).trim() : "";
        var t = (noteInput.text !== undefined && noteInput.text !== null) ? String(noteInput.text).trim() : "";
        if (pt.length > 0) {
            root.activeNoteText = (t.length > 0) ? (t + " " + pt).replace(/\s+/g, " ").trim() : pt;
        } else {
            root.activeNoteText = t;
        }
    }

    function getCurrentNoteText() {
        updateActiveNoteText();
        return root.activeNoteText;
    }

    function openModal() {
        root.isPickingTrack = false;
        root.trackSearchQuery = "";
        root.onlineSearchResults = [];
        root.isSearchingOnline = false;
        noteInput.text = "";
        root.activeNoteText = "";
        root.attachedTrack = root.currentTrack;
        root.visible = true;
        noteInput.forceActiveFocus();
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
                        console.log("PostNoteModal search parse error:", e);
                    }
                }
            }
        };
        xhr.send();
    }

    Timer {
        id: searchDebounceTimer
        interval: 350
        repeat: false
        onTriggered: root.performOnlineSearch()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (root.isPickingTrack) {
                root.isPickingTrack = false;
            } else {
                root.closeRequested();
            }
        }
    }

    // Modal Main Container (Dark Glass Canvas)
    Rectangle {
        id: dialogCard
        width: 440
        height: root.isPickingTrack ? 490 : 390
        anchors.centerIn: parent
        radius: 18
        color: Qt.rgba(0.06 + root.accentColor.r * 0.05, 0.06 + root.accentColor.g * 0.05, 0.08 + root.accentColor.b * 0.07, 0.96)
        border.color: Qt.rgba(255, 255, 255, 0.12)
        border.width: 1

        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        // Prevent click-through
        MouseArea {
            anchors.fill: parent
            onClicked: (mouse) => {
                mouse.accepted = true;
            }
        }

        // ==========================================
        // VIEW 1: NOTE CREATION VIEW (!root.isPickingTrack)
        // ==========================================
        ColumnLayout {
            id: noteCreationCol
            anchors.fill: parent
            anchors.margins: 20
            spacing: 0
            visible: !root.isPickingTrack

            // TOP BAR: '✕' (Left) | Title (Center) | 'Chia sẻ' (Right) - ALL BORDERLESS
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 32

                // Plain '✕' Close Button (Zero border, zero background box)
                MouseArea {
                    id: closeMouse
                    width: 28; height: 28
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()

                    AppIcon {
                        anchors.centerIn: parent
                        source: "../assets/icons/window-close-symbolic.svg"
                        iconSize: 15
                        color: closeMouse.containsMouse ? "#f43f5e" : Qt.rgba(1, 1, 1, 0.75)
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }

                Item { Layout.fillWidth: true }

                // Title "Ghi chú mới"
                Text {
                    text: I18n.tr("Ghi chú mới", "New note")
                    color: "#ffffff"
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                // Plain "Chia sẻ" Share Text Button (Zero border, zero background box)
                Text {
                    id: shareBtnText
                    text: I18n.tr("Chia sẻ", "Share")
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.bold: true

                    readonly property bool canSubmit: root.activeNoteText.length > 0 && root.activeNoteText.length <= 60

                    color: !canSubmit
                        ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.35)
                        : (shareMouse.containsMouse ? "#ffffff" : root.accentColor)
                    Behavior on color { ColorAnimation { duration: 150 } }

                    MouseArea {
                        id: shareMouse
                        anchors.fill: parent
                        anchors.margins: -8
                        hoverEnabled: true
                        cursorShape: shareBtnText.canSubmit ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            noteInput.focus = false;
                            var t = root.getCurrentNoteText();
                            if (!t || t.length > 60) return;
                            root.noteSubmitted(t, root.attachedTrack);
                        }
                    }
                }
            }

            // Spacing
            Item { Layout.fillWidth: true; Layout.preferredHeight: 14 }

            // CENTER: FLOATING THOUGHT BUBBLE + CIRCULAR AVATAR (Messenger Style - Ảnh 1 & 2)
            Item {
                id: centerArea
                Layout.fillWidth: true
                Layout.preferredHeight: 250

                // User Circular Avatar (68x68) - Anchored at bottom of center area
                Item {
                    id: modalAvatarWrapper
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 10
                    width: 68; height: 68

                    // Outer Border Ring
                    Rectangle {
                        anchors.fill: parent
                        radius: 34
                        color: "transparent"
                        border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.5)
                        border.width: 1.5
                    }

                    // Circle Mask for Modal Avatar
                    Rectangle {
                        id: modalAvatarMask
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: 32
                        color: "#ffffff"
                        visible: false
                        layer.enabled: true
                    }

                    // Masked Container
                    Item {
                        anchors.fill: parent
                        anchors.margins: 2
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: modalAvatarMask
                            autoPaddingEnabled: false
                        }

                        // Background fallback letter
                        Rectangle {
                            anchors.fill: parent
                            color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.25)

                            Text {
                                anchors.centerIn: parent
                                text: (root.userName && root.userName.length > 0) ? root.userName.substring(0, 1).toUpperCase() : "U"
                                color: "#ffffff"
                                font.family: Theme.fontFamily
                                font.pixelSize: 24
                                font.bold: true
                            }
                        }

                        // Profile Image
                        Image {
                            id: modalAvatarImg
                            anchors.fill: parent
                            source: root.userAvatar || ""
                            fillMode: Image.PreserveAspectCrop
                            visible: root.userAvatar !== ""
                            asynchronous: true
                            cache: true
                        }
                    }
                }

                // Connector Dot 1 (Small: 5px, just above avatar)
                Rectangle {
                    id: dot1
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: modalAvatarWrapper.top
                    anchors.bottomMargin: 4
                    width: 5; height: 5; radius: 2.5
                    color: thoughtBubble.color
                }

                // Connector Dot 2 (Medium: 8px, above dot1)
                Rectangle {
                    id: dot2
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: dot1.top
                    anchors.bottomMargin: 3
                    width: 8; height: 8; radius: 4
                    color: thoughtBubble.color
                }

                // Floating Thought Bubble Container (Grows upwards from dot2, desktop width: 340)
                Rectangle {
                    id: thoughtBubble
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: dot2.top
                    anchors.bottomMargin: 3
                    width: 340
                    height: bubbleCol.implicitHeight + 20
                    radius: 18
                    color: Qt.rgba(0.08 + root.accentColor.r * 0.10, 0.10 + root.accentColor.g * 0.10, 0.14 + root.accentColor.b * 0.16, 0.95)
                    border.color: root.activeNoteText.length > 60
                        ? "#f43f5e"
                        : (noteInput.activeFocus ? root.accentColor : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.35))
                    border.width: 1.5

                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    ColumnLayout {
                        id: bubbleCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 8

                        // Text Input Area
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.max(34, noteInput.contentHeight)

                            // Placeholder: Centered, disappears immediately when typing
                            Text {
                                anchors.fill: parent
                                text: I18n.tr("Chia sẻ suy nghĩ...", "Share a thought...")
                                color: Qt.rgba(1, 1, 1, 0.40)
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                visible: root.activeNoteText.length === 0
                            }

                            TextEdit {
                                id: noteInput
                                anchors.fill: parent
                                color: "#ffffff"
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                wrapMode: TextEdit.Wrap
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                selectByMouse: true

                                onTextChanged: root.updateActiveNoteText()
                                onPreeditTextChanged: root.updateActiveNoteText()
                                onInputMethodComposingChanged: root.updateActiveNoteText()
                            }
                        }

                        // Red Warning if > 60 characters (NO "0/60" shown normally)
                        Text {
                            visible: root.activeNoteText.length > 60
                            text: I18n.tr("Đã vượt quá 60 ký tự (" + root.activeNoteText.length + "/60)", "Exceeded 60 chars (" + root.activeNoteText.length + "/60)")
                            color: "#f43f5e"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                            Layout.alignment: Qt.AlignHCenter
                        }

                        // Attached Track Music Row (Inside thought bubble)
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30

                            // Case 1: Track is attached -> Cover art + Title & Artist + Change btn + Detach '✕' btn
                            RowLayout {
                                anchors.fill: parent
                                spacing: 8
                                visible: root.attachedTrack !== null

                                // Album Art Thumbnail (28x28, R=4)
                                Rectangle {
                                    width: 28; height: 28; radius: 4
                                    color: Qt.rgba(1, 1, 1, 0.08)
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        source: {
                                            if (!root.attachedTrack) return "";
                                            if (root.attachedTrack === root.currentTrack && root.resolvedCover) return root.resolvedCover;
                                            return root.attachedTrack.image || root.attachedTrack.cover || "";
                                        }
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                    }

                                    AppIcon {
                                        anchors.centerIn: parent
                                        source: "../assets/icons/folder-music-symbolic.svg"
                                        iconSize: 12
                                        color: root.accentColor
                                        visible: {
                                            var c = (root.attachedTrack === root.currentTrack && root.resolvedCover) ? root.resolvedCover : (root.attachedTrack ? (root.attachedTrack.image || root.attachedTrack.cover) : "");
                                            return !c;
                                        }
                                    }
                                }

                                // Title & Artist
                                Column {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        text: root.attachedTrack ? (root.attachedTrack.title || root.attachedTrack.name || "Track") : ""
                                        color: "#ffffff"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.bold: true
                                        elide: Text.ElideRight
                                        width: 190
                                    }

                                    Text {
                                        text: root.attachedTrack ? (root.attachedTrack.artist || "") : ""
                                        color: Qt.rgba(1, 1, 1, 0.6)
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 9
                                        elide: Text.ElideRight
                                        width: 190
                                        visible: text.length > 0
                                    }
                                }

                                // 🔍 Change Track Button
                                MouseArea {
                                    id: changeTrackBtn
                                    width: 22; height: 22
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.trackSearchQuery = "";
                                        pickerSearchInput.text = "";
                                        root.onlineSearchResults = [];
                                        root.isPickingTrack = true;
                                        pickerSearchInput.forceActiveFocus();
                                    }

                                    AppIcon {
                                        anchors.centerIn: parent
                                        source: "../assets/icons/system-search-symbolic.svg"
                                        iconSize: 12
                                        color: changeTrackBtn.containsMouse ? "#ffffff" : root.accentColor
                                    }
                                }

                                // ✕ Remove / Detach Track Button (NẰM NGAY CẠNH BÀI HÁT ĐÍNH KÈM!)
                                MouseArea {
                                    id: removeTrackBtn
                                    width: 22; height: 22
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.attachedTrack = null;
                                        root.isPickingTrack = false;
                                    }

                                    AppIcon {
                                        anchors.centerIn: parent
                                        source: "../assets/icons/window-close-symbolic.svg"
                                        iconSize: 12
                                        color: removeTrackBtn.containsMouse ? "#f43f5e" : Qt.rgba(1, 1, 1, 0.55)
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                    }
                                }
                            }

                            // Case 2: No track attached -> Subtle options to attach
                            RowLayout {
                                anchors.fill: parent
                                spacing: 8
                                visible: root.attachedTrack === null

                                // Option A: Attach currently playing song (if playing)
                                MouseArea {
                                    id: attachCurBtn
                                    visible: root.currentTrack !== null
                                    Layout.preferredHeight: 22
                                    Layout.preferredWidth: attachCurRow.implicitWidth + 8
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.attachedTrack = root.currentTrack;
                                    }

                                    Row {
                                        id: attachCurRow
                                        anchors.centerIn: parent
                                        spacing: 4

                                        AppIcon {
                                            anchors.verticalCenter: parent.verticalCenter
                                            source: "../assets/icons/folder-music-symbolic.svg"
                                            iconSize: 11
                                            color: attachCurBtn.containsMouse ? "#ffffff" : root.accentColor
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: I18n.tr("Bài đang phát", "Current song")
                                            color: attachCurBtn.containsMouse ? "#ffffff" : root.accentColor
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            font.bold: true
                                        }
                                    }
                                }

                                // Option B: Search & pick song
                                MouseArea {
                                    id: pickOtherBtn
                                    Layout.preferredHeight: 22
                                    Layout.preferredWidth: pickOtherRow.implicitWidth + 8
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.trackSearchQuery = "";
                                        pickerSearchInput.text = "";
                                        root.onlineSearchResults = [];
                                        root.isPickingTrack = true;
                                        pickerSearchInput.forceActiveFocus();
                                    }

                                    Row {
                                        id: pickOtherRow
                                        anchors.centerIn: parent
                                        spacing: 4

                                        AppIcon {
                                            anchors.verticalCenter: parent.verticalCenter
                                            source: "../assets/icons/system-search-symbolic.svg"
                                            iconSize: 11
                                            color: pickOtherBtn.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.6)
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: I18n.tr("Chọn bài...", "Pick song...")
                                            color: pickOtherBtn.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.6)
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                        }
                                    }
                                }

                                Item { Layout.fillWidth: true }
                            }
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true; Layout.fillHeight: true }

            // BOTTOM SUBTITLE (Messenger Style)
            Text {
                Layout.fillWidth: true
                text: I18n.tr("Bạn bè có thể xem ghi chú của bạn trong 24 giờ", "Friends can see your note for 24 hours")
                color: Qt.rgba(1, 1, 1, 0.45)
                font.family: Theme.fontFamily
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
            }
        }

        // ==========================================
        // VIEW 2: MUSIC SEARCH VIEW (Ảnh 1: media_1789810673070.jpg)
        // ==========================================
        ColumnLayout {
            id: searchMusicCol
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12
            visible: root.isPickingTrack

            // TOP SEARCH HEADER (Ảnh 1: Back Arrow + Search Pill)
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // Back Arrow Button '←'
                MouseArea {
                    id: backSearchMouse
                    width: 32; height: 32
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.isPickingTrack = false;
                        noteInput.forceActiveFocus();
                    }

                    AppIcon {
                        anchors.centerIn: parent
                        source: "../assets/icons/go-previous-symbolic.svg"
                        iconSize: 16
                        color: backSearchMouse.containsMouse ? root.accentColor : "#ffffff"
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                }

                // Search Pill Container (Ảnh 1)
                Rectangle {
                    Layout.fillWidth: true
                    height: 38
                    radius: 19
                    color: Qt.rgba(1, 1, 1, 0.08)
                    border.color: pickerSearchInput.activeFocus ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.4) : Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 10
                        spacing: 8

                        AppIcon {
                            source: "../assets/icons/system-search-symbolic.svg"
                            iconSize: 15
                            color: pickerSearchInput.activeFocus ? root.accentColor : Qt.rgba(1, 1, 1, 0.5)
                        }

                        TextInput {
                            id: pickerSearchInput
                            Layout.fillWidth: true
                            color: "#ffffff"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            clip: true
                            selectByMouse: true

                            function updatePickerQuery() {
                                var pt = (pickerSearchInput.preeditText !== undefined && pickerSearchInput.preeditText !== null) ? String(pickerSearchInput.preeditText).trim() : "";
                                var t = (pickerSearchInput.text !== undefined && pickerSearchInput.text !== null) ? String(pickerSearchInput.text).trim() : "";
                                var q = (pt.length > 0) ? (t + " " + pt).replace(/\s+/g, " ").trim() : t;
                                root.trackSearchQuery = q;
                                searchDebounceTimer.restart();
                            }

                            onTextChanged: updatePickerQuery()
                            onPreeditTextChanged: updatePickerQuery()
                            onInputMethodComposingChanged: updatePickerQuery()
                            onAccepted: root.performOnlineSearch()

                            Text {
                                anchors.fill: parent
                                text: I18n.tr("Tìm kiếm nhạc", "Search music")
                                color: Qt.rgba(1, 1, 1, 0.45)
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                visible: !pickerSearchInput.text && !pickerSearchInput.inputMethodComposing
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        // Clear search button '✕'
                        MouseArea {
                            visible: pickerSearchInput.text.length > 0
                            width: 20; height: 20
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                pickerSearchInput.text = "";
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
            }

            // Status Indicator (Searching...)
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 14
                visible: root.isSearchingOnline

                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    AppIcon {
                        source: "../assets/icons/process-working-symbolic.svg"
                        iconSize: 11
                        color: root.accentColor
                    }
                    Text {
                        text: I18n.tr("Đang tìm kiếm nhạc trực tuyến...", "Searching online music...")
                        color: Qt.rgba(1, 1, 1, 0.5)
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }
                }
            }

            // Tracks ListView (Styled exactly like Ảnh 1: media_1789810673070.jpg)
            ListView {
                id: pickerListView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6

                model: {
                    if (root.trackSearchQuery.trim().length > 0) {
                        return root.onlineSearchResults;
                    }
                    // Fallback to queue and library tracks when search query is empty
                    var list = (root.availableTracks && root.availableTracks.length > 0) ? root.availableTracks : (root.currentTrack ? [root.currentTrack] : []);
                    return list;
                }

                delegate: Rectangle {
                    id: songRowCard
                    width: pickerListView.width
                    height: 56
                    radius: 10
                    color: songRowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 12

                        // Album Artwork Thumbnail (44x44, R=8, Ảnh 1)
                        Rectangle {
                            width: 44; height: 44
                            radius: 8
                            color: Qt.rgba(1, 1, 1, 0.08)
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: modelData.image || modelData.cover || ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }

                            AppIcon {
                                anchors.centerIn: parent
                                source: "../assets/icons/folder-music-symbolic.svg"
                                iconSize: 18
                                color: root.accentColor
                                visible: !(modelData.image || modelData.cover)
                            }
                        }

                        // Middle: Song Title (bold, 13px) & Artist (11px, muted)
                        Column {
                            Layout.fillWidth: true
                            spacing: 3

                            Text {
                                text: modelData.title || modelData.name || "Track"
                                color: "#ffffff"
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.bold: true
                                elide: Text.ElideRight
                                width: songRowCard.width - 120
                            }

                            Text {
                                text: modelData.artist || "Unknown Artist"
                                color: Qt.rgba(1, 1, 1, 0.55)
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                width: songRowCard.width - 120
                            }
                        }

                        // Right: Circular Action Button (32x32, R=16, Ảnh 1)
                        Rectangle {
                            width: 32; height: 32
                            radius: 16
                            color: songRowMouse.containsMouse ? root.accentColor : Qt.rgba(1, 1, 1, 0.10)
                            Behavior on color { ColorAnimation { duration: 120 } }

                            AppIcon {
                                anchors.centerIn: parent
                                anchors.horizontalCenterOffset: 1
                                source: "../assets/icons/media-playback-start-symbolic.svg"
                                iconSize: 12
                                color: "#ffffff"
                            }
                        }
                    }

                    MouseArea {
                        id: songRowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.attachedTrack = modelData;
                            root.isPickingTrack = false;
                            noteInput.forceActiveFocus();
                        }
                    }
                }
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            root.openModal();
        }
    }
}
