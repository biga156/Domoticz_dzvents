local PHONE = 'Phone Eni'
local SETPOINT_DEVICE = 'Eni_Termosztat'
local TEMP_COMFORT= 22
local TEMP_ECO = 17
local Time = require('Time')
local t = Time()
---------------------Program---------------------
return { 
	on = {
		timer = { 'every 2 minutes' },
		devices = {
			PHONE,
			SETPOINT_DEVICE
			
		}
	},
	active = true,
	execute = function(domoticz, device, triggerInfo)
	
	local setpoint = domoticz.devices(SETPOINT_DEVICE)
	local phone = domoticz.devices(PHONE)
	local phone2 = domoticz.devices(PHONE2)
	local comf= TEMP_COMFORT
	local eco = TEMP_ECO
	local setpointValue = tonumber(setpoint.state)
	
	if(t.matchesRule('at 06:00-22:30') and phone.state=='On' ) then
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