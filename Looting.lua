-- Configure loot settings and suppress loot frame on login to optimize speed because default rate is slower

local function LootConfig()
    SetCVar("autoLootRate", 0)
    LootFrame:UnregisterAllEvents()
    LootFrame:Hide()
end

-- Collect all items and close to empty corpse quickly because manual looting is slow

local function LootHandler()
    if GetCVarBool("autoLootDefault") == IsModifiedClick("AUTOLOOTTOGGLE") then return end

    for slotIndex = GetNumLootItems(), 1, -1 do
        LootSlot(slotIndex)
    end

    CloseLoot()
end

-- Register and dispatch events to automate looting because centralized routing is cleaner

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("LOOT_READY")

eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        LootConfig()
    elseif event == "LOOT_READY" then
        LootHandler()
    end
end)