# Ougi Calendar

A minimal, transparent calendar widget for KDE Plasma 6, with simple per-day events.

- Transparent calendar that follows your theme colors
- Poppins font
- Simple events: click a date to add an event, hover a date to preview its events
- Optional week numbers (configurable)
- Minimal, dependency-free (uses the built-in Plasma calendar backend)

## Requirements

- KDE Plasma 6 (Qt 6)
- A recent `plasma-workspace` (the calendar backend `org.kde.plasma.workspace.calendar`)

## Install

### From source

```sh
# install locally for the current user
kpackagetool6 --type Plasma/Applet --install .   # or:
plasmapkg2 --install .                            # Plasma 5 only

# restart the shell
kquitapp6 plasmashell && kstart plasmashell
```

Or symlink the folder into your local widgets directory:

```sh
ln -s "$PWD" ~/.local/share/plasma/plasmoids/com.github.ghaisanghaisan.ougi-cal
kquitapp6 plasmashell && kstart plasmashell
```

Then add **Ougi Calendar** from the widget picker ("Add Widgets").

## Usage

- **Hover** a date with events to preview them.
- **Click** a date to select it and add an event (type + Enter).
- **Click** the selected date again (or press **Esc**) to deselect and close.
- **Hover** an event in the panel and click the trash icon to remove it.

## Configuration

Right-click the widget → *Configure*:
- Show week numbers
- Compact display (day of month or week number)

## License

[GPL-2.0-or-later](LICENSE)
