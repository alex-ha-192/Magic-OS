// SPDX-License-Identifier: GPL-3.0-or-later
// Magic Start menu: Windows 10 layout, Zune type, no live tiles.
// Data comes from /usr/libexec/magic-os/start-helper (apps, accent, update state).
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root
    preferredRepresentation: compactRepresentation
    switchWidth: 0
    switchHeight: 0

    property var info: ({ accent: { fill: "#4d7c0f", text: "#bef264" }, user: { name: "", initial: "" },
                          waiting: "", apps: [], most: [], tiles: [], help: [], icons: {}, iconsMuted: {} })
    readonly property color ac: info.accent.fill
    readonly property color at: info.accent.text
    readonly property string helper: "/usr/libexec/magic-os/start-helper"

    function q(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }
    function run(cmd) { exec.connectSource(cmd + " #" + Date.now()) }
    function launch(path) { run(helper + " launch " + q(path)); root.expanded = false }
    function task(key) { run(helper + " run " + key); root.expanded = false }
    function refresh() { exec.connectSource(helper + " data") }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            if (source === root.helper + " data") {
                try { root.info = JSON.parse(data["stdout"]) } catch (e) { console.warn("magic-start: " + e) }
            }
            disconnectSource(source)
        }
    }

    Component.onCompleted: refresh()
    onExpandedChanged: if (expanded) refresh()

    compactRepresentation: MouseArea {
        id: button
        hoverEnabled: true
        Layout.minimumWidth: height
        Layout.preferredWidth: height
        onClicked: root.expanded = !root.expanded
        Accessible.name: "Start"
        Accessible.role: Accessible.Button
        Rectangle {
            anchors.fill: parent
            color: root.expanded ? root.ac : (button.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
        }
        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.round(parent.height * 0.5); height: width
            source: "magic-start"
        }
    }

    fullRepresentation: StartMenu {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 34
        Layout.minimumHeight: Kirigami.Units.gridUnit * 28
        Layout.preferredWidth: Kirigami.Units.gridUnit * 46
        Layout.preferredHeight: Kirigami.Units.gridUnit * 36
        menu: root
    }
}
