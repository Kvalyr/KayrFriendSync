-- ====================================================================================================================
-- =	KayrFriendSync - Lightweight synchronization of friends & ignore lists across alts
-- =	Copyright (c) Kvalyr - 2020-2021 - All Rights Reserved
-- ====================================================================================================================
local C_FriendList = _G["C_FriendList"]
local C_Timer = _G["C_Timer"]
local GetRealmName = _G["GetRealmName"]
local GetServerTime = _G["GetServerTime"]
local UnitName = _G["UnitName"]
-- ====================================================================================================================
-- Debugging
local KLib = _G["KLib"]
if not KLib then
    KLib = {Con = function() end, Warn = function() end, Print = print} -- No-Op if KLib not available
end
-- ====================================================================================================================
local IGNORES = true

-- --------------------------------------------------------------------------------------------------------------------
-- Hooks
-- --------------------------------------------------------
function KayrFriendSync.Hook_AddIgnore(name, noHook, ...)
    -- KLib:Con("KayrFriendSync", "Hooked AddIgnore()", name, noHook, ...)
    if not noHook then
        C_FriendList.ShowFriends()
        -- Delay a few seconds to give the server time to sync
        KayrFriendSync:SaveIgnore(name, true)
    end
    return name
end

function KayrFriendSync.Hook_DelIgnore(name, noHook, ...)
    -- KLib:Con("KayrFriendSync", "Hooked DelIgnore()", name, noHook, ...)
    if not noHook then
        C_FriendList.ShowFriends()
        KayrFriendSync:RemoveSavedIgnore(name)
    end
    return name
end

function KayrFriendSync.Hook_AddOrDelIgnore(name, noHook, ...)
    -- KLib:Con("KayrFriendSync", "Hooked AddOrDelIgnore()", name, noHook, ...)
    if not noHook then
        C_FriendList.ShowFriends()
        if C_FriendList.IsIgnored(name) then
            KayrFriendSync:RemoveSavedIgnore(name)
        else
            KayrFriendSync:SaveIgnore(name, true)
        end
    end
    return name
end

-- --------------------------------------------------------------------------------------------------------------------
-- GetSavedVarsIgnoresTable / UpdateSavedVarsIgnoresTable
-- --------------------------------------------------------
function KayrFriendSync:GetSavedVarsIgnoresTable()
    if not self.initDone then return end

    local ignoresSavedVars = _G["KayrFriendSync_SV"]["ignores"][self.playerRealm]
    return ignoresSavedVars
end

function KayrFriendSync:UpdateSavedVarsIgnoresTable(newIgnoresSavedVars)
    if not self.initDone then return end
    _G["KayrFriendSync_SV"]["ignores"][self.playerRealm] = newIgnoresSavedVars
end


-- --------------------------------------------------------------------------------------------------------------------
-- RemoveSavedIgnore
-- --------------------------------------------------------
function KayrFriendSync:RemoveSavedIgnore(name)
    local ignoresSavedVars = KayrFriendSync:GetSavedVarsIgnoresTable()
    local existingIgnore = ignoresSavedVars[name]
    if existingIgnore then
        KLib:Warn("KayrFriendSync", "Removing ignore:", name)
        existingIgnore.removed = true
        ignoresSavedVars[name] = existingIgnore
    end
    KayrFriendSync:UpdateSavedVarsIgnoresTable(ignoresSavedVars)
end

-- --------------------------------------------------------------------------------------------------------------------
-- SaveFriend
-- --------------------------------------------------------
function KayrFriendSync:SaveIgnore(ignoreName, userUpdate)
    if not ignoreName or ignoreName == "" then
        -- KLib:Warn("KayrFriendSync", "Empty ignore name")
        return
    end

    local playerName = UnitName("player")
    local playerRealm = GetRealmName()
    local updateTime = GetServerTime()

    local newIgnore = {}
    newIgnore.removed = false
    newIgnore.name = ignoreName
    newIgnore.realm = playerRealm  -- TODO: Ignores can be cross-realm - Should we use that here by splitting it from the name?
    newIgnore.sourceCharacter = playerName
    newIgnore.lastUpdated = updateTime

    local ignoresSavedVars = KayrFriendSync:GetSavedVarsIgnoresTable()
    local existingIgnore = ignoresSavedVars[ignoreName]

    if existingIgnore then
        KLib:Warn("KayrFriendSync", "Existing ignore:", ignoreName)
        if userUpdate then
            -- In the case of a manual update by the user
            existingIgnore.lastUpdated = updateTime
            existingIgnore.sourceCharacter = playerName
        end
    else
        -- KLib:Con("KayrFriendSync", "New ignore:", ignoreName)
        ignoresSavedVars[ignoreName] = newIgnore
    end
    KayrFriendSync:UpdateSavedVarsIgnoresTable(ignoresSavedVars)
