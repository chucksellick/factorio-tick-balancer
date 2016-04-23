--[[
TickBalancer 1.0.0

Balances your ticks so you don't have to.

Released under MIT license

Changelog:

  * 23/04/2016 1.0.0

    Initial release
]]--

require "defines"

TickBalancer = {}
TickBalancer.__index = TickBalancer

function TickBalancer.create(laneCount, tickHandler)
  local balancer = {}
  setmetatable(balancer, TickBalancer)
  balancer.handler = tickHandler
  balancer:createLanes(laneCount)
  return balancer
end

function TickBalancer.setupForEntity(entityType, globalProperty, laneCount, tickHandler, dataConstructor)
  -- Initialize global storage
  if global[globalProperty] == nil then global[globalProperty] = {} end
  -- Create the balancer
  local balancer = TickBalancer.create(laneCount, tickHandler)
  -- Register existing data
  for _,lane in ipairs(global[globalProperty]) do
    for _2,data in ipairs(lane) do
      table.insert(balancer.lanes[data.__laneNumber], data)
    end
  end
  global[globalProperty] = balancer.lanes
  -- Default data constructor
  dataConstructor = dataConstructor or (function(entity)
    return {entity=entity}
  end)
  -- Handle game events
  function onBuiltEntity(event)
    if event.created_entity.name == entityType then
      balancer:add(dataConstructor(event.created_entity))
    end
  end
  function onMinedItem(event)
    if event.item_stack.name == entityType then
      for _,lane in ipairs(balancer.lanes) do
        for _2,data in ipairs(lane) do
          if not data.entity.valid then
            table.remove(lane, _2)
          end
        end
      end
    end
  end
  function onEntityDied(event)
    if event.entity.name == entityType then
      for _,lane in ipairs(balancer.lanes) do
        for _2,data in ipairs(lane) do
          if data.entity == event.entity then
            table.remove(lane, _2)
            return
          end
        end
      end
    end
  end

  script.on_event(defines.events.on_built_entity, onBuiltEntity)
  script.on_event(defines.events.on_robot_built_entity, onBuiltEntity)
  script.on_event(defines.events.on_player_mined_item, onMinedItem)
  script.on_event(defines.events.on_robot_mined, onMinedItem)
  script.on_event(defines.events.on_entity_died, onEntityDied)

  -- Handle ticks
  script.on_event(defines.events.on_tick, function(event)
    balancer:onTick(event)
  end)
  return balancer
end

function TickBalancer:createLanes(laneCount)
  self.laneCount = laneCount
  self.lanes = {}
  for n = 1,laneCount do
    self.lanes[n] = {}
  end
end

function TickBalancer:migrateEntityData(dataList, mutator)
  for _,data in ipairs(dataList) do
    if mutator then data = mutator(data) end
    if data.entity and data.entity.valid then
      self:assignLane(data)
      table.insert(self.lanes[data.__laneNumber], data)
    end
  end
end

function TickBalancer:getIterator()
  local lane = 1
  local index = 0
  return function()
    index = index + 1
    if self.lanes[lane][index] == nil then
      lane = lane + 1
      if lane > self.laneCount then
        return nil
      end
    end
    return self.lanes[lane][index]
  end
end

function TickBalancer:onTick(event)
  local whichLane = self.lanes[event.tick % self.laneCount + 1]
  for _,data in ipairs(whichLane) do
    self.handler(data)
  end
end

function TickBalancer:assignLane(data)
  local lowestLane = nil
  local lowestLaneCount = nil
  for _,lane in ipairs(self.lanes) do
    local thisLaneCount = #lane
    if lowestLaneCount == nil or thisLaneCount < lowestLaneCount then
      lowestLane = _
      lowestLaneCount = thisLaneCount
    end
  end
  data.__laneNumber = lowestLane
end

function TickBalancer:add(data)
  self:assignLane(data)
  table.insert(self.lanes[data.__laneNumber], data)
end

function TickBalancer:remove(data)
  for _,lane in ipairs(self.lanes) do
    for _2,whichData in ipairs(lane) do
      if whichData == data then
        table.remove(lane, _2)
      end
    end
  end
end