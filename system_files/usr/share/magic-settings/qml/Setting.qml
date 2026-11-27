// One setting: name and an explanation on the left, the control on the right.
// Narrow windows put the control underneath.
import QtQuick
import QtQuick.Layouts
import "."
Item {
    id: r
    property string title
    property string description
    default property alias control: slot.data
    readonly property bool narrow: width < 620
    Layout.fillWidth: true
    implicitHeight: grid.implicitHeight + 24
    GridLayout {
        id: grid
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        columns: r.narrow ? 1 : 2
        columnSpacing: 24
        rowSpacing: 10
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text { text: r.title; color: Theme.text; font.family: Theme.font; font.pixelSize: 17; Layout.fillWidth: true; wrapMode: Text.WordWrap }
            Body { text: r.description; visible: text.length > 0; Layout.fillWidth: true; font.pixelSize: 14; color: Theme.mute }
        }
        Item {
            Layout.alignment: r.narrow ? Qt.AlignLeft : (Qt.AlignRight | Qt.AlignVCenter)
            implicitWidth: slot.childrenRect.width
            implicitHeight: slot.childrenRect.height
            Item { id: slot; anchors.fill: parent }
        }
    }
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.line }
}
