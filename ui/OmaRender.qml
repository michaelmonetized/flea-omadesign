import QtQuick
import Quickshell.Io

Item {
    id: root
    property string path: ""
    property string mode: "preview"
    property int edge: 1280
    property var revision: ""
    property var answer: null
    property string error: ""
    property string requestPath: ""
    property var requestRevision: ""
    readonly property bool busy: renderer.running || settle.running
    readonly property string file: answer ? answer.file : ""
    readonly property string kind: answer ? answer.kind : ""

    function restart() {
        renderer.running = false
        root.answer = null
        root.error = ""
        if (root.enabled && root.path.length > 0) settle.restart()
        else settle.stop()
    }
    onPathChanged: restart()
    onRevisionChanged: restart()
    onEnabledChanged: restart()
    Component.onCompleted: restart()

    Timer {
        id: settle
        interval: 120
        onTriggered: {
            root.requestPath = root.path
            root.requestRevision = root.revision
            renderer.command = ["prlimit", "--as=2147483648", "--cpu=" + (root.mode === "preview" ? "180" : "30"),
                "oma-preview", root.mode, "--input", root.path, "--size", String(root.edge)]
            renderer.running = true
        }
    }
    Process {
        id: renderer
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: function(code) {
            if (!root.enabled || root.path !== root.requestPath || root.revision !== root.requestRevision) return
            try {
                var result = JSON.parse(renderer.stdout.text.trim())
                if (code === 0 && result.file) root.answer = result
                else root.error = result.error || "This design could not be rendered."
            } catch (error) {
                root.error = "This design could not be rendered."
            }
        }
    }
}
