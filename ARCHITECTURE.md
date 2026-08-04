# Catalyst Architecture

Catalyst is organized by feature ownership. The folders are navigational aids; the important architecture lives at the module interfaces described below.

## Modules

- `App`: application lifecycle and status-menu composition.
- `Launcher`: search, ranking, usage history, and explicit launcher navigation state.
- `Commands`: command metadata and execution. `CommandRegistry` is the authoritative source for built-in command presentation; `CommandExecutor` owns their effects and returns UI outcomes.
- `Applications`: installed-application discovery, aliases, running state inputs, and uninstall behavior.
- `Settings`: Catalyst preferences, the settings view, and System Settings discovery.
- `System`: macOS integrations such as the global hotkey, camera, keyboard lock, and system actions.
- `UI`: AppKit window composition, reusable launcher controls, results rendering, and action presentation.
- `Utilities`: cohesive pure or framework-backed utilities that do not own launcher flow.

## Primary interfaces

### `LauncherSearch`

The UI calls `results(for:)`. Search hides application discovery, aliases, calculations, System Settings panes, running state, ranking, grouping, and result limits. Running application state is refreshed only in response to workspace lifecycle notifications.

### `CommandExecutor`

The UI supplies a `CommandKind` and receives a `CommandOutcome`. Platform side effects stay behind the executor; the panel handles only outcomes that require navigation.

### `LauncherResultsView`

The window supplies result items and receives selection or activation callbacks. Table data-source behavior, reusable cells, selection, and scrolling remain local to the view.

### `CatalystSettingsView`

The settings view owns its controls and preference mutations. The command panel controls only whether Settings is visible.

## Dependency direction

```text
App → UI → Launcher → Applications
       ↓       ↓
    Settings Commands → System
       ↓
    Utilities
```

UI may depend on feature models. Search and ranking must not depend on the command-panel controller. Platform modules must not manipulate launcher views.

## DRY policy

- Keep domain knowledge authoritative: command metadata, usage identifiers, preference keys, and platform operations each have one owner.
- Reuse visual code when it represents a recurring Catalyst control or design token.
- Prefer duplication over a shallow wrapper when only two small call sites happen to look alike.
- Use the rule of three for incidental implementation details.
- Introduce a protocol only when there are real production and test adapters or genuinely varying implementations.
- Do not add general-purpose `Utils`, `Manager`, or `Service` buckets.

## Testing

Tests follow the same feature folders as production code. Module behavior is tested through its interface; AppKit interaction tests cover window wiring and visual invariants. Performance tests protect the show and query-update paths.
