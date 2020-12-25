-- ====================================================================================================================
-- =	KayrFriendSync - Lightweight synchronization of friends lists across alts
-- =	Copyright (c) Kvalyr - 2020-2021 - All Rights Reserved
-- ====================================================================================================================
local C_FriendList = _G["C_FriendList"]
local C_Timer = _G["C_Timer"]
local GetRealmName = _G["GetRealmName"]
local GetServerTime = _G["GetServerTime"]
local UnitFactionGroup = _G["UnitFactionGroup"]
local UnitName = _G["UnitName"]
-- ====================================================================================================================
-- Debugging
local KLib = _G["KLib"]
if not KLib then
    KLib = {Con = function() end, Warn = function() end, Print = print} -- No-Op if KLib not available
end
-- ====================================================================================================================

-- --------------------------------------------------------------------------------------------------------------------
-- Hooks
-- --------------------------------------------------------
function KayrFriendSync.Hook_AddFriend(name, notes, noHook, ...)
    -- KLib:Con("KayrFriendSync", "Hooked AddFriend()", name, notes, noHook, ...)
    if not noHook then
        C_FriendList.ShowFriends()
        -- Delay a few seconds to give the server time to sync
        C_Timer.After(2, function() KayrFriendSync:SaveFriend(C_FriendList.GetFriendInfo(name), true) end)
    end
    return name, notes
end

function KayrFriendSync.Hook_RemoveFriend(name, noHook, ...)
    -- KLib:Con("KayrFriendSync", "Hooked RemoveFriend()", name, noHook, ...)
    if not noHook then
        C_FriendList.ShowFriends()
        KayrFriendSync:RemoveSavedFriend(name)
    end
    return name
end

function KayrFriendSync.Hook_SetFriendNotes(name, newNote, noHook, ...)
    -- KLib:Con("KayrFriendSync", "Hooked SetFriendNotes()", name, newNote, noHook, ...)
    if not noHook then
        C_FriendList.ShowFriends()
        KayrFriendSync:SaveFriend(C_FriendList.GetFriendInfo(name), true)
    end
    return name, newNote
end

function KayrFriendSync.Hook_AddOrRemoveFriend(name, noHook, ...)
    -- KLib:Con("KayrFriendSync", "Hooked AddOrRemoveFriend()", name, noHook, ...)
    if not noHook then
        C_FriendList.ShowFriends()
        if C_FriendList.GetFriendInfo(name) then
            KayrFriendSync:RemoveSavedFriend(name)
        else
            C_Timer.After(2, function() KayrFriendSync:SaveFriend(C_FriendList.GetFriendInfo(name), true) end)
        end
    end
    return name
end

-- --------------------------------------------------------------------------------------------------------------------
-- GetSavedVarsFriendsTable / UpdateSavedVarsFriendsTable
-- --------------------------------------------------------
function KayrFriendSync:GetSavedVarsFriendsTable()
    if not self.initDone then return end

    local factionSavedVars = _G["KayrFriendSync_SV"]["friends"][self.playerRealm][self.playerFaction]
    return factionSavedVars
end

function KayrFriendSync:UpdateSavedVarsFriendsTable(newRealmSavedVars)
    if not self.initDone then return end
    _G["KayrFriendSync_SV"]["friends"][self.playerRealm][self.playerFaction] = newRealmSavedVars
end

-- --------------------------------------------------------------------------------------------------------------------
-- RemoveSavedFriend
-- --------------------------------------------------------
function KayrFriendSync:RemoveSavedFriend(name, playerRealm)
    playerRealm = playerRealm or GetRealmName()
    local factionSavedVars = self:GetSavedVarsFriendsTable()
    local existingFriend = factionSavedVars[name]
    if existingFriend then
        -- KLib:Warn("KayrFriendSync", "Removing friend:", name)
        existingFriend.removed = true
        factionSavedVars[name] = existingFriend
    end
    self:UpdateSavedVarsFriendsTable(factionSavedVars)
end

-- --------------------------------------------------------------------------------------------------------------------
-- SaveFriend
-- --------------------------------------------------------
function KayrFriendSync:SaveFriend(friendInfo, userUpdate)
    if not friendInfo then return end -- TODO: Logging
    if not friendInfo.name or friendInfo.name == "" then
        -- KLib:Warn("KayrFriendSync", "Empty friend name", friendInfo.guid)
        return
    end

    local playerName = UnitName("player")
    local playerRealm = GetRealmName()
    local updateTime = GetServerTime()
    local updateNotes

    local newFriend = {}
    newFriend.faction = UnitFactionGroup("player")
    newFriend.removed = false
    newFriend.guid = friendInfo.guid
    newFriend.name = friendInfo.name
    newFriend.notes = friendInfo.notes
    newFriend.realm = playerRealm
    newFriend.sourceCharacter = playerName
    newFriend.lastUpdated = updateTime

    local factionSavedVars = self:GetSavedVarsFriendsTable()
    local existingFriend = factionSavedVars[friendInfo.name]

    if existingFriend then
        -- KLib:Warn("KayrFriendSync", "Existing friend:", existingFriend.name)
        if userUpdate then
            -- In the case of a manual update by the user (changing notes, etc.)
            existingFriend.lastUpdated = updateTime
            existingFriend.sourceCharacter = playerName
            existingFriend.removed = false
            updateNotes = true
        end
        if ((not existingFriend.notes or existingFriend.notes == "") and newFriend.notes and newFriend.notes ~= "") and (existingFriend.notes ~= newFriend.notes) then
            updateNotes = true
        end
        if updateNotes then
            -- KLib:Con("KayrFriendSync", "Updating notes for:", newFriend.name, "->", newFriend.notes)
            existingFriend.notes = newFriend.notes
            factionSavedVars[existingFriend.name] = existingFriend
        end

    else
        -- KLib:Con("KayrFriendSync", "New friend:", newFriend.name)--, KLib.to.Str(newFriend))
        factionSavedVars[friendInfo.name] = newFriend
    end
    self:UpdateSavedVarsFriendsTable(factionSavedVars)
