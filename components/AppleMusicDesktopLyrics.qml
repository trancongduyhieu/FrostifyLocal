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
                // Slot 0: Previous line (Gentle Frosted Mist - Clearly Legible)
                // -------------------------------------------------------------
                Item {
                    x: 0
                    y: 0
                    width: parent.width
                    height: root.lineHeight
                    visible: opacity > 0.01
                    opacity: rollAnimation.running ? Math.max(0.0, 0.75 * (1.0 + root.slideOffsetY / root.slotHeight)) : 0.75

                    Text {
                        id: slot0Text
                        text: root.getLyricText(root.displayIndex - 1)
                        font.family: Theme.fontFamily
                        font.pixelSize: 28
                        font.weight: Font.Bold
                        color: "#b0b5c2"
                        elide: Text.ElideRight
                        width: parent.width
                        style: Text.Outline
                        styleColor: root.colShadowAmb
                    }

                    MultiEffect {
                        source: slot0Text
                        anchors.fill: slot0Text
                        blurEnabled: true
                        blur: 0.22
                        blurMax: 8
                        opacity: 0.70
                    }
                }

                // -------------------------------------------------------------
                // Slot 1: Active line (White sung text + White Phosphorescent Glowing Active Glyph)
                // -------------------------------------------------------------
                Item {
                    id: slot1Item
                    x: 0
                    y: root.slotHeight
                    width: parent.width
                    height: root.lineHeight

                    // Base Hidden Text (For width measurement)
                    Text {
                        id: slot1BaseText
                        text: root.getLyricText(root.displayIndex)
                        font.family: Theme.fontFamily
                        font.pixelSize: 28
                        font.weight: Font.Bold
                        visible: false
                    }

                    // 1. Pending Unsung Text (Soft dim gray)
                    Text {
                        id: slot1PendingText
                        text: slot1BaseText.text
                        font: slot1BaseText.font
                        color: root.colPendingText
                        elide: Text.ElideRight
                        width: parent.width
                        style: Text.Outline
                        styleColor: root.colShadowAmb
                    }

                    // 2. Sung Text (Clean White #ffffff) - strictly clipped up to the start of active character
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
                            color: "#ffffff"
                            width: slot1BaseText.width
                            style: Text.Outline
                            styleColor: root.colShadowAmb
                        }
                    }

                    // 3. SINGLE ACTIVE CHARACTER: Gradually illuminating from gray into white phosphorescent glow
                    Item {
                        id: singleActiveCharContainer
                        x: root.activeCharX
                        y: 0
                        width: Math.max(1, root.activeCharW)
                        height: slot1Item.height
                        visible: !rollAnimation.running && root.activeChar !== "" && root.activeChar !== " " && root.lineProgress > 0.001 && root.lineProgress < 0.99
                        z: 10

                        // Character progress (0.0 when playhead enters char, 1.0 when playhead leaves char)
                        readonly property real charProgress: {
                            if (root.activeCharW <= 0) return 0.0;
                            var playheadX = slot1BaseText.contentWidth * root.lineProgress;
                            return Math.min(1.0, Math.max(0.0, (playheadX - root.activeCharX) / root.activeCharW));
                        }

                        // Glow intensity: smoothly rises from 0.0 as character lights up
                        readonly property real glowIntensity: Math.min(1.0, charProgress * 1.8)

                        // Base character color: smoothly transitions from gray #8e8e8e to white #ffffff
                        readonly property color charColor: {
                            var r = 0.56 + (1.0 - 0.56) * charProgress;
                            return Qt.rgba(r, r, r, 1.0);
                        }

                        // Glyph for MultiEffect bloom
                        Text {
                            id: singleGlyphSource
                            text: root.activeChar
                            font: slot1BaseText.font
                            color: "#ffffff"
                            opacity: 0.01
                        }

                        // Wide soft white phosphorescent aura on THIS SINGLE GLYPH ONLY
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

                        // Tight intense white core glow on THIS SINGLE GLYPH ONLY
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

                        // The sharp character glyph transitioning gradually from gray to white
                        Text {
                            text: root.activeChar
                            font: slot1BaseText.font
                            color: singleActiveCharContainer.charColor
                            style: Text.Outline
                            styleColor: Qt.rgba(1.0, 1.0, 1.0, singleActiveCharContainer.glowIntensity * 0.9)
                        }
                    }

                    // MultiEffect blur that smoothly ramps up if rolling to Slot 0
                    MultiEffect {
                        anchors.fill: slot1PendingText
                        source: slot1PendingText
                        blurEnabled: true
                        blur: rollAnimation.running ? Math.min(0.22, (-root.slideOffsetY / root.slotHeight) * 0.22) : 0.0
                        blurMax: 8
                        opacity: rollAnimation.running ? Math.min(0.75, (-root.slideOffsetY / root.slotHeight)) : 0.0
                        visible: rollAnimation.running
                    }
                }

                // -------------------------------------------------------------
                // Slot 2: Upcoming line (Gentle Frosted Mist - Clearly Legible)
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
                        color: "#b0b5c2"
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
                        blur: rollAnimation.running ? Math.max(0.0, 0.22 * (1.0 + root.slideOffsetY / root.slotHeight)) : 0.22
                        blurMax: 8
                        opacity: rollAnimation.running ? Math.max(0.0, 0.70 * (1.0 + root.slideOffsetY / root.slotHeight)) : 0.70
                    }

                    opacity: rollAnimation.running ? 0.75 + 0.25 * (-root.slideOffsetY / root.slotHeight) : 0.75
                }

                // -------------------------------------------------------------
                // Slot 3: Next-next line (Gentle Frosted Mist fading in at bottom)
                // -------------------------------------------------------------
                Item {
                    x: 0
                    y: root.slotHeight * 3
                    width: parent.width
                    height: root.lineHeight
                    visible: rollAnimation.running
                    opacity: rollAnimation.running ? Math.min(0.75, 0.75 * (-root.slideOffsetY / root.slotHeight)) : 0.0

                    Text {
                        id: slot3Text
                        text: root.getLyricText(root.displayIndex + 2)
                        font.family: Theme.fontFamily
                        font.pixelSize: 28
                        font.weight: Font.Bold
                        color: "#b0b5c2"
                        elide: Text.ElideRight
                        width: parent.width
                        style: Text.Outline
                        styleColor: root.colShadowAmb
                    }

                    MultiEffect {
                        source: slot3Text
                        anchors.fill: slot3Text
                        blurEnabled: true
                        blur: 0.22
                        blurMax: 8
                        opacity: 0.70
                    }
                }
            }
        }
    }
}
