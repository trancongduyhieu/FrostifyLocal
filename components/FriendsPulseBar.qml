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
    signal addFriendClicked()
    signal openStoryRequested(var friendData, int index)
    signal playTrackRequested(var track)

    function openFriendNote(idx) {
        if (root.friendsNotes && idx >= 0 && idx < root.friendsNotes.length) {
            root.openStoryRequested(root.friendsNotes[idx], idx);
        }
    }

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

                    AppIcon {
                        anchors.centerIn: parent
                        source: "../assets/icons/list-add-symbolic.svg"
                        iconSize: 18
                        color: "#ffffff"
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

        // 2. HORIZONTAL LIST OF FRIENDS NOTES (Clean Avatar + Mini Thought Bubble)
        ListView {
            id: friendsListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: ListView.Horizontal
            spacing: 16
            clip: false
            boundsBehavior: Flickable.StopAtBounds

            model: root.friendsNotes

            delegate: Item {
                width: Math.max(90, Math.min(140, bubbleBox.width + 12))
                height: friendsListView.height

                // Mini Thought Bubble (Floating above avatar, no heavy pill clutter)
                Rectangle {
                    id: bubbleBox
                    anchors.top: parent.top
                    anchors.topMargin: 4
                    anchors.horizontalCenter: avatarWrapper.horizontalCenter
                    width: Math.max(76, Math.min(130, noteTextItem.implicitWidth + 22))
                    height: 24
                    radius: 12
                    color: friendArea.containsMouse
                        ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.28)
                        : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.16)
                    border.color: friendArea.containsMouse ? root.accentColor : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.36)
                    border.width: 1
                    scale: friendArea.containsMouse ? 1.05 : 1.0
                    Behavior on scale { NumberAnimation { duration: 150 } }

                    // Tiny bubble connector dots
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: bubbleBox.bottom
                        anchors.topMargin: -1
                        width: 5; height: 5; radius: 2.5
                        color: bubbleBox.color
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        spacing: 4

                        AppIcon {
                            Layout.alignment: Qt.AlignVCenter
                            source: "../assets/icons/folder-music-symbolic.svg"
                            iconSize: 10
                            color: root.accentColor
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

                // AVATAR WRAPPER (48px circle with breathing pulse ring if sharing track)
                Item {
                    id: avatarWrapper
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 14
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 48; height: 48
                    scale: friendArea.containsMouse ? 1.08 : 1.0
                    Behavior on scale { NumberAnimation { duration: 150 } }

                    // Outer Pulse Ring when music is attached
                    Rectangle {
                        anchors.fill: parent
                        radius: 24
                        color: "transparent"
                        border.color: friendArea.containsMouse ? root.accentColor : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.45)
                        border.width: 1.5
                    }

                    // Avatar Inner Circle Image
                    Item {
                        anchors.fill: parent
                        anchors.margins: 2

                        Rectangle {
                            id: avatarBg
                            anchors.fill: parent
                            radius: 22
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
                    onClicked: {
                        root.openStoryRequested(modelData, index);
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
                visible: !root.friendsNotes || root.friendsNotes.length === 0
            }
        }

        // 3. ADD FRIEND BUTTON
        Rectangle {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            Layout.alignment: Qt.AlignVCenter
            radius: 18
            color: addFriendArea.containsMouse ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.22) : Qt.rgba(1, 1, 1, 0.04)
            border.color: addFriendArea.containsMouse ? root.accentColor : Qt.rgba(1, 1, 1, 0.12)
            border.width: 1

            AppIcon {
                anchors.centerIn: parent
                source: "../assets/icons/list-add-symbolic.svg"
                iconSize: 14
                color: addFriendArea.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.75)
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
}
