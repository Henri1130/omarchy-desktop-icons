import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons

Item {
  id: root

  property var shell: null
  property var manifest: null
  property var items: []
  property string itemsJson: ""
  property var positions: ({})
  property string desktopPath: Quickshell.env("HOME") + "/Desktop"
  property string selectedId: ""
  property int iconSize: 72
  property int cellW: 144
  property int cellH: 162
  property int padLeft: 24
  property int padRight: 24
  property int padBottom: 24

  readonly property string home: Quickshell.env("HOME")
  readonly property string pluginDir: (manifest && manifest.__sourceDir)
    ? String(manifest.__sourceDir)
    : (home + "/.config/omarchy/plugins/henri.desktop-icons")
  readonly property string indexScript: pluginDir + "/bin/desktop-index"
  readonly property string addScript: pluginDir + "/bin/add-to-desktop"
  readonly property string hyperlinkScript: home + "/.local/bin/create-hyperlink"
  readonly property string positionsPath: home + "/.config/omarchy/desktop-icon-positions.json"

  function padTopFor(screen) {
    var bar = shell && shell.bar ? shell.bar : null
    var barSize = bar && bar.barSize ? bar.barSize : 26
    var extra = 24
    if (bar && bar.position === "top" && !bar.barHidden)
      return barSize + extra
    return extra
  }

  function padLeftFor(screen) {
    var bar = shell && shell.bar ? shell.bar : null
    var barSize = bar && bar.barSize ? bar.barSize : 26
    if (bar && bar.position === "left" && !bar.barHidden)
      return barSize + 24
    return root.padLeft
  }

  function isTrash(item) {
    return !!(item && item.kind === "trash")
  }

  function iconSource(item) {
    if (!item) return ""
    if (item.preview)
      return Util.fileUrl(item.preview)
    var icon = String(item.icon || "")
    if (icon.indexOf("file://") === 0 || icon.indexOf("image://") === 0)
      return icon
    if (icon.charAt(0) === "/")
      return Util.fileUrl(icon)
    var themed = Quickshell.iconPath(icon, true)
    if (themed && themed.length > 0)
      return themed
    return Quickshell.iconPath(item.isDir ? "folder" : "text-x-generic", true)
  }

  function refresh() {
    if (!listProc.running)
      listProc.running = true
  }

  function openItem(item) {
    if (!item || !item.path) return
    Quickshell.execDetached(["/usr/bin/python3", root.indexScript, "--open", item.path])
  }

  function trashUrls(urls) {
    if (!urls || urls.length === 0) return
    var cmd = ["/usr/bin/python3", root.indexScript, "--trash"]
    for (var i = 0; i < urls.length; i++)
      cmd.push(String(urls[i]))
    Quickshell.execDetached(cmd)
    Qt.callLater(root.refresh)
  }

  function trashItem(item) {
    if (!item || !item.path || root.isTrash(item)) return
    root.trashUrls([item.path])
  }

  function revealItem(item) {
    if (item && item.path)
      Quickshell.execDetached(["nautilus", "--select", item.path])
    else
      root.openDesktopFolder()
  }

  function newFolder() {
    Quickshell.execDetached([
      "bash", "-lc",
      "d=" + Util.shellQuote(root.desktopPath) + "; " +
      "n='New Folder'; p=\"$d/$n\"; i=2; " +
      "while [ -e \"$p\" ]; do p=\"$d/$n $i\"; i=$((i+1)); done; " +
      "mkdir -p \"$p\""
    ])
    Qt.callLater(root.refresh)
  }

  function newShortcut() {
    Quickshell.execDetached([root.hyperlinkScript, "--directory", root.desktopPath])
  }

  function pinApp() {
    Quickshell.execDetached([root.addScript, "--pick-app"])
  }

  function addFiles() {
    Quickshell.execDetached([root.addScript, "--pick-files"])
  }

  function openDesktopFolder() {
    Quickshell.execDetached(["xdg-open", root.desktopPath])
  }

  function switchWallpaper() {
    Quickshell.execDetached([
      "bash", "-lc",
      "background=$(omarchy-theme-bg-switcher); [[ -n $background ]] && omarchy-theme-bg-set \"$background\""
    ])
  }

  function placeUrls(urls, mode) {
    if (!urls || urls.length === 0) return
    var cmd = ["/usr/bin/python3", root.indexScript, "--mode", mode || "copy", "--place"]
    for (var i = 0; i < urls.length; i++)
      cmd.push(String(urls[i]))
    Quickshell.execDetached(cmd)
    Qt.callLater(root.refresh)
  }

  function dropMode(drop) {
    if (!drop) return "copy"
    if (drop.proposedAction === Qt.LinkAction) return "link"
    if (drop.proposedAction === Qt.MoveAction) return "move"
    return "copy"
  }

  function applyList(raw) {
    var text = String(raw || "").trim()
    if (!text || text === root.itemsJson) return
    try {
      var data = JSON.parse(text)
      if (data.desktop)
        root.desktopPath = data.desktop
      root.itemsJson = text
      root.items = Array.isArray(data.items) ? data.items : []
    } catch (e) {
      console.warn("desktop-icons: failed to parse index:", e)
    }
  }

  function applyPositions(raw) {
    try {
      var data = JSON.parse(String(raw || "{}"))
      root.positions = Util.isPlainObject(data) ? data : ({})
    } catch (e) {
      root.positions = ({})
    }
  }

  function savePositions() {
    posFile.setText(JSON.stringify(root.positions || {}, null, 2) + "\n")
  }

  function setItemPos(screenName, itemId, x, y) {
    var next = JSON.parse(JSON.stringify(root.positions || {}))
    if (!next[screenName])
      next[screenName] = ({})
    next[screenName][itemId] = { x: Math.round(x), y: Math.round(y) }
    root.positions = next
    root.savePositions()
  }

  Process {
    id: listProc
    command: ["/usr/bin/python3", root.indexScript]
    stdout: StdioCollector {
      onStreamFinished: root.applyList(text)
    }
  }

  FileView {
    id: posFile
    path: root.positionsPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.applyPositions(text())
    onLoadFailed: root.positions = ({})
    onFileChanged: reload()
  }

  Timer {
    interval: 1200
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: root.refresh()

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData

      // Repeater delegates with required properties cannot see outer ids.
      property var host: root

      screen: modelData
      visible: true
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "desktop-icons"
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
      anchors { top: true; bottom: true; left: true; right: true }
      // Default mask is the opaque pixels only, so a transparent desktop
      // lets clicks fall through to omarchy-background (double-click
      // wallpaper). Cover the whole surface so icon clicks land here.
      mask: Region {
        width: panel.width
        height: panel.height
      }

      readonly property string screenName: modelData.name || "default"
      property int padTop: host.padTopFor(modelData)
      property int padLeft: host.padLeftFor(modelData)
      property string menuKind: ""
      property var menuItem: null
      property real menuX: 0
      property real menuY: 0
      property bool dropping: false
      property int emptyClicks: 0

      function layoutPos(index) {
        var availH = Math.max(host.cellH, panel.height - panel.padTop - host.padBottom)
        var rows = Math.max(1, Math.floor(availH / host.cellH))
        var col = Math.floor(index / rows)
        var row = index % rows
        return {
          x: panel.padLeft + col * host.cellW,
          y: panel.padTop + row * host.cellH
        }
      }

      function posFor(item, index) {
        var byScreen = host.positions[panel.screenName]
        if (item && byScreen && byScreen[item.id] && byScreen[item.id].x !== undefined)
          return byScreen[item.id]
        return layoutPos(index)
      }

      function snap(x, y) {
        var col = Math.round((x - panel.padLeft) / host.cellW)
        var row = Math.round((y - panel.padTop) / host.cellH)
        if (col < 0) col = 0
        if (row < 0) row = 0
        return {
          x: panel.padLeft + col * host.cellW,
          y: panel.padTop + row * host.cellH
        }
      }

      function itemAt(x, y, exceptId) {
        for (var i = 0; i < host.items.length; i++) {
          var item = host.items[i]
          if (exceptId && item.id === exceptId)
            continue
          var pos = panel.posFor(item, i)
          if (x >= pos.x && x < pos.x + host.cellW && y >= pos.y && y < pos.y + host.cellH)
            return item
        }
        return null
      }

      function closeMenu() {
        menuKind = ""
        menuItem = null
      }

      function openEmptyMenu(mouse) {
        menuKind = "empty"
        menuItem = null
        menuX = mouse.x
        menuY = mouse.y
      }

      function openItemMenu(item, iconItem, mouse) {
        menuKind = "item"
        menuItem = item
        var p = contentItem.mapFromItem(iconItem, mouse.x, mouse.y)
        menuX = p.x
        menuY = p.y
      }

      readonly property var menuEntries: {
        if (menuKind === "item") {
          if (host.isTrash(menuItem))
            return [
              { action: "open", label: "Open Trash" },
              { action: "files", label: "Show in Files" }
            ]
          return [
            { action: "open", label: "Open" },
            { action: "files", label: "Show in Files" },
            { action: "trash", label: "Move to Trash" }
          ]
        }
        if (menuKind === "empty")
          return [
            { action: "folder", label: "New Folder" },
            { action: "shortcut", label: "New Shortcut…" },
            { action: "pin", label: "Pin application…" },
            { action: "addfiles", label: "Add files…" },
            { action: "files", label: "Open Desktop Folder" },
            { action: "refresh", label: "Refresh" }
          ]
        return []
      }

      Timer {
        id: emptyClickTimer
        interval: 2500
        repeat: false
        onTriggered: panel.emptyClicks = 0
      }

      MouseArea {
        id: emptyMouse
        z: 0
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        focus: true
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            panel.closeMenu()
            event.accepted = true
          } else if (event.key === Qt.Key_Delete && host.selectedId) {
            for (var i = 0; i < host.items.length; i++) {
              if (host.items[i].id === host.selectedId) {
                host.trashItem(host.items[i])
                host.selectedId = ""
                break
              }
            }
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            for (var j = 0; j < host.items.length; j++) {
              if (host.items[j].id === host.selectedId) {
                host.openItem(host.items[j])
                break
              }
            }
            event.accepted = true
          }
        }
        onClicked: function(mouse) {
          host.selectedId = ""
          emptyMouse.forceActiveFocus()
          if (mouse.button === Qt.RightButton) {
            panel.emptyClicks = 0
            panel.openEmptyMenu(mouse)
            return
          }
          panel.closeMenu()
          panel.emptyClicks += 1
          emptyClickTimer.restart()
          if (panel.emptyClicks >= 5) {
            panel.emptyClicks = 0
            host.switchWallpaper()
          }
        }
      }

      DropArea {
        z: 0
        anchors.fill: parent
        keys: ["text/uri-list"]
        onEntered: panel.dropping = true
        onExited: panel.dropping = false
        onDropped: function(drop) {
          panel.dropping = false
          var urls = []
          if (drop.urls) {
            for (var i = 0; i < drop.urls.length; i++)
              urls.push(String(drop.urls[i]))
          }
          if (urls.length > 0) {
            drop.acceptProposedAction()
            var target = panel.itemAt(drop.x, drop.y, "")
            if (target && host.isTrash(target))
              host.trashUrls(urls)
            else
              host.placeUrls(urls, host.dropMode(drop))
          }
        }
      }

      Rectangle {
        anchors.fill: parent
        visible: panel.dropping
        color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 2
        border.color: Qt.rgba(1, 1, 1, 0.35)
        z: 5
      }

      Repeater {
        model: panel.host.items

        Item {
          id: iconRoot
          required property var modelData
          required property int index

          width: panel.host.cellW
          height: panel.host.cellH
          z: iconMouse.drag.active ? 6 : 2
          property real pressX: 0
          property real pressY: 0

          Binding on x {
            value: panel.posFor(iconRoot.modelData, iconRoot.index).x
            when: !iconMouse.drag.active
            restoreMode: Binding.RestoreNone
          }
          Binding on y {
            value: panel.posFor(iconRoot.modelData, iconRoot.index).y
            when: !iconMouse.drag.active
            restoreMode: Binding.RestoreNone
          }

          Rectangle {
            anchors.fill: parent
            anchors.margins: 4
            radius: 8
            color: panel.host.selectedId === iconRoot.modelData.id ? Qt.rgba(1, 1, 1, 0.18) : (iconHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
            border.width: panel.host.selectedId === iconRoot.modelData.id ? 1 : 0
            border.color: Qt.rgba(1, 1, 1, 0.35)
          }

          HoverHandler { id: iconHover }

          Column {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 4

            Image {
              width: panel.host.iconSize
              height: panel.host.iconSize
              anchors.horizontalCenter: parent.horizontalCenter
              source: panel.host.iconSource(iconRoot.modelData)
              fillMode: Image.PreserveAspectFit
              asynchronous: true
              sourceSize.width: panel.host.iconSize * Screen.devicePixelRatio
              sourceSize.height: panel.host.iconSize * Screen.devicePixelRatio
            }

            Text {
              width: parent.width
              text: iconRoot.modelData.name
              color: "white"
              style: Text.Outline
              styleColor: "#cc000000"
              font.pixelSize: 18
              font.family: Style.fontFamily
              wrapMode: Text.Wrap
              elide: Text.ElideRight
              maximumLineCount: 2
              horizontalAlignment: Text.AlignHCenter
            }
          }

          MouseArea {
            id: iconMouse
            anchors.fill: parent
            z: 2
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            drag.target: iconRoot
            drag.axis: Drag.XAndYAxis
            drag.threshold: 36
            drag.minimumX: 0
            drag.minimumY: 0
            drag.maximumX: Math.max(0, panel.width - iconRoot.width)
            drag.maximumY: Math.max(0, panel.height - iconRoot.height)
            onPressed: function(mouse) {
              iconRoot.pressX = iconRoot.x
              iconRoot.pressY = iconRoot.y
              panel.host.selectedId = iconRoot.modelData.id
              emptyMouse.forceActiveFocus()
            }
            onReleased: function(mouse) {
              if (!iconMouse.drag.active) return
              var target = panel.itemAt(
                iconRoot.x + iconRoot.width / 2,
                iconRoot.y + iconRoot.height / 2,
                iconRoot.modelData.id
              )
              if (target && panel.host.isTrash(target) && !panel.host.isTrash(iconRoot.modelData)) {
                panel.host.trashItem(iconRoot.modelData)
                return
              }
              var snapped = panel.snap(iconRoot.x, iconRoot.y)
              iconRoot.x = snapped.x
              iconRoot.y = snapped.y
              panel.host.setItemPos(panel.screenName, iconRoot.modelData.id, snapped.x, snapped.y)
            }
            onClicked: function(mouse) {
              if (mouse.button === Qt.RightButton) {
                panel.host.selectedId = iconRoot.modelData.id
                panel.openItemMenu(iconRoot.modelData, iconRoot, mouse)
                return
              }
              if (iconMouse.drag.active) return
              if (Math.abs(iconRoot.x - iconRoot.pressX) > 8 || Math.abs(iconRoot.y - iconRoot.pressY) > 8)
                return
              panel.closeMenu()
              panel.host.openItem(iconRoot.modelData)
            }
          }

          DropArea {
            anchors.fill: parent
            z: 3
            enabled: panel.host.isTrash(iconRoot.modelData)
            keys: ["text/uri-list"]
            onEntered: panel.dropping = true
            onExited: panel.dropping = false
            onDropped: function(drop) {
              panel.dropping = false
              if (!panel.host.isTrash(iconRoot.modelData))
                return
              var urls = []
              if (drop.urls) {
                for (var i = 0; i < drop.urls.length; i++)
                  urls.push(String(drop.urls[i]))
              }
              if (urls.length > 0) {
                drop.acceptProposedAction()
                panel.host.trashUrls(urls)
              }
            }
          }
        }
      }

      Rectangle {
        id: menuBox
        visible: menuKind !== ""
        z: 20
        width: menuCol.implicitWidth + 16
        height: menuCol.implicitHeight + 12
        radius: 8
        color: Color.popups.background
        border.width: 1
        border.color: Color.popups.border
        x: Math.min(Math.max(8, menuX), Math.max(8, panel.width - width - 8))
        y: Math.min(Math.max(8, menuY), Math.max(8, panel.height - height - 8))

        // Bind plugin state onto this item so menu JS never needs the `panel` id.
        property var pluginHost: host
        property var currentItem: menuItem
        property int closeTick: 0

        function activateMenu(action) {
          var item = currentItem
          var plugin = pluginHost
          closeTick += 1
          if (!plugin)
            return
          if (action === "open")
            plugin.openItem(item)
          else if (action === "trash")
            plugin.trashItem(item)
          else if (action === "folder")
            plugin.newFolder()
          else if (action === "shortcut")
            plugin.newShortcut()
          else if (action === "pin")
            plugin.pinApp()
          else if (action === "addfiles")
            plugin.addFiles()
          else if (action === "refresh")
            plugin.refresh()
          else if (action === "files") {
            if (item && item.path)
              plugin.revealItem(item)
            else
              plugin.openDesktopFolder()
          }
        }

        Column {
          id: menuCol
          anchors.centerIn: parent
          width: Math.max(188, implicitWidth)
          spacing: 2

          Repeater {
            model: menuEntries

            Rectangle {
              width: menuCol.width
              height: 28
              radius: 4
              color: rowMouse.containsMouse ? Util.alpha(Color.popups.text, 0.12) : "transparent"

              Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 10
                text: modelData.label
                color: Color.popups.text
                font.pixelSize: 13
                font.family: Style.fontFamily
              }

              MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: function(mouse) {
                  var action = String(modelData.action || "")
                  var node = rowMouse
                  while (node) {
                    if (typeof node.activateMenu === "function") {
                      node.activateMenu(action)
                      return
                    }
                    node = node.parent
                  }
                }
              }
            }
          }
        }
      }

      Connections {
        target: menuBox
        function onCloseTickChanged() {
          menuKind = ""
          menuItem = null
        }
      }
    }
  }
}
