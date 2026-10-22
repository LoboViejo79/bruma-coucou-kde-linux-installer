# Bruma Coucou: cómo está armado el instalador

Todo está en una sola carpeta, **"Bruma Coucou"**:

- **Arriba** está el instalador listo para usar (doble clic en "Instalar Bruma Coucou"). Los scripts
  (`instalar.sh`, `paso-sistema.sh`, `paso-cuenta.sh`, `estado.sh`…) se editan ahí mismo.
- **`paquetes/`** tiene los paquetes armados que instala. `coucou-claro` y `kde-win11` los arma
  `construir.sh` desde `fuente/`; los demás (`hyper-headset-bin`, `uxplay`) van tal cual.
- **`fuente/`** (esta carpeta) tiene el código de los paquetes, para cambiarlos.

## Para hacer un cambio

1. Cambiá lo que haga falta: un script de arriba, o un archivo dentro de `fuente/coucou-claro/`,
   `fuente/kde-win11/` o `fuente/codigo/`.
2. `fuente/construir.sh --revisar` dice qué cambió.
3. `fuente/construir.sh` actualiza `paquetes/` y sube solo los números:
   - cada paquete que cambió: `1.0.37-47` → `1.0.37-48`;
   - el instalador (`VERSION`): `1.0.63` → `1.0.64`.

   Con eso, en un equipo que ya tiene Coucou el instalador ofrece "Actualizar" y pone solo lo nuevo.
4. Para pasarlo a otra PC: `fuente/construir.sh --zip` arma `../bruma-coucou-vX.Y.Z.zip`
   sin `fuente/` (no hace falta para instalar).

No hace falta `sudo`: los paquetes salen con todos sus archivos como de root igual.

## Qué hay en fuente/

| Carpeta | Qué es |
|---|---|
| `coucou-claro/` | El paquete de Coucou como árbol de archivos (lo que queda instalado en `/`) y su `.PKGINFO` |
| `kde-win11/` | La base del diseño heredada del tema de Windows 11 (iconos, cursores, apps de Coucou con nombre `win11-*`) |
| `configuracion/` | Las páginas (QML) de la app **Configuración** de Coucou. Se editan aquí: al armar van a `/usr/share/coucou/configuracion.rcc` y valen en lugar de las que trae el programa |
| `codigo/` | Código que se compila al armar: `coucou-pantallas.c` (la barra entre pantallas), `coucou-web.c` (suma las transiciones a la página de la barra) y `configuracion-paginas.cpp` (pone las páginas de `configuracion/` en Configuración) |
| `construir.sh` | Arma los paquetes y sube las versiones |
| `nuevo-widget.sh` | Crea el esqueleto de un widget nuevo para el escritorio (ver «Widgets») |
| `probar-widget.sh` | Muestra un widget del proyecto en una ventana, sin instalar nada |
| `.construido/` | Huellas de lo último armado (para saber qué cambió). No se toca |

Cada paquete tiene su `.PKGINFO` (nombre, versión, dependencias): para agregar una dependencia,
se agrega una línea `depend = …` ahí.

## Dónde está cada cosa de Coucou (fuente/coucou-claro)

