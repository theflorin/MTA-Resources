----------------------------------------------
-- 				Send.lua					--
-- Send requests/commands to other server	-- 
-- that are handled in receive.lua			--
----------------------------------------------

-- Info --
this_server = get('this_server')
other_server = get('other_server')
other_ip = get('other_ip')					-- ip to communicate with
other_port = tonumber(get('other_port'))	-- port to redirect
other_http_port = get('other_http_port')	-- http to communicate with
resourceName = getResourceName(getThisResource())
other_ipandport = other_ip .. ':' .. other_http_port

mapInfo_other = {}
mapInfo_other.name = ""
mapInfo_other.author = ""

max_players = getMaxPlayers()

function getServersInfo()
	triggerClientEvent(client, "receiveServersInfo", client, this_server, other_server)
end
addEvent("getServersInfo", true)
addEventHandler("getServersInfo", root, getServersInfo)


-- Test connection with other server
outputDebugString("Interchat " .. other_ipandport .. " " ..other_port .. " " .. tostring(
	callRemote(other_ipandport, resourceName, "testConnection", function(response)
		if response ~= "ERROR" then
			outputDebugString('Interchat response: ' .. tostring(response))
		end
	end)
))

-----------------
-- F2 redirect --
-----------------

function redirect()
	local player = client
	local tick, hoursPlayed = getElementData(player, 'jointick'), getElementData(player, 'hoursPlayed')
	callRemote ( other_ipandport, resourceName, "playerRedirect", function (response, serial)
		if response ~= "ok" then
			outputChatBox(other_server .. ' server is not responding!', player, 255, 0, 0)
		else
			setElementData( player , 'gotomix', true)
			redirectPlayer ( player, other_ip, other_port) 
		end
	end, getPlayerSerial(player), getElementData(player,'playtime'), tick, hoursPlayed )
end
addEvent('onRequestRedirect', true)
addEventHandler('onRequestRedirect', root, redirect)

function getPlayerFromSerial(serial)
    if serial and type(serial) == "string" then
        for i, v in ipairs(getElementsByType("player")) do
	    if getPlayerSerial(v) == serial then
	        return v
	    end
	end
    end
    return false
end

addCommandHandler('redirectall', function(p)
	outputChatBox('Redirecting everyone to other server')
	for k, player in ipairs(getElementsByType'player') do
		if player ~= p then
			setElementData( player , 'gotomix', true)
			redirectPlayer ( player, other_ip, other_port) 
		end
	end
end, true, true)

-------------------------
-- Chat, use the + prefix
-------------------------

local chat_prefix = '+'
function playerChat ( message, messageType )
	if messageType ~= 0 or message:sub(1,1) ~= chat_prefix or #message < 2 or exports.gus:chatDisabled() then
		return
	end
	return outputChatBox ( 'Server chat is moved to the U key now. Press U to chat with ' .. other_server, source, 255, 0, 0)
	-- local name = removeColorCoding(getPlayerName(source))
	-- message = removeColorCoding(message:sub(2))
    -- callRemote ( other_ipandport, resourceName, "playerChatBoxRemote", checkPlayerChat, name, message )
	-- cancelEvent()
end
addEventHandler ( "onPlayerChat", getRootElement(), playerChat)

function checkPlayerChat(name, message)
	if type(name) == "string" and type(message) == "string" then
		local out = "[" .. string.upper(this_server) .. "] " .. name .. "> " .. message .. ""
		outputChatBox(out, root, 0xFF, 0xD7, 0x00)
		outputServerLog(out)
		exports.irc:outputIRC("08[" .. this_server:upper() .. "] " .. tostring(name) .. "> " .. tostring(message) .. "")
	else
		outputDebugString("Serverchat: no/wrong response from other server! (" .. other_ipandport .. ")", 1)
	end
end

function removeColorCoding ( name )
	return type(name)=='string' and string.gsub ( name, '#%x%x%x%x%x%x', '' ) or name
