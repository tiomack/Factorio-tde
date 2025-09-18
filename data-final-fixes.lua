-- Final fixes - Complete technology overhaul and turret buffs
-- VERSION 4.0.0 v5 - FIXED FOR FACTORIO 2.0 + BASE HEART ENTITY + CUSTOMIZABLE RESEARCH

log("TDE: Starting technology overhaul in data-final-fixes v5 - Factorio 2.0 Compatible - DYNAMIC COSTS")

-- Add a fake science pack for kills (for GUI display)
data:extend({
  {
    type = "tool",
    name = "tde-kill-token",
    icon = "__base__/graphics/icons/small-biter-corpse.png", -- Use vanilla biter corpse icon
    icon_size = 64,
    subgroup = "science-pack",
    order = "z[tde-kill-token]",
    stack_size = 1,
    durability = 1,
    durability_description_key = "description.science-pack-remaining-amount",
    localised_name = {"item-name.tde-kill-token"},
    localised_description = {"item-description.tde-kill-token"}
  }
})

-- DYNAMIC TECHNOLOGY COSTS - NO LONGER USE STATIC COSTS
-- All technologies now use dynamic costs calculated in control.lua
-- First tech: 10, then +10 each until 100, then +15 until 500, then +20 until 1000, then +30 permanently

for tech_name, tech in pairs(data.raw.technology) do
  if tech then
    -- All technologies start with a base cost of 10 (will be dynamically calculated with categories)
    local base_cost = 10

    -- Use the dead biter token as the only ingredient (must be type "tool")
    tech.unit = {
      count = base_cost,
      ingredients = {{"tde-dead-biter", 1}},
      time = 1
    }
    
    -- Asegurar que la tecnología esté habilitada
    if tech.enabled ~= nil then
      tech.enabled = true
    end
    
    -- Agregar descripción del costo dinámico con categorías
    if not tech.localised_description then
      tech.localised_description = {"", "Cost: Dynamic (starts at 10, scales with research count and category)"}
    end
    
    log("TDE: Modified technology " .. tech_name .. " - uses dynamic cost system")
  end
end

-- Make all labs require only the dead biter token as input
for _, lab in pairs(data.raw["lab"]) do
  lab.inputs = {"tde-dead-biter"}
end

-- Ensure all technologies require only the dead biter token and have a unit field
for _, tech in pairs(data.raw.technology) do
  if not tech.unit then
    tech.unit = {count = 1, ingredients = { {"tde-dead-biter", 1} }, time = 1}
  else
    tech.unit.ingredients = { {"tde-dead-biter", 1} }
    if not tech.unit.count then tech.unit.count = 1 end
    if not tech.unit.time then tech.unit.time = 1 end
  end
end

-- ===== BALANCE TURRETS FOR TOWER DEFENSE - NERFEAR UN POCO =====
if data.raw["ammo-turret"] and data.raw["ammo-turret"]["gun-turret"] then
  local gun_turret = data.raw["ammo-turret"]["gun-turret"]
  gun_turret.max_health = 800         -- Reducido de 1000 a 800
  gun_turret.inventory_size = 15      -- Reducido de 20 a 15 
  if gun_turret.attack_parameters then
    gun_turret.attack_parameters.range = 30    -- Reducido de 35 a 30
    gun_turret.attack_parameters.cooldown = 6  -- Aumentado de 4 a 6 (más lento)
  end
  log("TDE: Balanced gun turret (nerfed slightly)")
end

if data.raw["electric-turret"] and data.raw["electric-turret"]["laser-turret"] then
  local laser_turret = data.raw["electric-turret"]["laser-turret"]
  laser_turret.max_health = 1200      -- Reducido de 1500 a 1200
  if laser_turret.attack_parameters then
    laser_turret.attack_parameters.range = 35  -- Reducido de 38 a 35
    laser_turret.attack_parameters.cooldown = 25  -- Aumentado de 20 a 25
  end
  if laser_turret.energy_source then
    laser_turret.energy_source.buffer_capacity = "1200kJ"  -- Reducido de 1500kJ
  end
  log("TDE: Balanced laser turret (nerfed slightly)")
