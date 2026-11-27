// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."
Page {
    readonly property var b: sys.state.bluetooth || {}
    title: "bluetooth & devices"
    intro: b.available === false ? "This computer has no Bluetooth." : "Headphones, speakers, mice, keyboards and phones."
    Group {
        Setting {
            title: "Bluetooth"
            description: "Leave it on to use wireless headphones and mice."
            Toggle { checked: !!b.powered; enabled: !!b.available; onToggled: sys.setBluetooth(checked) }
        }
        Setting {
            title: "Add a device"
            description: "Put the device in pairing mode first. Its instructions say how."
            MButton { text: "add a device"; primary: true; enabled: !!b.powered; onClicked: sys.openKcm("kcm_bluetooth") }
        }
    }
    Group {
        title: "other devices"
        Setting { title: "Phones"; description: "Send files and see notifications from your phone (KDE Connect)."
            Link { text: "set up"; onClicked: sys.openKcm("kcm_kdeconnect") } }
        Setting { title: "Game controllers"; description: "Test and set up controllers."
            Link { text: "open"; onClicked: sys.openKcm("kcm_gamecontroller") } }
    }
}
