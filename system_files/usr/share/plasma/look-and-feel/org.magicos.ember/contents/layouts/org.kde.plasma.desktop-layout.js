// Magic Ember layout: classic taskbar. Start button on the left, pinned apps,
// open windows with labels, tray and clock on the right.
// API: https://develop.kde.org/docs/plasma/scripting/
var desktopsArray = desktopsForActivity(currentActivity());
for (var i = 0; i < desktopsArray.length; i++) {
    desktopsArray[i].wallpaperPlugin = "org.kde.image";
}

var panel = new Panel;
panel.location = "bottom";
panel.height = 48;
panel.hiding = "none";
panel.floating = false;

var start = panel.addWidget("org.kde.plasma.kickoff");
start.currentConfigGroup = ["General"];
start.writeConfig("icon", "start-here-kde");

panel.addWidget("org.kde.plasma.pager");

var tasks = panel.addWidget("org.kde.plasma.taskmanager");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", [
    "applications:com.vivaldi.Vivaldi.desktop",
    "preferred://filemanager",
    "applications:org.kde.discover.desktop",
    "applications:systemsettings.desktop"
].join(","));
tasks.writeConfig("showToolTips", "true");
tasks.writeConfig("groupingStrategy", "0"); // never group: one button per window, like Windows

panel.addWidget("org.kde.plasma.marginsseparator");
panel.addWidget("org.kde.plasma.systemtray");
var clock = panel.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", "true");
panel.addWidget("org.kde.plasma.showdesktop");
