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
    property string resolvedCover: ""
    property color accentColor: Theme.accent
    property string statusMessage: ""
    property bool isSubmitting: false

    signal closeRequested()
    signal noteSubmitted(string text, var track)

    function openModal() {
        root.visible = true;
    }

    function getTrackCover() {
        if (root.resolvedCover && root.resolvedCover.length > 0) return root.resolvedCover;
        if (!root.currentTrack) return "";
        return root.currentTrack.image || root.currentTrack.cover || root.currentTrack.thumbnail || root.currentTrack.art || "";
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (!root.isSubmitting) root.closeRequested();
        }
    }

    // Centered Modal Dialog Card (Planar Modern Canvas R=12)
    Rectangle {
        id: dialogCard
        width: 460
        height: 230
        anchors.centerIn: parent
        radius: 12
        color: Qt.rgba(0.06 + root.accentColor.r * 0.06, 0.06 + root.accentColor.g * 0.06, 0.08 + root.accentColor.b * 0.08, 0.97)
        border.color: Qt.rgba(255, 255, 255, 0.12)
        border.width: 1

        // Prevent clicking background through modal
        MouseArea {
            anchors.fill: parent
            onClicked: (mouse) => mouse.accepted = true
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            // Header Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Column {
                    spacing: 3
                    Text {
                        text: I18n.tr("Chia Sẻ Khoảnh Khắc 24 Giờ", "Share 24h Note")
                        color: "#ffffff"
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
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

                // Close Button (Planar square icon button R=4)
                Rectangle {
                    width: 26; height: 26; radius: 4
                    color: closeArea.containsMouse ? Qt.rgba(244, 63, 94, 0.18) : Qt.rgba(1, 1, 1, 0.05)
                    border.color: closeArea.containsMouse ? Qt.rgba(244, 63, 94, 0.40) : Qt.rgba(1, 1, 1, 0.10)
                    border.width: 1

                    AppIcon {
                        anchors.centerIn: parent
                        source: "../assets/icons/window-close-symbolic.svg"
                        iconSize: 11
                        color: closeArea.containsMouse ? "#fda4af" : Qt.rgba(1, 1, 1, 0.70)
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

            // Text Input Box (Max 60 chars - Planar Rectangular R=4)
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 4
                color: Qt.rgba(0.02, 0.02, 0.04, 0.75)
                border.color: noteInput.activeFocus ? root.accentColor : Qt.rgba(1, 1, 1, 0.09)
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

            // Action Buttons Row (Crisp Rectangular buttons R=4, 0% pill/capsule)
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Item { Layout.fillWidth: true }

                // Cancel Button (Crisp rectangular button R=4)
                Rectangle {
                    width: 80; height: 34; radius: 4
                    color: cancelArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                    border.color: cancelArea.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: I18n.tr("Hủy", "Cancel")
                        color: cancelArea.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.8)
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

                // Submit Button (Crisp rectangular button R=4, NO pill)
                Rectangle {
                    width: 144; height: 34; radius: 4
                    color: submitArea.containsMouse ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.50) : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.32)
                    border.color: root.accentColor
                    border.width: 1
                    scale: submitArea.containsMouse ? 1.02 : 1.0
                    Behavior on scale { NumberAnimation { duration: 120 } }

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
                            root.noteSubmitted(t, null);
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
