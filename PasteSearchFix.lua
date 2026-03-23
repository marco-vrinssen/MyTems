local previousText = ""
local frame = CreateFrame("Frame")

local function StartSearch()
    if not AuctionHouseFrame or not AuctionHouseFrame:IsShown() then return end
    AuctionHouseFrame.SearchBar:StartSearch()
end

local function OnSetText(_, text)
    if text and text ~= "" then
        C_Timer.After(0, StartSearch)
    end
end

local function OnTextChanged(self, isUserInput)
    local currentText = self:GetText()
    if isUserInput and currentText ~= "" and math.abs(#currentText - #previousText) > 1 then
        C_Timer.After(0, StartSearch)
    end
    previousText = currentText
end

local function OnAddonLoaded(addonName)
    if addonName ~= "Blizzard_AuctionHouseUI" then return end
    frame:UnregisterEvent("ADDON_LOADED")
    local searchBox = AuctionHouseFrame.SearchBar.SearchBox
    hooksecurefunc(searchBox, "SetText", OnSetText)
    searchBox:HookScript("OnTextChanged", OnTextChanged)
end

frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, _, addonName)
    OnAddonLoaded(addonName)
end)
