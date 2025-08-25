-- Runtime settings for Tower Defense Evolution

data:extend({
  {
    type = "int-setting",
    name = "tde-safe-zone-radius",
    setting_type = "runtime-global",
    default_value = 175,
    minimum_value = 100,
    order = "a-safe-zone"
  },
  {
    type = "int-setting", 
    name = "tde-wave-interval",
    setting_type = "runtime-global",
    default_value = 10, -- minutes
    minimum_value = 1,
    maximum_value = 30,
    order = "b-wave-interval"
  },
  {
    type = "int-setting",
    name = "tde-nest-spacing",
    setting_type = "runtime-global", 
    default_value = 5,
    minimum_value = 3,
    maximum_value = 15,
    order = "c-nest-spacing"
  },
  {
    type = "double-setting",
    name = "tde-kill-multiplier",
    setting_type = "runtime-global",
    default_value = 1.0,
    minimum_value = 0.5,
    maximum_value = 3.0,
    order = "d-kill-multiplier"
  },
  {
    type = "int-setting",
    name = "tde-resource-amount",
    setting_type = "runtime-global",
    default_value = 2000000,
    minimum_value = 500000,
    maximum_value = 100000000,
    order = "e-resource-amount"
  },
  {
    type = "bool-setting",
    name = "tde-show-kill-messages",
    setting_type = "runtime-global",
    default_value = true,
    order = "f-kill-messages"
  },
  -- NEW: Setting to control ammo system messages
  {
    type = "bool-setting",
    name = "tde-show-ammo-messages",
    setting_type = "runtime-global",
    default_value = false, -- Default to false to reduce spam
    order = "f2-ammo-messages",
    localised_name = {"mod-setting-name.tde-show-ammo-messages"},
    localised_description = {"mod-setting-description.tde-show-ammo-messages"}
  },
  
  -- ===== DYNAMIC RESEARCH COST SETTINGS =====
  {
    type = "int-setting",
    name = "tde-research-base-cost",
    setting_type = "runtime-global",
    default_value = 10,
    minimum_value = 1,
    order = "g-research-base-cost",
    localised_name = {"mod-setting-name.tde-research-base-cost"},
    localised_description = {"mod-setting-description.tde-research-base-cost"}
  },
  {
    type = "int-setting",
    name = "tde-research-increment-1",
    setting_type = "runtime-global",
    default_value = 10,
    minimum_value = 1,
    order = "h-research-increment-1",
    localised_name = {"mod-setting-name.tde-research-increment-1"},
    localised_description = {"mod-setting-description.tde-research-increment-1"}
  },
  {
    type = "int-setting",
    name = "tde-research-threshold-1",
    setting_type = "runtime-global",
    default_value = 100,
    minimum_value = 50,
    order = "i-research-threshold-1",
    localised_name = {"mod-setting-name.tde-research-threshold-1"},
    localised_description = {"mod-setting-description.tde-research-threshold-1"}
  },
  {
    type = "int-setting",
    name = "tde-research-increment-2",
    setting_type = "runtime-global",
    default_value = 15,
    minimum_value = 1,
    order = "j-research-increment-2",
    localised_name = {"mod-setting-name.tde-research-increment-2"},
    localised_description = {"mod-setting-description.tde-research-increment-2"}
  },
  {
    type = "int-setting",
    name = "tde-research-threshold-2",
    setting_type = "runtime-global",
    default_value = 500,
    minimum_value = 200,
    order = "k-research-threshold-2",
    localised_name = {"mod-setting-name.tde-research-threshold-2"},
    localised_description = {"mod-setting-description.tde-research-threshold-2"}
  },
  {
    type = "int-setting",
    name = "tde-research-increment-3",
    setting_type = "runtime-global",
    default_value = 20,
    minimum_value = 1,
    order = "l-research-increment-3",
    localised_name = {"mod-setting-name.tde-research-increment-3"},
    localised_description = {"mod-setting-description.tde-research-increment-3"}
  },
  {
    type = "int-setting",
    name = "tde-research-threshold-3",
    setting_type = "runtime-global",
    default_value = 1000,
    minimum_value = 500,
    order = "m-research-threshold-3",
    localised_name = {"mod-setting-name.tde-research-threshold-3"},
    localised_description = {"mod-setting-description.tde-research-threshold-3"}
  },
  {
    type = "int-setting",
    name = "tde-research-increment-final",
    setting_type = "runtime-global",
    default_value = 30,
    minimum_value = 1,
    order = "n-research-increment-final",
    localised_name = {"mod-setting-name.tde-research-increment-final"},
    localised_description = {"mod-setting-description.tde-research-increment-final"}
  },
  {
    type = "double-setting",
    name = "tde-research-cost-multiplier",
    setting_type = "runtime-global",
    default_value = 1.0,
    minimum_value = 0.1,
    order = "o-research-cost-multiplier",
    localised_name = {"mod-setting-name.tde-research-cost-multiplier"},
    localised_description = {"mod-setting-description.tde-research-cost-multiplier"}
  },
  {
    type = "bool-setting",
    name = "tde-master-chest-enabled",
    setting_type = "runtime-global",
    default_value = true,
    minimum_value = false,
    order = "o-master-chest-enabled",
    localised_name = {"mod-setting-name.tde-master-chest-enabled"},
    localised_description = {"mod-setting-description.tde-master-chest-enabled"}
  },
  
  -- ===== SPACE AGE DLC SETTINGS =====
  {
    type = "bool-setting",
    name = "tde-space-age-integration",
    setting_type = "runtime-global",
    default_value = true,
    order = "p-space-age-integration",
    localised_name = {"mod-setting-name.tde-space-age-integration"},
    localised_description = {"mod-setting-description.tde-space-age-integration"}
  },
  {
    type = "double-setting",
    name = "tde-planet-enemy-ratio",
    setting_type = "runtime-global",
    default_value = 0.3,
    minimum_value = 0.0,
    maximum_value = 1.0,
    order = "q-planet-enemy-ratio",
    localised_name = {"mod-setting-name.tde-planet-enemy-ratio"},
    localised_description = {"mod-setting-description.tde-planet-enemy-ratio"}
  },
  {
    type = "bool-setting",
    name = "tde-vulkanus-boss-priority",
    setting_type = "runtime-global",
    default_value = true,
    order = "r-vulkanus-boss-priority",
    localised_name = {"mod-setting-name.tde-vulkanus-boss-priority"},
    localised_description = {"mod-setting-description.tde-vulkanus-boss-priority"}
  },
  
  -- ===== MULTIPLAYER SETTINGS =====
  {
    type = "bool-setting",
    name = "tde-multiplayer-sync",
    setting_type = "runtime-global",
    default_value = true,
    order = "s-multiplayer-sync",
    localised_name = {"mod-setting-name.tde-multiplayer-sync"},
    localised_description = {"mod-setting-description.tde-multiplayer-sync"}
  },
  {
    type = "int-setting",
    name = "tde-sync-interval",
    setting_type = "runtime-global",
    default_value = 300,
    minimum_value = 60,
    maximum_value = 1800,
    order = "t-sync-interval",
    localised_name = {"mod-setting-name.tde-sync-interval"},
    localised_description = {"mod-setting-description.tde-sync-interval"}
  }
})