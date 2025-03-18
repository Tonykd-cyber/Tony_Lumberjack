ESX = exports["es_extended"]:getSharedObject()

---@param entity number
---@param coords vector3
---@param door number
---@param useOffset boolean?
---@return boolean?

local ox_inventory = exports.ox_inventory
local ox_target = exports.ox_target
lib.locale()

xSound = exports.xsound

local spawnedWeeds = 0
local weedPlants = {}
 
local picktree = false
local hasTargetAdded = false
local hasTargetAddeds = false
local woodlong = nil
local DropObject = nil
 
local function canInteractWithDoor(entity, coords, door, useOffset)
    if not GetIsDoorValid(entity, door) or GetVehicleDoorLockStatus(entity) > 1 or IsVehicleDoorDamaged(entity, door) or cache.vehicle then return end
    if useOffset then return true end
    local boneName = bones[door]
    if not boneName then return false end
    boneId = GetEntityBoneIndexByName(entity, 'door_' .. boneName)
    if boneId ~= -1 then
        return #(coords - GetEntityBonePosition_2(entity, boneId)) < 0.5 or
        #(coords - GetEntityBonePosition_2(entity, GetEntityBoneIndexByName(entity, 'seat_' .. boneName))) < 0.72
    end
end


Citizen.CreateThread(function()
    for _, zone in pairs(Config.StartZones) do
        local blip = AddBlipForCoord(zone.coords)
        SetBlipSprite(blip, zone.sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.8)
        SetBlipColour(blip, zone.color)
        SetBlipAsShortRange(blip, true)
        
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(zone.name)
        EndTextCommandSetBlipName(blip)
    end
end)


function CreateBlipCircle(coords, text, radius, color, sprite)
	local blip = AddBlipForRadius(coords, radius)
	SetBlipHighDetail(blip, true)
	SetBlipColour(blip, 56)
	SetBlipAlpha (blip, 128)
	blip = AddBlipForCoord(coords)
	SetBlipHighDetail(blip, true)
	SetBlipSprite (blip, sprite)
	SetBlipScale  (blip, 0.8)
	SetBlipColour (blip, color)
	SetBlipAsShortRange(blip, true)
	BeginTextCommandSetBlipName("STRING")
	AddTextComponentSubstringPlayerName(text)
	EndTextCommandSetBlipName(blip)
end

local pedspawned = {} -- 用于存储每个位置的 NPC 引用
-- 配置缓冲距离防止边界抖动
local SPAWN_DISTANCE = 40.0   -- 生成触发距离
local DESPAWN_DISTANCE = 45.0  -- 消失触发距离（必须大于生成距离）
local CHECK_INTERVAL = 500     -- 检测间隔(ms)

-- 预加载所有NPC模型（资源启动时执行）
Citizen.CreateThread(function()
    for _, hash in ipairs(Config.Postalped) do
        RequestModel(hash)
        while not HasModelLoaded(hash) do
            Citizen.Wait(10)
        end
    end
end)

-- 主控制线程优化
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(CHECK_INTERVAL) -- 降低检测频率
        
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)

        for k, v in pairs(Config.Pedlocation) do
            local dist = #(v.Coords - playerCoords)
            local currentState = pedspawned[k]

            -- 状态机逻辑处理
            if dist < SPAWN_DISTANCE and not currentState then
                -- 异步生成防止阻塞
                Citizen.CreateThread(function()
                    TriggerEvent('Tony:lumberjackpedspawn', k, v.Coords, v.h)
                end)
            elseif dist >= DESPAWN_DISTANCE and currentState then
                -- 安全删除实体
                if DoesEntityExist(currentState) then
                    DeletePed(currentState)
                end
                pedspawned[k] = nil
            end
        end
    end
end)

