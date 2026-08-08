if not game:IsLoaded() then game.Loaded:Wait() end
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

-- 多重ロード防止（5秒以内に連続で実行された場合は弾く）
if getgenv().ModpackRivals_Executing then return end
getgenv().ModpackRivals_Executing = true
task.delay(5, function() getgenv().ModpackRivals_Executing = false end)

--==========
--[[
	WARNING: Heads up! This script has not been verified by ScriptBlox. Use at your own risk!
]]

--// Config



--===========
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

--=============================================================================
-- Emit/ClearフックによるKatanaパリー判定 (AntiKatana)
--=============================================================================
local DeflectingPlayers = {}
getgenv().DeflectingPlayers = DeflectingPlayers
local function isPlayerParrying(player)
    if not player then return false end
    local endTime = DeflectingPlayers[player]
    return endTime and tick() < endTime
end
local function getPlayerFromObj(obj)
    local char = obj:FindFirstAncestorOfClass("Model")
    return char and Players:GetPlayerFromCharacter(char)
end

pcall(function()
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
end)

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
                    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
                    raycastParams.FilterDescendantsInstances = {lp.Character}
                    local ray = workspace:Raycast(cam.CFrame.Position, (part.Position - cam.CFrame.Position), raycastParams)
                    local visible = not ray or ray.Instance:IsDescendantOf(plr.Character)
    
                    if visible then
                        local myHRP = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
                        local dist = (aim360 and myHRP) and (part.Position - myHRP.Position).Magnitude or (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
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
    -- 内部で direction = (endPos - origin).Unit * maxDist を計算している
    -- なので args[3] (endPos) をターゲット座標に差し替えるだけでいい
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
    BoxFill = false, BoxFillColor = Color3.fromRGB(255, 255, 255),
    Distance = false, DistanceColor = Color3.fromRGB(255, 255, 255),
    Weapon = false, WeaponColor = Color3.fromRGB(255, 255, 255),
    Ammo = false, AmmoColor = Color3.fromRGB(255, 255, 255),
    Katana = false, KatanaColor = Color3.fromRGB(255, 255, 255),
    Bone = false, BoneColor = Color3.fromRGB(255, 255, 255),
    Tracer = false, TracerColor = Color3.fromRGB(255, 255, 255),
    Name = false, NameColor = Color3.fromRGB(255, 255, 255),
    HP = false, HPColor = Color3.fromRGB(50, 255, 50),
    TextStrokeColor = Color3.fromRGB(0, 0, 0),
}
getgenv().ESPSettings_TeamCheck = false

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
        Box = Instance.new("Frame"),
        BoxStroke = Instance.new("UIStroke"),
        Tracer = createLine(),
        WeaponBillboard = billboard,
        WeaponText = weaponText,
        AmmoText = ammoText,
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
    
    c.Box.BackgroundTransparency = 1; c.Box.BorderSizePixel = 0; c.Box.Visible = false; c.Box.Parent = espContainer
    c.BoxStroke.Thickness = 1
    c.BoxStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    c.BoxStroke.LineJoinMode = Enum.LineJoinMode.Miter
    c.BoxStroke.Parent = c.Box
end

