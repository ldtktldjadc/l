if not game:IsLoaded() then game.Loaded:Wait() end
pcall(function() if clearconsole then clearconsole() end end)
pcall(function() if rconsoleclear then rconsoleclear() end end)
pcall(function()
    local LogService = game:GetService("LogService")
    if LogService and LogService.Clear then LogService:Clear() end
end)


local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local lp = Players.LocalPlayer
local PlayerGui = lp:WaitForChild("PlayerGui")

if PlayerGui:FindFirstChild("LoadingScreen") then
    repeat task.wait(0.5) until not PlayerGui:FindFirstChild("LoadingScreen")
    task.wait(1)
end

local boundRenderSteps = {}
local function safeBindToRenderStep(rs, name, priority, func)
    if type(rs.BindToRenderStep) == "function" then
        pcall(function() rs:BindToRenderStep(name, priority, func) end)
    else
        if boundRenderSteps[name] then boundRenderSteps[name]:Disconnect() end
        boundRenderSteps[name] = rs.RenderStepped:Connect(func)
    end
end
local function safeUnbindFromRenderStep(rs, name)
    if type(rs.UnbindFromRenderStep) == "function" then
        pcall(function() rs:UnbindFromRenderStep(name) end)
    end
    if boundRenderSteps[name] then
        boundRenderSteps[name]:Disconnect()
        boundRenderSteps[name] = nil
    end
end

-- 螟夐㍾繝ｭ繝ｼ繝蛾亟豁｢・・遘剃ｻ･蜀・↓騾｣邯壹〒螳溯｡後＆繧後◆蝣ｴ蜷医・蠑ｾ縺擾ｼ・
if getgenv().ModpackRivals_Executing then return end
getgenv().ModpackRivals_Executing = true
task.delay(5, function() getgenv().ModpackRivals_Executing = false end)

--==========
--[[
	WARNING: Heads up! This script has not been verified by ScriptBlox. Use at your own risk!
]]

--// Config



--===========

local cam = workspace.CurrentCamera


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
    if plr == lp then return false end
    
    if SpectateController then
        local duel = SpectateController.CurrentDuelSubject
        local localDueler = duel and duel:GetDueler(lp)
        local localTeam = localDueler and localDueler:Get("TeamID") or nil
        if localTeam and duel and duel.Duelers then
            for _, dueler in next, duel.Duelers do
                if dueler.Player == plr then
                    local team = dueler:Get("TeamID")
                    return team ~= localTeam
                end
            end
        end
    end
    
    local myID = getMyTeamID()
    local theirID = getPlayerTeamID(plr)
    
    if theirID == nil then return false end
    if myID and myID == theirID then return false end
    
    return true
end

local SA_CachedTarget = nil
local SA_CachedPartName = nil
local SA_LastCacheTime = 0

local function getClosestPlayerInFOV()
    if not silentAimEnabled then return nil, nil end
    local now = tick()
    if now - SA_LastCacheTime < 0.016 then
        return SA_CachedTarget, SA_CachedPartName
    end
    SA_LastCacheTime = now

    local cam = workspace.CurrentCamera
    if not cam then return nil, nil end

    local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    local bestTarget = nil
    local bestDist = math.huge
    local bestPartName = nil

    local maxDist = (FOV == 100) and math.huge or (FOV * 5)
    
    local myHRP = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {lp.Character}

    local validTargets = {}

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
                    local ray = workspace:Raycast(cam.CFrame.Position, (part.Position - cam.CFrame.Position), raycastParams)
                    local visible = not ray or ray.Instance:IsDescendantOf(plr.Character)
    
                    if visible then
                        local mouseDist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                        local worldDist = (aim360 and myHRP) and (part.Position - myHRP.Position).Magnitude or mouseDist
                        if mouseDist <= maxDist then
                            local health = 100
                            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                            if hum then health = hum.Health end
                            table.insert(validTargets, {
                                Player = plr,
                                PartName = partName,
                                MouseDist = mouseDist,
                                WorldDist = (myHRP) and (part.Position - myHRP.Position).Magnitude or math.huge,
                                Health = health
                            })
                        end
                    end
                end
            end
        end
    end

    if #validTargets > 0 then
        table.sort(validTargets, function(a, b)
            if silentTargetSort == "Distance (Closest)" then return a.WorldDist < b.WorldDist
            elseif silentTargetSort == "Distance (Farthest)" then return a.WorldDist > b.WorldDist
            elseif silentTargetSort == "Health (Lowest)" then return a.Health < b.Health
            elseif silentTargetSort == "Health (Highest)" then return a.Health > b.Health
            elseif silentTargetSort == "Mouse (Closest)" then return a.MouseDist < b.MouseDist
            elseif silentTargetSort == "Mouse (Farthest)" then return a.MouseDist > b.MouseDist
            else return a.MouseDist < b.MouseDist end
        end)
        bestTarget = validTargets[1].Player
        bestPartName = validTargets[1].PartName
    end

    if bestTarget then
        SA_CachedTarget = bestTarget
        SA_CachedPartName = bestPartName
        return bestTarget, bestPartName
    end
    SA_CachedTarget = nil
    SA_CachedPartName = nil
    return nil, nil
end

local function setupSilentAim()
    -- Utility:Raycast(self, origin, endPos, maxDist, filterList, filterType, debug)
    -- 蜀・Κ縺ｧ direction = (endPos - origin).Unit * maxDist 繧定ｨ育ｮ励＠縺ｦ縺・ｋ
    -- 縺ｪ縺ｮ縺ｧ args[3] (endPos) 繧偵ち繝ｼ繧ｲ繝・ヨ蠎ｧ讓吶↓蟾ｮ縺玲崛縺医ｋ縺縺代〒縺・＞
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
            if not getgenv().OriginalRaycast then
                getgenv().OriginalRaycast = utility.Raycast
            end
            local originalFn = getgenv().OriginalRaycast

            utility.Raycast = function(self, origin, endPos, ...)
                if silentAimEnabled and math.random(1, 100) <= hitChance then
                    local closest, selectedPartName = getClosestPlayerInFOV()
                    if closest and closest.Character and selectedPartName and closest.Character:FindFirstChild(selectedPartName) then
                        if typeof(origin) == "Vector3" then
                            endPos = closest.Character[selectedPartName].Position
                        end
                    end
                end
                return originalFn(self, origin, endPos, ...)
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
            if p then
                if not getgenv().DeflectingStartTimes then getgenv().DeflectingStartTimes = {} end
                if not DeflectingPlayers[p] or DeflectingPlayers[p] <= tick() then
                    getgenv().DeflectingStartTimes[p] = tick()
                end
                DeflectingPlayers[p] = tick() + 1
            end
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
local SpectateController = nil
task.spawn(function()
    pcall(function()
        local playerScripts = lp:WaitForChild("PlayerScripts", 5)
        if playerScripts then
            local controllers = playerScripts:WaitForChild("Controllers", 5)
            if controllers then
                local fc = controllers:WaitForChild("FighterController", 5)
                if fc then FighterController = require(fc) end
                
                local sc = controllers:WaitForChild("SpectateController", 5)
                if sc then SpectateController = require(sc) end
            end
        end
    end)
end)


