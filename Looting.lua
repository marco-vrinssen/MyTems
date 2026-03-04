-- Auto-loot with hidden loot frame to speed up looting because default frame adds unnecessary delay
-- Based on SpeedyAutoLoot by Veritass

local LOOT_SLOT_ITEM    = Enum.LootSlotType.Item
local LOOT_SLOT_NONE    = Enum.LootSlotType.None
local REAGENT_BAG_INDEX = 5
local TICK_INTERVAL     = 0.033

-- Create hidden parent frame to suppress loot frame during auto-loot because visible frame slows looting

local hiddenParent = CreateFrame("Frame", nil, UIParent)
hiddenParent:SetToplevel(true)
hiddenParent:Hide()

local looting           = false
local lootFrameHidden   = true
local anySlotLocked     = false
local previousItemCount = nil
local autoLootActive    = false
local anySlotFailed     = false
local lootTicker        = nil


-- Check if item fits in available bag slots to prevent loot failures because full bags cause errors

local function CanFitInBags(itemLink, quantity)
    local stackSize, _, _, _, _, _, _, _, _, isCraftingReagent = select(8, C_Item.GetItemInfo(itemLink))
    local itemFamily = C_Item.GetItemFamily(itemLink)

    local owned = C_Item.GetItemCount(itemLink)
    if owned > 0 and stackSize > 1 then
        if ((stackSize - owned) % stackSize) >= quantity then
            return true
        end
    end

    for bag = BACKPACK_CONTAINER, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
        local freeSlots, bagFamily = C_Container.GetContainerNumFreeSlots(bag)
        if freeSlots > 0 then
            if bag == REAGENT_BAG_INDEX then
                return isCraftingReagent and true or false
            end
            if not bagFamily or bagFamily == 0 or (itemFamily and bit.band(itemFamily, bagFamily) > 0) then
                return true
            end
        end
    end

    return false
end


-- Position loot frame at cursor or default anchor to match user preference because settings vary per player

local function PositionLootFrame()
    local lootFrame = LootFrame
    if GetCVarBool("lootUnderMouse") then
        local cursorX, cursorY = GetCursorPosition()
        lootFrame:ClearAllPoints()
        local scale = lootFrame:GetEffectiveScale()
        local positionX = cursorX / scale - 30
        local positionY = math.max(cursorY / scale + 50, 350)
        lootFrame:SetPoint("TOPLEFT", nil, "BOTTOMLEFT", positionX, positionY)
        lootFrame:Raise()
    else
        local anchor = lootFrame.systemInfo.anchorInfo
        local scale  = lootFrame:GetScale()
        lootFrame:SetPoint(anchor.point, anchor.relativeTo, anchor.relativePoint,
            anchor.offsetX / scale, anchor.offsetY / scale)
    end
end


-- Reparent loot frame to UIParent to make it visible again because hidden parent suppresses rendering

local function RevealLootFrame(isDelayed)
    lootFrameHidden = false
    if not LootFrame:IsEventRegistered("LOOT_OPENED") then return end

    LootFrame:SetParent(UIParent)
    LootFrame:SetFrameStrata("HIGH")
    PositionLootFrame()
    if isDelayed then
        PositionLootFrame()
    end
end


-- Reparent loot frame to hidden parent to suppress it during auto-loot because visible frame adds delay

local function HideLootFrame()
    if LootFrame:IsEventRegistered("LOOT_OPENED") then
        LootFrame:SetParent(hiddenParent)
    end
end


-- Stop the loot ticker to prevent further slot processing because looting is complete or cancelled

local function CancelTicker()
    if lootTicker then
        lootTicker:Cancel()
    end
end


-- Attempt to loot a single slot to collect items because each slot must be processed individually

local function TryLootSlot(slotIndex)
    local slotType = GetLootSlotType(slotIndex)
    if slotType == LOOT_SLOT_NONE then
        return true
    end

    local itemLink    = GetLootSlotLink(slotIndex)
    local quantity, _, _, isLocked, isQuestItem = select(3, GetLootSlotInfo(slotIndex))

    if isLocked then
        anySlotLocked = true
        return false
    end

    if slotType ~= LOOT_SLOT_ITEM or isQuestItem or CanFitInBags(itemLink, quantity) then
        LootSlot(slotIndex)
        return true
    end

    return false
end


-- Iterate all loot slots on a ticker to collect items because processing all at once can fail

local function LootAllSlots(totalSlots)
    CancelTicker()
    local nextSlot = totalSlots

    lootTicker = C_Timer.NewTicker(TICK_INTERVAL, function()
        if nextSlot >= 1 then
            if not TryLootSlot(nextSlot) then
                anySlotFailed = true
            end
            nextSlot = nextSlot - 1
        else
            if anySlotFailed then
                RevealLootFrame()
            end
            CancelTicker()
        end
    end, totalSlots + 1)
end


-- Start auto-looting when loot becomes available to collect items quickly because manual looting is slow

local function OnLootReady(isAutoLoot)
    looting = true

    if not autoLootActive then
        autoLootActive = isAutoLoot
            or (not isAutoLoot and GetCVarBool("autoLootDefault") ~= IsModifiedClick("AUTOLOOTTOGGLE"))
    end

    local itemCount = GetNumLootItems()
    if itemCount == 0 or previousItemCount == itemCount then
        return
    end

    if autoLootActive then
        LootAllSlots(itemCount)
    else
        RevealLootFrame()
    end

    previousItemCount = itemCount
end


-- Reset all state when loot window closes to prepare for next loot session because stale state causes errors

local function OnLootClosed()
    looting           = false
    lootFrameHidden   = true
    anySlotLocked     = false
    previousItemCount = nil
    autoLootActive    = false
    anySlotFailed     = false
    CancelTicker()
    HideLootFrame()
end


-- Show loot frame when bag error occurs to let player handle it because auto-loot cannot resolve bag issues

local function OnBagError(_, message)
    if not (looting and lootFrameHidden) then return end
    if message == ERR_INV_FULL or message == ERR_ITEM_MAX_COUNT or message == ERR_LOOT_ROLL_PENDING then
        RevealLootFrame(true)
    end
end


-- Register for loot lifecycle and bag error events to activate auto-loot at the right time because timing matters

hiddenParent:RegisterEvent("LOOT_READY")
hiddenParent:RegisterEvent("LOOT_OPENED")
hiddenParent:RegisterEvent("LOOT_CLOSED")
hiddenParent:RegisterEvent("UI_ERROR_MESSAGE")

hiddenParent:SetScript("OnEvent", function(_, event, ...)
    if event == "LOOT_READY" or event == "LOOT_OPENED" then
        OnLootReady(...)
    elseif event == "LOOT_CLOSED" then
        OnLootClosed()
    elseif event == "UI_ERROR_MESSAGE" then
        OnBagError(...)
    end
end)


-- Keep loot frame parented correctly to handle EditMode transitions because EditMode reparents frames

if LootFrame:IsEventRegistered("LOOT_OPENED") then
    hooksecurefunc(LootFrame, "UpdateShownState", function(self)
        if self.isInEditMode then
            self:SetParent(UIParent)
        else
            self:SetParent(hiddenParent)
        end
    end)
end


-- Delay initial hide to let other addons finish hooking LootFrame because early hiding breaks their hooks

C_Timer.After(6, HideLootFrame)