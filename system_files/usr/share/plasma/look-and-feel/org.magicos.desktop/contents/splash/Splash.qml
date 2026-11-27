// SPDX-License-Identifier: GPL-3.0-or-later
// Shown for a moment after signing in, while the desktop loads.
import QtQuick

Rectangle {
    id: root
    color: "#12100f"
    property int stage
    Column {
        anchors.centerIn: parent
        spacing: 26
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "magic"
            color: "#ffffff"
            font.family: "Open Sans"
            font.pixelSize: 64
            font.weight: Font.Light
        }
        Rectangle {
            width: 320; height: 4
            color: "#3d3835"
            clip: true
            Rectangle {
                id: seg
                width: 90; height: 4
                color: "#bef264"
                NumberAnimation on x { from: -90; to: 320; duration: 1300; loops: Animation.Infinite; running: true }
            }
        }
    }
}
