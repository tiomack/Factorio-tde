-- ENHANCED: More robust MAC reconstruction with better error handling
function reconstruct_mac_system_robust()
    log("TDE: Starting ROBUST MAC reconstruction...")
    
    if not storage.tde then
      log("TDE: No storage.tde found during reconstruction")
      return
    end
    
    -- Clear existing registrations completely
    storage.tde.master_ammo_chests = {}
    storage.tde.global_turrets = {}
    
    -- Verify game and surfaces are ready
    if not game or not game.surfaces then
      log("TDE: Game not ready for MAC reconstruction")
      return
    end
    
    local total_chest_count = 0
    local total_turret_count = 0
    
    -- Search all surfaces with comprehensive error handling
    for surface_name, surface in pairs(game.surfaces) do
      if surface and surface.valid then
        log("TDE: Scanning surface " .. surface_name .. " for MAC entities")
        
        -- ENHANCED: Search for Master Ammo Chests with multiple approaches
        local chest_count = 0
        
        -- Method 1: Direct name search
        local success_chests, master_chests = pcall(function()
          return surface.find_entities_filtered({
            name = "master-ammo-chest"
          })
        end)
        
        if success_chests and master_chests then
          for _, chest in pairs(master_chests) do
            if chest and chest.valid and chest.unit_number then
              storage.tde.master_ammo_chests[chest.unit_number] = {
                entity = chest,
                position = chest.position
              }
              chest_count = chest_count + 1
              log("TDE: Registered Master Ammo Chest " .. chest.unit_number .. " at " .. chest.position.x .. "," .. chest.position.y)
            end
          end
        else
          -- Method 2: Fallback - search by type and filter by name
          local fallback_success, all_containers = pcall(function()
            return surface.find_entities_filtered({
              type = "container"
            })
          end)
          
          if fallback_success and all_containers then
            for _, container in pairs(all_containers) do
              if container and container.valid and container.name == "master-ammo-chest" and container.unit_number then
                storage.tde.master_ammo_chests[container.unit_number] = {
                  entity = container,
                  position = container.position
                }
                chest_count = chest_count + 1
                log("TDE: Registered Master Ammo Chest (fallback) " .. container.unit_number)
              end
            end
          end
        end
        
        total_chest_count = total_chest_count + chest_count
        log("TDE: Found " .. chest_count .. " Master Ammo Chests on " .. surface_name)
        
        -- ENHANCED: Search for turrets with comprehensive type coverage
        local turret_count = 0
        local turret_types = {"ammo-turret", "electric-turret", "fluid-turret", "artillery-turret"}
        
        for _, turret_type in pairs(turret_types) do
          local success_turrets, turrets = pcall(function()
            return surface.find_entities_filtered({
              type = turret_type
            })
          end)
          
          if success_turrets and turrets then
            for _, turret in pairs(turrets) do
              if turret and turret.valid and turret.unit_number then
                local ammo_type = get_turret_ammo_type(turret)
                if ammo_type then -- Only register turrets that need ammo
                  storage.tde.global_turrets[turret.unit_number] = {
                    entity = turret,
                    ammo_type = ammo_type,
                    position = turret.position
                  }
                  turret_count = turret_count + 1
                  log("TDE: Registered turret " .. turret.name .. " " .. turret.unit_number)
                end
              end
            end
          else
            log("TDE: Error scanning for " .. turret_type .. " on " .. surface_name)
          end
        end
        
        total_turret_count = total_turret_count + turret_count
        log("TDE: Found " .. turret_count .. " turrets on " .. surface_name)
      end
    end
    
    log("TDE: ROBUST MAC reconstruction complete - " .. total_chest_count .. " chests, " .. total_turret_count .. " turrets total")
    
    -- Enhanced user feedback
    if total_chest_count > 0 or total_turret_count > 0 then
      local message = string.format("MAC system rebuilt: %d chests, %d turrets found and registered", 
        total_chest_count, total_turret_count)
      game.print(message, {r = 0, g = 1, b = 0})
      
      -- Additional system status info if debug messages are enabled
      if settings.global["tde-show-ammo-messages"].value then
        if total_chest_count > 0 and total_turret_count > 0 then
          game.print("MAC system is now operational - ammo will be distributed automatically!", {r = 0, g = 0.8, b = 1})
        elseif total_chest_count > 0 and total_turret_count == 0 then
          game.print("Warning: Master Ammo Chests found but no turrets - place turrets to enable distribution!", {r = 1, g = 0.8, b = 0})
        elseif total_chest_count == 0 and total_turret_count > 0 then
          game.print("Warning: Turrets found but no Master Ammo Chests - place chests to enable auto-distribution!", {r = 1, g = 0.8, b = 0})
        end
      end
    else
      game.print("No MAC entities found - place Master Ammo Chests and turrets to enable the system!", {r = 1, g = 1, b = 0})
    end
end