local SeasonLibrary = nil
task.spawn(function()
    pcall(function()
        SeasonLibrary = require(ReplicatedStorage.Modules:WaitForChild("SeasonLibrary", 5))
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
    Box = false, BoxColor = Color3.fromRGB(255, 255, 255), BoxType = "Full",
    BoxFill = false, BoxFillColor = Color3.fromRGB(255, 255, 255), BoxFillImage = false, BoxFillImageID = "",
    Distance = false, DistanceColor = Color3.fromRGB(255, 255, 255),
    Weapon = false, WeaponColor = Color3.fromRGB(255, 255, 255),
    Ammo = false, AmmoColor = Color3.fromRGB(255, 255, 255),
    Rank = false,
    Katana = false, KatanaColor = Color3.fromRGB(255, 255, 255),
    Bone = false, BoneColor = Color3.fromRGB(255, 255, 255),
    Tracer = false, TracerColor = Color3.fromRGB(255, 255, 255),
    Name = false, NameColor = Color3.fromRGB(255, 255, 255),
    HP = false, HPColor = Color3.fromRGB(50, 255, 50),
    TextStrokeColor = Color3.fromRGB(0, 0, 0),
}
getgenv().ESPSettings_TeamCheck = false

local teamEspCache = {}
local teamEspSettings = {
    Enabled = false,
    Box = true,  BoxColor = Color3.fromRGB(0, 200, 255), BoxType = "Full",
    Name = true, NameColor = Color3.fromRGB(0, 200, 255),
    HP = false,  HPColor = Color3.fromRGB(50, 255, 50),
    Tracer = false, TracerColor = Color3.fromRGB(0, 200, 255),
    TextStrokeColor = Color3.fromRGB(0, 0, 0),
}

local function createLine() 
    local line = Instance.new("Frame")
    line.BorderSizePixel = 0
    line.AnchorPoint = Vector2.new(0.5, 0.5)
    line.ZIndex = 0
    line.Visible = false
    line.Parent = espContainer
    local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = Color3.new(0, 0, 0)
    stroke.Thickness = 1
    stroke.Parent = line
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
    billboard.StudsOffset = Vector3.new(0, -4.5, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 5000
    billboard.Enabled = false
    billboard.Parent = screenGui

    local ammoText = Instance.new("TextLabel")
    ammoText.Size = UDim2.new(0, 200, 0, 16)
    ammoText.AnchorPoint = Vector2.new(0.5, 1)
    ammoText.BackgroundTransparency = 1
    ammoText.TextStrokeTransparency = 1
    ammoText.TextSize = 8
    ammoText.Font = Drawing.Fonts.UI
    ammoText.RichText = true
    ammoText.Visible = false
    ammoText.Parent = espContainer
    local ammoStroke = Instance.new("UIStroke")
    ammoStroke.Parent = ammoText

    local rankIcon = Instance.new("ImageLabel")
    rankIcon.BackgroundTransparency = 1
    rankIcon.Size = UDim2.new(0, 30, 0, 30)
    rankIcon.AnchorPoint = Vector2.new(0.5, 1)
    rankIcon.Visible = false
    rankIcon.Parent = espContainer

    local weaponText = Instance.new("TextLabel")
    weaponText.Size = UDim2.new(1, 0, 0.5, 0)
    weaponText.Position = UDim2.new(0, 0, 0.5, 0)
    weaponText.BackgroundTransparency = 1
    weaponText.TextStrokeTransparency = 1
    weaponText.TextSize = 8
    weaponText.Font = Drawing.Fonts.UI
    weaponText.RichText = true
    weaponText.Visible = false
    weaponText.Parent = billboard
    local weaponStroke = Instance.new("UIStroke")
    weaponStroke.Parent = weaponText

    local hpBarBg = Instance.new("Frame")
    hpBarBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    hpBarBg.BorderSizePixel = 1
    hpBarBg.BorderColor3 = Color3.new(0,0,0)
    hpBarBg.Visible = false
    hpBarBg.Parent = espContainer
    local hpBarFill = Instance.new("Frame")
    hpBarFill.BorderSizePixel = 0
    hpBarFill.Parent = hpBarBg

    espCache[p] = {
        NameTag = Instance.new("TextLabel"),
        DistanceTag = Instance.new("TextLabel"),
        BoxLines = {
            TL_H = createLine(), TL_V = createLine(),
            TR_H = createLine(), TR_V = createLine(),
            BL_H = createLine(), BL_V = createLine(),
            BR_H = createLine(), BR_V = createLine()
        },
        BoxFill = Instance.new("ImageLabel"),
        Tracer = createLine(),
        WeaponBillboard = billboard,
        WeaponText = weaponText,
        AmmoText = ammoText,
        RankIcon = rankIcon,
        HPBarBg = hpBarBg,
        HPBarFill = hpBarFill,
        lastChar = nil,
        boneRefs = {},
        Bones = {
            Head_Torso = createLine(),
            Torso_LArm = createLine(),
            Torso_RArm = createLine(),
            Torso_LLeg = createLine(),
            Torso_RLeg = createLine()
        }
    }

    local c = espCache[p]
    c.NameTag.BackgroundTransparency = 1; c.NameTag.Font = Drawing.Fonts.UI; c.NameTag.TextSize = 8; c.NameTag.TextStrokeTransparency = 1; c.NameTag.Visible = false; c.NameTag.Size = UDim2.new(0, 200, 0, 16); c.NameTag.AnchorPoint = Vector2.new(0.5, 1); c.NameTag.Parent = espContainer
    local nameStroke = Instance.new("UIStroke"); nameStroke.Parent = c.NameTag
    c.DistanceTag.BackgroundTransparency = 1; c.DistanceTag.Font = Drawing.Fonts.UI; c.DistanceTag.TextSize = 8; c.DistanceTag.TextStrokeTransparency = 1; c.DistanceTag.Visible = false; c.DistanceTag.Size = UDim2.new(0, 200, 0, 16); c.DistanceTag.AnchorPoint = Vector2.new(0.5, 0); c.DistanceTag.Parent = espContainer
    local distStroke = Instance.new("UIStroke"); distStroke.Parent = c.DistanceTag
    
    c.BoxFill.BackgroundTransparency = 0.5; c.BoxFill.BorderSizePixel = 0; c.BoxFill.Visible = false; c.BoxFill.Parent = espContainer
end

local function clearPlayerEsp(p)
    if espCache[p] then
        pcall(function() espCache[p].NameTag:Destroy() end)
        pcall(function() espCache[p].DistanceTag:Destroy() end)
        pcall(function() if espCache[p].BoxFill then espCache[p].BoxFill:Destroy() end end)
        for _, l in pairs(espCache[p].BoxLines or {}) do pcall(function() l:Destroy() end) end
        pcall(function() espCache[p].Tracer:Destroy() end)
        pcall(function() if espCache[p].WeaponBillboard then espCache[p].WeaponBillboard:Destroy() end end)
        pcall(function() if espCache[p].AmmoText then espCache[p].AmmoText:Destroy() end end)
        pcall(function() if espCache[p].RankIcon then espCache[p].RankIcon:Destroy() end end)
        pcall(function() if espCache[p].HPBarBg then espCache[p].HPBarBg:Destroy() end end)
        for _, b in pairs(espCache[p].Bones) do pcall(function() b:Destroy() end) end
        espCache[p] = nil
    end
    -- Team ESP cleanup
    if teamEspCache[p] then
        pcall(function() teamEspCache[p].NameTag:Destroy() end)
        pcall(function() teamEspCache[p].BoxFill:Destroy() end)
        pcall(function() teamEspCache[p].Tracer:Destroy() end)
        pcall(function() teamEspCache[p].HPBarBg:Destroy() end)
        for _, l in pairs(teamEspCache[p].BoxLines or {}) do pcall(function() l:Destroy() end) end
        teamEspCache[p] = nil
    end
end

local function createTeamPlayerEsp(p)
    if teamEspCache[p] then return end
    local c = {}
    c.NameTag = Instance.new("TextLabel")
    c.NameTag.BackgroundTransparency = 1
    c.NameTag.Font = Drawing.Fonts.UI
    c.NameTag.TextSize = 8
    c.NameTag.TextStrokeTransparency = 1
    c.NameTag.Visible = false
    c.NameTag.Size = UDim2.new(0, 200, 0, 16)
    c.NameTag.AnchorPoint = Vector2.new(0.5, 1)
    c.NameTag.Parent = espContainer
    local ns = Instance.new("UIStroke"); ns.Parent = c.NameTag

    c.BoxLines = {
        TL_H = createLine(), TL_V = createLine(),
        TR_H = createLine(), TR_V = createLine(),
        BL_H = createLine(), BL_V = createLine(),
        BR_H = createLine(), BR_V = createLine()
    }

    c.BoxFill = Instance.new("ImageLabel")
    c.BoxFill.BackgroundTransparency = 0.7
    c.BoxFill.BorderSizePixel = 0
    c.BoxFill.Visible = false
    c.BoxFill.Parent = espContainer

    c.Tracer = createLine()

    c.HPBarBg = Instance.new("Frame")
    c.HPBarBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    c.HPBarBg.BorderSizePixel = 1
    c.HPBarBg.BorderColor3 = Color3.new(0,0,0)
    c.HPBarBg.Visible = false
    c.HPBarBg.Parent = espContainer
    c.HPBarFill = Instance.new("Frame")
    c.HPBarFill.BorderSizePixel = 0
    c.HPBarFill.Parent = c.HPBarBg

    teamEspCache[p] = c
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

local function getBonePos(ref, cam)
    if ref and cam then
        local pos, onScreen = cam:WorldToViewportPoint(ref.Position)
        if onScreen then return Vector2.new(pos.X, pos.Y) end
    end
    return nil
end

local function updateBoneRefs(cache, char)
    if cache.lastChar == char then return end
    cache.lastChar = char
    cache.boneRefs = {
        Head = char:FindFirstChild("Head"),
        Torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart"),
        LArm = char:FindFirstChild("LeftLowerArm") or char:FindFirstChild("Left Arm"),
        RArm = char:FindFirstChild("RightLowerArm") or char:FindFirstChild("Right Arm"),
        LLeg = char:FindFirstChild("LeftLowerLeg") or char:FindFirstChild("Left Leg"),
        RLeg = char:FindFirstChild("RightLowerLeg") or char:FindFirstChild("Right Leg"),
    }
end

local _espLastTime = 0
RunService.Heartbeat:Connect(function()
    local now = tick()
    if now - _espLastTime < 0.03 then return end -- Max ~30fps for ESP
    _espLastTime = now

    local cam = workspace.CurrentCamera
    if not cam then return end

    if not espSettings.MasterEnabled then
        for _, c in pairs(espCache) do
            c.NameTag.Visible = false
            c.DistanceTag.Visible = false
            if c.BoxFill then c.BoxFill.Visible = false end
            for _, l in pairs(c.BoxLines or {}) do l.Visible = false end
            c.Tracer.Visible = false
            c.WeaponBillboard.Enabled = false
            if c.AmmoText then c.AmmoText.Visible = false end
            if c.RankIcon then c.RankIcon.Visible = false end
            if c.HPBarBg then c.HPBarBg.Visible = false end
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
                if c.BoxFill then c.BoxFill.Visible = false end
                for _, l in pairs(c.BoxLines or {}) do l.Visible = false end
                c.Tracer.Visible = false
                c.WeaponBillboard.Enabled = false
                if c.AmmoText then c.AmmoText.Visible = false end
                if c.RankIcon then c.RankIcon.Visible = false end
                if c.HPBarBg then c.HPBarBg.Visible = false end
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

            local fighter = nil
            if FighterController and typeof(FighterController.GetFighter) == "function" then
                fighter = FighterController:GetFighter(p)
            end

            if espSettings.Weapon then
                cache.WeaponText.TextColor3 = espSettings.WeaponColor
                cache.WeaponText.UIStroke.Color = espSettings.TextStrokeColor or Color3.fromRGB(0,0,0)
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
                cache.AmmoText.UIStroke.Color = espSettings.TextStrokeColor or Color3.fromRGB(0,0,0)
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
            cache.AmmoText.Visible = false
        end

        if onScreen then
            local headWorld = rootPart.Position + Vector3.new(0, 3.2, 0)
            local feetWorld = rootPart.Position + Vector3.new(0, -3.2, 0)
            local headScreen = cam:WorldToViewportPoint(headWorld)
            local feetScreen = cam:WorldToViewportPoint(feetWorld)
            local height = math.abs(headScreen.Y - feetScreen.Y)
            local width = height / 1.7
            local topPos = Vector2.new(rootPos.X, headScreen.Y)
            local botPos = Vector2.new(rootPos.X, feetScreen.Y)
            local topVis = true
            local botVis = true
            
            local currentTopY = topPos.Y - 5

            if espSettings.Name then
                local text = p.Name
                local color = espSettings.NameColor
                if espSettings.Katana and isPlayerParrying(p) then
                    text = text .. " [Parrying]"
                    color = espSettings.KatanaColor
                end
                cache.NameTag.Text = text
                cache.NameTag.TextColor3 = color
                cache.NameTag.UIStroke.Color = espSettings.TextStrokeColor or Color3.fromRGB(0,0,0)
                cache.NameTag.Position = UDim2.new(0, topPos.X, 0, currentTopY)
                cache.NameTag.Visible = true
                currentTopY = currentTopY - 10
            else
                cache.NameTag.Visible = false
            end

            if cache.AmmoText.Visible then
                cache.AmmoText.Position = UDim2.new(0, topPos.X, 0, currentTopY)
                currentTopY = currentTopY - 10
            end

            if espSettings.Rank and SeasonLibrary then
                local eloStat = p:FindFirstChild("CustomLeaderstats") and p.CustomLeaderstats:FindFirstChild("Current ELO")
                if eloStat and eloStat.Value then
                    local elo = eloStat.Value
                    local lbRank = nil
                    pcall(function() lbRank = SeasonLibrary:GetHighestELOLeaderboardRanking(elo, p.UserId) end)
                    local rankName = nil
                    pcall(function() rankName = SeasonLibrary:GetRank(elo, p.UserId, lbRank) end)
                    local rankInfo = rankName and SeasonLibrary.CurrentSeason.RankProfile.Ranks[rankName]
                    if rankInfo and rankInfo.Image then
                        cache.RankIcon.Image = rankInfo.Image
                        cache.RankIcon.Position = UDim2.new(0, topPos.X, 0, currentTopY)
                        cache.RankIcon.Visible = true
                    else
                        cache.RankIcon.Visible = false
                    end
                else
                    cache.RankIcon.Visible = false
                end
            else
                cache.RankIcon.Visible = false
            end

            if topVis and botVis then
                if espSettings.Box then
                    local tl = Vector2.new(topPos.X - (width/2), topPos.Y)
                    local tr = Vector2.new(topPos.X + (width/2), topPos.Y)
                    local bl = Vector2.new(topPos.X - (width/2), botPos.Y)
                    local br = Vector2.new(topPos.X + (width/2), botPos.Y)

                    if espSettings.BoxType == "Corner" then
                        local len = math.min(width, height) / 3
                        drawLine(cache.BoxLines.TL_H, tl, tl + Vector2.new(len, 0), espSettings.BoxColor)
                        drawLine(cache.BoxLines.TL_V, tl, tl + Vector2.new(0, len), espSettings.BoxColor)
                        drawLine(cache.BoxLines.TR_H, tr - Vector2.new(len, 0), tr, espSettings.BoxColor)
                        drawLine(cache.BoxLines.TR_V, tr, tr + Vector2.new(0, len), espSettings.BoxColor)
                        drawLine(cache.BoxLines.BL_H, bl, bl + Vector2.new(len, 0), espSettings.BoxColor)
                        drawLine(cache.BoxLines.BL_V, bl - Vector2.new(0, len), bl, espSettings.BoxColor)
                        drawLine(cache.BoxLines.BR_H, br - Vector2.new(len, 0), br, espSettings.BoxColor)
                        drawLine(cache.BoxLines.BR_V, br - Vector2.new(0, len), br, espSettings.BoxColor)
                    else
                        drawLine(cache.BoxLines.TL_H, tl, tr, espSettings.BoxColor)
                        drawLine(cache.BoxLines.BL_H, bl, br, espSettings.BoxColor)
                        drawLine(cache.BoxLines.TL_V, tl, bl, espSettings.BoxColor)
                        drawLine(cache.BoxLines.TR_V, tr, br, espSettings.BoxColor)
                        cache.BoxLines.TR_H.Visible = false
                        cache.BoxLines.BL_V.Visible = false
                        cache.BoxLines.BR_H.Visible = false
                        cache.BoxLines.BR_V.Visible = false
                    end
                    
                    local strokeColor = espSettings.TextStrokeColor or Color3.fromRGB(0,0,0)
                    for _, l in pairs(cache.BoxLines) do
                        local st = l:FindFirstChildOfClass("UIStroke")
                        if st then st.Color = strokeColor end
                    end

                    if espSettings.BoxFill then
                        if espSettings.BoxFillImage and espSettings.BoxFillImageID ~= "" then
                            cache.BoxFill.Image = "rbxassetid://" .. espSettings.BoxFillImageID
                            cache.BoxFill.ImageColor3 = Color3.new(1, 1, 1) -- Keep original image color
                            cache.BoxFill.BackgroundColor3 = espSettings.BoxFillColor -- Fallback/Tint
                            cache.BoxFill.BackgroundTransparency = 1 -- Hide frame bg if using image
                            cache.BoxFill.ImageTransparency = 0.5
                        else
                            cache.BoxFill.Image = ""
                            cache.BoxFill.BackgroundColor3 = espSettings.BoxFillColor
                            cache.BoxFill.BackgroundTransparency = 0.5
                        end
                        cache.BoxFill.Size = UDim2.new(0, width, 0, height)
                        cache.BoxFill.Position = UDim2.new(0, topPos.X - (width/2), 0, topPos.Y)
                        cache.BoxFill.Visible = true
                    else
                        cache.BoxFill.Visible = false
                    end
                else
                    for _, line in pairs(cache.BoxLines) do line.Visible = false end
                    if cache.BoxFill then cache.BoxFill.Visible = false end
                end
                
                if espSettings.HP and cache.HPBarBg then
                    local hpW = 2 -- Fixed thin width to 2px
                    cache.HPBarBg.Size = UDim2.new(0, hpW, 0, height)
                    cache.HPBarBg.Position = UDim2.new(0, topPos.X - (width / 2) - hpW - 4, 0, topPos.Y)
                    local hpPct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                    cache.HPBarFill.Size = UDim2.new(1, 0, hpPct, 0)
                    cache.HPBarFill.Position = UDim2.new(0, 0, 1 - hpPct, 0)
                    cache.HPBarFill.BackgroundColor3 = Color3.new(1 - hpPct, hpPct, 0) -- 邱・0,1,0)縺九ｉ襍､(1,0,0)縺ｸ縺ｮ繧ｰ繝ｩ繝・・繧ｷ繝ｧ繝ｳ
                    cache.HPBarBg.BorderColor3 = espSettings.TextStrokeColor or Color3.fromRGB(0,0,0)
                    cache.HPBarBg.Visible = true
                    cache.HPBarFill.Visible = true
                elseif cache.HPBarBg then
                    cache.HPBarBg.Visible = false
                end

                if espSettings.Distance then
                    local hpPctInt = math.floor((hum.Health / hum.MaxHealth) * 100)
                    cache.DistanceTag.Text = string.format("[ %dm ] [ %d%% ]", distance, hpPctInt)
                    cache.DistanceTag.TextColor3 = espSettings.DistanceColor
                    cache.DistanceTag.UIStroke.Color = espSettings.TextStrokeColor or Color3.fromRGB(0,0,0)
                    cache.DistanceTag.Position = UDim2.new(0, topPos.X, 0, botPos.Y + 2)
                    cache.DistanceTag.Visible = true
                    
                    if cache.WeaponBillboard.Enabled then
                        cache.WeaponBillboard.StudsOffset = Vector3.new(0, -4.5 - ((botPos.Y - topPos.Y) / 100), 0) -- Move Billboard further down dynamically to prevent overlap
                    end
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
                if cache.BoxFill then cache.BoxFill.Visible = false end
                for _, l in pairs(cache.BoxLines or {}) do l.Visible = false end
                cache.DistanceTag.Visible = false
                cache.Tracer.Visible = false
                cache.AmmoText.Visible = false
                cache.RankIcon.Visible = false
                if cache.HPBarBg then cache.HPBarBg.Visible = false end
            end

            if espSettings.Bone then
                updateBoneRefs(cache, char)
                local br = cache.boneRefs
                local h = getBonePos(br.Head, cam)
                local t = getBonePos(br.Torso, cam)
                local la = getBonePos(br.LArm, cam)
                local ra = getBonePos(br.RArm, cam)
                local ll = getBonePos(br.LLeg, cam)
                local rl = getBonePos(br.RLeg, cam)

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
            if cache.BoxFill then cache.BoxFill.Visible = false end
            for _, l in pairs(cache.BoxLines or {}) do l.Visible = false end
            cache.Tracer.Visible = false
            cache.AmmoText.Visible = false
            cache.RankIcon.Visible = false
            if cache.HPBarBg then cache.HPBarBg.Visible = false end
            for _, b in pairs(cache.Bones) do b.Visible = false end
        end
    end
end)

-- ========== TEAM ESP LOOP ==========
local _teamEspLastTime = 0
RunService.Heartbeat:Connect(function()
    local now = tick()
    if now - _teamEspLastTime < 0.03 then return end
    _teamEspLastTime = now

    local cam = workspace.CurrentCamera
    if not cam then return end

    local myID = getMyTeamID()

    if not teamEspSettings.Enabled or not myID then
        for _, c in pairs(teamEspCache) do
            c.NameTag.Visible = false
            c.BoxFill.Visible = false
            c.Tracer.Visible = false
            c.HPBarBg.Visible = false
            for _, l in pairs(c.BoxLines or {}) do l.Visible = false end
        end
        return
    end

    for _, p in pairs(Players:GetPlayers()) do
        if p == lp then continue end

        local theirID = getPlayerTeamID(p)
        local isSameTeam = theirID ~= nil and theirID == myID

        local char = p.Character
        local hum = char and char:FindFirstChild("Humanoid")
        local rootPart = char and char:FindFirstChild("HumanoidRootPart")

        if not isSameTeam or not char or not hum or hum.Health <= 0 or not rootPart then
            if teamEspCache[p] then
                local c = teamEspCache[p]
                c.NameTag.Visible = false
                c.BoxFill.Visible = false
                c.Tracer.Visible = false
                c.HPBarBg.Visible = false
                for _, l in pairs(c.BoxLines or {}) do l.Visible = false end
            end
            continue
        end

        createTeamPlayerEsp(p)
        local c = teamEspCache[p]

        local rootPos, onScreen = cam:WorldToViewportPoint(rootPart.Position)
        if not onScreen then
            c.NameTag.Visible = false
            c.BoxFill.Visible = false
            c.Tracer.Visible = false
            c.HPBarBg.Visible = false
            for _, l in pairs(c.BoxLines or {}) do l.Visible = false end
            continue
        end

        local headWorld = rootPart.Position + Vector3.new(0, 3.2, 0)
        local feetWorld = rootPart.Position + Vector3.new(0, -3.2, 0)
        local headScreen = cam:WorldToViewportPoint(headWorld)
        local feetScreen = cam:WorldToViewportPoint(feetWorld)
        local height = math.abs(headScreen.Y - feetScreen.Y)
        local width = height / 1.7
        local topPos = Vector2.new(rootPos.X, headScreen.Y)
        local botPos = Vector2.new(rootPos.X, feetScreen.Y)
        local currentTopY = topPos.Y - 5

        if teamEspSettings.Name then
            c.NameTag.Text = "[TEAM] " .. p.Name
            c.NameTag.TextColor3 = teamEspSettings.NameColor
            c.NameTag.UIStroke.Color = teamEspSettings.TextStrokeColor
            c.NameTag.Position = UDim2.new(0, topPos.X, 0, currentTopY)
            c.NameTag.Visible = true
            currentTopY = currentTopY - 10
        else
            c.NameTag.Visible = false
        end

        if teamEspSettings.Box then
            local tl = Vector2.new(topPos.X - width/2, topPos.Y)
            local tr = Vector2.new(topPos.X + width/2, topPos.Y)
            local bl = Vector2.new(topPos.X - width/2, botPos.Y)
            local br = Vector2.new(topPos.X + width/2, botPos.Y)
            
            if teamEspSettings.BoxType == "Corner" then
                local len = math.min(width, height) / 3
                drawLine(c.BoxLines.TL_H, tl, tl + Vector2.new(len, 0), teamEspSettings.BoxColor)
                drawLine(c.BoxLines.TL_V, tl, tl + Vector2.new(0, len), teamEspSettings.BoxColor)
                drawLine(c.BoxLines.TR_H, tr - Vector2.new(len, 0), tr, teamEspSettings.BoxColor)
                drawLine(c.BoxLines.TR_V, tr, tr + Vector2.new(0, len), teamEspSettings.BoxColor)
                drawLine(c.BoxLines.BL_H, bl, bl + Vector2.new(len, 0), teamEspSettings.BoxColor)
                drawLine(c.BoxLines.BL_V, bl - Vector2.new(0, len), bl, teamEspSettings.BoxColor)
                drawLine(c.BoxLines.BR_H, br - Vector2.new(len, 0), br, teamEspSettings.BoxColor)
                drawLine(c.BoxLines.BR_V, br - Vector2.new(0, len), br, teamEspSettings.BoxColor)
            else
                drawLine(c.BoxLines.TL_H, tl, tr, teamEspSettings.BoxColor)
                drawLine(c.BoxLines.BL_H, bl, br, teamEspSettings.BoxColor)
                drawLine(c.BoxLines.TL_V, tl, bl, teamEspSettings.BoxColor)
                drawLine(c.BoxLines.TR_V, tr, br, teamEspSettings.BoxColor)
                c.BoxLines.TR_H.Visible = false
                c.BoxLines.BL_V.Visible = false
                c.BoxLines.BR_H.Visible = false
                c.BoxLines.BR_V.Visible = false
            end
            c.BoxFill.BackgroundColor3 = teamEspSettings.BoxColor
            c.BoxFill.Size = UDim2.new(0, width, 0, height)
            c.BoxFill.Position = UDim2.new(0, topPos.X - width/2, 0, topPos.Y)
            c.BoxFill.Visible = false -- fill は常に非表示（輪郭のみ）
        else
            for _, l in pairs(c.BoxLines) do l.Visible = false end
            c.BoxFill.Visible = false
        end

        if teamEspSettings.HP then
            local hpPct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            local hpW = 2
            c.HPBarBg.Size = UDim2.new(0, hpW, 0, height)
            c.HPBarBg.Position = UDim2.new(0, topPos.X - width/2 - hpW - 4, 0, topPos.Y)
            c.HPBarFill.Size = UDim2.new(1, 0, hpPct, 0)
            c.HPBarFill.Position = UDim2.new(0, 0, 1 - hpPct, 0)
            c.HPBarFill.BackgroundColor3 = Color3.new(1 - hpPct, hpPct, 0)
            c.HPBarBg.Visible = true
        else
            c.HPBarBg.Visible = false
        end

        if teamEspSettings.Tracer then
            local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y)
            drawLine(c.Tracer, center, botPos, teamEspSettings.TracerColor)
        else
            c.Tracer.Visible = false
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
    World   = Window:AddTab("World"),
    Rage    = Window:AddTab("Rage"),
    Misc    = Window:AddTab("Misc"),
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

local silentTargetSort = "Distance (Closest)"
AimDep:AddDropdown("SilentAimTargetSort", {
    Values = {"Distance (Closest)", "Distance (Farthest)", "Health (Lowest)", "Health (Highest)", "Mouse (Closest)", "Mouse (Farthest)"},
    Default = 1,
    Multi = false,
    Text = "Target Sort",
    Callback = function(value) silentTargetSort = value end,
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

-- ===== AIM LOCK =====
local AimLockSection = Tabs.Combat:AddRightGroupbox("AimLock")

local AimLockSettings = {
    Enabled = false,
    TeamCheck = false,
    FOV = 150,
    Smoothness = 0.65,
    AlwaysLockSmooth = false,
    WallCheck = false,
    AliveCheck = true,
    TargetPart = "HitboxHead",
    TargetSort = "Mouse (Closest)",
    OnlyScope = false,
    SmoothnessIn = 0.15,
    SmoothnessOut = 0.65,
}

local AL_LockedTarget = nil
local AL_BlatantLockedFighter = nil
local AL_BLATANT_HITBOXES = {"HitboxHead", "HitboxHeadSmall", "HitboxBody", "HitboxBodySmall"}

local function AL_getHealth(entity)
	local h = 0
	pcall(function()
		if entity.GetHealth then h = entity:GetHealth()
		elseif entity.Health then h = entity.Health
		elseif entity.Humanoid then h = entity.Humanoid.Health end
	end)
	return h
end

local function AL_isEnemy(fighter)
    if not AimLockSettings.TeamCheck then return true end
    local plr = fighter.Player
    if plr == lp then return false end
    
    if SpectateController then
        local duel = SpectateController.CurrentDuelSubject
        local localDueler = duel and duel:GetDueler(lp)
        local localTeam = localDueler and localDueler:Get("TeamID") or nil
        if localTeam and duel and duel.Duelers then
            for _, dueler in next, duel.Duelers do
                if dueler.Player == plr then
                    local team = dueler:Get("TeamID")
                    return team ~= localTeam
                end
            end
        end
    end
    
	local localTeam = lp:GetAttribute("TeamID") or (FighterController and FighterController.LocalFighter and FighterController.LocalFighter:Get("TeamID"))
	local targetTeam = plr:GetAttribute("TeamID") or (fighter.Get and fighter:Get("TeamID"))
	if localTeam == nil or targetTeam == nil then return true end
	return localTeam ~= targetTeam
end

local function AL_clampToHitboxes(char, worldPos)
	local best = nil
	local bestDist = math.huge
	for _, name in ipairs(AL_BLATANT_HITBOXES) do
		local hb = char:FindFirstChild(name)
		if hb and hb:IsA("BasePart") then
			local cf = hb.CFrame
			local size = hb.Size
			local localP = cf:PointToObjectSpace(worldPos)
			local clamped = Vector3.new(
				math.clamp(localP.X, -size.X/2, size.X/2),
				math.clamp(localP.Y, -size.Y/2, size.Y/2),
				math.clamp(localP.Z, -size.Z/2, size.Z/2)
			)
			local worldClamped = cf:PointToWorldSpace(clamped)
			local d = (worldClamped - worldPos).Magnitude
			if d < bestDist then
				bestDist = d
				best = worldClamped
			end
		end
	end
	return best
end

local function AL_getTarget()
	if not AimLockSettings.Enabled then return nil, nil end
	if AimLockSettings.OnlyScope then
		local isAiming = false
		local localFighter = FighterController and FighterController.LocalFighter
		if localFighter then
			local item = localFighter.EquippedItem
			if item then
				pcall(function()
					isAiming = item:Get("IsAiming") == true or (item.ItemInterface and item.ItemInterface:IsScopeActive())
				end)
			end
		end
		if not isAiming then
			AL_LockedTarget = nil
			AL_BlatantLockedFighter = nil
			return nil, nil
		end
	end
	local camera = workspace.CurrentCamera
	local screenCenter = camera.ViewportSize / 2

	local function isBehindWall(part, char)
        if not AimLockSettings.WallCheck then return false end
		local origin = camera.CFrame.Position
		local dir = (part.Position - origin).Unit * (part.Position - origin).Magnitude
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {lp.Character, char, camera}
		local ray = workspace:Raycast(origin, dir, params)
		return ray and ray.Instance and ray.Instance.Transparency < 0.8
	end

	if AL_LockedTarget then
		local fighter = AL_BlatantLockedFighter
		if not fighter and FighterController and type(FighterController.Objects) == "table" then
			for _, f in pairs(FighterController.Objects) do
				if f and f.Entity and f.Entity.Model and (f.Entity.Model:IsAncestorOf(AL_LockedTarget) or f.Entity.Model == AL_LockedTarget.Parent) then
					fighter = f; break
				end
			end
		end
		local isAlive = (AL_getHealth(fighter.Entity) > 0)
		if not AimLockSettings.AliveCheck then isAlive = true end
		local ok = fighter and fighter.Player and fighter.Entity and isAlive
		if not ok or not pcall(function() return not isBehindWall(AL_LockedTarget, fighter.Entity.Model) end) then
			AL_LockedTarget = nil; AL_BlatantLockedFighter = nil
		elseif isBehindWall(AL_LockedTarget, fighter.Entity.Model) then
			AL_LockedTarget = nil; AL_BlatantLockedFighter = nil
		elseif lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") and fighter.Entity.Model:FindFirstChild("HumanoidRootPart") then
			if (fighter.Entity.Model.HumanoidRootPart.Position - lp.Character.HumanoidRootPart.Position).Magnitude > 500 then
				AL_LockedTarget = nil; AL_BlatantLockedFighter = nil
			end
		end
	end

	if not AL_LockedTarget then
		local validTargets = {}
		if not FighterController or type(FighterController.Objects) ~= "table" then return nil, nil end
		for _, fighter in pairs(FighterController.Objects or {}) do
			local isAlive = (AL_getHealth(fighter.Entity) > 0)
			if not AimLockSettings.AliveCheck then isAlive = true end
			if fighter ~= FighterController.LocalFighter and fighter.Entity and isAlive and AL_isEnemy(fighter) then
				local char = fighter.Entity.Model
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if hrp and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
					local worldDist = (hrp.Position - lp.Character.HumanoidRootPart.Position).Magnitude
					if worldDist < 500 then
						local part = char:FindFirstChild(AimLockSettings.TargetPart) or char:FindFirstChild("Head")
						if part then
							local sp, onScreen = camera:WorldToViewportPoint(part.Position)
							if onScreen then
								local mouseDist = (Vector2.new(sp.X, sp.Y) - screenCenter).Magnitude
								if mouseDist < AimLockSettings.FOV and not isBehindWall(part, char) then
									table.insert(validTargets, {
										Part = part,
										Fighter = fighter,
										MouseDist = mouseDist,
										WorldDist = worldDist,
										Health = AL_getHealth(fighter.Entity)
									})
								end
							end
						end
					end
				end
			end
		end

		if #validTargets > 0 then
			table.sort(validTargets, function(a, b)
				local sortMethod = AimLockSettings.TargetSort or "Mouse (Closest)"
				if sortMethod == "Distance (Closest)" then return a.WorldDist < b.WorldDist
				elseif sortMethod == "Distance (Farthest)" then return a.WorldDist > b.WorldDist
				elseif sortMethod == "Health (Lowest)" then return a.Health < b.Health
				elseif sortMethod == "Health (Highest)" then return a.Health > b.Health
				elseif sortMethod == "Mouse (Closest)" then return a.MouseDist < b.MouseDist
				elseif sortMethod == "Mouse (Farthest)" then return a.MouseDist > b.MouseDist
				else return a.MouseDist < b.MouseDist end
			end)
			AL_LockedTarget = validTargets[1].Part
			AL_BlatantLockedFighter = validTargets[1].Fighter
		else
			AL_LockedTarget = nil
			AL_BlatantLockedFighter = nil
		end
	end
	return AL_LockedTarget, AL_BlatantLockedFighter
end

task.spawn(function()
    local CameraController = nil
    pcall(function()
        local playerScripts = lp:WaitForChild("PlayerScripts", 5)
        if playerScripts then
            local controllers = playerScripts:WaitForChild("Controllers", 5)
            if controllers then
                local cc = controllers:WaitForChild("CameraController", 5)
                if cc then CameraController = require(cc) end
            end
        end
    end)
    
    if CameraController and type(CameraController.Update) == "function" and not getgenv()._AimLockHooked then
        getgenv()._AimLockHooked = true
        local oldUpdate = CameraController.Update
        CameraController.Update = function(self, dt)
            oldUpdate(self, dt)
            if not AimLockSettings.Enabled then return end
            
            local target, targetFighter = AL_getTarget()
            if target then
                local camera = workspace.CurrentCamera
                local targetPos = target.Position + ((target.Parent and target.Parent:FindFirstChild("HumanoidRootPart")) and target.Parent.HumanoidRootPart.AssemblyLinearVelocity * dt * 2.2 or Vector3.new(0,0,0))
                local camOrigin = camera.CFrame.Position + ((lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")) and lp.Character.HumanoidRootPart.AssemblyLinearVelocity * dt * 2.2 or Vector3.new(0,0,0))

                if AimLockSettings.AlwaysLockSmooth and targetFighter and targetFighter.Entity and targetFighter.Entity.Model then
                    local char = targetFighter.Entity.Model
                    local clamped = AL_clampToHitboxes(char, targetPos)
                    if clamped then targetPos = clamped end
                end

                local dir = (targetPos - camOrigin).Unit
                local yaw = math.atan2(-dir.X, -dir.Z)
                local pitch = math.asin(math.clamp(dir.Y, -1, 1))
                local targetRot = Vector2.new(pitch, yaw)
                local current = self.Rotation
                local diffYaw = (targetRot.Y - current.Y + math.pi) % (2 * math.pi) - math.pi
                local targetRotAdj = Vector2.new(targetRot.X, current.Y + diffYaw)
                -- ヒットボックス内にエイムが入っているか確認して吸い付き速度を切り替える
                local inHitbox = false
                if targetFighter and targetFighter.Entity and targetFighter.Entity.Model then
                    local char = targetFighter.Entity.Model
                    local aimDir = Vector3.new(
                        -math.sin(self.Rotation.Y) * math.cos(self.Rotation.X),
                        math.sin(self.Rotation.X),
                        -math.cos(self.Rotation.Y) * math.cos(self.Rotation.X)
                    )
                    local aimPoint = camOrigin + aimDir * (targetPos - camOrigin).Magnitude
                    local clamped = AL_clampToHitboxes(char, aimPoint)
                    inHitbox = clamped and (clamped - aimPoint).Magnitude < 0.5
                end
                local smoothness = inHitbox and AimLockSettings.SmoothnessIn or AimLockSettings.SmoothnessOut
                local alpha = math.clamp(1 - smoothness, 0.01, 1)
                self.Rotation = self.Rotation:Lerp(targetRotAdj, alpha)

                if AimLockSettings.AlwaysLockSmooth and targetFighter and targetFighter.Entity and targetFighter.Entity.Model then
                    local char = targetFighter.Entity.Model
                    -- lerp後の現在の向きからエイム先を計算
                    local rot = self.Rotation
                    local postPitch, postYaw = rot.X, rot.Y
                    local postDir = Vector3.new(
                        -math.sin(postYaw) * math.cos(postPitch),
                        math.sin(postPitch),
                        -math.cos(postYaw) * math.cos(postPitch)
                    )
                    local dist = (targetPos - camOrigin).Magnitude
                    local aimPoint = camOrigin + postDir * dist
                    local reclamped = AL_clampToHitboxes(char, aimPoint)
                    if reclamped then
                        local rdir = (reclamped - camOrigin).Unit
                        local finalYaw = math.atan2(-rdir.X, -rdir.Z)
                        local finalPitch = math.asin(math.clamp(rdir.Y, -1, 1))
                        local diffYaw2 = (finalYaw - current.Y + math.pi) % (2 * math.pi) - math.pi
                        local finalRotAdj = Vector2.new(finalPitch, current.Y + diffYaw2)
                        -- 瞬間移動(Snap)ではなく、元のcurrentからSmoothness(alpha)を適用してLerpする
                        self.Rotation = current:Lerp(finalRotAdj, alpha)
                    end
                end
            end
        end
    end
end)

local AimLockToggle = AimLockSection:AddToggle("AimLockEnabled", {
    Text = "Enabled",
    Default = false,
    Callback = function(value)
        AimLockSettings.Enabled = value
        if not value then
            AL_LockedTarget = nil
            AL_BlatantLockedFighter = nil
        end
    end
})

local AimLockDep = AimLockSection:AddDependencyBox()
AimLockDep:AddToggle("AimLockTeamCheck", { Text = "TeamCheck", Default = false, Callback = function(v) AimLockSettings.TeamCheck = v end })
AimLockDep:AddToggle("AimLockAliveCheck", { Text = "AliveCheck", Default = true, Callback = function(v) AimLockSettings.AliveCheck = v end })
AimLockDep:AddSlider("AimLockFOV", { Text = "Fov", Default = 150, Min = 1, Max = 800, Rounding = 0, Callback = function(v) AimLockSettings.FOV = v end })
AimLockDep:AddSlider("AimLockSmoothnessOut", { Text = "Smoothness (Hitbox外)", Default = 0.65, Min = 0, Max = 0.99, Rounding = 2, Callback = function(v) AimLockSettings.SmoothnessOut = v end })
AimLockDep:AddSlider("AimLockSmoothnessIn", { Text = "Smoothness (Hitbox内)", Default = 0.15, Min = 0, Max = 0.99, Rounding = 2, Callback = function(v) AimLockSettings.SmoothnessIn = v end })
AimLockDep:AddToggle("AimLockAlwaysLockSmooth", { Text = "AlwaysLockSmooth", Default = false, Callback = function(v) AimLockSettings.AlwaysLockSmooth = v end })
AimLockDep:AddToggle("AimLockWallCheck", { Text = "WallCheck", Default = false, Callback = function(v) AimLockSettings.WallCheck = v end })
AimLockDep:AddToggle("AimLockOnlyScope", { Text = "OnlyScope", Default = false, Callback = function(v) AimLockSettings.OnlyScope = v end })
AimLockDep:AddDropdown("AimLockTargetPart", {
    Values = {"HitboxHead", "HitboxBody", "Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg"},
    Default = 1,
    Multi = false,
    Text = "Target Part",
    Callback = function(value) AimLockSettings.TargetPart = value end
})
AimLockDep:AddDropdown("AimLockTargetSort", {
    Values = {"Distance (Closest)", "Distance (Farthest)", "Health (Lowest)", "Health (Highest)", "Mouse (Closest)", "Mouse (Farthest)"},
    Default = 5,
    Multi = false,
    Text = "Target Sort",
    Callback = function(value) AimLockSettings.TargetSort = value end
})
AimLockDep:SetupDependencies({ { AimLockToggle, true } })

-- ===== TRIGGERBOT =====
local TriggerBotSection = Tabs.Combat:AddLeftGroupbox("TriggerBot")

getgenv().TriggerBotSettings = {
    Enabled = false,
    Delay = 100,
    MaxDistance = 50,
    TeamCheck = false,
}

local TriggerBotToggle = TriggerBotSection:AddToggle("TriggerBotEnabled", {
    Text = "Enabled",
    Default = false,
    Callback = function(value) getgenv().TriggerBotSettings.Enabled = value end
})

local TriggerBotDep = TriggerBotSection:AddDependencyBox()

TriggerBotDep:AddToggle("TriggerBotTeamCheck", {
    Text = "TeamCheck",
    Default = false,
    Callback = function(value) getgenv().TriggerBotSettings.TeamCheck = value end
})

TriggerBotDep:AddSlider("TriggerBotDelay", {
    Text = "Delay (ms)", Default = 100, Min = 0, Max = 1000, Rounding = 0,
    Callback = function(value) getgenv().TriggerBotSettings.Delay = value end
})

TriggerBotDep:AddSlider("TriggerBotMaxDistance", {
    Text = "Max Distance", Default = 50, Min = 5, Max = 500, Rounding = 0,
    Callback = function(value) getgenv().TriggerBotSettings.MaxDistance = value end
})

TriggerBotDep:SetupDependencies({ { TriggerBotToggle, true } })

task.spawn(function()
    local plrs = game:GetService("Players")
    local runS = game:GetService("RunService")
    local ws = game:GetService("Workspace")
    local lplr = plrs.LocalPlayer
    
    local fC, mC
    pcall(function() fC = require(lplr.PlayerScripts.Controllers.FighterController) end)
    pcall(function() mC = require(lplr.PlayerScripts.Controllers.MechanicsController) end)
    
    local lastShot = 0
    runS.Heartbeat:Connect(function()
        if not getgenv().TriggerBotSettings.Enabled then return end
        
        local cam = ws.CurrentCamera
        if not cam then return end
        local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
        local unitRay = cam:ViewportPointToRay(center.X, center.Y)
        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances = {lplr.Character, cam}
        rayParams.IgnoreWater = true
        
        local maxDist = getgenv().TriggerBotSettings.MaxDistance
        local rayResult = ws:Raycast(unitRay.Origin, unitRay.Direction * maxDist, rayParams)
        
        if not rayResult or not rayResult.Instance then return end
        
        local hitPart = rayResult.Instance
        local hitModel = hitPart:FindFirstAncestorOfClass("Model")
        if not hitModel then return end
        
        local hitPlr = plrs:GetPlayerFromCharacter(hitModel)
        if not hitPlr or hitPlr == lplr then return end
        
        local triggerTeamCheck = getgenv().TriggerBotSettings.TeamCheck
        if triggerTeamCheck then
            local myID = lplr:GetAttribute("TeamID")
            local theirID = hitPlr:GetAttribute("TeamID")
            if theirID == nil or (myID and myID == theirID) then
                if SpectateController then
                    local duel = SpectateController.CurrentDuelSubject
                    local localDueler = duel and duel:GetDueler(lplr)
                    local localTeam = localDueler and localDueler:Get("TeamID") or nil
                    if localTeam and duel and duel.Duelers then
                        local isEnemy = false
                        for _, dueler in next, duel.Duelers do
                            if dueler.Player == hitPlr then
                                local team = dueler:Get("TeamID")
                                if team ~= localTeam then isEnemy = true end
                                break
                            end
                        end
                        if not isEnemy then return end
                    else
                        return
                    end
                else
                    return
                end
            end
        end
        
        local hum = hitModel:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return end
        
        local fighter = fC and fC:GetFighter(lplr)
        if not fighter then return end
        local item = fighter.EquippedItem
        if not item then return end
        
        local ammo = nil
        pcall(function() ammo = item:Get("Ammo") end)
        local reloadCD = item._reload_cooldown or 0
        if (tick() < reloadCD) or (type(ammo) == "number" and ammo <= 0) then return end
        
                local now = tick()
        local delaySec = getgenv().TriggerBotSettings.Delay / 1000
        if now - lastShot < delaySec then return end
        
        lastShot = now
        if mC and type(mC.EquippedItemInput) == "function" then
            mC:EquippedItemInput("StartShooting")
        end
    end)
end)

-- ===== VISUALS TAB =====
local ESPSection = Tabs.Visuals:AddLeftGroupbox("ESP")

local ESPToggle = ESPSection:AddToggle("ESP_Enabled", {
    Text = "Enabled", Default = false,
    Callback = function(value) espSettings.MasterEnabled = value end
})

local ESPDep = ESPSection:AddDependencyBox()

ESPDep:AddToggle("ESP_Box", { Text = "Box", Default = false, Callback = function(v) espSettings.Box = v end })
    :AddColorPicker("ESP_Box_Color", { Default = espSettings.BoxColor, Callback = function(v) espSettings.BoxColor = v end })

ESPDep:AddDropdown("ESP_Box_Type", {
    Text = "Box Type",
    Values = {"Full", "Corner"},
    Default = 1,
    Multi = false,
    Callback = function(v) espSettings.BoxType = v end
})


ESPDep:AddToggle("ESP_BoxFill", { Text = "Box fill", Default = false, Callback = function(v) espSettings.BoxFill = v end })
    :AddColorPicker("ESP_BoxFill_Color", { Default = espSettings.BoxFillColor, Callback = function(v) espSettings.BoxFillColor = v end })

ESPDep:AddToggle("ESP_BoxFillImage", { Text = "Use Image Fill", Default = false, Callback = function(v) espSettings.BoxFillImage = v end })
ESPDep:AddInput("ESP_BoxFillImageID", {
    Default = "",
    Text = "Image ID",
    Tooltip = "Put the Roblox Decal/Image ID here (Numbers only)",
    Placeholder = "e.g. 123456789",
    Callback = function(v)
        if type(v) == "string" then
            espSettings.BoxFillImageID = v:gsub("%D", "")
        elseif type(v) == "number" then
            espSettings.BoxFillImageID = tostring(v)
        else
            espSettings.BoxFillImageID = ""
        end
    end
})

ESPDep:AddToggle("ESP_Distance", { Text = "DistanceEsp", Default = false, Callback = function(v) espSettings.Distance = v end })
    :AddColorPicker("ESP_Distance_Color", { Default = espSettings.DistanceColor, Callback = function(v) espSettings.DistanceColor = v end })

ESPDep:AddToggle("ESP_Weapon", { Text = "WeaponESP", Default = false, Callback = function(v) espSettings.Weapon = v end })
    :AddColorPicker("ESP_Weapon_Color", { Default = espSettings.WeaponColor, Callback = function(v) espSettings.WeaponColor = v end })

ESPDep:AddToggle("ESP_Ammo", { Text = "AmmoESP", Default = false, Callback = function(v) espSettings.Ammo = v end })
    :AddColorPicker("ESP_Ammo_Color", { Default = espSettings.AmmoColor, Callback = function(v) espSettings.AmmoColor = v end })

ESPDep:AddToggle("ESP_Rank", { Text = "RankESP", Default = false, Callback = function(v) espSettings.Rank = v end })

ESPDep:AddToggle("ESP_Katana", { Text = "KatanaESP", Default = false, Callback = function(v) espSettings.Katana = v end })
    :AddColorPicker("ESP_Katana_Color", { Default = espSettings.KatanaColor, Callback = function(v) espSettings.KatanaColor = v end })

ESPDep:AddToggle("ESP_Bone", { Text = "BoneESP", Default = false, Callback = function(v) espSettings.Bone = v end })
    :AddColorPicker("ESP_Bone_Color", { Default = espSettings.BoneColor, Callback = function(v) espSettings.BoneColor = v end })

ESPDep:AddToggle("ESP_Tracer", { Text = "TracerESP", Default = false, Callback = function(v) espSettings.Tracer = v end })
    :AddColorPicker("ESP_Tracer_Color", { Default = espSettings.TracerColor, Callback = function(v) espSettings.TracerColor = v end })

ESPDep:AddToggle("ESP_Name", { Text = "NameESP", Default = false, Callback = function(v) espSettings.Name = v end })
    :AddColorPicker("ESP_Name_Color", { Default = espSettings.NameColor, Callback = function(v) espSettings.NameColor = v end })
    :AddColorPicker("ESP_TextStroke_Color", { Title = "Text Stroke", Default = espSettings.TextStrokeColor, Callback = function(v) espSettings.TextStrokeColor = v end })

ESPDep:AddToggle("ESP_HP", { Text = "HP Bar", Default = false, Callback = function(v) espSettings.HP = v end })
    :AddColorPicker("ESP_HP_Color", { Default = espSettings.HPColor, Callback = function(v) espSettings.HPColor = v end })

ESPDep:AddToggle("ESP_TeamCheck", { Text = "Team Check", Default = false, Callback = function(v) getgenv().ESPSettings_TeamCheck = v end })

ESPDep:SetupDependencies({ { ESPToggle, true } })

-- Team ESP
local TeamESPSection = Tabs.Visuals:AddRightGroupbox("Team ESP")

local TeamESPToggle = TeamESPSection:AddToggle("TeamESP_Enabled", {
    Text = "Enabled", Default = false,
    Callback = function(v) teamEspSettings.Enabled = v end
})

local TeamESPDep = TeamESPSection:AddDependencyBox()

TeamESPDep:AddToggle("TeamESP_Box", { Text = "Box", Default = true,
    Callback = function(v) teamEspSettings.Box = v end })
    :AddColorPicker("TeamESP_Box_Color", { Default = teamEspSettings.BoxColor,
        Callback = function(v) teamEspSettings.BoxColor = v end })

TeamESPDep:AddDropdown("TeamESP_Box_Type", {
    Text = "Box Type",
    Values = {"Full", "Corner"},
    Default = 1,
    Multi = false,
    Callback = function(v) teamEspSettings.BoxType = v end
})

TeamESPDep:AddToggle("TeamESP_Name", { Text = "Name", Default = true,
    Callback = function(v) teamEspSettings.Name = v end })
    :AddColorPicker("TeamESP_Name_Color", { Default = teamEspSettings.NameColor,
        Callback = function(v) teamEspSettings.NameColor = v end })

TeamESPDep:AddToggle("TeamESP_HP", { Text = "HP Bar", Default = false,
    Callback = function(v) teamEspSettings.HP = v end })

TeamESPDep:AddToggle("TeamESP_Tracer", { Text = "Tracer", Default = false,
    Callback = function(v) teamEspSettings.Tracer = v end })
    :AddColorPicker("TeamESP_Tracer_Color", { Default = teamEspSettings.TracerColor,
        Callback = function(v) teamEspSettings.TracerColor = v end })

TeamESPDep:SetupDependencies({ { TeamESPToggle, true } })

local CrosshairSection = Tabs.Visuals:AddRightGroupbox("Custom Crosshair")

local chEnabled = false
local chTextStr = "kei.win"
local chLineColor = Color3.fromRGB(255, 255, 255)
local chRainbow = true
local chStretch = true
local chSpin = true


local chGui = Instance.new("ScreenGui")
chGui.Name = "CustomCrosshairGui"
chGui.ResetOnSpawn = false
chGui.IgnoreGuiInset = true
chGui.Parent = getESPContainerParent()
chGui.Enabled = false

local chCenter = Instance.new("Frame")
chCenter.Name = "CenterFrame"
chCenter.Size = UDim2.new(0, 0, 0, 0)
chCenter.AnchorPoint = Vector2.new(0.5, 0.5)
chCenter.Position = UDim2.new(0.5, 0, 0.5, 0)
chCenter.BackgroundTransparency = 1
chCenter.Parent = chGui

local function makeCHLine(parent)
    local outer = Instance.new("Frame")
    outer.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    outer.BackgroundTransparency = 0.2
    outer.BorderSizePixel = 0
    outer.Parent = parent

    local inner = Instance.new("Frame")
    inner.Name = "MainLine"
    inner.Size = UDim2.new(1, -2, 1, -2)
    inner.Position = UDim2.new(0, 1, 0, 1)
    inner.BackgroundTransparency = 0
    inner.BorderSizePixel = 0
    inner.Parent = outer

    return outer, inner
end

local chUpO, chUpI = makeCHLine(chCenter)
local chRightO, chRightI = makeCHLine(chCenter)
local chLeftO, chLeftI = makeCHLine(chCenter)
local chDownO, chDownI = makeCHLine(chCenter)

local chText = Instance.new("TextLabel")
chText.Name = "CrosshairText"
chText.Size = UDim2.new(0, 200, 0, 20)
chText.AnchorPoint = Vector2.new(0.5, 0)
chText.Position = UDim2.new(0.5, 0, 0.5, 45)
chText.BackgroundTransparency = 1
chText.Text = chTextStr
chText.TextSize = 16
chText.Font = Enum.Font.Arcade
chText.TextColor3 = Color3.fromRGB(255, 255, 255)
chText.TextStrokeTransparency = 0
chText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
chText.Parent = chGui

local function chEaseOutQuad(t)
    return 1 - (1 - t) * (1 - t)
end

local chConn
local function updateCrosshair(dt)
    if not chEnabled then return end
    local t = tick()
    
    local cColor = chLineColor
    if chRainbow then cColor = Color3.fromHSV((t * 0.5) % 1, 1, 1) end

    local length = 28
    if chStretch then
        local raw = math.sin(t * 4)
        length = 28 + chEaseOutQuad((raw + 1) / 2) * 12
    end

    chUpO.Size = UDim2.new(0, 4, 0, length)
    chUpO.Position = UDim2.new(0.5, -2, 0.5, -length - 10)
    chUpI.BackgroundColor3 = cColor

    chRightO.Size = UDim2.new(0, length, 0, 4)
    chRightO.Position = UDim2.new(0.5, 10, 0.5, -2)
    chRightI.BackgroundColor3 = cColor

    chLeftO.Size = UDim2.new(0, length, 0, 4)
    chLeftO.Position = UDim2.new(0.5, -length - 10, 0.5, -2)
    chLeftI.BackgroundColor3 = cColor

    chDownO.Size = UDim2.new(0, 4, 0, length)
    chDownO.Position = UDim2.new(0.5, -2, 0.5, 10)
    chDownI.BackgroundColor3 = cColor

    chText.TextColor3 = cColor
    chText.Text = chTextStr

    if chSpin then
        chCenter.Rotation = (chCenter.Rotation + dt * 180) % 360
    else
        chCenter.Rotation = 0
    end
end

CrosshairSection:AddToggle("Crosshair_Enable", {
    Text = "Enable Crosshair",
    Default = false,
    Callback = function(v) 
        chEnabled = v
        chGui.Enabled = v
        if v then
            if chConn then chConn:Disconnect() end
            chConn = RunService.RenderStepped:Connect(updateCrosshair)
        else
            if chConn then chConn:Disconnect() chConn = nil end
        end
    end
})

CrosshairSection:AddInput("Crosshair_Text", {
    Default = "kei.win",
    Numeric = false,
    Finished = true,
    Text = "Crosshair Text",
    Placeholder = "Enter text...",
    Callback = function(v) chTextStr = v end
})

CrosshairSection:AddToggle("Crosshair_Rainbow", {
    Text = "Rainbow Animation",
    Default = true,
    Callback = function(v) chRainbow = v end
}):AddColorPicker("Crosshair_Color", {
    Default = Color3.fromRGB(255,255,255),
    Callback = function(v) chLineColor = v end
})

CrosshairSection:AddToggle("Crosshair_Stretch", {
    Text = "Stretch Animation",
    Default = true,
    Callback = function(v) chStretch = v end
})

CrosshairSection:AddToggle("Crosshair_Spin", {
    Text = "Spin Animation",
    Default = true,
    Callback = function(v) chSpin = v end
})

-- ===== BULLET TRACER TAB (VISUALS) =====
local BulletTracerSection = Tabs.Visuals:AddRightGroupbox("Bullet Tracer")

local btEnabled = false
local btWidth = 2
local btFadeTime = 4

BulletTracerSection:AddToggle("BulletTracerToggle", {
    Text = "Enable Bullet Tracer",
    Default = false,
    Callback = function(v) btEnabled = v end
})

BulletTracerSection:AddSlider("BulletTracerWidth", {
    Text = "Thickness",
    Default = 2,
    Min = 0.1,
    Max = 10,
    Rounding = 1,
    Compact = false,
    Callback = function(v) btWidth = v end
})

BulletTracerSection:AddSlider("BulletTracerFade", {
    Text = "Fade Time",
    Default = 4,
    Min = 0.1,
    Max = 10,
    Rounding = 1,
    Compact = false,
    Callback = function(v) btFadeTime = v end
})

task.spawn(function()
    local function findModule(parent, name)
        local found = parent:FindFirstChild(name, true)
        if found and found:IsA("ModuleScript") then return found end
        return nil
    end

    local GunModule = nil
    while not GunModule do
        GunModule = findModule(lp:WaitForChild("PlayerScripts"), "Gun") or findModule(game:GetService("ReplicatedStorage"), "Gun")
        task.wait(1)
    end
    
    local Gun = require(GunModule)
    
    local tracerColor      = Color3.fromRGB(190, 40, 255)
    local tracerStayTime   = 0
    local tracerFadeStyle  = Enum.EasingStyle.Quart

    local BEAM_CONFIGS = {
        { Name = "Beam2", Texture = "rbxassetid://84577820022939", Speed = 1, Length = 1, LightInf = 0 },
        { Name = "Beam3", Texture = "rbxassetid://15253860988",    Speed = 1, Length = 3, LightInf = 1 },
        { Name = "Beam",  Texture = "rbxassetid://18664874807",    Speed = 3, Length = 3, LightInf = 1 },
        { Name = "Beam1", Texture = "rbxassetid://12251459424",    Speed = 1, Length = 1, LightInf = 1 },
    }

    local TweenService = game:GetService("TweenService")
    local function drawRichTracers(self, data)
        if not (data and data.IsLocal) then return end
        local ok, muzzle = pcall(function() return self.ViewModel:GetMuzzlePosition() end)
        if not ok or typeof(muzzle) ~= "Vector3" then return end
        local cam = workspace.CurrentCamera
        if not cam then return end
        
        local colorSeq = ColorSequence.new(tracerColor)
        local initTrans = NumberSequence.new(0.5)

        for _, res in ipairs(data.RaycastResults or {}) do
            if not res or typeof(res.Position) ~= "Vector3" then continue end
            pcall(function()
                local container = Instance.new("Part")
                container.Anchored = true
                container.CanCollide = false
                container.Transparency = 1
                container.CFrame = CFrame.new()
                container.Parent = cam
                
                local attStart = Instance.new("Attachment", container)
                attStart.Name = "start"
                attStart.WorldPosition = muzzle
                
                local attHit = Instance.new("Attachment", container)
                attHit.Name = "Hit"
                attHit.WorldPosition = res.Position
                
                local beams = {}
                for _, cfg in ipairs(BEAM_CONFIGS) do
                    local b = Instance.new("Beam")
                    b.Name = cfg.Name
                    b.Attachment0 = attStart
                    b.Attachment1 = attHit
                    b.Texture = cfg.Texture
                    b.TextureSpeed = cfg.Speed
                    b.TextureLength = cfg.Length
                    b.Color = colorSeq
                    b.LightEmission = 1
                    b.LightInfluence = cfg.LightInf
                    b.Brightness = 1
                    b.Width0 = btWidth
                    b.Width1 = btWidth
                    b.FaceCamera = true
                    b.Transparency = initTrans
                    b.Parent = container
                    table.insert(beams, b)
                end
                
                local alive = true
                local fadeVal = Instance.new("NumberValue", container)
                fadeVal.Value = 0
                
                local tw = TweenService:Create(
                    fadeVal,
                    TweenInfo.new(btFadeTime, tracerFadeStyle, Enum.EasingDirection.Out),
                    { Value = 1 }
                )
                
                local conn = fadeVal:GetPropertyChangedSignal("Value"):Connect(function()
                    if not alive then return end
                    local v = fadeVal.Value
                    if type(v) ~= "number" then return end
                    local trans = 0.5 + (0.5 * v)
                    local width = btWidth * (1 - v)
                    local seq = NumberSequence.new(math.clamp(trans, 0, 1))
                    for _, b in ipairs(beams) do
                        pcall(function()
                            b.Transparency = seq
                            b.Width0 = width
                            b.Width1 = width
                        end)
                    end
                end)
                
                task.delay(math.max(tracerStayTime, 0), function()
                    if not alive then return end
                    tw:Play()
                    task.delay(btFadeTime + 0.2, function()
                        alive = false
                        if conn then pcall(function() conn:Disconnect() end) end
                        pcall(function()
                            if container.Parent then container:Destroy() end
                        end)
                    end)
                end)
            end)
        end
    end

    if not getgenv()._bulletTracerHooked_Rich then
        local oldTracers = Gun._Tracers
        Gun._Tracers = function(self, data, p2, p3)
            if btEnabled then
                drawRichTracers(self, data)
            end
            return oldTracers(self, data, p2, p3)
        end
        getgenv()._bulletTracerHooked_Rich = true
    end
end)

-- ===== ENVIRONMENT TAB (WORLD) =====
local EnvSection = Tabs.World:AddLeftGroupbox("Environment")

local Lighting = game:GetService("Lighting")
local origAmbient = Lighting.Ambient
local origClockTime = Lighting.ClockTime

local envSettings = {
    WorldColorEnabled = false,
    Ambient = Color3.fromRGB(120, 0, 200),
    ClockTime = 2,
    CCEnabled = false,
    CCTint = Color3.fromRGB(160, 100, 255),
    CCSaturation = 0.6,
    CCContrast = 0.2,
    SnowEnabled = false,
    SnowColor = Color3.fromRGB(255, 255, 255),
    SnowRate = 10000,
    SnowSpeed = 30
}

local function updateWorldColor()
    if envSettings.WorldColorEnabled then
        Lighting.Ambient = envSettings.Ambient
        Lighting.ClockTime = envSettings.ClockTime
    else
        Lighting.Ambient = origAmbient
        Lighting.ClockTime = origClockTime
    end
end

local function updateCC()
    local cc = Lighting:FindFirstChild("ModpackCorrection")
    if not cc then
        cc = Instance.new("ColorCorrectionEffect")
        cc.Name = "ModpackCorrection"
        cc.Parent = Lighting
    end
    cc.Enabled = envSettings.CCEnabled
    cc.TintColor = envSettings.CCTint
    cc.Saturation = envSettings.CCSaturation
    cc.Contrast = envSettings.CCContrast
end

local snowPart, snowEmitter, snowConn
local function updateSnow()
    if not snowPart then
        snowPart = Instance.new("Part")
        snowPart.Name = "ModpackSnowPart"
        snowPart.Transparency = 1
        snowPart.Anchored = true
        snowPart.CanCollide = false
        snowPart.Size = Vector3.new(60, 1, 60)
        
        snowEmitter = Instance.new("ParticleEmitter", snowPart)
        snowEmitter.Acceleration = Vector3.new(0, 0, 0)
        snowEmitter.Brightness = 50 
        snowEmitter.Drag = 0
        snowEmitter.EmissionDirection = Enum.NormalId.Bottom
        snowEmitter.Lifetime = NumberRange.new(5, 10)
        snowEmitter.LightEmission = 1 
        snowEmitter.LightInfluence = 0
        snowEmitter.RotSpeed = NumberRange.new(0, 0)
        snowEmitter.Rotation = NumberRange.new(0, 0)
        snowEmitter.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.33),
            NumberSequenceKeypoint.new(0.55, 0.40),
            NumberSequenceKeypoint.new(1, 0.33)
        })
        snowEmitter.SpreadAngle = Vector2.new(50, 50)
        snowEmitter.Squash = NumberSequence.new(0)
        snowEmitter.Texture = "rbxassetid://99851851"
        snowEmitter.TimeScale = 1
        snowEmitter.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.98, 0.04),
            NumberSequenceKeypoint.new(1, 1)
        })
        snowEmitter.ZOffset = 1 
        snowPart.Parent = workspace
        
        snowConn = RunService.RenderStepped:Connect(function()
            local cam = workspace.CurrentCamera
            if cam and snowPart then
                snowPart.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, 50, 0))
            end
        end)
    end
    
    if envSettings.SnowEnabled then
        snowEmitter.Enabled = true
        snowEmitter.Color = ColorSequence.new(envSettings.SnowColor)
        snowEmitter.Rate = envSettings.SnowRate
        snowEmitter.Speed = NumberRange.new(envSettings.SnowSpeed, envSettings.SnowSpeed)
    else
        snowEmitter.Enabled = false
    end
