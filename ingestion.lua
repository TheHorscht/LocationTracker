function split_string(inputstr, sep)
  sep = sep or "%s"
  local t= {}
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    table.insert(t, str)
  end
  return t
end

local entity_id = GetUpdatedEntityID()

local material_inventory_component = EntityGetFirstComponentIncludingDisabled(entity_id, "MaterialInventoryComponent")
local count_per_material_type = ComponentGetValue2(material_inventory_component, "count_per_material_type")
local water_amount = count_per_material_type[CellFactory_GetType("water")+1]
local ingestion_component = EntityGetFirstComponentIncludingDisabled(entity_id, "IngestionComponent")
local ingestion_size = ComponentGetValue2(ingestion_component, "ingestion_size")
local amount_to_eat_per_tick = 5

ComponentSetValue2(ingestion_component, "ingestion_size", ingestion_size - 6 * math.max(0, water_amount - amount_to_eat_per_tick))
AddMaterialInventoryMaterial(entity_id, "water", math.max(0, water_amount - amount_to_eat_per_tick))

-- local ingestion_effect_causes = ComponentGetValue2(status_effect_data_component, "ingestion_effect_causes")
-- for i, v in ipairs(ingestion_effect_causes) do
--   ingestion_effect_causes[i] = 0
-- end
local status_effect_data_component = EntityGetFirstComponentIncludingDisabled(entity_id, "StatusEffectDataComponent")
local ingestion_effects = ComponentGetValue2(status_effect_data_component, "ingestion_effects")
for i, v in ipairs(ingestion_effects) do
  ingestion_effects[i] = 0
end
ComponentSetValue2(status_effect_data_component, "ingestion_effects", ingestion_effects)
-- for k, v in pairs(ingestion_effects) do
--   if tonumber(v) > 0 then
--     print(k, v)
--   end
-- end

local damage_model_component = EntityGetFirstComponentIncludingDisabled(entity_id, "DamageModelComponent")
local hp = ComponentGetValue2(damage_model_component, "hp")
local max_hp = ComponentGetValue2(damage_model_component, "max_hp")
ComponentSetValue2(damage_model_component, "hp", math.min(max_hp, hp + 0.05/25 * water_amount))