end

-- Buff flamethrower turret if it exists
if data.raw["fluid-turret"] and data.raw["fluid-turret"]["flamethrower-turret"] then
  local flame_turret = data.raw["fluid-turret"]["flamethrower-turret"]
  flame_turret.max_health = 1000      -- Reducido de 1200 a 1000
  if flame_turret.attack_parameters then
    flame_turret.attack_parameters.range = 35  -- Reducido de 40 a 35
  end
  log("TDE: Balanced flamethrower turret")
end

-- ===== REMOVE WORM TURRETS FROM NATURAL GENERATION =====
local worm_turrets = {
  "small-worm-turret", "medium-worm-turret", "big-worm-turret", "behemoth-worm-turret"
}

for _, turret_name in pairs(worm_turrets) do
  if data.raw["turret"] and data.raw["turret"][turret_name] then
    if data.raw["turret"][turret_name].autoplace then
      data.raw["turret"][turret_name].autoplace = nil
      log("TDE: Removed autoplace for " .. turret_name)
    end
  end
end

-- ===== BALANCE AMMUNITION - REDUCIR DAÑO INICIAL =====
if data.raw["ammo"] and data.raw["ammo"]["firearm-magazine"] then
  local firearm_mag = data.raw["ammo"]["firearm-magazine"]
  if firearm_mag.ammo_type and firearm_mag.ammo_type.action then
    if type(firearm_mag.ammo_type.action) == "table" then
      for _, action in pairs(firearm_mag.ammo_type.action) do
        if action.action_delivery and action.action_delivery.target_effects then
          for _, effect in pairs(action.action_delivery.target_effects) do
            if effect.type == "damage" and effect.damage and effect.damage.amount then
              effect.damage.amount = effect.damage.amount * 1.1  -- Reducido de 1.3 a 1.1
            end
          end
        end
      end
    end
  end
  log("TDE: Balanced firearm magazine damage")
end

if data.raw["ammo"] and data.raw["ammo"]["piercing-rounds-magazine"] then
  local piercing_mag = data.raw["ammo"]["piercing-rounds-magazine"]
  if piercing_mag.ammo_type and piercing_mag.ammo_type.action then
    if type(piercing_mag.ammo_type.action) == "table" then
      for _, action in pairs(piercing_mag.ammo_type.action) do
        if action.action_delivery and action.action_delivery.target_effects then
          for _, effect in pairs(action.action_delivery.target_effects) do
            if effect.type == "damage" and effect.damage and effect.damage.amount then
              effect.damage.amount = effect.damage.amount * 1.3  -- Mantenido en 1.3 para piercing
            end
          end
        end
      end
    end
  end
  log("TDE: Balanced piercing rounds damage")
end

-- ===== MODIFY SPAWNER BEHAVIOR =====
-- Make spawners always active and more aggressive
if data.raw["unit-spawner"] and data.raw["unit-spawner"]["biter-spawner"] then
  local biter_spawner = data.raw["unit-spawner"]["biter-spawner"]
  biter_spawner.max_health = 500  -- Increased health
  biter_spawner.max_count_of_owned_units = 10  -- More units per spawner
  biter_spawner.max_friends_around_to_spawn = 8  -- Allow spawning with more friends nearby
  
  -- Ensure spawning parameters exist
  if biter_spawner.spawning_cooldown then
    biter_spawner.spawning_cooldown = {180, 120}  -- Faster spawning (3-2 seconds)
  end
  
  log("TDE: Modified biter spawner behavior")
end

if data.raw["unit-spawner"] and data.raw["unit-spawner"]["spitter-spawner"] then
  local spitter_spawner = data.raw["unit-spawner"]["spitter-spawner"]
  spitter_spawner.max_health = 500  -- Increased health
  spitter_spawner.max_count_of_owned_units = 8  -- More units per spawner
  spitter_spawner.max_friends_around_to_spawn = 8  -- Allow spawning with more friends nearby
  
  -- Ensure spawning parameters exist
  if spitter_spawner.spawning_cooldown then
    spitter_spawner.spawning_cooldown = {180, 120}  -- Faster spawning (3-2 seconds)
  end
  
  log("TDE: Modified spitter spawner behavior")
