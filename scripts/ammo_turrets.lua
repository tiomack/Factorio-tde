function register_master_ammo_chest(chest)
    if not chest or not chest.valid or not chest.unit_number then
      log("Cannot register master ammo chest - invalid entity")
      return
    end
    
    storage.tde.master_ammo_chests[chest.unit_number] = {
      entity = chest,
      position = chest.position
      -- Note: No player tracking - all chests contribute to the same objective
      -- regardless of who placed them (multiplayer-friendly)
    }
    
    -- FIXED: Check setting before showing messages
    if settings.global["tde-show-ammo-messages"].value then
      game.print("Master Ammo Chest registered for global distribution!", {r = 0, g = 1, b = 0})
    end
    log("Registered Master Ammo Chest at " .. chest.position.x .. "," .. chest.position.y)
end
  
function unregister_master_ammo_chest(chest)
    if chest and chest.unit_number then
      storage.tde.master_ammo_chests[chest.unit_number] = nil
      log("Unregistered Master Ammo Chest")
    end
end
  
function register_turret(turret)
    if not turret or not turret.valid or not turret.unit_number then
      log("Cannot register turret - invalid entity")
      return
    end
    
    local ammo_types = get_turret_ammo_type(turret)
    if ammo_types then
      storage.tde.global_turrets[turret.unit_number] = {
        entity = turret,
        ammo_types = ammo_types, -- Store all compatible ammo types
        position = turret.position,
        surface = turret.surface.name,
        registered_tick = game.tick
        -- Note: No player tracking - all turrets contribute to the same objective
        -- regardless of who placed them (multiplayer-friendly)
      }
      
      local ammo_list = table.concat(ammo_types, ", ")
      log("Registered turret " .. turret.name .. " at " .. turret.position.x .. "," .. turret.position.y .. " (accepts: " .. ammo_list .. ")")
      
      -- Update turret networks immediately when a new turret is placed
      update_turret_networks_for_new_turret(turret.unit_number)
      
      -- FIXED: Check setting before showing messages
      if settings.global["tde-show-ammo-messages"].value then
        game.print("Turret registered: " .. turret.name .. " (accepts: " .. ammo_list .. ")", {r = 0, g = 1, b = 0.5})
      end
    else
      log("Turret " .. turret.name .. " doesn't need ammo - not registered")
    end
end

-- NEW: Update turret networks when a new turret is added
function update_turret_networks_for_new_turret(turret_id)
    if not storage.tde.turret_networks then
        storage.tde.turret_networks = {}
    end
    
    local turret_data = storage.tde.global_turrets[turret_id]
    if not turret_data or not turret_data.ammo_types then
        return
    end
    
    -- For each ammo type this turret accepts, add it to the appropriate network
    for _, ammo_type in pairs(turret_data.ammo_types) do
        local network_key = ammo_type .. "_" .. (turret_data.surface or "nauvis")
        
        -- Find existing network or create new one
        local found_network = nil
        for network_id, network_data in pairs(storage.tde.turret_networks) do
            if network_data.ammo_type == ammo_type and network_data.surface == (turret_data.surface or "nauvis") then
                found_network = network_id
                break
            end
        end
        
        if found_network then
            -- Add turret to existing network
            table.insert(storage.tde.turret_networks[found_network].turrets, turret_id)
            log("Added turret " .. turret_id .. " to existing network " .. found_network .. " (" .. ammo_type .. ")")
        else
            -- Create new network
            local network_counter = table_size(storage.tde.turret_networks) + 1
            local network_id = "network_" .. network_counter
            
            storage.tde.turret_networks[network_id] = {
                ammo_type = ammo_type,
                surface = turret_data.surface or "nauvis",
                turrets = {turret_id},
                created_tick = game.tick
            }
            
            log("Created new turret network " .. network_id .. " for turret " .. turret_id .. " (" .. ammo_type .. ")")
        end
        
        -- Assign network reference to turret
        if not turret_data.network_ids then
            turret_data.network_ids = {}
        end
        turret_data.network_ids[ammo_type] = found_network or ("network_" .. (table_size(storage.tde.turret_networks)))
    end
    
    local network_count = table_size(storage.tde.turret_networks)
    if settings.global["tde-show-ammo-messages"].value then
        game.print("Turret networks updated - now " .. network_count .. " active networks", {r = 0, g = 0.8, b = 1})
    end