end

EnvSection:AddToggle("Env_WorldColor_Enabled", {
    Text = "Enable Custom Lighting", Default = false,
    Callback = function(v) envSettings.WorldColorEnabled = v; updateWorldColor() end
}):AddColorPicker("Env_Ambient_Color", {
    Default = envSettings.Ambient, Title = "Ambient Color",
    Callback = function(v) envSettings.Ambient = v; updateWorldColor() end
})

EnvSection:AddSlider("Env_ClockTime", {
    Text = "Time of Day", Default = 2, Min = 0, Max = 24, Rounding = 1,
    Callback = function(v) envSettings.ClockTime = v; updateWorldColor() end
})

EnvSection:AddToggle("Env_CC_Enabled", {
    Text = "Enable Color Correction", Default = false,
    Callback = function(v) envSettings.CCEnabled = v; updateCC() end
}):AddColorPicker("Env_CC_Tint", {
    Default = envSettings.CCTint, Title = "Tint Color",
    Callback = function(v) envSettings.CCTint = v; updateCC() end
})

EnvSection:AddSlider("Env_CC_Saturation", {
    Text = "Saturation", Default = 0.6, Min = -1, Max = 1, Rounding = 1,
    Callback = function(v) envSettings.CCSaturation = v; updateCC() end
})

