// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."
Page {
    readonly property var t: sys.state.time || {}
    title: "time & language"
    Group {
        Setting { title: "Set the time automatically"; description: "Uses the internet to keep the clock right."
            Toggle { checked: !!t.auto; onToggled: sys.setAutoTime(checked) } }
        Setting { title: "Time zone"; description: (t.timezone || "").replace(/_/g, " ")
            Link { text: "change"; onClicked: sys.openKcm("kcm_clock") } }
    }
    Group {
        title: "language"
        Setting { title: "Language and formats"; description: (t.language || "") + ". Also dates, numbers and currency."
            Link { text: "change"; onClicked: sys.openKcm("kcm_regionandlang") } }
        Setting { title: "Keyboard layout"; description: "Add a layout, or switch between them."
            Link { text: "change"; onClicked: sys.openKcm("kcm_keyboard") } }
    }
}
