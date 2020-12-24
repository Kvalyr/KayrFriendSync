-- ====================================================================================================================
-- =	KayrFriendSync - Lightweight synchronization of friends lists across alts
-- =	Copyright (c) Kvalyr - 2020-2021 - All Rights Reserved
-- ====================================================================================================================
local hooksecurefunc = _G["hooksecurefunc"]
local C_FriendList = _G["C_FriendList"]
local C_Timer = _G["C_Timer"]
local CreateFrame = _G["CreateFrame"]
local GetRealmName = _G["GetRealmName"]
local UnitFactionGroup = _G["UnitFactionGroup"]
local UnitName = _G["UnitName"]
-- ====================================================================================================================

-- Debugging
local KLib = _G["KLib"]
if not KLib then
    KLib = {Con = function() end, Warn = function() end, Print = print} -- No-Op if KLib not available
end

-- --------------------------------------------------------------------------------------------------------------------
-- Addon class
-- --------------------------------------------------------
KayrFriendSync = CreateFrame("Frame", "KayrFriendSync", UIParent)
KayrFriendSync.initDone = false
KayrFriendSync.showMissionHookDone = false

-- --------------------------------------------------------------------------------------------------------------------
-- Helpers
-- --------------------------------------------------------

-- --------------------------------------------------------------------------------------------------------------------
-- GetFactionSavedVars / UpdateFactionSavedVars
-- --------------------------------------------------------
function KayrFriendSync:GetFactionSavedVars()
    if not self.initDone then return end
    local factionSavedVars = _G["KayrFriendSync_SV"]["friends"][self.playerRealm][self.playerFaction]
    return factionSavedVars
end

function KayrFriendSync:UpdateFactionSavedVars(newRealmSavedVars)
    if not self.initDone then return end
    _G["KayrFriendSync_SV"]["friends"][self.playerRealm][self.playerFaction] = newRealmSavedVars
end

-- --------------------------------------------------------------------------------------------------------------------
-- Hooks
-- --------------------------------------------------------
function KayrFriendSync.Hook_AddFriend(name, notes, ...)
    KLib:Con("KayrFriendSync", "Hooked AddFriend()", name, notes, ...)
    C_FriendList.ShowFriends()
    -- Delay a few seconds to give the server time to sync
    C_Timer.After(3, function() KayrFriendSync:SaveFriend(C_FriendList.GetFriendInfo(name), true) end)
    return ...
end

function KayrFriendSync.Hook_RemoveFriend(name, ...)
    KLib:Con("KayrFriendSync", "Hooked RemoveFriend()", name, ...)
    C_FriendList.ShowFriends()
    KayrFriendSync:RemoveFriend(name)
    return ...
end

function KayrFriendSync.Hook_SetFriendNotes(name, newNote, ...)
    KLib:Con("KayrFriendSync", "Hooked SetFriendNotes()", name, newNote, ...)
    C_FriendList.ShowFriends()
    KayrFriendSync:SaveFriend(C_FriendList.GetFriendInfo(name), true)
    return ...
end

function KayrFriendSync.Hook_AddOrRemoveFriend(name, ...)
    KLib:Con("KayrFriendSync", "Hooked AddOrRemoveFriend()", name, ...)
    C_FriendList.ShowFriends()
    if C_FriendList.GetFriendInfo(name) then
        KayrFriendSync:RemoveFriend(name)
    else
        KayrFriendSync:SaveFriend(C_FriendList.GetFriendInfo(name), true)
    end
    return ...
end


-- --------------------------------------------------------------------------------------------------------------------
-- SaveFriend
-- --------------------------------------------------------
function KayrFriendSync:RemoveFriend(name, playerRealm)
    playerRealm = playerRealm or GetRealmName()
    local factionSavedVars = KayrFriendSync:GetFactionSavedVars()
    factionSavedVars[name] = nil
    KLib:Warn("KayrFriendSync", "Removing friend:", name)
    KayrFriendSync:UpdateFactionSavedVars(factionSavedVars)
end

