-- ===== DEBUG COMMANDS =====
commands.add_command("tde-add-tokens", "Add research tokens for testing (number)", function(command)
    local amount = tonumber(command.parameter) or 100
    add_tokens_to_base_heart(amount)
    game.print(string.format("Added %d research tokens to Base Heart.", amount))
end)
  
commands.add_command("tde-wave", "Spawn test wave", function(command)
    spawn_wave()
end)
  
commands.add_command("tde-status", "Show current status", function(command)
    local next_wave_seconds = math.floor((storage.tde.next_wave_tick - game.tick) / 60)
    local next_wave_minutes = math.floor(next_wave_seconds / 60)
    
    game.print("=== TOWER DEFENSE EVOLUTION STATUS ===", {r = 0, g = 1, b = 1})
    game.print(string.format("Wave: %d | Next: %d:%02d", 
      storage.tde.wave_count,
      next_wave_minutes, next_wave_seconds % 60))
    
    -- Show research progress with dynamic costs
    local research_count = storage.tde.research_count or 0
    local next_cost = get_next_research_cost()
    game.print(string.format("Research Progress: %d technologies researched | Next cost: %d tokens", 
      research_count, next_cost), {r = 0, g = 1, b = 1})
    
    -- Show base heart status
    local base_heart = find_base_heart()
    if base_heart and base_heart.valid then
      local hp_percent = math.floor((base_heart.health / BASE_HEART_MAX_HP) * 100)
      game.print(string.format("Base Heart: %d%% HP (%d/%d)", 
        hp_percent, math.floor(base_heart.health), BASE_HEART_MAX_HP))
      
      -- Show tokens in base heart
      local inventory = base_heart.get_inventory(defines.inventory.chest)
      if inventory then
        local token_count = inventory.get_item_count("tde-dead-biter")
        game.print(string.format("Research tokens available: %d", token_count))
      end
    else
      game.print("Base Heart: NOT FOUND! (Game Over)", {r = 1, g = 0, b = 0})
    end
    
    -- Información detallada del estado
    game.print(string.format("Game tick: %d | Next wave tick: %d", 
      game.tick, storage.tde.next_wave_tick))
    
    game.print(string.format("Active waves: %d | World setup: %s", 
      #storage.tde.active_waves, storage.tde.world_setup_complete and "Complete" or "Pending"))
      
    -- Show some sample techs with current costs
    local sample_techs = {"automation", "electronics", "logistics", "military", "gun-turret", "laser-turrets"}
    game.print("Sample technologies (all cost " .. next_cost .. " tokens):")
    for _, tech_name in pairs(sample_techs) do
      local tech = game.forces.player.technologies[tech_name]
      if tech then
        local status = tech.researched and "RESEARCHED" or "AVAILABLE"
        game.print(string.format("  %s: %s", tech_name, status))
      end
    end
    
    -- Show cost progression info with current settings
    local config = get_research_settings()
    game.print(string.format("💡 Cost scaling: +%d until %d, +%d until %d, +%d until %d, then +%d", 
      config.increment_1, config.threshold_1, config.increment_2, config.threshold_2, 
      config.increment_3, config.threshold_3, config.increment_final), {r = 1, g = 1, b = 0})
end)
  
commands.add_command("tde-tech", "Unlock technology by name", function(command)
    local tech_name = command.parameter
    if not tech_name then
      game.print("Usage: /tde-tech <technology-name>")
      return
    end
    
    local success, message = unlock_technology_with_dynamic_cost(tech_name)
    
    if success then
      game.print(message, {r = 0, g = 1, b = 0})
    else
      game.print(message, {r = 1, g = 0.5, b = 0})
    end
end)
  
commands.add_command("tde-tech-debug", "Debug technology system", function(command)
    game.print("=== DYNAMIC TECHNOLOGY SYSTEM DEBUG ===")
    
    local base_heart = find_base_heart()
    local available_tokens = 0
    
    if base_heart and base_heart.valid then
      local inventory = base_heart.get_inventory(defines.inventory.chest)
      if inventory then
        available_tokens = inventory.get_item_count("tde-dead-biter")
      end
    end
    
    local research_count = storage.tde.research_count or 0
    local next_cost = get_next_research_cost()
    
    game.print("Available tokens: " .. available_tokens)
    game.print("Research count: " .. research_count)
    game.print("Next research cost: " .. next_cost)
    
    -- Show cost progression examples
    game.print("=== COST PROGRESSION EXAMPLES ===")
    for i = 0, 10 do
      local cost = calculate_dynamic_research_cost(i)
      game.print(string.format("Research #%d: %d tokens", i + 1, cost))
    end
    
    -- Show bracket examples
    local config = get_research_settings()
    game.print("=== COST BRACKETS ===")
    game.print(string.format("Research 1-X: +%d tokens each until %d", config.increment_1, config.threshold_1))
    game.print(string.format("Research at %d+: +%d tokens each until %d", config.threshold_1, config.increment_2, config.threshold_2))
    game.print(string.format("Research at %d+: +%d tokens each until %d", config.threshold_2, config.increment_3, config.threshold_3))
    game.print(string.format("Research at %d+: +%d tokens each permanently", config.threshold_3, config.increment_final))
    
    local test_techs = {"automation", "electronics", "logistics", "military", "gun-turret", "laser-turrets"}
    
    game.print("=== SAMPLE TECHNOLOGIES ===")
    for _, tech_name in pairs(test_techs) do
      local tech = game.forces.player.technologies[tech_name]
      if tech then
        local status = tech.researched and "RESEARCHED" or "AVAILABLE"
        local affordable = available_tokens >= next_cost and "YES" or "NO"
        local prereqs_met = true
        
        for _, prereq in pairs(tech.prerequisites) do
          if not prereq.researched then
            prereqs_met = false
            break
          end
        end
        
        game.print(string.format("  %s: %s | Can afford: %s | Prereqs: %s", 
          tech_name, status, affordable, prereqs_met and "YES" or "NO"))
      else
        game.print("  " .. tech_name .. ": NOT FOUND")
      end
    end
    
    game.print("All technologies now use dynamic costs! Open Research tab to see all available technologies!")
end)
  
  -- Additional debug commands...
commands.add_command("tde-nest-test", "Test nest defense system", function(command)
    local player = game.players[1]
    if not player then 
      game.print("No player found")
      return 
    end
    
    -- Find nearest spawner
    local spawners = player.surface.find_entities_filtered({
      name = {"biter-spawner", "spitter-spawner"},
      position = player.position,
      radius = 300
    })
    
    if #spawners > 0 then
      local spawner = spawners[1]
      local spawner_id = spawner.unit_number
      if spawner_id and storage.tde.nest_territories[spawner_id] then
        local nest_data = storage.tde.nest_territories[spawner_id]
        
        -- CORREGIDO: Verificar que nest_data tiene toda la información necesaria
        if not nest_data.spawner then
          nest_data.spawner = spawner
        end
        if not nest_data.position then
          nest_data.position = spawner.position
        end
        
        game.print("Activating nest defense test...")
        log("Nest test: spawner valid=" .. tostring(nest_data.spawner and nest_data.spawner.valid))
        
        activate_defensive_nest(nest_data, player.character)
        game.print("Activated nearest nest defense!")
      else
        game.print("Nearest spawner not registered in nest system")
        log("Spawner ID: " .. tostring(spawner_id) .. ", registered: " .. tostring(storage.tde.nest_territories[spawner_id] ~= nil))
      end
    else
      game.print("No spawners found nearby")
    end
end)
  
commands.add_command("tde-spawners", "Check spawner status", function(command)
    if not game.surfaces[1] then return end
    
    local spawners = game.surfaces[1].find_entities_filtered({
      name = {"biter-spawner", "spitter-spawner"}
    })
    
    local active_count = 0
    local inactive_count = 0
    
    for _, spawner in pairs(spawners) do
      if spawner.active then
        active_count = active_count + 1
      else
        inactive_count = inactive_count + 1
        spawner.active = true -- Reactivate
      end
    end
    
    game.print(string.format("Spawners: %d active, %d reactivated, %d total", 
      active_count, inactive_count, #spawners))
end)
  
commands.add_command("tde-base-heart", "Base Heart management commands", function(command)
    local param = command.parameter or ""
    
    if param == "create" then
      if create_base_heart() then
        game.print("Base Heart created successfully!", {r = 0, g = 1, b = 0})
      else
        game.print("Failed to create Base Heart", {r = 1, g = 0, b = 0})
      end
    elseif param == "find" then
      local base_heart = find_base_heart()
      if base_heart and base_heart.valid then
        game.print(string.format("Base Heart found at (%d, %d) with %d/%d HP", 
          base_heart.position.x, base_heart.position.y, 
          math.floor(base_heart.health), BASE_HEART_MAX_HP), {r = 0, g = 1, b = 0})
      else
        game.print("Base Heart not found!", {r = 1, g = 0, b = 0})
      end
    elseif param == "heal" then
      local base_heart = find_base_heart()
      if base_heart and base_heart.valid then
        base_heart.health = BASE_HEART_MAX_HP
        game.print("Base Heart fully healed!", {r = 0, g = 1, b = 0})
      else
        game.print("Base Heart not found!", {r = 1, g = 0, b = 0})
      end
    else
      game.print("Usage: /tde-base-heart <create|find|heal>")
    end
end)
  
commands.add_command("tde-save-debug", "Debug save/load system", function(command)
    game.print("=== SAVE/LOAD DEBUG v13 ===", {r = 1, g = 1, b = 0})
    game.print("Global structure exists: " .. tostring(storage ~= nil))
    game.print("TDE data exists: " .. tostring(storage and storage.tde ~= nil))
    
    if storage and storage.tde then
      game.print("--- CURRENT DATA ---")
      game.print("Wave count: " .. tostring(storage.tde.wave_count))
      game.print("Research count: " .. tostring(storage.tde.research_count))
      game.print("Next wave tick: " .. tostring(storage.tde.next_wave_tick))
      game.print("Current game tick: " .. tostring(game.tick))
      game.print("Time to next wave: " .. tostring(storage.tde.next_wave_tick - game.tick) .. " ticks")
      game.print("World setup complete: " .. tostring(storage.tde.world_setup_complete))
      game.print("Technologies unlocked: " .. tostring(storage.tde.technologies_unlocked and table_size(storage.tde.technologies_unlocked) or 0))
      game.print("Master ammo chests: " .. tostring(storage.tde.master_ammo_chests and table_size(storage.tde.master_ammo_chests) or 0))
      game.print("Global turrets: " .. tostring(storage.tde.global_turrets and table_size(storage.tde.global_turrets) or 0))
      game.print("Active waves: " .. tostring(#storage.tde.active_waves))
      game.print("Game over: " .. tostring(storage.tde.game_over))
      
      -- Base heart status
      local base_heart = find_base_heart()
      if base_heart and base_heart.valid then
        game.print("Base Heart: FOUND at " .. base_heart.position.x .. "," .. base_heart.position.y)
        game.print("Base Heart HP: " .. math.floor(base_heart.health) .. "/" .. BASE_HEART_MAX_HP)
      else
        game.print("Base Heart: NOT FOUND")
      end
    else
      game.print("ERROR: No TDE data found!", {r = 1, g = 0, b = 0})
    end
end)
  
commands.add_command("tde-mac-rebuild", "Manually rebuild MAC system", function(command)
    game.print("Rebuilding Master Ammo Chest system...", {r = 1, g = 1, b = 0})
    reconstruct_mac_system_robust()
    game.print("MAC system rebuild complete!", {r = 0, g = 1, b = 0})
    
    -- Mostrar estadísticas después de la reconstrucción
    local chest_count = 0
    local turret_count = 0
    
    for _ in pairs(storage.tde.master_ammo_chests) do
      chest_count = chest_count + 1
    end
    
    for _ in pairs(storage.tde.global_turrets) do
      turret_count = turret_count + 1
    end
    
    game.print(string.format("Result: %d chests, %d turrets registered", chest_count, turret_count))
end)
  
commands.add_command("tde-wave-debug", "Debug wave count issues", function(command)
    game.print("=== WAVE COUNT DEBUG ===", {r = 1, g = 1, b = 0})
    
    if not storage then
      game.print("ERROR: global is nil!", {r = 1, g = 0, b = 0})
      return
    end
    
    if not storage.tde then
      game.print("ERROR: storage.tde is nil!", {r = 1, g = 0, b = 0})
      return
    end
    
    game.print("Current wave_count: " .. tostring(storage.tde.wave_count))
    game.print("Current game tick: " .. tostring(game.tick))
    game.print("Next wave tick: " .. tostring(storage.tde.next_wave_tick))
    
    if storage.tde.next_wave_tick then
      local time_left = storage.tde.next_wave_tick - game.tick
      game.print("Time to next wave: " .. tostring(time_left) .. " ticks")
      
      if time_left > 0 then
        local minutes = math.floor(time_left / 3600)
        local seconds = math.floor((time_left % 3600) / 60)
        game.print("That's: " .. minutes .. ":" .. string.format("%02d", seconds))
      end
    end
    
    game.print("World setup complete: " .. tostring(storage.tde.world_setup_complete))
    game.print("Active waves: " .. tostring(#storage.tde.active_waves))
end)
  
commands.add_command("tde-mac-debug", "Debug Master Ammo Chest system", function(command)
    game.print("=== MASTER AMMO CHEST DEBUG v13 ===")
    
    local chest_count = 0
    local total_ammo_in_chests = {}
    local invalid_chest_count = 0
    
    for chest_id, chest_data in pairs(storage.tde.master_ammo_chests) do
      if chest_data.entity and chest_data.entity.valid then
        chest_count = chest_count + 1
        local pos = chest_data.position
        local inventory = chest_data.entity.get_inventory(defines.inventory.chest)
        local ammo_count = 0
        
        if inventory then
          for i = 1, #inventory do
            local stack = inventory[i]
            if stack.valid_for_read and is_ammunition(stack.name) then
              ammo_count = ammo_count + stack.count
              total_ammo_in_chests[stack.name] = (total_ammo_in_chests[stack.name] or 0) + stack.count
            end
          end
        end
        
        game.print(string.format("  Chest %d at (%d,%d) - %d ammo items", 
          chest_id, pos.x, pos.y, ammo_count))
      else
        invalid_chest_count = invalid_chest_count + 1
        storage.tde.master_ammo_chests[chest_id] = nil
      end
    end
    
    local valid_turret_count = 0
    local invalid_turret_count = 0
    
    for turret_id, turret_data in pairs(storage.tde.global_turrets) do
      if turret_data.entity and turret_data.entity.valid and turret_data.ammo_type then
        valid_turret_count = valid_turret_count + 1
        local pos = turret_data.position
        
        -- Verificar cuánta munición tiene la torreta
        local turret_ammo = 0
        local inventory = turret_data.entity.get_inventory(defines.inventory.turret_ammo)
        if inventory then
          for i = 1, #inventory do
            local stack = inventory[i]
            if stack.valid_for_read then
              turret_ammo = turret_ammo + stack.count
            end
          end
        end
        
        game.print(string.format("  Turret %d (%s) at (%d,%d) - needs %s, has %d ammo", 
          turret_id, turret_data.entity.name, pos.x, pos.y, turret_data.ammo_type, turret_ammo))
      else
        invalid_turret_count = invalid_turret_count + 1
        storage.tde.global_turrets[turret_id] = nil
      end
    end
    
    game.print(string.format("Total: %d valid chests (%d invalid), %d valid turrets (%d invalid)", 
      chest_count, invalid_chest_count, valid_turret_count, invalid_turret_count))
    
    for ammo_name, count in pairs(total_ammo_in_chests) do
      game.print(string.format("  Available: %d %s", count, ammo_name))
    end
    
    -- Diagnóstico de estado del sistema
    if chest_count > 0 and valid_turret_count == 0 then
      game.print("WARNING: Chests will NOT consume ammo because no valid turrets!", {r = 1, g = 0.5, b = 0})
    elseif chest_count > 0 and valid_turret_count > 0 then
      game.print("System working correctly - ammo will be distributed!", {r = 0, g = 1, b = 0})
    elseif chest_count == 0 and valid_turret_count > 0 then
      game.print("No Master Ammo Chests found - place some to enable auto-distribution!", {r = 1, g = 1, b = 0})
    else
      game.print("No MAC system components found - place chests and turrets!", {r = 1, g = 0.8, b = 0})
    end
    
    -- Opción de reconstrucción manual
    game.print("Use /tde-mac-rebuild to manually reconstruct the system", {r = 0, g = 0.8, b = 1})
end)
  
-- ===== SPACE AGE DLC TESTING COMMANDS =====
commands.add_command("tde-vulkanus-boss", "Spawn a boss wave with Vulkanus Demolisher enemies", function(command)
    if not storage.tde then
        game.print("TDE system not initialized!", {r = 1, g = 0, b = 0})
        return
    end
    
    -- Simulate Vulkanus planet visit if not already visited
    if not storage.tde.multiplayer then
        storage.tde.multiplayer = {planet_visits = {}}
    end
    
    if not storage.tde.multiplayer.planet_visits["vulkanus"] then
        storage.tde.multiplayer.planet_visits["vulkanus"] = game.tick
        game.print("Simulating Vulkanus planet visit...", {r = 0, g = 1, b = 1})
    end
    
    -- Force a boss wave with Vulkanus enemies
    game.print("Spawning Vulkanus boss wave...", {r = 1, g = 0, b = 1})
    
    -- Use the enhanced boss wave function (access space_age module from global scope)
    if space_age and space_age.is_space_age_available() then
        local boss_composition, planet_data = space_age.calculate_enhanced_boss_composition()
        local boss_kills_value = math.floor((storage.tde.wave_count / storage.tde.BOSS_EVERY) * 1000) + 1000
        
        local spawn_locations = find_wave_spawn_locations()
        
        if spawn_locations and #spawn_locations > 0 then
            local boss_spawn = spawn_locations[math.random(#spawn_locations)]
            
            if boss_spawn then
                create_attack_group(boss_spawn.position, boss_composition, true, boss_spawn, boss_kills_value)
                
                -- Announce planet-specific boss wave
                space_age.announce_planet_wave(storage.tde.wave_count, true, planet_data)
                
                game.print(string.format("VULKANUS BOSS WAVE SPAWNED! Demolisher enemies worth %d research tokens!", 
                    boss_kills_value), {r = 1, g = 0, b = 1})
            else
                game.print("Failed to get boss spawn location!", {r = 1, g = 0, b = 0})
            end
        else
            game.print("No valid spawn locations found!", {r = 1, g = 0, b = 0})
        end
    else
        game.print("Space Age DLC not available - spawning regular boss wave", {r = 1, g = 0.5, b = 0})
        spawn_boss_wave()
    end
end)

commands.add_command("tde-gleba-wave", "Spawn a normal wave with Gleba enemies (Pentapods and Stompers)", function(command)
    if not storage.tde then
        game.print("TDE system not initialized!", {r = 1, g = 0, b = 0})
        return
    end
    
    -- Simulate Gleba planet visit if not already visited
    if not storage.tde.multiplayer then
        storage.tde.multiplayer = {planet_visits = {}}
    end
    
    if not storage.tde.multiplayer.planet_visits["gleba"] then
        storage.tde.multiplayer.planet_visits["gleba"] = game.tick
        game.print("Simulating Gleba planet visit...", {r = 0, g = 1, b = 1})
    end
    
    -- Force a normal wave with Gleba enemies
    game.print("Spawning Gleba enemy wave...", {r = 0, g = 1, b = 0})
    
    -- Use the enhanced wave composition function (access space_age module from global scope)
    if space_age and space_age.is_space_age_available() then
        local evolution = get_enemy_evolution()
        local base_count = math.floor(10 + (storage.tde.wave_count * 2) + (evolution * 20))
        local wave_composition = space_age.calculate_enhanced_wave_composition(base_count, evolution)
        
        local spawn_locations = find_wave_spawn_locations()
        
        if spawn_locations and #spawn_locations > 0 then
            local spawn = spawn_locations[math.random(#spawn_locations)]
            
            if spawn then
                create_attack_group(spawn.position, wave_composition, false, spawn, nil)
                
                -- Announce planet-specific wave
                space_age.announce_planet_wave(storage.tde.wave_count, false, {name = "Gleba"})
                
                game.print("GLEBA ENEMY WAVE SPAWNED! Pentapods and Stompers incoming!", {r = 0, g = 1, b = 0})
            else
                game.print("Failed to get spawn location!", {r = 1, g = 0, b = 0})
            end
        else
            game.print("No valid spawn locations found!", {r = 1, g = 0, b = 0})
        end
    else
        game.print("Space Age DLC not available - spawning regular wave", {r = 1, g = 0.5, b = 0})
        spawn_wave()
    end
end)

commands.add_command("tde-boss-wave", "Spawn a regular boss wave (uses current planet discoveries)", function(command)
    if not storage.tde then
        game.print("TDE system not initialized!", {r = 1, g = 0, b = 0})
        return
    end
    
    game.print("Spawning boss wave with current planet discoveries...", {r = 1, g = 0.8, b = 0})
    
    -- Use the enhanced boss wave function which will automatically use planet discoveries (access space_age module from global scope)
    if space_age and space_age.is_space_age_available() then
        local boss_composition, planet_data = space_age.calculate_enhanced_boss_composition()
        local boss_kills_value = math.floor((storage.tde.wave_count / storage.tde.BOSS_EVERY) * 1000) + 1000
        
        local spawn_locations = find_wave_spawn_locations()
        
        if spawn_locations and #spawn_locations > 0 then
            local boss_spawn = spawn_locations[math.random(#spawn_locations)]
            
            if boss_spawn then
                create_attack_group(boss_spawn.position, boss_composition, true, boss_spawn, boss_kills_value)
                
                -- Announce planet-specific boss wave
                space_age.announce_planet_wave(storage.tde.wave_count, true, planet_data)
                
                local planet_name = planet_data and planet_data.name or "Behemoth"
                game.print(string.format("BOSS WAVE SPAWNED! %s enemies worth %d research tokens!", 
                    planet_name, boss_kills_value), {r = 1, g = 0, b = 1})
            else
                game.print("Failed to get boss spawn location!", {r = 1, g = 0, b = 0})
            end
        else
            game.print("No valid spawn locations found!", {r = 1, g = 0, b = 0})
        end
    else
        game.print("Space Age DLC not available - spawning regular boss wave", {r = 1, g = 0.5, b = 0})
        spawn_boss_wave()
    end
end)

commands.add_command("tde-planet-status", "Show current planet discovery status", function(command)
    game.print("=== PLANET DISCOVERY STATUS ===", {r = 0, g = 1, b = 1})
    
    if not storage.tde or not storage.tde.multiplayer then
        game.print("No planet data found - no planets visited yet", {r = 1, g = 0.5, b = 0})
        return
    end
    
    local visited_planets = storage.tde.multiplayer.planet_visits or {}
    local planet_count = 0
    
    for planet_name, visit_tick in pairs(visited_planets) do
        planet_count = planet_count + 1
        local visit_time = math.floor((game.tick - visit_tick) / 3600) -- minutes ago
        game.print(string.format("✓ %s: Visited %d minutes ago", planet_name, visit_time), {r = 0, g = 1, b = 0})
    end
    
    if planet_count == 0 then
        game.print("No planets visited yet", {r = 1, g = 0.5, b = 0})
        game.print("Use /tde-vulkanus-boss or /tde-gleba-wave to simulate planet visits", {r = 0, g = 0.8, b = 1})
    else
        game.print(string.format("Total planets discovered: %d", planet_count), {r = 0, g = 1, b = 1})
        
        -- Show what enemies are now available
        if visited_planets["vulkanus"] then
            game.print("Vulkanus enemies available: Vulkanus biters, spitters, Demolisher (boss priority)", {r = 0, g = 0.8, b = 1})
        end
        
        if visited_planets["gleba"] then
            game.print("Gleba enemies available: Pentapods, Stompers (normal waves only)", {r = 0, g = 0.8, b = 1})
        end
    end
    
    -- Show Space Age DLC status (access space_age module from global scope)
    local dlc_available = space_age and space_age.is_space_age_available() or false
    game.print("Space Age DLC: " .. (dlc_available and "AVAILABLE" or "NOT AVAILABLE"), 
        dlc_available and {r = 0, g = 1, b = 0} or {r = 1, g = 0.5, b = 0})
end)

commands.add_command("tde-simulate-planet", "Simulate visiting a specific planet", function(command)
    local planet_name = command.parameter
    if not planet_name then
        game.print("Usage: /tde-simulate-planet <planet-name>")
        game.print("Available planets: vulkanus, gleba")
        return
    end
    
    if not storage.tde then
        game.print("TDE system not initialized!", {r = 1, g = 0, b = 0})
        return
    end
    
    if not storage.tde.multiplayer then
        storage.tde.multiplayer = {planet_visits = {}}
    end
    
    -- Simulate planet visit
    storage.tde.multiplayer.planet_visits[planet_name] = game.tick
    
    game.print(string.format("Simulated visit to %s!", planet_name), {r = 0, g = 1, b = 0})
    
    -- Show what enemies are now available
    if planet_name == "vulkanus" then
        game.print("Vulkanus enemies now available in waves!", {r = 0, g = 0.8, b = 1})
        game.print("Demolisher enemies will appear in boss waves!", {r = 1, g = 0, b = 1})
    elseif planet_name == "gleba" then
        game.print("Gleba enemies now available in normal waves!", {r = 0, g = 0.8, b = 1})
        game.print("Pentapods and Stompers will appear in waves!", {r = 0, g = 1, b = 0})
    end
    
    -- Notify all players
    game.print(string.format("New planet discovered: %s! New enemies may appear in waves!", planet_name), {r = 0, g = 1, b = 1})
end)

commands.add_command("tde-space-age-test", "Test Space Age DLC detection and integration", function(command)
    game.print("=== SPACE AGE DLC TEST ===", {r = 0, g = 1, b = 1})
    
    -- Test Space Age availability with detailed logging
    local dlc_available = false
    if space_age then
        dlc_available = space_age.is_space_age_available()
        game.print("Space Age module loaded: YES", {r = 0, g = 1, b = 0})
    else
        game.print("Space Age module loaded: NO", {r = 1, g = 0, b = 0})
    end
    
    game.print("Space Age DLC Available: " .. (dlc_available and "YES" or "NO"), 
        dlc_available and {r = 0, g = 1, b = 0} or {r = 1, g = 0.5, b = 0})
    
    -- Test available enemies
    if space_age then
        local enemy_types = space_age.get_available_enemy_types()
        game.print("Available normal enemies: " .. #enemy_types.normal)
        game.print("Available boss enemies: " .. #enemy_types.boss)
        
        -- Show planet-specific enemies if any
        local planet_enemies = {}
        for _, enemy_name in pairs(enemy_types.normal) do
            if enemy_name:find("vulkanus") or enemy_name:find("pentapod") or enemy_name:find("stomper") or enemy_name:find("demolisher") then
                table.insert(planet_enemies, enemy_name)
            end
        end
        
        if #planet_enemies > 0 then
            game.print("Planet-specific enemies: " .. table.concat(planet_enemies, ", "), {r = 0, g = 0.8, b = 1})
        else
            game.print("No planet-specific enemies available", {r = 1, g = 0.5, b = 0})
        end
        
        -- Test boss enemy type
        local boss_enemy, planet_data = space_age.get_boss_enemy_type()
        game.print("Current boss enemy: " .. boss_enemy)
        if planet_data then
            game.print("Boss planet: " .. planet_data.name, {r = 0, g = 0.8, b = 1})
        end
    else
        game.print("Space Age module not loaded!", {r = 1, g = 0, b = 0})
    end
    
    -- Test planet visits
    if storage.tde and storage.tde.multiplayer then
        local visited_planets = storage.tde.multiplayer.planet_visits or {}
        local planet_count = 0
        for planet_name, _ in pairs(visited_planets) do
            planet_count = planet_count + 1
        end
        game.print("Planets visited: " .. planet_count)
    else
        game.print("No planet visit data found", {r = 1, g = 0.5, b = 0})
    end
    
    -- Test entity prototypes with detailed results
    local test_entities = {"demolisher", "pentapod", "stomper", "vulkanus-biter", "vulkanus-spitter"}
    game.print("Entity prototype test:")
    for _, entity_name in pairs(test_entities) do
        local success, entity = pcall(function()
            return game.get_entity_by_tag(entity_name)
        end)
        local exists = success and entity ~= nil
        game.print("  " .. entity_name .. ": " .. (exists and "EXISTS" or "NOT FOUND"), 
            exists and {r = 0, g = 1, b = 0} or {r = 1, g = 0.5, b = 0})
    end
    
    -- Test mod detection - REMOVED game.active_mods check as it doesn't exist in Factorio 2.0
    game.print("Mod detection: Using surface and entity detection instead")
    
    -- Test surface detection
    game.print("Surface detection:")
    for surface_name, _ in pairs(game.surfaces) do
        if surface_name:find("vulkanus") or surface_name:find("gleba") then
            game.print("  " .. surface_name .. ": FOUND", {r = 0, g = 1, b = 0})
        end
    end
end)
  
commands.add_command("tde-enemy-tiers", "Test enemy tier system and HP scaling", function(command)
    game.print("=== ENEMY TIER SYSTEM TEST ===", {r = 0, g = 1, b = 1})
    
    if not space_age then
        game.print("Space Age module not loaded!", {r = 1, g = 0, b = 0})
        return
    end
    
    -- Test enemy tiers
    local test_enemies = {
        "small-biter", "medium-biter", "big-biter", "behemoth-biter",
        "small-spitter", "medium-spitter", "big-spitter", "behemoth-spitter",
        "vulkanus-biter", "vulkanus-spitter", "pentapod", "stomper", "demolisher"
    }
    
    game.print("Enemy tier assignments:")
    for _, enemy_name in pairs(test_enemies) do
        local tier = space_age.get_enemy_tier(enemy_name)
        local tier_color = {r = 1, g = 1, b = 1}
        if tier == 1 then tier_color = {r = 0.8, g = 0.8, b = 0.8}
        elseif tier == 2 then tier_color = {r = 0, g = 1, b = 0}
        elseif tier == 3 then tier_color = {r = 1, g = 0.5, b = 0}
        elseif tier == 4 then tier_color = {r = 1, g = 0, b = 0}
        end
        
        game.print("  " .. enemy_name .. ": Tier " .. tier, tier_color)
    end
    
    -- Test enemies by tier
    game.print("Enemies by tier:")
    for tier = 1, 4 do
        local enemies = space_age.get_enemies_by_tier(tier)
        if #enemies > 0 then
            game.print("  Tier " .. tier .. ": " .. table.concat(enemies, ", "), {r = 0, g = 0.8, b = 1})
        end
    end
    
    -- Test HP scaling calculation
    if storage.tde then
        local wave_number = storage.tde.wave_count or 1
        local boss_wave_number = math.floor(wave_number / storage.tde.BOSS_EVERY)
        
        game.print("HP scaling calculation (current wave " .. wave_number .. "):")
        for _, enemy_name in pairs({"behemoth-biter", "demolisher"}) do
            local tier = space_age.get_enemy_tier(enemy_name)
            local tier_multiplier = 1 + (tier - 1) * 0.3
            local progression = 1000 + (boss_wave_number - 1) * 1500 + (boss_wave_number - 1) * (boss_wave_number - 1) * 250
            local final_hp = progression * tier_multiplier
            
            game.print("  " .. enemy_name .. " (Tier " .. tier .. "): " .. math.floor(final_hp) .. " HP", {r = 1, g = 1, b = 0})
        end
    end
end)
  