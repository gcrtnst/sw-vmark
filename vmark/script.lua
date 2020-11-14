function onCustomCommand(full_message, user_peer_id, is_admin, is_auth, cmd, ...)
    local args = {...}
    local mission_cmd = '?vmark'
    if cmd == mission_cmd then
        if #args <= 0 or args[1] == 'help' then
            server.announce(
                getPlaylistNameCurrent(),
                mission_cmd .. ' list [num]\n' ..
                mission_cmd .. ' set [vehicle_id]\n' ..
                mission_cmd .. ' clear',
                user_peer_id
            )
            return
        elseif args[1] == 'list' then
            if #args > 2 then
                server.announce(getPlaylistNameCurrent(), 'too many arguments', user_peer_id)
                return
            end

            local num = 5
            if #args == 2 then
                num = tonumber(args[2])
                if num == fail then
                    server.announce(getPlaylistNameCurrent(), string.format('expected number, got "%s"', args[2]), user_peer_id)
                    return
                elseif num < 0 then
                    server.announce(getPlaylistNameCurrent(), string.format('expected positive number, got "%s"', args[2]), user_peer_id)
                    return
                elseif math.floor(num) ~= num then
                    server.announce(getPlaylistNameCurrent(), string.format('expected integer, got "%s"', args[2]), user_peer_id)
                    return
                end
            end

            local list = loadList()
            local msg = {}
            for i = math.max(1, #list - num + 1), #list do
                table.insert(msg, string.format(
                    '[%d]%s (spawned %s ago by %s)',
                    list[i]['vehicle_id'],
                    list[i]['vehicle_display_name'],
                    formatTicks(g_savedata['time'] - list[i]['spawn_time']),
                    list[i]['peer_display_name']
                ))
            end
            msg = table.concat(msg, '\n')
            server.announce(getPlaylistNameCurrent(), msg, user_peer_id)
            return
        elseif args[1] == 'set' then
            if #args > 2 then
                server.announce(getPlaylistNameCurrent(), 'too many arguments', user_peer_id)
                return
            end

            local list = loadList()
            local mark = nil
            if #args == 2 then
                local vehicle_id = tonumber(args[2])
                if vehicle_id == fail then
                    server.announce(getPlaylistNameCurrent(), string.format('expected number, got "%s"', args[2]), user_peer_id)
                    return
                end
                mark = getVehicleInfo(vehicle_id)
                if mark == nil then
                    server.announce(getPlaylistNameCurrent(), string.format('vehicle_id of a non-existent vehicle: %d', vehicle_id), user_peer_id)
                    return
                end
            else
                if #list <= 0 then
                    server.announce(getPlaylistNameCurrent(), 'no vehicle spawned yet', user_peer_id)
                    return
                end
                mark = list[#list]
            end
            g_savedata['mark'] = mark
            server.announce(getPlaylistNameCurrent(), string.format('%s marked %s', getPlayerDisplayName(user_peer_id), mark['vehicle_display_name']))
            return
        elseif args[1] == 'clear' then
            if #args > 1 then
                server.announce(getPlaylistNameCurrent(), 'too many arguments', user_peer_id)
                return
            end
            g_savedata['mark'] = nil
            server.announce(getPlaylistNameCurrent(), string.format('%s cleared the mark', getPlayerDisplayName(user_peer_id)))
            return
        else
            server.announce(getPlaylistNameCurrent(), string.format('unknown subcommand "%s"', args[1]), user_peer_id)
            return
        end
    end
end

function onVehicleSpawn(vehicle_id, peer_id, x, y, z, cost)
    local info = {
        ['spawn_time'] = g_savedata['time'],
        ['vehicle_id'] = vehicle_id,
    }
    local vehicle_name, is_success = server.getVehicleName(vehicle_id)
    info['vehicle_name'] = is_success and vehicle_name or nil
    info['vehicle_display_name'] = is_success and vehicle_name or 'unnamed vehicle'
    local peer_name, is_success = server.getPlayerName(peer_id)
    info['peer_name'] = is_success and peer_name or nil
    info['peer_display_name'] = is_success and peer_name or 'script'

    local list = loadList()
    table.insert(list, info)
    while #list > 1024 do
        table.remove(list, 1)
    end
    saveList(list)
end

function onTick(game_ticks)
    g_savedata['time'] = g_savedata['time'] + game_ticks

    local old_list = loadList()
    local new_list = {}
    for _, info in ipairs(old_list) do
        local _, is_success = server.getVehiclePos(info['vehicle_id'])
        if is_success then
            table.insert(new_list, info)
        end
    end
    saveList(new_list)

    server.removeMapObject(-1, g_savedata['ui_id'])
    if g_savedata['mark'] ~= nil then
        local vehicle_matrix, is_success = server.getVehiclePos(g_savedata['mark']['vehicle_id'])
        if not is_success then
            server.announce(getPlaylistNameCurrent(), string.format('%s despawned', g_savedata['mark']['vehicle_display_name']))
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
                g_savedata['mark']['vehicle_display_name'],
                0,
                ''
            )
            for _, player in pairs(server.getPlayers()) do
                local text = g_savedata['mark']['vehicle_display_name']
                local peer_matrix, is_success = server.getPlayerPos(player['id'])
                if is_success then
                    text = text .. '\n' .. formatDistance(matrix.distance(peer_matrix, vehicle_matrix))
                end
                server.setPopup(player['id'], g_savedata['ui_id'], getPlaylistNameCurrent(), true, text, vehicle_x, vehicle_y, vehicle_z, 0)
            end
        end
    end
    if g_savedata['mark'] == nil then
        server.removePopup(-1, g_savedata['ui_id'])
    end
end

function onCreate(is_world_create)
    if g_savedata['version'] ~= 2 then
        g_savedata = {
            ['version'] = 2,
            ['time'] = 0,
            ['ui_id'] = server.getMapID(),
            ['list'] = {}
        }
    end
end

function getPlaylistNameCurrent()
    local playlist_index = server.getPlaylistIndexCurrent()
    local playlist_data = server.getPlaylistData(playlist_index)
    return playlist_data['name']
end

function getPlayerDisplayName(peer_id)
    local peer_name, is_success = server.getPlayerName(peer_id)
    if not is_success then
        return 'someone'
    end
    return peer_name
end

function getVehicleInfo(vehicle_id)
    local list = loadList()
    for _, info in ipairs(list) do
        if info['vehicle_id'] == vehicle_id then
            return info
        end
    end

    local _, is_success = server.getVehiclePos(vehicle_id)
    if not is_success then
        return nil
    end

    local info = {
        ['vehicle_id'] = vehicle_id,
        ['peer_display_name'] = 'someone'
    }
    local vehicle_name, is_success = server.getVehicleName(vehicle_id)
    info['vehicle_name'] = is_success and vehicle_name or nil
    info['vehicle_display_name'] = is_success and vehicle_name or 'unnamed vehicle'
    return info
end

function loadList()
    local list = {}
    for i, item in pairs(g_savedata['list']) do
        i = tonumber(i)
        if i ~= fail then
            list[i] = item
        end
    end
    return list
end

function saveList(list)
    g_savedata['list'] = {}
    for i, value in ipairs(list) do
        g_savedata['list'][tostring(i)] = value
    end
end

function formatTicks(ticks)
    if ticks < 2 then
        return string.format('%d', ticks) .. ' tick'
    elseif ticks < 60 then
        return string.format('%d', ticks) .. ' ticks'
    elseif ticks < 120 then
        return '1 second'
    elseif ticks < 3600 then
        return string.format('%d', ticks // 60) .. ' seconds'
    elseif ticks < 7200 then
        return '1 minute'
    elseif ticks < 216000 then
        return string.format('%d', ticks // 3600) .. ' minutes'
    elseif ticks < 432000 then
        return '1 hour'
    elseif ticks < 5184000 then
        return string.format('%d', ticks // 216000) .. ' hours'
    elseif ticks < 10368000 then
        return '1 day'
    end
    return string.format('%d', ticks // 5184000) .. ' days'
end

function formatDistance(dist)
    if dist < 1000 then
        return string.format('%dm', math.floor(dist))
    end
    return string.format('%.1fkm', dist/1000)
end
