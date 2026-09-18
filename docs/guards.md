# Guard setup

Author guards in `Workspace.Guards.<IslandName>` with one or more uniquely named guard Models.
The island names must match `Workspace.Structures.Islands.<IslandName>`.
At startup GuardService moves the guard templates to `ReplicatedStorage.Assets.Guards`;
each client clones its own rigs into `Workspace.LocalGuards`. You can also author the
templates directly in `ReplicatedStorage.Assets.Guards`.

Each island needs an `Area` BasePart. This can be the ground itself: detection uses its
rotated X/Z bounds and `ZoneHeight` above the part. Each guard uses the island's Area
for patrol unless a separate `PatrolZone` BasePart exists in its island or guard folder.
For individual zones, add an ObjectValue named `PatrolZone` to the guard model and point
it to a world-space BasePart. Patrol zones should be flat rectangular walkable surfaces;
this tween-based system does not pathfind around obstacles.

Each guard model should have:

- A PrimaryPart (or HumanoidRootPart), with the rest of the rig properly jointed to it.
- An AnimationController and Animator, or an existing Humanoid and Animator.
- `Idle` and `Walk` Animation instances with your AnimationId values.
- A `Hitbox` BasePart positioned around its body. It is made invisible and attached to
  the root locally. If absent, a default hitbox is created from guardConfig.

The whole guard's footprint must fit its patrol zone. Movement clamps inward from the
edges to account for rig size and rotation. Guards also stay inside these bounds while
chasing a player outside their smaller patrol area.

The existing `ReplicatedStorage.Assets.Gui.GuardAlertGui` is shown during chase.
`AlertDanger` plays when a chase starts, `Running` loops while guards chase, and `Punch`
plays after the server accepts a catch. Guards only chase players carrying a stolen egg.
Entering an Area with an egg, or stealing one while inside it, starts a chase. Dropping or
claiming the egg, leaving the Area, dying, or getting caught returns guards to patrol.

The alert attachment is positioned above the visible rig with `AlertHeightOffset`; invisible
hitbox/root parts do not affect its height or how the guard rests on the ground. Guards turn
smoothly each render frame, tracking the player during a chase. Adjust `TurnSpeed`
in `guardConfig` to change responsiveness. The red highlight exists only during a chase.

Tune timings, chase speed, zone height, hit tolerance, punch strength, and ragdoll duration
in `GameConfiguration.Gameplay.guardConfig`. The default punch is mild and ragdoll lasts
one second. Ragdoll joints require a Motor6D character rig (R6/R15).

GuardController calls `GuardService:Capture`. The server validates the guard ID, finite
positions, protected/patrol bounds, proximity to the player's current position, line of
sight, health, and cooldowns. It selects only the caller's carried egg and places it on
the ground at the capture X/Z before applying ragdoll. A small network-position tolerance
permits the sampled capture location to differ from the latest replicated player position.
The dropped egg uses the existing world model, prompt, and carry/claim rules. The server
temporarily owns character physics for the ragdoll and punch, then restores ownership.
Rejected captures with setup/position/obstruction errors are logged once per distinct reason
in the client Output to make Studio troubleshooting possible.

Unclaimed captures are not authoritative guard simulations: an altered client can disable
its guards or suppress capture reports. The server validates reported catches and owns egg
state, but cannot prove that a client-only guard actually made contact.

Studio checks: use two players, confirm guards differ per client, carry an egg into an Area,
get caught, verify both clients see the dropped egg, pick it up again after recovery, and
test leaving the Area, death/respawn, rotated areas, and quick crossings of the hitbox.
