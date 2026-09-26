import QtQuick
import QtQuick.Effects
import "."

Item {
    id: root

    property var words: []
    property real currentTime: 0.0
    property bool isLineActive: false
    property int fontSize: 28
    property string fontFamily: Theme.fontFamily
    property int fontWeight: Font.Bold
    property color accentColor: Theme.accent
    property int wordSpacing: 8

    // Tuned Apple Music Wave Constants (Calibrated & Verified):
    // peakLiftY: 1.6 (dynamic amplitude swing <= 2.0px), scale: 1.01, glowBlur: 0.55, glowOpacity: 0.51, spacing: 8, exponent: 2.0
    readonly property real peakLiftY: 1.6
    readonly property real peakScale: 1.01
    readonly property real glowBlurVal: 0.55
    readonly property real glowOpacityVal: 0.51
    readonly property int glowMaxVal: 24
    readonly property real curveExponent: 2.0

    implicitWidth: parent ? parent.width : 300
    implicitHeight: wordsFlow.implicitHeight + 8

    Flow {
        id: wordsFlow
        y: 4
        width: root.width
        spacing: root.wordSpacing

        Repeater {
            model: root.words || []

            delegate: Item {
                id: wordContainer
                width: wordTxt.implicitWidth
                height: wordTxt.implicitHeight

                // Inner animated item to isolate transforms and NEVER touch Flow's positioner
                Item {
                    id: wordVisual
                    anchors.fill: parent
                    transformOrigin: Item.Bottom

                    readonly property real wStart: modelData.start
                    readonly property real wEnd: modelData.end
                    readonly property real wDur: Math.max(0.08, modelData.duration || (wEnd - wStart))
                    readonly property bool isHeld: modelData.isHeld || false
                    readonly property bool isPast: root.currentTime >= wEnd
                    readonly property bool isSinging: root.currentTime >= wStart && root.currentTime < wEnd
                    readonly property real wordProgress: isSinging ? Math.max(0.0, Math.min(1.0, (root.currentTime - wStart) / wDur)) : 0.0

                    // Phrase boundary detection (dấu phẩy, dấu câu hoặc khoảng nghỉ > 0.35s)
                    readonly property bool isPhraseStart: {
                        if (index === 0) return true;
                        var prev = root.words[index - 1];
                        if (!prev) return true;
                        var prevText = prev.text || "";
                        if (/[,\.\?!;—\-]/.test(prevText.trim())) return true;
                        if (modelData.start - (prev.end || modelData.start) > 0.35) return true;
                        return false;
                    }

                    // Continuous wave lead: words within the same phrase anticipate the traveling crest
                    readonly property real leadTime: isPhraseStart
                        ? Math.min(0.10, Math.max(0.04, (index > 0 ? (modelData.start - root.words[index - 1].end) * 0.4 : 0.08)))
                        : 0.16

                    readonly property real waveStart: wStart - leadTime
                    readonly property real waveTotal: wDur + leadTime
                    readonly property bool isWaveActive: !isPast && (root.currentTime >= waveStart)
                    readonly property real waveProgressTotal: isWaveActive
                        ? Math.max(0.0, Math.min(1.0, (root.currentTime - waveStart) / Math.max(0.08, waveTotal)))
                        : 0.0

                    readonly property bool isApproaching: !isSinging && !isPast && (root.currentTime >= waveStart) && (root.currentTime < wStart)
                    readonly property real preProgress: isApproaching ? Math.max(0.0, Math.min(1.0, (root.currentTime - waveStart) / leadTime)) : 0.0

                    // Held note envelope (smooth rise, sustained crest during hold, soft release)
                    readonly property real heldEnv: {
                        if (!isSinging) return 0.0;
                        var tFromStart = root.currentTime - wStart;
                        var tToEnd = wEnd - root.currentTime;
                        var rise = Math.min(1.0, Math.max(0.0, tFromStart / Math.min(0.25, wDur * 0.3)));
                        var rel = Math.min(1.0, Math.max(0.0, tToEnd / Math.min(0.25, wDur * 0.3)));
                        return Math.min(rise, rel);
                    }

                    // Phosphor glow envelope: luminous bloom during active singing and sustained in held notes
                    readonly property real glowEnv: {
                        if (!isSinging) return 0.0;
                        if (isHeld) {
                            return Math.pow(Math.sin(Math.PI * 0.5 * heldEnv), 1.2);
                        }
                        return Math.pow(Math.sin(Math.PI * wordProgress), 1.3);
                    }

                    // Apple Music Phrase Traveling Wave (Silky Smooth Spring Damped):
                    // - Resting baseline: 0.0px for ALL words (no trenches, no stepped cliffs)
                    // - Wave elevation: rises from 0.0px up to -peakLiftY (-1.6px) and gently lowers back to 0.0px
                    // - Total vertical dynamic swing: 1.6px (capped <= 2.0px)
                    readonly property real waveY: {
                        if (isPast || !isWaveActive) return 0.0;
                        if (isHeld) {
                            return -root.peakLiftY * Math.pow(Math.sin(Math.PI * 0.5 * heldEnv), root.curveExponent);
                        }
                        return -root.peakLiftY * Math.pow(Math.sin(Math.PI * waveProgressTotal), root.curveExponent);
                    }

                    readonly property real waveScale: {
                        if (isSinging) {
                            if (isHeld) {
                                return 1.0 + (root.peakScale - 1.0) * heldEnv;
                            }
                            return 1.0 + (root.peakScale - 1.0) * Math.sin(Math.PI * wordProgress);
                        }
                        if (isApproaching) {
                            return 1.0 + (root.peakScale - 1.0) * 0.3 * Math.sin(Math.PI * 0.5 * preProgress);
                        }
                        return 1.0;
                    }

                    transform: Translate {
                        id: wordTranslate
                        y: wordVisual.waveY
                        Behavior on y {
                            SmoothedAnimation {
                                duration: 150
                                reversingMode: SmoothedAnimation.Immediate
                            }
                        }
                    }
                    scale: wordVisual.waveScale
                    Behavior on scale {
                        SmoothedAnimation {
                            duration: 150
                            reversingMode: SmoothedAnimation.Immediate
                        }
                    }

                    // Phosphor Bloom Glow Layer for Held Notes & Active Words
                    Text {
                        id: glowTxt
                        anchors.centerIn: parent
                        text: modelData.text || ""
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize
                        font.weight: root.fontWeight
                        color: "#ffffff"
                        visible: wordVisual.isSinging && (wordVisual.isHeld || root.glowOpacityVal > 0.05)
                        opacity: wordVisual.glowEnv * root.glowOpacityVal
                        layer.enabled: visible
                        layer.smooth: true
                        layer.effect: MultiEffect {
                            blurEnabled: true
                            blur: root.glowBlurVal
                            blurMax: root.glowMaxVal
                        }
                    }

                    // Main Crisp Text Layer
                    Text {
                        id: wordTxt
                        anchors.centerIn: parent
                        text: modelData.text || ""
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize
                        font.weight: root.fontWeight
                        color: {
                            if (wordVisual.isPast) return "#ffffff";
                            if (wordVisual.isSinging) {
                                if (wordVisual.isHeld) return "#ffffff";
                                // Dynamic illumination from dimmed gray to pure white
                                var frac = wordVisual.wordProgress;
                                var r = Math.round(180 + (255 - 180) * frac);
                                var g = Math.round(185 + (255 - 185) * frac);
                                var b = Math.round(198 + (255 - 198) * frac);
                                return "#" + ((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1);
                            }
                            if (wordVisual.isApproaching) {
                                var pf = wordVisual.preProgress;
                                var pr = Math.round(138 + (180 - 138) * pf);
                                var pg = Math.round(144 + (185 - 144) * pf);
                                var pb = Math.round(162 + (198 - 162) * pf);
                                return "#" + ((1 << 24) + (pr << 16) + (pg << 8) + pb).toString(16).slice(1);
                            }
                            // Unsung: dimmed elegant translucent gray
                            return "#8a90a2";
                        }
                    }
                }
            }
        }
    }
}
