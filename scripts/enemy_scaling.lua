-- ===== ENEMY SCALING MODULE =====
-- Centralized enemy scaling, HP calculations, boss modifications, and evolution logic
-- VERSION 5.2.0 - MODULAR ENEMY SCALING SYSTEM

-- Enemy tier definitions for HP scaling
local ENEMY_TIERS = {
    ["small-biter"] = 1,
    ["medium-biter"] = 2,
    ["big-biter"] = 3,
    ["behemoth-biter"] = 4,
    ["small-spitter"] = 1,
    ["medium-spitter"] = 2,
    ["big-spitter"] = 3,
    ["behemoth-spitter"] = 4,
    ["vulkanus-biter"] = 2,
    ["vulkanus-spitter"] = 2,
    ["pentapod"] = 1,
    ["stomper"] = 1,
    ["demolisher"] = 3
}

-- Boss HP scaling configuration
local BOSS_SCALING_CONFIG = {
    -- Vanilla boss scaling
    vanilla = {
        base_hp = 1000,
        progression_multiplier = 1500,
        quadratic_multiplier = 250,
        tier_multiplier = 0.3 -- Each tier adds 30% base HP for vanilla bosses
    },
    -- Space Age boss scaling
    space_age = {
        base_hp = 1000,
        progression_multiplier = 1500,
        quadratic_multiplier = 250,
        tier_multiplier = 0.5 -- Each tier adds 50% base HP for Space Age bosses
    }
}

-- ===== ENEMY TIER SYSTEM =====

-- Get enemy tier for HP scaling
function get_enemy_tier(enemy_name)
    return ENEMY_TIERS[enemy_name] or 1
end

-- Get enemies by tier
function get_enemies_by_tier(tier)
    local result = {}
    for name, value in pairs(ENEMY_TIERS) do
        if value == tier then
            table.insert(result, name)
        end
    end
    return result
end

-- ===== ENEMY EVOLUTION SYSTEM =====

-- Get enemy evolution factor with fallback
function get_enemy_evolution()
    local success, evolution = pcall(function()
        return game.forces.enemy.get_evolution_factor()
    end)
    if success and evolution then
        return evolution
    else
        -- Fallback calculation based on time if API fails
        local ticks = game.tick or 0
        return math.min(1, ticks / (60 * 60 * 60)) -- 1 hour to max
    end
end

-- ===== BOSS HP SCALING SYSTEM =====

-- Calculate boss HP multiplier based on wave number and enemy tier
function calculate_boss_hp_multiplier(wave_number, enemy_tier, is_space_age_boss)
    local boss_wave_number = math.floor(wave_number / (storage.tde.BOSS_EVERY or 10))
    
    if boss_wave_number <= 0 then
        return 1 -- No scaling for first boss wave
    end
    
    local config = is_space_age_boss and BOSS_SCALING_CONFIG.space_age or BOSS_SCALING_CONFIG.vanilla
    
    -- Progressive scaling formula with tier consideration
    -- Formula: base_hp + (boss_wave_number - 1) * progression_multiplier + (boss_wave_number - 1) * (boss_wave_number - 1) * quadratic_multiplier
    local progression = config.base_hp + 
                       (boss_wave_number - 1) * config.progression_multiplier + 
                       (boss_wave_number - 1) * (boss_wave_number - 1) * config.quadratic_multiplier
    
    -- Apply tier multiplier
    local tier_multiplier = 1 + (enemy_tier - 1) * config.tier_multiplier
    
    return progression * tier_multiplier
end

-- Apply boss HP scaling to a unit
function apply_boss_hp_scaling(unit, wave_number, is_boss, boss_kill_value)
    if not unit or not unit.valid or not is_boss then
        return
    end
    
    local base_hp = unit.health
    local enemy_tier = get_enemy_tier(unit.name)
    
    -- Check if this is a Space Age boss
    local is_space_age_boss = false
    if space_age and space_age.is_space_age_available then
        local boss_enemy, planet_data = space_age.get_boss_enemy_type()
        if unit.name == boss_enemy and planet_data then
            is_space_age_boss = true
        end
    end
    
    -- Calculate HP multiplier
    local hp_multiplier = calculate_boss_hp_multiplier(wave_number, enemy_tier, is_space_age_boss)
    local final_hp = base_hp * (hp_multiplier / base_hp)
    
    -- Apply the HP scaling
    unit.health = final_hp
    
    -- Store boss kill value for rewards
    local unit_id = unit.unit_number
    if unit_id and storage.tde and storage.tde.nest_territories then
        storage.tde.nest_territories[unit_id] = {
            is_boss = true,
            kill_value = boss_kill_value or 100
        }
    end
    
    -- Log the boss creation
    local boss_type = is_space_age_boss and "Space Age" or "vanilla"
    log(string.format("TDE: Created %s boss with %.0f HP (wave %d, tier %d)", 
        boss_type, final_hp, wave_number, enemy_tier))
    
    return final_hp
end

-- ===== ENEMY HP SCALING SYSTEM =====

