import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var downloadTasks: ({}) // videoId -> task object
    property int activeDownloadsCount: 0
    property int batchTotal: 0
    property int batchCompleted: 0
    property var activeQueue: []

    signal taskEnqueued(var task)
    signal taskStarted(var task)
    signal taskProgress(string videoId, real progress, string speed, string eta)
    signal taskCompleted(string videoId, string title, string path)
    signal taskFailed(string videoId, string title, string error)

    function isDownloading(videoId) {
        if (!videoId || !root.downloadTasks) return false;
        var t = root.downloadTasks[videoId];
        return t && (t.state === 1 || t.state === 2);
    }

    function isDownloaded(videoId) {
        if (!videoId || !root.downloadTasks) return false;
        var t = root.downloadTasks[videoId];
        return t && t.state === 3;
    }

    function getProgress(videoId) {
        if (!videoId || !root.downloadTasks) return -1;
        var t = root.downloadTasks[videoId];
        return t ? t.progress : -1;
    }

    function enqueue(trk) {
        if (!trk) return;
        var vid = trk.videoId || "";
        if (!vid && trk.path && trk.path.startsWith("ytdl://")) {
            vid = trk.path.replace("ytdl://", "");
        } else if (!vid && trk.path && trk.path.includes("watch?v=")) {
            var match = trk.path.match(/v=([a-zA-Z0-9_-]+)/);
            if (match) vid = match[1];
        }
        if (!vid) return;

        var title = trk.title || trk.name || "Track";
        var artist = trk.artist || "Artist";
        var thumb = trk.image || "";

        // Immediately reflect in local state for 0ms visual feedback
        var updated = Object.assign({}, root.downloadTasks);
        updated[vid] = {
            videoId: vid,
            title: title,
            artist: artist,
            thumbnail: thumb,
            state: 1, // PREPARING
            progress: 0.0,
            speed: "--",
            eta: "--"
        };
        root.downloadTasks = updated;
        root.activeDownloadsCount++;

        Quickshell.execDetached([
            "python3", win.appDir + "/backend/download_manager.py", "add",
            vid, title, artist, thumb
        ]);
    }

    function cancel(videoId) {
        if (!videoId) return;
        Quickshell.execDetached([
            "python3", win.appDir + "/backend/download_manager.py", "cancel",
            videoId
        ]);
    }

    function handleEvent(line) {
        if (!line || line.trim() === "") return;
        try {
            var data = JSON.parse(line.trim());
            var evt = data.event;

            if (evt === "task_enqueued" || evt === "task_started") {
                var vid = data.videoId;
                var updated = Object.assign({}, root.downloadTasks);
                var existing = updated[vid] || {};
                existing.videoId = vid;
                existing.title = data.title || existing.title || "Track";
                existing.artist = data.artist || existing.artist || "Artist";
                existing.thumbnail = data.thumbnail || existing.thumbnail || "";
                existing.state = 2; // DOWNLOADING
                if (data.progress !== undefined) existing.progress = data.progress;
                updated[vid] = existing;
                root.downloadTasks = updated;
                if (data.active_count !== undefined) root.activeDownloadsCount = data.active_count;
                if (data.batch_total !== undefined) root.batchTotal = data.batch_total;
                root.taskStarted(existing);
            }
            else if (evt === "task_progress") {
                var vid = data.videoId;
                if (root.downloadTasks[vid]) {
                    var updated = Object.assign({}, root.downloadTasks);
                    updated[vid].progress = data.progress;
                    updated[vid].speed = data.speed;
                    updated[vid].eta = data.eta;
                    updated[vid].state = 2;
                    root.downloadTasks = updated;
                    root.taskProgress(vid, data.progress, data.speed, data.eta);
                }
            }
            else if (evt === "task_completed") {
                var vid = data.videoId;
                var updated = Object.assign({}, root.downloadTasks);
                if (updated[vid]) {
                    updated[vid].state = 3; // DOWNLOADED
                    updated[vid].progress = 100.0;
                    updated[vid].path = data.path || "";
                } else {
                    updated[vid] = {
                        videoId: vid,
                        title: data.title,
                        state: 3,
                        progress: 100.0,
                        path: data.path || ""
                    };
                }
                root.downloadTasks = updated;
                if (data.active_count !== undefined) root.activeDownloadsCount = data.active_count;
                root.taskCompleted(vid, data.title || "", data.path || "");
            }
            else if (evt === "task_failed") {
                var vid = data.videoId;
                var updated = Object.assign({}, root.downloadTasks);
                if (updated[vid]) {
                    updated[vid].state = 4; // FAILED
                    updated[vid].error = data.error || "Failed";
                }
                root.downloadTasks = updated;
                if (data.active_count !== undefined) root.activeDownloadsCount = data.active_count;
                root.taskFailed(vid, data.title || "", data.error || "");
            }
            else if (evt === "status_dump") {
                if (data.tasks) {
                    root.downloadTasks = Object.assign({}, data.tasks);
                }
                if (data.active_count !== undefined) {
                    root.activeDownloadsCount = data.active_count;
                }
            }
        } catch(e) {}
    }

    Process {
        id: downloadDaemonProc
        command: ["python3", "-u", win.appDir + "/backend/download_manager.py", "daemon"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.handleEvent(data)
        }
    }
}
