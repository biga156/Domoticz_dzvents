	local PHONE = 'Phone Szabi'
	local SETPOINT_DEVICE = 'Szabi_termosztat' 
	local TEMP_COMFORT= 22
	local TEMP_ECO = 18

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
    local comf= TEMP_COMFORT
    local eco = TEMP_ECO
		
     if (domoticz.devices(SETPOINT_DEVICE).changed) then
        -- a new setpoint was set
         if LOGGING then domoticz.log('Setpoint was set to ' .. device.state) end
    else
      -- no business here, bail out...
        return
    end
	

	if('between 06:00 and 23:00') then
	    if(phone.state=='On' ) then
			targettemp.updateSetPoint(comf) 
			domoticz.log('Device ' .. 'Szabi_termosztat' .. ' was changed', domoticz.LOG_INFO)
			return
		else 
			 targettemp.updateSetPoint(eco) 
			 return
			
		end
	else
		targettemp.updateSetPoint(eco) 
		return
	
	end

end
}