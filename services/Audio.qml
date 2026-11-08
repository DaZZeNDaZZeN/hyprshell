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

    readonly property var audioNodes: Pipewire.nodes.values.filter(n => n && n.audio !== null)
    readonly property var sinks: audioNodes.filter(n => !n.isStream && n.isSink)
    readonly property var sources: audioNodes.filter(n => !n.isStream && !n.isSink
        && (!n.properties || !n.properties["media.class"] || n.properties["media.class"].startsWith("Audio/Source")))
    readonly property var streams: audioNodes.filter(n => n.isStream && (n.isSink
        || (n.properties && n.properties["media.class"] === "Stream/Output/Audio")))

    PwObjectTracker { objects: [root.sink, root.source].concat(root.audioNodes) }

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
        if (!n) return "";
        const p = n.properties ?? ({});
        const app = p["application.name"] || p["node.nick"] || n.nickname || n.description || n.name || "Application";
        const media = p["media.name"];
        return (media && media !== app && !app.toLowerCase().includes(media.toLowerCase())) ? (app + " — " + media) : app;
    }

    function osd() { Osd.show("volume", icon(volume, muted), muted ? "Muted" : Math.round(volume * 100) + "%", Math.min(1, volume), "Volume", !muted); }
    onVolumeChanged: osd()
    onMutedChanged: osd()
    onMicMutedChanged: Osd.show("mic", micMuted ? "\uf131" : "\uf130", micMuted ? "Mic muted" : "Mic on", -1, "Microphone", !micMuted)
}
