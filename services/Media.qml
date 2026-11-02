pragma Singleton

import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import qs.config

// Active MPRIS player + media OSD.
Singleton {
    id: root
    readonly property var players: Mpris.players.values
    readonly property var player: players.find(p => p.isPlaying) ?? players[0] ?? null
    readonly property bool playing: player?.isPlaying ?? false
    readonly property string title: player?.trackTitle ?? ""
    readonly property string artist: player?.trackArtist ?? ""
    readonly property string art: player?.trackArtUrl ?? ""

    function playPause() { if (player) player.togglePlaying(); }
    function next() { if (player?.canGoNext) player.next(); }
    function previous() { if (player?.canGoPrevious) player.previous(); }

    onTitleChanged: if (title) Osd.show("media", playing ? "\uf04b" : "\uf04c", title, -1, artist || (player?.identity ?? ""), true)
    onPlayingChanged: if (title) Osd.show("media", playing ? "\uf04b" : "\uf04c", playing ? "Playing" : "Paused", -1, title, playing)
}
