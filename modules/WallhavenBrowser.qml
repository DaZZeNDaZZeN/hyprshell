import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Browse, preview, download and apply wallpapers from wallhaven.cc.
Variants {
    model: Quickshell.screens

    PanelOverlay {
        id: win
        required property var modelData
        screen: modelData
        name: "wallhaven"
        scrimOpacity: 0.5
        property var preview: null
        onOpenChanged: {
            if (open) { if (Wallhaven.results.length === 0) Wallhaven.search(); search.forceActiveFocus(); }
            else preview = null;
        }
        onVisibleChanged: if (!visible) pv.pvLast = null

        component Pill: Chip { Layout.alignment: Qt.AlignVCenter }

        PopupCard {
            id: card
            shown: win.open
            width: Math.min(parent.width - 80, 1180); height: Math.min(parent.height - 80, 760)
            anchors.centerIn: parent
            slideY: 20
            clip: true

            ColumnLayout {
                anchors { fill: parent; margins: 16 }
                spacing: 10
                RowLayout {
                    Layout.fillWidth: true; spacing: 10
                    Icon { text: "\uf03e"; tint: Theme.accent; font.pixelSize: 20 }
                    Label { text: "Wallhaven"; font.pixelSize: Theme.fsL; font.weight: Font.DemiBold }
                    TextField {
                        id: search
                        Layout.fillWidth: true
                        glyph: "\uf002"; placeholder: "Search wallpapers…"
                        onAccepted: { Wallhaven.query = text; Wallhaven.search(); }
                        input.Keys.onEscapePressed: { if (win.preview) win.preview = null; else Panels.close(); }
                    }
                    Button { text: "Search"; primary: true; onClicked: { Wallhaven.query = search.text; Wallhaven.search(); } }
                    IconButton { glyph: "\uf00d"; size: 34; iconSize: 14; onClicked: Panels.close() }
                }
                Flickable {
                    Layout.fillWidth: true; Layout.preferredHeight: 34
                    contentWidth: filters.implicitWidth; clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Row {
                        id: filters; spacing: 8
                        Chip { text: "General"; active: Wallhaven.general; onClicked: { Wallhaven.general = !Wallhaven.general; Wallhaven.search(); } }
                        Chip { text: "Anime"; active: Wallhaven.anime; onClicked: { Wallhaven.anime = !Wallhaven.anime; Wallhaven.search(); } }
                        Chip { text: "People"; active: Wallhaven.people; onClicked: { Wallhaven.people = !Wallhaven.people; Wallhaven.search(); } }
                        Rectangle { width: 1; height: 24; color: Theme.border; anchors.verticalCenter: parent.verticalCenter }
                        Chip { text: "Sketchy"; active: Wallhaven.sketchy; onClicked: { Wallhaven.sketchy = !Wallhaven.sketchy; Wallhaven.search(); } }
                        Chip { text: "NSFW"; visible: Config.o.wallhavenApiKey !== ""; active: Wallhaven.nsfw; onClicked: { Wallhaven.nsfw = !Wallhaven.nsfw; Wallhaven.search(); } }
                        Rectangle { width: 1; height: 24; color: Theme.border; anchors.verticalCenter: parent.verticalCenter }
                        Chip { glyph: "\uf0dc"; text: "Sort: " + Wallhaven.sorting.replace("_", " ")
                            onClicked: { const l = Wallhaven.sortings; Wallhaven.sorting = l[(l.indexOf(Wallhaven.sorting) + 1) % l.length]; Wallhaven.search(); } }
                        Chip { visible: Wallhaven.sorting === "toplist"; glyph: "\uf017"; text: "Range: " + Wallhaven.toplistRange
                            onClicked: { const l = ["1d", "3d", "1w", "1M", "3M", "6M", "1y"]; Wallhaven.toplistRange = l[(l.indexOf(Wallhaven.toplistRange) + 1) % l.length]; Wallhaven.search(); } }
                        Chip { glyph: "\uf108"; text: "Min: " + (Wallhaven.atleast || "any")
                            onClicked: { const l = Wallhaven.resolutions; Wallhaven.atleast = l[(l.indexOf(Wallhaven.atleast) + 1) % l.length]; Wallhaven.search(); } }
                        Chip { glyph: "\uf0b2"; text: "Ratio: " + (Wallhaven.ratios || "any")
                            onClicked: { const l = Wallhaven.ratioList; Wallhaven.ratios = l[(l.indexOf(Wallhaven.ratios) + 1) % l.length]; Wallhaven.search(); } }
                    }
                }

                GridView {
                    id: grid
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true
                    readonly property int cols: Math.max(2, Math.floor(width / 250))
                    cellWidth: Math.floor(width / cols); cellHeight: Math.round(cellWidth * 0.62)
                    model: win.visible ? Wallhaven.model : null
                    boundsBehavior: Flickable.StopAtBounds
                    onAtYEndChanged: if (atYEnd && count > 0) Wallhaven.more()
                    delegate: Item {
                        id: cell
                        required property int index
                        readonly property var itemData: Wallhaven.results[index] ?? ({ id: "", path: "", thumbs: { large: "", original: "" }, resolution: "", favorites: 0, file_size: 0, category: "" })
                        width: grid.cellWidth; height: grid.cellHeight
                        readonly property bool have: itemData.path ? Wallhaven.isDownloaded(itemData) : false
                        readonly property bool busy: Wallhaven.downloading === itemData.id
                        Rectangle {
                            anchors { fill: parent; margins: 5 }
                            radius: Theme.radiusS + 2; color: Theme.surface2; clip: true
                            scale: gm.pressed ? 0.97 : (gm.containsMouse ? 1.02 : 1)
                            Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
                            Image {
                                id: th
                                anchors.fill: parent
                                source: cell.itemData.thumbs.large
                                fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false
                                sourceSize: Qt.size(400, 260)
                                opacity: status === Image.Ready ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: Theme.anim } }
                            }
                            Rectangle {
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                height: 34; color: "#99000000"
                                opacity: gm.containsMouse || cell.have ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                                Label { x: 10; anchors.verticalCenter: parent.verticalCenter; text: cell.itemData.resolution; color: "white"; font.pixelSize: Theme.fsS }
                                Row { anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter } spacing: 4
                                    Icon { visible: cell.have; text: "\uf00c"; tint: Theme.ok; font.pixelSize: 12 }
                                    Label { text: "\uf005 " + cell.itemData.favorites; color: "white"; font.pixelSize: Theme.fsS; font.family: Theme.iconFont }
                                }
                            }
                            Rectangle { anchors.fill: parent; color: "#aa000000"; visible: cell.busy
                                Label { anchors.centerIn: parent; text: "Downloading…"; color: "white" } }
                            MouseArea { id: gm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.preview = cell.itemData }
                        }
                    }
                    Label { anchors.centerIn: parent; visible: Wallhaven.loading && Wallhaven.results.length === 0; text: "Loading…"; color: Theme.subtext }
                    Label { anchors.centerIn: parent; visible: !Wallhaven.loading && Wallhaven.results.length === 0 && Wallhaven.error === ""; text: "No results"; color: Theme.subtext }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: Wallhaven.error !== "" ? Wallhaven.error : (Wallhaven.loading ? "Loading…" : Wallhaven.results.length + " of " + Wallhaven.total + " wallpapers"); color: Wallhaven.error !== "" ? Theme.danger : Theme.subtext; font.pixelSize: Theme.fsS; Layout.fillWidth: true }
                    Label { text: "Downloads go to " + Config.o.wallpaperDir; color: Theme.subtext; font.pixelSize: Theme.fsS }
                }
            }

            // ---------- preview ----------
            Rectangle {
                id: pv
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.78)
                opacity: win.preview ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: Theme.anim } }
                MouseArea { anchors.fill: parent; onClicked: win.preview = null }
                property var item: win.preview ?? pvLast
                property var pvLast: null
                onItemChanged: if (win.preview) pvLast = win.preview

                Rectangle {
                    id: frame
                    anchors { centerIn: parent; verticalCenterOffset: -24 }
                    width: parent.width - 120; height: parent.height - 160
                    radius: Theme.radius; color: Theme.surface; clip: true
                    scale: win.preview ? 1 : 0.94
                    Behavior on scale { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutQuint } }
                    Image {
                        anchors.fill: parent
                        source: pv.visible && pv.item ? pv.item.thumbs.original : ""
                        fillMode: Image.PreserveAspectFit; asynchronous: true; cache: false
                    }
                    MouseArea { anchors.fill: parent }
                }
                Row {
                    anchors { top: frame.bottom; topMargin: 14; horizontalCenter: parent.horizontalCenter }
                    spacing: 10
                    Label { anchors.verticalCenter: parent.verticalCenter; color: "white"; text: pv.item ? pv.item.resolution + " · " + (pv.item.file_size / 1048576).toFixed(1) + " MB · " + pv.item.category : "" }
                    Button { glyph: "\uf019"; text: Wallhaven.downloading ? "Downloading…" : "Download"; onClicked: Wallhaven.download(pv.item, false) }
                    Button { glyph: "\uf03e"; text: "Set as wallpaper"; primary: true; onClicked: { const it = pv.item; if (Wallhaven.isDownloaded(it)) Wallpaper.apply(Wallhaven.localPath(it)); else Wallhaven.download(it, true); } }
                    Button { glyph: "\uf00d"; text: "Close"; onClicked: win.preview = null }
                }
            }
        }
    }
}
