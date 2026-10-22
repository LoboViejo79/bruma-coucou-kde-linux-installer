
// Fondo de Windows 11 en todos los escritorios (lo agrega el PKGBUILD al diseño del tema global)
desktops().forEach(function (d) {
  d.wallpaperPlugin = "org.kde.image";
  d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
  d.writeConfig("Image", "file://@WALLPAPER@");
});
