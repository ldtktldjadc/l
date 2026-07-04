if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

-- 多重ロード防止（5秒以内に連続で実行された場合は弾く）
if getgenv().ModpackRivals_Executing then return end
getgenv().ModpackRivals_Executing = true
task.delay(5, function() getgenv().ModpackRivals_Executing = false end)

local lp = Players.LocalPlayer
local cam = workspace.CurrentCamera
local PlayerGui = lp:WaitForChild("PlayerGui")
if PlayerGui:FindFirstChild("LoadingScreen") then
    repeat task.wait(0.5) until not PlayerGui:FindFirstChild("LoadingScreen")
    task.wait(1)
end

-- Cleanup old instances for re-execution
if getgenv().MyLinoriaLibrary then
    pcall(function() getgenv().MyLinoriaLibrary:Unload() end)
end
if getgenv().MyModpackESP then
    pcall(function() getgenv().MyModpackESP:Destroy() end)
end

-- ========== SILENT AIM ==========
local silentAimEnabled = false
local targetPart = "HitboxHead"
local FOV = 100
local aim360 = false
local teamCheck = false
local hitChance = 100
local targetPartsList = {"HitboxHead", "Head", "HitboxBody", "LowerTorso"}

local originalRaycast = nil

local function isPlayerAliveSA(plr)
    if not plr.Character then return false end
    local hum = plr.Character:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function getMyTeamID()
    return lp:GetAttribute("TeamID")
end

local function getPlayerTeamID(plr)
    return plr:GetAttribute("TeamID")
end

local function checkTeam(plr, isESP)
    local tc = isESP and getgenv().ESPSettings_TeamCheck or teamCheck
    if not tc then return true end
    
    local myID = getMyTeamID()
    local theirID = getPlayerTeamID(plr)
    
    if myID == nil or theirID == nil then return false end
    if myID == theirID then return false end
    
    return true
end