-- Calculate regular enemy HP scaling (non-boss)
function calculate_enemy_hp_scaling(enemy_name, wave_number, evolution)
    local base_hp = 100 -- Default base HP
    local enemy_tier = get_enemy_tier(enemy_name)
    
    -- Get base HP from entity prototype if available
    local success, entity_prototype = pcall(function()
        return game.entity_prototypes[enemy_name]
    end)
    if success and entity_prototype then
        base_hp = entity_prototype.max_health or base_hp
    end
    
    -- Apply wave-based scaling
    local wave_multiplier = 1 + (wave_number * 0.1) -- 10% increase per wave
    
    -- Apply evolution-based scaling
    local evolution_multiplier = 1 + (evolution * 0.5) -- 50% increase at max evolution
    
    -- Apply tier-based scaling
    local tier_multiplier = 1 + (enemy_tier - 1) * 0.2 -- 20% increase per tier
    
    local final_hp = base_hp * wave_multiplier * evolution_multiplier * tier_multiplier
    
    return final_hp
end

-- Apply HP scaling to a regular enemy unit
function apply_enemy_hp_scaling(unit, wave_number, evolution)
    if not unit or not unit.valid then
        return
    end
    
    local final_hp = calculate_enemy_hp_scaling(unit.name, wave_number, evolution)
    unit.health = final_hp
    
    return final_hp
end

-- ===== WAVE COMPOSITION SCALING =====

-- Calculate wave composition based on evolution
function calculate_wave_composition(base_count, evolution)
    local composition = {}
    
    if evolution < 0.2 then
        composition["small-biter"] = math.floor(base_count * 0.6)
        composition["small-spitter"] = math.floor(base_count * 0.4)
    elseif evolution < 0.5 then
        composition["small-biter"] = math.floor(base_count * 0.2)
        composition["medium-biter"] = math.floor(base_count * 0.4)
        composition["medium-spitter"] = math.floor(base_count * 0.4)
    elseif evolution < 0.8 then
        composition["medium-biter"] = math.floor(base_count * 0.2)
        composition["big-biter"] = math.floor(base_count * 0.4)
        composition["big-spitter"] = math.floor(base_count * 0.4)
    else
        composition["big-biter"] = math.floor(base_count * 0.3)
        composition["behemoth-biter"] = math.floor(base_count * 0.4)
        composition["behemoth-spitter"] = math.floor(base_count * 0.3)
    end
    
    return composition
end

-- Calculate defensive spawn composition
function calculate_defensive_composition(evolution, base_count)
    local composition = {}
    
    if evolution < 0.2 then
        composition["small-biter"] = math.floor(base_count * 0.7)
        composition["small-spitter"] = math.floor(base_count * 0.3)
    elseif evolution < 0.5 then
        composition["small-biter"] = math.floor(base_count * 0.3)
        composition["medium-biter"] = math.floor(base_count * 0.5)
        composition["medium-spitter"] = math.floor(base_count * 0.2)
    elseif evolution < 0.8 then
        composition["medium-biter"] = math.floor(base_count * 0.3)
        composition["big-biter"] = math.floor(base_count * 0.5)
        composition["big-spitter"] = math.floor(base_count * 0.2)
    else
        composition["big-biter"] = math.floor(base_count * 0.4)
        composition["behemoth-biter"] = math.floor(base_count * 0.5)
        composition["behemoth-spitter"] = math.floor(base_count * 0.1)
    end
    
    return composition
end

-- ===== UTILITY FUNCTIONS =====

-- Get scaling information for debugging/testing
function get_scaling_info(enemy_name, wave_number, evolution)
    local tier = get_enemy_tier(enemy_name)
    local base_hp = 100
    
    -- Get base HP from entity prototype if available
    local success, entity_prototype = pcall(function()
        return game.entity_prototypes[enemy_name]
    end)
    if success and entity_prototype then
        base_hp = entity_prototype.max_health or base_hp
    end
    
    local regular_hp = calculate_enemy_hp_scaling(enemy_name, wave_number, evolution)
    local boss_hp_vanilla = calculate_boss_hp_multiplier(wave_number, tier, false)
    local boss_hp_space_age = calculate_boss_hp_multiplier(wave_number, tier, true)
    
    return {
        enemy_name = enemy_name,
        tier = tier,
        base_hp = base_hp,
        regular_hp = regular_hp,
        boss_hp_vanilla = boss_hp_vanilla,
        boss_hp_space_age = boss_hp_space_age,
        wave_number = wave_number,
        evolution = evolution
    }
end

-- ===== MODULE EXPORTS =====
-- Return the module interface
return {
    -- Enemy tier system
    get_enemy_tier = get_enemy_tier,
    get_enemies_by_tier = get_enemies_by_tier,
    
    -- Evolution system
    get_enemy_evolution = get_enemy_evolution,
    
    -- Boss scaling system
    calculate_boss_hp_multiplier = calculate_boss_hp_multiplier,
    apply_boss_hp_scaling = apply_boss_hp_scaling,
    
    -- Enemy scaling system
    calculate_enemy_hp_scaling = calculate_enemy_hp_scaling,
    apply_enemy_hp_scaling = apply_enemy_hp_scaling,
    
    -- Wave composition system
    calculate_wave_composition = calculate_wave_composition,
    calculate_defensive_composition = calculate_defensive_composition,
    
    -- Utility functions
    get_scaling_info = get_scaling_info,
    
    -- Configuration (read-only)
    ENEMY_TIERS = ENEMY_TIERS,
    BOSS_SCALING_CONFIG = BOSS_SCALING_CONFIG
} 