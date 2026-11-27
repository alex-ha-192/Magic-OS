// Left list entry on category pages. Current page: accent bar + bold.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."
AbstractButton {
    id: n
    property string iconName
    property bool current: false
    property bool compact: false
    implicitHeight: 40
    focusPolicy: Qt.StrongFocus
    Accessible.name: text
    ToolTip.visible: compact && hovered
    ToolTip.text: text
    background: Rectangle {
        color: n.hovered ? "#1d1a18" : "transparent"
        Rectangle { width: 4; height: parent.height; color: Theme.ac; visible: n.current }
        Rectangle { anchors.fill: parent; anchors.margins: 1; color: "transparent"; border.color: Theme.text; border.width: 2; visible: n.visualFocus }
    }
    contentItem: RowLayout {
        spacing: 14
        Icon { name: n.iconName; size: 20; tint: n.current ? Theme.at : Theme.soft }
        Text {
            visible: !n.compact
            text: n.text.toLowerCase()
            color: n.current ? Theme.text : Theme.soft
            font.family: Theme.font; font.pixelSize: 16
            font.weight: n.current ? Font.DemiBold : Font.Light
            Layout.fillWidth: true; elide: Text.ElideRight
        }
    }
    leftPadding: compact ? 22 : 24; rightPadding: 12
}
