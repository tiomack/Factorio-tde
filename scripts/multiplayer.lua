-- ===== MULTIPLAYER COMPATIBILITY MODULE =====
-- Simplified multiplayer support focusing on essential functionality

-- Initialize multiplayer-specific data
function initialize_multiplayer_data()
    if not storage.tde then
        storage.tde = {}
    end
    
    -- Multiplayer-specific storage (simplified)
    if not storage.tde.multiplayer then
        storage.tde.multiplayer = {
            planet_visits = {}, -- Track which planets have been visited by any player
            sync_tick = 0 -- Last synchronization tick
        }
    end
end

-- Handle new player joining (simplified)
function handle_player_join(player)
    if not player or not player.valid then return end
    
    log("TDE: Player joined: " .. player.name)
    
    -- Show welcome message with current game state
    show_welcome_messages(player)
    
    -- Create GUI for the new player
    create_tde_info_gui(player)
    
    -- Sync current game state to new player
    sync_game_state_to_player(player)
end

-- Handle player leaving (simplified)
function handle_player_leave(player)
    if not player or not player.name then return end
    
    log("TDE: Player left: " .. player.name)
    -- No complex tracking needed - just log the event
end

-- Track planet visits for Space Age DLC integration (simplified)
function track_planet_visit(player, surface_name)
    if not surface_name then return end
    
    -- Track planet visit globally (not per player)
    if not storage.tde.multiplayer.planet_visits[surface_name] then
        storage.tde.multiplayer.planet_visits[surface_name] = game.tick
        log("TDE: Planet discovered: " .. surface_name)
        
        -- Notify all players about new planet discovery
        game.print("New planet discovered: " .. surface_name .. "! New enemies may appear in waves!", {r = 0, g = 1, b = 1})
    end
end

-- Check if any player has visited a specific planet (simplified)
function has_any_player_visited_planet(planet_name)
    if not storage.tde.multiplayer or not storage.tde.multiplayer.planet_visits then
        return false
    end
    
    return storage.tde.multiplayer.planet_visits[planet_name] ~= nil
end

-- Get all planets that any player has visited (simplified)
function get_visited_planets()
    if not storage.tde.multiplayer or not storage.tde.multiplayer.planet_visits then
        return {}
    end
    
    local visited_planets = {}
    for planet_name, _ in pairs(storage.tde.multiplayer.planet_visits) do
        visited_planets[planet_name] = true
    end
    
    return visited_planets
end

-- Synchronize game state to a specific player (simplified)
function sync_game_state_to_player(player)
    if not player or not player.valid then return end
    
    -- Send current wave information
    if storage.tde.wave_count and storage.tde.wave_count > 0 then
        player.print("Current wave: " .. storage.tde.wave_count, {r = 1, g = 1, b = 0})
    end
    
    -- Send kill count information
    if storage.tde.total_kills then
        player.print("Total kills: " .. storage.tde.total_kills, {r = 0, g = 1, b = 0})
    end
    
    -- Send visited planets information
    local visited_planets = get_visited_planets()
    if next(visited_planets) then
        local planet_list = ""
        for planet_name, _ in pairs(visited_planets) do
            planet_list = planet_list .. planet_name .. ", "
        end
        planet_list = planet_list:sub(1, -3) -- Remove trailing comma
        player.print("Discovered planets: " .. planet_list, {r = 0, g = 0.8, b = 1})
    end
end

-- Periodic synchronization for all players (simplified)
function sync_game_state_to_all_players()
    if not storage.tde.multiplayer then return end
    
    storage.tde.multiplayer.sync_tick = game.tick
    
    for _, player in pairs(game.connected_players) do
        if player.valid then
            -- Update GUI for all connected players
            update_tde_info_gui(player)
        end
    end
end

-- Handle surface changes (for Space Age DLC) - simplified
function handle_surface_change(player, old_surface, new_surface)
    if not player or not player.valid then return end
    
    if old_surface and new_surface and old_surface.name ~= new_surface.name then
        log("TDE: Player " .. player.name .. " moved from " .. old_surface.name .. " to " .. new_surface.name)
        
        -- Track planet visit
        track_planet_visit(player, new_surface.name)
    end
end

-- Export multiplayer functions
return {
    initialize_multiplayer_data = initialize_multiplayer_data,
    handle_player_join = handle_player_join,
    handle_player_leave = handle_player_leave,
    track_planet_visit = track_planet_visit,
    has_any_player_visited_planet = has_any_player_visited_planet,
    get_visited_planets = get_visited_planets,
    sync_game_state_to_player = sync_game_state_to_player,
    sync_game_state_to_all_players = sync_game_state_to_all_players,
    handle_surface_change = handle_surface_change
} 