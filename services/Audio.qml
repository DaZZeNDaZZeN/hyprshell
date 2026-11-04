pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import qs.config

Singleton {
    id: root
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real micVolume: source?.audio?.volume ?? 0
    readonly property bool micMuted: source?.audio?.muted ?? false

    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    readonly property var sources: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio
        && (!n.properties || !n.properties["media.class"] || n.properties["media.class"].startsWith("Audio/Source")))
    readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream && n.audio
        && n.properties["media.class"] === "Stream/Output/Audio")

    PwObjectTracker { objects: [root.sink, root.source].concat(root.streams).concat(root.sinks).concat(root.sources) }

    function setVolume(v) { if (sink?.audio) { sink.audio.muted = false; sink.audio.volume = Math.max(0, Math.min(1.5, v)); } }
    function step(d) { setVolume(Math.round((volume + d) * 100) / 100); }
    function toggleMute() { if (sink?.audio) sink.audio.muted = !sink.audio.muted; }
    function toggleMic() {
        if (source?.audio) source.audio.muted = !source.audio.muted;
        else Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]);
    }
    function setMic(v) { if (source?.audio) source.audio.volume = Math.max(0, Math.min(1, v)); }
    function setDefault(n) { Pipewire.preferredDefaultAudioSink = n; }
    function setDefaultSource(n) { Pipewire.preferredDefaultAudioSource = n; }

    function icon(vol, mute) {
        if (mute || vol <= 0) return "\ueee8";
        if (vol < 0.34) return "\uf026";
        if (vol < 0.67) return "\uf027";
        return "\uf028";
    }
    function nodeName(n) {
        const p = n.properties;
        return p["application.name"] || n.nickname || n.description || n.name;
    }

    function osd() { Osd.show("volume", icon(volume, muted), muted ? "Muted" : Math.round(volume * 100) + "%", Math.min(1, volume), "Volume", !muted); }
    onVolumeChanged: osd()
    onMutedChanged: osd()
    onMicMutedChanged: Osd.show("volume", micMuted ? "\uf131" : "\uf130", micMuted ? "Mic muted" : "Mic on", -1, "Microphone", !micMuted)
}
