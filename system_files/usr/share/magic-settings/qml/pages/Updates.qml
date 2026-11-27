// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."
Page {
    readonly property var u: sys.state.updates || {}
    readonly property var sec: sys.state.security || {}
    title: "updates & safety"
    intro: "Magic updates itself in the background. You never have to look for updates."
    Group {
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: uc.implicitHeight + 36
            color: Theme.panel
            Rectangle { width: 4; height: parent.height; color: u.staged ? Theme.ac : Theme.line2 }
            ColumnLayout {
                id: uc
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 26; rightMargin: 20 }
                spacing: 6
                Heading { text: u.staged ? "an update is ready" : "you're up to date"; size: 30; color: u.staged ? Theme.at : Theme.text; Layout.fillWidth: true }
                Body {
                    Layout.fillWidth: true
                    text: u.staged ? "Magic " + u.staged + " is downloaded. It installs when you next restart or shut down, so nothing changes until you choose to."
                                   : "You're on Magic " + (u.booted || "") + ". New versions come out on Saturdays and download by themselves."
                }
                RowLayout {
                    visible: !!u.staged
                    spacing: 12
                    Layout.topMargin: 6
                    MButton { text: "restart now"; primary: true; onClicked: sys.restartNow() }
                    Body { text: "Save your work first."; font.pixelSize: 13; color: Theme.mute }
                }
            }
        }
    }
    Group {
        title: "something not right?"
        Setting {
            title: u.previous ? "Go back to " + u.previous : "Go back to the earlier version"
            description: u.rolled_back ? "Done. Magic will start the earlier version next time, and skip this update until a newer one comes out."
                         : "If something stopped working after an update, go back. Your files and settings stay as they are."
            MButton {
                text: sys.busy ? "working…" : "go back"
                enabled: !!u.previous && !sys.busy && !u.rolled_back
                onClicked: confirm.open()
            }
        }
        Setting {
            visible: !!u.rolled_back
            title: "Restart to finish going back"
            MButton { text: "restart now"; primary: true; onClicked: sys.restartNow() }
        }
    }
    Group {
        title: "apps"
        Setting { title: "App updates"; description: "Apps from the App Store update themselves every day, too."
            Link { text: "app store"; onClicked: sys.openStore("") } }
    }
    Group {
        title: "protection"
        Setting {
            title: sec.encrypted ? "Your files are encrypted" : "Your files are not encrypted"
            description: sec.encrypted ? "If this computer is lost or stolen, nobody can read your files. Keep your recovery key somewhere safe: you'll need it if the computer ever asks for it."
                                       : "Encryption is chosen when Magic is installed. To turn it on, reinstall Magic and keep 'protect your files' ticked."
            Text { text: sec.encrypted ? "✓" : "!"; color: sec.encrypted ? Theme.at : Theme.warn; font.pixelSize: 26; font.family: Theme.font }
        }
    }
    Dialog {
        id: confirm
        modal: true
        anchors.centerIn: Overlay.overlay
        width: Math.min(520, parent ? parent.width - 40 : 520)
        padding: 26
        background: Rectangle { color: Theme.panel; border.color: Theme.line2 }
        contentItem: ColumnLayout {
            spacing: 14
            Heading { text: "go back to " + (u.previous || "the earlier version") + "?"; size: 30; Layout.fillWidth: true; wrapMode: Text.WordWrap }
            Body { Layout.fillWidth: true; text: "Magic will start that version next time you restart. Your files, apps and settings stay as they are. You may be asked for your password." }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 10
                MButton { text: "cancel"; onClicked: confirm.close() }
                MButton { text: "go back"; primary: true; onClicked: { confirm.close(); sys.goBack() } }
            }
        }
    }
}
