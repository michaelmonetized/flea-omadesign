import fs from 'node:fs';
import path from 'node:path';

const [source, destination, plugin] = process.argv.slice(2);
if (!source || !destination || !plugin) throw new Error('Pass packaged UI, output directory, and plugin directory.');
fs.cpSync(source, destination, { recursive: true, verbatimSymlinks: true });

function patch(file, before, after) {
  const target = path.join(destination, file);
  const text = fs.readFileSync(target, 'utf8');
  if (!text.includes(before)) throw new Error(`Flea changed ${file}; the Omadesign adapter needs updating.`);
  fs.writeFileSync(target, text.replaceAll(before, after));
}

patch('js/Kinds.js', 'function quickLookKind(icon, name) {',
  'function quickLookKind(icon, name) {\n    if (/\\.oma$/i.test(name)) return IMAGE');
patch('js/Facts.js', '    if (kindName === UNKNOWN_KIND) {',
  '    if (/\\.oma$/i.test(row.n)) return IMAGE\n    if (kindName === UNKNOWN_KIND) {');
patch('js/Thumbs.js', 'function allowed(row, mode) {',
  'function allowed(row, mode) {\n    if (row && /\\.oma$/i.test(row.n)) return false');
patch('Preview.qml', 'imageLoader.source = root.isImage ? "PreviewImage.qml" : ""',
  'imageLoader.source = root.isImage ? (/\\.oma$/i.test(root.path) ? "PreviewOma.qml" : "PreviewImage.qml") : ""');
patch('Preview.qml', 'readonly property int position: (root.isMedia && mediaLoader.item) ? mediaLoader.item.position : 0',
  'readonly property int position: (root.isMedia && mediaLoader.item) ? mediaLoader.item.position : (imageLoader.item && /\\.oma$/i.test(root.path) ? imageLoader.item.position : 0)');
patch('Preview.qml', 'readonly property int duration: (root.isMedia && mediaLoader.item) ? mediaLoader.item.duration : 0',
  'readonly property int duration: (root.isMedia && mediaLoader.item) ? mediaLoader.item.duration : (imageLoader.item && /\\.oma$/i.test(root.path) ? imageLoader.item.duration : 0)');
patch('Preview.qml', '    readonly property bool isPdf:',
  '    readonly property bool isOmaMotion: /\\.oma$/i.test(root.path) && imageLoader.item !== null && imageLoader.item.duration > 0\n    readonly property bool isPdf:');
patch('Preview.qml', 'if (root.isMedia && mediaLoader.item) mediaLoader.item.togglePlay()',
  'if (root.isMedia && mediaLoader.item) mediaLoader.item.togglePlay(); else if (root.isOmaMotion) imageLoader.item.togglePlay()');
patch('Preview.qml', 'if (root.isMedia && mediaLoader.item) mediaLoader.item.seekTo(ms)',
  'if (root.isMedia && mediaLoader.item) mediaLoader.item.seekTo(ms); else if (root.isOmaMotion) imageLoader.item.seekTo(ms)');
patch('js/Focus.js', 'root.preview.isMedia', '(root.preview.isMedia || root.preview.isOmaMotion)');
patch('js/PreviewKeys.js', 'root.preview.isMedia', '(root.preview.isMedia || root.preview.isOmaMotion)');

