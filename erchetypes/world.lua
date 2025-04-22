
local path = (...):gsub('%.[^%.]+$', '')


local SchemaSet = require(path .. ".SchemaSet")


---@class erchetypes.ECS
---@field schema SchemaSet.Schema
---@field hasLoadedEntityTypes boolean
---@field validETypes table<erchetypes.EType, true?>
---@field validComponents table<string, true?>
---@field keyToErch table<string, erchetypes.Erchetype>
---@field addBuffer erchetypes.Entity[]
---@field remBuffer erchetypes.Entity[]
local ECS = {}


local ECS_mt = {__index = ECS}




---@return erchetypes.ECS
local function newECS()
    local self = setmetatable({}, ECS_mt)

    self.schema = SchemaSet.newSchema()
    self.hasLoadedEntityTypes = false

    self.keyToErch = {--[[
        [key] -> Erchetype
    ]]}

    self.validETypes = {--[[
        [etype] -> true
    ]]}

    self.validComponents = {--[[
        [etype] -> true
    ]]}

    return self
end



function ECS:defineComponent(compName)
    self.validComponents[compName] = true
    self.schema:defineNewElement(compName)
end

function ECS:isValidComponent(compName)
    return self.validComponents[compName]
end


---@param self erchetypes.ECS
---@param compName any
local function assertValidComp(self, compName)
    if not self.validComponents[compName] then
        error("Undefined/invalid component: " .. tostring(compName))
    end
end




---@class erchetypes.Erchetype
---@field schset SchemaSet.Set
---@field components string[]
---@field forwardGraph table<string, erchetypes.Erchetype>
---@field backGraph table<string, erchetypes.Erchetype>
---@field ecs table<string, erchetypes.ECS>
local Erchetype = {}
local Erchetype_mt = {__index = Erchetype}




local newErchetype

do
local function findMissingComp(biggerErch, smallerErch)
    for _, c in ipairs(biggerErch:getComponents()) do
        if not smallerErch:hasComponent(c) then
            return c
        end
    end
    error("Wot wot?")
end



--- This function will update the forward/back graphs between 2 erchetypes, 
--- IF appropriate.
---@param erch1 erchetypes.Erchetype
---@param erch2 erchetypes.Erchetype
local function tryUpdateErchetypeEdge(erch1, erch2)
    local n1 = erch1:getComponents()
    local n2 = erch2:getComponents()

    if (n1 - n2) == 1 then
        -- (erch1 -> erch2) is a step backwards, aka removing a component:
        local comp = findMissingComp(erch1, erch2)
        erch2.forwardGraph[comp] = erch1
        erch1.backGraph[comp] = erch2
    elseif (n1 - n2) == -1 then
        -- (erch1 -> erch2) is a step forwards, aka ADDING a component:
        local comp = findMissingComp(erch2, erch1)
        erch2.backGraph[comp] = erch1
        erch1.forwardGraph[comp] = erch2
    end
end


---@param ecs erchetypes.ECS
---@param components string[]
---@return erchetypes.Erchetype
function newErchetype(ecs, components)
    local self = setmetatable({}, Erchetype_mt)

    self.schset = ecs.schema:newSet(components)
    self.components = components
    self.ecs = ecs

    -- forwardGraph and backGraph is basically just a big graph of
    -- erchetypes, where each edge is a transition 
    -- (either removing a component, or adding a component)

    -- when we add a component, we walk the forwardGraph 
    self.forwardGraph = {--[[
        [comp] -> erch
    ]]}
    -- (^^^ same for backGraph, but for component removal)
    self.backGraph = {--[[
        [comp] -> erch
    ]]}

    for _, erch in pairs(ecs.keyToErch) do
        tryUpdateErchetypeEdge(self, erch)
    end

    return self
end

end



---Walks forward across the erchetype graph
---@param comp string
---@return erchetypes.Erchetype
function Erchetype:forward(comp)
    if self.forwardGraph[comp] then
        return self.forwardGraph[comp]
    end

    local erch = newErchetype(self.ecs, {comp})
    error("todo")
end

---Walks backwards across the erchetype graph
---@param comp string
---@return erchetypes.Erchetype
function Erchetype:back(comp)
    return self
end

---Walks backwards across the erchetype graph
---@return erchetypes.Erchetype
function Erchetype:getComponents()
    return self.schset:getElements()
end






---@param self erchetypes.ECS
---@param schset SchemaSet.Set
local function getOrMakeErchetype(self, schset)
    local k = schset:getKey()
    if self.keyToErch[k] then
        return self.keyToErch[k]
    end

    -- make new:
    local erch = Erchetype()
end


function ECS:defineEntityType(etype)
    local comps = {}
    for comp, _v in pairs(etype) do
        assertValidComp(self, comp)
        table.insert(comps)
    end
    local set = self.schema:newSet(comps)
end



function ECS:addEntity()
end
function ECS:removeEntity()
end

function ECS:flush()
end




function ECS:newEntity(etype, args_or_nil)

end





return newECS
