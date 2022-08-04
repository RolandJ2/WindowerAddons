_addon.author = 'RolandJ'
_addon.version = '1.0.0'
_addon.commands = {'autows', 'aws'}



-------------------------------------------------------------------------------------------------------------------
-- Setup local variables used throughout this lua.
-------------------------------------------------------------------------------------------------------------------

require('functions')
local res = require('resources')

--[[local active = true
local tpLimit = 3000
local wsName = "Spirits Within"
local wsRange = 5
local minHpp = 20]]
local fsDelay = 3
local fsTries = 0
local fsTriesMax = 30
local debugMode = false



-------------------------------------------------------------------------------------------------------------------
-- Setup local config
-------------------------------------------------------------------------------------------------------------------

local config = require('config')
local settings
defaults = T{
	active = false,
	tpLimit = 1000,
	wsName = '',
	wsRange = 5,
	minHpp = 10,
	ui = T{
		visible = true,
		pos = T{x = 20, y = 20}
	}
}
--local settings = config.load(defaults)
--config.save(settings)



-------------------------------------------------------------------------------------------------------------------
-- Setup local UI
-------------------------------------------------------------------------------------------------------------------

local texts = require('texts')
local display = texts.new()

local colors = T{
	red = '255,0,0',
	white = '255,255,255',
	green = '0,255,0',
	yellow = '240,240,0'
}

function colorInText(text, color)
	if colors[color] == nil then return print('colorInText issue: color not found') end
	return '\\cs(' .. colors[color] .. ')' .. text .. '\\cr'
end

function updateDisplayLine()
	return display:text(T{
		'  Status: ' .. colorInText(settings.active and 'on' or 'off', settings.active and 'green' or 'red'),
		'WS: ' .. colorInText(settings.wsName, 'yellow'),
		'Min TP: ' .. colorInText(settings.tpLimit, 'yellow'),
		'Min Mob HP: ' .. colorInText(settings.minHpp .. '%', 'red') .. '  ',
		'Max WS Range: ' .. colorInText(settings.wsRange, 'red') .. '  ',
	}:concat('      '))
end



-------------------------------------------------------------------------------------------------------------------
-- Check current scenario for AWS triggers
-------------------------------------------------------------------------------------------------------------------

local checkAwsTriggers = function()
	local player = windower.ffxi.get_player()
	local playerIsEngaged = player and player.status == 1 or false
	local target = windower.ffxi.get_mob_by_target('t')
	
	-- Skip AWS inactive OR no target OR player is disengaged
	if target == nil then return end
    if not settings.active then return end
	if not playerIsEngaged then return end
	
	if debugMode then windower.add_to_chat(8, "[AutoWS] checkAwsTriggers executing...") end
	
	-- Standard Auto WS (NOTE: player.status: 0 = disengaged, 1 = engaged)
	if player.vitals.tp >= settings.tpLimit then
		if math.sqrt(target.distance) <= settings.wsRange then
			if target.hpp >= settings.minHpp then
				if debugMode then windower.add_to_chat(8, "[AutoWS] Attempting to perform "..settings.wsName.." at "..player.vitals.tp.." TP") end
				windower.send_command('input /ws "' .. settings.wsName .. '" <t>')
			else
				if debugMode then windower.add_to_chat(8, "[AutoWS] Holding TP, Target HPP < "..target.hpp) end
			end
		else
			if debugMode then windower.add_to_chat(8, "[AutoWS] Target is too far away... (distance: "..target.distance..")") end
		end
	end
	
	-- 3000 TP Failsafe (tp change event stops firing @ 3000 TP, status change only fires once)
	if player.vitals.tp == 3000 then
		fsTries = fsTries + 1
		if debugMode then windower.add_to_chat(8, "[AutoWS] Queueing the 3000TP aws failsafe (Try "..fsTries.."/"..fsTriesMax..")") end
		awsFailsafe:schedule(fsDelay) -- Failsafe: tp change event stops firing @ 3000 TP
	end
end


-------------------------------------------------------------------------------------------------------------------
-- 3000 TP Failsafe for terminated tp change event
-------------------------------------------------------------------------------------------------------------------

