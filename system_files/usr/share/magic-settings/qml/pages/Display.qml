// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."
Page {
    readonly property var d: sys.state.display || {}
    title: "display"
    intro: "Brightness, comfortable colours at night, and how big things look."
    Group {
        Setting {
            visible: (d.brightness || -1) >= 0
            title: "Brightness"
            MSlider { from: 5; to: 100; value: d.brightness || 50; onMoved: sys.setBrightness(Math.round(value)) }
        }
        Setting {
            title: "Night light"
            description: "Warmer colours in the evening, easier on the eyes."
            Toggle { checked: !!d.night_light; onToggled: sys.setNightLight(checked) }
        }
    }
    Group {
        title: "size of text and apps"
        Setting {
            title: "Make everything bigger"
            description: "Changes text, buttons and windows together."
            Row {
                spacing: 6
                Repeater {
                    model: [100, 125, 150, 175, 200]
                    delegate: MButton {
                        required property int modelData
                        implicitWidth: 64
                        text: modelData + "%"
                        primary: Math.abs((d.scale || 100) - modelData) < 3
                        onClicked: sys.setScale(modelData)
                    }
                }
            }
        }
    }
    Group {
        title: "more"
        Setting { title: "Screens, resolution and rotation"; description: "Arrange two screens, or change the resolution."
            Link { text: "advanced"; onClicked: sys.openKcm("kcm_kscreen") } }
    }
}
