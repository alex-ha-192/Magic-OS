// SPDX-License-Identifier: GPL-3.0-or-later
// Magic desktop layout: classic taskbar. Start button on the left, pinned
// apps, one button per open window, tray and clock on the right.
// API: https://develop.kde.org/docs/plasma/scripting/

// Accent chosen in the installer (written to the person's kdeglobals by
// magic-firstboot); decides the wallpaper.
var names = { lime: "Lime", ember: "Ember", magenta: "Magenta", teal: "Teal", blue: "Blue", violet: "Violet" };
var accent = "lime";
try {
    var g = ConfigFile("kdeglobals", "General");
    var a = g.readEntry("MagicAccent");
    if (a && names[a]) accent = a;
} catch (e) {}
var wallpaper = "/usr/share/wallpapers/Magic" + names[accent] + "/contents/images/3840x2160.jpg";

var desktopsArray = desktopsForActivity(currentActivity());
for (var i = 0; i < desktopsArray.length; i++) {
    var d = desktopsArray[i];
    d.wallpaperPlugin = "org.kde.image";
    d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    d.writeConfig("Image", "file://" + wallpaper);
    d.writeConfig("FillMode", 2);   // scaled and cropped
}

var panel = new Panel;
panel.location = "bottom";
panel.height = 2 * Math.ceil(gridUnit * 2.5 / 2);
panel.hiding = "none";
panel.floating = false;
panel.lengthMode = "fill";

var start = panel.addWidget("org.kde.plasma.kickoff");
start.currentConfigGroup = ["General"];
start.writeConfig("icon", "magic-start");
start.writeConfig("favoritesPortedToKAstats", "false");
start.writeConfig("favorites", [
    "preferred://browser",
    "org.kde.dolphin.desktop",
    "org.kde.discover.desktop",
    "org.magicos.Settings.desktop"
].join(","));
start.writeConfig("showActionButtonCaptions", "true");

// Pin whichever browser the installer put on (Vivaldi or Firefox).
var launchers = [];
var browsers = ["com.vivaldi.Vivaldi", "org.mozilla.firefox", "firefox"];
for (var b = 0; b < browsers.length; b++) {
    if (applicationExists(browsers[b] + ".desktop")) {
        launchers.push("applications:" + browsers[b] + ".desktop");
        break;
    }
}
launchers.push("applications:org.kde.dolphin.desktop");
launchers.push("applications:org.kde.discover.desktop");
launchers.push("applications:org.magicos.Settings.desktop");

var tasks = panel.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", launchers.join(","));
tasks.writeConfig("groupingStrategy", "0");     // one button per window, like Windows
tasks.writeConfig("showOnlyCurrentDesktop", "false");

panel.addWidget("org.kde.plasma.marginsseparator");
panel.addWidget("org.kde.plasma.systemtray");
var clock = panel.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", "true");
clock.writeConfig("dateFormat", "shortDate");
panel.addWidget("org.kde.plasma.showdesktop");