end
  
function unregister_turret(turret)
    if turret and turret.unit_number then
      storage.tde.global_turrets[turret.unit_number] = nil
      log("Unregistered turret")
    end
end
  
function is_turret(entity)
    return entity.type == "ammo-turret" or entity.type == "electric-turret" or entity.type == "fluid-turret"
end
  
function get_turret_ammo_type(turret)
    if not turret or not turret.valid then
        return nil
    end
    
    -- Enhanced turret type detection - return multiple ammo types for gun turrets
    local turret_ammo_map = {
        ["gun-turret"] = {"firearm-magazine", "piercing-rounds-magazine", "uranium-rounds-magazine"},
        ["laser-turret"] = nil, -- Laser turrets don't need ammo
        ["flamethrower-turret"] = nil, -- Flamethrower turrets use fluid, not ammo
        ["artillery-turret"] = {"artillery-shell"},
        -- Space Age DLC turrets (if available)
        ["tesla-turret"] = {"tesla-ammo"},
        -- Add more turret types as needed
    }
    
    -- Return the ammo types this turret can use
    return turret_ammo_map[turret.name]
end

-- NEW: Get all possible ammo types that a turret can use
function get_all_turret_ammo_types(turret)
    local ammo_types = get_turret_ammo_type(turret)
    if ammo_types then
        return ammo_types
    end
    
    -- For unknown turrets, try to detect if they need ammo
    if turret.type == "ammo-turret" then
        -- Fallback for ammo turrets: assume they use all bullet types
        return {"firearm-magazine", "piercing-rounds-magazine", "uranium-rounds-magazine"}
    end
    
    -- Electric, fluid, and other turrets don't need ammo
    return nil
end

-- NEW: Check if a turret can use a specific ammo type
function turret_can_use_ammo(turret, ammo_type)
    local ammo_types = get_turret_ammo_type(turret)
    if not ammo_types then
        return false
    end
    
    for _, accepted_ammo in pairs(ammo_types) do
        if accepted_ammo == ammo_type then
            return true
        end
    end
    
    return false
end

-- NEW: Check if turret data can use a specific ammo type (from stored data)
function turret_data_can_use_ammo(turret_data, ammo_type)
    if not turret_data or not turret_data.ammo_types then
        return false
    end
    
    for _, accepted_ammo in pairs(turret_data.ammo_types) do
        if accepted_ammo == ammo_type then
            return true
        end
    end
    
    return false
end
  
