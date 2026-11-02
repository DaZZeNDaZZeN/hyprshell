pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.config

// wallhaven.cc API client: search, filter, paginate, download and apply.
Singleton {
    id: root
    property var results: []
    property bool loading: false
    property string error: ""
    property int page: 1
    property int lastPage: 1
    property int total: 0

    property string query: ""
    property bool general: true
    property bool anime: true
    property bool people: false
    property bool sketchy: false
    property bool nsfw: false
    property string sorting: "toplist"      // date_added | relevance | random | views | favorites | toplist | hot
    property string toplistRange: "1M"
    property string atleast: ""             // "" | 1920x1080 | 2560x1440 | 3840x2160
    property string ratios: ""              // "" | 16x9 | 16x10 | 21x9
    property string downloading: ""         // id currently being downloaded
    property string pendingApply: ""

    readonly property var sortings: ["toplist", "hot", "date_added", "views", "favorites", "relevance", "random"]
    readonly property var resolutions: ["", "1920x1080", "2560x1440", "3840x2160"]
    readonly property var ratioList: ["", "16x9", "16x10", "21x9"]

    function url(p) {
        const cat = (general ? "1" : "0") + (anime ? "1" : "0") + (people ? "1" : "0");
        const pur = "1" + (sketchy ? "1" : "0") + (nsfw && Config.o.wallhavenApiKey ? "1" : "0");
        let u = "https://wallhaven.cc/api/v1/search?q=" + encodeURIComponent(query) + "&categories=" + cat + "&purity=" + pur
            + "&sorting=" + sorting + "&order=desc&page=" + p;
        if (sorting === "toplist") u += "&topRange=" + toplistRange;
        if (atleast) u += "&atleast=" + atleast;
        if (ratios) u += "&ratios=" + ratios;
        if (Config.o.wallhavenApiKey) u += "&apikey=" + encodeURIComponent(Config.o.wallhavenApiKey);
        return u;
    }
    function search() { results = []; page = 1; lastPage = 1; fetch(1); }
    function more() { if (!loading && page < lastPage) fetch(page + 1); }
    property var _xhr: null
    function fetch(p) {
        loading = true; error = "";
        if (_xhr) _xhr.abort();
        const xhr = new XMLHttpRequest();
        _xhr = xhr;
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            loading = false;
            if (xhr.status !== 200) { error = xhr.status === 0 ? "Network error" : (xhr.status === 429 ? "Rate limited, try again in a minute" : "HTTP " + xhr.status); return; }
            try {
                const j = JSON.parse(xhr.responseText);
                root.page = j.meta.current_page; root.lastPage = j.meta.last_page; root.total = j.meta.total;
                root.results = (p === 1 ? [] : root.results).concat(j.data);
            } catch (e) { error = "Bad response"; }
        };
        xhr.open("GET", url(p));
        xhr.send();
    }

    function localPath(item) {
        const ext = item.path.substring(item.path.lastIndexOf("."));
        return Config.o.wallpaperDir + "/wallhaven-" + item.id + ext;
    }
    function isDownloaded(item) { return Wallpaper.files.indexOf(localPath(item)) >= 0; }
    function download(item, apply) {
        if (downloading !== "") return;
        downloading = item.id;
        pendingApply = apply ? localPath(item) : "";
        dl.command = ["sh", "-c", "mkdir -p '" + Config.o.wallpaperDir + "' && curl -sfL -m 120 -o '" + localPath(item) + ".part' '" + item.path + "' && mv '" + localPath(item) + ".part' '" + localPath(item) + "'"];
        dl.running = true;
    }
    Process {
        id: dl
        onExited: code => {
            root.downloading = "";
            Wallpaper.refresh();
            if (code === 0) {
                if (root.pendingApply) Wallpaper.apply(root.pendingApply);
                Quickshell.execDetached(["notify-send", "-a", "Wallpapers", root.pendingApply ? "Wallpaper applied" : "Wallpaper downloaded", "Saved to " + Config.o.wallpaperDir]);
            } else root.error = "Download failed";
            root.pendingApply = "";
        }
    }
}
