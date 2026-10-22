pragma Singleton
import QtQuick

// Coucou: los colores de los widgets. Cada widget elige uno en su configuración ("Color"):
//   coucou    el énfasis y el modo claro/oscuro de Coucou (cambia solo con los de Configuración)
//   original  los de la foto de diseño de ese widget (los define cada widget)
//   oscuro, claro, violeta, azul, verde, rojo, naranja, rosa, petroleo   uno fijo
QtObject {
    readonly property var lista: [
        { id: "coucou", nombre: "Coucou (sigue el énfasis y el modo)" },
        { id: "original", nombre: "Como en el diseño original" },
        { id: "oscuro", nombre: "Oscuro" }, { id: "claro", nombre: "Claro" },
        { id: "violeta", nombre: "Violeta" }, { id: "azul", nombre: "Azul" }, { id: "petroleo", nombre: "Petróleo" },
        { id: "verde", nombre: "Verde" }, { id: "rojo", nombre: "Rojo" }, { id: "naranja", nombre: "Naranja" },
        { id: "rosa", nombre: "Rosa" }
    ]

    readonly property var fijas: ({
        "oscuro":   { arriba: "#26262B", abajo: "#121215", acento: "#FFFFFF", manchas: ["#3A3A44", "#1C1C22"], texto: "#FFFFFF" },
        "claro":    { arriba: "#FFFFFF", abajo: "#ECEAF4", acento: "#5B4BD5", manchas: ["#E3DEFF", "#F5F0FF"], texto: "#1D1B33", claro: true },
        "violeta":  { arriba: "#6B39E8", abajo: "#9A2FD8", acento: "#FFFFFF", manchas: ["#38C6F4", "#C04BE3"], texto: "#FFFFFF" },
        "azul":     { arriba: "#2563EB", abajo: "#1E3A8A", acento: "#FFFFFF", manchas: ["#38BDF8", "#1D4ED8"], texto: "#FFFFFF" },
        "petroleo": { arriba: "#24465A", abajo: "#173040", acento: "#3FA8E0", manchas: ["#2E5A70", "#1A3A4C"], texto: "#FFFFFF" },
        "verde":    { arriba: "#063D22", abajo: "#021A0E", acento: "#16E07A", manchas: ["#0B5C33", "#04140B"], texto: "#FFFFFF" },
        "rojo":     { arriba: "#E53935", abajo: "#A61B1B", acento: "#FFFFFF", manchas: ["#FF6B5B", "#8E1414"], texto: "#FFFFFF" },
        "naranja":  { arriba: "#F97316", abajo: "#C2410C", acento: "#FFFFFF", manchas: ["#FDBA74", "#9A3412"], texto: "#FFFFFF" },
        "rosa":     { arriba: "#EC4899", abajo: "#9D174D", acento: "#FFFFFF", manchas: ["#F9A8D4", "#831843"], texto: "#FFFFFF" }
    })

    function luz(c) { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b }
    function mezcla(a, b, f) { return Qt.rgba(a.r + (b.r - a.r) * f, a.g + (b.g - a.g) * f, a.b + (b.b - a.b) * f, 1) }

    // Devuelve { arriba, abajo, acento, manchas, texto, claro }
    function resolver(estilo, original, enfasis, fondo) {
        var p
        if (estilo === "original" && original && original.arriba)
            p = original
        else if (fijas[estilo])
            p = fijas[estilo]
        else {
            // Coucou: el énfasis sobre el fondo del modo (oscuro: noche violeta; claro: lavanda)
            var oscuroModo = luz(fondo) < 0.5
            var e = Qt.color(enfasis)
            if (oscuroModo) {
                p = { arriba: mezcla(Qt.color("#1B1844"), e, 0.30), abajo: mezcla(Qt.color("#0B0A20"), e, 0.12),
                      acento: Qt.lighter(e, 1.25), manchas: [Qt.alpha(e, 0.9), Qt.alpha(Qt.lighter(e, 1.5), 0.55)], texto: "#FFFFFF" }
            } else {
                p = { arriba: mezcla(Qt.color("#FFFFFF"), e, 0.10), abajo: mezcla(Qt.color("#F1EEFE"), e, 0.22),
                      acento: Qt.darker(e, 1.15), manchas: [Qt.alpha(e, 0.35), Qt.alpha(Qt.lighter(e, 1.4), 0.4)], texto: "#1D1B33", claro: true }
            }
        }
        return { arriba: p.arriba, abajo: p.abajo || p.arriba, acento: p.acento || p.texto || "#FFFFFF",
                 manchas: p.manchas || [], texto: p.texto || "#FFFFFF", claro: !!p.claro }
    }
}