local function getClosestPlayerInFOV()
    if not silentAimEnabled then return nil end

    local cam = workspace.CurrentCamera
    if not cam then return nil, nil end

    local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    local bestTarget = nil
    local bestDist = math.huge
    local bestPartName = nil

    local maxDist = (FOV == 100) and math.huge or (FOV * 5)

    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= lp and isPlayerAliveSA(plr) and checkTeam(plr, false) and plr.Character then
            local partName = targetPart
            if partName == "Random" then
                local validParts = {}
                for _, name in ipairs(targetPartsList) do
                    if plr.Character:FindFirstChild(name) then
                        table.insert(validParts, name)
                    end
                end
                if #validParts > 0 then
                    partName = validParts[math.random(1, #validParts)]
                end
            end
            
            local part = plr.Character:FindFirstChild(partName)
            if part then
                local screenPos, onScreen = cam:WorldToViewportPoint(part.Position)
    
                if onScreen or aim360 then
                    local raycastParams = RaycastParams.new()
                    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
                    raycastParams.FilterDescendantsInstances = {lp.Character}
                    local ray = workspace:Raycast(cam.CFrame.Position, (part.Position - cam.CFrame.Position), raycastParams)
                    local visible = not ray or ray.Instance:IsDescendantOf(plr.Character)
    
                    if visible then
                        local dist = aim360 and (part.Position - lp.Character.HumanoidRootPart.Position).Magnitude or (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                        if dist <= maxDist and dist < bestDist then
                            bestDist = dist
                            bestTarget = plr
                            bestPartName = partName
                        end
                    end
                end
            end
        end
    end

    if bestTarget then
        return bestTarget, bestPartName
    end
    return nil, nil
end

local function setupSilentAim()
    local utilityModule = nil
    for _, module in pairs(ReplicatedStorage:GetDescendants()) do
        if module:IsA("ModuleScript") and module.Name == "Utility" then
            utilityModule = module
            break
        end
    end

    if utilityModule then
        local success, utility = pcall(function() return require(utilityModule) end)
        if success and utility and utility.Raycast then
            -- Store original to avoid infinite loop on re-execute
            if not getgenv().OriginalRaycast then
                getgenv().OriginalRaycast = utility.Raycast
            end
            originalRaycast = getgenv().OriginalRaycast
            
            utility.Raycast = function(...)
                local args = table.pack(...)
                if silentAimEnabled and math.random(1, 100) <= hitChance then
                    local closest, selectedPartName = getClosestPlayerInFOV()
                    if closest and closest.Character and selectedPartName and closest.Character:FindFirstChild(selectedPartName) then
                        args[3] = closest.Character[selectedPartName].Position
                    end
                end
                return originalRaycast(table.unpack(args, 1, args.n))
            end
        end
    end
end

task.spawn(setupSilentAim)

-- ========== ESP LOGIC ==========
local DeflectingPlayers = {}
getgenv().DeflectingPlayers = DeflectingPlayers
local function isPlayerParrying(player)
    if not player then return false end
    local endTime = DeflectingPlayers[player]
    return endTime and tick() < endTime
end
getgenv()._isPlayerParrying = isPlayerParrying

local function getPlayerFromObj(obj)
    local char = obj:FindFirstAncestorOfClass("Model")
    return char and Players:GetPlayerFromCharacter(char)
end

if not getgenv().ParticleHooked then
    getgenv().ParticleHooked = true
    local _tempPE = Instance.new("ParticleEmitter")
    local oldEmit; oldEmit = hookfunction(_tempPE.Emit, function(self, count)
        if self.Name == "bigstar" then
            local p = getPlayerFromObj(self)
            if p then DeflectingPlayers[p] = tick() + 1 end
        end
        return oldEmit(self, count)
    end)
    local oldClear; oldClear = hookfunction(_tempPE.Clear, function(self)
        if self.Name == "bigstar" then
            local p = getPlayerFromObj(self)
            if p then DeflectingPlayers[p] = 0 end
        end
        return oldClear(self)
    end)
    _tempPE:Destroy()
end

local FighterController = nil
task.spawn(function()
    pcall(function()
        local playerScripts = lp:WaitForChild("PlayerScripts", 5)
        if playerScripts then
            local controllers = playerScripts:WaitForChild("Controllers", 5)
            if controllers then
                local fc = controllers:WaitForChild("FighterController", 5)
                if fc then FighterController = require(fc) end
            end
        end
    end)
end)

local function getESPContainerParent()
    local success, hui = pcall(function() return gethui() end)
    if success and hui then return hui end
    local success2, core = pcall(function() return game:GetService("CoreGui") end)
    if success2 and core then return core end
    return lp:WaitForChild("PlayerGui")
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ModpackESP_UI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = getESPContainerParent()
getgenv().MyModpackESP = screenGui

local espContainer = Instance.new("Frame")
espContainer.Name = "ESP_Container"
espContainer.Size = UDim2.new(1, 0, 1, 0)
espContainer.BackgroundTransparency = 1
espContainer.Parent = screenGui

local espCache = {}

local espSettings = {
    MasterEnabled = false,
    Box = false, BoxColor = Color3.fromRGB(255, 255, 255),
    BoxFill = false, BoxFillColor = Color3.fromRGB(255, 0, 0),
    Distance = false, DistanceColor = Color3.fromRGB(255, 255, 255),
    Weapon = false, WeaponColor = Color3.fromRGB(255, 200, 0),
    Ammo = false, AmmoColor = Color3.fromRGB(0, 255, 127),
    Katana = false, KatanaColor = Color3.fromRGB(255, 0, 0),
    Bone = false, BoneColor = Color3.fromRGB(255, 255, 255),
    Tracer = false, TracerColor = Color3.fromRGB(255, 255, 255),
    Name = false, NameColor = Color3.fromRGB(255, 255, 255),
}
getgenv().ESPSettings_TeamCheck = false

local function createLine() 
    local line = Instance.new("Frame")
    line.BorderSizePixel = 0
    line.AnchorPoint = Vector2.new(0.5, 0.5)
    line.ZIndex = 0
    line.Visible = false
    line.Parent = espContainer
    return line 
end

local function drawLine(frame, p1, p2, color) 
    local dir = p2 - p1
    frame.Position = UDim2.new(0, (p1.X+p2.X)/2, 0, (p1.Y+p2.Y)/2)
    frame.Size = UDim2.new(0, dir.Magnitude, 0, 1)
    frame.Rotation = math.deg(math.atan2(dir.Y, dir.X))
    frame.BackgroundColor3 = color
    frame.Visible = true 
end

local function createPlayerEsp(p)
    if espCache[p] then return end
    
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "WeaponInfo"
    billboard.Size = UDim2.new(0, 200, 0, 60)
    billboard.StudsOffset = Vector3.new(0, -3.5, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 5000
    billboard.Enabled = false
    billboard.Parent = screenGui

    local ammoText = Instance.new("TextLabel")
    ammoText.Size = UDim2.new(1, 0, 0.5, 0)
    ammoText.Position = UDim2.new(0, 0, 0, 0)
    ammoText.BackgroundTransparency = 1
    ammoText.TextStrokeTransparency = 0
    ammoText.TextSize = 12
    ammoText.Font = Enum.Font.GothamBold
    ammoText.RichText = true
    ammoText.Visible = false
    ammoText.Parent = billboard

    local weaponText = Instance.new("TextLabel")
    weaponText.Size = UDim2.new(1, 0, 0.5, 0)
    weaponText.Position = UDim2.new(0, 0, 0.5, 0)
    weaponText.BackgroundTransparency = 1
    weaponText.TextStrokeTransparency = 0
    weaponText.TextSize = 14
    weaponText.Font = Enum.Font.GothamBold
    weaponText.RichText = true
    weaponText.Visible = false
    weaponText.Parent = billboard

    espCache[p] = {
        NameTag = Instance.new("TextLabel"),
        DistanceTag = Instance.new("TextLabel"),
        Box = Instance.new("Frame"),
        BoxStroke = Instance.new("UIStroke"),
        Tracer = createLine(),
        WeaponBillboard = billboard,
        WeaponText = weaponText,
        AmmoText = ammoText,
        Bones = {
            Head_Torso = createLine(),
            Torso_LArm = createLine(),
            Torso_RArm = createLine(),
            Torso_LLeg = createLine(),
            Torso_RLeg = createLine()
        }
    }

    local c = espCache[p]
    c.NameTag.BackgroundTransparency = 1; c.NameTag.Font = Enum.Font.GothamBold; c.NameTag.TextSize = 14; c.NameTag.TextStrokeTransparency = 0; c.NameTag.Visible = false; c.NameTag.Parent = espContainer
    c.DistanceTag.BackgroundTransparency = 1; c.DistanceTag.Font = Enum.Font.GothamBold; c.DistanceTag.TextSize = 12; c.DistanceTag.TextStrokeTransparency = 0; c.DistanceTag.Visible = false; c.DistanceTag.Parent = espContainer
    
    c.Box.BackgroundTransparency = 1; c.Box.BorderSizePixel = 0; c.Box.Visible = false; c.Box.Parent = espContainer
    c.BoxStroke.Thickness = 1.5; c.BoxStroke.Parent = c.Box
end

local function clearPlayerEsp(p)
    if espCache[p] then
        pcall(function() espCache[p].NameTag:Destroy() end)
        pcall(function() espCache[p].DistanceTag:Destroy() end)
        pcall(function() espCache[p].Box:Destroy() end)
        pcall(function() espCache[p].Tracer:Destroy() end)
        pcall(function() if espCache[p].WeaponBillboard then espCache[p].WeaponBillboard:Destroy() end end)
        for _, b in pairs(espCache[p].Bones) do pcall(function() b:Destroy() end) end
        espCache[p] = nil
    end
end

Players.PlayerRemoving:Connect(clearPlayerEsp)
for _, p in pairs(Players:GetPlayers()) do
    if p ~= lp then
        p.CharacterAdded:Connect(function() clearPlayerEsp(p) end)
    end
end
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function() clearPlayerEsp(p) end)
end)

local function getBonePos(char, partName, cam)
    local part = char:FindFirstChild(partName)
    if part and cam then
        local pos, onScreen = cam:WorldToViewportPoint(part.Position)
        if onScreen then return Vector2.new(pos.X, pos.Y) end
    end
    return nil
end

RunService.RenderStepped:Connect(function()
    local cam = workspace.CurrentCamera
    if not cam then return end

    if not espSettings.MasterEnabled then
        for _, c in pairs(espCache) do
            c.NameTag.Visible = false
            c.DistanceTag.Visible = false
            c.Box.Visible = false
            c.Tracer.Visible = false
            c.WeaponBillboard.Enabled = false
            for _, b in pairs(c.Bones) do b.Visible = false end
        end
        return
    end

    for _, p in pairs(Players:GetPlayers()) do
        if p == lp then continue end
        
        local char = p.Character
        local hum = char and char:FindFirstChild("Humanoid")
        local rootPart = char and char:FindFirstChild("HumanoidRootPart")
        local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HitboxHead") or rootPart)

        if not char or not hum or hum.Health <= 0 or not rootPart or not head or not checkTeam(p, true) then
            if espCache[p] then
                local c = espCache[p]
                c.NameTag.Visible = false
                c.DistanceTag.Visible = false
                c.Box.Visible = false
                c.Tracer.Visible = false
                c.WeaponBillboard.Enabled = false
                for _, b in pairs(c.Bones) do b.Visible = false end
            end
            continue
        end

        createPlayerEsp(p)
        local cache = espCache[p]

        local rootPos, onScreen = cam:WorldToViewportPoint(rootPart.Position)
        local distance = math.floor((cam.CFrame.Position - rootPart.Position).Magnitude)

        if espSettings.Weapon or espSettings.Ammo then
            cache.WeaponBillboard.Adornee = rootPart
            cache.WeaponBillboard.Enabled = true

            if espSettings.Weapon then
                cache.WeaponText.TextColor3 = espSettings.WeaponColor
                local fighter = FighterController and typeof(FighterController.GetFighter) == "function" and FighterController:GetFighter(p)
                local weaponName = "None"
                if fighter and fighter.EquippedItem then
                    weaponName = fighter.EquippedItem.Name
                end
                cache.WeaponText.Text = weaponName
                cache.WeaponText.Visible = true
            else
                cache.WeaponText.Visible = false
            end

            if espSettings.Ammo then
                cache.AmmoText.TextColor3 = espSettings.AmmoColor
                local fighter = FighterController and typeof(FighterController.GetFighter) == "function" and FighterController:GetFighter(p)
                local ammoStr = ""
                if fighter and fighter.EquippedItem then
                    local ammo = fighter.EquippedItem:Get("Ammo")
                    local reserve = fighter.EquippedItem:Get("AmmoReserve")
                    if ammo then
                        ammoStr = string.format("Ammo: %d / %s", ammo, reserve or "0")
                    end
                end
                if ammoStr ~= "" then
                    cache.AmmoText.Text = ammoStr
                    cache.AmmoText.Visible = true
                else
                    cache.AmmoText.Visible = false
                end
            else
                cache.AmmoText.Visible = false
            end
        else
            cache.WeaponBillboard.Enabled = false
        end

        if onScreen then
            local headPosV3 = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 1.5, 0))
            local topPosV3, topVis = cam:WorldToViewportPoint(rootPart.Position + Vector3.new(0, 3, 0))
            local botPosV3, botVis = cam:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3.5, 0))
            local headPos = Vector2.new(headPosV3.X, headPosV3.Y)
            local topPos = Vector2.new(topPosV3.X, topPosV3.Y)
            local botPos = Vector2.new(botPosV3.X, botPosV3.Y)

            if espSettings.Name then
                local text = p.Name
                local color = espSettings.NameColor
                if espSettings.Katana and isPlayerParrying(p) then
                    text = text .. " [Parrying]"
                    color = espSettings.KatanaColor
                end
                cache.NameTag.Text = text
                cache.NameTag.TextColor3 = color
                cache.NameTag.Position = UDim2.new(0, headPos.X, 0, headPos.Y - 20)
                cache.NameTag.Visible = true
            else
                cache.NameTag.Visible = false
            end

            if topVis and botVis then
                local height = botPos.Y - topPos.Y
                local width = height / 2

                if espSettings.Box then
                    cache.BoxStroke.Color = espSettings.BoxColor
                    cache.Box.Size = UDim2.new(0, width, 0, height)
                    cache.Box.Position = UDim2.new(0, topPos.X - (width/2), 0, topPos.Y)
                    cache.Box.Visible = true

                    if espSettings.BoxFill then
                        cache.Box.BackgroundColor3 = espSettings.BoxFillColor
                        cache.Box.BackgroundTransparency = 0.5
                    else
                        cache.Box.BackgroundTransparency = 1
                    end
                else
                    cache.Box.Visible = false
                end
                
                if espSettings.Distance then
                    cache.DistanceTag.Text = tostring(distance) .. "m"
                    cache.DistanceTag.TextColor3 = espSettings.DistanceColor
                    cache.DistanceTag.Position = UDim2.new(0, botPos.X, 0, botPos.Y + 5)
                    cache.DistanceTag.Visible = true
                else
                    cache.DistanceTag.Visible = false
                end

                if espSettings.Tracer then
                    local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y)
                    drawLine(cache.Tracer, center, botPos, espSettings.TracerColor)
                else
                    cache.Tracer.Visible = false
                end
            else
                cache.Box.Visible = false
                cache.DistanceTag.Visible = false
                cache.Tracer.Visible = false
            end

            if espSettings.Bone then
                local h = getBonePos(char, "Head", cam)
                local t = getBonePos(char, "UpperTorso", cam) or getBonePos(char, "Torso", cam) or getBonePos(char, "HumanoidRootPart", cam)
                local la = getBonePos(char, "LeftLowerArm", cam) or getBonePos(char, "Left Arm", cam)
                local ra = getBonePos(char, "RightLowerArm", cam) or getBonePos(char, "Right Arm", cam)
                local ll = getBonePos(char, "LeftLowerLeg", cam) or getBonePos(char, "Left Leg", cam)
                local rl = getBonePos(char, "RightLowerLeg", cam) or getBonePos(char, "Right Leg", cam)

                if h and t then drawLine(cache.Bones.Head_Torso, h, t, espSettings.BoneColor) else cache.Bones.Head_Torso.Visible = false end
                if t and la then drawLine(cache.Bones.Torso_LArm, t, la, espSettings.BoneColor) else cache.Bones.Torso_LArm.Visible = false end
                if t and ra then drawLine(cache.Bones.Torso_RArm, t, ra, espSettings.BoneColor) else cache.Bones.Torso_RArm.Visible = false end
                if t and ll then drawLine(cache.Bones.Torso_LLeg, t, ll, espSettings.BoneColor) else cache.Bones.Torso_LLeg.Visible = false end
                if t and rl then drawLine(cache.Bones.Torso_RLeg, t, rl, espSettings.BoneColor) else cache.Bones.Torso_RLeg.Visible = false end
            else
                for _, b in pairs(cache.Bones) do b.Visible = false end
            end
        else
            cache.NameTag.Visible = false
            cache.DistanceTag.Visible = false
            cache.Box.Visible = false
            cache.Tracer.Visible = false
            for _, b in pairs(cache.Bones) do b.Visible = false end
        end
    end
