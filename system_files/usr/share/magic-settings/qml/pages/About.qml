// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."
Page {
    readonly property var a: sys.state.about || {}
    title: "about this computer"
    Group {
        Setting { title: "Version"; description: (a.name || "Magic OS") + " " + (a.version || "") + ". Versions are named after the day they came out." }
        Setting { title: "Computer name"; description: a.computer || ""
            Link { text: "change"; onClicked: sys.openKcm("kcm_about-distro") } }
        Setting { title: "Processor"; description: a.cpu || "" }
        Setting { title: "Memory"; description: (a.memory_gb || "") + " GB" }
        Setting { title: "Storage"; description: (a.disk_free_gb || "") + " GB free of " + (a.disk_total_gb || "") + " GB" }
        Setting { title: "Copy these details"; description: "Handy if someone is helping you."
            MButton { text: "copy"; onClicked: sys.copy(sys.aboutText()) } }
    }
}