EnvSection:AddSlider("Env_CC_Contrast", {
    Text = "Contrast", Default = 0.2, Min = -1, Max = 1, Rounding = 1,
    Callback = function(v) envSettings.CCContrast = v; updateCC() end
})

EnvSection:AddToggle("Env_Snow_Enabled", {
    Text = "Enable Snow", Default = false,
    Callback = function(v) envSettings.SnowEnabled = v; updateSnow() end
}):AddColorPicker("Env_Snow_Color", {
    Default = envSettings.SnowColor, Title = "Snow Color",
    Callback = function(v) envSettings.SnowColor = v; updateSnow() end
})

EnvSection:AddSlider("Env_Snow_Rate", {
    Text = "Snow Density", Default = 10000, Min = 100, Max = 50000, Rounding = 0,
    Callback = function(v) envSettings.SnowRate = v; updateSnow() end
})

EnvSection:AddSlider("Env_Snow_Speed", {
    Text = "Snow Speed", Default = 30, Min = 1, Max = 100, Rounding = 0
})

local RageBotSection = Tabs.Rage:AddRightGroupbox("RageBot")

getgenv().RageBotConfig = {
    Enabled = false,
    WeaponSlot = "Primary",
    FireRate = 0.0005,
    TargetSort = "Distance (Closest)"
}

