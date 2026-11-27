// SPDX-License-Identifier: GPL-3.0-or-later
// Magic Settings: home of big category tiles, then a page per category with
// the category list down the left (Windows 10 layout, Zune type).
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

ApplicationWindow {
    id: win
    signal checkDone()
    width: 1180
    height: 760
    minimumWidth: 720
    minimumHeight: 500
    visible: true
    title: "Settings"
    color: Theme.bg
    font.family: Theme.font

    property string page: startPage || ""
    property string query: ""
    readonly property var st: sys.state

    // key, title, icon, words people might search for, page file
    readonly property var cats: [
        { key: "network",   title: "Wi-Fi & internet",    icon: "wifi", words: "wifi wireless internet network ethernet cable vpn airplane" },
        { key: "bluetooth", title: "Bluetooth & devices", icon: "bluetooth", words: "bluetooth headphones speaker phone pair mouse keyboard devices" },
        { key: "display",   title: "Display",             icon: "display", words: "screen brightness night light size scale text bigger monitor resolution" },
        { key: "sound",     title: "Sound",               icon: "sound", words: "volume speakers headphones microphone mute audio" },
        { key: "look",      title: "Colour & look",       icon: "look", words: "colour color accent wallpaper background theme look" },
        { key: "updates",   title: "Updates & safety",    icon: "updates", words: "update updates version go back rollback restore encryption recovery key safety security" },
        { key: "apps",      title: "Apps",                icon: "apps", words: "apps programs install remove uninstall store default browser email" },
        { key: "you",       title: "Your account",        icon: "you", words: "account password name picture user sign in login" },
        { key: "time",      title: "Time & language",     icon: "time", words: "time date clock time zone language region keyboard layout" },
        { key: "power",     title: "Power & battery",     icon: "power", words: "battery power sleep energy saver performance lid" },
        { key: "printers",  title: "Printers & scanners", icon: "printers", words: "printer print scanner scan" },
        { key: "mouse",     title: "Mouse & keyboard",    icon: "mouse", words: "mouse touchpad trackpad keyboard pointer scroll click" },
        { key: "about",     title: "About this computer", icon: "about", words: "about version computer name memory storage processor specs" }
    ]
    readonly property var pageFiles: ({ network: "Network", bluetooth: "Bluetooth", display: "Display", sound: "Sound",
        look: "Look", updates: "Updates", apps: "Apps", you: "You", time: "Time", power: "Power",
        printers: "Printers", mouse: "Mouse", about: "About" })

    function catOf(k) { for (var i = 0; i < cats.length; i++) if (cats[i].key === k) return cats[i]; return null }
    function matches(c) {
        var q = query.trim().toLowerCase()
        if (!q) return true
        return (c.title + " " + c.words).toLowerCase().indexOf(q) >= 0
    }
    function status(k) {
        var s = st[k] || {}
        switch (k) {
        case "network": return s.connection ? (s.kind === "wifi" ? "Connected to " + s.connection : "Connected with a cable") : (s.wifi_enabled === false ? "Wi-Fi is off" : "Not connected")
        case "bluetooth": { var b = st.bluetooth || {}; return !b.available ? "No Bluetooth on this computer" : b.powered ? "On" : "Off" }
        case "display": { var d = st.display || {}; return (d.night_light ? "Night light on · " : "") + "Text size " + (d.scale || 100) + "%" }
        case "sound": { var a = st.sound || {}; return !a.available ? "No speakers found" : a.muted ? "Muted" : "Volume " + a.volume + "%" }
        case "look": return (sys.accents.accents[sys.accent] || {}).name + " colour"
        case "updates": { var u = st.updates || {}; return u.staged ? "An update is ready" : "Up to date" + (u.booted ? " · " + u.booted : "") }
        case "apps": return "Add or remove apps, pick your browser"
        case "you": return (st.you || {}).name || ""
        case "time": { var t = st.time || {}; return (t.timezone || "").replace(/_/g, " ").split("/").pop() + " · " + (t.language || "") }
        case "power": { var p = st.power || {}; return p.has_battery ? p.battery + "%" + (p.charging ? " · charging" : "") : "Plugged in" }
        case "printers": return "Add a printer or scanner"
        case "mouse": return "Pointer speed, scrolling, layouts"
        case "about": { var ab = st.about || {}; return ab.name ? ab.name + " " + ab.version : "" }
        }
        return ""
    }

    // ------------------------------------------------------------ home
    Component {
        id: home
        Flickable {
            clip: true
            contentHeight: hc.implicitHeight + 60
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            ColumnLayout {
                id: hc
                x: width > 0 ? Math.max(28, (parent.width - width) / 2) : 28
                y: 34
                width: Math.min(win.width - 56, 1100)
                spacing: 16
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 20
                    Heading { text: "settings"; size: 54; Layout.fillWidth: true }
                    SearchBox { Layout.preferredWidth: Math.min(380, hc.width * 0.45) }
                }
                // Update waiting? Say so first, with the one button that matters.
                Rectangle {
                    Layout.fillWidth: true
                    visible: !!(st.updates && st.updates.staged) && query === ""
                    implicitHeight: ub.implicitHeight + 28
                    color: Theme.panel
                    Rectangle { width: 4; height: parent.height; color: Theme.ac }
                    RowLayout {
                        id: ub
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 22; rightMargin: 16 }
                        spacing: 16
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 0
                            Text { text: "An update is ready"; color: Theme.text; font.family: Theme.font; font.pixelSize: 17; font.weight: Font.DemiBold }
                            Body { text: "It installs the next time you restart or shut down. Nothing else to do."; Layout.fillWidth: true; font.pixelSize: 14 }
                        }
                        MButton { text: "restart now"; primary: true; onClicked: sys.restartNow() }
                    }
                }
                GridLayout {
                    id: grid
                    Layout.fillWidth: true
                    columns: Math.max(1, Math.min(4, Math.floor((hc.width + 10) / 250)))
                    columnSpacing: 10
                    rowSpacing: 10
                    Repeater {
                        model: win.cats.filter(win.matches)
                        delegate: Tile {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            cat: modelData
                            onClicked: win.page = modelData.key
                        }
                    }
                }
                Body { visible: win.cats.filter(win.matches).length === 0; text: "Nothing matches “" + query + "”. Try a simpler word, or look in advanced settings." }
                RowLayout {
                    Layout.topMargin: 6
                    spacing: 18
                    Link { text: "advanced settings"; onClicked: sys.openAdvanced() }
                    Body { text: "Every KDE setting, for when you need something not shown here."; font.pixelSize: 13; color: Theme.mute; Layout.fillWidth: true }
                }
            }
        }
    }

    // ------------------------------------------------------------ category pages
    RowLayout {
        anchors.fill: parent
        spacing: 0
        Rectangle {
            id: nav
            visible: win.page !== ""
            Layout.fillHeight: true
            Layout.preferredWidth: win.width < 900 ? 64 : 270
            color: Theme.side
            Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.line }
            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 18
                spacing: 2
                NavItem {
                    Layout.fillWidth: true
                    text: "settings home"; iconName: "home"
                    compact: nav.width < 100
                    onClicked: { win.page = ""; win.query = "" }
                }
                Item { Layout.preferredHeight: 10 }
                Repeater {
                    model: win.cats
                    delegate: NavItem {
                        required property var modelData
                        Layout.fillWidth: true
                        text: modelData.title; iconName: modelData.icon
                        current: win.page === modelData.key
                        compact: nav.width < 100
                        onClicked: win.page = modelData.key
                    }
                }
                Item { Layout.fillHeight: true }
                NavItem {
                    Layout.fillWidth: true; Layout.bottomMargin: 12
                    text: "advanced settings"; iconName: "advanced"
                    compact: nav.width < 100
                    onClicked: sys.openAdvanced()
                }
            }
        }
        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: win.page === ""
            active: visible
            sourceComponent: home
        }
        Loader {
            id: body
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: win.page !== ""
            source: win.page === "" ? "" : "pages/" + win.pageFiles[win.page] + ".qml"
        }
    }

    // Short messages ("Copied.", "Done. Restart to ...")
    Rectangle {
        id: toast
        property alias text: tt.text
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        width: tt.implicitWidth + 40; height: 44
        color: Theme.ac
        opacity: 0
        visible: opacity > 0
        Text { id: tt; anchors.centerIn: parent; color: Theme.text; font.family: Theme.font; font.pixelSize: 15 }
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Timer { id: tth; interval: 3500; onTriggered: toast.opacity = 0 }
    }
    Connections {
        target: sys
        function onMessage(m) { toast.text = m; toast.opacity = 1; tth.restart() }
    }

    Shortcut { sequences: [StandardKey.Back]; onActivated: win.page = "" }
    Shortcut { sequence: "Esc"; enabled: win.page !== ""; onActivated: win.page = "" }

    // --check: visit every page, then report.
    Timer {
        id: checker
        property int i: -1
        running: checkMode
        interval: 250
        repeat: true
        onTriggered: {
            i++
            if (i < win.cats.length) win.page = win.cats[i].key
            else { stop(); win.page = ""; win.checkDone() }
        }
    }
}
