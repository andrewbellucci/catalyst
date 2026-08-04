# Catalyst

Catalyst is a fast, native command launcher for macOS. It is built with Swift
and AppKit, stays out of the Dock, and opens from anywhere with a configurable
global keyboard shortcut.

> Catalyst is currently an early-stage project. Interfaces and behavior may
> change as the app develops.

## Features

### Find and manage applications

- Search installed applications with usage-aware ranking and recent suggestions
- See which applications are currently running
- Launch, reveal, restart, quit, or force-quit an application
- Add custom search aliases to applications
- Uninstall an application and select associated files to move to the Trash
- Copy an application's path

Open the action palette for a selected result with **Command-K**.

### Commands and utilities

- Open a live camera preview
- Look up a word with `define <word>`
- Calculate expressions such as `12 * (8 + 2)`, `20 percent of 85`,
  `square root of 144`, or `2 to the power of 8`
- Search for and open individual macOS System Settings panes
- Toggle light and dark system appearance
- Lock the Mac
- Lock keyboard input for 30 seconds, 1 minute, 2 minutes, or 5 minutes while
  cleaning it
- Quit the focused application or all regular applications
- Restart or shut down the Mac after confirmation
- Restart or quit Catalyst

Calculation results are copied to the clipboard when selected.

### Personalization

- Choose from four global shortcuts
- Choose a result highlight color
- Adjust the launcher background transparency
- Show or hide the menu bar icon
- Start Catalyst automatically at login

## Requirements

- macOS 14 Sonoma or later
- Swift 6 toolchain to build from source

Some features ask for macOS permissions only when needed:

- **Camera** for Camera Preview
- **Accessibility** for temporarily suppressing keyboard input
- **Automation** for commands that control System Events, including appearance
  and power actions

Permissions can be reviewed in **System Settings → Privacy & Security**.

## Build and run

Clone the repository, then run:

```sh
chmod +x scripts/build-app.sh
./scripts/build-app.sh
open .build/Catalyst.app
```

The build script creates a release build, assembles `.build/Catalyst.app`, and
applies an ad-hoc code signature for local use.

## Using Catalyst

Press **Option-Space** to open or hide Catalyst. This default shortcut can be
changed in Settings.

| Key | Action |
| --- | --- |
| Up / Down | Move through results or actions |
| Return | Run the selected result or action |
| Command-K | Open or close the selected result's action palette |
| Escape | Go back, close the action palette, or dismiss Catalyst |

Start typing to search applications, commands, and System Settings. Catalyst
learns from the items you use and promotes relevant results over time.

## Development

Run the test suite with:

```sh
swift test
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for module ownership, dependency
direction, testing seams, and the project's pragmatic DRY policy.

## License

Catalyst is available under the [MIT License](LICENSE).
