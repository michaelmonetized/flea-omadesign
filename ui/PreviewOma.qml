import QtQuick
import QtMultimedia
import "." as Flea
import "js/Format.js" as Format

Item {
    id: root
    property string path: ""
    property bool autoStart: true
    readonly property bool failed: render.error.length > 0 || picture.status === Image.Error || player.error !== MediaPlayer.NoError
    readonly property string status: {
        if (root.failed) return render.error || "This design could not be previewed."
        if (render.busy || !render.answer) return "loading"
        if (render.kind === "motion") {
            if (player.mediaStatus === MediaPlayer.LoadingMedia) return "loading"
            return player.playbackState === MediaPlayer.PlayingState ? "playing" : "paused"
        }
        return picture.status === Image.Ready ? "image" : "loading"
    }
    readonly property int position: player.position
    readonly property int duration: player.duration
    readonly property int currentFrame: duration > 0 && render.answer ? Math.floor(position * render.answer.fps / 1000) : 0
    readonly property string renderedFile: render.file
    function togglePlay() {
        if (player.playbackState === MediaPlayer.PlayingState) player.pause()
        else player.play()
    }
    function seekTo(ms) { player.position = Math.max(0, Math.min(player.duration, ms)) }

    Flea.OmaRender {
        id: render
        path: root.path
        enabled: root.visible
    }
    Rectangle { anchors.fill: parent; color: Theme.color.background }
    Image {
        id: picture
        anchors.fill: parent
        anchors.bottomMargin: caption.height
        source: render.kind === "static" ? Format.fileUri(render.file) : ""
        visible: render.kind === "static"
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: false
        sourceSize.width: Math.max(1, Math.round(width))
        sourceSize.height: Math.max(1, Math.round(height))
    }
    MediaPlayer {
        id: player
        source: render.kind === "motion" ? Format.fileUri(render.file) : ""
        videoOutput: video
        autoPlay: root.autoStart && render.kind === "motion" && render.file.length > 0
        loops: render.answer && render.answer.looped ? MediaPlayer.Infinite : 1
    }
    VideoOutput {
        id: video
        anchors.fill: picture
        visible: render.kind === "motion"
    }
    Column {
        anchors.centerIn: parent
        spacing: Theme.spacing.gap
        visible: render.busy || root.failed
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.failed ? root.status : "Rendering design…"
            textFormat: Text.PlainText
            color: root.failed ? Theme.color.error : Theme.color.muted
            font.family: Theme.font.family
            font.pixelSize: Theme.font.body
        }
    }
    Item {
        id: caption
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: render.answer ? Theme.chromeHeight : 0
        Flea.MediaStrip {
            anchors.fill: parent
            visible: render.kind === "motion"
            playing: player.playbackState === MediaPlayer.PlayingState
            position: player.position
            duration: player.duration
            framed: false
            onToggled: root.togglePlay()
            onSeeked: function(ms) { root.seekTo(ms) }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            visible: render.kind === "static"
            text: render.answer ? render.answer.width + " × " + render.answer.height : ""
            color: Theme.color.muted
            font.family: Theme.font.family
            font.pixelSize: Theme.font.caption
            textFormat: Text.PlainText
        }
    }
}
