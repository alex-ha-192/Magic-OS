// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton
import QtQuick

QtObject {
    readonly property var acc: sys.accents.accents[sys.accent] || sys.accents.accents[sys.accents["default"]]
    readonly property color ac: acc.fill        // accent fill (buttons, selection)
    readonly property color at: acc.text        // accent on dark (headings, links)
    readonly property color wp: acc.wallpaper
    readonly property color bg: "#12100f"
    readonly property color side: "#0e0c0b"
    readonly property color panel: "#1c1917"
    readonly property color hi: "#25211f"
    readonly property color field: "#262220"
    readonly property color line: "#2f2b29"
    readonly property color line2: "#3d3835"
    readonly property color text: "#ffffff"
    readonly property color soft: "#d8d2ce"
    readonly property color mute: "#b5aeaa"
    readonly property color warn: "#f6c450"
    readonly property string font: "Open Sans"
}
