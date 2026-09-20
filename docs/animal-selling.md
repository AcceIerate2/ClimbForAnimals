# Selling animals

`AnimalSellService` validates ownership and prices on the server. `AnimalSellController`
handles requests and notifications; `sellAnimalsPanel` binds the existing SellAnimals UI.
The lobby's existing SellAnimals stall opens the panel through PanelController.

## Pricing

Edit `GameConfiguration/Economy/animalSellConfig.luau` to change `IncomeSeconds` (default 10).
The formula uses EarningCurve's animal rate, rolled size and variant, then the applicable
rebirth AnimalIncome multiplier and AllTimeCashMultiplier. The sale price is rounded to
whole cash. The same quote function drives individual buttons and the Sell All total.

CashService receives the already-calculated price with source `AnimalSale`, preventing
bonuses from multiplying it a second time. Plot and backpack animals use the same formula.
Cash and inventory changes remain in the same active ProfileStore session via DataService.

## Behavior

- Individual buttons sell one owned animal. Sell All includes plot and backpack animals.
- AnimalService removes the animal, its tool/placement and ongoing income.
- Eggs remain visible, locked, and sorted after every animal; the server rejects egg sales.
- Animals sort by sale price descending, then stable inventory reference ID.
- Plot status uses white text on green; Backpack uses white text on white, retaining
  authored text strokes for readability.
- The existing Locked overlay provides the lock icon and Can't Sell message.
- Rarity labels/tints and viewport fitting reuse the animal/egg display utilities.
- Success notifies `Dog sold for $300!` (or the number of animals for Sell All) and plays
  the same `Cash` sound used after the offline earnings count-up via NotificationController.
- Requests during an animal's hatch reveal are rejected until the reveal finishes.
- Empty inventory, missing ownership, and invalid requests never grant money.
- Rendering is deferred/coalesced and only refreshed while open. Rows and previews are
  reused; removed rows and destroyed panels disconnect their listeners and previews.

## UI

Uses `Panels.SellAnimals.Body.Content.Holder.ScrollingFrame.PetsTemplate` with:
`View.ViewportFrame`, `View.Status`, `Locked`, `SellBtn`, `Background`, `ItemName`,
`IncomePerSecond`, and `Rarity`. SellBtn uses its existing TextLabel descendant.

SellAll may be under Body or Content. Header may be under the panel or Body; its
`Header` text label shows the total and `Shop` button closes the panel.
Buttons run through the existing Action framework for animations and SFX.

Run `lune run tests/animal-selling.luau` for server ownership, egg rejection, pricing,
duplicate prevention, Sell All, and panel ordering/total checks. Live Studio validation
is still needed for the authored overlay, viewport presentation, and sounds.