end

function chatCommand(player, cmd, ...)
	if isPlayerMuted(player) or exports.gus:chatDisabled() then
		return
	end
	local name = removeColorCoding(getPlayerName(player))
	message = removeColorCoding(table.concat({...},' '))
    callRemote ( other_ipandport, resourceName, "playerChatBoxRemote", checkPlayerChat, name, message )
end
addCommandHandler(other_server, chatCommand)

function start()
	for k, p in ipairs(getElementsByType'player') do
		join(p)
	end
end
addEventHandler('onResourceStart', resourceRoot, start)

function join(p)
	bindKey ( p or source, 'u', 'down', 'chatbox', other_server )
end
addEventHandler('onPlayerJoin', root, join)

-------------
-- Players --
-------------

function getOtherServerPlayers ( player, cmd, server )
	if server and server:lower() == other_server:lower() then
		callRemote ( other_ipandport, resourceName, "sendPlayerNames", receivePlayerNames, getPlayerName(player) )
	end
end
addCommandHandler("players", getOtherServerPlayers, false, false)

function receivePlayerNames ( player, amount, max, names )
	if type(amount) == "string" and tonumber(amount) and type(names) == "string" and getPlayerFromName(player) then
		player = getPlayerFromName(player)
		amount = tonumber(amount)
		if amount > 0 then
			_outputChatBox("[" .. other_server:upper() .. "] Total players online: " .. amount .. "/" .. max .. " - Names: "..names, player, 0xFF, 0xD7, 0x00)
		else
			outputChatBox("[" .. other_server:upper() .. "] No players online", player, 0xFF, 0xD7, 0x00)
		end
	else
		outputDebugString("Serverchat: no/wrong response from other server! (" .. other_ipandport .. ")", 1)
	end
end

