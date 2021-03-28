g_cmd = '?vmark'
g_init = false
g_mark = {}
g_hide = {}
g_uim = nil

function onCustomCommand(full_message, user_peer_id, is_admin, is_auth, cmd, ...)
    if not g_init then
        init()
    end

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
        elseif args[1] == 'restore' then
            execRestore(user_peer_id, is_admin, is_auth, args)
        elseif args[1] == 'setlocal' then
            execSetLocal(user_peer_id, is_admin, is_auth, args)
        elseif args[1] == 'clearlocal' then
            execClearLocal(user_peer_id, is_admin, is_auth, args)
        elseif args[1] == 'hide' then
            execHide(user_peer_id, is_admin, is_auth, args)
        elseif args[1] == 'show' then
            execShow(user_peer_id, is_admin, is_auth, args)
        else
            server.announce(
                getAnnounceName(),
                string.format(
                    (
                        'error: undefined subcommand "%s"\n' ..
                        'see "?vmark help" for list of subcommands'
                    ),
                    args[1]
                ),
                user_peer_id
            )
        end
    end
end

function execHelp(user_peer_id, is_admin, is_auth, args)
    if #args == 2 and args[2] == 'list' then
        server.announce(
            getAnnounceName(),
            (
                g_cmd .. ' list [OPTIONS]\n' ..
                '\n' ..
                'OPTIONS:\n' ..
                '-num NUM\n' ..
                '-peer PEER_ID\n' ..
                '-name VEHICLE_NAME\n' ..
                '-sort ([!]id | [!]dist | [!]peer | [!]name)'
            ),
            user_peer_id
        )
        return
    end
    server.announce(
        getAnnounceName(),
        (
            g_cmd .. ' list [OPTIONS]\n' ..
            g_cmd .. ' set [VEHICLE_ID]\n' ..
            g_cmd .. ' clear VEHICLE_ID\n' ..
            g_cmd .. ' restore\n' ..
            g_cmd .. ' setlocal [VEHICLE_ID]\n' ..
            g_cmd .. ' clearlocal VEHICLE_ID\n' ..
            g_cmd .. ' hide\n' ..
            g_cmd .. ' show\n' ..
            g_cmd .. ' help [list]'
        ),
        user_peer_id
    )
end

