# Flutter AI Agent Rules

These rules come from the official Flutter agent-plugin rules repository
(https://github.com/flutter/agent-plugins/tree/main/rules).

## Proactive Flutter Hot Reload

Whenever you edit or modify any `.dart` file under `lib/` in this project:

1. **When to Skip**:
   - **Files Outside `lib/`**: Only trigger hot reload or hot restart for edits
     under `lib/`. Do not trigger when modifying files in other directories
     (e.g., `test/**`, `integration_test/**`, `benchmark/**`, `test_driver/**`
     or `example/**`).
   - **Comments & Documentation**: Do not trigger hot reload or hot restart when
     changes only affect comments, docstrings, or whitespace.

2. **Discover & Connect**:
   - Discover active running application instances using the `dtd` MCP Tool (or
     `list_running_apps` / `vm_service`) from the Dart MCP server.

3. **Trigger Hot Reload / Hot Restart**:
   - Execute the `hot_reload` MCP tool immediately after making changes to UI
     widgets (including `build` methods of stateful widgets) or simple methods.
   - Execute the `hot_restart` MCP tool if fundamental logic, state
     initialization (e.g., `initState`), global/static state, or `main()` was
     modified.

## Launching Dart and Flutter Applications

- Always pass the `--print-dtd` flag to `dart` or `flutter` when spawning an
  application so the agent can discover the running app.
- For pure `dart` applications, always pass the `--observe` flag so the app can
  be connected to.
- Both `--print-dtd` and `--observe` must come before the script name or path
  when spawning `dart` applications: `dart --observe --print-dtd bin/main.dart`.
