g_cmd = '?vmark'
g_ui_cache = nil

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
        g_cmd .. ' list [NUM]\n' ..
        g_cmd .. ' set [VEHICLE_ID]\n' ..
        g_cmd .. ' clear VEHICLE_ID',
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
    for i = math.max(1, #g_savedata['list'] - num + 1), #g_savedata['list'] do
        table.insert(msg, string.format(
            '%s %3d %s @%s "%s"',
            g_savedata['list'][i]['mark'] and 'M' or '-',
            g_savedata['list'][i]['vehicle_id'],
            formatTicks(g_savedata['time'] - g_savedata['list'][i]['spawn_time']),
            g_savedata['list'][i]['peer_name'],
            g_savedata['list'][i]['vehicle_name']
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

    local info = nil
    if #args == 2 then
        local vehicle_id = tonumber(args[2])
        if vehicle_id == fail or vehicle_id < 0 or math.floor(vehicle_id) ~= vehicle_id then
            server.announce(getAnnounceName(), string.format('error: not a vehicle_id: "%s"', args[2]), user_peer_id)
            return
        end
        info = getVehicleInfo(vehicle_id)
        if info == nil then
            server.announce(getAnnounceName(), string.format('error: unknown vehicle: %d', vehicle_id), user_peer_id)
            return
        end
    else
        if #g_savedata['list'] <= 0 then
            server.announce(getAnnounceName(), 'error: no vehicle spawned yet', user_peer_id)
            return
        end
        info = g_savedata['list'][#g_savedata['list']]
    end
    info['mark'] = true
    server.announce(getAnnounceName(), string.format('%s marked %s', getPlayerDisplayName(user_peer_id), info['vehicle_name']))
end

function execClear(user_peer_id, is_admin, is_auth, args)
    if #args ~= 2 then
        server.announce(getAnnounceName(), 'error: missing or extra arguments', user_peer_id)
        return
    end

    local vehicle_id = tonumber(args[2])
    if vehicle_id == fail or vehicle_id < -1 or math.floor(vehicle_id) ~= vehicle_id then
        server.announce(getAnnounceName(), string.format('error: not a vehicle_id: "%s"', args[2]), user_peer_id)
        return
    end

    if vehicle_id == -1 then
        for _, info in pairs(g_savedata['list']) do
            info['mark'] = false
        end
        server.announce(getAnnounceName(), string.format('%s cleared all marks', getPlayerDisplayName(user_peer_id)))
    else
        local info = getVehicleInfo(vehicle_id)
        if info == nil then
            server.announce(getAnnounceName(), string.format('error: unknown vehicle: %d', vehicle_id), user_peer_id)
            return
        end
        info['mark'] = false
        server.announce(getAnnounceName(), string.format('%s cleared mark on %s', getPlayerDisplayName(user_peer_id), info['vehicle_name']))
    end
end

function onVehicleSpawn(vehicle_id, peer_id, x, y, z, cost)
    local info = {
        ['spawn_time'] = g_savedata['time'],
        ['vehicle_id'] = vehicle_id,
        ['ui_id'] = server.getMapID(),
        ['mark'] = false
    }
    local vehicle_name, is_success = server.getVehicleName(vehicle_id)
    info['vehicle_name'] = is_success and vehicle_name or '[unnamed vehicle]'
    local peer_name, is_success = server.getPlayerName(peer_id)
    info['peer_name'] = is_success and peer_name or '[script]'
    table.insert(g_savedata['list'], info)
end

function onTick(game_ticks)
    g_savedata['time'] = g_savedata['time'] + game_ticks

    local list = {}
    for _, info in ipairs(g_savedata['list']) do
        local _, is_success = server.getVehiclePos(info['vehicle_id'])
        if is_success then
            table.insert(list, info)
        else
            g_ui_cache.removeMapObject(-1, info['ui_id'])
            g_ui_cache.removePopup(-1, info['ui_id'])
        end
    end
    g_savedata['list'] = list

    for _, info in pairs(g_savedata['list']) do
        if info['mark'] then
            local vehicle_matrix, _ = server.getVehiclePos(info['vehicle_id'])
            local vehicle_x, vehicle_y, vehicle_z = matrix.position(vehicle_matrix)
            g_ui_cache.removeMapObject(-1, info['ui_id'])
            g_ui_cache.setMapObject(-1, info['ui_id'], 0, 2, vehicle_x, vehicle_z, 0, 0, -1, -1, info['vehicle_name'], 0, '')
            for _, player in pairs(server.getPlayers()) do
                local text = info['vehicle_name']
                local peer_matrix, is_success = server.getPlayerPos(player['id'])
                if is_success then
                    text = text .. '\n' .. formatDistance(matrix.distance(peer_matrix, vehicle_matrix))
                end
                g_ui_cache.setPopup(player['id'], info['ui_id'], getAnnounceName(), true, text, vehicle_x, vehicle_y, vehicle_z, 0)
            end
        else
            g_ui_cache.removeMapObject(-1, info['ui_id'])
            g_ui_cache.removePopup(-1, info['ui_id'])
        end
    end

    g_ui_cache.flush()
end

function onCreate(is_world_create)
    if g_savedata['version'] ~= 10 then
        g_savedata = {
            ['version'] = 10,
            ['time'] = 0,
            ['list'] = {}
        }
    end

    g_ui_cache = buildUICache()
    for _, info in pairs(g_savedata['list']) do
        server.removeMapObject(-1, info['ui_id'])
        server.removePopup(-1, info['ui_id'])
    end
end

function onPlayerJoin(steam_id, name, peer_id, is_admin, is_auth)
    g_ui_cache.onPlayerJoin(steam_id, name, peer_id, is_admin, is_auth)
end

function onPlayerLeave(steam_id, name, peer_id, is_admin, is_auth)
    g_ui_cache.onPlayerLeave(steam_id, name, peer_id, is_admin, is_auth)
end

function buildUICache()
    local ui_cache = {
        ['_map_object_1'] = {},
        ['_map_object_2'] = {},
        ['_popup_1'] = {},
        ['_popup_2'] = {}
    }

    function ui_cache.setMapObject(peer_id, ui_id, position_type, marker_type, x, z, parent_local_x, parent_local_z, vehicle_id, object_id, label, radius, hover_label)
        for _, peer_id in pairs(getPeerIDList(peer_id)) do
            local key = string.format('%d,%d', peer_id, ui_id)
            ui_cache['_map_object_2'][key] = {
                ['peer_id'] = peer_id,
                ['ui_id'] = ui_id,
                ['position_type'] = position_type,
                ['marker_type'] = marker_type,
                ['x'] = x,
                ['z'] = z,
                ['parent_local_x'] = parent_local_x,
                ['parent_local_z'] = parent_local_z,
                ['vehicle_id'] = vehicle_id,
                ['object_id'] = object_id,
                ['label'] = label,
                ['radius'] = radius,
                ['hover_label'] = hover_label
            }
        end
    end

    function ui_cache.removeMapObject(peer_id, ui_id)
        if peer_id < 0 then
            for key, map_object in pairs(ui_cache['_map_object_2']) do
                if map_object['ui_id'] == ui_id then
                    ui_cache['_map_object_2'][key] = nil
                end
            end
        else
            local key = string.format('%d,%d', peer_id, ui_id)
            ui_cache['_map_object_2'][key] = nil
        end
    end

    function ui_cache.setPopup(peer_id, ui_id, name, is_show, text, x, y, z, render_distance)
        for _, peer_id in pairs(getPeerIDList(peer_id)) do
            local key = string.format('%d,%d', peer_id, ui_id)
            ui_cache['_popup_2'][key] = {
                ['peer_id'] = peer_id,
                ['ui_id'] = ui_id,
                ['name'] = name,
                ['is_show'] = is_show,
                ['text'] = text,
                ['x'] = x,
                ['y'] = y,
                ['z'] = z,
                ['render_distance'] = render_distance
            }
        end
    end

    function ui_cache.removePopup(peer_id, ui_id)
        if peer_id < 0 then
            for key, popup in pairs(ui_cache['_popup_2']) do
                if popup['ui_id'] == ui_id then
                    ui_cache['_popup_2'][key] = nil
                end
            end
        else
            local key = string.format('%d,%d', peer_id, ui_id)
            ui_cache['_popup_2'][key] = nil
        end
    end

    function ui_cache.onPlayerJoin(steam_id, name, peer_id, is_admin, is_auth)
        for key, map_object in pairs(ui_cache['_map_object_1']) do
            if map_object['peer_id'] == peer_id then
                server.removeMapObject(map_object['peer_id'], map_object['ui_id'])
                ui_cache['_map_object_1'][key] = nil
            end
        end

        for key, popup in pairs(ui_cache['_popup_1']) do
            if popup['peer_id'] == peer_id then
                server.removePopup(popup['peer_id'], popup['ui_id'])
                ui_cache['_popup_1'][key] = nil
            end
        end
    end

    function ui_cache.onPlayerLeave(steam_id, name, peer_id, is_admin, is_auth)
        for key, map_object in pairs(ui_cache['_map_object_1']) do
            if map_object['peer_id'] == peer_id then
                ui_cache['_map_object_1'][key] = nil
            end
        end
        for key, map_object in pairs(ui_cache['_map_object_2']) do
            if map_object['peer_id'] == peer_id then
                ui_cache['_map_object_2'][key] = nil
            end
        end
        for key, popup in pairs(ui_cache['_popup_1']) do
            if popup['peer_id'] == peer_id then
                ui_cache['_popup_1'][key] = nil
            end
        end
        for key, popup in pairs(ui_cache['_popup_2']) do
            if popup['peer_id'] == peer_id then
                ui_cache['_popup_2'][key] = nil
            end
        end
    end

    function ui_cache.flush()
        ui_cache.flushMapObject()
        ui_cache.flushPopup()
    end

    function ui_cache.flushMapObject()
        for key, map_object in pairs(ui_cache['_map_object_1']) do
            if ui_cache['_map_object_2'][key] == nil then
                server.removeMapObject(map_object['peer_id'], map_object['ui_id'])
            end
        end

        for key, map_object_2 in pairs(ui_cache['_map_object_2']) do
            local map_object_1 = ui_cache['_map_object_1'][key]
            if map_object_1 == nil or
                map_object_2['position_type'] ~= map_object_1['position_type'] or
                map_object_2['marker_type'] ~= map_object_1['marker_type'] or
                map_object_2['x'] ~= map_object_1['x'] or
                map_object_2['z'] ~= map_object_1['z'] or
                map_object_2['parent_local_x'] ~= map_object_1['parent_local_x'] or
                map_object_2['parent_local_z'] ~= map_object_1['parent_local_z'] or
                map_object_2['vehicle_id'] ~= map_object_1['vehicle_id'] or
                map_object_2['object_id'] ~= map_object_1['object_id'] or
                map_object_2['label'] ~= map_object_1['label'] or
                map_object_2['radius'] ~= map_object_1['radius'] or
                map_object_2['hover_label'] ~= map_object_1['hover_label'] then
                server.removeMapObject(map_object_2['peer_id'], map_object_2['ui_id'])
                server.addMapObject(
                    map_object_2['peer_id'],
                    map_object_2['ui_id'],
                    map_object_2['position_type'],
                    map_object_2['marker_type'],
                    map_object_2['x'],
                    map_object_2['z'],
                    map_object_2['parent_local_x'],
                    map_object_2['parent_local_z'],
                    map_object_2['vehicle_id'],
                    map_object_2['object_id'],
                    map_object_2['label'],
                    map_object_2['radius'],
                    map_object_2['hover_label']
                )
            end
        end

        ui_cache['_map_object_1'] = copyTable(ui_cache['_map_object_2'])
    end

    function ui_cache.flushPopup()
        for key, popup in pairs(ui_cache['_popup_1']) do
            if ui_cache['_popup_2'][key] == nil then
                server.removePopup(popup['peer_id'], popup['ui_id'])
            end
        end

        for key, popup_2 in pairs(ui_cache['_popup_2']) do
            local popup_1 = ui_cache['_popup_1'][key]
            if popup_1 == nil or
                popup_2['name'] ~= popup_1['name'] or
                popup_2['is_show'] ~= popup_1['is_show'] or
                popup_2['text'] ~= popup_1['text'] or
                popup_2['x'] ~= popup_1['x'] or
                popup_2['y'] ~= popup_1['y'] or
                popup_2['z'] ~= popup_1['z'] or
                popup_2['render_distance'] ~= popup_1['render_distance'] then
                server.setPopup(
                    popup_2['peer_id'],
                    popup_2['ui_id'],
                    popup_2['name'],
                    popup_2['is_show'],
                    popup_2['text'],
                    popup_2['x'],
                    popup_2['y'],
                    popup_2['z'],
                    popup_2['render_distance']
                )
            end
        end

        ui_cache['_popup_1'] = copyTable(ui_cache['_popup_2'])
    end

    return ui_cache
end

function getAnnounceName()
    local playlist_index = server.getPlaylistIndexCurrent()
    local playlist_data = server.getPlaylistData(playlist_index)
    return string.format('[%s]', playlist_data['name'])
end

function getPlayerExists(peer_id)
    local _, is_success = server.getPlayerName(peer_id)
    return is_success
end

function getPlayerDisplayName(peer_id)
    local peer_name, is_success = server.getPlayerName(peer_id)
    if not is_success then
        return '[someone]'
    end
    return peer_name
end

function getPeerIDList(peer_id)
    local peer_id_list = {}
    if peer_id < 0 then
        for _, player in pairs(server.getPlayers()) do
            table.insert(peer_id_list, player['id'])
        end
    else
        table.insert(peer_id_list, peer_id)
    end
    return peer_id_list
end

function getVehicleInfo(vehicle_id)
    for _, info in ipairs(g_savedata['list']) do
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

function copyTable(tbl)
    local new = {}
    for key, value in pairs(tbl) do
        new[key] = value
    end
    return new
end
