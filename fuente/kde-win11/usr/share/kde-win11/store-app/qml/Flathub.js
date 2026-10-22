.pragma library

// Catálogo de Flathub (API pública v2). Las respuestas se guardan en memoria durante la sesión.
var API = "https://flathub.org/api/v2"
var cache = ({})

// Categorías de "Aplicaciones" con nombres como en la Microsoft Store
var appCategories = [
    { id: "Office", title: "Productividad", icon: "applications-office" },
    { id: "AudioVideo", title: "Música y vídeo", icon: "applications-multimedia" },
    { id: "Graphics", title: "Fotos y diseño", icon: "applications-graphics" },
    { id: "Network", title: "Internet y redes", icon: "applications-internet" },
    { id: "Development", title: "Desarrollo", icon: "applications-development" },
    { id: "Education", title: "Educación", icon: "applications-education" },
    { id: "Science", title: "Ciencia", icon: "applications-science" },
    { id: "System", title: "Sistema", icon: "applications-system" },
    { id: "Utility", title: "Utilidades", icon: "applications-utilities" }
]

var categoryNames = {
    office: "Productividad", audiovideo: "Música y vídeo", graphics: "Fotos y diseño",
    network: "Internet y redes", development: "Desarrollo", education: "Educación",
    science: "Ciencia", system: "Sistema", utility: "Utilidades", game: "Juegos"
}

function categoryName(c) {
    if (!c) return "Aplicación"
    if (typeof c !== "string") c = String(c[0] || "")
    return categoryNames[c.toLowerCase()] || "Aplicación"
}

function request(method, path, body, cb) {
    var key = method + path + (body ? JSON.stringify(body) : "")
    if (cache[key]) { cb(cache[key], ""); return }
    var xhr = new XMLHttpRequest()
    xhr.onreadystatechange = function () {
        if (xhr.readyState !== XMLHttpRequest.DONE) return
        if (xhr.status === 200) {
            try {
                var data = JSON.parse(xhr.responseText)
                cache[key] = data
                cb(data, "")
            } catch (e) { cb(null, "Respuesta no válida de Flathub") }
        } else {
            cb(null, xhr.status === 0 ? "Sin conexión a Internet" : "Flathub respondió " + xhr.status)
        }
    }
    xhr.open(method, API + path)
    if (body) xhr.setRequestHeader("Content-Type", "application/json")
    xhr.send(body ? JSON.stringify(body) : null)
}

// Solo apps de escritorio (la búsqueda también devuelve extensiones y runtimes)
function apps(data) {
    return (data && data.hits ? data.hits : []).filter(function (h) {
        return !h.type || h.type === "desktop-application" || h.type === "desktop" || h.type === "console-application"
    })
}

// collection: popular | trending | recently-updated | recently-added | verified
function collection(name, page, perPage, cb) {
    request("GET", "/collection/" + name + "?page=" + page + "&per_page=" + perPage, null, function (d, err) {
        cb(apps(d), d ? d.totalPages || 1 : 0, err)
    })
}

function category(cat, page, perPage, cb) {
    request("GET", "/collection/category/" + cat + "?page=" + page + "&per_page=" + perPage, null, function (d, err) {
        cb(apps(d), d ? d.totalPages || 1 : 0, err)
    })
}

function search(query, cb) {
    request("POST", "/search", { query: query, filters: [] }, function (d, err) { cb(apps(d), err) })
}

function details(appId, cb) {
    request("GET", "/appstream/" + appId, null, cb)
}

function summary(appId, cb) {
    request("GET", "/summary/" + appId, null, cb)
}

function stats(appId, cb) {
    request("GET", "/stats/" + appId, null, cb)
}

// Captura más cercana al ancho pedido
function screenshot(shot, width) {
    var best = null
    var sizes = shot && shot.sizes ? shot.sizes : []
    for (var i = 0; i < sizes.length; ++i) {
        var w = parseInt(sizes[i].width)
        if (w >= width && (!best || w < parseInt(best.width))) best = sizes[i]
    }
    if (!best && sizes.length) best = sizes[0]
    return best ? best.src : ""
}

function iconFor(appId) {
    return "https://dl.flathub.org/media/icons/128x128/" + appId + ".png"
}

function formatCount(n) {
    if (!n) return ""
    if (n >= 1000000) return (n / 1000000).toFixed(1).replace(".", ",").replace(",0", "") + " M"
    if (n >= 1000) return Math.round(n / 1000) + " mil"
    return "" + n
}

function formatDate(ts) {
    if (!ts) return ""
    var d = new Date(parseInt(ts) * 1000)
    var m = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sept", "oct", "nov", "dic"]
    return d.getDate() + " " + m[d.getMonth()] + " " + d.getFullYear()
}

function subcategory(cat, sub, page, perPage, cb) {
    request("GET", "/collection/category/" + cat + "/subcategories?subcategory=" + sub + "&page=" + page + "&per_page=" + perPage, null, function (d, err) {
        cb(apps(d), d ? d.totalPages || 1 : 0, err)
    })
}

var gameCategories = [
    { id: "ActionGame", title: "Acción" }, { id: "AdventureGame", title: "Aventura" },
    { id: "StrategyGame", title: "Estrategia" }, { id: "RolePlaying", title: "Rol" },
    { id: "Shooter", title: "Disparos" }, { id: "Simulation", title: "Simulación" },
    { id: "LogicGame", title: "Puzles" }, { id: "BoardGame", title: "Mesa" },
    { id: "CardGame", title: "Cartas" }, { id: "ArcadeGame", title: "Arcade" },
    { id: "KidsGame", title: "Niños" }, { id: "Emulator", title: "Emuladores" }
]

// Degradados de los mosaicos de categorías
var tileColors = [
    ["#0F6CBD", "#3A96DD"], ["#8E24AA", "#C239B3"], ["#C2185B", "#E8467C"],
    ["#00796B", "#26A69A"], ["#5C2D91", "#8764B8"], ["#CA5010", "#F7894A"],
    ["#2E7D32", "#5DB761"], ["#37474F", "#6B8794"], ["#B71C1C", "#E5534B"]
]