RageBotSection:AddToggle("RageBot_Enabled", {
    Text = "Enable RageBot",
    Default = false,
    Callback = function(value)
        getgenv().RageBotConfig.Enabled = value
    end
})

RageBotSection:AddDropdown("RageBot_Slot", {
    Values = {"Primary", "Secondary", "Melee"},
    Default = 1,
    Multi = false,
    Text = "Weapon Slot",
    Callback = function(value)
        getgenv().RageBotConfig.WeaponSlot = value
    end
})

RageBotSection:AddDropdown("RageBot_TargetSort", {
    Values = {"Distance (Closest)", "Distance (Farthest)", "Health (Lowest)", "Health (Highest)", "Mouse (Closest)", "Mouse (Farthest)"},
    Default = 1,
    Multi = false,
    Text = "Target Sort",
    Callback = function(value)
        getgenv().RageBotConfig.TargetSort = value
    end
})

task.spawn(function()
    local plrs = cloneref(game:GetService("Players"))
    local repS = cloneref(game:GetService("ReplicatedStorage"))
    local runS = cloneref(game:GetService("RunService"))
    local ws   = cloneref(game:GetService("Workspace"))
    local lplr = plrs.LocalPlayer
    local util = nil
    local enum = nil
    pcall(function() util = require(repS.Modules.Utility) end)
    pcall(function() enum = require(repS.Modules.EnumLibrary) end)
    
    local slots = { Primary = 1, Secondary = 2, Melee = 3 }
    local function getSlotNumber() return slots[getgenv().RageBotConfig.WeaponSlot] or 3 end
    
    task.spawn(function()
        while true do
            task.wait(1)
            if not getgenv().RageBotConfig.Enabled then continue end
            local localFighter = FighterController and FighterController.LocalFighter
            if localFighter then
                pcall(function() localFighter:EquipItem(getSlotNumber()) end)
            end
        end
    end)

    local lastFire = 0
    local deflecting = {}
    plrs.PlayerRemoving:Connect(function(player) deflecting[player] = nil end)

    local function updateDeflection()
        if not FighterController or not FighterController.Objects then return end
        for _, fighterObj in FighterController.Objects do
            local player = fighterObj.Player
            if not player then continue end
            if not fighterObj.Entity or not fighterObj.Entity:IsAlive() or fighterObj:Get("IsSpectating") then
                deflecting[player] = false
                continue
            end
            local equipped = fighterObj.EquippedItem
            local isKatana = equipped and equipped.ViewModel and equipped.ViewModel.Name == "Katana"
            local isDeflecting = false
            if isKatana then
                isDeflecting = (equipped._attack_cooldown and equipped._attack_cooldown > tick()) or false
            end
            deflecting[player] = isDeflecting
        end
    end

    local function isEnemy(player)
        if player == lplr then return false end
        local duel = SpectateController and SpectateController.CurrentDuelSubject
        local localDueler = duel and duel:GetDueler(lplr)
        local localTeam = localDueler and localDueler:Get("TeamID") or nil
        if localTeam and duel and duel.Duelers then
            for _, dueler in duel.Duelers do
                if dueler.Player == player then
                    local team = dueler:Get("TeamID")
                    return team ~= localTeam
                end
            end
        end
        local pTeam = player:GetAttribute("TeamID")
        local lTeam = lplr:GetAttribute("TeamID")
        if pTeam and lTeam then return pTeam ~= lTeam end
        return true
    end

    local function getClosestTarget()
        local char = lplr.Character
        if not char then return nil, nil, nil end
        local myRoot = char:FindFirstChild("HumanoidRootPart")
        if not myRoot then return nil, nil, nil end
        
        local cam = workspace.CurrentCamera
        local center = cam and Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2) or Vector2.zero

        local validTargets = {}
        for _, player in plrs:GetPlayers() do
            if not isEnemy(player) then continue end
            local pChar = player.Character
            if not pChar then continue end
            local pRoot = pChar:FindFirstChild("HumanoidRootPart")
            local pHead = pChar:FindFirstChild("HitboxHead") or pChar:FindFirstChild("Head")
            local pHum = pChar:FindFirstChildWhichIsA("Humanoid")
            if not (pRoot and pHead and pHum and pHum.Health > 0) then continue end
            
            local worldDist = (myRoot.Position - pRoot.Position).Magnitude
            if worldDist < 500 then
                local mouseDist = math.huge
                if cam then
                    local screenPos, onScreen = cam:WorldToViewportPoint(pRoot.Position)
                    if onScreen then
                        mouseDist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                    end
                end
                
                table.insert(validTargets, {
                    Player = player,
                    Root = pRoot,
                    Head = pHead,
                    WorldDist = worldDist,
                    MouseDist = mouseDist,
                    Health = pHum.Health
                })
            end
        end
        
        if #validTargets > 0 then
            table.sort(validTargets, function(a, b)
                local sortMethod = getgenv().RageBotConfig.TargetSort or "Distance (Closest)"
                if sortMethod == "Distance (Closest)" then return a.WorldDist < b.WorldDist
                elseif sortMethod == "Distance (Farthest)" then return a.WorldDist > b.WorldDist
                elseif sortMethod == "Health (Lowest)" then return a.Health < b.Health
                elseif sortMethod == "Health (Highest)" then return a.Health > b.Health
                elseif sortMethod == "Mouse (Closest)" then return a.MouseDist < b.MouseDist
                elseif sortMethod == "Mouse (Farthest)" then return a.MouseDist > b.MouseDist
                else return a.WorldDist < b.WorldDist end
            end)
            return validTargets[1].Player, validTargets[1].Root, validTargets[1].Head
        end

        return nil, nil, nil
    end

    runS.Heartbeat:Connect(function()
        if not getgenv().RageBotConfig.Enabled then return end
        updateDeflection()
        local myRoot = lplr.Character and lplr.Character:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end

        local item = nil
        local isReloading = false
        if FighterController and FighterController.LocalFighter then
            item = FighterController.LocalFighter.EquippedItem
            if item then
                pcall(function()
                    local ammo = item:Get("Ammo")
                    local reloadCD = item._reload_cooldown or 0
                    isReloading = (tick() < reloadCD) or (type(ammo) == "number" and ammo <= 0)
                end)
            end
        end

        local targetPlayer, targetRoot, targetHead = getClosestTarget()

        local myFF = false
        local targetFF = false
        pcall(function()
            local lf = FighterController and FighterController.LocalFighter
            if lf and lf.Entity then myFF = lf.Entity:Get("IsInvincible") == true end
        end)
        if targetPlayer then
            pcall(function()
                local fighter = FighterController:GetFighter(targetPlayer)
                if fighter and fighter.Entity then targetFF = fighter.Entity:Get("IsInvincible") == true end
            end)
        end

        local canAttack = getgenv().RageBotConfig.Enabled
            and myRoot ~= nil
            and (not isReloading)
            and (not myFF)
            and (not targetFF)
            and targetPlayer ~= nil
            and targetRoot ~= nil
            and targetHead ~= nil
            and (not deflecting[targetPlayer])
            and item ~= nil

        local desyncCF
        if canAttack then
            local targetLowerTorso = targetPlayer.Character and targetPlayer.Character:FindFirstChild("LowerTorso")
            local baseCFrame = targetLowerTorso and targetLowerTorso.CFrame or targetRoot.CFrame
            local desyncPos = (baseCFrame * CFrame.new(0, 5, 0)).Position
            desyncCF = CFrame.lookAt(desyncPos, targetHead.Position)
        else
            local randomDir = Vector3.new(math.random(-100, 100), math.random(-100, 100), math.random(-100, 100)).Unit
            local cam = ws.CurrentCamera
            local camPos = cam and cam.CFrame.Position or Vector3.new(0, 0, 0)
            desyncCF = CFrame.new(camPos + randomDir * 7000000000000)
        end

        local oldCF     = myRoot.CFrame
        local oldVel    = myRoot.Velocity
        local oldRotVel = myRoot.RotVelocity
        local _stepName = "__rb_" .. tostring(math.random(100000, 999999))
        myRoot.CFrame = desyncCF
        runS:BindToRenderStep(_stepName, 101, function()
            if myRoot then
                myRoot.CFrame      = oldCF
                myRoot.Velocity    = oldVel
                myRoot.RotVelocity = oldRotVel
            end
            runS:UnbindFromRenderStep(_stepName)
        end)

        if not canAttack then return end
        if tick() - lastFire < getgenv().RageBotConfig.FireRate then return end
        lastFire = tick()

        if not util or not enum then return end

        local originPos = desyncCF.Position
        local targetPos = targetHead.Position
        local aimCF    = CFrame.lookAt(originPos, targetPos)
        local targetCF = targetHead.CFrame
        local randomOffset = Vector3.new((math.random() - 0.5) * 0.1, (math.random() - 0.5) * 0.1, (math.random() - 0.5) * 0.1)
        local aimedPos = targetPos + randomOffset
        local objSpaceHeadOffset = targetHead.CFrame:ToObjectSpace(CFrame.new(aimedPos))
        local cameradata = {}
        cameradata[utf8.char(1)] = {
            [utf8.char(0)] = util:EncodeCFrame(aimCF),
            [utf8.char(1)] = util:EncodeCFrame(targetCF),
            [utf8.char(2)] = targetHead,
            [utf8.char(3)] = util:EncodeCFrame(objSpaceHeadOffset)
        }
        repS.Remotes.Replication.Fighter.UseItem:FireServer(
            item:Get("ObjectID"),
            enum:ToEnum("StartShooting"),
            cameradata,
            nil
        )
    end)
end)
local GunModsSection = Tabs.Rage:AddLeftGroupbox("Gun Mods")

getgenv().RageSettings = {
    Enabled = false,
    NoRecoil = false,
    NoSpread = false,
    RapidFire = false,
    AntiKatana = false,
    AntiKatanaDelay = 0.0,
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
                            if getgenv().RageSettings.Enabled and getgenv().RageSettings.NoSpread then return true end
                            return originalIsFullyAiming(weaponSelf, ...)
                        end
                    else
                        self.IsFullyAiming = function() return getgenv().RageSettings.Enabled and getgenv().RageSettings.NoSpread end
                    end
                end

                -- Anti-Katana: StartShooting繧偵ヵ繝・け
                local origSS = self.StartShooting
                if type(origSS) == "function" and not self._isAntiKatanaSSHooked then
                    self._isAntiKatanaSSHooked = true
                    self.StartShooting = function(gunSelf, ...)
                        if getgenv().RageSettings.Enabled and getgenv().RageSettings.AntiKatana then
                            local now = tick()
                            local cam = workspace.CurrentCamera
                            local delay = getgenv().RageSettings.AntiKatanaDelay or 0
                            for p, endTime in pairs(DeflectingPlayers) do
                                local startTime = (getgenv().DeflectingStartTimes and getgenv().DeflectingStartTimes[p]) or (endTime - 1)
                                if now < endTime and now >= (startTime + delay) and p ~= lp and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                                    local _, onScreen = cam:WorldToScreenPoint(p.Character.HumanoidRootPart.Position)
                                    if onScreen then return false end
                                end
                            end
                        end
                        return origSS(gunSelf, ...)
                    end
                end

                -- Anti-Katana: Shot:Fire()繧偵ヵ繝・け・井ｺ亥ｙ・・
                if self.Shot and not self._isAntiKatanaShotHooked then
                    self._isAntiKatanaShotHooked = true
                    local origShotFire = self.Shot.Fire
                    self.Shot.Fire = function(sig, ...)
                        if getgenv().RageSettings.Enabled and getgenv().RageSettings.AntiKatana then
                            local now = tick()
                            local cam = workspace.CurrentCamera
                            local delay = getgenv().RageSettings.AntiKatanaDelay or 0
                            for p, endTime in pairs(DeflectingPlayers) do
                                local startTime = (getgenv().DeflectingStartTimes and getgenv().DeflectingStartTimes[p]) or (endTime - 1)
                                if now < endTime and now >= (startTime + delay) and p ~= lp and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                                    local _, onScreen = cam:WorldToViewportPoint(p.Character.HumanoidRootPart.Position)
                                    if onScreen then return end
                                end
                            end
                        end
                        return origShotFire(sig, ...)
                    end
                end

                return originalEquip(self, ...)
            end
        end
    end

    local inputFunc = clientItemModule.Input
    if type(inputFunc) == "function" and not clientItemModule._isInputHooked then
        clientItemModule._isInputHooked = true
        clientItemModule.Input = function(self, ...)
            if not getgenv().RageSettings.Enabled then
                return inputFunc(self, ...)
            end
            if type(self) == "table" and self.Info then
                local gunName = self.Name or tostring(self)
                if not OriginalStats[gunName] then
                    OriginalStats[gunName] = {
                        ShootRecoil = self.Info.ShootRecoil,
                        ShootSpread = self.Info.ShootSpread,
                        ShootCooldown = self.Info.ShootCooldown,
                        QuickShotCooldown = self.Info.QuickShotCooldown,
                        ShootBurstCooldown = self.Info.ShootBurstCooldown,
                        AttackCooldown = self.Info.AttackCooldown,
                        SwingCooldown = self.Info.SwingCooldown,
                        MeleeCooldown = self.Info.MeleeCooldown,
                        Cooldown = self.Info.Cooldown,
                        RecoveryTime = self.Info.RecoveryTime,
                        ResetTime = self.Info.ResetTime
                    }
                end
                local orig = OriginalStats[gunName]
                if not self._isStatsHooked then
                    self._isStatsHooked = true
                    if setreadonly then pcall(function() setreadonly(self.Info, false) end) end
                end

                local rapid = getgenv().RageSettings.RapidFire and 0.001 or nil

                local overrides = {
                    ShootRecoil = getgenv().RageSettings.NoRecoil and 0 or orig.ShootRecoil,
                    ShootSpread = getgenv().RageSettings.NoSpread and 0 or orig.ShootSpread,
                    ShootCooldown = rapid or orig.ShootCooldown,
                    QuickShotCooldown = rapid or orig.QuickShotCooldown,
                    ShootBurstCooldown = rapid or orig.ShootBurstCooldown,
                    AttackCooldown = rapid or orig.AttackCooldown,
                    SwingCooldown = rapid or orig.SwingCooldown,
                    MeleeCooldown = rapid or orig.MeleeCooldown,
                    Cooldown = rapid or orig.Cooldown,
                    RecoveryTime = rapid or orig.RecoveryTime,
                    ResetTime = rapid or orig.ResetTime
                }

                for prop, tgtValue in pairs(overrides) do
                    -- 繧ゅ→繧ゅ→縺昴・豁ｦ蝎ｨ縺ｫ繝励Ο繝代ユ繧｣縺悟ｭ伜惠縺吶ｋ蝣ｴ蜷医・縺ｿ荳頑嶌縺阪☆繧・
                    if orig[prop] ~= nil and self.Info[prop] ~= tgtValue then
                        self.Info[prop] = tgtValue
                    end
                end
            end
            return inputFunc(self, ...)
        end
    end
end)


local GunModsToggle = GunModsSection:AddToggle("GunMods_Enabled", {
    Text = "Enabled",
    Default = false,
    Callback = function(value)
        getgenv().RageSettings.Enabled = value
    end
})

local GunModsDep = GunModsSection:AddDependencyBox()

GunModsDep:AddToggle("GunMods_NoSpread", {
    Text = "No Spread",
    Default = false,
    Callback = function(value)
        getgenv().RageSettings.NoSpread = value
    end
})

GunModsDep:AddToggle("GunMods_NoRecoil", {
    Text = "No Recoil",
    Default = false,
    Callback = function(value)
        getgenv().RageSettings.NoRecoil = value
    end
})

GunModsDep:AddToggle("GunMods_RapidFire", {
    Text = "Rapid Fire",
    Default = false,
    Callback = function(value)
        getgenv().RageSettings.RapidFire = value
    end
})

GunModsDep:AddToggle("GunMods_AntiKatana", {
    Text = "Anti Katana",
    Default = false,
    Callback = function(value)
        getgenv().RageSettings.AntiKatana = value
    end
})

GunModsDep:AddSlider("GunMods_AntiKatanaDelay", {
    Text = "Anti Katana Delay (sec)",
    Default = 0.0,
    Min = 0.0,
    Max = 1.0,
    Rounding = 2,
    Callback = function(value)
        getgenv().RageSettings.AntiKatanaDelay = value
    end
})

GunModsDep:SetupDependencies({ { GunModsToggle, true } })




do
    local autoQueueEnabled = false
    local autoQueueName = nil
    local autoQueueDisplayToInternal = {}
    local MatchmakingController = nil
    local CONSTANTS_REF = nil
    local DEFAULT_DISPLAYS = { "1v1", "2v2", "3v3", "4v4", "5v5", "Ranked 1v1", "Ranked 2v2", "Ranked 3v3" }
    local tryQueueRef
    
    local AutoQueueBox = Tabs.Misc:AddLeftGroupbox("Auto Queue")
    
    AutoQueueBox:AddToggle("AutoQueueToggle", {
        Text = "Enabled",
        Default = false,
        Tooltip = "Automatically start matchmaking when not in-game or when match ends.\nWill re-queue if canceled.",
        Callback = function(Value)
            autoQueueEnabled = Value
            if Value and tryQueueRef then
                task.spawn(function() task.wait(0.2); pcall(tryQueueRef) end)
            end
        end,
    })
    
    local AutoQueueDropObj = AutoQueueBox:AddDropdown("AutoQueueDrop", {
        Values = DEFAULT_DISPLAYS,
        Default = 1,
        Multi = false,
        Text = "Queue Type",
        Callback = function(Value)
            autoQueueName = autoQueueDisplayToInternal[Value] or Value
        end,
    })
    
    task.spawn(function()
        local DuelLibrary
        local ok = pcall(function()
            DuelLibrary = require(ReplicatedStorage:WaitForChild("Modules", 15):WaitForChild("DuelLibrary", 15))
        end)
        if not ok or type(DuelLibrary) ~= "table" or type(DuelLibrary.MatchmakingQueues) ~= "table" then
            return
        end
        pcall(function()
            CONSTANTS_REF = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CONSTANTS"))
        end)
        pcall(function()
            MatchmakingController = require(lp:WaitForChild("PlayerScripts"):WaitForChild("Controllers"):WaitForChild("MatchmakingController"))
        end)
        
        local entries = {}
        for queueName, queueInfo in pairs(DuelLibrary.MatchmakingQueues) do
            local display = queueName
            if type(queueInfo) == "table" then
                display = queueInfo.DisplayName or queueInfo.TitleName or queueName
            end
            table.insert(entries, { display = tostring(display), internal = queueName })
        end
        table.sort(entries, function(a, b) return a.display < b.display end)
        
        local labels = {}
        autoQueueDisplayToInternal = {}
        for _, e in ipairs(entries) do
            table.insert(labels, e.display)
            autoQueueDisplayToInternal[e.display] = e.internal
        end
        
        if AutoQueueDropObj then
            pcall(function() AutoQueueDropObj:SetValues(labels) end)
            if labels[1] then
                autoQueueName = autoQueueDisplayToInternal[labels[1]] or labels[1]
            end
        end
    end)
    
    local function isInActiveDuel()
        local inMatchmakingServer = false
        if CONSTANTS_REF then inMatchmakingServer = CONSTANTS_REF.IS_MATCHMAKING_SERVER and true or false end
        if not inMatchmakingServer then return false end
        
        local gameOver = false
        if MatchmakingController and type(MatchmakingController.Get) == "function" then
            pcall(function() gameOver = MatchmakingController:Get("MatchmadeGameOver") end)
        end
        return not gameOver
    end
    
    local autoQueueInvoking = false
    local function tryQueue()
        if autoQueueInvoking then return end
        if not autoQueueEnabled then return end
        if not autoQueueName or autoQueueName == "" then return end
        if not MatchmakingController then return end
        if isInActiveDuel() then return end
        
        autoQueueInvoking = true
        pcall(function() MatchmakingController:QueueInto(autoQueueName) end)
        autoQueueInvoking = false
    end
    tryQueueRef = tryQueue
    
    task.spawn(function()
        while true do
            task.wait(3)
            if autoQueueEnabled then
                pcall(tryQueue)
            end
        end
    end)
    
    task.spawn(function()
        while not MatchmakingController do task.wait(0.5) end
        if MatchmakingController.MatchmadeDuelEnded then
            MatchmakingController.MatchmadeDuelEnded:Connect(function()
                if autoQueueEnabled then
                    task.wait(0.5)
                    pcall(tryQueue)
                end
            end)
        end
    end)
