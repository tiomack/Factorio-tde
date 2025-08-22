function create_base_heart()
    local surface = game.surfaces[1]
    if not surface then
        log("TDE: No surface found for base heart creation")
        return false
    end

    -- Check if base heart already exists
    local existing_heart = find_base_heart()
    if existing_heart then
        log("TDE: Base heart already exists, not creating new one")
        return true
    end

    -- Find a good position near spawn (0,0)
    local position = surface.find_non_colliding_position("tde-base-heart", {2, 3}, 200, 2)
    if not position then
        position = {2.0, 3.0}  -- Force spawn at origin if no other position found
    end

    local base_heart = surface.create_entity{
        name = "tde-base-heart",
        position = position,
        force = "player"
    }

    if base_heart and base_heart.valid then
        base_heart.health = BASE_HEART_MAX_HP
        storage.tde.base_heart = base_heart
        
        -- Add starting tokens to base heart based on settings
        if base_heart.get_inventory then
        local inventory = base_heart.get_inventory(defines.inventory.chest)
        if inventory then
            local config = get_research_settings()
            local starting_tokens = math.max(config.base_cost, storage.tde.total_kills or 10)
            inventory.insert{name = "tde-dead-biter", count = starting_tokens}
            log("TDE: Added " .. starting_tokens .. " starting tokens to base heart")
        end
        end
        
        log("TDE: Base heart created at " .. position.x .. "," .. position.y)
        game.print("Base Heart established! Defend it at all costs!", {r = 0, g = 1, b = 0})
        return true
    else
        log("TDE: Failed to create base heart")
        return false
    end
end
-- ===== BASE HEART FUNCTIONS =====
function find_base_heart()
    -- Look for base heart in global storage first
    if storage.tde and storage.tde.base_heart and storage.tde.base_heart.valid then
      return storage.tde.base_heart
    end
    
    -- Search all surfaces for base heart
    for _, surface in pairs(game.surfaces) do
      local hearts = surface.find_entities_filtered{name = "tde-base-heart"}
      if #hearts > 0 then
        storage.tde.base_heart = hearts[1]
        return hearts[1]
      end
    end
    return nil
  end
  
function add_tokens_to_base_heart(count)
    local base_heart = find_base_heart()
    if base_heart and base_heart.valid then
      local inventory = base_heart.get_inventory(defines.inventory.chest)
      if inventory then
        local inserted = inventory.insert{name = "tde-dead-biter", count = count}
        if inserted < count then
          -- If base heart is full, drop remainder around it
          base_heart.surface.spill_item_stack{
            position = base_heart.position,
            items = {name = "tde-dead-biter", count = count - inserted},
            enable_looted = true,
            force = "player"
          }
        end
        return true
      end
    end
    
    -- Fallback: drop at spawn if no base heart
    local surface = game.surfaces[1]
    if surface then
      surface.spill_item_stack{
        position = {0, 0},
        items = {name = "tde-dead-biter", count = count},
        enable_looted = true,
        force = "player"
      }
    end
    return false
end
  
function regenerate_base_heart_hp()
    local base_heart = find_base_heart()
    if base_heart and base_heart.valid then
      local current_hp = base_heart.health
      local max_hp = BASE_HEART_MAX_HP
      
      if current_hp < max_hp then
        local regen_amount = BASE_HEART_REGEN_RATE / 60  -- Per second conversion
        local new_hp = math.min(max_hp, current_hp + regen_amount)
        base_heart.health = new_hp
      end
    end
end
  
function check_base_heart_destroyed()
    local base_heart = find_base_heart()
    if not base_heart or not base_heart.valid then
      if not storage.tde.game_over then
        storage.tde.game_over = true
        game.print("GAME OVER! The Base Heart has been destroyed!", {r = 1, g = 0, b = 0})
        
        -- End game for all players
        for _, player in pairs(game.players) do
          if player.valid then
            player.print("=== TOWER DEFENSE FAILED ===", {r = 1, g = 0, b = 0})
            player.print("Your base heart was destroyed by the enemy!", {r = 1, g = 0.5, b = 0})
            player.print("Final wave reached: " .. storage.tde.wave_count, {r = 1, g = 1, b = 0})
          end
        end
        
        -- Stop wave spawning
        storage.tde.next_wave_tick = math.huge
      end
      return true
    end
    return false
end

