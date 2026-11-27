// Theme icon drawn flat in one colour (the accent by default), like the mockups.
// The colouring happens in the image provider, so it needs no GPU effects.
import QtQuick
import "."
Item {
    id: i
    property string name
    property int size: 24
    property color tint: Theme.at
    implicitWidth: size
    implicitHeight: size
    Image {
        anchors.fill: parent
        sourceSize: Qt.size(i.size * 2, i.size * 2)
        source: i.name ? "image://icon/" + i.name + "-symbolic?" + i.tint : ""
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
}
