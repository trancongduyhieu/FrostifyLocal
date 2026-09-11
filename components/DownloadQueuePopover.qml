import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import "."

Item {
    id: root
    anchors.fill: parent
    z: 9999
    visible: opacity > 0
    opacity: isOpen ? 1 : 0
    enabled: isOpen

    Behavior on opacity {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    property bool isOpen: false
    property var dlMgr: (typeof downloadManager !== "undefined" ? downloadManager : null)

    readonly property var allTasksList: dlMgr ? (dlMgr.tasksList || []) : []
    readonly property var activeTasks: allTasksList.filter(t => t.state === 1 || t.state === 2)
    readonly property var completedTasks: allTasksList.filter(t => t.state === 3)

    function open() {
        isOpen = true;
    }

    function close() {
        isOpen = false;
    }

    // Dismiss backdrop
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        preventStealing: true
        onClicked: root.close()
    }

    // Popover Card - Minimalist Clean (#121212 Spotify Desktop, 8px radius)
    Rectangle {
        id: popoverCard
        width: 390
        height: Math.min(Math.max(tasksCol.implicitHeight + 84, 160), 480)
        radius: 8
        color: "#121212"
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1
        clip: true

        // Positioned below header near download pill
        x: Math.max(20, Math.min(parent.width - width - 24, 380))
        y: 64

        scale: root.isOpen ? 1.0 : 0.95
        Behavior on scale {
            NumberAnimation { duration: 150; easing.type: Easing.OutBack }
        }

        // Prevent click through
        MouseArea {
            anchors.fill: parent
            preventStealing: true
            onClicked: mouse => mouse.accepted = true
        }

        ColumnLayout {
            id: cardContent
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            // Header Bar
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                SpotifyIcon {
                    source: "../assets/icons/download-symbolic.svg"
                    iconSize: 15
                    color: root.activeTasks.length > 0 ? Theme.spotifyGreen : Theme.textSecondary
                }

                Text {
                    text: "Downloads & Queue"
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                    color: "#ffffff"
                }

                Rectangle {
                    visible: root.activeTasks.length > 0
                    radius: 4
                    height: 18
                    width: actCountText.implicitWidth + 10
                    color: Qt.rgba(30, 215, 96, 0.15)
                    border.color: Theme.spotifyGreen
                    border.width: 1

                    Text {
                        id: actCountText
                        anchors.centerIn: parent
                        text: root.activeTasks.length + " active"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.bold: true
                        color: Theme.spotifyGreen
                    }
                }

                Item { Layout.fillWidth: true }

                // Open Folder Button
                Rectangle {
                    width: 26
                    height: 26
                    radius: 13
                    color: folderH.hovered ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                    HoverHandler { id: folderH }
                    ToolTip.visible: folderH.hovered
                    ToolTip.text: "Mở thư mục tải xuống"
                    ToolTip.delay: 300

                    SpotifyIcon {
                        anchors.centerIn: parent
                        source: "../assets/icons/folder-music-symbolic.svg"
                        iconSize: 14
                        color: folderH.hovered ? "#ffffff" : Theme.textSecondary
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached([
                                "xdg-open",
                                Quickshell.env("HOME") + "/Music/Downloads_Phone"
                            ]);
                        }
                    }
                }

                // Clear completed button
                Rectangle {
                    width: 26
                    height: 26
                    radius: 13
                    visible: root.completedTasks.length > 0
                    color: clearH.hovered ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                    HoverHandler { id: clearH }
                    ToolTip.visible: clearH.hovered
                    ToolTip.text: "Xóa danh sách đã tải xong"
                    ToolTip.delay: 300

                    SpotifyIcon {
                        anchors.centerIn: parent
                        source: "../assets/icons/edit-clear-all-symbolic.svg"
                        iconSize: 14
                        color: clearH.hovered ? "#ffffff" : Theme.textSecondary
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.dlMgr) root.dlMgr.clearCompleted();
                        }
                    }
                }

                // Close Button
                Rectangle {
                    width: 26
                    height: 26
                    radius: 13
                    color: closeH.hovered ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                    HoverHandler { id: closeH }
                    ToolTip.visible: closeH.hovered
                    ToolTip.text: "Đóng"
                    ToolTip.delay: 300

                    SpotifyIcon {
                        anchors.centerIn: parent
                        source: "../assets/icons/window-close-symbolic.svg"
                        iconSize: 12
                        color: closeH.hovered ? "#ffffff" : Theme.textSecondary
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(1, 1, 1, 0.06)
            }

            // Scrollable Task List
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: width
                contentHeight: tasksCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: tasksCol
                    width: parent.width
                    spacing: 10

                    // Empty State
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        visible: root.activeTasks.length === 0 && root.completedTasks.length === 0
                        Layout.topMargin: 20
                        Layout.bottomMargin: 20

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "No active downloads"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.bold: true
                            color: Theme.textSecondary
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Downloaded tracks are saved to ~/Music/Downloads_Phone"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: Qt.rgba(1, 1, 1, 0.35)
                        }
                    }

                    // Section: Active Downloads
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        visible: root.activeTasks.length > 0

                        Text {
                            text: "DOWNLOADING (" + root.activeTasks.length + ")"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                            color: Theme.spotifyGreen
                        }

                        Repeater {
                            model: root.activeTasks

                            delegate: Rectangle {
                                Layout.fillWidth: true
                                height: 56
                                radius: 6
                                color: Qt.rgba(1, 1, 1, 0.03)
                                border.color: Qt.rgba(1, 1, 1, 0.06)
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 10

                                    // 38x38 Thumbnail with Circular Spinner
                                    Rectangle {
                                        width: 38
                                        height: 38
                                        radius: 4
                                        color: "#1e1e1e"
                                        clip: true

                                        Image {
                                            anchors.fill: parent
                                            source: modelData.thumbnail || ""
                                            fillMode: Image.PreserveAspectCrop
                                            visible: status === Image.Ready
                                        }

                                        CircularSpinner {
                                            anchors.centerIn: parent
                                            size: 16
                                            strokeWidth: 2
                                            color: Theme.spotifyGreen
                                            running: true
                                        }
                                    }

                                    // Title, info, progress bar
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.title || "Track"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: "#ffffff"
                                            elide: Text.ElideRight
                                        }

                                        // Progress Bar (Slim 3px)
                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 3
                                            radius: 1.5
                                            color: Qt.rgba(1, 1, 1, 0.08)

                                            Rectangle {
                                                height: parent.height
                                                radius: 1.5
                                                color: Theme.spotifyGreen
                                                width: parent.width * Math.min(1.0, Math.max(0.0, (modelData.progress || 0) / 100.0))
                                                Behavior on width { NumberAnimation { duration: 150 } }
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6

                                            Text {
                                                text: Math.round(modelData.progress || 0) + "%"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: Theme.spotifyGreen
                                            }

                                            Text {
                                                text: "•"
                                                font.pixelSize: 10
                                                color: Theme.textMuted
                                            }

                                            Text {
                                                text: (modelData.speed || "--")
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 10
                                                color: Theme.textSecondary
                                            }

                                            Item { Layout.fillWidth: true }

                                            Text {
                                                text: "ETA: " + (modelData.eta || "--")
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 10
                                                color: Theme.textMuted
                                            }
                                        }
                                    }

                                    // Cancel Button
                                    Rectangle {
                                        width: 24
                                        height: 24
                                        radius: 12
                                        color: cancelH.hovered ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                                        HoverHandler { id: cancelH }

                                        SpotifyIcon {
                                            anchors.centerIn: parent
                                            source: "../assets/icons/window-close-symbolic.svg"
                                            iconSize: 11
                                            color: cancelH.hovered ? "#ff5252" : Theme.textMuted
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (root.dlMgr) root.dlMgr.cancel(modelData.videoId);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Section: Completed Downloads
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        visible: root.completedTasks.length > 0

                        Text {
                            text: "RECENTLY COMPLETED (" + root.completedTasks.length + ")"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                            color: Theme.textMuted
                        }

                        Repeater {
                            model: root.completedTasks

                            delegate: Rectangle {
                                Layout.fillWidth: true
                                height: 42
                                radius: 6
                                color: Qt.rgba(1, 1, 1, 0.02)

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 8

                                    SpotifyIcon {
                                        source: "../assets/icons/emblem-ok-symbolic.svg"
                                        iconSize: 14
                                        color: Theme.spotifyGreen
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.title || "Track"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: "#ffffff"
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.artist || "Downloaded"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            color: Theme.textSecondary
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
