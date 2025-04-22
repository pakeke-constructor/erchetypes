
--[[

From:
https://github.com/pakeke-constructor/SchemaSet

]]

---@meta


local bit = rawget(_G, "bit") or require("bit")



local api = {}


---@class SchemaSet.Schema
---@field elementToIndex table<any, integer>
---@field indexToElement table<integer, any>
---@field cachedSets table<string, SchemaSet.Set>
---@field elements string[]
---@field nextBitIndex integer
local Schema = {}

local Schema_mt = {
    __index = Schema
}


local function defensiveCopy(tabl)
    local ret = {}
    for _, v in ipairs(tabl) do
        table.insert(ret,v)
    end
    return ret
end


---@param elements any[]
---@return SchemaSet.Schema
function api.newSchema(elements)
    local self = setmetatable({}, Schema_mt)

    self.elementToIndex = {--[[
        [element] -> bit-index
    ]]}
    self.indexToElement = {--[[
        [bit-index] -> element
    ]]}

    self.cachedSets = {--[[
        [setKey] --> SchemaSet
    ]]}

    self.elements = defensiveCopy(elements)

    local i = 0
    for _, elem in ipairs(elements) do
        self.elementToIndex[elem] = i
        self.indexToElement[i] = elem
        i = i + 1
    end

    self.nextBitIndex = i

    return self
end



---@param elem string
function Schema:defineNewElement(elem)
    assert(type(elem) == "string")
    if self.elementToIndex[elem] then
        error("Duplicate element added: " .. elem)
    end

    local i = self.nextBitIndex

    table.insert(self.elements, elem)
    self.indexToElement[i] = elem
    self.elementToIndex[elem] = i

    self.nextBitIndex = i + 1
end


function Schema:hasElement(elem)
    return self.elementToIndex[elem]
end


---@class SchemaSet.Set
---@field bitVec integer[]
---@field schema SchemaSet.Schema
---@field cachedKey string
---@field cachedElements any[]
local Set = {}
local Set_mt = {__index=Set}



local BITS = 32
-- 32 bits per number
-- https://bitop.luajit.org/semantics.html#range



local function setBit(bitVec, i, bool)
    local j = math.floor(i / BITS) + 1 -- index of num in bitVec
    local num = bitVec[j]
    local shift = i % BITS
    if bool then
        -- set bit to 1
        local t = bit.lshift(1, shift)
        num = bit.bor(num, t)
    else
        -- set bit to 0
        local t = bit.bnot(bit.lshift(1, shift))
        num = bit.band(num, t)
    end

    bitVec[j] = num
end


local function getBit(bitVec, i)
    local j = math.floor(i / BITS) + 1 -- index of num in bitVec
    local num = bitVec[j]
    local shift = i % BITS
    local t = bit.lshift(1, shift)
    local res = bit.band(t, num)
    if res == 0 then
       return false
    else
        return true
    end
end



---@param bitVec integer[]
---@return string
local function makeKey(bitVec)
    return table.concat(bitVec, "-")
end



---@param schema SchemaSet.Schema
---@param bitVec integer[]
---@return SchemaSet.Set
local function newSetFromBitVec(schema, bitVec)
    local key = makeKey(bitVec)
    if schema.cachedSets[key] then
       return schema.cachedSets[key]
    end

    local scSet = setmetatable({
        bitVec = bitVec,
        cachedKey = key,
        schema = schema,

        -- lazy-eval for getElements
        cachedElements = false
    }, Set_mt)
    schema.cachedSets[key] = scSet
    return scSet
end


