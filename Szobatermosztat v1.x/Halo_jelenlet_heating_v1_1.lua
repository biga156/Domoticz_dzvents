local PHONE = 'Phone Gabi'
local PHONE2 = 'Phone Viki'
local SETPOINT_DEVICE = 'Haloszoba_Termosztat'
local TEMP_COMFORT= 23
local TEMP_ECO = 17
local Time = require('Time')
local t = Time()
local LOGGING=true


---------------------Program---------------------
return { 
on = {
	timer = { 'every 2 minutes' },
	devices = {
		PHONE,
		PHONE2,
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
local man=false
local setpointValue = tonumber(setpoint.state)
------------------Setup manual------------------------------
	
	if (triggerInfo.type == domoticz.EVENT_TYPE_DEVICE) then
	
		if (setpoint.changed) then
				  -- a new setpoint was set
				  comf =  setpointValue
				  local man=true
				  local c=Time()
			if LOGGING then 
				domoticz.log.DEBUG('!!!!!!!!!!Setpoint was set to ' .. device.state)
				domoticz.log.DEBUG('!!!!!!!!!!man  was set to ' .. man.state)
			 end
		else
			local comf= TEMP_COMFORT	
			
			return
		end
	end

--------------------------Logic----------------------------------

if(t.matchesRule('at 06:30-22:30') and (phone.state=='On' or phone2.state=='On')) then
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