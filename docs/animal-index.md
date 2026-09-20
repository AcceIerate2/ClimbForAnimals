# Animal index

UI: PlayerGui.Panels.Index. Existing panel toggler handles opening and closing.
Set the HUD index button's GuiButton tag, Type = PanelToggler, PanelName = Index.
The panel setup links Header.Shop (the supplied close-button name), or a named Close
button if present. ClaimBtn.TextLabel is updated automatically.

Numbered biome Frames are replaced with ImageButton roots at runtime, preserving their
children, layout, and attributes. Existing button roots are reused. They use the Buttons
module for animation/sounds and the SelectIndexAnimal action. ViewportFrames are added.
Their existing UIGradients use muted rarityGradients, falling back to a muted rarityColors
shade at the top and a darker bottom. Common starts at RGB (152, 152, 152).
Undiscovered models render as black silhouettes; names and income show ???.
Both the biome and total progress bars use discovered species counts, not claim counts.

The catalog uses eggConfig.Eggs.Animal / Biome / Rarity and animalConfig income.
Biome order follows zoneConfig.Height. Mystic Isles accepts the UI spelling Mistic Isles.
Cards are sorted by base income, then animal name. Unused numbered cards are hidden.
No duplicate animal or biome configuration was added. Current configs contain 75 species.

AnimalIndex.Discovered and AnimalIndex.Claimed persist in the player profile.
A successful hatch records discovery when ownership is granted, before the reveal ends.
Discovery is permanent and shared across variants. Existing animals from before this
feature are not inferred as prior hatches; their next hatch will unlock the species.

Add the owner's reward formula inside IndexService:GetReward(animalName), returning
cash, speed. This server method can read the existing animalConfig. Until configured,
rewards show zero / COMING SOON and claims are rejected without marking them claimed.
Only finite, nonnegative amounts with at least one positive reward are accepted.
The client sends only the species name; the server checks discovery and prior claim,
then grants cash through CashService and speed through the existing Speed value object.

Studio checks: open Index, select locked and unlocked cards, verify silhouette previews,
scroll through all ten biomes, hatch two variants of the same species, and verify the
count increases only once. Supply a test reward formula, claim it twice, and verify one
grant. Rejoin to verify discovery and claim persistence (disable any Studio profile-reset
option if testing persistence). Resize the viewport and check preview/progress layout.

## Preview polish

Index-only previews fit the visible model parts in camera space and ignore invisible
hitboxes. Resting bounds are cached so idle animations do not move the camera.
CardPadding and DetailPadding in indexPanel/preview.luau control framing separately.
White Ambient / LightColor and the angled front view are retained. The detail viewport
fits above its labels. Selection adds a subtle stroke and a short preview fade.
Only cards intersecting the scroll window load/play idle animations; scroll and resize
signals update visibility without a per-frame loop. The authored canvas is unchanged.
