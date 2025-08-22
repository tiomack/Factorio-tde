-- ===== WORLD GENERATION =====
function setup_tower_defense_world()
    if not game.surfaces[1] or not game.surfaces[1].valid then
      log("No valid surface found during world setup")
      return
    end
    
    local surface = game.surfaces[1]
    
    -- Create small infinite resource patches (safe operation)
    local success1, error1 = pcall(create_small_infinite_patches, surface)
    if not success1 then
      log("Error creating resource patches: " .. tostring(error1))
    end
    
    -- Clear safe zone first
    local success2, error2 = pcall(clear_safe_zone, surface)
    if not success2 then
      log("Error clearing safe zone: " .. tostring(error2))
    end
    
    -- Generate initial nest field (reduced scope for better performance)
    local success3, error3 = pcall(generate_initial_nests, surface)
    if not success3 then
      log("Error generating initial nests: " .. tostring(error3))
    end
    
    -- Activate existing spawners
    activate_all_spawners(surface)
end

function create_small_infinite_patches(surface)
    if not surface or not surface.valid then
      log("Invalid surface in create_small_infinite_patches")
      return
    end
    
    if not storage.tde or not storage.tde.infinite_resources then
      log("Global TDE structure not ready for infinite resources")
      return
    end
    local tempFactor = settings.global["tde-resource-amount"].value / 2000000
    
    local resources = {
      {name = "iron-ore", pos = {x = 20, y = 0}, amount = 2000000*tempFactor},
      {name = "copper-ore", pos = {x = -20, y = 0}, amount = 2000000*tempFactor},
      {name = "coal", pos = {x = 0, y = 20}, amount = 1500000*tempFactor},
      {name = "stone", pos = {x = 0, y = -20}, amount = 1000000*tempFactor},
      {name = "uranium-ore", pos = {x = 30, y = 30}, amount = 800000*tempFactor}
    }
    
    -- Create oil separately with different handling
    local oil_success, oil = pcall(function()
      return surface.create_entity({
        name = "crude-oil",
        position = {x = -30, y = -30},
        amount = 50000000*tempFactor
      })
    end)
    
    if oil_success and oil and oil.valid then
      local oil_id = oil.unit_number
      if oil_id then
        storage.tde.infinite_resources[oil_id] = {
          entity = oil,
          base_amount = 50000000*tempFactor,
          resource_name = "crude-oil",
          is_oil = true
        }
        log("Created oil patch successfully")
      else
        log("Oil entity has no unit_number")
      end
    else
      log("Failed to create oil entity")
    end
    
    -- Create resource patches
    for _, resource_info in pairs(resources) do
      for x = -1, 1 do
        for y = -1, 1 do
          local pos = {
            x = resource_info.pos.x + x,
            y = resource_info.pos.y + y
          }
          
          local success, resource = pcall(function()
            return surface.create_entity({
              name = resource_info.name,
              position = pos,
              amount = resource_info.amount
            })
          end)
          
          if success and resource and resource.valid then
            local resource_id = resource.unit_number
            if resource_id then
              storage.tde.infinite_resources[resource_id] = {
                entity = resource,
                base_amount = resource_info.amount,
                resource_name = resource_info.name
              }
            else
              log("Resource entity has no unit_number: " .. resource_info.name)
            end
          else
            log("Failed to create resource: " .. resource_info.name .. " at " .. pos.x .. "," .. pos.y)
          end
        end
      end
    end
    
    log("Resource patch creation completed")
end

-- Safe spawner creation without prototype access
function create_scaled_nest(surface, position, distance)
    if not surface or not surface.valid then
      return false
    end
    
    local valid_position = surface.find_non_colliding_position("biter-spawner", position, 15, 1)
    if not valid_position then return false end
    
    -- Mix of biter and spitter spawners (70% biter, 30% spitter)
    local spawner_type = "biter-spawner"
    if math.random() < 0.3 then
      spawner_type = "spitter-spawner"
    end
    
    local success, spawner = pcall(function()
      return surface.create_entity({
        name = spawner_type,
        position = valid_position,
        force = "enemy"
      })
    end)
    
    if success and spawner and spawner.valid then
      -- Use fixed HP bonus instead of prototype access
      local base_hp = 500 -- Fixed base HP for spawners
      local hp_bonus = math.min(distance / 10, MAX_DISTANCE_HP / 10)
      local new_health = math.min(base_hp + hp_bonus, spawner.health + hp_bonus)
      spawner.health = new_health
      
      -- IMPORTANT: Make spawner active
      spawner.active = true
      
      -- Store for tracking with defensive capability
      if storage.tde and storage.tde.nest_territories then
        storage.tde.nest_territories[spawner.unit_number] = {
          spawner = spawner,
          position = valid_position,
          distance = distance,
          hp_bonus = hp_bonus,
          is_defensive = true,  -- Enable defensive spawning
          spawn_cooldown = 0
        }
      end
      
      return true
    end
    
    return false
end

function clear_safe_zone(surface)
    if not surface or not surface.valid then
      log("Invalid surface in clear_safe_zone")
      return
    end
    
    local success, enemies = pcall(function()
      return surface.find_entities_filtered({
        area = {{-SAFE_ZONE_RADIUS, -SAFE_ZONE_RADIUS}, {SAFE_ZONE_RADIUS, SAFE_ZONE_RADIUS}},
        force = "enemy"
      })
    end)
    
    if success and enemies then
      local cleared_count = 0
      for _, enemy in pairs(enemies) do
        if enemy and enemy.valid then
          local destroy_success = pcall(function() enemy.destroy() end)
          if destroy_success then
            cleared_count = cleared_count + 1
          end
        end
      end
      log("Cleared " .. cleared_count .. " enemies from safe zone")
    else
      log("Failed to find enemies in safe zone")
    end
end