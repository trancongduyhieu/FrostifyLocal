pragma Singleton
import QtQuick

QtObject {
    id: root

    // We can load JSON file directly by importing or XMLHttpRequest
    function loadJson(url, callback) {
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200 || xhr.status === 0) {
                    try {
                        var obj = JSON.parse(xhr.responseText);
                        callback(obj);
                    } catch (e) {
                        console.log("JSON parse error:", e);
                    }
                }
            }
        };
        xhr.open("GET", url, true);
        xhr.send();
    }
}