end

-- --------------------------------------------------------------------------------------------------------------------
-- DumpFriends
-- --------------------------------------------------------
function KayrFriendSync.DumpFriends()
    -- Refresh from server
    C_FriendList.ShowFriends()

    local numFriends = C_FriendList.GetNumFriends()
    for i=1, numFriends do
        local friendInfo = C_FriendList.GetFriendInfoByIndex(i)
        KLib:Print("index:", i, "friendInfoType:", type(friendInfo), "friendInfo:", friendInfo.name, friendInfo.notes, friendInfo.guid)
    end
end

-- --------------------------------------------------------------------------------------------------------------------
-- DumpSavedFriends
-- --------------------------------------------------------
function KayrFriendSync:DumpSavedFriends()
    local factionSavedVars = self:GetSavedVarsFriendsTable()
    for name, info in pairs(factionSavedVars) do
        KLib:Con("KayrFriendSync", "Saved Friend:", name, KLib.to.Str(info))
    end
end

-- --------------------------------------------------------------------------------------------------------------------
-- SaveAllFriends
-- Register this alt's friends in SavedVariables
-- --------------------------------------------------------
function KayrFriendSync:SaveAllFriends()
    -- Refresh from server
    C_FriendList.ShowFriends()

    local numFriends = C_FriendList.GetNumFriends()
    for i=1, numFriends do
        local friendInfo = C_FriendList.GetFriendInfoByIndex(i)
        -- KLib:Con("index:", i, "friendInfoType:", type(friendInfo), "friendInfo:", friendInfo.name, friendInfo.notes, friendInfo.guid)
        self:SaveFriend(friendInfo)
    end
end

-- --------------------------------------------------------------------------------------------------------------------
-- CanAddMoreFriends
-- --------------------------------------------------------
function KayrFriendSync:CanAddMoreFriends()
    if C_FriendList.GetNumFriends() >= 100 then
        return false
    end
    return true
end

-- --------------------------------------------------------------------------------------------------------------------
-- SyncFromSavedFriends
-- --------------------------------------------------------
function KayrFriendSync:SyncFromSavedFriends()
    local enabled = self:GetSettings().enabled
    -- KLib:Con("KayrFriendSync", "SyncFromSavedFriends()", enabled)
    if not enabled then return end
    C_FriendList.ShowFriends()
    C_Timer.After(5, function() self:SyncFromSavedFriends_Immediate(true) end)
end

-- --------------------------------------------------------------------------------------------------------------------
-- SyncFromSavedFriends_Immediate
-- Add friends in-game from those stored in SavedVariables from player alts
-- --------------------------------------------------------
function KayrFriendSync:SyncFromSavedFriends_Immediate(showFriendsCalled)
    local enabled = self:GetSettings().enabled
    -- KLib:Con("KayrFriendSync", "SyncFromSavedFriends_Immediate()")
    if not enabled then return end
    if not showFriendsCalled then
        C_FriendList.ShowFriends()
    end

    local canAddMore = KayrFriendSync:CanAddMoreFriends()
    local numAdds = 0
    local numRemovals = 0

    local factionSavedVars = self:GetSavedVarsFriendsTable()
    for name, info in pairs(factionSavedVars) do

        local existingFriend = C_FriendList.GetFriendInfo(name)
        if existingFriend then
            if info.removed then
                -- KLib:Con("KayrFriendSync", "Removing friend due to removed flag in Saved Ignores:", name)
                C_FriendList.RemoveFriend(name)
                numRemovals = numRemovals + 1
            else
                if info.notes ~= existingFriend.notes  then
                    -- KLib:Con("KayrFriendSync", "Updating notes from saved friend:", name)--, KLib.to.Str(info))
                    C_FriendList.SetFriendNotes(name, info.notes)
                -- else
                    -- KLib:Con("KayrFriendSync", "Friend already up to date:", name)--, KLib.to.Str(info))
                end
            end
        else
            -- KLib:Con("KayrFriendSync", "Adding friend from Saved Friends:", name)--, KLib.to.Str(info))
            if canAddMore then
                C_FriendList.AddFriend(name, info.notes, true)
            end
            numAdds = numAdds + 1
        end
    end
    C_Timer.After(5, function()
        if not canAddMore then
            print("KayrFriendSync: Friend limit reached - Cannot add additional friends.")
            print("KayrFriendSync: There are " .. numAdds .. " entries waiting to be added once space is available in friends list.")
        else
            if numAdds > 0 then
                print("KayrFriendSync: " .. numAdds .. " entries added to friend list that were collected from your other characters.")
            end
        end
        if numRemovals > 0 then
            print("KayrFriendSync: " .. numRemovals .. " entries removed from friend list due to being removed on your other characters.")
        end
    end)
end