-- NPC生成事件优化
RegisterNetEvent('Tony:lumberjackpedspawn')
AddEventHandler('Tony:lumberjackpedspawn', function(key, coords, heading)
    -- 二次验证防止重复生成
    if pedspawned[key] then return end

    local hash = Config.Postalped[math.random(#Config.Postalped)]
    
    -- 强化模型加载验证
    if not HasModelLoaded(hash) then
        RequestModel(hash)
        local timeout = 2000 -- 2秒超时
        while not HasModelLoaded(hash) and timeout > 0 do
            timeout = timeout - 10
            Citizen.Wait(10)
        end
    end

    -- 实体创建保护
    if HasModelLoaded(hash) then
        local npc = CreatePed(5, hash, coords.x, coords.y, coords.z, heading, false, false)
        
        -- 实体属性设置
        SetEntityAsMissionEntity(npc, true, true)
        FreezeEntityPosition(npc, true)
        SetBlockingOfNonTemporaryEvents(npc, true)
        SetEntityInvincible(npc, true)
        
        -- 坐标修正
        SetEntityCoordsNoOffset(npc, coords.x, coords.y, coords.z, false, false, false)
        
        -- 存储引用
        pedspawned[key] = npc
    else
        print("模型加载失败:", hash)
    end
end)


CreateThread(function()
	for k,zone in pairs(Config.CircleZones) do
		CreateBlipCircle(zone.coords, zone.name, zone.radius, zone.color, zone.sprite)
	end
end)

CreateThread(function()
    while true do
        Wait(500)  -- 适当降低检测频率
        local coords = GetEntityCoords(PlayerPedId())
        local inZone = (#(coords - Config.CircleZones.WoodField.coords) < 80)

        -- 当状态发生改变时执行操作
        if inZone ~= picktree then
            picktree = inZone
            picktreedd()
            print(picktree and '进入区域' or '离开区域')
        end

        if picktree then
            SpawnWeedPlants()  -- 确保生成植物的逻辑需要频繁执行
        end
    end
end)
 

CreateThread(function()
    while true do
        Wait(500)  -- 适当降低检测频率
        local coords = GetEntityCoords(PlayerPedId())
        local inZonepack = (#(coords - Config.spawnpack.center) < 50)

        -- 当状态发生改变时执行操作
        if inZonepack ~= picktreepack then
            picktreepack = inZonepack
            picktreedddpc()
            print(picktreepack)
        end
 
    end
end)


function picktreedddpc()
      if picktreepack then
		ox_target:addModel('bzzz_lumberjack_wood_pack_2d', {
			{
				name = 'additempack',   -- 唯一标识符
				event = "Tony:additempack",
				icon = "fa-solid fa-cube",
				label = locale('A5'),
				distance = 1.5
			}
		}) 

		ox_target:addGlobalVehicle({
			{
				name = 'packtrunk',
				icon = 'fa-solid fa-leaf',
				label = locale('A6'),
				offset = vec3(0.5, 0, 0.5),
				distance = 2,
				canInteract = function(entity, distance, coords, name)
					return canInteractWithDoor(entity, coords, 5, true)
				end,
				onSelect = function(data)
					Packrunk()
				end
			}
		})
		
	  else
		ox_target:removeModel('bzzz_lumberjack_wood_pack_2d', 'additempack')
		ox_target:removeGlobalVehicle('packtrunk')
	  end	
end

function picktreedd()
    if picktree then
        if not hasTargetAdded then
            addoxtarger()
            hasTargetAdded = true
        end
    else
        if hasTargetAdded then
			removetarger()
            hasTargetAdded = false
        end
    end
end
 
function canPickUp()
	local electric_saw = exports.ox_inventory:Search('count', 'electric_saw')
    if electric_saw >= 1 then
		local playerPed = PlayerPedId()
		local coords = GetEntityCoords(playerPed)
		local nearbyObject, nearbyID
		
		-- 开始播放木屑粒子效果
		local particleDict = "core"  -- 粒子效果字典
		local particleName = "ent_sht_steam"  -- 粒子效果名称
		RequestNamedPtfxAsset(particleDict)
		while not HasNamedPtfxAssetLoaded(particleDict) do
			Wait(0)
		end
		UseParticleFxAssetNextCall(particleDict)

		-- 找到右手的骨骼索引
		local handBoneIndex = GetEntityBoneIndexByName(playerPed, "SKEL_L_Finger01")

		-- 生成粒子效果并附加到玩家的手上
		local particleId = StartParticleFxLoopedOnEntity(
			particleName,
			playerPed,
			0.35,  -- 相对位置（X）
			0.6,   -- 相对位置（Y）
			-0.3,   -- 相对位置（Z）
			0.0,   -- 旋转（横向）
			1.0,   -- 旋转（纵向）
			0.0,   -- 旋转（垂直）
			2.0,   -- 尺寸
			false,
			false,
			false
		)

		-- 播放音效
		xSound:PlayUrlPos("name", "./sounds/fast3.ogg", 0.2, coords)

		-- 查找附近的植物
		for i = 1, #weedPlants, 1 do
			if #(coords - GetEntityCoords(weedPlants[i])) < 4.5 then
				nearbyObject, nearbyID = weedPlants[i], i
				break -- 找到后立即退出循环
			end
		end

		-- 进度条设置与使用
		if lib.progressBar({
			label =locale('A7'),
			duration = 7000,  -- 进度条时长
			position = 'bottom',
			useWhileDead = false,
			canCancel = false,
			disable = { car = true, move = true, combat = true },
		--	anim = { dict = 'bzzz_animation_chainsaw', clip = 'animation_chainsaw' },
		--	prop = { model = 'bzzz_prop_wood_chainsaw', bone = 57005, pos = vec3(0.22, 0.41, 0.1), rot = vec3(-8.0, 309.0, -27.0) }
			anim = { dict = 'anim@heists@fleeca_bank@drilling', clip = 'drill_straight_fail' },
	    	prop = { model = 'prop_tool_consaw', bone = 28422, pos = vec3(0.00, 0.00, 0.00), rot = vec3(0.00, 0.00, 90.00) }
		}) then
			ESX.Game.DeleteObject(nearbyObject)
			table.remove(weedPlants, nearbyID)
			spawnedWeeds = spawnedWeeds - 1
			-- 停止播放音效和粒子效果
			xSound:Destroy("name")
			StopParticleFxLooped(particleId, 0)
			woodadd()
		end   
	else
		lib.notify({
			id = 'no_electricsaw',
			title = locale('A8'),
			description =  locale('A9'),
			showDuration = 3000,
			position = 'top',
			style = {
				backgroundColor = '#0d0d0d',
				color = '#fafafa',
				['.description'] = {
				  color = '#fafafa'
				}
			},
			icon = 'fa-solid fa-leaf',
			iconColor = '#fafafa'
		})
		
	end	
end

function SpawnWeedPlants()
	while spawnedWeeds < 25 do
		Wait(0)
		local weedCoords = GenerateWeedCoords()
		ESX.Game.SpawnLocalObject('prop_tree_cedar_03', weedCoords, function(obj)
			PlaceObjectOnGroundProperly(obj)
			FreezeEntityPosition(obj, true)
			table.insert(weedPlants, obj)
			spawnedWeeds = spawnedWeeds + 1
		end)
	end
end

function GenerateWeedCoords()
	while true do
		Wait(0)
		local weedCoordX, weedCoordY
		math.randomseed(GetGameTimer())
		local modX = math.random(-90, 90)
		Wait(100)
		math.randomseed(GetGameTimer())
		local modY = math.random(-90, 90)
		weedCoordX = Config.CircleZones.WoodField.coords.x + modX  
		weedCoordY = Config.CircleZones.WoodField.coords.y + modY  
		local coordZ = GetCoordZ(weedCoordX, weedCoordY) - 2
		local coord = vector3(weedCoordX, weedCoordY, coordZ) 
		if ValidateWeedCoord(coord) then
			return coord
		end
	end
end

function GetCoordZ(x, y)
	local groundCheckHeights = { 48.0, 49.0, 50.0, 51.0, 52.0, 53.0, 54.0, 55.0, 56.0, 57.0, 58.0 }
	for i, height in ipairs(groundCheckHeights) do
		local foundGround, z = GetGroundZFor_3dCoord(x, y, height)

		if foundGround then
			return z
		end
	end
	return 43.0
end

function ValidateWeedCoord(plantCoord)
	if spawnedWeeds > 0 then
		local validate = true
		for k, v in pairs(weedPlants) do
			if #(plantCoord - GetEntityCoords(v)) < 5 then
				validate = false
			end
		end
		if #(plantCoord - Config.CircleZones.WoodField.coords) > 50 then
			validate = false
		end
		return validate
	else
		return true
	end
end

AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() then
		for k, v in pairs(weedPlants) do
			ESX.Game.DeleteObject(v)
		end
		woodremove()
	end
end)

 
 

function woodadd()
 	 ox_target:addModel('bzzz_lumberjack_wood_pack_1a_dynamic', {
		{
			name = 'addwood_long',
			onSelect = function()
				woodaddcar()
			end,
			icon = 'fa-solid fa-leaf',
			label = locale('A5'),
			distance = 4.5
		}
	}) 
	local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local playerHeading = GetEntityHeading(playerPed)
    local propModel = 'bzzz_lumberjack_wood_pack_1a_dynamic'
    local forwardVector = GetEntityForwardVector(playerPed)
    local spawnPos = playerCoords + (forwardVector * 0.65)
    spawnPos = vector3(spawnPos.x+0.5, spawnPos.y-0.5, playerCoords.z) -- 保持相同高度
	ESX.Game.SpawnLocalObject(propModel, spawnPos, function(object)
		print(DoesEntityExist(object), 'this code is async!')
		 PlaceObjectOnGroundProperly(object)
		 DropObject = object
	end)
	 
 
end	

function woodremove()
	local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    if DropObject then
        -- 安全删除对象（处理网络实体）
        if NetworkGetEntityIsNetworked(DropObject) then
            DeleteEntity(DropObject)  -- 网络实体需用 DeleteEntity
        else
            SetEntityAsMissionEntity(DropObject, true, true)
            DeleteObject(DropObject)
        end
    else
    end
end	
local haswoodlog = false
function woodaddcar()
	ox_target:removeModel('bzzz_lumberjack_wood_pack_1a_dynamic', 'addwood_long')
		woodremove()
		haswoodlog = true
		local ped = PlayerPedId()
		local x, y, z = table.unpack(GetOffsetFromEntityInWorldCoords(ped, 0.0, 3.0, 0.5))
		local hash = GetHashKey('bzzz_lumberjack_wood_pack_1a_dynamic')

		if DoesEntityExist(woodlong) then
			DetachEntity(woodlong, false, false)
			DeleteEntity(woodlong)
			woodlong = nil
		end
	
		RequestModel(hash)
		while not HasModelLoaded(hash) do 
			Citizen.Wait(0) 
		end

		woodlong = CreateObjectNoOffset(hash, x, y, z, true, false)
		SetModelAsNoLongerNeeded(hash)

		LoadAnimDict("missfinale_c2mcs_1")
		AttachEntityToEntity(woodlong, ped, GetPedBoneIndex(ped, 28422),  0.3, -0.25, 0.0, 90.0, 90.0, 0.0, 0.0,false, false, true, false, 2, true)
		if not IsEntityPlayingAnim(ped, 'missfinale_c2mcs_1', 'fin_c2_mcs_1_camman', 3) then
			TaskPlayAnim(ped, 'missfinale_c2mcs_1', 'fin_c2_mcs_1_camman',8.0, 8.0, -1, 50, 0, false, false, false)
		end
  
end

function woodlogremove()
	local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)
    if DoesEntityExist(woodlong) then
        DetachEntity(woodlong, false, false)
        DeleteEntity(woodlong)
        woodlong = nil
    end
    ClearPedTasks(ped)
    RemoveAnimDict("missfinale_c2mcs_1")
end	

function LoadAnimDict(dict)
    while (not HasAnimDictLoaded(dict)) do
        RequestAnimDict(dict)
        Citizen.Wait(10)
    end
end

-- 事件处理：添加后备箱
function lumberaddtrunk()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    -- 获取离玩家最近的车辆
    local vehicle = ESX.Game.GetClosestVehicle(playerCoords)
	local rebelodel = `rebel`
	local isVehicleTow = IsVehicleModel(vehicle, rebelodel)
	if isVehicleTow and DoesEntityExist(vehicle) and haswoodlog then
		local vehicleProperties = ESX.Game.GetVehicleProperties(vehicle)
		local plate = vehicleProperties.plate
        print(plate)
		TriggerServerEvent('Tony:lumberaddtrunk',plate)
		haswoodlog = false
	else
		print("未找到最近的车辆！")
	end	
	if DoesEntityExist(woodlong) then
        DetachEntity(woodlong, false, false)
        DeleteEntity(woodlong)
        woodlong = nil
    end
    -- 停止动画
    ClearPedTasks(playerPed)
    RemoveAnimDict("missfinale_c2mcs_1")
end

function addoxtarger()
	ox_target:addModel('prop_tree_cedar_03', {
		{
			name = 'picktree',
			onSelect = function()
				canPickUp()
			end,
			icon = 'fa-solid fa-leaf',
			label = locale('A10'),
			distance = 4.5
		}
	}) 

	--[[ox_target:addModel('bzzz_lumberjack_wood_pack_1a_dynamic', {
		{
			name = 'addwood_long',
			onSelect = function()
				woodaddcar()
			end,
			icon = 'fa-solid fa-leaf',
			label = '捡起',
			distance = 4.5
		}
	}) ]]

	ox_target:addGlobalVehicle({
		{
			name = 'lumberaddtrunk',
			icon = 'fa-solid fa-leaf',
			label = locale('A11'),
			offset = vec3(0.5, 0, 0.5),
			distance = 2,
			canInteract = function(entity, distance, coords, name)
				return canInteractWithDoor(entity, coords, 5, true)
			end,
			onSelect = function(data)
				lumberaddtrunk()
			end
		}
	})
	print('添加目标选项')
end	
 
function removetarger()
	ox_target:removeModel('prop_tree_cedar_03', 'picktree')
	--ox_target:removeModel('bzzz_lumberjack_wood_pack_1a_dynamic', 'addwood_long')
	ox_target:removeGlobalVehicle('lumberaddtrunk')
	print('移除目标选项')
end	



ox_target:addBoxZone({

    coords = vec3(180.1566, 2793.3364, 45.6552),
    size = vec3(2, 2, 2),
    rotation = 270.7433,
    debug = false,
    drawSprite = true,
    options = {
        {
            name = 'Tonylumberjack_SpawnVehicle',
			icon = 'fa-solid fa-leaf',
			label = locale('A12'),
            distance = 2.0,
			onSelect = function()
				SpawnVehicle()
			end
        },
		{
            name = 'Tonylumberjack_DeleteVehicle',
			icon = 'fa-solid fa-leaf',
			label = locale('A13'),
            distance = 2.0,
			onSelect = function()
				DeleteVehicle()
			end
        },
		{
            name = 'Tonylumberjack_Shot',
			icon = 'fa-solid fa-leaf',
			label = locale('A14'),
            distance = 2.0,
			onSelect = function()
				exports.ox_inventory:openInventory('shop', { type = 'LumberjackShop'})
			end
        }
    }
})

ox_target:addBoxZone({ 
    coords = vec3(1197.4633, -1301.4375, 35.1957),
    size = vec3(2, 2, 2),
    rotation = 130.0828,
    debug = false,
    drawSprite = true,
    options = {
        {
            name = 'woodlog',
			icon = 'fa-solid fa-leaf',
			label = locale('A15'),
            distance = 2.0,
			event = 'Tony:sell'
        } 
    }
})

ox_target:addBoxZone({ 
	name = "Tonyremovelu",
	coords = vec3(-533.2, 5293.1, 74.3),
	size = vec3(2, 2, 2),
	rotation = 354.2,
	debug = false,
	drawSprite = true,
	options = {
		{
			name = 'Tonylumberjack_SpawnVehicle',
			icon = 'fa-solid fa-leaf',
			label = locale('A16'),
			distance = 2.0,
			onSelect = function()
				woodlogcut()
			end
		} 
	}
})

function addTonyremovelu()
	ox_target:addBoxZone({ 
		name = "Tonyremovelu",
		coords = vec3(-533.2, 5293.1, 74.3),
		size = vec3(2, 2, 2),
		rotation = 354.2,
		debug = false,
		drawSprite = true,
		options = {
			{
				name = 'Tonylumberjack_SpawnVehicle',
				icon = 'fa-solid fa-leaf',
				label = locale('A16'),
				distance = 2.0,
				onSelect = function()
					woodlogcut()
				end
			} 
		}
	})
end	

local spawnedVehicle = nil
local prisonCoords = Config.CircleZones.WoodField.coords -- 监狱坐标
local markerDistance = 10.0 -- 距离监狱的触发距离
local pathSet = false -- 是否已设置路径点

function SpawnVehicle()
    ESX.Game.SpawnVehicle('rebel', Config.vehicle[1], Config.vehicle.heading, function(vehicle)
        spawnedVehicle = vehicle
        Citizen.Wait(100)  
        SetVehicleDoorsLocked(vehicle, 0)
        SetVehicleDoorsLockedForAllPlayers(vehicle, false)
        SetVehicleNeedsToBeHotwired(vehicle, false)
        SetPedIntoVehicle(PlayerPedId(), vehicle, -1)
        print("Door lock status:", GetVehicleDoorLockStatus(vehicle))

        -- 设置路径点到监狱
        SetNewWaypoint(prisonCoords.x, prisonCoords.y) 
        pathSet = true
        print("路径点已设置")
    end)
end

function DeleteVehicle()
	if DoesEntityExist(spawnedVehicle) then  
        ESX.Game.DeleteVehicle(spawnedVehicle)
        spawnedVehicle = nil  
        print("车辆已删除")
    else
        print("没有可删除的车辆")
    end
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0) -- 每帧循环

        local playerPed = PlayerPedId() -- 获取玩家角色
        local playerCoords = GetEntityCoords(playerPed) -- 获取玩家坐标
 
        -- 检查玩家是否靠近监狱
        if Vdist(playerCoords, prisonCoords) < markerDistance then
            -- 如果玩家到达了监狱，清除路径点
            if pathSet then
                ClearGpsPlayerWaypoint()
                pathSet = false
                print("到达监狱，路径点已清除")
            end
        end
    end
end)

