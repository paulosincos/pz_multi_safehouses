local SafehouseServer = {}

---@type Callback_OnClientCommand
---@param module string
---@param command string
---@param playerObj IsoPlayer
---@param args table | nil
SafehouseServer.OnClientCommand = function(module, command, playerObj, args)
    -- Process only commands sent by this mod.
    if module ~= "MultiSafehouses" then return end
    
    if command == "claimAdditionalSafehouse" then
        if not args then return end
        -- Recreate the square using client-provided coordinates.
        local square = getSquare(args.x, args.y, args.z)
        if not square then return end
        
        -- Prevent duplicate claims on the server.
        if not SafeHouse then return end
        if SafeHouse.getSafeHouse(square) then 
            playerObj:Say(getText("IGUI_Safehouse_AlreadyHaveSafehouse"))
            return 
        end
        
        -- Create the native Build 42 safehouse record.
        local newSafehouse = SafeHouse.addSafeHouse(square, playerObj)
        
        if newSafehouse then
            local title = playerObj:getUsername()
            newSafehouse.setTitle(newSafehouse, title)
            -- Ask the owner client to emit the native SyncSafehouse packet.
            sendServerCommand(playerObj, "MultiSafehouses", "syncSafehouse", {
                x = args.x,
                y = args.y,
                z = args.z,
                title = title
            })
        end
    end
end

Events.OnClientCommand.Add(SafehouseServer.OnClientCommand)
