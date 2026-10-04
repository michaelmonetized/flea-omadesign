import fs from 'node:fs';
const file = process.argv[2];
let text = fs.readFileSync(file, 'utf8');
text = text.replace('    property var fleaWindow: null', `
    property IpcHandler verification: IpcHandler {
        target: "omaVerification"
        function look(index: int): bool {
            root.pane.cursorIndex = index
            var row = root.pane.rowFor(index)
            if (!row) return false
            root.pane.preview.open(root.pane.join(root.pane.path, row.n), row.i, row.s, root.pane.kindNames[row.k] || "")
            return true
        }
        function closeLook(): bool { root.pane.preview.close(); return true }
        function view(mode: string): bool { root.pane.viewMode = mode; return true }
        function pause(): bool { root.pane.preview.togglePlay(); return true }
        function seek(ms: int): bool { root.pane.preview.seekTo(ms); return true }
        function pick(index: int): bool { root.pane.cursorIndex = index; return true }
    }
    property var fleaWindow: null`);
fs.writeFileSync(file, text);
