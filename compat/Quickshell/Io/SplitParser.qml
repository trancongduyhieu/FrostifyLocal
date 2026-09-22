import QtQuick

QtObject {
    id: root
    property string splitMarker: "\n"
    property string _buffer: ""
    signal read(string data)

    function feed(chunk) {
        if (!chunk) return;
        _buffer += chunk;
        var lines = _buffer.split(splitMarker);
        // The last element is the unfinished line fragment (or empty string if chunk ended with splitMarker)
        _buffer = lines.pop() || "";
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i];
            if (line.length > 0) {
                root.read(line);
            }
        }
    }

    function flush() {
        if (_buffer.length > 0) {
            var remaining = _buffer;
            _buffer = "";
            root.read(remaining);
        }
    }
}