end

-- ===== ENHANCE BITERS FOR TOWER DEFENSE =====
-- Make biters slightly stronger to compensate for buffed turrets
local biter_types = {"small-biter", "medium-biter", "big-biter", "behemoth-biter"}
for _, biter_name in pairs(biter_types) do
  if data.raw["unit"] and data.raw["unit"][biter_name] then
    local biter = data.raw["unit"][biter_name]
    if biter.max_health then
      biter.max_health = math.ceil(biter.max_health * 1.2)  -- 20% more health
    end
    if biter.movement_speed then
      biter.movement_speed = biter.movement_speed * 1.1  -- 10% faster
    end
    log("TDE: Enhanced " .. biter_name)
  end
end

local spitter_types = {"small-spitter", "medium-spitter", "big-spitter", "behemoth-spitter"}
for _, spitter_name in pairs(spitter_types) do
  if data.raw["unit"] and data.raw["unit"][spitter_name] then
    local spitter = data.raw["unit"][spitter_name]
    if spitter.max_health then
      spitter.max_health = math.ceil(spitter.max_health * 1.2)  -- 20% more health
    end
    if spitter.movement_speed then
      spitter.movement_speed = spitter.movement_speed * 1.1  -- 10% faster
    end
    log("TDE: Enhanced " .. spitter_name)
  end
end

-- ===== ENHANCE PLAYER EQUIPMENT =====
-- Make the player stronger for tower defense gameplay
if data.raw["character"] and data.raw["character"]["character"] then
  local character = data.raw["character"]["character"]
  
  -- Increase health
  character.max_health = 300  -- Increased from 100
  
  -- Increase inventory size
  character.inventory_size = 80  -- Increased from 60
  
  -- Increase reach distance
  character.reach_distance = 8  -- Increased from 6
  character.item_pickup_distance = 2  -- Increased pickup range
  character.loot_pickup_distance = 3  -- Increased loot pickup range
  
  log("TDE: Enhanced player character")
end

-- ===== ENHANCE INSERTERS =====
-- Make inserters faster for better factory performance
local inserter_types = {"inserter", "fast-inserter", "long-handed-inserter", "filter-inserter", "stack-inserter", "bulk-inserter"}
for _, inserter_name in pairs(inserter_types) do
  if data.raw["inserter"] and data.raw["inserter"][inserter_name] then
    local inserter = data.raw["inserter"][inserter_name]
    if inserter.rotation_speed then
      inserter.rotation_speed = inserter.rotation_speed * 1.5  -- 50% faster
    end
    if inserter.extension_speed then
      inserter.extension_speed = inserter.extension_speed * 1.5  -- 50% faster
    end
    log("TDE: Enhanced " .. inserter_name .. " speed")
  end
end

-- ===== ENHANCE BELT SPEEDS =====
-- Make belts faster for better throughput
local belt_types = {"transport-belt", "fast-transport-belt", "express-transport-belt", "turbo-transport-belt"}
for _, belt_name in pairs(belt_types) do
  if data.raw["transport-belt"] and data.raw["transport-belt"][belt_name] then
    local belt = data.raw["transport-belt"][belt_name]
    if belt.speed then
      belt.speed = belt.speed * 1.3  -- 30% faster
    end
    log("TDE: Enhanced " .. belt_name .. " speed")
  end
  
  -- Also enhance underground belts
  local underground_name = "underground-" .. belt_name
  if data.raw["underground-belt"] and data.raw["underground-belt"][underground_name] then
    local underground = data.raw["underground-belt"][underground_name]
    if underground.speed then
      underground.speed = underground.speed * 1.3  -- 30% faster
    end
    log("TDE: Enhanced " .. underground_name .. " speed")
  end
  
  -- Also enhance splitters
  local splitter_name = belt_name:gsub("transport%-belt", "splitter")
  if data.raw["splitter"] and data.raw["splitter"][splitter_name] then
    local splitter = data.raw["splitter"][splitter_name]
    if splitter.speed then
      splitter.speed = splitter.speed * 1.3  -- 30% faster
    end
    log("TDE: Enhanced " .. splitter_name .. " speed")
  end
