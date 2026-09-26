pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // =========================================================================
    // 1. CẢ CÂU (Whole Sentence / Line Level)
    // =========================================================================
    property real sentenceActiveY: 0.0          // Độ nâng/hạ cả câu khi active (-10 đến +10 px)
    property real sentenceRestY: 0.0            // Độ dịch cả câu khi inactive (-10 đến +10 px)
    property real sentenceActiveScale: 1.0      // Scale câu khi active (0.90 đến 1.10)
    property real sentenceRestScale: 0.97       // Scale câu khi inactive (0.85 đến 1.00)
    property int sentenceSmoothMs: 250          // Thời gian mượt animation câu (ms) (50 đến 500)

    // =========================================================================
    // 2. TỪNG TỪ (Word-by-Word Wave Ripple - User's Calibrated Preset)
    // =========================================================================
    property real peakLiftY: 0.5                // liftY: 0.5 (User calibrated)
    property real restY: 2.5                    // restY: 2.5 (User calibrated)
    property real peakScale: 1.01               // scale: 1.01 (User calibrated)
    property real glowBlur: 0.55                // glowBlur: 0.55 (User calibrated)
    property real glowOpacity: 0.51             // glowOpacity: 0.51 (User calibrated)
    property int glowMax: 24                    // glowMax: 24
    property int wordSpacing: 8                 // spacing: 8 (User calibrated)
    property real curveExponent: 2.3            // exponent: 2.3 (User calibrated)
    property real leadTime: 0.16                // Thời gian đón đầu sóng (s)
    property int wordSmoothMs: 120              // SmoothedAnimation duration (ms)
    property bool autoScaleWithDur: true        // Tự động chuẩn hóa thời gian animation theo nhịp từ

    // =========================================================================
    // 3. INTERACTIVE TEST & DEMO MODE
    // =========================================================================
    property bool testMode: false               // Bật chế độ chạy câu mẫu test loop
    property real demoTime: 0.0                 // Playhead thời gian
    property real demoSpeed: 1.0                // Tốc độ chạy (0.5x, 1x, 1.5x)
    property bool isPlayingDemo: true           // Tự động chạy timeline demo
    property bool useShortDemo: false           // Toggle: test câu ngắn vs test câu dài

    // Câu dài mẫu: "Wake up in the morning, everything's alright" (nhiều từ)
    readonly property var demoWordsLong: [
        { text: "Wake", start: 0.20, end: 0.65, duration: 0.45, isHeld: false },
        { text: "up", start: 0.65, end: 1.00, duration: 0.35, isHeld: false },
        { text: "in", start: 1.00, end: 1.25, duration: 0.25, isHeld: false },
        { text: "the", start: 1.25, end: 1.55, duration: 0.30, isHeld: false },
        { text: "morning,", start: 1.55, end: 2.65, duration: 1.10, isHeld: true },
        { text: "everything's", start: 2.80, end: 3.75, duration: 0.95, isHeld: false },
        { text: "alright", start: 3.80, end: 5.20, duration: 1.40, isHeld: true }
    ]

    // Câu ngắn mẫu: "And, oh," / "Love me not" (ít từ, kiểm tra xem có bị bay lên không trung không)
    readonly property var demoWordsShort: [
        { text: "And,", start: 0.30, end: 1.80, duration: 1.50, isHeld: true },
        { text: "oh,", start: 1.80, end: 3.60, duration: 1.80, isHeld: true }
    ]

    readonly property var demoWords: useShortDemo ? demoWordsShort : demoWordsLong
    readonly property real demoMaxDuration: useShortDemo ? 4.2 : 5.8

    // =========================================================================
    // 4. AUTO-PERSISTENCE (Lưu & Tải file ~/.config/noctalia/lyric_tuning.json)
    // =========================================================================
    property bool isLoaded: false

    function getExportJson() {
        return JSON.stringify({
            sentenceActiveY: parseFloat(sentenceActiveY.toFixed(2)),
            sentenceRestY: parseFloat(sentenceRestY.toFixed(2)),
            sentenceActiveScale: parseFloat(sentenceActiveScale.toFixed(3)),
            sentenceRestScale: parseFloat(sentenceRestScale.toFixed(3)),
            sentenceSmoothMs: sentenceSmoothMs,
            liftY: parseFloat(peakLiftY.toFixed(2)),
            restY: parseFloat(restY.toFixed(2)),
            scale: parseFloat(peakScale.toFixed(3)),
            glowBlur: parseFloat(glowBlur.toFixed(2)),
            glowOpacity: parseFloat(glowOpacity.toFixed(2)),
            spacing: wordSpacing,
            exponent: parseFloat(curveExponent.toFixed(2)),
            leadTime: parseFloat(leadTime.toFixed(2)),
            wordSmoothMs: wordSmoothMs,
            autoScaleWithDur: autoScaleWithDur
        }, null, 2);
    }

    function saveSettings() {
        if (!isLoaded) return;
        var data = getExportJson();
        Quickshell.execDetached(["python3", "-c",
            "import sys, os\np = os.path.expanduser('~/.config/noctalia/lyric_tuning.json')\nos.makedirs(os.path.dirname(p), exist_ok=True)\nwith open(p, 'w', encoding='utf-8') as f: f.write(sys.argv[1])",
            data
        ]);
    }

    function loadSettings(raw) {
        if (!raw || raw.trim() === "") {
            isLoaded = true;
            return;
        }
        try {
            var obj = JSON.parse(raw);
            if (obj.sentenceActiveY !== undefined) sentenceActiveY = Number(obj.sentenceActiveY);
            if (obj.sentenceRestY !== undefined) sentenceRestY = Number(obj.sentenceRestY);
            if (obj.sentenceActiveScale !== undefined) sentenceActiveScale = Number(obj.sentenceActiveScale);
            if (obj.sentenceRestScale !== undefined) sentenceRestScale = Number(obj.sentenceRestScale);
            if (obj.sentenceSmoothMs !== undefined) sentenceSmoothMs = Number(obj.sentenceSmoothMs);

            if (obj.liftY !== undefined) peakLiftY = Number(obj.liftY);
            else if (obj.peakLiftY !== undefined) peakLiftY = Number(obj.peakLiftY);

            if (obj.restY !== undefined) restY = Number(obj.restY);
            if (obj.scale !== undefined) peakScale = Number(obj.scale);
            else if (obj.peakScale !== undefined) peakScale = Number(obj.peakScale);

            if (obj.glowBlur !== undefined) glowBlur = Number(obj.glowBlur);
            if (obj.glowOpacity !== undefined) glowOpacity = Number(obj.glowOpacity);
            if (obj.spacing !== undefined) wordSpacing = Number(obj.spacing);
            else if (obj.wordSpacing !== undefined) wordSpacing = Number(obj.wordSpacing);

            if (obj.exponent !== undefined) curveExponent = Number(obj.exponent);
            else if (obj.curveExponent !== undefined) curveExponent = Number(obj.curveExponent);

            if (obj.leadTime !== undefined) leadTime = Number(obj.leadTime);
            if (obj.wordSmoothMs !== undefined) wordSmoothMs = Number(obj.wordSmoothMs);
            if (obj.autoScaleWithDur !== undefined) autoScaleWithDur = !!obj.autoScaleWithDur;
        } catch(e) {
            console.log("DEBUG LyricTuningState load error:", e);
        }
        isLoaded = true;
    }

    function resetDefaults() {
        sentenceActiveY = 0.0;
        sentenceRestY = 0.0;
        sentenceActiveScale = 1.0;
        sentenceRestScale = 0.97;
        sentenceSmoothMs = 250;

        peakLiftY = 0.5;
        restY = 2.5;
        peakScale = 1.01;
        glowBlur = 0.55;
        glowOpacity = 0.51;
        glowMax = 24;
        wordSpacing = 8;
        curveExponent = 2.3;
        leadTime = 0.16;
        wordSmoothMs = 120;
        autoScaleWithDur = true;
        saveSettings();
    }

    // Tự động đọc file cấu hình khi khởi động
    property var tuningFileView: FileView {
        path: Quickshell.env("HOME") + "/.config/noctalia/lyric_tuning.json"
        watchChanges: true
        onFileChanged: {
            reload();
            if (loaded) root.loadSettings(text());
        }
        onLoadedChanged: {
            if (loaded) root.loadSettings(text());
        }
        Component.onCompleted: {
            if (loaded) root.loadSettings(text());
        }
    }

    // Demo Timeline Timer
    property var demoTimer: Timer {
        interval: 16
        running: root.testMode && root.isPlayingDemo
        repeat: true
        onTriggered: {
            var step = (interval / 1000.0) * root.demoSpeed;
            root.demoTime += step;
            if (root.demoTime > root.demoMaxDuration) {
                root.demoTime = 0.0;
            }
        }
    }
}
