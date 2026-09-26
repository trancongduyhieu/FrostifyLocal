import QtQuick
import "."

// Apple Music Word-by-Word Flow Engine — AMLL-accurate physics & Soft Phosphor Bloom
// Spec source: amll-dev/applemusic-like-lyrics & Apple Music reference captures
//   • scale:        1.0 + 0.01 × sin(π × progress) → peak 1.010x (held: 1.020x with soft release)
//   • liftY:       -1.2 × sin(π × progress) px (held: -0.8px with soft release)
//   • Held notes:   Soft Phosphor Bloom (Gaussian Blur + Drop Shadow aura, ZERO Text.Outline)
//   • Release Wipe: When sustained note nears end, bloom sweeps off LEFT-TO-RIGHT via Scissor Clipper
//   • Overlap:      hasActiveHeldWord keeps prev line visible while sustained note continues to glow

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

    // Compensate for 80ms audio buffer latency so words light up on-beat
    readonly property real effectiveTime: root.currentTime + 0.08
    readonly property var effectiveWords: root.words || []

    // Expose for parent delegate: if any held word is still in its duration window
    // (including the left-to-right wipe decay phase), keep loader visible.
    readonly property bool hasActiveHeldWord: {
        var ws = root.effectiveWords;
        for (var i = 0; i < ws.length; i++) {
            var w = ws[i];
            var dur = (w.duration || (w.end - w.start)) || 0;
            if ((w.isHeld || dur >= 0.85) && root.effectiveTime >= w.start && root.effectiveTime < (w.end + 0.08)) {
                return true;
            }
        }
        return false;
    }

    implicitWidth: parent ? parent.width : 300
    implicitHeight: wordsFlow.implicitHeight + 8

    Flow {
        id: wordsFlow
        y: 4
        width: root.width
        spacing: root.wordSpacing

        Repeater {
            model: root.effectiveWords

            delegate: Item {
                id: wordContainer
                width: baseWordTxt.implicitWidth
                height: baseWordTxt.implicitHeight

                Item {
                    id: wordVisual
                    anchors.fill: parent
                    transformOrigin: Item.Center

                    readonly property real wStart: modelData.start
                    readonly property real wEnd: modelData.end
                    readonly property real wDur: Math.max(0.08, modelData.duration || (wEnd - wStart))
                    readonly property bool isHeld: modelData.isHeld || (wDur >= 0.85)
                    readonly property bool isPast: root.effectiveTime >= wEnd
                    readonly property bool isSinging: root.effectiveTime >= wStart && root.effectiveTime < wEnd

                    // Held-note linear progress 0→1 over duration
                    readonly property real heldProgress: isSinging
                        ? Math.max(0.0, Math.min(1.0, (root.effectiveTime - wStart) / wDur))
                        : (isPast ? 1.0 : 0.0)

                    // ── Left-to-Right Wipe Decay Calculation ──────────────────────────
                    // Takes place in the final ~28% (0.28s - 0.50s) of the sustained note.
                    // wipeProgress: 0.0 (full glow across whole word) → 1.0 (glow completely swept off to the right).
                    readonly property real wipeDuration: Math.min(0.50, Math.max(0.28, wDur * 0.28))
                    readonly property real wipeStartTime: wEnd - wipeDuration
                    readonly property real wipeProgress: {
                        if (!isHeld) return 0.0;
                        if (root.effectiveTime < wipeStartTime) return 0.0;
                        if (root.effectiveTime >= wEnd) return 1.0;
                        return Math.max(0.0, Math.min(1.0, (root.effectiveTime - wipeStartTime) / wipeDuration));
                    }

                    // Glow remains active while singing and wipe has not yet completed
                    readonly property bool isGlowActive: isHeld && (isSinging || (root.effectiveTime >= wEnd && root.effectiveTime < (wEnd + 0.08))) && (wipeProgress < 1.0)

                    // Smoothed progress for C¹ continuity on normal words
                    property real wordProgress: 0.0
                    Behavior on wordProgress {
                        SmoothedAnimation {
                            duration: 160
                            reversingMode: SmoothedAnimation.Immediate
                        }
                    }
                    readonly property real rawProgress: isPast ? 1.0 : (isSinging ? Math.max(0.0, Math.min(1.0, (root.effectiveTime - wStart) / wDur)) : 0.0)
                    onRawProgressChanged: wordProgress = rawProgress

                    // Anticipation within 0.12s before singing
                    readonly property bool isApproaching: !isSinging && !isPast && (root.effectiveTime >= wStart - 0.12)

                    // ── Apple Music Wave Lift ─────────────────────────────────────────
                    // Held notes lift -0.8px smoothly, then gracefully settle back to 0px as wipe completes
                    transform: Translate {
                        y: wordVisual.isHeld
                            ? -0.8 * Math.min(wordVisual.heldProgress * 2.0, 1.0) * (1.0 - wordVisual.wipeProgress)
                            : -1.2 * Math.sin(Math.PI * wordVisual.wordProgress)
                    }

                    // ── Micro Scale Breath ────────────────────────────────────────────
                    // Held notes expand +2.0%, then softly converge back to 1.0x as wipe completes
                    scale: wordVisual.isHeld
                        ? (1.0 + 0.020 * Math.min(wordVisual.heldProgress * 2.5, 1.0) * (1.0 - wordVisual.wipeProgress))
                        : (1.0 + 0.010 * Math.sin(Math.PI * wordVisual.wordProgress))

                    // ── 1. Soft Phosphor Bloom Glow Layer (Behind Main Text) ─────────
                    // Pure vector-glyph bloom: zero MultiEffect FBO bounding box artifacts.
                    // Stays tightly bounded within 4-6px of the glyph outline (Apple Music spec),
                    // never spilling over adjacent words or creating rectangular halos.
                    // Left-to-Right Wipe Decay: When sustained note nears end, bloom sweeps off
                    // smoothly from left to right via Scissor Clipper.
                    Item {
                        id: heldBloomContainer
                        anchors.fill: parent
                        visible: wordVisual.isGlowActive

                        // Wipe progress: 0.0 (full glow) → 1.0 (swept completely off to the right)
                        readonly property real currentWipe: wordVisual.wipeProgress

                        // Base glow intensity: fast ramp-up in first 20% of duration, then holds bright
                        readonly property real baseIntensity: {
                            var ramp = Math.min(wordVisual.heldProgress * 5.0, 1.0);
                            return 0.95 * ramp * (1.0 - currentWipe * 0.4);
                        }

                        // Scissor Clipper sweeping left-to-right
                        Item {
                            id: wipeClipper
                            x: heldBloomContainer.currentWipe * wordContainer.width
                            y: -8
                            width: Math.max(0, wordContainer.width - x + 8)
                            height: wordContainer.height + 16
                            clip: true

                            // Inside clipper: counter-offset so glow glyphs align 100% with base text
                            Item {
                                x: -wipeClipper.x
                                y: -wipeClipper.y
                                width: wordContainer.width
                                height: wordContainer.height

                                // Layer 3 (Outer soft halo ~5px)
                                Text {
                                    anchors.centerIn: parent
                                    anchors.horizontalCenterOffset: -4
                                    text: modelData.text || ""
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize
                                    font.weight: root.fontWeight
                                    color: "#ffffff"
                                    opacity: 0.08 * heldBloomContainer.baseIntensity
                                }
                                Text {
                                    anchors.centerIn: parent
                                    anchors.horizontalCenterOffset: 4
                                    text: modelData.text || ""
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize
                                    font.weight: root.fontWeight
                                    color: "#ffffff"
                                    opacity: 0.08 * heldBloomContainer.baseIntensity
                                }
                                Text {
                                    anchors.centerIn: parent
                                    anchors.verticalCenterOffset: -4
                                    text: modelData.text || ""
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize
                                    font.weight: root.fontWeight
                                    color: "#ffffff"
                                    opacity: 0.08 * heldBloomContainer.baseIntensity
                                }
                                Text {
                                    anchors.centerIn: parent
                                    anchors.verticalCenterOffset: 4
                                    text: modelData.text || ""
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize
                                    font.weight: root.fontWeight
                                    color: "#ffffff"
                                    opacity: 0.08 * heldBloomContainer.baseIntensity
                                }

                                // Layer 2 (Mid aura ~3px)
                                Text {
                                    anchors.centerIn: parent
                                    anchors.horizontalCenterOffset: -2.5
                                    anchors.verticalCenterOffset: -2.5
                                    text: modelData.text || ""
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize
                                    font.weight: root.fontWeight
                                    color: "#ffffff"
                                    opacity: 0.16 * heldBloomContainer.baseIntensity
                                }
                                Text {
                                    anchors.centerIn: parent
                                    anchors.horizontalCenterOffset: 2.5
                                    anchors.verticalCenterOffset: -2.5
                                    text: modelData.text || ""
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize
                                    font.weight: root.fontWeight
                                    color: "#ffffff"
                                    opacity: 0.16 * heldBloomContainer.baseIntensity
                                }
                                Text {
                                    anchors.centerIn: parent
                                    anchors.horizontalCenterOffset: -2.5
                                    anchors.verticalCenterOffset: 2.5
                                    text: modelData.text || ""
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize
                                    font.weight: root.fontWeight
                                    color: "#ffffff"
                                    opacity: 0.16 * heldBloomContainer.baseIntensity
                                }
                                Text {
                                    anchors.centerIn: parent
                                    anchors.horizontalCenterOffset: 2.5
                                    anchors.verticalCenterOffset: 2.5
                                    text: modelData.text || ""
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize
                                    font.weight: root.fontWeight
                                    color: "#ffffff"
                                    opacity: 0.16 * heldBloomContainer.baseIntensity
                                }

                                // Layer 1 (Tight core bloom ~1.5px)
                                Text {
                                    anchors.centerIn: parent
                                    anchors.horizontalCenterOffset: -1.5
                                    text: modelData.text || ""
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize
                                    font.weight: root.fontWeight
                                    color: "#ffffff"
                                    opacity: 0.28 * heldBloomContainer.baseIntensity
                                }
                                Text {
                                    anchors.centerIn: parent
                                    anchors.horizontalCenterOffset: 1.5
                                    text: modelData.text || ""
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize
                                    font.weight: root.fontWeight
                                    color: "#ffffff"
                                    opacity: 0.28 * heldBloomContainer.baseIntensity
                                }
                                Text {
                                    anchors.centerIn: parent
                                    anchors.verticalCenterOffset: -1.5
                                    text: modelData.text || ""
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize
                                    font.weight: root.fontWeight
                                    color: "#ffffff"
                                    opacity: 0.28 * heldBloomContainer.baseIntensity
                                }
                                Text {
                                    anchors.centerIn: parent
                                    anchors.verticalCenterOffset: 1.5
                                    text: modelData.text || ""
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize
                                    font.weight: root.fontWeight
                                    color: "#ffffff"
                                    opacity: 0.28 * heldBloomContainer.baseIntensity
                                }
                            }
                        }
                    }

                    // ── 2. Main Crisp Typography (In Front of Bloom) ──────────────────
                    // Renders ON TOP of the bloom aura for razor-sharp legibility.
                    // Luminance jump dim (#757a88) → bright (#ffffff) carries word-by-word timing.
                    Text {
                        id: baseWordTxt
                        anchors.centerIn: parent
                        text: modelData.text || ""
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize
                        font.weight: root.fontWeight
                        color: {
                            if (wordVisual.isPast || wordVisual.isSinging) return "#ffffff";
                            if (wordVisual.isApproaching) return "#9ba1b2";
                            return "#757a88"; // Dim muted slate — AMLL dark-mask-alpha ~0.3
                        }
                        Behavior on color { ColorAnimation { duration: 80 } }
                    }
                }
            }
        }
    }
}

