-- ===== SETTINGS INTEGRATION =====
function get_research_settings()
    return {
      base_cost = settings.global["tde-research-base-cost"].value,
      increment_1 = settings.global["tde-research-increment-1"].value,
      threshold_1 = settings.global["tde-research-threshold-1"].value,
      increment_2 = settings.global["tde-research-increment-2"].value,
      threshold_2 = settings.global["tde-research-threshold-2"].value,
      increment_3 = settings.global["tde-research-increment-3"].value,
      threshold_3 = settings.global["tde-research-threshold-3"].value,
      increment_final = settings.global["tde-research-increment-final"].value,
      cost_multiplier = settings.global["tde-research-cost-multiplier"].value
    }
end
  
function calculate_dynamic_research_cost(research_count)
    local config = get_research_settings()
    local base_cost = config.base_cost
    
    local cost = base_cost
  
    -- Now increment the cost up to this specific research count
    for i = 1, research_count do
      if cost < config.threshold_1 then
        cost = cost + config.increment_1
      elseif cost < config.threshold_2 then
        cost = cost + config.increment_2
      elseif cost < config.threshold_3 then
        cost = cost + config.increment_3
      else
        cost = cost + config.increment_final
      end
    end
  
    return math.floor(cost * config.cost_multiplier)
end
  
function get_next_research_cost()
    local research_count = storage.tde.research_count or 0
    return calculate_dynamic_research_cost(research_count)
end
  
function check_cost_bracket_notification(old_cost, new_cost)
    local config = get_research_settings()
    local brackets = {
      {threshold = config.threshold_1, increment = config.increment_2, message = string.format("Research costs now increase by +%d per technology!", config.increment_2)},
      {threshold = config.threshold_2, increment = config.increment_3, message = string.format("Research costs now increase by +%d per technology!", config.increment_3)},
      {threshold = config.threshold_3, increment = config.increment_final, message = string.format("Research costs now increase by +%d per technology!", config.increment_final)}
    }
    
    for _, bracket in pairs(brackets) do
      if old_cost < bracket.threshold and new_cost >= bracket.threshold then
        game.print(string.format("🔬 RESEARCH MILESTONE! %s (Next tech: %d tokens)", 
          bracket.message, new_cost), {r = 0, g = 1, b = 1})
        return
      end
    end
end
  
function increment_research_count()
    if not storage.tde.research_count then
      storage.tde.research_count = 0
    end
  
    local old_cost = get_next_research_cost()
    storage.tde.research_count = storage.tde.research_count + 1
    local new_cost = get_next_research_cost()
  
    local config = get_research_settings()
    local unmultiplied_cost = new_cost / config.cost_multiplier
    local multiplier = unmultiplied_cost / config.base_cost
  
    game.difficulty_settings.technology_price_multiplier = multiplier
  
    game.print(string.format("🔬 Technology researched! Next research cost: %d tokens", new_cost), {r = 0, g = 0.8, b = 1})
    game.print(string.format("📈 Applied research multiplier: x%.2f", multiplier), {r = 0.6, g = 1, b = 0.6})
  
    check_cost_bracket_notification(old_cost, new_cost)
end

-- ===== TECHNOLOGY UNLOCK SYSTEM =====
function get_tech_kill_cost(tech)
    -- Use dynamic cost system instead of static costs
    return get_next_research_cost()
end
  
function unlock_technology_with_dynamic_cost(tech_name)
    local tech = game.forces.player.technologies[tech_name]
    if not tech then
      return false, "Technology not found: " .. tech_name
    end
    if tech.researched then
      return false, "Technology already researched: " .. tech_name
    end
  
    for _, prereq in pairs(tech.prerequisites) do
      if not prereq.researched then
        return false, string.format("Missing prerequisite: %s", prereq.name)
      end
    end
  
    local base_heart = find_base_heart()
    local available_tokens = 0
    local inventory = nil
  
    if base_heart and base_heart.valid then
      inventory = base_heart.get_inventory(defines.inventory.chest)
      if inventory then
        available_tokens = inventory.get_item_count("tde-dead-biter")
      end
    end
  
    local total_cost = get_next_research_cost()
    local current_progress = game.forces.player.research_progress
    local remaining_fraction = 1 - current_progress
    local required_tokens = math.ceil(total_cost * remaining_fraction)
  
    if available_tokens < 1 then
      return false, string.format("No tokens available! Need %d.", required_tokens)
    end
  
    local tokens_to_use = math.min(available_tokens, required_tokens)
    local added_progress = tokens_to_use / total_cost
    local new_progress = math.min(1, current_progress + added_progress)
    
    game.forces.player.research_progress = new_progress
    inventory.remove({name = "tde-dead-biter", count = tokens_to_use})
  
    if new_progress >= 1 then
      if game.forces.player.current_research ~= nil then
        game.forces.player.research_progress = 0
      end
      tech.researched = true
      increment_research_count()
      return true, string.format("Technology unlocked: %s (Cost: %d tokens)", tech_name, total_cost)
    else
      return false, string.format("Partial progress: Used %d tokens (%.0f%%)", tokens_to_use, new_progress * 100)
    end
end

