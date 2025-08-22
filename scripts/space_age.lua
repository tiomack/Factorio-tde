-- ===== SPACE AGE DLC INTEGRATION MODULE =====
-- Handles planet-specific enemies and wave system integration

-- Planet-specific enemy definitions with tier system
local PLANET_ENEMIES = {
    ["vulkanus"] = {
        name = "Vulkanus",
        tier = 2,
        normal_enemies = {
            "vulkanus-biter",
            "vulkanus-spitter"
        },
        boss_enemies = {
            "demolisher"
        },
        color = {r = 0.8, g = 0.2, b = 0.2} -- Reddish
    },
    ["gleba"] = {
        name = "Gleba", 
        tier = 1,
        normal_enemies = {
            "pentapod",
            "stomper"
        },
        boss_enemies = {
            -- Gleba enemies only appear in normal waves, not boss waves
        },
        color = {r = 0.2, g = 0.8, b = 0.2} -- Greenish (changed from cyan)
    }
}

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

-- Check if Space Age DLC is available - FIXED VERSION
function is_space_age_available()
    -- Multiple safe checks for Space Age DLC
    local checks = {
        -- Check 1: Check for Space Age surfaces
        function()
            if game and game.surfaces then
                for surface_name, _ in pairs(game.surfaces) do
                    if surface_name:find("vulkanus") or surface_name:find("gleba") then
                        return true
                    end
                end
            end
            return false
        end,
        
        -- Check 2: Check for Space Age entities using proper API
        function()
            if game then
                -- Check for Space Age specific entities using get_entity_by_tag
                local space_age_entities = {
                    "demolisher",
                    "pentapod", 
                    "stomper",
                    "vulkanus-biter",
                    "vulkanus-spitter"
                }
                
                for _, entity_name in pairs(space_age_entities) do
                    local success, entity = pcall(function()
                        return game.get_entity_by_tag(entity_name)
                    end)
                    if success and entity then
                        log("TDE: Space Age DLC detected via entity: " .. entity_name)
                        return true
                    end
                end
            end
            return false
        end,
        
        -- Check 3: Check for Space Age items using proper API
        function()
            if game then
                local space_age_items = {
                    "vulkanus-ore",
                    "gleba-ore"
                }
                
                for _, item_name in pairs(space_age_items) do
                    local success, item = pcall(function()
                        return game.get_item_by_tag(item_name)
                    end)
                    if success and item then
                        log("TDE: Space Age DLC detected via item: " .. item_name)
                        return true
                    end
                end
            end
            return false
        end
    }
    
    -- Try each check safely
    for i, check_func in ipairs(checks) do
        local success, result = pcall(check_func)
        if success and result then
            log("TDE: Space Age DLC detected via check " .. i)
            return true
        end
    end
    
    log("TDE: Space Age DLC not detected")
    return false
end

-- Get available enemy types based on visited planets
function get_available_enemy_types()
    local enemy_types = {
        -- Base game enemies (always available)
        normal = {
            "small-biter", "medium-biter", "big-biter", "behemoth-biter",
            "small-spitter", "medium-spitter", "big-spitter", "behemoth-spitter"
        },
        boss = {
            "behemoth-biter" -- Default boss
        }
    }
    
    -- Add planet-specific enemies if Space Age is available and planets have been visited
    if is_space_age_available() then
        local visited_planets = get_visited_planets()
        
        for planet_name, _ in pairs(visited_planets) do
            local planet_data = PLANET_ENEMIES[planet_name]
            if planet_data then
                -- Add normal enemies from this planet
                for _, enemy_name in pairs(planet_data.normal_enemies) do
                    local success, entity = pcall(function()
                        return game.get_entity_by_tag(enemy_name)
                    end)
                    if success and entity then
                        table.insert(enemy_types.normal, enemy_name)
                    end
                end
                
                -- Add boss enemies from this planet (only for planets that have boss enemies)
                if planet_data.boss_enemies and #planet_data.boss_enemies > 0 then
                    for _, enemy_name in pairs(planet_data.boss_enemies) do
                        local success, entity = pcall(function()
                            return game.get_entity_by_tag(enemy_name)
                        end)
                        if success and entity then
                            table.insert(enemy_types.boss, enemy_name)
                        end
                    end
                end
            end
        end
    end
    
    return enemy_types
end

