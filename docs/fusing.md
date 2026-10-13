# Animal fusion

The existing lobby controller already opens `Fuse` from `workspace.MutateMachine.Hitbox`. The panel uses the supplied `Body.Content.Animals.Slot1/2/3`, `PossibleFusions.Template`, `Timer`, `Body.Selection.ScrollingFrame.Template`, and `Header.FusePanelToggler` hierarchy. Slots and selection templates must be GuiButtons. Each row uses AnimalName, VariantName, Weight, ViewportFrame, and VariantStroke; empty slots also use X.

Click an empty slot to select an animal. The selection list only offers matching species/variants after the first selection, excludes selected animals and eggs, and excludes the highest variant. Selecting returns to Content. Click an occupied slot to remove it; click it again to choose a replacement. Closing/reopening the panel returns to Content without cancelling the saved fusion. The possible-result viewport appears once all three slots are filled.

`GameConfiguration/Gameplay/fuseConfig.luau` controls:

- Duration: 600 seconds. DurationByVariant optionally overrides the time for an input variant.
- WeightMode: Average (default), Highest, or Sum. Average uses actual weight, computed from scale cubed; the output's scale is the cube root of the resulting weight ratio. Species remains unchanged. Gender is inherited from slot 1.
- ResetOnRemoval: true resets to a full duration; false pauses the remaining time until the slots are filled again. Emptying every slot always clears paused time.
- Enabled, UpdateInterval, RequestCooldown. SlotCount corresponds to the three authored slot buttons; changing it also requires adding/removing those buttons.

Variant progression reads the order in eggConfig.Variants: Normal → Golden → Diamond → Ruby. Ruby currently cannot fuse further. Adding further tiers requires the corresponding animal assets, income settings, and variant styling as well as updating that list. No price is charged for fusion.

FuseService validates all requests on the server. Selected animals remain in Inventory but are reserved by the saved Fuse.Slots references. Selecting an animal on the plot removes its placement and income; its tool is removed too. Reserved animals cannot be placed or sold, including Sell All. Removing one returns it to the backpack rather than its former plot position. Inventory restoration also respects reservations on rejoin.

Fuse.FinishAt is an absolute server timestamp saved through the existing DataService/ProfileStore profile. Closing the menu or leaving does not stop the clock. Completed offline jobs grant the output on the first service tick after the player's profile/animals are loaded. The three inputs are replaced in one Inventory write, then the job is cleared without yielding, preventing duplicate grants from repeated ticks. Fusion respects existing rebirth removal rules: if a reset deletes an input, that job cannot grant a reward. Missing inputs are cleared at completion, and remaining animals stay removable. If a required output asset becomes unavailable, inputs remain owned and the countdown stops.

Implementation is separated into FuseService, FuseController, the fuse panel and row module, a button action, and shared configuration. UI uses existing buttons, scrolling-canvas, viewport, weight, and variant styling utilities. The countdown does not make server requests; the server polls at one-second intervals and only copies inventory for a due job or a slot change.

Run `lune run tests/fusing.luau` and `lune run tests/animal-selling.luau`. In Studio, temporarily reduce Duration and test all three upgrades, selecting plot animals, removal during a countdown, closing/reopening, Sell All, and rejoining after a job finishes. Confirm the authored viewport sizing and mobile layout visually; the automated tests do not render Roblox UI.
