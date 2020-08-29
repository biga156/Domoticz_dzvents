https://easydomoticz.com/forum/viewtopic.php?t=3093--[[

Type : Time
Name : script_time_heating.lua
Description : Controls heating in a room with hysterisis or PID method
Usage : Place in scripts/lua directory of Domoticz instance

This script provides heating control in a room, providing different modes (Comfort, Eco), according
to presence in the room and to a couple of setpoints. The heating control is proposed through
two differents algorithms (Hysterisis or PID). The script supports multiple temperature control
devices used in fallback, and multiple heating devices used simultaneously.
A power consumption computation is made, based on the declared power consumption of each heating device.

Required Domoticz configuration :

- A Thermostat to set the comfort temperature, created with Dummy hardware and a Thermostat device
  Variable : sSetPointConfortDeviceName

- A Thermostat to set the eco temperature, created with Dummy hardware and a Thermostat device
  Variable : sSetPointEcoDeviceName

- A Mode switch to set and program with timers the heating scenarii, created with Dummy hardware and a Selector Switch device
  Variable : sHeatingModeDeviceName

- A Control Mode switch to switch between the Hysterisis and PID ways of control.
  Variables : sHeatingControlModeDeviceName
  sHeatingControlModePIDName, sHeatingControlModeHysteresisName are used for the name given to either mode.

- A Presence detection switch. The switch would be controlled either by hand or by some external scripts/commands.
  Variable : sPresenceDeviceName

- An Electricity consumption meter, created with an Instant+Counter meter
  Variable : sPowerMeterDeviceName

- Heaters
  One or more heaters have to be declared in an array, together with their power consumption and commands.
  Variable : aHeatingDeviceNames

- Temperature sensors
  They are declared in a array, with fall back mode implemented. The script is written for sensors that gather both temperature and humidity.
  Variable : aTempSensorDeviceNames

- User variables
  - fISumLast, a float value initialized to 0, that's the PID current integral value ;
  - fTempLastInput, a float value initialized to 0, used for the PID derivative computation ;
  - fSetpointLast, a float value initialized to 0, used to check a setpoint change ;
  - iResetDeviceMeterTime, an integer value initialized to 0, used to record the power meter reset time.

The PID parameters are to be determined for your own installation. Three parameters need to be calculated,
according to the following formulas :

Kp = ΔPV / ΔCO  -- On steady temperature states, ratio of temperature difference for command difference
Tp -- Time needed to reach 63% of the setpoint
θp -- Time between action on the heating and measurable reaction of the temperature sensor
Tc -- Response time, highest value among 0.1Tp or 0.8θp (agressive), 1Tp or 8θp (middle), 10Tp or 80θp (conservative)
Kc = P = (1/Kp)*(Tp/(θp+Tc)) -- Our fPIDKp
I = Kc/Ti -- Our fPIDKi
Td = (Tp x θp)/(2Tp+θp) -- Needed to compute the last constant
D = Kc * Td -- Our fPIDKd

This script distributed under the GPL license. Please see https://www.gnu.org/licenses/gpl.html
--]]

-- Zone name
local sZoneName = 'Living room'

-- Setpoint
local sSetPointConfortDeviceName = 'Thermostat Confort'         -- Thermostat for comfort Setpoint
local sSetPointEcoDeviceName = 'Thermostat Eco'                 -- Thermostat for eco Setpoint

-- Power Meter
local sPowerMeterDeviceName = 'Consommation Chauffage'          -- Power meter based on configured heating devices consumption

-- Modes
-- These modes belong to the heating mode selector switch
local sHeatingModeDeviceName = 'Mode Chauffage'
local sHeatingModeComfortName = 'Confort'
local sHeatingModeEcoName = 'Eco'
local sHeatingModeForceOnName = 'Force'
local sHeatingModeFrostFreeName = 'Off'

-- Heating control mode (PID or Hysteresis)
local sHeatingControlModeDeviceName = 'Mode Controle Chauffage'
local sHeatingControlModePIDName = 'PID'                             -- Selection switch name for PID
local sHeatingControlModeHysteresisName = 'Hysteresis'         -- Selection switch name for hysterisis mode

local fHysteresis = 0.4                          -- Hysterisis value

-- Sensors
-- Will be choosen in fallback. Second parameter is a delta to the first temp sensor
local aTempSensorDevices = {
                             { 'Living-room 1',0 } ,

                             { 'Chambre Enfant',1.2 }     -- The room is usually ~1.2 deg hotter than the living room
                           }

local sPresenceDeviceName = 'Presence'          -- Presence device switch. Heating goes in Eco mode when Presence is Off.