end)


-- ========== LINORIA UI ==========
local repo = "https://raw.githubusercontent.com/mstudio45/LinoriaLib/main/"

local Library     = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager  = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

getgenv().MyLinoriaLibrary = Library

local Window = Library:CreateWindow({
    Title = "Modpack Rivals",
    Center = true,
    AutoShow = true,
})

local Tabs = {
    Combat  = Window:AddTab("Combat"),
    Visuals = Window:AddTab("Visuals"),
    Rage    = Window:AddTab("Rage"),
    Config  = Window:AddTab("Config"),
}

-- ===== COMBAT TAB =====
local AimSection = Tabs.Combat:AddLeftGroupbox("Silent Aim")

local SilentToggle = AimSection:AddToggle("SilentEnabled", {
    Text    = "Enabled",
    Default = false,
    Callback = function(value) silentAimEnabled = value end,
})

local AimDep = AimSection:AddDependencyBox()

AimDep:AddDropdown("TargetPart", {
    Values = {"Random", "HitboxHead", "Head", "HitboxBody", "LowerTorso"},
    Default = 2,
    Multi = false,
    Text = "Target Part",
    Callback = function(value) targetPart = value end,
})

AimDep:AddSlider("SAHitChance", {
    Text    = "Hit Chance (%)", Default = 100, Min = 1, Max = 100, Rounding = 0,
    Callback = function(value) hitChance = value end,
})

