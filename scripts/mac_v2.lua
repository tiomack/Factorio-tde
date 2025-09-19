-- ===== TURRET CENTRAL NETWORK (TCN) SYSTEM =====
-- Master Ammo Chest as Cloud Storage for Turrets
-- Turrets consume ammo directly from MAC chests when needed
-- VERSION 3.0 - SIMPLIFIED CLOUD STORAGE

-- ===== SYSTEM CONFIGURATION =====
local TCN_CONFIG = {
    debug_mode = true,
    ammo_request_check_interval = 60, -- Check turrets every 1 second
    max_ammo_per_turret = 200, -- Maximum ammo a turret can request
    min_ammo_threshold = 10 -- Request ammo when below this amount
}

-- ===== AMMO DETECTION SYSTEM =====

-- Get ammo categories that a turret can use
local function get_turret_ammo_categories(entity)
    if not entity or not entity.valid then return nil end
    
    -- Check if entity has turret_ammo inventory
    local ammo_inventory = entity.get_inventory(defines.inventory.turret_ammo)
    if not ammo_inventory then return nil end
    
    local ammo_categories = {}
    
    -- Try to get prototype information
    local success, prototype = pcall(function()
        return entity.prototype
    end)
    
    if success and prototype and prototype.attack_parameters then
        local attack_params = prototype.attack_parameters
        if attack_params.ammo_categories then
            for _, category in pairs(attack_params.ammo_categories) do
                if category and category.name then
                    ammo_categories[category.name] = true
                elseif type(category) == "string" then
                    ammo_categories[category] = true
                end
            end
        elseif attack_params.ammo_category then
            if attack_params.ammo_category.name then
                ammo_categories[attack_params.ammo_category.name] = true
            elseif type(attack_params.ammo_category) == "string" then
                ammo_categories[attack_params.ammo_category] = true
            end
        end
    end
    
    -- Fallback based on turret type
    if next(ammo_categories) == nil then
        if entity.type == "ammo-turret" then
            ammo_categories["bullet"] = true
        elseif entity.type == "artillery-turret" then
            ammo_categories["artillery-shell"] = true
        else
            local ammo_inv = entity.get_inventory(defines.inventory.turret_ammo)
            if ammo_inv then
                ammo_categories["bullet"] = true
            end
        end
    end
    
    return next(ammo_categories) and ammo_categories or nil
end

-- Check if an item is ammunition and get its category
local function get_item_ammo_category(item_name)
    if not item_name then return nil end
    
    local success, prototype = pcall(function()
        return prototypes.item[item_name]
    end)
    
    if success and prototype then
        if prototype.ammo_category then
            if prototype.ammo_category.name then
                return prototype.ammo_category.name
            elseif type(prototype.ammo_category) == "string" then
                return prototype.ammo_category
            end
        end
        
        -- Fallback: manually check known ammo items
        local known_ammo = {
            ["firearm-magazine"] = "bullet",
            ["piercing-rounds-magazine"] = "bullet",
            ["uranium-rounds-magazine"] = "bullet",
            ["artillery-shell"] = "artillery-shell",
            ["cannon-shell"] = "cannon-shell",
            ["explosive-cannon-shell"] = "cannon-shell",
            ["uranium-cannon-shell"] = "cannon-shell",
            ["explosive-uranium-cannon-shell"] = "cannon-shell"
        }
        
        return known_ammo[item_name]
    end
    
    return nil
end

-- ===== ENTITY REGISTRY SYSTEM =====

-- Register a turret for TCN network
local function register_turret(entity)
    if not entity or not entity.valid or not entity.unit_number then
        return false
    end
    
    local success, ammo_categories = pcall(get_turret_ammo_categories, entity)
    if not success or not ammo_categories then
        return false
    end
    
    if not storage.tde then
        storage.tde = {}
    end
    if not storage.tde.global_turrets then
        storage.tde.global_turrets = {}
    end
    
    -- Convert ammo_categories to ammo_types array for compatibility
    local ammo_types = {}
    for category_name, _ in pairs(ammo_categories) do
        table.insert(ammo_types, category_name)
    end
    
    storage.tde.global_turrets[entity.unit_number] = {
        entity = entity,
        ammo_types = ammo_types,
        position = entity.position,
        surface = entity.surface.name,
        registered_tick = game.tick,
        last_ammo_check = 0
    }
    
    if TCN_CONFIG.debug_mode then
        local debug_msg = string.format("TCN: Registered turret %s (%d) - categories: %s", 
            entity.name, entity.unit_number, table.concat(ammo_types, ", "))
        log(debug_msg)
        game.print(debug_msg, {r = 0, g = 1, b = 1})
    end
    
    return true
