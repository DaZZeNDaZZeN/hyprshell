import QtQuick
import qs.config

// Minimal themed single-line input.
Rectangle {
    id: root
    property alias text: input.text
    property alias placeholder: ph.text
    property alias echoMode: input.echoMode
    property alias input: input
    property string glyph: ""
    signal accepted()
    signal edited()
    implicitHeight: 38
    implicitWidth: 200
    radius: Theme.radiusS + 2
    color: Theme.surface2
    border.width: input.activeFocus ? 2 : 1
    border.color: input.activeFocus ? Theme.accent : Theme.border
    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

    Icon { id: gi; visible: root.glyph !== ""; text: root.glyph; x: 12; anchors.verticalCenter: parent.verticalCenter; tint: Theme.subtext; font.pixelSize: 14 }
    TextInput {
        id: input
        anchors.left: gi.visible ? gi.right : parent.left
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: Theme.fsM
        selectionColor: Theme.accent
        selectedTextColor: Theme.onAccent
        clip: true
        onAccepted: root.accepted()
        onTextEdited: root.edited()
        Text {
            id: ph
            visible: !input.text && !input.preeditText
            color: Theme.subtext
            font: input.font
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    function forceActiveFocus() { input.forceActiveFocus(); }
}
