local function L(...) return ... end

local Modes = {
    Off = 0,
    Suppress = 1,
    Humanize = 2,
}

local function Initialize()
    if not RobotsDotTxtDB then
        RobotsDotTxtDB = {
            addons = { CraftScan = Modes.Humanize, CraftRadar = Modes.Humanize }
        }
    end

    -- Make a drop-down for each addon that can be filtered.
    local category, layout = Settings.RegisterVerticalLayoutCategory(L("robots.txt"))

    local function GetModeOptions()
        local container = Settings.CreateControlTextContainer()
        container:Add(Modes.Off, "Off")
        container:Add(Modes.Suppress, "Suppressed")
        container:Add(Modes.Humanize, "Humanized")
        return container:GetData()
    end

    for name, value in pairs(RobotsDotTxtDB.addons) do
        -- Setting ID must be unique
        local settingID = "RobotsDotTxt_" .. name

        local setting = Settings.RegisterAddOnSetting(
            category,
            settingID,
            name,
            RobotsDotTxtDB.addons,
            Settings.VarType.Number,
            name, -- The key within the table
            Modes.Humanize
        )

        Settings.CreateDropdown(
            category,
            setting,
            GetModeOptions,
            L("Filtering")
        )
    end

    Settings.RegisterAddOnCategory(category)
end

local silenced = {}
local function RobotsChatFilter(self, event, msg, author, ...)
    local name = Ambiguate(author, "none")
    if silenced[name] then
        return true -- filtered
    end
    return false    -- allowed
end

ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", RobotsChatFilter)

local ROBOTS_PREFIX = "robots.txt"
C_ChatInfo.RegisterAddonMessagePrefix(ROBOTS_PREFIX)

local listener = CreateFrame("Frame")
listener:RegisterEvent("CHAT_MSG_ADDON")
listener:RegisterEvent("ADDON_LOADED")

listener:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_ADDON" then
        local prefix, text, channel, sender = ...
        if prefix == ROBOTS_PREFIX and text:find("Q:") then
            local _, addonName = strsplit(":", text)

            -- Default to off, but 'discover' supported addons so that after we
            -- receive a message from a new addon, it shows up in the list to
            -- filter out.
            local mode = RobotsDotTxtDB.addons[addonName]
            if not mode then
                RobotsDotTxtDB.addons[addonName] = Modes.Humanize
                return
            end

            if mode == Modes.Off then
                return
            end

            local delay = math.random(10, 295)

            -- Add this sender to our filter, ignoring whispers from them for
            -- the next 5 seconds so we don't see the message sent by CraftScan.
            local senderName = Ambiguate(sender, "none")
            silenced[senderName] = true
            C_Timer.After(delay, function()
                silenced[senderName] = nil
            end)

            -- In humanize mode, tell the sender to send us a less useful
            -- message in a random, long amount of time, after we have dropped
            -- our filter.
            if mode == Modes.Humanize then
                local response = string.format("D:%d", delay + 5)
                C_ChatInfo.SendAddonMessage(ROBOTS_PREFIX, response, "WHISPER", sender)
            end
        end
    elseif event == "ADDON_LOADED" and ... == 'RobotsDotTxt' then
        Initialize()
    end
end)
