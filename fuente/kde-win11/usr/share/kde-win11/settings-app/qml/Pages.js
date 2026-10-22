// Estructura de Configuración (misma organización que Windows 11), con TODOS los módulos de KDE.
// Cada elemento puede ser:
//   kcm: "kcm_x"     -> abre ese módulo de KDE
//   action: "prog"   -> ejecuta un programa ("editpanel" = editar la barra)
//   page: "colors"   -> página propia de esta app
//   items: [...]     -> subpágina con su propia lista (se oculta si no queda ningún módulo instalado)
//   section: "Título"-> encabezado de grupo dentro de una lista
// type de la categoría: "links" (lista) o una página propia (system, personalization, update).
.pragma library

var pages = [
    { id: "home", title: "Inicio", icon: "user-home", type: "home", items: [] },
    { id: "system", title: "Sistema", icon: "computer", type: "system",
      items: [
        { title: "Pantalla", desc: "Monitores, brillo, luz nocturna, resolución, escala", icon: "video-display", kcm: "kcm_kscreen" },
        { title: "Sonido", desc: "Volumen, dispositivos de salida y entrada, sonidos del sistema", icon: "audio-volume-high",
          items: [
            { title: "Dispositivos y volumen", desc: "Salida, entrada, volumen por aplicación", icon: "audio-volume-high", kcm: "kcm_pulseaudio" },
            { title: "Sonidos del sistema", desc: "Tema de sonidos para notificaciones y eventos", icon: "preferences-desktop-sound", kcm: "kcm_soundtheme" },
            { title: "Información de audio", desc: "Detalles de las tarjetas y dispositivos de sonido", icon: "audio-card", kcm: "kcm_audio_information" }
          ] },
        { title: "Notificaciones", desc: "Alertas de aplicaciones y del sistema, No molestar", icon: "preferences-desktop-notification", kcm: "kcm_notifications" },
        { title: "Luz nocturna", desc: "Colores más cálidos y horario día-noche", icon: "redshift-status-on",
          items: [
            { title: "Luz nocturna", desc: "Temperatura de color y activación", icon: "redshift-status-on", kcm: "kcm_nightlight" },
            { title: "Horario día-noche", desc: "Horas de amanecer y anochecer para el sistema", icon: "preferences-system-time", kcm: "kcm_nighttime" }
          ] },
        { title: "Energía y batería", desc: "Suspensión, pantalla, perfiles de energía, uso de batería", icon: "preferences-system-power-management",
          items: [
            { title: "Energía", desc: "Suspensión, apagado de pantalla, botones de encendido", icon: "preferences-system-power-management", kcm: "kcm_powerdevilprofilesconfig" },
            { title: "Uso de batería y energía", desc: "Estadísticas de consumo", icon: "battery", kcm: "kcm_energyinfo", needs: "battery" }
          ] },
        { title: "Almacenamiento", desc: "Espacio de almacenamiento, unidades, carpetas personales", icon: "drive-harddisk",
          items: [
            { title: "Uso del espacio", desc: "Qué ocupa espacio en tu disco", icon: "filelight", action: "filelight" },
            { title: "Unidades y particiones", desc: "Discos y dispositivos de bloques", icon: "drive-harddisk", kcm: "kcm_block_devices" },
            { title: "Ubicación de las carpetas personales", desc: "Escritorio, Documentos, Descargas…", icon: "folder-home", kcm: "kcm_desktoppaths" }
          ] },
        { title: "Multitarea", desc: "Escritorios virtuales, Alt+Tab, actividades, bordes de pantalla", icon: "preferences-system-windows",
          items: [
            { title: "Escritorios virtuales", desc: "Número, nombres y cambio de escritorios", icon: "preferences-system-windows", kcm: "kcm_kwin_virtualdesktops" },
            { title: "Alt+Tab", desc: "Cómo se muestran las ventanas al cambiar de tarea", icon: "preferences-system-tabbox", kcm: "kcm_kwintabbox" },
            { title: "Actividades", desc: "Espacios de trabajo separados por tarea", icon: "preferences-activities", kcm: "kcm_activities" },
            { title: "Esquinas y bordes de pantalla", desc: "Acciones al llevar el puntero a los bordes", icon: "preferences-desktop-display", kcm: "kcm_kwinscreenedges" },
            { title: "Gestos de pantalla táctil", desc: "Deslizar desde los bordes", icon: "input-touchscreen", kcm: "kcm_kwintouchscreen", needs: "touchscreen" }
          ] },
        { title: "Ventanas", desc: "Comportamiento, reglas, scripts de KWin", icon: "preferences-system-windows-actions",
          items: [
            { title: "Comportamiento de las ventanas", desc: "Foco, acciones de la barra de título, movimiento", icon: "preferences-system-windows-actions", kcm: "kcm_kwinoptions" },
            { title: "Reglas de ventanas", desc: "Tamaño y posición por aplicación", icon: "preferences-system-windows-actions", kcm: "kcm_kwinrules" },
            { title: "Scripts de KWin", desc: "Extensiones del gestor de ventanas", icon: "preferences-system-windows-script", kcm: "kcm_kwin_scripts" },
            { title: "Aplicaciones X11 heredadas", desc: "Teclas que pueden leer las aplicaciones X11", icon: "preferences-system-windows", kcm: "kcm_kwinxwayland" }
          ] },
        { title: "Portapapeles", desc: "Historial del portapapeles, borrar datos, sincronización", icon: "edit-paste", page: "clipboard" },
        { title: "Inicio y apagado", desc: "Sesión, servicios en segundo plano, pantalla de arranque", icon: "system-shutdown",
          items: [
            { title: "Sesión del escritorio", desc: "Qué hacer al iniciar y cerrar sesión", icon: "system-log-out", kcm: "kcm_smserver" },
            { title: "Aplicaciones de inicio", desc: "Programas que se inician al iniciar sesión", icon: "system-run", kcm: "kcm_autostart" },
            { title: "Servicios en segundo plano", desc: "Activar o desactivar servicios de KDE", icon: "preferences-system-services", kcm: "kcm_kded" }
          ] },
        { title: "Opciones avanzadas", desc: "Comportamiento general, renderizado de Qt Quick, ajustes rápidos", icon: "preferences-other",
          items: [
            { title: "Comportamiento general", desc: "Clic simple o doble, animaciones, previsualizaciones", icon: "preferences-desktop", kcm: "kcm_workspace" },
            { title: "Ajustes rápidos de KDE", desc: "Página de inicio de Preferencias del sistema", icon: "preferences-system", kcm: "kcm_landingpage" },
            { title: "Renderizado de Qt Quick", desc: "Motor de dibujo de las aplicaciones", icon: "preferences-desktop-display", kcm: "kcm_qtquicksettings" }
          ] },
        { title: "Acerca de", desc: "Especificaciones del dispositivo, información detallada del hardware", icon: "help-about",
          items: [
            { title: "Especificaciones del dispositivo", desc: "Sistema operativo, procesador, memoria, nombre del equipo", icon: "help-about", kcm: "kcm_about-distro" },
            { section: "Hardware" },
            { title: "Procesador", desc: "Información avanzada de la CPU", icon: "cpu", kcm: "kcm_cpu" },
            { title: "Memoria", desc: "Uso de la memoria RAM", icon: "media-flash", kcm: "kcm_memory" },
            { title: "Sensores", desc: "Temperaturas, ventiladores, voltajes", icon: "temperature-normal", kcm: "kcm_sensors" },
            { title: "Dispositivos PCI", desc: "Tarjetas y controladoras internas", icon: "preferences-devices-tree", kcm: "kcm_pci" },
            { title: "Dispositivos USB", desc: "Dispositivos USB conectados", icon: "drive-removable-media-usb", kcm: "kcm_usb" },
            { title: "Interrupciones", desc: "Uso de interrupciones (IRQ)", icon: "preferences-system", kcm: "kcm_interrupts" },
            { title: "Interfaces de red", desc: "Adaptadores y direcciones", icon: "network-card", kcm: "kcm_network" },
            { title: "Datos del monitor (EDID)", desc: "Identificación de las pantallas", icon: "video-display", kcm: "kcm_edid" },
            { section: "Gráficos" },
            { title: "Vulkan", desc: "Información de Vulkan y la GPU", icon: "video-display", kcm: "kcm_vulkan" },
            { title: "OpenGL (EGL)", desc: "Información de EGL", icon: "video-display", kcm: "kcm_egl" },
            { title: "OpenGL (GLX)", desc: "Información de GLX", icon: "video-display", kcm: "kcm_glx" },
            { title: "OpenCL", desc: "Plataformas de cálculo en la GPU", icon: "video-display", kcm: "kcm_opencl" },
            { title: "Wayland", desc: "Información del compositor", icon: "wayland", kcm: "kcm_wayland" },
            { title: "Servidor X", desc: "Información de X11", icon: "xorg", kcm: "kcm_xserver" },
            { title: "Información de KWin", desc: "Datos de soporte del gestor de ventanas", icon: "kwin", kcm: "kcm_kwinsupportinfo" }
          ] }
      ] },
    { id: "devices", title: "Bluetooth y dispositivos", icon: "preferences-system-bluetooth", type: "links",
      items: [
        { title: "Bluetooth", desc: "Detectable como \"%HOST%\"", icon: "preferences-system-bluetooth", kcm: "kcm_bluetooth" },
        { title: "Mouse", desc: "Botones, velocidad del puntero, desplazamiento", icon: "input-mouse", kcm: "kcm_mouse" },
        { title: "Panel táctil", desc: "Pulsaciones, gestos, desplazamiento, zoom", icon: "input-touchpad", kcm: "kcm_touchpad", needs: "touchpad" },
        { title: "Teclado", desc: "Distribución, repetición de teclas, Bloq Num", icon: "input-keyboard", kcm: "kcm_keyboard" },
        { title: "Métodos abreviados de teclado", desc: "Atajos globales de aplicaciones y del sistema", icon: "preferences-desktop-keyboard-shortcut", kcm: "kcm_keys" },
        { title: "Pantalla táctil", desc: "Calibración y asignación a pantallas", icon: "input-touchscreen", kcm: "kcm_touchscreen", needs: "touchscreen" },
        { title: "Lápiz y tableta gráfica", desc: "Botones del lápiz, área de la tableta", icon: "input-tablet", kcm: "kcm_tablet", needs: "tablet" },
        { title: "Mandos de juego", desc: "Configura y prueba tus mandos", icon: "input-gaming", kcm: "kcm_gamecontroller" },
        { title: "Reproducción automática", desc: "Montaje automático de unidades", icon: "media-removable", kcm: "kcm_device_automounter" },
        { title: "Acciones de dispositivos", desc: "Qué hacer al conectar dispositivos nuevos", icon: "device-notifier", kcm: "kcm_solid_actions" },
        { title: "Impresoras", desc: "Añadir y administrar impresoras", icon: "printer", kcm: "kcm_printer_manager" },
        { title: "Thunderbolt", desc: "Dispositivos Thunderbolt", icon: "preferences-desktop-thunderbolt", kcm: "kcm_bolt", needs: "thunderbolt" }
      ] },
    { id: "network", title: "Red e Internet", icon: "network-wireless", type: "links",
      items: [
        { title: "Wi-Fi y Ethernet", desc: "Conexiones, propiedades, redes conocidas, VPN", icon: "network-wireless", kcm: "kcm_networkmanagement" },
        { title: "Red móvil", desc: "Datos móviles, SIM, itinerancia", icon: "network-mobile", kcm: "kcm_cellular_network", needs: "modem" },
        { title: "Zona con cobertura inalámbrica móvil", desc: "Comparte tu conexión a Internet", icon: "network-wireless-hotspot", kcm: "kcm_mobile_hotspot", needs: "wifi" },
        { title: "Proxy", desc: "Servidor proxy para conexiones Wi-Fi y Ethernet", icon: "preferences-system-network-proxy", kcm: "kcm_proxy" },
        { title: "Firewall", desc: "Protege tu equipo de conexiones no deseadas", icon: "security-high", kcm: "kcm_firewall" },
        { title: "Uso compartido de Windows (Samba)", desc: "Carpetas compartidas en la red", icon: "folder-remote", kcm: "kcm_samba" },
        { title: "Configuración de red avanzada", desc: "Tiempos de espera y preferencias generales", icon: "preferences-system-network", kcm: "kcm_netpref" },
        { title: "Interfaces de red", desc: "Adaptadores y direcciones", icon: "network-card", kcm: "kcm_network" }
      ] },
    { id: "personalization", title: "Personalización", icon: "preferences-desktop-theme-global", type: "personalization",
      items: [
        { title: "Fondo", desc: "Imágenes, color sólido, presentación", icon: "preferences-desktop-wallpaper", kcm: "kcm_wallpaper" },
        { title: "Colores", desc: "Modo oscuro, color de énfasis, transparencia", icon: "preferences-desktop-color", page: "colors" },
        { title: "Temas", desc: "Tema global, esquema de colores, estilos, iconos, cursores", icon: "preferences-desktop-theme-global",
          items: [
            { title: "Tema global", desc: "Instalar, cambiar o crear temas completos", icon: "preferences-desktop-theme-global", kcm: "kcm_lookandfeel" },
            { title: "Esquema de colores", desc: "Colores de las ventanas y aplicaciones", icon: "preferences-desktop-color", kcm: "kcm_colors" },
            { title: "Estilo de Plasma", desc: "Aspecto de la barra de tareas y los paneles", icon: "preferences-desktop-plasma-theme", kcm: "kcm_desktoptheme" },
            { title: "Estilo de las aplicaciones", desc: "Botones, menús y controles", icon: "preferences-desktop-theme-applications", kcm: "kcm_style" },
            { title: "Barras de título", desc: "Decoración, botones y bordes de las ventanas", icon: "preferences-system-windows-actions", kcm: "kcm_kwindecoration" },
            { title: "Iconos", desc: "Tema de iconos", icon: "preferences-desktop-icons", kcm: "kcm_icons" },
            { title: "Puntero del mouse", desc: "Tema y tamaño del puntero", icon: "preferences-cursors", kcm: "kcm_cursortheme" },
            { title: "Sonidos", desc: "Tema de sonidos del sistema", icon: "preferences-desktop-sound", kcm: "kcm_soundtheme" }
          ] },
        { title: "Pantalla de bloqueo", desc: "Imagen, reloj, tiempo de espera", icon: "preferences-desktop-screensaver", kcm: "kcm_screenlocker" },
        { title: "Inicio de sesión y arranque", desc: "Pantalla de inicio de sesión, bienvenida y arranque", icon: "preferences-system-login",
          items: [
            { title: "Pantalla de inicio de sesión", desc: "Plasma Login Manager", icon: "system-switch-user", kcm: "kcm_plasmalogin" },
            { title: "Pantalla de inicio de sesión (SDDM)", desc: "Tema del inicio de sesión", icon: "system-switch-user", kcm: "kcm_sddm" },
            { title: "Pantalla de bienvenida", desc: "Animación al entrar al escritorio", icon: "preferences-desktop-splash", kcm: "kcm_splashscreen" },
            { title: "Pantalla de arranque", desc: "Animación de Plymouth al encender", icon: "preferences-desktop-splash", kcm: "kcm_plymouth" }
          ] },
        { title: "Fuentes", desc: "Tipos de letra del sistema, instalar y administrar fuentes", icon: "preferences-desktop-font",
          items: [
            { title: "Fuentes del sistema", desc: "Tipo y tamaño de letra, suavizado", icon: "preferences-desktop-font", kcm: "kcm_fonts" },
            { title: "Administrar fuentes", desc: "Instalar, eliminar y previsualizar fuentes", icon: "preferences-desktop-font-installer", kcm: "kcm_fontinst" }
          ] },
        { title: "Inicio", desc: "Aplicaciones ancladas, recientes, carpetas", icon: "start-here", action: "editpanel" },
        { title: "Barra de tareas", desc: "Comportamiento de la barra de tareas, elementos anclados", icon: "preferences-desktop", action: "editpanel" },
        { title: "Comportamiento del escritorio", desc: "Clic simple o doble, animaciones, información emergente", icon: "preferences-desktop", kcm: "kcm_workspace" }
      ] },
    { id: "apps", title: "Aplicaciones", icon: "preferences-desktop-apps", type: "links",
      items: [
        { title: "Aplicaciones instaladas", desc: "Desinstalar, ver información", icon: "applications-all", page: "installed" },
        { title: "Aplicaciones predeterminadas", desc: "Navegador, correo, archivos y protocolos", icon: "preferences-desktop-default-applications", kcm: "kcm_componentchooser" },
        { title: "Asociaciones de archivos", desc: "Con qué aplicación se abre cada tipo de archivo", icon: "preferences-desktop-filetype-association", kcm: "kcm_filetypes" },
        { title: "Inicio", desc: "Aplicaciones que se inician al iniciar sesión", icon: "system-run", kcm: "kcm_autostart" },
        { title: "Búsquedas web", desc: "Palabras clave para buscar en Internet", icon: "preferences-web-browser-shortcuts", kcm: "kcm_webshortcuts" },
        { title: "Reglas de ventanas", desc: "Tamaño y posición por aplicación", icon: "preferences-system-windows-actions", kcm: "kcm_kwinrules" },
        { title: "Microsoft Store", desc: "Descarga aplicaciones y juegos", icon: "win11-store", glyph: "start", action: "win11-store" }
      ] },
    { id: "accounts", title: "Cuentas", icon: "system-users", type: "links",
      items: [
        { title: "Tu información", desc: "Foto de perfil, nombre, contraseña, otros usuarios", icon: "user-identity", kcm: "kcm_users" },
        { title: "Cuentas en línea", desc: "Correo, calendario, almacenamiento en la nube", icon: "applications-internet", kcm: "kcm_kaccounts" },
        { title: "Opciones de inicio de sesión", desc: "Pantalla de inicio de sesión", icon: "system-switch-user", kcm: "kcm_plasmalogin" },
        { title: "Opciones de inicio de sesión (SDDM)", desc: "Pantalla de inicio de sesión", icon: "system-switch-user", kcm: "kcm_sddm" },
        { title: "Cartera de contraseñas", desc: "Contraseñas guardadas de redes y aplicaciones", icon: "kwalletmanager", kcm: "kcm_kwallet5" }
      ] },
    { id: "time", title: "Hora e idioma", icon: "preferences-system-time", type: "links",
      items: [
        { title: "Fecha y hora", desc: "Zona horaria, ajuste automático", icon: "preferences-system-time", kcm: "kcm_clock" },
        { title: "Idioma y región", desc: "Idioma de la interfaz, formatos regionales", icon: "preferences-desktop-locale", kcm: "kcm_regionandlang" },
        { title: "Escritura", desc: "Revisión ortográfica", icon: "tools-check-spelling", kcm: "kcmspellchecking" },
        { title: "Teclado virtual", desc: "Teclado en pantalla", icon: "input-keyboard-virtual", kcm: "kcm_virtualkeyboard" }
      ] },
    { id: "gaming", title: "Juegos", icon: "applications-games", type: "links",
      items: [
        { title: "Mandos de juego", desc: "Configura y prueba tus mandos", icon: "input-gaming", kcm: "kcm_gamecontroller" },
        { title: "Gráficos", desc: "Información de Vulkan, OpenGL y la GPU", icon: "video-display", kcm: "kcm_vulkan" },
        { title: "OpenCL", desc: "Plataformas de cálculo en la GPU", icon: "video-display", kcm: "kcm_opencl" }
      ] },
    { id: "accessibility", title: "Accesibilidad", icon: "preferences-desktop-accessibility", type: "links",
      items: [
        { section: "Visión" },
        { title: "Tamaño del texto", desc: "Tamaño de las fuentes en todo el sistema", icon: "preferences-desktop-font", kcm: "kcm_fonts" },
        { title: "Efectos visuales", desc: "Animaciones, transparencia, zoom, filtros de color", icon: "preferences-desktop-effects", kcm: "kcm_kwin_effects" },
        { title: "Velocidad de animaciones", desc: "Duración de las animaciones del sistema", icon: "preferences-desktop-animations", kcm: "kcm_animations" },
        { title: "Puntero del mouse", desc: "Tamaño y color del puntero", icon: "preferences-cursors", kcm: "kcm_cursortheme" },
        { section: "Interacción" },
        { title: "Accesibilidad", desc: "Teclas especiales, campana visual, lector de pantalla", icon: "preferences-desktop-accessibility", kcm: "kcm_access" },
        { title: "Teclado", desc: "Repetición de teclas, Bloq Num", icon: "input-keyboard", kcm: "kcm_keyboard" },
        { title: "Métodos abreviados de teclado", desc: "Atajos globales", icon: "preferences-desktop-keyboard-shortcut", kcm: "kcm_keys" },
        { title: "Teclado virtual", desc: "Teclado en pantalla", icon: "input-keyboard-virtual", kcm: "kcm_virtualkeyboard" }
      ] },
    { id: "privacy", title: "Privacidad y seguridad", icon: "preferences-system-privacy", type: "links",
      items: [
        { section: "Seguridad" },
        { title: "Firewall", desc: "Protege tu equipo de conexiones no deseadas", icon: "security-high", kcm: "kcm_firewall" },
        { title: "Seguridad del firmware", desc: "Estado de seguridad del dispositivo", icon: "security-medium", kcm: "kcm_firmware_security" },
        { title: "Cartera de contraseñas", desc: "Contraseñas guardadas", icon: "kwalletmanager", kcm: "kcm_kwallet5" },
        { section: "Privacidad" },
        { title: "Historial de actividad", desc: "Archivos y aplicaciones recientes", icon: "document-open-recent", kcm: "kcm_recentFiles" },
        { title: "Búsqueda de archivos", desc: "Indexación de archivos", icon: "system-search", kcm: "kcm_baloofile" },
        { title: "Búsqueda", desc: "Complementos de búsqueda de Inicio", icon: "preferences-desktop-search", kcm: "kcm_plasmasearch" },
        { title: "Comentarios y diagnósticos", desc: "Datos que se comparten con KDE", icon: "preferences-desktop-feedback", kcm: "kcm_feedback" }
      ] },
    { id: "update", title: "Windows Update", icon: "system-software-update", type: "update", items: [] }
];

