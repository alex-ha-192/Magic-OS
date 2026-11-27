// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."
Page {
    readonly property var p: sys.state.power || {}
    title: "power & battery"
    intro: p.has_battery ? "Battery " + p.battery + "%" + (p.charging ? ", charging." : ".") : ""
    Group {
        Setting {
            visible: (p.profiles || []).length > 0
            title: "Power mode"
            description: "Save battery, or get the most speed."
            Row {
                spacing: 6
                Repeater {
                    model: p.profiles || []
                    delegate: MButton {
                        required property string modelData
                        text: ({ "power-saver": "save battery", "balanced": "balanced", "performance": "best speed" })[modelData]
                        primary: p.profile === modelData
                        onClicked: sys.setPowerProfile(modelData)
                    }
                }
            }
        }
        Setting { title: "Sleep and screen off"; description: "When the screen turns off and the computer goes to sleep."
            Link { text: "change"; onClicked: sys.openKcm("kcm_powerdevilprofilesconfig") } }
    }
}
