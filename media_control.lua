

return { 
    on = {
        timer = { 'every 5 minutes' },
        devices = {
            'WallPlug',
            'ManInTheHousee',
            'MediaFogyasztas'
            
        } 
    },
    
    
    execute = function(domoticz, device, triggerInfo)
    
    local mSwitch = domoticz.devices('WallPlug')
    local presSwitch = domoticz.devices('ManInTheHouse')
    local consomption = domoticz.devices('MediaFogyasztas')
       local lim= 20
    local val=lim+5
    
    local consomptionValue = tonumber(consomption.state)
        
------------------------Setup-----------------------
	
		if (triggerInfo.type == domoticz.EVENT_TYPE_DEVICE) then

			if (domoticz.devices('WallPlug').changed) then
                
                if(mSwitch.state=='On') then
                    
                    consomptionValue.update(val).forMin(5)
                end
          else
		    	return
			end
		end

------------------------Logic1 - Reinitit-----------------------
	

		--if (mSwitch.state == nil or mSwitch.state == 'Off') then
            --man.update(false)
        
        
		--	return 
		--end
----------------------------------------------------------
     
    --if(presSwitch.state=='Off' or consomptionValue<lim) then
    if(consomptionValue<lim) then
        
        mSwitch.switchOff().checkFirst()
  
     end
end
}

   