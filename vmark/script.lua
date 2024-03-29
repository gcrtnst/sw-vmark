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
        elseif args[1] == 'set' or args[1] == 'setlocal' then
            execSet(user_peer_id, is_admin, is_auth, args)
        elseif args[1] == 'clear' or args[1] == 'clearlocal' then
            execClear(user_peer_id, is_admin, is_auth, args)
        elseif args[1] == 'restore' then
            execRestore(user_peer_id, is_admin, is_auth, args)
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
            g_cmd .. ' clear [VEHICLE_ID]\n' ..
            g_cmd .. ' restore\n' ..
            g_cmd .. ' setlocal [VEHICLE_ID]\n' ..
            g_cmd .. ' clearlocal [VEHICLE_ID]\n' ..
            g_cmd .. ' hide\n' ..
            g_cmd .. ' show\n' ..
            g_cmd .. ' help [list]'
        ),
        user_peer_id
    )
end

function execList(user_peer_id, is_admin, is_auth, args)
    local num = 5
    local owner = nil
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
            local peer_id = tonumber(args[i + 1])
            if peer_id == fail or math.floor(peer_id) ~= peer_id then
                server.announce(
                    getAnnounceName(),
                    string.format('error: option -peer got invalid parameter "%s"', args[i + 1]),
                    user_peer_id
                )
                return
            end
            owner = getOwner(peer_id)
            if owner == nil then
                server.announce(
                    getAnnounceName(),
                    string.format('error: option -peer got unassigned peer_id "%s"', peer_id),
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

    local function getPeerSortValue(owner)
        local peer_id = getOwnerPeerID(owner)
        if peer_id == nil then
            return -1
        elseif peer_id < 0 then
            return -2
        end
        return peer_id
    end

    local function filterVehicleList(list)
        local new = {}
        for _, info in pairs(list) do
            local owner_matched = owner == nil or getOwnerEqual(info['owner'], owner)
            local vehicle_name_matched = string.find(info['vehicle_display_name'], vehicle_name, 1, true) ~= fail
            if owner_matched and vehicle_name_matched then
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
            value_1 = getPeerSortValue(info_1['owner'])
            value_2 = getPeerSortValue(info_2['owner'])
        elseif sort == '!peer' then
            value_1 = getPeerSortValue(info_2['owner'])
            value_2 = getPeerSortValue(info_1['owner'])
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
        local dist = getVehicleDist(info)
        if dist ~= nil then
            dist = string.format('%.1fkm', dist/1000)
        else
            dist = '???km'
        end

        return string.format(
            '%s %3d %s %s %s "%s"',
            getMarker(user_peer_id, info['vehicle_id']),
            info['vehicle_id'],
            formatTicks(g_savedata['time'] - info['spawn_time']),
            dist,
            getOwnerDisplayNameAndID(info['owner']),
            info['vehicle_display_name']
        )
    end

    cleanVehicleDB()
    cleanMarkerDB()
    local list = getVehicleList()
    list = filterVehicleList(list)
    table.sort(list, compareVehicleInfo)

    local msg = {}
    for i = #list, 1, -1 do
        if getMarker(user_peer_id, list[i]['vehicle_id']) == 'L' then
            table.insert(msg, formatMessage(list[i]))
        end
    end
    for i = #list, 1, -1 do
        if getMarker(user_peer_id, list[i]['vehicle_id']) == 'G' then
            table.insert(msg, formatMessage(list[i]))
        end
    end
    for i = #list, 1, -1 do
        if #msg >= num then
            break
        end
        if getMarker(user_peer_id, list[i]['vehicle_id']) == '-' then
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

    cleanVehicleDB()
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
        info = g_savedata['vehicle_db'][vehicle_id]
        if info == nil then
            server.announce(
                getAnnounceName(),
                string.format('error: got unrecorded vehicle_id "%d"', vehicle_id),
                user_peer_id
            )
            return
        end
    else
        info = getLastSpawnedVehicleInfo()
        if info == nil then
            server.announce(
                getAnnounceName(),
                'error: no markable vehicles exist',
                user_peer_id
            )
            return
        end
    end

    if args[1] == 'set' then
        setMarker(-1, info['vehicle_id'])
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
    else
        setMarker(user_peer_id, info['vehicle_id'])
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
end

function execClear(user_peer_id, is_admin, is_auth, args)
    if #args > 2 then
        server.announce(
            getAnnounceName(),
            'error: too many arguments',
            user_peer_id
        )
        return
    end

    local vehicle_id = -1
    if #args >= 2 then
        vehicle_id = tonumber(args[2])
        if vehicle_id == fail or math.floor(vehicle_id) ~= vehicle_id then
            server.announce(
                getAnnounceName(),
                string.format('error: got invalid vehicle_id "%s"', args[2]),
                user_peer_id
            )
            return
        end
    end

    if vehicle_id < 0 then
        if args[1] == 'clear' then
            cleanMarkerDB()
            local bak = getMarkerTable(-1)
            if next(bak) ~= nil then
                g_savedata['bak'] = bak
            end

            removeMarker(-1, -1)
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
            removeMarker(user_peer_id, -1)
            server.announce(
                getAnnounceName(),
                string.format('%s cleared all local markers', getPlayerDisplayName(user_peer_id)),
                user_peer_id
            )
        end
    else
        cleanVehicleDB()
        local info = g_savedata['vehicle_db'][vehicle_id]
        if info == nil then
            server.announce(
                getAnnounceName(),
                string.format('error: got unrecorded vehicle_id "%d"', vehicle_id),
                user_peer_id
            )
            return
        end

        if args[1] == 'clear' then
            removeMarker(-1, info['vehicle_id'])
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
        else
            removeMarker(user_peer_id, info['vehicle_id'])
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
    setMarkerTable(-1, g_savedata['bak'])
    server.announce(
        getAnnounceName(),
        string.format('%s restored global markers', getPlayerDisplayName(user_peer_id))
    )
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
        ['owner'] = getOwner(peer_id),
        ['ui_id'] = server.getMapID(),
    }

    local vehicle_name = ""
    local is_success = false
    if server.getVehicleName ~= nil then
        vehicle_name, is_success = server.getVehicleName(vehicle_id)
    end
    info['vehicle_name'] = is_success and vehicle_name or nil
    info['vehicle_display_name'] = is_success and vehicle_name or '{unnamed vehicle}'

    cleanVehicleDB()
    g_savedata['vehicle_db'][vehicle_id] = info