AimDep:AddSlider("SAIFOV", {
    Text    = "FOV", Default = 100, Min = 1, Max = 100, Rounding = 0,
    Callback = function(value) FOV = value end,
})

AimDep:AddToggle("Aim360", {
    Text    = "360", Default = false,
    Callback = function(value) aim360 = value end,
})

AimDep:AddToggle("TeamCheck", {
    Text    = "Team Check", Default = false,
    Callback = function(value) teamCheck = value end,
})

AimDep:SetupDependencies({ { SilentToggle, true } })


-- ===== VISUALS TAB =====
local ESPSection = Tabs.Visuals:AddLeftGroupbox("ESP")

local ESPToggle = ESPSection:AddToggle("ESP_Enabled", {
    Text = "Enabled", Default = false,
    Callback = function(value) espSettings.MasterEnabled = value end
})

local ESPDep = ESPSection:AddDependencyBox()

ESPDep:AddToggle("ESP_Box", { Text = "Box", Default = false, Callback = function(v) espSettings.Box = v end })
    :AddColorPicker("ESP_Box_Color", { Default = espSettings.BoxColor, Callback = function(v) espSettings.BoxColor = v end })

ESPDep:AddToggle("ESP_BoxFill", { Text = "Box fill", Default = false, Callback = function(v) espSettings.BoxFill = v end })
    :AddColorPicker("ESP_BoxFill_Color", { Default = espSettings.BoxFillColor, Callback = function(v) espSettings.BoxFillColor = v end })

