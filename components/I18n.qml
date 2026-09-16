pragma Singleton
import QtQuick
import Quickshell

QtObject {
    id: i18n

    // Active Language Locale: "vi" (Tiếng Việt) | "en" (English)
    property string locale: "vi"
    readonly property bool isVietnamese: locale === "vi"

    // Primary Inline Pair Translation Helper
    // Guarantees effortless bimodal translations right where the text is declared:
    // text: I18n.tr("Cài đặt", "Settings")
    function tr(viText, enText) {
        return locale === "vi" ? (viText !== undefined ? viText : "") : (enText !== undefined ? enText : viText);
    }

    // Auto-detect operating system locale on initial cold start
    Component.onCompleted: {
        try {
            var sysLang = Quickshell.env("LANG") || Quickshell.env("LC_ALL") || "";
            if (sysLang.indexOf("vi") !== -1 || sysLang.indexOf("VI") !== -1) {
                locale = "vi";
            } else if (sysLang.indexOf("en") !== -1 || sysLang.indexOf("EN") !== -1) {
                locale = "en";
            }
        } catch(e) {
            console.log("[I18n] Note: Could not query system LANG env, defaulting to:", locale);
        }
    }
}
