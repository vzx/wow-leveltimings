--[[
TODO:
- Detect name change upon loading
- Custom duration calculation
- Reset feature
- UI to display level ups
]]--

local LevelTimings = {}
local addonName = 'LevelTimings'
-- timePlayedRequested is initialized to true so that if another addon requests time played before us, we handle that
local timePlayedRequested = true
-- levelUps is an array because the player can get multiple level ups at one time and we want to record them all
local levelUps = {}

SLASH_LevelTimings1 = "/leveltimings"
SlashCmdList['LevelTimings'] = function(msg)
    -- Assumption: database has already been initialized at this point
    local guid = UnitGUID("player")
    if LevelTimingsDB == nil or LevelTimingsDB[guid] == nil then
        print('[LevelTimings] LevelTimingsDB not initialized, LevelTimingsDB:', LevelTimingsDB, '; LevelTimingsDB[guid]:', LevelTimingsDB[guid])
        return
    end

    local charEntry = LevelTimingsDB[guid]
    local timings = charEntry.timings;
    local levels = {}
    local n = 1
    for level, entry in pairs(timings) do
        levels[n] = level
        n = n + 1
    end
    table.sort(levels)
    print('Level timings for ' .. charEntry.name .. '-' .. charEntry.realm)
    for _, level in pairs(levels) do
        local t = timings[level]
        local prev = timings[level-1]
        local delta = ""
        if prev ~= nil then
            delta = " (" .. SecondsToTime(t.played - prev.played) .. ")"
        end
        print("[" .. date("%Y-%m-%d %H:%M:%S", t.timestamp) .. "] " .. level .. ": " .. SecondsToTime(t.played) .. delta)
    end
end


local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("TIME_PLAYED_MSG")

local function handleEvents(self, event, ...)
    print('[LevelTimings] handle event', event, ...)
    if event == "ADDON_LOADED" then
        self:UnregisterEvent("ADDON_LOADED")
        LevelTimings:handleLoaded(...)
    elseif event == "PLAYER_LEVEL_UP" then
        LevelTimings:handleLevelUp(...)
    elseif event == "TIME_PLAYED_MSG" then
        LevelTimings:handleTimePlayed(...)
    end
end

frame:SetScript("OnEvent", handleEvents)


function LevelTimings.handleLoaded(self, ...)
    local addonName = ...
    if addonName ~= addonName then
        return
    end

    local guid = LevelTimings:playerGuid()
    if LevelTimingsDB ~= nil and LevelTimingsDB[guid] ~= nil then
        -- The DB has already been initialized for this character, nothing to do
        print('[LevelTimings] LevelTimingsDB already initialized')
        timePlayedRequested = false
        return
    end

    -- if another addon requested time played first, timePlayedRequested should be false here
    if timePlayedRequested then
        RequestTimePlayed()
    else
        print('[LevelTimings] NOT requesting time played, it was already handled')
    end
end


function LevelTimings.handleLevelUp(self, ...)
    local level = ...
    timePlayedRequested = true
    local isFirstLevelUp = #levelUps == 0
    table.insert(levelUps, level)
    if isFirstLevelUp then
        -- When there are multiple level ups at once, only request time played the first time (when the array was still empty)
        -- Assumption here is that all level up events are fired and handled before the time played message is handled
        RequestTimePlayed()
    else
        print('[LevelTimings] Multiple level ups, this is number', #levelUps)
    end
end


function LevelTimings.handleTimePlayed(self, ...)
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

function LevelTimings.handleTimePlayedLoaded(self, totalTimePlayedSec)
    if LevelTimingsDB == nil then
        -- If the DB does not exist at all yet, initialize it to an empty table
        print('[LevelTimings] LevelTimingsDB is nil, initializing')
        LevelTimingsDB = {}
    end

    local guid = LevelTimings:playerGuid()
    if LevelTimingsDB[guid] ~= nil then
        print('[LevelTimings] LevelTimingsDB for', guid, 'already exists')
        return
    end

    print('[LevelTimings] LevelTimingsDB for', guid, 'is nil, initializing')

    -- No entry for the player at all, initialize entry
    local name, realm = UnitFullName('player')
    local currentLevel = UnitLevel('player')
    local timestamp = time()
    print('[LevelTimings] name:', name, '; realm:', realm, '; currentLevel:', currentLevel, '; timestamp:', timestamp, '; totalTimePlayedSec:', totalTimePlayedSec)
    LevelTimingsDB[guid] = {
        ['name'] = name,
        ['realm'] = realm,
        ['timings'] = {
            [currentLevel] = {
                ['initial'] = true,
                ['timestamp'] = timestamp,
                ['played'] = totalTimePlayedSec
            }
        }
    }
end

function LevelTimings:handleTimePlayedLevelUp(totalTimePlayedSec, newLevels)
    -- Assumption: DB is fully initialized at this point
    local timestamp = time()
    local guid = LevelTimings:playerGuid()

    if LevelTimingsDB == nil or LevelTimingsDB[guid] == nil then
        print('[LevelTimings] DB not initialized; LevelTimingsDB:', LevelTimingsDB, '; LevelTimingsDB[guid]:', LevelTimingsDB[guid])
        return
    end

    print('[LevelTimings] newLevels:', table.concat(newLevels, ", "), '; timestamp:', timestamp, '; totalTimePlayedSec:', totalTimePlayedSec, '; guid:', guid)
    for _, newLevel in ipairs(newLevels) do
        print('recording new level', newLevel)
        LevelTimingsDB[guid]['timings'][newLevel] = {
            ['timestamp'] = timestamp,
            ['played'] = totalTimePlayedSec
        }

        local prevLevel = newLevel - 1
        local prevEntry = LevelTimingsDB[guid]['timings'][prevLevel]
        if prevEntry ~= nil then
            local secondsNeededToReachThislevel = totalTimePlayedSec - prevEntry.played
            print('[LevelTimings] Took ' .. SecondsToTime(secondsNeededToReachThislevel) .. ' to reach level ' .. newLevel .. ' (' .. secondsNeededToReachThislevel .. ' seconds)')
        end
    end
end

function LevelTimings.playerGuid()
    return UnitGUID("player")
end

function LevelTimings.storeLevelTimings(self, playerGuid, isInitial, level, timestamp, totalTimePlayedSec)
    local entry = {
        ['level'] = level,
        ['timestamp'] = timestamp,
        ['played'] = totalTimePlayedSec
    }
    if isInitial then
        entry.initial = true
    end

    LevelTimingsDB[playerGuid] = entry
end
