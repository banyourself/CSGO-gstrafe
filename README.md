# gstrafe (fork)

Ground-strafe movement: tapping duck at the right moment while airborne close to the ground
gives you a small speed boost, so you can chain ducks to build speed. This is my fork of the
**EFRAG GStrafe + SGS** plugin, which zwolof wrote based on an idea by diablix. zwolof got me
the original file.

Upstream is 215 lines, this is 294.

## Install

Drop the `addons` folder into your `csgo` folder:

```
addons/sourcemod/plugins/gstrafe.smx                            the compiled plugin
addons/sourcemod/scripting/gstrafe.sp                           source
addons/sourcemod/scripting/include/kevac_movement.inc           only needed to recompile
```

Convars land in `cfg/sourcemod/gstrafe.cfg` on first run.

## The speed cap, which is the main change

The original modifier was a two-state switch: under 400 speed a duck multiplied your velocity
by 1.0, over 400 it multiplied by 0.965. So below the threshold ducking did nothing at all,
and above it you got trimmed. Speed sawtoothed around 400 forever instead of settling there.

This version does the arithmetic the other way round. A duck multiplies by `gstrafe_gain`
(1.025 by default) and the result is clamped to `gstrafe_max_speed` (450), so a boost lands
exactly on the cap instead of overshooting and getting knocked back. Only genuinely over-cap
speeds get trimmed, and never harder than 0.965 per duck, so the trim stays gradual rather
than yanking you back.

Both numbers are convars now. The original had them baked in.

## Teammates do not block you, enemies do

The original trace filter ignored only yourself, so any player you were standing near killed
the boost, including your own team. Now the filter ignores teammates as well, and enemies
still block, so you cannot gstrafe through someone you are trying to get past.

The one exception is funjump. KevFJ turns off player collision entirely while it is running,
so the filter has to stop blocking on enemies for that window or boosts still die on contact.
That is behind an optional `kev_isFJActive` native, so gstrafe works fine without KevFJ.

## Anti-cheat integration

Boosting works by teleporting the player, and that looks exactly like the thing an anti-cheat
wants to flag. So when gstrafe changes a position or a velocity itself, it calls
`KevAC_IgnoreMovement` to mark that tick, and KevAC skips only its outcome-based movement
checks. Command cadence, angles and cvar checks stay live. Optional native, so this runs
standalone.

## The license check I took out

The original had a hostname check that called `SetFailState("PLUGIN THIEF!!!! Contact
zwolof#0001 to purchase")` unless your hostname contained "Aphelium". zwolof gave me the file
directly, so it is gone.

## Smaller fixes

**`getLastDuck` returned a float through an `int` native.** The original declared
`_GS_GetLastDuck` as `public int` and then returned `view_as<float>`, so callers reading it as
a float got garbage. It is `public any` with `view_as<any>` now.

**Dead players were running the whole movement path.** The original ran on
`IsPlayerAlive(client) || m_lifeState == 1`, which includes the dying state. Now it needs a
valid, alive, non-fake client.

**`sv_timebetweenducks` gets reapplied on `OnConfigsExecuted`,** not just `OnMapStart`. Server
configs execute after map start and were resetting it.

**`IsValidClient` used a chained comparison,** `(0 < client <= MaxClients)`, which SourcePawn
evaluates left to right into a bool and then compares that against MaxClients. Replaced with
a real range check.

**`OnPlayerRunCmd` returns `Plugin_Continue`.** The original was an `Action` function with no
return statement.

Also removed an unused `g_hResetDucks` handle array the original never touched.

## Convars

| Convar | Default | What |
|---|---|---|
| `gstrafe_max_speed` | 450.0 | Peak speed reachable by gstrafing. Above this, each duck trims speed down. Minimum 250. |
| `gstrafe_gain` | 1.025 | Multiplier applied per duck below the cap. Range 1.0 to 1.2. The original build used 1.025. |

## Natives

```sourcepawn
native int getDucks(int client);      // ducks in the current chain
native float getLastDuck(int client); // seconds since the last counted duck
```

## Credits

Original **EFRAG GStrafe + SGS** by **zwolof** ([github.com/zwolof](https://github.com/zwolof)),
based on an idea by **diablix**. zwolof provided the original file.

## License

GPL-3.0, see `LICENSE`.
