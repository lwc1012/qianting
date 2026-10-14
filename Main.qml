import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick3D
import QtQuick3D.Helpers
import QtTextToSpeech
import QtQuick.LocalStorage

ApplicationWindow {
    id: window
    width: 1380
    height: 850
    visible: true
    title: "深潜救生艇潜浮均衡智能计算系统"

    Component.onCompleted: {
        initExperienceDB();
    }

    property color themeBg: "#0e141b"
    property color panelBg: Qt.rgba(0.11, 0.16, 0.22, 0.85)
    property color borderColor: "#2c3b49"
    property color accentColor: "#4cc9f0"
    property color warningColor: "#ff3d00"
    property color textMain: "#e1e6eb"
    property color textDim: "#8f9bb3"
    property bool voiceProcessing: false

    color: themeBg

    TextToSpeech {
        id: tts
    }

    ListModel {
        id: personModel
        // 结构: { name: "乘员1", weight: 65, pos: 10 }
    }

    readonly property double waterDensity: 1.02
    readonly property double leadWeight: 20.0
    readonly property double ironWeight: 618.0
    readonly property var leadPos: { 1: -3.159, 2: -0.5, 3: 2.26 }
    readonly property var seatLong: {
        1: -0.157, 2: 0.073, 3: 0.313, 4: 0.643, 5: 0.883, 6: 1.103,
        7: 1.343, 8: 1.563, 9: 1.803, 10: 2.023, 11: 2.373, 12: 2.593,
        13: 2.833, 14: 3.053, 15: 3.403, 16: 3.513, 17: 3.826, 18: 3.928
    }
    readonly property var seatTrans: {
        1: -0.424, 2: 0.424, 3: -0.424, 4: 0.424, 5: -0.424, 6: 0.424,
        7: -0.424, 8: 0.424, 9: -0.424, 10: 0.424, 11: -0.424, 12: 0.424,
        13: -0.424, 14: 0.424, 15: -0.424, 16: 0.424, 17: -0.379, 18: 0.379
    }
    readonly property var tankLong: { 1: 1.243, 2: 1.932, 3: 2.621, 4: 3.31 }
    readonly property double tankCapacity: 142.5
    readonly property double airTailLong: 3.837
    readonly property double airTailCapacity: 600.0
    readonly property double commandTankLong: -2.969
    readonly property double commandTankCapacity: 430.0


    component DarkField : TextField {
        color: accentColor
        font.pixelSize: 12
        font.family: "Courier New"
        background: Rectangle {
            color: "#080b0f"
            border.color: parent.activeFocus ? accentColor : borderColor
            border.width: 1
        }
    }

    component LabelInput : RowLayout {
        property alias text: field.text
        property string labelText: ""
        property string suffix: ""
        property int labelWidth: 60
        Label { text: labelText; color: textDim; font.pixelSize: 12; Layout.preferredWidth: labelWidth }
        DarkField { id: field; Layout.fillWidth: true; text: "0" }
        Label { text: suffix; color: textDim; font.pixelSize: 12; visible: suffix !== "" }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            color: panelBg
            border.color: accentColor
            border.width: 1
            radius: 2

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20

                Row {
                    Layout.alignment: Qt.AlignLeft
                    spacing: 10
                    Image {
                        source: "maps/submarine_side_view.png"
                        width: 32
                        height: 32
                        fillMode: Image.PreserveAspectFit
                    }
                    Label {
                        text: "深潜救生艇潜浮均衡智能计算系统"
                        font.pixelSize: 16
                        font.bold: true
                        font.letterSpacing: 1.2
                        color: accentColor
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    Layout.alignment: Qt.AlignRight
                    spacing: 16
                    Image {
                        source: "maps/submarine_academy.png"
                        width: 28
                        height: 28
                        fillMode: Image.PreserveAspectFit
                    }
                    Image {
                        source: "maps/sdu_logo.svg"
                        width: 28
                        height: 28
                        fillMode: Image.PreserveAspectFit
                    }
                }
            }
        }

        RowLayout {
            Layout.fillHeight: true
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"
                border.color: borderColor
                border.width: 1

                View3D {
                    id: view3D
                    anchors.fill: parent
                    anchors.margins: 1

                    // -55是水面高度
                    Texture {
                        id: dynamicSky
                        textureData: ProceduralSkyTextureData {
                            Behavior on skyTopColor { ColorAnimation { duration: 800; easing.type: Easing.InOutQuad } }
                            Behavior on skyHorizonColor { ColorAnimation { duration: 800; easing.type: Easing.InOutQuad } }
                            Behavior on groundHorizonColor { ColorAnimation { duration: 800; easing.type: Easing.InOutQuad } }
                            Behavior on groundBottomColor { ColorAnimation { duration: 800; easing.type: Easing.InOutQuad } }
                            Behavior on sunColor { ColorAnimation { duration: 800; easing.type: Easing.InOutQuad } }

                            skyTopColor: view3D.isUnderwater ? "#1a4b77" : "#3a8ae0"
                            skyHorizonColor: view3D.isUnderwater ? "#051a30" : "#b3e5fc"
                            groundHorizonColor: view3D.isUnderwater ? "#000814" : "#1e5b8f"
                            groundBottomColor: view3D.isUnderwater ? "#000000" : "#0c2842"

                            sunColor: view3D.isUnderwater ? "#334cc9f0" : "#ffffee"
                            sunAngleMin: view3D.isUnderwater ? 15 : 2
                            sunAngleMax: view3D.isUnderwater ? 60 : 6
                        }
                    }

                    environment: SceneEnvironment {
                        backgroundMode: SceneEnvironment.SkyBox
                        lightProbe: dynamicSky
                        antialiasingMode: SceneEnvironment.MSAA
                        antialiasingQuality: SceneEnvironment.High

                        fog: Fog {
                            color: view3D.isUnderwater ? "#051a30" : "#b3e5fc"
                            density: view3D.isUnderwater ? 0.015 : 0.0005
                            depthEnabled: true
                            Behavior on color { ColorAnimation { duration: 800; easing.type: Easing.InOutQuad } }
                            Behavior on density { NumberAnimation { duration: 800; easing.type: Easing.InOutQuad } }
                        }
                    }

                    Node {
                        id: cameraOrbit
                        eulerRotation.x: -15
                        eulerRotation.y: 45
                        PerspectiveCamera {
                            id: camera
                            z: 350
                            y: 50
                            eulerRotation.x: -18
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        property point lastPos: Qt.point(0, 0)
                        onPressed: (mouse) => { lastPos = Qt.point(mouse.x, mouse.y) }
                        onPositionChanged: (mouse) => {
                            var deltaX = mouse.x - lastPos.x
                            var deltaY = mouse.y - lastPos.y
                            cameraOrbit.eulerRotation.y -= deltaX * 0.5
                            var newPitch = cameraOrbit.eulerRotation.x - deltaY * 0.5
                            if (newPitch > -80 && newPitch < 20) {
                                cameraOrbit.eulerRotation.x = newPitch
                            }
                            lastPos = Qt.point(mouse.x, mouse.y)
                        }
                    }

                    DirectionalLight {
                        eulerRotation.x: -45
                        eulerRotation.y: -30
                        brightness: view3D.isUnderwater ? 0.3 : 2.5
                        color: "#fffaec"
                    }

                    Model {
                        id: seaPlane
                        source: "meshes/water_plane.mesh"
                        scale: Qt.vector3d(10, 1, 10)
                        position: Qt.vector3d(0, -55, 0)

                        materials: [
                            CustomMaterial {
                                property real uTime: 0.0
                                NumberAnimation on uTime {
                                    from: 0.0; to: 1000.0; duration: 1000000
                                    loops: Animation.Infinite; running: true
                                }

                                vertexShader: "water.vert"
                                fragmentShader: "water.frag"

                                cullMode: Material.NoCulling
                                shadingMode: CustomMaterial.Shaded
                                sourceBlend: CustomMaterial.SrcAlpha
                                destinationBlend: CustomMaterial.OneMinusSrcAlpha
                            }
                        ]
                    }

                    Jiushengting {
                        id: ship
                        scale: Qt.vector3d(0.3, 0.3, 0.3)

                        x: 0
                        z: 0
                        y: (typeof statusCombo !== "undefined" && statusCombo.currentIndex === 1) ? -220 : -120

                        Behavior on y {
                            NumberAnimation { duration: 2000; easing.type: Easing.InOutQuad }
                        }

                        property real rollValue: typeof sensorData !== "undefined" ? sensorData.roll : 0.0
                        property real pitchValue: typeof sensorData !== "undefined" ? sensorData.pitch : 0.0
                        eulerRotation.z: rollValue
                        eulerRotation.x: pitchValue
                        Behavior on eulerRotation.z { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                        Behavior on eulerRotation.x { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                    }
                }

                Column {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.margins: 20
                    spacing: 10
                    Column {
                        spacing: 4
                        Rectangle { width: 100; height: 2; color: accentColor }
                        Text { text: "纵倾角"; color: textDim; font.pixelSize: 10; font.bold: true }
                        Text {
                            text: (-ship.eulerRotation.x).toFixed(1) + "°"
                            color: Math.abs(ship.eulerRotation.x) > 35.0 ? warningColor : "white"
                            font.pixelSize: 32; font.family: "Courier New"; font.bold: true
                        }
                    }
                    Column {
                        spacing: 4
                        Rectangle { width: 100; height: 2; color: accentColor }
                        Text { text: "横倾角"; color: textDim; font.pixelSize: 10; font.bold: true }
                        Text {
                            text: ship.eulerRotation.z.toFixed(1) + "°"
                            color: Math.abs(ship.eulerRotation.z) > 22.5 ? warningColor : "white"
                            font.pixelSize: 32; font.family: "Courier New"; font.bold: true
                        }
                    }
                }
                Image {
                    width: 20; height: 20
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.margins: 5
                    Canvas {
                        anchors.fill: parent
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.strokeStyle = accentColor; ctx.lineWidth = 2;
                            ctx.beginPath(); ctx.moveTo(0, 10); ctx.lineTo(0, 0); ctx.lineTo(10, 0); ctx.stroke();
                        }
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 480
                Layout.fillHeight: true
                color: panelBg
                border.color: borderColor
                border.width: 1
                radius: 2

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    RowLayout {
                        Rectangle { width: 4; height: 18; color: accentColor }
                        Label { text: "辅助决策中心"; color: textMain; font.pixelSize: 14; font.bold: true }
                        Item { Layout.fillWidth: true }
                    }

                    TabBar {
                        id: bar
                        Layout.fillWidth: true
                        background: Rectangle { color: "transparent" }

                        TabButton {
                            id: tabBtn1
                            text: "参数设定"
                            Layout.fillWidth: true
                            contentItem: Text {
                                text: parent.text
                                font.family: "Courier New"
                                color: parent.checked ? accentColor : textDim
                                horizontalAlignment: Text.AlignHCenter
                                font.bold: parent.checked
                            }
                            background: Rectangle {
                                color: parent.checked ? Qt.rgba(0.3, 0.8, 0.9, 0.1) : "transparent"
                                Rectangle {
                                    width: parent.width; height: 2
                                    anchors.bottom: parent.bottom
                                    color: tabBtn1.checked ? accentColor : "transparent"
                                }
                            }
                        }

                        TabButton {
                            id: tabBtn2
                            text: "系统日志"
                            Layout.fillWidth: true
                            contentItem: Text {
                                text: parent.text
                                font.family: "Courier New"
                                color: parent.checked ? accentColor : textDim
                                horizontalAlignment: Text.AlignHCenter
                                font.bold: parent.checked
                            }
                            background: Rectangle {
                                color: parent.checked ? Qt.rgba(0.3, 0.8, 0.9, 0.1) : "transparent"
                                Rectangle {
                                    width: parent.width; height: 2
                                    anchors.bottom: parent.bottom
                                    color: tabBtn2.checked ? accentColor : "transparent"
                                }
                            }
                        }

                        TabButton {
                            id: tabBtn3
                            text: "语音录入"
                            Layout.fillWidth: true
                            contentItem: Text {
                                text: parent.text
                                font.family: "Courier New"
                                color: parent.checked ? accentColor : textDim
                                horizontalAlignment: Text.AlignHCenter
                                font.bold: parent.checked
                            }
                            background: Rectangle {
                                color: parent.checked ? Qt.rgba(0.3, 0.8, 0.9, 0.1) : "transparent"
                                Rectangle {
                                    width: parent.width; height: 2
                                    anchors.bottom: parent.bottom
                                    color: tabBtn3.checked ? accentColor : "transparent"
                                }
                            }
                        }
                    }

                    StackLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        currentIndex: bar.currentIndex

                        ScrollView {
                            id: scrollView
                            clip: true
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            ScrollBar.vertical.policy: ScrollBar.AsNeeded

                            ColumnLayout {
                                width: scrollView.availableWidth
                                spacing: 15

                                GroupBox {
                                    title: "潜浮状态"
                                    Layout.fillWidth: true
                                    background: Rectangle { color: "transparent"; border.color: borderColor; border.width: 1 }
                                    label: Label { text: parent.title; color: accentColor; font.bold: true; padding: 5 }

                                    ColumnLayout {
                                        width: parent.width
                                        ComboBox {
                                            id: statusCombo
                                            Layout.fillWidth: true
                                            model: ["水面", "水下"]
                                            currentIndex: 0
                                            contentItem: Text {
                                                text: parent.displayText; color: textMain; leftPadding: 10; verticalAlignment: Text.AlignVCenter
                                            }
                                            background: Rectangle { color: "#080b0f"; border.color: borderColor }
                                            popup: Popup {
                                                y: parent.height - 1
                                                width: parent.width
                                                padding: 1
                                                contentItem: ListView {
                                                    implicitHeight: contentHeight
                                                    model: statusCombo.delegateModel
                                                }
                                                background: Rectangle { color: themeBg; border.color: accentColor }
                                            }
                                        }
                                    }
                                }

                                GroupBox {
                                    title: "均衡水舱 (L)"
                                    Layout.fillWidth: true
                                    background: Rectangle { color: "transparent"; border.color: borderColor; border.width: 1 }
                                    label: Label { text: parent.title; color: accentColor; font.bold: true; padding: 5 }

                                    GridLayout {
                                        columns: 2
                                        width: parent.width
                                        rowSpacing: 8; columnSpacing: 10

                                        LabelInput { labelText: "指挥舱1:"; id: tCmd1; text: "215"; labelWidth: 60 }
                                        LabelInput { labelText: "指挥舱2:"; id: tCmd2; text: "215"; labelWidth: 60 }
                                        LabelInput { labelText: "救生舱1:"; id: t1; text: "71.25"; labelWidth: 60 }
                                        LabelInput { labelText: "救生舱2:"; id: t2; text: "71.25"; labelWidth: 60 }
                                        LabelInput { labelText: "救生舱3:"; id: t3; text: "71.25"; labelWidth: 60 }
                                        LabelInput { labelText: "救生舱4:"; id: t4; text: "71.25"; labelWidth: 60 }
                                        LabelInput { labelText: "救生舱5:"; id: t5; text: "71.25"; labelWidth: 60 }
                                        LabelInput { labelText: "救生舱6:"; id: t6; text: "71.25"; labelWidth: 60 }
                                        LabelInput { labelText: "救生舱7:"; id: t7; text: "71.25"; labelWidth: 60 }
                                        LabelInput { labelText: "救生舱8:"; id: t8; text: "71.25"; labelWidth: 60 }
                                    }
                                }

                                GroupBox {
                                    title: "压铅 (块/20kg)"
                                    Layout.fillWidth: true
                                    background: Rectangle { color: "transparent"; border.color: borderColor; border.width: 1 }
                                    label: Label { text: parent.title; color: accentColor; font.bold: true; padding: 5 }

                                    GridLayout {
                                        width: parent.width
                                        columns: 3
                                        columnSpacing: 5

                                        LabelInput { labelText: "艏："; id: l1; text: "5"; Layout.fillWidth: true; labelWidth: 30 }
                                        LabelInput { labelText: "舯："; id: l2; text: "18"; Layout.fillWidth: true; labelWidth: 30 }
                                        LabelInput { labelText: "艉："; id: l3; text: "2"; Layout.fillWidth: true; labelWidth: 30 }
                                    }
                                }

                                GroupBox {
                                    background: Rectangle { color: "transparent"; border.color: "transparent" }
                                    Layout.fillWidth: true
                                    padding: 0
                                    contentItem: RowLayout {
                                        Label { text: "压载水舱 (600L)"; color: textDim }
                                        Item { Layout.fillWidth: true }
                                        Switch {
                                            id: airSwitch
                                            text: checked ? "FULL" : "EMPTY"
                                            checked: true
                                            contentItem: Text {
                                                text: parent.text; color: parent.checked ? accentColor : textDim
                                                verticalAlignment: Text.AlignVCenter
                                                leftPadding: parent.indicator.width + 4
                                            }
                                        }
                                    }
                                }

                                GroupBox {
                                    title: "艇员配置(kg)"
                                    Layout.fillWidth: true
                                    background: Rectangle { color: "transparent"; border.color: borderColor; border.width: 1 }
                                    label: Label { text: parent.title; color: accentColor; font.bold: true; padding: 5 }

                                    ColumnLayout {
                                        width: parent.width
                                        spacing: 10

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 170
                                            color: "#080b0f"
                                            border.color: borderColor
                                            border.width: 1
                                            radius: 4
                                            clip: true

                                            Image {
                                                id: seatMapImage
                                                source: "maps/seats.png"
                                                anchors.fill: parent
                                                anchors.margins: 5
                                                fillMode: Image.PreserveAspectFit

                                                // -1 为未选中
                                                property int currentInputSeat: -1

                                                // 座位相对坐标系 (x, y 取值 0.0-1.0)
                                                property var seatCoords: [
                                                    { text: "固", isFixed: true,  x: 0.81, y: 0.5, id: 0 },
                                                    { text: "固", isFixed: true,  x: 0.63, y: 0.5, id: 0 },
                                                    { text: "固", isFixed: true,  x: 0.54, y: 0.62, id: 0 },

                                                    { text: "1",  isFixed: false, x: 0.52, y: 0.37, id: 1 },
                                                    { text: "2",  isFixed: false, x: 0.50, y: 0.62, id: 2 },
                                                    { text: "3",  isFixed: false, x: 0.47, y: 0.38, id: 3 },
                                                    { text: "4",  isFixed: false, x: 0.44, y: 0.63, id: 4 },
                                                    { text: "5",  isFixed: false, x: 0.42, y: 0.38, id: 5 },
                                                    { text: "6",  isFixed: false, x: 0.39, y: 0.62, id: 6 },
                                                    { text: "7",  isFixed: false, x: 0.37, y: 0.37, id: 7 },
                                                    { text: "8",  isFixed: false, x: 0.35, y: 0.62, id: 8 },
                                                    { text: "9",  isFixed: false, x: 0.32, y: 0.37, id: 9 },
                                                    { text: "10", isFixed: false, x: 0.30, y: 0.62, id: 10 },
                                                    { text: "11", isFixed: false, x: 0.27, y: 0.37, id: 11 },
                                                    { text: "12", isFixed: false, x: 0.24, y: 0.62, id: 12 },
                                                    { text: "13", isFixed: false, x: 0.22, y: 0.37, id: 13 },
                                                    { text: "14", isFixed: false, x: 0.19, y: 0.62, id: 14 },
                                                    { text: "15", isFixed: false, x: 0.16, y: 0.36, id: 15 },
                                                    { text: "16", isFixed: false, x: 0.15, y: 0.62, id: 16 },
                                                    { text: "17", isFixed: false, x: 0.12, y: 0.38, id: 17 },
                                                    { text: "18", isFixed: false, x: 0.10, y: 0.60, id: 18 }
                                                ]

                                                Repeater {
                                                    model: seatMapImage.seatCoords
                                                    Rectangle {
                                                        x: modelData.x * seatMapImage.paintedWidth + (seatMapImage.width - seatMapImage.paintedWidth) / 2 - width / 2
                                                        y: modelData.y * seatMapImage.paintedHeight + (seatMapImage.height - seatMapImage.paintedHeight) / 2 - height / 2
                                                        width: 20
                                                        height: 20
                                                        radius: 10

                                                        property bool isFocused: seatMapImage.currentInputSeat === modelData.id
                                                        property bool isOccupied: {
                                                            if (modelData.isFixed) return true;
                                                            var val = 0;
                                                            switch(modelData.id) {
                                                                case 1: val = parseFloat(crew1.text); break;
                                                                case 2: val = parseFloat(crew2.text); break;
                                                                case 3: val = parseFloat(crew3.text); break;
                                                                case 4: val = parseFloat(crew4.text); break;
                                                                case 5: val = parseFloat(crew5.text); break;
                                                                case 6: val = parseFloat(crew6.text); break;
                                                                case 7: val = parseFloat(crew7.text); break;
                                                                case 8: val = parseFloat(crew8.text); break;
                                                                case 9: val = parseFloat(crew9.text); break;
                                                                case 10: val = parseFloat(crew10.text); break;
                                                                case 11: val = parseFloat(crew11.text); break;
                                                                case 12: val = parseFloat(crew12.text); break;
                                                                case 13: val = parseFloat(crew13.text); break;
                                                                case 14: val = parseFloat(crew14.text); break;
                                                                case 15: val = parseFloat(crew15.text); break;
                                                                case 16: val = parseFloat(crew16.text); break;
                                                                case 17: val = parseFloat(crew17.text); break;
                                                                case 18: val = parseFloat(crew18.text); break;
                                                            }
                                                            return !isNaN(val) && val > 0;
                                                        }

                                                        color: {
                                                            if (modelData.isFixed) return "#00ff9d";
                                                            if (isFocused) return Qt.rgba(1, 0.6, 0, 0.9);
                                                            if (isOccupied) return "#ffd700";
                                                            return Qt.rgba(0.3, 0.8, 0.9, 0.3);
                                                        }

                                                        border.color: {
                                                            if (modelData.isFixed) return "#00cc7d";
                                                            if (isFocused) return warningColor;
                                                            if (isOccupied) return "#ccac00";
                                                            return accentColor;
                                                        }
                                                        border.width: isFocused ? 2 : 1

                                                        SequentialAnimation on scale {
                                                            running: isFocused
                                                            loops: Animation.Infinite
                                                            NumberAnimation { from: 1.0; to: 1.4; duration: 600; easing.type: Easing.InOutQuad }
                                                            NumberAnimation { from: 1.4; to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
                                                        }

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: {
                                                                if (modelData.isFixed) return "固";
                                                                if (isFocused) return modelData.text;
                                                                if (isOccupied) return "占";
                                                                return modelData.text;
                                                            }
                                                            color: (modelData.isFixed || isOccupied || isFocused) ? "#000000" : textMain
                                                            font.pixelSize: (text === "占" || text === "固") ? 10 : 9
                                                            font.bold: true
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        ColumnLayout {
                                            width: parent.width
                                            spacing: 6

                                            RowLayout {
                                                spacing: 5
                                                Label { text: "艇员1:"; color: textDim; font.pixelSize: 11; Layout.preferredWidth: 45 }
                                                DarkField { id: crew1; Layout.fillWidth: true; Layout.preferredWidth: 1; inputMethodHints: Qt.ImhFormattedNumbersOnly; onActiveFocusChanged: { if(activeFocus) seatMapImage.currentInputSeat = 1 } }
                                                Label { text: "艇员2:"; color: textDim; font.pixelSize: 11; Layout.preferredWidth: 45 }
                                                DarkField { id: crew2; Layout.fillWidth: true; Layout.preferredWidth: 1; inputMethodHints: Qt.ImhFormattedNumbersOnly; onActiveFocusChanged: { if(activeFocus) seatMapImage.currentInputSeat = 2 } }
                                            }
                                            RowLayout {
                                                spacing: 5
                                                Label { text: "艇员3:"; color: textDim; font.pixelSize: 11; Layout.preferredWidth: 45 }
                                                DarkField { id: crew3; Layout.fillWidth: true; Layout.preferredWidth: 1; inputMethodHints: Qt.ImhFormattedNumbersOnly; onActiveFocusChanged: { if(activeFocus) seatMapImage.currentInputSeat = 3 } }
                                                Label { text: "艇员4:"; color: textDim; font.pixelSize: 11; Layout.preferredWidth: 45 }
                                                DarkField { id: crew4; Layout.fillWidth: true; Layout.preferredWidth: 1; inputMethodHints: Qt.ImhFormattedNumbersOnly; onActiveFocusChanged: { if(activeFocus) seatMapImage.currentInputSeat = 4 } }
                                            }
                                            RowLayout {
                                                spacing: 5
                                                Label { text: "艇员5:"; color: textDim; font.pixelSize: 11; Layout.preferredWidth: 45 }
                                                DarkField { id: crew5; Layout.fillWidth: true; Layout.preferredWidth: 1; inputMethodHints: Qt.ImhFormattedNumbersOnly; onActiveFocusChanged: { if(activeFocus) seatMapImage.currentInputSeat = 5 } }
                                                Label { text: "艇员6:"; color: textDim; font.pixelSize: 11; Layout.preferredWidth: 45 }
                                                DarkField { id: crew6; Layout.fillWidth: true; Layout.preferredWidth: 1; inputMethodHints: Qt.ImhFormattedNumbersOnly; onActiveFocusChanged: { if(activeFocus) seatMapImage.currentInputSeat = 6 } }
                                            }
                                            RowLayout {
                                                spacing: 5
                                                Label { text: "艇员7:"; color: textDim; font.pixelSize: 11; Layout.preferredWidth: 45 }
                                                DarkField { id: crew7; Layout.fillWidth: true; Layout.preferredWidth: 1; inputMethodHints: Qt.ImhFormattedNumbersOnly; onActiveFocusChanged: { if(activeFocus) seatMapImage.currentInputSeat = 7 } }
                                                Label { text: "艇员8:"; color: textDim; font.pixelSize: 11; Layout.preferredWidth: 45 }
                                                DarkField { id: crew8; Layout.fillWidth: true; Layout.preferredWidth: 1; inputMethodHints: Qt.ImhFormattedNumbersOnly; onActiveFocusChanged: { if(activeFocus) seatMapImage.currentInputSeat = 8 } }
                                            }
                                            RowLayout {
                                                spacing: 5
                                                Label { text: "艇员9:"; color: textDim; font.pixelSize: 11; Layout.preferredWidth: 45 }
                                                DarkField { id: crew9; Layout.fillWidth: true; Layout.preferredWidth: 1; inputMethodHints: Qt.ImhFormattedNumbersOnly; onActiveFocusChanged: { if(activeFocus) seatMapImage.currentInputSeat = 9 } }
                                                Label { text: "艇员10:"; color: textDim; font.pixelSize: 11; Layout.preferredWidth: 45 }
                                                DarkField { id: crew10; Layout.fillWidth: true; Layout.preferredWidth: 1; inputMethodHints: Qt.ImhFormattedNumbersOnly; onActiveFocusChanged: { if(activeFocus) seatMapImage.currentInputSeat = 10 } }
                                            }
                                            RowLayout {
                                                spacing: 5
                                                Label { text: "艇员11:"; color: textDim; font.pixelSize: 11; Layout.preferredWidth: 45 }
                                                DarkField { id: crew11; Layout.fillWidth: true; Layout.preferredWidth: 1; inputMethodHints: Qt.ImhFormattedNumbersOnly; onActiveFocusChanged: { if(activeFocus) seatMapImage.currentInputSeat = 11 } }
                                                Label { text: "艇员12:"; color: textDim; font.pixelSize: 11; Layout.preferredWidth: 45 }
                                                DarkField { id: crew12; Layout.fillWidth: true; Layout.preferredWidth: 1; inputMethodHints: Qt.ImhFormattedNumbersOnly; onActiveFocusChanged: { if(activeFocus) seatMapImage.currentInputSeat = 12 } }
                                            }
                                            RowLayout {
                                                spacing: 5
                                                Label { text: "艇员13:"; color: textDim; font.pixelSize: 11; Layout.preferredWidth: 45 }
                                                DarkField { id: crew13; Layout.fillWidth: true; Layout.preferredWidth: 1; inputMethodHints: Qt.ImhFormattedNumbersOnly; onActiveFocusChanged: { if(activeFocus) seatMapImage.currentInputSeat = 13 } }
                                                Label { text: "艇员14:"; color: textDim; font.pixelSize: 11; Layout.preferredWidth: 45 }
                                                DarkField { id: crew14; Layout.fillWidth: true; Layout.preferredWidth: 1; inputMethodHints: Qt.ImhFormattedNumbersOnly; onActiveFocusChanged: { if(activeFocus) seatMapImage.currentInputSeat = 14 } }
                                            }
                                            RowLayout {
                                                spacing: 5
                                                Label { text: "艇员15:"; color: textDim; font.pixelSize: 11; Layout.preferredWidth: 45 }
                                                DarkField { id: crew15; Layout.fillWidth: true; Layout.preferredWidth: 1; inputMethodHints: Qt.ImhFormattedNumbersOnly; onActiveFocusChanged: { if(activeFocus) seatMapImage.currentInputSeat = 15 } }
                                                Label { text: "艇员16:"; color: textDim; font.pixelSize: 11; Layout.preferredWidth: 45 }
                                                DarkField { id: crew16; Layout.fillWidth: true; Layout.preferredWidth: 1; inputMethodHints: Qt.ImhFormattedNumbersOnly; onActiveFocusChanged: { if(activeFocus) seatMapImage.currentInputSeat = 16 } }
                                            }
                                            RowLayout {
                                                spacing: 5
                                                Label { text: "艇员17:"; color: textDim; font.pixelSize: 11; Layout.preferredWidth: 45 }
                                                DarkField { id: crew17; Layout.fillWidth: true; Layout.preferredWidth: 1; inputMethodHints: Qt.ImhFormattedNumbersOnly; onActiveFocusChanged: { if(activeFocus) seatMapImage.currentInputSeat = 17 } }
                                                Label { text: "艇员18:"; color: textDim; font.pixelSize: 11; Layout.preferredWidth: 45 }
                                                DarkField { id: crew18; Layout.fillWidth: true; Layout.preferredWidth: 1; inputMethodHints: Qt.ImhFormattedNumbersOnly; onActiveFocusChanged: { if(activeFocus) seatMapImage.currentInputSeat = 18 } }
                                            }
                                        }
                                    }
                                }

                                Item { height: 20 }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 8

                            GroupBox {
                                title: "人工决策经验库录入"
                                Layout.fillWidth: true
                                background: Rectangle {
                                    color: "transparent"
                                    border.color: borderColor
                                    border.width: 1
                                    radius: 2
                                }
                                label: Label {
                                    text: parent.title
                                    color: accentColor
                                    font.bold: true
                                    padding: 5
                                }

                                contentItem: RowLayout {
                                    spacing: 8

                                    DarkField {
                                        id: userDecisionInput
                                        Layout.fillWidth: true
                                        placeholderText: "输入最终决策，系统将记录入库..."
                                        onAccepted: saveUserDecision()
                                    }

                                    Button {
                                        text: "写入经验库"
                                        palette.buttonText: themeBg
                                        palette.button: accentColor
                                        onClicked: saveUserDecision()
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: "#080b0f"
                                border.color: borderColor
                                border.width: 1
                                radius: 2

                                ScrollView {
                                    anchors.fill: parent
                                    anchors.margins: 5
                                    TextArea {
                                        id: logArea
                                        text: "系统加载完毕，等待参数输入"
                                        textFormat: Text.RichText
                                        color: accentColor
                                        font.pixelSize: 13
                                        font.family: "Courier New"
                                        wrapMode: Text.WordWrap
                                        readOnly: true
                                        background: null
                                    }
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 15
                                spacing: 20

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 60
                                    color: Qt.rgba(0.0, 0.0, 0.0, 0.3)
                                    border.color: voiceBtn.pressed ? warningColor : (voiceProcessing ? accentColor : borderColor)
                                    border.width: 1
                                    radius: 4

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        Label {
                                            text: voiceBtn.pressed ? "🔴 正在聆听指令..." :
                                                 (voiceProcessing  ? "⚙️ 正在解析语义..." : "🟢 系统就绪，请按住下方按钮说话")

                                            color: voiceBtn.pressed ? warningColor : accentColor

                                            font.pixelSize: 14
                                            font.bold: true
                                            Layout.fillWidth: true
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 180
                                    Rectangle {
                                        id: pulseRing
                                        anchors.centerIn: parent
                                        width: voiceBtn.width
                                        height: voiceBtn.height
                                        radius: width / 2
                                        color: "transparent"
                                        border.color: warningColor
                                        border.width: 2
                                        opacity: 0
                                        visible: voiceBtn.pressed

                                        SequentialAnimation on scale {
                                            running: voiceBtn.pressed
                                            loops: Animation.Infinite
                                            NumberAnimation { from: 1.0; to: 1.5; duration: 1000; easing.type: Easing.OutQuad }
                                        }
                                        SequentialAnimation on opacity {
                                            running: voiceBtn.pressed
                                            loops: Animation.Infinite
                                            NumberAnimation { from: 0.8; to: 0.0; duration: 1000; easing.type: Easing.OutQuad }
                                        }
                                    }

                                    Rectangle {
                                        id: voiceBtn
                                        width: 120
                                        height: 120
                                        radius: 60
                                        anchors.centerIn: parent
                                        color: pressed ? Qt.rgba(1, 0.2, 0, 0.2) : panelBg
                                        border.color: pressed ? warningColor : accentColor
                                        border.width: 2

                                        property bool pressed: false

                                        Text {
                                            anchors.centerIn: parent
                                            text: "🎙️\n按住说话"
                                            color: parent.pressed ? warningColor : accentColor
                                            font.pixelSize: 16
                                            font.bold: true
                                            horizontalAlignment: Text.AlignHCenter
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            onPressed: {
                                                voiceBtn.pressed = true;
                                                tts.stop();
                                                VoiceController.startRecording()
                                            }
                                            onReleased: {
                                                voiceBtn.pressed = false;
                                                voiceProcessing = true;
                                                VoiceController.stopRecordingAndProcess()
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 120
                                    color: Qt.rgba(0.0, 0.0, 0.0, 0.3)
                                    border.color: borderColor
                                    border.width: 1
                                    radius: 4

                                    Label {
                                        id: voiceHintText
                                        anchors.centerIn: parent
                                        width: parent.width - 40
                                        wrapMode: Text.WordWrap
                                        visible: !voiceBtn.pressed && !voiceProcessing
                                        text: "提示：您可以说「切换到水中平衡，救生舱1有水50升，上来个75公斤的人坐3号位。」"
                                        color: textDim
                                        font.pixelSize: 13
                                        font.bold: true
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 15
                                        visible: voiceProcessing && !voiceBtn.pressed

                                        Item {
                                            id: loadingSpinner
                                            width: 30
                                            height: 30
                                            anchors.verticalCenter: parent.verticalCenter

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: width / 2
                                                color: "transparent"
                                                border.color: Qt.rgba(1, 1, 1, 0.1)
                                                border.width: 3
                                            }

                                            Item {
                                                anchors.fill: parent

                                                RotationAnimator on rotation {
                                                    loops: Animation.Infinite
                                                    from: 0
                                                    to: 360
                                                    duration: 1000
                                                    running: voiceProcessing
                                                }

                                                Rectangle {
                                                    width: 10
                                                    height: 10
                                                    radius: 5
                                                    color: accentColor
                                                    anchors.top: parent.top
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                }
                                            }
                                        }

                                        Label {
                                            text: "⚙️ 正在解析语义，请稍候..."
                                            color: accentColor
                                            font.pixelSize: 14
                                            font.bold: true
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    Label {
                                        anchors.centerIn: parent
                                        visible: voiceBtn.pressed
                                        text: "🔴 正在聆听指令..."
                                        color: warningColor
                                        font.pixelSize: 14
                                        font.bold: true
                                    }

                                    Label {
                                        id: voiceDoneText
                                        anchors.centerIn: parent
                                        visible: false
                                        text: "✅ 参数提取完成"
                                        color: "#00ff9d"
                                        font.pixelSize: 14
                                        font.bold: true
                                    }
                                }

                                Connections {
                                    target: VoiceController

                                    function onParametersExtracted(jsonData) {
                                        try {
                                            var data = JSON.parse(jsonData);

                                            if (data.status !== undefined) {
                                                statusCombo.currentIndex = data.status;
                                            }

                                            if (data.ballast) {
                                                if (data.ballast.t1 !== undefined && data.ballast.t1 !== null) t1.text = data.ballast.t1.toString();
                                                if (data.ballast.t2 !== undefined && data.ballast.t2 !== null) t2.text = data.ballast.t2.toString();
                                                if (data.ballast.t3 !== undefined && data.ballast.t3 !== null) t3.text = data.ballast.t3.toString();
                                                if (data.ballast.t4 !== undefined && data.ballast.t4 !== null) t4.text = data.ballast.t4.toString();
                                                if (data.ballast.t5 !== undefined && data.ballast.t5 !== null) t5.text = data.ballast.t5.toString();
                                                if (data.ballast.t6 !== undefined && data.ballast.t6 !== null) t6.text = data.ballast.t6.toString();
                                                if (data.ballast.t7 !== undefined && data.ballast.t7 !== null) t7.text = data.ballast.t7.toString();
                                                if (data.ballast.t8 !== undefined && data.ballast.t8 !== null) t8.text = data.ballast.t8.toString();
                                                if (data.ballast.tCmd1 !== undefined && data.ballast.tCmd1 !== null) tCmd1.text = data.ballast.tCmd1.toString();
                                                if (data.ballast.tCmd2 !== undefined && data.ballast.tCmd2 !== null) tCmd2.text = data.ballast.tCmd2.toString();
                                            }

                                            if (data.leads) {
                                                if (data.leads.l1 !== undefined && data.leads.l1 !== null) l1.text = data.leads.l1.toString();
                                                if (data.leads.l2 !== undefined && data.leads.l2 !== null) l2.text = data.leads.l2.toString();
                                                if (data.leads.l3 !== undefined && data.leads.l3 !== null) l3.text = data.leads.l3.toString();
                                            }

                                            if (data.personnel && Array.isArray(data.personnel)) {
                                                var crewFields = [crew1, crew2, crew3, crew4, crew5, crew6, crew7, crew8, crew9, crew10, crew11, crew12, crew13, crew14, crew15, crew16, crew17, crew18];
                                                crewFields.forEach(function(field) { field.text = ""; });
                                                data.personnel.forEach(function(p) {
                                                    if (p.pos >= 1 && p.pos <= 18) {
                                                        crewFields[p.pos - 1].text = p.weight.toString();
                                                    }
                                                });
                                            }

                                            voiceProcessing = false;
                                            voiceDoneText.visible = true;
                                            tts.say("参数提取完成，界面已更新");
                                            Qt.callLater(function() {voiceDoneText.visible = false;}, 3000);

                                        } catch (e) {
                                            voiceProcessing = false;
                                            console.error("JSON parsing error:", e, jsonData);
                                            tts.say("参数解析失败");
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle { Layout.fillWidth: true; height: 1; color: borderColor }

                        Button {
                            id: askAiButton
                            Layout.fillWidth: true
                            Layout.preferredHeight: 45

                            contentItem: Item {
                                anchors.fill: parent
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 10
                                    Text {
                                        text: "执行智能决策分析"
                                        color: askAiButton.down ? "#000" : accentColor
                                        font.bold: true
                                        font.pixelSize: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }

                            background: Rectangle {
                                color: parent.down ? accentColor : "transparent"
                                border.color: accentColor
                                border.width: 1
                                opacity: parent.enabled ? 1 : 0.3
                                Rectangle {
                                    anchors.fill: parent
                                    color: accentColor
                                    opacity: parent.hovered ? 0.1 : 0.0
                                }
                            }

                            onClicked: {
                                solveBalance();
                            }
                        }
                    }
                }
            }
        }
    }

    function solveBalance() {
        var passengers = [];
        var crewFields = [crew1, crew2, crew3, crew4, crew5, crew6, crew7, crew8, crew9, crew10, crew11, crew12, crew13, crew14, crew15, crew16, crew17, crew18];
        for (var i = 0; i < crewFields.length; i++) {
            var weight = parseFloat(crewFields[i].text) || 0;
            if (weight > 0) {
                passengers.push({
                    weight: weight,
                    seat: i + 1
                });
            }
        }

        var lead_config = {
            1: parseInt(l1.text) || 0,
            2: parseInt(l2.text) || 0,
            3: parseInt(l3.text) || 0
        };

        var tanks_state = {
            lifeboat: {
                1: (parseFloat(t1.text) || 0) + (parseFloat(t2.text) || 0),
                2: (parseFloat(t3.text) || 0) + (parseFloat(t4.text) || 0),
                3: (parseFloat(t5.text) || 0) + (parseFloat(t6.text) || 0),
                4: (parseFloat(t7.text) || 0) + (parseFloat(t8.text) || 0)
            },
            command: (parseFloat(tCmd1.text) || 0) + (parseFloat(tCmd2.text) || 0)
        };

        var pVal = (typeof sensorData !== "undefined") ? sensorData.pitch : 0.0;
        var rVal = (typeof sensorData !== "undefined") ? sensorData.roll : 0.0;
        var result = null;

        if (statusCombo.currentIndex === 0) {
            result = solve_departure(passengers, lead_config, tanks_state, pVal, rVal);
        } else {
            result = solve_rescue(passengers, lead_config, tanks_state, pVal, rVal);
        }

        var currentParams = {
            "status": statusCombo.currentIndex,
            "tank1": (parseFloat(t1.text) || 0) + (parseFloat(t2.text) || 0),
            "tank2": (parseFloat(t3.text) || 0) + (parseFloat(t4.text) || 0),
            "tank3": (parseFloat(t5.text) || 0) + (parseFloat(t6.text) || 0),
            "tank4": (parseFloat(t7.text) || 0) + (parseFloat(t8.text) || 0),
            "cmdTank": (parseFloat(tCmd1.text) || 0) + (parseFloat(tCmd2.text) || 0),
            "lead1": parseInt(l1.text) || 0,
            "lead2": parseInt(l2.text) || 0,
            "lead3": parseInt(l3.text) || 0,
            "passengers": passengers
        };

        var matchResult = queryExperience(currentParams);

        if (matchResult.found && matchResult.similarity > 0.98) {
            result.reasoning += "<br><br><font color='#00ff9d'><b>[经验库匹配]</b> 发现相似度 " + (matchResult.similarity * 100).toFixed(1) + "% 的历史人工干预记录。系统的原始建议：[" + result.final + "] 已降级为参考。</font>";
            result.final = matchResult.decision;
        }

        if (result && result.final) {
            if (tts.state === TextToSpeech.Speaking) {
                tts.stop()
            }
            tts.say(result.final)
        }

        var outputHtml = "<p style='color: #4cc9f0; font-weight: bold'>[计算完成]</p>" +
                         "<p style='color: #8f9bb3'>--------------------------------</p>" +
                         "<p style='color: #e1e6eb'><b>详细推理:</b><br>" + result.reasoning + "</p>" +
                         "<br>" +
                         "<p style='color: #4cc9f0'><b>最终指令:</b><br>" + result.final + "</p>";

        logArea.text = outputHtml;

        bar.currentIndex = 1;
    }

    function solve_departure(passengers, lead_config, tanks_state, pitch_val, roll_val) {
        const SEAT_LONG = window.seatLong;
        const SEAT_TRANS = window.seatTrans;
        const LIFEBOAT_TANK_CAPACITY = window.tankCapacity;
        const WATER_DENSITY = window.waterDensity;
        const LIFEBOAT_TANK_LONG = window.tankLong;
        const COMMAND_TANK_CAPACITY = window.commandTankCapacity;
        const COMMAND_TANK_LONG = window.commandTankLong;
        const LEAD_WEIGHT = window.leadWeight;
        const LEAD_POS = window.leadPos;
        const IRON_WEIGHT = window.ironWeight;

        let p_long_moment = passengers.reduce((sum, p) => sum + p.weight * SEAT_LONG[p.seat], 0);
        let w_long_moment_change = 0;
        let w_text_steps = [];

        for (let key in tanks_state.lifeboat) {
            let group_id = parseInt(key);
            let current_l = tanks_state.lifeboat[key];
            let missing = LIFEBOAT_TANK_CAPACITY - current_l;

            if (missing > 0.01) {
                let m_change = missing * WATER_DENSITY * LIFEBOAT_TANK_LONG[group_id];
                w_long_moment_change += m_change;
                w_text_steps.push(
                    `救生舱组${group_id}少了${missing.toFixed(1)}L，减少纵轴力矩${missing.toFixed(1)}L*${WATER_DENSITY}kg/L*${LIFEBOAT_TANK_LONG[group_id]}m=${m_change.toFixed(3)}kg*m`
                );
            }
        }

        let cmd_current = tanks_state.command;
        let cmd_missing = COMMAND_TANK_CAPACITY - cmd_current;
        if (cmd_missing > 0.01) {
            let m_change = cmd_missing * WATER_DENSITY * COMMAND_TANK_LONG;
            w_long_moment_change += m_change;
            w_text_steps.push(
                `指挥舱水舱少了${cmd_missing.toFixed(1)}L，减少纵轴力矩${cmd_missing.toFixed(1)}L*${WATER_DENSITY}kg/L*${COMMAND_TANK_LONG}m=${m_change.toFixed(3)}kg*m`
            );
        }

        let total_long_moment = p_long_moment - w_long_moment_change;
        let all_possible_moves = [{ 'src': 2, 'dst': 2, 'n': 0, 'res': total_long_moment }];
        const positions = [1, 2, 3];

        for (let src of positions) {
            for (let dst of positions) {
                if (src === dst) continue;
                let max_n = lead_config[src];
                for (let n = 1; n <= max_n; n++) {
                    let moment_delta = -n * LEAD_WEIGHT * LEAD_POS[src] + n * LEAD_WEIGHT * LEAD_POS[dst];
                    let new_moment = total_long_moment + moment_delta;
                    all_possible_moves.push({ 'src': src, 'dst': dst, 'n': n, 'res': new_moment });
                }
            }
        }

        let positives = all_possible_moves.filter(m => m.res >= 0);
        let negatives = all_possible_moves.filter(m => m.res < 0);

        let best = null;
        let is_success = false;

        if (positives.length > 0) {
            // 升序排，找最小正值
            positives.sort((a, b) => a.res - b.res);
            best = positives[0];
            is_success = true;
        } else if (negatives.length > 0) {
            // 降序排，找最大负值
            negatives.sort((a, b) => b.res - a.res);
            best = negatives[0];
            is_success = false;
        }

        let final_long_moment = best.res;
        let move_desc = "";
        let lead_calc = "";
        if (best.n > 0) {
            move_desc = `压载铅从位置${best.src}移动${best.n}块到位置${best.dst}`;
            let calc_val = -best.n * LEAD_WEIGHT * LEAD_POS[best.src] + best.n * LEAD_WEIGHT * LEAD_POS[best.dst];
            lead_calc = `压载铅从位置${best.src}移动${best.n}块到位置${best.dst}，造成的纵轴力矩变化是-${LEAD_WEIGHT}kg*${best.n}*${LEAD_POS[best.src]}m + ${LEAD_WEIGHT}kg*${best.n}*${LEAD_POS[best.dst]}m = ${calc_val.toFixed(3)}kg*m`;
        } else {
            move_desc = "压载铅无需调整";
            lead_calc = "压载铅无需调整";
        }

        let pitch_triggered = false;
        if (!is_success && best.n === 0) {
            if (pitch_val > 12.5) {
                move_desc = "当前船头翘起过大，将压载铅移至船后部，人员往船前中部移动";
                pitch_triggered = true;
            } else if (pitch_val < -12.5) {
                move_desc = "当前船头角度过低，将压载铅移至船前中部，人员往船后部移动";
                pitch_triggered = true;
            }
        }

        let p_trans_moment = passengers.reduce((sum, p) => sum + p.weight * SEAT_TRANS[p.seat], 0);
        let shift_m = -1 * p_trans_moment / IRON_WEIGHT;
        let shift_mm = shift_m * 1000;

        let calc_direction = 0; // 0=无需移动, 1=右移, -1=左移
        let shift_text_cot = "";
        let shift_text_ans = "";

        if (Math.abs(shift_mm) < 10.0) {
            shift_text_cot = `压载铁需要移动的距离：-1*(${p_trans_moment.toFixed(3)})kg*m / ${IRON_WEIGHT}kg = ${shift_m.toFixed(5)}m = ${shift_mm.toFixed(2)}mm。绝对值小于10mm，忽略不计。`;
            shift_text_ans = "无需移动压载铁";
            calc_direction = 0;
        } else {
            let shift_dir = shift_mm > 0 ? "右" : "左";
            let sign_text = shift_mm > 0 ? '正' : '负';
            let dir_explain = shift_mm > 0 ? '正为右边' : '负为左边';

            shift_text_cot = `压载铁需要移动的距离：-1*(${p_trans_moment.toFixed(3)})kg*m / ${IRON_WEIGHT}kg = ${shift_m.toFixed(5)}m = ${shift_mm.toFixed(2)}mm。计算结果为${sign_text}，${dir_explain}，那么压载铁需要${shift_dir}移${Math.abs(shift_mm).toFixed(2)}mm。`;

            shift_text_ans = `压载铁${shift_dir}移${Math.abs(shift_mm).toFixed(2)}mm`;
            calc_direction = shift_mm > 0 ? 1 : -1;
        }

        let roll_target = 0; // 0=不存在, 1=乘员右移, -1=乘员左移
        let roll_instruction = "";
        let roll_dir_text = "";

        if (roll_val > 2) {
            roll_target = -1;
            roll_instruction = "部分乘员往左移动";
            roll_dir_text = "左";
        } else if (roll_val < -2) {
            roll_target = 1;
            roll_instruction = "部分乘员往右移动";
            roll_dir_text = "右";
        }

        let override_roll = false;
        if (roll_target !== 0) {
            if (calc_direction !== 0 && calc_direction !== roll_target) {
                override_roll = true;
            } else if (calc_direction === 0) {
                override_roll = true;
            }
        }

        if (override_roll) {
            shift_text_ans = roll_instruction;
            shift_text_cot += `\n横轴力矩计算有误，直接根据倾角仪调整。当前船横倾角${roll_val}度，人员应该${roll_dir_text}移动。`;
        }

        let p_long_strs = passengers.map(p => `${p.weight}kg * ${SEAT_LONG[p.seat]}m = ${(p.weight * SEAT_LONG[p.seat]).toFixed(3)} kg*m`);
        let cot = `纵轴：乘员增加的纵轴力矩是${p_long_strs.join("，")}。 `;

        if (w_text_steps.length > 0) {
            cot += "均衡水舱因为" + w_text_steps.join("，") + "。 ";
        }
        cot += `那么纵轴总力矩是 ${total_long_moment.toFixed(3)}kg*m。`;

        if (total_long_moment < 0 && (best.n || 0) > 0) {
            cot += " 因为纵轴总力矩是负值，说明船尾轻，要船头翘起，就需要压载铅后移。";
        }

        if (is_success) {
            if (best.n > 0) {
                cot += ` ${lead_calc}。此时纵轴总力矩是${final_long_moment.toFixed(3)}kg*m，成功达到正值。结合当前状态，位置${best.src}有${lead_config[best.src]}块，足够移动。\n`;
            } else {
                cot += ` 当前纵轴力矩已满足要求，无需移动压载铅。\n`;
            }
        } else {
            if (best.n > 0) {
                cot += ` ${lead_calc}。注意：即便执行此最佳调整，纵轴总力矩为${final_long_moment.toFixed(3)}kg*m，仍无法达到完全平衡（大于0），但已调整至最优状态。\n`;
            } else {
                if (pitch_triggered) {
                    cot += ` 警告：即使调整压载铅也无法达到平衡，且当前状态已是力矩最大的状态（${final_long_moment.toFixed(3)}kg*m）。船纵倾角已达${pitch_val}度\n`;
                } else {
                    cot += ` 警告：即使调整压载铅也无法达到平衡，且当前状态已是力矩最大的状态（${final_long_moment.toFixed(3)}kg*m）。\n`;
                }
            }
        }

        let p_trans_strs = passengers.map(p => `${p.weight}kg*${SEAT_TRANS[p.seat]}m=${(p.weight * SEAT_TRANS[p.seat]).toFixed(3)}kg*m`);
        cot += `横轴：乘员横轴力矩是${p_trans_strs.join("，")}。`;
        cot += ` 横轴总力矩是 ${p_trans_moment.toFixed(3)}kg*m。${shift_text_cot}`;

        let ans = `${move_desc}，${shift_text_ans}`;

        return { "reasoning": cot.trim(), "final": ans.trim() };
    }

    function solve_rescue(passengers, lead_config, tanks_state, pitch_val, roll_val) {
        const SEAT_LONG = window.seatLong;
        const SEAT_TRANS = window.seatTrans;
        const WATER_DENSITY = window.waterDensity;
        const LIFEBOAT_TANK_LONG = window.tankLong;
        const COMMAND_TANK_LONG = window.commandTankLong;
        const AIR_TAIL_CAPACITY = window.airTailCapacity;
        const AIR_TAIL_LONG = window.airTailLong;
        const LEAD_WEIGHT = window.leadWeight;
        const LEAD_POS = window.leadPos;
        const IRON_WEIGHT = window.ironWeight;

        let total_passenger_weight = passengers.reduce((sum, p) => sum + p.weight, 0);
        let total_water_needed_kg = total_passenger_weight;
        let total_water_needed_L = total_water_needed_kg / WATER_DENSITY;

        let discharge_plan = [];
        let water_long_moment_loss = 0;
        let steps_log = [];
        let total_lifeboat_water = 0;
        for (let k = 1; k <= 4; k++) {
            if (tanks_state.lifeboat[k]) total_lifeboat_water += tanks_state.lifeboat[k];
        }

        let use_air_tail = false;
        let use_command = false;
        let remaining_needed_L = 0;

        if (total_lifeboat_water >= total_water_needed_L) {
            remaining_needed_L = total_water_needed_L;
        } else {
            use_air_tail = true;
            if ((total_lifeboat_water + 600.0) < total_water_needed_L) {
                use_command = true;
            }
            remaining_needed_L = total_water_needed_L;
        }

        if (use_air_tail) {
            discharge_plan.push("压载水舱尾组全排空");
            let loss_air = AIR_TAIL_CAPACITY * WATER_DENSITY * AIR_TAIL_LONG;
            water_long_moment_loss += loss_air;
            steps_log.push(`压载水舱尾组排空600L，减少纵轴力矩${loss_air.toFixed(3)}kg*m`);
            remaining_needed_L -= AIR_TAIL_CAPACITY;
        }

        for (let i = 1; i <= 4; i++) {
            if (remaining_needed_L <= 0.01) break;
            let available = tanks_state.lifeboat[i] || 0;
            if (available > 0) {
                let discharge = Math.min(available, remaining_needed_L);
                if (discharge > 0) {
                    discharge_plan.push(`救生舱组${i}排出${discharge.toFixed(2)}L`);
                    let loss = discharge * WATER_DENSITY * LIFEBOAT_TANK_LONG[i];
                    water_long_moment_loss += loss;
                    remaining_needed_L -= discharge;
                    steps_log.push(`救生舱组${i}排出${discharge.toFixed(2)}L，减少纵轴力矩(${discharge.toFixed(2)}L*1.02kg/L*${LIFEBOAT_TANK_LONG[i]}m)=${loss.toFixed(3)}kg*m`);
                }
            }
        }

        if (use_command && remaining_needed_L > 0.01) {
            let cmd_available = tanks_state.command;
            let discharge_cmd = Math.min(cmd_available, remaining_needed_L);
            if (discharge_cmd > 0) {
                discharge_plan.push(`指挥舱均衡水舱排出${discharge_cmd.toFixed(2)}L`);
                let loss_cmd = discharge_cmd * WATER_DENSITY * COMMAND_TANK_LONG;
                water_long_moment_loss += loss_cmd;
                steps_log.push(`指挥舱均衡水舱排出${discharge_cmd.toFixed(2)}L，减少纵轴力矩(${discharge_cmd.toFixed(2)}*${WATER_DENSITY}*${COMMAND_TANK_LONG})=${loss_cmd.toFixed(3)}kg*m`);
                remaining_needed_L -= discharge_cmd;
            }

            if (remaining_needed_L > 0.01) {
                discharge_plan.push("所有水舱已排空仍不足，需将压载铁和压载铅弃置于被困潜艇中");
                steps_log.push(`当前仍缺${remaining_needed_L.toFixed(2)}L排水量，建议弃置固体压载`);
            }
        }

        let p_long_moment = passengers.reduce((sum, p) => sum + (p.weight * SEAT_LONG[p.seat]), 0);
        let total_long_moment = p_long_moment - water_long_moment_loss;

        let all_possible_moves = [{ 'src': 2, 'dst': 2, 'n': 0, 'res': total_long_moment }];
        const positions = [1, 2, 3];

        for (let src of positions) {
            for (let dst of positions) {
                if (src === dst) continue;
                let max_n = lead_config[src];
                for (let n = 1; n <= max_n; n++) {
                    let moment_delta = -n * LEAD_WEIGHT * LEAD_POS[src] + n * LEAD_WEIGHT * LEAD_POS[dst];
                    let new_moment = total_long_moment + moment_delta;
                    all_possible_moves.push({ 'src': src, 'dst': dst, 'n': n, 'res': new_moment });
                }
            }
        }

        let positives = all_possible_moves.filter(m => m.res >= 0);
        let negatives = all_possible_moves.filter(m => m.res < 0);
        let best = null;
        let is_success = false;

        if (positives.length > 0) {
            // 升序排，找最小正值
            positives.sort((a, b) => a.res - b.res);
            best = positives[0];
            is_success = true;
        } else if (negatives.length > 0) {
            // 降序排，找最大负值
            negatives.sort((a, b) => b.res - a.res);
            best = negatives[0];
            is_success = false;
        }

        let final_long_moment = best.res;
        let lead_desc = "";
        let lead_calc = "";

        if (best.n > 0) {
            lead_desc = `压载铅从位置${best.src}移动${best.n}块到位置${best.dst}`;
            let delta = -best.n * LEAD_WEIGHT * LEAD_POS[best.src] + best.n * LEAD_WEIGHT * LEAD_POS[best.dst];
            lead_calc = `移动${best.n}块造成的纵轴力矩变化${delta.toFixed(3)}kg*m`;
        } else {
            lead_desc = "压载铅保持不变";
            lead_calc = "无需移动";
        }

        let pitch_triggered = false;
        if (!is_success && best.n === 0) {
            if (pitch_val > 12.5) {
                lead_desc = "当前船头翘起过大，将压载铅移至船后部，人员往船前中部移动";
                pitch_triggered = true;
            } else if (pitch_val < -12.5) {
                lead_desc = "当前船头角度过低，将压载铅移至船前中部，人员往船后部移动";
                pitch_triggered = true;
            }
        }

        let p_trans_moment = passengers.reduce((sum, p) => sum + (p.weight * SEAT_TRANS[p.seat]), 0);
        let shift_m = -1 * p_trans_moment / IRON_WEIGHT;
        let shift_mm = shift_m * 1000;

        let calc_direction = 0;
        let shift_text_cot = "";
        let shift_text_ans = "";

        if (Math.abs(shift_mm) < 10.0) {
            shift_text_cot = `压载铁需要移动的距离：-1*(${p_trans_moment.toFixed(3)})kg*m / ${IRON_WEIGHT}kg = ${shift_m.toFixed(5)}m = ${shift_mm.toFixed(2)}mm。绝对值小于10mm，忽略不计。`;
            shift_text_ans = "无需移动压载铁";
            calc_direction = 0;
        } else {
            let shift_dir = shift_mm > 0 ? "右" : "左";
            let sign_text = shift_mm > 0 ? '正' : '负';
            let dir_explain = shift_mm > 0 ? '正为右边' : '负为左边';

            shift_text_cot = `压载铁需要移动的距离：-1*(${p_trans_moment.toFixed(3)})kg*m / ${IRON_WEIGHT}kg = ${shift_m.toFixed(5)}m = ${shift_mm.toFixed(2)}mm。计算结果为${sign_text}，${dir_explain}，那么压载铁需要${shift_dir}移${Math.abs(shift_mm).toFixed(2)}mm。`;

            shift_text_ans = `压载铁${shift_dir}移${Math.abs(shift_mm).toFixed(2)}mm`;
            calc_direction = shift_mm > 0 ? 1 : -1;
        }


        let roll_target = 0;
        let roll_instruction = "";
        let roll_dir_text = "";

        if (roll_val > 2) {
            roll_target = -1;
            roll_instruction = "被救者往左移动";
            roll_dir_text = "左";
        } else if (roll_val < -2) {
            roll_target = 1;
            roll_instruction = "被救者往右移动";
            roll_dir_text = "右";
        }

        let override_roll = false;
        if (roll_target !== 0) {
            if (calc_direction !== 0 && calc_direction !== roll_target) {
                override_roll = true;
            } else if (calc_direction === 0) {
                override_roll = true;
            }
        }

        if (override_roll) {
            shift_text_ans = roll_instruction;
            shift_text_cot += `\n横轴力矩计算有误，直接根据倾角仪调整。当前船横倾角${roll_val}度，人员应该${roll_dir_text}移动。`;
        }

        let passenger_moment_strs = passengers.map(p =>
            `${p.weight}kg*${SEAT_LONG[p.seat]}m=${(p.weight * SEAT_LONG[p.seat]).toFixed(2)}kg*m`
        );
        let cot = `纵轴：被救者上船导致增加的纵轴力矩是${passenger_moment_strs.join(", ")}。 `;
        cot += `需要先排出和被救者总重相同的压载水${total_passenger_weight}kg / ${WATER_DENSITY}kg/L = ${total_water_needed_L.toFixed(3)}L。 `;

        if (use_air_tail) {
            cot += "因救生舱水不够，先排空压载水舱。 ";
        }

        cot += steps_log.join("。") + "。 ";
        cot += `排出水之后的纵轴总力矩是 ${total_long_moment.toFixed(3)}kg*m。`;

        if (is_success) {
            if (best.n > 0) {
                cot += ` ${lead_calc}。最后纵轴总力矩为${final_long_moment.toFixed(3)}kg*m，略大于0，满足平衡。`;
            } else {
                cot += ` 当前力矩已满足要求。最后纵轴总力矩为${final_long_moment.toFixed(3)}kg*m。`;
            }
        } else {
            if (best.n > 0) {
                cot += ` 警告：${lead_calc}。此为最佳调整方案，最后纵轴总力矩为${final_long_moment.toFixed(3)}kg*m，虽仍小于0，但已最接近平衡。`;
            } else {
                if (pitch_triggered) {
                    cot += ` 警告：即使调整压载铅也无法达到平衡，且当前状态已是力矩最大的状态（${final_long_moment.toFixed(3)}kg*m）。船纵倾角已达${pitch_val}度\n`;
                } else {
                    cot += ` 警告：无论如何调整压载铅，纵轴总力矩（当前${final_long_moment.toFixed(3)}kg*m）均无法大于0且无法优化。`;
                }
            }
        }

        let p_trans_moment_strs = passengers.map(p =>
            `${p.weight}kg*${SEAT_TRANS[p.seat]}m=${(p.weight * SEAT_TRANS[p.seat]).toFixed(2)}kg*m`
        );
        cot += `\n横轴：被救者导致的新增横轴力矩变化为${p_trans_moment_strs.join(", ")}。`;
        cot += ` 横轴总力矩为${p_trans_moment.toFixed(2)}kg*m。${shift_text_cot}`;

        let ans = `${discharge_plan.join("，")}，${lead_desc}，${shift_text_ans}`;

        return {
            "reasoning": cot.trim(),
            "final": ans.trim()
        };
    }


    function getDb() {
        return LocalStorage.openDatabaseSync("UserExperienceDB", "1.0", "User Decision Vector Database", 1000000);
    }

    function initExperienceDB() {
        var db = getDb();
        db.transaction(function(tx) {
            tx.executeSql('CREATE TABLE IF NOT EXISTS Experience (id INTEGER PRIMARY KEY AUTOINCREMENT, vector_json TEXT, decision TEXT)');
        });
    }

    function extractVector(params) {
        var vec = [
            (params.status || 0) * 2.0,
            (params.tank1 || 0) / 142.5,
            (params.tank2 || 0) / 142.5,
            (params.tank3 || 0) / 142.5,
            (params.tank4 || 0) / 142.5,
            (params.cmdTank || 0) / 430.0,
            (params.lead1 || 0) / 25.0,
            (params.lead2 || 0) / 25.0,
            (params.lead3 || 0) / 25.0
        ];

        var seatWeights = new Array(18).fill(0.0);
        if (params.passengers) {
            for (var i = 0; i < params.passengers.length; i++) {
                var p = params.passengers[i];
                var seatIndex = p.seat - 1;
                if (seatIndex >= 0 && seatIndex < 18) {
                    seatWeights[seatIndex] += (p.weight / 75.0);
                }
            }
        }
        return vec.concat(seatWeights);
    }

    function calculateVectorSimilarity(v1, v2) {
        if (!v1 || !v2 || v1.length !== v2.length) return 0.0;

        var sumSq = 0.0;
        for (var i = 0; i < v1.length; i++) {
            var diff = v1[i] - v2[i];
            sumSq += diff * diff;
        }

        var distance = Math.sqrt(sumSq);
        var similarity = 1.0 - distance;
        return similarity < 0 ? 0.0 : similarity;
    }

    function saveUserExperience(params, decision) {
        var vec = extractVector(params);
        var vecStr = JSON.stringify(vec);
        var db = getDb();

        db.transaction(function(tx) {
            var rs = tx.executeSql('SELECT id FROM Experience WHERE vector_json = ?', [vecStr]);
            if (rs.rows.length > 0) {
                var existingId = rs.rows.item(0).id;
                tx.executeSql('UPDATE Experience SET decision = ? WHERE id = ?', [decision, existingId]);
                console.log("【更新成功】检测到相同参数，已覆盖历史记录 (ID: " + existingId + ")");
                console.log(">>> 更新后的指令为: " + decision);
            } else {
                tx.executeSql('INSERT INTO Experience (vector_json, decision) VALUES (?, ?)', [vecStr, decision]);
                console.log("【写入成功】存入新的经验记录，向量为: " + vecStr);
            }
        });
    }

    function queryExperience(params) {
        var queryVec = extractVector(params);
        var maxSim = 0.0;
        var bestMatch = "";

        console.log("========== 开始检索经验库 ==========");
        console.log("当前输入生成的向量: " + JSON.stringify(queryVec));

        var db = getDb();
        db.transaction(function(tx) {
            var rs = tx.executeSql('SELECT * FROM Experience');
            console.log("本地数据库中共找到 " + rs.rows.length + " 条记录。");

            for (var i = 0; i < rs.rows.length; i++) {
                var dbVec = JSON.parse(rs.rows.item(i).vector_json);
                var sim = calculateVectorSimilarity(queryVec, dbVec);

                console.log("---");
                console.log("对比记录 ID: " + rs.rows.item(i).id);
                console.log("数据库中的向量: " + JSON.stringify(dbVec));
                console.log(">>> 算出的相似度: " + sim);

                if (sim > maxSim) {
                    maxSim = sim;
                    bestMatch = rs.rows.item(i).decision;
                }
            }
        });

        console.log("----------------------------------");
        console.log("最高相似度: " + maxSim);
        console.log("==================================\n");

        return {
            found: maxSim > 0.98,
            similarity: maxSim,
            decision: bestMatch
        };
    }


    function saveUserDecision() {
        var decisionText = userDecisionInput.text.trim();
        if (decisionText === "") return;

        var passengersArr = [];
        var crewFields = [crew1, crew2, crew3, crew4, crew5, crew6, crew7, crew8, crew9, crew10, crew11, crew12, crew13, crew14, crew15, crew16, crew17, crew18];
        for (var i = 0; i < crewFields.length; i++) {
            var weight = parseFloat(crewFields[i].text) || 0;
            if (weight > 0) {
                passengersArr.push({
                    "weight": weight,
                    "seat": i + 1
                });
            }
        }

        var currentParams = {
            "status": statusCombo.currentIndex,
            "tank1": (parseFloat(t1.text) || 0) + (parseFloat(t2.text) || 0),
            "tank2": (parseFloat(t3.text) || 0) + (parseFloat(t4.text) || 0),
            "tank3": (parseFloat(t5.text) || 0) + (parseFloat(t6.text) || 0),
            "tank4": (parseFloat(t7.text) || 0) + (parseFloat(t8.text) || 0),
            "cmdTank": (parseFloat(tCmd1.text) || 0) + (parseFloat(tCmd2.text) || 0),
            "lead1": parseInt(l1.text) || 0,
            "lead2": parseInt(l2.text) || 0,
            "lead3": parseInt(l3.text) || 0,
            "passengers": passengersArr
        };
        saveUserExperience(currentParams, decisionText);

        logArea.text += "<br><br><font color='#ff3d00'><b>[系统提示] 新的人工干预决策已向量化并写入本地 SQLite 数据库。系统将在下次遇到相似参数时优先采纳。</b></font>";
        userDecisionInput.text = "";

        logArea.cursorPosition = logArea.text.length;
    }

}