-- Get boss enemy type based on visited planets
function get_boss_enemy_type()
    local enemy_types = get_available_enemy_types()
    
    -- Check for Vulkanus first (priority for boss waves) - Demolisher boss
    if is_space_age_available() and has_any_player_visited_planet("vulkanus") then
        local vulkanus_data = PLANET_ENEMIES["vulkanus"]
        for _, enemy_name in pairs(vulkanus_data.boss_enemies) do
            local success, entity = pcall(function()
                return game.get_entity_by_tag(enemy_name)
            end)
            if success and entity then
                return enemy_name, vulkanus_data
            end
        end
    end
    
    -- Default to behemoth-biter (no Gleba boss enemies)
    return "behemoth-biter", nil
end

-- Enhanced wave composition calculation with planet enemies
function calculate_enhanced_wave_composition(base_count, evolution)
    local composition = {}
    local enemy_types = get_available_enemy_types()
    
    -- Calculate base composition using vanilla enemies
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
    
    -- Add planet-specific enemies if available (only in normal waves, not boss waves)
    if is_space_age_available() then
        local visited_planets = get_visited_planets()
        local planet_enemy_count = math.floor(base_count * 0.2) -- Reduced to 20% for lower population
        
        for planet_name, _ in pairs(visited_planets) do
            local planet_data = PLANET_ENEMIES[planet_name]
            if planet_data then
                for _, enemy_name in pairs(planet_data.normal_enemies) do
                    local success, entity = pcall(function()
                        return game.get_entity_by_tag(enemy_name)
                    end)
                    if success and entity then
                        local enemy_count = math.floor(planet_enemy_count / #visited_planets)
                        if enemy_count > 0 then
                            composition[enemy_name] = (composition[enemy_name] or 0) + enemy_count
                        end
                    end
                end
            end
        end
    end
    
    return composition
end

-- Enhanced boss wave composition
function calculate_enhanced_boss_composition()
    local boss_enemy, planet_data = get_boss_enemy_type()
    local composition = {}
    
    -- Add ONLY the boss enemy (no escorts)
    composition[boss_enemy] = 1
    
    return composition, planet_data
end

-- Announce planet-specific waves
function announce_planet_wave(wave_number, is_boss, planet_data)
    if not planet_data then return end
    
    local wave_type = is_boss and "BOSS WAVE" or "Wave"
    local planet_name = planet_data.name
    local color = planet_data.color or {r = 1, g = 1, b = 1}
    
    if is_boss then
        game.print(string.format("%s %d! %s boss incoming!", wave_type, wave_number, planet_name), color)
    else
        game.print(string.format("%s %d incoming! %s enemies detected!", wave_type, wave_number, planet_name), color)
    end
end

-- Check for planet-specific surface names
function detect_planet_from_surface(surface)
    if not surface or not surface.name then return nil end
    
    local surface_name = surface.name:lower()
    
    -- Check for Space Age planet names
    if surface_name:find("vulkanus") then
        return "vulkanus"
    elseif surface_name:find("gleba") then
        return "gleba"
    elseif surface_name:find("nauvis") then
        return "nauvis"
    end
    
    return nil
end

-- Initialize Space Age integration
function initialize_space_age_integration()
    -- Use pcall to safely check for Space Age
    local success, has_space_age = pcall(function()
        return is_space_age_available()
    end)
    
    if success and has_space_age then
        log("TDE: Space Age DLC detected - enabling planet-specific enemies")
        
        -- Check all existing surfaces for planet detection
        for surface_name, surface in pairs(game.surfaces) do
            local planet = detect_planet_from_surface(surface)
            if planet and planet ~= "nauvis" then
                log("TDE: Detected planet surface: " .. surface_name .. " -> " .. planet)
                
                -- Mark this planet as visited by all current players
                for _, player in pairs(game.players) do
                    if player.valid then
                        track_planet_visit(player, planet)
                    end
                end
            end
        end
    else
        log("TDE: Space Age DLC not detected or not accessible - using vanilla enemies only")
    end
end

-- Export Space Age functions
return {
    is_space_age_available = is_space_age_available,
    get_available_enemy_types = get_available_enemy_types,
    get_boss_enemy_type = get_boss_enemy_type,
    calculate_enhanced_wave_composition = calculate_enhanced_wave_composition,
    calculate_enhanced_boss_composition = calculate_enhanced_boss_composition,
    announce_planet_wave = announce_planet_wave,
    detect_planet_from_surface = detect_planet_from_surface,
    initialize_space_age_integration = initialize_space_age_integration,
    get_enemy_tier = get_enemy_tier,
    get_enemies_by_tier = get_enemies_by_tier,
    PLANET_ENEMIES = PLANET_ENEMIES,
    ENEMY_TIERS = ENEMY_TIERS
} 