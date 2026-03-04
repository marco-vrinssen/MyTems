-- Sync auction house favorites across all characters
--
-- Account DB (MyTemsFavoritesDB) is the single source of truth.
-- Per-character DB (MyTemsFavoritesCharDB) stores a snapshot of what was
-- last synced so we can detect adds and removals from other characters.
--
-- First session modes:
--   Seed:    Account DB is empty, discover this character's existing
--            favorites and populate the account DB from them.
--   Enforce: Account DB has data, push it to character and remove any
--            character favorites not present in the account DB.
--
-- Subsequent sessions:
--   Two-way diff between account DB and snapshot to propagate adds
--   and removals made on other characters.

local ADDON_NAME = "MyTems"
local accountDB, characterDB
local syncing = false

-- Tracks first-session mode: "seed", "enforce", or nil (normal)

local sessionMode = nil

----------------------------------------------------------------
-- Item key handling
----------------------------------------------------------------

local KEY_FIELDS = {"itemID", "itemLevel", "itemSuffix", "battlePetSpeciesID", "itemContext"}

local function CopyItemKey(itemKey)
    local copy = {}
    for _, field in ipairs(KEY_FIELDS) do
        copy[field] = itemKey[field] or 0
    end
    return copy
end

local function SerializeItemKey(itemKey)
    local parts = {}
    for i, field in ipairs(KEY_FIELDS) do
        parts[i] = tostring(itemKey[field] or 0)
    end
    return table.concat(parts, ":")
end

-- Reconstruct a proper WoW ItemKey from a saved plain table

local function ToItemKey(saved)
    return C_AuctionHouse.MakeItemKey(
        saved.itemID or 0,
        saved.itemLevel or 0,
        saved.itemSuffix or 0,
        saved.battlePetSpeciesID or 0
    )
end

----------------------------------------------------------------
-- Chat notifications
----------------------------------------------------------------

local function GetItemLink(itemKey)
    if itemKey.itemID and itemKey.itemID ~= 0 then
        local _, link = C_Item.GetItemInfo(itemKey.itemID)
        if link then return link end
        C_Item.RequestLoadItemDataByID(itemKey.itemID)
        return "|cff9d9d9d[Item " .. itemKey.itemID .. "]|r"
    end
    return "|cff9d9d9d[Unknown]|r"
end

local function Notify(added, displayLink)
    local prefix = added and "|cff00ff00[+]|r " or "|cffff0000[-]|r "
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. displayLink)
    end
end

----------------------------------------------------------------
-- Safe wrapper for SetFavoriteItem
----------------------------------------------------------------

local function SafeSetFavorite(itemKey, isFavorite)
    local ok, err = pcall(C_AuctionHouse.SetFavoriteItem, itemKey, isFavorite)
    if not ok then
        local key = SerializeItemKey(itemKey)
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff6600[MyTems] Error setting favorite " .. key .. ": " .. tostring(err) .. "|r")
        end
    end
    return ok
end

----------------------------------------------------------------
-- Hook: capture user-initiated favorite changes in real time
----------------------------------------------------------------

hooksecurefunc(C_AuctionHouse, "SetFavoriteItem", function(itemKey, isFavorite)
    if syncing or not accountDB or not characterDB then return end
    local key = SerializeItemKey(itemKey)
    local copy = CopyItemKey(itemKey)
    if isFavorite then
        accountDB.favorites[key] = copy
        characterDB.snapshot[key] = copy
    else
        accountDB.favorites[key] = nil
        characterDB.snapshot[key] = nil
    end
    Notify(isFavorite, GetItemLink(itemKey))
end)

----------------------------------------------------------------
-- Browse result handler: behavior depends on session mode
----------------------------------------------------------------

local function HandleBrowseResult(itemKey)
    if not itemKey or not accountDB or not characterDB then return end

    if sessionMode == "seed" then
        -- First character ever: discover existing favorites into account DB

        if not C_AuctionHouse.IsFavoriteItem(itemKey) then return end
        local key = SerializeItemKey(itemKey)
        if accountDB.favorites[key] then return end
        local copy = CopyItemKey(itemKey)
        accountDB.favorites[key] = copy
        characterDB.snapshot[key] = copy

    elseif sessionMode == "enforce" then
        -- Account DB is authoritative: remove character favorites not in account

        if not C_AuctionHouse.IsFavoriteItem(itemKey) then return end
        local key = SerializeItemKey(itemKey)
        if accountDB.favorites[key] then return end
        syncing = true
        SafeSetFavorite(itemKey, false)
        syncing = false
        Notify(false, GetItemLink(itemKey))
    end
