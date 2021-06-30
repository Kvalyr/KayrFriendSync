-- ====================================================================================================================
-- =	KayrFriendSync - Lightweight synchronization of friends lists across alts
-- =	Copyright (c) Kvalyr - 2020-2021 - All Rights Reserved
-- ====================================================================================================================
local hooksecurefunc = _G["hooksecurefunc"]
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
-- ====================================================================================================================

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
-- GetSettings
-- --------------------------------------------------------
function KayrFriendSync:GetSettings()
    return _G["KayrFriendSync_SV"].settings
end

-- --------------------------------------------------------------------------------------------------------------------
-- InitSavedVariables
-- --------------------------------------------------------
function KayrFriendSync:InitAccountSavedVariables()
    if not _G["KayrFriendSync_SV"] then
        _G["KayrFriendSync_SV"] = {
            friends={[self.playerRealm] = {}},
            ignores={[self.playerRealm] = {}},
            settings={enabled=false, ignores_enabled=false},
        }
    end

    -- Friends
    if not _G["KayrFriendSync_SV"].friends then _G["KayrFriendSync_SV"].friends = {} end
    if not _G["KayrFriendSync_SV"].friends[self.playerRealm] then
        _G["KayrFriendSync_SV"].friends[self.playerRealm] = {}
    end
    if not _G["KayrFriendSync_SV"].friends[self.playerRealm][self.playerFaction] then
        _G["KayrFriendSync_SV"].friends[self.playerRealm][self.playerFaction] = {}
    end

    -- Make sure we don't try to add a character from this account as a friend, it just produces errors in chat frame
    _G["KayrFriendSync_SV"].friends[self.playerRealm][self.playerFaction][UnitName("player")] = nil

    -- Ignores
    -- TODO: Do we need to filter by realm for ignores?
    -- Need to confirm logic for ignoring people from other realms such as in BGs, dungeons etc.
    -- Seems to be okay to include realm in the name and otherwise disregard it for our purposes
    if not _G["KayrFriendSync_SV"].ignores then _G["KayrFriendSync_SV"].ignores = {} end
    if not _G["KayrFriendSync_SV"].ignores[self.playerRealm] then
        _G["KayrFriendSync_SV"].ignores[self.playerRealm] = {}
    end
end

-- --------------------------------------------------------------------------------------------------------------------
-- InitCharacterSavedVariables
-- --------------------------------------------------------
function KayrFriendSync:InitCharacterSavedVariables()
    if not _G["KayrFriendSync_SVPC"] or not _G["KayrFriendSync_SVPC"].characterSeenBefore then
        _G["KayrFriendSync_SVPC"] = {characterSeenBefore=false}
        return true
    end
    return false
end

-- --------------------------------------------------------------------------------------------------------------------
-- OnNewCharacter
-- --------------------------------------------------------
function KayrFriendSync:OnNewCharacter()
    self:SaveAllFriends()
    self:SaveAllIgnores()

    -- Mark this player character as seen before so that we don't run this method on every login
    _G["KayrFriendSync_SVPC"].characterSeenBefore = true
end

-- --------------------------------------------------------------------------------------------------------------------
-- OnEnable
-- --------------------------------------------------------
function KayrFriendSync:OnEnable()
    local newChar = self:InitCharacterSavedVariables()
    if newChar then
        self:OnNewCharacter()
    -- else
        -- Rely on hooks from hereon for this character instead
    end
    KayrFriendSync:SyncFromSavedFriends()
end

-- --------------------------------------------------------------------------------------------------------------------
-- OnEnableIgnores
-- --------------------------------------------------------
function KayrFriendSync:OnEnableIgnores()
    local newChar = self:InitCharacterSavedVariables()
    if newChar then
        self:OnNewCharacter(true)
    -- else
        -- Rely on hooks from hereon for this character instead
    end
    KayrFriendSync:SyncFromSavedIgnores()
end

-- --------------------------------------------------------------------------------------------------------------------
-- Init
-- --------------------------------------------------------
function KayrFriendSync:Init()
    -- KLib:Con("KayrFriendSync.Init")
    if self.initDone then return end

    -- Friends
    hooksecurefunc(_G["C_FriendList"], "AddFriend", KayrFriendSync.Hook_AddFriend)
    hooksecurefunc(_G["C_FriendList"], "RemoveFriend", KayrFriendSync.Hook_RemoveFriend)
    hooksecurefunc(_G["C_FriendList"], "AddOrRemoveFriend", KayrFriendSync.Hook_AddOrRemoveFriend)
    hooksecurefunc(_G["C_FriendList"], "SetFriendNotes", KayrFriendSync.Hook_SetFriendNotes)
    -- TODO: RemoveFriendByIndex -- More difficult. Before/after check by pre-hooking?
    -- TODO: SetFriendNotesByIndex -- More difficult. Before/after check by pre-hooking?

    -- Ignores
    hooksecurefunc(_G["C_FriendList"], "AddIgnore", KayrFriendSync.Hook_AddIgnore)
    hooksecurefunc(_G["C_FriendList"], "DelIgnore", KayrFriendSync.Hook_DelIgnore)
    hooksecurefunc(_G["C_FriendList"], "AddOrDelIgnore", KayrFriendSync.Hook_AddOrDelIgnore)

    -- UI Updates
    hooksecurefunc(_G, "FriendsFrame_Update", KayrFriendSync.Hook_FriendsFrame_Update)  -- UI

    KayrFriendSync.playerRealm = GetRealmName()
    KayrFriendSync.playerFaction = UnitFactionGroup("player")

    self:InitAccountSavedVariables()
    self.initDone = true

    if self:GetSettings().enabled then
        self:OnEnable()
    end
    if self:GetSettings().ignores_enabled then
        self:OnEnableIgnores()
    end

    -- Set up UI changes (Toggle buttons)
    KayrFriendSync:ModifyFriendsFrame()

end

-- --------------------------------------------------------------------------------------------------------------------
-- Enable/Disable/Toggle
-- --------------------------------------------------------
function KayrFriendSync:Enable()
    _G["KayrFriendSync_SV"].settings.enabled = true
    self:OnEnable()
end

function KayrFriendSync:Disable()
    _G["KayrFriendSync_SV"].settings.enabled = false
end

function KayrFriendSync:EnableIgnores()
    _G["KayrFriendSync_SV"].settings.ignores_enabled = true
    self:OnEnableIgnores()
end

function KayrFriendSync:DisableIgnores()
    _G["KayrFriendSync_SV"].settings.ignores_enabled = false
end

function KayrFriendSync:Toggle(toggleValue, ignores)
    -- KLib:Con(self, "Toggle", toggleValue, ignores)
    if toggleValue then
        if ignores then
            KayrFriendSync:EnableIgnores()
        end
        KayrFriendSync:Enable()
    else
        if ignores then
            KayrFriendSync:DisableIgnores()
        end
        KayrFriendSync:Disable()
    end
end

-- --------------------------------------------------------------------------------------------------------------------
-- Login Event
-- --------------------------------------------------------
function KayrFriendSync:PLAYER_LOGIN(event, addon)
    -- Delay initialization for some time after the event to give the server time to populate friend info
    C_Timer.After(7, function() KayrFriendSync:Init() end)

end

KayrFriendSync:RegisterEvent("PLAYER_LOGIN")
KayrFriendSync:SetScript("OnEvent", KayrFriendSync.PLAYER_LOGIN)