-- --------------------------------------------------------------------------------------------------------------------
-- SaveFriend
-- --------------------------------------------------------
function KayrFriendSync:SaveFriend(friendInfo, updateNotes)
    if not friendInfo then return end -- TODO: Logging

    local playerName = UnitName("player")
    local playerRealm = GetRealmName()

    local newFriend = {}
    newFriend.faction = UnitFactionGroup("player")
    newFriend.guid = friendInfo.guid
    newFriend.name = friendInfo.name
    newFriend.notes = friendInfo.notes
    newFriend.realm = playerRealm
    newFriend.sourceCharacter = playerName

    local factionSavedVars = KayrFriendSync:GetFactionSavedVars()
    local existingFriend = factionSavedVars[friendInfo.name]
    if existingFriend then
        KLib:Warn("KayrFriendSync", "Existing friend:", existingFriend.name)
        if ((not existingFriend.notes or existingFriend.notes == "") and newFriend.notes and newFriend.notes ~= "") and (existingFriend.notes ~= newFriend.notes) then
            updateNotes = true
        end
        if updateNotes then
            KLib:Con("KayrFriendSync", "Updating notes for:", newFriend.name, "->", newFriend.notes)
            existingFriend.notes = newFriend.notes
            factionSavedVars[existingFriend.name] = existingFriend
        end
    else
        KLib:Con("KayrFriendSync", "New friend:", newFriend.name)--, KLib.to.Str(newFriend))
        factionSavedVars[friendInfo.name] = newFriend
    end
    KayrFriendSync:UpdateFactionSavedVars(factionSavedVars)
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
-- DumpFriends
-- --------------------------------------------------------
function KayrFriendSync:DumpSavedFriends()
    local factionSavedVars = KayrFriendSync:GetFactionSavedVars()
    for name, info in pairs(factionSavedVars) do
        KLib:Con("KayrFriendSync", "Saved Friend:", name, KLib.to.Str(info))
    end
end

-- --------------------------------------------------------------------------------------------------------------------
-- SaveAllFriends
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
-- SyncFromSavedFriends
-- --------------------------------------------------------
function KayrFriendSync:SyncFromSavedFriends()
    KLib:Con("KayrFriendSync", "SyncFromSavedFriends()")
    local factionSavedVars = KayrFriendSync:GetFactionSavedVars()
    for name, info in pairs(factionSavedVars) do
        local existingFriend = C_FriendList.GetFriendInfo(name)
        if existingFriend then
            if info.notes ~= existingFriend.notes  then
                KLib:Con("KayrFriendSync", "Updating notes from saved friend:", name)--, KLib.to.Str(info))
                C_FriendList.SetFriendNotes(name, info.notes)
            else
                KLib:Con("KayrFriendSync", "Friend already up to date:", name)--, KLib.to.Str(info))
            end
        else
            KLib:Con("KayrFriendSync", "Adding friend from Saved Friends:", name)--, KLib.to.Str(info))
            C_FriendList.AddFriend(name, info.notes)
        end
    end
end


-- --------------------------------------------------------------------------------------------------------------------
-- Init
-- --------------------------------------------------------
function KayrFriendSync:Init()
    KLib:Con("KayrFriendSync.Init")
    if self.initDone then return end
    hooksecurefunc(_G["C_FriendList"], "AddFriend", KayrFriendSync.Hook_AddFriend)
    hooksecurefunc(_G["C_FriendList"], "RemoveFriend", KayrFriendSync.Hook_RemoveFriend)
    hooksecurefunc(_G["C_FriendList"], "AddOrRemoveFriend", KayrFriendSync.Hook_AddOrRemoveFriend)
    hooksecurefunc(_G["C_FriendList"], "SetFriendNotes", KayrFriendSync.Hook_SetFriendNotes)
    -- TODO: RemoveFriendByIndex -- More difficult. Before/after check by pre-hooking?
    -- TODO: SetFriendNotesByIndex -- More difficult. Before/after check by pre-hooking?

    local playerRealm = GetRealmName()
    KayrFriendSync.playerRealm = playerRealm

    local playerFaction = UnitFactionGroup("player")
    KayrFriendSync.playerFaction = playerFaction

    if not _G["KayrFriendSync_SV"] then _G["KayrFriendSync_SV"] = {friends={}} end
    if not _G["KayrFriendSync_SV"].friends[playerRealm] then
        _G["KayrFriendSync_SV"].friends[playerRealm] = {}
    end
    if not _G["KayrFriendSync_SV"].friends[playerRealm][playerFaction] then
        _G["KayrFriendSync_SV"].friends[playerRealm][playerFaction] = {}
    end


    self.initDone = true
end

-- --------------------------------------------------------------------------------------------------------------------
-- Listen for Blizz Garrison UI being loaded
-- --------------------------------------------------------
function KayrFriendSync:PLAYER_LOGIN(event, addon)
    KayrFriendSync:Init()
end

KayrFriendSync:RegisterEvent("PLAYER_LOGIN")
KayrFriendSync:SetScript("OnEvent", KayrFriendSync.PLAYER_LOGIN)
