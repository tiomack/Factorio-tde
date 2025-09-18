-- ===== MASTER AMMO CHEST SYSTEM V2.0 =====
-- Complete rebuild based on official Factorio API documentation
-- Robust entity management, efficient inventory operations, proper persistence
-- VERSION 2.0 - PRODUCTION READY

-- ===== SYSTEM CONFIGURATION =====
local MAC_CONFIG = {
    update_interval = 360, -- 6 seconds (60 ticks/second × 6 = 360 ticks)
    batch_size = 10, -- Process max 10 entities per tick for performance
    min_ammo_threshold = 20, -- Request ammo when below this count
    max_ammo_target = 100, -- Fill up to this amount
    scan_radius = 50, -- Radius for initial area scans
    debug_mode = true -- Enable detailed logging for troubleshooting
}

-- ===== CORE DATA STRUCTURES =====

-- Initialize storage structure
local function init_mac_storage()
    if not storage.mac then
        storage.mac = {
            -- Entity registries
            turrets = {}, -- [unit_number] = turret_data
            master_chests = {}, -- [unit_number] = chest_data
            
            -- System state
            version = "2.0",
            last_update = 0,
            update_queue = {},
            
            -- Performance tracking
            stats = {
                turrets_tracked = 0,
                chests_tracked = 0,
                items_distributed = 0,
                last_distribution_tick = 0
            }
        }
    end
end

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
                    -- Handle case where category is just a string
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
            -- For unknown turret types, check if they have turret_ammo inventory
            local ammo_inv = entity.get_inventory(defines.inventory.turret_ammo)
            if ammo_inv then
                -- Default to bullet if it has ammo inventory
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
    
    if success and prototype and prototype.ammo_category then
        if prototype.ammo_category.name then
            return prototype.ammo_category.name
        elseif type(prototype.ammo_category) == "string" then
            return prototype.ammo_category
        end
    end
    
    return nil
end

-- Check if a turret can use specific ammo
local function turret_can_use_ammo(turret_categories, ammo_category)
    if not turret_categories or not ammo_category then return false end
    return turret_categories[ammo_category] == true
end

-- ===== ENTITY REGISTRY SYSTEM =====

-- Register a turret for ammo management
local function register_turret(entity)
    if not entity or not entity.valid or not entity.unit_number then
        return false
    end
    
    -- Safely get ammo categories with error handling
    local success, ammo_categories = pcall(get_turret_ammo_categories, entity)
    if not success then
        if MAC_CONFIG.debug_mode then
            log("MAC: Error getting ammo categories for " .. (entity.name or "unknown") .. ": " .. tostring(ammo_categories))
        end
        return false
    end
    
    if not ammo_categories then
        return false -- Turret doesn't use ammo
    end
    
    local turret_data = {
        entity = entity,
        unit_number = entity.unit_number,
        name = entity.name,
        position = entity.position,
        surface_name = entity.surface.name,
        ammo_categories = ammo_categories,
        last_ammo_count = 0,
        registered_tick = game.tick
    }
    
    storage.mac.turrets[entity.unit_number] = turret_data
    storage.mac.stats.turrets_tracked = storage.mac.stats.turrets_tracked + 1
    
    if MAC_CONFIG.debug_mode then
        local debug_msg = string.format("MAC: Registered turret %s (%d) - categories: %s", 
            entity.name, entity.unit_number, table.concat(table_keys(ammo_categories), ", "))
        log(debug_msg)
        game.print(debug_msg, {r = 0, g = 1, b = 1})
    end
    
    return true
end

-- Register a master ammo chest
local function register_master_chest(entity)
    if not entity or not entity.valid or not entity.unit_number then
        return false
    end
    
    local chest_inventory = entity.get_inventory(defines.inventory.chest)
    if not chest_inventory then
        return false
    end
    
    local chest_data = {
        entity = entity,
        unit_number = entity.unit_number,
        name = entity.name,
        position = entity.position,
        surface_name = entity.surface.name,
        inventory = chest_inventory,
        last_scan_tick = 0,
        registered_tick = game.tick
    }
    
    storage.mac.master_chests[entity.unit_number] = chest_data
    storage.mac.stats.chests_tracked = storage.mac.stats.chests_tracked + 1
    
    if MAC_CONFIG.debug_mode then
        local debug_msg = string.format("MAC: Registered master chest %s (%d)", 
            entity.name, entity.unit_number)
        log(debug_msg)
        game.print(debug_msg, {r = 0, g = 1, b = 1})
    end
    
    return true
end

-- Unregister entities
local function unregister_turret(unit_number)
    if storage.mac.turrets[unit_number] then
        storage.mac.turrets[unit_number] = nil
        storage.mac.stats.turrets_tracked = math.max(0, storage.mac.stats.turrets_tracked - 1)
        return true
    end
    return false
