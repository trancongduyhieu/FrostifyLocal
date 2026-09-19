import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtQuick.Effects
import "."

Item {
    id: root
    width: parent ? parent.width : 800
    height: 96

    property var friendsNotes: []
    property color accentColor: Theme.accent
    property var myLatestNote: null
    property string userAvatar: ""
    property string userName: ""

    signal postNoteClicked()
    signal addFriendClicked()
    signal openStoryRequested(var friendData, int index)
    signal playTrackRequested(var track)

    function openFriendNote(idx) {
        if (root.friendsNotes && idx >= 0 && idx < root.friendsNotes.length) {
            root.openStoryRequested(root.friendsNotes[idx], idx);
        }
    }

    // Scroll Left Arrow Button
    NavArrowButton {
        id: leftNavBtn
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        z: 10
        direction: "left"
        accentColor: root.accentColor
        visible: friendsFlickable.contentWidth > friendsFlickable.width && friendsFlickable.contentX > 8
        canScroll: friendsFlickable.contentX > 0
        onClicked: {
            var targetX = Math.max(0, friendsFlickable.contentX - 220);
            scrollAnim.to = targetX;
            scrollAnim.restart();
        }
    }

    // Scroll Right Arrow Button
    NavArrowButton {
        id: rightNavBtn
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        z: 10
        direction: "right"
        accentColor: root.accentColor
        visible: friendsFlickable.contentWidth > friendsFlickable.width && friendsFlickable.contentX < (friendsFlickable.contentWidth - friendsFlickable.width - 8)
        canScroll: friendsFlickable.contentX < (friendsFlickable.contentWidth - friendsFlickable.width)
        onClicked: {
            var maxScroll = Math.max(0, friendsFlickable.contentWidth - friendsFlickable.width);
            var targetX = Math.min(maxScroll, friendsFlickable.contentX + 220);
            scrollAnim.to = targetX;
            scrollAnim.restart();
        }
    }

    NumberAnimation {
        id: scrollAnim
        target: friendsFlickable
        property: "contentX"
        duration: 220
        easing.type: Easing.OutCubic
    }

    // Horizontal Scrollable Container
    Flickable {
        id: friendsFlickable
        anchors.fill: parent
        anchors.leftMargin: leftNavBtn.visible ? 36 : 0
        anchors.rightMargin: rightNavBtn.visible ? 36 : 0
        contentWidth: itemsRow.width + 16
        contentHeight: height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick

        Behavior on anchors.leftMargin { NumberAnimation { duration: 150 } }
        Behavior on anchors.rightMargin { NumberAnimation { duration: 150 } }

        // Desktop Linux Mouse Wheel Handler (Captures Vertical Wheel Delta Y to Scroll Horizontally)
        WheelHandler {
            target: friendsFlickable
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                var delta = (event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x);
                var maxScroll = Math.max(0, friendsFlickable.contentWidth - friendsFlickable.width);
                friendsFlickable.contentX = Math.max(0, Math.min(maxScroll, friendsFlickable.contentX - delta * 1.2));
            }
        }

        // Touchpad / Mouse Drag Handler
        DragHandler {
            target: null
            grabPermissions: PointerHandler.CanTakeOverFromItems | PointerHandler.CanTakeOverFromHandlersOfDifferentType
            property real startContentX: 0
            onActiveChanged: {
                if (active) startContentX = friendsFlickable.contentX;
            }
            onTranslationChanged: {
                if (active) {
                    var maxScroll = Math.max(0, friendsFlickable.contentWidth - friendsFlickable.width);
                    friendsFlickable.contentX = Math.max(0, Math.min(maxScroll, startContentX - translation.x));
                }
            }
        }

        Row {
            id: itemsRow
            height: parent.height
            spacing: 12

            // ==========================================
            // ITEM 0: CURRENT USER NOTE / POST NOTE (Messenger Pattern - Ảnh 2)
            // ==========================================
            Item {
                id: userNoteItem
                width: 72
                height: friendsFlickable.height

                // Mini Thought Bubble above user avatar (Compact 64-76px)
                Rectangle {
                    id: userBubbleBox
                    anchors.top: parent.top
                    anchors.topMargin: 4
                    anchors.horizontalCenter: userAvatarWrapper.horizontalCenter
                    width: Math.max(64, Math.min(76, userBubbleText.implicitWidth + 18))
                    height: 24
                    radius: 12
                    color: userMouseArea.containsMouse
                        ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.28)
                        : (root.myLatestNote ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.18) : Qt.rgba(1, 1, 1, 0.05))
                    border.color: userMouseArea.containsMouse
                        ? root.accentColor
                        : (root.myLatestNote ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.40) : Qt.rgba(1, 1, 1, 0.16))
                    border.width: 1
                    scale: userMouseArea.containsMouse ? 1.05 : 1.0
                    Behavior on scale { NumberAnimation { duration: 150 } }

                    // Bubble connector dot
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: userBubbleBox.bottom
                        anchors.topMargin: -1
                        width: 5; height: 5; radius: 2.5
                        color: userBubbleBox.color
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        spacing: 3

                        AppIcon {
                            Layout.alignment: Qt.AlignVCenter
                            source: "../assets/icons/folder-music-symbolic.svg"
                            iconSize: 9
                            color: root.accentColor
                            visible: root.myLatestNote && root.myLatestNote.track !== null && root.myLatestNote.track !== undefined
                        }

                        Text {
                            id: userBubbleText
                            Layout.fillWidth: true
                            text: root.myLatestNote ? (root.myLatestNote.note_text || "") : I18n.tr("Chia sẻ...", "Share...")
                            color: root.myLatestNote ? "#ffffff" : Qt.rgba(1, 1, 1, 0.65)
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.bold: root.myLatestNote !== null
                            elide: Text.ElideRight
                        }
                    }
                }

                // User Circular Avatar Wrapper (48x48)
                Item {
                    id: userAvatarWrapper
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 18
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 48; height: 48
                    scale: userMouseArea.containsMouse ? 1.08 : 1.0
                    Behavior on scale { NumberAnimation { duration: 150 } }

                    // Outer Border / Pulse Ring if track is attached
                    Rectangle {
                        anchors.fill: parent
                        radius: 24
                        color: "transparent"
                        border.color: userMouseArea.containsMouse
                            ? root.accentColor
                            : (root.myLatestNote ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.55) : Qt.rgba(1, 1, 1, 0.16))
                        border.width: 1.5
                    }

                    // Circle Mask for User Avatar (Hardware GPU layer effect mask)
                    Rectangle {
                        id: userAvatarMask
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: 22
                        color: "#ffffff"
                        visible: false
                        layer.enabled: true
                    }

                    // Masked Container: Zero Pixel Leakage Outside Circle
                    Item {
                        anchors.fill: parent
                        anchors.margins: 2
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: userAvatarMask
                            autoPaddingEnabled: false
                        }

                        // Background fallback
                        Rectangle {
                            anchors.fill: parent
                            color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.22)

                            Text {
                                anchors.centerIn: parent
                                text: (root.userName && root.userName.length > 0) ? root.userName.substring(0, 1).toUpperCase() : "U"
                                color: "#ffffff"
                                font.family: Theme.fontFamily
                                font.pixelSize: 16
                                font.bold: true
                            }
                        }

                        // Profile Image
                        Image {
                            id: userAvatarImg
                            anchors.fill: parent
                            source: root.userAvatar || ""
                            fillMode: Image.PreserveAspectCrop
                            visible: root.userAvatar !== ""
                            asynchronous: true
                            cache: true
                        }
                    }

                    // Plus / Edit Action Badge at bottom-right of avatar
                    Rectangle {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        width: 16; height: 16; radius: 8
                        color: root.accentColor
                        border.color: "#08090d"
                        border.width: 1.5

                        AppIcon {
                            anchors.centerIn: parent
                            source: root.myLatestNote ? "../assets/icons/document-edit-symbolic.svg" : "../assets/icons/list-add-symbolic.svg"
                            iconSize: 9
                            color: "#ffffff"
                        }
                    }
                }

                // Label below user avatar
                Text {
                    anchors.top: userAvatarWrapper.bottom
                    anchors.topMargin: 2
                    anchors.horizontalCenter: userAvatarWrapper.horizontalCenter
                    text: root.myLatestNote ? I18n.tr("Note của bạn", "Your Note") : I18n.tr("Ghi chú của bạn", "Your note")
                    color: userMouseArea.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.70)
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.bold: true
                    elide: Text.ElideRight
                    width: 70
                    horizontalAlignment: Text.AlignHCenter
                }

                MouseArea {
                    id: userMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.postNoteClicked()
                }
            }

            // ==========================================
            // ITEMS 1..N: FRIENDS NOTES (Compact 72px width)
            // ==========================================
            Repeater {
                model: root.friendsNotes

                delegate: Item {
                    width: 72
                    height: friendsFlickable.height

                    // Mini Thought Bubble above friend avatar (Compact 64-76px)
                    Rectangle {
                        id: friendBubbleBox
                        anchors.top: parent.top
                        anchors.topMargin: 4
                        anchors.horizontalCenter: friendAvatarWrapper.horizontalCenter
                        width: Math.max(64, Math.min(76, friendNoteText.implicitWidth + 18))
                        height: 24
                        radius: 12
                        color: friendArea.containsMouse
                            ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.28)
                            : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.16)
                        border.color: friendArea.containsMouse
                            ? root.accentColor
                            : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.36)
                        border.width: 1
                        scale: friendArea.containsMouse ? 1.05 : 1.0
                        Behavior on scale { NumberAnimation { duration: 150 } }

                        // Bubble connector dot
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: friendBubbleBox.bottom
                            anchors.topMargin: -1
                            width: 5; height: 5; radius: 2.5
                            color: friendBubbleBox.color
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            spacing: 3

                            AppIcon {
                                Layout.alignment: Qt.AlignVCenter
                                source: "../assets/icons/folder-music-symbolic.svg"
                                iconSize: 9
                                color: root.accentColor
                                visible: modelData.track !== null && modelData.track !== undefined
                            }

                            Text {
                                id: friendNoteText
                                Layout.fillWidth: true
                                text: modelData.note_text || ""
                                color: "#ffffff"
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.bold: true
                                elide: Text.ElideRight
                            }
                        }
                    }

                    // Friend Circular Avatar Wrapper (48x48)
                    Item {
                        id: friendAvatarWrapper
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 18
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 48; height: 48
                        scale: friendArea.containsMouse ? 1.08 : 1.0
                        Behavior on scale { NumberAnimation { duration: 150 } }

                        // Outer Pulse Ring when music is attached
                        Rectangle {
                            anchors.fill: parent
                            radius: 24
                            color: "transparent"
                            border.color: friendArea.containsMouse
                                ? root.accentColor
                                : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.45)
                            border.width: 1.5
                        }

                        // Friend Circle Mask (Hardware GPU layer effect mask)
                        Rectangle {
                            id: friendAvatarMask
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: 22
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
                                maskSource: friendAvatarMask
                                autoPaddingEnabled: false
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.25)

                                Text {
                                    anchors.centerIn: parent
                                    text: (modelData.user_name && modelData.user_name.length > 0) ? modelData.user_name.substring(0, 1).toUpperCase() : "F"
                                    color: "#ffffff"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 16
                                    font.bold: true
                                }
                            }

                            Image {
                                id: friendAvatarImg
                                anchors.fill: parent
                                source: modelData.avatar_url || ""
                                fillMode: Image.PreserveAspectCrop
                                visible: (modelData.avatar_url || "") !== ""
                                asynchronous: true
                                cache: true
                            }
                        }

                        // Green Online Indicator Dot
                        Rectangle {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            width: 12; height: 12; radius: 6
                            color: "#10b981"
                            border.color: "#08090d"
                            border.width: 2
                        }
                    }

                    // Friend Name below avatar
                    Text {
                        anchors.top: friendAvatarWrapper.bottom
                        anchors.topMargin: 2
                        anchors.horizontalCenter: friendAvatarWrapper.horizontalCenter
                        text: modelData.user_name || "Friend"
                        color: friendArea.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.6)
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        elide: Text.ElideRight
                        width: 70
                        horizontalAlignment: Text.AlignHCenter
                    }

                    MouseArea {
                        id: friendArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openStoryRequested(modelData, index)
                    }
                }
            }

            // ==========================================
            // TAIL ITEM: ADD FRIEND ACTION (Compact 72px width)
            // ==========================================
            Item {
                id: addFriendItem
                width: 72
                height: friendsFlickable.height

                // Placeholder space matching thought bubble height to preserve exact avatar baseline
                Item {
                    anchors.top: parent.top
                    anchors.topMargin: 4
                    width: parent.width
                    height: 24
                }

                // Circular Add Friend Avatar Container (48x48)
                Rectangle {
                    id: addFriendCircle
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 18
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 48; height: 48; radius: 24
                    color: addFriendMouse.containsMouse
                        ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.22)
                        : Qt.rgba(1, 1, 1, 0.04)
                    border.color: addFriendMouse.containsMouse
                        ? root.accentColor
                        : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.35)
                    border.width: 1.5
                    scale: addFriendMouse.containsMouse ? 1.08 : 1.0
                    Behavior on scale { NumberAnimation { duration: 150 } }

                    AppIcon {
                        anchors.centerIn: parent
                        source: "../assets/icons/list-add-symbolic.svg"
                        iconSize: 16
                        color: addFriendMouse.containsMouse ? "#ffffff" : root.accentColor
                    }
                }

                // Label below Add Friend avatar
                Text {
                    anchors.top: addFriendCircle.bottom
                    anchors.topMargin: 2
                    anchors.horizontalCenter: addFriendCircle.horizontalCenter
                    text: I18n.tr("Thêm bạn", "Add friend")
                    color: addFriendMouse.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.60)
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.bold: true
                    elide: Text.ElideRight
                    width: 70
                    horizontalAlignment: Text.AlignHCenter
                }

                MouseArea {
                    id: addFriendMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.addFriendClicked()
                }
            }
        }
    }
}