end

function onTick(game_ticks)
    if not g_init then
        init()
    end
    g_savedata['time'] = g_savedata['time'] + game_ticks

    local peer_id_tbl = getPeerIDTable()
    for peer_id, _ in pairs(g_hide) do
        if peer_id_tbl[peer_id] == nil then
            g_hide[peer_id] = nil
        end
    end
    for peer_id, _ in pairs(g_hide) do
        peer_id_tbl[peer_id] = nil
    end

    cleanMarkerDB()
    for peer_id, _ in pairs(peer_id_tbl) do
        for vehicle_id, _ in pairs(getMarkerTable(-1, peer_id)) do
            local info = g_savedata['vehicle_db'][vehicle_id]
            local vehicle_matrix, _ = server.getVehiclePos(vehicle_id)
            local vehicle_x, vehicle_y, vehicle_z = matrix.position(vehicle_matrix)
            local popup_text = info['vehicle_display_name']
            local peer_matrix, is_success = server.getPlayerPos(peer_id)
            if is_success then
                popup_text = popup_text .. '\n' .. formatDistance(matrix.distance(peer_matrix, vehicle_matrix))
            end
            g_uim.setMapObject(peer_id, info['ui_id'], 0, 2, vehicle_x, vehicle_z, 0, 0, -1, -1, info['vehicle_display_name'], 0, '')
            g_uim.setPopup(peer_id, info['ui_id'], getAnnounceName(), true, popup_text, vehicle_x, vehicle_y, vehicle_z, 0)
        end
    end
    g_uim.flush()
end