ESPDep:AddToggle("ESP_Distance", { Text = "DistanceEsp", Default = false, Callback = function(v) espSettings.Distance = v end })
    :AddColorPicker("ESP_Distance_Color", { Default = espSettings.DistanceColor, Callback = function(v) espSettings.DistanceColor = v end })

ESPDep:AddToggle("ESP_Weapon", { Text = "WeaponESP", Default = false, Callback = function(v) espSettings.Weapon = v end })
    :AddColorPicker("ESP_Weapon_Color", { Default = espSettings.WeaponColor, Callback = function(v) espSettings.WeaponColor = v end })

ESPDep:AddToggle("ESP_Ammo", { Text = "AmmoESP", Default = false, Callback = function(v) espSettings.Ammo = v end })
    :AddColorPicker("ESP_Ammo_Color", { Default = espSettings.AmmoColor, Callback = function(v) espSettings.AmmoColor = v end })

ESPDep:AddToggle("ESP_Katana", { Text = "KatanaESP", Default = false, Callback = function(v) espSettings.Katana = v end })
    :AddColorPicker("ESP_Katana_Color", { Default = espSettings.KatanaColor, Callback = function(v) espSettings.KatanaColor = v end })

ESPDep:AddToggle("ESP_Bone", { Text = "BoneESP", Default = false, Callback = function(v) espSettings.Bone = v end })
    :AddColorPicker("ESP_Bone_Color", { Default = espSettings.BoneColor, Callback = function(v) espSettings.BoneColor = v end })

ESPDep:AddToggle("ESP_Tracer", { Text = "TracerESP", Default = false, Callback = function(v) espSettings.Tracer = v end })
    :AddColorPicker("ESP_Tracer_Color", { Default = espSettings.TracerColor, Callback = function(v) espSettings.TracerColor = v end })

ESPDep:AddToggle("ESP_Name", { Text = "NameESP", Default = false, Callback = function(v) espSettings.Name = v end })
    :AddColorPicker("ESP_Name_Color", { Default = espSettings.NameColor, Callback = function(v) espSettings.NameColor = v end })

ESPDep:AddToggle("ESP_TeamCheck", { Text = "Team Check", Default = false, Callback = function(v) getgenv().ESPSettings_TeamCheck = v end })

ESPDep:SetupDependencies({ { ESPToggle, true } })


