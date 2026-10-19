# omarchy-activity-chip

A vertical-bar compaction of the [omarchy activity monitor](https://github.com/modib/omarchy-activity-monitor) plugin for Omarchy.

Where the original stacks several telemetry cells (GPU / CPU / RAM / temperature / fan) down the vertical bar, this variant renders **a single chip**: one glyph + one figure, color-coded by the plugin's own severity ramp (green → warm → urgent). The full telemetry popup — history graphs, Top CPU / Top Memory — is unchanged.

## Behavior

- `chipStat: auto` (default) promotes whichever enabled-and-readable metric sits highest on the severity ramp (critical beats warned beats calm), so heat outranks load. Ties prefer: `cpu-temp → cpu → ram → gpu-temp → gpu → fan`.
- Pin a specific stat with `chipStat: cpu | cpu-temp | ram | gpu | gpu-temp | fan` — hand-picked stats fall back to auto if that sensor is off or unreadable.
- Left-click (and right-click, in the vertical bar) opens the full system panel. All horizontal-bar render modes are untouched.

## Install

```bash
omarchy plugin add https://github.com/ansonboby/omarchy-activity-chip --enable --yes
```

Then swap the widget id in `~/.config/omarchy/shell.json`:

```json
{ "id": "anson.activity-monitor" }
```

(keep your existing per-widget settings — thresholds, `fanOverridePath`, everything — only the `id` changes)

## Fan override on HP 250 G9

If your firmware zeroes the WMI fan query like Anson's HP 250 G9, pair this with [hp-ec-fan-rpm](https://github.com/ansonboby/hp-ec-fan-rpm), which publishes the true tach reading from EC register 0x11 to `/run/hp-fan-rpm`, and set `fanOverridePath: "/run/hp-fan-rpm"`.

- Plugin id: `anson.activity-monitor` (vertical bar chip only — the base `modib.activity-monitor` plugin is untouched for horizontal bars)
- Upstream: [modib/omarchy-activity-monitor](https://github.com/modib/omarchy-activity-monitor)