woodcut = nil
function woodlogcut()
	 
	local playerPed = PlayerPedId()
	local coords = GetEntityCoords(playerPed)
	local wood_log = exports.ox_inventory:Search('count', 'wood_log')
	if wood_log >=1 then
 		TriggerServerEvent('Tony:woodlog')
		xSound:PlayUrlPos("cut", "./sounds/woodcut.ogg", 0.5, coords)
		ox_target:removeZone("Tonyremovelu")
		local playerPed = PlayerPedId()
		local spawnPos = vector3(-533.486, 5292.797, 74.2) -- 保持相同高度
		local propModel = 'bzzz_lumberjack_wood_pack_2b'
		local particleDict = "core" -- 在此替换为您的粒子文件字典
		local particleName = "ent_sht_steam" -- 在此替换为您的粒子名称
		local scenario = 'PROP_HUMAN_PARKING_METER' -- Scenario to be played

		-- 预加载粒子效果字典
		RequestNamedPtfxAsset(particleDict)
		while not HasNamedPtfxAssetLoaded(particleDict) do
			Wait(0)
		end

		-- Play the scenario
		TaskStartScenarioInPlace(playerPed, scenario, 0, true)
		
		ESX.Game.SpawnLocalObject(propModel, spawnPos, function(object)
			print(DoesEntityExist(object), 'this code is async!')
			-- SetEntityCollision(object, false, false)
			-- 设置旋转
			local rotation = vector3(0.000, 77.787, 0.000) -- 旋转角度
			SetEntityRotation(object, rotation, 2, true) -- 设置物体旋转

			-- 启动粒子效果
			UseParticleFxAssetNextCall(particleDict)
			
			-- 对象上生成粒子效果
			local particleId = StartParticleFxLoopedOnEntity(
				particleName,
				object,  -- 将粒子效果附加到生成的对象
				0.0,     -- 相对位置（X）
				0.0,     -- 相对位置（Y）
				0.0,     -- 相对位置（Z）
				0.0,     -- 旋转（横向）
				1.0,     -- 旋转（纵向）
				0.0,     -- 旋转（垂直）
				1.0,     -- 尺寸
				false,
				false,
				false
			)
			
			-- 让物体沿X轴移动2米
			local moveDistance = 0.01 -- 每次循环移动的距离
			local totalDistanceMoved = 0.0 -- 总移动距离
			while DoesEntityExist(object) and totalDistanceMoved < 0.7 do
				Wait(100) -- 等待一段时间以控制移动速度
				local currentCoords = GetEntityCoords(object)
				-- 更新物体坐标
				SetEntityCoords(object, currentCoords.x + moveDistance, currentCoords.y, currentCoords.z, false, false, false, false)
				totalDistanceMoved = totalDistanceMoved + moveDistance -- 更新总移动距离
			end
			
			-- 停止粒子效果并清理对象
			exports.xsound:Destroy("cut")
			StopParticleFxLooped(particleId, 0) -- 停止粒子效果
			DeleteObject(object) -- 删除对象
			
			-- Stop the scenario
			ClearPedTasks(playerPed) -- Stop the scenario
			addTonyremovelu()
			plankdrop()
			 

		end)
 	else
		lib.notify({
			id = 'no_electricsaw',
			title = locale('A1'),
			description = locale('A17'),
			showDuration = 3000,
			position = 'top',
			style = {
				backgroundColor = '#0d0d0d',
				color = '#fafafa',
				['.description'] = {
				  color = '#fafafa'
				}
			},
			icon = 'fa-solid fa-leaf',
			iconColor = '#fafafa'
		})
	end		