-- ===== RAGE TAB =====
-- ========== WALLBANG V1 ==========
do
    getgenv().RageEnabled = false
    getgenv().RageHeight = 7.5

    if getgenv().__WallBangV1 then
        pcall(function() getgenv().__WallBangV1:Shutdown() end)
    end

    local UIS = game:GetService("UserInputService")
    local ps = lp:WaitForChild("PlayerScripts", 10)
    local GunMod     = require(ps.Modules.ItemTypes.Gun)
    local MeleeMod   = require(ps.Modules.ItemTypes.Melee)
    local Utility    = require(ReplicatedStorage.Modules.Utility)
    local DuelCtrl   = require(ps.Controllers.DuelController)

    local function getBestHead(char)
        if not char then return nil end
        return char:FindFirstChild("HitboxHead") or char:FindFirstChild("HitboxHeadSmall") or char:FindFirstChild("Head")
    end

    local wb = {}
    getgenv().__WallBangV1 = wb

    local wbTeamCheck = false

    wb.__active = false; wb.__desync = false; wb.__conn1 = nil; wb.__conn2 = nil
    wb.__task1 = nil; wb.__old_gun = nil; wb.__old_melee = nil; wb.__tp_time = 0
    wb.__is_tp_active = false; wb.__locked_target = nil; wb.__last_duel = nil
    wb.__curr = nil; wb.__pause_desync = false; wb.__target = nil

    function wb:Shutdown()
        self.__active = false
        getgenv().IsRageBotShooting = false
        if self.__conn1 then self.__conn1:Disconnect() end
        if self.__conn2 then self.__conn2:Disconnect() end
        if self.__task1 then task.cancel(self.__task1) end
        if self.__old_gun   then GunMod.StartShooting   = self.__old_gun   end
        if self.__old_melee then MeleeMod.StartShooting = self.__old_melee end
    end

    function wb:__desync_stop()
        self.__desync = false
        getgenv().IsRageBotShooting = false
        self.__curr = nil
        if self.__conn2 then self.__conn2:Disconnect(); self.__conn2 = nil end
    end

    function wb:__desync_start(target, isMelee)
        if self.__conn2 then self.__conn2:Disconnect() end
        self.__desync = true
        getgenv().IsRageBotShooting = true
        self.__curr = target
        self.__is_tp_active = false
        self.__conn2 = RunService.Heartbeat:Connect(function()
            if not self.__desync or self.__is_tp_active or self.__pause_desync then return end
            local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            local head = getBestHead(target.Character)
            if not head then self:__desync_stop(); return end
            self.__is_tp_active = true
            local origCF = hrp.CFrame
            local origLV = hrp.AssemblyLinearVelocity
            local origAV = hrp.AssemblyAngularVelocity
            local maxH = isMelee and 4.5 or (getgenv().RageHeight or 7.5)
            local safeH = maxH
            local rp = RaycastParams.new()
            rp.FilterType = Enum.RaycastFilterType.Exclude
            rp.FilterDescendantsInstances = {lp.Character, target.Character}
            local ray = workspace:Raycast(head.Position, Vector3.new(0, maxH, 0), rp)
            if ray then safeH = math.max(0, (ray.Position - head.Position).Magnitude - 1.5) end
            hrp.CFrame = CFrame.lookAt(head.Position + Vector3.new(0, safeH, 0), head.Position)
            RunService:BindToRenderStep("__wb_restore", 101, function()
                if not self.__pause_desync then
                    hrp.CFrame = origCF
                    hrp.AssemblyLinearVelocity = origLV
                    hrp.AssemblyAngularVelocity = origAV
                end
                self.__is_tp_active = false
                RunService:UnbindFromRenderStep("__wb_restore")
            end)
        end)
    end

    function wb:__find()
        local curDuel = DuelCtrl:GetDuel(lp)
        if self.__last_duel ~= curDuel then self.__last_duel = curDuel; self.__locked_target = nil end
        if self.__locked_target then
            local lt = self.__locked_target
            local ltHum = lt.Character and lt.Character:FindFirstChildWhichIsA("Humanoid")
            if lt ~= lp and lt.Character and ltHum and ltHum.Health > 0 then return lt end
            self.__locked_target = nil
        end
        local best, bestDist = nil, math.huge
        local mousePos = UIS:GetMouseLocation()
        local myTeamID = lp:GetAttribute("TeamID")
        for _, p in next, Players:GetPlayers() do
            if p == lp then continue end
            if getgenv().WallBangTeamCheck then
                local theirID = p:GetAttribute("TeamID")
                if myTeamID == nil or theirID == nil or myTeamID == theirID then continue end
            end
            local char = p.Character; if not char then continue end
            local body = char:FindFirstChild("HitboxBody") or char:FindFirstChild("HitboxBodySmall") or char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChildWhichIsA("Humanoid")
            if not (body and hum and hum.Health > 0) then continue end
            local sp = cam:WorldToViewportPoint(body.Position)
            local dist = (mousePos - Vector2.new(sp.X, sp.Y)).Magnitude
            if dist < bestDist then bestDist = dist; best = p end
        end
        if best then self.__locked_target = best end
        return best
    end

    function wb:__setup()
        self.__conn1 = RunService.Heartbeat:Connect(function()
            if self.__active then self.__target = self:__find() end
        end)
        local function hookModule(module, isMelee)
            local old = module.StartShooting
            module.StartShooting = function(item, ...)
                if not getgenv().RageEnabled or not self.__active then return old(item, ...) end
                local isLocal = item.ClientFighter and item.ClientFighter.IsLocalPlayer
                local target = self.__target
                local curDuel = DuelCtrl:GetDuel(lp)
                local inDuel = curDuel and curDuel.LocalDueler
                local isSelf = false
                if not target and inDuel then target = lp; isSelf = true end
                local canTP = target and target.Character and not isSelf
                if isMelee then canTP = canTP and tick() > (item._attack_cooldown or 0)
                else canTP = canTP and item:Get("Ammo") > 0 and tick() > (item._reload_cooldown or 0) end
                if self.__active and isLocal and canTP then
                    if not self.__desync or self.__curr ~= target then
                        self.__tp_time = tick()
                        self:__desync_start(target, isMelee)
                    end
                    local elapsed = tick() - self.__tp_time
                    if elapsed < 0.15 then task.wait(0.15 - elapsed) end
                end
                local results = {old(item, ...)}
                if not isLocal then return unpack(results) end
                local camData = results[3]
                if not camData or typeof(camData) ~= "table" then return unpack(results) end
                if not isMelee then results[4] = true end
                if not self.__active or not target or not target.Character or isSelf then return unpack(results) end
                if self.__task1 then task.cancel(self.__task1) end
                self.__task1 = task.delay(0.15, function() self.__task1 = nil; self:__desync_stop() end)
                local head = getBestHead(target.Character)
                if not head then return unpack(results) end
                local headPos = head.Position
                local maxH = isMelee and 4.5 or (getgenv().RageHeight or 7.5)
                local safeH = maxH
                local rp = RaycastParams.new()
                rp.FilterType = Enum.RaycastFilterType.Exclude
                rp.FilterDescendantsInstances = {lp.Character, target.Character}
                local ray = workspace:Raycast(headPos, Vector3.new(0, maxH, 0), rp)
                if ray then safeH = math.max(0, (ray.Position - headPos).Magnitude - 1.5) end
                local tpPos = headPos + Vector3.new(0, safeH, 0)
                local newCamCF = CFrame.lookAt(tpPos + Vector3.new(0.01, 0.01, 0.01), headPos)
                local localOffset = head.CFrame:ToObjectSpace(CFrame.new(headPos))
                local newCamData = {}
                for k, v in pairs(camData) do newCamData[k] = v end
                results[3] = newCamData
                newCamData[utf8.char(0)] = Utility:EncodeCFrame(newCamCF)
                newCamData[utf8.char(1)] = Utility:EncodeCFrame(newCamCF)
                newCamData[utf8.char(2)] = head
                newCamData[utf8.char(3)] = Utility:EncodeCFrame(localOffset)
                return unpack(results)
            end
            return old
        end
        self.__old_gun   = hookModule(GunMod, false)
        self.__old_melee = hookModule(MeleeMod, true)
    end

    wb:__setup()