end

-- --------------------------------------------------------------------------------------------------------------------
-- DumpIgnores
-- --------------------------------------------------------
function KayrFriendSync.DumpIgnores()
    -- Refresh from server
    C_FriendList.ShowFriends()

    local numIgnores = C_FriendList.GetNumIgnores()
    for i=1, numIgnores do
        local ignoreName = C_FriendList.GetIgnoreName(i)
        KLib:Print("index:", i, "ignoreName:", ignoreName)
    end
end

-- --------------------------------------------------------------------------------------------------------------------
-- DumpSavedIgnores
-- --------------------------------------------------------
function KayrFriendSync:DumpSavedIgnores()
    local ignoresSavedVars = KayrFriendSync:GetSavedVarsIgnoresTable()
    for name, info in pairs(ignoresSavedVars) do
        -- KLib:Con("KayrFriendSync", "Saved Ignore:", name, KLib.to.Str(info))
    end
end

-- --------------------------------------------------------------------------------------------------------------------
-- SaveAllIgnores
-- Register this alt's friends in SavedVariables
-- --------------------------------------------------------
function KayrFriendSync:SaveAllIgnores()
    -- Refresh from server
    C_FriendList.ShowFriends()

    local numIgnores = C_FriendList.GetNumIgnores()
    for i=1, numIgnores do
        local ignoreName = C_FriendList.GetIgnoreName(i)
        -- KLib:Con("index:", i, "ignoreName:", ignoreName)
        self:SaveIgnore(ignoreName)
    end
end

-- --------------------------------------------------------------------------------------------------------------------
-- CanAddMoreFriends
-- --------------------------------------------------------
function KayrFriendSync:CanAddMoreIgnores()
    if C_FriendList.GetNumIgnores() >= 50 then
        return false
    end
    return true
end

-- --------------------------------------------------------------------------------------------------------------------
-- SyncFromSavedIgnores
-- --------------------------------------------------------
function KayrFriendSync:SyncFromSavedIgnores()
    local enabled = self:GetSettings().ignores_enabled
    -- KLib:Con("KayrFriendSync", "SyncFromSavedIgnores()", enabled)
    if not enabled then return end
    C_FriendList.ShowFriends()
    C_Timer.After(5, function() self:SyncFromSavedIgnores_Immediate(true) end)
end

-- --------------------------------------------------------------------------------------------------------------------
-- SyncFromSavedIgnores_Immediate
-- Add friends in-game from those stored in SavedVariables from player alts
-- --------------------------------------------------------
function KayrFriendSync:SyncFromSavedIgnores_Immediate(showFriendsCalled)
    local enabled = self:GetSettings().ignores_enabled
    -- KLib:Con("KayrFriendSync", "SyncFromSavedIgnores_Immediate()", enabled)
    if not enabled then return end
    if not showFriendsCalled then
        C_FriendList.ShowFriends()
    end

    local canAddMore = KayrFriendSync:CanAddMoreIgnores()
    local numAdds = 0
    local numRemovals = 0

    local ignoresSavedVars = KayrFriendSync:GetSavedVarsIgnoresTable()
    for name, info in pairs(ignoresSavedVars) do
        local existingIgnore = C_FriendList.IsIgnored(name)
        if existingIgnore then
            if info.removed then
                -- KLib:Con("KayrFriendSync", "Removing ignore due to removed flag in Saved Ignores:", name)
                C_FriendList.DelIgnore(name)
                numRemovals = numRemovals + 1
            else
                -- KLib:Con("KayrFriendSync", "Ignore already up to date:", name, info.removed)
            end
        else
            -- KLib:Con("KayrFriendSync", "Adding ignore from Saved Ignores:", name)
            local addSuccess = false
            if canAddMore then
                addSuccess = C_FriendList.AddIgnore(name, true)
            end
            -- Increment if we either successfully added someone to ignores, or if we can't but would try to (and possibly fail)
            if (not canAddMore) or addSuccess then
                numAdds = numAdds + 1
            end
        end
    end
    C_Timer.After(5, function()
        if not canAddMore then
            print("KayrFriendSync: Ignore limit reached - Cannot add additional ignores.")
            print("KayrFriendSync: There are " .. numAdds .. " entries waiting to be added once space is available in ignore list.")
        else
            if numAdds > 0 then
                print("KayrFriendSync: " .. numAdds .. " entries added to ignore list that were collected from your other characters.")
            end
        end
        if numRemovals > 0 then
            print("KayrFriendSync: " .. numRemovals .. " entries removed from ignore list due to being removed on your other characters.")
        end
    end)
end
