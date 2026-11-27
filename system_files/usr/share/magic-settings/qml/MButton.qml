// Square Metro button. primary: accent fill. Otherwise outlined.
import QtQuick
import QtQuick.Controls
import "."
AbstractButton {
    id: b
    property bool primary: false
    implicitHeight: 40
    implicitWidth: Math.max(110, label.implicitWidth + 36)
    focusPolicy: Qt.StrongFocus
    Accessible.name: text
    background: Rectangle {
        color: !b.enabled ? "#2a2624" : b.primary ? (b.down ? Qt.darker(Theme.ac, 1.25) : b.hovered ? Qt.darker(Theme.ac, 1.1) : Theme.ac)
                                       : (b.down ? Theme.line2 : b.hovered ? "#2b2725" : "transparent")
        border.width: b.primary ? 0 : 1
        border.color: "#7a736f"
        Rectangle { anchors.fill: parent; anchors.margins: -3; color: "transparent"; border.color: Theme.text; border.width: 2; visible: b.visualFocus }
    }
    contentItem: Text {
        id: label
        text: b.text.toLowerCase()
        color: b.enabled ? Theme.text : "#8f8984"
        font.family: Theme.font
        font.pixelSize: 15
        font.weight: b.primary ? Font.DemiBold : Font.Normal
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
