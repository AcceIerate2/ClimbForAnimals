# Shop products

Gamepass IDs live in monetizationService/passIds.luau:
- 3713831619: 2x hatch speed. New eggs take half the normal duration; existing eggs keep
  their progress and halve their remaining wait when the bonus first applies.
- 3713831694: 2x cash. Sets AllTimeCashMultiplier to 2, separate from rebirth CashMultiplier.
  Repeated ownership checks set 2 rather than stacking. Rebirth does not reset either pass.

Income = animal's size/variant-adjusted rate * rebirth multiplier * AllTimeCashMultiplier.
The permanent cash bonus applies to online/offline animal income and positive CashService
rewards (including Index cash). Spending is unchanged. Already-calculated offline cash and
cash packs are excluded from further multiplication. Owner/visitor billboards and animal
inventory cards use the same multipliers. Passes load before offline payouts are prepared.

Cash pack IDs and editable CashAmount values live in monetizationService/productIds.luau:
- 3713831826: 3,000
- 3713831881: 40,000
- 3713831956: 250,000
- 3713831998: 1,500,000
- 3713832029: 5,000,000

Packs grant their exact listed amount through CashService. ProcessReceipt saves the grant
and PurchaseHistory receipt marker in the same player profile before acknowledging Roblox.
Retries do not grant a second pack. Pack purchases are delivered to the buyer.

ShopPanel automatically binds Cash.cashProduct1?5 and Cash2x/Hatch2x.PurchaseBtn
under Shop.Body.Content.Holder.ScrollingFrame. ShopKey in each server registry maps
the item to its UI. Cash amounts update from CashAmount; prices load through
MonetizationController from Roblox. No client IDs or prices need editing.
Owned passes display "Owned" and cannot be repurchased; successful grants update
that text live. Unavailable prices disable purchasing and retry on reopening.
Buttons use the existing Purchase handler, animation/SFX and purchase overlay.
The authored scrolling layout is preserved.

Saved egg HatchDate/HatchDuration/HatchSpeedMultiplier keep world countdowns, growth visuals,
the egg panel and server completion synchronized across purchases and rejoins.
