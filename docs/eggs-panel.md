# Eggs panel

The panel lists the local player's placed eggs. Rows use the authored EggTemplate,
show a viewport preview, and update the countdown and progress from saved PlaceDate.
The row button says Skip Timer until the server marks CanHatch, then switches to Hatch.
Hatch closes the panel and runs the existing reveal. Grow All finishes growth without
hatching the animals automatically.

## Setup

Developer product IDs are configured in
`src/shared/serverStorage/services/monetizationService/productIds.luau`:

- `eggProduct("SkipTimer", rarity)`: one product per rarity, Common through Eternal.
- `eggProduct("GrowAll")`: finish all currently growing eggs on the purchaser's plot.

The server selects the skip ID using the selected egg's rarity in eggConfig.
Roblox's purchase prompt displays the price through MonetizationController.

Keep the hierarchy from the screenshot:
`General.Eggs.Body.Holder.ScrollingFrame.EggTemplate`, with Title, PurchaseBtn,
Bar.ViewportFrame, and ProgressBar.Bar / ProgressBar.Time.
`Body.Close` and `Eggs["Grow All"]` must be GuiButtons. PurchaseBtn can be a TextButton
or an ImageButton containing a TextLabel. The existing open button should have
`Type = Action`, `Action = ToggleEggVisibility`, and the GuiButton tag.
Close, Grow All, and generated row buttons are registered automatically.

Set VisiblePosition and HiddenPosition attributes on Eggs to customize its slide.
If absent, the authored position is the visible position and it slides off the right.

## Purchases and saved data

EggPurchaseService validates ownership and grants growth only through the existing
MonetizationService receipt callback. No client remote directly grants growth.
Receipts are recorded alongside credits in EggPurchases. A paid skip whose target
is already hatched/ready remains a credit for that rarity; the next matching click consumes it before
opening another purchase prompt. Grow All similarly keeps a credit if no eggs remain.
New skips are stored in SkipTimerCredits by rarity. Existing universal SkipTimer
credits are preserved separately. Pending targets are stored by product ID.
The receipt is acknowledged only after ProfileStore confirms its save.

This follows Roblox's [developer product receipt guidance](https://create.roblox.com/docs/production/monetization/developer-products):
the prompt-finished event only handles cancellation, never granting the reward.

## Studio checks

1. Open/close quickly and verify the right HUD buttons return correctly.
2. Place multiple eggs; rows and previews should appear and sort by placement date.
3. Let an egg mature; the progress completes and both the row and 3D prompt can hatch it.
4. With real product IDs configured, cancel a purchase and retry.
5. Buy a skip and Grow All; verify the panel and 3D eggs become ready together.
6. Hatch a selected egg before a delayed receipt arrives; verify the paid credit survives.

Mocked receipt/ownership tests and Luau compilation can run outside Studio.
The actual UI layout, animations, and Marketplace prompts need a Studio playtest.

MonetizationService dispatches receipts through productIds and fires UserPurchased after
a confirmed saved grant, once per receipt per session. Gamepasses remain in passIds.
