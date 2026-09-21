import QtQuick

Item {
    id: root
    property string path: ""
    signal fileChanged()

    Timer {
        id: pollTimer
        interval: 1000
        repeat: true
        running: root.path !== ""
        property string lastMtime: ""
        onTriggered: {
            if (typeof __NutstyBridge !== "undefined" && __NutstyBridge.checkFileMtime) {
                var m = __NutstyBridge.checkFileMtime(root.path);
                if (m && m !== lastMtime) {
                    if (lastMtime !== "") {
                        root.fileChanged();
                    }
                    lastMtime = m;
                }
            }
        }
    }
}
