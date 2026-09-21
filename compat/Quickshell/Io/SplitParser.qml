import QtQuick

QtObject {
    id: root
    property string splitMarker: "\n"
    signal read(string data)

    function feed(chunk) {
        if (!chunk) return;
        var lines = chunk.split(splitMarker);
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i];
            if (line.length > 0) {
                root.read(line);
            }
        }
    }
}