end

-- ===== ENHANCE ASSEMBLING MACHINES =====
-- Make assembling machines faster
local assembler_types = {"assembling-machine-1", "assembling-machine-2", "assembling-machine-3"}
for _, assembler_name in pairs(assembler_types) do
  if data.raw["assembling-machine"] and data.raw["assembling-machine"][assembler_name] then
    local assembler = data.raw["assembling-machine"][assembler_name]
    if assembler.crafting_speed then
      assembler.crafting_speed = assembler.crafting_speed * 1.3  -- 30% faster
    end
    log("TDE: Enhanced " .. assembler_name .. " speed")
  end
end

-- ===== ENHANCE FURNACES =====
local furnace_types = {"stone-furnace", "steel-furnace", "electric-furnace"}
for _, furnace_name in pairs(furnace_types) do
  if data.raw["furnace"] and data.raw["furnace"][furnace_name] then
    local furnace = data.raw["furnace"][furnace_name]
    if furnace.crafting_speed then
      furnace.crafting_speed = furnace.crafting_speed * 1.3  -- 30% faster
    end
    log("TDE: Enhanced " .. furnace_name .. " speed")
  end
end

-- ===== ENHANCE MINING DRILLS =====
local drill_types = {"burner-mining-drill", "electric-mining-drill", "big-mining-drill"}
for _, drill_name in pairs(drill_types) do
  if data.raw["mining-drill"] and data.raw["mining-drill"][drill_name] then
    local drill = data.raw["mining-drill"][drill_name]
    if drill.mining_speed then
      drill.mining_speed = drill.mining_speed * 1.4  -- 40% faster
    end
    log("TDE: Enhanced " .. drill_name .. " speed")
  end
end

-- ===== ENHANCE PUMPJACKS =====
if data.raw["mining-drill"] and data.raw["mining-drill"]["pumpjack"] then
  local pumpjack = data.raw["mining-drill"]["pumpjack"]
  if pumpjack.mining_speed then
    pumpjack.mining_speed = pumpjack.mining_speed * 1.5  -- 50% faster
  end
  log("TDE: Enhanced pumpjack speed")
end

-- ===== ENHANCE LABS =====
if data.raw["lab"] and data.raw["lab"]["lab"] then
  local lab = data.raw["lab"]["lab"]
  if lab.researching_speed then
    lab.researching_speed = lab.researching_speed * 2  -- 100% faster research
  end
  log("TDE: Enhanced lab research speed")
end

-- ===== ENHANCE CHESTS =====
-- Increase chest capacity for better storage
local chest_types = {"wooden-chest", "iron-chest", "steel-chest", "logistic-chest-active-provider", "logistic-chest-passive-provider", "logistic-chest-storage", "logistic-chest-requester", "logistic-chest-buffer"}
for _, chest_name in pairs(chest_types) do
  local chest_type = nil
  if data.raw["container"] and data.raw["container"][chest_name] then
    chest_type = data.raw["container"][chest_name]
  elseif data.raw["logistic-container"] and data.raw["logistic-container"][chest_name] then
    chest_type = data.raw["logistic-container"][chest_name]
  end
  
  if chest_type and chest_type.inventory_size then
    chest_type.inventory_size = math.ceil(chest_type.inventory_size * 1.5)  -- 50% more storage
    log("TDE: Enhanced " .. chest_name .. " capacity")
  end
end

-- ===== ENHANCE POWER GENERATION =====
-- Steam engines
if data.raw["generator"] and data.raw["generator"]["steam-engine"] then
  local steam_engine = data.raw["generator"]["steam-engine"]
  if steam_engine.max_power_output then
    steam_engine.max_power_output = "1200kW"  -- Increased from 900kW
  end
  log("TDE: Enhanced steam engine power")