end

local WallBangSection = Tabs.Rage:AddLeftGroupbox("WallBang V1")
WallBangSection:AddToggle("WallBangEnabled", {
    Text = "Enabled",
    Default = false,
    Callback = function(value)
        getgenv().RageEnabled = value
        getgenv().__WallBangV1.__active = value
    end
})

getgenv().WallBangTeamCheck = false
WallBangSection:AddToggle("WallBangTeamCheck", {
    Text = "Team Check",
    Default = false,
    Callback = function(value)
        getgenv().WallBangTeamCheck = value
    end
})

local GunModsSection = Tabs.Rage:AddLeftGroupbox("Gun Mods")

_G.RageSettings = {
    Enabled = false,
    NoRecoil = false,
    NoSpread = false,
    RapidFire = false
}

task.spawn(function()
    local OriginalStats = {} 
    local PlayerScripts = lp:WaitForChild("PlayerScripts", 10)
    if not PlayerScripts then return end
    
    local clientItemModule = require(PlayerScripts:WaitForChild("Modules", 5):WaitForChild("ClientReplicatedClasses", 5):WaitForChild("ClientFighter", 5):WaitForChild("ClientItem", 5))
    
    if type(clientItemModule) == "table" then
        local originalEquip = clientItemModule.Equip
        if type(originalEquip) == "function" and not clientItemModule._isEquipHooked then
            clientItemModule._isEquipHooked = true
            clientItemModule.Equip = function(self, ...)
                if not self._isNoSpreadHooked then
                    self._isNoSpreadHooked = true
                    local originalIsFullyAiming = self.IsFullyAiming
                    if type(originalIsFullyAiming) == "function" then
                        self.IsFullyAiming = function(weaponSelf, ...)
                            if _G.RageSettings.Enabled and _G.RageSettings.NoSpread then return true end
                            return originalIsFullyAiming(weaponSelf, ...)
                        end
                    else
                        self.IsFullyAiming = function() return _G.RageSettings.Enabled and _G.RageSettings.NoSpread end
                    end
                end
                return originalEquip(self, ...)
            end
        end
    end

    local inputFunc = clientItemModule.Input
    local oldRage;
    
    if hookfunction then
        oldRage = hookfunction(inputFunc, function(...)
            local args = {...}
            if type(args[1]) == "table" and args[1].Info then
                local gunName = args[1].Name or tostring(args[1])
                if not OriginalStats[gunName] then
                    OriginalStats[gunName] = {
                        Recoil = args[1].Info.ShootRecoil,
                        Spread = args[1].Info.ShootSpread,
                        CD = args[1].Info.ShootCooldown,
                        QCD = args[1].Info.QuickShotCooldown
                    }
                end
                
                local orig = OriginalStats[gunName]
                if _G.RageSettings.Enabled then
                    args[1].Info.ShootRecoil = _G.RageSettings.NoRecoil and 0 or orig.Recoil
                    args[1].Info.ShootSpread = _G.RageSettings.NoSpread and 0 or orig.Spread
                    args[1].Info.ShootCooldown = _G.RageSettings.RapidFire and 0.001 or orig.CD
                    args[1].Info.QuickShotCooldown = _G.RageSettings.RapidFire and 0.001 or orig.QCD
                else
                    args[1].Info.ShootRecoil = orig.Recoil
                    args[1].Info.ShootSpread = orig.Spread
                    args[1].Info.ShootCooldown = orig.CD
                    args[1].Info.QuickShotCooldown = orig.QCD
                end
            end
            return oldRage(...)
        end)
    end
end)

