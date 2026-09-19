import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtQuick.Effects
import "."

Item {
    id: root
    anchors.fill: parent
    z: 9999
    visible: opacity > 0.001
    opacity: isOpen ? 1.0 : 0.0
    enabled: isOpen

    Behavior on opacity {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    property bool isOpen: false
    property var friendsNotes: []
    property int currentIndex: 0
    property color accentColor: (typeof win !== "undefined" && win.accentColor) ? win.accentColor : Theme.accent

    signal listenAlongRequested(var friendData)

    readonly property var currentFriend: (friendsNotes && friendsNotes.length > currentIndex && currentIndex >= 0) ? friendsNotes[currentIndex] : null

    function openWithIndex(idx) {
        if (friendsNotes && idx >= 0 && idx < friendsNotes.length) {
            currentIndex = idx;
        } else {
            currentIndex = 0;
        }
        isOpen = true;
    }

    function openWithFriend(friend) {
        if (!friendsNotes || friendsNotes.length === 0) {
            friendsNotes = friend ? [friend] : [];
            currentIndex = 0;
        } else {
            var found = -1;
            for (var i = 0; i < friendsNotes.length; i++) {
                if (friendsNotes[i].user_email === friend.user_email) {
                    found = i;
                    break;
                }
            }
            if (found >= 0) currentIndex = found;
            else {
                friendsNotes.push(friend);
                currentIndex = friendsNotes.length - 1;
            }
        }
        isOpen = true;
    }

    function close() {
        isOpen = false;
    }

    function nextStory() {
        if (currentIndex < friendsNotes.length - 1) {
            currentIndex++;
        }
    }

    function prevStory() {
        if (currentIndex > 0) {
            currentIndex--;
        }
    }

    function formatTimeAgo(isoStr) {
        if (!isoStr) return I18n.tr("Vừa xong", "Just now");
        try {
            var d = new Date(isoStr);
            var diffSec = Math.floor((Date.now() - d.getTime()) / 1000);
            if (diffSec < 60) return I18n.tr("Vừa xong", "Just now");
            var diffMin = Math.floor(diffSec / 60);
            if (diffMin < 60) return diffMin + I18n.tr(" phút trước", "m ago");
            var diffHours = Math.floor(diffMin / 60);
            if (diffHours < 24) return diffHours + I18n.tr(" giờ trước", "h ago");
            return Math.floor(diffHours / 24) + I18n.tr(" ngày trước", "d ago");
        } catch(e) {
            return I18n.tr("Hôm nay", "Today");
        }
    }

    // Dismiss Backdrop
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.02, 0.02, 0.04, 0.72)

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    // Story Dialog Container (Row with Nav Arrows and Story Card)
    RowLayout {
        anchors.centerIn: parent
        spacing: 16

        // Left Navigation Arrow
        NavArrowButton {
            direction: "left"
            accentColor: root.accentColor
            btnSize: 38
            iconSize: 15
            canScroll: root.currentIndex > 0
            onClicked: root.prevStory()
        }

        // Center Story Card (Messenger/Instagram Stories Style - Concentric R=22)
        Rectangle {
            id: storyCard
            Layout.preferredWidth: 440
            Layout.preferredHeight: 520
            radius: 22
            color: Qt.rgba(0.05 + root.accentColor.r * 0.08, 0.05 + root.accentColor.g * 0.08, 0.07 + root.accentColor.b * 0.12, 0.96)
            border.color: Qt.rgba(255, 255, 255, 0.16)
            border.width: 1
            clip: true

            // Absorbs click inside story card so clicking doesn't close backdrop
            MouseArea {
                anchors.fill: parent
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 16

                // 1. Header: Friend Profile & Close Button
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // Mini Avatar
                    Rectangle {
                        width: 38; height: 38; radius: 19
                        color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.22)
                        border.color: root.accentColor
                        border.width: 1.5
                        clip: true

                        Image {
                            id: miniAvatarImg
                            anchors.fill: parent
                            source: root.currentFriend ? (root.currentFriend.avatar_url || "") : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready && source != ""
                        }

                        Text {
                            anchors.centerIn: parent
                            text: root.currentFriend && root.currentFriend.user_name ? root.currentFriend.user_name.charAt(0).toUpperCase() : "F"
                            color: "#ffffff"
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            font.bold: true
                            visible: !miniAvatarImg.visible
                        }
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: root.currentFriend ? (root.currentFriend.user_name || "Friend") : ""
                            color: "#ffffff"
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.bold: true
                            elide: Text.ElideRight
                            width: 280
                        }
                        Text {
                            text: root.currentFriend ? root.formatTimeAgo(root.currentFriend.created_at) : ""
                            color: Qt.rgba(1, 1, 1, 0.5)
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }
                    }

                    // Close Button with AppIcon
                    Rectangle {
                        width: 32; height: 32; radius: 16
                        color: closeArea.containsMouse ? Qt.rgba(244, 63, 94, 0.25) : Qt.rgba(1, 1, 1, 0.08)
                        border.color: closeArea.containsMouse ? Qt.rgba(244, 63, 94, 0.45) : Qt.rgba(1, 1, 1, 0.12)
                        border.width: 1

                        AppIcon {
                            anchors.centerIn: parent
                            source: "../assets/icons/window-close-symbolic.svg"
                            iconSize: 12
                            color: closeArea.containsMouse ? "#fda4af" : Qt.rgba(1, 1, 1, 0.8)
                        }

                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.close()
                        }
                    }
                }

                Item { Layout.fillHeight: true; Layout.preferredHeight: 6 }

                // 2. Center Stage: Large Avatar + Live Pulse Ring + Thought Bubble
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 210

                    // Pulse Ring (Breathing animation when friend has music)
                    Rectangle {
                        id: pulseRing
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 70
                        width: 116; height: 116; radius: 58
                        color: "transparent"
                        border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.35)
                        border.width: 1.5

                        SequentialAnimation on scale {
                            loops: Animation.Infinite
                            running: root.isOpen && root.currentFriend && root.currentFriend.track
                            NumberAnimation { to: 1.08; duration: 1600; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 1600; easing.type: Easing.InOutSine }
                        }
                    }

                    // Main Big Avatar (104x104)
                    Rectangle {
                        id: bigAvatar
                        anchors.centerIn: pulseRing
                        width: 104; height: 104; radius: 52
                        color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.28)
                        border.color: root.accentColor
                        border.width: 2.5
                        clip: true

                        Image {
                            id: bigAvatarImg
                            anchors.fill: parent
                            source: root.currentFriend ? (root.currentFriend.avatar_url || "") : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready && source != ""
                        }

                        Text {
                            anchors.centerIn: parent
                            text: root.currentFriend && root.currentFriend.user_name ? root.currentFriend.user_name.charAt(0).toUpperCase() : "F"
                            color: "#ffffff"
                            font.family: Theme.fontFamily
                            font.pixelSize: 42
                            font.bold: true
                            visible: !bigAvatarImg.visible
                        }
                    }

                    // Thought Bubble (Bong bóng suy nghĩ nổi trên đầu avatar)
                    Rectangle {
                        id: thoughtBubble
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 4
                        width: Math.min(360, Math.max(160, noteText.implicitWidth + 36))
                        height: Math.max(44, noteText.implicitHeight + 20)
                        radius: 16
                        color: Qt.rgba(0.08 + root.accentColor.r * 0.12, 0.08 + root.accentColor.g * 0.12, 0.11 + root.accentColor.b * 0.16, 0.98)
                        border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.42)
                        border.width: 1.5

                        // Subtle bubble connector dots
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: thoughtBubble.bottom
                            anchors.topMargin: 2
                            width: 10; height: 10; radius: 5
                            color: thoughtBubble.color
                            border.color: thoughtBubble.border.color
                            border.width: 1
                        }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: thoughtBubble.bottom
                            anchors.topMargin: 14
                            width: 6; height: 6; radius: 3
                            color: thoughtBubble.color
                            border.color: thoughtBubble.border.color
                            border.width: 1
                        }

                        Text {
                            id: noteText
                            anchors.centerIn: parent
                            anchors.margins: 12
                            width: parent.width - 24
                            text: root.currentFriend ? (root.currentFriend.note_text || "") : ""
                            color: "#ffffff"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }
                }

                Item { Layout.fillHeight: true; Layout.preferredHeight: 6 }

                // 3. Attached Song Card (To bản, rõ nét, concentric R=12)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 66
                    radius: 12
                    color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.12)
                    border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.28)
                    border.width: 1
                    visible: root.currentFriend && root.currentFriend.track !== null && root.currentFriend.track !== undefined

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 12

                        // Track Cover Artwork (50x50, R=8 with GPU MultiEffect Mask)
                        Item {
                            width: 50; height: 50

                            Rectangle {
                                id: storySongMask
                                anchors.fill: parent
                                radius: 8
                                color: "#ffffff"
                                visible: false
                                layer.enabled: true
                            }

                            Item {
                                anchors.fill: parent
                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    maskEnabled: true
                                    maskSource: storySongMask
                                    autoPaddingEnabled: false
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 8
                                    color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.24)
                                    border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.36)
                                    border.width: 1
                                }

                                Image {
                                    id: songCoverImg
                                    anchors.fill: parent
                                    source: (root.currentFriend && root.currentFriend.track) ? (root.currentFriend.track.cover || root.currentFriend.track.image || "") : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    visible: status === Image.Ready && source != ""
                                }

                                AppIcon {
                                    anchors.centerIn: parent
                                    source: "../assets/icons/folder-music-symbolic.svg"
                                    iconSize: 20
                                    color: root.accentColor
                                    visible: !songCoverImg.visible
                                }
                            }
                        }

                        // Song Details
                        Column {
                            Layout.fillWidth: true
                            spacing: 3
                            Text {
                                text: root.currentFriend && root.currentFriend.track ? (root.currentFriend.track.title || root.currentFriend.track.name || "") : ""
                                color: "#ffffff"
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.bold: true
                                elide: Text.ElideRight
                                width: 230
                            }
                            Text {
                                text: root.currentFriend && root.currentFriend.track ? (root.currentFriend.track.artist || I18n.tr("Đang phát", "Playing")) : ""
                                color: Qt.rgba(1, 1, 1, 0.6)
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                width: 230
                            }
                        }

                        // Badge "24h Note"
                        Rectangle {
                            Layout.preferredWidth: 64
                            Layout.preferredHeight: 22
                            radius: 11
                            color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.2)
                            border.color: root.accentColor
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: I18n.tr("24h Note", "24h Note")
                                color: root.accentColor
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.bold: true
                            }
                        }
                    }
                }

                // Empty track fallback message if no track attached
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 46
                    radius: 12
                    color: Qt.rgba(1, 1, 1, 0.04)
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1
                    visible: !root.currentFriend || !root.currentFriend.track

                    Text {
                        anchors.centerIn: parent
                        text: I18n.tr("Bạn này không đính kèm bài hát vào note", "No track attached to this note")
                        color: Qt.rgba(1, 1, 1, 0.45)
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                }

                // 4. Primary CTA: [ ▶ Nghe cùng bạn ] (Listen Along Button)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    radius: 12
                    visible: root.currentFriend && root.currentFriend.track !== null && root.currentFriend.track !== undefined
                    color: listenBtnArea.containsMouse
                        ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.45)
                        : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.28)
                    border.color: root.accentColor
                    border.width: 1.2
                    scale: listenBtnArea.containsMouse ? 1.02 : 1.0
                    Behavior on scale { NumberAnimation { duration: 120 } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 8

                        AppIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            source: "../assets/icons/media-playback-start-symbolic.svg"
                            iconSize: 13
                            color: "#ffffff"
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.tr("Nghe cùng bạn", "Listen along with friend")
                            color: "#ffffff"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.bold: true
                        }
                    }

                    MouseArea {
                        id: listenBtnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var f = root.currentFriend;
                            root.close();
                            if (f && f.track) {
                                root.listenAlongRequested(f);
                            }
                        }
                    }
                }
            }
        }

        // Right Navigation Arrow
        NavArrowButton {
            direction: "right"
            accentColor: root.accentColor
            btnSize: 38
            iconSize: 15
            canScroll: root.currentIndex < (root.friendsNotes ? root.friendsNotes.length - 1 : 0)
            onClicked: root.nextStory()
        }
    }
}
