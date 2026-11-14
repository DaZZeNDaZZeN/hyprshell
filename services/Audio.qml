pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import qs.config

Singleton {
    id: root
    readonly property string volumeSound: Qt.resolvedUrl("../assets/volume.wav").toString().replace("file://", "")
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
        || (n.properties && n.properties["media.class"] === "Stream/Output/Audio"))
        && n.name !== "pw-play" && n.properties?.["application.binary"] !== "pw-play")

    PwObjectTracker { objects: [root.sink, root.source].concat(root.audioNodes) }

    property int activeSliderDrags: 0
    property double suppressAutoSoundUntil: 0
    property real pendingSoundScale: 1.0

    Process {
        id: volSoundProc
        command: ["pw-play", "--volume", "1.000", root.volumeSound]
    }
    Timer {
        id: volSoundTimer
        interval: 45
        onTriggered: {
            if (!Osd.armed || root.muted || root.activeSliderDrags > 0) return;
            root.playVolumeSoundNow(root.pendingSoundScale);
        }
    }
    function playVolumeSoundNow(scale) {
        if (!Osd.armed || root.muted) return;
        const s = (scale === undefined || scale === null || !isFinite(scale)) ? 1.0 : Math.max(0, Math.min(1, scale));
        if (s <= 0.001) return;
        if (volSoundProc.running) volSoundProc.running = false;
        volSoundProc.command = ["pw-play", "--volume", s.toFixed(3), root.volumeSound];
        volSoundProc.running = true;
    }
    function playVolumeSound(scale) {
        if (!Osd.armed || root.muted) return;
        if (activeSliderDrags > 0 || Date.now() < suppressAutoSoundUntil) return;
        pendingSoundScale = (scale === undefined || scale === null || !isFinite(scale)) ? 1.0 : Math.max(0, Math.min(1, scale));
        volSoundTimer.restart();
    }
    function beginSliderDrag() {
        activeSliderDrags = Math.max(0, activeSliderDrags) + 1;
        volSoundTimer.stop();
    }
    function endSliderDrag(playOnRelease, scale) {
        activeSliderDrags = Math.max(0, activeSliderDrags - 1);
        suppressAutoSoundUntil = Date.now() + 200;
        volSoundTimer.stop();
        if (playOnRelease && activeSliderDrags === 0) {
            playVolumeSoundNow(scale);
        }
    }

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

    function osd() {
        Osd.show("volume", icon(volume, muted), muted ? "Muted" : Math.round(volume * 100) + "%", Math.min(1, volume), "Volume", !muted);
        playVolumeSound();
    }
    onVolumeChanged: osd()
    onMutedChanged: osd()
    onMicMutedChanged: Osd.show("mic", micMuted ? "\uf131" : "\uf130", micMuted ? "Mic muted" : "Mic on", -1, "Microphone", !micMuted)
}
