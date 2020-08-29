local PHONE = 'Phone Zsu'
local SETPOINT_DEVICE = 'Zsu_Termosztat' 
local TEMP_COMFORT= 22.5
local TEMP_ECO = 18
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
	local comf= TEMP_COMFORT
	local eco = TEMP_ECO
	local man=false
	local setpointValue = tonumber(setpoint.state)
	------------------Setup------------------------------
		-- first check if the sensor got a new reading or the setpoint was changed:
		if (triggerInfo.type == domoticz.EVENT_TYPE_DEVICE) then
		
			if (domoticz.devices(SETPOINT_DEVICE).changed) then
					  -- a new setpoint was set
					  local manual =  setpointValue
					  local man=true
					  local c=Time()
				if LOGGING then domoticz.log('Setpoint was set to ' .. device.state) end
			else
				local comf= TEMP_COMFORT	
				
				return
			end
		end
	
	--------------------------Logic----------------------------------
	if(t.matchesRule('at 06:15-22:30') and phone.state=='On' and man== false) then
		if(setpointValue~=comf) then
			setpoint.updateSetPoint(comf) 
		else
			return
		end
	elseif(t.matchesRule('at 06:15-22:30') and (phone.state=='On' or phone2.state=='On') and man== true) then
		setpoint.updateSetPoint(manual)
		
		if((t.compare(c).secs)>=3600) then
			local man=false
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