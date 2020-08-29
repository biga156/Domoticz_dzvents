
--https://itechnofrance.wordpress.com/2017/01/26/dtecter-la-prsence-grce-au-wifi-du-tlphone-avec-domoticz/
--name: script_time_xxx.lua ->  (xxx ce que vous voulez) afin d’indiquer à Domoticz qu’il sera exécuté chaque minute.
--copy: domoticz/scripts/lua
--Eni

commandArray = {}

--ping_success=os.execute('sudo arping -q -c3 192.168.1.8 -W 5')
ping_success=os.execute('ping -c3 192.168.1.8')
if ping_success then
    if ( otherdevices['Phone Eni'] == 'Off') then
           commandArray['Phone Eni']='On'
    end

else
    if (otherdevices['Phone Eni'] == 'On') then
           commandArray['Phone Eni']='Off'
    end
end

return commandArray