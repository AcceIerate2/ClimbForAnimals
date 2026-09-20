# Animals panel

Uses `PlayerGui.General.Animals` with the hierarchy supplied in the Explorer screenshot.
`Body.Holder.ScrollingFrame.AnimalTemplate` remains hidden and is cloned per owned animal.
The header is `Body.Header.header`. `Body.Close`, `BuySlot`, `EquipBest`, and each
`AnimalTemplate.EquipToggler` must be GuiButtons. EquipToggler uses its `TextLabel` child.
BuySlot displays its price in its first descendant TextLabel (or its own text if a TextButton).

## Open button

Give the HUD button the `GuiButton` tag and these attributes:
- `Type = Action`
- `Action = ToggleAnimalVisibility`

Close, BuySlot, EquipBest, and row buttons are connected automatically. Set the panel's
VisiblePosition and HiddenPosition attributes to customize its slide. Opening Animals
closes Eggs, and vice versa. Both close while the climbing height bar is visible.

## Slots and equipment

BuySlot uses the existing UpgradeBase action and BaseUpgradeController. Its displayed
price comes from the next BaseLevel in GameConfiguration/Economy/baseUpgradeConfig.
The existing button wording is retained. At the final plot level, the button is disabled.
BaseUpgradeService charges cash, upgrades the plot fences, and sets MaxAnimals from
that level's config. There is no separate animal-slot price formula or purchase endpoint.

Equip Best selects the highest actual cash-per-second rates, including size and variant
bonuses. Ties prefer currently equipped animals. Existing selected animals keep their
positions; unequipped animals return to the backpack through AnimalService. Animals
still being revealed cannot be equipped early. Invalid/unavailable rigs are skipped by
Equip Best. All requests use the requesting player's saved inventory and slot limit.

## Verification

Mock checks cover ranking, keeping existing rigs, repeat Equip Best, reveal checks,
foreign references, request throttling, loading state, and the equip limit. Changed Luau files compile.

In Studio, verify the authored button labels, viewport previews, green EQUIP/red UNEQUIP
backgrounds, panel transitions, tool removal/restoration, and slot persistence after rejoin.