| Qué | Dónde |
|---|---|
| Lanzador de la barra (modo seguro, pantallas, reaperturas) | `usr/bin/coucou-launch` |
| Configuración: sus páginas | `fuente/configuracion/qml/` (p. ej. `IconsPage.qml` = Personalización › Iconos, `WidgetsPage.qml` = Personalización › Widgets) |
| Widgets del escritorio (Música, Clima, Rendimiento…) | `usr/share/plasma/plasmoids/org.coucou.*` |
| Centro de control (Meta+C): bloques, vistas, edición | `usr/share/coucou/control/` (lo abre `usr/bin/coucou-control`; el atajo lo pone `usr/lib/coucou/control-atajo`) |
| Lo común de los widgets: la tarjeta con sus efectos, colores, botones, pixeles | `usr/lib/qt6/qml/org/coucou/widgets/` |
| Iconos: tema, color de carpetas, restablecer, lugares del explorador | `usr/lib/coucou/coucou-iconos` |
| Temas de iconos Coucou (Papirus con carpetas violetas) | `usr/lib/coucou/iconos-coucou` + `usr/share/libalpm/hooks/coucou-iconos.hook` |
| La barra (programa compilado, sin su código aquí) | `usr/bin/coucou` |
| Barra entre pantallas: filtro de Wayland | `fuente/codigo/coucou-pantallas.c` |
| Barra entre pantallas: entrada/salida sin parpadeo (efecto de KWin) | `usr/share/kwin/effects/coucou-barra/` |
| Transiciones de la barra (mochi ↔ panel; panel → Coucou Code) | `usr/share/coucou/web/` (lo suma `fuente/codigo/coucou-web.c`) y `usr/share/kwin/effects/coucou-barra/` |
| Colores claro/oscuro, énfasis, GTK, tema de Plasma | `usr/lib/coucou/coucou-colors` |
| Aplicar el diseño a una cuenta | `usr/lib/coucou/estilo` |
| Mismo fondo en todas las pantallas | `usr/lib/coucou/fondos-pantallas` |
| Pantalla de bloqueo | `usr/share/coucou/lockscreen/` (la copia `usr/lib/coucou/lockscreen-sync`) |
| Diálogo de apagar / reiniciar / suspender | `usr/share/coucou/logout/` (también lo copia `lockscreen-sync`) |
| Inicio de sesión (SDDM) | `usr/share/sddm/themes/coucou-login/` |
| Sesión X11 para AnyDesk (Xfce vestido como tu Plasma: copia pantallas, mouse/touchpad, teclado, tema, iconos, cursor y letra al entrar; barra de tareas abajo; sin la barra de Coucou, que en X11 tapaba la pantalla y se comía los clics). Registro: `~/.cache/coucou-sesion-x11.log` | `usr/lib/coucou/sesion-x11`, `usr/share/coucou/xsessions/` (la instala `paso-sistema.sh` o la Tienda si hay AnyDesk) |
| Tienda: apps nativas (CachyOS/Arch y AUR) al lado de Flathub, de dónde conviene cada una | `usr/lib/coucou/tienda-nativo` (como usuario), `usr/lib/coucou/tienda-nativo-root` (con pkexec: pacman y lo que cada app necesita para andar, p. ej. el servicio de AnyDesk), `usr/share/coucou/tienda/apps.conf` |
| Tienda (el programa): código | `fuente/kde-win11/usr/share/kde-win11/store-app/` (lo compila `construir.sh` a `coucou-claro/usr/local/bin/win11-store`) |
| Ventana del instalador: sus pantallas (la página «Copias de seguridad») | `fuente/ventana/qml/Main.qml` (sacada del programa, que viene compilado) y `fuente/codigo/instalador-ventana*.{cpp,c}` (la ponen encima de las del programa, suman ver el historial y desinstalar, y la dejan siempre clara aunque el tema del sistema sea oscuro): `construir.sh` las arma en `bin/` |
| Bienvenido (el programa): código | `fuente/kde-win11/usr/share/kde-win11/welcome-app/` (lo compila `construir.sh` a `kde-win11/usr/bin/win11-welcome`) |
| Modo juego: pausa lo de fondo que no hace falta (avisos, voz, estadísticas, indexador, KDE Connect, historial del portapapeles, accesibilidad), limpia la memoria, manda a la memoria comprimida (zram, `memory.reclaim` de cada servicio de la cuenta) lo que está en segundo plano (la barra, Plasma), perfil Rendimiento y video AMD al máximo, No molestar, pantalla siempre encendida; la barra y el escritorio siguen a la vista. Avisa qué deja de andar (notificación, Centro de control y ventana de Juegos). Al salir vuelve todo. Es uno solo: el botón "Modo juego" de la ventana de Juegos de la barra usa el mismo script (lo engancha `web/mochi.js` y lo corre `codigo/coucou-web.c`). Opciones en `~/.config/coucou/modo-juego.conf`; registro en `~/.cache/coucou-modo-juego.log` | `usr/lib/coucou/modo-juego`, `usr/lib/coucou/modo-juego-root` (lo de administrador, sin contraseña: `usr/share/polkit-1/actions/org.coucou.modo-juego.policy`), `control/bloques/Juego.qml`, `control/vistas/VistaJuego.qml`, el botón en `control/bloques/Botones.qml`, `usr/share/applications/coucou-modo-juego.desktop`, `usr/share/coucou/web/mochi.js` (ventana de Juegos) |
| Animación de arranque (Plymouth) | `usr/share/plymouth/themes/coucou/` |
| Rehacer la imagen de arranque si cambia la animación | `usr/share/libalpm/hooks/coucou-plymouth.hook` |

