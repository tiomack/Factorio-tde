-- Create the countdown label for a player (e.g., when they join or mod initializes)
function create_tde_info_gui(player)

    if player.gui.left.tde_info_frame then
      player.gui.left.tde_info_frame.destroy()
    end
  
    local frame = player.gui.left.add{
      type = "frame",
      name = "tde_info_frame",
      caption = "⚔ TDE Status",
      direction = "vertical"
    }
  
    frame.style.font = "default-bold"
    frame.style.minimal_width = 200
  
    -- Add close button
    local title_flow = frame.add{type = "flow", direction = "horizontal"}
    title_flow.add{type = "label", caption = "⚔ TDE Status", style = "frame_title"}
    local close_button = title_flow.add{
      type = "button",
      name = "tde_close_button",
      caption = "×",
      style = "close_button"
    }
    
    frame.add{type = "label", name = "wave_timer_label", caption = "Next wave in: 60s"}
    frame.add{type = "label", name = "current_wave_label", caption = "Current wave: 1"}
    frame.add{type = "label", name = "next_boss_label", caption = string.format("Next boss in: %d waves", 10)}
    frame.add{type = "label", name = "kill_count_label", caption = "Kills: 0"}
    frame.add{type = "label", name = "boss_kill_count_label", caption = "Boss kills: 0"}
    frame.add{type = "label", name = "research_count_label", caption = "Research: 0"}
    
end
  
function update_tde_info_gui(player)
if not player or not player.valid then return end

local frame = player.gui.left.tde_info_frame
if not frame then
    create_tde_info_gui(player)
    frame = player.gui.left.tde_info_frame
    if not frame then return end
end
  
    -- Wave countdown logic (your original)
    local _, next_wave_tick = tde_calculate_wave_state()
    local remaining = next_wave_tick - game.tick
    local minutes = math.floor(remaining / 3600)
    local seconds = math.floor((remaining % 3600) / 60)
    local countdown = (remaining > 0)
      and string.format("Next wave in: %02d:%02d", minutes, seconds)
      or "⚠️ Wave arriving!"
  
    local waves_since_last_boss = storage.tde.wave_count % storage.tde.BOSS_EVERY
    local waves_until_next_boss = storage.tde.BOSS_EVERY - waves_since_last_boss
    if waves_until_next_boss == storage.tde.BOSS_EVERY then
      waves_until_next_boss = 0 -- We're on a boss wave
      frame.next_boss_label.caption = string.format("Next boss in: ⚠️ BOSS WAVE ⚠️")
    else
      frame.next_boss_label.caption = string.format("Next boss in: %d waves", waves_until_next_boss)
    end
  
    -- Update GUI labels
    frame.wave_timer_label.caption = countdown
    frame.current_wave_label.caption = "Current wave: " .. tostring(storage.tde.wave_count or 0)
    frame.kill_count_label.caption = "Kills: " .. tostring(storage.tde.total_kills or 0)
    frame.boss_kill_count_label.caption = "Boss kills: " .. tostring(storage.tde.total_boss_kills or 0)
    frame.research_count_label.caption = "Research: " .. tostring(storage.tde.research_count or 0)
end

-- Add function to handle GUI button clicks
function handle_tde_gui_click(event)
    if not event.element or not event.element.valid then
        return
    end
    
    local player = game.get_player(event.player_index)
    if not player or not player.valid then
        return
    end
    
    if event.element.name == "tde_close_button" then
        -- Close the GUI
        if player.gui.left.tde_info_frame then
            player.gui.left.tde_info_frame.destroy()
        end
        -- Add a button to reopen it
        if not player.gui.top.tde_reopen_button then
            player.gui.top.add{
                type = "button",
                name = "tde_reopen_button",
                caption = "TDE Status",
                style = "blue_button"
            }
        end
    elseif event.element.name == "tde_reopen_button" then
        -- Reopen the GUI
        event.element.destroy()
        create_tde_info_gui(player)
    end
end

-- Add function to create the reopen button for players who close the GUI
function ensure_tde_gui_available(player)
    if not player.gui.left.tde_info_frame and not player.gui.top.tde_reopen_button then
        player.gui.top.add{
            type = "button",
            name = "tde_reopen_button",
            caption = "TDE Status",
            style = "blue_button"
        }
    end
end
  