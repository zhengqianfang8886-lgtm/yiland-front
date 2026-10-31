// ==========================================
// 📄 File: ui/components/compact/CompactImeView.qml
// 🌟 纯粹的内容展示层 (外观与行为已彻底解耦至 FluidSlotPod)
// ==========================================
import QtQuick

Item {
    id: imeRoot
    anchors.fill: parent

    property string fontFam: "Monospace"
    readonly property string iconUrl: (typeof Bridge !== "undefined" && Bridge.imeIcon !== undefined) ? Bridge.imeIcon : ""
    readonly property string fallbackLabel: (typeof Bridge !== "undefined" && Bridge.imeLabel !== undefined) ? Bridge.imeLabel : "A"

    Row {
        anchors.centerIn: parent

        Image {
            width: 16; height: 16
            source: imeRoot.iconUrl
            fillMode: Image.PreserveAspectFit
            visible: imeRoot.iconUrl !== "" && status === Image.Ready
            smooth: true; mipmap: true
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: imeRoot.fallbackLabel
            color: "#ffffff"
            font.family: imeRoot.fontFam
            font.pixelSize: (imeRoot.fallbackLabel === "A" || imeRoot.fallbackLabel === "朗") ? 14 : 12
            font.weight: Font.Bold
            visible: !parent.children[0].visible
            anchors.verticalCenter: parent.verticalCenter
            renderType: Text.QtRendering
        }
    }
}