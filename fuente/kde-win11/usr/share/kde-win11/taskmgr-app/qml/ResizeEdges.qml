import QtQuick

// Bordes para redimensionar una ventana sin marco (los gestiona el compositor con startSystemResize)
Item {
    id: root
    property var window: Window.window
    property int grip: 6
    anchors.fill: parent
    visible: window && window.visibility !== Window.Maximized && window.visibility !== Window.FullScreen
    z: 1000

    component Edge: MouseArea {
        property int edges
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onPressed: root.window.startSystemResize(edges)
    }
    Edge { edges: Qt.LeftEdge; x: 0; y: root.grip; width: root.grip; height: parent.height - 2 * root.grip; cursorShape: Qt.SizeHorCursor }
    Edge { edges: Qt.RightEdge; x: parent.width - root.grip; y: root.grip; width: root.grip; height: parent.height - 2 * root.grip; cursorShape: Qt.SizeHorCursor }
    Edge { edges: Qt.TopEdge; x: root.grip; y: 0; width: parent.width - 2 * root.grip; height: root.grip / 2; cursorShape: Qt.SizeVerCursor }
    Edge { edges: Qt.BottomEdge; x: root.grip; y: parent.height - root.grip; width: parent.width - 2 * root.grip; height: root.grip; cursorShape: Qt.SizeVerCursor }
    Edge { edges: Qt.LeftEdge | Qt.TopEdge; x: 0; y: 0; width: root.grip; height: root.grip; cursorShape: Qt.SizeFDiagCursor }
    Edge { edges: Qt.RightEdge | Qt.TopEdge; x: parent.width - root.grip; y: 0; width: root.grip; height: root.grip; cursorShape: Qt.SizeBDiagCursor }
    Edge { edges: Qt.LeftEdge | Qt.BottomEdge; x: 0; y: parent.height - root.grip; width: root.grip; height: root.grip; cursorShape: Qt.SizeBDiagCursor }
    Edge { edges: Qt.RightEdge | Qt.BottomEdge; x: parent.width - root.grip; y: parent.height - root.grip; width: root.grip; height: root.grip; cursorShape: Qt.SizeFDiagCursor }
}
