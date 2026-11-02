pragma Singleton

import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import qs.config

// Notification daemon + history.
Singleton {
    id: root
    property var items: []           // newest first; wrappers (see Notif below)
    readonly property int count: items.length
    readonly property var popups: items.filter(i => i.popup)
    property bool dnd: Config.o.dnd

    function setDnd(v) { Config.o.dnd = v; }

    component Notif: QtObject {
        id: w
        required property var n
        property string summary: n.summary
        property string body: n.body
        property string appName: n.appName
        property string appIcon: n.appIcon
        property string image: n.image
        property var actions: n.actions.map(a => ({ id: a.identifier, text: a.text }))
        property bool critical: n.urgency === NotificationUrgency.Critical
        property bool alive: true
        property bool popup: !Config.o.dnd
        property date time: new Date()
        property Timer timer: Timer {
            interval: Config.o.notifTimeout
            running: w.popup && !w.critical && !hovered
            onTriggered: w.popup = false
        }
        property bool hovered: false
        property Connections conn: Connections {
            target: w.n
            function onClosed() { w.alive = false; w.popup = false; }
        }
        function invoke(id) {
            if (!alive) return;
            for (const a of n.actions) if (a.identifier === id) a.invoke();
            popup = false;
        }
    }
    Component { id: notifComp; Notif {} }

    NotificationServer {
        keepOnReload: true
        actionsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: false
        imageSupported: true
        persistenceSupported: true
        onNotification: n => {
            n.tracked = true;
            const w = notifComp.createObject(root, { n: n });
            root.items = [w].concat(root.items).slice(0, 150);
        }
    }

    function dismiss(w) {
        if (w.alive) w.n.dismiss();
        root.items = root.items.filter(i => i !== w);
        w.destroy();
    }
    function clearAll() {
        for (const w of items) { if (w.alive) w.n.dismiss(); w.destroy(); }
        items = [];
    }
    function hidePopup(w) { w.popup = false; }
}
