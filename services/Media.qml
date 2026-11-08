pragma Singleton

import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import qs.config

// Active MPRIS player + multi-player paging + media OSD + position/duration/volume helpers.
Singleton {
    id: root
    readonly property var rawPlayers: Mpris.players.values ?? []
    readonly property var players: {
        let list = rawPlayers.filter(p => p && (p.identity || "").toLowerCase() !== "playerctld" && !(p.dbusName || "").includes("playerctld"));
        if (list.length === 0) list = rawPlayers;
        const hasPbi = list.some(p => (p.dbusName || "").includes("plasma-browser-integration") || (p.identity || "").toLowerCase().includes("plasma-browser-integration"));
        if (hasPbi) {
            const filtered = list.filter(p => !((p.dbusName || "").includes("org.mpris.MediaPlayer2.firefox") && !(p.dbusName || "").includes("plasma-browser-integration")));
            if (filtered.length > 0) list = filtered;
        }
        return list;
    }

    property string activeKey: ""
    property var savedVolumes: ({})
    property var lastSetVolumes: ({})
    property var trackLengths: ({})
    property string fallbackTrackKey: ""
    property real fallbackPosition: -1

    function playerKey(p) {
        if (!p) return "";
        return p.dbusName || p.uniqueId || p.identity || p.desktopEntry || String(p);
    }

    function normalizeVolume(p, rawVol) {
        if (rawVol === undefined || rawVol === null || !isFinite(rawVol)) return 0;
        if (rawVol > 1.001) return Math.max(0, Math.min(1, rawVol / 100));
        if (rawVol === 1 && p) {
            const k = playerKey(p);
            if (k && lastSetVolumes[k] !== undefined && lastSetVolumes[k] < 0.05) {
                return 0.01;
            }
        }
        return Math.max(0, Math.min(1, rawVol));
    }

    function playerName(p) {
        if (!p) return "Media";
        const id = p.identity || p.desktopEntry || "";
        if (id.toLowerCase().includes("plasma-browser-integration")) return "Firefox";
        if (id.toLowerCase() === "mozilla firefox") return "Firefox";
        return id || "Media";
    }

    // Track last active player automatically whenever a player starts playing or changes track while playing
    Instantiator {
        model: root.players
        delegate: QtObject {
            required property var modelData
            readonly property bool isPlaying: modelData?.isPlaying ?? false
            readonly property string trackTitle: modelData?.trackTitle ?? ""
            readonly property real vol: (modelData && modelData.volumeSupported) ? root.normalizeVolume(modelData, modelData.volume) : -1
            onIsPlayingChanged: {
                if (isPlaying && modelData) {
                    root.activeKey = root.playerKey(modelData);
                }
            }
            onTrackTitleChanged: {
                if (isPlaying && modelData) {
                    root.activeKey = root.playerKey(modelData);
                }
            }
            onVolChanged: {
                if (modelData && vol > 0.001) {
                    const k = root.playerKey(modelData);
                    if (k && root.savedVolumes[k] !== vol) {
                        const next = Object.assign({}, root.savedVolumes);
                        next[k] = vol;
                        root.savedVolumes = next;
                    }
                }
            }
            Component.onCompleted: {
                if (isPlaying && modelData) {
                    root.activeKey = root.playerKey(modelData);
                }
                if (modelData && vol > 0.001) {
                    const k = root.playerKey(modelData);
                    if (k) {
                        const next = Object.assign({}, root.savedVolumes);
                        next[k] = vol;
                        root.savedVolumes = next;
                    }
                }
            }
        }
    }

    readonly property int count: players.length
    readonly property int currentIndex: {
        if (players.length === 0) return -1;
        if (activeKey) {
            const idx = players.findIndex(p => playerKey(p) === activeKey);
            if (idx >= 0) return idx;
        }
        const playingIdx = players.findIndex(p => p && p.isPlaying);
        return playingIdx >= 0 ? playingIdx : 0;
    }
    readonly property var player: (currentIndex >= 0 && currentIndex < players.length) ? players[currentIndex] : null

    function selectIndex(i) {
        if (i >= 0 && i < players.length) {
            activeKey = playerKey(players[i]);
        }
    }
    function nextPlayer() {
        if (players.length > 1) {
            selectIndex((currentIndex + 1) % players.length);
        }
    }
    function prevPlayer() {
        if (players.length > 1) {
            selectIndex((currentIndex - 1 + players.length) % players.length);
        }
    }

    readonly property bool playing: player?.isPlaying ?? false
    readonly property string title: player?.trackTitle ?? ""
    readonly property string artist: player?.trackArtist ?? ""
    readonly property string art: player?.trackArtUrl ?? ""

    readonly property string trackKey: player ? (playerKey(player) + "|" + title + "|" + artist) : ""
    readonly property real rawLength: (player && player.lengthSupported && player.length > 0) ? player.length : 0
    onRawLengthChanged: {
        if (rawLength > 0 && trackKey) {
            const next = Object.assign({}, trackLengths);
            next[trackKey] = rawLength;
            trackLengths = next;
        }
    }
    onTrackKeyChanged: {
        if (rawLength > 0 && trackKey) {
            const next = Object.assign({}, trackLengths);
            next[trackKey] = rawLength;
            trackLengths = next;
        }
        if (fallbackTrackKey !== trackKey) {
            fallbackPosition = -1;
        }
    }

    readonly property real length: rawLength > 0 ? rawLength : ((trackKey && trackLengths[trackKey] > 0) ? trackLengths[trackKey] : 0)
    readonly property real position: {
        if (!player) return 0;
        const reported = (player.positionSupported && player.position > 0) ? player.position : -1;
        const rawPos = reported >= 0
            ? reported
            : ((fallbackTrackKey === trackKey && fallbackPosition >= 0) ? fallbackPosition : ((player.positionSupported && player.position >= 0) ? player.position : 0));
        return length > 0 ? Math.min(length, rawPos) : rawPos;
    }
    readonly property bool canSeek: !!(player && player.canSeek && length > 0)

    readonly property var playerStream: {
        if (!player) return null;
        const id = (player.identity || "").toLowerCase();
        const de = (player.desktopEntry || "").toLowerCase();
        for (const s of Audio.streams) {
            const p = s.properties ?? ({});
            const app = (p["application.name"] || s.nickname || s.description || s.name || "").toLowerCase();
            const bin = (p["application.process.binary"] || "").toLowerCase();
            if ((id && (app.includes(id) || id.includes(app) || bin.includes(id)))
                || (de && (app.includes(de) || bin.includes(de)))) {
                return s;
            }
        }
        return Audio.streams.length === 1 ? Audio.streams[0] : null;
    }

    readonly property real volume: {
        if (player && player.volumeSupported) return normalizeVolume(player, player.volume);
        if (playerStream && playerStream.audio) return Math.max(0, Math.min(1, playerStream.audio.volume));
        return Math.max(0, Math.min(1, Audio.volume));
    }
    readonly property bool muted: {
        if (player && player.volumeSupported) return normalizeVolume(player, player.volume) <= 0.001;
        if (playerStream && playerStream.audio) return playerStream.audio.muted;
        return Audio.muted;
    }

    function setVolume(v) {
        const clamped = Math.max(0, Math.min(1, v));
        if (player && player.volumeSupported) {
            const k = playerKey(player);
            if (k) {
                const nextSet = Object.assign({}, lastSetVolumes);
                nextSet[k] = clamped;
                lastSetVolumes = nextSet;
                if (clamped > 0.001) {
                    const nextSaved = Object.assign({}, savedVolumes);
                    nextSaved[k] = clamped;
                    savedVolumes = nextSaved;
                }
            }
            player.volume = clamped;
        } else if (playerStream && playerStream.audio) {
            playerStream.audio.muted = false;
            playerStream.audio.volume = clamped;
        } else {
            Audio.setVolume(clamped);
        }
    }

    function toggleMute() {
        if (player && player.volumeSupported) {
            const k = playerKey(player);
            const curVol = normalizeVolume(player, player.volume);
            if (curVol > 0.001) {
                if (k) {
                    const next = Object.assign({}, savedVolumes);
                    next[k] = curVol;
                    savedVolumes = next;
                }
                player.volume = 0;
            } else {
                const restore = (k && savedVolumes[k] > 0.001) ? savedVolumes[k] : 0.5;
                player.volume = restore;
            }
        } else if (playerStream && playerStream.audio) {
            playerStream.audio.muted = !playerStream.audio.muted;
        } else {
            Audio.toggleMute();
        }
    }

    function seekRatio(r) {
        if (!player || length <= 0) return;
        const target = Math.max(0, Math.min(length, r * length));
        fallbackTrackKey = trackKey;
        fallbackPosition = target;
        if (player.canSeek) {
            if (player.positionSupported && player.lengthSupported) {
                player.position = target;
            } else if (player.dbusName) {
                const rawTid = player.metadata ? player.metadata["mpris:trackid"] : null;
                const tid = (rawTid && typeof rawTid === "string" && rawTid.startsWith("/"))
                    ? rawTid
                    : ((rawTid && rawTid.path) ? String(rawTid.path) : "/org/mpris/MediaPlayer2/firefox");
                Quickshell.execDetached([
                    "busctl", "--user", "call",
                    player.dbusName,
                    "/org/mpris/MediaPlayer2",
                    "org.mpris.MediaPlayer2.Player",
                    "SetPosition", "ox", tid, String(Math.round(target * 1000000))
                ]);
            } else {
                player.position = target;
            }
        }
    }

    function formatTime(sec) {
        if (!sec || !isFinite(sec) || sec < 0) return "0:00";
        const s = Math.floor(sec);
        const m = Math.floor(s / 60);
        const rem = s % 60;
        return m + ":" + (rem < 10 ? "0" + rem : rem);
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.playing && root.player !== null
        onTriggered: {
            if (root.player) {
                root.player.positionChanged();
                if (root.player.positionSupported && root.player.position > 0) {
                    root.fallbackTrackKey = root.trackKey;
                    root.fallbackPosition = root.player.position;
                } else if (root.fallbackTrackKey === root.trackKey && root.fallbackPosition >= 0) {
                    root.fallbackPosition = root.length > 0 ? Math.min(root.length, root.fallbackPosition + 1) : (root.fallbackPosition + 1);
                }
            }
        }
    }

    function playPause() { if (player) player.togglePlaying(); }
    function next() { if (player?.canGoNext) player.next(); }
    function previous() { if (player?.canGoPrevious) player.previous(); }

    onTitleChanged: if (title) Osd.show("media", playing ? "\uf04b" : "\uf04c", title, -1, artist || (player?.identity ?? ""), true)
    onPlayingChanged: if (title) Osd.show("media", playing ? "\uf04b" : "\uf04c", playing ? "Playing" : "Paused", -1, title, playing)
}
