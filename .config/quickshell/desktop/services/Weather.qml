pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// One-line weather from wttr.in (location by IP), e.g. "Sunny +61°F".
// Fetched lazily -- only when something shows it and the last fetch is stale.
Singleton {
    id: root

    property string text: "…"
    property double fetchedAt: 0

    function refresh(maxAgeMs) {
        if (Date.now() - fetchedAt < (maxAgeMs ?? 600000) || proc.running)
            return;
        proc.running = true;
    }

    Process {
        id: proc
        command: ["curl", "-s", "--max-time", "8", "wttr.in/?format=%C+%t"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                // wttr.in answers errors with an HTML page or a long sentence.
                if (t && t.length < 60 && !t.startsWith("<")) {
                    root.text = t;
                    root.fetchedAt = Date.now();
                } else if (root.text === "…") {
                    root.text = "N/A";
                }
            }
        }
    }
}
