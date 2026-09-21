pragma Singleton
import QtQuick

QtObject {
    id: root

    function env(key) {
        if (typeof __NutstyBridge !== "undefined" && __NutstyBridge.getEnv) {
            return __NutstyBridge.getEnv(key);
        }
        return "";
    }

    function execDetached(args) {
        if (typeof __NutstyBridge !== "undefined" && __NutstyBridge.execDetached) {
            return __NutstyBridge.execDetached(args);
        }
    }

    property var screens: Qt.application.screens
}
