// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."
Page {
    readonly property var n: sys.state.network || {}
    title: "wi-fi & internet"
    intro: n.connection ? (n.kind === "wifi" ? "You're connected to " + n.connection + "." : "You're connected with a cable.") : "You're not connected to the internet."
    Group {
        Setting {
            title: "Wi-Fi"
            description: n.has_wifi === false ? "This computer has no Wi-Fi." : "Turn off to save battery, or on a plane."
            Toggle { checked: !!n.wifi_enabled; enabled: n.has_wifi !== false; onToggled: sys.setWifi(checked) }
        }
        Setting {
            title: "Choose a network"
            description: "Pick a Wi-Fi network and type its password. The network icon by the clock does this too."
            MButton { text: "show networks"; primary: true; onClicked: sys.openKcm("kcm_networkmanagement") }
        }
    }
    Group {
        title: "more"
        Setting { title: "VPN, hotspot and saved networks"; description: "Forget a network, share your connection, or add a VPN."
            Link { text: "advanced"; onClicked: sys.openKcm("kcm_networkmanagement") } }
    }
}
