local offscreenAnchor = CreateFrame("Frame", nil, UIParent)
offscreenAnchor:Hide()

local lootFrameSuppressed = false


local function SuppressLootFrame()
    LootFrame:SetParent(offscreenAnchor)
end

local function ReleaseLootFrame()
    lootFrameSuppressed = false
    LootFrame:SetParent(UIParent)
    LootFrame:SetFrameStrata("HIGH")
end


local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("LOOT_READY")
eventFrame:RegisterEvent("LOOT_OPENED")
eventFrame:RegisterEvent("LOOT_CLOSED")
eventFrame:RegisterEvent("UI_ERROR_MESSAGE")

eventFrame:SetScript("OnEvent", function(_, event, ...)

    if event == "PLAYER_LOGIN" then
        SetCVar("autoLootRate", 0)
        SuppressLootFrame()
        hooksecurefunc(LootFrame, "UpdateShownState", function()
            if lootFrameSuppressed then SuppressLootFrame() end
        end)

    elseif event == "LOOT_READY" then
        if GetCVarBool("autoLootDefault") ~= IsModifiedClick("AUTOLOOTTOGGLE") then
            lootFrameSuppressed = true
            local hasLockedSlots = false
            for i = GetNumLootItems(), 1, -1 do
                local _, _, _, isLocked = GetLootSlotInfo(i)
                if isLocked then hasLockedSlots = true else LootSlot(i) end
            end
            if hasLockedSlots then ReleaseLootFrame() end
        end

    elseif event == "LOOT_OPENED" then
        if lootFrameSuppressed then SuppressLootFrame() end

    elseif event == "LOOT_CLOSED" then
        lootFrameSuppressed = false
        SuppressLootFrame()

    elseif event == "UI_ERROR_MESSAGE" then
        local _, msg = ...
        if lootFrameSuppressed and tContains({ ERR_INV_FULL, ERR_ITEM_MAX_COUNT, ERR_LOOT_ROLL_PENDING }, msg) then
            ReleaseLootFrame()
        end

    end
end)