end

local function unregister_master_chest(unit_number)
    if storage.mac.master_chests[unit_number] then
        storage.mac.master_chests[unit_number] = nil
        storage.mac.stats.chests_tracked = math.max(0, storage.mac.stats.chests_tracked - 1)
        return true
    end
    return false
end

-- ===== INVENTORY MANAGEMENT SYSTEM =====

-- Get current ammo count for a turret
local function get_turret_ammo_count(turret_data)
    if not turret_data.entity.valid then return 0 end
    
    local ammo_inventory = turret_data.entity.get_inventory(defines.inventory.turret_ammo)
    if not ammo_inventory then return 0 end
    
    return ammo_inventory.get_item_count()
end

-- Get available ammo from all master chests by category
local function get_available_ammo_by_category()
    local ammo_pool = {}
    
    for unit_number, chest_data in pairs(storage.mac.master_chests) do
        if chest_data.entity.valid then
            local success, contents = pcall(function()
                return chest_data.inventory.get_contents()
            end)
            
            if not success or not contents then
                if MAC_CONFIG.debug_mode then
                    local debug_msg = "MAC: Failed to get contents from chest " .. unit_number .. ": " .. tostring(contents)
                    log(debug_msg)
                    game.print(debug_msg, {r = 1, g = 0.5, b = 0})
                end
                goto continue_chest
            end
            
            if MAC_CONFIG.debug_mode and next(contents) then
                local debug_msg = "MAC: Chest " .. unit_number .. " contents type check:"
                log(debug_msg)
                game.print(debug_msg, {r = 0.8, g = 0.8, b = 0.8})
                for item_id, count in pairs(contents) do
                    local item_debug = "  Item: " .. tostring(item_id) .. " (type: " .. type(item_id) .. "), Count: " .. tostring(count)
                    log(item_debug)
                    game.print(item_debug, {r = 0.8, g = 0.8, b = 0.8})
                    break -- Only log first item to avoid spam
                end
            end
            
            for item_id, count in pairs(contents) do
                -- Handle different formats of get_contents() return values
                local item_name
                if type(item_id) == "string" then
                    -- Simple format: item_id is the item name string
                    item_name = item_id
                elseif type(item_id) == "table" and item_id.name then
                    -- Complex format: item_id is an object with .name property
                    item_name = item_id.name
                else
                    -- Unknown format, skip this item
                    if MAC_CONFIG.debug_mode then
                        log("MAC: Unknown item_id format: " .. tostring(item_id) .. " (type: " .. type(item_id) .. ")")
                    end
                    goto continue_item
                end
                
                local ammo_category = get_item_ammo_category(item_name)
                
                if ammo_category then
                    if not ammo_pool[ammo_category] then
                        ammo_pool[ammo_category] = {}
                    end
                    ammo_pool[ammo_category][item_name] = (ammo_pool[ammo_category][item_name] or 0) + count
                end
                
                ::continue_item::
            end
        else
            -- Clean up invalid chest
            storage.mac.master_chests[unit_number] = nil
            storage.mac.stats.chests_tracked = math.max(0, storage.mac.stats.chests_tracked - 1)
        end
        
        ::continue_chest::
    end
    
    return ammo_pool
end

-- Transfer specific ammo from chests to turret
local function transfer_ammo_to_turret(turret_data, ammo_item_name, amount_needed)
    local transferred = 0
    local ammo_inventory = turret_data.entity.get_inventory(defines.inventory.turret_ammo)
    
    if not ammo_inventory then return 0 end
    
    -- Calculate how much we can actually insert
    local can_insert = ammo_inventory.get_insertable_count(ammo_item_name)
    local transfer_amount = math.min(amount_needed, can_insert)
    
    if transfer_amount <= 0 then return 0 end
    
    -- Remove ammo from chests
    for unit_number, chest_data in pairs(storage.mac.master_chests) do
        if transferred >= transfer_amount then break end
        if not chest_data.entity.valid then goto continue end
        
        local available = chest_data.inventory.get_item_count(ammo_item_name)
        if available > 0 then
            local to_remove = math.min(available, transfer_amount - transferred)
            local removed = chest_data.inventory.remove({name = ammo_item_name, count = to_remove})
            
            if removed > 0 then
                local inserted = ammo_inventory.insert({name = ammo_item_name, count = removed})
                transferred = transferred + inserted
                
                -- Return any excess back to chest
                if inserted < removed then
                    chest_data.inventory.insert({name = ammo_item_name, count = removed - inserted})
                end
            end
        end
        
        ::continue::
    end
    
    return transferred
end

-- ===== DISTRIBUTION ALGORITHM =====

