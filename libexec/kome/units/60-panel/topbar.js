// kome panel layout "topbar": a thin bar at the top of every screen
// (launcher, clock in the middle, tray on the first screen) and a floating
// dock of open apps centred at the bottom.
// To customise it, copy this file to ~/.config/kome/templates/panel/topbar.js.
var layout = [
    {
        location: "top", height: 1.5, lengthMode: "fill", alignment: "center",
        floating: false, hiding: "none", screens: "all",
        widgets: ["org.kde.plasma.kickoff", "org.kde.plasma.panelspacer",
                  "org.kde.plasma.digitalclock", "org.kde.plasma.panelspacer",
                  "first:org.kde.plasma.systemtray"]
    },
    {
        location: "bottom", height: 3, lengthMode: "fit", alignment: "center",
        floating: true, hiding: "dodgewindows", screens: "all",
        widgets: ["org.kde.plasma.icontasks"]
    }
];