end

-- Register a master ammo chest (MAC)
local function register_master_chest(entity)
    if not entity or not entity.valid or not entity.unit_number then
        return false
    end
    
    local chest_inventory = entity.get_inventory(defines.inventory.chest)
    if not chest_inventory then
        return false
    end
    
    if not storage.tde then
        storage.tde = {}
    end
    if not storage.tde.master_ammo_chests then
        storage.tde.master_ammo_chests = {}
    end
    
    storage.tde.master_ammo_chests[entity.unit_number] = {
        entity = entity,
        position = entity.position,
        surface = entity.surface.name,
        registered_tick = game.tick
    }
    
    if TCN_CONFIG.debug_mode then
        local debug_msg = string.format("TCN: Registered MAC chest %s (%d)", 
            entity.name, entity.unit_number)
        log(debug_msg)
        game.print(debug_msg, {r = 0, g = 1, b = 1})
    end
    
    return true
end

-- Unregister entities
local function unregister_turret(unit_number)
    if storage.tde and storage.tde.global_turrets and storage.tde.global_turrets[unit_number] then
        storage.tde.global_turrets[unit_number] = nil
        return true
    end
    return false
end

local function unregister_master_chest(unit_number)
    if storage.tde and storage.tde.master_ammo_chests and storage.tde.master_ammo_chests[unit_number] then
        storage.tde.master_ammo_chests[unit_number] = nil
        return true
    end
    return false
end

-- ===== CLOUD AMMO CONSUMPTION SYSTEM =====

-- Get total ammo count in a turret
local function get_turret_total_ammo(entity)
    local ammo_inv = entity.get_inventory(defines.inventory.turret_ammo)
    if not ammo_inv then return 0 end
    
    local total = 0
    for i = 1, #ammo_inv do
        local stack = ammo_inv[i]
        if stack and stack.valid_for_read then
            total = total + stack.count
        end
    end
    return total
end

-- Find and retrieve ammo from MAC chests for a specific category
local function get_ammo_from_mac_chests(ammo_category, requested_amount)
    if not storage.tde or not storage.tde.master_ammo_chests then
        return nil, 0
    end
    
    for unit_number, chest_data in pairs(storage.tde.master_ammo_chests) do
        if chest_data.entity and chest_data.entity.valid then
            local chest_inv = chest_data.entity.get_inventory(defines.inventory.chest)
            if chest_inv then
                local contents = chest_inv.get_contents()
                
                for item_id, count_data in pairs(contents) do
                    local item_name, item_count
                    
                    -- Handle different inventory formats
                    if type(item_id) == "string" then
                        item_name = item_id
                        item_count = count_data
                    elseif type(item_id) == "number" and type(count_data) == "table" then
                        if count_data.name and count_data.count then
                            item_name = count_data.name
                            item_count = count_data.count
                        else
                            goto continue_item
                        end
                    elseif type(item_id) == "table" and item_id.name then
                        item_name = item_id.name
                        item_count = count_data
                    else
                        goto continue_item
                    end
                    
                    if item_count > 0 then
                        local item_ammo_category = get_item_ammo_category(item_name)
                        if item_ammo_category == ammo_category then
                            local to_remove = math.min(item_count, requested_amount)
                            local removed = chest_inv.remove({name = item_name, count = to_remove})
                            
                            if removed > 0 then
                                if TCN_CONFIG.debug_mode then
                                    local debug_msg = string.format("TCN: Retrieved %d %s from MAC chest %d", 
                                        removed, item_name, unit_number)
                                    log(debug_msg)
                                    game.print(debug_msg, {r = 0, g = 1, b = 0})
                                end
                                return item_name, removed
                            end
                        end
                    end
                    
                    ::continue_item::
                end
            end
        else
            -- Clean up invalid chest
            storage.tde.master_ammo_chests[unit_number] = nil
        end
    end
    
    return nil, 0