end

function plankdrop()
    local spawnCount = math.random(Config.spawnpack.minCount, Config.spawnpack.maxCount)
    local center = Config.spawnpack.center -- 获取配置中的中心坐标

    for i = 1, spawnCount do
        local randomAngle = math.random() * math.pi * 2
        local randomDist = math.random() * Config.spawnpack.radius
        local xOffset = math.cos(randomAngle) * randomDist
        local yOffset = math.sin(randomAngle) * randomDist
        
        -- 使用配置中的中心坐标作为基准点
        local spawnPos = vector3(
            center.x + xOffset,
            center.y + yOffset,
            center.z + 1.0 -- 临时高度防止物体卡地
        )

        -- 获取准确地面高度
        local _, groundZ = GetGroundZFor_3dCoord(spawnPos.x, spawnPos.y, spawnPos.z, true)
        spawnPos = vector3(spawnPos.x, spawnPos.y, groundZ or center.z)

        ESX.Game.SpawnLocalObject('bzzz_lumberjack_wood_pack_2d', spawnPos, function(object)
            if not DoesEntityExist(object) then return end -- 实体验证
            
            -- 放置并微调位置
            PlaceObjectOnGroundProperly(object)
            SetEntityHeading(object, math.random(0.0, 360.0))
            
            -- 二次校准防止悬空
            local finalPos = GetEntityCoords(object)
            SetEntityCoords(object, finalPos.x, finalPos.y, finalPos.z + 0.05)
        end)
 
    end
	
