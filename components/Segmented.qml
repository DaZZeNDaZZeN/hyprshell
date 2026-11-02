import QtQuick
import qs.config

// Row of mutually-exclusive chips. options: [{label, value}] or plain strings.
Row {
    id: root
    property var options: []
    property var current
    signal picked(var value)
    spacing: 6
    Repeater {
        model: root.options
        delegate: Chip {
            required property var modelData
            readonly property var val: modelData.value !== undefined ? modelData.value : modelData
            text: modelData.label !== undefined ? modelData.label : String(modelData)
            active: root.current === val
            onClicked: root.picked(val)
        }
    }
}