function onPlayerJoin(steam_id, name, peer_id, is_admin, is_auth)
    if not g_init then
        init()
    end
    g_uim.onPlayerJoin(steam_id, name, peer_id, is_admin, is_auth)

    local owner = getOwner(peer_id)
    for _, info in pairs(g_savedata['vehicle_db']) do
        if getOwnerEqual(info['owner'], owner) then
            info['owner'] = owner
        end
    end
end

function init()
    g_init = true
    initSavedata()
    initUIManager()
end

function initSavedata()
    if g_savedata['version'] == 16 then
        g_savedata['version'] = 17
        for _, info in pairs(g_savedata['list']) do
            info['owner'] = getOwner(info['peer_id'] >= 0 and 0 or -1)
            info['peer_id'] = nil
            info['peer_name'] = nil
            info['peer_display_name'] = nil
        end
    end

    if g_savedata['version'] == 17 then
        g_savedata['version'] = 18

        local bak = {}
        for _, vehicle_id in pairs(g_savedata['bak']) do
            bak[vehicle_id] = true
        end
        g_savedata['bak'] = bak

        g_savedata['mark'] = {}
        for _, info in pairs(g_savedata['list']) do
            if info['mark'] then
                g_savedata['mark'][info['vehicle_id']] = true
            end
            info['mark'] = nil
        end

        g_savedata['vehicle_db'] = {}
        for _, info in pairs(g_savedata['list']) do
            g_savedata['vehicle_db'][info['vehicle_id']] = info
        end
        g_savedata['list'] = nil
    end

    if g_savedata['version'] ~= 18 then
        g_savedata = {
            ['version'] = 18,
            ['vehicle_db'] = {},
            ['mark'] = {},
            ['bak'] = {},
            ['time'] = 0,
        }
    end
end

function initUIManager()
    g_uim = buildUIManager()
    for _, info in pairs(g_savedata['vehicle_db']) do
        server.removeMapObject(-1, info['ui_id'])
        server.removePopup(-1, info['ui_id'])
    end
end

function cleanMarkerDB()
    for vehicle_id, _ in pairs(g_savedata['mark']) do
        if not getVehicleExists(vehicle_id) or g_savedata['vehicle_db'][vehicle_id] == nil then
            g_savedata['mark'][vehicle_id] = nil
        end
    end
    for peer_id, _ in pairs(g_mark) do
        if (next(g_mark[peer_id]) == nil) or (not getPlayerExists(peer_id)) then
            g_mark[peer_id] = nil
        else
            for vehicle_id, _ in pairs(g_mark[peer_id]) do
                if not getVehicleExists(vehicle_id) or g_savedata['vehicle_db'][vehicle_id] == nil then
                    g_mark[peer_id][vehicle_id] = nil
                end
            end
        end
    end
end

function getMarkerTable(...)
    local mark = {}
    for _, peer_id in pairs({...}) do
        if peer_id < 0 then
            for vehicle_id, _ in pairs(g_savedata['mark']) do
                mark[vehicle_id] = true
            end
        elseif g_mark[peer_id] ~= nil then
            for vehicle_id, _ in pairs(g_mark[peer_id]) do
                mark[vehicle_id] = true
            end
        end
    end
    return mark
end

function setMarkerTable(peer_id, mark)
    for vehicle_id, _ in pairs(mark) do
        setMarker(peer_id, vehicle_id)
    end
end

function getMarker(peer_id, vehicle_id)
    if peer_id >= 0 and g_mark[peer_id] ~= nil and g_mark[peer_id][vehicle_id] then
        return 'L'
    elseif g_savedata['mark'][vehicle_id] then
        return 'G'
    end
    return '-'
end

function setMarker(peer_id, vehicle_id)
    if peer_id < 0 then
        g_savedata['mark'][vehicle_id] = true
        return
    end
    if g_mark[peer_id] == nil then
        g_mark[peer_id] = {}
    end
    g_mark[peer_id][vehicle_id] = true
end

function removeMarker(peer_id, vehicle_id)
    if peer_id < 0 then
        if vehicle_id < 0 then
            g_savedata['mark'] = {}
            return
        end
        g_savedata['mark'][vehicle_id] = nil
        return
    end
    if g_mark[peer_id] == nil then
        return
    end
    if vehicle_id < 0 then
        g_mark[peer_id] = nil
        return
    end
    g_mark[peer_id][vehicle_id] = nil
