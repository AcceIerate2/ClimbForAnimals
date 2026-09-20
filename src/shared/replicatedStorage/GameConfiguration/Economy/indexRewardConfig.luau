
-- Index claim rewards.
-- Cash is the animal's own income, so an income rebalance carries it along.
-- Speed is a band per biome, spread across that biome's cards: card 1 pays the band's floor
-- and the last card pays SpeedSlotSpread times it, so no two animals of a biome ever pay the
-- same. INVARIANT: SpeedSlotSpread must stay BELOW SpeedBiomeGrowth, otherwise the bands
-- overlap and a late card of one biome pays more than the first card of the next.
local IndexRewardConfig = {}

-- Cash = the animal's CashPerSecond times this, i.e. how many seconds of its income one claim
-- is worth. 100 is the value the reference game uses.
IndexRewardConfig.CashSeconds = 100

-- Speed of the first biome's first card, and how much each biome deeper multiplies it.
-- 420 x 2.85^9 x 2.2 lands the last card of the last biome at ~11.5M, the reference's scale.
IndexRewardConfig.SpeedBase = 420
IndexRewardConfig.SpeedBiomeGrowth = 2.85
IndexRewardConfig.SpeedSlotSpread = 2.2

return IndexRewardConfig