// Icono de línea de cada tarjeta: por módulo de KDE o, si no, por título
var glyphByKcm = {
    kcm_kscreen: "display", kcm_pulseaudio: "sound", kcm_soundtheme: "sound", kcm_audio_information: "info",
    kcm_notifications: "bell", kcm_nightlight: "moon", kcm_nighttime: "clock", kcm_powerdevilprofilesconfig: "power",
    kcm_energyinfo: "battery", kcm_block_devices: "storage", kcm_desktoppaths: "folder", kcm_kwin_virtualdesktops: "multitask",
    kcm_kwintabbox: "multitask", kcm_activities: "multitask", kcm_kwinscreenedges: "display", kcm_kwintouchscreen: "touch",
    kcm_kwinoptions: "window", kcm_kwinrules: "window", kcm_kwin_scripts: "puzzle", kcm_kwinxwayland: "window",
    kcm_smserver: "power", kcm_autostart: "power", kcm_kded: "puzzle", kcm_workspace: "advanced", kcm_landingpage: "home",
    kcm_qtquicksettings: "advanced", "kcm_about-distro": "info", kcm_cpu: "cpu", kcm_memory: "memory", kcm_sensors: "sensor",
    kcm_pci: "cpu", kcm_usb: "usb", kcm_interrupts: "cpu", kcm_network: "ethernet", kcm_edid: "display", kcm_vulkan: "display",
    kcm_egl: "display", kcm_glx: "display", kcm_opencl: "cpu", kcm_wayland: "window", kcm_xserver: "window",
    kcm_kwinsupportinfo: "info", kcm_bluetooth: "bluetooth", kcm_mouse: "mouse", kcm_touchpad: "touchpad",
    kcm_keyboard: "keyboard", kcm_keys: "keyboard", kcm_touchscreen: "touch", kcm_tablet: "pen", kcm_gamecontroller: "gamepad",
    kcm_device_automounter: "play", kcm_solid_actions: "usb", kcm_printer_manager: "printer", kcm_bolt: "thunder",
    kcm_networkmanagement: "wifi", kcm_cellular_network: "cellular", kcm_mobile_hotspot: "hotspot", kcm_proxy: "globe",
    kcm_firewall: "shield", kcm_samba: "folder", kcm_netpref: "advanced", kcm_wallpaper: "image", kcm_lookandfeel: "brush",
    kcm_colors: "palette", kcm_desktoptheme: "brush", kcm_style: "brush", kcm_kwindecoration: "window", kcm_icons: "start",
    kcm_cursortheme: "cursor", kcm_screenlocker: "lock", kcm_plasmalogin: "user", kcm_sddm: "user", kcm_splashscreen: "sparkle",
    kcm_plymouth: "power", kcm_fonts: "font", kcm_fontinst: "font", kcm_componentchooser: "apps", kcm_filetypes: "file",
    kcm_webshortcuts: "globe", kcm_users: "user", kcm_kaccounts: "mail", kcm_kwallet5: "key", kcm_clock: "clock",
    kcm_regionandlang: "language", kcmspellchecking: "spell", kcm_virtualkeyboard: "keyboard", kcm_kwin_effects: "sparkle",
    kcm_animations: "sparkle", kcm_access: "access", kcm_firmware_security: "shield", kcm_recentFiles: "history",
    kcm_baloofile: "search", kcm_plasmasearch: "search", kcm_feedback: "chart"
}
var glyphByTitle = {
    "Sonido": "sound", "Luz nocturna": "moon", "Energía y batería": "power", "Almacenamiento": "storage",
    "Multitarea": "multitask", "Ventanas": "window", "Portapapeles": "clipboard", "Inicio y apagado": "power",
    "Opciones avanzadas": "advanced", "Acerca de": "info", "Colores": "palette", "Temas": "brush",
    "Inicio de sesión y arranque": "lock", "Fuentes": "font", "Inicio": "start", "Barra de tareas": "taskbar",
    "Aplicaciones instaladas": "apps", "Uso del espacio": "storage"
}
function glyphFor(item) {
    if (!item) return "info"
    return item.glyph || glyphByKcm[item.kcm] || glyphByTitle[item.title] || "advanced"
}

