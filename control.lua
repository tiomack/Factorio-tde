-- Tower Defense Evolution - Pure Kills System
-- Complete tower defense conversion with kill-based tech progression
-- VERSION 5.2.0 - MULTIPLAYER + SPACE AGE DLC SUPPORT

require("scripts.variables")

require("scripts.init")

require("scripts.base")
require("scripts.research")
require("scripts.enemy")
require("scripts.mac")
require("scripts.gen")
require("scripts.ammo_turrets")

require("scripts.wave")

require("scripts.gui")
require("scripts.commands")

-- NEW: Load multiplayer and Space Age modules
local multiplayer = require("scripts.multiplayer")
local space_age = require("scripts.space_age")

function show_welcome_messages(player)
  if player and player.valid then
    player.print("=== WELCOME TO TOWER DEFENSE EVOLUTION ===", {r = 0, g = 1, b = 1})
    player.print("This is a tower defense conversion mod!", {r = 1, g = 1, b = 0})
    player.print("• Kill biters to earn research tokens", {r = 1, g = 1, b = 1})
    player.print("• Tokens are stored in your Base Heart", {r = 0, g = 1, b = 0})
    player.print("• Technologies have different costs by category:", {r = 0, g = 0.8, b = 1})
    player.print("  ⚔️ Combat techs: 2x cost (military, damage, turrets)", {r = 1, g = 0.5, b = 0})
    player.print("  🏭 Production techs: 1.5x cost (assembling, oil, science)", {r = 1, g = 0.8, b = 0})
    player.print("  🛠️ Utility techs: 0.5x cost (toolbelt, landfill, gates, lights)", {r = 0, g = 1, b = 0})
    player.print("  📋 Standard techs: 1x cost (everything else)", {r = 1, g = 1, b = 1})
    
    local config = get_research_settings()
    player.print(string.format("• Base costs scale: Start at %d, then +%d until %d", 
      config.base_cost, config.increment_1, config.threshold_1), {r = 0, g = 0.8, b = 1})
    player.print(string.format("• Then +%d until %d, +%d until %d, +%d after %d!", 
      config.increment_2, config.threshold_2, config.increment_3, config.threshold_3, config.increment_final, config.threshold_3), {r = 0, g = 0.8, b = 1})
    player.print("• Costs can be customized in mod settings!", {r = 1, g = 1, b = 0})
    
    player.print("• Build turrets and defenses to survive waves", {r = 1, g = 0.5, b = 0})
    player.print(string.format("• Waves come every %d minutes, bosses every 10 waves",(WAVE_INTERVAL/60/60)), {r = 1, g = 0.8, b = 0})
    player.print("• If your Base Heart is destroyed, you lose!", {r = 1, g = 0, b = 0})
    player.print("• Build Master Ammo Chests for automatic distribution", {r = 0, g = 0.8, b = 1})
    player.print("Good luck, defender!", {r = 0, g = 1, b = 0})
  end
end

