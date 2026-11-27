// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."
Page {
    title: "printers & scanners"
    intro: "Most printers on your network or plugged in by USB are found by themselves."
    Group {
        Setting { title: "Printers"; description: "Add a printer, or see what's printing."
            MButton { text: "printers"; primary: true; onClicked: sys.openKcm("kcm_printer_manager") } }
        Setting { title: "Scan a document"; description: "Use the Skanpage app from the App Store."
            Link { text: "get skanpage"; onClicked: sys.openStore("") } }
    }
}