function execList(user_peer_id, is_admin, is_auth, args)
    local num = 5
    local peer_id = nil
    local vehicle_name = ''
    local sort = 'id'
    for i = 2, #args, 2 do
        if args[i] == '-num' then
            if i + 1 > #args then
                server.announce(
                    getAnnounceName(),
                    'error: option -num requires parameter',
                    user_peer_id
                )
                return
            end
            num = tonumber(args[i + 1])
            if num == fail or num < 0 or math.floor(num) ~= num then
                server.announce(
                    getAnnounceName(),
                    string.format('error: option -num got invalid parameter "%s"', args[i + 1]),
                    user_peer_id
                )
                return
            end
        elseif args[i] == '-peer' then
            if i + 1 > #args then
                server.announce(
                    getAnnounceName(),
                    'error: option -peer requires parameter',
                    user_peer_id
                )
                return
            end
            peer_id = tonumber(args[i + 1])
            if peer_id == fail or math.floor(peer_id) ~= peer_id then
                server.announce(
                    getAnnounceName(),
                    string.format('error: option -peer got invalid parameter "%s"', args[i + 1]),
                    user_peer_id
                )
                return
            end
        elseif args[i] == '-name' then
            if i + 1 > #args then
                server.announce(
                    getAnnounceName(),
                    'error: option -name requires paramter',
                    user_peer_id
                )
                return
            end
            vehicle_name = args[i + 1]
        elseif args[i] == '-sort' then
            if i + 1 > #args then
                server.announce(
                    getAnnounceName(),
                    'error: option -sort requires parameter',
                    user_peer_id
                )
                return
            end
            sort = args[i + 1]
            if sort ~= 'id' and sort ~= '!id' and
                sort ~= 'dist' and sort ~= '!dist' and
                sort ~= 'peer' and sort ~= '!peer' and
                sort ~= 'name' and sort ~= '!name' then
                server.announce(
                    getAnnounceName(),
                    string.format(
                        (
                            'error: option -sort got undefined sort key "%s"\n' ..
                            'available sort keys are [!]id, [!]dist, [!]peer, [!]name'
                        ),
                        sort
                    ),
                    user_peer_id
                )
                return
            end
        elseif args[i] == '-help' then
            return execHelp(user_peer_id, is_admin, is_auth, {'help', 'list'})
        else
            server.announce(
                getAnnounceName(),
                string.format(
                    (
                        'error: invalid argument "%s"\n' ..
                        'see "?vmark help list" for list of options'
                    ),
                    args[i]
                ),
                user_peer_id
            )
            return
        end
    end

    local function getVehicleDist(info)
        local peer_matrix, is_success_peer = server.getPlayerPos(user_peer_id)
        local vehicle_matrix, is_success_vehicle = server.getVehiclePos(info['vehicle_id'])
        if not is_success_peer or not is_success_vehicle then
            return nil
        end
        return matrix.distance(peer_matrix, vehicle_matrix)
    end

    local function filterVehicleList(list)
        local new = {}
        for _, info in ipairs(list) do
            local peer_id_matched = peer_id == nil or info['peer_id'] == peer_id
            local vehicle_name_matched = string.find(info['vehicle_display_name'], vehicle_name, 1, true) ~= fail
            if peer_id_matched and vehicle_name_matched then
                table.insert(new, info)
            end
        end
        return new
    end

    local function compareVehicleInfo(info_1, info_2)
        local value_1 = nil
        local value_2 = nil
        if sort == 'id' then
            value_1 = info_1['vehicle_id']
            value_2 = info_2['vehicle_id']
        elseif sort == '!id' then
            value_1 = info_2['vehicle_id']
            value_2 = info_1['vehicle_id']
        elseif sort == 'dist' then
            value_1 = getVehicleDist(info_2)
            value_2 = getVehicleDist(info_1)
        elseif sort == '!dist' then
            value_1 = getVehicleDist(info_1)
            value_2 = getVehicleDist(info_2)
        elseif sort == 'peer' then
            value_1 = info_1['peer_id']
            value_2 = info_2['peer_id']
        elseif sort == '!peer' then
            value_1 = info_2['peer_id']
            value_2 = info_1['peer_id']
        elseif sort == 'name' then
            value_1 = info_1['vehicle_name']
            value_2 = info_2['vehicle_name']
        elseif sort == '!name' then
            value_1 = info_2['vehicle_name']
            value_2 = info_1['vehicle_name']
        end

        if value_1 == value_2 then
            return info_1['vehicle_id'] < info_2['vehicle_id']
        elseif value_1 == nil then
            return false
        elseif value_2 == nil then
            return true
        end
        return value_1 < value_2
    end

    local function formatMessage(info)
        local mark = '-'
        if g_mark[user_peer_id][info['vehicle_id']] then
            mark = 'L'
        elseif info['mark'] then
            mark = 'G'
        end

        local dist = getVehicleDist(info)
        if dist ~= nil then
            dist = string.format('%.1fkm', dist/1000)
        else
            dist = '???km'
        end

        local peer_display_name = info['peer_display_name']
        if info['peer_id'] >= 0 then
            peer_display_name = string.format('%s#%d', info['peer_display_name'], info['peer_id'])
        end

        return string.format(
            '%s %3d %s %s %s "%s"',
            mark,
            info['vehicle_id'],
            formatTicks(g_savedata['time'] - info['spawn_time']),
            dist,
            peer_display_name,
            info['vehicle_display_name']
        )
    end

    local list = copyTable(g_savedata['list'])
    list = filterVehicleList(list)
    table.sort(list, compareVehicleInfo)

    local msg = {}
    for i = #list, 1, -1 do
        if g_mark[user_peer_id][list[i]['vehicle_id']] then
            table.insert(msg, formatMessage(list[i]))
        end
    end
    for i = #list, 1, -1 do
        if list[i]['mark'] and not g_mark[user_peer_id][list[i]['vehicle_id']] then
            table.insert(msg, formatMessage(list[i]))
        end
    end
    for i = #list, 1, -1 do
        if #msg >= num then
            break
        end
        if not list[i]['mark'] and not g_mark[user_peer_id][list[i]['vehicle_id']] then
            table.insert(msg, formatMessage(list[i]))
        end
    end
    msg = reverseTable(msg)
    msg = table.concat(msg, '\n')
    server.announce(getAnnounceName(), msg, user_peer_id)