end

-- ========== CHARM SPOOFER ==========
do
local charmRankList = {
    "Use Spoofed ELO",
    "Unranked",
    "Bronze 1", "Bronze 2", "Bronze 3",
    "Silver 1", "Silver 2", "Silver 3",
    "Gold 1", "Gold 2", "Gold 3",
    "Platinum 1", "Platinum 2", "Platinum 3",
    "Diamond 1", "Diamond 2", "Diamond 3",
    "Onyx 1", "Onyx 2", "Onyx 3",
    "Nemesis", "Archnemesis",
}
local charmEloMap = {
    ["Unranked"] = -1,
    ["Bronze 1"] = 0,   ["Bronze 2"] = 200,  ["Bronze 3"] = 400,
    ["Silver 1"] = 600, ["Silver 2"] = 800,  ["Silver 3"] = 1000,
    ["Gold 1"] = 1200,  ["Gold 2"] = 1400,   ["Gold 3"] = 1600,
    ["Platinum 1"] = 1800, ["Platinum 2"] = 2000, ["Platinum 3"] = 2200,
    ["Diamond 1"] = 2400,  ["Diamond 2"] = 2600,  ["Diamond 3"] = 2800,
    ["Onyx 1"] = 3000,  ["Onyx 2"] = 3200,   ["Onyx 3"] = 3400,
    ["Nemesis"] = 3600, ["Archnemesis"] = 3600,
}
local charmSeasonNameMap = {
    [0] = "Zero", [1] = "Warp", [2] = "Polar", [3] = "Fame",
    ["Zero"] = 0, ["Warp"] = 1, ["Polar"] = 2, ["Fame"] = 3,
}
local charmSeasonToggleMap = {
    [0] = "s0", [1] = "s1", [2] = "s2", [3] = "s3",
}

local charmState = {
    charm_rank = "Use Spoofed ELO",
    arch_rank = 1,
    s0 = false, s1 = false, s2 = false, s3 = false,
}

local charmHooked = false

local function applyCharmHook()
    if charmHooked then return end
    local sl = nil
    pcall(function()
        sl = require(ReplicatedStorage:WaitForChild("Modules", 5):WaitForChild("SeasonLibrary", 5))
    end)
    if not sl or not sl.FormatSeasonRankCharm then return end
    charmHooked = true

    local original_fsrc = sl.FormatSeasonRankCharm
    sl.FormatSeasonRankCharm = function(self, p2, p3, p4, p5)
        local season_num = charmSeasonNameMap[p3]
        local toggleKey = season_num and charmSeasonToggleMap[season_num]
        if toggleKey and charmState[toggleKey] then
            local elo = charmEloMap[charmState.charm_rank]
            if not elo then
                -- "Use Spoofed ELO" → そのままp4を使う
                elo = p4
            end
            p4 = elo
            p5 = charmState.arch_rank
        end
        return original_fsrc(self, p2, p3, p4, p5)
    end
end

local function refreshCharms()
    task.spawn(function()
        task.wait(1)
        for _, desc in ipairs(workspace:GetDescendants()) do
            if not desc:IsA("Model") then continue end
            if not desc:FindFirstChild("Extra") then continue end
            local name = desc.Name
            if string.sub(name, 1, 7) ~= "Season " then continue end
            local season_num = tonumber(string.sub(name, 8))
            if not season_num then continue end
            local toggleKey = charmSeasonToggleMap[season_num]
            if not toggleKey or not charmState[toggleKey] then continue end
            local season_name = charmSeasonNameMap[season_num]
            if not season_name then continue end
            local elo = charmEloMap[charmState.charm_rank] or lp:GetAttribute("ELO") or 0
            pcall(function()
                local sl = require(ReplicatedStorage:WaitForChild("Modules", 5):WaitForChild("SeasonLibrary", 5))
                sl:FormatSeasonRankCharm(desc, season_name, elo, charmState.arch_rank)
            end)
        end
    end)
end

local CharmSection = Tabs.Misc:AddRightGroupbox("Charm Spoofer")

CharmSection:AddDropdown("Charm_Rank", {
    Text = "Charm Rank",
    Values = charmRankList,
    Default = 1,
    Multi = false,
    Callback = function(v)
        charmState.charm_rank = v
        applyCharmHook()
        refreshCharms()
    end,
})

CharmSection:AddSlider("Charm_ArchRank", {
    Text = "Arch Rank",
    Default = 1, Min = 1, Max = 100, Rounding = 0,
    Callback = function(v)
        charmState.arch_rank = v
        refreshCharms()
    end,
})

CharmSection:AddToggle("Charm_S0", { Text = "Season 0 Charm", Default = false,
    Callback = function(v) charmState.s0 = v; applyCharmHook(); refreshCharms() end })
CharmSection:AddToggle("Charm_S1", { Text = "Season 1 Charm", Default = false,
    Callback = function(v) charmState.s1 = v; applyCharmHook(); refreshCharms() end })
CharmSection:AddToggle("Charm_S2", { Text = "Season 2 Charm", Default = false,
    Callback = function(v) charmState.s2 = v; applyCharmHook(); refreshCharms() end })
CharmSection:AddToggle("Charm_S3", { Text = "Season 3 Charm", Default = false,
    Callback = function(v) charmState.s3 = v; applyCharmHook(); refreshCharms() end })
end -- do CharmSpoofer

-- ========== UNLOCK ALL ==========

local UnlockAllSection = Tabs.Misc:AddLeftGroupbox("Unlock All")
UnlockAllSection:AddToggle("UnlockAllToggle", {
    Text = "Enable Unlock All",
    Default = false,
    Callback = function(value)
        getgenv().UnlockAllEnabled = value
        if value and not getgenv().UnlockAllExecuted then
            getgenv().UnlockAllExecuted = true
            task.spawn(function()
                -- [EMBEDDED UNLOCKALL.LUA]


-- Unlock All Skins / Wraps / Charms.
local _plrs    = game:GetService("Players")
local _rs      = game:GetService("ReplicatedStorage")
local _http    = game:GetService("HttpService")
local _run     = game:GetService("RunService")
local _ws      = game:GetService("Workspace")
local _lp      = _plrs.LocalPlayer
local _pscripts = _lp.PlayerScripts
local _ctrl    = _pscripts.Controllers
local _mods    = _rs:WaitForChild("Modules", 10)

local _enumLib = require(_mods:WaitForChild("EnumLibrary", 10))
if _enumLib then pcall(function() _enumLib:WaitForEnumBuilder() end) end

local _cosLib  = require(_mods:WaitForChild("CosmeticLibrary", 10))
local _itmLib  = require(_mods:WaitForChild("ItemLibrary", 10))
local _datCtrl = require(_ctrl:WaitForChild("PlayerDataController", 10))

local _eq, _favs = {}, {}
local _buildingWep, _viewProf = nil, nil
local _lastWep = nil
local _fakeInv = {}

local function _mkCosmetic(nm, ctype, opts)
    local _base = _cosLib.Cosmetics[nm]
    if not _base then return nil end
    local _d = {}
    for k, v in pairs(_base) do _d[k] = v end
    _d.Name = nm
    _d.Type = _d.Type or ctype
    _d.Seed = _d.Seed or math.random(1, 1000000)
    if _enumLib then
        local _s, _eid = pcall(_enumLib.ToEnum, _enumLib, nm)
        if _s and _eid then
            _d.Enum = _eid
            _d.ObjectID = _d.ObjectID or _eid
        end
    end
    if opts then
        if opts.inverted ~= nil then _d.Inverted = opts.inverted end
        if opts.favoritesOnly ~= nil then _d.OnlyUseFavorites = opts.favoritesOnly end
    end
    return _d
end

local _cfgFile = "rivals_unlocker_config.json"
local _saveLock = false

local function _stripForSave()
    local _out = {}
    for wn, cos in pairs(_eq) do
        _out[wn] = {}
        for ct, cd in pairs(cos) do
            if cd and cd.Name then
                _out[wn][ct] = {
                    Name = cd.Name,
                    Inverted = cd.Inverted,
                    OnlyUseFavorites = cd.OnlyUseFavorites
                }
            end
        end
    end
    return { equipped = _out, favorites = _favs }
end

local function _loadCfg()
    if not isfile or not readfile then return end
    local _ok1, _ex = pcall(isfile, _cfgFile)
    if not _ok1 or not _ex then return end
    local _ok2, _raw = pcall(readfile, _cfgFile)
    if not _ok2 or not _raw or _raw == "" then return end
    local _ok3, _dec = pcall(_http.JSONDecode, _http, _raw)
    if not _ok3 or not _dec then return end
    if _dec.favorites then
        _favs = _dec.favorites
    end
    if _dec.equipped then
        _eq = {}
        local _cnt = 0
        for wn, cos in pairs(_dec.equipped) do
            _eq[wn] = {}
            for ct, sd in pairs(cos) do
                if sd and sd.Name then
                    if _cosLib.Cosmetics[sd.Name] then
                        local _cloned = _mkCosmetic(sd.Name, ct, {
                            inverted = sd.Inverted,
                            favoritesOnly = sd.OnlyUseFavorites
                        })
                        if _cloned then
                            _eq[wn][ct] = _cloned
                            _cnt += 1
                        end
                    end
                end
            end
            if not next(_eq[wn]) then _eq[wn] = nil end
        end
    end
end

local function _saveCfg()
    if not writefile or _saveLock then return end
    _saveLock = true
    task.spawn(function()
        task.wait(1)
        local _payload = _stripForSave()
        local _ok, _enc = pcall(_http.JSONEncode, _http, _payload)
        if _ok then
            pcall(writefile, _cfgFile, _enc)
        end
        _saveLock = false
    end)
end

_loadCfg()

local _cosTypes = {Skin = true, Wrap = true, Charm = true, Dance = true, Emote = true}
local function _isCosType(cosObj)
    if not cosObj then return false end
    return _cosTypes[cosObj.Type] == true
end

local _origOwnsNormally = _cosLib.OwnsCosmeticNormally
_cosLib.OwnsCosmeticNormally = function(self, inv, nm, wep)
    if not getgenv().UnlockAllEnabled then return _origOwnsNormally(self, inv, nm, wep) end
    local c = _cosLib.Cosmetics[nm]
    if c and c.Type == "Skin" then return true end
    return false
end
local _origOwnsUniversally = _cosLib.OwnsCosmeticUniversally
_cosLib.OwnsCosmeticUniversally = function(self, inv, nm, wep)
    if not getgenv().UnlockAllEnabled then return _origOwnsUniversally(self, inv, nm, wep) end
    local c = _cosLib.Cosmetics[nm]
    if c and c.Type == "Skin" then return true end
    return false
end
local _origOwnsForWep = _cosLib.OwnsCosmeticForWeapon
_cosLib.OwnsCosmeticForWeapon = function(self, inv, nm, wep)
    if not getgenv().UnlockAllEnabled then return _origOwnsForWep(self, inv, nm, wep) end
    local c = _cosLib.Cosmetics[nm]
    if c and c.Type == "Skin" then return true end
    return false
end

local _origOwns = _cosLib.OwnsCosmetic
_cosLib.OwnsCosmetic = function(self, inv, nm, wep)
    if not getgenv().UnlockAllEnabled then return _origOwns(self, inv, nm, wep) end
    if nm:find("MISSING_") or nm == "Bubble Gun" then
        return _origOwns(self, inv, nm, wep)
    end
    local c = _cosLib.Cosmetics[nm]
    if c and _isCosType(c) then return true end
    return _origOwns(self, inv, nm, wep)
end

local _cachedCosmeticProxy = nil
local _origGet = _datCtrl.Get
_datCtrl.Get = function(self, key)
    local _val = _origGet(self, key)
    if not getgenv().UnlockAllEnabled then return _val end
    if key == "CosmeticInventory" then
        if _cachedCosmeticProxy then return _cachedCosmeticProxy end
        local _prx = {}
        if _val then
            for k, v in pairs(_val) do
                local c = _cosLib.Cosmetics[k]
                if c and _isCosType(c) then _prx[k] = v end
            end
        end
        _cachedCosmeticProxy = setmetatable(_prx, {
            __index = function(t, k)
                local c = _cosLib.Cosmetics[k]
                if c and _isCosType(c) then return true end
                return nil
            end
        })
        return _cachedCosmeticProxy
    end
    if key == "FavoritedCosmetics" then
        local _res = _val and table.clone(_val) or {}
        for wep, fv in pairs(_favs) do
            _res[wep] = _res[wep] or {}
            for nm, isFav in pairs(fv) do
                local c = _cosLib.Cosmetics[nm]
                if c and _isCosType(c) then
                    _res[wep][nm] = isFav
                end
            end
        end
        return _res
    end
    return _val
end

local _wepDataCache = {}
local _origGetWep = _datCtrl.GetWeaponData
_datCtrl.GetWeaponData = function(self, wn)
    local _d = _origGetWep(self, wn)
    if not getgenv().UnlockAllEnabled then return _d end
    if not _d then return nil end
    if _wepDataCache[wn] then return _wepDataCache[wn] end
    local _m = {}
    for k, v in pairs(_d) do _m[k] = v end
    _m.Name = wn
    if _eq[wn] then
        for ct, cd in pairs(_eq[wn]) do
            _m[ct] = cd
        end
    end
    _wepDataCache[wn] = _m
    return _m
end

local _fightCtrl
pcall(function()
    _fightCtrl = require(_ctrl:WaitForChild("FighterController", 10))
end)

if hookmetamethod then
    local _remotes   = _rs:FindFirstChild("Remotes")
    local _dataRem   = _remotes and _remotes:FindFirstChild("Data")
    local _equipRem  = _dataRem and _dataRem:FindFirstChild("EquipCosmetic")
    local _favRem    = _dataRem and _dataRem:FindFirstChild("FavoriteCosmetic")

    if _equipRem then
        local _onc
        _onc = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if method ~= "FireServer" then
                return _onc(self, ...)
            end
            if not getgenv().UnlockAllEnabled then return _onc(self, ...) end

            if self == _equipRem then
                local _wn, _ct, _cn, _opts = ...
                _opts = _opts or {}
                if _cn and _cn ~= "None" and _cn ~= "" then
                    local _inv = _datCtrl:Get("CosmeticInventory")
                    if _inv and rawget(_inv, _cn) then
                        return _onc(self, ...)
                    end
                end
                _eq[_wn] = _eq[_wn] or {}
                if not _cn or _cn == "None" or _cn == "" then
                    _eq[_wn][_ct] = nil
                    if not next(_eq[_wn]) then _eq[_wn] = nil end
                else
                    local _cloned = _mkCosmetic(_cn, _ct, {
                        inverted = _opts.IsInverted,
                        favoritesOnly = _opts.OnlyUseFavorites
                    })
                    if _cloned then _eq[_wn][_ct] = _cloned end
                end
                if _wepDataCache then table.clear(_wepDataCache) end
                task.defer(function()
                    pcall(function() _datCtrl.CurrentData:Replicate("WeaponInventory") end)
                end)
                _saveCfg()
                return
            end

            if self == _favRem then
                local a1, a2, a3 = ...
                local _cos = _cosLib.Cosmetics[a2]
                if _cos then
                    _favs[a1] = _favs[a1] or {}
                    _favs[a1][a2] = a3 or nil
                    task.spawn(function()
                        pcall(function() _datCtrl.CurrentData:Replicate("FavoritedCosmetics") end)
                    end)
                    _saveCfg()
                end
                return
            end

            return _onc(self, ...)
        end)
    end
end

local _cliItem
pcall(function()
    _cliItem = require(_lp.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem)
end)

if _cliItem and _cliItem._CreateViewModel then
    local _origCVM = _cliItem._CreateViewModel
    _cliItem._CreateViewModel = function(self, vmRef)
        if not getgenv().UnlockAllEnabled then return _origCVM(self, vmRef) end
        local _wn  = self.Name
        local _wp  = self.ClientFighter and self.ClientFighter.Player
        _buildingWep = (_wp == _lp) and _wn or nil
        if _wp == _lp and _eq[_wn] then
            local _dk = self:ToEnum("Data")
            if vmRef[_dk] then
                if _eq[_wn].Skin then
                    vmRef[_dk][self:ToEnum("Skin")] = _eq[_wn].Skin
                    vmRef[_dk][self:ToEnum("Name")] = _eq[_wn].Skin.Name
                end
                if _eq[_wn].Charm then vmRef[_dk][self:ToEnum("Charm")] = _eq[_wn].Charm end
                if _eq[_wn].Wrap  then vmRef[_dk][self:ToEnum("Wrap")]  = _eq[_wn].Wrap  end
            elseif vmRef.Data then
                if _eq[_wn].Skin  then vmRef.Data.Skin  = _eq[_wn].Skin; vmRef.Data.Name = _eq[_wn].Skin.Name end
                if _eq[_wn].Charm then vmRef.Data.Charm = _eq[_wn].Charm end
                if _eq[_wn].Wrap  then vmRef.Data.Wrap  = _eq[_wn].Wrap  end
            end
        end
        local _r = _origCVM(self, vmRef)
        _buildingWep = nil
        return _r
    end
end

local _vmMod = _lp.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem:FindFirstChild("ClientViewModel")
if _vmMod then
    local _CVM = require(_vmMod)
    local _origNew = _CVM.new
    local _RC  = require(_rs.Modules.ReplicatedClass)
    local _dk  = _RC:ToEnum("Data")
    local _ekSkin = _RC:ToEnum("Skin")
    local _ekCharm = _RC:ToEnum("Charm")
    local _ekWrap = _RC:ToEnum("Wrap")
    _CVM.new = function(repData, cliItm)
        if not getgenv().UnlockAllEnabled then return _origNew(repData, cliItm) end
        local _wp  = cliItm.ClientFighter and cliItm.ClientFighter.Player
        local _wn  = _buildingWep or cliItm.Name
        if _wp == _lp and _eq[_wn] then
            repData[_dk] = repData[_dk] or {}
            local _cos = _eq[_wn]
            if _cos.Skin  then repData[_dk][_ekSkin]  = _cos.Skin  end
            if _cos.Charm then repData[_dk][_ekCharm] = _cos.Charm end
            if _cos.Wrap  then repData[_dk][_ekWrap]  = _cos.Wrap  end
        end
        return _origNew(repData, cliItm)
    end
end
                -- [END EMBEDDED UNLOCKALL.LUA]
            end)
        end
    end
})
-- ========== DEVICE SPOOFER ==========
local DeviceSpoofSection = Tabs.Misc:AddLeftGroupbox("Device Spoofer")