for (const file of ['Row.qml', 'GridTile.qml', 'ColumnRow.qml']) {
  const target = path.join(destination, file);
  let text = fs.readFileSync(target, 'utf8').replace(/root\.thumb\b/g, 'root.omaThumb');
  const anchor = '    property string thumb: ""';
  if (!text.includes(anchor)) throw new Error(`Flea changed ${file}'s thumbnail binding.`);
  const added = `${anchor}
    property string omaPath: ""
    readonly property string omaThumb: omaThumbnail.item ? omaThumbnail.item.file : root.thumb
    Loader {
        id: omaThumbnail
        active: root.visible && root.omaPath.length > 0 && /\\.oma$/i.test(root.omaPath) && ViewState.thumbnailMode !== "off"
        source: "OmaThumbnail.qml"
        onLoaded: {
            item.path = Qt.binding(function () { return root.omaPath })
            item.revision = Qt.binding(function () { return root.row })
        }
    }`;
  text = text.replace(anchor, added);
  fs.writeFileSync(target, text);
}
for (const file of ['List.qml', 'GridArea.qml']) {
  patch(file, 'row: root.pane.rowFor(listingIndex)',
    'row: root.pane.rowFor(listingIndex)\n        omaPath: row ? root.pane.join(root.pane.path, row.n) : ""');
}
patch('ColumnPane.qml', 'thumb: root.pane !== null && Thumbs.allowed(row, ViewState.thumbnailMode)',
  'omaPath: root.pane && row ? root.pane.join(root.pane.path, row.n) : ""\n            thumb: root.pane !== null && Thumbs.allowed(row, ViewState.thumbnailMode)');
patch('PickerList.qml', 'row: cell.shownRow',
  'row: cell.shownRow\n            omaPath: row && !root.picker.recent ? (root.picker.path === "/" ? "/" : root.picker.path + "/") + row.n : ""');

patch('PreviewColumn.qml', '    readonly property bool wantsThumb:',
  '    readonly property bool oma: /\\.oma$/i.test(root.path)\n    readonly property bool wantsThumb: !root.oma &&');
patch('PreviewColumn.qml', '            Image {\n                id: frameThumb',
  `            Loader {
                id: omaColumn
                anchors.fill: parent
                anchors.margins: Theme.spacing.hairline
                active: root.oma && root.visible && !root.overlayOpen && !root.manualHold && root.selectionCount <= 1
                source: "PreviewOma.qml"
                onLoaded: {
                    item.autoStart = false
                    item.path = Qt.binding(function () { return root.path })
                }
            }
            Image {
                id: frameThumb`);
patch('PreviewColumn.qml', 'visible: root.previewState === Facts.ERROR || (root.previewState === Facts.UNSUPPORTED && !root.thumbShown)',
  'visible: !root.oma && (root.previewState === Facts.ERROR || (root.previewState === Facts.UNSUPPORTED && !root.thumbShown))');
patch('PreviewColumn.qml', 'if (!root.manualHold && root.noThumbComing && root.previewState === Facts.IMAGE',
  'if (!root.oma && !root.manualHold && root.noThumbComing && root.previewState === Facts.IMAGE');
patch('PreviewColumn.qml', '    property string path: ""',
  '    property string path: ""\n    readonly property var omaPreview: omaColumn.item');
patch('Ipc.qml', '        function ready(): bool { return true }',
  `        function ready(): bool { return true }
        function omaPreviewState(): string {
            var item = root.pane.preview.surfaceItem()
            return JSON.stringify(item && item.renderedFile !== undefined
                ? {file: item.renderedFile, status: item.status, position: item.position, duration: item.duration, frame: item.currentFrame}
                : {})
        }
        function omaColumnState(): string {
            var column = root.pane.previewColumnItem
            var item = column && column.omaPreview
            return JSON.stringify(item ? {file: item.renderedFile, status: item.status, position: item.position, duration: item.duration} : {})
        }
        function omaThumbnailFile(index: int): string {
            var item = root.pane.visibleItemFor(index)
            return item && item.omaThumb !== undefined ? item.omaThumb : ""
        }
        function omaThumbnailState(index: int): string {
            var item = root.pane.visibleItemFor(index)
            return JSON.stringify(item ? {path: item.omaPath, file: item.omaThumb, visible: item.visible, name: item.row ? item.row.n : ""} : {})
        }`);

for (const file of ['OmaRender.qml', 'OmaThumbnail.qml', 'PreviewOma.qml']) {
  fs.copyFileSync(path.join(plugin, 'ui', file), path.join(destination, file));
  fs.appendFileSync(path.join(destination, 'qmldir'), `\n${file.slice(0, -4)} 1.0 ${file}\n`);
}
