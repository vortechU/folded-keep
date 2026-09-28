# Rules for AI agents working on Folded Keep

1. **Read `DESIGN.md` first.** It's the source of truth for rules, architecture and ownership.
   Then read `TASKS.md` and take only a task assigned to you.
2. **One agent in the project at a time.** Don't start work while another agent's task is
   `IN PROGRESS` in TASKS.md, unless its files don't overlap with yours.
3. **Stay in your folders** (see the ownership table in DESIGN.md). Never edit `scripts/fold/` or
   `shaders/fold.gdshader`. If you need a change there, write it under "Requests" in TASKS.md.
4. **Web-safe only:** GL Compatibility renderer, no threads, no GDExtension-only features, no
   compute shaders. Don't change project display/render settings.
5. **Single pointer:** everything must work with one mouse button and one finger. Use mouse
   events (touch is emulated as mouse).
6. Typed GDScript, snake_case files, signals over direct node paths across systems. Use the
   `Events` and `Audio` autoloads described in DESIGN.md.
7. **Smoke-test before marking DONE.** Run this and fix any `SCRIPT ERROR` / `ERROR` lines it prints:
   `"C:/Apps/Godot_v4.7.2-stable_win64.exe/Godot.exe" --headless --path . --quit-after 300`
8. When you finish: mark the task `DONE` in TASKS.md with a one-line note on what changed and
   anything the next agent must know. Make sure the game still runs without errors.