## Cosas a tener en cuenta

- **Varias pantallas**: bloqueo, inicio de sesión y apagar muestran la contraseña y los botones
  solo en la pantalla principal; las demás, el fondo.
- **Plasma 6.8**: la pantalla de bloqueo y el diálogo de apagar salen del *shell*, no del tema
  global. `lockscreen-sync` arma una copia del shell en la cuenta con los de Coucou. Con una
  versión de Plasma no probada deja los de Plasma (ver `PROBADO` en `lockscreen-sync`).
- **El programa de la barra** (`usr/bin/coucou`) viene compilado: sus fallos se esquivan desde
  afuera (lanzador, filtro de Wayland, efecto de KWin). Si se consigue su código, conviene
  arreglarlos ahí.
- `bin/coucou-instalador` (la ventana del instalador) también viene compilado.
- **La Tienda** instala cada app desde Flathub o nativa (repositorios o AUR): la ficha deja elegir y
  dice de dónde vino. No deja instalar algo que ya está (de otra forma), y si hay dos copias
  (Flathub de usuario y del equipo, o Flathub y nativa) lo avisa y ofrece quitar una: dos copias se
  pelean (AnyDesk abierto dos veces). El instalador usa lo mismo para su página "Aplicaciones": lo
  que dice `apps.conf` (AnyDesk, VS Code: AUR; VLC, Discord: repositorios; Spotify: Flathub), y si la
  nativa falla, Flathub. Para que una app quede andando sola después de instalarla, se agrega su caso
  en `arreglar()` de `tienda-nativo-root` (vale igual si vino de Flathub o nativa).
- **Configuración** (`usr/lib/coucou/win11-settings`) viene compilada y su código C++ no está aquí,
  pero sus páginas sí (`configuracion/`, sacadas del programa): se cambian como cualquier QML. Lo que
  hacen lo pide al programa (`backend.…`: `launch`, `kconfigRead`, `iconThemes`…), así que una página
  nueva puede usar todo eso y los scripts de `usr/lib/coucou/`. Para probar una página sin instalar:
  `fuente/construir.sh`, copiar `coucou-claro/usr/share/coucou/configuracion.rcc` y
  `coucou-claro/usr/lib/coucou/libcoucou-configuracion.so` a una carpeta **sin espacios** (p. ej.
  `/tmp`: LD_PRELOAD corta en los espacios) y abrir Configuración (cerrada antes: es de una sola
  ventana) con `COUCOU_PAGINAS=/tmp/configuracion.rcc LD_PRELOAD=/tmp/libcoucou-configuracion.so
  QML_DISABLE_DISK_CACHE=1 /usr/lib/coucou/win11-settings "personalization/Iconos"`.

## Widgets

Son widgets de Plasma para el escritorio (`fuente/coucou-claro/usr/share/plasma/plasmoids/org.coucou.*`),
hechos en QML, sin compilar nada. Todos usan lo común de `usr/lib/qt6/qml/org/coucou/widgets/`:

- `Tarjeta`: el fondo (degradé con manchas de color difuminadas, grano, borde con luz, sombra, o una
  imagen difuminada) y los colores para dibujar encima (`colorTexto`, `colorAcento`, `colorVidrio`…).
- `Paletas`: los colores que se eligen en cada widget («Color»): `coucou` sigue el énfasis y el modo
  claro/oscuro; `original`, los del diseño de ese widget; o uno fijo.
