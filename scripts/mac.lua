-- ENHANCED: Global MAC reconstruction with save/load resilience
function reconstruct_mac_system_robust()
    log("TDE: Starting GLOBAL MAC reconstruction...")
    
    if not storage.tde then
      log("TDE: No storage.tde found during reconstruction")
      return
    end
    
    -- Initialize global MAC storage if missing
    if not storage.tde.master_ammo_chests then
        storage.tde.master_ammo_chests = {}
    end
    if not storage.tde.global_turrets then
        storage.tde.global_turrets = {}
    end
    
    -- Store old counts for comparison
    local old_chest_count = table_size(storage.tde.master_ammo_chests)
    local old_turret_count = table_size(storage.tde.global_turrets)
    
    -- Clear existing registrations completely for fresh rebuild
    storage.tde.master_ammo_chests = {}
    storage.tde.global_turrets = {}
    
    -- Verify game and surfaces are ready
    if not game or not game.surfaces then
      log("TDE: Game not ready for MAC reconstruction")
      return
    end
    
    local total_chest_count = 0
    local total_turret_count = 0
    local surfaces_scanned = 0
    
    -- Search all surfaces with comprehensive error handling
    for surface_name, surface in pairs(game.surfaces) do
      if surface and surface.valid then
        surfaces_scanned = surfaces_scanned + 1
        log("TDE: Scanning surface " .. surface_name .. " for MAC entities")
        
        -- ENHANCED: Search for Master Ammo Chests with multiple approaches
        local chest_count = find_and_register_chests_on_surface(surface, surface_name)
        total_chest_count = total_chest_count + chest_count
        
        -- ENHANCED: Search for turrets with comprehensive type coverage
        local turret_count = find_and_register_turrets_on_surface(surface, surface_name)
        total_turret_count = total_turret_count + turret_count
        
        log("TDE: Surface " .. surface_name .. " scan complete: " .. chest_count .. " chests, " .. turret_count .. " turrets")
      end
    end
    
    -- Create turret networks for improved linking
    create_global_turret_networks()
    
    log(string.format("TDE: GLOBAL MAC reconstruction complete - %d surfaces scanned, %d chests, %d turrets total", 
      surfaces_scanned, total_chest_count, total_turret_count))
    
    -- Enhanced user feedback with comparison to previous state
    provide_reconstruction_feedback(total_chest_count, total_turret_count, old_chest_count, old_turret_count)
end

-- NEW: Find and register chests on a specific surface
function find_and_register_chests_on_surface(surface, surface_name)
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
            position = chest.position,
            surface = surface_name,
            registered_tick = game.tick
          }
          chest_count = chest_count + 1
          log("TDE: Registered Master Ammo Chest " .. chest.unit_number .. " on " .. surface_name)
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
              position = container.position,
              surface = surface_name,
              registered_tick = game.tick
            }
            chest_count = chest_count + 1
            log("TDE: Registered Master Ammo Chest (fallback) " .. container.unit_number .. " on " .. surface_name)
          end
        end
      end
    end
    
    return chest_count
end

-- NEW: Find and register turrets on a specific surface
function find_and_register_turrets_on_surface(surface, surface_name)
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
            local ammo_types = get_turret_ammo_type(turret)
            if ammo_types then -- Only register turrets that need ammo
              storage.tde.global_turrets[turret.unit_number] = {
                entity = turret,
                ammo_types = ammo_types, -- Updated to use ammo_types array
                position = turret.position,
                surface = surface_name,
                registered_tick = game.tick,
                network_id = nil  -- Will be assigned by network creation
              }
              turret_count = turret_count + 1
              log("TDE: Registered turret " .. turret.name .. " " .. turret.unit_number .. " on " .. surface_name)
            end
          end
        end
      else
        log("TDE: Error scanning for " .. turret_type .. " on " .. surface_name)
      end
    end
    
    return turret_count
end