---@param elements any[]
---@return SchemaSet.Set
function Schema:newSet(elements)
    local bitNumLen = math.floor(#self.indexToElement / 32) + 1
    local bitVec = {}
    for i=1, bitNumLen do
        -- initialize with zeros
        table.insert(bitVec, 0)
    end
    for _, elem in ipairs(elements) do
        local i = self.elementToIndex[elem]
        if (type(elem) ~= "string") or (not i) then
            error("Invalid element: " .. tostring(elem))
        end
        setBit(bitVec, i, true)
    end
    local key = makeKey(bitVec)
    if self.cachedSets[key] then
        return self.cachedSets[key]
    end

    ---@type SchemaSet.Set
    local scSet = setmetatable({
        bitVec = bitVec,
        schema = self,

        -- caching for efficiency
        cachedKey = false,
        cachedElements = defensiveCopy(elements),
    }, Set_mt)

    self.cachedSets[key] = scSet

    return scSet
end



function Set:hasElement(elem)
    local i = self.schema.elementToIndex[elem]
    if not i then
        error("invalid element: " .. tostring(elem))
    end
    return getBit(self.bitVec, i)
end



---@return string
function Set:getKey()
    if self.cachedKey then
        return self.cachedKey
    end
    self.cachedKey = makeKey(self.bitVec)
    return self.cachedKey
end


---@param otherSet SchemaSet.Set
---@return boolean
function Set:isSubsetOf(otherSet)
    local otherBitVec = otherSet.bitVec
    for i, n in ipairs(self.bitVec) do
        local n2 = otherBitVec[i]
        if bit.band(n, n2) ~= n then
            return false
        end
    end
    return true
end


--- Creates a new Set with an extra component added.
--- similar to  set:union( newSet({elem}) ),
--- just slightly more efficient/ergonomic
---@param elem string
---@return SchemaSet.Set
function Set:add(elem)
    local newElems = defensiveCopy(self:getElements())
    table.insert(newElems, elem)
    return self.schema:newSet(newElems)
end


--- Creates a new Set with a component removed.
--- similar to  set:intersect( newSet({everything except elem}) ),
--- just slightly more efficient/ergonomic
---@param elem string
---@return SchemaSet.Set
function Set:remove(elem)
    local newElems = {}
    for _, v in ipairs(self:getElements()) do
        if v ~= elem then
            table.insert(newElems, elem)
        end
    end
    return self.schema:newSet(newElems)
end




---@param otherSet SchemaSet.Set
---@return boolean
function Set:equals(otherSet)
    local otherBitVec = otherSet.bitVec
    for i, n in ipairs(self.bitVec) do
        local n2 = otherBitVec[i]
        if n ~= n2 then
            return false
        end
    end
    return true
end


---@param otherSet SchemaSet.Set
---@return SchemaSet.Set
function Set:intersect(otherSet)
    local newBitVec = {}
    local otherBitVec = otherSet.bitVec
    for i, n in ipairs(self.bitVec) do
        local n2 = otherBitVec[i]
        local newNum = bit.band(n,n2)
        newBitVec[i] = newNum
    end
    return newSetFromBitVec(self.schema, newBitVec)
end



---@param otherSet SchemaSet.Set
---@return SchemaSet.Set
function Set:union(otherSet)
    local newBitVec = {}
    local otherBitVec = otherSet.bitVec
    for i, n in ipairs(self.bitVec) do
        local n2 = otherBitVec[i]
        local newNum = bit.bor(n,n2)
        newBitVec[i] = newNum
    end
    return newSetFromBitVec(self.schema, newBitVec)
end


---@return any[]
function Set:getElements()
    if self.cachedElements then
        return self.cachedElements
    end
    -- (This entire algorithm is kinda slow, bit eh, its cached.)
    local elems = {}
    local schema = self.schema
    for i=0, #schema.indexToElement do
        if getBit(self.bitVec, i) then
            -- if the bit is toggled for this element; add it.
            local elem = schema.indexToElement[i]
            table.insert(elems, elem)
        end
    end
    self.cachedElements = elems
    return elems
end








--[[
-----------------------------------------
==============================================================

TESTING!
Everything below this point is unit tests.

If you wanna activate testing, just set `TEST = true`.
It is `false` by default.

==============================================================
-----------------------------------------
]]


local TEST = true
if not TEST then
    return
end

--- tests
do

---@param s any
local function printElems(s)
    local str = "{ " .. table.concat(s:getElements(), ", ") .. " }"
    print(str)
end

---@param elems2 any[]
---@param elems1 any[]
local function assertEqual(elems1, elems2)
    elems1 = defensiveCopy(elems1)
    elems2 = defensiveCopy(elems2)
    table.sort(elems1)
    table.sort(elems2)

    assert(#elems1 == #elems2)
    for i=1,#elems1 do
        assert(elems1[i]==elems2[i])
    end
end


--- Basic tests:
do
local allElems = {"a", "b", "bb", "c", "e"}
local sc = api.newSchema(allElems)

local s0 = sc:newSet(allElems)

local s1 = sc:newSet({"a","b","c"})
local s2 = sc:newSet({"a","b","bb"})
local s3 = sc:newSet({"bb","b","c"})
local s4 = sc:newSet({"e"})


-- test intersection:
assertEqual(s1:intersect(s2):getElements(), {"b","a"})
assertEqual(s2:intersect(s3):getElements(), {"b","bb"})
assertEqual(s1:intersect(s2):intersect(s3):getElements(), {"b"})
assertEqual(s0:intersect(s4):getElements(), {"e"})

-- test union:
assertEqual(s1:union(s2):getElements(), {"a","b","bb","c"})
assertEqual(s1:union(s4):getElements(), {"a","b","c","e"})
assertEqual(s0:union(s3):getElements(), allElems)



-- test caching:
assert(s1:intersect(s2) == s2:intersect(s1), "caching aint working!")
local s1_2 = sc:newSet({"a","b","c"})
assert(s1 == s1_2, "Caching aint working!")
assert(s3:intersect(s0) == s3, "Caching aint working!")
assert(s2:union(s0) == s0, "Caching aint working!")
end



-- Testing bitVec set/get:
do
local bitVec = {0,0}

-- basic calls:
local i,j = 0,1 -- indexes into bitVec
setBit(bitVec, i, true)
assert(bitVec[1] == 1)
assert(getBit(bitVec, i))
assert(not getBit(bitVec, j))

setBit(bitVec, j, true)
assert(bitVec[1] == 3)
assert(getBit(bitVec, j))

-- trying multiple numbers:
local k=32
setBit(bitVec, k, true)
assert(bitVec[2] == 1)
assert(getBit(bitVec, k))

end




-- Testing a big schema:
do
local allElems = {}
for i=1, 100 do
    table.insert(allElems, tostring(i))
end
local bigSchema = api.newSchema(allElems)

local s1 = bigSchema:newSet(allElems)
assertEqual(s1:getElements(), allElems)

local oddElems = {}
local evenElems = {}
for i=1, #allElems, 2 do
    table.insert(oddElems, allElems[i])
    local j=i+1
    if allElems[j] then
        table.insert(evenElems, allElems[j])
    end
end

local n1 = bigSchema:newSet({"1"})
local n2 = bigSchema:newSet({"2"})
local n99 = bigSchema:newSet({"99"})
local n50 = bigSchema:newSet({"50"})

local odds = bigSchema:newSet(oddElems)
local evens = bigSchema:newSet(evenElems)

assertEqual(n1:union(n2):union(n99):union(n50):getElements(), {"1","2","50","99"})

assertEqual(odds:union(evens):getElements(), allElems)
assert(odds:union(evens) == evens:union(odds))

end

end

print("ALL TESTS DONE.")


