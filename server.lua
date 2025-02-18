-- Exports
local BadgerDiscordAPI = exports['Badger_Discord_API']

-- hardcap swapping
StopResource('hardcap')

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        if GetResourceState('hardcap') == 'stopped' then
            StartResource('hardcap')
        end
    end
end)

-- Functions
local function getDiscordId(src)
    local identifier
    local whitelisted
    local id

    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        id = GetPlayerIdentifier(src, i)

        if string.find(id, 'discord') then
            identifier = id:gsub('discord:', '')
            break
        end
    end

    return identifier
end

local function showFlightCard(deferral, seat, connCount, priorityLabel)
    local cardString = [[{
    "type": "AdaptiveCard",
    "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
    "version": "1.3",
    "body": [
        {
            "type": "TextBlock",
            "text": "]]..Config.Displays.Prefix..[[",
            "wrap": true,
            "size": "Large",
            "weight": "Bolder",
            "color": "Light",
            "horizontalAlignment": "Center"
        },
        {
            "type": "Image",
            "url": "]]..Config.SplashImage..[[",
            "horizontalAlignment": "Center"
        },
        {
            "type": "Container",
            "items": [
                {
                    "type": "TextBlock",
                    "text": "You are flying in the ]]..priorityLabel..[[ section, seat ]]..tostring(seat)..[[ / ]]..tostring(connCount)..[[",
                    "wrap": true,
                    "color": "Light",
                    "size": "Medium",
                    "horizontalAlignment": "Center"
                }
            ],
            "style": "default",
            "bleed": true,
            "height": "stretch"
        }
    ]
}]]

    deferral.presentCard(cardString)
end

-- Events
local connectedDiscordIds = {}
local grace = {}
local graceCount = 0
local connections = {}
local connCount = 0
local loadCount = 0
local sessions = {}

AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    deferrals.defer()
    local src = source
    local discordId = getDiscordId(src)
    local prioRoles = BadgerDiscordAPI:GetDiscordRoles(src)
    Wait(0)

    if not discordId then
        deferrals.done(Config.Displays.Prefix .. ' ' .. Config.Displays.Messages.MSG_DISCORD_REQUIRED)
        print(name..' disconnected for lack of Discord')
    elseif not prioRoles then
        deferrals.done(Config.Displays.Prefix .. ' ' .. Config.Displays.Messages.MSG_MISSING_WHITELIST)
        print(name..' disconnected for lack of whitelisted role')
    elseif connectedDiscordIds[discordId] then
        deferrals.done(Config.Displays.Prefix .. ' ' .. Config.Displays.Messages.MSG_DUPLICATE_LICENSE)
        print(name..' disconnected for duplicate Discord')
    else
        print(name..' is connecting with deferred source '..tostring(src)..' and discord '..discordId)
        local priority
        local priorityLabel

        if grace[discordId] then
            grace[discordId] = GetGameTimer()
            print('Grace prio timer reset for '..name)
            priority = -1
            priorityLabel = 'Grace'
        else
            priority = 10000

            for _,v in pairs(prioRoles) do
                for l,q in pairs(Config.Rankings) do
                    if BadgerDiscordAPI:CheckEqual(v, l) then
                        if q <= priority then
                            priority = q
                            priorityLabel = l
                        end
                    end
                end
            end
        end

        if priorityLabel then
            print(name..' placed in queue with prio '..tostring(priorityLabel))

            MySQL.prepare.await(
                'INSERT into queueStats ( discordId, queueStartTime, queueStopTime, queueType ) values ( ?, now(), null, ? );', {
                discordId,
                priorityLabel
            })

            local dbEntryData = MySQL.prepare.await(
                'SELECT id from queueStats where discordId = ? and queueStopTime is null order by queueStartTime;', {
                discordId
            })

            if type(dbEntryData) == 'table' then
                local numRecords = #dbEntryData

                if numRecords > 1 then
                    for i=1,(numRecords-1) do
                        MySQL.prepare.await(
                            'UPDATE queueStats a set queueStopTime = \'12/31/9999\' where id = ?;', {
                            dbEntryData[i]
                        })
                    end
                end

                dbEntryData = dbEntryData[numRecords]
            end

            local dbEntry = dbEntryData

            connections[discordId] = {
                Priority = priority,
                Deferral = deferrals,
                Name = name,
                Source = src,
                dbEntry = dbEntry,
                PriorityLabel = priorityLabel,
                StartTime = GetGameTimer(),
                MetBufferReq = false,
            }

            connCount = connCount + 1
        end
    end
