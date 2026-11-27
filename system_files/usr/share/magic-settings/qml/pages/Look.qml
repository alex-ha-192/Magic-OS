// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."
Page {
    title: "colour & look"
    intro: "Pick a colour. Magic uses it for buttons, highlights and your background."
    Group {
        Flow {
            Layout.fillWidth: true
            Layout.topMargin: 10
            spacing: 10
            Repeater {
                model: sys.accents.order || Object.keys(sys.accents.accents)
                delegate: AbstractButton {
                    id: sw
                    required property string modelData
                    readonly property var a: sys.accents.accents[modelData]
                    width: 150; height: 104
                    focusPolicy: Qt.StrongFocus
                    Accessible.name: a.name
                    onClicked: sys.setAccent(modelData)
                    background: Rectangle {
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: "#161311" }
                            GradientStop { position: 1; color: sw.a.wallpaper }
                        }
                        Rectangle { anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 12; width: 34; height: 34; color: sw.a.fill }
                        Rectangle { anchors.fill: parent; color: "transparent"; border.width: sys.accent === sw.modelData ? 3 : 1; border.color: sys.accent === sw.modelData ? Theme.text : Theme.line2 }
                        Rectangle { anchors.fill: parent; anchors.margins: -4; color: "transparent"; border.color: Theme.text; border.width: 2; visible: sw.visualFocus }
                    }
                    contentItem: Text {
                        text: sw.a.name.toLowerCase()
                        color: Theme.text; font.family: Theme.font; font.pixelSize: 18; font.weight: Font.Light
                        horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignTop
                        rightPadding: 12; topPadding: 8
                    }
                }
            }
        }
    }
    Group {
        title: "more"
        Setting { title: "Background picture"; description: "Use one of your own photos instead."
            Link { text: "choose a picture"; onClicked: sys.openKcm("kcm_wallpaper") } }
        Setting { title: "Fonts, icons and window style"; description: "For people who like to tinker."
            Link { text: "advanced"; onClicked: sys.openKcm("kcm_lookandfeel") } }
    }
}
