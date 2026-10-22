// kome panel layout "dock": a floating dock centred at the bottom of every
// screen, as wide as its contents; the system tray only on the first one.
// To customise it, copy this file to ~/.config/kome/templates/panel/dock.js.
var layout = [
    {
        location: "bottom", height: 3, lengthMode: "fit", alignment: "center",
        floating: true, hiding: "none", screens: "all",
        widgets: ["org.kde.plasma.kickoff", "org.kde.plasma.icontasks",
                  "org.kde.plasma.marginsseparator", "first:org.kde.plasma.systemtray",
                  "org.kde.plasma.digitalclock"]
    }
];
