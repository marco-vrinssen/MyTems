-- Post auctions with spacebar and default to current expansion filter to speed up auction workflow because default UI requires extra clicks

local auctionFrame = CreateFrame("Frame")
local postEnabled = false


-- Find visible sell frame and click post button to submit auction because multiple sell frames can be active

local function PostAuction()
    if not postEnabled then return end
    if not AuctionHouseFrame or not AuctionHouseFrame:IsShown() then return end

    local sellFrames = {
        AuctionHouseFrame.CommoditiesSellFrame,
        AuctionHouseFrame.ItemSellFrame,
        AuctionHouseFrame.SellFrame,
    }

    for _, sellFrame in ipairs(sellFrames) do
        if sellFrame and sellFrame:IsShown() and sellFrame.PostButton and sellFrame.PostButton:IsEnabled() then
            sellFrame.PostButton:Click()
            return
        end
    end
end


-- Enable current expansion filter to reduce search noise when Blizzard auction UI loads because most trades involve current items

local function OnAddonLoaded(addonName)
    if addonName == "Blizzard_AuctionHouseUI" then
        if AUCTION_HOUSE_DEFAULT_FILTERS then
            AUCTION_HOUSE_DEFAULT_FILTERS[Enum.AuctionHouseFilter.CurrentExpansionOnly] = true
        end
    end
end


-- Bind spacebar to post auction while auction house is open to enable quick posting because mouse clicking is slower

local function OnAuctionHouseShow()
    postEnabled = true

    auctionFrame:SetScript("OnKeyDown", function(_, key)
        if key == "SPACE" and postEnabled then
            PostAuction()
            auctionFrame:SetPropagateKeyboardInput(false)
        else
            auctionFrame:SetPropagateKeyboardInput(true)
        end
    end)

    auctionFrame:SetPropagateKeyboardInput(true)
    auctionFrame:EnableKeyboard(true)
    auctionFrame:SetFrameStrata("HIGH")
end


-- Unbind spacebar and disable posting when auction house closes to restore default key behavior because posting outside is invalid

local function OnAuctionHouseClosed()
    postEnabled = false
    auctionFrame:SetScript("OnKeyDown", nil)
    auctionFrame:EnableKeyboard(false)
end


-- Register for auction house lifecycle and addon load events to activate features at the right time because timing matters

auctionFrame:RegisterEvent("ADDON_LOADED")
auctionFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
auctionFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")

auctionFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        OnAddonLoaded(...)
    elseif event == "AUCTION_HOUSE_SHOW" then
        OnAuctionHouseShow()
    elseif event == "AUCTION_HOUSE_CLOSED" then
        OnAuctionHouseClosed()
    end
end)
