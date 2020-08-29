
--https://itechnofrance.wordpress.com/2017/01/26/dtecter-la-prsence-grce-au-wifi-du-tlphone-avec-domoticz/
--name: script_time_xxx.lua ->  (xxx ce que vous voulez) afin d’indiquer à Domoticz qu’il sera exécuté chaque minute.
--copy: domoticz/scripts/lua


commandArray = {}

--ping_success=os.execute('sudo arping -q -c5 192.168.1.82 -W 1')
ping_success=os.execute('ping -c4 192.168.1.82')
if ping_success then
    if ( otherdevices['Phone Zsu'] == 'Off') then
           commandArray['Phone Zsu']='On'
    end

else
    if (otherdevices['Phone Zsu'] == 'On') then
           commandArray['Phone Zsu']='Off'
    end
end

return commandArray