function create_attack_group(spawn_point, composition, is_boss, spawn_info, boss_kill_value)
  local surface = game.surfaces[1]
  if not surface or not surface.valid then
    log("TDE: Invalid surface in create_attack_group")
    return
  end
  
  if not spawn_point then
    log("TDE: Invalid spawn_point in create_attack_group")
    return
  end
  
  local unit_group = surface.create_unit_group({
    position = spawn_point,
    force = game.forces.enemy
  })
  
  if not unit_group then
    log("TDE: Failed to create unit group at " .. spawn_point.x .. "," .. spawn_point.y)
    return
  end
  
  local units_created = 0
  
  for unit_type, count in pairs(composition) do
    for i = 1, count do
      local unit_position = {
        x = spawn_point.x + math.random(-20, 20),
        y = spawn_point.y + math.random(-20, 20)
      }
      
      local valid_position = surface.find_non_colliding_position(unit_type, unit_position, 25, 3)
      if valid_position then
        local success, unit = pcall(function()
          return surface.create_entity({
            name = unit_type,
            position = valid_position,
            force = game.forces.enemy
          })
        end)
        
        if success and unit and unit.valid then
          units_created = units_created + 1
          
          -- Apply boss modifications
          if is_boss and boss_kill_value then
            -- Calculate boss HP scaling based on wave number and enemy tier - ENHANCED SCALING
            local base_hp = unit.health
            local wave_number = storage.tde.wave_count or 1
            local boss_wave_number = math.floor(wave_number / storage.tde.BOSS_EVERY) -- Which boss wave this is
            
            -- Get enemy tier for HP scaling
            local enemy_tier = 1
            if space_age and space_age.get_enemy_tier then
                enemy_tier = space_age.get_enemy_tier(unit.name) or 1
            end
            
            -- Check if this is a Space Age boss (Demolisher, etc.)
            local is_space_age_boss = false
            if space_age and space_age.is_space_age_available() then
                local boss_enemy, planet_data = space_age.get_boss_enemy_type()
                if unit.name == boss_enemy and planet_data then
                    is_space_age_boss = true
                end
            end
            
            if is_space_age_boss then
                -- Space Age bosses use tier-based scaling instead of vanilla HP
                local tier_multiplier = 1 + (enemy_tier - 1) * 0.5 -- Each tier adds 50% base HP
                local boss_hp_multiplier = 1
                if boss_wave_number > 0 then
                    -- Progressive scaling with tier consideration
                    local progression = 1000 + (boss_wave_number - 1) * 1500 + (boss_wave_number - 1) * (boss_wave_number - 1) * 250
                    boss_hp_multiplier = (progression * tier_multiplier) / base_hp
                end
                
                unit.health = base_hp * boss_hp_multiplier
                
                log("TDE: Created Space Age boss with " .. math.floor(unit.health) .. " HP (wave " .. wave_number .. ", tier " .. enemy_tier .. ")")
            else
                -- Vanilla bosses use progressive scaling formula with tier consideration
                -- Formula: 1000 + (boss_wave_number - 1) * 1500 + (boss_wave_number - 1) * (boss_wave_number - 1) * 250
                -- This gives: Wave 10: 1000, Wave 20: 2500, Wave 30: 4000, Wave 40: 5750, Wave 50: 8000
                local tier_multiplier = 1 + (enemy_tier - 1) * 0.3 -- Each tier adds 30% base HP for vanilla bosses
                local boss_hp_multiplier = 1
                if boss_wave_number > 0 then
                    local progression = 1000 + (boss_wave_number - 1) * 1500 + (boss_wave_number - 1) * (boss_wave_number - 1) * 250
                    boss_hp_multiplier = (progression * tier_multiplier) / base_hp
                end
                
                unit.health = base_hp * boss_hp_multiplier
                
                log("TDE: Created vanilla boss with " .. math.floor(unit.health) .. " HP (wave " .. wave_number .. ", boss #" .. boss_wave_number .. ", tier " .. enemy_tier .. ")")
            end
            
            -- Store boss kill value
            local unit_id = unit.unit_number
            if unit_id and storage.tde and storage.tde.nest_territories then
              storage.tde.nest_territories[unit_id] = {
                is_boss = true,
                kill_value = boss_kill_value
              }
            end
          end
          
          unit_group.add_member(unit)
        else
          log("TDE: Failed to create unit " .. unit_type .. " at " .. valid_position.x .. "," .. valid_position.y)
        end
      else
        log("TDE: No valid position found for " .. unit_type .. " near " .. unit_position.x .. "," .. unit_position.y)
      end
    end
  end
  
  if units_created == 0 then
    log("TDE: No units created for attack group, destroying empty unit group")
    unit_group.destroy()
    return
  end
  
  -- CRITICAL FIX: Use Factorio 2.0 command system properly
  local player_base = find_player_base_center()
  
  if player_base and unit_group.valid then
    -- FIXED: Use the new 2.0 commandable system with proper validation
    unit_group.set_command({
      type = defines.command.compound,
      structure_type = defines.compound_command.return_last,
      commands = {
        {
          type = defines.command.attack_area,
          destination = player_base,
          radius = 20, -- Small constant radius around current path
          distraction = defines.distraction.by_anything
        },
        {
          type = defines.command.attack_area, -- Changed from attack to attack_area for reliability
          destination = player_base,
          radius = 50,
          distraction = defines.distraction.by_anything
        }
      }
    })
  else
    -- Fallback: attack direct area
    if unit_group.valid then
      unit_group.set_command({
        type = defines.command.attack_area,
        destination = {x = 0, y = 0},
        radius = 150,
        distraction = defines.distraction.by_enemy
      })
    end
  end
  
  -- Announce direction only once with correct information
  if spawn_info and spawn_info.name and spawn_info.arrow then
    local boss_prefix = is_boss and "BOSS " or ""
    game.print(string.format("%s%s %s %s Attack incoming! (%d units)", 
      boss_prefix, spawn_info.arrow, spawn_info.name, spawn_info.arrow, units_created), {r = 1, g = 0.5, b = 0})
  end
  
  table.insert(storage.tde.active_waves, {
    group = unit_group,
    spawn_time = game.tick,
    wave_number = storage.tde.wave_count,
    is_boss = is_boss or false,
    destination = player_base or {x = 0, y = 0},
    direction = spawn_info and spawn_info.direction
  })
  
  log("TDE: Created attack group with " .. units_created .. " units")
