pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.config

// Weather from wttr.in (no API key). City from settings or auto-detected by IP.
Singleton {
    id: root
    property bool ok: false
    property real tempC: 0
    property real feelsC: 0
    property string desc: ""
    property int code: 113
    property int humidity: 0
    property int wind: 0
    property string place: ""
    property var days: []
    property int users: 0
    readonly property bool f: Config.o.weatherFahrenheit
    function t(c) { return f ? Math.round(c * 9 / 5 + 32) : Math.round(c); }
    readonly property string unit: f ? "°F" : "°C"

    function icon(c) {
        c = parseInt(c);
        if (c === 113) return "\uf185";
        if ([116, 119, 122].includes(c)) return "\uf0c2";
        if ([143, 248, 260].includes(c)) return "\uf0c2";
        if ([200, 386, 389, 392, 395].includes(c)) return "\uf0e7";
        if ([179, 182, 227, 230, 323, 326, 329, 332, 335, 338, 350, 368, 371, 374, 377].includes(c)) return "\uf2dc";
        return "\uf0e9";
    }
    function refresh() {
        const city = encodeURIComponent(Config.o.weatherCity.trim());
        proc.command = ["curl", "-sf", "-m", "15", "https://wttr.in/" + city + "?format=j1"];
        proc.running = true;
    }
    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    const c = j.current_condition[0];
                    root.tempC = parseFloat(c.temp_C); root.feelsC = parseFloat(c.FeelsLikeC);
                    root.desc = c.weatherDesc[0].value; root.code = parseInt(c.weatherCode);
                    root.humidity = parseInt(c.humidity); root.wind = parseInt(c.windspeedKmph);
                    root.place = j.nearest_area[0].areaName[0].value;
                    root.days = j.weather.map(d => ({ date: d.date, max: parseFloat(d.maxtempC), min: parseFloat(d.mintempC),
                        code: parseInt(d.hourly[4].weatherCode) }));
                    root.ok = true;
                } catch (e) { root.ok = false; }
            }
        }
    }
    readonly property bool active: root.users > 0
    Timer { interval: 1800000; repeat: true; running: root.active; triggeredOnStart: true; onTriggered: root.refresh() }
    Connections { target: Config.o; function onWeatherCityChanged() { if (root.active) root.refresh(); } }
}
