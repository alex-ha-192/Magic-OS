// Flat slider: accent fill, square thumb.
import QtQuick
import QtQuick.Controls
import "."
Slider {
    id: s
    implicitWidth: 320
    implicitHeight: 30
    background: Rectangle {
        x: s.leftPadding; y: s.topPadding + s.availableHeight / 2 - height / 2
        width: s.availableWidth; height: 4
        color: Theme.line2
        Rectangle { width: s.visualPosition * parent.width; height: parent.height; color: Theme.at }
    }
    handle: Rectangle {
        x: s.leftPadding + s.visualPosition * (s.availableWidth - width)
        y: s.topPadding + s.availableHeight / 2 - height / 2
        width: 10; height: 26
        color: s.pressed ? Theme.text : Theme.at
        Rectangle { anchors.fill: parent; anchors.margins: -4; color: "transparent"; border.color: Theme.text; border.width: 2; visible: s.visualFocus }
    }
}