- `Escala`: lo de adentro se diseña a un tamaño fijo (170 × 170, o 360 × 170 los anchos) y se agranda
  con el widget. Para que se vea nítido: `Texto` en vez de `Text`, `Lienzo` en vez de `Canvas`, y
  pasarle `k: e.k` (el de la Escala) a `Lienzo`, `Vidrio`, `PixelArte` y `PixelTexto`.
- `Vidrio` (botón), `PixelArte` y `PixelTexto` (dibujos y letras de pixeles), `ConfigColor` (el
  selector de color de la configuración).

Para uno nuevo: `fuente/nuevo-widget.sh <id> "<Nombre>" "<Descripción>" <icono> <categoría> [opciones]`,
escribir su `contents/ui/main.qml` y `ConfigGeneral.qml` (sirve de ejemplo cualquiera de los que hay),
probarlo con `fuente/probar-widget.sh <id>` y agregarlo a la lista de `configuracion/qml/WidgetsPage.qml`.

## Centro de control

Un panel flotante (`usr/share/coucou/control/`, QML sin compilar) que se abre con Meta+C, desde el
menú o con `coucou-control`. Está hecho de **bloques** (`bloques/`: Música, Wi-Fi, Bluetooth, Botones,
Brillo, Volumen, Energía, Proyectar, Teléfono, Modo juego) y **vistas** que se abren dentro del mismo panel
(`vistas/`: Wi-Fi, Bluetooth, Sonido, Energía, Agregar, Ajustes). `Sistema.qml` tiene el estado del
equipo y lo que se puede hacer; `Redondo`, `Pildora`, `Deslizador`, `Encabezado` y `Fila` son las piezas.

- Es **apaisado**: una grilla de 4, 6 u 8 columnas (128 px cada una; "Ancho del panel") y filas de
  72 px. Cada bloque ocupa las columnas × filas que se le den, entre el mínimo y el máximo de su tipo
  (`tipos` en `main.qml`: `minAn`/`maxAn`/`minAl`/`maxAl`). Se acomodan en orden en el primer lugar
  libre; fuera de la edición, un bloque con lugar libre a su derecha se estira hasta llenarlo.
- Cada bloque se dibuja según su **ancho y alto reales**, no según sus columnas: la píldora pasa a
  solo el círculo (angosta) o a tarjeta (alta); brillo y volumen, a deslizador vertical (alto y
  angosto) o con nombre y porcentaje (alto y ancho); la música tiene forma chica, compacta, ancha y
  grande; los botones entran los que quepan. Las cosas tienen tope (círculos de 64 px, deslizador
  de 72, carátula de 220): con lugar de sobra se separan, no se agrandan.
- Para uno nuevo: el archivo en `bloques/` y una línea en `tipos` de `main.qml`.
- Lo que abre el panel (Configuración, capturas…) pasa por `Sistema.comando()`, que quita
  `QT_WAYLAND_SHELL_INTEGRATION=layer-shell`: heredado, esas apps se abrían a pantalla completa y
  sin poder minimizarse.
- El orden y los tamaños los guarda cada cuenta en `~/.config/coucou/control.conf` (clave `grilla`).
- Para probar sin instalar: `coucou-control editar` (o `wifi`, `sonido`…) usa lo instalado; para los
  archivos del proyecto, `QML_IMPORT_PATH` con `org/coucou/widgets` del proyecto y
  `QT_WAYLAND_SHELL_INTEGRATION=layer-shell /usr/lib/qt6/bin/qml fuente/coucou-claro/usr/share/coucou/control/main.qml`.

## Transiciones entre vistas (elementos compartidos)

El Centro de control y Configuración cambian de vista con transiciones "de héroe": lo que está en
las dos vistas viaja de un lugar al otro (posición, tamaño y color) en vez de desaparecer y aparecer.

