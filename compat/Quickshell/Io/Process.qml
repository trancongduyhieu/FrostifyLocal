import QtQuick

Item {
    id: root
    property var command: []
    property bool running: false
    property var stdout: null
    property var stderr: null

    signal exited(int code, int status)

    onRunningChanged: {
        if (running) {
            if (typeof __NutstyBridge !== "undefined" && __NutstyBridge.runProcess) {
                var cmdCopy = root.command;
                __NutstyBridge.runProcess(cmdCopy, function(outData, errData, exitCode) {
                    if (outData && root.stdout) {
                        if (typeof root.stdout.feed === "function") {
                            root.stdout.feed(outData);
                            if (typeof root.stdout.flush === "function") {
                                root.stdout.flush();
                            }
                        } else if (typeof root.stdout.read === "function") {
                            root.stdout.read(outData);
                        }
                    }
                    root.running = false;
                    root.exited(exitCode || 0, 0);
                });
            } else {
                root.running = false;
            }
        }
    }

    function write(data) {
        // Can bridge to stdin if needed
    }
}
