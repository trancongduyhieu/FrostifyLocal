import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtQuick.Effects
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
    property Item backgroundSourceItem: null
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
        if (xPos !== undefined && xPos > 0) root.targetX = xPos;
        else root.targetX = root.width - 240;
        if (yPos !== undefined && yPos > 0) root.targetY = yPos;
        else root.targetY = root.height - 80;
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

    // Popover Card with Keo 502 Optical LiquidGlass (SimpMusic / PlayerBar Spec)
    Item {
        id: cardWrapper
        width: 250
        height: Math.min(320, col.implicitHeight + 24)

        // Clamping within window
        x: Math.max(16, Math.min(root.targetX - width / 2, root.width - width - 16))
        y: Math.max(16, Math.min(root.targetY - height - 12, root.height - height - 16))

        scale: root.isOpen ? 1 : 0.94
        Behavior on scale {
            NumberAnimation { duration: 160; easing.type: Easing.OutBack }
        }

        // Outer Drop Shadow (MultiEffect standard)
        Rectangle {
            id: shadowShape
            anchors.fill: parent
            radius: 16
            color: "#000000"
            visible: false
        }

        MultiEffect {
            anchors.fill: shadowShape
            source: shadowShape
            shadowEnabled: true
            shadowColor: "#66000000"
            shadowVerticalOffset: 2
            shadowBlur: 0.50
            z: 1
        }

        // Keo 502 Optical LiquidGlass Resin Container (Liquid Glass Spec - Identical to PlayerBar)
        LiquidGlass {
            id: card
            anchors.fill: parent
            radius: 16
            displacement: 18.0
            aberration: 0.03
            bevelWidth: 24.0
            tintColor: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.18)
            backgroundSourceItem: root.backgroundSourceItem
            isFlowActive: (typeof win !== "undefined" && win.isPlaying && win.currentTrack !== null)
            clip: true
            z: 2

            // 1px Concentric Hairline Accent Border (Keo 502 Surface Tension Rim)
            Rectangle {
                anchors.fill: parent
                radius: card.radius
                color: "transparent"
                border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.25)
                border.width: 1
                z: 1
                Behavior on border.color { ColorAnimation { duration: 250 } }
            }

            // Prevent click-through from card background to dismiss backdrop
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                z: 1
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
                spacing: 12
                z: 10

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

                    // Close mini button (z: 5, responsive click area)
                    Item {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        z: 5

                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            color: closeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        AppIcon {
                            anchors.centerIn: parent
                            source: "../assets/icons/window-close-symbolic.svg"
                            iconSize: 11
                            color: closeMouse.containsMouse ? "#f43f5e" : "#a1a1aa"
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closePopover()
                        }
                    }
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
                                borderColor: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.45)
                                borderWidth: 1
                                fallbackIcon: "../assets/icons/preferences-system-symbolic.svg"
                                placeholderColor: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.20)
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

                            // Nút Kick riêng từng người: Phẳng hoàn toàn trên bề mặt, không bọc con nhộng (z: 5)
                            Item {
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 26
                                z: 5

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 13
                                    color: kickMouse.containsMouse ? Qt.rgba(244, 63, 94, 0.16) : "transparent"
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }

                                AppIcon {
                                    anchors.centerIn: parent
                                    source: "../assets/icons/window-close-symbolic.svg"
                                    iconSize: 11
                                    color: kickMouse.containsMouse ? "#f43f5e" : Qt.rgba(1, 1, 1, 0.45)
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }

                                MouseArea {
                                    id: kickMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
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


        }
    }
}
}

