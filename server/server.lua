ESX = exports["es_extended"]:getSharedObject()

local ox_inventory = exports.ox_inventory
lib.locale()

 

local function ValidatePickupCannabis(src)
	local ECoords = Config.CircleZones.WeedField.coords
	local PCoords = GetEntityCoords(GetPlayerPed(src))
	local Dist = #(PCoords-ECoords)
	if Dist <= 90 then return true end
end

 
local function FoundExploiter(src,reason)
	-- ADD YOUR BAN EVENT HERE UNTIL THEN IT WILL ONLY KICK THE PLAYER --
	DropPlayer(src,reason)
end

RegisterServerEvent('Tony:lumberaddtrunk')
AddEventHandler('Tony:lumberaddtrunk', function(plate)
	local src = source
    ox_inventory:AddItem('trunk'..plate, 'wood_log', 1) 
end)

RegisterServerEvent('Tony:plank')
AddEventHandler('Tony:plank', function(plate)
	local src = source
    ox_inventory:AddItem('trunk'..plate, 'woodplank', 1) 
end)

RegisterServerEvent('Tony:woodlog')
AddEventHandler('Tony:woodlog', function()
	local src = source
 	ox_inventory:RemoveItem(src,'wood_log', 1) 
end)

RegisterServerEvent('Tony:sell')
AddEventHandler('Tony:sell', function()
 

	 local src = source
	 local plank = ox_inventory:Search(src, 'count', 'woodplank')
	 print(plank)
	 if plank >= 1 then
 
	 ox_inventory:RemoveItem(src, 'woodplank', plank)
	 ox_inventory:AddItem(src, 'money',plank *100 )
	 end
end)

ox_inventory:RegisterShop('LumberjackShop', {
    name = '伐木商店',
    inventory = {
        { name = 'electric_saw', price = 500 },
    } 
})