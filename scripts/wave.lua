-- ===== RESTORE tde_calculate_wave_state FUNCTION =====
function tde_calculate_wave_state()
    -- Calculates the current wave number and next wave tick based on game tick and interval
    local current_tick = game.tick
    
    -- First wave starts at tick 1800 (30 seconds after game start)
    if current_tick < 1800 then
      return 0, 1800  -- No wave yet, next wave at 1800
    end
    
    -- Calculate which wave we should be on
    local wave = math.floor((current_tick - 1800) / WAVE_INTERVAL) + 1
    local next_wave_tick = 1800 + wave * WAVE_INTERVAL
    
    return wave, next_wave_tick
end

-- ===== WAVE SYSTEM =====
function schedule_first_wave()
    storage.tde.next_wave_tick = game.tick + 1800 -- 30 seconds initial delay
    game.print("First wave incoming in 30 seconds!", {r = 1, g = 0.8, b = 0})
  end

-- AÑADIR función nueva que monitorea cambios en wave_count:
function monitor_wave_count_changes(location)
    if storage and storage.tde then
      log("TDE: Wave count check at " .. location .. " - Current: " .. tostring(storage.tde.wave_count))
    else
      log("TDE: Wave count check at " .. location .. " - storage.tde is nil!")
    end
end

function check_wave_schedule()
    -- Use calculated next_wave_tick
    if game.tick >= storage.tde.next_wave_tick then
      spawn_wave()
      -- No need to schedule_next_wave, as it's calculated from tick
    end
end
  
function spawn_wave()
    -- Use calculated wave_count
    local wave_num = storage.tde.wave_count
    log("TDE: spawn_wave() called - Wave: " .. tostring(wave_num))
    
    -- Don't spawn waves if wave count is 0 or less
    if wave_num <= 0 then
      log("TDE: Wave count is 0 or negative, skipping wave spawn")
      return
    end
    
    game.print("Wave " .. wave_num .. " incoming!", {r = 1, g = 0.8, b = 0})
  
    local is_boss_wave = (wave_num % storage.tde.BOSS_EVERY == 0 and wave_num > 0)
  
    if is_boss_wave then
      --spawn_normal_wave()
      spawn_boss_wave()
    else
      spawn_normal_wave()
    end
end
  