-- Get turrets that need ammo, sorted by priority
local function get_turrets_needing_ammo()
    local needy_turrets = {}
    
    for unit_number, turret_data in pairs(storage.mac.turrets) do
        if turret_data.entity.valid then
            local current_ammo = get_turret_ammo_count(turret_data)
            turret_data.last_ammo_count = current_ammo
            
            if current_ammo < MAC_CONFIG.min_ammo_threshold then
                local priority = MAC_CONFIG.min_ammo_threshold - current_ammo -- Higher number = more urgent
                local needed_ammo = MAC_CONFIG.max_ammo_target - current_ammo
                
                table.insert(needy_turrets, {
                    turret_data = turret_data,
                    current_ammo = current_ammo,
                    priority = priority,
                    needed_ammo = needed_ammo
                })
                
                if MAC_CONFIG.debug_mode then
                    local debug_msg = string.format("MAC: Turret %d (%s) needs ammo: has %d, needs %d", 
                        turret_data.unit_number, turret_data.name, current_ammo, needed_ammo)
                    log(debug_msg)
                    game.print(debug_msg, {r = 1, g = 0.8, b = 0})
                end
            end
        else
            -- Clean up invalid turret
            storage.mac.turrets[unit_number] = nil
            storage.mac.stats.turrets_tracked = math.max(0, storage.mac.stats.turrets_tracked - 1)
        end
    end
    
    -- Sort by priority (most urgent first)
    table.sort(needy_turrets, function(a, b)
        return a.priority > b.priority
    end)
    
    return needy_turrets
end