-- ENHANCED: Global ammunition distribution system with priority-based distribution
function process_ammo_distribution()
    if game.tick % 360 ~= 0 then return end -- Every 6 seconds
    
    if not storage.tde or not storage.tde.master_ammo_chests or not storage.tde.global_turrets then
      return
    end
    
    -- STEP 1: Clean up invalid entities and collect valid ones
    local valid_turrets_by_ammo = {} -- Group turrets by ammo type
    local valid_chests = {}
    local total_turret_count = 0
    local total_chest_count = 0
    
    -- Clean and group turrets by ammunition type
    for turret_id, turret_data in pairs(storage.tde.global_turrets) do
      if turret_data.entity and turret_data.entity.valid and turret_data.ammo_type then
        local ammo_type = turret_data.ammo_type
        if not valid_turrets_by_ammo[ammo_type] then
          valid_turrets_by_ammo[ammo_type] = {}
        end
        table.insert(valid_turrets_by_ammo[ammo_type], turret_data)
        total_turret_count = total_turret_count + 1
      else
        storage.tde.global_turrets[turret_id] = nil
      end
    end
    
    -- Clean and collect valid chests
    for chest_id, chest_data in pairs(storage.tde.master_ammo_chests) do
      if chest_data.entity and chest_data.entity.valid then
        table.insert(valid_chests, chest_data)
        total_chest_count = total_chest_count + 1
      else
        storage.tde.master_ammo_chests[chest_id] = nil
      end
    end
    
    -- Early exit if no valid components
    if total_turret_count == 0 or total_chest_count == 0 then
      if game.tick % 3600 == 0 then -- Debug every minute
        log("MAC System: " .. total_chest_count .. " chests, " .. total_turret_count .. " turrets found - skipping distribution")
      end
      return
    end
    
    -- STEP 2: Create global ammunition pool from all chests
    local global_ammo_pool = {}
    
    for _, chest_data in pairs(valid_chests) do
      local inventory = chest_data.entity.get_inventory(defines.inventory.chest)
      if inventory then
        for i = 1, #inventory do
          local stack = inventory[i]
          if stack.valid_for_read and is_ammunition(stack.name) then
            global_ammo_pool[stack.name] = (global_ammo_pool[stack.name] or 0) + stack.count
          end
        end
      end
    end
    
    -- STEP 3: Process all ammunition types to all compatible turrets
    local total_distributed = 0
    
    -- For each ammunition type in the global pool
    for ammo_type, available_amount in pairs(global_ammo_pool) do
      if available_amount > 0 and is_ammunition(ammo_type) then
        -- Find all turrets that can use this ammo type
        local compatible_turrets = {}
        
        for turret_id, turret_data in pairs(storage.tde.global_turrets) do
          if turret_data.entity and turret_data.entity.valid then
            if turret_data_can_use_ammo(turret_data, ammo_type) then
              table.insert(compatible_turrets, turret_data)
            end
          end
        end
        
        if #compatible_turrets > 0 then
          local distributed_this_type = distribute_ammo_with_priority(ammo_type, compatible_turrets, available_amount, valid_chests)
          total_distributed = total_distributed + distributed_this_type
          
          -- Show distribution message if enabled
          if distributed_this_type > 0 and settings.global["tde-show-ammo-messages"].value then
            game.print(string.format("Distributed %d %s to %d turrets (priority-based)", 
              distributed_this_type, ammo_type, #compatible_turrets), {r = 0, g = 0.8, b = 1})
          end
        end
      end
    end
    
    -- Debug output every minute (reduced frequency)
    if game.tick % 3600 == 0 and (total_chest_count > 0 or total_turret_count > 0) then
      log(string.format("MAC System: %d chests, %d turrets, distributed %d ammo this cycle", 
        total_chest_count, total_turret_count, total_distributed))
    end
end

-- NEW: Priority-based ammunition distribution function
function distribute_ammo_with_priority(ammo_type, turrets, available_ammo, valid_chests)
    if not turrets or #turrets == 0 or available_ammo <= 0 then
        return 0
    end
    
    -- STEP 1: Calculate current ammo levels for all turrets of this type
    local turret_ammo_levels = {}
    for _, turret_data in pairs(turrets) do
        local inventory = turret_data.entity.get_inventory(defines.inventory.turret_ammo)
        local current_ammo = 0
        
        if inventory then
            for i = 1, #inventory do
                local stack = inventory[i]
                if stack.valid_for_read and stack.name == ammo_type then
                    current_ammo = current_ammo + stack.count
                end
            end
        end
        
        table.insert(turret_ammo_levels, {
            turret_data = turret_data,
            current_ammo = current_ammo,
            inventory = inventory
        })
    end
    
    -- STEP 2: Sort turrets by current ammo level (lowest first = highest priority)
    table.sort(turret_ammo_levels, function(a, b)
        return a.current_ammo < b.current_ammo
    end)
    
    -- STEP 3: Calculate distribution targets with priority
    local min_threshold = 50  -- Minimum ammo each turret should have
    local max_threshold = 200 -- Maximum ammo each turret should have
    local distribution_plan = {}
    local total_needed = 0
    
    for _, turret_info in pairs(turret_ammo_levels) do
        local current = turret_info.current_ammo
        local target = math.min(min_threshold, max_threshold)
        
        -- Priority system: turrets with less ammo get more priority
        if current < min_threshold then
            local need = math.min(target - current, max_threshold - current)
            if need > 0 then
                table.insert(distribution_plan, {
                    turret_info = turret_info,
                    need = need,
                    priority = min_threshold - current -- Higher number = higher priority
                })
                total_needed = total_needed + need
            end
        end
    end
    
    -- STEP 4: Sort by priority (highest first)
    table.sort(distribution_plan, function(a, b)
        return a.priority > b.priority
    end)
    
    -- STEP 5: Remove ammo from global chest pool
    local to_distribute = math.min(available_ammo, total_needed)
    local removed_ammo = remove_ammo_from_chests(ammo_type, to_distribute, valid_chests)
    
    -- STEP 6: Distribute based on priority
    local distributed = 0
    for _, plan in pairs(distribution_plan) do
        if distributed >= removed_ammo then break end
        
        local to_give = math.min(plan.need, removed_ammo - distributed)
        if to_give > 0 and plan.turret_info.inventory then
            local inserted = plan.turret_info.inventory.insert({name = ammo_type, count = to_give})
            distributed = distributed + inserted
            
            -- If we couldn't insert all, return remainder to chests
            local leftover = to_give - inserted
            if leftover > 0 then
                return_ammo_to_chests(ammo_type, leftover, valid_chests)
            end
        end
    end
    
    -- STEP 7: Return any undistributed ammo to chests
    local undistributed = removed_ammo - distributed
    if undistributed > 0 then
        return_ammo_to_chests(ammo_type, undistributed, valid_chests)
    end
    
    return distributed
end

-- HELPER: Remove specific ammo from chest pool
function remove_ammo_from_chests(ammo_type, amount_needed, valid_chests)
    local removed = 0
    
    for _, chest_data in pairs(valid_chests) do
        if removed >= amount_needed then break end
        
        local inventory = chest_data.entity.get_inventory(defines.inventory.chest)
        if inventory then
            for i = 1, #inventory do
                if removed >= amount_needed then break end
                
                local stack = inventory[i]
                if stack.valid_for_read and stack.name == ammo_type then
                    local to_remove = math.min(stack.count, amount_needed - removed)
                    stack.count = stack.count - to_remove
                    removed = removed + to_remove
                    
                    if stack.count == 0 then
                        stack.clear()
                    end
                end
            end
        end
    end
    
    return removed
end

-- HELPER: Return ammo to the global chest pool
function return_ammo_to_chests(ammo_type, amount, valid_chests)
    local remaining = amount
    
    for _, chest_data in pairs(valid_chests) do
        if remaining <= 0 then break end
        
        local inventory = chest_data.entity.get_inventory(defines.inventory.chest)
        if inventory then
            local inserted = inventory.insert({name = ammo_type, count = remaining})
            remaining = remaining - inserted
        end
    end
    
    if remaining > 0 then
        log("TDE: Warning - Could not return " .. remaining .. " " .. ammo_type .. " to chests")
    end
end
  
-- FIXED: Enhanced ammunition detection with more types
function is_ammunition(item_name)
    if not item_name then return false end
    
    -- Enhanced ammunition types list for better compatibility
    local ammo_types = {
      ["firearm-magazine"] = true,
      ["piercing-rounds-magazine"] = true,
      ["uranium-rounds-magazine"] = true,
      ["shotgun-shell"] = true,
      ["piercing-shotgun-shell"] = true,
      ["cannon-shell"] = true,
      ["explosive-cannon-shell"] = true,
      ["uranium-cannon-shell"] = true,
      ["explosive-uranium-cannon-shell"] = true,
      ["artillery-shell"] = true,
      ["rocket"] = true,
      ["explosive-rocket"] = true,
      ["atomic-bomb"] = true,
      ["flamethrower-ammo"] = true,
      -- TDE Enhanced ammunition types
      ["tde-enhanced-magazine"] = true,
      ["tde-armor-piercing-rounds"] = true,
      -- Add Space Age ammo types if they exist
      ["tesla-ammo"] = true, -- Example Space Age ammo
    }
    
    return ammo_types[item_name] or false
end

-- ENHANCED: Global turret-to-turret ammo balancing with improved linking
function balance_ammo_between_turrets()
    if not storage.tde or not storage.tde.global_turrets then
      return
    end
    
    -- Group turrets by ammo type and create linking system
    local turret_networks = {}
    local total_turrets = 0
    
    for turret_id, turret_data in pairs(storage.tde.global_turrets) do
      if turret_data.entity and turret_data.entity.valid and turret_data.ammo_type then
        local ammo_type = turret_data.ammo_type
        
        if not turret_networks[ammo_type] then
          turret_networks[ammo_type] = {
            turrets = {},
            total_ammo = 0,
            count = 0
          }
        end
        
        -- Add turret to network
        table.insert(turret_networks[ammo_type].turrets, turret_data)
        turret_networks[ammo_type].count = turret_networks[ammo_type].count + 1
        total_turrets = total_turrets + 1
      else
        storage.tde.global_turrets[turret_id] = nil
      end
    end
    
    if total_turrets == 0 then
      return
    end
    
    -- Process each turret network independently
    local total_redistributed = 0
    
    for ammo_type, network in pairs(turret_networks) do
      if network.count > 1 then -- Only balance networks with multiple turrets
        local redistributed = balance_turret_network(network, ammo_type)
        total_redistributed = total_redistributed + redistributed
        
        -- Update network statistics for monitoring
        if redistributed > 0 then
          log(string.format("TDE: Balanced %d %s among %d linked turrets", 
            redistributed, ammo_type, network.count))
        end
      end
    end
    
    -- Show message if setting is enabled and something was redistributed
    if total_redistributed > 0 and settings.global["tde-show-ammo-messages"].value then
      game.print(string.format("Turret networks balanced: %d ammo redistributed", total_redistributed), {r = 0, g = 0.8, b = 1})
    end
end

-- NEW: Enhanced network-based balancing system
function balance_turret_network(network, ammo_type)
    if not network or not network.turrets or #network.turrets < 2 then
        return 0
    end
    
    -- Calculate current ammo distribution across the network
    local turret_inventories = {}
    local total_ammo = 0
    local min_ammo = math.huge
    local max_ammo = 0
    
    for _, turret_data in pairs(network.turrets) do
        if turret_data.entity and turret_data.entity.valid then
            local inventory = turret_data.entity.get_inventory(defines.inventory.turret_ammo)
            if inventory then
                local ammo_count = 0
                
                for i = 1, #inventory do
                    local stack = inventory[i]
                    if stack.valid_for_read and stack.name == ammo_type then
                        ammo_count = ammo_count + stack.count
                    end
                end
                
                table.insert(turret_inventories, {
                    turret_data = turret_data,
                    inventory = inventory,
                    current_ammo = ammo_count,
                    position = turret_data.position
                })
                
                total_ammo = total_ammo + ammo_count
                min_ammo = math.min(min_ammo, ammo_count)
                max_ammo = math.max(max_ammo, ammo_count)
            end
        end
    end
    
    if #turret_inventories < 2 or total_ammo == 0 then
        return 0
    end
    
    -- Only balance if there's significant imbalance
    local imbalance_threshold = 40  -- Only balance if difference > 40 ammo
    if (max_ammo - min_ammo) <= imbalance_threshold then
        return 0
    end
    
    -- Calculate target distribution (even distribution)
    local target_per_turret = math.floor(total_ammo / #turret_inventories)
    local excess_to_distribute = total_ammo % #turret_inventories
    
    -- Create redistribution plan
    local redistribution_plan = create_redistribution_plan(turret_inventories, target_per_turret, ammo_type)
    
    -- Execute redistribution
    local redistributed = execute_redistribution(redistribution_plan, ammo_type)
    
    return redistributed
end

-- NEW: Create smart redistribution plan
function create_redistribution_plan(turret_inventories, target_per_turret, ammo_type)
    local donors = {}  -- Turrets with excess ammo
    local receivers = {}  -- Turrets needing ammo
    
    for _, turret_inv in pairs(turret_inventories) do
        local difference = turret_inv.current_ammo - target_per_turret
        
        if difference > 10 then  -- Has significant excess (more than 10 above target)
            table.insert(donors, {
                turret_inv = turret_inv,
                excess = difference - 5  -- Keep 5 ammo buffer
            })
        elseif difference < -10 then  -- Has significant deficit (more than 10 below target)
            table.insert(receivers, {
                turret_inv = turret_inv,
                deficit = math.abs(difference) - 5  -- Account for 5 ammo buffer
            })
        end
    end
    
    -- Sort donors by excess (most excess first)
    table.sort(donors, function(a, b) return a.excess > b.excess end)
    
    -- Sort receivers by deficit (most deficit first) 
    table.sort(receivers, function(a, b) return a.deficit > b.deficit end)
    
    return {
        donors = donors,
        receivers = receivers
    }
end

-- NEW: Execute the redistribution plan
function execute_redistribution(plan, ammo_type)
    local total_redistributed = 0
    
    for _, donor in pairs(plan.donors) do
        local ammo_to_give = donor.excess
        
        if ammo_to_give <= 0 then goto continue_donor end
        
        -- Remove ammo from donor
        local removed_ammo = remove_ammo_from_turret(donor.turret_inv, ammo_type, ammo_to_give)
        
        if removed_ammo > 0 then
            -- Distribute to receivers
            local remaining_ammo = removed_ammo
            
            for _, receiver in pairs(plan.receivers) do
                if remaining_ammo <= 0 then break end
                
                local ammo_to_receive = math.min(remaining_ammo, receiver.deficit)
                if ammo_to_receive > 0 then
                    local inserted = give_ammo_to_turret(receiver.turret_inv, ammo_type, ammo_to_receive)
                    remaining_ammo = remaining_ammo - inserted
                    receiver.deficit = receiver.deficit - inserted
                    total_redistributed = total_redistributed + inserted
                end
            end
            
            -- Return any leftover ammo to donor
            if remaining_ammo > 0 then
                give_ammo_to_turret(donor.turret_inv, ammo_type, remaining_ammo)
            end
        end
        
        ::continue_donor::
    end
    
    return total_redistributed
end

-- HELPER: Remove ammo from a turret
function remove_ammo_from_turret(turret_inv, ammo_type, amount)
    local removed = 0
    
    if turret_inv.inventory then
        for i = 1, #turret_inv.inventory do
            if removed >= amount then break end
            
            local stack = turret_inv.inventory[i]
            if stack.valid_for_read and stack.name == ammo_type then
                local to_remove = math.min(stack.count, amount - removed)
                stack.count = stack.count - to_remove
                removed = removed + to_remove
                
                if stack.count == 0 then
                    stack.clear()
                end
            end
        end
    end
    
    return removed
end

-- HELPER: Give ammo to a turret
function give_ammo_to_turret(turret_inv, ammo_type, amount)
    if turret_inv.inventory and amount > 0 then
        return turret_inv.inventory.insert({name = ammo_type, count = amount})
    end
    return 0
end
  
-- LEGACY: Keep for compatibility but redirect to new system
function balance_ammo_group_improved(turrets, ammo_type)
    -- This function is kept for compatibility but now uses the new network system
    local network = {
        turrets = turrets,
        count = #turrets
    }
    
    return balance_turret_network(network, ammo_type)
end