end

function find_player_base_center()
  local surface = game.surfaces[1]
  if not surface or not surface.valid then return {x = 0, y = 0} end

  -- Priority 1: Return exact position of the base heart
  local base_heart = find_base_heart()
  if base_heart and base_heart.valid then
    return base_heart.position
  end

  -- Priority 2: Fallback to player's important structures (excluding ignored types/names)
  local relevant_entities = {}
  for _, entity in pairs(surface.find_entities_filtered{force = "player"}) do
    if entity.valid and entity.prototype.selectable_in_game then
      if not excluded_types[entity.type] and not excluded_names[entity.name] then
        table.insert(relevant_entities, entity)
      end
    end
  end

  if #relevant_entities > 0 then
    local total_x, total_y = 0, 0
    for _, entity in pairs(relevant_entities) do
      total_x = total_x + entity.position.x
      total_y = total_y + entity.position.y
    end
    return {x = total_x / #relevant_entities, y = total_y / #relevant_entities}
  end

  -- Priority 3: Fallback to a valid player's position
  for _, player in pairs(game.players) do
    if player.valid and player.character then
      return player.position
    end
  end

  -- Final fallback: origin
  return {x = 0, y = 0}
end

-- ===== RESTORE get_enemy_evolution FUNCTION =====
function get_enemy_evolution()
  local success, evolution = pcall(function()
    return game.forces.enemy.get_evolution_factor()
  end)
  if success and evolution then
    return evolution
  else
    -- Fallback calculation based on time if API fails
    local ticks = game.tick or 0
    return math.min(1, ticks / (60 * 60 * 60)) -- 1 hour to max
  end
end

-- Helper function para table_size
function table_size(t)
  local count = 0
  if t then
    for _ in pairs(t) do count = count + 1 end
  end
  return count
end

-- ===== INITIALIZATION =====
-- Note: initialize_tde_global function is defined in scripts/init.lua
-- This function is called from on_init and on_configuration_changed events

script.on_init(function()
  log("TDE: on_init called - NEW GAME")
  initialize_tde_global()
  
  -- Create base heart immediately
  create_base_heart()
  
  -- Schedule first wave (30 seconds after game start)
  storage.tde.next_wave_tick = game.tick + 1800
  
  -- Show welcome messages to players
  for _, player in pairs(game.players) do
    show_welcome_messages(player)
  end
  
  game.print("=== TOWER DEFENSE EVOLUTION - PURE KILLS SYSTEM ===", {r = 0, g = 1, b = 1})
  game.print("Kill biters to unlock technologies with dynamic costs!", {r = 1, g = 1, b = 0})
  
  local config = get_research_settings()
  game.print(string.format("Research costs: %d → +%d → +%d → +%d → +%d (customizable in settings)", 
    config.base_cost, config.increment_1, config.increment_2, config.increment_3, config.increment_final), {r = 0, g = 0.8, b = 1})
  
  game.print("First wave in 30 seconds!", {r = 1, g = 0.8, b = 0})
  game.print("Build Master Ammo Chests for automatic distribution!", {r = 0, g = 1, b = 0.5})
  game.print("DEFEND YOUR BASE HEART AT ALL COSTS!", {r = 1, g = 0, b = 0})

  for _, player in pairs(game.players) do
    create_wave_timer_gui(player)
  end
end)

-- Handle migration for existing saves - TIMING CORREGIDO PARA MAC
script.on_configuration_changed(function(event)
  log("TDE: on_configuration_changed called - LOADING EXISTING SAVE")
  
  -- Solo verificar estructura sin resetear datos
  if not storage or not storage.tde then
    log("TDE: Missing global structure in existing save - initializing")
    initialize_tde_global()
  else
    log("TDE: Existing save loaded successfully")
    -- Solo añadir campos faltantes sin tocar valores existentes
    if storage.tde.total_kills == nil then storage.tde.total_kills = 0 end
    if storage.tde.total_boss_kills == nil then storage.tde.total_boss_kills = 0 end
    if storage.tde.BOSS_EVERY == nil then storage.tde.BOSS_EVERY = DEFAULT_BOSS_EVERY end
    if not storage.tde.technologies_unlocked then storage.tde.technologies_unlocked = {} end
    if storage.tde.research_count == nil then storage.tde.research_count = 0 end -- NEW
    if storage.tde.wave_count == nil then storage.tde.wave_count = 0 end
    if not storage.tde.active_waves then storage.tde.active_waves = {} end
    if not storage.tde.master_ammo_chests then storage.tde.master_ammo_chests = {} end
    if not storage.tde.global_turrets then storage.tde.global_turrets = {} end
    if not storage.tde.infinite_resources then storage.tde.infinite_resources = {} end
    if not storage.tde.nest_territories then storage.tde.nest_territories = {} end
    if storage.tde.world_setup_complete == nil then storage.tde.world_setup_complete = false end
    if storage.tde.mac_needs_reconstruction == nil then storage.tde.mac_needs_reconstruction = false end
    if storage.tde.base_heart == nil then storage.tde.base_heart = nil end
    if storage.tde.game_over == nil then storage.tde.game_over = false end
    if not storage.tde.next_wave_tick then 
      storage.tde.next_wave_tick = game.tick + 1800 
    end
  end
  
  -- CRÍTICO: Marcar que necesita reconstruir MAC, pero no hacerlo ahora
  storage.tde.mac_needs_reconstruction = true
  log("TDE: Marked MAC system for reconstruction on next game tick")
  
  -- Try to find existing base heart
  find_base_heart()
  
  -- Mostrar información de la partida cargada
  if storage.tde then
    game.print("Tower Defense Evolution: Loaded existing save", {r = 0, g = 1, b = 1})
    game.print(string.format("Progress: %d kills | Wave: %d", 
      storage.tde.total_kills or 0, storage.tde.wave_count or 0), {r = 1, g = 1, b = 0})
    
    -- Mostrar tiempo hasta próxima wave
    if storage.tde.next_wave_tick then
      local time_left = storage.tde.next_wave_tick - game.tick
      if time_left > 0 then
        local minutes = math.floor(time_left / 3600)
        local seconds = math.floor((time_left % 3600) / 60)
        game.print(string.format("Next wave in: %d:%02d", minutes, seconds), {r = 0, g = 1, b = 1})
      else
        game.print("Wave incoming soon!", {r = 1, g = 0.8, b = 0})
      end
    end
    
    game.print("Rebuilding MAC system...", {r = 1, g = 1, b = 0})
  end
  for _, player in pairs(game.players) do
    create_tde_info_gui(player)
  end
end)

script.on_event(defines.events.on_research_started, function(event)
  local research = event.research  -- This is a LuaTechnology object
  local research_name = research.name

  local success, message = unlock_technology_with_dynamic_cost(research_name)
  game.print(message)
end)

-- === ON BITER DEATH: ADD TOKENS TO BASE HEART ===
script.on_event(defines.events.on_entity_died, function(event)
  local entity = event.entity
  if not entity or not entity.valid then return end
  
  -- Handle different enemy death types
  if entity.force.name == "enemy" then
    storage.tde.total_kills = (storage.tde.total_kills or 0) + 1
    if entity.type == "unit" then
      -- Regular biter/spitter kill = 1 token
      add_tokens_to_base_heart(1)
    elseif entity.name == "biter-spawner" or entity.name == "spitter-spawner" then
      -- Spawner kill = 10 tokens
      add_tokens_to_base_heart(10)
      game.print("Spawner destroyed! +10 research tokens!", {r = 0, g = 1, b = 0})
    end
  end
  
  -- Handle boss kills with special value
  if entity.unit_number and storage.tde.nest_territories[entity.unit_number] then
    local nest_data = storage.tde.nest_territories[entity.unit_number]
    if nest_data.is_boss then
      add_tokens_to_base_heart(nest_data.kill_value)
      game.print(string.format("BOSS DEFEATED! +%d research tokens!", 
        nest_data.kill_value), {r = 1, g = 0, b = 1})
      storage.tde.nest_territories[entity.unit_number] = nil
      storage.tde.total_boss_kills = (storage.tde.total_boss_kills or 0) + 1
    end
  end

  
  if settings.global["tde-master-chest-enabled"].value then
    -- Handle Master Ammo Chest system
    if entity.name == "master-ammo-chest" then
      unregister_master_ammo_chest(entity)
    elseif is_turret(entity) then
      unregister_turret(entity)
    end
  end
  
  -- Handle Base Heart destruction
  if entity.name == "tde-base-heart" then
    storage.tde.base_heart = nil
    check_base_heart_destroyed()
  end
end)

script.on_event(defines.events.on_player_created, function(event)
  local player = game.get_player(event.player_index)
  if player then
    show_welcome_messages(player)
  end
  if player then
    create_tde_info_gui(player)
  end
end)

-- Add GUI click handler
script.on_event(defines.events.on_gui_click, function(event)
  handle_tde_gui_click(event)
end)

-- ARREGLADO: Main game loop - RECONSTRUCCIÓN MAC AUTOMÁTICA Y ROBUSTA + MONITOREO
script.on_nth_tick(60, function(event) 
  --monitor_wave_count_changes("main_loop_start")
  if event.tick % 60 == 0 then
    for _, player in pairs(game.connected_players) do
      update_tde_info_gui(player)
    end
  end
  
  -- CRÍTICO: Verificar que global existe
  if not storage or not storage.tde then
    log("TDE: CRITICAL - Global missing in main loop, calling initialize_tde_global()")
    monitor_wave_count_changes("before_init")
    initialize_tde_global()
    monitor_wave_count_changes("after_init")
    return
  end
  
  -- Check if game is over
  if storage.tde.game_over then
    return  -- Stop all processing if game is over
  end
  
  -- Check base heart status
  check_base_heart_destroyed()
  if storage.tde.game_over then

    return
  end
  
  -- Regenerate base heart HP
  regenerate_base_heart_hp()
  
  -- Verificación de integridad
  if not storage.tde.wave_count then
    log("TDE: CRITICAL - wave_count is nil, setting to 0")
    storage.tde.wave_count = 0
  end
  
  --monitor_wave_count_changes("after_integrity_check")
  
  -- CRÍTICO: Reconstruir MAC system si está marcado para reconstrucción (PRIORITARIO)
  if storage.tde.mac_needs_reconstruction then
    log("TDE: Executing automatic MAC reconstruction...")
    reconstruct_mac_system_robust()
    storage.tde.mac_needs_reconstruction = false
    log("TDE: MAC reconstruction completed")
    
    -- Mostrar mensaje al jugador
    game.print("MAC system automatically rebuilt!", {r = 0, g = 1, b = 0})
    return -- Salir para procesar en el siguiente tick
  end
  
  -- Handle delayed world setup on first run (solo para partidas nuevas con wave_count = 0)
  if not storage.tde.world_setup_complete and storage.tde.wave_count == 0 then
    local success, error_msg = pcall(function()
      setup_tower_defense_world()
      storage.tde.world_setup_complete = true
    end)
    
    if success then
      game.print("World setup completed successfully!")
    else
      log("Error during world setup: " .. tostring(error_msg))
      game.print("Warning: World setup encountered errors. Check log for details.")
      storage.tde.world_setup_complete = true -- Prevent infinite retries
    end
    return
  end
  
  -- NUEVO: Verificación automática de integridad MAC cada 2 minutos
  if game.tick % 7200 == 0 then
    verify_and_fix_mac_system()
  end
  
  --monitor_wave_count_changes("before_game_operations")
  
  -- Don't process waves if game just started (before first wave should spawn)
  if game.tick < 1800 then
    return
  end
  
  -- Normal game operations
  check_wave_schedule()
  manage_active_waves()
  if settings.global["tde-master-chest-enabled"].value then
    process_ammo_distribution()
  
    -- Balancear munición entre torretas cada 30 segundos
    if game.tick % 1800 == 0 then
      balance_ammo_between_turrets()
    end
  end
  
  -- Expand nest field every 10 minutes (reduced frequency to prevent crashes)
  if game.tick % 36000 == 0 and storage.tde.wave_count > 0 then
    expand_nest_field()
  end
  
  -- Periodically ensure spawners are active
  if game.tick % 1800 == 0 then -- Every 30 seconds
    ensure_spawners_active()
  end
  
  -- Calculate wave state from game tick
  local calculated_wave, calculated_next_wave_tick = tde_calculate_wave_state()
  
  -- Only update if the calculated wave is different to avoid resetting mid-wave
  if calculated_wave ~= storage.tde.wave_count then
    log("TDE: Wave count updated from " .. storage.tde.wave_count .. " to " .. calculated_wave)
    storage.tde.wave_count = calculated_wave
  end
  storage.tde.next_wave_tick = calculated_next_wave_tick

  --monitor_wave_count_changes("main_loop_end")

  if game.tick % 600 == 0 then
    local tech_t = game.forces.player.current_research
    if (tech_t and not tech_t.researched) then
      unlock_technology_with_dynamic_cost(tech_t.name)
    end
  end
end)
-- ===== ENHANCED MASTER AMMO CHEST SYSTEM - FACTORIO 2.0 COMPATIBLE =====
-- FIXED: Enhanced robot building event handlers for Factorio 2.0
script.on_event(defines.events.on_built_entity, function(event)
  if settings.global["tde-master-chest-enabled"].value then
    -- FIXED: Use the new event structure for 2.0
    local entity = event.entity or event.created_entity
    if not entity or not entity.valid then return end
    
    if entity.name == "master-ammo-chest" then
      register_master_ammo_chest(entity)
    elseif is_turret(entity) then
      register_turret(entity)
    end
  end
end)

-- FIXED: Updated robot built entity event for Factorio 2.0 compatibility
script.on_event(defines.events.on_robot_built_entity, function(event)
  if settings.global["tde-master-chest-enabled"].value then
    -- CRITICAL FIX: Properly handle the robot built entity event
    local entity = event.entity or event.created_entity
    if not entity or not entity.valid then 
      log("TDE: Invalid entity in on_robot_built_entity event")
      return 
    end
    
    log("TDE: Robot built entity: " .. (entity.name or "unknown") .. " at " .. entity.position.x .. "," .. entity.position.y)
    
    if entity.name == "master-ammo-chest" then
      register_master_ammo_chest(entity)
      log("TDE: Master Ammo Chest registered via robot building")
    elseif is_turret(entity) then
      register_turret(entity)
      log("TDE: Turret registered via robot building: " .. entity.name)
    end
  end
end)

-- ENHANCED: Add additional robot building events that might be relevant in 2.0
script.on_event(defines.events.on_space_platform_built_entity, function(event)
  if settings.global["tde-master-chest-enabled"].value then
    local entity = event.entity or event.created_entity
    if not entity or not entity.valid then return end
    
    log("TDE: Space platform built entity: " .. (entity.name or "unknown"))
    
    if entity.name == "master-ammo-chest" then
      register_master_ammo_chest(entity)
      log("TDE: Master Ammo Chest registered via space platform building")
    elseif is_turret(entity) then
      register_turret(entity)
      log("TDE: Turret registered via space platform building: " .. entity.name)
    end
  end
end)

-- ENHANCED: Add ghost revived event (when robots revive ghosts)
script.on_event(defines.events.on_pre_ghost_deconstructed, function(event)
  if settings.global["tde-master-chest-enabled"].value then
    local ghost = event.ghost
    if not ghost or not ghost.valid then return end
    
    -- If it's being revived (not deconstructed), we'll get the built event
    if ghost.name == "entity-ghost" then
      local ghost_name = ghost.ghost_name
      if ghost_name == "master-ammo-chest" or is_turret_name(ghost_name) then
        log("TDE: Ghost being revived: " .. ghost_name)
      end
    end
  end
end)

-- Helper function to check if an entity name corresponds to a turret
function is_turret_name(entity_name)
  if not entity_name then return false end
  
  -- Check common turret names
  local turret_names = {
    ["gun-turret"] = true,
    ["laser-turret"] = true,
    ["flamethrower-turret"] = true,
    ["artillery-turret"] = true,
  }
  
  return turret_names[entity_name] or false
end

-- ENHANCED: Alternative approach using entity cloned event (for upgraded entities)
script.on_event(defines.events.on_entity_cloned, function(event)
  if settings.global["tde-master-chest-enabled"].value then
    local entity = event.destination
    if not entity or not entity.valid then return end
    
    if entity.name == "master-ammo-chest" then
      register_master_ammo_chest(entity)
      log("TDE: Master Ammo Chest registered via entity cloning")
    elseif is_turret(entity) then
      register_turret(entity)
      log("TDE: Turret registered via entity cloning: " .. entity.name)
    end
  end
end)

-- DEBUGGING: Add comprehensive entity tracking for troubleshooting
script.on_event(defines.events.script_raised_built, function(event)
  if settings.global["tde-master-chest-enabled"].value and settings.global["tde-show-ammo-messages"].value then
    local entity = event.entity
    if not entity or not entity.valid then return end
    
    if entity.name == "master-ammo-chest" then
      register_master_ammo_chest(entity)
      log("TDE: Master Ammo Chest registered via script_raised_built")
    elseif is_turret(entity) then
      register_turret(entity)
      log("TDE: Turret registered via script_raised_built: " .. entity.name)
    end
  end
end)

script.on_event(defines.events.script_raised_revive, function(event)
  if settings.global["tde-master-chest-enabled"].value and settings.global["tde-show-ammo-messages"].value then
    local entity = event.entity
    if not entity or not entity.valid then return end
    
    if entity.name == "master-ammo-chest" then
      register_master_ammo_chest(entity)
      log("TDE: Master Ammo Chest registered via script_raised_revive")
    elseif is_turret(entity) then
      register_turret(entity)
      log("TDE: Turret registered via script_raised_revive: " .. entity.name)
    end
  end
end)

-- ===== ENHANCED NEST ACTIVATION SYSTEM =====
-- FIXED: Update entity damaged event handler to validate targets properly
script.on_event(defines.events.on_entity_damaged, function(event)
  if not event.entity or not event.entity.valid then return end
  
  -- FIXED: Validate the entity has health before processing
  if not event.entity.health or event.entity.health <= 0 then 
    return  -- Skip entities without health or with 0 health
  end
  
  if event.entity.name == "biter-spawner" or event.entity.name == "spitter-spawner" then
    local spawner_id = event.entity.unit_number
    if spawner_id and storage.tde and storage.tde.nest_territories then
      local nest_data = storage.tde.nest_territories[spawner_id]
      
      if nest_data and nest_data.is_defensive then
        -- CRITICAL FIX: Validate the cause (attacker) before passing to activate_defensive_nest
        local valid_attacker = nil
        if event.cause and event.cause.valid and event.cause.health and event.cause.health > 0 then
          valid_attacker = event.cause
        end
        
        activate_defensive_nest(nest_data, valid_attacker)
      end
    end
  end
end)

-- ===== DISABLE POLLUTION ATTACKS =====
script.on_event(defines.events.on_chunk_generated, function(event)
  -- Find all spawners and make them active but not pollution responsive
  local spawners = event.surface.find_entities_filtered({
    area = event.area,
    name = {"biter-spawner", "spitter-spawner"}
  })
  
  for _, spawner in pairs(spawners) do
    spawner.active = true -- Keep spawners active for natural spawning
    
    -- Register in our system
    if spawner.unit_number and storage.tde and storage.tde.nest_territories then
      storage.tde.nest_territories[spawner.unit_number] = {
        spawner = spawner,
        position = spawner.position,
        distance = math.sqrt(spawner.position.x^2 + spawner.position.y^2),
        is_defensive = true,
        spawn_cooldown = 0
      }
    end
  end
end)

script.on_event(defines.events.on_player_joined_game, function(event)
  local player = game.get_player(event.player_index)
  if player then
    multiplayer.handle_player_join(player)
  end
end)

script.on_event(defines.events.on_player_left_game, function(event)
  local player = game.get_player(event.player_index)
  if player then
    multiplayer.handle_player_leave(player)
  end
end)

-- ===== NEW: SPACE AGE DLC EVENT HANDLERS =====
script.on_event(defines.events.on_player_changed_surface, function(event)
  local player = game.get_player(event.player_index)
  if player then
    local old_surface = event.old_surface
    local new_surface = event.new_surface
    multiplayer.handle_surface_change(player, old_surface, new_surface)
  end
end)

-- ===== NEW: ENHANCED WAVE SYSTEM INTEGRATION =====
-- Override the wave composition functions to use Space Age enemies
local original_calculate_wave_composition = calculate_wave_composition
local original_spawn_boss_wave = spawn_boss_wave

-- Enhanced wave composition with planet enemies
function calculate_wave_composition(base_count, evolution)
  if space_age.is_space_age_available() then
    return space_age.calculate_enhanced_wave_composition(base_count, evolution)
  else
    return original_calculate_wave_composition(base_count, evolution)
  end
end

-- Enhanced boss wave with planet bosses
function spawn_boss_wave()
  if space_age.is_space_age_available() then
    -- Use enhanced boss composition
    local boss_composition, planet_data = space_age.calculate_enhanced_boss_composition()
    local boss_kills_value = math.floor((storage.tde.wave_count / storage.tde.BOSS_EVERY) * 1000)
    
    local spawn_locations = find_wave_spawn_locations()
    
    if not spawn_locations or #spawn_locations == 0 then
      log("TDE: No valid spawn locations found for boss wave, skipping")
      game.print("Warning: No valid spawn locations found for boss wave!", {r = 1, g = 0.5, b = 0})
      return
    end
    
    local boss_spawn = spawn_locations[math.random(#spawn_locations)]
    
    if boss_spawn then
      -- Spawn boss with planet-specific announcement
      create_attack_group(boss_spawn.position, boss_composition, true, boss_spawn, boss_kills_value)
      
      -- Announce planet-specific boss wave
      space_age.announce_planet_wave(storage.tde.wave_count, true, planet_data)
      
      game.print(string.format("BOSS WAVE %d! %s boss worth %d research tokens!", 
        storage.tde.wave_count, planet_data and planet_data.name or "Behemoth", boss_kills_value), {r = 1, g = 0, b = 1})
    else
      log("TDE: Boss spawn location is nil, boss wave spawn failed")
    end
  else
    -- Use original boss wave function
    original_spawn_boss_wave()
  end
end

-- ===== NEW: PERIODIC MULTIPLAYER SYNC =====
script.on_nth_tick(1800, function(event) -- Every 30 seconds (reduced from 5 seconds)
  multiplayer.sync_game_state_to_all_players()
end)

log("TDE: Multiplayer and Space Age DLC integration loaded successfully!")
