// Plain accent-coloured link, lowercase, with a chevron.
import QtQuick
import QtQuick.Controls
import "."
AbstractButton {
    id: l
    implicitHeight: 34
    implicitWidth: t.implicitWidth
    focusPolicy: Qt.StrongFocus
    Accessible.name: text
    background: Item {}
    contentItem: Text {
        id: t
        text: l.text.toLowerCase() + " ›"
        color: l.hovered ? Theme.text : Theme.at
        font.family: Theme.font; font.pixelSize: 15
        font.underline: l.visualFocus
        verticalAlignment: Text.AlignVCenter
    }
}