-- ENHANCED: More thorough verification and fixing system
function verify_and_fix_mac_system()
    if not storage.tde or not storage.tde.master_ammo_chests or not storage.tde.global_turrets then
      return
    end
    
    local invalid_chests = 0
    local invalid_turrets = 0
    local fixed_issues = false
    
    -- Verify chests and clean up invalid ones
    for chest_id, chest_data in pairs(storage.tde.master_ammo_chests) do
      if not chest_data.entity or not chest_data.entity.valid then
        invalid_chests = invalid_chests + 1
        storage.tde.master_ammo_chests[chest_id] = nil
        fixed_issues = true
      end
    end
    
    -- Verify turrets and clean up invalid ones
    for turret_id, turret_data in pairs(storage.tde.global_turrets) do
      if not turret_data.entity or not turret_data.entity.valid then
        invalid_turrets = invalid_turrets + 1
        storage.tde.global_turrets[turret_id] = nil
        fixed_issues = true
      end
    end
    
    -- Enhanced recovery logic
    if invalid_chests > 5 or invalid_turrets > 15 then
      log("TDE: Significant entity loss detected - triggering full MAC reconstruction")
      storage.tde.mac_needs_reconstruction = true
      if settings.global["tde-show-ammo-messages"].value then
        game.print("MAC system integrity compromised - scheduling full rebuild...", {r = 1, g = 0.5, b = 0})
      end
    elseif (invalid_chests > 0 or invalid_turrets > 0) and settings.global["tde-show-ammo-messages"].value then
      log(string.format("TDE: MAC integrity check - removed %d invalid chests, %d invalid turrets", 
        invalid_chests, invalid_turrets))
    end
    
    -- Automatic re-scanning for missing entities (less aggressive)
    if fixed_issues and (game.tick % 36000 == 0) then -- Only every 10 minutes
      local chest_count = 0
      local turret_count = 0
      
      for _ in pairs(storage.tde.master_ammo_chests) do
        chest_count = chest_count + 1
      end
      
      for _ in pairs(storage.tde.global_turrets) do
        turret_count = turret_count + 1
      end
      
      -- If we have very few entities registered, maybe we missed some
      if chest_count < 2 and turret_count < 5 then
        log("TDE: Very few entities registered, scheduling gentle reconstruction")
        storage.tde.mac_needs_reconstruction = true
      end
    end
end

-- NEW: Gentler reconstruction that preserves existing registrations
function gentle_mac_reconstruction()
    if not storage.tde then return end
    
    log("TDE: Starting gentle MAC reconstruction (preserving existing registrations)")
    
    local initial_chest_count = 0
    local initial_turret_count = 0
    local found_chest_count = 0
    local found_turret_count = 0
    
    -- Count existing registrations
    for _ in pairs(storage.tde.master_ammo_chests) do
      initial_chest_count = initial_chest_count + 1
    end
    
    for _ in pairs(storage.tde.global_turrets) do
      initial_turret_count = initial_turret_count + 1
    end
    
    -- Only look for missing entities, don't clear existing ones
    for surface_name, surface in pairs(game.surfaces) do
      if surface and surface.valid then
        -- Find Master Ammo Chests not already registered
        local success, chests = pcall(function()
          return surface.find_entities_filtered({name = "master-ammo-chest"})
        end)
        
        if success and chests then
          for _, chest in pairs(chests) do
            if chest and chest.valid and chest.unit_number then
              if not storage.tde.master_ammo_chests[chest.unit_number] then
                storage.tde.master_ammo_chests[chest.unit_number] = {
                  entity = chest,
                  position = chest.position
                }
                found_chest_count = found_chest_count + 1
              end
            end
          end
        end
        
        -- Find turrets not already registered
        local turret_types = {"ammo-turret", "electric-turret", "fluid-turret", "artillery-turret"}
        for _, turret_type in pairs(turret_types) do
          local success_t, turrets = pcall(function()
            return surface.find_entities_filtered({type = turret_type})
          end)
          
          if success_t and turrets then
            for _, turret in pairs(turrets) do
              if turret and turret.valid and turret.unit_number then
                if not storage.tde.global_turrets[turret.unit_number] then
                  local ammo_type = get_turret_ammo_type(turret)
                  if ammo_type then
                    storage.tde.global_turrets[turret.unit_number] = {
                      entity = turret,
                      ammo_type = ammo_type,
                      position = turret.position
                    }
                    found_turret_count = found_turret_count + 1
                  end
                end
              end
            end
          end
        end
      end
    end
    
    if found_chest_count > 0 or found_turret_count > 0 then
      local message = string.format("MAC gentle rebuild: found %d new chests, %d new turrets (total: %d chests, %d turrets)", 
        found_chest_count, found_turret_count, 
        initial_chest_count + found_chest_count, initial_turret_count + found_turret_count)
      
      if settings.global["tde-show-ammo-messages"].value then
        game.print(message, {r = 0, g = 0.8, b = 1})
      end
      log("TDE: " .. message)
    end
end