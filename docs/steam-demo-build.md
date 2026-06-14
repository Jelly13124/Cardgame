# Steam Demo — Build & Export

Scaffolding for shipping the Windows demo build. This is **export-preset +
placeholder only** — there is no Steamworks SDK integration yet (no App ID).
Audio and final art are out of scope for this pass.

## Files in this scaffold

| File | Purpose |
|---|---|
| `export_presets.cfg` | Windows Desktop (x86_64) export preset. Single-file exe (`embed_pck=true`). **Gitignored** by project convention (`.gitignore` line 8) — see the canonical content below to recreate it. |
| `steam_appid.txt` | Placeholder Steam App ID `480` (Steam's public test app). Replace with the real demo App ID once Steamworks assigns one. Tracked in git. |

> `export_presets.cfg` is **not read at runtime**, so it never affects the
> headless smoke gate. It is a hand-authored starting point — open the editor's
> export dialog once to let Godot fill in the full canonical option set for your
> installed template version (see step 2).
>
> Because `export_presets.cfg` is gitignored, the working copy lives on disk but
> is **not committed**. The canonical content is reproduced here so any clone can
> recreate it:

```ini
[preset.0]

name="Windows Desktop"
platform="Windows Desktop"
runnable=true
export_filter="all_resources"
exclude_filter="*.csv,*.md,docs/*,scripts/*,**/generated_sheet/*"
export_path="build/windows/WastelandSalvageDemo.exe"
script_export_mode=2

[preset.0.options]

debug/export_console_wrapper=0
binary_format/embed_pck=true
binary_format/architecture="x86_64"
application/modify_resources=true
application/file_version="0.1.0.0"
application/product_version="0.1.0.0"
application/company_name="Wasteland Salvage"
application/product_name="Wasteland Salvage Demo"
application/file_description="Wasteland Salvage — Steam Demo"
```

## One-time setup

1. **Install export templates** matching the engine (4.6):
   - Editor → `Editor` → `Manage Export Templates…` → Download and Install,
     **or** CLI: `Godot_v4.6-stable_win64.exe --headless --install-export-templates`.

2. **Verify the preset** in the editor:
   - `Project` → `Export…` → select **Windows Desktop**.
   - Confirm the export path, architecture (`x86_64`), and `Embed Pck`.
   - Hit `Export Project` once from here so Godot re-saves `export_presets.cfg`
     with the complete option list for your template version.

## Build the demo exe

CLI (headless), from the project root:

```bash
# Release build → build/windows/WastelandSalvageDemo.exe
"C:/Program Files/Godot/Godot.exe" --headless --export-release "Windows Desktop" build/windows/WastelandSalvageDemo.exe
```

Then copy `steam_appid.txt` **next to the exe** in `build/windows/` so the Steam
client can associate the running build with the App ID during local testing:

```
build/windows/
  WastelandSalvageDemo.exe
  steam_appid.txt
```

(`steam_appid.txt` is only needed for local/dev launches outside Steam. Once the
build is uploaded to a Steam depot and launched via Steam, the client supplies
the App ID and the file is ignored.)

## Demo scope reminder

The demo is gated by `RunManager.DEMO_BUILD` (`run_system/core/run_manager.gd`):
- `DEMO_MAX_ACTS = 1` — only Act 1; its boss wins the demo (no extract choice).
- `DEMO_ALLOWED_HEROES = ["cowboy_bill"]` — only Cowboy Bill in the Warehouse picker.

Flip `DEMO_BUILD = false` to build the full 3-act, all-heroes game from the same
codebase.

## Where Steamworks plugs in later (when an App ID exists)

When the demo gets a real Steam App ID and you want overlay / achievements /
cloud saves:

1. Add the **GodotSteam** GDExtension (`addons/godotsteam/`) — the prebuilt 4.6
   Windows binary, per its install guide. (Per ADR-0005 / project rules, vendored
   addons are not hand-edited.)
2. Replace `480` in `steam_appid.txt` with the real App ID.
3. Initialize Steam early (e.g. a `SteamInit` autoload) and guard every call
   behind an `OS.has_feature` / availability check so non-Steam (itch, dev) runs
   still work.
4. Map achievements to existing run-end events (`RunManager.run_ended`) and the
   demo-complete screen.

None of that is required to ship a functional demo build — the steps above
produce a runnable Windows exe today.
