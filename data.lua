-- Data stage - Master Ammo Chest and Turret Buffs

data:extend({
  -- Master Ammo Chest entity
  {
    type = "container",
    name = "master-ammo-chest",
    icon = "__base__/graphics/icons/steel-chest.png",
    icon_size = 64,
    flags = {"placeable-neutral", "player-creation"},
    minable = {mining_time = 0.3, result = "master-ammo-chest"},
    max_health = 500,
    corpse = "steel-chest-remnants",
    dying_explosion = "steel-chest-explosion",
    open_sound = {filename = "__base__/sound/metallic-chest-open.ogg", volume = 0.5},
    close_sound = {filename = "__base__/sound/metallic-chest-close.ogg", volume = 0.5},
    resistances = {
      {type = "fire", decrease = 3, percent = 90},
      {type = "impact", decrease = 20, percent = 70},
      {type = "explosion", decrease = 15, percent = 60}
    },
    collision_box = {{-0.35, -0.35}, {0.35, 0.35}},
    selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
    inventory_size = 120, -- Large inventory for ammo storage
    picture = {
      layers = {
        {
          filename = "__base__/graphics/entity/steel-chest/steel-chest.png",
          priority = "extra-high",
          width = 64,
          height = 80,
          shift = {-0.03125, -0.0625},
          tint = {r = 0.9, g = 0.3, b = 0.1}, -- Distinctive red color
          hr_version = {
            filename = "__base__/graphics/entity/steel-chest/hr-steel-chest.png",
            priority = "extra-high",
            width = 126,
            height = 158,
            shift = {-0.03125, -0.0625},
            scale = 0.5,
            tint = {r = 0.9, g = 0.3, b = 0.1}
          }
        }
      }
    },
    circuit_wire_max_distance = 15
  },
  
  -- Master Ammo Chest item
  {
    type = "item",
    name = "master-ammo-chest",
    icon = "__base__/graphics/icons/steel-chest.png",
    icon_size = 64,
    subgroup = "storage",
    order = "a[items]-d[master-ammo-chest]",
    place_result = "master-ammo-chest",
    stack_size = 50
  },
  
  -- Master Ammo Chest recipe - Iron chest with basic materials
  {
    type = "recipe",
    name = "master-ammo-chest",
    ingredients = {
      {type = "item", name = "iron-chest", amount = 1},
      {type = "item", name = "coal", amount = 1},
      {type = "item", name = "iron-ore", amount = 1},
      {type = "item", name = "copper-ore", amount = 1}
    },
    results = {{type = "item", name = "master-ammo-chest", amount = 1}},
    energy_required = 2,
    enabled = true -- Available from start, no research needed
  }
})