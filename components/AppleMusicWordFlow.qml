import QtQuick
import "."

// Apple Music Word-by-Word Flow Engine — AMLL-accurate physics
// Spec source: amll-dev/applemusic-like-lyrics
//   • scale:      1.0 + 0.01 × sin(π × progress) → peak 1.010x  (AMLL: ≤1.015x)
//   • liftY:     -1.2 × sin(π × progress) px       (AMLL: -0.05em ≈ -1.4px on 28px)
//   • Held notes: bloom opacity held at FULL while currentTime in [word.start, word.end]
//                 → "Oh" glows at peak the entire duration, even while next line plays
//   • SmoothedAnimation: duration 160ms, reversingMode Immediate → C¹ velocity continuity
//   • Footgun: NEVER set x/y directly on Flow children — use transform: Translate { y: }
//   • Footgun: NEVER use MultiEffect inside Repeater — GPU offscreen pass per word = killer

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

    // Expose for parent delegate: if any held word is still in its duration window,
    // the parent should keep this loader visible even when the line is no longer "current".
    // This enables the held-note-overlap behavior: Oh (34→38s) stays glowing while
    // I'm blinded... (36→40s) starts playing on the NEXT line simultaneously.
    readonly property bool hasActiveHeldWord: {
        var ws = root.effectiveWords;
        for (var i = 0; i < ws.length; i++) {
            var w = ws[i];
            var dur = (w.duration || (w.end - w.start)) || 0;
            if ((w.isHeld || dur >= 0.85) && root.effectiveTime >= w.start && root.effectiveTime < w.end) {
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
                    readonly property real rawProgress: isPast ? 1.0 : (isSinging ? Math.max(0.0, Math.min(1.0, (root.effectiveTime - wStart) / wDur)) : 0.0)

                    // Held-note progress: linear 0→1 over the word's full duration.
                    // Used for the "breathing sustain glow" that grows and holds bright,
                    // rather than the sin-bell that fades mid-word.
                    readonly property real heldProgress: isSinging
                        ? Math.max(0.0, Math.min(1.0, (root.effectiveTime - wStart) / wDur))
                        : (isPast ? 1.0 : 0.0)

                    // Smoothed progress for C¹ continuity — eliminates snap/jump on boundary transitions
                    property real wordProgress: 0.0
                    Behavior on wordProgress {
                        SmoothedAnimation {
                            duration: 160
                            reversingMode: SmoothedAnimation.Immediate
                        }
                    }
                    // Bind rawProgress → wordProgress via SmoothedAnimation
                    onRawProgressChanged: wordProgress = rawProgress

                    // Anticipation within 0.12s before singing
                    readonly property bool isApproaching: !isSinging && !isPast && (root.effectiveTime >= wStart - 0.12)

                    // ── Apple Music Wave Lift ─────────────────────────────────────────
                    // -1.2px at sin-peak (mid-word), returns smoothly to 0px at end.
                    // Translate keeps the Flow positioner layout untouched (Footgun #1 safe).
                    // AMLL ref: float/index.ts → y = -0.05em on 28px = ~-1.4px
                    // Held notes: clamp lift to a gentle -0.8px to avoid layout thrash at long sustain
                    transform: Translate {
                        y: wordVisual.isHeld
                            ? -0.8 * Math.min(wordVisual.heldProgress * 2.0, 1.0) // fast ramp to peak, holds flat
                            : -1.2 * Math.sin(Math.PI * wordVisual.wordProgress)
                    }

                    // ── Micro Scale Breath ────────────────────────────────────────────
                    // Peak: 1.010x (held notes: 1.013x) — luminance contrast carries perception,
                    // not geometric expansion. Keeps adjacent glyphs from being crowded.
                    // Held notes: ramp to peak quickly then hold, not a bell curve.
                    // AMLL ref: emphasize/index.ts → 1 + 0.1 × amount, amount ≤ 0.1 → ≤1.01×
                    scale: wordVisual.isHeld
                        ? (1.0 + 0.013 * Math.min(wordVisual.heldProgress * 2.5, 1.0))
                        : (1.0 + 0.010 * Math.sin(Math.PI * wordVisual.wordProgress))

                    // ── 1. Phosphor Bloom Glow Layer ──────────────────────────────────
                    // For NORMAL words: sin-bell → blooms at mid-word, fades at endpoints.
                    // For HELD notes:   ramp-and-hold → grows quickly to ~0.50 then stays
                    //   bright the ENTIRE duration (Oh 34s→38s stays glowing), fades only
                    //   AFTER word.end is crossed. This matches AMLL's held-note luminance
                    //   behavior where sustained notes maintain full mask-alpha throughout.
                    // Native Text.Outline (zero extra GPU pass vs MultiEffect in Repeater).
                    Text {
                        id: bloomGlowTxt
                        anchors.centerIn: parent
                        text: modelData.text || ""
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize
                        font.weight: root.fontWeight
                        color: "#ffffff"
                        style: Text.Outline
                        // Held: peak at 0.55 (slightly brighter than normal 0.50 to feel "sustained")
                        // Normal: sin-bell exactly as before
                        styleColor: wordVisual.isHeld
                            ? Qt.rgba(1.0, 1.0, 1.0, 0.42)
                            : Qt.rgba(1.0, 1.0, 1.0, 0.38)
                        opacity: {
                            if (wordVisual.isHeld) {
                                if (!wordVisual.isSinging) return 0.0;
                                // Ramp up fast (0→0.55 in first 30% of duration), then hold flat at 0.55
                                var ramp = Math.min(wordVisual.heldProgress * 3.0, 1.0);
                                return 0.55 * ramp;
                            } else {
                                // Normal: sin-bell fades in and out symmetrically
                                return wordVisual.isSinging
                                    ? (0.50 * Math.sin(Math.PI * wordVisual.wordProgress))
                                    : 0.0;
                            }
                        }
                        Behavior on opacity { NumberAnimation { duration: wordVisual.isHeld ? 220 : 80 } }
                        visible: opacity > 0.005
                    }

                    // ── 2. Main Crisp Typography ──────────────────────────────────────
                    // Luminance jump dim→bright is the PRIMARY perceptual "karaoke" cue.
                    // AMLL: dark-mask-alpha 0.2→0.4 (dim), bright-mask-alpha 1.0 (active).
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
