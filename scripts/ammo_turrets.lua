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
    
    game.print("Master Ammo Chest registered for global distribution!", {r = 0, g = 1, b = 0})
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
      game.print("Turret registered: " .. turret.name .. " (needs " .. ammo_type .. ")", {r = 0, g = 1, b = 0.5})
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
  
-- CORREGIDO: Sistema de distribución de munición SIMPLIFICADO - Volver a lógica que funcionaba
function process_ammo_distribution()
    if game.tick % 180 ~= 0 then return end -- Every 3 seconds
    
    if not storage.tde or not storage.tde.master_ammo_chests or not storage.tde.global_turrets then
      return
    end
    
    -- Limpiar torretas inválidas primero
    local valid_turret_count = 0
    for turret_id, turret_data in pairs(storage.tde.global_turrets) do
      if turret_data.entity and turret_data.entity.valid and turret_data.ammo_type then
        valid_turret_count = valid_turret_count + 1
      else
        storage.tde.global_turrets[turret_id] = nil
      end
    end
    
    -- Si no hay torretas válidas, no hacer nada (no tocar cofres)
    if valid_turret_count == 0 then
      -- Debug cada minuto
      if game.tick % 3600 == 0 then
        log("MAC System: No valid turrets found, skipping ammo collection")
      end
      return
    end
    
    local total_ammo = {}
    local chest_count = 0
    
    -- Recoger munición de Master Ammo Chests (solo si hay torretas válidas)
    for chest_id, chest_data in pairs(storage.tde.master_ammo_chests) do
      if chest_data.entity and chest_data.entity.valid then
        chest_count = chest_count + 1
        local inventory = chest_data.entity.get_inventory(defines.inventory.chest)
        
        if inventory then
          for i = 1, #inventory do
            local stack = inventory[i]
            if stack.valid_for_read and is_ammunition(stack.name) then
              total_ammo[stack.name] = (total_ammo[stack.name] or 0) + stack.count
              stack.clear()
            end
          end
        end
      else
        storage.tde.master_ammo_chests[chest_id] = nil
        log("Removed invalid Master Ammo Chest " .. chest_id)
      end
    end
    
    -- Debug output every minute
    if game.tick % 3600 == 0 and (chest_count > 0 or valid_turret_count > 0) then
      log(string.format("MAC System: %d chests, %d turrets registered", chest_count, valid_turret_count))
      for ammo_name, count in pairs(total_ammo) do
        log(string.format("  Collected %d %s", count, ammo_name))
      end
    end
    
    -- Distribuir munición (usar función original simplificada)
    if next(total_ammo) then
      distribute_ammo_to_turrets_simple(total_ammo)
    end
end
  
-- CORREGIDO: Función is_ammunition mejorada
function is_ammunition(item_name)
    if not item_name then return false end
    
    -- Hardcoded ammunition types para evitar problemas con prototypes
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
      ["flamethrower-ammo"] = true
    }
    
    return ammo_types[item_name] or false
end
  