end

-- Supply ammo to a turret from MAC chests when needed
local function supply_turret_ammo(turret_data)
    if not turret_data.entity or not turret_data.entity.valid then
        return false
    end
    
    local current_ammo = get_turret_total_ammo(turret_data.entity)
    
    -- Only supply ammo if below threshold
    if current_ammo >= TCN_CONFIG.min_ammo_threshold then
        return false
    end
    
    local ammo_inv = turret_data.entity.get_inventory(defines.inventory.turret_ammo)
    if not ammo_inv then return false end
    
    local ammo_supplied = false
    
    -- Try to supply ammo for each category this turret can use
    for _, ammo_category in pairs(turret_data.ammo_types) do
        local needed_ammo = TCN_CONFIG.max_ammo_per_turret - current_ammo
        if needed_ammo > 0 then
            local item_name, amount = get_ammo_from_mac_chests(ammo_category, needed_ammo)
            
            if item_name and amount > 0 then
                local inserted = ammo_inv.insert({name = item_name, count = amount})
                
                if inserted > 0 then
                    ammo_supplied = true
                    current_ammo = current_ammo + inserted
                    
                    if TCN_CONFIG.debug_mode then
                        local debug_msg = string.format("TCN: Supplied %d %s to turret %d (total now: %d)", 
                            inserted, item_name, turret_data.entity.unit_number, current_ammo)
                        log(debug_msg)
                        game.print(debug_msg, {r = 0, g = 1, b = 0.5})
                    end
                    
                    -- Put back any excess that couldn't be inserted
                    if inserted < amount then
                        -- Return excess to any available MAC chest
                        local returned = false
                        if storage.tde.master_ammo_chests then
                            for chest_unit, chest_data in pairs(storage.tde.master_ammo_chests) do
                                if chest_data.entity and chest_data.entity.valid then
                                    local chest_inv = chest_data.entity.get_inventory(defines.inventory.chest)
                                    if chest_inv then
                                        local excess = amount - inserted
                                        local returned_amount = chest_inv.insert({name = item_name, count = excess})
                                        if returned_amount > 0 then
                                            returned = true
                                            break
                                        end
                                    end
                                end
                            end
                        end
                        
                        if not returned and TCN_CONFIG.debug_mode then
                            local debug_msg = string.format("TCN: WARNING! Lost %d %s (couldn't return to MAC chest)", 
                                amount - inserted, item_name)
                            log(debug_msg)
                            game.print(debug_msg, {r = 1, g = 0, b = 0})
                        end
                    end
                    
                    -- Stop after successfully supplying one type of ammo
                    break
                end
            end
        end
    end
    
    return ammo_supplied
end

-- Process all turrets for ammo supply
local function process_turret_ammo_requests()
    if not storage.tde or not storage.tde.global_turrets then
        return
    end
    
    local current_tick = game.tick
    
    if not storage.tde.tcn_last_check then
        storage.tde.tcn_last_check = 0
    end
    
    -- Only check every interval
    if current_tick - storage.tde.tcn_last_check < TCN_CONFIG.ammo_request_check_interval then
        return
    end
    
    storage.tde.tcn_last_check = current_tick
    
    if TCN_CONFIG.debug_mode then
        local turret_count = 0
        for _ in pairs(storage.tde.global_turrets) do
            turret_count = turret_count + 1
        end
        
        local debug_msg = string.format("TCN: Checking %d turrets for ammo needs", turret_count)
        log(debug_msg)
        game.print(debug_msg, {r = 0, g = 0.8, b = 1})
    end
    
    local turrets_supplied = 0
    
    for unit_number, turret_data in pairs(storage.tde.global_turrets) do
        if turret_data.entity and turret_data.entity.valid then
            if supply_turret_ammo(turret_data) then
                turrets_supplied = turrets_supplied + 1
            end
        else
            -- Clean up invalid turret
            storage.tde.global_turrets[unit_number] = nil
        end
    end
    
    if TCN_CONFIG.debug_mode and turrets_supplied > 0 then
        local debug_msg = string.format("TCN: Supplied ammo to %d turrets", turrets_supplied)
        log(debug_msg)
        game.print(debug_msg, {r = 0, g = 1, b = 0})
    end
