-- ===== SAFE INITIALIZATION FUNCTION - NO RESETEAR SAVES =====
function initialize_tde_global()
    if not storage then
      storage = {}
    end
  
    -- CRÍTICO: Solo inicializar si NO existe storage.tde (partida nueva)
    if not storage.tde then
      log("TDE: Creating NEW game - initializing fresh data")
      storage.tde = {
        -- Kill tracking system - AJUSTADO para costos escalados
        total_kills = 0, -- Aumentado de 50 a 80 para gun-turret (35) + automation (10) + electronics (40)
        total_boss_kills = 0,
        technologies_unlocked = {},
        research_count = 0, -- NEW: Track number of technologies researched
        
        -- Wave system
        wave_count = 0,
        next_wave_tick = game.tick + 1800,
        active_waves = {},
        boss_wave = false,
        BOSS_EVERY = DEFAULT_BOSS_EVERY,
        
        -- Master Ammo Chest system
        master_ammo_chests = {},
        global_turrets = {},
        
        -- Resource system
        infinite_resources = {},
        
        -- Nest system with HP scaling
        nest_territories = {},
        
        -- Setup flag
        world_setup_complete = false,
        
        -- MAC reconstruction flag
        mac_needs_reconstruction = true,
        
        -- Base Heart system
        base_heart = nil,
        game_over = false
      }
      log("TDE: Initialized NEW global structure with starting kills")
    else
      log("TDE: EXISTING save detected - preserving all data")
      -- SOLO asegurar que tenga todas las propiedades necesarias sin cambiar valores
      if storage.tde.total_kills == nil then storage.tde.total_kills = 0 end
      if storage.tde.total_boss_kills == nil then storage.tde.total_boss_kills = 0 end
      if not storage.tde.technologies_unlocked then storage.tde.technologies_unlocked = {} end
      if storage.tde.research_count == nil then storage.tde.research_count = 0 end -- NEW
      -- Only set wave_count if nil, never overwrite if it exists
      if storage.tde.wave_count == nil then
        storage.tde.wave_count = 0
        log("TDE: wave_count was nil, set to 0")
      else
        log("TDE: wave_count preserved: " .. tostring(storage.tde.wave_count))
      end
      if not storage.tde.active_waves then storage.tde.active_waves = {} end
      if not storage.tde.master_ammo_chests then storage.tde.master_ammo_chests = {} end
      if storage.tde.BOSS_EVERY == nil then storage.tde.BOSS_EVERY = 0 end
      if not storage.tde.global_turrets then storage.tde.global_turrets = {} end
      if not storage.tde.infinite_resources then storage.tde.infinite_resources = {} end
      if not storage.tde.nest_territories then storage.tde.nest_territories = {} end
      if storage.tde.world_setup_complete == nil then storage.tde.world_setup_complete = false end
      if storage.tde.mac_needs_reconstruction == nil then storage.tde.mac_needs_reconstruction = false end
      if storage.tde.base_heart == nil then storage.tde.base_heart = nil end
      if storage.tde.game_over == nil then storage.tde.game_over = false end
  
      -- CRÍTICO: NO tocar next_wave_tick si ya existe un valor válido
      if storage.tde.next_wave_tick == nil then
        storage.tde.next_wave_tick = game.tick + 1800
        log("TDE: Added missing next_wave_tick to existing save")
      else
        log("TDE: Preserving existing wave timing: " .. tostring(storage.tde.next_wave_tick))
      end
  
      log("TDE: Preserved existing save - Kills: " .. storage.tde.total_kills .. ", Wave: " .. storage.tde.wave_count)
    end
end

