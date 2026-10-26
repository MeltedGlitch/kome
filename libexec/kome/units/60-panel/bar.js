// kome panel layout "bar": Plasma's own default — one full-width bar at the
// bottom of every screen; the system tray only on the first one.
// To customise it, copy this file to ~/.config/kome/templates/panel/bar.js.
var layout = [
    {
        location: "bottom", height: 3, lengthMode: "fill", alignment: "center",
        floating: true, hiding: "none", screens: "all",
        widgets: ["org.kde.plasma.kickoff", "org.kde.plasma.pager", "org.kde.plasma.icontasks",
                  "org.kde.plasma.marginsseparator", "first:org.kde.plasma.systemtray",
                  "org.kde.plasma.digitalclock", "org.kde.plasma.showdesktop"]
    }
];
