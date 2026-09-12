import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "."

Item {
    id: root

    // Lyrics Data and State
    property var activeLyrics: []
    property real currentTime: 0.0
    property bool isPlaying: false
    property var currentTrack: null

    // Adaptive Palette / Styling
    property color colHighlight: "#deb06c"
    property color colActiveText: "#ffffff"
    property color colPendingText: "#8e8e8e"
    property color colShadowDir: "#a6020305"
    property color colShadowAmb: "#66000000"

    // Positioning
    property int defaultX: Math.round(root.width * 0.14)
    property int defaultY: Math.round(root.height * 0.62)
    property int customX: -1
    property int customY: -1

    signal positionChanged(int newX, int newY)

    // Sizing constants
    readonly property int lineHeight: 46
    readonly property int lineGap: 14
    readonly property int slotHeight: lineHeight + lineGap // 60px
    readonly property int containerWidth: Math.min(880, Math.round(root.width * 0.55))

    // =========================================================================
    // Synchronized Timing Engine
    // =========================================================================
    property int currentLyricIndex: -1
    property real currentLineStart: 0.0
    property real currentLineEnd: 0.0
    property real lineProgress: 0.0

    // Display index used for smooth rolling slide animation
    property int displayIndex: -1
    property real slideOffsetY: 0.0

    onCurrentTimeChanged: updateProgress()
    onActiveLyricsChanged: {
        updateProgress();
        displayIndex = currentLyricIndex;
    }

    function updateProgress() {
        if (!activeLyrics || activeLyrics.length === 0) {
            currentLyricIndex = -1;
            displayIndex = -1;
            lineProgress = 0.0;
            return;
        }

        var idx = -1;
        for (var i = 0; i < activeLyrics.length; i++) {
            var startTime = activeLyrics[i].time;
            var nextTime = (i + 1 < activeLyrics.length) ? activeLyrics[i + 1].time : (startTime + 5.0);
            if (currentTime >= startTime && currentTime < nextTime) {
                idx = i;
                currentLineStart = startTime;
                currentLineEnd = nextTime;
                var duration = Math.max(0.4, nextTime - startTime);
                lineProgress = Math.min(1.0, Math.max(0.0, (currentTime - startTime) / duration));
                break;
            }
        }

        if (idx !== currentLyricIndex) {
            var oldIdx = currentLyricIndex;
            currentLyricIndex = idx;

            if (idx === oldIdx + 1 && displayIndex === oldIdx) {
                // Advance by exactly 1 line -> Trigger Smooth Apple Glide rolling animation!
                rollAnimation.restart();
            } else {
                // Seek / skip -> snap directly without animation
                rollAnimation.stop();
                slideOffsetY = 0.0;
                displayIndex = idx;
            }
        }
    }

    NumberAnimation {
        id: rollAnimation
        target: root
        property: "slideOffsetY"
        from: 0
        to: -root.slotHeight
        duration: 450
        easing.type: Easing.OutCubic
        onFinished: {
            root.displayIndex = root.currentLyricIndex;
            root.slideOffsetY = 0.0;
        }
    }

    // Helper functions to get text safely
    function getLyricText(index) {
        if (!activeLyrics || index < 0 || index >= activeLyrics.length) return "";
        return activeLyrics[index].text || "";
    }

    // =========================================================================
    // Desktop Lyrics Bounding Box & Drag Handler
    // =========================================================================
    Item {
        id: container
        x: (root.customX >= 0) ? root.customX : root.defaultX
        y: (root.customY >= 0) ? root.customY : root.defaultY
        width: root.containerWidth
        height: root.slotHeight * 3 // 180px for 3 slots
        visible: root.activeLyrics && root.activeLyrics.length > 0 && root.currentLyricIndex >= 0

        // Hover indicator for Drag & Drop discovery
        Rectangle {
            anchors.fill: parent
            anchors.margins: -8
            radius: 12
            color: "transparent"
            border.color: dragArea.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : "transparent"
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: 150 } }

            // Subtle drag handle badge on top-right
            RowLayout {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 6
                spacing: 4
                opacity: dragArea.containsMouse ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 150 } }

                Rectangle {
                    width: 16
                    height: 16
                    radius: 4
                    color: Qt.rgba(0, 0, 0, 0.5)

                    AppIcon {
                        anchors.centerIn: parent
                        source: "../assets/icons/selection-mode-symbolic.svg"
                        iconSize: 10
                        color: "#cccccc"
                    }
                }

                Text {
                    text: "Kéo để dời"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: "#cccccc"
                }
            }
        }

        MouseArea {
            id: dragArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: containsMouse ? Qt.SizeAllCursor : Qt.ArrowCursor
            drag.target: container
            drag.axis: Drag.XAndYAxis
            drag.minimumX: 0
            drag.maximumX: Math.max(0, root.width - container.width)
            drag.minimumY: 0
            drag.maximumY: Math.max(0, root.height - container.height)

            onReleased: {
                root.positionChanged(container.x, container.y);
            }
        }

        // =====================================================================
        // Rolling Slots Viewport
        // =====================================================================
        Item {
            anchors.fill: parent
            clip: false

            Item {
                id: rollingContent
                x: 0
                y: root.slideOffsetY
                width: parent.width
                height: root.slotHeight * 4

                // -------------------------------------------------------------
                // Slot 0: Previous line (fading out during roll)
                // -------------------------------------------------------------
                Item {
                    x: 0
                    y: 0
                    width: parent.width
                    height: root.lineHeight
                    visible: opacity > 0.01
                    opacity: rollAnimation.running ? Math.max(0.0, 0.45 * (1.0 + root.slideOffsetY / root.slotHeight)) : 0.45

                    Text {
                        id: slot0Text
                        text: root.getLyricText(root.displayIndex - 1)
                        font.family: Theme.fontFamily
                        font.pixelSize: 28
                        font.weight: Font.Bold
                        color: root.colPendingText
                        elide: Text.ElideRight
                        width: parent.width
                        style: Text.Outline
                        styleColor: root.colShadowAmb
                    }

                    MultiEffect {
                        source: slot0Text
                        anchors.fill: slot0Text
                        blurEnabled: true
                        blur: 0.5
                        opacity: 0.8
                    }
                }

                // -------------------------------------------------------------
                // Slot 1: Active line (or transitions to previous during roll)
                // -------------------------------------------------------------
                Item {
                    id: slot1Item
                    x: 0
                    y: root.slotHeight
                    width: parent.width
                    height: root.lineHeight

                    // Base Pending Text
                    Text {
                        id: slot1BaseText
                        text: root.getLyricText(root.displayIndex)
                        font.family: Theme.fontFamily
                        font.pixelSize: 28
                        font.weight: Font.Bold
                        color: root.colPendingText
                        elide: Text.ElideRight
                        width: parent.width
                        style: Text.Outline
                        styleColor: root.colShadowAmb
                    }

                    // Karaoke Active Sung Wipe
                    Item {
                        id: slot1WipeClip
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: rollAnimation.running ? parent.width : Math.round(slot1BaseText.contentWidth * root.lineProgress)
                        clip: true
                        visible: width > 0

                        Text {
                            text: slot1BaseText.text
                            font: slot1BaseText.font
                            color: root.colActiveText
                            width: slot1BaseText.width
                            style: Text.Outline
                            styleColor: root.colShadowAmb
                        }
                    }

                    // Soft Neon Bloom Glow behind the sung text
                    MultiEffect {
                        anchors.fill: slot1WipeClip
                        source: slot1WipeClip
                        blurEnabled: true
                        blur: 0.25
                        opacity: 0.35
                        visible: !rollAnimation.running && slot1WipeClip.width > 0
                    }

                    // MultiEffect blur that smoothly ramps up if rolling to Slot 0
                    MultiEffect {
                        anchors.fill: slot1BaseText
                        source: slot1BaseText
                        blurEnabled: true
                        blur: rollAnimation.running ? Math.min(0.5, (-root.slideOffsetY / root.slotHeight) * 0.5) : 0.0
                        opacity: rollAnimation.running ? Math.min(0.8, (-root.slideOffsetY / root.slotHeight)) : 0.0
                        visible: rollAnimation.running
                    }
                }

                // -------------------------------------------------------------
                // Slot 2: Upcoming line (transitions to active during roll)
                // -------------------------------------------------------------
                Item {
                    x: 0
                    y: root.slotHeight * 2
                    width: parent.width
                    height: root.lineHeight

                    Text {
                        id: slot2Text
                        text: root.getLyricText(root.displayIndex + 1)
                        font.family: Theme.fontFamily
                        font.pixelSize: 28
                        font.weight: Font.Bold
                        color: root.colPendingText
                        elide: Text.ElideRight
                        width: parent.width
                        style: Text.Outline
                        styleColor: root.colShadowAmb
                    }

                    // Blur that smoothly ramps down as it glides up into Slot 1
                    MultiEffect {
                        source: slot2Text
                        anchors.fill: slot2Text
                        blurEnabled: true
                        blur: rollAnimation.running ? Math.max(0.0, 0.5 * (1.0 + root.slideOffsetY / root.slotHeight)) : 0.5
                        opacity: rollAnimation.running ? Math.max(0.0, 0.8 * (1.0 + root.slideOffsetY / root.slotHeight)) : 0.8
                    }

                    opacity: rollAnimation.running ? 0.45 + 0.55 * (-root.slideOffsetY / root.slotHeight) : 0.45
                }

                // -------------------------------------------------------------
                // Slot 3: Next-next line (fading in at bottom during roll)
                // -------------------------------------------------------------
                Item {
                    x: 0
                    y: root.slotHeight * 3
                    width: parent.width
                    height: root.lineHeight
                    visible: rollAnimation.running
                    opacity: rollAnimation.running ? Math.min(0.45, 0.45 * (-root.slideOffsetY / root.slotHeight)) : 0.0

                    Text {
                        id: slot3Text
                        text: root.getLyricText(root.displayIndex + 2)
                        font.family: Theme.fontFamily
                        font.pixelSize: 28
                        font.weight: Font.Bold
                        color: root.colPendingText
                        elide: Text.ElideRight
                        width: parent.width
                        style: Text.Outline
                        styleColor: root.colShadowAmb
                    }

                    MultiEffect {
                        source: slot3Text
                        anchors.fill: slot3Text
                        blurEnabled: true
                        blur: 0.5
                        opacity: 0.8
                    }
                }
            }
        }
    }
}
