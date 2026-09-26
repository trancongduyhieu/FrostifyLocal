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
    property int wordSpacing: LyricTuningState.wordSpacing

    readonly property real effectiveTime: LyricTuningState.testMode ? LyricTuningState.demoTime : root.currentTime
    readonly property var effectiveWords: (LyricTuningState.testMode && LyricTuningState.demoWords) ? LyricTuningState.demoWords : (root.words || [])

    implicitWidth: parent ? parent.width : 300
    implicitHeight: wordsFlow.implicitHeight + 8

    Flow {
        id: wordsFlow
        y: 4
        width: root.width
        spacing: LyricTuningState.wordSpacing

        Repeater {
            model: root.effectiveWords

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
                    readonly property bool isPast: root.effectiveTime >= wEnd
                    readonly property bool isSinging: root.effectiveTime >= wStart && root.effectiveTime < wEnd
                    readonly property real wordProgress: isSinging ? Math.max(0.0, Math.min(1.0, (root.effectiveTime - wStart) / wDur)) : 0.0

                    // Phrase boundary detection (dấu phẩy, dấu câu hoặc khoảng nghỉ > 0.35s)
                    readonly property bool isPhraseStart: {
                        if (index === 0) return true;
                        var prev = root.effectiveWords[index - 1];
                        if (!prev) return true;
                        var prevText = prev.text || "";
                        if (/[,\.\?!;—\-]/.test(prevText.trim())) return true;
                        if (modelData.start - (prev.end || modelData.start) > 0.35) return true;
                        return false;
                    }

                    // Continuous wave lead: words within the same phrase anticipate the traveling crest
                    readonly property real leadTime: isPhraseStart
                        ? Math.min(LyricTuningState.leadTime * 0.6, Math.max(0.04, (index > 0 ? (modelData.start - root.effectiveWords[index - 1].end) * 0.4 : 0.06)))
                        : LyricTuningState.leadTime

                    readonly property real waveStart: wStart - leadTime
                    readonly property real waveTotal: wDur + leadTime
                    readonly property bool isWaveActive: !isPast && (root.effectiveTime >= waveStart)
                    readonly property real waveProgressTotal: isWaveActive
                        ? Math.max(0.0, Math.min(1.0, (root.effectiveTime - waveStart) / Math.max(0.08, waveTotal)))
                        : 0.0

                    readonly property bool isApproaching: !isSinging && !isPast && (root.effectiveTime >= waveStart) && (root.effectiveTime < wStart)
                    readonly property real preProgress: isApproaching ? Math.max(0.0, Math.min(1.0, (root.effectiveTime - waveStart) / leadTime)) : 0.0

                    // Normalized animation duration: scale with word duration to ensure BOTH short words and long words
                    // hit 100% of peak amplitude without cutting off or overstaying
                    readonly property int dynamicAnimMs: LyricTuningState.autoScaleWithDur
                        ? Math.min(LyricTuningState.wordSmoothMs, Math.max(45, Math.round(wDur * 400)))
                        : LyricTuningState.wordSmoothMs

                    // Held note envelope (smooth rise, sustained crest during hold, soft release)
                    readonly property real heldEnv: {
                        if (!isSinging) return 0.0;
                        var tFromStart = root.effectiveTime - wStart;
                        var tToEnd = wEnd - root.effectiveTime;
                        var riseTime = Math.min(0.25, wDur * 0.25);
                        var relTime = Math.min(0.25, wDur * 0.25);
                        var rise = Math.min(1.0, Math.max(0.0, tFromStart / Math.max(0.05, riseTime)));
                        var rel = Math.min(1.0, Math.max(0.0, tToEnd / Math.max(0.05, relTime)));
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

                    // Apple Music Live Tunable Wave Equation:
                    // - Unsung: rests at restY (+px) or pre-lifts as wave crest approaches
                    // - Singing: elevates smoothly towards peakLiftY (-px) at crest center, then settles to 0.0px
                    // - Sung: cleanly settles at standard baseline 0.0px
                    readonly property real waveY: {
                        if (isPast) return 0.0;
                        if (isSinging) {
                            if (isHeld) {
                                var baseHeld = LyricTuningState.restY * (1.0 - heldEnv);
                                var liftHeld = -LyricTuningState.peakLiftY * Math.pow(Math.sin(Math.PI * 0.5 * heldEnv), LyricTuningState.curveExponent);
                                return baseHeld + liftHeld;
                            }
                            var base = LyricTuningState.restY * (1.0 - wordProgress);
                            var lift = -LyricTuningState.peakLiftY * Math.pow(Math.sin(Math.PI * wordProgress), LyricTuningState.curveExponent);
                            return base + lift;
                        }
                        if (isApproaching) {
                            return LyricTuningState.restY * (1.0 - 0.5 * Math.sin(Math.PI * 0.5 * preProgress));
                        }
                        return LyricTuningState.restY;
                    }

                    readonly property real waveScale: {
                        if (isSinging) {
                            if (isHeld) {
                                return 1.0 + (LyricTuningState.peakScale - 1.0) * heldEnv;
                            }
                            return 1.0 + (LyricTuningState.peakScale - 1.0) * Math.sin(Math.PI * wordProgress);
                        }
                        if (isApproaching) {
                            return 1.0 + (LyricTuningState.peakScale - 1.0) * 0.3 * Math.sin(Math.PI * 0.5 * preProgress);
                        }
                        return 1.0;
                    }

                    transform: Translate {
                        id: wordTranslate
                        y: wordVisual.waveY
                        Behavior on y {
                            enabled: LyricTuningState.wordSmoothMs > 0
                            SmoothedAnimation {
                                duration: wordVisual.dynamicAnimMs
                                reversingMode: SmoothedAnimation.Immediate
                            }
                        }
                    }
                    scale: wordVisual.waveScale
                    Behavior on scale {
                        enabled: LyricTuningState.wordSmoothMs > 0
                        SmoothedAnimation {
                            duration: wordVisual.dynamicAnimMs
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
                        visible: wordVisual.isSinging && (wordVisual.isHeld || LyricTuningState.glowOpacity > 0.05)
                        opacity: wordVisual.glowEnv * LyricTuningState.glowOpacity
                        layer.enabled: visible
                        layer.smooth: true
                        layer.effect: MultiEffect {
                            blurEnabled: true
                            blur: LyricTuningState.glowBlur
                            blurMax: LyricTuningState.glowMax
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
