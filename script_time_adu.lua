
--https://itechnofrance.wordpress.com/2017/01/26/dtecter-la-prsence-grce-au-wifi-du-tlphone-avec-domoticz/
--name: script_time_xxx.lua ->  (xxx ce que vous voulez) afin d’indiquer à Domoticz qu’il sera exécuté chaque minute.
--copy: domoticz/scripts/lua
--Viki-Gabi

commandArray = {}

--ping_success=os.execute('sudo arping -q -c3 192.168.1.138 -W 5')
ping_success=os.execute('ping -c3 192.168.1.138')
if ping_success then
    if ( otherdevices['Phone Viki'] == 'Off') then
           commandArray['Phone Viki']='On'
    end

else
    if (otherdevices['Phone Viki'] == 'On') then
           commandArray['Phone Viki']='Off'
    end
end

--ping_success=os.execute('sudo arping -q -c3 192.168.1.93 -W 5')
ping_success=os.execute('ping -c3 192.168.1.93')
if ping_success then
    if ( otherdevices['Phone Gabi'] == 'Off') then
           commandArray['Phone Gabi']='On'
    end

else
    if (otherdevices['Phone Gabi'] == 'On') then
           commandArray['Phone Gabi']='Off'
    end
end
return commandArray