end

-- ===== DISCOVERY AND RECONSTRUCTION =====

-- Scan all surfaces for existing entities
local function discover_existing_entities()
    local turrets_found = 0
    local chests_found = 0
    
    for surface_name, surface in pairs(game.surfaces) do
        if surface.valid then
            -- Find all turret types
            local turret_types = {"ammo-turret", "electric-turret", "fluid-turret", "artillery-turret"}
            for _, turret_type in pairs(turret_types) do
                local success, entities = pcall(function()
                    return surface.find_entities_filtered({type = turret_type})
                end)
                
                if success and entities then
                    for _, entity in pairs(entities) do
                        if register_turret(entity) then
                            turrets_found = turrets_found + 1
                        end
                    end
                end
            end
            
            -- Find master ammo chests
            local chest_success, chests = pcall(function()
                return surface.find_entities_filtered({name = "master-ammo-chest"})
            end)
            
            if chest_success and chests then
                for _, entity in pairs(chests) do
                    if register_master_chest(entity) then
                        chests_found = chests_found + 1
                    end
                end
            end
        end
    end
    
    log(string.format("TCN: Discovery complete - %d turrets, %d master chests found", 
        turrets_found, chests_found))
    
    return turrets_found, chests_found
end

-- ===== PUBLIC API =====

local tcn_api = {}

-- Initialize the TCN system
function tcn_api.init_mac_system()
    log("TCN System (Master Ammo Chest as Cloud Storage) v3.0 initialized")
end

-- Register entity from events
function tcn_api.on_entity_built(entity)
    if not entity or not entity.valid then return end
    
    if entity.name == "master-ammo-chest" then
        register_master_chest(entity)
    else
        register_turret(entity)
    end
end

-- Unregister entity from events
function tcn_api.on_entity_destroyed(entity)
    if not entity or not entity.unit_number then return end
    
    local unit_number = entity.unit_number
    unregister_turret(unit_number)
    unregister_master_chest(unit_number)
end

-- Main update function - processes turret ammo requests
function tcn_api.update_mac_system()
    if not storage.tde then
        return
    end
    
    process_turret_ammo_requests()
end

-- Manual reconstruction trigger
function tcn_api.rebuild_mac_system()
    discover_existing_entities()
end

-- Get system statistics
function tcn_api.get_mac_stats()
    if not storage.tde then return {} end
    
    local chest_count = 0
    local turret_count = 0
    local total_mac_ammo = 0
    
    if storage.tde.master_ammo_chests then
        for unit_number, chest_data in pairs(storage.tde.master_ammo_chests) do
            if chest_data.entity and chest_data.entity.valid then
                chest_count = chest_count + 1
                local chest_inv = chest_data.entity.get_inventory(defines.inventory.chest)
                if chest_inv then
                    total_mac_ammo = total_mac_ammo + chest_inv.get_item_count()
                end
            end
        end
    end
    
    if storage.tde.global_turrets then
        for _ in pairs(storage.tde.global_turrets) do
            turret_count = turret_count + 1
        end
    end
    
    return {
        chests_tracked = chest_count,
        turrets_tracked = turret_count,
        total_mac_ammo = total_mac_ammo,
        last_check_tick = storage.tde.tcn_last_check or 0
    }
end

-- Update configuration
function tcn_api.set_mac_config(new_config)
    for key, value in pairs(new_config) do
        if TCN_CONFIG[key] ~= nil then
            TCN_CONFIG[key] = value
        end
    end
end

log("TCN System (Turret Central Network) v3.0 loaded successfully")

-- Export the API
return tcn_api