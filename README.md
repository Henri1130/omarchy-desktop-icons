# Desktop Icons

Windows-style files and shortcuts on the Omarchy wallpaper.

![Desktop icons on the wallpaper](preview.png)

> [!IMPORTANT]
> This plugin is for **Omarchy 4 (Quattro)**, where the desktop shell uses
> [Quickshell](https://quickshell.org/).

## What it does

- Shows `~/Desktop` as icons on every monitor, under windows and the bar
- Click an icon to open it; drag to move it (snaps to a grid)
- Right-click empty wallpaper: New Folder, New Shortcut, Pin application, Add files
- Right-click an icon: Open, Show in Files, Move to Trash
- Drag an icon onto Trash, or drop files from Files onto Trash, to delete them
- Drag files from Files onto the wallpaper to copy them there
- Click empty wallpaper five times to switch the background (`Super+Ctrl+Space` still works)

## Install

Point Omarchy at a real `~/Desktop` folder first, if you do not already have one:

```bash
mkdir -p ~/Desktop
```

In `~/.config/user-dirs.dirs` set:

```bash
XDG_DESKTOP_DIR="$HOME/Desktop"
```

Then:

```bash
xdg-user-dirs-update
```

Review the repository, then add the plugin:

```bash
omarchy plugin add https://github.com/Henri1130/omarchy-desktop-icons.git
```

Accept the prompt to enable the plugin during installation.

For an unattended install from a repository you already trust:

```bash
omarchy plugin add https://github.com/Henri1130/omarchy-desktop-icons.git --enable --yes
```

Restart the shell once after enabling, so the icon layer gets a full click mask:

```bash
omarchy restart shell
```

### Files context menu (optional)

To add **Send to Desktop (create shortcut)** and **Copy to Desktop** in Files:

```bash
mkdir -p ~/.local/share/nautilus-python/extensions
cp ~/.config/omarchy/plugins/henri.desktop-icons/nautilus/add_to_desktop.py \
  ~/.local/share/nautilus-python/extensions/
nautilus -q
```

Optional: float the pin/add dialogs in `~/.config/hypr/hyprland.lua`:

```lua
o.window("org.omarchy.add-to-desktop", { float = true, center = true })
```

## Use

| Action | How |
| --- | --- |
| Open | Click an icon |
| Move an icon | Drag it; it snaps to the grid |
| Put a file on the desktop | Drag it onto the wallpaper, or copy it into `~/Desktop` |
| Pin a shortcut | Right-click wallpaper → Pin application… / New Shortcut… |
| Trash | Right-click an icon → Move to Trash, press Delete, or drag onto Trash |
| Change wallpaper | Click empty wallpaper five times, or `Super+Ctrl+Space` |

## Update

```bash
omarchy plugin update henri.desktop-icons
```

## Disable

```bash
omarchy plugin disable henri.desktop-icons
```

## Uninstall

```bash
omarchy plugin remove henri.desktop-icons
```

## Validate from source

```bash
omarchy plugin validate .
```