function distribute_ammo_to_turrets_simple(total_ammo)
    if not total_ammo or not next(total_ammo) then
        return
    end

    -- First collect all valid turrets that need ammo
    local turrets_needing_ammo = {}
    for turret_id, turret_data in pairs(storage.tde.global_turrets) do
        if turret_data.entity and turret_data.entity.valid and turret_data.ammo_type then
            table.insert(turrets_needing_ammo, turret_data)
        end
    end

    if #turrets_needing_ammo == 0 then
        return
    end

    -- Distribute each ammo type
    for ammo_name, total_count in pairs(total_ammo) do
        local distributed_count = 0
        local turrets_to_feed = {}

        -- Find turrets that can use this ammo type
        for _, turret_data in pairs(turrets_needing_ammo) do
            if turret_data.ammo_type == ammo_name then
                table.insert(turrets_to_feed, turret_data)
            end
        end

        if #turrets_to_feed > 0 then
            -- Calculate how much ammo each turret should get (minimum 1)
            local ammo_per_turret = math.max(1, math.floor(total_count / #turrets_to_feed))
            
            -- First pass: distribute ammo_per_turret to each turret
            for _, turret_data in pairs(turrets_to_feed) do
                if distributed_count < total_count then
                    local inventory = turret_data.entity.get_inventory(defines.inventory.turret_ammo)
                    if inventory then
                        local to_insert = math.min(ammo_per_turret, total_count - distributed_count)
                        if to_insert > 0 then
                            local inserted = inventory.insert({name = ammo_name, count = to_insert})
                            distributed_count = distributed_count + inserted
                        end
                    end
                end
            end

            -- Second pass: distribute any remaining ammo
            local remaining_ammo = total_count - distributed_count
            if remaining_ammo > 0 then
                for _, turret_data in pairs(turrets_to_feed) do
                    if remaining_ammo <= 0 then break end
                    local inventory = turret_data.entity.get_inventory(defines.inventory.turret_ammo)
                    if inventory then
                        local inserted = inventory.insert({name = ammo_name, count = 1})
                        remaining_ammo = remaining_ammo - inserted
                        distributed_count = distributed_count + inserted
                    end
                end
            end

            -- Return any unused ammo to chests instead of losing it
            local unused_ammo = total_count - distributed_count
            if unused_ammo > 0 then
                for chest_id, chest_data in pairs(storage.tde.master_ammo_chests) do
                    if chest_data.entity and chest_data.entity.valid then
                        local inventory = chest_data.entity.get_inventory(defines.inventory.chest)
                        if inventory then
                            local inserted = inventory.insert({name = ammo_name, count = unused_ammo})
                            if inserted > 0 then
                                unused_ammo = unused_ammo - inserted
                                if unused_ammo <= 0 then break end
                            end
                        end
                    end
                end
            end

            -- Log the distribution result
            if distributed_count > 0 then
                game.print(string.format("Distributed %d %s to %d turrets", 
                    distributed_count, ammo_name, #turrets_to_feed), {r = 0, g = 0.8, b = 1})
            end
        else
            log("No compatible turrets found for " .. ammo_name .. " - this shouldn't happen")
        end
    end
end

-- ARREGLADO: Sistema de balanceo de munición entre torretas - SIMPLIFICADO Y FUNCIONAL
function balance_ammo_between_turrets()
    if not storage.tde or not storage.tde.global_turrets then
      return
    end
    
    log("TDE: Starting ammo balancing...")
    
    -- Agrupar torretas por tipo de munición
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
    
    log("TDE: Found " .. total_turrets .. " turrets to balance")
    
    -- Balancear cada grupo de torretas
    local total_redistributed = 0
    for ammo_type, turrets in pairs(turret_groups) do
      if #turrets > 1 then -- Solo balancear si hay más de 1 torreta
        local redistributed = balance_ammo_group_simple(turrets, ammo_type)
        total_redistributed = total_redistributed + redistributed
      end
    end
    
    if total_redistributed > 0 then
      game.print(string.format("Rebalanced %d ammo among turrets", total_redistributed), {r = 0, g = 0.8, b = 1})
      log("TDE: Ammo balancing completed - redistributed " .. total_redistributed .. " ammo")
    end
end
  
  -- NUEVA: Función de balanceo SIMPLE que SÍ funciona
function balance_ammo_group_simple(turrets, ammo_type)
    local turret_inventories = {}
    local total_ammo = 0
    
    -- Paso 1: Recopilar información de todas las torretas
    for _, turret_data in pairs(turrets) do
      if turret_data.entity and turret_data.entity.valid then
        local inventory = turret_data.entity.get_inventory(defines.inventory.turret_ammo)
        if inventory then
          local ammo_count = 0
          
          -- Contar munición total en esta torreta
          for i = 1, #inventory do
            local stack = inventory[i]
            if stack.valid_for_read then
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
      return 0 -- No hay suficientes torretas o munición para balancear
    end
    
    -- Paso 2: Calcular si hay desequilibrio significativo
    local max_ammo = 0
    local min_ammo = math.huge
    
    for _, turret_inv in pairs(turret_inventories) do
      max_ammo = math.max(max_ammo, turret_inv.current_ammo)
      min_ammo = math.min(min_ammo, turret_inv.current_ammo)
    end
    
    local difference = max_ammo - min_ammo
    log("TDE: Ammo difference: " .. difference .. " (max: " .. max_ammo .. ", min: " .. min_ammo .. ")")
    
    -- Solo balancear si hay una diferencia significativa (más de 15 municiones)
    if difference < 15 then
      log("TDE: Difference too small, skipping balance")
      return 0
    end
    
    -- Paso 3: Redistribución simple - mover munición de torretas con más a torretas con menos
    local redistributed = 0
    local target_ammo = math.floor(total_ammo / #turret_inventories)
    
    -- Recoger exceso de torretas que tienen más que el promedio + 5
    local excess_ammo_items = {}
    
    for _, turret_inv in pairs(turret_inventories) do
      if turret_inv.current_ammo > target_ammo + 5 then
        local excess = turret_inv.current_ammo - target_ammo
        local removed = 0
        
        -- Remover munición excedente
        for i = 1, #turret_inv.inventory do
          local stack = turret_inv.inventory[i]
          if stack.valid_for_read and removed < excess then
            local to_remove = math.min(excess - removed, stack.count)
            
            -- Guardar munición removida
            table.insert(excess_ammo_items, {
              name = stack.name,
              count = to_remove
            })
            
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
    
    -- Distribuir munición excedente a torretas que tienen menos que el promedio - 5
    for _, turret_inv in pairs(turret_inventories) do
      if turret_inv.current_ammo < target_ammo - 5 and #excess_ammo_items > 0 then
        local needed = target_ammo - turret_inv.current_ammo
        
        -- Dar munición de la reserva de exceso
        for i = #excess_ammo_items, 1, -1 do
          local ammo_item = excess_ammo_items[i]
          if needed > 0 and ammo_item.count > 0 then
            local to_give = math.min(needed, ammo_item.count)
            local inserted = turret_inv.inventory.insert({name = ammo_item.name, count = to_give})
            
            ammo_item.count = ammo_item.count - inserted
            needed = needed - inserted
            
            if ammo_item.count == 0 then
              table.remove(excess_ammo_items, i)
            end
          end
        end
      end
    end
    
    log("TDE: Redistributed " .. redistributed .. " " .. ammo_type .. " ammo")
    return redistributed
end
  
function find_compatible_turrets(ammo_name, turret_groups)
    local ammo_compatibility = {
      ["firearm-magazine"] = "firearm-magazine",
      ["piercing-rounds-magazine"] = "firearm-magazine",
      ["uranium-rounds-magazine"] = "firearm-magazine"
    }
    
    local compatible_type = ammo_compatibility[ammo_name]
    return (compatible_type and turret_groups[compatible_type]) or {}
end

