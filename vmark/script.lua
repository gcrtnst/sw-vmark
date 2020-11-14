function onCustomCommand(full_message, user_peer_id, is_admin, is_auth, cmd, ...)
    local args = {...}
    local mission_cmd = '?vmark'
    if cmd == mission_cmd then
        if #args <= 0 or args[1] == 'help' then
            server.announce(
                full_message,
                mission_cmd .. ' list [num]\n' ..
                mission_cmd .. ' set [vehicle_id]\n' ..
                mission_cmd .. ' clear',
                user_peer_id
            )
            return
        elseif args[1] == 'list' then
            if #args > 2 then
                server.announce(full_message, 'too many arguments', user_peer_id)
                return
            end

            local num = 5
            if #args == 2 then
                num = tonumber(args[2])
                if num == fail then
                    server.announce(full_message, string.format('expected number, got "%s"', args[2]), user_peer_id)
                    return
                elseif num < 0 then
                    server.announce(full_message, string.format('expected positive number, got "%s"', args[2]), user_peer_id)
                    return
                elseif math.floor(num) ~= num then
                    server.announce(full_message, string.format('expected integer, got "%s"', args[2]), user_peer_id)
                    return
                end
            end

            local list = loadList()
            local msg = {}
            for i = math.max(1, #list - num + 1), #list do
                table.insert(msg, string.format(
                    '[%d]%s (spawned by %s, %s ago)',
                    list[i]['vehicle_id'],
                    list[i]['vehicle_display_name'],
                    list[i]['peer_display_name'],
                    formatTicks(g_savedata['time'] - list[i]['spawn_time'])
                ))
            end
            msg = table.concat(msg, '\n')
            server.announce(full_message, msg, user_peer_id)
            return
        elseif args[1] == 'set' then
            if #args > 2 then
                server.announce(full_message, 'too many arguments', user_peer_id)
                return
            end

            local list = loadList()
            local mark = nil
            if #args == 2 then
                local vehicle_id = tonumber(args[2])
                if vehicle_id == fail then
                    server.announce(full_message, string.format('expected number, got "%s"', args[2]), user_peer_id)
                    return
                end
                for i = 1, #list do
                    if list[i]['vehicle_id'] == vehicle_id then
                        mark = list[i]
                        break
                    end
                end
                if mark == nil then
                    server.announce(full_message, string.format('unlisted vehicle_id: %d', vehicle_id), user_peer_id)
                    return
                end
            else
                if #list <= 0 then
                    server.announce(full_message, 'no vehicle spawned yet', user_peer_id)
                    return
                end
                mark = list[#list]
            end
            g_savedata['mark'] = mark
            server.announce(full_message, string.format('%s marked %s', getPlayerDisplayName(user_peer_id), mark['vehicle_display_name']))
            return
        elseif args[1] == 'clear' then
            if #args > 1 then
                server.announce(full_message, 'too many arguments', user_peer_id)
                return
            end
            g_savedata['mark'] = nil

            server.removeMapObject(-1, g_savedata['ui_id'])
            server.removePopup(-1, g_savedata['ui_id'])
            server.announce(full_message, string.format('%s cleared the mark', getPlayerDisplayName(user_peer_id)))
            return
        else
            server.announce(full_message, string.format('unknown subcommand "%s"', args[1]), user_peer_id)
            return
        end
    end
end

function onVehicleSpawn(vehicle_id, peer_id, x, y, z, cost)
    local info = {
        ['spawn_time'] = g_savedata['time'],
        ['vehicle_id'] = vehicle_id,
        ['x'] = x,
        ['y'] = y,
        ['z'] = z,
    }
    local vehicle_name, is_success = server.getVehicleName(vehicle_id)
    info['vehicle_name'] = is_success and vehicle_name or nil
    info['vehicle_display_name'] = is_success and vehicle_name or 'unnamed vehicle'
    local peer_name, is_success = server.getPlayerName(peer_id)
    info['peer_name'] = is_success and peer_name or nil
    info['peer_display_name'] = is_success and peer_name or 'script'

    local list = loadList()
    table.insert(list, info)
    while #list > 128 do
        table.remove(list, 1)
    end
    saveList(list)
end

function onTick(game_ticks)
    g_savedata['time'] = g_savedata['time'] + game_ticks

    if g_savedata['mark'] ~= nil then
        server.removeMapObject(-1, g_savedata['ui_id'])
        server.addMapObject(
            -1,
            g_savedata['ui_id'],
            0,
            2,
            g_savedata['mark']['x'],
            g_savedata['mark']['z'],
            0,
            0,
            -1,
            -1,
            g_savedata['mark']['vehicle_display_name'],
            0,
            string.format('spawned %s ago', formatTicks(g_savedata['time'] - g_savedata['mark']['spawn_time']))
        )
        for _, player in pairs(server.getPlayers()) do
            local text = g_savedata['mark']['vehicle_display_name']
            local peer_matrix, is_success = server.getPlayerPos(player['id'])
            if is_success then
                text = text .. '\n' .. formatDistance(
                    matrix.distance(
                        peer_matrix,
                        matrix.translation(g_savedata['mark']['x'], g_savedata['mark']['y'], g_savedata['mark']['z'])
                    )
                )
            end

            server.setPopup(
                -1,
                g_savedata['ui_id'],
                'Vehicle Mark',
                true,
                text,
                g_savedata['mark']['x'],
                g_savedata['mark']['y'],
                g_savedata['mark']['z'],
                0
            )
        end
    end
end

function onCreate(is_world_create)
    if g_savedata['version'] ~= 1 then
        g_savedata = {
            ['version'] = 1,
            ['time'] = 0,
            ['ui_id'] = server.getMapID(),
            ['list'] = {}
        }
    end
end

function getPlayerDisplayName(peer_id)
    local peer_name, is_success = server.getPlayerName(peer_id)
    if not is_success then
        return 'someone'
    end
    return peer_name
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
    if ticks < 60 then
        return string.format('%d', ticks) .. ' ticks'
    elseif ticks < 3600 then
        return string.format('%d', ticks // 60) .. ' seconds'
    elseif ticks < 216000 then
        return string.format('%d', ticks // 3600) .. ' minutes'
    elseif ticks < 5184000 then
        return string.format('%d', ticks // 216000) .. ' hours'
    end
    return string.format('%d', ticks // 5184000) .. ' days'
end

function formatDistance(dist)
    if dist < 1000 then
        return string.format('%dm', math.floor(dist))
    end
    return string.format('%.1fkm', dist/1000)
end
