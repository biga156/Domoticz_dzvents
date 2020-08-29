--https://www.domoticz.com/forum/viewtopic.php?t=21422
--      Heat control 
--
        ------------------------------------------------------------------------
        local version = '2.3'                   -- current version of script 
        ------------------------------------------------------------------------
        local LOGGING =  true                   -- true or false LOGGING info to domoticz log. 
        --=======================================================
        -- DEVICES // name of devices in Domoticz  
        --=======================================================
		-- HEAT  
		local devHEAT = 'Central heating boiler'     -- switch that will be turned OFF and ON

		-- thermometers
		local devThermometer_main   = 'Main thermometer'       -- main thermometer to control switch
		local devThermometer_second = 'Backup thermometer'           -- backup thermometer to control switch  when main thermometer dont work  (lastUpdate > max_time_last_seen) 
        
        --=======================================================
        -- DUMMY DEVICES  // your name of devices create in Domoticz  for this script
        --=======================================================
        -- setpoints  
		local devSetpoint_comfort = 'Comfort temperature'        -- setpoint: comfort temperature
        local devSetpoint_night = 'Economic temperature'              -- setpoint: eco temperature for night 
        local devSetpoint_custom = 'Temperature for manual mode' -- setpoint: temperature for manual mode
        local devSetpoint_holidays = 'Temperature HOLIDAYS'           -- setpoint: eco temperature for holidays mode
        -- selectors 
		local devSelector_heat_work_day = 'Heating - working days'   -- heat work day  with buttons for zone of hours exp: [5-22] or [5.30-22.30] or [5.30-7/14.00-22]
		local devSelector_heat_weekend = 'Heating - weekends'       -- heat weekend with buttons for zone of hours exp: [5-22] or [5.30-22.30] or [5.30-7/14.00-22]
		local devSelector_mode = 'Working mode'               -- work mode with 4 buttons as below: 
		        local devSelector_mode_auto = 'AUTO'
		        local devSelector_mode_manual = 'MANUAL'
				local devSelector_mode_holidays = 'HOLIDAYS'
		        local devSelector_mode_off  = 'OFF'
   
        -- text 
		local devText_work_state      = 'Current working status CO'   -- text device witch displayed current status 

        --=======================================================
        -- USER VARIABLES   // name of user variables in Domoticz ( Setup > More options > User variables). 
        --=======================================================
		local usrStateWorkHEAT      = 'HeatWorkCondition'                 -- helper variable to work script 
		local usrLastStatement      = 'HeatStatement'                 -- helper variable last statemen 

        --=======================================================
        -- OTHER 
        --=======================================================
        -- conditions of TIME ZONE 
        local NOTIFY_TIME    = 'at 05:00-22:00'                                  -- matchesRule when notify will be send.  (default - PUSHOVER)
		local BACK_TO_AUTO   = 'at 23:30-23:40 on mon,tue,wed,thu,fri,sat,sun'   -- matchesRule to back to 'AUTO' mode from 'MANUAL' mode. 
        --=======================================================
		-- auxiliary variables
		local HISTERESIS = 0.3              -- deviation from the set temperature
		local max_time_last_seen = 60       -- the maximum time in minutes when main thermometer have to report  (lastUpdate) or we change on backup 
		local min_time_to_change = 5        -- the minimum time in minutes to do change  of state devHEAT
		local min_time_to_notify = 60       -- the minimum time in minutes to repeat the unchanged notifycation. 
		local temp_default  = 20            -- default temperature when both  termometers dont work. 

		local description_heat ='Heating '        -- label "HEAT" to info for text device 
		local description_break ='Break '       -- label "BREAK" to info for text device 
		local descriptionPrefix = ' temp.: '     -- label "PREFIX" to info for text device  
		local descriptionSufix  = ' dg.'          -- label "SUFIX" to info for text device   

        --=======================================================
        -- FUNCTION: helpers
        --=======================================================