end

-- Steam turbines
if data.raw["generator"] and data.raw["generator"]["steam-turbine"] then
  local steam_turbine = data.raw["generator"]["steam-turbine"]
  if steam_turbine.max_power_output then
    steam_turbine.max_power_output = "7800kW"  -- Increased from 5800kW
  end
  log("TDE: Enhanced steam turbine power")
end

-- Solar panels
if data.raw["solar-panel"] and data.raw["solar-panel"]["solar-panel"] then
  local solar_panel = data.raw["solar-panel"]["solar-panel"]
  if solar_panel.production then
    solar_panel.production = "90kW"  -- Increased from 60kW
  end
  log("TDE: Enhanced solar panel power")
end

-- Accumulators
if data.raw["accumulator"] and data.raw["accumulator"]["accumulator"] then
  local accumulator = data.raw["accumulator"]["accumulator"]
  if accumulator.energy_source and accumulator.energy_source.buffer_capacity then
    accumulator.energy_source.buffer_capacity = "7.5MJ"  -- Increased from 5MJ
  end
  log("TDE: Enhanced accumulator capacity")
end

-- Add tde-dead-biter to all labs' inputs so every tech is researchable
for _, lab in pairs(data.raw["lab"]) do
  if lab.inputs then
    local found = false
    for _, input in ipairs(lab.inputs) do
      if input == "tde-dead-biter" then
        found = true
        break
      end
    end
    if not found then
      table.insert(lab.inputs, "tde-dead-biter")
    end
  end
end

-- FINAL PATCH: Ensure every technology has a .unit table with count, time, and dead biter token ingredient
for _, tech in pairs(data.raw.technology) do
  if not tech.unit or type(tech.unit) ~= "table" then
    tech.unit = {count = 1, ingredients = { {"tde-dead-biter", 1} }, time = 1}
  else
    tech.unit.ingredients = { {"tde-dead-biter", 1} }
    if not tech.unit.count then tech.unit.count = 1 end
    if not tech.unit.time then tech.unit.time = 1 end
  end
end

-- === ADD DEAD BITER RESEARCH TOKEN ITEM ===
data:extend({
  {
    type = "tool",
    name = "tde-dead-biter",
    icon = "__base__/graphics/icons/small-biter-corpse.png",
    icon_size = 64,
    subgroup = "science-pack",
    order = "z[tde-dead-biter]",
    stack_size = 200000,
    durability = 1,
    durability_description_key = "description.science-pack-remaining-amount",
    localised_name = {"item-name.tde-dead-biter", "Research Token"},
    localised_description = {"item-description.tde-dead-biter", "Research tokens earned by killing biters. Store in Base Heart to unlock technologies."}
  }
})

local base_heart_graphics = {
  layers = {
    {
      filename = "__tower-defense-evolution__/graphics/entity/base_heart.png",
      priority = "extra-high",
      width = 404,
      height = 469,
      shift = util.by_pixel(0, -25),
      scale = 1.0
    }
  }
}

data:extend({
  {
    type = "container",
    name = "tde-base-heart",
    icon = "__base__/graphics/icons/biter-spawner.png",
    icon_size = 64,
    flags = {"placeable-neutral", "player-creation", "not-rotatable"},
    minable = nil,
    max_health = 100000,
    corpse = "small-remnants",
    collision_box = {{-3.8, -2.4}, {3.8, 5.3}},
    map_generator_bounding_box = {{-4.5, -2.6}, {4.5, 5.7}},
    selection_box = {{-4.2, -2.6}, {4.2, 5.7}},
    inventory_size = 128,
    picture = base_heart_graphics,
    open_sound = { filename = "__base__/sound/machine-open.ogg", volume = 0.85 },
    close_sound = { filename = "__base__/sound/machine-close.ogg", volume = 0.75 },

    circuit_wire_connection_point = circuit_connector_definitions["chest"].points,
    circuit_connector_sprites = circuit_connector_definitions["chest"].sprites,
    circuit_wire_max_distance = default_circuit_wire_max_distance
  }
})
-- === ADD BASE HEART ITEM (NEVER GIVEN TO PLAYER - ONLY FOR ENTITY PLACEMENT) ===
data:extend({
  {
    type = "item",
    name = "tde-base-heart",
    icon = "__base__/graphics/icons/biter-spawner.png",
    icon_size = 64,
    subgroup = "storage",
    order = "z[tde-base-heart]",
    place_result = "tde-base-heart",
    stack_size = 1,
    localised_name = {"item-name.tde-base-heart", "Base Heart"},
    localised_description = {"item-description.tde-base-heart", "The heart of your base. Stores research tokens and must be defended at all costs!"}
  }
})