end

function execSet(user_peer_id, is_admin, is_auth, args)
    if #args > 2 then
        server.announce(
            getAnnounceName(),
            'error: too many arguments',
            user_peer_id
        )
        return
    end

    local info = nil
    if #args == 2 then
        local vehicle_id = tonumber(args[2])
        if vehicle_id == fail or vehicle_id < 0 or math.floor(vehicle_id) ~= vehicle_id then
            server.announce(
                getAnnounceName(),
                string.format('error: got invalid vehicle_id "%s"', args[2]),
                user_peer_id
            )
            return
        end
        info = getVehicleInfo(vehicle_id)
        if info == nil then
            server.announce(
                getAnnounceName(),
                string.format('error: got unrecorded vehicle_id "%d"', vehicle_id),
                user_peer_id
            )
            return
        end
    else
        if #g_savedata['list'] <= 0 then
            server.announce(
                getAnnounceName(),
                'error: no markable vehicles exist',
                user_peer_id
            )
            return
        end
        info = g_savedata['list'][#g_savedata['list']]
    end
    info['mark'] = true

    server.announce(
        getAnnounceName(),
        string.format(
            (
                '%s set global marker on %s\n' ..
                '(vehicle_id = %d)'
            ),
            getPlayerDisplayName(user_peer_id),
            info['vehicle_display_name'],
            info['vehicle_id']
        )
    )
end

function execClear(user_peer_id, is_admin, is_auth, args)
    if #args < 2 then
        server.announce(
            getAnnounceName(),
            'error: no vehicle_id specified',
            user_peer_id
        )
        return
    end
    if #args > 2 then
        server.announce(
            getAnnounceName(),
            'error: too many arguments',
            user_peer_id
        )
        return
    end

    local vehicle_id = tonumber(args[2])
    if vehicle_id == fail or vehicle_id < -1 or math.floor(vehicle_id) ~= vehicle_id then
        server.announce(
            getAnnounceName(),
            string.format('error: got invalid vehicle_id "%s"', args[2]),
            user_peer_id
        )
        return
    end

    if vehicle_id == -1 then
        local bak = {}
        for _, info in ipairs(g_savedata['list']) do
            if info['mark'] then
                table.insert(bak, info['vehicle_id'])
            end
        end
        if #bak > 0 then
            g_savedata['bak'] = bak
        end

        for _, info in ipairs(g_savedata['list']) do
            info['mark'] = false
        end
        server.announce(
            getAnnounceName(),
            string.format(
                (
                    '%s cleared all global markers\n' ..
                    'use "?vmark restore" to undo'
                ),
                getPlayerDisplayName(user_peer_id)
            )
        )
    else
        local info = getVehicleInfo(vehicle_id)
        if info == nil then
            server.announce(
                getAnnounceName(),
                string.format('error: got unrecorded vehicle_id "%d"', vehicle_id),
                user_peer_id
            )
            return
        end
        info['mark'] = false

        server.announce(
            getAnnounceName(),
            string.format(
                (
                    '%s cleared global marker on %s\n' ..
                    '(vehicle_id = %d)'
                ),
                getPlayerDisplayName(user_peer_id),
                info['vehicle_display_name'],
                info['vehicle_id']
            )
        )
    end
end

function execRestore(user_peer_id, is_admin, is_auth, args)
    if #args > 1 then
        server.announce(
            getAnnounceName(),
            'error: extra arguments',
            user_peer_id
        )
        return
    end
    for _, vehicle_id in ipairs(g_savedata['bak']) do
        local info = getVehicleInfo(vehicle_id)
        if info ~= nil then
            info['mark'] = true
        end
    end
    server.announce(
        getAnnounceName(),
        string.format('%s restored global markers', getPlayerDisplayName(user_peer_id))
    )
end

function execSetLocal(user_peer_id, is_admin, is_auth, args)
    if #args > 2 then
        server.announce(
            getAnnounceName(),
            'error: too many arguments',
            user_peer_id
        )
        return
    end

    local info = nil
    if #args == 2 then
        local vehicle_id = tonumber(args[2])
        if vehicle_id == fail or vehicle_id < 0 or math.floor(vehicle_id) ~= vehicle_id then
            server.announce(
                getAnnounceName(),
                string.format('error: got invalid vehicle_id "%s"', args[2]),
                user_peer_id
            )
            return
        end
        info = getVehicleInfo(vehicle_id)
        if info == nil then
            server.announce(
                getAnnounceName(),
                string.format('error: got unrecorded vehicle_id "%d"', vehicle_id),
                user_peer_id
            )
            return
        end
    else
        if #g_savedata['list'] <= 0 then
            server.announce(
                getAnnounceName(),
                'error: no markable vehicles exist',
                user_peer_id
            )
            return
        end
        info = g_savedata['list'][#g_savedata['list']]
    end
    g_mark[user_peer_id][info['vehicle_id']] = true

    server.announce(
        getAnnounceName(),
        string.format(
            (
                '%s set local marker on %s\n' ..
                '(vehicle_id = %d)'
            ),
            getPlayerDisplayName(user_peer_id),
            info['vehicle_display_name'],
            info['vehicle_id']
        ),
        user_peer_id
    )
end

function execClearLocal(user_peer_id, is_admin, is_auth, args)
    if #args < 2 then
        server.announce(
            getAnnounceName(),
            'error: no vehicle_id specified',
            user_peer_id
        )
        return
    end
    if #args > 2 then
        server.announce(
            getAnnounceName(),
            'error: too many arguments',
            user_peer_id
        )
        return
    end

    local vehicle_id = tonumber(args[2])
    if vehicle_id == fail or vehicle_id < -1 or math.floor(vehicle_id) ~= vehicle_id then
        server.announce(
            getAnnounceName(),
            string.format('error: got invalid vehicle_id "%s"', args[2]),
            user_peer_id
        )
        return
    end

    if vehicle_id == -1 then
        g_mark[user_peer_id] = {}
        server.announce(
            getAnnounceName(),
            string.format('%s cleared all local markers', getPlayerDisplayName(user_peer_id)),
            user_peer_id
        )
    else
        local info = getVehicleInfo(vehicle_id)
        if info == nil then
            server.announce(
                getAnnounceName(),
                string.format('error: got unrecorded vehicle_id "%d"', vehicle_id),
                user_peer_id
            )
            return
        end
        g_mark[user_peer_id][info['vehicle_id']] = nil

        server.announce(
            getAnnounceName(),
            string.format(
                (
                    '%s cleared local marker on %s\n' ..
                    '(vehicle_id = %d)'
                ),
                getPlayerDisplayName(user_peer_id),
                info['vehicle_display_name'],
                info['vehicle_id']
            ),
            user_peer_id
        )
    end
end

function execHide(user_peer_id, is_admin, is_auth, args)
    if #args > 1 then
        server.announce(
            getAnnounceName(),
            'error: extra arguments',
            user_peer_id
        )
        return
    end
    g_hide[user_peer_id] = true
    server.announce(
        getAnnounceName(),
        'markers are now invisible',
        user_peer_id
    )
end

function execShow(user_peer_id, is_admin, is_auth, args)
    if #args > 1 then
        server.announce(
            getAnnounceName(),
            'error: extra arguments',
            user_peer_id
        )
        return
    end
    g_hide[user_peer_id] = nil
    server.announce(
        getAnnounceName(),
        'markers are now visible',
        user_peer_id
    )
end

function onVehicleSpawn(vehicle_id, peer_id, x, y, z, cost)
    if not g_init then
        init()
    end

    local info = {
        ['spawn_time'] = g_savedata['time'],
        ['vehicle_id'] = vehicle_id,
        ['peer_id'] = peer_id,
        ['ui_id'] = server.getMapID(),
        ['mark'] = false
    }
    local vehicle_name, is_success = server.getVehicleName(vehicle_id)
    info['vehicle_name'] = is_success and vehicle_name or nil
    info['vehicle_display_name'] = is_success and vehicle_name or '{unnamed vehicle}'
    local peer_name, is_success = server.getPlayerName(peer_id)
    info['peer_name'] = is_success and peer_name or nil
    info['peer_display_name'] = is_success and peer_name or '{script}'
    table.insert(g_savedata['list'], info)
end

function onTick(game_ticks)
    if not g_init then
        init()
    end

    g_savedata['time'] = g_savedata['time'] + game_ticks
    local peer_list = server.getPlayers()

    for _, peer in pairs(peer_list) do
        if g_mark[peer['id']] == nil then
            g_mark[peer['id']] = {}
        end
    end
    for peer_id, _ in pairs(g_mark) do
        if not getPlayerExists(peer_id) then
            g_mark[peer_id] = nil
        end
    end

    local function onVehicleExists(info)
        local vehicle_matrix, _
        local vehicle_x, vehicle_y, vehicle_z
        for _, peer in pairs(peer_list) do
            if (info['mark'] or g_mark[peer['id']][info['vehicle_id']]) and (not g_hide[peer['id']]) then
                if vehicle_matrix == nil then
                    vehicle_matrix, _ = server.getVehiclePos(info['vehicle_id'])
                    vehicle_x, vehicle_y, vehicle_z = matrix.position(vehicle_matrix)
                end
                local popup_text = info['vehicle_display_name']
                local peer_matrix, is_success = server.getPlayerPos(peer['id'])
                if is_success then
                    popup_text = popup_text .. '\n' .. formatDistance(matrix.distance(peer_matrix, vehicle_matrix))
                end

                g_uim.setMapObject(peer['id'], info['ui_id'], 0, 2, vehicle_x, vehicle_z, 0, 0, -1, -1, info['vehicle_display_name'], 0, '')
                g_uim.setPopup(peer['id'], info['ui_id'], getAnnounceName(), true, popup_text, vehicle_x, vehicle_y, vehicle_z, 0)
            end
        end
    end

    local function onVehicleDespawn(info)
        for peer_id, _ in pairs(g_mark) do
            g_mark[peer_id][info['vehicle_id']] = nil
        end
    end

    local list = {}
    for _, info in ipairs(g_savedata['list']) do
        local vehicle_exists = getVehicleExists(info['vehicle_id'])
        if vehicle_exists then
            table.insert(list, info)
            onVehicleExists(info)
        else
            onVehicleDespawn(info)
        end
    end

    g_savedata['list'] = list
    g_uim.flush()
end

function onCreate(is_world_create)
    if not g_init then
        init()
    end
end

function onPlayerJoin(steam_id, name, peer_id, is_admin, is_auth)
    if not g_init then
        init()
    end

    g_uim.onPlayerJoin(steam_id, name, peer_id, is_admin, is_auth)
end

function onPlayerLeave(steam_id, name, peer_id, is_admin, is_auth)
    if not g_init then
        init()
    end

    g_hide[peer_id] = nil
    g_uim.onPlayerLeave(steam_id, name, peer_id, is_admin, is_auth)
end

function init()
    g_init = true
    if g_savedata['version'] ~= 16 then
        g_savedata = {
            ['version'] = 16,
            ['time'] = 0,
            ['list'] = {},
            ['bak'] = {},
        }
    end

    g_uim = buildUIManager()
    for _, info in ipairs(g_savedata['list']) do
        server.removeMapObject(-1, info['ui_id'])
        server.removePopup(-1, info['ui_id'])
    end
end

function buildUIManager()
    local uim = {
        ['_map_object_1'] = {},
        ['_map_object_2'] = {},
        ['_popup_1'] = {},
        ['_popup_2'] = {}
    }

    function uim.setMapObject(peer_id, ui_id, position_type, marker_type, x, z, parent_local_x, parent_local_z, vehicle_id, object_id, label, radius, hover_label)
        for _, peer_id in pairs(getPeerIDList(peer_id)) do
            local key = string.format('%d,%d', peer_id, ui_id)
            uim['_map_object_2'][key] = {
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

    function uim.setPopup(peer_id, ui_id, name, is_show, text, x, y, z, render_distance)
        for _, peer_id in pairs(getPeerIDList(peer_id)) do
            local key = string.format('%d,%d', peer_id, ui_id)
            uim['_popup_2'][key] = {
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

    function uim.onPlayerJoin(steam_id, name, peer_id, is_admin, is_auth)
        for key, map_object in pairs(uim['_map_object_1']) do
            if map_object['peer_id'] == peer_id then
                server.removeMapObject(map_object['peer_id'], map_object['ui_id'])
                uim['_map_object_1'][key] = nil
            end
        end

        for key, popup in pairs(uim['_popup_1']) do
            if popup['peer_id'] == peer_id then
                server.removePopup(popup['peer_id'], popup['ui_id'])
                uim['_popup_1'][key] = nil
            end
        end
    end

    function uim.onPlayerLeave(steam_id, name, peer_id, is_admin, is_auth)
        for key, map_object in pairs(uim['_map_object_1']) do
            if map_object['peer_id'] == peer_id then
                uim['_map_object_1'][key] = nil
            end
        end
        for key, map_object in pairs(uim['_map_object_2']) do
            if map_object['peer_id'] == peer_id then
                uim['_map_object_2'][key] = nil
            end
        end
        for key, popup in pairs(uim['_popup_1']) do
            if popup['peer_id'] == peer_id then
                uim['_popup_1'][key] = nil
            end
        end
        for key, popup in pairs(uim['_popup_2']) do
            if popup['peer_id'] == peer_id then
                uim['_popup_2'][key] = nil
            end
        end
    end

    function uim.flush()
        uim.flushMapObject()
        uim.flushPopup()
    end

    function uim.flushMapObject()
        for key, map_object in pairs(uim['_map_object_1']) do
            if uim['_map_object_2'][key] == nil then
                server.removeMapObject(map_object['peer_id'], map_object['ui_id'])
            end
        end

        for key, map_object_2 in pairs(uim['_map_object_2']) do
            local map_object_1 = uim['_map_object_1'][key]
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

        uim['_map_object_1'] = uim['_map_object_2']
        uim['_map_object_2'] = {}
    end

    function uim.flushPopup()
        for key, popup in pairs(uim['_popup_1']) do
            if uim['_popup_2'][key] == nil then
                server.removePopup(popup['peer_id'], popup['ui_id'])
            end
        end

        for key, popup_2 in pairs(uim['_popup_2']) do
            local popup_1 = uim['_popup_1'][key]
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

        uim['_popup_1'] = uim['_popup_2']
        uim['_popup_2'] = {}
    end

    return uim
end

function getAnnounceName()
    local addon_index = server.getAddonIndex()
    local addon_data = server.getAddonData(addon_index)
    return string.format('[%s]', addon_data['name'])
end

function getPlayerExists(peer_id)
    local _, is_success = server.getPlayerName(peer_id)
    return is_success
end

function getPlayerDisplayName(peer_id)
    local peer_name, is_success = server.getPlayerName(peer_id)
    if not is_success then
        return '{someone}'
    end
    return peer_name
end

function getPeerIDList(peer_id)
    local peer_id_list = {}
    if peer_id < 0 then
        for _, peer in pairs(server.getPlayers()) do
            table.insert(peer_id_list, peer['id'])
        end
    else
        table.insert(peer_id_list, peer_id)
    end
    return peer_id_list
end

function getVehicleExists(vehicle_id)
    local _, is_success = server.getVehicleFireCount(vehicle_id)
    return is_success
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

function reverseTable(tbl)
    local new = {}
    for i, value in ipairs(tbl) do
        new[#tbl - i + 1] = value
    end
    return new
end