function notify(domoticz, text1, text2)
    if domoticz.variables(usrLastStatement).value ~= text2 or domoticz.variables(usrLastStatement).lastUpdate.minutesAgo > min_time_to_notify then 
        domoticz.variables(usrLastStatement).set(text2) 
 	    if domoticz.time.matchesRule(NOTIFY_TIME) then 
            domoticz.notify(text1,text2, domoticz.PRIORITY_HIGH, domoticz.SOUND_PUSHOVER, '', domoticz.NSS_PUSHOVER)    -- notify system default - PUSHOVER
        end  
    end 
end     

function log(domoticz, text, lvlError)
     local lvlLog = domoticz.LOG_FORCE
     if lvlError ~= nil and lvlError == true then lvlLog = domoticz.LOG_ERROR end 
     if LOGGING then  domoticz.log(text , lvlLog) end 
end      

function round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end

function rtrim(s)
  local n = #s
  while n > 0 and s:find("^%s", n) do n = n - 1 end
  return s:sub(1, n)
end

function updateTextInfoDevice(domoticz, text_content)
        if domoticz.devices(devText_work_state).state ~= text_content then domoticz.devices(devText_work_state).updateText(text_content) end
        if domoticz.variables(usrStateWorkHEAT).value ~= text_content then
            domoticz.variables(usrStateWorkHEAT).set(text_content) 
 		    notify(domoticz,'Heating control - Change of mode work', 'Change of mode: '..text_content) 
        --  domoticz.log(text_content, domoticz.LOG_FORCE);
        --  domoticz.log(domoticz.variables(usrStateWorkHEAT).value, domoticz.LOG_FORCE);
        end
end 

function getHourFromSelector(state,nZone)
	-- separators in buttons with hours exp: [5-22] or [5.30-22.15] or [5.30-7/14.20-22]
    local hourSplit = '-'     
    local minSplit = '.'
    local zoneSplit = '/'
    ---
    
    local ret = ''
    local hour1 =''
    local hour2 =''
    if  minSplit == '.' then minSplit = '%.' end 
    local nZoneSplit= string.find(state, zoneSplit)    
    if nZone == 1 then nFrom = 0 end 
    nLenZoneSplit=string.len(zoneSplit)
    if nZone == 2 and nZoneSplit ~= nil then  
        nFrom = nZoneSplit + nLenZoneSplit
    else 
       if nZone == 2 then  return nil end 
    end 
    if nFrom == nil then return nil end 
    local nHourSplit= string.find(state, hourSplit, nFrom,true)     
    if nHourSplit > 0 then  
        local hour1 = string.sub(state,nFrom,nHourSplit-1)  
        if string.len(hour1) == 0 then hour1='00' end 
        if string.len(hour1) == 1 then hour1='0'..hour1 end  
        local nMin=string.find(hour1,minSplit,1)      

        if nMin == nil then 
            hour1 = hour1..':00' 
        else
            hour1 = string.gsub(hour1,minSplit,':')
        end 

        local nZoneSplit2 = string.find(state, zoneSplit, nHourSplit+1)           

        if nZoneSplit2 == nil then  hour2 = string.sub(state,nHourSplit+1) else  
            hour2 = string.sub(state,nHourSplit+1,nZoneSplit2-1)  
        end 
        hour2=rtrim(hour2)

        if string.len(hour2) == 0 then hour2='00' end 
        if string.len(hour2) == 1 then hour2='0'..hour2 end  
        nMin=string.find(hour2,minSplit,1)      

        if nMin == nil then 
            hour2 = hour2..':00'
        else 
            hour2 = string.gsub(hour2,minSplit,':')
        end 

        ret = hour1..'-'..hour2
    end 
    return ret 
    
end     

--=======================================================
 -- MAIN dzVent's SCRIPT  
--=======================================================

