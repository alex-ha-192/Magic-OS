// Metro toggle: a rectangular switch with "on"/"off" beside it.
import QtQuick
import QtQuick.Controls
import "."
AbstractButton {
    id: t
    checkable: true
    implicitWidth: 112
    implicitHeight: 32
    focusPolicy: Qt.StrongFocus
    Accessible.role: Accessible.CheckBox
    background: Item {}
    contentItem: Row {
        spacing: 12
        Rectangle {
            width: 50; height: 22
            anchors.verticalCenter: parent.verticalCenter
            color: t.checked ? Theme.ac : "transparent"
            border.width: 2
            border.color: t.checked ? Theme.ac : (t.hovered ? Theme.text : "#b5aeaa")
            Rectangle {
                width: 12; height: 12
                anchors.verticalCenter: parent.verticalCenter
                x: t.checked ? parent.width - width - 5 : 5
                color: t.checked ? Theme.text : (t.hovered ? Theme.text : "#b5aeaa")
                Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }
            Rectangle { anchors.fill: parent; anchors.margins: -4; color: "transparent"; border.color: Theme.text; border.width: 2; visible: t.visualFocus }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: t.checked ? "on" : "off"
            color: Theme.text; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.Light
        }
    }
}
