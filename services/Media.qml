pragma Singleton

import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import qs.config

// Active MPRIS player + media OSD + position/duration/volume helpers.
Singleton {
    id: root
    readonly property var players: Mpris.players.values
    readonly property var player: players.find(p => p.isPlaying) ?? players[0] ?? null
    readonly property bool playing: player?.isPlaying ?? false
    readonly property string title: player?.trackTitle ?? ""
    readonly property string artist: player?.trackArtist ?? ""
    readonly property string art: player?.trackArtUrl ?? ""

    readonly property real length: (player && player.lengthSupported && player.length > 0) ? player.length : 0
    readonly property real position: (player && player.positionSupported && player.position >= 0)
        ? (length > 0 ? Math.min(length, player.position) : player.position) : 0
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
        if (player && player.volumeSupported) return Math.max(0, Math.min(1, player.volume));
        if (playerStream && playerStream.audio) return Math.max(0, Math.min(1, playerStream.audio.volume));
        return Math.max(0, Math.min(1, Audio.volume));
    }
    readonly property bool muted: {
        if (player && player.volumeSupported) return player.volume <= 0.001;
        if (playerStream && playerStream.audio) return playerStream.audio.muted;
        return Audio.muted;
    }

    function setVolume(v) {
        const clamped = Math.max(0, Math.min(1, v));
        if (player && player.volumeSupported) {
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
            player.volume = player.volume > 0.001 ? 0 : 1;
        } else if (playerStream && playerStream.audio) {
            playerStream.audio.muted = !playerStream.audio.muted;
        } else {
            Audio.toggleMute();
        }
    }

    function seekRatio(r) {
        if (!player || length <= 0) return;
        const target = Math.max(0, Math.min(length, r * length));
        if (player.positionSupported && player.canSeek) {
            player.position = target;
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
        onTriggered: if (root.player) root.player.positionChanged()
    }

    function playPause() { if (player) player.togglePlaying(); }
    function next() { if (player?.canGoNext) player.next(); }
    function previous() { if (player?.canGoPrevious) player.previous(); }

    onTitleChanged: if (title) Osd.show("media", playing ? "\uf04b" : "\uf04c", title, -1, artist || (player?.identity ?? ""), true)
    onPlayingChanged: if (title) Osd.show("media", playing ? "\uf04b" : "\uf04c", playing ? "Playing" : "Paused", -1, title, playing)
}
