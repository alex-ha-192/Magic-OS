// SPDX-License-Identifier: GPL-3.0-or-later
// The open Start menu. Left: you, settings, power. Middle: search, most used,
// all apps under thin lowercase letters. Right: everyday tasks, help & settings.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Rectangle {
    id: m
    property var menu
    readonly property var info: menu.info
    readonly property color ac: menu.ac
    readonly property color at: menu.at
    readonly property color bg: "#171514"
    readonly property color panel: "#211e1c"
    readonly property color hi: "#2b2725"
    readonly property color soft: "#d8d2ce"
    readonly property color mute: "#b5aeaa"
    readonly property string font: "Open Sans"
    property bool powerOpen: false
    color: bg

    function letterOf(name) {
        var c = (name || "").charAt(0).toLowerCase()
        return /[a-z]/.test(c) ? c : "#"
    }
    function matches(a, q) {
        q = q.toLowerCase()
        return a.name.toLowerCase().indexOf(q) >= 0 || (a.words || "").indexOf(q) >= 0
    }

    ListModel { id: allApps }
    function rebuild() {
        allApps.clear()
        var apps = (info && info.apps) || []
        for (var i = 0; i < apps.length; i++)
            allApps.append({ name: apps[i].name, icon: apps[i].icon, path: apps[i].path, letter: letterOf(apps[i].name) })
    }
    Connections { target: m.menu; ignoreUnknownSignals: true; function onInfoChanged() { m.rebuild(); Qt.callLater(list.positionViewAtBeginning) } }
    Component.onCompleted: rebuild()

    // Opening the menu: start typing to search.
    Connections {
        target: m.menu
        ignoreUnknownSignals: true
        function onExpandedChanged() {
            if (m.menu.expanded) { search.text = ""; m.powerOpen = false; search.forceActiveFocus(); Qt.callLater(list.positionViewAtBeginning) }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ---------------------------------------------------------- left rail
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 52
            color: "#12100f"
            ColumnLayout {
                anchors.fill: parent
                anchors.bottomMargin: 8
                spacing: 4
                Item { Layout.fillHeight: true }
                RailButton {
                    tip: m.info.user.name || "your account"
                    onClicked: m.menu.task("you")
                    Rectangle {
                        anchors.centerIn: parent
                        width: 30; height: 30; radius: 15; color: m.ac
                        Text { anchors.centerIn: parent; text: m.info.user.initial || "?"; color: "white"; font.family: m.font; font.pixelSize: 15 }
                    }
                }
                RailButton { tip: "settings"; icon: m.info.iconsMuted.settings || ""; onClicked: m.menu.task("settings") }
                RailButton {
                    id: powerButton
                    tip: "power"
                    icon: m.info.iconsMuted.power || ""
                    active: m.powerOpen
                    onClicked: m.powerOpen = !m.powerOpen
                    Rectangle {   // an update is waiting
                        visible: !!m.info.waiting
                        width: 8; height: 8; radius: 4; color: m.at
                        anchors { right: parent.right; top: parent.top; margins: 9 }
                    }
                }
            }
        }

        // ---------------------------------------------------------- apps
        ColumnLayout {
            Layout.fillHeight: true
            Layout.preferredWidth: Math.min(330, m.width * 0.42)
            Layout.maximumWidth: 360
            spacing: 0
            Rectangle {
                Layout.fillWidth: true
                Layout.margins: 14
                Layout.bottomMargin: 6
                implicitHeight: 40
                color: "#262220"
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; color: search.activeFocus ? m.at : "#7a736f" }
                Image { id: sIcon; source: m.info.icons.search || ""; width: 18; height: 18; sourceSize: Qt.size(36, 36); anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter } }
                TextInput {
                    id: search
                    anchors { left: sIcon.right; right: parent.right; leftMargin: 10; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    color: "white"; font.family: m.font; font.pixelSize: 15
                    clip: true
                    selectByMouse: true
                    Accessible.name: "Search for apps"
                    Text { anchors.fill: parent; text: "type to search"; color: "#8f8984"; font: parent.font; visible: !parent.text }
                    Keys.onReturnPressed: if (results.count > 0) m.menu.launch(results.model[0].path)
                    Keys.onDownPressed: { results.forceActiveFocus(); results.currentIndex = 0 }
                }
            }
            // search results
            ListView {
                id: results
                visible: search.text.length > 0
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true
                model: search.text ? (m.info.apps || []).filter(function (a) { return m.matches(a, search.text) }).slice(0, 30) : []
                delegate: AppRow { width: ListView.view.width; name: modelData.name; icon: modelData.icon; onClicked: m.menu.launch(modelData.path); highlighted: ListView.isCurrentItem && results.activeFocus }
                Keys.onReturnPressed: if (currentIndex >= 0) m.menu.launch(model[currentIndex].path)
                Text {
                    visible: results.count === 0
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
                    text: "No apps match. Try the App Store."
                    color: m.mute; font.family: m.font; font.pixelSize: 14; wrapMode: Text.WordWrap
                }
            }
            // most used + all apps
            ListView {
                id: list
                visible: !results.visible
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true
                currentIndex: -1
                boundsBehavior: Flickable.StopAtBounds
                QQC2.ScrollBar.vertical: QQC2.ScrollBar { }
                header: Column {
                    width: ListView.view.width
                    onHeightChanged: Qt.callLater(list.positionViewAtBeginning)
                    Heading { text: "most used"; visible: (m.info.most || []).length > 0 }
                    Repeater {
                        model: m.info.most || []
                        delegate: AppRow { width: parent.width; name: modelData.name; icon: modelData.icon; onClicked: m.menu.launch(modelData.path) }
                    }
                    Heading { text: "all apps" }
                }
                model: allApps
                section.property: "letter"
                section.delegate: Text {
                    required property string section
                    width: ListView.view.width
                    leftPadding: 18; topPadding: 10; bottomPadding: 2
                    text: section
                    color: m.at; font.family: m.font; font.pixelSize: 26; font.weight: Font.Light
                }
                delegate: AppRow {
                    required property var model
                    width: ListView.view.width
                    name: model.name
                    icon: model.icon
                    onClicked: m.menu.launch(model.path)
                }
            }
        }

        // ---------------------------------------------------------- tiles
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentHeight: tilesCol.implicitHeight + 30
            boundsBehavior: Flickable.StopAtBounds
            ColumnLayout {
                id: tilesCol
                x: 10; y: 14
                width: parent.width - 28
                spacing: 6
                Heading { text: "everyday"; Layout.fillWidth: true; leftPadding: 4 }
                Grid {
                    id: g1
                    Layout.fillWidth: true
                    columns: Math.max(2, Math.floor((width + 6) / 112))
                    spacing: 6
                    Repeater {
                        model: m.info.tiles || []
                        delegate: Tile { size: (g1.width - (g1.columns - 1) * 6) / g1.columns; label: modelData.label; icon: modelData.icon; onClicked: m.menu.launch(modelData.path) }
                    }
                }
                Heading { text: "help & settings"; Layout.fillWidth: true; leftPadding: 4; Layout.topMargin: 10 }
                Grid {
                    id: g2
                    Layout.fillWidth: true
                    columns: g1.columns
                    spacing: 6
                    Repeater {
                        model: m.info.help || []
                        delegate: Tile { size: (g2.width - (g2.columns - 1) * 6) / g2.columns; label: modelData.label; icon: modelData.icon; onClicked: m.menu.task(modelData.key) }
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------- power flyout
    Rectangle {
        id: flyout
        visible: m.powerOpen
        x: 52; y: m.height - height - 8
        width: 300
        height: fcol.implicitHeight + 20
        color: "#262220"
        border.color: "#3d3835"
        ColumnLayout {
            id: fcol
            x: 10; y: 10
            width: parent.width - 20
            spacing: 2
            PowerItem {
                text: m.info.waiting ? "update and restart" : "restart"
                note: m.info.waiting ? "installs the waiting update first" : ""
                onClicked: m.menu.run("busctl --user call org.kde.Shutdown /Shutdown org.kde.Shutdown logoutAndReboot")
            }
            PowerItem {
                text: m.info.waiting ? "update and shut down" : "shut down"
                note: m.info.waiting ? "installs it, then turns off" : ""
                onClicked: m.menu.run("busctl --user call org.kde.Shutdown /Shutdown org.kde.Shutdown logoutAndShutdown")
            }
            PowerItem { text: "sleep"; onClicked: { m.menu.expanded = false; m.menu.run("systemctl suspend") } }
            PowerItem { text: "lock"; onClicked: { m.menu.expanded = false; m.menu.run("loginctl lock-session") } }
            PowerItem { text: "sign out"; onClicked: m.menu.run("busctl --user call org.kde.Shutdown /Shutdown org.kde.Shutdown logout") }
            Text {
                visible: !!m.info.waiting
                Layout.fillWidth: true
                Layout.margins: 8
                text: "While an update is waiting, restarting or shutting down always installs it. You pick when."
                color: m.mute; font.family: m.font; font.pixelSize: 12; wrapMode: Text.WordWrap
            }
        }
    }

    // ---------------------------------------------------------- pieces
    component Heading: Text {
        color: "white"
        font.family: m.font; font.pixelSize: 24; font.weight: Font.Light
        topPadding: 10; bottomPadding: 6; leftPadding: 18
    }
    component RailButton: MouseArea {
        id: rb
        property string icon
        property string tip
        property bool active: false
        Layout.preferredWidth: 52; Layout.preferredHeight: 48
        hoverEnabled: true
        Accessible.name: tip
        Accessible.role: Accessible.Button
        Rectangle { anchors.fill: parent; color: rb.active ? m.hi : (rb.containsMouse ? "#211e1c" : "transparent") }
        Image { visible: rb.icon !== ""; anchors.centerIn: parent; source: rb.icon; width: 22; height: 22; sourceSize: Qt.size(44, 44) }
        QQC2.ToolTip.visible: containsMouse && tip !== ""
        QQC2.ToolTip.text: tip
    }
    component AppRow: MouseArea {
        id: ar
        property string name
        property string icon
        property bool highlighted: false
        height: 40
        hoverEnabled: true
        Accessible.name: name
        Accessible.role: Accessible.Button
        Rectangle { anchors.fill: parent; color: ar.highlighted ? m.ac : (ar.containsMouse ? m.hi : "transparent") }
        Kirigami.Icon { id: ai; source: ar.icon; width: 26; height: 26; anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter } }
        Text {
            anchors { left: ai.right; leftMargin: 12; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            text: ar.name; elide: Text.ElideRight
            color: "white"; font.family: m.font; font.pixelSize: 14
        }
    }
    component Tile: MouseArea {
        id: t
        property real size: 104
        property string label
        property string icon
        width: size; height: size
        hoverEnabled: true
        Accessible.name: label
        Accessible.role: Accessible.Button
        Rectangle {
            anchors.fill: parent
            color: t.pressed ? "#3d3835" : (t.containsMouse ? m.hi : m.panel)
            Rectangle { width: parent.width; height: 3; color: m.ac; visible: t.containsMouse }
        }
        Image { source: t.icon; width: 30; height: 30; sourceSize: Qt.size(60, 60); anchors { left: parent.left; top: parent.top; margins: 12 } }
        Text {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 10 }
            text: t.label; elide: Text.ElideRight
            color: "white"; font.family: m.font; font.pixelSize: 14; font.weight: Font.Light
        }
    }
    component PowerItem: MouseArea {
        id: pi
        property string text
        property string note
        Layout.fillWidth: true
        implicitHeight: note ? 52 : 40
        hoverEnabled: true
        Accessible.name: text
        Accessible.role: Accessible.Button
        Rectangle { anchors.fill: parent; color: pi.containsMouse ? m.ac : "transparent" }
        Column {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            Text { text: pi.text; color: "white"; font.family: m.font; font.pixelSize: 16; font.weight: pi.note ? Font.DemiBold : Font.Normal }
            Text { visible: pi.note !== ""; text: pi.note; color: pi.containsMouse ? "white" : m.mute; font.family: m.font; font.pixelSize: 12 }
        }
    }
}
