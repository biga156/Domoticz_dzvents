local PHONE = 'Phone Szabi'
local COMPUTER = 'Computer Szabi'
local SETPOINT_DEVICE = 'Szabi_termosztat' 
local TEMP_COMFORT= 21.5
local TEMP_ECO = 17
local Time = require('Time')
local t = Time()

---------------------Program---------------------
return { 
	on = {
		timer = { 'every 2 minutes' },
		devices = {
			PHONE,
			COMPUTER,
			SETPOINT_DEVICE
			
		}
	},
	active = true,
	execute = function(domoticz, device, triggerInfo)
	
	local setpoint = domoticz.devices(SETPOINT_DEVICE)
	local phone = domoticz.devices(PHONE)
	local computer = domoticz.devices(COMPUTER)
	local comf= TEMP_COMFORT
	local eco = TEMP_ECO
	local setpointValue = tonumber(setpoint.state)
	
	if(t.matchesRule('at 06:30-22:30') and (phone.state=='On' or computer.state=='On')) then
	--if(t.matchesRule('at 06:00-22:30') and phone.state=='On' ) then
		if(setpointValue~=comf) then
			setpoint.updateSetPoint(comf) 
		else
			return
		end
	else
		if(setpointValue~=eco) then
			setpoint.updateSetPoint(eco) 
		else
			return
		end
	end
	
	end
	}