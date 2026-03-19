-- Create event frame to receive merchant notifications because WoW requires a frame to register events
local merchantEventFrame = CreateFrame("Frame")

local eventHandlers = {
    MERCHANT_SHOW = function()
        -- Unregister and defer to trigger once per session because the merchant frame may not be ready on the same tick
        merchantEventFrame:UnregisterEvent("MERCHANT_SHOW")
        RunNextFrame(function()
            if CanMerchantRepair() then RepairAllItems() end
            if C_MerchantFrame.IsSellAllJunkEnabled() then C_MerchantFrame.SellAllJunkItems() end
        end)
    end,

    MERCHANT_CLOSED = function()
        -- Re-register show event to restore automation for the next vendor visit
        merchantEventFrame:RegisterEvent("MERCHANT_SHOW")
    end,

    MERCHANT_CONFIRM_TRADE_TIMER_REMOVAL = function()
        -- Defer popup confirmation because the popup may not exist on the same tick
        RunNextFrame(function()
            local tradeTimerPopup = StaticPopup_FindVisible("CONFIRM_MERCHANT_TRADE_TIMER_REMOVAL")
            if tradeTimerPopup then tradeTimerPopup.button1:Click() end
        end)
    end,
}

-- Route events through handler table because each registered event maps to exactly one function
merchantEventFrame:SetScript("OnEvent", function(_, event)
    eventHandlers[event]()
end)

-- Register all events to subscribe the frame to merchant notifications
for event in pairs(eventHandlers) do
    merchantEventFrame:RegisterEvent(event)
end