end

 
RegisterNetEvent('Tony:additempack')
AddEventHandler('Tony:additempack', function()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local foundObject = nil

    -- 遍历所有配置模型，寻找最近的有效对象
 
        local modelHash = GetHashKey('bzzz_lumberjack_wood_pack_2d')  -- 关键修正：逐个获取模型哈希
        local object = GetClosestObjectOfType(playerCoords, 1.5, modelHash, false, false, false)

    if object ~= 0 and DoesEntityExist(object) then
            foundObject = object
		if foundObject then
			-- 安全删除对象（处理网络实体）
			if NetworkGetEntityIsNetworked(foundObject) then
				DeleteEntity(foundObject)  -- 网络实体需用 DeleteEntity
			else
				SetEntityAsMissionEntity(foundObject, true, true)
				DeleteObject(foundObject)
			end
			print("✅ 目标物体已删除")
			createBox()
		
		else
			print("❌ 未找到附近的可交互箱子")
		end
	end
end)

local box = nil
local haspack = false

function createBox()
    haspack = true
	local hash = GetHashKey('bzzz_lumberjack_wood_pack_2d')
    local ped = PlayerPedId()
    local x, y, z = table.unpack(GetOffsetFromEntityInWorldCoords(ped, 0.0, 3.0, 0.5))

    -- 清理已存在的物体
    if DoesEntityExist(box) then
        DetachEntity(box, false, false)
        DeleteEntity(box)
        box = nil
    end

    -- 加载模型
    RequestModel(hash)
    while not HasModelLoaded(hash) do 
        Citizen.Wait(0) 
    end

    -- 创建并附加箱子
    box = CreateObjectNoOffset(hash, x, y, z, true, false)
    SetModelAsNoLongerNeeded(hash)

    -- 设置物体为本地专属（不会同步给其他玩家）
    SetEntityAsMissionEntity(box, true, true)
    NetworkSetEntityInvisibleToNetwork(box, true)

    -- 加载并播放动画
    LoadAnimDict("anim@heists@box_carry@")
    AttachEntityToEntity(box, ped, GetPedBoneIndex(ped, 28422), 0.0, -0.1, -0.17, 0.0, 0.0, 90.0, 0.0, false, false, true, false, 2, true)

    if not IsEntityPlayingAnim(ped, 'anim@heists@box_carry@', 'idle', 3) then
        TaskPlayAnim(ped, 'anim@heists@box_carry@', 'idle', 
            8.0, 8.0, -1, 50, 0, false, false, false)
    end