local GunModsToggle = GunModsSection:AddToggle("GunMods_Enabled", {
    Text = "Enabled",
    Default = false,
    Callback = function(value)
        _G.RageSettings.Enabled = value
    end
})

local GunModsDep = GunModsSection:AddDependencyBox()

GunModsDep:AddToggle("GunMods_NoSpread", {
    Text = "No Spread",
    Default = false,
    Callback = function(value)
        _G.RageSettings.NoSpread = value
    end
})

GunModsDep:AddToggle("GunMods_NoRecoil", {
    Text = "No Recoil",
    Default = false,
    Callback = function(value)
        _G.RageSettings.NoRecoil = value
    end
})

GunModsDep:AddToggle("GunMods_RapidFire", {
    Text = "Rapid Fire",
    Default = false,
    Callback = function(value)
        _G.RageSettings.RapidFire = value
    end
})

GunModsDep:SetupDependencies({ { GunModsToggle, true } })


-- ========== THEME MANAGER ==========
ThemeManager:SetLibrary(Library)
ThemeManager:SetFolder("NewModpackRivals")
ThemeManager:ApplyTheme("Default")
Library.AccentColor = Color3.fromRGB(0, 180, 255)
Library:UpdateColorsUsingRegistry()

local ThemeSection = Tabs.Config:AddLeftGroupbox("Theme")
ThemeManager:ApplyToGroupbox(ThemeSection)

-- ========== AUTO EXECUTE ==========
local AutoExecSection = Tabs.Config:AddRightGroupbox("Auto Execute")

local pastebinCode = "loadstring(game:HttpGet('https://raw.githubusercontent.com/ldtktldjadc/l/refs/heads/main/ModpackRivals.luau'))()"

AutoExecSection:AddToggle("AutoExecuteToggle", {
    Text = "Auto Execute (Keep Script)",
    Default = false,
    Callback = function(value)
        if value then
            -- サーバー移動のたびに自動実行を予約
            pcall(function()
                if queue_on_teleport then
                    queue_on_teleport(pastebinCode)
                elseif syn and syn.queue_on_teleport then
                    syn.queue_on_teleport(pastebinCode)
                end
            end)

            -- 実ファイルのAutoExecuteフォルダにも登録
            pcall(function()
                if isfolder and not isfolder("autoexec") then makefolder("autoexec") end
                writefile("autoexec/ModpackRivals.lua", pastebinCode)
            end)
            pcall(function() writefile("ModpackRivals_AutoExec.lua", pastebinCode) end)
        else
            -- オフにしたらファイルごと削除
            pcall(function() delfile("autoexec/ModpackRivals.lua") end)
            pcall(function() delfile("ModpackRivals_AutoExec.lua") end)
        end
    end
})

-- ========== SAVE MANAGER ==========
SaveManager:SetLibrary(Library)
SaveManager:SetFolder("NewModpackRivals")
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
SaveManager:BuildConfigSection(Tabs.Config)
SaveManager:LoadAutoloadConfig()
