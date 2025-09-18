-- ===== GLOBAL VARIABLES =====
SAFE_ZONE_RADIUS = settings.global["tde-safe-zone-radius"].value  -- 150-200 tiles safe zone
NEST_SPACING = settings.global["tde-nest-spacing"].value        -- 1 nest every 5 tiles
WAVE_INTERVAL = settings.global["tde-wave-interval"].value * 60 * 60   -- 10 minutes in ticks (10 * 60 * 60 = 36000)
MAX_DISTANCE_HP = 50000 -- Max distance for HP scaling
BASE_HEART_MAX_HP = 100000 -- Base Heart maximum HP
BASE_HEART_REGEN_RATE = 50 -- HP regenerated per minute
DEFAULT_BOSS_EVERY = 10

-- UTILITY: Table size function for compatibility
function table_size(t)
  local count = 0
  if t then
    for _ in pairs(t) do count = count + 1 end
  end
  return count
end