end

 
function Packrunk()

	local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    -- 获取离玩家最近的车辆
    local vehicle = ESX.Game.GetClosestVehicle(playerCoords)
	local rebelodel = `rebel`
	local isVehicleTow = IsVehicleModel(vehicle, rebelodel)
	if isVehicleTow and DoesEntityExist(vehicle) and haspack then
		local vehicleProperties = ESX.Game.GetVehicleProperties(vehicle)
		local plate = vehicleProperties.plate
		print(plate)
		TriggerServerEvent('Tony:plank',plate)
		haspack = false
	else
		print("未找到最近的车辆！")
	end	
	if DoesEntityExist(box) then
        DetachEntity(box, false, false)
        DeleteEntity(box)
        box = nil
    end
    -- 停止动画
    ClearPedTasks(playerPed)
	RemoveAnimDict("anim@heists@box_carry@")

end
 


RegisterNetEvent('Tony:sell')
AddEventHandler('Tony:sell', function()

local plank = ox_inventory:Search('count', 'woodplank')
	if plank >= 1 then 
		if lib.progressBar({
			duration = 5000,
			label = locale('A18'),
            useWhileDead = false,
            canCancel = false,
            disable = { car = true, move = true, combat = true },
			anim = {dict = 'anim@heists@box_carry@',clip = 'idle'},
			prop = {model = `bzzz_lumberjack_wood_pack_2d`,bone = 28422,pos = vec3(0.0,-0.1,-0.17),rot = vec3(0.0,0.0,90.0)},
		}) then 
			TriggerServerEvent('Tony:sell')
		end
	else
		lib.notify({
			id = 'no_electricsaw',
			title = locale('A1'),
			description = locale('A19'),
			showDuration = 3000,
			position = 'top',
			style = {
				backgroundColor = '#0d0d0d',
				color = '#fafafa',
				['.description'] = {
				  color = '#fafafa'
				}
			},
			icon = 'fa-solid fa-leaf',
			iconColor = '#fafafa'
		})
	end	
end)	