-- Heaters
-- Domoticz Device Name, power in Watts, On command, Off command.
local aHeatingDevices = {
                             { 'Hors-Gel Radiateur Salon Est', 1500 , 'Off AFTER 3', 'On' } ,

                             { 'Hors-Gel Radiateur Salon Sud', 1500 , 'Off AFTER 3', 'On' }

                        }

-- PID - Proportional, Integral, Derivative - Parameters

local iHeatingCycleDuration = 10 -- Duration of a heating cycle in minutes, to be adapted to the heating devices
local fPIDKp = 113  -- Change this !
local fPIDKi = 0.05 -- Change this !
local fPIDKd = 30045 -- Change this !

-- Alerts
local sEmailContact = 'name@domain.tld'

-- Debug
local bDebug = true
---------------------------------------------- End of configuration section ----------------------------------------------

-- Variables

local fCurrentTemp = 1000

-- Statics variables
-- Heating commands, constants not to be changed
local sHeatingOnCommand = 'ON'
local sHeatingOnForCommand = 'ONFOR'
local sHeatingOffCommand = 'OFF'

-- Functions

function prDebug(sString)
  if(bDebug) then
   print ( sString )
  end
end

function addCommand( sDevice, sCommand )
   commandArray[#commandArray+1] = { [sDevice] = sCommand }
end

function timeDifference(sDeviceName)
   sDeviceTimeChanged = otherdevices_lastupdate[sDeviceName]
   sYear = string.sub(sDeviceTimeChanged, 1, 4)
   sMonth = string.sub(sDeviceTimeChanged, 6, 7)
   sDay = string.sub(sDeviceTimeChanged, 9, 10)
   sHour = string.sub(sDeviceTimeChanged, 12, 13)
   sMinutes = string.sub(sDeviceTimeChanged, 15, 16)
   sSeconds = string.sub(sDeviceTimeChanged, 18, 19)
   t1 = os.time()
   t2 = os.time{year=sYear, month=sMonth, day=sDay, hour=sHour, min=sMinutes, sec=sSeconds}
   return os.difftime (t1, t2)
end

function round(fNumber, iPrecision)
  local iMult = 10^(iPrecision or 0)
  return math.floor(fNumber * iMult + 0.5) / iMult
end

function commandHeating(sCommand,iTime)
 local fIntervalEnergy = 0
 local fInstantPower = 0

      -- Send command to heaters, calculate power and energy

       for iHeatingDeviceIndex = 1, #aHeatingDevices do
        local sActiveHeatingDevice = aHeatingDevices[iHeatingDeviceIndex]
        fInstantPower = fInstantPower + sActiveHeatingDevice[2]
        if( sCommand == sHeatingOnForCommand ) then
          fIntervalEnergy = fIntervalEnergy + (tonumber(fInstantPower) / 60 ) * iHeatingCycleDuration 
        else
           fIntervalEnergy = fIntervalEnergy + tonumber(fInstantPower) / 60 
        end
        if( sCommand == sHeatingOnCommand ) then
         prDebug('Heating device : - '..sActiveHeatingDevice[1]..' - , power : ' .. sActiveHeatingDevice[2]..' Watts gets command : '..sActiveHeatingDevice[3])
         addCommand(sActiveHeatingDevice[1],sActiveHeatingDevice[3])
        end
        if( sCommand == sHeatingOnForCommand ) then 
         prDebug('Heating device : - '..sActiveHeatingDevice[1]..' - , power : ' .. sActiveHeatingDevice[2]..' Watts gets command : '..sActiveHeatingDevice[3]..' FOR '..tostring(iTime))
         addCommand(sActiveHeatingDevice[1],sActiveHeatingDevice[3] .. ' FOR ' .. tostring(iTime))  -- Can be missed :-( --> zwave!
        end
        if( sCommand == sHeatingOffCommand ) then
         prDebug('Heating device : - '..sActiveHeatingDevice[1]..' - , power : ' .. sActiveHeatingDevice[2]..' Watts gets command : '..sActiveHeatingDevice[4])
         addCommand(sActiveHeatingDevice[1],sActiveHeatingDevice[4])
        end
       end

      -- Energy accounting
       -- Get current power-meter values
       sCurrentPower,sCurrentTotalEnergy = string.match(otherdevices_svalues[sPowerMeterDeviceName], "(%d+%.*%d*);(%d+%.*%d*)" )
       local fCurrentTotalEnergy = tonumber(sCurrentTotalEnergy)
       if(sCommand == sHeatingOffCommand ) then -- No instant power consumption
         addCommand('UpdateDevice', iPowerMeterIdx .. '|0|0;' .. sCurrentTotalEnergy)
         return
       end

       fUpdatedEnergy = fCurrentTotalEnergy + fIntervalEnergy
       if(sCommand == sHeatingOnForCommand ) then -- System heating iTimes minutes
         addCommand('UpdateDevice', iPowerMeterIdx .. '|0|' .. fInstantPower .. ';' .. fUpdatedEnergy)
         addCommand('Variable:iResetDeviceMeterTime',tostring(iTime))
       end

       if(sCommand == sHeatingOnCommand ) then -- System in On/Off mode, heating happends until a stop command
       -- Total instant power update
         addCommand('UpdateDevice', iPowerMeterIdx .. '|0|' .. fInstantPower .. ';' .. fUpdatedEnergy)
       end
end


-- Init
commandArray = {}
iPowerMeterIdx = otherdevices_idx[sPowerMeterDeviceName]

-- Get time
local sCurrentTime = string.sub(os.date("%X"), 1, 5)
local sCurrentMinute = os.date('%M')

-- Check temperature sensors, choose the first one with response time < 10 min
-- set setpoint delta

for iTempSensorIndex = 1, #aTempSensorDevices do
      prDebug('Temp Sensor Device : '..aTempSensorDevices[iTempSensorIndex][1]..' - Delta to reference : ' .. aTempSensorDevices[iTempSensorIndex][2] )
      sTempSensorDeviceName = aTempSensorDevices[iTempSensorIndex][1]
      sTempSensorDeltaToReference = aTempSensorDevices[iTempSensorIndex][2]
  -- Last seen ?
      local sTempSensorLastSeen = string.sub(os.date("!%X", timeDifference(sTempSensorDeviceName)), 1, 5)
        -- if (sTempSensorLastSeen >= '00:10' and sTempSensorLastSeen < '00:12') then
        if (sTempSensorLastSeen >= '00:10') then
                  prDebug('Temp sensor missing')
          addCommand('SendEmail',sZoneName..' Heating Alert#Temperature sensor '..sTempSensorDeviceName..' has not updated for more than 10m.#'..sEmailContact)
        else -- Sensor has been seen, we use it
          sCurrentTemp,sCurrentHumidity = string.match(otherdevices_svalues[sTempSensorDeviceName],"(%d+%.*%d*);(%d+%.*%d*)")
          fCurrentTemp = tonumber(sCurrentTemp) + tonumber(sTempSensorDeltaToReference)
          prDebug ('Current measured temperature and delta applied : '..fCurrentTemp)
          break
        end
end
if ( fCurrentTemp == 1000) then return commandArray end -- No temp sensor, end of execution

-- Check for energy accounting timer to reset the meter
local iResetMeterDeviceTime = tonumber(uservariables['iResetDeviceMeterTime'])
if ( iResetMeterDeviceTime > 0 ) then -- There is an ongoing power consumption
    local iNewResetDeviceMeterTime = iResetMeterDeviceTime - 1
     if( iNewResetDeviceMeterTime == 0) then
  -- reset energy counters on time
         sCurrentPower,sCurrentTotalEnergy = string.match(otherdevices_svalues[sPowerMeterDeviceName], "(%d+%.*%d*);(%d+%.*%d*)" )
         addCommand('UpdateDevice', iPowerMeterIdx .. '|0|0;' .. sCurrentTotalEnergy)
     end
    addCommand('Variable:iResetDeviceMeterTime',tostring(iNewResetDeviceMeterTime))
end

-- Get current heating mode
sHeatingMode = otherdevices[sHeatingModeDeviceName]

-- Heating in Eco or Comfort, needs a calculation

if ( sHeatingMode == sHeatingModeComfortName
     or
     sHeatingMode == sHeatingModeEcoName
   )
   then
            -- Inits
            bPresence = false
            fSetPointTemp = 7

            -- Check for presence
            sPresenceDeviceStatus = otherdevices[sPresenceDeviceName]
            if ( sPresenceDeviceStatus == 'On' ) then
                   prDebug('Presence is on')
                   bPresence = true
             else
                   prDebug('Presence is off')
                   bPresence = false
            end

            -- Comfort mode, set heating setpoint to thermostat value, only applies if Presence is true.
            if( (sHeatingMode == sHeatingModeComfortName) and bPresence ) then
                fSetPointTemp = tonumber(otherdevices_svalues[sSetPointConfortDeviceName])
                prDebug ('Heating in *Comfort mode*, Setpoint : '..fSetPointTemp..' at '..sCurrentTime)
            end

            -- Eco mode, setpoint adjusted. Use this setpoint if no Presence.
            if( sHeatingMode == sHeatingModeEcoName or bPresence == false) then
               fSetPointTemp = tonumber(otherdevices_svalues[sSetPointEcoDeviceName])
                prDebug ('Heating in *Eco mode*, Setpoint : '..fSetPointTemp..' at '..sCurrentTime)
            end
                        -- Control mode

            local sControlMode = otherdevices[sHeatingControlModeDeviceName]
            prDebug('Heating Control mode : ' .. sControlMode)

            if( sControlMode == sHeatingControlModeHysteresisName ) then -- Control mode set to hysteresis

                             -- Decision to heat or not

                             -- Is it cold ?
                             if(fCurrentTemp <= (fSetPointTemp - fHysteresis) ) then
                                 prDebug ('Heating needed with delta : ' .. fCurrentTemp - fSetPointTemp)
                                 -- startHeating(aHeatingDeviceNames) --GH get rid of variable
                                 commandHeating(sHeatingOnCommand)
                            end

                             -- Is it warm ?
                            if(fCurrentTemp >= (fSetPointTemp + fHysteresis) ) then
                                 prDebug ('Stopping heating needed with delta : ' .. fCurrentTemp - fSetPointTemp)
                                 -- stoptHeating(aHeatingDeviceNames)
                                 commandHeating(sHeatingOffCommand)
                            end
             end

            if( sControlMode == sHeatingControlModePIDName ) then -- Control mode set to PID
                   -- We control the execution frequency
                   if( sCurrentMinute % iHeatingCycleDuration == 0) then -- We run the cycle

                                -- Set PID coefficients according to sample time
                                local fPIDTKi = fPIDKi * iHeatingCycleDuration * 60
                                local fPIDTKd = fPIDKd / (iHeatingCycleDuration * 60)
                                -- Current temperature error
                                 fTempError = fSetPointTemp - fCurrentTemp
                                 -- Compute new Integral
                                        -- If Setpoint changed, reset the integral action
                                         if( fSetPointTemp ~= tonumber(uservariables['fSetpointLast']) ) then
                                          fISum=0
                                         else
                                          -- Get the last Integral
                                          fISum = uservariables['fISumLast']
                                         end
                                 fISum = fISum + (fPIDTKi * fTempError)
                                 -- if(fISum > 255) then fISum = 255 end
                                 if(fISum > 255) then fISum = 255 end -- Integral limitation
                                 if(fISum < 0) then fISum = 0 end
                                 -- Derivative computation
                                 local fDeltaInput = fCurrentTemp - uservariables['fTempLastInput']  -- to number
                                 -- Sum up the PID output
                                 local fPIDOutput = fPIDKp * fTempError + fISum - fPIDTKd * fDeltaInput
                                 prDebug('PID Output : fPIDKp * fTempError = ' ..fPIDKp..' * '..fTempError..' = '..fPIDKp*fTempError..', fISum + '..fPIDTKi * fTempError..'  = '..fISum..', -fPIDTKd * fDeltaInput = '..fPIDTKd..' * '..fDeltaInput..' = -' .. fPIDTKd*fDeltaInput..', Output : '..fPIDOutput)
                                 if(fPIDOutput > 255) then fPIDOutput = 255 end
                                 if(fPIDOutput < 0) then fPIDOutput = 0 end
                                 -- Update user variables for next cycle
                                 addCommand('Variable:fTempLastInput',tostring(fCurrentTemp))
                                 addCommand('Variable:fISumLast',tostring(fISum))
                                 addCommand('Variable:fSetpointLast',tostring(fSetPointTemp))
                                 
                                  -- Heating cycle duration calculation
                                 if( fPIDOutput > 0 ) then -- heat
                                    fCycleDuration = round(fPIDOutput * iHeatingCycleDuration / 255,0)
                                    if( fCycleDuration == 0 ) then fCycleDuration = 1 end -- Heating is needed, let's go for at least 1 minute
                                    prDebug('Going to heat for : ' ..fCycleDuration..' minutes during the next '..round(iHeatingCycleDuration*60)..' seconds ('..iHeatingCycleDuration..' minutes) period.' )
                                    commandHeating(sHeatingOnForCommand,fCycleDuration)
                                  else -- Output null or negative, stop the heating
                                    prDebug('No heating needed')
                                    commandHeating(sHeatingOffCommand)
                                 end

            end -- Time period
       end -- PID mode
end

-- Heating forced on
if ( sHeatingMode == sHeatingModeForceOnName )
   then
            prDebug('Heaters forced On')
            commandHeating(sHeatingOnCommand)
end

-- Heating forced off
if ( sHeatingMode == sHeatingModeFrostFreeName )
   then
            prDebug('Heaters forced Off - Anti-frost mode')
            commandHeating(sHeatingOffCommand)
end

return commandArray