local DeviceSpooferToggle, DeviceSpoofDropdownObj

DeviceSpooferToggle = DeviceSpoofSection:AddToggle("DeviceSpoofToggle", {
    Text = "Enable Device Spoofer",
    Default = false,
    Callback = function(value)
        if value and DeviceSpoofDropdownObj then
            task.defer(function()
                pcall(function()
                    ReplicatedStorage.Remotes.Replication.Fighter.SetControls:FireServer(DeviceSpoofDropdownObj.Value)
                end)
            end)
        end
    end
})

local DeviceSpoofDep = DeviceSpoofSection:AddDependencyBox()
DeviceSpoofDropdownObj = DeviceSpoofDep:AddDropdown("DeviceSpoofDropdown", {
    Values = {"Touch", "MouseKeyboard", "Gamepad", "VR"},
    Multi = false,
    Text = "Select Device",
    Callback = function(value)
        -- 螟画峩縺励◆縺縺代〒縺ｯ襍ｰ繧峨↑縺・ｈ縺・↓縺吶ｋ・医が繝ｳ縺ｫ縺励◆譎ゅ・縺ｿ・・
    end
})
DeviceSpoofDep:SetupDependencies({ { DeviceSpooferToggle, true } })

-- ========== DAMAGE NOTIFICATION ==========
do
local dmgNotifEnabled = false
local dmgNotifMin = 1
local dmgNotifCooldown = 0.3
local _dmgConnections = {}
local _dmgLastTime = {}

local _lastHitmarkerTime = 0
local _hitmarkerHooked = false

local function hookHitmarker()
    if _hitmarkerHooked then return end
    pcall(function()
        local cvmObj = lp.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem:FindFirstChild("ClientViewModel")
        if cvmObj then
            -- SoundChangerと同じ方法でChildAddedを使ってヒット音を検出
            cvmObj.ChildAdded:Connect(function(v)
                if v:IsA("Sound") then
                    _lastHitmarkerTime = tick()
                end
            end)
            _hitmarkerHooked = true
        end
    end)
end

local _hookCoroutine = nil
local function startHookLoop()
    if _hookCoroutine then return end
    _hookCoroutine = task.spawn(function()
        while dmgNotifEnabled do
            if not _hitmarkerHooked then
                hookHitmarker()
            end
            task.wait(0.5)
        end
        _hookCoroutine = nil
    end)
end

local function attachDmgNotif(p)
    if _dmgConnections[p] then
        pcall(function() _dmgConnections[p]:Disconnect() end)
        _dmgConnections[p] = nil
    end
    if not p.Character then return end
    local hum = p.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    local prevHP = hum.Health
    _dmgConnections[p] = hum.HealthChanged:Connect(function(newHP)
        if not dmgNotifEnabled then return end
        
        local dmg = prevHP - newHP
        prevHP = newHP
        if dmg < dmgNotifMin then return end
        
        -- HealthChangedがHitmarker再生よりも先に届く場合（PropertyReplicationの方が早い場合）があるため、
        -- 少し待ってから判定する
        task.spawn(function()
            task.wait(0.15)
            
            -- フックがまだなら試行
            if not _hitmarkerHooked then hookHitmarker() end
            
            -- 自分がダメージを与えた（直近0.8秒以内にHitmarkerが鳴った）か判定
            -- pingによる遅延を考慮して0.8秒の猶予を持たせる
            if tick() - _lastHitmarkerTime > 0.8 then return end

            local now = tick()
            if _dmgLastTime[p] and now - _dmgLastTime[p] < dmgNotifCooldown then return end
            _dmgLastTime[p] = now
            local dmgStr = math.floor(dmg)
            local hpLeft = math.max(0, math.floor(newHP))
            Library:Notify(
                "Hit " .. p.Name .. " for " .. dmgStr .. " damage! (" .. hpLeft .. " HP left)",
                3
            )
        end)
    end)
end

local function refreshDmgConnections()
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= lp then
            attachDmgNotif(p)
            p.CharacterAdded:Connect(function()
                task.wait(0.5)
                attachDmgNotif(p)
            end)
        end
    end
end

Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function()
        task.wait(0.5)
        attachDmgNotif(p)
    end)
end)
Players.PlayerRemoving:Connect(function(p)
    if _dmgConnections[p] then
        pcall(function() _dmgConnections[p]:Disconnect() end)
        _dmgConnections[p] = nil
    end
end)

local DmgNotifSection = Tabs.Misc:AddLeftGroupbox("Damage Notification")
DmgNotifSection:AddToggle("DmgNotif_Enabled", {
    Text = "Enabled", Default = false,
    Callback = function(v)
        dmgNotifEnabled = v
        if v then 
            refreshDmgConnections() 
            startHookLoop()
        end
    end,
})
DmgNotifSection:AddSlider("DmgNotif_Min", {
    Text = "Min Damage", Default = 1, Min = 1, Max = 100, Rounding = 0,
    Callback = function(v) dmgNotifMin = v end,
})
DmgNotifSection:AddSlider("DmgNotif_Cooldown", {
    Text = "Cooldown (s)", Default = 0.3, Min = 0, Max = 3, Rounding = 1,
    Callback = function(v) dmgNotifCooldown = v end,
})
end -- do DamageNotification

-- ========== ANTI BAN ==========

local AntiBanSection = Tabs.Misc:AddRightGroupbox("Anti Ban")

local StaffDetectorEnabled = false
local StaffDetectorAction = "Notify"
local ArchNemesisEnabled = false

local STAFF_GROUP_ID = 3461453
local StaffRoles = {
    ["Community Staff"] = true,
    Tester = true,
    Builder = true,
    Developer = true,
    Scripter = true
}

local function HandleStaffDetection(player, role)
    local msg = "笞・・STAFF DETECTED 笞・十nName: " .. player.Name .. "\nRole: " .. role
    if StaffDetectorAction == "Kick" then
        lp:Kick(msg)
    else
        Library:Notify(msg, 5)
    end
end

local function CheckPlayerAntiBan(player)
    if not StaffDetectorEnabled and not ArchNemesisEnabled then return end
    if player == lp then return end

    task.spawn(function()
        if StaffDetectorEnabled then
            local success, role = pcall(function() return player:GetRoleInGroup(STAFF_GROUP_ID) end)
            if success and StaffRoles[role] then
                HandleStaffDetection(player, role)
                return
            end
        end

        if ArchNemesisEnabled then
            local success, seasonLib = pcall(function()
                return require(ReplicatedStorage:WaitForChild("Modules", 5):WaitForChild("SeasonLibrary", 5))
            end)
            if success and seasonLib then
                local stats = player:WaitForChild("CustomLeaderstats", 5)
                if stats then
                    local eloVal = stats:WaitForChild("Current ELO", 5)
                    if eloVal then
                        local function checkRank()
                            if not ArchNemesisEnabled then return end
                            local elo = tonumber(eloVal.Value) or 0
                            local rankName = seasonLib:GetRank(elo, player.UserId)
                            if type(rankName) == "string" and rankName == "Archnemesis" then
                                HandleStaffDetection(player, "Archnemesis Rank")
                            end
                        end
                        checkRank()
                        eloVal.Changed:Connect(checkRank)
                    end
                end
            end
        end
    end)
end

AntiBanSection:AddToggle("StaffDetectorToggle", {
    Text = "Staff Detector",
    Default = false,
    Callback = function(value)
        StaffDetectorEnabled = value
        if value then
            for _, p in pairs(Players:GetPlayers()) do
                CheckPlayerAntiBan(p)
            end
        end
    end
})

AntiBanSection:AddDropdown("StaffDetectorAction", {
    Values = {"Notify", "Kick"},
    Default = 1,
    Multi = false,
    Text = "Action",
    Callback = function(value) StaffDetectorAction = value end
})

AntiBanSection:AddToggle("ArchNemesisToggle", {
    Text = "ArchNemesis Checker",
    Default = false,
    Callback = function(value)
        ArchNemesisEnabled = value
        if value then
            for _, p in pairs(Players:GetPlayers()) do
                CheckPlayerAntiBan(p)
            end
        end
    end
})

Players.PlayerAdded:Connect(function(player)
    CheckPlayerAntiBan(player)
end)

-- ========== SOUND CHANGER ==========
local SoundChangerSection = Tabs.Misc:AddRightGroupbox("Sound Changer")

-- HitSoundChanger
local soundChangerEnabled = false
local soundtochange = "rbxassetid://4764109000" --Rust Sound
local soundChangerConnection = nil

local function updateSoundChanger()
    if soundChangerEnabled then
        if not soundChangerConnection then
            pcall(function()
                local clientViewModel = game:GetService("Players").LocalPlayer.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem.ClientViewModel
                soundChangerConnection = clientViewModel.ChildAdded:Connect(function(v)
                    if v:IsA("Sound") and v.SoundId ~= "rbxassetid://16537449730" then
                        v.SoundId = soundtochange
                        v.Pitch = 1
                        v.Volume = 1
                    end
                end)
            end)
        end
    else
        if soundChangerConnection then
            soundChangerConnection:Disconnect()
            soundChangerConnection = nil
        end
    end
end

local SoundChangerToggle = SoundChangerSection:AddToggle("SoundChangerToggle", {
    Text = "HitSoundChanger",
    Default = false,
    Callback = function(value)
        soundChangerEnabled = value
        updateSoundChanger()
    end
})

local SoundChangerDep = SoundChangerSection:AddDependencyBox()
SoundChangerDep:AddInput("SoundChangerID", {
    Default = "4764109000",
    Numeric = true,
    Finished = false,
    Text = "Sound ID",
    Placeholder = "Enter Sound ID",
    Callback = function(value)
        local id = string.match(tostring(value), "%d+")
        if id then
            soundtochange = "rbxassetid://" .. id
        end
    end
})
SoundChangerDep:SetupDependencies({ { SoundChangerToggle, true } })

-- KillSoundChanger
local killSoundEnabled = false
local killSoundId = "rbxassetid://137918234220296"
local SoundService = game:GetService("SoundService")
local deathSound = Instance.new("Sound")
deathSound.SoundId = killSoundId
deathSound.Volume = 1
deathSound.Parent = SoundService

local function playKillSound()
    if killSoundEnabled then
        deathSound.SoundId = killSoundId
        deathSound:Play()
    end
end

local function onCharacterAdded(character)
    local humanoid = character:WaitForChild("Humanoid", 10)
    if humanoid then
        humanoid.Died:Connect(playKillSound)
    end
end

local function onPlayerAdded(player)
    if player.Character then
        onCharacterAdded(player.Character)
    end
    player.CharacterAdded:Connect(onCharacterAdded)
end

for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, player)
end
Players.PlayerAdded:Connect(onPlayerAdded)

local KillSoundToggle = SoundChangerSection:AddToggle("KillSoundToggle", {
    Text = "KillSoundChanger",
    Default = false,
    Callback = function(value)
        killSoundEnabled = value
    end
})

local KillSoundDep = SoundChangerSection:AddDependencyBox()
KillSoundDep:AddInput("KillSoundID", {
    Default = "137918234220296",
    Numeric = true,
    Finished = false,
    Text = "Kill Sound ID",
    Placeholder = "Enter Sound ID",
    Callback = function(value)
        local id = string.match(tostring(value), "%d+")
        if id then
            killSoundId = "rbxassetid://" .. id
            deathSound.SoundId = killSoundId
        end
    end
})
KillSoundDep:SetupDependencies({ { KillSoundToggle, true } })

-- ========== ANIMATION PLAYER ==========
local AnimationPlayerSection = Tabs.Misc:AddLeftGroupbox("Animation Player")

local animPlayerEnabled = false
local animPlayerId = "rbxassetid://97893809425239"
local animPlayerSpeed = 1

local currentAnim = nil
local currentTrack = nil
local currentStoppedConn = nil
local charAddedConn = nil
local animatorConn = nil

local function stopAnimation()
    if currentStoppedConn then pcall(function() currentStoppedConn:Disconnect() end) currentStoppedConn = nil end
    if animatorConn then pcall(function() animatorConn:Disconnect() end) animatorConn = nil end
    if currentTrack then pcall(function() currentTrack:Stop() end) currentTrack = nil end
    if charAddedConn then pcall(function() charAddedConn:Disconnect() end) charAddedConn = nil end
    currentAnim = nil
end

local function playAnimation(char)
    if not animPlayerEnabled or not currentAnim then return end
    
    task.spawn(function()
        local humanoid = char:WaitForChild("Humanoid", 5)
        local animator = humanoid and humanoid:WaitForChild("Animator", 5)
        
        if animator then
            -- 遒ｺ螳溘↓繝ｯ繝ｼ繧ｯ繧ｹ繝壹・繧ｹ遲峨↓驟咲ｽｮ縺輔ｌ繧九∪縺ｧ蟆代＠蠕・ｩ・
            while char.Parent == nil do
                task.wait(0.1)
            end
            task.wait(0.5) -- 繝ｪ繧ｹ繝昴・繝ｳ逶ｴ蠕後・繝ｩ繧ｰ蟇ｾ遲・
            
            if not animPlayerEnabled or not currentAnim then return end
            
            if currentTrack then
                local t = currentTrack
                currentTrack = nil
                pcall(function() t:Stop() end)
            end
            if animatorConn then
                pcall(function() animatorConn:Disconnect() end)
                animatorConn = nil
            end
            
            pcall(function()
                currentTrack = animator:LoadAnimation(currentAnim)
                currentTrack.Priority = Enum.AnimationPriority.Action4
                currentTrack.Looped = true
                currentTrack:Play()
                currentTrack:AdjustSpeed(animPlayerSpeed)

                for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
                    if t ~= currentTrack then pcall(function() t:Stop() end) end
                end

                animatorConn = animator.AnimationPlayed:Connect(function(t)
                    if currentTrack and t ~= currentTrack then
                        pcall(function() t:Stop() end)
                    end
                end)
            end)
        end
    end)
end

local function updateAnimationPlayer()
    stopAnimation()

    if animPlayerEnabled then
        local success, objects = pcall(function()
            return game:GetObjects(animPlayerId)
        end)

        if success and objects then
            for _, obj in ipairs(objects) do
                local anim = obj:IsA("Animation") and obj or obj:FindFirstChildWhichIsA("Animation", true)
                if anim then
                    currentAnim = anim
                    break
                end
            end
        end

        if currentAnim then
            if lp.Character then task.spawn(playAnimation, lp.Character) end
            charAddedConn = lp.CharacterAdded:Connect(playAnimation)
        else
            warn("GetObjects failed or no Animation found.")
        end
    end
end

local AnimationPlayerToggle = AnimationPlayerSection:AddToggle("AnimationPlayerToggle", {
    Text = "Enabled",
    Default = false,
    Callback = function(value)
        animPlayerEnabled = value
        updateAnimationPlayer()
    end
})

local AnimationPlayerDep = AnimationPlayerSection:AddDependencyBox()
AnimationPlayerDep:AddInput("AnimationPlayerID", {
    Default = "97893809425239",
    Numeric = true,
    Finished = false,
    Text = "Animation ID",
    Placeholder = "Enter Animation ID",
    Callback = function(value)
        local id = string.match(tostring(value), "%d+")
        if id then
            animPlayerId = "rbxassetid://" .. id
            if animPlayerEnabled then
                updateAnimationPlayer()
            end
        end
    end
})

AnimationPlayerDep:AddSlider("AnimationPlayerSpeed", {
    Text = "Speed",
    Default = 1,
    Min = 0.1,
    Max = 30,
    Rounding = 1,
    Callback = function(value)
        animPlayerSpeed = value
        if currentTrack then
            pcall(function() currentTrack:AdjustSpeed(animPlayerSpeed) end)
        end
    end
})

AnimationPlayerDep:SetupDependencies({ { AnimationPlayerToggle, true } })

-- ========== THEME MANAGER ==========
ThemeManager:SetLibrary(Library)
ThemeManager:SetFolder("NewModpackRivals")
ThemeManager:ApplyTheme("Default")
Library.AccentColor = Color3.fromRGB(0, 180, 255)
Library:UpdateColorsUsingRegistry()

local ThemeSection = Tabs.Config:AddLeftGroupbox("Theme")
ThemeManager:ApplyToGroupbox(ThemeSection)

-- ========== FLY & NOCLIP ==========
local MovementSection = Tabs.Misc:AddRightGroupbox("Movement")

local flyEnabled = false
local flySpeed = 70
local bodyVelocity = nil
local bodyGyro = nil
local flyThread = nil
local noclipEnabled = false
local noclipConnection = nil

local function cleanupFly()
    if flyThread then pcall(task.cancel, flyThread) flyThread = nil end
    if bodyVelocity then bodyVelocity:Destroy() bodyVelocity = nil end
    if bodyGyro then bodyGyro:Destroy() bodyGyro = nil end
end

local function startFly()
    local char = lp.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end
    
    cleanupFly()
    
    bodyVelocity = Instance.new("BodyVelocity", root)
    bodyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    
    bodyGyro = Instance.new("BodyGyro", root)
    bodyGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
    bodyGyro.P = 10000
    
    hum:ChangeState(Enum.HumanoidStateType.Swimming)
    
    flyEnabled = true
    
    flyThread = task.spawn(function()
        while flyEnabled and char and char.Parent and root and root.Parent do
            local humCurrent = char:FindFirstChildOfClass("Humanoid")
            if humCurrent then
                local moveDir = humCurrent.MoveDirection
                if bodyVelocity then
                    if moveDir.Magnitude > 0 then
                        bodyVelocity.Velocity = moveDir * flySpeed
                    else
                        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
                    end
                end
                if bodyGyro then
                    bodyGyro.CFrame = workspace.CurrentCamera.CFrame
                end
                if humCurrent:GetState() ~= Enum.HumanoidStateType.Swimming then
                    humCurrent:ChangeState(Enum.HumanoidStateType.Swimming)
                end
            end
            task.wait()
        end
        cleanupFly()
    end)
end

local function stopFly()
    flyEnabled = false
    cleanupFly()
    local char = lp.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum:GetState() == Enum.HumanoidStateType.Swimming then
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end
end

