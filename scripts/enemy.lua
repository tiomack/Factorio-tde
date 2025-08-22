local excluded_types = {
    ["wall"] = true,
    ["straight-rail"] = true,
    ["curved-rail"] = true,
    ["decorative"] = true,
    ["tree"] = true,
    ["unit"] = true,
    ["corpse"] = true
}

local excluded_names = {
    ["stone-wall"] = true,
    -- add more if needed
}

require("wave")

-- Activate all spawners to ensure they produce biters
function activate_all_spawners(surface)
    local spawners = surface.find_entities_filtered({
      name = {"biter-spawner", "spitter-spawner"}
    })
    
    for _, spawner in pairs(spawners) do
      if spawner and spawner.valid then
        spawner.active = true
        -- Store in nest territories for defensive behavior
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
    end
    
    log("Activated " .. #spawners .. " existing spawners")
end

-- Simplified initial nest generation
function generate_initial_nests(surface)
    if not surface or not surface.valid then
      log("Invalid surface in generate_initial_nests")
      return
    end
    
    if not storage.tde or not storage.tde.nest_territories then
      log("Global TDE structure not ready for nest generation")
      return
    end
    
    -- Generate only a few nests initially in a small area
    local max_range = SAFE_ZONE_RADIUS+25  -- Very small initial range
    local nest_count = 0
    local max_nests = 30   -- More initial nests for better gameplay
    
    for x = -max_range, max_range, 25 do
      for y = -max_range, max_range, 25 do
        if nest_count >= max_nests then break end
        
        local distance = math.sqrt(x*x + y*y)
        
        -- Skip safe zone and place sparsely
        if distance > SAFE_ZONE_RADIUS and distance < max_range and math.random() < 0.4 then
          local position = {x = x + math.random(-12, 12), y = y + math.random(-12, 12)}
          
          local success, created = pcall(create_scaled_nest, surface, position, distance)
          if success and created then
            nest_count = nest_count + 1
          end
        end
      end
      if nest_count >= max_nests then break end
    end
    
    log("Initial nest generation completed: " .. nest_count .. " nests created")
end

function activate_defensive_nest(nest_data, attacker)
    local current_tick = game.tick
    
    -- Check cooldown
    if current_tick < (nest_data.spawn_cooldown or 0) then
      return
    end
    
    nest_data.spawn_cooldown = current_tick + 1200 -- 20 second cooldown
    nest_data.last_attacked = current_tick
    
    game.print("Nest under attack! Spawning defenders!", {r = 1, g = 0.5, b = 0})
    
    spawn_defensive_units(nest_data, attacker)
    alert_nearby_nests(nest_data.position, 150)
end

function spawn_defensive_units(nest_data, attacker)
    if not nest_data.spawner or not nest_data.spawner.valid then
      return
    end
    
    local surface = nest_data.spawner.surface
    local evolution = get_enemy_evolution()
    
    local distance_from_spawn = math.sqrt(nest_data.position.x^2 + nest_data.position.y^2)
    local distance_factor = math.min(1.5, distance_from_spawn / 1000)
    
    local base_count = 4 + math.floor(evolution * 5) + math.floor(distance_factor * 3)
    local composition = calculate_defensive_composition(evolution, base_count)
    
    -- CORREGIDO: Crear unit_group para comando en lugar de unidades individuales
    local unit_group = surface.create_unit_group({
      position = nest_data.position,
      force = game.forces.enemy
    })
    
    local units_spawned = 0
    
    for unit_type, count in pairs(composition) do
      for i = 1, count do
        local spawn_angle = math.random() * 2 * math.pi
        local spawn_distance = math.random(10, 18)
        local spawn_position = {
          x = nest_data.position.x + math.cos(spawn_angle) * spawn_distance,
          y = nest_data.position.y + math.sin(spawn_angle) * spawn_distance
        }
        
        local valid_position = surface.find_non_colliding_position(unit_type, spawn_position, 15, 2)
        if valid_position then
          local unit = surface.create_entity({
            name = unit_type,
            position = valid_position,
            force = game.forces.enemy
          })
          
          if unit and unit.valid then
            units_spawned = units_spawned + 1
            unit_group.add_member(unit)
          end
        end
      end
    end
    
    -- CORREGIDO: Dar comando al group, no a unidades individuales
    if units_spawned > 0 then
      if attacker and attacker.valid then
        unit_group.set_command({
          type = defines.command.attack,
          target = attacker,
          distraction = defines.distraction.by_anything
        })
      else
        -- Attack towards player base if no specific attacker
        local player_base = find_player_base_center()
        unit_group.set_command({
          type = defines.command.attack_area,
          destination = player_base or {x = 0, y = 0},
          radius = 75,
          distraction = defines.distraction.by_anything
        })
      end
      
      -- Create explosion effect
      surface.create_entity({
        name = "explosion",
        position = nest_data.position
      })
      
      log("Spawned " .. units_spawned .. " defensive units at nest")
    end
end

function calculate_defensive_composition(evolution, base_count)
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

function alert_nearby_nests(position, radius)
    local surface = game.surfaces[1]
    
    local nearby_spawners = surface.find_entities_filtered({
      area = {{position.x - radius, position.y - radius}, {position.x + radius, position.y + radius}},
      name = {"biter-spawner", "spitter-spawner"},
      force = "enemy"
    })
    
    for _, spawner in pairs(nearby_spawners) do
      if spawner.unit_number then
        local nest_data = storage.tde.nest_territories[spawner.unit_number]
        if nest_data and nest_data.is_defensive then
          local current_tick = game.tick
          
          if current_tick >= (nest_data.spawn_cooldown or 0) and math.random() < 0.3 then
            nest_data.spawn_cooldown = current_tick + 2400
            
            -- CORREGIDO: Pasar nest_data completo, no crear nuevo objeto
            spawn_defensive_units(nest_data, nil)
          end
        end
      end
    end
end
-- Ensure spawners remain active
function ensure_spawners_active()
    if not game.surfaces[1] or not game.surfaces[1].valid then return end
    
    local surface = game.surfaces[1]
    local spawners = surface.find_entities_filtered({
      name = {"biter-spawner", "spitter-spawner"}
    })
    
    local activated_count = 0
    for _, spawner in pairs(spawners) do
      if spawner and spawner.valid and not spawner.active then
        spawner.active = true
        activated_count = activated_count + 1
      end
    end
    
    if activated_count > 0 then
      log("Reactivated " .. activated_count .. " dormant spawners")
    end
end

-- Gradually expand nest field during gameplay
function expand_nest_field()
    if not game.surfaces[1] or not game.surfaces[1].valid then
      return
    end
    
    local surface = game.surfaces[1]
    local current_range = SAFE_ZONE_RADIUS + (storage.tde.wave_count * 20) -- Slower expansion
    
    -- Add only a few nests at a time to prevent performance issues
    local nest_count = 4 + math.random(0, 3) -- 4-7 nests per expansion
    
    for i = 1, nest_count do
      local angle = math.random() * 2 * math.pi
      local distance = current_range + math.random(-40, 40)
      
      if distance > SAFE_ZONE_RADIUS then
        local position = {
          x = math.cos(angle) * distance,
          y = math.sin(angle) * distance
        }
        
        -- Only create nest if area is not too crowded
        local nearby_spawners = surface.count_entities_filtered({
          name = {"biter-spawner", "spitter-spawner"},
          position = position,
          radius = 60
        })
        
        if nearby_spawners < 2 then -- Limit density
          local success = create_scaled_nest(surface, position, distance)
          if success then
            log("Created new nest at distance: " .. distance)
          end
        end
      end
    end
    
    log("Expanded nest field to range: " .. current_range .. " (attempted " .. nest_count .. " nests)")
end

