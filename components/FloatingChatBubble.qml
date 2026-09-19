import QtQuick
import QtQuick.Layouts
import "."

Item {
    id: root
    anchors.fill: parent
    z: 9995

    property color accentColor: (typeof win !== "undefined" && win.accentColor) ? win.accentColor : Theme.accent

    ListModel {
        id: bubbleModel
    }

    function spawnBubble(senderName, senderAvatar, messageText) {
        if (!messageText || messageText.trim() === "") return;
        var rOffset = Math.floor(Math.random() * 80) - 40; // Slight random jitter for Danmaku feel
        bubbleModel.append({
            "msgId": Date.now() + "_" + Math.random(),
            "name": senderName || I18n.tr("Bạn bè", "Friend"),
            "avatar": senderAvatar || "",
            "text": messageText.trim(),
            "jitterX": rOffset
        });
    }

    Repeater {
        model: bubbleModel

        delegate: Item {
            id: bubbleDelegate
            width: bubbleContent.implicitWidth + 20
            height: bubbleContent.implicitHeight + 14

            // Positioned horizontally centered above PlayerBar with slight organic jitter
            x: Math.max(20, Math.min(root.width - width - 20, (root.width - width) / 2 + (model.jitterX || 0)))
            y: root.height - 100

            // Danmaku Floating Animation: Flies upward and fades out gracefully over 4 seconds
            ParallelAnimation {
                running: true

                NumberAnimation {
                    target: bubbleDelegate
                    property: "y"
                    from: root.height - 100
                    to: root.height - 270
                    duration: 4000
                    easing.type: Easing.OutCubic
                }

                SequentialAnimation {
                    NumberAnimation {
                        target: bubbleDelegate
                        property: "opacity"
                        from: 0.0
                        to: 1.0
                        duration: 200
                        easing.type: Easing.OutQuad
                    }
                    PauseAnimation {
                        duration: 2800
                    }
                    NumberAnimation {
                        target: bubbleDelegate
                        property: "opacity"
                        from: 1.0
                        to: 0.0
                        duration: 1000
                        easing.type: Easing.InQuad
                    }
                    ScriptAction {
                        script: {
                            // Find and remove self from model when animation completes
                            for (var i = 0; i < bubbleModel.count; i++) {
                                if (bubbleModel.get(i).msgId === model.msgId) {
                                    bubbleModel.remove(i);
                                    break;
                                }
                            }
                        }
                    }
                }

                NumberAnimation {
                    target: bubbleDelegate
                    property: "scale"
                    from: 0.88
                    to: 1.0
                    duration: 250
                    easing.type: Easing.OutBack
                }
            }

            Rectangle {
                id: bubbleBg
                anchors.fill: parent
                radius: 16
                color: Qt.rgba(0.08, 0.08, 0.10, 0.92)
                border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.40)
                border.width: 1

                RowLayout {
                    id: bubbleContent
                    anchors.centerIn: parent
                    spacing: 8

                    // Mini Sender Avatar
                    RoundedImage {
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        radius: 11
                        source: model.avatar || ""
                        fallbackIcon: "../assets/icons/preferences-system-symbolic.svg"
                        placeholderColor: "#27272a"
                        visible: model.avatar !== ""
                    }

                    // Green Live Dot when no avatar
                    Rectangle {
                        Layout.preferredWidth: 6
                        Layout.preferredHeight: 6
                        radius: 3
                        color: "#10b981"
                        visible: !model.avatar || model.avatar === ""
                    }

                    ColumnLayout {
                        spacing: 1

                        Text {
                            text: model.name
                            color: root.accentColor
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            text: model.text
                            color: "#ffffff"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                    }
                }
            }
        }
    }
}
