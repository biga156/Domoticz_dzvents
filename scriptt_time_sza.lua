
--https://itechnofrance.wordpress.com/2017/01/26/dtecter-la-prsence-grce-au-wifi-du-tlphone-avec-domoticz/
--name: script_time_xxx.lua ->  (xxx ce que vous voulez) afin d’indiquer à Domoticz qu’il sera exécuté chaque minute.
--copy: domoticz/scripts/lua


commandArray = {}

--ping_success=os.execute('sudo arping -q -c3 192.168.1.13 -W 1')
ping_success=os.execute('ping -c1 192.168.1.13')
if ping_success then
    if ( otherdevices['Phone Szabi'] == 'Off') then
           commandArray['Phone Szabi']='On'
    end

else
    if (otherdevices['Phone Szabi'] == 'On') then
           commandArray['Phone Szabi']='Off'
    end
end

return commandArray