// Detección de hardware que inyecta Main.qml (la biblioteca no ve "backend")
var hasHardware = function (what) { return true }
function setHardware(fn) { hasHardware = fn; return true }

function byId(id) {
    for (var i = 0; i < pages.length; ++i)
        if (pages[i].id === id) return pages[i];
    return null;
}

// ¿Se puede mostrar este elemento? (módulo instalado; subpágina con algún módulo instalado)
function available(item, kcms) {
    if (item.section) return true;
    if (item.needs && !hasHardware(item.needs)) return false;
    if (item.items) return item.items.some(function (i) { return !i.section && available(i, kcms) });
    return !item.kcm || kcms.indexOf(item.kcm) >= 0;
}

// Lista visible: quita módulos ausentes y encabezados que se quedan sin elementos
function visibleItems(items, kcms) {
    var out = [];
    for (var i = 0; i < items.length; ++i) {
        var it = items[i];
        if (it.section) {
            var any = false;
            for (var j = i + 1; j < items.length && !items[j].section; ++j)
                if (available(items[j], kcms)) { any = true; break }
            if (any) out.push(it);
        } else if (!it.hidden && available(it, kcms)) out.push(it);
    }
    return out;
}

// Todos los elementos finales con su ruta (para el buscador)
function flatten(kcms) {
    var out = [];
    function walk(items, path, catId) {
        items.forEach(function (it) {
            if (it.section || !available(it, kcms)) return;
            out.push({ item: it, path: path, category: catId });
            if (it.items) walk(it.items, path.concat([it]), catId);
        });
    }
    pages.forEach(function (pg) { walk(pg.items, [], pg.id) });
    return out;
}

var accents = [
    "#FFB900", "#FF8C00", "#F7630C", "#CA5010", "#DA3B01", "#EF6950", "#D13438", "#FF4343",
    "#E74856", "#E81123", "#EA005E", "#C30052", "#E3008C", "#BF0077", "#C239B3", "#9A0089",
    "#0078D4", "#0063B1", "#8E8CD8", "#6B69D6", "#8764B8", "#744DA9", "#B146C2", "#881798",
    "#0099BC", "#2D7D9A", "#00B7C3", "#038387", "#00B294", "#018574", "#00CC6A", "#10893E",
    "#7A7574", "#5D5A58", "#68768A", "#515C6B", "#567C73", "#486860", "#498205", "#107C10",
    "#767676", "#4C4A48", "#69797E", "#4A5459", "#647C64", "#525E54", "#847545", "#7E735F"
];