-- === PATCH ALL LABS TO USE ONLY DEAD BITER ===
for _, lab in pairs(data.raw["lab"]) do
  lab.inputs = {"tde-dead-biter"}
end
if data.raw["lab"]["biolab"] then
  data.raw["lab"]["biolab"].inputs = {"tde-dead-biter"}
end

-- === PATCH ALL TECHNOLOGIES TO USE ONLY DEAD BITER ===
for _, tech in pairs(data.raw.technology) do
  if not tech.unit or type(tech.unit) ~= "table" then
    tech.unit = {count = 1, ingredients = { {"tde-dead-biter", 1} }, time = 1}
  else
    tech.unit.ingredients = { {"tde-dead-biter", 1} }
    if not tech.unit.count then tech.unit.count = 1 end
    if not tech.unit.time then tech.unit.time = 1 end
  end
end

-- === ADD MASTER AMMO CHEST ENTITY (ALREADY DEFINED IN BASE MOD) ===
-- If master ammo chest doesn't exist, create a basic version
if not data.raw["container"]["master-ammo-chest"] then
  local master_ammo_chest = table.deepcopy(data.raw["container"]["steel-chest"])
  master_ammo_chest.name = "master-ammo-chest"
  master_ammo_chest.icon = "__base__/graphics/icons/steel-chest.png"
  master_ammo_chest.minable = {mining_time = 1, result = "master-ammo-chest"}
  master_ammo_chest.inventory_size = 64
  -- Add a distinctive color or appearance modification here if needed
  data:extend({master_ammo_chest})
  
  -- Add the item too
  data:extend({
    {
      type = "item",
      name = "master-ammo-chest",
      icon = "__base__/graphics/icons/steel-chest.png",
      icon_size = 64,
      subgroup = "storage",
      order = "z[master-ammo-chest]",
      place_result = "master-ammo-chest",
      stack_size = 50,
      localised_name = {"item-name.master-ammo-chest", "Master Ammo Chest"},
      localised_description = {"item-description.master-ammo-chest", "Automatically distributes ammunition to nearby turrets."}
    }
  })
  
  log("TDE: Created Master Ammo Chest entity and item")
end

-- ===== ENHANCED AMMUNITION PROGRESSION =====
-- Add new ammunition types for better progression
data:extend({
  {
    type = "ammo",
    name = "tde-enhanced-magazine",
    icon = "__base__/graphics/icons/piercing-rounds-magazine.png",
    icon_size = 64,
    ammo_type = {
      category = "bullet",
      action = {
        type = "direct",
        action_delivery = {
          type = "instant",
          target_effects = {
            {
              type = "damage",
              damage = {amount = 12, type = "physical"} -- Enhanced damage
            },
            {
              type = "create-explosion",
              entity_name = "explosion-gunshot"
            }
          }
        }
      }
    },
    magazine_size = 10,
    subgroup = "ammo",
    order = "a[basic-clips]-c[enhanced-magazine]",
    stack_size = 200,
    localised_name = {"item-name.tde-enhanced-magazine", "Enhanced Magazine"},
    localised_description = {"item-description.tde-enhanced-magazine", "High-damage ammunition for gun turrets. More effective than regular magazines."}
  },
  {
    type = "ammo",
    name = "tde-armor-piercing-rounds",
    icon = "__base__/graphics/icons/uranium-rounds-magazine.png",
    icon_size = 64,
    ammo_type = {
      category = "bullet",
      action = {
        type = "direct",
        action_delivery = {
          type = "instant",
          target_effects = {
            {
              type = "damage",
              damage = {amount = 20, type = "physical"} -- Very high damage
            },
            {
              type = "create-explosion",
              entity_name = "explosion-gunshot"
            }
          }
        }
      }
    },
    magazine_size = 10,
    subgroup = "ammo",
    order = "a[basic-clips]-d[armor-piercing]",
    stack_size = 200,
    localised_name = {"item-name.tde-armor-piercing-rounds", "Armor-Piercing Rounds"},
    localised_description = {"item-description.tde-armor-piercing-rounds", "Devastating ammunition that can pierce through the toughest enemy armor."}
  }
})

