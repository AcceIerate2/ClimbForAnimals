# Global Speed and Cash/s leaderboards

The separate Knit LeaderboardService owns global persistence and cached rankings.
LeaderboardController renders the two existing world boards locally, including each
player's own MyStats row. Knit's existing module discovery loads both automatically.

## Scores and persistence

- Speed comes from DataService's saved Speed value (not Humanoid.WalkSpeed).
- Cash is the sum of active placed animals' cash/second from CashFlowService, including
  size/variant rates, the applicable rebirth multiplier, and AllTimeCashMultiplier.
  Wallet cash, cash packs and offline lump-sum claims do not count as income/second.
- These are current stats, not lifetime records: rebirth can lower Speed and removing
  animals can lower Cash/s. Offline users retain their last published scores.
- Scores are floored to whole numbers and capped at 2^53 - 1 for ordered-store storage.
- ProfileStore/DataService remain the source of truth; ordered stores are a derived index.
  No extra profile fields or changes to the existing data template are required.
- PlayerService connects rankings after plot/animal restoration and captures departure
  values before clearing animals or releasing profile data. Final writes are best effort;
  a Roblox outage can leave the previous published score until the player joins again.
- Players enter the global index after joining with this system installed. Historical
  profiles that have never joined since installation cannot appear automatically.

## Tuning

Edit `src/shared/replicatedStorage/GameConfiguration/Gameplay/leaderboardConfig.luau`:

| Setting | Default | Purpose |
| --- | --- | --- |
| DisplayCount | 100 | Visible rows per board; supported range 1–100 |
| RankLookupCount | 1000 | Shared bounded lookup for personal ranks; at least DisplayCount |
| SampleSeconds | 5 | Sample authoritative scores for publishing; does not update MyStats |
| SaveSeconds | 60 | Publish changed scores; unchanged scores skip writes |
| RefreshSeconds | 180 | Read global rankings after a three-minute countdown |
| LeaveWaitSeconds | 8 | Wait for an existing score write before attempting the final write |
| NameCacheSeconds | 3600 | Cache usernames to avoid repeated user lookups |
| StoreVersion | v1 | Changing it starts fresh indexes; it does not reset player profiles |

MyStats values and ranks both reflect the last global refresh, matching the board rows.
Outside the rank lookup range, MyStats freezes the last successfully published value
at refresh time. Live gameplay changes do not update this display between refreshes.
Exact row positions are available within RankLookupCount, with `1000+` beyond it.
Newly published players can show `Updating...` until their rank enters the next snapshot.
Tied scores follow Roblox's ordered result order, including at the lookup boundary.
Global changes normally propagate within roughly four minutes with default intervals;
throttling or outages can take longer. Increase the lookup depth cautiously: each extra
100 ranks adds a paged read per board on every refresh. Failed reads retain the old board.

The client snapshot endpoint only returns cached data. It never queries a datastore
or accepts a score. Writes are budget checked, one writer per player; failures retry
on subsequent write intervals. Usernames are fetched in batches; rows are reused,
avatars use Roblox thumbnail URLs, and streaming boards are rebound when they return.

## Authored hierarchy

Both `workspace.Scoreboard.Speed` and `workspace.Scoreboard.Cash` need:

```text
LeaderboardPart
  Surface
    Title
  SurfaceGui
    MyStats
      Default
        Icon
        PlayerName
        Rank
        Value
    ScrollingFrame
      UIListLayout
      UIPadding
      Template
        PlayerIcon
        PlayerName
        PlayerValue
        Rank
```

The controller hides Template and clones rows from it, preserving its styling.
Surface.Title displays an `Updates in M:SS` countdown using the server's scheduled
refresh time, then `Updating...` during the refresh. The client
updates this text once per second without additional remote or datastore requests.
ScrollingFrame uses automatic vertical canvas sizing. Cash values display `$…/s`;
Speed uses NumberShortner. Other boards such as Chest and Events are not bound.

## Verification

Run `lune run tests/leaderboards.luau` for mocked income, writes/retries, paging,
rank cache, departure ordering, row reuse and MyStats rendering checks.
Validate the actual GUI and cross-server persistence in Roblox Studio/published servers.
Studio uses Development stores; live servers use Production stores. Studio datastore
testing requires API Services access. The existing ProfileStoreService resets profile
data on Studio joins; that behavior is unchanged.

API references: [ordered data stores](https://create.roblox.com/docs/cloud-services/data-stores),
[request budgets](https://create.roblox.com/docs/reference/engine/enums/DataStoreRequestType),
[batched user information](https://create.roblox.com/docs/reference/engine/classes/UserService).