function _outputChatBox(str, player, c1, c2, c3)
	local sz = 0
	if #str > 96 then
		if #str % 96 == 0 then
			sz = #str / 96
		else
			sz = (#str / 96) + 1
		end
		for i = 0, sz-1 do
			local nstr = ''
			nstr = string.sub(str, i*96, i*96 + 96)
			outputChatBox(nstr, player, c1, c2, c3)
		end	
	else
		outputChatBox(str, player, c1, c2, c3)
	end
end


------------
-- Admins --
------------

function getOtherServerAdmins ( player, cmd )
	callRemote ( other_ipandport, resourceName, "sendAdminNames", receiveAdminNames, getPlayerSerial(player) )
end
addCommandHandler("admins", getOtherServerAdmins)

function receiveAdminNames ( serial, admins, moderators )
	local player = getPlayerFromSerial(serial)
	if not player then return end
	
	if #admins > 0 then
		outputChatBox("[" .. other_server:upper() .. "] Admins online: " .. admins, player, 0xFF, 0xD7, 0x00)
	else
		outputChatBox("[" .. other_server:upper() .. "] No admins online", player, 0xFF, 0xD7, 0x00)
	end

	if #moderators > 0 then
		outputChatBox("[" .. other_server:upper() .. "] Moderators online: " .. moderators, player, 0xFF, 0xD7, 0x00)
	else
		outputChatBox("[" .. other_server:upper() .. "] No moderators online", player, 0xFF, 0xD7, 0x00)
	end
end


--------------
-- Map info --
--------------

function mapStarted (mapinfo)
	mapInfo = mapinfo
	callRemote ( other_ipandport, resourceName, "sendMapInfo", (function() end), mapInfo.name, mapInfo.author, exports.race:getRaceMode(), true, false ) --Send mapInfo and update F2 GUI for clients of the other server
	triggerClientEvent("updateF2GUI", resourceRoot, this_server.." Map", "Map: "..mapInfo.name.."\nAuthor: "..mapInfo.author) --Update F2 GUI for clients of this server
end
addEvent("onMapStarting")
addEventHandler("onMapStarting", root, mapStarted)

function getServersMapInfo ( sendTo )
	if not mapInfo then
		local s = getElementData( getResourceRootElement( getResourceFromName("race") ) , "info") 
		if s then
			mapInfo = s.mapInfo
		else
			mapInfo = {}
			mapInfo.name = ""
			mapInfo.author = ""
		end
	end
	
	if sendTo == "sendToAll" then
		sendToElement = root
		callRemote ( other_ipandport, resourceName, "sendMapInfo", receiveMapInfo, mapInfo.name, mapInfo.author, nil, false, true ) --Get mapInfo from the other server and update F2 GUI for clients of this server
	elseif sendTo == "client" then
		sendToElement = client
		triggerClientEvent(sendToElement, "updateF2GUI", sendToElement, other_server.." Map", "Map: "..mapInfo_other.name.."\nAuthor: "..mapInfo_other.author) --Update F2 GUI for clients of this server
	end
	
	triggerClientEvent(sendToElement, "updateF2GUI", resourceRoot, this_server.." Map", "Map: "..mapInfo.name.."\nAuthor: "..mapInfo.author) --Update F2 GUI for clients of this server
end
addEvent("getServersMapInfo", true)
addEventHandler("getServersMapInfo", root, getServersMapInfo)


function receiveMapInfo ( mapinfo )
	if mapinfo == "ERROR" or mapinfo == nil then 
		mapInfo_other = {}
		mapInfo_other.name = ""
		mapInfo_other.author = ""
	else
		mapInfo_other = mapinfo
	end
	
	triggerClientEvent(root, "updateF2GUI", resourceRoot, other_server.." Map", "Map: "..mapInfo_other.name.."\nAuthor: "..mapInfo_other.author)
end


addEventHandler("onResourceStart", resourceRoot, 
function() 
	setTimer(getServersMapInfo, 500, 1, "sendToAll")
end
)

---------------
-- GC logins --
---------------

function gcLogin ( forumID, amount )
	callRemote ( other_ipandport, resourceName, "greencoinsLogin", (function() end), forumID )
end
addEventHandler("onGCLogin" , root, gcLogin )


------------------
-- Mutes & bans --
------------------

-- admin panel hook
addEvent ( "aPlayer", true )
addEventHandler ( "aPlayer", root, function ( player, action, data, additional, additional2 )
	if ( action == "mute" )  then
		local seconds = tonumber(additional) and tonumber(additional) > 0 and tonumber(additional)
		if seconds then
			callRemote ( other_ipandport, resourceName, "aAddSerialUnmuteTimer", (function() end), getPlayerSerial(player), seconds )
		end
	end
end, true, 'high')

addEventHandler("onBan",root,
	function (ban)
		local reason = getBanReason(ban)
		if reason and reason:find('sync_banned', 1, true) then return end
		local ip = getBanIP(ban)
		local admin = getBanAdmin(ban)
		local serial = getBanSerial(ban)
		local seconds = getUnbanTime(ban)
		callRemote ( other_ipandport, resourceName, "addSyncBan", (function() end), ip, serial, reason, seconds )
	end
)

-----------------------
-- Online players F2 --
-----------------------

function getServerPlayersOnline ( )
	players = #getElementsByType('player')
	setElementData(resourceRoot, this_server.." Players", players.."/"..max_players, true)
	
	callRemote ( other_ipandport, resourceName, "sendOnlinePlayers", receivePlayersOnline) --getOtherServerPlayersOnline
end
setTimer(getServerPlayersOnline, 1000, 0)


function receivePlayersOnline ( players2, max_players2 )
	if players2 == "ERROR" or players2 == nil then players2 = "0" end
	if max_players2 == nil then max_players2 = "0" end
	
	setElementData(resourceRoot, other_server.." Players", players2.."/"..max_players2, true)
	
	local players_total = tostring(tonumber(players) + tonumber(players2))
	setElementData(resourceRoot, "Total players online", players_total, true)
end