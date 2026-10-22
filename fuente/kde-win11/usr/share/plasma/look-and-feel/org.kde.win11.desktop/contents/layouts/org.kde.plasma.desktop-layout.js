// Barra de tareas estilo Windows 11: inferior, iconos centrados, bandeja + reloj + "mostrar escritorio" a la derecha.
panels().forEach(function (p) { p.remove(); });

var bar = new Panel;
bar.location = "bottom";
bar.height = 48;
bar.floating = false;
bar.lengthMode = "fill";
bar.hiding = "none";
bar.opacity = "translucent";   // theme.sh la pone opaca si la transparencia está desactivada

// Huecos de la barra con el menú de clic derecho de Windows 11 ("Administrador de tareas")
var spacer = knownWidgetTypes.indexOf("org.kde.win11.spacer") >= 0 ? "org.kde.win11.spacer" : "org.kde.plasma.panelspacer";
bar.addWidget(spacer);

// Menú Inicio estilo Windows 11 (menu-11-next); si no está instalado, Kickoff
var start = bar.addWidget(knownWidgetTypes.indexOf("menu.11.next") >= 0 ? "menu.11.next" : "org.kde.plasma.kickoff");
start.currentConfigGroup = ["General"];
start.writeConfig("icon", "start-here");
start.writeConfig("showWeather", false);

function pick(win11, kde) { return knownWidgetTypes.indexOf(win11) >= 0 ? win11 : kde; }

var tasks = bar.addWidget(pick("org.mops1k.win11tasks", "org.kde.plasma.icontasks"));
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("fill", false);
tasks.writeConfig("iconSpacing", 1);
tasks.writeConfig("indicateAudioStreams", true);
// Navegador por su .desktop: preferred://browser sale como "?" si no hay asociación http
var browser = applicationExists("firefox") ? "applications:firefox.desktop" : "preferred://browser";
tasks.writeConfig("launchers",
  "applications:org.kde.dolphin.desktop," + browser + ",applications:org.kde.konsole.desktop,applications:win11-settings.desktop");

bar.addWidget(spacer);

var tray = bar.addWidget(pick("org.mops1k.win11tray", "org.kde.plasma.systemtray"));
tray.globalShortcut = "Meta+A";   // ajustes rápidos, como Win+A en Windows 11
// Junto al "^" solo iconos de apps (actualizaciones, Discord...): sonido, red, brillo, batería y
// Bluetooth ya están en el grupo de ajustes rápidos (si no, el altavoz salía dos veces) y el
// portapapeles en Windows 11 es Win+V
tray.currentConfigGroup = ["General"];
tray.writeConfig("hiddenItems", ["org.kde.plasma.clipboard", "org.kde.plasma.volume",
  "org.kde.plasma.networkmanagement", "org.kde.plasma.brightness", "org.kde.plasma.battery",
  "org.kde.plasma.bluetooth"]);

// Reloj estilo Windows 11 (hora sobre fecha, centro de notificaciones); si no, el reloj de KDE
var clock;
if (knownWidgetTypes.indexOf("org.mops1k.win11clock") >= 0) {
  clock = bar.addWidget("org.mops1k.win11clock");
  clock.currentConfigGroup = ["General"];
  clock.writeConfig("dateFormat", "custom");      // 8/10/2026, como Windows 11
  clock.writeConfig("customDateFormat", "d/M/yyyy");
  // Las notificaciones emergentes (estilo Windows 11) las muestra el reloj: sin el applet de
  // notificaciones de KDE en la bandeja, que mostraba otra copia de cada una encima.
  // Marcado como "conocido" para que la bandeja no lo active por defecto.
  tray.currentConfigGroup = ["General"];
  tray.writeConfig("knownItems", ["org.kde.plasma.notifications"]);
  tray.writeConfig("extraItems", []);
} else {
  clock = bar.addWidget("org.kde.plasma.digitalclock");
  clock.currentConfigGroup = ["Appearance"];
  clock.writeConfig("showDate", true);
  clock.writeConfig("dateDisplayFormat", "BelowTime");
  clock.writeConfig("dateFormat", "shortDate");
}

clock.globalShortcut = "Meta+N";   // calendario y notificaciones, como Win+N en Windows 11

var desk = bar.addWidget("org.kde.plasma.showdesktop");
desk.currentConfigGroup = ["General"];
desk.writeConfig("peekingEnabled", true);

// Fondo de Windows 11 en todos los escritorios (lo agrega el PKGBUILD al diseño del tema global)
desktops().forEach(function (d) {
  d.wallpaperPlugin = "org.kde.image";
  d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
  d.writeConfig("Image", "file:///usr/share/wallpapers/Win11OS-light/contents/images/3840x2400.jpg");
});
