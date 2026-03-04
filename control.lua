-- Control script for air filtering mod
-- Makes efficiency modules increase pollution removal rate instead of reducing energy consumption

script.on_init(function()
  -- Initialize global table
  global.air_filtering = global.air_filtering or {
    entities = {}
  }
end)

script.on_configuration_changed(function(event)
  -- Handle mod updates
  global.air_filtering = global.air_filtering or { entities = {} }
end)

-- Function to recalculate pollution removal based on modules
local function recalculate_pollution_removal(entity)
  if not entity.valid then return end

  local module_inventory = entity.get_module_inventory()
  if not module_inventory then return end

  local base_pollution = 0
  local efficiency_bonus = 0
  local speed_bonus = 0

  -- Get base pollution value from entity type
  local entity_type = entity.name
  if entity_type == "air-filter-machine" then
    base_pollution = 180  -- Positive value, we'll negate it later
  elseif entity_type == "air-filter-machine-mk2" then
    base_pollution = 480
  elseif entity_type == "air-filter-machine-mk3" then
    base_pollution = 2400
  end

  -- Calculate module effects
  for i = 1, #module_inventory do
    local module = module_inventory[i]
    if module and module.valid and module.name then
      local module_def = game.item_prototypes[module.name]
      if module_def and module_def.module_specification then
        local spec = module_def.module_specification

        -- Handle efficiency modules - convert to pollution removal bonus
        if spec.effect and spec.effect.effectivity then
          local eff_value = spec.effect.effectivity
          if eff_value < 0 then
            -- This is an efficiency module (e.g., -30% = -0.3)
            -- Convert efficiency to pollution removal: -30% efficiency = +20% pollution removal
            efficiency_bonus = efficiency_bonus + (math.abs(eff_value) * 0.67)
          end
        end

        -- Handle speed modules
        if spec.effect and spec.effect.speed then
          speed_bonus = speed_bonus + spec.effect.speed
        end
      end
    end
  end

  -- Store the multipliers
  local entity_key = entity.unit_number
  global.air_filtering.entities[entity_key] = {
    entity = entity,
    base_pollution = base_pollution,
    efficiency_bonus = efficiency_bonus,
    speed_bonus = speed_bonus,
    last_applied_tick = game.tick
  }
end

-- Handle entity built events (player built)
script.on_event(defines.events.on_built_entity, function(event)
  local entity = event.entity
  if entity and entity.name and string.find(entity.name, "air-filter-machine") then
    recalculate_pollution_removal(entity)
  end
end)

-- Handle robot built events
script.on_event(defines.events.on_robot_built_entity, function(event)
  local entity = event.entity
  if entity and entity.name and string.find(entity.name, "air-filter-machine") then
    recalculate_pollution_removal(entity)
  end
end)

-- Handle space platform built events
script.on_event(defines.events.on_space_platform_built_entity, function(event)
  local entity = event.entity
  if entity and entity.name and string.find(entity.name, "air-filter-machine") then
    recalculate_pollution_removal(entity)
  end
end)

-- Handle entity cloned (for blueprint placement)
script.on_event(defines.events.on_entity_cloned, function(event)
  local entity = event.destination
  if entity and entity.name and string.find(entity.name, "air-filter-machine") then
    recalculate_pollution_removal(entity)
  end
end)

-- Handle entity died
script.on_event(defines.events.on_entity_died, function(event)
  local entity = event.entity
  if entity then
    local entity_key = entity.unit_number
    if entity_key and global.air_filtering.entities[entity_key] then
      global.air_filtering.entities[entity_key] = nil
    end
  end
end)

-- Handle player mined entity
script.on_event(defines.events.on_player_mined_entity, function(event)
  local entity = event.entity
  if entity then
    local entity_key = entity.unit_number
    if entity_key and global.air_filtering.entities[entity_key] then
      global.air_filtering.entities[entity_key] = nil
    end
  end
end)

-- Handle robot mined entity
script.on_event(defines.events.on_robot_mined_entity, function(event)
  local entity = event.entity
  if entity then
    local entity_key = entity.unit_number
    if entity_key and global.air_filtering.entities[entity_key] then
      global.air_filtering.entities[entity_key] = nil
    end
  end
end)

-- Handle space platform mined entity
script.on_event(defines.events.on_space_platform_mined_entity, function(event)
  local entity = event.entity
  if entity then
    local entity_key = entity.unit_number
    if entity_key and global.air_filtering.entities[entity_key] then
      global.air_filtering.entities[entity_key] = nil
    end
  end
end)

-- Handle entity settings pasted (for copy/paste entity with modules)
script.on_event(defines.events.on_entity_settings_pasted, function(event)
  local entity = event.destination
  if entity and entity.name and string.find(entity.name, "air-filter-machine") then
    recalculate_pollution_removal(entity)
  end
end)

-- Periodic pollution application (every 30 ticks = 0.5 seconds)
script.on_event(defines.events.on_tick, function(event)
  if event.tick % 30 == 0 then
    for entity_key, data in pairs(global.air_filtering.entities or {}) do
      if data.entity and data.entity.valid then
        local entity = data.entity
        local surface = entity.surface
        local position = entity.position

        -- Calculate final pollution removal multiplier
        -- Base + efficiency bonus (efficiency modules increase pollution removal)
        -- Speed modules also increase effective pollution removal by processing faster
        local total_multiplier = 1.0 + data.efficiency_bonus + (data.speed_bonus * 0.5)

        -- Calculate final pollution value (negative for removal)
        local final_pollution = -(data.base_pollution * total_multiplier)

        -- Remove pollution from the surface
        -- Note: We can't directly set emissions_per_minute, so we manually remove pollution
        surface.pollute(position, -final_pollution * 0.5) -- Negative of negative = removal

        data.last_applied_tick = game.tick
      else
        -- Clean up invalid entities
        global.air_filtering.entities[entity_key] = nil
      end
    end
  end
end)
