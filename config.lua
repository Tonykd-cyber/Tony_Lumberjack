Config = {}

lib.locale()

Config.LicenseEnable = false 
 
Config.CircleZones = {
    WoodField = {coords = vector3(2048.6577, 2808.8257, 50.2864), name = '伐木场', color = 56, sprite = 238, radius = 80.0},
 
}

Config.StartZones = {
    WoodStart = {coords = vector3(180.1566, 2793.3364, 44.6552), name = '伐木', color = 56, sprite = 238},
    Woodadd = {coords = vector3(-528.7129, 5298.0332, 74.1741), name = '伐木加工', color = 56, sprite = 238},
    Woodsell = {coords = vector3(1197.4633, -1301.4375, 34.1957), name = '伐木出售', color = 56, sprite = 238},
}


Config.Pedlocation = {  
    {Coords = vector3(180.1566, 2793.3364, 45.6552), h = 270.7433},   
    {Coords = vector3(1197.4633, -1301.4375, 35.1957), h = 130.0828},   
}

Config.Postalped = {
    `s_m_y_airworker` 
}


Config.vehicle = {
    vector3(184.7253, 2797.9895, 45.6552),
    heading = 271.3849
}

Config.spawnpack = {
    center = vector3(-531.2314, 5290.2490, 74.2039),  -- 建议Z值使用预估地面高度
    radius = 2.0,
    minCount = 1,
    maxCount = 2
  }