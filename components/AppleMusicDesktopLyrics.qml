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

    // FontMetrics and Character-level Active Glow Engine
    FontMetrics {
        id: slot1FontMetrics
        font.family: Theme.fontFamily
        font.pixelSize: 28
        font.weight: Font.Bold
    }

    property int activeCharIndex: -1
    property string activeChar: ""
    property real activeCharX: 0
    property real activeCharW: 0

    onLineProgressChanged: {
        if (!rollAnimation.running) {
            updateActiveChar();
        }
    }

    onDisplayIndexChanged: {
        updateActiveChar();
        updateParsedWords();
    }

    // Word-level Parsing & Preparation Engine
    property var parsedWords: []

    function updateParsedWords() {
        var txt = getLyricText(displayIndex);
        if (!txt || txt.length === 0) {
            parsedWords = [];
            return;
        }

        var words = [];
        var regex = /\S+/g;
        var match;

        while ((match = regex.exec(txt)) !== null) {
            var wordStr = match[0];
            var sIdx = match.index;
            var eIdx = match.index + wordStr.length;
            var sX = slot1FontMetrics.advanceWidth(txt.substring(0, sIdx));
            var eX = slot1FontMetrics.advanceWidth(txt.substring(0, eIdx));
            words.push({
                text: wordStr,
                startIndex: sIdx,
                endIndex: eIdx,
                startX: sX,
                endX: eX,
                width: Math.max(1, eX - sX)
            });
        }
        parsedWords = words;
    }

    function updateActiveChar() {
        var txt = getLyricText(displayIndex);
        if (!txt || txt.length === 0 || lineProgress <= 0.001) {
            activeCharIndex = -1;
            activeChar = "";
            activeCharX = 0;
            activeCharW = 0;
            return;
        }

        var totalW = slot1FontMetrics.advanceWidth(txt);
        var targetW = totalW * lineProgress;
        var startX = 0;

        for (var i = 0; i < txt.length; i++) {
            var nextX = slot1FontMetrics.advanceWidth(txt.substring(0, i + 1));
            if (targetW <= nextX || i === txt.length - 1) {
                activeCharIndex = i;
                activeChar = txt.charAt(i);
                activeCharX = startX;
                activeCharW = Math.max(1, nextX - startX);
                return;
            }
            startX = nextX;
        }
    }

    onCurrentTimeChanged: updateProgress()
    onActiveLyricsChanged: {
        updateProgress();
        displayIndex = currentLyricIndex;
        updateParsedWords();
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
            // Slot 1: Active line (White sung text + Single-Character Gradual Glow)
            // -----------------------------------------------------------------
            Item {
                id: slot1Item
                x: 0
                y: root.slotHeight
                width: parent.width
                height: root.lineHeight

                // Normalized rolling animation progress (0.0 at rest, 0.0 -> 1.0 during glide)
                readonly property real rollProgress: rollAnimation.running ? Math.min(1.0, Math.max(0.0, -root.slideOffsetY / root.slotHeight)) : 0.0

                // When rolling up into Slot 0 position, smoothly apply frosted glass mist blur
                readonly property real rollBlur: rollProgress * 0.35

                layer.enabled: rollBlur > 0.01
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: slot1Item.rollBlur
                    blurMax: 20
                }

                opacity: rollAnimation.running ? Math.max(0.58, 1.0 - 0.42 * rollProgress) : 1.0

                // Base Hidden Text (For width measurement)
                Text {
                    id: slot1BaseText
                    text: root.getLyricText(root.displayIndex)
                    font.family: Theme.fontFamily
                    font.pixelSize: 28
                    font.weight: Font.Bold
                    visible: false
                }

                // 1. Pending Unsung Text
                Text {
                    id: slot1PendingText
                    text: slot1BaseText.text
                    font: slot1BaseText.font
                    color: root.colPendingText
                    elide: Text.ElideRight
                    width: parent.width
                    style: Text.Outline
                    styleColor: root.colShadowAmb
                    visible: !rollAnimation.running || (slot1WipeClip.width < parent.width)
                }

                // 2. Sung Text (Clean White #ffffff) - smoothly lerps to root.colPendingText during roll animation
                Item {
                    id: slot1WipeClip
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: {
                        if (rollAnimation.running || root.lineProgress >= 0.99) return parent.width;
                        if (root.activeCharIndex < 0) return 0;
                        return (root.activeChar === " ") ? (root.activeCharX + root.activeCharW) : root.activeCharX;
                    }
                    clip: true
                    visible: width > 0

                    Text {
                        text: slot1BaseText.text
                        font: slot1BaseText.font
                        color: {
                            if (rollAnimation.running) {
                                var p = slot1Item.rollProgress;
                                var baseR = root.colPendingText.r;
                                var baseG = root.colPendingText.g;
                                var baseB = root.colPendingText.b;
                                var r = 1.0 - (1.0 - baseR) * p;
                                var g = 1.0 - (1.0 - baseG) * p;
                                var b = 1.0 - (1.0 - baseB) * p;
                                return Qt.rgba(r, g, b, 1.0);
                            }
                            return "#ffffff";
                        }
                        width: slot1BaseText.width
                        style: Text.Outline
                        styleColor: root.colShadowAmb
                    }
                }

                // 3. SINGLE ACTIVE CHARACTER: Gradually illuminating from root.colPendingText into white phosphorescent glow
                Item {
                    id: singleActiveCharContainer
                    x: root.activeCharX
                    y: 0
                    width: Math.max(1, root.activeCharW)
                    height: slot1Item.height
                    visible: !rollAnimation.running && root.activeChar !== "" && root.activeChar !== " " && root.lineProgress > 0.001 && root.lineProgress < 0.99
                    z: 10

                    readonly property real charProgress: {
                        if (root.activeCharW <= 0) return 0.0;
                        var playheadX = slot1BaseText.contentWidth * root.lineProgress;
                        return Math.min(1.0, Math.max(0.0, (playheadX - root.activeCharX) / root.activeCharW));
                    }

                    readonly property real glowIntensity: Math.min(1.0, charProgress * 1.8)

                    readonly property color charColor: {
                        var baseR = root.colPendingText.r;
                        var baseG = root.colPendingText.g;
                        var baseB = root.colPendingText.b;
                        var r = baseR + (1.0 - baseR) * charProgress;
                        var g = baseG + (1.0 - baseG) * charProgress;
                        var b = baseB + (1.0 - baseB) * charProgress;
                        return Qt.rgba(r, g, b, 1.0);
                    }

                    Text {
                        id: singleGlyphSource
                        text: root.activeChar
                        font: slot1BaseText.font
                        color: "#ffffff"
                        opacity: 0.01
                    }

                    MultiEffect {
                        source: singleGlyphSource
                        anchors.fill: singleGlyphSource
                        shadowEnabled: true
                        shadowColor: "#ffffff"
                        shadowBlur: 0.85
                        shadowOpacity: 1.0
                        blurEnabled: true
                        blur: 0.50
                        blurMax: 16
                        opacity: singleActiveCharContainer.glowIntensity * 0.95
                    }

                    MultiEffect {
                        source: singleGlyphSource
                        anchors.fill: singleGlyphSource
                        shadowEnabled: true
                        shadowColor: "#ffffff"
                        shadowBlur: 0.40
                        shadowOpacity: 1.0
                        blurEnabled: true
                        blur: 0.20
                        blurMax: 8
                        opacity: singleActiveCharContainer.glowIntensity * 1.0
                    }

                    Text {
                        text: root.activeChar
                        font: slot1BaseText.font
                        color: singleActiveCharContainer.charColor
                        style: Text.Outline
                        styleColor: Qt.rgba(1.0, 1.0, 1.0, singleActiveCharContainer.glowIntensity * 0.9)
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