end)

RegisterNetEvent('DiscordQueue:Activated', function()
    local src = source
    local playerName = GetPlayerName(src)
    local discordId = getDiscordId(src)

    if connections[discordId] then
        MySQL.prepare.await(
            'INSERT into sessionStats ( queueId, sessionStartTime ) values ( ?, now() );', {
            connections[discordId].dbEntry
        })

        local dbEntryData = MySQL.prepare.await(
            'SELECT id from sessionStats where queueId = ? and sessionStopTime is null order by sessionStartTime;', {
            connections[discordId].dbEntry
        })

        sessions[src] = dbEntryData
        connections[discordId] = nil
        connCount = connCount - 1
        loadCount = loadCount - 1
        grace[discordId] = nil
        graceCount = graceCount - 1
        print(playerName..' granted Grace prio for next disconnect')
    end
end)

AddEventHandler('playerDropped', function (reason)
    local src = source
    local discordId = getDiscordId(src)

    if discordId then
        grace[discordId] = GetGameTimer()
        graceCount = graceCount + 1
        print(GetPlayerName(src)..' disconnected')
    end

    if sessions[src] then
        MySQL.prepare.await(
            'UPDATE sessionStats a set sessionStopTime = now() where id = ?;', {
            sessions[src]
        })

        sessions[src] = nil
    end
end)

-- Queue Thread
CreateThread(function()
    local playerCount
    local PollDelayInMS = Config.PollDelayInSeconds * 1000
    local GracePeriodInMS = Config.GracePeriodInSeconds * 1000
    local DeferralCardBufferInMS = Config.DeferralCardBufferInSeconds * 1000
    local maxConnections = GetConvarInt('sv_maxclients', 10)
    local textCount = 0
    local priority

    while true do
        priority = {}

        for k,v in pairs(grace) do
            if GetGameTimer() - v > GracePeriodInMS then
                print('Grace prio removed from '..k)
                grace[k] = nil
            end
        end

        for k,v in pairs(connections) do
            if v.Name == GetPlayerName(v.Source) then
                if not v.MetBufferReq and GetGameTimer() - v.StartTime >= DeferralCardBufferInMS then
                    v.MetBufferReq = true
                end

                table.insert(priority, {
                    DiscordId = k,
                    Priority = v.Priority,
                    Deferral = v.Deferral,
                    Name = v.Name,
                    Source = v.Source,
                    Loading = v.Loading,
                    PriorityLabel = v.PriorityLabel,
                    StartTime = v.StartTime,
                    MetBufferReq = v.MetBufferReq,
                })
            else
                MySQL.prepare.await(
                    'UPDATE queueStats a set queueStopTime = now(), discordId = null where id = ?;', {
                    connections[k].dbEntry
                })

                connections[k] = nil
                connCount = connCount - 1
            end

            local newConnCount = 0

            for _,_ in pairs(connections) do
                newConnCount = newConnCount + 1
            end

            if connCount ~= newConnCount then
                connCount = newConnCount
                print('Connection count corrected')
            end
        end

        table.sort(priority, function(a, b)
            local ret

            if a.Loading ~= b.Loading then
                ret = (not a.Loading) and b.Loading
            elseif a.MetBufferReq ~= b.MetBufferReq then
                ret = a.MetBufferReq and (not b.MetBufferReq)
            else
                ret = a.Priority < b.Priority
            end

            return ret
        end)

        for k,v in ipairs(priority) do
            if v.Deferral and (not v.Loading) then
                if k == 1 then
                    playerCount = GetNumPlayerIndices()

                    if
                        (
                            (
                                grace[v.DiscordId]
                                and connections[v.DiscordId]
                            )
                            or playerCount + graceCount + loadCount + 1 <= maxConnections
                        )
                        and v.MetBufferReq
                    then
                        v.Deferral.done()

                        MySQL.prepare.await(
                            'UPDATE queueStats a set queueStopTime = now(), discordId = null where id = ?;', {
                            connections[v.DiscordId].dbEntry
                        })

                        connections[v.DiscordId].Loading = true
                        loadCount = loadCount + 1
                    else
                        showFlightCard(v.Deferral, k, connCount, v.PriorityLabel)
                    end
                else
                    showFlightCard(v.Deferral, k, connCount, v.PriorityLabel)
                end
            end
        end

        Wait(PollDelayInMS)
    end
end)
