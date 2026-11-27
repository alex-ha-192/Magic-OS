// A titled group of settings.
import QtQuick
import QtQuick.Layouts
import "."
ColumnLayout {
    property string title
    default property alias items: col.data
    Layout.fillWidth: true
    spacing: 4
    Heading { text: parent.title; size: 24; color: Theme.at; Layout.topMargin: 18; visible: text.length > 0 }
    ColumnLayout { id: col; Layout.fillWidth: true; spacing: 0 }
}
