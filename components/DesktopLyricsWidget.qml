import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    property var activeLyrics: []
    property real currentTime: 0.0
    property bool isPlaying: false
    property var currentTrack: null
    property bool enabled: true

    screen: Quickshell.screens[0]
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "frostify:desktop_lyrics"
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Instrument Serif (Cinematic Typeface) & Fonts
    FontLoader {
        id: instrumentSerifFont
        source: "../assets/fonts/InstrumentSerif-Regular.ttf"
    }

    FontLoader {
        id: instrumentSerifItalicFont
        source: "../assets/fonts/InstrumentSerif-Italic.ttf"
    }

    readonly property string magicFontFamily: (instrumentSerifFont.status === FontLoader.Ready && instrumentSerifFont.name !== "") ? instrumentSerifFont.name : "Instrument Serif"

    // Palette & Colors: Sophisticated Vintage Champagne Gold
    readonly property color colHighlight: "#deb06c"

    // =========================================================================
    // Synchronized Timing Engine (Single Line Active + Deep Languid Exiting Fade)
    // =========================================================================
    property int currentLyricIndex: -1
    property real currentLineStart: 0.0
    property real currentLineEnd: 0.0
    property real lineProgress: 0.0

    property string activeLineText: ""
    property string fadingLineText: ""

    // Raised position on the maid skirt/lap area (y ≈ 72.5%)
    readonly property int activeY: Math.round(root.height * 0.725)
    readonly property int activeX: Math.round(root.width * 0.145)

    onCurrentTimeChanged: updateProgress()
    onActiveLyricsChanged: updateProgress()

    function updateProgress() {
        if (!activeLyrics || activeLyrics.length === 0) {
            currentLyricIndex = -1;
            lineProgress = 0.0;
            activeLineText = "";
            fadingLineText = "";
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
            if (currentLyricIndex >= 0 && idx > currentLyricIndex && activeLyrics && currentLyricIndex < activeLyrics.length) {
                // Completed previous line -> trigger smooth, deep fade-down exit!
                triggerFadeOutLine(activeLyrics[currentLyricIndex].text);
            }
            currentLyricIndex = idx;
            if (idx >= 0 && activeLyrics && idx < activeLyrics.length) {
                activeLineText = activeLyrics[idx].text;
            } else {
                activeLineText = "";
            }
        }
    }

    function triggerFadeOutLine(oldText) {
        fadingLineText = oldText;
        fadingContainer.opacity = 0.78;
        fadingContainer.y = activeY;
        fadingContainer.rotation = 0;
        fadeDownExitAnim.restart();
    }

    // Master Desktop Canvas
    Item {
        anchors.fill: parent
        visible: root.enabled && root.activeLyrics.length > 0 && (activeLineText !== "" || fadingLineText !== "")

        // =========================================================================
        // EXITING LINE: Sinks deep (+52px), lingers gracefully, then fades smoothly to 0
        // (Không biến mất liền, xuống sâu hơn, fade mượt mà 1.6s)
        // =========================================================================
        Item {
            id: fadingContainer
            x: root.activeX
            y: root.activeY
            width: Math.min(740, Math.round(parent.width * 0.45))
            height: 68
            transformOrigin: Item.Left
            opacity: 0.0
            visible: fadingLineText !== "" && opacity > 0.01

            EnchantingSentence {
                id: fadingSentence
                anchors.fill: parent
                text: root.fadingLineText
                progress: 1.0
                isActive: false
                isDead: true
                fontFamily: root.magicFontFamily
                fontSize: 35
                colHighlight: root.colHighlight
            }

            SequentialAnimation {
                id: fadeDownExitAnim

                ParallelAnimation {
                    // Sinks significantly deeper (+52px down onto the lower fold)
                    NumberAnimation {
                        target: fadingContainer
                        property: "y"
                        from: root.activeY
                        to: root.activeY + 52
                        duration: 1600
                        easing.type: Easing.OutCubic
                    }
                    // Very subtle organic tilt (1.8 deg)
                    NumberAnimation {
                        target: fadingContainer
                        property: "rotation"
                        from: 0
                        to: 1.8
                        duration: 1600
                        easing.type: Easing.OutCubic
                    }
                    // Lingers gracefully before dissolving into the air
                    SequentialAnimation {
                        NumberAnimation {
                            target: fadingContainer
                            property: "opacity"
                            from: 0.78
                            to: 0.65
                            duration: 450
                            easing.type: Easing.Linear
                        }
                        NumberAnimation {
                            target: fadingContainer
                            property: "opacity"
                            from: 0.65
                            to: 0.0
                            duration: 1150
                            easing.type: Easing.OutQuad
                        }
                    }
                }

                ScriptAction {
                    script: {
                        root.fadingLineText = "";
                    }
                }
            }
        }

        // =========================================================================
        // ACTIVE LYRIC LINE: 1-Line only, raised to lap/skirt area (y ≈ 72.5%)
        // Words pop in White -> shift to Vintage Champagne Gold (#deb06c)
        // =========================================================================
        Item {
            id: activeContainer
            x: root.activeX
            y: root.activeY
            width: Math.min(740, Math.round(parent.width * 0.45))
            height: 68

            EnchantingSentence {
                id: activeSentence
                anchors.fill: parent
                text: root.activeLineText
                progress: root.lineProgress
                isActive: root.currentLyricIndex >= 0
                isDead: false
                fontFamily: root.magicFontFamily
                fontSize: 35
                colHighlight: root.colHighlight
            }
        }
    }
}
