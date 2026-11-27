// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."
Page {
    title: "apps"
    intro: "Get new apps, remove ones you don't use, and choose which app opens what."
    Group {
        Setting { title: "Get apps"; description: "Browse and install apps from the App Store. They update themselves."
            MButton { text: "open app store"; primary: true; onClicked: sys.openStore("") } }
        Setting { title: "Remove apps"; description: "See what's installed and remove what you don't need."
            Link { text: "installed apps"; onClicked: sys.openStore("installed") } }
        Setting { title: "Default apps"; description: "Which browser, email app, music player and so on open your links and files."
            Link { text: "choose"; onClicked: sys.openKcm("kcm_componentchooser") } }
    }
    Group {
        title: "more"
        Setting { title: "Apps that start when you sign in"
            Link { text: "advanced"; onClicked: sys.openKcm("kcm_autostart") } }
        Setting { title: "What apps are allowed to do"; description: "Camera, microphone, files and more, per app."
            Link { text: "advanced"; onClicked: sys.openKcm("kcm_flatpak") } }
    }
}
