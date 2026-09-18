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

    signal postNoteClicked()
    signal playTrackRequested(var track)
    signal addFriendClicked()

    property var activePopoverNote: null

    RowLayout {
        anchors.fill: parent
        spacing: 16

        // 1. MY NOTE / POST NOTE ACTION CARD
        Rectangle {
            Layout.preferredWidth: 80
            Layout.fillHeight: true
            radius: 14
            color: postCardArea.containsMouse ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.16) : Qt.rgba(1, 1, 1, 0.03)
            border.color: postCardArea.containsMouse ? root.accentColor : Qt.rgba(1, 1, 1, 0.08)
            border.width: 1

            Column {
                anchors.centerIn: parent
                spacing: 6

                // Add Circle Icon
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 44; height: 44; radius: 22
                    color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.18)
                    border.color: root.accentColor
                    border.width: 1.5
                    scale: postCardArea.containsMouse ? 1.08 : 1.0
                    Behavior on scale { NumberAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "＋"
                        color: "#ffffff"
                        font.pixelSize: 20
                        font.bold: true
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.myLatestNote ? I18n.tr("Note của bạn", "Your Note") : I18n.tr("Đăng Note", "Share Note")
                    color: postCardArea.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.7)
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.bold: true
                }
            }

            MouseArea {
                id: postCardArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.postNoteClicked()
            }
        }

        // Hairline Vertical Divider
        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 64
            Layout.alignment: Qt.AlignVCenter
            color: Qt.rgba(1, 1, 1, 0.08)
        }

        // 2. HORIZONTAL LIST OF FRIENDS NOTES
        ListView {
            id: friendsListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: ListView.Horizontal
            spacing: 18
            clip: false
            boundsBehavior: Flickable.StopAtBounds

            model: root.friendsNotes

            delegate: Item {
                width: Math.max(100, Math.min(180, bubbleBox.width + 8))
                height: friendsListView.height

                // SPEECH BUBBLE (24H NOTE)
                Rectangle {
                    id: bubbleBox
                    anchors.top: parent.top
                    anchors.topMargin: 2
                    anchors.horizontalCenter: avatarWrapper.horizontalCenter
                    width: Math.max(80, Math.min(170, noteTextItem.implicitWidth + 24))
                    height: 26
                    radius: 13
                    color: friendArea.containsMouse ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.28) : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.16)
                    border.color: friendArea.containsMouse ? root.accentColor : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.38)
                    border.width: 1

                    // Bubble tail pointing down
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.bottom
                        anchors.topMargin: -3
                        width: 6; height: 6
                        rotation: 45
                        color: bubbleBox.color
                        border.color: bubbleBox.border.color
                        border.width: 1
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 4

                        Text {
                            text: "♫"
                            color: root.accentColor
                            font.pixelSize: 10
                            visible: modelData.track !== null && modelData.track !== undefined
                        }

                        Text {
                            id: noteTextItem
                            Layout.fillWidth: true
                            text: modelData.note_text || ""
                            color: "#ffffff"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                            elide: Text.ElideRight
                        }
                    }
                }

                // AVATAR WRAPPER (48px circle with MultiEffect Masking)
                Item {
                    id: avatarWrapper
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 48; height: 48

                    // Outer Halo Ring
                    Rectangle {
                        anchors.fill: parent
                        radius: 24
                        color: "transparent"
                        border.color: friendArea.containsMouse ? root.accentColor : Qt.rgba(1, 1, 1, 0.16)
                        border.width: 1.5
                        scale: friendArea.containsMouse ? 1.06 : 1.0
                        Behavior on scale { NumberAnimation { duration: 150 } }
                    }

                    // Avatar Inner Circle Image
                    Item {
                        anchors.fill: parent
                        anchors.margins: 2

                        Rectangle {
                            id: avatarBg
                            anchors.fill: parent
                            radius: 22
                            color: Qt.rgba(1, 1, 1, 0.08)

                            Text {
                                anchors.centerIn: parent
                                text: (modelData.user_name && modelData.user_name.length > 0) ? modelData.user_name.substring(0, 1).toUpperCase() : "U"
                                color: "#ffffff"
                                font.family: Theme.fontFamily
                                font.pixelSize: 16
                                font.bold: true
                            }
                        }

                        Image {
                            id: avatarImg
                            anchors.fill: parent
                            source: modelData.avatar_url || ""
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready && source != ""
                        }

                        // Mask avatar to round circle (chống vỡ viền đen theo rule #01)
                        MultiEffect {
                            anchors.fill: avatarImg
                            source: avatarImg
                            maskEnabled: true
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1.0
                            visible: avatarImg.visible
                            maskSource: Rectangle {
                                width: 44; height: 44
                                radius: 22
                                color: "#000000"
                            }
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
                    anchors.top: avatarWrapper.bottom
                    anchors.topMargin: 2
                    anchors.horizontalCenter: avatarWrapper.horizontalCenter
                    text: modelData.user_name || "Friend"
                    color: Qt.rgba(1, 1, 1, 0.55)
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
                    onClicked: {
                        root.activePopoverNote = modelData;
                        var pt = avatarWrapper.mapToItem(root, 0, 0);
                        notePopover.x = Math.max(16, Math.min(root.width - notePopover.width - 16, pt.x - (notePopover.width - avatarWrapper.width) / 2));
                        notePopover.visible = true;
                    }
                }
            }

            // Empty state placeholder
            Text {
                anchors.centerIn: parent
                text: I18n.tr("Chưa có bạn bè nào đăng note hôm nay", "No friends have posted a note today")
                color: Qt.rgba(1, 1, 1, 0.35)
                font.family: Theme.fontFamily
                font.pixelSize: 12
                visible: root.friendsNotes.length === 0
            }
        }

        // 3. ADD FRIEND BUTTON
        Rectangle {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            Layout.alignment: Qt.AlignVCenter
            radius: 18
            color: addFriendArea.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.04)
            border.color: Qt.rgba(1, 1, 1, 0.12)
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "👥"
                font.pixelSize: 14
                visible: false // No emojis rule
            }

            Text {
                anchors.centerIn: parent
                text: "+"
                color: Qt.rgba(1, 1, 1, 0.7)
                font.pixelSize: 16
                font.bold: true
            }

            MouseArea {
                id: addFriendArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.addFriendClicked()
            }
        }
    }

    // INTERACTIVE NOTE POPOVER (LISTEN ALONG)
    Rectangle {
        id: notePopover
        visible: false
        z: 999
        width: 320
        height: cardCol.implicitHeight + 32
        x: 100
        y: root.height + 6
        radius: 16
        color: Qt.rgba(0.08, 0.08, 0.12, 0.96)
        border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.4)
        border.width: 1

        MultiEffect {
            anchors.fill: notePopover
            source: notePopover
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.7)
            shadowBlur: 0.8
            shadowVerticalOffset: 8
        }

        ColumnLayout {
            id: cardCol
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            // Header: Friend Name & Close
            RowLayout {
                Layout.fillWidth: true
                Column {
                    spacing: 2
                    Text {
                        text: root.activePopoverNote ? (root.activePopoverNote.user_name || "Friend") : ""
                        color: "#ffffff"
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.bold: true
                    }
                    Text {
                        text: root.activePopoverNote ? (root.activePopoverNote.user_email || "") : ""
                        color: Qt.rgba(1, 1, 1, 0.45)
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 24; height: 24; radius: 12
                    color: Qt.rgba(1, 1, 1, 0.08)
                    Text { anchors.centerIn: parent; text: "✕"; color: Qt.rgba(1, 1, 1, 0.6); font.pixelSize: 10 }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: notePopover.visible = false
                    }
                }
            }

            // Note Text Quote
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                radius: 8
                color: Qt.rgba(1, 1, 1, 0.04)
                border.color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 1

                Text {
                    anchors.fill: parent
                    anchors.margins: 8
                    text: root.activePopoverNote ? ("“" + root.activePopoverNote.note_text + "”") : ""
                    color: "#ffffff"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.italic: true
                    wrapMode: Text.Wrap
                }
            }

            // Attached Song & Listen Along Button
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8
                    visible: root.activePopoverNote && root.activePopoverNote.track !== null && root.activePopoverNote.track !== undefined

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            width: 32; height: 32; radius: 6
                            color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.2)
                            Text { anchors.centerIn: parent; text: "♫"; color: root.accentColor; font.pixelSize: 14 }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                text: root.activePopoverNote && root.activePopoverNote.track ? (root.activePopoverNote.track.title || "") : ""
                                color: "#ffffff"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.bold: true
                                elide: Text.ElideRight
                                width: 220
                            }
                            Text {
                                text: root.activePopoverNote && root.activePopoverNote.track ? (root.activePopoverNote.track.artist || "") : ""
                                color: Qt.rgba(1, 1, 1, 0.5)
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                elide: Text.ElideRight
                                width: 220
                            }
                        }
                    }

                    // CTA Listen Along Button (Dynamic Accent)
                    Rectangle {
                        Layout.fillWidth: true
                        height: 34
                        radius: 8
                        color: playBtnArea.containsMouse ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.35) : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.22)
                        border.color: root.accentColor
                        border.width: 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Text { text: "▶"; color: "#ffffff"; font.pixelSize: 10 }
                            Text {
                                text: I18n.tr("Nghe bài này cùng bạn", "Listen along with friend")
                                color: "#ffffff"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }

                        MouseArea {
                            id: playBtnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                notePopover.visible = false;
                                if (root.activePopoverNote && root.activePopoverNote.track) {
                                    root.playTrackRequested(root.activePopoverNote.track);
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: I18n.tr("Bạn này không đính kèm bài hát", "No track attached to this note")
                    color: Qt.rgba(1, 1, 1, 0.4)
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    visible: !root.activePopoverNote || !root.activePopoverNote.track
                }
            }
        }
    }
}
