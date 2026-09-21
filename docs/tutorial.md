# Tutorial

World highlights pass ViewportPosition explicitly to the UI highlighter. It converts the camera's device-safe coordinates using GuiService:GetInsetArea(DeviceSafeInsets).Min minus the fullscreen overlay's AbsolutePosition each draw. This accounts for mobile notches and changing safe-area origins without a hard-coded topbar offset. Offscreen cutouts clamp their original edges independently. Button highlights retain their existing target-to-overlay conversion. Automated checks cover notch offsets, origin changes, and partial clipping; verify the treadmill sign in Studio's phone emulator and on-device.

Landing within PlatformDistance of PlatformLeft or PlatformRight advances immediately to Steal when grounded in Running (including idle) or Landed state. Players do not need to enter the guard Area. PlatformBiome (Forest by default) identifies the egg folder outside the Area bounds, and the platform approach remains valid while walking toward the eggs. The original Zone approach still displays platform guidance while climbing. Guard-stunned, knocked, airborne, or falling players cannot use the landing shortcut.

Tutorial analytics lives in `tutorialFunnelService`, with its own `config.luau` for enabling events, Studio debug output, funnel names, version, and ordered step names. `TutorialService` calls it at saved transitions; it exposes no client remotes. Progress flags live in `Tutorial.Funnels` and are saved with the existing DataService/ProfileStore data. No extra data store or client controller is needed.

In Creator Dashboard analytics, the `Tutorial` funnel shows entry into each stage through `Tutorial complete`. `TutorialSteps` shows Started → Completed; filter CustomField01 by the step name and CustomField02 by version. This uses two funnel names instead of exceeding Roblox's ten-funnel limit. Forward progression completes the previous visited stage; backtracking does not. Skipped stages are not emitted as individual step starts/completions. Roblox automatically treats skipped intermediate stages as passed on the overall funnel. Already-finished and migration-skipped players are excluded; profiles already midway when tracking is introduced enter at their current stage.

Events are best-effort: errors are caught and warned without blocking gameplay, and failed events are not retried. Saved flags prevent repeated calls on retries/rejoins. Studio never sends analytics; set DebugInStudio true to inspect events in Output. Test real delivery in a published game. Keep published step ordering/names stable. Run `lune run tests/tutorial-funnels.luau` for progression, deduplication, resume, migration, Studio, and failure-isolation checks.

Tune `GameConfiguration/Gameplay/tutorialConfig.luau`. The flow is Climb → Ascend → Platform → Steal → Return → Deposit → Hatch → Stamina → Treadmill → Train → Finish.

All text is in `Text`. `TextInterval` controls typewriting, `WriteSoundInterval` limits typing SFX, and `FinishSeconds` controls the completion message. The sound is cloned from SoundService.src.Sfx.Tutorial.Write.

The server saves the `Tutorial` profile table through DataService. It checks route proximity, actual egg carrying/ownership, successful placement/hatching, stamina/treadmill levels, and active treadmill training near the player's own treadmill. Gameplay milestones are server-verified. The client only acknowledges closing the stamina panel; the server accepts that acknowledgement at CloseStamina after validating the stamina level. Progress survives rejoining and rebirth. Losing a carried egg returns to climbing; a saved inventory egg resumes at deposit, and a placed egg resumes at hatch.

`SkipExistingPlayers = true` excludes returning profiles that never started this tutorial. Set it to false before initializing existing test profiles if you want them to receive it. For a Studio replay, reset that profile's Tutorial table to `{ Initialized = false, Step = "Climb", Completed = false, FreeStaminaUsed = false }` with SkipExistingPlayers false. Do not clear production completion/free-purchase flags merely to change tutorial wording.

`FreeFirstStaminaPurchase = true` makes the base-level stamina purchase free only at the Stamina step. The normal purchase button displays FREE and the server records FreeStaminaUsed alongside the purchase. Setting this flag false restores the normal price. Already-upgraded players advance at StaminaTargetLevel; they do not get another free upgrade. The treadmill uses its existing economy settings, where level 1 costs zero. If changing the tutorial's target levels or treadmill price, update the matching tutorial text too.

Required authored objects:

- Workspace.TutorialParts.Climb, Zone, PlatformLeft, PlatformRight (BaseParts).
- ReplicatedStorage.Assets.TutorialBeam.Beam (Beam).
- PlayerGui.Hud.Tutorial.Title and Text (TextLabels).
- Existing base Fences, StaminaShopCFrame, TMUpgradeSignCFrame, TreadmillCFrame, and PlacedEggs.

Beams use Attachment0 on the character and Attachment1 at each destination. Texture scrolling is configured separately in guidance. PlatformLeft and PlatformRight display together. ArrivalDistance measures distance outside a marker's bounds; ZoneDistance controls the transition to platform guidance. Deposit/return arrows use Fences:GetBoundingBox(). Eggs are selected from the current biome's SpawnedEggs folder by shortest configured hatch duration (including size), with distance as the tie-breaker. Disabled steal prompts are excluded. The tutorial never changes egg hatch times or takes another player's egg automatically.

Screen buttons use UIHighlighterController with the real GUI inset. The separate tutorialController/worldHighlighter module projects the treadmill sign bounds into a screen cutout that follows camera movement. The overlay sits above panels, so the stamina cutout highlights only PurchaseBtn. No tutorial purchase bypasses the ordinary services.

Run `lune run tests/tutorial.luau` for progression, resume, free-purchase validation and beam ownership checks. In Studio, test both platform routes, stealing/dropping an egg, dying/rejoining midway, hatching, FREE stamina, the treadmill sign, and riding the treadmill. Check mobile text wrapping and beam texture direction against the authored asset; automated tests cannot verify visual rendering.

Guard recovery: guidance pauses silently during GuardStunned/Knocked; normal jumps and falls preserve the current instruction. Platform arrival uses Structures.Islands.<biome>.Area through guardGeometry.Contains, plus a grounded confirmation window (PlatformConfirmSeconds). Falling past a biome at its height does not count as arriving. PlatformHeight, FallingSpeed and ClimbColumnRadius are configurable. HatchRewardSeconds defaults to 0 (no extra delay) and begins when the animal reveal completes; saved reward deadlines resume after rejoining. Screen-button highlights now use the target and overlay AbsolutePosition difference, refreshed every frame to follow panel/button animation.

After upgrading stamina, CloseStamina highlights the existing header close button. The tutorial waits until the panel is hidden before advancing to the treadmill. Closing by another UI action also counts; rejoining with the panel already closed acknowledges this step automatically.

Route stability: reaching Platform no longer regresses merely by leaving the Zone marker radius. Steal remembers the confirmed biome during brief edge crossings. RouteExitConfirmSeconds (1.5) confirms recovery. Once Platform is reached, small drops on the climb do not reverse it; resetting requires landing back near the climb-start height. Recovery messages are removed, and the selected egg stays locked until it becomes unavailable or the player leaves its biome. The client displays the server-selected route step without an independent climbing override.
