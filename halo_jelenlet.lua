return {
	on = {
        timer = { 'every 2 minutes' },
		devices = {
			'Phone Viki',
			'Phone Gabi',
			'Haloszoba_Termosztat'
		}
	},
    active = true,
    execute = function(domoticz, device)

	local targettemp=domoticz.devices('Haloszoba_Termosztat')
    local viki = domoticz.devices('Phone Viki')
	local gabi = domoticz.devices('Phone Gabi')
	local nappali=domoticz.devices('Nappali_ Termosztát')
	

	if('between 06:30 and 22:30') then
	    if(viki.state=='On' or gabi.state=='On') then
			targettemp.updateSetPoint(22) 
			domoticz.log('Device ' .. 'Haloszoba_Termosztat' .. ' was changed', domoticz.LOG_INFO)
		else 
			 targettemp.updateSetPoint(19) 
			
		end
	else
		targettemp.updateSetPoint(19) 
		
	end

end
}