end

----------------------------------------------------------------
-- Sync favorites between account DB and character
----------------------------------------------------------------

local function SyncFavorites()
    if not accountDB or not characterDB then return end

    if not characterDB.initialized then
        local hasAccountData = next(accountDB.favorites) ~= nil

        if hasAccountData then
            -- Account DB has data: push to character, then enforce via browse

            syncing = true
            for key, saved in pairs(accountDB.favorites) do
                local itemKey = ToItemKey(saved)
                SafeSetFavorite(itemKey, true)
                characterDB.snapshot[key] = CopyItemKey(saved)
                Notify(true, GetItemLink(saved))
            end
            syncing = false
            sessionMode = "enforce"
        else
            -- Account DB is empty: seed it from this character's favorites

            sessionMode = "seed"
        end

        C_AuctionHouse.SearchForFavorites({})
        return
    end

    -- Subsequent sessions: two-way diff against snapshot

    syncing = true
    local changed = false

    -- Items in account DB but not in snapshot: added on another character

    for key, saved in pairs(accountDB.favorites) do
        if not characterDB.snapshot[key] then
            local itemKey = ToItemKey(saved)
            SafeSetFavorite(itemKey, true)
            characterDB.snapshot[key] = CopyItemKey(saved)
            Notify(true, GetItemLink(saved))
            changed = true
        end
    end

    -- Items in snapshot but not in account DB: removed on another character

    for key, saved in pairs(characterDB.snapshot) do
        if not accountDB.favorites[key] then
            local itemKey = ToItemKey(saved)
            SafeSetFavorite(itemKey, false)
            characterDB.snapshot[key] = nil
            Notify(false, GetItemLink(saved))
            changed = true
        end
    end

    syncing = false
    if changed then
        C_AuctionHouse.SearchForFavorites({})
    end
end

----------------------------------------------------------------
-- Event handling
----------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("AUCTION_HOUSE_SHOW")

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local addon = ...
        if addon == ADDON_NAME then
            MyTemsFavoritesDB = MyTemsFavoritesDB or {}
            accountDB = MyTemsFavoritesDB
            accountDB.favorites = accountDB.favorites or {}

            MyTemsFavoritesCharDB = MyTemsFavoritesCharDB or {}
            characterDB = MyTemsFavoritesCharDB
            characterDB.snapshot = characterDB.snapshot or {}
        end
        return
    end

    if event == "AUCTION_HOUSE_SHOW" then
        SyncFavorites()
        frame:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
        frame:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_ADDED")
        frame:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
        frame:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
        frame:RegisterEvent("AUCTION_HOUSE_CLOSED")
        return
    end

    if event == "AUCTION_HOUSE_CLOSED" then
        -- Finalize first session

        if characterDB and not characterDB.initialized then
            characterDB.initialized = true
        end
        sessionMode = nil
        frame:UnregisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
        frame:UnregisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_ADDED")
        frame:UnregisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
        frame:UnregisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
        frame:UnregisterEvent("AUCTION_HOUSE_CLOSED")
        return
    end

    -- Browse result scanning for first-session seed/enforce modes

    if event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" then
        for _, result in ipairs(C_AuctionHouse.GetBrowseResults()) do
            HandleBrowseResult(result.itemKey)
        end
        return
    end

    if event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then
        local results = ...
        if results then
            for _, result in ipairs(results) do
                HandleBrowseResult(result.itemKey)
            end
        end
        return
    end

    if event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
        local itemID = ...
        if itemID then
            HandleBrowseResult(C_AuctionHouse.MakeItemKey(itemID))
        end
        return
    end

    if event == "ITEM_SEARCH_RESULTS_UPDATED" then
        local itemKey = ...
        if itemKey then
            HandleBrowseResult(itemKey)
        end
        return
    end
end)
