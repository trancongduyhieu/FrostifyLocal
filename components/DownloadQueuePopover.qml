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

    // Popover Card
    Rectangle {
        id: popoverCard
        width: 390
        height: Math.min(Math.max(tasksCol.implicitHeight + 84, 160), 480)
        radius: 12
        color: Qt.rgba(0.10, 0.10, 0.13, 0.97)
        border.color: Qt.rgba(1, 1, 1, 0.14)
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
            anchors.margins: 16
            spacing: 12

            // Header Bar
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                SpotifyIcon {
                    source: "../assets/icons/download-symbolic.svg"
                    iconSize: 16
                    color: root.activeTasks.length > 0 ? "#00c853" : Theme.textPrimary
                }

                Text {
                    text: "Downloads & Transfers"
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.bold: true
                    color: Theme.textPrimary
                }

                Rectangle {
                    visible: root.activeTasks.length > 0
                    radius: 9
                    height: 18
                    width: actCountText.implicitWidth + 12
                    color: Qt.rgba(0, 200, 83, 0.2)
                    border.color: "#00c853"
                    border.width: 1

                    Text {
                        id: actCountText
                        anchors.centerIn: parent
                        text: root.activeTasks.length + " active"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.bold: true
                        color: "#00c853"
                    }
                }

                Item { Layout.fillWidth: true }

                // Open Folder Button
                Item {
                    width: 28
                    height: 28
                    HoverHandler { id: folderH }

                    SpotifyIcon {
                        anchors.centerIn: parent
                        source: "../assets/icons/folder-music-symbolic.svg"
                        iconSize: 15
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
                Item {
                    width: 28
                    height: 28
                    visible: root.completedTasks.length > 0
                    HoverHandler { id: clearH }

                    SpotifyIcon {
                        anchors.centerIn: parent
                        source: "../assets/icons/edit-clear-all-symbolic.svg"
                        iconSize: 15
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
                Item {
                    width: 28
                    height: 28
                    HoverHandler { id: closeH }

                    SpotifyIcon {
                        anchors.centerIn: parent
                        source: "../assets/icons/window-close-symbolic.svg"
                        iconSize: 14
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
                color: Qt.rgba(1, 1, 1, 0.08)
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
                    spacing: 12

                    // Empty State
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        visible: root.activeTasks.length === 0 && root.completedTasks.length === 0
                        Layout.topMargin: 16
                        Layout.bottomMargin: 16

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
                        spacing: 8
                        visible: root.activeTasks.length > 0

                        Text {
                            text: "DOWNLOADING (" + root.activeTasks.length + ")"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: "#00c853"
                        }

                        Repeater {
                            model: root.activeTasks

                            delegate: Rectangle {
                                Layout.fillWidth: true
                                height: 56
                                radius: 8
                                color: Qt.rgba(1, 1, 1, 0.04)
                                border.color: Qt.rgba(1, 1, 1, 0.08)
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 10

                                    // Thumbnail or Spinner
                                    Rectangle {
                                        width: 38
                                        height: 38
                                        radius: 4
                                        color: "#202024"
                                        clip: true

                                        Image {
                                            anchors.fill: parent
                                            source: modelData.thumbnail || ""
                                            fillMode: Image.PreserveAspectCrop
                                            visible: status === Image.Ready
                                        }

                                        DownloadingSpinner {
                                            anchors.centerIn: parent
                                            running: true
                                            iconSize: 18
                                            color: "#00c853"
                                        }
                                    }

                                    // Title, info, progress bar
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 3

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.title || "Track"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: Theme.textPrimary
                                            elide: Text.ElideRight
                                        }

                                        // Progress Bar
                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 4
                                            radius: 2
                                            color: "#303036"

                                            Rectangle {
                                                height: parent.height
                                                radius: 2
                                                color: "#00c853"
                                                width: parent.width * Math.min(1.0, Math.max(0.0, (modelData.progress || 0) / 100.0))
                                                Behavior on width { NumberAnimation { duration: 100 } }
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
                                                color: "#00c853"
                                            }

                                            Text {
                                                text: "•"
                                                font.pixelSize: 10
                                                color: Theme.textSecondary
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
                                                color: Theme.textSecondary
                                            }
                                        }
                                    }

                                    // Cancel Button
                                    Item {
                                        width: 24
                                        height: 24
                                        HoverHandler { id: cancelH }

                                        SpotifyIcon {
                                            anchors.centerIn: parent
                                            source: "../assets/icons/window-close-symbolic.svg"
                                            iconSize: 12
                                            color: cancelH.hovered ? "#ff5252" : Theme.textSecondary
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
                        spacing: 8
                        visible: root.completedTasks.length > 0

                        Text {
                            text: "RECENTLY COMPLETED (" + root.completedTasks.length + ")"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: Theme.textSecondary
                        }

                        Repeater {
                            model: root.completedTasks

                            delegate: Rectangle {
                                Layout.fillWidth: true
                                height: 44
                                radius: 6
                                color: Qt.rgba(1, 1, 1, 0.02)

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 8

                                    SpotifyIcon {
                                        source: "../assets/icons/emblem-ok-symbolic.svg"
                                        iconSize: 14
                                        color: "#00c853"
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.title || "Track"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            color: Theme.textPrimary
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
