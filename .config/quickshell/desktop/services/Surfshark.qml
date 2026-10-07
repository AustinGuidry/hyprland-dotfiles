pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Surfshark, for the bar's shield menu (bar/VpnModule.qml).
//
// surfshark-vpn is a root-only interactive wizard, so anything that changes
// the tunnel goes through vpn/surfshark-helper, which answers the wizard's
// prompts and which vpn/install.sh sets up to run under `sudo -n`. Whether the
// tunnel is up is read without root, so the shield also follows a connection
// made from the terminal.
Singleton {
    id: root

    readonly property string source: Quickshell.shellPath("vpn/surfshark-helper")
    readonly property string installer: Quickshell.shellPath("vpn/install.sh")
    readonly property var helper: ["sudo", "-n", "/usr/local/libexec/surfshark-bar-helper"]
    readonly property var probeCommand: ["python3", "-I", source, "status"]

    // The tunnel as it is, however it got that way.
    property bool connected: false
    property string server: ""          // from OpenVPN's command line, e.g. "us-nyc"
    property string liveProtocol: ""

    // Setup: the root copy exists, sudo runs it, and it matches vpn/surfshark-helper.
    property bool installed: false
    property bool allowed: false
    property bool upToDate: true
    readonly property bool ready: installed && allowed

    // "connecting", "disconnecting", "listing" or "checking" while the helper runs.
    property string busy: ""
    property string target: ""
    property string error: ""
    property bool cancelling: false
    // A connect asked for while the list was still loading: { where }.
    property var queued: null

    // Remembered across restarts.
    property string protocol: "udp"
    property string location: ""        // last one picked here; "" is the nearest server
    property bool owned: false          // the live connection was made from this menu
    property string ownedProtocol: ""
    property var recent: []
    property var locations: []          // names, in the wizard's order

    readonly property string summary: cancelling ? "Cancelling…"
        : busy === "connecting" ? `Connecting to ${target || "the nearest server"}…`
        : busy === "disconnecting" ? "Disconnecting…"
        : !connected ? "Not connected"
        : ["Connected", owned ? (location || server || "Nearest server") : server,
            (liveProtocol || (owned ? ownedProtocol : "")).toUpperCase()].filter(s => s).join(" · ")

    function connect(where) {
        if (!ready)
            return;
        if (busy === "listing") {
            // The list can wait: a connect brings it back anyway.
            queued = { where };
            cancel();
        } else if (!busy) {
            target = where;
            run("connecting", ["connect", protocol].concat(where ? [where] : []));
        }
    }

    // Switching off mid-connect calls the connect off.
    function disconnect() {
        if (!ready)
            return;
        if (busy === "connecting") {
            cancelling = true;
            cancel();
        } else if (!busy) {
            run("disconnecting", ["down"]);
        }
    }

    // The helper runs under sudo, which this process can't signal; a second
    // helper does it from the inside, and the first then reports "cancelled".
    function cancel() {
        if (!canceller.running)
            canceller.running = true;
    }

    // Changing protocol means a new tunnel. Only one this menu made is redone
    // on the spot; for anything else the choice waits for the next connect.
    function setProtocol(proto) {
        if (proto === protocol || (busy && busy !== "listing"))
            return;
        protocol = proto;
        save();
        if (connected && owned)
            connect(location);
    }

    // The wizard has to be started to see its list, which is only safe to do
    // with the VPN down. Every connect brings the list back with it as well.
    function loadLocations() {
        if (busy || !ready || !upToDate || connected)
            return;
        run("listing", ["list"]);
    }

    // Called as the menu opens.
    function opened() {
        error = "";
        refresh();
        if (installed && !allowed)
            run("checking", ["status"]);
        else if (locations.length === 0)
            loadLocations();
    }

    function refresh() {
        if (probe.running)
            probe.again = true;
        else
            probe.running = true;
    }

    function run(what, args) {
        if (busy)
            return;
        busy = what;
        error = "";
        // sudo complains on stderr; fold it in so one stream tells the story.
        action.command = ["sh", "-c", "exec \"$@\" 2>&1", "sh"].concat(helper, args);
        action.running = true;
    }

    function finished(text) {
        const what = busy;
        let result = null;
        try {
            result = JSON.parse(text.trim().split("\n").pop());
        } catch (e) {}
        busy = "";
        cancelling = false;

        if (!result) {
            if (text.includes("sudo:"))
                allowed = false;    // no rule for the helper: back to the setup prompt
            else
                error = "The VPN helper failed; `qs -c desktop log` has the details.";
            console.warn("surfshark:", text.trim());
        } else {
            const first = !allowed;
            allowed = true;
            if (result.locations?.length)
                locations = result.locations;
            if (result.cancelled) {
                // Asked for; nothing to report.
            } else if (!result.ok) {
                error = result.error;
                console.warn(`surfshark: ${result.error}\n${result.transcript ?? ""}`);
            } else if (what === "connecting") {
                location = target;
                owned = true;
                ownedProtocol = result.proto || protocol;
                if (target)
                    recent = [target].concat(recent.filter(name => name !== target)).slice(0, 3);
            }
            if (first && locations.length === 0)
                loadLocations();
        }
        save();
        refresh();
        if (queued) {
            const next = queued;
            queued = null;
            connect(next.where);
        }
    }

    function applyStatus(text) {
        let s = null;
        try {
            s = JSON.parse(text);
        } catch (e) {
            return;
        }
        connected = s.connected;
        server = s.server;
        liveProtocol = s.proto;
        upToDate = s.current;
        installed = s.installed;
        if (!connected && !busy && owned) {
            owned = false;
            save();
        }
    }

    function save() {
        state.setText(JSON.stringify({ protocol, location, owned, ownedProtocol, recent, locations }));
    }

    // A list read by an older helper isn't to be trusted: the first one only
    // got as far as the wizard's opening page.
    onUpToDateChanged: {
        if (upToDate && ready) {
            locations = [];
            save();
            loadLocations();
        }
    }

    onInstalledChanged: {
        if (installed)
            run("checking", ["status"]);
        else
            allowed = false;
    }

    FileView {
        id: state
        path: Quickshell.statePath("surfshark.json")
        blockLoading: true
        printErrors: false
        onLoaded: {
            let s = {};
            try {
                s = JSON.parse(text());
            } catch (e) {}
            root.protocol = s.protocol === "tcp" ? "tcp" : "udp";
            root.location = s.location ?? "";
            root.owned = s.owned ?? false;
            root.ownedProtocol = s.ownedProtocol ?? "";
            root.recent = s.recent ?? [];
            root.locations = s.locations ?? [];
        }
    }

    Process {
        id: action
        stdout: StdioCollector {
            onStreamFinished: root.finished(text)
        }
    }

    Process {
        id: canceller
        command: root.helper.concat(["cancel"])
    }

    Process {
        id: probe

        property bool again: false

        running: true
        command: root.probeCommand
        stdout: StdioCollector {
            onStreamFinished: {
                root.applyStatus(text);
                if (probe.again) {
                    probe.again = false;
                    Qt.callLater(root.refresh);
                }
            }
        }
    }

    // The tunnel is a tun device, so link changes say when to look again; the
    // timer is only there in case that stream ever goes quiet.
    Process {
        running: true
        command: ["ip", "-o", "monitor", "link"]
        stdout: SplitParser {
            onRead: line => {
                if (line.includes("tun"))
                    settle.restart();
            }
        }
    }

    Timer {
        id: settle
        interval: 400
        onTriggered: root.refresh()
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
