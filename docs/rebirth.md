# Rebirth system

Edit `src/shared/replicatedStorage/GameConfiguration/Economy/rebirthConfig.luau` for game rules.
These defaults come from the supplied UI and our own placeholder scaling; they are not verified
Steal an Egg formulas. The official game listing does not publish its rebirth rules.

## Defaults and knobs

- First rebirth: 10,000 Speed; each following requirement doubles (10k, 20k, 40k...).
- Requirement formula: `Base * Growth ^ completedRebirths + Add * completedRebirths`, rounded up.
  Add another numeric profile stat (e.g. Cash) to `Requirements` to require both.
  Requirements are eligibility checks, not deductions. Use `Reset` to specify what is lost.
- Cash multiplier: `1 + 0.5 * completedRebirths` (1, 1.5, 2, 2.5...). Set Mode to
  `Multiplicative` to use `Base * Factor ^ completedRebirths` instead.
- `Overrides[rebirthNumber]` can replace that rebirth's requirements and/or resulting multiplier.
  Overrides are exact for that tier; later tiers resume the formula unless also overridden.
- `MaxRebirths = 0` means unlimited; non-finite formula results disable further rebirths.
- `Reset`: set a field to false to preserve it, or a nonnegative number to reset it to that value.
  Supported fields: Speed, Cash, TreadmillLevel, StaminaConsumptionRate, BaseLevel, PendingOfflineCash.
  Default only resets Speed to 250, matching the current starting Speed. Keep this in sync if changing
  starting Speed in the profile config. Treadmill/plot reset levels must exist in their configurations.
- `RemoveAnimals` and `RemoveEggs` permanently remove owned items and active world instances.
  Both default false. `UnequipAnimals` returns active animals to inventory without deleting them.
  Index discoveries/claims, trails, purchases, gamepasses and paid credits remain intact.
- Training continues after the Speed reset. If TreadmillLevel resets, training stops on both
  server and client so the player can exit and enter the treadmill again normally.
  A stolen/carried egg returns to its nest when resets apply.
  Active hatch reveals must finish first. Reducing plot level restores only animals that fit;
  excess animals stay owned in the backpack.
- `CashSources`: independently toggle AnimalIncome, OfflineIncome, IndexRewards, OtherRewards.
  Online and offline animal income default on; Index and other rewards default off.
  OtherRewards means positive additions through CashService without a named source. Costs never multiply.
  Offline income is boosted when prepared on join and still capped at five hours; pending rewards
  are never multiplied again on claim. Animal inventory cards and all players' billboards show boosted rates.
  Index catalog earnings remain base species rates; Index reward previews follow the IndexRewards toggle.
- No Speed training bonus is granted; CashMultiplier affects only the selected cash sources.
- `Skip.Enabled` controls prompting/using retained credits; `Skip.ApplyResets` controls paid reset behavior.
  A skip bypasses requirements and grants one rebirth. It follows the same multiplier and cap.
- `RequestCooldown` limits normal/skip button requests on the server.

## Paid skip

Skip Rebirth uses developer product `3713833755`, registered with `Action = "SkipRebirth"` in
`src/shared/serverStorage/services/monetizationService/productIds.luau`.
The rebirth system reads that registry; do not duplicate the ID in the shared config or button.
Existing MonetizationController handles the prompt/overlay and successful purchase notification.

Only ProcessReceipt grants paid credits. Receipt IDs and credits persist in RebirthPurchases;
the service acknowledges purchases only after ProfileStore confirms the receipt was saved.
Duplicate receipts cannot grant a second rebirth. If delivery occurs while loading, revealing,
disabled or capped, the paid credit stays available for the Skip button when eligible.
Already purchased receipts are honored even if new skip purchases have since been disabled.

## UI

Uses `Panels.Rebirth.Body.Content`: Requirements.ProgressBar (Bar and Number), Rewards
(InfoNow, InfoNext and the authored reset-warning label), Rebirth, `Skip Rebirth`, and Title.
The reset-warning label is identified by its authored text containing "reset" because there
are two children named Title. Rename/update that lookup if changing the authored text.
The header's Close/Shop button (or first GuiButton) uses the existing PanelToggler.
Set the opener's GuiButton tag, Type=PanelToggler, PanelName=Rebirth.
Actions Rebirth and SkipRebirth use the existing button animation/SFX framework.

CashMultiplier is the total multiplier (1 = normal), derived from Rebirths on join; existing
profiles with CashMultiplier=0 migrate automatically. Change formulas in rebirthConfig, not saved
CashMultiplier values. Config changes take effect in new servers.

## Verification

Run `lune run tests/rebirth.luau` for mocked server logic tests. In Studio, verify panel paths,
progress, normal rebirth, owner/visitor income labels, and a real test product receipt.
The existing ProfileStoreService resets profiles every Studio session; persistence checks need
that existing development reset disabled or a controlled published test. No change to that reset
was made here.