awsFailsafe = function() --IMPORTANT: function:schedule only works on this when it's global... I don't know why
	local player = windower.ffxi.get_player()
	local playerIsEngaged = player.status == 1
	
	if fsTries < fsTriesMax and playerIsEngaged then
		if player.vitals.tp == 3000 then
			-- Tries Remain: Re-check Scenario for AWS Trigger
			checkAwsTriggers()
		else
			-- TP Event Restarted: Reset/Terminate Failsafe
			if debugMode then windower.add_to_chat(8, "[AutoWS] 3000 TP Failsafe Ended on Try " .. fsTries .. " of " .. fsTriesMax .. " (TP: " .. player.vitals.tp .. ")") end
			fsTries = 0
		end
	else
		-- Out of Tries: Reset/Terminate Failsafe
		if debugMode then windower.add_to_chat(8, "[AutoWS] 3000 TP Failsafe Ended on Try " .. fsTries .. " of " .. fsTriesMax .. (playerIsEngaged and "" or " (Player Disengaged)")) end
		fsTries = 0
	end
end


-------------------------------------------------------------------------------------------------------------------
-- Processing for addon commands (type //aws ingame)
-------------------------------------------------------------------------------------------------------------------

windower.register_event('addon command', function(...)
	-- Detect command vs value
	local commandArgs = {...}
	local command = commandArgs[1] and string.lower(table.remove(commandArgs, 1)) or 'help'
	local value = table.concat(commandArgs, " ")
	--windower.add_to_chat(17, "command: "..command.." / value: "..value)
	
	-- Prepare chat color definitions
	local green = 158
	local red = 123
	local grey = 207

    if command:wmatch('toggle|switch|flip') then
		windower.send_command('aws ' .. (settings.active and 'off' or 'on'))
	elseif command:wmatch('on|start|begin|activate|off|stop|end|deactivate') then
        local activating = command:wmatch('on|start|begin|activate')
		if (activating and settings.active) or (not activating and not settings.active) then
			return windower.add_to_chat(red, '[AutoWS] Already ' .. (active and 'activated' or 'deactivated'))
		end
		settings.active = activating
		config.save(settings)
		updateDisplayLine()
		windower.add_to_chat(activating and green or red, '[AutoWS] ' .. (activating and 'Activated' or 'Deactivated'))
    elseif command == 'tp' then
		if value ~= '' then
			if tonumber(value) >= 1000 and tonumber(value) <= 3000 then
				settings.tpLimit = tonumber(value)
				config.save(settings)
				updateDisplayLine()
				windower.add_to_chat(grey, "[AutoWS] Set TP threshold to ["..value.."]")
			else
				windower.add_to_chat(red, "[AutoWS] Error: Please specify a TP value between 1000 and 3000 [command: "..command..", value:"..value.."]")
			end
		else
			windower.add_to_chat(red, "[AutoWS] Error: Please specify a TP value [command: "..command..", value:"..value.."]")
		end
    elseif command == 'ws' then
		if value ~= '' then
			value = windower.convert_auto_trans(value)
			local match = false
			for _, ws in pairs(res.weapon_skills) do
				if ws.en:lower() == value:lower() then
					match = true
				end
			end
			if match then
				settings.wsName = value
				config.save(settings)
				updateDisplayLine()
				windower.add_to_chat(grey, "[AutoWS] Set WS name to ["..value.."]")
			else
				windower.add_to_chat(red, '[AutoWS] Unable to find ws "' .. value .. '".')
			end
		else
			windower.add_to_chat(red, "[AutoWS] Error: Please specify a WS name [command: "..command..", value:"..value.."]")
		end
    elseif command == 'range' then
		if value ~= '' then
			if tonumber(value) >= 0 and tonumber(value) <= 21 then
				settings.wsRange = tonumber(value)
				config.save(settings)
				updateDisplayLine()
				windower.add_to_chat(grey, "[AutoWS] Set WS range to ["..value.."]")
			else
				windower.add_to_chat(red, "[AutoWS] Error: Please specify a range value between 0 and 21 [command: "..command..", value:"..value.."]")
			end
		else
			windower.add_to_chat(red, "[AutoWS] Error: Please specify a WS range [command: "..command..", value:"..value.."]")
		end
    elseif command == 'hp' or command == 'hpp' then
		if value ~= '' then
			if tonumber(value) >= 0 and tonumber(value) <= 100 then
				settings.minHpp = tonumber(value)
				config.save(settings)
				updateDisplayLine()
				windower.add_to_chat(grey, "[AutoWS] Set mob HPP threshold to ["..value.."]")
			else
				windower.add_to_chat(red, "[AutoWS] Error: Please specify a hp value between 0 and 100 [command: "..command..", value:"..value.."]")
			end
		else
			windower.add_to_chat(red, "[AutoWS] Error: Please specify a mob HPP value [command: "..command..", value:"..value.."]")
		end
	elseif command =='uipos' then
		if value ~= '' then
			local coords = value:split(' ')
			if #coords < 2 then
				return windower.add_to_chat(red, '[AutoWS] Please provide both a X and Y coordinate')
			end
			for i, pos in ipairs(value:split(' ')) do
				local coord = tonumber(pos)
				if coord == nil or coord < 0 then
					return windower.add_to_chat(red, '[AutoWS] Please provide only positive X and Y coordinates')
				end
				settings.ui.pos[i == 1 and 'x' or 'y'] = coord
			end
			config.save(settings)
			display:pos(settings.ui.pos.x, settings.ui.pos.y)
			windower.add_to_chat(grey, "[AutoWS] Set UI position to [".. settings.ui.pos.x .. '/' .. settings.ui.pos.y .."]")
		else
			windower.add_to_chat(red, "[AutoWS] Error: Please specify UI position [command: "..command..", value:"..value.."]")
		end
	elseif command == 'debug' then
		debugMode = not debugMode
		windower.add_to_chat(grey, "[AutoWS] debugMode set to ["..tostring(debugMode).."]")
	elseif command == 'config' or command == 'settings' then
        windower.add_to_chat(grey, 'AutoWS  settings:')
        windower.add_to_chat(grey, '    active     - '..tostring(settings.active))
        windower.add_to_chat(grey, '    tpLimit    - '..settings.tpLimit)
        windower.add_to_chat(grey, '    wsName   - '..settings.wsName)
        windower.add_to_chat(grey, '    wsRange   - '..settings.wsRange)
        windower.add_to_chat(grey, '    minHpp    - '..settings.minHpp)
    elseif command == 'help' then
        windower.add_to_chat(grey, 'AutoWS  v' .. _addon.version .. ' commands:')
        windower.add_to_chat(grey, '//aws [options]')
        windower.add_to_chat(grey, '    toggle   - Toggles auto weaponskill ON or OFF')
        windower.add_to_chat(grey, '    tp       - Sets TP threshold at which to weaponskill')
        windower.add_to_chat(grey, '    ws       - Sets the weaponskill to use')
        windower.add_to_chat(grey, '    range    - Sets the max range to weaponskill at')
        windower.add_to_chat(grey, '    hp       - Sets HPP threshold at which to halt AWS (set to 0 to disable this feature)')
        windower.add_to_chat(grey, '    config   - Displays the curent AWS settings')
        windower.add_to_chat(grey, '    help     - Displays this help text')
        windower.add_to_chat(grey, ' ')
        windower.add_to_chat(grey, 'NOTE: AutoWS will only automate weaponskills if your status is "Engaged".')
    else
		windower.add_to_chat(red, '[AutoWs] "'..command..'" is not a valid command. Listing commands...')
		windower.send_command('aws help')
	end
end)



-------------------------------------------------------------------------------------------------------------------
-- Addon hooks for TP and status change events
-------------------------------------------------------------------------------------------------------------------

local function load_settings()
	settings = config.load('data\\'..windower.ffxi.get_player().main_job..'.xml', defaults)
	config.save(settings)
	
	display:text(updateDisplayLine())
	display:size(10)
	display:bold(true)
	display:draggable(false)
	display:pos(settings.ui.pos.x, settings.ui.pos.y)
	display:show()
end

windower.register_event('tp change', checkAwsTriggers)
windower.register_event('status change', checkAwsTriggers)
windower.register_event('load', 'job change', load_settings)