local function clearPlayerEsp(p)
    if espCache[p] then
        pcall(function() espCache[p].NameTag:Destroy() end)
        pcall(function() espCache[p].DistanceTag:Destroy() end)
        pcall(function() espCache[p].Box:Destroy() end)
        pcall(function() espCache[p].Tracer:Destroy() end)
        pcall(function() if espCache[p].WeaponBillboard then espCache[p].WeaponBillboard:Destroy() end end)
        pcall(function() if espCache[p].AmmoText then espCache[p].AmmoText:Destroy() end end)
        pcall(function() if espCache[p].HPBarBg then espCache[p].HPBarBg:Destroy() end end)
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
            c.Box.Visible = false
            c.Tracer.Visible = false
            c.WeaponBillboard.Enabled = false
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
                c.Box.Visible = false
                c.Tracer.Visible = false
                c.WeaponBillboard.Enabled = false
                if c.AmmoText then c.AmmoText.Visible = false end
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
            local height = (cam.ViewportSize.Y / rootPos.Z) * 3.4
            local width = height / 1.7
            local topPos = Vector2.new(rootPos.X, rootPos.Y - (height / 2))
            local botPos = Vector2.new(rootPos.X, rootPos.Y + (height / 2))
            local topVis = true
            local botVis = true
            
            if cache.AmmoText.Visible then
                cache.AmmoText.Position = UDim2.new(0, topPos.X, 0, topPos.Y - (espSettings.Name and 14 or 4))
            end

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
                cache.NameTag.Position = UDim2.new(0, topPos.X, 0, topPos.Y - 5)
                cache.NameTag.Visible = true
            else
                cache.NameTag.Visible = false
            end

            if topVis and botVis then
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
                
                if espSettings.HP and cache.HPBarBg then
                    local hpW = 2 -- Fixed thin width to 2px
                    cache.HPBarBg.Size = UDim2.new(0, hpW, 0, height)
                    cache.HPBarBg.Position = UDim2.new(0, topPos.X - (width / 2) - hpW - 4, 0, topPos.Y)
                    local hpPct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                    cache.HPBarFill.Size = UDim2.new(1, 0, hpPct, 0)
                    cache.HPBarFill.Position = UDim2.new(0, 0, 1 - hpPct, 0)
                    cache.HPBarFill.BackgroundColor3 = espSettings.HPColor
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
                cache.Box.Visible = false
                cache.DistanceTag.Visible = false
                cache.Tracer.Visible = false
                cache.AmmoText.Visible = false
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
            cache.Box.Visible = false
            cache.Tracer.Visible = false
            if cache.HPBarBg then cache.HPBarBg.Visible = false end
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
    :AddColorPicker("ESP_TextStroke_Color", { Title = "Text Stroke", Default = espSettings.TextStrokeColor, Callback = function(v) espSettings.TextStrokeColor = v end })

ESPDep:AddToggle("ESP_HP", { Text = "HP Bar", Default = false, Callback = function(v) espSettings.HP = v end })
    :AddColorPicker("ESP_HP_Color", { Default = espSettings.HPColor, Callback = function(v) espSettings.HPColor = v end })

ESPDep:AddToggle("ESP_TeamCheck", { Text = "Team Check", Default = false, Callback = function(v) getgenv().ESPSettings_TeamCheck = v end })

ESPDep:SetupDependencies({ { ESPToggle, true } })



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
    Text = "Snow Speed", Default = 30, Min = 1, Max = 100, Rounding = 0,
    Callback = function(v) envSettings.SnowSpeed = v; updateSnow() end
})


-- ===== RAGE TAB =====

local GunModsSection = Tabs.Rage:AddLeftGroupbox("Gun Mods")

getgenv().RageSettings = {
    Enabled = false,
    NoRecoil = false,
    NoSpread = false,
    RapidFire = false,
    AntiKatana = false
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

                -- Anti-Katana: StartShootingをフック
                local origSS = self.StartShooting
                if type(origSS) == "function" and not self._isAntiKatanaSSHooked then
                    self._isAntiKatanaSSHooked = true
                    self.StartShooting = function(gunSelf, ...)
                        if getgenv().RageSettings.Enabled and getgenv().RageSettings.AntiKatana then
                            local now = tick()
                            local cam = workspace.CurrentCamera
                            for p, endTime in pairs(DeflectingPlayers) do
                                if now < endTime and p ~= lp and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                                    local _, onScreen = cam:WorldToScreenPoint(p.Character.HumanoidRootPart.Position)
                                    if onScreen then return false end
                                end
                            end
                        end
                        return origSS(gunSelf, ...)
                    end
                end

                -- Anti-Katana: Shot:Fire()をフック（予備）
                if self.Shot and not self._isAntiKatanaShotHooked then
                    self._isAntiKatanaShotHooked = true
                    local origShotFire = self.Shot.Fire
                    self.Shot.Fire = function(sig, ...)
                        if getgenv().RageSettings.Enabled and getgenv().RageSettings.AntiKatana then
                            local now = tick()
                            local cam = workspace.CurrentCamera
                            for p, endTime in pairs(DeflectingPlayers) do
                                if now < endTime and p ~= lp and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
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
                    -- もともとその武器にプロパティが存在する場合のみ上書きする
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
        -- 変更しただけでは走らないようにする（オンにした時のみ）
    end
})
DeviceSpoofDep:SetupDependencies({ { DeviceSpooferToggle, true } })

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
    local msg = "⚠️ STAFF DETECTED ⚠️\nName: " .. player.Name .. "\nRole: " .. role
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

local _autoExecOn = false
pcall(function()
    if isfile then
        _autoExecOn = isfile("autoexec/ModpackRivals.lua") or isfile("ModpackRivals_AutoExec.lua") or false
    end
end)

-- 起動時にファイルが存在していれば queue_on_teleport を再登録
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
