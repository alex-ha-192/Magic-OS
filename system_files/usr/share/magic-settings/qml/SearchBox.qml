import QtQuick
import QtQuick.Controls
import "."
TextField {
    id: f
    placeholderText: "find a setting"
    placeholderTextColor: "#8f8984"
    text: win.query
    onTextEdited: win.query = text
    color: Theme.text
    font.family: Theme.font
    font.pixelSize: 16
    leftPadding: 14
    implicitHeight: 42
    selectByMouse: true
    Accessible.name: "Find a setting"
    background: Rectangle { color: Theme.field; Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; color: f.activeFocus ? Theme.at : "#7a736f" } }
}
