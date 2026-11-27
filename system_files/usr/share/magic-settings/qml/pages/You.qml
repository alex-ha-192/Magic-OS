// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."
Page {
    readonly property var me: sys.state.you || {}
    title: "your account"
    Group {
        RowLayout {
            Layout.topMargin: 8
            spacing: 20
            Rectangle {
                width: 84; height: 84; radius: 42; color: Theme.ac
                Text { anchors.centerIn: parent; text: (me.name || "?").charAt(0).toUpperCase(); color: Theme.text; font.family: Theme.font; font.pixelSize: 38; font.weight: Font.Light }
            }
            ColumnLayout {
                spacing: 0
                Heading { text: me.name || ""; size: 32 }
                Body { text: "Signs in as " + (me.username || ""); color: Theme.mute }
            }
        }
        Setting { title: "Change your password"; description: "You'll need your current password."
            MButton { text: "change password"; primary: true; onClicked: sys.openKcm("kcm_users") } }
        Setting { title: "Picture and name"
            Link { text: "change"; onClicked: sys.openKcm("kcm_users") } }
        Setting { title: "Other people"; description: "Add an account for someone else who uses this computer."
            Link { text: "add someone"; onClicked: sys.openKcm("kcm_users") } }
    }
}
