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
    
    local ammo_type = get_turret_ammo_type(turret)
    if ammo_type then
      storage.tde.global_turrets[turret.unit_number] = {
        entity = turret,
        ammo_type = ammo_type,
        position = turret.position
        -- Note: No player tracking - all turrets contribute to the same objective
        -- regardless of who placed them (multiplayer-friendly)
      }
      log("Registered turret " .. turret.name .. " at " .. turret.position.x .. "," .. turret.position.y .. " (needs " .. ammo_type .. ")")
      
      -- FIXED: Check setting before showing messages
      if settings.global["tde-show-ammo-messages"].value then
        game.print("Turret registered: " .. turret.name .. " (needs " .. ammo_type .. ")", {r = 0, g = 1, b = 0.5})
      end
    else
      log("Turret " .. turret.name .. " doesn't need ammo - not registered")
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
    if turret.name == "gun-turret" then
      return "firearm-magazine"
    elseif turret.name == "laser-turret" then
      return nil -- Laser turrets don't need ammo
    elseif turret.name == "flamethrower-turret" then
      return nil -- Flamethrower turrets use fluid, not ammo
    end
    return nil
end
  
-- FIXED: Completely rewritten ammo distribution system to prevent ammo loss
function process_ammo_distribution()
    if game.tick % 180 ~= 0 then return end -- Every 3 seconds
    
    if not storage.tde or not storage.tde.master_ammo_chests or not storage.tde.global_turrets then
      return
    end
    
    -- STEP 1: Clean up invalid entities first
    local valid_turret_count = 0
    local valid_turrets = {}
    
    for turret_id, turret_data in pairs(storage.tde.global_turrets) do
      if turret_data.entity and turret_data.entity.valid and turret_data.ammo_type then
        valid_turret_count = valid_turret_count + 1
        table.insert(valid_turrets, turret_data)
      else
        storage.tde.global_turrets[turret_id] = nil
      end
    end
    
    -- STEP 2: Clean up invalid chests
    local valid_chests = {}
    local chest_count = 0
    
    for chest_id, chest_data in pairs(storage.tde.master_ammo_chests) do
      if chest_data.entity and chest_data.entity.valid then
        chest_count = chest_count + 1
        table.insert(valid_chests, chest_data)
      else
        storage.tde.master_ammo_chests[chest_id] = nil
      end
    end
    
    -- If no valid components, exit early
    if valid_turret_count == 0 or chest_count == 0 then
      if game.tick % 3600 == 0 then -- Debug every minute
        log("MAC System: " .. chest_count .. " chests, " .. valid_turret_count .. " turrets found - skipping distribution")
      end
      return
    end
    
    -- STEP 3: Collect available ammo from chests WITHOUT removing it yet
    local available_ammo = {}
    
    for _, chest_data in pairs(valid_chests) do
      local inventory = chest_data.entity.get_inventory(defines.inventory.chest)
      if inventory then
        for i = 1, #inventory do
          local stack = inventory[i]
          if stack.valid_for_read and is_ammunition(stack.name) then
            available_ammo[stack.name] = (available_ammo[stack.name] or 0) + stack.count
          end
        end
      end
    end
    
    -- STEP 4: Calculate turret needs without taking ammo yet
    local turret_needs = {}
    local total_needs = {}
    
    for _, turret_data in pairs(valid_turrets) do
      local inventory = turret_data.entity.get_inventory(defines.inventory.turret_ammo)
      if inventory then
        local current_ammo = 0
        for i = 1, #inventory do
          local stack = inventory[i]
          if stack.valid_for_read and stack.name == turret_data.ammo_type then
            current_ammo = current_ammo + stack.count
          end
        end
        
        -- Each turret wants at least 50 ammo, up to 200 max
        local desired_ammo = 50
        local max_ammo = 200
        local need = math.max(0, math.min(desired_ammo - current_ammo, max_ammo - current_ammo))
        
        if need > 0 then
          table.insert(turret_needs, {
            turret_data = turret_data,
            need = need,
            current = current_ammo
          })
          total_needs[turret_data.ammo_type] = (total_needs[turret_data.ammo_type] or 0) + need
        end
      end
    end
    
    -- STEP 5: Only proceed if we have both supply and demand
    local total_distributed = 0
    
    for ammo_type, total_needed in pairs(total_needs) do
      local available = available_ammo[ammo_type] or 0
      
      if available > 0 and total_needed > 0 then
        local to_distribute = math.min(available, total_needed)
        
        -- STEP 6: Remove ammo from chests (only what we'll actually distribute)
        local removed_ammo = 0
        for _, chest_data in pairs(valid_chests) do
          if removed_ammo >= to_distribute then break end
          
          local inventory = chest_data.entity.get_inventory(defines.inventory.chest)
          if inventory then
            for i = 1, #inventory do
              if removed_ammo >= to_distribute then break end
              
              local stack = inventory[i]
              if stack.valid_for_read and stack.name == ammo_type then
                local to_remove = math.min(stack.count, to_distribute - removed_ammo)
                stack.count = stack.count - to_remove
                removed_ammo = removed_ammo + to_remove
                
                if stack.count == 0 then
                  stack.clear()
                end
              end
            end
          end
        end
        
        -- STEP 7: Distribute the removed ammo to turrets
        local distributed_ammo = 0
        for _, need_data in pairs(turret_needs) do
          if distributed_ammo >= removed_ammo then break end
          if need_data.turret_data.ammo_type ~= ammo_type then goto continue end
          
          local to_give = math.min(need_data.need, removed_ammo - distributed_ammo)
          if to_give > 0 then
            local inventory = need_data.turret_data.entity.get_inventory(defines.inventory.turret_ammo)
            if inventory then
              local inserted = inventory.insert({name = ammo_type, count = to_give})
              distributed_ammo = distributed_ammo + inserted
              total_distributed = total_distributed + inserted
              
              -- If we couldn't insert all, put remainder back in chests
              local leftover = to_give - inserted
              if leftover > 0 then
                for _, chest_data in pairs(valid_chests) do
                  if leftover <= 0 then break end
                  local chest_inventory = chest_data.entity.get_inventory(defines.inventory.chest)
                  if chest_inventory then
                    local returned = chest_inventory.insert({name = ammo_type, count = leftover})
                    leftover = leftover - returned
                  end
                end
              end
            end
          end
          
          ::continue::
        end
        
        -- STEP 8: Return any undistributed ammo to chests
        local undistributed = removed_ammo - distributed_ammo
        if undistributed > 0 then
          for _, chest_data in pairs(valid_chests) do
            if undistributed <= 0 then break end
            local inventory = chest_data.entity.get_inventory(defines.inventory.chest)
            if inventory then
              local returned = inventory.insert({name = ammo_type, count = undistributed})
              undistributed = undistributed - returned
            end
          end
        end
        
        -- FIXED: Only show message if setting is enabled
        if distributed_ammo > 0 and settings.global["tde-show-ammo-messages"].value then
          game.print(string.format("Distributed %d %s to turrets", 
            distributed_ammo, ammo_type), {r = 0, g = 0.8, b = 1})
        end
      end
    end
    
    -- Debug output every minute (reduced frequency)
    if game.tick % 3600 == 0 and (chest_count > 0 or valid_turret_count > 0) then
      log(string.format("MAC System: %d chests, %d turrets, distributed %d ammo this cycle", 
        chest_count, valid_turret_count, total_distributed))
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

-- SIMPLIFIED: More balanced ammo redistribution system
function balance_ammo_between_turrets()
    if not storage.tde or not storage.tde.global_turrets then
      return
    end
    
    -- Only log if setting is enabled
    if settings.global["tde-show-ammo-messages"].value then
      log("TDE: Starting ammo balancing...")
    end
    
    -- Group turrets by ammo type
    local turret_groups = {}
    local total_turrets = 0
    
    for turret_id, turret_data in pairs(storage.tde.global_turrets) do
      if turret_data.entity and turret_data.entity.valid and turret_data.ammo_type then
        local ammo_type = turret_data.ammo_type
        turret_groups[ammo_type] = turret_groups[ammo_type] or {}
        table.insert(turret_groups[ammo_type], turret_data)
        total_turrets = total_turrets + 1
      else
        storage.tde.global_turrets[turret_id] = nil
      end
    end
    
    if total_turrets == 0 then
      return
    end
    
    -- Balance each group
    local total_redistributed = 0
    for ammo_type, turrets in pairs(turret_groups) do
      if #turrets > 1 then -- Only balance if there are multiple turrets
        local redistributed = balance_ammo_group_improved(turrets, ammo_type)
        total_redistributed = total_redistributed + redistributed
      end
    end
    
    -- FIXED: Only show message if setting is enabled and something was redistributed
    if total_redistributed > 0 and settings.global["tde-show-ammo-messages"].value then
      game.print(string.format("Rebalanced %d ammo among turrets", total_redistributed), {r = 0, g = 0.8, b = 1})
      log("TDE: Ammo balancing completed - redistributed " .. total_redistributed .. " ammo")
    end
end
  
-- IMPROVED: Better balancing algorithm that prevents ammo loss
function balance_ammo_group_improved(turrets, ammo_type)
    local turret_inventories = {}
    local total_ammo = 0
    
    -- Step 1: Collect ammo information from all turrets
    for _, turret_data in pairs(turrets) do
      if turret_data.entity and turret_data.entity.valid then
        local inventory = turret_data.entity.get_inventory(defines.inventory.turret_ammo)
        if inventory then
          local ammo_count = 0
          
          -- Count ammo in this turret
          for i = 1, #inventory do
            local stack = inventory[i]
            if stack.valid_for_read and stack.name == ammo_type then
              ammo_count = ammo_count + stack.count
            end
          end
          
          table.insert(turret_inventories, {
            turret_data = turret_data,
            inventory = inventory,
            current_ammo = ammo_count
          })
          total_ammo = total_ammo + ammo_count
        end
      end
    end
    
    if #turret_inventories < 2 or total_ammo == 0 then
      return 0 -- Not enough turrets or ammo to balance
    end
    
    -- Step 2: Calculate target distribution (more conservative)
    local target_per_turret = math.floor(total_ammo / #turret_inventories)
    local max_difference_threshold = 30 -- Only balance if difference > 30
    
    local max_ammo = 0
    local min_ammo = math.huge
    
    for _, turret_inv in pairs(turret_inventories) do
      max_ammo = math.max(max_ammo, turret_inv.current_ammo)
      min_ammo = math.min(min_ammo, turret_inv.current_ammo)
    end
    
    -- Only balance if there's a significant imbalance
    if (max_ammo - min_ammo) <= max_difference_threshold then
      return 0
    end
    
    -- Step 3: Collect excess ammo from turrets with too much
    local excess_ammo = {}
    local redistributed = 0
    
    for _, turret_inv in pairs(turret_inventories) do
      if turret_inv.current_ammo > target_per_turret + 10 then -- Allow 10 ammo buffer
        local excess = turret_inv.current_ammo - target_per_turret
        local removed = 0
        
        -- Remove excess ammo
        for i = 1, #turret_inv.inventory do
          if removed >= excess then break end
          
          local stack = turret_inv.inventory[i]
          if stack.valid_for_read and stack.name == ammo_type then
            local to_remove = math.min(excess - removed, stack.count)
            
            table.insert(excess_ammo, {name = ammo_type, count = to_remove})
            stack.count = stack.count - to_remove
            removed = removed + to_remove
            redistributed = redistributed + to_remove
            
            if stack.count == 0 then
              stack.clear()
            end
          end
        end
      end
    end
    
    -- Step 4: Distribute excess to turrets with too little
    for _, turret_inv in pairs(turret_inventories) do
      if turret_inv.current_ammo < target_per_turret - 10 and #excess_ammo > 0 then -- Allow 10 ammo buffer
        local needed = target_per_turret - turret_inv.current_ammo
        
        -- Give ammo from excess pool
        for i = #excess_ammo, 1, -1 do
          if needed <= 0 then break end
          
          local ammo_item = excess_ammo[i]
          local to_give = math.min(needed, ammo_item.count)
          local inserted = turret_inv.inventory.insert({name = ammo_item.name, count = to_give})
          
          ammo_item.count = ammo_item.count - inserted
          needed = needed - inserted
          
          if ammo_item.count == 0 then
            table.remove(excess_ammo, i)
          end
        end
      end
    end
    
    -- Step 5: Return any leftover ammo to any available turret
    for _, leftover_item in pairs(excess_ammo) do
      if leftover_item.count > 0 then
        for _, turret_inv in pairs(turret_inventories) do
          if leftover_item.count <= 0 then break end
          
          local inserted = turret_inv.inventory.insert({name = leftover_item.name, count = leftover_item.count})
          leftover_item.count = leftover_item.count - inserted
        end
      end
    end
    
    log("TDE: Redistributed " .. redistributed .. " " .. ammo_type .. " ammo among " .. #turret_inventories .. " turrets")
    return redistributed
end

