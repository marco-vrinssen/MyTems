-- Auto sell junk and auto repair to streamline vendor visits because manual selling and repairing is tedious

local merchantFrame = CreateFrame("Frame")
local handled = false


-- Repair all gear using guild bank then sell junk to save gold and clear inventory because manual steps are slow

local function AutoSellAndRepair()
    if not MerchantFrame:IsShown() then return end

    if CanMerchantRepair() then
        RepairAllItems(CanGuildBankRepair())
    end

    C_MerchantFrame.SellAllJunkItems()
end


-- Trigger sell and repair once per visit with a short delay to avoid race conditions because UI needs time to initialize

local function OnMerchantShow()
    if handled then return end
    handled = true
    C_Timer.After(0.1, AutoSellAndRepair)
end


-- Reset handled flag when merchant closes to allow processing on next visit because each visit should trigger independently

local function OnMerchantClosed()
    handled = false
end


-- Auto-confirm trade timer removal to skip popup when selling cooldown items because manual confirmation is annoying

local function OnTradeTimerConfirm()
    local popup = StaticPopup_FindVisible("CONFIRM_MERCHANT_TRADE_TIMER_REMOVAL")
    if popup then
        StaticPopup_OnClick(popup, 1)
    end
end


-- Register for merchant lifecycle events to activate features at the right time because addon needs event-driven activation

merchantFrame:RegisterEvent("MERCHANT_SHOW")
merchantFrame:RegisterEvent("MERCHANT_CLOSED")
merchantFrame:RegisterEvent("MERCHANT_CONFIRM_TRADE_TIMER_REMOVAL")

merchantFrame:SetScript("OnEvent", function(_, event)
    if event == "MERCHANT_SHOW" then
        OnMerchantShow()
    elseif event == "MERCHANT_CLOSED" then
        OnMerchantClosed()
    elseif event == "MERCHANT_CONFIRM_TRADE_TIMER_REMOVAL" then
        OnTradeTimerConfirm()
    end
end)
