


# API IDEATION:

```lua

local w = ECS() -- create a new world


-- all components MUST be defined BEFORE any entities are created.
-- (AND before any etypes are defined!)
w:defineComponent("myComp")


w:flush()




-- ======================
--  ENTITIES:
-- ======================
local etype = w:defineEntityType({
    image = "moose"
})

local e = w:newEntity(etype)

local erch = e:getErchetype()

w:addEntity(e)
w:removeEntity(e)

e:addEntityInstantly(e)
e:removeEntityInstantly(e)

e:addComponent(tabl, "myComp", 123.4)
e:addComponentBuffered(tabl, "myComp", 123.4)

e:removeComponent(tabl, "myComp")
e:removeComponentBuffered(tabl, "myComp")





-- ======================
--  ENTITIES:
-- ======================
-- views must be defined at load-time
local drawView = w:view("x", "y", "image")


drawView:onEntityAdded(function(ent)
    print("ent added to view!")
end)
drawView:onEntityRemoved(function(ent)
    print("ent removed from view")
end)


drawView:forEveryErchetype(function(erch)
    -- This will be called for every erchetype that this `view` contains.
    -- It applies for all current erchetypes, 
    -- AND will be called for erchetypes lazily-created in the future too.
    print("erchetype was added!", erch)
end)


local erchList = drawView:getErchetypes()

drawView:foreachEntity(function(ent)
    -- works by iterating over the erchetypes
    print("iterated over ent: ", ent)
end)

```



# OK. Lets step back a bit.
## What API would we like to see?
```lua

local etype = w:defineEntityType({
    image = "mod:image",
    explosiveness = 10
})

local ent = w:newEntity(etype, {
    x = 5, y = 5,
    timeout = 2,
})

w:addEntity(ent)
w:removeEntity(ent)

w:flush()


```


----

<br/>
<br/>
<br/>
<br/>
<br/>
<br/>

----


# What about smart ev-buses? And erchetypes?
```lua

local call, smartOn = defineSmartEvent()

smartOn({"x", "y"}, function(ent)
    -- `ent` is guaranteed to have x,y components
end)


local function defineSmartEvent()
    local erchToFunctions = {--[[
        [erch] -> {func1, func2, func3...}
    ]]}

    -- functions that apply for EVERY erchetype
    local globalFunctions = {}

    local function call(ent, ...)
        local erch = ent:getErchetype()
        local funcs = erchToFunctions[erch]
        if funcs then
            for _,f in ipairs(funcs) do
                f(ent, ...)
            end
        end
        for _, f in ipairs(globalFunctions) do
            f(ent, ...)
        end
    end

    local function smartOn(comps, func)
        onTc(comps, func)

        if #comps == 0 then
            table.insert(globalFunctions, func)
            return
        end

        local view = w:view(comps)
        view:foreachErchetype(function(erch)
            erchToFunctions[erch] = erchToFunctions[erch] or {}
            table.insert(erchToFunctions[erch], func)
        end)
    end

    return call, smartOn
end


local call, smartOn = defineSmartEvent()


```
