# Catalyst

A lightweight native macOS command launcher built with Swift and AppKit.

See [ARCHITECTURE.md](ARCHITECTURE.md) for module ownership, dependency direction,
testing seams, and the project's pragmatic DRY policy.

## MVP commands

- Search for and launch installed applications
- `Camera Preview`
- `Quit Focused App`
- `Quit All Apps`
- `define <word>`
- Natural-language arithmetic such as `20 percent of 85`

## Run

```sh
chmod +x scripts/build-app.sh
./scripts/build-app.sh
open .build/Catalyst.app
```

Press **Option–Space** to show or hide Catalyst. Use the arrow keys and Return to
run a result; Escape dismisses the panel. Calculation results are copied to the
clipboard.
