-- =============================================================================
-- 1. HELPER FUNCTIONS
-- =============================================================================

-- Check for living zombies in the loaded building area.
local function IsBuildingClearOfZombies(building)
    if not building then return true end
    local cell = getCell()
    local objectList = cell:getZombieList()
    if not objectList then return true end

    for i = 0, objectList:size() - 1 do
        local zombie = objectList:get(i)
        if zombie and not zombie:isDead() then
            local zombieSquare = zombie:getCurrentSquare()
            if zombieSquare and zombieSquare:getBuilding() == building then
                return false -- Zumbi vivo encontrado dentro da estrutura!
            end
        end
    end
    return true
end

-- Check for other players inside the same building.
local function IsPlayerInsideBuilding(building, playerObj)
    if not building then return false end
    local players = getOnlinePlayers()
    
    if players then
        -- Multiplayer and co-op player loop.
        for i = 0, players:size() - 1 do
            local p = players:get(i)
            local pSquare = p:getCurrentSquare()
            if pSquare and pSquare:getBuilding() == building and p ~= playerObj then
                return true
            end
        end
    else
        -- Safe fallback for pure single-player games.
        for i = 0, 3 do
            local p = getSpecificPlayer(i)
            if p and p ~= getSpecificPlayer(0) then
                local pSquare = p:getCurrentSquare()
                if pSquare and pSquare:getBuilding() == building then
                    return true
                end
            end
        end
    end
    return false
end

-- Check whether a building is public using Build 42 BuildingDef data.
local function IsPublicBuilding(building)
    if not building then return false end
    
    local def = building:getDef()
    if not def then return false end
    
    local rooms = def:getRooms()
    if not rooms then return false end
    
    for i = 0, rooms:size() - 1 do
        local roomDef = rooms:get(i)
        
        if roomDef then
            -- Check the internal room name defined by the zone.
            local roomName = roomDef:getName()
            if roomName == "police" or roomName == "medical" or roomName == "firestation" then
                return true
            end
            
            -- Check the PVP status when the room is loaded.
            local isoRoom = roomDef:getIsoRoom()
            if isoRoom and isoRoom.isPVP and isoRoom:isPVP() then
                return true
            end
        end
    end
    
    return false
end


-- =============================================================================
-- 2. CLAIM ACTION
-- =============================================================================
local function OnClaimAdditionalSafehouse(targetObject, playerObj, building)
    if not playerObj then return end
    
    local square = playerObj:getCurrentSquare()
    if square then
        -- Send the structured command to the server.
        local args = { x = square:getX(), y = square:getY(), z = square:getZ() }
        sendClientCommand(playerObj, "MultiSafehouses", "claimAdditionalSafehouse", args)
    end
end

local function OnServerCommand(module, command, args)
    if module ~= "MultiSafehouses" or command ~= "syncSafehouse" then return end

    local square = getSquare(args.x, args.y, args.z)
    local playerObj = getSpecificPlayer(0)
    if square and playerObj and not SafeHouse.getSafeHouse(square) then
        local newSafehouse = SafeHouse.addSafeHouse(square, playerObj)
        newSafehouse.setTitle(newSafehouse, args.title);
    end
end

-- =============================================================================
-- 3. CONTEXT MENU
-- =============================================================================
local function AddSafehouseContextOption(playerObj, square, context, worldObjects)
    -- Check the native safehouse list exposed by Build 42.
    if SafeHouse.getSafeHouse(square) then
        return end -- The location is already claimed.

    local building = square:getBuilding()
    -- Require the player to stand inside a functional building.
    if building and square:getRoom() then
        local targetObject = worldObjects
        local option = context:addOption(
            getText("ContextMenu_SafehouseClaim") .. " [Mod]", 
            targetObject, 
            OnClaimAdditionalSafehouse, 
            playerObj, 
            building
        )
        
        local canClaim = false
        local blockReason = ""
        local daysRequired = getServerOptions():getInteger("SafehouseDaySurvivedToClaim") or 0
        local hoursRequired = daysRequired * 24
        local isAdmin = playerObj:isAccessLevel("admin")

        -- Administrators bypass client-side claim restrictions.
        if isAdmin then
            canClaim = true
        elseif playerObj:getHoursSurvived() < hoursRequired then
            blockReason = getText("IGUI_Safehouse_DaysSurvivedToClaim", daysRequired)
        elseif not SandboxVars.SafehouseAllowPublic and IsPublicBuilding(building) then
            blockReason = getText("IGUI_Safehouse_NotHouse")
        elseif SandboxVars.SafehouseAllowTrepass == false and IsPlayerInsideBuilding(building, playerObj) then
            blockReason = getText("IGUI_Safehouse_SomeoneInside")
        elseif not IsBuildingClearOfZombies(building) then 
            blockReason = getText("IGUI_Safehouse_SomeoneInside")
        else
            canClaim = true
        end

        -- Configure a red tooltip when a rule blocks the action.
        if not canClaim then
            option.notAvailable = true
            local toolTip = ISToolTip:new()
            toolTip:initialise()
            toolTip.description = blockReason
            option.toolTip = toolTip
        end
    end
end

local function CreateContextMenu(player, context, worldObjects, test)
    if test then return end

    local playerObj = getSpecificPlayer(player)
    local square = playerObj:getCurrentSquare()
    if square then
        AddSafehouseContextOption(playerObj, square, context, worldObjects)
    end
end

Events.OnFillWorldObjectContextMenu.Add(CreateContextMenu)
Events.OnServerCommand.Add(OnServerCommand)
