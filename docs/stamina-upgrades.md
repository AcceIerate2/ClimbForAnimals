# Stamina upgrades

Edit `src/shared/replicatedStorage/GameConfiguration/Economy/staminaUpgradeConfig.luau` to tune progression.

Defaults: level 1, maximum level 50, first upgrade $1M, each subsequent price doubles. Stamina remains a 100-point meter; each level adds one second between drain ticks. At level 1 it drains every second; at level 2 every two seconds. Buying an upgrade does not refill the meter.

- `FirstPrice`, `PriceGrowth`: price = FirstPrice × PriceGrowth ^ (current level − BaseLevel).
- `BaseDrainInterval`, `DrainIntervalPerLevel`: seconds between ticks = BaseDrainInterval + (level − BaseLevel) × DrainIntervalPerLevel.
- `MaxLevel`: last purchasable level.
- `Enabled`: disable purchases while preserving existing upgrades.
- `Overrides[targetLevel]`: optional `{ Price = 1500000, DrainInterval = 2.5 }` replaces the formula for that level.

Use finite nonnegative prices, positive drain intervals, and integer levels with MaxLevel ≥ BaseLevel. Keep drain intervals increasing with level. The separate Gameplay/staminaConfig still controls maximum stamina, consumption amount, and tired slowdown.

StaminaUpgradeService validates purchases and deducts cash through CashService. DataService replicates StaminaLevel and StaminaConsumptionRate; ProfileStore saves them. A zero level in the profile template is a migration marker, converted at login using the existing drain interval. The existing StaminaController reads the replicated interval while climbing, so upgrades take effect immediately.

Upgrades survive rebirth by default. Set `rebirthConfig.Reset.StaminaLevel = 1` to reset them; the service also resets the drain interval. Prefer this setting over the legacy StaminaConsumptionRate reset.

StaminaUpgradeController handles requests and notifications. The staminaPanel setup binds the existing PurchaseBtn through ButtonsController and fills Stud.CurrentLevel, Stud.NewLevel, and PurchaseBtn.TextLabel with the current level, next level, and shortened cash price. The authored panel appearance is preserved.

Run `lune run tests/stamina-upgrades.luau` for purchase and migration checks. Verify the panel and climbing behavior in Studio with Rojo connected.