-- NEW: Create global turret networks for improved linking with migration support
function create_global_turret_networks()
    if not storage.tde.turret_networks then
        storage.tde.turret_networks = {}
    end
    
    -- Clear existing networks
    storage.tde.turret_networks = {}
    local network_counter = 0
    
    -- Group turrets by ammo type and surface
    local network_groups = {}
    
    for turret_id, turret_data in pairs(storage.tde.global_turrets) do
        if turret_data.entity and turret_data.entity.valid then
            -- MIGRATION: Handle old save format (single ammo_type) vs new format (ammo_types array)
            local ammo_types_to_process = {}
            
            if turret_data.ammo_types then
                -- New format: multiple ammo types
                ammo_types_to_process = turret_data.ammo_types
            elseif turret_data.ammo_type then
                -- Old format: single ammo type - migrate to new format
                ammo_types_to_process = {turret_data.ammo_type}
                
                -- Migrate the turret data to new format
                local updated_ammo_types = nil
                if get_turret_ammo_type then
                    updated_ammo_types = get_turret_ammo_type(turret_data.entity)
                end
                
                if updated_ammo_types then
                    turret_data.ammo_types = updated_ammo_types
                    turret_data.ammo_type = nil -- Remove old field
                    log("TDE: Migrated turret " .. turret_id .. " to new ammo format")
                else
                    turret_data.ammo_types = {turret_data.ammo_type}
                    turret_data.ammo_type = nil
                end
                ammo_types_to_process = turret_data.ammo_types
            else
                -- No ammo type data - try to detect from entity
                local detected_ammo_types = nil
                if get_turret_ammo_type then
                    detected_ammo_types = get_turret_ammo_type(turret_data.entity)
                end
                
                if detected_ammo_types then
                    turret_data.ammo_types = detected_ammo_types
                    ammo_types_to_process = detected_ammo_types
                    log("TDE: Detected ammo types for turret " .. turret_id)
                else
                    log("TDE: Could not determine ammo types for turret " .. turret_id)
                    goto continue_turret
                end
            end
            
            -- Create network groups for each ammo type this turret accepts
            for _, ammo_type in pairs(ammo_types_to_process) do
                local key = ammo_type .. "_" .. (turret_data.surface or "nauvis")
                
                if not network_groups[key] then
                    network_groups[key] = {
                        ammo_type = ammo_type,
                        surface = turret_data.surface or "nauvis",
                        turrets = {}
                    }
                end
                
                table.insert(network_groups[key].turrets, turret_id)
            end
        end
        
        ::continue_turret::
    end
    
    -- Create networks and assign IDs
    for key, group in pairs(network_groups) do
        if #group.turrets > 0 then
            network_counter = network_counter + 1
            local network_id = "network_" .. network_counter
            
            storage.tde.turret_networks[network_id] = {
                ammo_type = group.ammo_type,
                surface = group.surface,
                turrets = group.turrets,
                created_tick = game.tick
            }
            
            -- Assign network ID to all turrets in this network
            for _, turret_id in pairs(group.turrets) do
                if storage.tde.global_turrets[turret_id] then
                    if not storage.tde.global_turrets[turret_id].network_ids then
                        storage.tde.global_turrets[turret_id].network_ids = {}
                    end
                    storage.tde.global_turrets[turret_id].network_ids[group.ammo_type] = network_id
                end
            end
            
            log(string.format("TDE: Created turret network %s with %d turrets (ammo: %s, surface: %s)", 
              network_id, #group.turrets, group.ammo_type, group.surface))
        end
    end
    
    log("TDE: Created " .. network_counter .. " turret networks for improved linking (with migration)")
end

-- NEW: Provide detailed feedback about reconstruction
function provide_reconstruction_feedback(total_chest_count, total_turret_count, old_chest_count, old_turret_count)
    local network_count = table_size(storage.tde.turret_networks or {})
    
    if total_chest_count > 0 or total_turret_count > 0 then
      local message = string.format("Global MAC system rebuilt: %d chests, %d turrets, %d networks", 
        total_chest_count, total_turret_count, network_count)
      game.print(message, {r = 0, g = 1, b = 0})
      
      -- Show changes from previous state
      if old_chest_count > 0 or old_turret_count > 0 then
          local chest_change = total_chest_count - old_chest_count
          local turret_change = total_turret_count - old_turret_count
          
          if chest_change ~= 0 or turret_change ~= 0 then
              game.print(string.format("Changes: %+d chests, %+d turrets", chest_change, turret_change), {r = 0, g = 0.8, b = 1})
          end
      end
      
      -- Additional system status info if debug messages are enabled
      if settings.global["tde-show-ammo-messages"].value then
        if total_chest_count > 0 and total_turret_count > 0 then
          game.print("Global MAC system operational - all chests linked to all turrets!", {r = 0, g = 0.8, b = 1})
        elseif total_chest_count > 0 and total_turret_count == 0 then
          game.print("Warning: Master Ammo Chests found but no turrets - place turrets to enable distribution!", {r = 1, g = 0.8, b = 0})
        elseif total_chest_count == 0 and total_turret_count > 0 then
          game.print("Warning: Turrets found but no Master Ammo Chests - place chests to enable auto-distribution!", {r = 1, g = 0.8, b = 0})
        end
      end
    else
      game.print("No MAC entities found - place Master Ammo Chests and turrets to enable the global system!", {r = 1, g = 1, b = 0})
    end
end

-- ENHANCED: Global MAC system verification with network integrity
function verify_and_fix_mac_system()
    if not storage.tde or not storage.tde.master_ammo_chests or not storage.tde.global_turrets then
      return
    end
    
    local invalid_chests = 0
    local invalid_turrets = 0
    local invalid_networks = 0
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
    
    -- Verify and clean up turret networks
    if storage.tde.turret_networks then
        for network_id, network_data in pairs(storage.tde.turret_networks) do
            local valid_turrets_in_network = 0
            
            if network_data.turrets then
                for i = #network_data.turrets, 1, -1 do
                    local turret_id = network_data.turrets[i]
                    if storage.tde.global_turrets[turret_id] then
                        valid_turrets_in_network = valid_turrets_in_network + 1
                    else
                        -- Remove invalid turret from network
                        table.remove(network_data.turrets, i)
                    end
                end
            end
            
            -- Remove network if it has no valid turrets
            if valid_turrets_in_network == 0 then
                storage.tde.turret_networks[network_id] = nil
                invalid_networks = invalid_networks + 1
                fixed_issues = true
            end
        end
    end
    
    -- Enhanced recovery logic with network consideration
    local total_entities_lost = invalid_chests + invalid_turrets
    
    if total_entities_lost > 10 or invalid_networks > 3 then
      log("TDE: Significant entity/network loss detected - triggering full MAC reconstruction")
      storage.tde.mac_needs_reconstruction = true
      if settings.global["tde-show-ammo-messages"].value then
        game.print("Global MAC system integrity compromised - scheduling full rebuild...", {r = 1, g = 0.5, b = 0})
      end
    elseif fixed_issues and settings.global["tde-show-ammo-messages"].value then
      log(string.format("TDE: MAC integrity check - removed %d invalid chests, %d invalid turrets, %d invalid networks", 
        invalid_chests, invalid_turrets, invalid_networks))
    end
    
    -- Automatic re-scanning for missing entities (less aggressive)
    if fixed_issues and (game.tick % 36000 == 0) then -- Only every 10 minutes
      local chest_count = table_size(storage.tde.master_ammo_chests)
      local turret_count = table_size(storage.tde.global_turrets)
      local network_count = table_size(storage.tde.turret_networks or {})
      
      -- If we have very few entities registered, maybe we missed some
      if chest_count < 2 and turret_count < 5 then
        log("TDE: Very few entities registered, scheduling gentle reconstruction")
        storage.tde.mac_needs_reconstruction = true
      elseif network_count == 0 and turret_count > 0 then
        log("TDE: No turret networks but turrets exist, scheduling network reconstruction")
        create_global_turret_networks()
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
                  local ammo_types = get_turret_ammo_type(turret)
                  if ammo_types then
                    storage.tde.global_turrets[turret.unit_number] = {
                      entity = turret,
                      ammo_types = ammo_types, -- Updated to use ammo_types array
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