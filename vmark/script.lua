g_cmd = '?vmark'

function onCustomCommand(full_message, user_peer_id, is_admin, is_auth, cmd, ...)
    local args = {...}
    if #args > 0 and args[#args] == '' then
        table.remove(args, #args)
    end

    if cmd == g_cmd then
        if #args <= 0 or args[1] == 'help' then
            execHelp(user_peer_id, is_admin, is_auth, args)
        elseif args[1] == 'list' then
            execList(user_peer_id, is_admin, is_auth, args)
        elseif args[1] == 'set' then
            execSet(user_peer_id, is_admin, is_auth, args)
        elseif args[1] == 'clear' then
            execClear(user_peer_id, is_admin, is_auth, args)
        else
            server.announce(getAnnounceName(), string.format('error: undefined subcommand: "%s"', args[1]), user_peer_id)
        end
    end
end

function execHelp(user_peer_id, is_admin, is_auth, args)
    server.announce(getAnnounceName(),
        g_cmd .. ' list [num]\n' ..
        g_cmd .. ' set [vehicle_id]\n' ..
        g_cmd .. ' clear',
        user_peer_id
    )
end

function execList(user_peer_id, is_admin, is_auth, args)
    if #args > 2 then
        server.announce(getAnnounceName(), 'error: too many arguments', user_peer_id)
        return
    end

    local num = 5
    if #args == 2 then
        num = tonumber(args[2])
        if num == fail or num < 0 or math.floor(num) ~= num then
            server.announce(getAnnounceName(), string.format('error: not a positive integer: "%s"', args[2]), user_peer_id)
            return
        end
    end

    local msg = {}
    for i = math.max(1, #g_savedata['vehicles'] - num + 1), #g_savedata['vehicles'] do
        table.insert(msg, string.format(
            'v%3d %s @%s "%s"',
            g_savedata['vehicles'][i]['vehicle_id'],
            formatTicks(g_savedata['time'] - g_savedata['vehicles'][i]['spawn_time']),
            g_savedata['vehicles'][i]['peer_name'],
            g_savedata['vehicles'][i]['vehicle_name']
        ))
    end
    msg = table.concat(msg, '\n')
    server.announce(getAnnounceName(), msg, user_peer_id)
end

function execSet(user_peer_id, is_admin, is_auth, args)
    if #args > 2 then
        server.announce(getAnnounceName(), 'error: too many arguments', user_peer_id)
        return
    end

    local mark = nil
    if #args == 2 then
        local vehicle_id = tonumber(args[2])
        if vehicle_id == fail or vehicle_id < 0 or math.floor(vehicle_id) ~= vehicle_id then
            server.announce(getAnnounceName(), string.format('error: not a vehicle_id: "%s"', args[2]), user_peer_id)
            return
        end
        mark = getVehicleInfo(vehicle_id)
        if mark == nil then
            server.announce(getAnnounceName(), string.format('error: unknown vehicle: %d', vehicle_id), user_peer_id)
            return
        end
    else
        if #g_savedata['vehicles'] <= 0 then
            server.announce(getAnnounceName(), 'error: no vehicle spawned yet', user_peer_id)
            return
        end
        mark = g_savedata['vehicles'][#g_savedata['vehicles']]
    end
    g_savedata['mark'] = mark
    server.announce(getAnnounceName(), string.format('%s marked %s', getPlayerDisplayName(user_peer_id), mark['vehicle_name']))
end

function execClear(user_peer_id, is_admin, is_auth, args)
    if #args > 1 then
        server.announce(getAnnounceName(), 'error: too many arguments', user_peer_id)
        return
    end
    g_savedata['mark'] = nil
    server.announce(getAnnounceName(), string.format('%s cleared the mark', getPlayerDisplayName(user_peer_id)))
end

function onVehicleSpawn(vehicle_id, peer_id, x, y, z, cost)
    local info = {
        ['spawn_time'] = g_savedata['time'],
        ['vehicle_id'] = vehicle_id,
    }
    local vehicle_name, is_success = server.getVehicleName(vehicle_id)
    info['vehicle_name'] = is_success and vehicle_name or '[unnamed vehicle]'
    local peer_name, is_success = server.getPlayerName(peer_id)
    info['peer_name'] = is_success and peer_name or '[script]'
    table.insert(g_savedata['vehicles'], info)
end

function onTick(game_ticks)
    g_savedata['time'] = g_savedata['time'] + game_ticks

    local vehicles = {}
    for _, info in ipairs(g_savedata['vehicles']) do
        local _, is_success = server.getVehiclePos(info['vehicle_id'])
        if is_success then
            table.insert(vehicles, info)
        end
    end
    g_savedata['vehicles'] = vehicles

    server.removeMapObject(-1, g_savedata['ui_id'])
    if g_savedata['mark'] ~= nil then
        local vehicle_matrix, is_success = server.getVehiclePos(g_savedata['mark']['vehicle_id'])
        if not is_success then
            server.announce(getAnnounceName(), string.format('%s despawned', g_savedata['mark']['vehicle_name']))
            g_savedata['mark'] = nil
        else
            local vehicle_x, vehicle_y, vehicle_z = matrix.position(vehicle_matrix)
            server.addMapObject(
                -1,
                g_savedata['ui_id'],
                0,
                2,
                vehicle_x,
                vehicle_z,
                0,
                0,
                -1,
                -1,
                g_savedata['mark']['vehicle_name'],
                0,
                ''
            )
            for _, player in pairs(server.getPlayers()) do
                local text = g_savedata['mark']['vehicle_name']
                local peer_matrix, is_success = server.getPlayerPos(player['id'])
                if is_success then
                    text = text .. '\n' .. formatDistance(matrix.distance(peer_matrix, vehicle_matrix))
                end
                server.setPopup(player['id'], g_savedata['ui_id'], getAnnounceName(), true, text, vehicle_x, vehicle_y, vehicle_z, 0)
            end
        end
    end
    if g_savedata['mark'] == nil then
        server.removePopup(-1, g_savedata['ui_id'])
    end
end

function onCreate(is_world_create)
    if g_savedata['version'] ~= 6 then
        g_savedata = {
            ['version'] = 6,
            ['time'] = 0,
            ['ui_id'] = server.getMapID(),
            ['vehicles'] = {}
        }
    end
end

function getAnnounceName()
    local playlist_index = server.getPlaylistIndexCurrent()
    local playlist_data = server.getPlaylistData(playlist_index)
    return string.format('[%s]', playlist_data['name'])
end

function getPlayerDisplayName(peer_id)
    local peer_name, is_success = server.getPlayerName(peer_id)
    if not is_success then
        return '[someone]'
    end
    return peer_name
end

function getVehicleInfo(vehicle_id)
    for _, info in ipairs(g_savedata['vehicles']) do
        if info['vehicle_id'] == vehicle_id then
            return info
        end
    end
end

function formatTicks(ticks)
    if ticks < 3600 then
        return string.format('%ds', ticks // 60)
    elseif ticks < 216000 then
        return string.format('%dm', ticks // 3600)
    elseif ticks < 5184000 then
        return string.format('%dh', ticks // 216000)
    end
    return string.format('%dd', ticks // 5184000)
end

function formatDistance(dist)
    if dist < 1000 then
        return string.format('%dm', math.floor(dist))
    end
    return string.format('%.1fkm', dist/1000)
end
