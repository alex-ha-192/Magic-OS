// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."
Page {
    readonly property var a: sys.state.sound || {}
    title: "sound"
    intro: a.available === false ? "No speakers or headphones were found." : ""
    Group {
        Setting {
            title: "Volume"
            RowLayout {
                spacing: 14
                MSlider { from: 0; to: 100; value: a.volume || 0; enabled: !!a.available && !a.muted; onMoved: sys.setVolume(Math.round(value)) }
                Text { text: (a.volume || 0) + "%"; color: Theme.soft; font.family: Theme.font; font.pixelSize: 15; Layout.preferredWidth: 46 }
            }
        }
        Setting {
            title: "Mute"
            Toggle { checked: !!a.muted; enabled: !!a.available; onToggled: sys.setMuted(checked) }
        }
    }
    Group {
        title: "more"
        Setting { title: "Choose speakers, headphones or microphone"; description: "Pick which device plays sound and which one listens."
            Link { text: "advanced"; onClicked: sys.openKcm("kcm_pulseaudio") } }
    }
}