end

function cleanVehicleDB()
    for vehicle_id, _ in pairs(g_savedata['vehicle_db']) do
        if not getVehicleExists(vehicle_id) then
            g_savedata['vehicle_db'][vehicle_id] = nil
        end
    end
end

function getLastSpawnedVehicleInfo()
    local vehicle_id = -1
    for _, info in pairs(g_savedata['vehicle_db']) do
        if info['vehicle_id'] > vehicle_id then
            vehicle_id = info['vehicle_id']
        end
    end
    return g_savedata['vehicle_db'][vehicle_id]
end

function getVehicleList()
    local list = {}
    for _, info in pairs(g_savedata['vehicle_db']) do
        table.insert(list, info)
    end
    return list
end

function buildUIManager()
    local uim = {
        ['_map_object_1'] = {},
        ['_map_object_2'] = {},
        ['_popup_1'] = {},
        ['_popup_2'] = {}
    }

    function uim.setMapObject(peer_id, ui_id, position_type, marker_type, x, z, parent_local_x, parent_local_z, vehicle_id, object_id, label, radius, hover_label)
        for peer_id, _ in pairs(getPeerIDTable(peer_id)) do
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
        for peer_id, _ in pairs(getPeerIDTable(peer_id)) do
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

function getOwner(peer_id)
    if peer_id < 0 or peer_id == 65535 then -- HACK: In Stormworks v.1.4.15, the peer_id of a vehicle spawned from a script is 65535
        return {['kind'] = 'SCRIPT', ['steam_id'] = nil}
    elseif peer_id == 0 then
        return {['kind'] = 'HOST', ['steam_id'] = nil}
    end

    for _, peer in pairs(server.getPlayers()) do
        if peer['id'] == peer_id then
            return {
                ['kind'] = 'GUEST',
                ['steam_id'] = string.format('%d', peer['steam_id']),
                ['name'] = peer['name'],
            }
        end
    end
    return nil
end

function getOwnerEqual(owner_1, owner_2)
    if owner_1['kind'] ~= owner_2['kind'] then
        return false
    elseif owner_1['kind'] ~= 'GUEST' then
        return true
    end
    return owner_1['steam_id'] == owner_2['steam_id']
end

function getOwnerPeerID(owner)
    if owner['kind'] == 'SCRIPT' then
        return -1
    elseif owner['kind'] == 'HOST' then
        return 0
    end

    for _, peer in pairs(server.getPlayers()) do
        local steam_id = string.format('%d', peer['steam_id'])
        if steam_id == owner['steam_id'] then
            return peer['id']
        end
    end
    return nil
end

function getOwnerDisplayName(owner)
    if owner['kind'] == 'HOST' then
        local peer_name, is_success = server.getPlayerName(0)
        if is_success then
            return peer_name
        end
    end

    if owner['name'] ~= nil then
        return owner['name']
    end

    if owner['kind'] == 'SCRIPT' then
        return '{script}'
    elseif owner['kind'] == 'HOST' then
        return '{host}'
    end
    return '{guest}'
end

function getOwnerDisplayNameAndID(owner)
    local peer_display_name = getOwnerDisplayName(owner)
    local peer_id = getOwnerPeerID(owner)

    if peer_id == nil or peer_id < 0 then
        return peer_display_name
    end
    return string.format('%s#%d', peer_display_name, peer_id)
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

function getPeerIDTable(peer_id)
    if peer_id ~= nil and peer_id >= 0 then
        return {[peer_id] = true}
    end

    local peer_id_tbl = {}
    for _, peer in pairs(server.getPlayers()) do
        peer_id_tbl[peer['id']] = true
    end
    return peer_id_tbl
end

function getVehicleExists(vehicle_id)
    local _, is_success = server.getVehicleFireCount(vehicle_id)
    return is_success
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

function reverseTable(tbl)
    local new = {}
    for i, value in ipairs(tbl) do
        new[#tbl - i + 1] = value
    end
    return new
end
