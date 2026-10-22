import QtQuick
import QtQuick.Controls

// Tabla del Administrador de tareas: encabezados que ordenan (con el total encima en Procesos),
// filas de 32 px, mapa de calor en las columnas numéricas, grupos plegables y selección.
// Cada página da las columnas y funciones para leer cada fila.
ListView {
    id: table
    // [{ title, width (0 = rellenar), align: "left"|"right", sort: n, total: "", heat: bool }]
    property var columns: []
    property int sortColumn: -1
    property bool sortDescending: false
    property string selectedKey: ""
    property bool twoLineHeader: false
    property int minFill: 220
    // Lectura de filas (row = model en modelos de C++ o modelData en listas)
    property var cellText: function (row, i) { return "" }
    property var cellHeat: function (row, i) { return -1 }
    property var rowKey: function (row) { return row.key }
    property var rowIcon: function (row) { return "" }
    property var rowKind: function (row) { return 1 }
    property var rowDepth: function (row) { return 0 }
    property var rowExpandable: function (row) { return false }
    property var rowExpanded: function (row) { return false }
    property var rowEfficiency: function (row) { return false }

    signal sortRequested(int sort)
    signal rowActivated(var row)
    signal rowToggled(var row)
    signal rowSelected(var row)
    signal rowMenu(var row)

    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.AutoFlickIfNeeded
    reuseItems: true
    cacheBuffer: 400
    ScrollBar.vertical: ScrollBar {}
    ScrollBar.horizontal: ScrollBar {}

    readonly property real fixedWidth: {
        var w = 0
        for (var i = 0; i < columns.length; ++i) w += columns[i].width || 0
        return w
    }
    readonly property real fillWidth: Math.max(minFill, width - fixedWidth - 12)
    contentWidth: fixedWidth + fillWidth + 12
    function colWidth(i) { return columns[i].width || fillWidth }

    // Guarda el desplazamiento cuando el modelo se reconstruye (procesos nuevos o cerrados)
    property real savedY: 0
    Connections {
        target: table.model && table.model.modelAboutToBeReset ? table.model : null
        ignoreUnknownSignals: true
        function onModelAboutToBeReset() { table.savedY = table.contentY }
        function onModelReset() { table.contentY = Math.min(table.savedY, Math.max(0, table.contentHeight - table.height)) }
    }

    headerPositioning: ListView.OverlayHeader
    header: Rectangle {
        z: 3
        width: table.contentWidth
        height: table.twoLineHeader ? 56 : 36
        color: win.layer
        Row {
            x: 6
            height: parent.height
            Repeater {
                model: table.columns
                Item {
                    width: table.colWidth(index)
                    height: parent.height
                    readonly property bool sorted: modelData.sort !== undefined && modelData.sort === table.sortColumn
                    Rectangle {
                        anchors.fill: parent
                        color: hdr.containsMouse ? win.hover : "transparent"
                    }
                    // Flecha de orden, centrada arriba como en Windows
                    FluentIcon {
                        visible: parent.sorted
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 1
                        name: table.sortDescending ? "chevronDown" : "chevronUp"
                        size: 10
                        stroke: 1.6
                        color: win.subtext
                    }
                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        anchors.bottomMargin: 7
                        spacing: 0
                        Label {
                            width: parent.width
                            visible: table.twoLineHeader && (modelData.total || "") !== ""
                            text: modelData.total || ""
                            horizontalAlignment: modelData.align === "right" ? Text.AlignRight : Text.AlignLeft
                            font.pixelSize: 16
                            color: win.text
                        }
                        Label {
                            width: parent.width
                            text: modelData.title
                            elide: Text.ElideRight
                            horizontalAlignment: modelData.align === "right" ? Text.AlignRight : Text.AlignLeft
                            font.pixelSize: 12
                            color: win.subtext
                        }
                    }
                    Rectangle {   // separador
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.topMargin: 8
                        anchors.bottomMargin: 8
                        width: 1
                        color: win.divider
                    }
                    MouseArea {
                        id: hdr
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: modelData.sort !== undefined
                        onClicked: table.sortRequested(modelData.sort)
                    }
                }
            }
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: win.divider }
    }

    delegate: Item {
        id: rowItem
        required property int index
        required property var model
        readonly property var row: model.modelData !== undefined ? model.modelData : model
        readonly property int kind: table.rowKind(row)
        readonly property string key: table.rowKey(row)
        readonly property bool isSelected: kind > 0 && key === table.selectedKey
        width: table.contentWidth
        height: kind === 0 ? 44 : 32

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            radius: 4
            visible: rowItem.kind > 0
            color: rowItem.isSelected ? win.selection : (rowMouse.containsMouse ? win.hover : "transparent")
        }
        // Barrita de selección a la izquierda
        Rectangle {
            visible: rowItem.isSelected
            x: 4; width: 3; height: 16; radius: 1.5
            anchors.verticalCenter: parent.verticalCenter
            color: win.accent
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            enabled: rowItem.kind > 0
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: function (mouse) {
                table.rowSelected(rowItem.row)
                if (mouse.button === Qt.RightButton) table.rowMenu(rowItem.row)
            }
            onDoubleClicked: table.rowActivated(rowItem.row)
        }

        // Cabecera de sección: "Aplicaciones (5)"
        Label {
            visible: rowItem.kind === 0
            x: 16
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            text: rowItem.kind === 0 ? table.cellText(rowItem.row, 0) : ""
            font.pixelSize: 14
            font.weight: Font.DemiBold
            color: win.text
        }

        Row {
            visible: rowItem.kind > 0
            x: 6
            height: parent.height
            Repeater {
                model: rowItem.kind > 0 ? table.columns.length : 0
                Item {
                    width: table.colWidth(index)
                    height: rowItem.height
                    readonly property real heatValue: table.columns[index].heat ? table.cellHeat(rowItem.row, index) : -1
                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: 0.5
                        anchors.bottomMargin: 0.5
                        visible: parent.heatValue >= 0
                        color: win.heat(parent.heatValue)
                    }
                    // Primera columna: sangría, flecha de grupo, icono y nombre
                    Row {
                        visible: index === 0
                        anchors.verticalCenter: parent.verticalCenter
                        x: 8 + table.rowDepth(rowItem.row) * 28
                        width: parent.width - x - 8
                        spacing: 8
                        Item {
                            width: 16; height: 16
                            anchors.verticalCenter: parent.verticalCenter
                            FluentIcon {
                                anchors.centerIn: parent
                                visible: table.rowExpandable(rowItem.row)
                                name: table.rowExpanded(rowItem.row) ? "chevronDown" : "chevronRight"
                                size: 12
                                stroke: 1.6
                            }
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
                                enabled: table.rowExpandable(rowItem.row)
                                onClicked: table.rowToggled(rowItem.row)
                            }
                        }
                        Image {
                            width: 16; height: 16
                            anchors.verticalCenter: parent.verticalCenter
                            visible: source != ""
                            source: table.rowIcon(rowItem.row) ? "image://icon/" + table.rowIcon(rowItem.row) : ""
                            sourceSize: Qt.size(32, 32)
                            asynchronous: true
                        }
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 48
                            text: index === 0 ? table.cellText(rowItem.row, 0) : ""
                            elide: Text.ElideRight
                            color: win.text
                            font.pixelSize: 13
                        }
                    }
                    Row {
                        visible: index > 0
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: table.columns[index].align === "right" ? parent.right : undefined
                        anchors.left: table.columns[index].align === "right" ? undefined : parent.left
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 6
                        // Hoja verde del modo de eficiencia en la columna Estado
                        FluentIcon {
                            visible: table.columns[index].status === true && table.rowEfficiency(rowItem.row)
                            anchors.verticalCenter: parent.verticalCenter
                            name: "leaf"
                            size: 14
                            color: win.dark ? "#6CCB5F" : "#0F7B0F"
                        }
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: index > 0 ? table.cellText(rowItem.row, index) : ""
                            width: Math.min(implicitWidth, table.colWidth(index) - 20)
                            elide: Text.ElideRight
                            color: win.text
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }

    }
}
