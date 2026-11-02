import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Clipboard history with search, pinning and one-click re-copy.
Variants {
    model: Quickshell.screens

    PanelOverlay {
        id: win
        required property var modelData
        screen: modelData
        name: "clipboard"
        property int sel: 0
        readonly property var shownEntries: {
            const q = search.text.trim().toLowerCase();
            return Clipboard.entries.filter(e => !q || e.text.toLowerCase().includes(q));
        }
        function pick(e) { Panels.close(); Clipboard.copy(e.text); }
        onOpenChanged: if (open) { search.text = ""; sel = 0; search.forceActiveFocus(); }

        PopupCard {
            shown: win.open
            width: 580; height: 540
            anchors.centerIn: parent
            slideY: 14
            ColumnLayout {
                anchors { fill: parent; margins: 16 }
                spacing: 12
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: "Clipboard"; font.pixelSize: Theme.fsL; font.weight: Font.DemiBold; Layout.fillWidth: true }
                    Button { text: "Clear unpinned"; glyph: "\uf1f8"; onClicked: Clipboard.clear() }
                }
                TextField {
                    id: search
                    Layout.fillWidth: true
                    glyph: "\uf002"; placeholder: "Search history…"
                    onEdited: win.sel = 0
                    onAccepted: if (win.shownEntries[win.sel]) win.pick(win.shownEntries[win.sel])
                    input.Keys.onDownPressed: win.sel = Math.min(win.shownEntries.length - 1, win.sel + 1)
                    input.Keys.onUpPressed: win.sel = Math.max(0, win.sel - 1)
                    input.Keys.onEscapePressed: Panels.close()
                }
                ListView {
                    id: list
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true; spacing: 6
                    model: win.shownEntries
                    currentIndex: win.sel
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        width: list.width; height: Math.min(86, txt.implicitHeight + 24)
                        radius: Theme.radiusS + 2
                        color: win.sel === index ? Theme.accentDim : (rm.containsMouse ? Theme.surface2 : Theme.surface)
                        border.width: win.sel === index ? 1 : 0; border.color: Theme.accentSoft
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        Text {
                            id: txt
                            anchors { left: parent.left; leftMargin: 14; right: acts.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            text: row.modelData.text.trim()
                            maximumLineCount: 3; elide: Text.ElideRight; wrapMode: Text.WrapAnywhere
                            color: Theme.text; font.family: "monospace"; font.pixelSize: Theme.fsM - 1
                        }
                        MouseArea { id: rm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            property real lastX: -1; property real lastY: -1
                            onPositionChanged: m => { if (lastX >= 0 && (Math.abs(m.x - lastX) > 1 || Math.abs(m.y - lastY) > 1)) win.sel = row.index; lastX = m.x; lastY = m.y; }
                            onExited: { lastX = -1; lastY = -1; }
                            onClicked: win.pick(row.modelData) }
                        Row {
                            id: acts
                            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            IconButton { glyph: "\uf08d"; size: 28; iconSize: 12; active: row.modelData.pinned; onClicked: Clipboard.togglePin(row.modelData) }
                            IconButton { glyph: "\uf00d"; size: 28; iconSize: 12; onClicked: Clipboard.remove(row.modelData) }
                        }
                    }
                    Label { anchors.centerIn: parent; visible: win.shownEntries.length === 0; text: "Nothing copied yet"; color: Theme.subtext }
                }
            }
        }
    }
}
