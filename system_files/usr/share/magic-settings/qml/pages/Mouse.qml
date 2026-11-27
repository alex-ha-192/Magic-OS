// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."
Page {
    title: "mouse & keyboard"
    Group {
        Setting { title: "Mouse"; description: "Pointer speed, left-handed buttons and scrolling."
            Link { text: "change"; onClicked: sys.openKcm("kcm_mouse") } }
        Setting { title: "Touchpad"; description: "Tap to click, two-finger scrolling."
            Link { text: "change"; onClicked: sys.openKcm("kcm_touchpad") } }
        Setting { title: "Keyboard"; description: "Layouts, key repeat and Num Lock."
            Link { text: "change"; onClicked: sys.openKcm("kcm_keyboard") } }
        Setting { title: "Keyboard shortcuts"
            Link { text: "change"; onClicked: sys.openKcm("kcm_keys") } }
    }
}
