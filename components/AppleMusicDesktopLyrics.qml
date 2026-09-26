import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "."

Item {
    id: root

    // =========================================================================
    // Lyrics Data and State (Passed from Universal DesktopLyricsWidget)
    // =========================================================================
    property var activeLyrics: []
    property real currentTime: 0.0
    property bool isPlaying: false
    property var currentTrack: null

    // Adaptive Palette / Styling
    property color colHighlight: "#deb06c"
    property color colActiveText: "#ffffff"
    property color colPendingText: "#a0a5b5"
    property color colShadowDir: "#a6020305"
    property color colShadowAmb: "#66000000"

    // Parametric Multi-Line Configuration (Easily switch between 3, 5, 7 lines)
    property int visibleLinesCount: 5

    // Sizing constants
    readonly property int lineHeight: 46
    readonly property int lineGap: 14
    readonly property int slotHeight: lineHeight + lineGap // 60px

    implicitHeight: slotHeight * visibleLinesCount // 300px for 5 lines
    implicitWidth: 880

    visible: root.activeLyrics && root.activeLyrics.length > 0 && root.currentLyricIndex >= 0

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

    // Current line data and word-level timing resolution
    function getCurrentLineData(idx) {
        if (!root.activeLyrics || idx < 0 || idx >= root.activeLyrics.length) return null;
        return root.activeLyrics[idx];
    }

    readonly property var currentLineObj: getCurrentLineData(root.displayIndex)
    readonly property var currentLineWords: (currentLineObj && currentLineObj.words) ? currentLineObj.words : []
    readonly property bool currentLineHasWords: !!(currentLineObj && currentLineObj.hasWords && !currentLineObj.isSynthetic && currentLineWords.length > 0)

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

    // Mathematical Optical Depth-of-Field Formulas
    function calcBaseOpacity(s) {
        if (s <= 1) return 1.0;
        if (s === 2) return 0.58;
        return Math.max(0.14, 0.58 - 0.20 * (s - 2));
    }

    function calcBaseBlur(s) {
        if (s <= 1) return 0.0;
        if (s === 2) return 0.35;
        return Math.min(0.85, 0.35 + 0.25 * (s - 2));
    }

    function calcBaseScale(s) {
        if (s <= 2) return 1.0;
        if (s === 3) return 0.93;
        if (s === 4) return 0.84;
        return Math.max(0.70, 0.84 - 0.09 * (s - 4));
    }

    // =========================================================================
    // Rolling Slots Viewport (Pure Presentation)
    // =========================================================================
    Item {
        anchors.fill: parent
        clip: false

        Item {
            id: rollingContent
            x: 0
            y: root.slideOffsetY
            width: parent.width
            height: root.slotHeight * (root.visibleLinesCount + 1)

            // -----------------------------------------------------------------
            // Slot 0: Previous line (Frosted Glass Optical Blur)
            // -----------------------------------------------------------------
            Item {
                id: slot0Item
                x: 0
                y: 0
                width: parent.width
                height: root.lineHeight
                visible: opacity > 0.01
                opacity: rollAnimation.running ? Math.max(0.0, 0.58 * (1.0 - slot1Item.rollProgress)) : 0.58

                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: 0.35
                    blurMax: 20
                }

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
            }

            // -----------------------------------------------------------------
            // Slot 1: Active Line — Driven by AppleMusicWordFlow Engine
            // -----------------------------------------------------------------
            Item {
                id: slot1Item
                x: 0
                y: root.slotHeight
                width: parent.width
                height: root.lineHeight

                // Normalized rolling animation progress (0.0 at rest, 0.0 -> 1.0 during glide)
                readonly property real rollProgress: rollAnimation.running ? Math.min(1.0, Math.max(0.0, -root.slideOffsetY / root.slotHeight)) : 0.0
                readonly property real rollBlur: rollProgress * 0.35

                layer.enabled: rollBlur > 0.01
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: slot1Item.rollBlur
                    blurMax: 20
                }

                opacity: rollAnimation.running ? Math.max(0.58, 1.0 - 0.42 * rollProgress) : 1.0

                // Syllable Mode: Real AppleMusicWordFlow engine (accurate physics, wave lift, phosphor bloom)
                Loader {
                    id: activeWordFlowLoader
                    anchors.fill: parent
                    active: root.currentLineHasWords
                    visible: active

                    sourceComponent: Component {
                        AppleMusicWordFlow {
                            width: slot1Item.width
                            words: root.currentLineWords
                            currentTime: root.currentTime
                            isLineActive: true
                            fontSize: 28
                            fontFamily: Theme.fontFamily
                            fontWeight: Font.Bold
                            accentColor: root.colHighlight
                        }
                    }
                }

                // Fallback Mode: For LRC lines without word timestamps (isSynthetic)
                Item {
                    id: activeFallbackItem
                    anchors.fill: parent
                    visible: !root.currentLineHasWords

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.getLyricText(root.displayIndex)
                        font.family: Theme.fontFamily
                        font.pixelSize: 28
                        font.weight: Font.Bold
                        color: "#ffffff"
                        elide: Text.ElideRight
                        width: parent.width
                        style: Text.Outline
                        styleColor: root.colShadowAmb
                    }
                }
            }

            // -----------------------------------------------------------------
            // Slots 2..N + Buffer: Parametric Upcoming Lines (Optical DoF Depth of Field)
            // -----------------------------------------------------------------
            Repeater {
                id: upcomingSlotsRepeater
                model: root.visibleLinesCount // E.g., for 5 lines, creates slots 2, 3, 4, 5 (buffer)

                Item {
                    id: slotItem
                    readonly property int slotIndex: index + 2
                    readonly property bool isBufferSlot: slotIndex > root.visibleLinesCount

                    x: 0
                    y: root.slotHeight * slotIndex
                    width: rollingContent.width
                    height: root.lineHeight
                    transformOrigin: Item.Left
                    visible: (!isBufferSlot || rollAnimation.running) && opacity > 0.01

                    // Base values at rest
                    readonly property real baseOp: root.calcBaseOpacity(slotIndex)
                    readonly property real prevOp: root.calcBaseOpacity(slotIndex - 1)

                    readonly property real baseBl: root.calcBaseBlur(slotIndex)
                    readonly property real prevBl: root.calcBaseBlur(slotIndex - 1)

                    readonly property real baseSc: root.calcBaseScale(slotIndex)
                    readonly property real prevSc: root.calcBaseScale(slotIndex - 1)

                    // Dynamic interpolation during roll glide animation
                    opacity: {
                        if (isBufferSlot) {
                            return rollAnimation.running ? Math.min(baseOp, baseOp * slot1Item.rollProgress) : 0.0;
                        }
                        return rollAnimation.running ? (baseOp + (prevOp - baseOp) * slot1Item.rollProgress) : baseOp;
                    }

                    scale: {
                        if (isBufferSlot) {
                            return 0.75 + 0.09 * slot1Item.rollProgress;
                        }
                        return rollAnimation.running ? (baseSc + (prevSc - baseSc) * slot1Item.rollProgress) : baseSc;
                    }

                    readonly property real currentBlur: {
                        if (isBufferSlot) return 0.85;
                        return rollAnimation.running ? (baseBl + (prevBl - baseBl) * slot1Item.rollProgress) : baseBl;
                    }

                    layer.enabled: currentBlur > 0.01
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blur: slotItem.currentBlur
                        blurMax: 32
                    }

                    Text {
                        text: root.getLyricText(root.displayIndex + (slotItem.slotIndex - 1))
                        font.family: Theme.fontFamily
                        font.pixelSize: 28
                        font.weight: Font.Bold
                        color: root.colPendingText
                        elide: Text.ElideRight
                        width: parent.width
                        style: Text.Outline
                        styleColor: root.colShadowAmb
                    }
                }
            }
        }
    }
}
