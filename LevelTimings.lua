-- Copyright © 2020 vzx8. All rights reserved.
-- Licensed under GPLv3 (see license.txt).

local LEVEL_TIMINGS_CURRENT_DB_VERSION = 2

local addonName = ...
local LevelTimings = {}
-- timePlayedRequested is initialized to true so that if another addon requests time played before us, we handle that
local timePlayedRequested = true
-- levelUps is an array because the player can get multiple level ups at one time and we want to record them all
local levelUps = {}

local eventsFrame = CreateFrame("Frame")
eventsFrame:RegisterEvent("ADDON_LOADED")
eventsFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventsFrame:RegisterEvent("TIME_PLAYED_MSG")

local function handleEvents(self, event, ...)
    if event == "ADDON_LOADED" then
        self:UnregisterEvent("ADDON_LOADED")
        LevelTimings:handleLoaded(...)
    elseif event == "PLAYER_LEVEL_UP" then
        LevelTimings:handleLevelUp(...)
    elseif event == "TIME_PLAYED_MSG" then
        LevelTimings:handleTimePlayed(...)
    end
end

eventsFrame:SetScript("OnEvent", handleEvents)


function LevelTimings:handleLoaded(...)
    local loadedAddonName = ...
    if loadedAddonName ~= addonName then
        return
    end

    local guid = LevelTimings:playerGuid()
    if LevelTimingsDB ~= nil then
        LevelTimings:UpgradeDB()

        local playerEntry = LevelTimingsDB["players"][guid]
        if playerEntry ~= nil then
            -- The DB has already been initialized for this character
            timePlayedRequested = false
            
            -- Update base character data in case of some changes (eg. name or faction change)
            playerEntry.name = UnitFullName("player")
            playerEntry.realm = GetRealmName()
            playerEntry.class = select(2, UnitClass("player"))
            playerEntry.faction = UnitFactionGroup("player") 

            return
        end
    end

    -- if another addon requested time played first, timePlayedRequested will be false here
    if timePlayedRequested then
        RequestTimePlayed()
    end
end


function LevelTimings:handleLevelUp(...)
    local level = ...
    timePlayedRequested = true
    local isFirstLevelUp = #levelUps == 0
    table.insert(levelUps, level)
    if isFirstLevelUp then
        -- When there are multiple level ups at once, only request time played the first time (when the array was still empty)
        -- Assumption here is that all level up events are fired and handled before the time played message is handled
        RequestTimePlayed()
    end
end


function LevelTimings:handleTimePlayed(...)
    local totalTimePlayedSec = ...
    if not timePlayedRequested then
        return
    end
    timePlayedRequested = false

    if #levelUps == 0 then
        -- Message is fired during ADDON_LOADED
        LevelTimings:handleTimePlayedLoaded(totalTimePlayedSec)
        return
    end
    
    -- Message was fired during PLAYER_LEVEL_UP
    LevelTimings:handleTimePlayedLevelUp(totalTimePlayedSec, levelUps)
    levelUps = {}
end

function LevelTimings:handleTimePlayedLoaded(totalTimePlayedSec)
    if LevelTimingsDB == nil then
        -- If the DB does not exist at all yet, initialize it to an empty table first
        LevelTimingsDB = {version = LEVEL_TIMINGS_CURRENT_DB_VERSION, players = {}}
    end

    local guid = LevelTimings:playerGuid()
    if LevelTimingsDB["players"][guid] ~= nil then
        return
    end

    -- No entry for the player, initialize entry
    local name = UnitFullName("player")
    -- GetRealmName() returns with spaces (eg. "Aerie Peak"), while UnitFullName() returns without (eg. "AeriePeak")
    local realm = GetRealmName()
    local currentLevel = UnitLevel("player")
    local class = select(2, UnitClass("player"))
    local faction = UnitFactionGroup("player")
    local timestamp = time()
    local gameVersion, _, _, tocVersion = GetBuildInfo()
    LevelTimingsDB["players"][guid] = {
        name = name,
        realm = realm,
        class = class,
        faction = faction,
        timings = {{
            initial = true,
            level = currentLevel,
            timestamp = timestamp,
            played = totalTimePlayedSec,
            gameVersion = gameVersion,
            tocVersion = tocVersion
        }}
    }
end

function LevelTimings:handleTimePlayedLevelUp(totalTimePlayedSec, newLevels)
    local timestamp = time()
    local guid = LevelTimings:playerGuid()
    local zone = GetRealZoneText()
    local subZone = GetSubZoneText()

    for _, newLevel in ipairs(newLevels) do
        -- Record the data into the database
        local timings = LevelTimingsDB["players"][guid]["timings"]
        local gameVersion, _, _, tocVersion = GetBuildInfo()
        table.insert(timings, {
            level = newLevel,
            timestamp = timestamp,
            played = totalTimePlayedSec,
            zone = zone,
            subzone = subZone,
            gameVersion = gameVersion,
            tocVersion = tocVersion
        })

        -- Show a nice message to the player
        local prevEntry = timings[#timings - 1]
        if prevEntry ~= nil then
            local secondsNeededToReachThislevel = totalTimePlayedSec - prevEntry.played
        end

        -- Refresh the UI in case it is open at this time
        LevelTimingsUI_RefreshList()
    end
end

-- Converts the DB of an old format which was a table of level to entry, to a flat array
function LevelTimings:UpgradeDB()
    if LevelTimingsDB["version"] == LEVEL_TIMINGS_CURRENT_DB_VERSION then
        return
    end

    -- The new DB format now has a version number and player timings are in the 'players' entry rather than the top level
    local newDb = {version = LEVEL_TIMINGS_CURRENT_DB_VERSION, players = {}}
    local newDbPlayers = newDb["players"]
    for guid, playerData in pairs(LevelTimingsDB) do
        -- Timings are now a flat array, not indexed by level; the level is now inside the entry
        local newTimings = {}
        for level, entry in pairs(playerData["timings"]) do
            entry["level"] = level
            table.insert(newTimings, entry)
        end
        playerData["timings"] = newTimings
        newDbPlayers[guid] = playerData
    end
    LevelTimingsDB = newDb
end

function LevelTimings:playerGuid()
    return UnitGUID("player")
end

function LevelTimings_GetConfig(key)
    if not LevelTimingsConfig then
        LevelTimingsConfig = {}
    end
    return LevelTimingsConfig[key]
end

function LevelTimings_SetConfig(key, value)
    if not LevelTimingsConfig then
        LevelTimingsConfig = {}
    end
    LevelTimingsConfig[key] = value
end