-- Main distribution process
local function process_ammo_distribution()
    if game.tick - storage.mac.last_update < MAC_CONFIG.update_interval then
        return
    end
    
    storage.mac.last_update = game.tick
    
    if MAC_CONFIG.debug_mode then
        local debug_msg = string.format("MAC: Starting distribution cycle at tick %d (every %d ticks = %.1f seconds)", 
            game.tick, MAC_CONFIG.update_interval, MAC_CONFIG.update_interval / 60.0)
        log(debug_msg)
        game.print(debug_msg, {r = 1, g = 1, b = 0})
    end
    
    local needy_turrets = get_turrets_needing_ammo()
    if #needy_turrets == 0 then 
        if MAC_CONFIG.debug_mode then
            local debug_msg = "MAC: No turrets need ammo right now"
            log(debug_msg)
            game.print(debug_msg, {r = 0.8, g = 0.8, b = 0.8})
        end
        return 
    end
    
    local ammo_pool = get_available_ammo_by_category()
    if next(ammo_pool) == nil then 
        if MAC_CONFIG.debug_mode then
            local debug_msg = "MAC: No ammo available in master chests"
            log(debug_msg)
            game.print(debug_msg, {r = 1, g = 0.8, b = 0})
        end
        return 
    end
    
    if MAC_CONFIG.debug_mode then
        local debug_msg = string.format("MAC: Found %d needy turrets and ammo available", #needy_turrets)
        log(debug_msg)
        game.print(debug_msg, {r = 0, g = 1, b = 0})
    end
    
    local total_distributed = 0
    local turrets_served = 0
    
    -- Process turrets in batches for performance
    local batch_count = 0
    for _, turret_need in pairs(needy_turrets) do
        if batch_count >= MAC_CONFIG.batch_size then break end
        
        local turret_data = turret_need.turret_data
        local amount_needed = turret_need.needed_ammo
        
        -- Try each ammo category this turret accepts
        for category_name, _ in pairs(turret_data.ammo_categories) do
            if ammo_pool[category_name] then
                -- Find best ammo type (prefer higher tier)
                local ammo_types = {}
                for item_name, available_count in pairs(ammo_pool[category_name]) do
                    if available_count > 0 then
                        table.insert(ammo_types, {name = item_name, count = available_count})
                    end
                end
                
                -- Sort by count (use what we have most of to balance)
                table.sort(ammo_types, function(a, b) return a.count > b.count end)
                
                for _, ammo_type in pairs(ammo_types) do
                    if amount_needed <= 0 then break end
                    
                    local transferred = transfer_ammo_to_turret(turret_data, ammo_type.name, amount_needed)
                    if transferred > 0 then
                        amount_needed = amount_needed - transferred
                        total_distributed = total_distributed + transferred
                        ammo_pool[category_name][ammo_type.name] = ammo_pool[category_name][ammo_type.name] - transferred
                        
                        if MAC_CONFIG.debug_mode then
                            local debug_msg = string.format("MAC: Transferred %d %s to turret %d", 
                                transferred, ammo_type.name, turret_data.unit_number)
                            log(debug_msg)
                            game.print(debug_msg, {r = 0, g = 0.8, b = 1})
                        end
                    end
                end
            end
        end
        
        if amount_needed < turret_need.needed_ammo then
            turrets_served = turrets_served + 1
        end
        
        batch_count = batch_count + 1
    end
    
    -- Update statistics
    storage.mac.stats.items_distributed = storage.mac.stats.items_distributed + total_distributed
    storage.mac.stats.last_distribution_tick = game.tick
    
    -- User feedback
    if total_distributed > 0 and settings.global["tde-show-ammo-messages"].value then
        game.print(string.format("MAC System: Distributed %d ammo to %d turrets", 
            total_distributed, turrets_served), {r = 0, g = 0.8, b = 1})
    end
end

-- ===== DISCOVERY AND RECONSTRUCTION =====

-- Scan all surfaces for existing entities
local function discover_existing_entities()
    local turrets_found = 0
    local chests_found = 0
    
    for surface_name, surface in pairs(game.surfaces) do
        if surface.valid then
            -- Find all turret types with error handling
            local turret_types = {"ammo-turret", "electric-turret", "fluid-turret", "artillery-turret"}
            for _, turret_type in pairs(turret_types) do
                local success, entities = pcall(function()
                    return surface.find_entities_filtered({type = turret_type})
                end)
                
                if success and entities then
                    for _, entity in pairs(entities) do
                        local reg_success, result = pcall(register_turret, entity)
                        if reg_success and result then
                            turrets_found = turrets_found + 1
                        elseif not reg_success and MAC_CONFIG.debug_mode then
                            log("MAC: Failed to register turret " .. (entity.name or "unknown") .. ": " .. tostring(result))
                        end
                    end
                elseif MAC_CONFIG.debug_mode then
                    log("MAC: Failed to find " .. turret_type .. " entities on " .. surface_name)
                end
            end
            
            -- Find master ammo chests with error handling
            local chest_success, chests = pcall(function()
                return surface.find_entities_filtered({name = "master-ammo-chest"})
            end)
            
            if chest_success and chests then
                for _, entity in pairs(chests) do
                    if register_master_chest(entity) then
                        chests_found = chests_found + 1
                    end
                end
            elseif MAC_CONFIG.debug_mode then
                log("MAC: Failed to find master-ammo-chest entities on " .. surface_name)
            end
        end
    end
    
    log(string.format("MAC: Discovery complete - %d turrets, %d master chests found", 
        turrets_found, chests_found))
    
    return turrets_found, chests_found
end

-- Full system reconstruction
local function reconstruct_mac_system()
    log("MAC: Starting system reconstruction...")
    
    -- Clear existing data
    storage.mac.turrets = {}
    storage.mac.master_chests = {}
    storage.mac.stats.turrets_tracked = 0
    storage.mac.stats.chests_tracked = 0
    
    -- Discover entities
    local turrets_found, chests_found = discover_existing_entities()
    
    -- User feedback
    local message = string.format("MAC System v2.0 rebuilt: %d turrets, %d master chests", 
        turrets_found, chests_found)
    game.print(message, {r = 0, g = 1, b = 0})
    
    log("MAC: System reconstruction complete")
end

-- ===== UTILITY FUNCTIONS =====

-- Get keys from table
function table_keys(tbl)
    local keys = {}
    for k, _ in pairs(tbl) do
        table.insert(keys, k)
    end
    return keys
end

-- Validate entity reference
local function validate_entity_reference(entity_data)
    return entity_data and entity_data.entity and entity_data.entity.valid
end

-- ===== PUBLIC API =====

local mac_api = {}

-- Initialize the MAC system
function mac_api.init_mac_system()
    init_mac_storage()
    log("MAC System v2.0 initialized")
end

-- Register entity from events
function mac_api.on_entity_built(entity)
    if not entity or not entity.valid then return end
    
    if entity.name == "master-ammo-chest" then
        register_master_chest(entity)
    else
        register_turret(entity)
    end
end

-- Unregister entity from events
function mac_api.on_entity_destroyed(entity)
    if not entity or not entity.unit_number then return end
    
    local unit_number = entity.unit_number
    unregister_turret(unit_number)
    unregister_master_chest(unit_number)
end

-- Main update function
function mac_api.update_mac_system()
    if not storage.mac then
        mac_api.init_mac_system()
        return
    end
    
    process_ammo_distribution()
end

-- Manual reconstruction trigger
function mac_api.rebuild_mac_system()
    reconstruct_mac_system()
end

-- Get system statistics
function mac_api.get_mac_stats()
    if not storage.mac then return {} end
    return storage.mac.stats
end

-- Update configuration
function mac_api.set_mac_config(new_config)
    for key, value in pairs(new_config) do
        if MAC_CONFIG[key] ~= nil then
            MAC_CONFIG[key] = value
        end
    end
end

log("MAC System v2.0 loaded successfully")

-- Export the API
return mac_api