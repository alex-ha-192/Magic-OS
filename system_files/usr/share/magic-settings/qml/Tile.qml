// Home tile: icon, name, one-line status. Square, flat, accent edge on hover.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."
AbstractButton {
    id: t
    property var cat
    implicitHeight: 118
    implicitWidth: 240
    focusPolicy: Qt.StrongFocus
    Accessible.name: cat ? cat.title : ""
    background: Rectangle {
        color: t.down ? Theme.line2 : t.hovered ? Theme.hi : Theme.panel
        Rectangle { width: parent.width; height: 3; color: Theme.ac; visible: t.hovered || t.visualFocus }
        Rectangle { anchors.fill: parent; anchors.margins: -3; color: "transparent"; border.color: Theme.text; border.width: 2; visible: t.visualFocus }
    }
    contentItem: ColumnLayout {
        spacing: 6
        Icon { name: t.cat ? t.cat.icon : ""; size: 30 }
        Item { Layout.fillHeight: true }
        Text {
            text: t.cat ? t.cat.title.toLowerCase() : ""
            color: Theme.text; font.family: Theme.font; font.pixelSize: 20; font.weight: Font.Light
            Layout.fillWidth: true; elide: Text.ElideRight
        }
        Text {
            text: t.cat ? win.status(t.cat.key) : ""
            color: Theme.mute; font.family: Theme.font; font.pixelSize: 13
            Layout.fillWidth: true; elide: Text.ElideRight
        }
    }
    leftPadding: 18; rightPadding: 18; topPadding: 16; bottomPadding: 14
}
