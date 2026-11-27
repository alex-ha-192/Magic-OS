// Scrolling page with a big thin heading.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."
Flickable {
    id: p
    property string title
    property string intro
    default property alias content: col.data
    clip: true
    contentWidth: width
    contentHeight: col.implicitHeight + 80
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
    ColumnLayout {
        id: col
        x: p.width > 900 ? 48 : 28
        y: 34
        width: Math.min(p.width - 2 * x, 880)
        spacing: 6
        Heading { text: p.title; size: p.width > 700 ? 46 : 36; Layout.fillWidth: true }
        Body { text: p.intro; visible: text.length > 0; Layout.fillWidth: true; Layout.bottomMargin: 8 }
    }
}
