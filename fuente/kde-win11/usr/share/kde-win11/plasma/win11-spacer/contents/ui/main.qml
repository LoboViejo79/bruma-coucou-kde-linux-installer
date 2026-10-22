import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

// Hueco flexible de la barra que, con clic derecho, muestra el menú de la barra de tareas de
// Windows 11 ("Administrador de tareas", "Configuración de la barra de tareas").
// El cálculo del tamaño es el del separador de Plasma (org.kde.plasma.panelspacer): con dos
// separadores, lo de en medio queda centrado en la pantalla y no en el hueco que sobra.
PlasmoidItem {
    id: root

    readonly property bool horizontal: Plasmoid.formFactor !== PlasmaCore.Types.Vertical
    readonly property var spacerPlugins: ["org.kde.win11.spacer", "org.kde.plasma.panelspacer"]

    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.minimumWidth: Plasmoid.containment.corona?.editMode ? Kirigami.Units.gridUnit * 2 : 1
    Layout.minimumHeight: Plasmoid.containment.corona?.editMode ? Kirigami.Units.gridUnit * 2 : 1
    Layout.preferredWidth: horizontal ? optimalSize : 0
    Layout.preferredHeight: horizontal ? 0 : optimalSize

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    property GridLayout panelLayout: {
        let candidate = root.parent;
        while (candidate) {
            if (candidate instanceof GridLayout)
                return candidate as GridLayout;
            candidate = candidate.parent;
        }
        return null;
    }

    property real optimalSize: {
        if (!panelLayout) return 1;
        let expandingSpacers = 0;
        let thisSpacerIndex = null;
        let sizeHints = [0];
        for (const child of panelLayout.children) {
            if (!child.visible)
                continue;
            const plugin = child.applet?.plasmoid?.pluginName;
            const isSpacer = plugin === "org.kde.win11.spacer"
                || (plugin === "org.kde.plasma.panelspacer" && child.applet.plasmoid.configuration.expanding);
            if (isSpacer) {
                if (child.applet.plasmoid === Plasmoid)
                    thisSpacerIndex = expandingSpacers;
                sizeHints.push(0);
                expandingSpacers += 1;
            } else if (root.horizontal) {
                sizeHints[sizeHints.length - 1] += Math.min(child.Layout.maximumWidth, Math.max(child.Layout.minimumWidth, child.Layout.preferredWidth)) + panelLayout.rowSpacing;
            } else {
                sizeHints[sizeHints.length - 1] += Math.min(child.Layout.maximumHeight, Math.max(child.Layout.minimumHeight, child.Layout.preferredHeight)) + panelLayout.columnSpacing;
            }
        }
        if (thisSpacerIndex === null) return 1;
        sizeHints[0] *= 2; sizeHints[sizeHints.length - 1] *= 2;
        // Ancho de la fila del panel (toda la barra)
        const opt = (root.horizontal ? panelLayout.width : panelLayout.height) / expandingSpacers
            - sizeHints[thisSpacerIndex] / 2 - sizeHints[thisSpacerIndex + 1] / 2;
        return Math.max(opt, 0);
    }

    // En modo edición se ve dónde está, como el separador de Plasma
    Rectangle {
        anchors.fill: parent
        color: Kirigami.Theme.highlightColor
        opacity: Plasmoid.containment.corona?.editMode ? 1 : 0.2
        visible: Plasmoid.containment.corona?.editMode ?? false
    }

    P5Support.DataSource {
        id: launcher
        engine: "executable"
        connectedSources: []
        onNewData: source => disconnectSource(source)
        function run(cmd) { connectSource(cmd) }
    }
    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: "Administrador de tareas"
            icon.name: "utilities-system-monitor"
            onTriggered: launcher.run('p="$HOME/.local/bin/win11-taskmgr"; [ -x "$p" ] && exec "$p" || exec plasma-systemmonitor')
        },
        PlasmaCore.Action {
            text: "Configuración de la barra de tareas"
            icon.name: "configure"
            onTriggered: launcher.run('p="$HOME/.local/bin/win11-settings"; [ -x "$p" ] && exec "$p" personalization || exec systemsettings')
        }
    ]
    // Solo lo de Windows en el menú (sin "Configurar" ni "Eliminar"; se puede quitar en modo edición)
    Component.onCompleted: {
        Plasmoid.removeInternalAction("configure");
        const remove = Plasmoid.internalAction("remove");
        if (remove) remove.visible = false;
    }
}