function spawn_normal_wave()
    -- Don't spawn if wave count is invalid
    if not storage.tde.wave_count or storage.tde.wave_count <= 0 then
      log("TDE: Invalid wave count in spawn_normal_wave: " .. tostring(storage.tde.wave_count))
      return
    end
    
    -- BALANCEADO: Empezar con waves pequeñas y escalar gradualmente
    local wave_size
    if storage.tde.wave_count == 1 then
      wave_size = 5  -- Primera wave: solo 5 biters
    elseif storage.tde.wave_count <= 5 then
      wave_size = 5 + storage.tde.wave_count * 3  -- Waves 2-5: 8, 11, 14, 17, 20
    else
      wave_size = 20 + (storage.tde.wave_count - 5) * 2  -- Waves 6+: escalado normal
    end
    
    local evolution = get_enemy_evolution()
    
    -- ENHANCED: Use enhanced composition if Space Age is available
    local composition
    if space_age and space_age.is_space_age_available then
      composition = space_age.calculate_enhanced_wave_composition(wave_size, evolution)
    else
      composition = calculate_wave_composition(wave_size, evolution)
    end
    
    local spawn_locations = find_wave_spawn_locations()
    
    -- CRITICAL FIX: Check if spawn_locations is empty
    if not spawn_locations or #spawn_locations == 0 then
      log("TDE: No valid spawn locations found, skipping wave")
      game.print("Warning: No valid spawn locations found for wave!", {r = 1, g = 0.5, b = 0})
      return
    end
    
    -- CORREGIDO: Seleccionar solo UNA dirección para la wave, no todas
    local selected_spawn = spawn_locations[math.random(#spawn_locations)]
    
    if selected_spawn then
      create_attack_group(selected_spawn.position, composition, false, selected_spawn)
      
      -- ENHANCED: Check for planet-specific enemies in composition
      local planet_enemies = {}
      for enemy_name, count in pairs(composition) do
        if enemy_name:find("vulkanus") or enemy_name:find("pentapod") or enemy_name:find("stomper") or enemy_name:find("demolisher") then
          table.insert(planet_enemies, enemy_name)
        end
      end
      
      if #planet_enemies > 0 then
        game.print(string.format("Wave %d incoming! (%d enemies, including %s!)", 
          storage.tde.wave_count, wave_size, table.concat(planet_enemies, ", ")), {r = 1, g = 0, b = 0})
      else
        game.print(string.format("Wave %d incoming! (%d biters)", 
          storage.tde.wave_count, wave_size), {r = 1, g = 0, b = 0})
      end
    else
      log("TDE: Selected spawn is nil, wave spawn failed")
    end
end
  
function spawn_boss_wave()
    -- Don't spawn if wave count is invalid
    if not storage.tde.wave_count or storage.tde.wave_count <= 0 then
      log("TDE: Invalid wave count in spawn_boss_wave: " .. tostring(storage.tde.wave_count))
      return
    end
    
    local boss_kills_value = math.floor((storage.tde.wave_count / storage.tde.BOSS_EVERY) * 1000) + 1000
    
    -- ENHANCED: Use Space Age boss composition if available
    local boss_composition = {}
    local planet_data = nil
    
    if space_age and space_age.is_space_age_available() then
        boss_composition, planet_data = space_age.calculate_enhanced_boss_composition()
    else
        -- Fallback to regular behemoth boss
        boss_composition = {["behemoth-biter"] = 1}
    end
    
    local spawn_locations = find_wave_spawn_locations()
    
    -- CRITICAL FIX: Check if spawn_locations is empty
    if not spawn_locations or #spawn_locations == 0 then
      log("TDE: No valid spawn locations found for boss wave, skipping")
      game.print("Warning: No valid spawn locations found for boss wave!", {r = 1, g = 0.5, b = 0})
      return
    end
    
    -- CORREGIDO: Boss desde UNA dirección específica
    local boss_spawn = spawn_locations[math.random(#spawn_locations)]
    
    if boss_spawn then
      -- Spawn ONLY the boss (no escorts)
      create_attack_group(boss_spawn.position, boss_composition, true, boss_spawn, boss_kills_value)
      
      -- Announce the boss wave
      local boss_name = "Behemoth"
      if planet_data then
        boss_name = planet_data.name
      end
      
      game.print(string.format("BOSS WAVE %d! %s boss worth %d research tokens!", 
        storage.tde.wave_count, boss_name, boss_kills_value), {r = 1, g = 0, b = 1})
      
    else
      log("TDE: Boss spawn location is nil, boss wave spawn failed")
    end
end
  
function calculate_wave_composition(base_count, evolution)
    local composition = {}
    
    if evolution < 0.2 then
      composition["small-biter"] = math.floor(base_count * 0.7)
      composition["small-spitter"] = math.floor(base_count * 0.3)
    elseif evolution < 0.5 then
      composition["small-biter"] = math.floor(base_count * 0.3)
      composition["medium-biter"] = math.floor(base_count * 0.4)
      composition["medium-spitter"] = math.floor(base_count * 0.3)
    elseif evolution < 0.8 then
      composition["medium-biter"] = math.floor(base_count * 0.2)
      composition["big-biter"] = math.floor(base_count * 0.5)
      composition["big-spitter"] = math.floor(base_count * 0.3)
    else
      composition["big-biter"] = math.floor(base_count * 0.3)
      composition["behemoth-biter"] = math.floor(base_count * 0.4)
      composition["behemoth-spitter"] = math.floor(base_count * 0.3)
    end
    
    return composition
end
  
function find_wave_spawn_locations()
    local surface = game.surfaces[1]
    if not surface or not surface.valid then
      log("TDE: Invalid surface in find_wave_spawn_locations")
      return {}
    end
    
    -- Use a more conservative spawn distance for early waves
    local base_spawn_distance = 250  -- Reduced from 450
    local spawn_distance = base_spawn_distance + (storage.tde.wave_count or 0) * 2  -- Reduced multiplier
    local locations = {}
    
    -- Direcciones con nombres y flechas para el chat
    local directions = {
      {angle = 0, name = "East", arrow = "→", direction = "east"},           -- Este  
      {angle = math.pi/2, name = "South", arrow = "↓", direction = "south"},    -- Sur
      {angle = math.pi, name = "West", arrow = "←", direction = "west"},     -- Oeste
      {angle = 3*math.pi/2, name = "North", arrow = "↑", direction = "north"} -- Norte
    }
    
    for _, dir_info in pairs(directions) do
      local spawn_point = {
        x = math.cos(dir_info.angle) * spawn_distance,
        y = math.sin(dir_info.angle) * spawn_distance
      }
      
      -- Try multiple search attempts with increasing search radius
      local valid_position = nil
      for search_radius = 30, 120, 30 do
        valid_position = surface.find_non_colliding_position("big-biter", spawn_point, search_radius, 2)
        if valid_position then
          break
        end
      end
      
      -- Fallback: if still no position found, use a simpler approach
      if not valid_position then
        -- Try with small-biter (smaller collision box)
        valid_position = surface.find_non_colliding_position("small-biter", spawn_point, 150, 3)
      end
      
      -- Final fallback: just use the spawn point directly
      if not valid_position then
        valid_position = spawn_point
        log("TDE: Using fallback spawn position at " .. spawn_point.x .. "," .. spawn_point.y)
      end
      
      if valid_position then
        table.insert(locations, {
          position = valid_position,
          direction = dir_info.direction,
          name = dir_info.name,
          arrow = dir_info.arrow
        })
      end
    end
    
    --log("TDE: Found " .. #locations .. " spawn locations")
    return locations
end

function manage_active_waves()
    local active_waves = {}
    
    for _, wave_data in pairs(storage.tde.active_waves) do
      if wave_data.group.valid and #wave_data.group.members > 0 then
        table.insert(active_waves, wave_data)
      else
        if wave_data.group.valid and #wave_data.group.members == 0 then
          local wave_type = wave_data.is_boss and "BOSS " or ""
          game.print(string.format("%sWave %d defeated!", wave_type, wave_data.wave_number), {r = 0, g = 1, b = 0})
        end
      end
    end
    
    storage.tde.active_waves = active_waves
end