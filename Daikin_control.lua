-- Daikin control v0.1
------------------------ Global variables-----------------------
local BOILER_DEVICE = 'DaikinPower' -- switch device
local SETPOINT_DEVICE = 'DaikinTarget Temperature' -- device
local TEMPERATURE_SENSOR_INSIDE = 'Daikin Home Temp+Hum'
local TEMPERATURE_SENSOR_OUTSIDE = 'Daikin Outside Temperature'
local MODE_SELECTOR = 'Daikin Mode'
local VENTILLATION_SELECTOR = 'Daikin Ventillation'
local WINDS_SELECTOR = 'Daikin Winds'

local HYSTERESIS = 0.5 -- temp has to drop this value below setpoint before boiler is on again
local CORRECTION = 1.2 --difference between sensor and setpoint
local SMOOTH_FACTOR = 3

local LOGGING = true


------------------------ Initialisations-----------------------
return {
	on = {
		timer = { 'every 5 minutes' },
		device = { TEMPERATURE_SENSOR_INSIDE,TEMPERATURE_SENSOR_OUTSIDE, SETPOINT_DEVICE }
	},
	data = {
		temperatureReadings = { history = true, maxItems = SMOOTH_FACTOR }
	},
	active = true,
	execute = function(domoticz, device, triggerInfo)

 ------------------------ Local variables-----------------------
		local avgTemp
		local avgTemp_outside
		local tempComfort=22 
		local temperatureReadings = domoticz.data.temperatureReadings
		local boiler = domoticz.devices(BOILER_DEVICE)
		local setpoint = domoticz.devices(SETPOINT_DEVICE)
        local mode = domoticz.devices(MODE_SELECTOR).switchSelector(5)
        local vent = domoticz.devices(VENTILLATION_SELECTOR).switchSelector(6)
        local winds = domoticz.devices(WINDS_SELECTOR)
        local sensor_inside = domoticz.devices(TEMPERATURE_SENSOR_INSIDE)
        local sensor_outside = domoticz.devices(TEMPERATURE_SENSOR_OUTSIDE)
        local current_inside = sensor_inside.temperature
        local current_outside = sensor_outside.temperature

------------------------Setup-----------------------
		if (triggerInfo.type == domoticz.EVENT_TYPE_DEVICE) then
			if (sensor_inside.changed or sensor_outside.changed) then
                    -- sensor just reported a new reading
                    -- add it to the readings table
				if (current_inside ~= 0 and current_inside ~= nil) then
					temperatureReadings.add(current_inside)
				else
					domoticz.log('Strange sensor reading.. skiping', domoticz.LOG_ERROR)
					return
				end
				if (current_outside ~= nil) then
					temperatureReadings.add(current_outside)
				else
					domoticz.log('Strange sensor reading.. skiping', domoticz.LOG_ERROR)
					return
				end

			elseif (domoticz.devices(SETPOINT_DEVICE).changed) then
				      -- a new setpoint was set
				if LOGGING then domoticz.log('Setpoint was set to ' .. device.state) 
				end
			else
				    -- no business here, bail out...
				return
			end
		end

------------------------Logic1 - Reinitit-----------------------
		if (setpoint.state == nil or setpoint.state == 'Off') then
			 --boiler.switchOff()
            --override.switchOff()
			return 
		end

------------------------Setup - room depending temperature-----------------------
		local setpointValue = tonumber(setpoint.state)
                -- determine at which temperature the boiler should be
                -- switched on
		local setpointValueCorr = setpointValue - CORRECTION
		local switchOnTemp = setpointValueCorr - HYSTERESIS
                -- don't use the current reading but average it out over
                -- the past <SMOOTH_FACTOR> readings (data smoothing) to get rid of noise, wrong readings etc
		--local avgTemp = temperatureReadings.avg(1, SMOOTH_FACTOR)
		local avgTemp = temperatureReadings.avg(1, SMOOTH_FACTOR, current_inside)
		local avgTemp_outside = temperatureReadings.avg(1, (SMOOTH_FACTOR*12), current_outside)

		if LOGGING then
			domoticz.log('Average: ' .. avgTemp, domoticz.LOG_INFO)
			domoticz.log('Average outside: ' .. avgTemp_outside, domoticz.LOG_INFO)
			domoticz.log('Setpoint: ' .. setpointValue, domoticz.LOG_INFO)
			domoticz.log('Current heater state: ' .. boiler.state, domoticz.LOG_INFO)
			domoticz.log('Switch-on temperature: ' .. switchOnTemp, domoticz.LOG_INFO)
		end
------------------------Logic2 -Switch off (temp>=nedded)-----------------------
		if (avgTemp_outside<=tempComfort) then
			mode.switchSelector='HOT'
		else
			mode.switchSelector='COLD'
		end


------------------------Logic4 - Switch On (temp<nedded)-----------------------

	if(mode.state=='HOT') then
		if (avgTemp < setpointValueCorr) then      -- test avgTemp
			if (current < switchOnTemp) then        -- default: current
				if LOGGING then domoticz.log('Heating is required, heater switched on') 
				end
				if(boiler.state == 'Off' ) then				-- protection variation 2
					boiler.switchOn()
				end
			end
		elseif (avgTemp >= setpointValueCorr and override.state =='On') then
				if LOGGING then domoticz.log('Target temperature reached, heater off') 
				end
				--boiler.switchOff()
				boiler.switchOff().afterMin(2)
		else
			if LOGGING then domoticz.log('Average temperature below setpoint but within hysteresis range, waiting for temperature to drop to ' .. switchOnTemp)
			end
		end
	elseif(mode.state=='COOL') then
		
	end
end

}