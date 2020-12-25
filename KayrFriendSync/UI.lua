-- ====================================================================================================================
-- =	KayrFriendSync - Lightweight synchronization of friends lists across alts
-- =	Copyright (c) Kvalyr - 2020-2021 - All Rights Reserved
-- ====================================================================================================================
-- Debugging
local KLib = _G["KLib"]
if not KLib then
    KLib = {Con = function() end, Warn = function() end, Print = print} -- No-Op if KLib not available
end
-- ====================================================================================================================
local CreateFrame = _G["CreateFrame"]
-- ====================================================================================================================

-- --------------------------------------------------------------------------------------------------------------------
-- Hook_FriendsFrame_Update
-- --------------------------------------------------------
function KayrFriendSync.Hook_FriendsFrame_Update(...)
    -- KLib:Con("KayrFriendSync", "Hooked FriendsFrame_Update()", ...)
    local selectedTab = _G["FriendsTabHeader"].selectedTab
    local KFSToggleButton = _G["KFSToggleButton"]
    local KFSToggleButtonText = _G["KFSToggleButtonText"]

    if selectedTab == 1 then
        KFSToggleButton:Show()
        KFSToggleButton:SetChecked(_G["KayrFriendSync_SV"].settings.enabled)
        KFSToggleButtonText:SetText("Friends\nSync")
        KFSToggleButton.tooltipText = "Click to toggle synchronization of your friends list across \nall of your characters that load the KayrFriendSync addon."

    elseif selectedTab == 2 then
        KFSToggleButton:Show()
        KFSToggleButton:SetChecked(_G["KayrFriendSync_SV"].settings.ignores_enabled)
        KFSToggleButtonText:SetText("Ignores\nSync")
        KFSToggleButton.tooltipText = "Click to toggle synchronization of your ignore list across \nall of your characters that load the KayrFriendSync addon."

    else
        KFSToggleButton:Hide()

    end
    return ...
end

-- --------------------------------------------------------------------------------------------------------------------
-- UI
-- --------------------------------------------------------
local friendsFrameModified = false
function KayrFriendSync:ModifyFriendsFrame()
    if friendsFrameModified then return end

    local FriendsFrame = _G["FriendsFrame"]
    local KFSToggleButton = CreateFrame("CheckButton", "KFSToggleButton", FriendsFrame, KLib.AddBackdropTemplate("OptionsSmallCheckButtonTemplate"))
    KFSToggleButton:SetFrameStrata("HIGH")
    KFSToggleButton:ClearAllPoints()
    KFSToggleButton:SetPoint("TOPRIGHT", FriendsFrame, "TOPRIGHT", -5, -56)
    _G["KFSToggleButtonText"]:ClearAllPoints()
    _G["KFSToggleButtonText"]:SetPoint("RIGHT", KFSToggleButton, "LEFT", 0, 0)
    _G["KFSToggleButtonText"]:SetText("Friends\nSync")

    KFSToggleButton:SetChecked(_G["KayrFriendSync_SV"].settings.enabled)
    KFSToggleButton:SetScript("OnClick",
        function (self, button, down)
            if _G["FriendsTabHeader"].selectedTab == 1 then -- Friends
                KayrFriendSync:Toggle(self:GetChecked())
            elseif _G["FriendsTabHeader"].selectedTab == 2 then -- Ignores
                KayrFriendSync:Toggle(self:GetChecked(), true)
            end
        end
    )

    function KFSToggleButton:ShowTooltip()
        local str = self.tooltipText
        if KLib.is.StrNotEmpty(str) then
            _G["GameTooltip"]:SetOwner(self, "ANCHOR_TOPLEFT")
            _G["GameTooltip"]:SetText(self.tooltipText)
            _G["GameTooltip"]:Show()
        end
    end
    function KFSToggleButton:HideTooltip() _G["GameTooltip"]:Hide() end
    KFSToggleButton:SetScript("OnEnter", KFSToggleButton.ShowTooltip)
    KFSToggleButton:SetScript("OnLeave", KFSToggleButton.HideTooltip)
    friendsFrameModified = true
end