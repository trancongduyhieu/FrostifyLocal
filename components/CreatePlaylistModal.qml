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
    z: 10010

    property color accentColor: Theme.accent
    property bool editMode: false
    property string targetPlaylistId: ""
    property var attachedTracks: []

    signal closeRequested()
    signal playlistCreated(string title, string description, string cover, var tracks)
    signal playlistUpdated(string plId, string title, string description, string cover)

    function openCreate(tracks) {
        root.editMode = false;
        root.targetPlaylistId = "";
        root.attachedTracks = (tracks && Array.isArray(tracks)) ? tracks : [];
        titleInput.text = "";
        descInput.text = "";
        coverInput.text = "";
        root.visible = true;
        titleInput.forceActiveFocus();
    }

    function openEdit(pl) {
        if (!pl) return;
        root.editMode = true;
        root.targetPlaylistId = pl.id || pl.playlistId || "";
        root.attachedTracks = pl.tracks || [];
        titleInput.text = pl.title || pl.name || "";
        descInput.text = pl.description || "";
        coverInput.text = pl.customCover || pl.cover || "";
        root.visible = true;
        titleInput.forceActiveFocus();
    }

    function closeModal() {
        titleInput.focus = false;
        descInput.focus = false;
        coverInput.focus = false;
        root.visible = false;
        root.closeRequested();
    }

    function submitForm() {
        var cleanTitle = titleInput.text.trim();
        if (!cleanTitle) return;
        var cleanDesc = descInput.text.trim();
        var cleanCover = coverInput.text.trim();

        if (root.editMode) {
            root.playlistUpdated(root.targetPlaylistId, cleanTitle, cleanDesc, cleanCover);
        } else {
            root.playlistCreated(cleanTitle, cleanDesc, cleanCover, root.attachedTracks);
        }
        root.closeModal();
    }

    // Dismiss on background click
    MouseArea {
        anchors.fill: parent
        onClicked: root.closeModal()
    }

    // Modal Card
    Rectangle {
        id: card
        width: Math.min(500, root.width - 32)
        height: formCol.implicitHeight + 48
        anchors.centerIn: parent
        radius: 20
        color: Qt.rgba(0.08, 0.09, 0.13, 0.96)
        border.color: Qt.rgba(255, 255, 255, 0.14)
        border.width: 1

        // Consume click so background doesn't trigger
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            id: formCol
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 24
            spacing: 20

            // Header Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    Layout.fillWidth: true
                    text: root.editMode ? I18n.tr("Chỉnh sửa danh sách phát", "Edit Playlist")
                                       : I18n.tr("Tạo danh sách phát mới", "Create New Playlist")
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    color: "#ffffff"
                    elide: Text.ElideRight
                }

                Rectangle {
                    width: 30
                    height: 30
                    radius: 15
                    color: closeArea.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : "transparent"

                    AppIcon {
                        anchors.centerIn: parent
                        source: "../assets/icons/window-close-symbolic.svg"
                        iconSize: 14
                        color: closeArea.containsMouse ? "#ffffff" : Qt.rgba(255, 255, 255, 0.6)
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeModal()
                    }
                }
            }

            // Body Layout: Preview on Left, Inputs on Right
            RowLayout {
                Layout.fillWidth: true
                spacing: 18

                // Live Collage / Gradient Preview
                PlaylistCollageThumbnail {
                    Layout.preferredWidth: 110
                    Layout.preferredHeight: 110
                    radius: 14
                    customCover: coverInput.text.trim()
                    tracks: root.attachedTracks
                    playlistTitle: titleInput.text.trim()
                    accentColor: root.accentColor
                }

                // Input Fields
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    // Title Input
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: I18n.tr("Tên danh sách", "Playlist Name")
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: Qt.rgba(255, 255, 255, 0.65)
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 38
                            radius: 10
                            color: Qt.rgba(255, 255, 255, 0.06)
                            border.color: titleInput.activeFocus ? root.accentColor : Qt.rgba(255, 255, 255, 0.1)
                            border.width: 1

                            TextField {
                                id: titleInput
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                verticalAlignment: TextInput.AlignVCenter
                                color: "#ffffff"
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                placeholderText: I18n.tr("Nhập tên danh sách phát...", "Enter playlist title...")
                                placeholderTextColor: Qt.rgba(255, 255, 255, 0.3)
                                background: null
                                selectByMouse: true
                                Keys.onReturnPressed: root.submitForm()
                                Keys.onEnterPressed: root.submitForm()
                            }
                        }
                    }

                    // Description Input
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: I18n.tr("Mô tả (tùy chọn)", "Description (optional)")
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: Qt.rgba(255, 255, 255, 0.65)
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 38
                            radius: 10
                            color: Qt.rgba(255, 255, 255, 0.06)
                            border.color: descInput.activeFocus ? root.accentColor : Qt.rgba(255, 255, 255, 0.1)
                            border.width: 1

                            TextField {
                                id: descInput
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                verticalAlignment: TextInput.AlignVCenter
                                color: "#ffffff"
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                placeholderText: I18n.tr("Mô tả ngắn...", "Brief description...")
                                placeholderTextColor: Qt.rgba(255, 255, 255, 0.3)
                                background: null
                                selectByMouse: true
                                Keys.onReturnPressed: root.submitForm()
                                Keys.onEnterPressed: root.submitForm()
                            }
                        }
                    }
                }
            }

            // Cover URL Input
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: I18n.tr("Ảnh bìa tùy chỉnh (tùy chọn)", "Custom Cover URL (optional)")
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: Qt.rgba(255, 255, 255, 0.65)
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 38
                    radius: 10
                    color: Qt.rgba(255, 255, 255, 0.06)
                    border.color: coverInput.activeFocus ? root.accentColor : Qt.rgba(255, 255, 255, 0.1)
                    border.width: 1

                    TextField {
                        id: coverInput
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        color: "#ffffff"
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        placeholderText: I18n.tr("Dán URL ảnh hoặc đường dẫn file...", "Paste image URL or file path...")
                        placeholderTextColor: Qt.rgba(255, 255, 255, 0.3)
                        background: null
                        selectByMouse: true
                        Keys.onReturnPressed: root.submitForm()
                        Keys.onEnterPressed: root.submitForm()
                    }
                }
            }

            // Action Buttons
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                spacing: 12

                Item { Layout.fillWidth: true }

                // Cancel Button
                Rectangle {
                    Layout.preferredWidth: 90
                    Layout.preferredHeight: 38
                    radius: 19
                    color: cancelArea.containsMouse ? Qt.rgba(255, 255, 255, 0.1) : Qt.rgba(255, 255, 255, 0.05)
                    border.color: Qt.rgba(255, 255, 255, 0.12)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: I18n.tr("Hủy", "Cancel")
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: "#ffffff"
                    }

                    MouseArea {
                        id: cancelArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeModal()
                    }
                }

                // Submit Button (Dynamic Chromatic Accent)
                Rectangle {
                    id: submitBtn
                    readonly property bool canSubmit: titleInput.text.trim().length > 0
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 38
                    radius: 19
                    color: canSubmit
                           ? (submitArea.containsMouse ? Qt.lighter(root.accentColor, 1.15) : root.accentColor)
                           : Qt.rgba(255, 255, 255, 0.08)
                    opacity: canSubmit ? 1.0 : 0.5
                    border.color: canSubmit ? Qt.rgba(255, 255, 255, 0.25) : "transparent"
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        AppIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            source: root.editMode ? "../assets/icons/emblem-ok-symbolic.svg" : "../assets/icons/list-add-symbolic.svg"
                            iconSize: 14
                            color: submitBtn.canSubmit ? "#000000" : Qt.rgba(255, 255, 255, 0.4)
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.editMode ? I18n.tr("Lưu", "Save") : I18n.tr("Tạo mới", "Create")
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            color: submitBtn.canSubmit ? "#000000" : Qt.rgba(255, 255, 255, 0.4)
                        }
                    }

                    MouseArea {
                        id: submitArea
                        anchors.fill: parent
                        enabled: submitBtn.canSubmit
                        hoverEnabled: true
                        cursorShape: submitBtn.canSubmit ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.submitForm()
                    }
                }
            }
        }
    }
}
