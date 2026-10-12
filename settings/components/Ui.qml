pragma Singleton
import QtQuick

// Window-wide state shared by the sidebar, the pages and the search.
QtObject {
    id: ui

    property string page: backend.lastPage
    onPageChanged: backend.lastPage = page

    property string query: ""            // the sidebar search
    property string keybindFilter: ""    // what the Keybinds page filters by

    readonly property string iconFamily: "Font Awesome 7 Free Solid"
    readonly property bool hasIcons: Qt.fontFamilies().indexOf(iconFamily) >= 0
    readonly property color danger: "#e5867f"

    // Sidebar order. Icons are Font Awesome code points.
    readonly property var pages: [
        { key: "home", label: "Home", icon: "", group: "" },
        { key: "wallpapers", label: "Wallpapers", icon: "", group: "Look" },
        { key: "presets", label: "Presets", icon: "", group: "Look" },
        { key: "appearance", label: "Appearance", icon: "", group: "Look" },
        { key: "animations", label: "Animations", icon: "", group: "Look" },
        { key: "bar", label: "Bar", icon: "", group: "Desktop" },
        { key: "notifications", label: "Notifications", icon: "", group: "Desktop" },
        { key: "displays", label: "Displays", icon: "", group: "Desktop" },
        { key: "input", label: "Keyboard & mouse", icon: "", group: "Desktop" },
        { key: "keybinds", label: "Keybinds", icon: "", group: "Desktop" },
        { key: "apps", label: "Apps", icon: "", group: "System" },
        { key: "startup", label: "Startup", icon: "", group: "System" },
        { key: "idle", label: "Idle", icon: "", group: "System" }
    ]

    function pageLabel(key) {
        for (var i = 0; i < pages.length; i++)
            if (pages[i].key === key) return pages[i].label
        return key
    }

    // Every SettingRow adds itself here, so search can find it and the toast can name it.
    property var rows: []
    function register(row) { rows.push(row) }
    function unregister(row) {
        var i = rows.indexOf(row)
        if (i >= 0) rows.splice(i, 1)
    }
    function titleFor(key) {
        for (var i = 0; i < rows.length; i++)
            if (rows[i].key === key) return rows[i].title
        return { monitor: "Display", kb_layout: "Keyboard layouts", browser: "Browser",
                 terminal: "Terminal" }[key] || key
    }

    // Open a page and bring a row into view.
    function show(row) {
        query = ""
        page = row.pageKey
        Qt.callLater(function() {
            if (row.pageScroll) row.pageScroll.scrollTo(row)
            row.flash()
        })
    }

    function search(text) {
        var q = text.trim().toLowerCase()
        if (q === "") return []
        var out = []
        for (var i = 0; i < pages.length; i++)
            if (pages[i].label.toLowerCase().indexOf(q) >= 0)
                out.push({ kind: "page", title: pages[i].label, detail: "Page", page: pages[i].key })
        for (var j = 0; j < rows.length; j++) {
            var r = rows[j]
            var hay = (r.title + " " + r.hint + " " + r.section + " " + pageLabel(r.pageKey)).toLowerCase()
            if (hay.indexOf(q) >= 0)
                out.push({ kind: "row", title: r.title, detail: pageLabel(r.pageKey) + (r.hint ? " · " + r.hint : ""), row: r })
        }
        var groups = backend.keybinds
        for (var g = 0; g < groups.length; g++)
            for (var b = 0; b < groups[g].binds.length; b++) {
                var bind = groups[g].binds[b]
                if ((groups[g].title + " " + bind.keys + " " + bind.action).toLowerCase().indexOf(q) >= 0)
                    out.push({ kind: "bind", title: bind.keys, detail: "Keybind · " + groups[g].title, page: "keybinds" })
            }
        return out.slice(0, 40)
    }
}