local function startNoclip()
    if noclipConnection then noclipConnection:Disconnect() end
    noclipEnabled = true
    noclipConnection = RunService.Stepped:Connect(function()
        if noclipEnabled and lp.Character then
            for _, part in pairs(lp.Character:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end
    end)
end

local function stopNoclip()
    noclipEnabled = false
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end
    if lp.Character then
        for _, part in pairs(lp.Character:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = true end
        end
    end
end

MovementSection:AddToggle("FlyToggle", {
    Text = "Fly",
    Default = false,
    Callback = function(value)
        if value then startFly() else stopFly() end
    end
})

MovementSection:AddSlider("FlySpeedSlider", {
    Text = "Fly Speed",
    Default = 70,
    Min = 20,
    Max = 200,
    Rounding = 0,
    Callback = function(value)
        flySpeed = value
        if flyEnabled and bodyVelocity then
            local char = lp.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum and hum.MoveDirection.Magnitude > 0 then
                    bodyVelocity.Velocity = hum.MoveDirection * value
                end
            end
        end
    end
})

local hideInFloorEnabled = false
local hideDesyncEnabled = false
local hideTargetPos = nil
local hideDesyncConn = nil

local function startHideInFloor()
    local char = lp.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    if hideDesyncConn then hideDesyncConn:Disconnect() end
    
    task.spawn(function()
        while hideInFloorEnabled do
            local cam = workspace.CurrentCamera
            local rayParams = RaycastParams.new()
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
            local c = lp.Character
            if c then rayParams.FilterDescendantsInstances = {c} end

            if cam then
                local ray = workspace:Raycast(cam.CFrame.Position, Vector3.new(0, -9999, 0), rayParams)
                if ray then
                    hideTargetPos = ray.Position - Vector3.new(0, 5, 0)
                else
                    hideTargetPos = cam.CFrame.Position - Vector3.new(0, 5, 0)
                end
            elseif c and c:FindFirstChild("HumanoidRootPart") then
                local hrp = c.HumanoidRootPart
                local ray = workspace:Raycast(hrp.Position, Vector3.new(0, -9999, 0), rayParams)
                if ray then
                    hideTargetPos = ray.Position - Vector3.new(0, 5, 0)
                else
                    hideTargetPos = hrp.Position - Vector3.new(0, 5, 0)
                end
            end
            task.wait(1)
        end
    end)

    hideDesyncConn = RunService.Heartbeat:Connect(function()
        if not hideInFloorEnabled then return end
        local c = lp.Character
        if not (c and c:FindFirstChild("HumanoidRootPart") and hideTargetPos) then return end
        local h = c.HumanoidRootPart
        local savedCF = h.CFrame
        -- 螳滄圀縺ｮ菴咲ｽｮ繧貞ｺ翫・荳九↓蝗ｺ螳夲ｼ・縺ｨZ縺ｯ迴ｾ蝨ｨ縺ｮ菴咲ｽｮ繧剃ｽｿ逕ｨ縺励〆縺ｮ縺ｿ蝗ｺ螳夲ｼ・
        local targetPos = Vector3.new(savedCF.X, hideTargetPos.Y, savedCF.Z)
        h.CFrame = CFrame.new(targetPos) * CFrame.Angles(savedCF:ToEulerAnglesXYZ())
        if hideDesyncEnabled then
            -- WB縺ｨ蜷後§繝代ち繝ｼ繝ｳ: RenderStep縺ｧ蜈・・CFrame縺ｫ謌ｻ縺呻ｼ医し繝ｼ繝舌・蛛ｴ縺ｫ繧ｺ繝ｬ縺滉ｽ咲ｽｮ繧帝∽ｿ｡・・
            safeBindToRenderStep(RunService, "__hif_restore", 101, function()
                h.CFrame = savedCF
                safeUnbindFromRenderStep(RunService, "__hif_restore")
            end)
        end
    end)
end

local function stopHideInFloor()
    if hideDesyncConn then hideDesyncConn:Disconnect() hideDesyncConn = nil end
    safeUnbindFromRenderStep(RunService, "__hif_restore")
    hideTargetPos = nil

    local char = lp.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local hrp = char.HumanoidRootPart
        hrp.CFrame = hrp.CFrame + Vector3.new(0, 10, 0)
    end
end

MovementSection:AddToggle("NoclipToggle", {
    Text = "Noclip",
    Default = false,
    Callback = function(value)
        if value then startNoclip() else stopNoclip() end
    end
})

MovementSection:AddToggle("HideInFloorToggle", {
    Text = "Hide In Floor",
    Default = false,
    Callback = function(value)
        hideInFloorEnabled = value
        if value then startHideInFloor() else stopHideInFloor() end
    end
})

MovementSection:AddToggle("HideDesyncToggle", {
    Text = "Desync In Floor",
    Default = false,
    Callback = function(value)
        hideDesyncEnabled = value
    end
})

local infJumpEnabled = false
local fighterControllerCache = nil
local maxDoubleJumpsOriginals = {}

MovementSection:AddToggle("InfJumpToggle", {
    Text = "Infinite Jump",
    Default = false,
    Callback = function(value)
        infJumpEnabled = value
        
        -- OFFにした時元に戻す
        if not value and fighterControllerCache and fighterControllerCache.LocalFighter then
            local item = fighterControllerCache.LocalFighter.EquippedItem
            if item and item.Info and item.Name and maxDoubleJumpsOriginals[item.Name] then
                item.Info.MaxDoubleJumps = maxDoubleJumpsOriginals[item.Name]
            end
        end
    end
})

RunService.RenderStepped:Connect(function()
    if infJumpEnabled then
        if not fighterControllerCache then
            pcall(function()
                fighterControllerCache = require(lp.PlayerScripts:WaitForChild("Controllers"):WaitForChild("FighterController"))
            end)
        end
        
        if fighterControllerCache and fighterControllerCache.LocalFighter then
            local item = fighterControllerCache.LocalFighter.EquippedItem
            if item and type(item.Info) == "table" and item.Name then
                if maxDoubleJumpsOriginals[item.Name] == nil then
                    maxDoubleJumpsOriginals[item.Name] = item.Info.MaxDoubleJumps or 1
                end
                item.Info.MaxDoubleJumps = math.huge
            end
        end
    end
end)

lp.CharacterAdded:Connect(function()
    if flyEnabled then task.wait(0.5) startFly() end
    if noclipEnabled then task.wait(0.5) startNoclip() end
end)

-- ========== AUTO LOADOUT ==========
do
local autoLoadoutEnabled = false
local ChosenWeapons = {}
local WeaponLists = {}
local ListIndexes = {1, 1, 1, 1}

local LoadCoreBox = Tabs.Misc:AddLeftGroupbox("Loadout Core")
LoadCoreBox:AddToggle("AutoLoadToggle", { Text = "Enable Auto Loadout", Default = autoLoadoutEnabled, Callback = function(Value) autoLoadoutEnabled = Value end })

local LoadSlotsBox = Tabs.Misc:AddRightGroupbox("Weapon Slots")
local PriDropObj = LoadSlotsBox:AddDropdown("PriDrop", { Values = {"None"}, Default = 1, Multi = false, Text = "Primary", Callback = function(Value) ChosenWeapons[1] = Value end })
local SecDropObj = LoadSlotsBox:AddDropdown("SecDrop", { Values = {"None"}, Default = 1, Multi = false, Text = "Secondary", Callback = function(Value) ChosenWeapons[2] = Value end })
local MelDropObj = LoadSlotsBox:AddDropdown("MelDrop", { Values = {"None"}, Default = 1, Multi = false, Text = "Melee", Callback = function(Value) ChosenWeapons[3] = Value end })
local UtiDropObj = LoadSlotsBox:AddDropdown("UtiDrop", { Values = {"None"}, Default = 1, Multi = false, Text = "Utility", Callback = function(Value) ChosenWeapons[4] = Value end })

local AutoLoadout_ItemLibrary = nil
local AutoLoadout_FighterController = nil
local AutoLoadout_DuelController = nil


local function getSavedWeaponSelections()
    local saved = {}
    pcall(function()
        local sm = getgenv().SaveManager or SaveManager
        if not (sm and sm.Folder) then return end
        local autoFile = sm.Folder .. "/settings/autoload.txt"
        if not (type(isfile) == "function" and isfile(autoFile)) then return end
        local name = readfile(autoFile)
        local path = sm.Folder .. "/settings/" .. name .. ".json"
        if not isfile(path) then return end
        local decoded = game:GetService("HttpService"):JSONDecode(readfile(path))
        if type(decoded) == "table" and type(decoded.Options) == "table" then
            saved[1] = decoded.Options.PriDrop
            saved[2] = decoded.Options.SecDrop
            saved[3] = decoded.Options.MelDrop
            saved[4] = decoded.Options.UtiDrop
        end
    end)
    return saved
end

local dropObjs = {PriDropObj, SecDropObj, MelDropObj, UtiDropObj}

local function updateWeaponLabels()
    -- SetValues蜑阪↓迴ｾ蝨ｨ縺ｮ蛟､繧剃ｿ晏ｭ假ｼ・aveManager縺後☆縺ｧ縺ｫ繝ｭ繝ｼ繝峨＠縺溷､繧貞ｮ医ｋ・・
    local prevVals = {
        PriDropObj.Value,
        SecDropObj.Value,
        MelDropObj.Value,
        UtiDropObj.Value,
    }
    if WeaponLists[1] and #WeaponLists[1] > 0 then
        PriDropObj:SetValues(WeaponLists[1])
        local v = (prevVals[1] and table.find(WeaponLists[1], prevVals[1])) and prevVals[1] or PriDropObj.Value
        PriDropObj:SetValue(v); ChosenWeapons[1] = v
    end
    if WeaponLists[2] and #WeaponLists[2] > 0 then
        SecDropObj:SetValues(WeaponLists[2])
        local v = (prevVals[2] and table.find(WeaponLists[2], prevVals[2])) and prevVals[2] or SecDropObj.Value
        SecDropObj:SetValue(v); ChosenWeapons[2] = v
    end
    if WeaponLists[3] and #WeaponLists[3] > 0 then
        MelDropObj:SetValues(WeaponLists[3])
        local v = (prevVals[3] and table.find(WeaponLists[3], prevVals[3])) and prevVals[3] or MelDropObj.Value
        MelDropObj:SetValue(v); ChosenWeapons[3] = v
    end
    if WeaponLists[4] and #WeaponLists[4] > 0 then
        UtiDropObj:SetValues(WeaponLists[4])
        local v = (prevVals[4] and table.find(WeaponLists[4], prevVals[4])) and prevVals[4] or UtiDropObj.Value
        UtiDropObj:SetValue(v); ChosenWeapons[4] = v
    end
end

local function refreshWeapons()
    if not AutoLoadout_ItemLibrary or not AutoLoadout_FighterController then return end
    local maxSlots = AutoLoadout_FighterController.LocalFighter and AutoLoadout_FighterController.LocalFighter:GetMaxEquippableWeapons() or 4
    for slotIndex = 1, maxSlots do
        local weapons = {}
        local classData = AutoLoadout_ItemLibrary.SlotToClass[slotIndex]
        local className = classData and classData.Name
        if className then
            local weaponPool = AutoLoadout_FighterController.LocalFighter and AutoLoadout_FighterController.LocalFighter:Get("WeaponPool") or {}
            local filterType = AutoLoadout_FighterController.LocalFighter and AutoLoadout_FighterController.LocalFighter:Get("WeaponPoolFilterType") or ""
            for _, itemName in ipairs(AutoLoadout_ItemLibrary.ItemsAlphabetized) do
                local itemData = AutoLoadout_ItemLibrary.Items[itemName]
                if itemData and itemData.Class == className then
                    local isBlacklisted = (filterType == "Blacklist") and table.find(weaponPool, itemName)
                    local canUse = AutoLoadout_FighterController.LocalFighter and AutoLoadout_FighterController.LocalFighter:CanUseWeapon(itemName)
                    if (canUse or isBlacklisted) then
                        table.insert(weapons, itemName)
                    end
                end
            end
        end
        WeaponLists[slotIndex] = weapons
        if type(weapons) == "table" and ListIndexes[slotIndex] > #weapons then ListIndexes[slotIndex] = 1 end
        if type(weapons) == "table" and #weapons > 0 and not ChosenWeapons[slotIndex] then
            ChosenWeapons[slotIndex] = weapons[ListIndexes[slotIndex]]
        end
    end
end

LoadCoreBox:AddButton({
    Text = "Refresh Weapons Data",
    Func = function()
        refreshWeapons()
        updateWeaponLabels()
    end,
})

local lastAutoLoadoutTime = 0
local function triggerAutoLoadout()
    if not autoLoadoutEnabled then return end
    
    -- 騾｣邯夐∽ｿ｡縺ｫ繧医ｋ讀懃衍繧帝亟縺舌ョ繝舌え繝ｳ繧ｹ・・遘偵↓1蝗槭∪縺ｧ・・
    if os.clock() - lastAutoLoadoutTime < 1 then return end
    lastAutoLoadoutTime = os.clock()

    local validLoadout = {}
    local maxSlots = AutoLoadout_FighterController and AutoLoadout_FighterController.LocalFighter and AutoLoadout_FighterController.LocalFighter:GetMaxEquippableWeapons() or 4
    
    local index = 1
    for i = 1, maxSlots do 
        if ChosenWeapons[i] and ChosenWeapons[i] ~= "None" then
            validLoadout[index] = ChosenWeapons[i]
            index = index + 1
        end
    end
    
    local duel = AutoLoadout_DuelController and AutoLoadout_DuelController:GetDuel(lp)
    if duel and duel.LocalDueler and duel.LocalDueler:GetStaggeredSpawnsTurn() then
        ReplicatedStorage.Remotes.Duels.PickWeaponsAheadOfTime:FireServer(validLoadout)
    else
        ReplicatedStorage.Remotes.Replication.Fighter.PickWeapons:FireServer(validLoadout)
    end
end

local function enforceAutoLoadout()
    local function hideExpectedUI(guiObj)
        if not autoLoadoutEnabled then return end
        local nameStr = string.lower(guiObj.Name)
        if string.find(nameStr, "pickweapon") or string.find(nameStr, "weaponselect") then
            task.spawn(function()
                if guiObj:IsA("ScreenGui") then
                    guiObj.Enabled = false
                    guiObj:GetPropertyChangedSignal("Enabled"):Connect(function()
                        if autoLoadoutEnabled and guiObj.Enabled then
                            guiObj.Enabled = false; refreshWeapons(); triggerAutoLoadout()
                        end
                    end)
                elseif guiObj:IsA("GuiObject") then
                    guiObj.Visible = false
                    guiObj:GetPropertyChangedSignal("Visible"):Connect(function()
                        if autoLoadoutEnabled and guiObj.Visible then
                            guiObj.Visible = false; refreshWeapons(); triggerAutoLoadout()
                        end
                    end)
                end
            end)
            refreshWeapons()
            triggerAutoLoadout()
        end
    end
    
    local PlayerGui = lp:WaitForChild("PlayerGui")
    PlayerGui.ChildAdded:Connect(hideExpectedUI)
    PlayerGui.DescendantAdded:Connect(hideExpectedUI)
    for _, desc in ipairs(PlayerGui:GetDescendants()) do hideExpectedUI(desc) end

    local function attachToFighter()
        if AutoLoadout_FighterController and AutoLoadout_FighterController.LocalFighter and type(AutoLoadout_FighterController.LocalFighter.GetPropertyChangedSignal) == "function" then
            pcall(function()
                AutoLoadout_FighterController.LocalFighter:GetPropertyChangedSignal("CanPickWeapons"):Connect(function()
                    if autoLoadoutEnabled and AutoLoadout_FighterController.LocalFighter:Get("CanPickWeapons") then
                        refreshWeapons(); triggerAutoLoadout()
                    end
                end)
            end)
        end
    end

    if AutoLoadout_FighterController then
        attachToFighter()
        if type(AutoLoadout_FighterController.FighterAdded) == "userdata" then
            AutoLoadout_FighterController.FighterAdded:Connect(attachToFighter)
        end
    end
end

task.spawn(function()
    local Modules = ReplicatedStorage:WaitForChild("Modules", 10)
    if Modules then AutoLoadout_ItemLibrary = require(Modules:WaitForChild("ItemLibrary", 10)) end
    local playerScripts = lp:WaitForChild("PlayerScripts", 10)
    local Controllers = playerScripts and playerScripts:WaitForChild("Controllers", 10)
    if Controllers then
        AutoLoadout_FighterController = require(Controllers:WaitForChild("FighterController", 10))
        AutoLoadout_DuelController = require(Controllers:WaitForChild("DuelController", 10))
    end
    
    task.wait(1)
    refreshWeapons()
    updateWeaponLabels()
    -- 豁ｦ蝎ｨ繝ｪ繧ｹ繝医′謠・▲縺溷ｾ後↓SaveManager縺ｮAutoload繧貞・驕ｩ逕ｨ縺励※蛟､繧貞ｾｩ蜈・
    pcall(function() SaveManager:LoadAutoloadConfig() end)
    enforceAutoLoadout()
end)

lp.CharacterAdded:Connect(function()
    task.wait(1.5)
    if autoLoadoutEnabled then
        refreshWeapons()
        triggerAutoLoadout()
    end
end)
end -- do AutoLoadout

-- ========== AUTO EXECUTE ==========
local AutoExecSection = Tabs.Config:AddRightGroupbox("Auto Execute")

local pastebinCode = "loadstring(game:HttpGet('https://raw.githubusercontent.com/ldtktldjadc/l/refs/heads/main/ModpackRivals.luau'))()"

local _autoExecOn = false
pcall(function()
    if isfile then
        _autoExecOn = isfile("autoexec/ModpackRivals.lua") or isfile("ModpackRivals_AutoExec.lua") or false
    end
end)

-- 襍ｷ蜍墓凾縺ｫ繝輔ぃ繧､繝ｫ縺悟ｭ伜惠縺励※縺・ｌ縺ｰ queue_on_teleport 繧貞・逋ｻ骭ｲ
if _autoExecOn then
    pcall(function()
        if queue_on_teleport then queue_on_teleport(pastebinCode)
        elseif syn and syn.queue_on_teleport then syn.queue_on_teleport(pastebinCode) end
    end)
end

AutoExecSection:AddToggle("AutoExecuteToggle", {
    Text = "Auto Execute (Keep Script)",
    Default = _autoExecOn,
    Callback = function(value)
        if value then
            pcall(function()
                if queue_on_teleport then
                    queue_on_teleport(pastebinCode)
                elseif syn and syn.queue_on_teleport then
                    syn.queue_on_teleport(pastebinCode)
                end
            end)
            pcall(function()
                if isfolder and not isfolder("autoexec") then makefolder("autoexec") end
                writefile("autoexec/ModpackRivals.lua", pastebinCode)
            end)
            pcall(function() writefile("ModpackRivals_AutoExec.lua", pastebinCode) end)
        else
            pcall(function() if isfile("autoexec/ModpackRivals.lua") then delfile("autoexec/ModpackRivals.lua") end end)
            pcall(function() if isfile("ModpackRivals_AutoExec.lua") then delfile("ModpackRivals_AutoExec.lua") end end)
        end
    end
})

-- ========== SAVE MANAGER ==========
SaveManager:SetLibrary(Library)
SaveManager:SetFolder("NewModpackRivals")
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({"AutoExecuteToggle"})
SaveManager:BuildConfigSection(Tabs.Config)
SaveManager:LoadAutoloadConfig()
