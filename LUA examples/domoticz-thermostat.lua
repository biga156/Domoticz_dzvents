--
-- Domoticz passes information to scripts through a number of global tables
--
-- otherdevices, otherdevices_lastupdate and otherdevices_svalues are arrays for all devices: 
--   otherdevices['yourotherdevicename'] = "On"
--   otherdevices_lastupdate['yourotherdevicename'] = "2015-12-27 14:26:40"
--   otherdevices_svalues['yourotherthermometer'] = string of svalues
--
-- uservariables and uservariables_lastupdate are arrays for all user variables: 
--   uservariables['yourvariablename'] = 'Test Value'
--   uservariables_lastupdate['yourvariablename'] = '2015-12-27 11:19:22'
--
-- other useful details are contained in the timeofday table
--   timeofday['Nighttime'] = true or false
--   timeofday['SunriseInMinutes'] = number
--   timeofday['Daytime'] = true or false
--   timeofday['SunsetInMinutes'] = number
--   globalvariables['Security'] = 'Disarmed', 'Armed Home' or 'Armed Away'
--
-- To see examples of commands see: http://www.domoticz.com/wiki/LUA_commands#General
-- To get a list of available values see: http://www.domoticz.com/wiki/LUA_commands#Function_to_dump_all_variables_supplied_to_the_script
--
-- Based on your logic, fill the commandArray with device commands. Device name is case sensitive. 
--

-- This script will keep the temperature between 19°C and 21°C
-- when the switch named by the day of the week is on

-----------------------
------ Variables ------
-----------------------
local m = os.date('%M')             -- Current date/time
local consigne = 20.5               -- Room temperature
local hysteresis = 0.2              -- Threshold
local trigger = 'Trigger'           -- Trigger Device
local probe = 'Temperature'         -- Temparture probe
local heating_units = {             -- Heating units array
    'Living Room Heater L',
    'Living Room Heater R',
    'Office Heater L',
    'Office Heater R'
}

-----------------------
-------- Logic --------
-----------------------

commandArray = {}

local function heatingManagement()
    -- Virtual switch named by the full day of the week (e.g. Monday)
    local dayoftheweek = os.date("%A")
    print('# dayoftheweek: ' .. dayoftheweek)
    
    -- Get today's switch state
    local switchvalue = otherdevices[dayoftheweek]
    print('# switchvalue: ' .. switchvalue)
    
    -- Current room temperature
	local temperature = tonumber(otherdevices_svalues[probe])
	print('# temperature: ' .. temperature)
	
    if (switchvalue == 'On') then
        print('# Heating system is on today')
        
        local time = tonumber(os.date("%H"));
        
        print ('# Current time: ' .. time) 
        print ('# temperature: ' .. temperature)
        print ('# consigne: ' .. consigne)
        print ('# hysteresis: ' .. hysteresis)
        print ('# (consigne - hysteresis): ' .. (consigne - hysteresis))
        print ('# (consigne + hysteresis): ' .. (consigne + hysteresis))
        
        -- Taking advantage of the day/night electricity pricing
        -- Heating between 6-23
        if(time >= 6 and time < 23) then
            print('# Day time');
        	if (temperature < (consigne - hysteresis) ) then
                print('# Needs heating')
                for i, heating_unit in ipairs(heating_units) do
                    commandArray[heating_unit] = 'Set Level: 100'
                end
    	    elseif (temperature > (consigne + hysteresis)) then
    	        print('# No need to heat')
                for i, heating_unit in ipairs(heating_units) do
                    commandArray[heating_unit] = 'Set Level: 20'
                end
            else
                print('# Needs heating - Threshold Gap')
                for i, heating_unit in ipairs(heating_units) do
                    commandArray[heating_unit] = 'Set Level: 100'
                end
            end
        else
            print('# Night time mode');
            for i, heating_unit in ipairs(heating_units) do
                commandArray[heating_unit] = 'Set Level: 26'
            end
	    end
    else
        print('# Heating system is off today. Set to "Hors Gel"')
        for i, heating_unit in ipairs(heating_units) do
            commandArray[heating_unit] = 'Set Level: 20'
        end
    end
end

-- Run every n minutes
if (m % 15 == 0) then
   heatingManagement()
end

return commandArray