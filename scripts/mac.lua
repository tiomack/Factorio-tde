-- NUEVA: Reconstrucción MAC ROBUSTA que encuentra TODAS las entidades
function reconstruct_mac_system_robust()
    log("TDE: Starting ROBUST MAC reconstruction...")
    
    if not storage.tde then
      log("TDE: No storage.tde found during reconstruction")
      return
    end
    
    -- Limpiar registros existentes completamente
    storage.tde.master_ammo_chests = {}
    storage.tde.global_turrets = {}
    
    -- Verificar que game y surfaces estén listos
    if not game or not game.surfaces then
      log("TDE: Game not ready for MAC reconstruction")
      return
    end
    
    local total_chest_count = 0
    local total_turret_count = 0
    
    -- Buscar en TODAS las superficies con manejo de errores robusto
    for surface_name, surface in pairs(game.surfaces) do
      if surface and surface.valid then
        log("TDE: Scanning surface " .. surface_name .. " for MAC entities")
        
        -- MEJORADO: Buscar Master Ammo Chests con múltiples intentos
        local chest_count = 0
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
          total_chest_count = total_chest_count + chest_count
          log("TDE: Found " .. chest_count .. " Master Ammo Chests on " .. surface_name)
        else
          log("TDE: Error scanning for chests on " .. surface_name)
        end
        
        -- MEJORADO: Buscar torretas con detección exhaustiva
        local turret_count = 0
        local success_turrets, turrets = pcall(function()
          return surface.find_entities_filtered({
            type = {"ammo-turret", "electric-turret", "fluid-turret"}
          })
        end)
        
        if success_turrets and turrets then
          for _, turret in pairs(turrets) do
            if turret and turret.valid and turret.unit_number then
              local ammo_type = get_turret_ammo_type(turret)
              if ammo_type then -- Solo registrar torretas que necesitan munición
                storage.tde.global_turrets[turret.unit_number] = {
                  entity = turret,
                  ammo_type = ammo_type,
                  position = turret.position
                }
                turret_count = turret_count + 1
                log("TDE: Registered turret " .. turret.name .. " " .. turret.unit_number .. " at " .. turret.position.x .. "," .. turret.position.y)
              end
            end
          end
          total_turret_count = total_turret_count + turret_count
          log("TDE: Found " .. turret_count .. " turrets on " .. surface_name)
        else
          log("TDE: Error scanning for turrets on " .. surface_name)
        end
      end
    end
    
    log("TDE: ROBUST MAC reconstruction complete - " .. total_chest_count .. " chests, " .. total_turret_count .. " turrets total")
    
    -- Mensaje detallado al jugador
    if total_chest_count > 0 or total_turret_count > 0 then
      game.print(string.format("MAC system rebuilt: %d chests, %d turrets found and registered", 
        total_chest_count, total_turret_count), {r = 0, g = 1, b = 0})
    else
      game.print("No MAC entities found - place Master Ammo Chests and turrets!", {r = 1, g = 1, b = 0})
    end
end

-- NUEVA: Verificación automática e integridad del sistema MAC
function verify_and_fix_mac_system()
    if not storage.tde or not storage.tde.master_ammo_chests or not storage.tde.global_turrets then
      return
    end
    
    local invalid_chests = 0
    local invalid_turrets = 0
    
    -- Verificar chests y limpiar inválidos
    for chest_id, chest_data in pairs(storage.tde.master_ammo_chests) do
      if not chest_data.entity or not chest_data.entity.valid then
        invalid_chests = invalid_chests + 1
        storage.tde.master_ammo_chests[chest_id] = nil
      end
    end
    
    -- Verificar turrets y limpiar inválidos
    for turret_id, turret_data in pairs(storage.tde.global_turrets) do
      if not turret_data.entity or not turret_data.entity.valid then
        invalid_turrets = invalid_turrets + 1
        storage.tde.global_turrets[turret_id] = nil
      end
    end
    
    -- Si se perdieron muchas entidades, reconstruir automáticamente
    if invalid_chests > 3 or invalid_turrets > 10 then
      log("TDE: Too many invalid entities detected - auto-rebuilding MAC system")
      storage.tde.mac_needs_reconstruction = true
      game.print("MAC system integrity check failed - rebuilding automatically...", {r = 1, g = 0.8, b = 0})
    elseif invalid_chests > 0 or invalid_turrets > 0 then
      log(string.format("TDE: MAC integrity check - removed %d invalid chests, %d invalid turrets", 
        invalid_chests, invalid_turrets))
    end
end