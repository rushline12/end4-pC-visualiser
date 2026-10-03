import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.background.widgets

// VisualizerWidget — ii-p3drovfx widget extension
// Ported from end4-pC to ii-p3drovfx
// Injected by extension system: widgetExtensionId, widgetConfig

AbstractBackgroundWidget {
    id: root

    // Extension system injects these at runtime
    property string widgetExtensionId: ""
    property var    widgetConfig: ({})
    property bool   wallpaperSafetyTriggered: false

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool isPlaying: Boolean(activePlayer && activePlayer.isPlaying)

    // Config accessors with defaults from widgetConfig or fallback
    property bool clickthrough: (widgetConfig && widgetConfig.clickthrough !== undefined) ? widgetConfig.clickthrough :
        ((Config.options && Config.options.background && Config.options.background.widgets && Config.options.background.widgets.visualizer && Config.options.background.widgets.visualizer.clickthrough !== undefined) ? Config.options.background.widgets.visualizer.clickthrough : true)

    enabled: !clickthrough
    acceptedButtons: clickthrough ? Qt.NoButton : (allowMiddleClick ? (Qt.MiddleButton | Qt.LeftButton) : Qt.LeftButton)

    property real barWidth: (widgetConfig && widgetConfig.barWidth !== undefined) ? widgetConfig.barWidth : 4
    property real barSpacing: (widgetConfig && widgetConfig.barSpacing !== undefined) ? widgetConfig.barSpacing : 8
    property real maxBarHeight: (widgetConfig && widgetConfig.maxBarHeight !== undefined) ? widgetConfig.maxBarHeight : 220
    property real smoothingDuration: (widgetConfig && widgetConfig.smoothingDuration !== undefined) ? widgetConfig.smoothingDuration : 150
    property real maxVisualizerValue: 1000

    // Real Cava points or decorative waveform preview when in settings preview
    readonly property var points: {
        if (root.isPreview && (!CavaService.visualizerPoints || CavaService.visualizerPoints.length === 0)) {
            let dummy = [];
            for (let i = 0; i < 64; i++) {
                let v = Math.sin(i * 0.25) * 350 + Math.cos(i * 0.5) * 150 + 450;
                dummy.push(Math.max(50, v));
            }
            return dummy;
        }
        return CavaService.visualizerPoints;
    }

    readonly property int barCount: Math.max(1, Math.floor(screenWidth / (barWidth + barSpacing)))

    readonly property var smoothedPoints: {
        let raw = points
        if (!raw || raw.length === 0) return Array(barCount).fill(0)
        let count = barCount
        let mapped = new Array(count)
        let rawLenM1 = raw.length - 1

        for (let i = 0; i < count; i++) {
            let progress = i / (count - 1 || 1)
            let relPos = progress * rawLenM1
            let low = Math.floor(relPos)
            let high = Math.ceil(relPos)
            let mix = relPos - low
            mapped[i] = (raw[low] * (1 - mix)) + (raw[high] * (high < raw.length ? mix : 0))
        }

        let smoothed = new Array(count)
        let sW = 0.2
        for (let j = 0; j < count; j++) {
            let p = mapped[Math.max(0, j - 1)]
            let n = mapped[Math.min(count - 1, j + 1)]
            smoothed[j] = (p * sW) + (mapped[j] * (1.0 - 2 * sW)) + (n * sW)
        }
        return smoothed
    }

    property real activityOpacity: isPreview ? 1.0 : 0
    Behavior on activityOpacity {
        NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
    }

    Timer {
        id: silenceTimer
        interval: 1000
        onTriggered: {
            if (!root.isPreview)
                root.activityOpacity = 0
        }
    }

    onPointsChanged: {
        if (points.some(p => p > 0)) {
            root.activityOpacity = 1.0
            silenceTimer.restart()
        }
    }

    implicitWidth: screenWidth
    implicitHeight: maxBarHeight + 20
    width: screenWidth
    height: implicitHeight

    targetX: 0
    targetY: isPreview ? 0 : (screenHeight - height)
    x: 0
    y: isPreview ? 0 : (screenHeight - height)
    draggable: false

    // Full-width widget: opt out of the 0.85 lock-animation shrink
    scale: _effectiveInstanceScale * (Config.options.background.widgets.widgetsScale ?? 1.0) * lifecycleScale

    Row {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: root.barSpacing
        opacity: root.activityOpacity

        Behavior on opacity {
            NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
        }

        Repeater {
            model: root.barCount
            Rectangle {
                required property int index
                width: root.barWidth
                property real pointValue: {
                    const v = root.smoothedPoints[index] ?? 0
                    return Math.max(root.barWidth, (v / root.maxVisualizerValue) * root.maxBarHeight)
                }
                height: pointValue
                topLeftRadius: root.barWidth / 2
                topRightRadius: root.barWidth / 2
                anchors.bottom: parent.bottom

                property real intensity: pointValue / root.maxBarHeight
                color: Qt.rgba(
                    Appearance.colors.colPrimary.r * intensity + Appearance.colors.colPrimaryContainer.r * (1 - intensity),
                    Appearance.colors.colPrimary.g * intensity + Appearance.colors.colPrimaryContainer.g * (1 - intensity),
                    Appearance.colors.colPrimary.b * intensity + Appearance.colors.colPrimaryContainer.b * (1 - intensity),
                    1
                )

                Behavior on height {
                    NumberAnimation { duration: root.smoothingDuration; easing.type: Easing.OutQuad }
                }
            }
        }
    }
}
