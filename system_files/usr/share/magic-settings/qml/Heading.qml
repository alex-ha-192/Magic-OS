// Zune-style heading: thin, lowercase, tight.
import QtQuick
import "."
Text {
    property int size: 44
    color: Theme.text
    font.family: Theme.font
    font.pixelSize: size
    font.weight: Font.Light
    font.letterSpacing: -size / 32
    textFormat: Text.PlainText
    elide: Text.ElideRight
    font.capitalization: Font.AllLowercase
}