- **Centro de control** (`control/main.qml`, `heroe`): al abrir un bloque, el círculo con el ícono
  y el título (`objectName: "heroIcono"` / `"heroTitulo"` en `Pildora.qml`) viajan al encabezado de
  la vista (`Encabezado.qml`, con su `icono`), y el fondo del bloque crece hasta llenar el panel
  (`morfo`). Al volver, todo regresa a su bloque. Para que un bloque nuevo haga lo mismo, sus
  elementos llevan esos `objectName`.
- **Configuración** (`configuracion/qml/Main.qml`, `content`): dos capas se turnan, así la página
  nueva entra mientras la anterior se va (hacia adentro, desde la derecha; hacia atrás, al revés). El
  título de la tarjeta tocada (`SettingsCard`, `"heroTitulo"`) viaja al título de la página
  (`PageHeader`, `"heroDestino"`) y al volver regresa a su tarjeta.
- Los héroes se dibujan en una capa encima de todo y copian los colores (no los toman de los
  elementos, que pueden cerrarse mientras viajan).

### La barra (Mochi)

La barra es una página web compilada adentro de `/usr/bin/coucou`. `libcoucou-web.so`
(`codigo/coucou-web.c`, precargada por `coucou-launch`) le suma `usr/share/coucou/web/mochi.css` y
`mochi.js`:

- **Abrir/cerrar el panel del mochi**: View Transitions de WebKit.
  Abriendo, el botón del mochi se transforma en el panel y el dibujito viaja del dock a su lugar;
  cerrando, el panel se encoge hacia el botón y el mochi vuelve (con la animación de la barra).
  Mientras dura, la isla queda fija donde va a quedar y los cuadros de la barra se pausan (si no,
  la transición iba a saltos).
- **La flechita** de los paneles sale ya apuntando a su botón (la barra la deslizaba).
- **Los demás paneles** (buscador, juegos, notificaciones, "en segundo plano"): cada uno nace de
  su botón y vuelve a él al cerrarse, en vez de viajar desde el centro; con la isla abierta, pasar
  de uno a otro hace que el de antes vuelva a su botón y el nuevo nazca del suyo (por separado:
  estirar un panel hasta el otro deformaba el contenido). El tamaño final de cada panel lo calcula
  la barra adentro; `mochi.js` lo aprende la primera vez que se abre (si no lo sabe, espera oculto
  a que la barra lo acomode). El dibujito del mochi solo viaja con el panel del mochi.
- **El botón de Wi-Fi / volumen / batería** abre el Centro de control de Coucou (`coucou-control
  barra=abajo margen=… derecha=…`, apoyado sobre la barra y alineado con el botón) en vez del panel
  propio de la barra, vestido como los paneles de la barra (sus colores, que le pasa la página, y
  la flechita apuntando al botón). La página se lo pide a `libcoucou-web.so` por
  `window.webkit.messageHandlers.coucou` (solo acepta ese pedido).
- **El foco al cerrar un panel**: si se escribió en un panel (buscador, recordatorio…), la barra
  queda como ventana activa y el botón de una app del dock la traía en vez de minimizarla. Al
  cerrarse un panel, `mochi.js` pide (por `libcoucou-web.so`) `usr/lib/coucou/devolver-foco`, que
  corre `usr/share/coucou/web/foco.js` en KWin: activa la ventana de adelante.
- **"Abrir Coucou Code (pantalla completa)"**: el panel queda quieto mientras carga la ventana; el
  efecto de KWin `coucou-barra` la hace crecer desde el panel (y al cerrarla, encogerse hacia el
  dock), y el panel se desvanece encima.
- Para probar otro script sin instalar: `COUCOU_WEB_JS=… COUCOU_WEB_CSS=… COUCOU_WEB_CONSOLA=1
  LD_PRELOAD=/ruta/a/libcoucou-web.so /usr/bin/coucou`. `COUCOU_SIN_TRANSICIONES=1` en
  `~/.config/coucou/entorno` las apaga.
- Depende de cómo está armada la página de la barra (`#island`, `#content`, `.mb-mochi`,
  `#bot-canvas`, `.hdr-expand`): si una versión nueva de Coucou cambia eso, las transiciones no
  se hacen y la barra sigue andando como siempre.
