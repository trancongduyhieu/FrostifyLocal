import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "."

Item {
    id: root
    anchors.fill: parent
    enabled: isOpen || closingGuard
    visible: opacity > 0 || closingGuard
    opacity: isOpen ? 1 : 0
    z: 9998

    Behavior on opacity {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }

    property bool isOpen: false
    property bool closingGuard: false
    property var listeners: [] // Array of { email, name, avatar }
    property color accentColor: (typeof win !== "undefined" && win.accentColor) ? win.accentColor : Theme.accent
    property real targetX: 0
    property real targetY: 0

    signal stopAllRequested()
    signal kickRequested(string email, string name)

    Timer {
        id: closeTimer
        interval: 200
        repeat: false
        onTriggered: root.closingGuard = false
    }

    function openAt(listenersList, xPos, yPos) {
        closeTimer.stop();
        root.closingGuard = false;
        root.listeners = listenersList || [];
        if (xPos !== undefined) root.targetX = xPos;
        if (yPos !== undefined) root.targetY = yPos;
        if (!root.listeners || root.listeners.length === 0) {
            root.closePopover();
            return;
        }
        root.isOpen = true;
    }

    function closePopover() {
        if (!root.isOpen && !root.closingGuard) return;
        root.isOpen = false;
        root.closingGuard = true;
        closeTimer.restart();
    }

    // Dismiss backdrop
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        preventStealing: true
        onPressed: mouse => {
            mouse.accepted = true;
            root.closePopover();
        }
        onReleased: mouse => mouse.accepted = true
        onClicked: mouse => mouse.accepted = true
    }

    // Popover Card
    Rectangle {
        id: card
        width: 250
        height: Math.min(320, col.implicitHeight + 24)
        radius: 14
        color: Qt.rgba(0.08, 0.08, 0.10, 0.96)
        border.color: Qt.rgba(1, 1, 1, 0.14)
        border.width: 1

        // Clamping within window
        x: Math.max(16, Math.min(root.targetX - width / 2, root.width - width - 16))
        y: Math.max(16, Math.min(root.targetY - height - 12, root.height - height - 16))

        scale: root.isOpen ? 1 : 0.94
        Behavior on scale {
            NumberAnimation { duration: 160; easing.type: Easing.OutBack }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            preventStealing: true
            onPressed: mouse => mouse.accepted = true
            onReleased: mouse => mouse.accepted = true
            onClicked: mouse => mouse.accepted = true
        }

        ColumnLayout {
            id: col
            anchors.top: parent.top
            anchors.topMargin: 12
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 12
            spacing: 10

            // Header Row: Title + Count (Không dùng chấm xanh)
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: I18n.tr("Đang nghe cùng (" + (root.listeners ? root.listeners.length : 0) + ")", "Listening along (" + (root.listeners ? root.listeners.length : 0) + ")")
                    color: "#ffffff"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                // Close mini button
                Rectangle {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    radius: 10
                    color: closeHover.hovered ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

                    HoverHandler { id: closeHover }

                    AppIcon {
                        anchors.centerIn: parent
                        source: "../assets/icons/window-close-symbolic.svg"
                        iconSize: 10
                        color: closeHover.hovered ? "#ffffff" : "#a1a1aa"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closePopover()
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(1, 1, 1, 0.08)
            }

            // Listeners List
            ListView {
                id: listView
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(180, count * 42)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.listeners || []

                delegate: Item {
                    width: listView.width
                    height: 40

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 4
                        anchors.rightMargin: 4
                        spacing: 10

                        // Avatar with circular clip
                        RoundedImage {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 14
                            source: modelData.avatar || ""
                            borderColor: Qt.rgba(1, 1, 1, 0.15)
                            borderWidth: 1
                            fallbackIcon: "../assets/icons/preferences-system-symbolic.svg"
                            placeholderColor: "#27272a"
                        }

                        // Name and Email
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: modelData.name || modelData.email || I18n.tr("Bạn bè", "Friend")
                                color: "#ffffff"
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.email ? modelData.email : ""
                                color: "#a1a1aa"
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                visible: text !== ""
                            }
                        }

                        // Nút Kick riêng từng người: Phẳng hoàn toàn trên bề mặt, không bọc con nhộng
                        Item {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24

                            HoverHandler { id: kickHover }

                            AppIcon {
                                anchors.centerIn: parent
                                source: "../assets/icons/window-close-symbolic.svg"
                                iconSize: 10
                                color: kickHover.hovered ? "#f43f5e" : Qt.rgba(1, 1, 1, 0.40)
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.kickRequested(modelData.email, modelData.name || modelData.email);
                                }
                            }
                        }
                    }
                }
            }

            // Empty state if 0 listeners
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                visible: !root.listeners || root.listeners.length === 0

                Text {
                    anchors.centerIn: parent
                    text: I18n.tr("Chưa có ai nghe cùng", "No co-listeners yet")
                    color: "#71717a"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(1, 1, 1, 0.08)
            }

            // Bottom Action: Chữ phẳng ở giữa, không có icon 'X', không có hộp hay con nhộng bọc ngoài
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 28

                HoverHandler { id: stopHover }

                Text {
                    anchors.centerIn: parent
                    text: I18n.tr("Dừng phát cùng tất cả", "End Co-Listening Session")
                    color: stopHover.hovered ? "#f43f5e" : "#fda4af"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    opacity: stopHover.hovered ? 1.0 : 0.85
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.closePopover();
                        root.stopAllRequested();
                    }
                }
            }
        }
    }
}
