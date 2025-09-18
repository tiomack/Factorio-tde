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

-- ===== TECHNOLOGY CATEGORIZATION SYSTEM =====
function get_tech_category(tech_name)
    -- Define technology categories with different cost multipliers
    local categories = {
        -- Combat/Defense technologies - higher cost (more valuable)
        combat = {
            "military", "military-2", "military-3", "military-4",
            "gun-turret", "laser-turrets", "flamethrower-turrets",
            "physical-projectile-damage-1", "physical-projectile-damage-2", "physical-projectile-damage-3", "physical-projectile-damage-4", "physical-projectile-damage-5", "physical-projectile-damage-6", "physical-projectile-damage-7",
            "weapon-shooting-speed-1", "weapon-shooting-speed-2", "weapon-shooting-speed-3", "weapon-shooting-speed-4", "weapon-shooting-speed-5", "weapon-shooting-speed-6",
            "laser-turret-speed-1", "laser-turret-speed-2", "laser-turret-speed-3", "laser-turret-speed-4", "laser-turret-speed-5", "laser-turret-speed-6", "laser-turret-speed-7",
            "laser-turret-damage-1", "laser-turret-damage-2", "laser-turret-damage-3", "laser-turret-damage-4", "laser-turret-damage-5", "laser-turret-damage-6", "laser-turret-damage-7",
            "flamethrower-damage-1", "flamethrower-damage-2", "flamethrower-damage-3", "flamethrower-damage-4", "flamethrower-damage-5", "flamethrower-damage-6", "flamethrower-damage-7",
            "artillery", "artillery-shell-range-1", "artillery-shell-speed-1", "artillery-shell-damage-1", "artillery-shell-damage-2", "artillery-shell-damage-3", "artillery-shell-damage-4", "artillery-shell-damage-5", "artillery-shell-damage-6",
            "energy-weapons-damage-1", "energy-weapons-damage-2", "energy-weapons-damage-3", "energy-weapons-damage-4", "energy-weapons-damage-5", "energy-weapons-damage-6", "energy-weapons-damage-7",
            "stronger-explosives-1", "stronger-explosives-2", "stronger-explosives-3", "stronger-explosives-4", "stronger-explosives-5", "stronger-explosives-6", "stronger-explosives-7",
            "tde-enhanced-ammunition", "tde-armor-piercing"
        },
        -- Utility technologies - lower cost (less impactful on combat)
        utility = {
            "automation", "electronics", "logistics", "logistics-2", "logistics-3",
            "automated-construction", "construction-robotics", "logistic-robotics", "logistic-system",
            "solar-energy", "solar-panel-equipment", "personal-solar-panel-equipment",
            "night-vision-equipment", "personal-roboport-equipment", "personal-roboport-mk2-equipment",
            "toolbelt", "toolbelt-2", "toolbelt-3", "toolbelt-4", "toolbelt-5", "toolbelt-6", "toolbelt-7", "toolbelt-8", "toolbelt-9", "toolbelt-10",
            "landfill", "landfill-2", "landfill-3", "landfill-4", "landfill-5", "landfill-6", "landfill-7", "landfill-8", "landfill-9", "landfill-10",
            "gates", "gates-2", "gates-3", "gates-4", "gates-5", "gates-6", "gates-7", "gates-8", "gates-9", "gates-10",
            "light", "light-2", "light-3", "light-4", "light-5", "light-6", "light-7", "light-8", "light-9", "light-10",
            "inserter-capacity-bonus-1", "inserter-capacity-bonus-2", "inserter-capacity-bonus-3", "inserter-capacity-bonus-4", "inserter-capacity-bonus-5", "inserter-capacity-bonus-6", "inserter-capacity-bonus-7",
            "mining-productivity-1", "mining-productivity-2", "mining-productivity-3", "mining-productivity-4", "mining-productivity-5", "mining-productivity-6", "mining-productivity-7",
            "worker-robots-speed-1", "worker-robots-speed-2", "worker-robots-speed-3", "worker-robots-speed-4", "worker-robots-speed-5", "worker-robots-speed-6", "worker-robots-speed-7",
            "worker-robots-storage-1", "worker-robots-storage-2", "worker-robots-storage-3", "worker-robots-storage-4", "worker-robots-storage-5", "worker-robots-storage-6", "worker-robots-storage-7",
            "character-logistic-slots-1", "character-logistic-slots-2", "character-logistic-slots-3", "character-logistic-slots-4", "character-logistic-slots-5", "character-logistic-slots-6", "character-logistic-slots-7",
            "character-logistic-trash-slots-1", "character-logistic-trash-slots-2", "character-logistic-trash-slots-3", "character-logistic-trash-slots-4", "character-logistic-trash-slots-5", "character-logistic-trash-slots-6", "character-logistic-trash-slots-7"
        },
        -- Production technologies - medium cost
        production = {
            "steel-processing", "advanced-material-processing", "advanced-material-processing-2",
            "concrete", "concrete-2", "concrete-3", "concrete-4", "concrete-5", "concrete-6", "concrete-7", "concrete-8", "concrete-9", "concrete-10",
            "advanced-electronics", "advanced-electronics-2", "advanced-electronics-3", "advanced-electronics-4", "advanced-electronics-5", "advanced-electronics-6", "advanced-electronics-7", "advanced-electronics-8", "advanced-electronics-9", "advanced-electronics-10",
            "production-science-pack", "utility-science-pack", "space-science-pack",
            "assembling-machine-1", "assembling-machine-2", "assembling-machine-3",
            "oil-processing", "advanced-oil-processing", "coal-liquefaction",
            "plastics", "sulfur-processing", "battery", "explosives", "flying", "rocket-silo", "rocket-control-unit", "low-density-structure", "rocket-fuel", "rocket-part", "space-science-pack"
        }
    }
    
    -- Check each category
    for category, techs in pairs(categories) do
        for _, tech in pairs(techs) do
            if tech == tech_name then
                return category
            end
        end
    end
    
    -- Default category for unknown technologies
    return "standard"
end

function get_tech_cost_multiplier(category)
    local multipliers = {
        combat = 2.0,      -- Combat techs cost 2x more (harder to get)
        production = 1.5,  -- Production techs cost 1.5x more
        utility = 0.5,     -- Utility techs cost 0.5x less (easier to get)
        standard = 1.0     -- Standard cost for unknown techs
    }
    return multipliers[category] or 1.0
end

-- ===== TECHNOLOGY UNLOCK SYSTEM =====
function get_tech_kill_cost(tech)
    -- Use dynamic cost system with category-based multipliers
    local base_cost = get_next_research_cost()
    local category = get_tech_category(tech.name)
    local multiplier = get_tech_cost_multiplier(category)
    return math.floor(base_cost * multiplier)
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
  
    local total_cost = get_tech_kill_cost(tech)  -- Use categorized cost
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
      local category = get_tech_category(tech_name)
      local category_emoji = category == "combat" and "⚔️" or category == "utility" and "🛠️" or category == "production" and "🏭" or "📋"
      return true, string.format("Technology unlocked: %s %s (Cost: %d tokens, Category: %s)", category_emoji, tech_name, total_cost, category)
    else
      return false, string.format("Partial progress: Used %d tokens (%.0f%%)", tokens_to_use, new_progress * 100)
    end
end

