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

    property var currentTrack: null
    property color accentColor: Theme.accent
    property string statusMessage: ""
    property bool isSubmitting: false

    signal closeRequested()
    signal noteSubmitted(string text, var track)

    function openModal() {
        root.visible = true;
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (!root.isSubmitting) root.closeRequested();
        }
    }

    // Centered Modal Dialog Card
    Rectangle {
        id: dialogCard
        width: 480
        height: 350
        anchors.centerIn: parent
        radius: 18
        color: Qt.rgba(0.06, 0.06, 0.09, 0.96)
        border.color: Qt.rgba(1, 1, 1, 0.12)
        border.width: 1

        // Prevent clicking background through modal
        MouseArea {
            anchors.fill: parent
            onClicked: (mouse) => mouse.accepted = true
        }

        // Ambient glow around dialog
        MultiEffect {
            anchors.fill: dialogCard
            source: dialogCard
            shadowEnabled: true
            shadowColor: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.35)
            shadowBlur: 0.8
            shadowVerticalOffset: 6
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            // Header Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Column {
                    spacing: 4
                    Text {
                        text: I18n.tr("Chia Sẻ Khoảnh Khắc 24 Giờ", "Share 24h Music Capsule")
                        color: "#ffffff"
                        font.family: Theme.fontFamily
                        font.pixelSize: 17
                        font.bold: true
                    }
                    Text {
                        text: I18n.tr("Ghi chú sẽ xuất hiện trên app của bạn bè trong 24h", "Your note will appear on friends' screens for 24 hours")
                        color: Qt.rgba(1, 1, 1, 0.5)
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                }

                Item { Layout.fillWidth: true }

                // Close Button (Hairline glass)
                Rectangle {
                    width: 32; height: 32; radius: 16
                    color: closeArea.containsMouse ? Qt.rgba(244, 63, 94, 0.2) : Qt.rgba(1, 1, 1, 0.06)
                    border.color: closeArea.containsMouse ? Qt.rgba(244, 63, 94, 0.4) : Qt.rgba(1, 1, 1, 0.1)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: closeArea.containsMouse ? "#fda4af" : Qt.rgba(1, 1, 1, 0.6)
                        font.pixelSize: 12
                        font.bold: true
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeRequested()
                    }
                }
            }

            // Text Input Box (Max 60 chars)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 88
                radius: 12
                color: Qt.rgba(0, 0, 0, 0.45)
                border.color: noteInput.activeFocus ? root.accentColor : Qt.rgba(1, 1, 1, 0.12)
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentWidth: width
                        contentHeight: noteInput.implicitHeight
                        clip: true

                        TextEdit {
                            id: noteInput
                            width: parent.width
                            color: "#ffffff"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            wrapMode: TextEdit.Wrap
                            selectByMouse: true

                            Text {
                                text: I18n.tr("Hôm nay bạn cảm thấy thế nào? (Tối đa 60 ký tự)", "How are you feeling today? (Max 60 chars)")
                                color: Qt.rgba(1, 1, 1, 0.35)
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                visible: !noteInput.text && !noteInput.activeFocus
                            }

                            onTextChanged: {
                                if (text.length > 60) {
                                    text = text.substring(0, 60);
                                    cursorPosition = 60;
                                }
                            }
                        }
                    }

                    // Character counter
                    RowLayout {
                        Layout.fillWidth: true
                        Item { Layout.fillWidth: true }
                        Text {
                            text: noteInput.text.length + " / 60"
                            color: noteInput.text.length >= 50 ? "#f43f5e" : Qt.rgba(1, 1, 1, 0.4)
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.bold: noteInput.text.length >= 50
                        }
                    }
                }
            }

            // Attached Track Preview Card (Concentric radius R_con = 12 - 4 = 8)
            Rectangle {
                Layout.fillWidth: true
                height: 52
                radius: 10
                color: Qt.rgba(1, 1, 1, 0.04)
                border.color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 12

                    // Album Cover or vinyl icon
                    Rectangle {
                        width: 36; height: 36; radius: 6
                        color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.15)
                        border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.3)
                        border.width: 1
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: (root.currentTrack && root.currentTrack.cover) ? root.currentTrack.cover : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "♫"
                            color: root.accentColor
                            font.pixelSize: 16
                            visible: !root.currentTrack || !root.currentTrack.cover
                        }
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: root.currentTrack ? (root.currentTrack.title || root.currentTrack.name || I18n.tr("Không rõ bài hát", "Unknown Song")) : I18n.tr("Không có bài hát nào đang phát", "No track currently playing")
                            color: "#ffffff"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.bold: true
                            elide: Text.ElideRight
                            width: 300
                        }
                        Text {
                            text: root.currentTrack ? (root.currentTrack.artist || I18n.tr("Đang phát trong Nutsty", "Playing in Nutsty")) : I18n.tr("Bật nhạc để đính kèm vào note", "Play a song to attach to note")
                            color: Qt.rgba(1, 1, 1, 0.5)
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            elide: Text.ElideRight
                            width: 300
                        }
                    }

                    Rectangle {
                        width: 76; height: 22; radius: 11
                        color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.18)
                        border.color: root.accentColor
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: I18n.tr("Đính Kèm", "Attached")
                            color: "#ffffff"
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.bold: true
                        }
                    }
                }
            }

            // Action Buttons Row (Optical padding px = 2 * py)
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Item { Layout.fillWidth: true }

                // Cancel Button
                Rectangle {
                    width: 96; height: 38; radius: 10
                    color: cancelArea.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05)
                    border.color: Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: I18n.tr("Hủy", "Cancel")
                        color: "#ffffff"
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: cancelArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeRequested()
                    }
                }

                // Submit Button (Dynamic Accent)
                Rectangle {
                    width: 160; height: 38; radius: 10
                    color: submitArea.containsMouse ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.35) : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.22)
                    border.color: root.accentColor
                    border.width: 1
                    scale: submitArea.containsMouse ? 1.03 : 1.0
                    Behavior on scale { NumberAnimation { duration: 150 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: I18n.tr("Đăng Trong 24 Giờ", "Post for 24h")
                            color: "#ffffff"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }

                    MouseArea {
                        id: submitArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var t = noteInput.text.trim();
                            if (!t) return;
                            root.noteSubmitted(t, root.currentTrack);
                        }
                    }
                }
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            noteInput.text = "";
            noteInput.forceActiveFocus();
        }
    }
}