-- Add recipes for new ammunition
data:extend({
  {
    type = "recipe",
    name = "tde-enhanced-magazine",
    ingredients = {
      {type = "item", name = "firearm-magazine", amount = 2},
      {type = "item", name = "iron-plate", amount = 1},
      {type = "item", name = "copper-plate", amount = 1}
    },
    results = {{type = "item", name = "tde-enhanced-magazine", amount = 4}},
    energy_required = 3,
    enabled = false,
    localised_name = {"recipe-name.tde-enhanced-magazine", "Enhanced Magazine"},
    localised_description = {"recipe-description.tde-enhanced-magazine", "Craft enhanced ammunition from basic magazines and metal plates."}
  },
  {
    type = "recipe",
    name = "tde-armor-piercing-rounds",
    ingredients = {
      {type = "item", name = "piercing-rounds-magazine", amount = 2},
      {type = "item", name = "steel-plate", amount = 2},
      {type = "item", name = "copper-plate", amount = 2}
    },
    results = {{type = "item", name = "tde-armor-piercing-rounds", amount = 3}},
    energy_required = 5,
    enabled = false,
    localised_name = {"recipe-name.tde-armor-piercing-rounds", "Armor-Piercing Rounds"},
    localised_description = {"recipe-description.tde-armor-piercing-rounds", "Craft devastating armor-piercing ammunition from piercing rounds and steel."}
  }
})

-- Add technologies for new ammunition
data:extend({
  {
    type = "technology",
    name = "tde-enhanced-ammunition",
    icon = "__base__/graphics/technology/military.png",
    icon_size = 256,
    effects = {
      {
        type = "unlock-recipe",
        recipe = "tde-enhanced-magazine"
      }
    },
    prerequisites = {"military", "steel-processing"},
    unit = {
      count = 50,
      ingredients = {{"tde-dead-biter", 1}},
      time = 15
    },
    order = "e-a-a",
    localised_name = {"technology-name.tde-enhanced-ammunition", "Enhanced Ammunition"},
    localised_description = {"technology-description.tde-enhanced-ammunition", "Unlock enhanced magazines with improved damage."}
  },
  {
    type = "technology",
    name = "tde-armor-piercing",
    icon = "__base__/graphics/technology/military-2.png",
    icon_size = 256,
    effects = {
      {
        type = "unlock-recipe",
        recipe = "tde-armor-piercing-rounds"
      }
    },
    prerequisites = {"tde-enhanced-ammunition", "military-2"},
    unit = {
      count = 100,
      ingredients = {{"tde-dead-biter", 1}},
      time = 30
    },
    order = "e-a-b",
    localised_name = {"technology-name.tde-armor-piercing", "Armor-Piercing Rounds"},
    localised_description = {"technology-description.tde-armor-piercing", "Unlock devastating armor-piercing ammunition."}
  }
})

log("TDE: Enhanced ammunition progression system added!")
log("TDE: Science system refactored to use only Dead Biter research tokens.")
log("TDE: Base Heart entity created as large 2x2 container with biter nest appearance and light blue tint.")
log("TDE: All systems updated for Factorio 2.0 compatibility.")
log("TDE: DYNAMIC RESEARCH COSTS with CATEGORIES implemented - costs scale based on research count and technology category!")