return {
    active = true,
    on = { 
	       devices = {devSetpoint_comfort, devSetpoint_night, devSetpoint_custom, devSetpoint_holidays, devSelector_heat_work_day, devSelector_heat_weekend, devSelector_mode, devThermometer_main },
		   timer = {'every 2 minutes'},
		   },
 		
    execute = function(domoticz,device,triggerInfo)
	    
	    --==========================================    
        -- BLOCK INFO TO DEBUG
        --==========================================
        log(domoticz,'')
        log(domoticz,' **************************************************************************')
        log(domoticz,'1. Heating control - start debug ver -> '.. version)
        -------------- STATE ON BEGIN RUN OF SCRIPT 
        log(domoticz,' **************************************************************************')
        log(domoticz,' On moment start script:')
        log(domoticz,' --------------------------------------------------------------------------')
        log(domoticz,' > '..domoticz.devices(devHEAT).name .. ' -> '.. domoticz.devices(devHEAT).state)
        log(domoticz,' > '..domoticz.devices(devThermometer_main).name .. ' -> '.. round(domoticz.devices(devThermometer_main).temperature,1))
        log(domoticz,' > '..domoticz.devices(devText_work_state).name .. ' -> '.. domoticz.devices(devText_work_state).state)
        log(domoticz,' > '..domoticz.devices(devSetpoint_comfort).name .. ' -> '.. domoticz.devices(devSetpoint_comfort).state)
        log(domoticz,' > '..domoticz.devices(devSetpoint_night).name .. ' -> '.. domoticz.devices(devSetpoint_night).state)
        log(domoticz,' > '..domoticz.devices(devSetpoint_custom).name .. ' -> '.. domoticz.devices(devSetpoint_custom).state)
        log(domoticz,' > '..domoticz.devices(devSetpoint_holidays).name .. ' -> '.. domoticz.devices(devSetpoint_holidays).state)
        log(domoticz,' > '..domoticz.devices(devSelector_heat_work_day).name .. ' -> '.. domoticz.devices(devSelector_heat_work_day).state)
        log(domoticz,' > '..domoticz.devices(devSelector_heat_weekend).name .. ' -> '.. domoticz.devices(devSelector_heat_weekend).state)
        log(domoticz,' > HISTERESIS' .. ' -> '.. HISTERESIS)
        log(domoticz,' --------------------------------------------------------------------------')

        --=======================================================
        --  variables
        --=======================================================
            local Time = require('Time')
            local stateworkHEAT = ''
            local stateworkMODE = ''
    	    local temp_current = 0
            local temp_set = 0
            local temp_night = 0
            local temp_comfort = 0

        --=======================================================
        --  BLOCK OF selectors 
        --=======================================================

       if ((domoticz.devices(devSelector_mode).changed) and (domoticz.devices(devSelector_mode).state == devSelector_mode_off)) then 
			local text_content = 'SYSTEM OFF'
            updateTextInfoDevice(domoticz, text_content)                   
			domoticz.devices(devHEAT).switchOff()		
			log(domoticz,' > 3. SETTING MODE: [' .. text_content .. ']',true)
            log(domoticz,' --------------------------------------------------------------------------')
			return
		end						

        if domoticz.devices(devSelector_mode).state == devSelector_mode_holidays then stateworkMODE = '>'..devSelector_mode_holidays..'<' end			
		if domoticz.devices(devSelector_mode).state == devSelector_mode_auto then  stateworkMODE = '>'..devSelector_mode_auto..'<' end	
		if domoticz.devices(devSelector_mode).state == devSelector_mode_manual then stateworkMODE = '>'..devSelector_mode_manual..'<' end				
		if domoticz.devices(devSelector_mode).state == devSelector_mode_off then  return  end		  --- because system is OFF. 
        
        
        --==========================================    
        -- BLOCK return from MANUAL to AUTO 
        --==========================================
        -- automatic return to AUTO mode when the time condition described in the parameters is met, the event is triggered by a thermometer (ie automatically and not manually)
        if domoticz.time.matchesRule(BACK_TO_AUTO) and domoticz.devices(devSelector_mode).state == devSelector_mode_manual then  
	        domoticz.devices(devSelector_mode).dimTo(10)
		    notify(domoticz,'Heating control - back to mode '..devSelector_mode_auto, 'The condition for automatic switching into mode is met '..devSelector_mode_auto) 
    	    log(domoticz,' > 2. Auto back to mode '..devSelector_mode_auto..' -> Switch ON mode '..devSelector_mode_auto..' -> '..BACK_TO_AUTO)         
            log(domoticz,' **************************************************************************')
            log(domoticz,'')
            return  --exit from the script, because it will trigger a second event which will enter the new service for auto mode.
        end 

        --=======================================================
        --  BLOCK OF setpoints
        --=======================================================

        -- notifications of changes in the status of important control parameters
        local llnotify=false
		if (domoticz.devices(devSetpoint_comfort).changed) then
		    notify(domoticz,'Heating control - parameter change', 'The temperature setting for the comfort zone has been changed to value: '..domoticz.devices(devSetpoint_comfort).state) 
		    log(domoticz,' > 4. Notification sent ->'..' The temperature setting for the comfort zone has been changed to value: '..domoticz.devices(devSetpoint_comfort).state)
		    llnotify = true
		end
		if (domoticz.devices(devSetpoint_night).changed) then
    		notify(domoticz,'Heating control - parameter change', 'The night temp setting has been changed to value: '..domoticz.devices(devSetpoint_night).state) 
		    log(domoticz,' > 5. Notification sent ->'..' The night temp setting has been changed to value: '..domoticz.devices(devSetpoint_night).state)
		    llnotify = true
		end
		if (domoticz.devices(devSetpoint_custom).changed) then
		    notify(domoticz,'Heating control - parameter change', 'User temperature setting changed to value: '..domoticz.devices(devSetpoint_custom).state) 
		    log(domoticz,' > 6. Notification sent ->'..'User temperature setting changed to value: '..domoticz.devices(devSetpoint_custom).state)
		    llnotify = true
		end
		if (domoticz.devices(devSetpoint_holidays).changed) then
		    notify(domoticz,'Heating control - parameter change', 'The temperature setting for the mode has been changed '..devSelector_mode_holidays..' on value: '..domoticz.devices(devSetpoint_holidays).state) 
		    log(domoticz,' > 7. Notification sent ->'..'The temperature setting for the mode has been changed '..devSelector_mode_holidays..' on value: '..domoticz.devices(devSetpoint_holidays).state) 
		    llnotify = true
		end
		if (domoticz.devices(devSelector_heat_work_day).changed) then
		    notify(domoticz,'Heating control - parameter change', 'The setting of heating zones on WORK DAYS was changed on value: '..domoticz.devices(devSelector_heat_work_day).state) 
		    log(domoticz,' > 8. Notification sent ->'..' The setting of heating zones on WORK DAYS was changed on value: '..domoticz.devices(devSelector_heat_work_day).state)
		    llnotify = true
		end
		if (domoticz.devices(devSelector_heat_weekend).changed) then
		    notify(domoticz,'Heating control - parameter change', 'The setting of heating zones on WEEKENDS has been changed on value: '..domoticz.devices(devSelector_heat_weekend).state) 
		    log(domoticz,' > 9. Notification sent ->'..'The setting of heating zones on WEEKENDS has been changed on value: '..domoticz.devices(devSelector_heat_weekend).state)
		    llnotify = true
		end
        if llnotify  then log(domoticz,' ------------------------------------------------------------------------') end 


        --==========================================    
        -- BLOCK OF CHECKS termometers :
        --==========================================
        local devHeatMinAgo = domoticz.devices(devHEAT).lastUpdate.minutesAgo
        --- its time event so user dont click any push button, below we check condition to not offen change state of devHEAT. 
        if (triggerInfo.type ==  domoticz.EVENT_TYPE_TIMER or device.name == devThermometer_main)  and devHeatMinAgo <  min_time_to_change  then 
    	    log(domoticz,' > 10. Nothing to change, last change -> '.. tostring(devHeatMinAgo) .. '  minutes ago. QUIT')
            log(domoticz,' **************************************************************************')
            log(domoticz,'')
            return  --exit from the script, because it will trigger a second event which will enter the new service for auto mode.
        end 

        -- Determining the current temperature in the living room [this is a reference point for heating control] but if the thermometer does not work, we assume the temperature of the spare thermometer
        if domoticz.devices(devThermometer_main).lastUpdate.minutesAgo < max_time_last_seen then temp_current = round(domoticz.devices(devThermometer_main).temperature,2) end 

        if (domoticz.devices(devThermometer_main).lastUpdate.minutesAgo >= max_time_last_seen) then
            notify(domoticz,'Heating control - ALERT!!!', 'The thermometer does not report from '..tostring(max_time_last_seen)..' minutes, the system gets the temperature from an alternative thermometer!')
            log(domoticz,'10a. The thermometer does not report from '..tostring(max_time_last_seen)..' minutes, the system gets the temperature from an alternative thermometer!') 
            if (domoticz.devices(devThermometer_second).lastUpdate.minutesAgo < max_time_last_seen) then
                temp_current = round(domoticz.devices(devThermometer_second).temperature,2)
            else
                temp_current =  temp_default
		        notify(domoticz,'Heating control - ALERT!!!', 'Alternative thermometer also does not work, I accept as temp_current '..tostring(temp_default)..' dg') 
		        log(domoticz,'10b. Alternative thermometer also does not work, I accept as temp_current '..tostring(temp_default)..' dg') 
            end
        end

        --==========================================
        -- BLOCK CONTROL:  <holidays> i <MANUAL>
        --==========================================
        if ((domoticz.devices(devSelector_mode).state == devSelector_mode_holidays) or (domoticz.devices(devSelector_mode).state == devSelector_mode_manual)) then 
            if domoticz.devices(devSelector_mode).state == devSelector_mode_holidays  then 
                temp_set =  tonumber(domoticz.devices(devSetpoint_holidays).state) 
                log(domoticz,' > Operating mode selected >'..devSelector_mode_holidays..'<, checking if boiler operation is needed ')
                end
            if domoticz.devices(devSelector_mode).state == devSelector_mode_manual then 
                temp_set =  tonumber(domoticz.devices(devSetpoint_custom).state) 
                log(domoticz,' >  Operating mode selected  >'..devSelector_mode_manual..'<, checking if boiler operation is needed ')
                end
            log(domoticz,' --------------------------------------------------------------------------')
            log(domoticz,' Boiler response to new settings: ')
            log(domoticz,' --------------------------------------------------------------------------')
            if temp_set > temp_current then
                domoticz.devices(devHEAT).switchOn()
                log(domoticz,' >11. ' .. devHEAT .. ' On because the current temperature '.. tostring(temp_current)..' lower than required '..tostring(temp_set),true)
            else
                domoticz.devices(devHEAT).switchOff()
                log(domoticz,' > 11a. '.. devHEAT .. ' OFF because the current temperature '..tostring(temp_current)..' it is not lower than required '..tostring(temp_set),true)
            end 
             -- contentet of text info 
            local text_content = stateworkMODE ..' '..stateworkHEAT..descriptionPrefix..temp_set..descriptionSufix
            updateTextInfoDevice(domoticz, text_content)     
            log(domoticz,' > 11b. I set the info about the work status on: [' .. text_content .. ']')
            log(domoticz,' **************************************************************************')
            log(domoticz,'')
            return 
        end   

        --==========================================
        -- BLOCK CONTROL: <AUTO>
        --==========================================
        --  determination of heating zones: on what days in which times the comfort temperature should be maintained, and when it should be lowered
        --- WORK DAY 
    
        log(domoticz,' Boiler operation settings for mode '..devSelector_mode_auto..': ')
        log(domoticz,' --------------------------------------------------------------------------')

    	local HEAT_MORNING   = ''      
		local HEAT_AFTERNOON = '' 
		local HEAT_WEEKEND   = '' 

        -- devSelector_heat_work_day
        stateDevSelector_heat_work_day=domoticz.devices(devSelector_heat_work_day).state
        strHEAT_morning = getHourFromSelector(stateDevSelector_heat_work_day, 1)
        if strHEAT_morning ~= nil then 
            HEAT_MORNING = 'at '..  strHEAT_morning  ..' on mon,tue,wed,thu,fri'
            log(domoticz,' > 13. I set the heating zone: Working days - heating from '.. strHEAT_morning)
        else 
             -- contentet of text info 
            local text_content = ' SYSTEM OFF !!!'
            updateTextInfoDevice(domoticz, text_content)                     
			domoticz.devices(devHEAT).switchOff()		
            log(domoticz,text_content,true);
            log(domoticz,' **************************************************************************')
            log(domoticz,'')
            return 
        end    

        strHEAT_afternoon = getHourFromSelector(stateDevSelector_heat_work_day, 2)
        if strHEAT_afternoon ~= nil then 
            HEAT_AFTERNOON = 'at '..  strHEAT_afternoon  ..' on mon,tue,wed,thu,fri'
            log(domoticz,' > 14.I set the heating zone: Working days - heating from '.. strHEAT_afternoon)
        else 
            HEAT_AFTERNOON = HEAT_MORNING
        end    
       
        --- WEEKEND; 
        stateDevSelector_heat_work_weekend=domoticz.devices(devSelector_heat_weekend).state
        strHEAT_weekend = getHourFromSelector(stateDevSelector_heat_work_weekend, 1)
        if strHEAT_weekend ~= nil then 
           HEAT_WEEKEND = 'at ' .. strHEAT_weekend .. ' on sat, sun'
           log(domoticz,' > 15. I set the heating zone: Weekends - heating '..strHEAT_weekend)
        else 
            local text_content = ' SYSTEM OFF !!!'
            updateTextInfoDevice(domoticz, text_content)                     

			domoticz.devices(devHEAT).switchOff()		
            log(domoticz,text_content,true);
            log(domoticz,' **************************************************************************')
            log(domoticz,'')
            return 
        end
        
       -- log(domoticz,' > 16. Aktualne reguły : ')
       -- log(domoticz,' > 17. ...HEAT_MORNING   -> '.. HEAT_MORNING )
       -- log(domoticz,' > 18. ...HEAT_AFTERNOON -> '.. HEAT_AFTERNOON )
       -- log(domoticz,' > 19. ...HEAT_WEEKEND   -> '.. HEAT_WEEKEND )

        -- determination of comfortable and overnight temperature
        if (domoticz.time.matchesRule(HEAT_MORNING) or domoticz.time.matchesRule(HEAT_AFTERNOON) or domoticz.time.matchesRule(HEAT_WEEKEND)) then 
              temp_comfort =  tonumber(domoticz.devices(devSetpoint_comfort).state)
	          temp_set = temp_comfort
	          stateworkHEAT = description_heat
              log(domoticz,' > 20. Current boiler operation mode: Heating day')
        else
              temp_night = domoticz.devices(devSetpoint_night).state
              temp_set = tonumber(temp_night)
              stateworkHEAT = description_break
              log(domoticz,' > 21. Current boiler operation mode: Cold zone')
	    end
            -- switching the boiler on or off if the set temperature has been reached
        local temp_to_compare = domoticz.devices(devHEAT).state 
		local switchOnTemp = temp_set - HISTERESIS
		local switchOffTemp = temp_set + HISTERESIS

        log(domoticz,' > 22. I turn on the oven for an even or lower temperature: ' .. switchOnTemp ..'  Current temp: '..tostring(temp_current))
        log(domoticz,' > 23. I turn off the furnace for an even or higher temperature: ' .. switchOffTemp ..'  Current temp: '..tostring(temp_current))
        
        log(domoticz,' --------------------------------------------------------------------------')
    	if (temp_current >= switchOffTemp and domoticz.devices(devHEAT).state == 'On') then
            log(domoticz,' The boilers reaction to new settings (or calling the conservator by a temp.): ')
            log(domoticz,' --------------------------------------------------------------------------')
			log(domoticz,' > 24. Target temperature reached, Status => off',true)
	    	domoticz.devices(devHEAT).switchOff()
		end
		if (temp_current <= switchOnTemp and  domoticz.devices(devHEAT).state == 'Off') then
            log(domoticz,'Boiler response to new settings (or calling the sensor by the temperature sensor): ')
            log(domoticz,' --------------------------------------------------------------------------')
		    domoticz.devices(devHEAT).switchOn()
			log(domoticz,' > 25. Heating is needed, Status => on',true) 
		end

       -- contentet of text info 
        local text_content = stateworkMODE ..' '..stateworkHEAT..descriptionPrefix..temp_set..descriptionSufix
        updateTextInfoDevice(domoticz, text_content)
        log(domoticz,' > 23. I set the info about the work status on: [' .. text_content .. ']')
        log(domoticz,' ************************************************************************** ')
        log(domoticz,'')
    end
}
 --=======================================================
 -- end of script 
--========================================================