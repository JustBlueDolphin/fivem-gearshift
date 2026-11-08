# Gearshift animation prototype

**Made with AI** — the custom gearshift animations and FiveM script were created with AI assistance.

Preview footage uses Rockstar Games' GTA V multiplayer ped and Sultan vehicle models as visual references. Those third-party game models are not included in this repository. Existing third-party references and credits below apply to their respective work.

[Watch all 22 animation previews](previews/full-set.mp4)

Version 0.4.3 plays all 22 clips at half their previous speed. Clip durations are doubled and script task durations match: H-pattern 1.60 seconds, sequential 0.92 seconds, paddle 0.44 seconds. This changes the clip rate, not the starting phase. The included preview videos were already rendered at half of the original speed and now match the new game timing.

Version 0.4.2 fixes the playback call's starting phase: use `0.0` to play from the beginning, rather than `1.0` (the end of a one-shot clip). It uses task control flag 2 to disable arm IK for this animation only when `Config.ReleaseArmIK` is true. It removes version 0.4.1's global ped arm-IK toggles and extra frame thread. The phase/control argument interpretation follows [ox_lib's native wrapper](https://github.com/overextended/ox_lib/blob/master/imports/playAnim/client.lua).

The dictionary/clip checks and `/gearshift diagnose` and `/shifttest` commands remain available. The correction is covered by mocked regression checks; actual FiveM playback still needs confirmation.

## Troubleshooting in game

Replace the existing resource folder with this build, then run `refresh` and `restart gearshift` in the server console (or `ensure gearshift` if stopped). Do not install duplicate copies under different folder names.

As the driver, run `/gearshift diagnose`, then `/shifttest up 2`. The test waits for dictionary loading and prints a playback result after 100 ms. Messages also appear in F8. Run `/gearshift diagnose` again after a few seconds if it initially says the dictionary is not loaded.

- No response to either command: confirm `ensure gearshift` and check F8/server console for startup errors.
- `exists=false` or loading timeout: verify `gearshift/stream/gearshift.ycd` is present and the new resource was restarted.
- `clip_not_found` or duration 0: the loaded dictionary does not expose the requested clip; report the exact clip name.
- `playing=false`: GTA did not keep the requested task active at the sample time; report this plus any F8 errors and other driving/animation resources in use.
- `playing=true` but no visible movement: task acceptance is not proof of visible motion; report ped model, vehicle and whether disabling `Config.ReleaseArmIK` changes the result.
- Manual playback works but automatic does not: check `mode=auto`, `/gearshift on`, and whether the reported gear actually changes while driving. Other gearbox resources may need the `PlayShift` export.

The Blender previews and mocked tests do not verify this engine behaviour; do not treat this build as a confirmed fix until the above outputs are checked in game.

Version 0.4.0 automatically triggers shifting animations for supported road vehicle classes, including add-on models. Install and drive; no list of vehicle spawn names is required. Cars, SUVs, vans, buses, trucks and open-wheel cars are enabled. Motorcycles, bicycles, boats, aircraft and trains use different poses and are excluded.

Defaults are H-pattern for general road classes, sequential for Sports, and paddles for Super/Open Wheel. These are configurable animation choices; GTA vehicle class does not reliably identify real transmission type. Automatic H-pattern profiles switch to sequential when the vehicle has more than six forward gears.

Use `/gearshift status` to see the current selection and `/gearshift on` or `/gearshift off` to toggle animations for your client. This toggle lasts for the session. The script runs locally for each driver and needs no ESX/QB/Qbox framework.

Standalone FiveM client resource with a custom `stream/gearshift.ycd` containing 22 clips:

- H-pattern: gears 1-6, reverse and neutral, with left/right shifter hands (16 clips).
- Sequential: pull to upshift, push to downshift, left/right hands (4 clips).
- Paddles: right-hand upshift and left-hand downshift (2 clips).

This is a first-pass animation set based on the GTA freemode male skeleton and a standard seated driving reference. Binary export/reload and offline Lua tests pass. The rig motion has been inspected, but FiveM playback, steering IK, multiplayer replication, female/custom peds and vehicle-specific alignment have **not** been verified. The interactive preview shows skeleton motion, not in-game footage.

Revision 3 places the H-pattern hand palm-down on top of a reference knob and holds the grip orientation through gate movement, for both hands. It retains the revision 2 elbow-plane fix. The cutaway preview uses the actual MP male ped and stripped Sultan interior with clay materials. The orange reference knob follows the authored gear movement in the preview only; the resource does not animate vehicle levers. This is not a verified fit to the Sultan's original gear lever. The head is rigidly attached for the preview, with no facial animation.

## Install

Copy the complete `gearshift` folder into your server resources, then add:

```cfg
ensure gearshift
```

No framework or server script is required. `stream/gearshift.ycd` streams automatically. Keep the resource folder named `gearshift` for the export examples below.

## Try it

Enter a car as the driver, allow the dictionary to load, then use:

```text
/shiftstyle hpattern right external
/shifttest up 1
/shifttest down 2
/shifttest down r
/shifttest down n
/shiftstyle hpattern left external
/shifttest up 3
/shiftstyle sequential right external
/shifttest up
/shifttest down
/shiftstyle paddle right external
/shifttest up
/shifttest down
/shiftstyle reset
```

Use `auto` instead of `external` to observe GTA gear changes. These commands only animate the character; they do not change gears or handling. Disable `Config.TestCommands` after testing. Per-session command overrides reset when changing vehicles.

## Vehicle settings

Edit `config.lua`. The default `hand = 'auto'` reads the driver-seat bone relative to the vehicle: a driver on the left shifts with the right hand, and a driver on the right shifts with the left. Missing or centrally placed seat bones use `Config.FallbackHand`. Custom vehicles with inaccurate seat metadata can override `hand` explicitly. Paddle direction is independent of this setting: right up, left down.

Profiles inherit `Config.Default`, then `Config.ClassProfiles[class]`, then `Config.Vehicles[modelHash]`. For example:

```lua
Config.Vehicles = {
    [joaat('my_rhd_car')] = { style = 'hpattern', hand = 'left' },
    [joaat('my_racecar')] = { style = 'paddle' },
    [joaat('my_automatic')] = false, -- Exclude this model
}
```

This supports vanilla and add-on vehicles without editing the script. Class selection and seat detection happen on driver entry; changing vehicle or player ped resets session profile overrides. Automatic selection does not fit the hand to every console: the fixed clips still need vehicle-specific alignment checks.

`auto` reacts after `GetVehicleCurrentGear` changes between forward gears. It intentionally ignores gear 0 because it cannot reliably represent manual neutral selection. Vehicles that do not report forward gear changes, such as many electric vehicles, produce no automatic shift gesture. An explicit H-pattern profile shifting above gear 6 uses `Config.ExtraGearStyle` (sequential by default), because no seventh/eighth H-pattern gate exists. Reverse/neutral and precise timing require an external gearbox integration.

## Existing manual gearbox integration

From your gearbox's client script, once the player becomes the driver:

```lua
exports['gearshift']:SetProfile('hpattern', 'left', 'external')
```

When that script accepts a shift, call:

```lua
local ok, reason = exports['gearshift']:PlayShift('up', 3)
-- direction: 'up' or 'down'; target gear: integer 1-6, 'r', or 'n'.
-- Sequential/paddle styles only use the direction.
```

Use `external` to avoid duplicate automatic triggers. Call after dictionary loading, normally after the driver-entry setup. The export returns `false, 'dictionary_not_loaded'` while loading; it does not queue stale shifts. Other rejection reasons include `not_driver`, `ped_busy`, `cooldown` and `invalid_shift_or_profile`. Rapid shifts within 120 ms are suppressed; later shifts interrupt the previous clip. The resource stops only its own clip on exit or shutdown.

Additional client exports: `GetProfile()` returns a copy of `{ style, hand, mode, enabled }` for the current supported vehicle (or nil); `SetEnabled(boolean)` toggles playback; `ResetProfile()` restores the automatic vehicle profile. A disabled client returns `false, 'disabled'` from `PlayShift`.

## Animation scope and tuning

H-pattern motion reaches a central gate, moves sideways to the selected lane, moves forward/back, and returns to the wheel. It is a destination-gear gesture, not a complete matrix of source-to-destination gearbox transitions. Reverse uses the outer rear gate. Clutch/pedal motion and animated vehicle levers/paddles are not included.

The animation only keys the selected arm, wrist and fingers. Upper-body secondary playback is intended to retain the driving task. Driving IK may need additional tuning after an in-game check. This set has fixed hand targets; console position, seat pose and wheel dimensions differ between vehicles. Per-car style selection does not automatically retarget the hand position.

H-pattern duration: 1600 ms. Sequential: 920 ms. Paddle: 440 ms. Test third/first person, steering, rapid shifts, drive-by interruption, getting out, and another player's view before deploying broadly.

The sibling `gearshift_work` folder contains `gearshift.blend`, the XML source, regeneration scripts, tests and the rig preview. Only this `gearshift` resource folder belongs on the server. The authoring scripts currently reference this machine's Blender, CodeWalker and GTA installation paths.

Reference APIs: [TaskPlayAnim flags](https://github.com/citizenfx/natives/blob/master/TASK/TaskPlayAnim.md), [FiveM resource manifests](https://docs.fivem.net/docs/scripting-reference/resource-manifest/).
