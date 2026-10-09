if not game:IsLoaded() then game.Loaded:Wait() end
pcall(function() if clearconsole then clearconsole() end end)
pcall(function() if rconsoleclear then rconsoleclear() end end)
pcall(function()
    local LogService = game:GetService("LogService")
    if LogService and LogService.Clear then LogService:Clear() end
end)
getgenv().ModpackLoaded = false
getgenv().DeviceSpoofEnabled = false
getgenv().DeviceSpoofValue = "Touch"
getgenv()._LastPendingControls = nil
if not getgenv()._MasterNamecallHooked and hookmetamethod then
    getgenv()._MasterNamecallHooked = true
    getgenv().MasterHooks = {}
    getgenv()._masterOldNC = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local isCaller = checkcaller()
        for _, hookFn in ipairs(getgenv().MasterHooks) do
            local intercept, ret = hookFn(isCaller, self, method, ...)
            if intercept then return ret end
        end
        return getgenv()._masterOldNC(self, ...)
    end))
end

if not getgenv()._SetControlsHooked and hookmetamethod and newcclosure then
    getgenv()._SetControlsHooked = true
    table.insert(getgenv().MasterHooks, function(isCaller, self, method, ...)
        if method == "FireServer" or method == "fireServer" then
            if self and (self.Name == "SetControls" or tostring(self) == "SetControls") then
                if not getgenv().ModpackLoaded then
                    getgenv()._LastPendingControls = ...
                    return true, nil
                end
                if getgenv().DeviceSpoofEnabled and getgenv().DeviceSpoofValue then
                    if not isCaller then
                        return true, getgenv()._masterOldNC(self, getgenv().DeviceSpoofValue)
                    end
                end
            end
        end
        return false, nil
    end)
end
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local lp = Players.LocalPlayer
local PlayerGui = lp:WaitForChild("PlayerGui")
if PlayerGui:FindFirstChild("LoadingScreen") then
    repeat task.wait(0.05) until not PlayerGui:FindFirstChild("LoadingScreen")
end
local math_min = math.min
local math_max = math.max
local math_clamp = math.clamp
local math_abs = math.abs
local math_sin = math.sin
local math_cos = math.cos
local math_deg = math.deg
local math_rad = math.rad
local math_atan2 = math.atan2
local Vector2_new = Vector2.new
local Vector3_new = Vector3.new
local CFrame_new = CFrame.new
local UDim2_new = UDim2.new
local tick = tick

boundRenderSteps = {}
local function safeBindToRenderStep(rs, name, priority, func)
    if type(rs.BindToRenderStep) == "function" then
        pcall(rs.BindToRenderStep, rs, name, priority, func)
    else
        if boundRenderSteps[name] then boundRenderSteps[name]:Disconnect() end
        boundRenderSteps[name] = rs.RenderStepped:Connect(func)
    end
end
local function safeUnbindFromRenderStep(rs, name)
    if type(rs.UnbindFromRenderStep) == "function" then
        pcall(rs.UnbindFromRenderStep, rs, name)
    end
    if boundRenderSteps[name] then
        boundRenderSteps[name]:Disconnect()
        boundRenderSteps[name] = nil
    end
end
if getgenv().KETY_Executed then
    if getgenv().MyLinoriaLibrary and getgenv().MyLinoriaLibrary.Notify then
        getgenv().MyLinoriaLibrary:Notify("Script is already running! Please rejoin to inject a new version.", 5)
    end
    return 
end
getgenv().KETY_Executed = true
local cam = workspace.CurrentCamera
if getgenv().MyLinoriaLibrary then
    pcall(function() getgenv().MyLinoriaLibrary:Unload() end)
end
if getgenv().MyKETYESP then
    pcall(function() getgenv().MyKETYESP:Destroy() end)
end
if getgenv().KETY_NoArmConnection then
    pcall(function() getgenv().KETY_NoArmConnection:Disconnect() end)
    getgenv().KETY_NoArmConnection = nil
end
if getgenv()._AimLockFOVConn then
    pcall(function() getgenv()._AimLockFOVConn:Disconnect() end)
    getgenv()._AimLockFOVConn = nil
end
if getgenv()._AimLockFOVContainer then
    pcall(function() getgenv()._AimLockFOVContainer:Destroy() end)
    getgenv()._AimLockFOVContainer = nil
end
if getgenv()._KETY_RageAttackButton then
    pcall(function() getgenv()._KETY_RageAttackButton:Destroy() end)
    getgenv()._KETY_RageAttackButton = nil
end
getgenv().SilentConfig = {
    Enabled = false,
    SilentFOV = 100,
    SilentHitChance = 100,
    SilentTargetPart = "HitboxHead",
    WallCheck = false,
    TeamCheck = false,
}
local function getMyTeamID()
    return lp:GetAttribute("TeamID")
end
local function getPlayerTeamID(plr)
    return plr:GetAttribute("TeamID")
end
local function checkTeam(plr, isESP)
    if not plr or plr == lp then return false end
    tc = isESP and getgenv().ESPSettings_TeamCheck or (getgenv().SilentConfig and getgenv().SilentConfig.TeamCheck)
    if not tc then return true end
    
    myID = getMyTeamID()
    if myID == nil then
        return true
    end
    theirID = getPlayerTeamID(plr)
    if theirID ~= nil and myID == theirID then return false end

    if SpectateController then
        duel = SpectateController.CurrentDuelSubject
        if duel and duel.Duelers then
            localDueler = duel:GetDueler(lp)
            if localDueler then
                localTeam = localDueler:Get("TeamID")
                if localTeam then
                    inDuel = false
                    for _, dueler in next, duel.Duelers do
                        if dueler.Player == plr then
                            inDuel = true
                            return localTeam == nil or dueler:Get("TeamID") ~= localTeam
                        end
                    end
                    -- If they are not in the same duel, they are not a valid enemy
                    if not inDuel then return false end
                end
            end
        end
    end
    return true
end
do
    UserInputService = game:GetService("UserInputService")
    rawRaycast = workspace.Raycast
    isInsideRaycastHook = false
    staticRayParams = RaycastParams.new()
    staticRayParams.FilterType = Enum.RaycastFilterType.Exclude
    staticRayParams.IgnoreWater = true
    wallCheckRayParams = RaycastParams.new()
    wallCheckRayParams.FilterType = Enum.RaycastFilterType.Exclude
    wallCheckRayParams.IgnoreWater = true
    candidateParts = {
        "HitboxHead", "HitboxHeadSmall", "HitboxBody", "HitboxBodySmall",
        "Head", "UpperTorso", "LowerTorso", "HumanoidRootPart",
        "LeftUpperArm", "LeftLowerArm", "LeftHand",
        "RightUpperArm", "RightLowerArm", "RightHand",
        "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
        "RightUpperLeg", "RightLowerLeg", "RightFoot"
    }
    local function getClosestTarget(maxFOV, partMode)
        cfg = getgenv().SilentConfig
        local closest, closestDist = nil, (maxFOV == 100 and 500 or (maxFOV or 300))
        mousePos = UserInputService:GetMouseLocation()
        myChar = lp.Character
        curCam = workspace.CurrentCamera
        if not curCam then return nil end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= lp and checkTeam(p, false) then
                char = p.Character
                hum = char and char:FindFirstChildOfClass("Humanoid")
                root = char and char:FindFirstChild("HumanoidRootPart")
                if char and hum and hum.Health > 0 and root then
                    hitPart = root
                    if partMode == "Random" then
                        valid = {}
                        for _, name in ipairs(candidateParts) do
                            part = char:FindFirstChild(name)
                            if part then table.insert(valid, part) end
                        end
                        hitPart = (#valid > 0 and valid[math.random(1, #valid)]) or root
                    elseif partMode == "Closest" then
                        closestPart = root
                        closestDistToMouse = math.huge
                        for _, name in ipairs(candidateParts) do
                            part = char:FindFirstChild(name)
                            if part then
                                local pScr, pOn = curCam:WorldToViewportPoint(part.Position)
                                if pOn and pScr.Z > 0 then
                                    dist = (Vector2.new(pScr.X, pScr.Y) - mousePos).Magnitude
                                    if dist < closestDistToMouse then
                                        closestDistToMouse = dist
                                        closestPart = part
                                    end
                                end
                            end
                        end
                        hitPart = closestPart
                    else
                        hitPart = char:FindFirstChild(partMode) or char:FindFirstChild("HitboxHead") or char:FindFirstChild("Head") or root
                    end
                    if cfg and cfg.WallCheck and hitPart then
                        wallCheckRayParams.FilterDescendantsInstances = myChar and {curCam, myChar} or {curCam}
                        camPos = curCam.CFrame.Position
                        hitPos = hitPart.Position
                        dir = hitPos - camPos
                        rayResult = rawRaycast(workspace, camPos, dir, wallCheckRayParams)
                        if rayResult and rayResult.Instance and not rayResult.Instance:IsDescendantOf(char) then
                            continue
                        end
                    end
                    local scrPos, onScreen = curCam:WorldToViewportPoint(hitPart.Position)
                    if onScreen and scrPos.Z > 0 then
                        fovDist = (Vector2.new(scrPos.X, scrPos.Y) - mousePos).Magnitude
                        if fovDist <= closestDist then
                            closest = hitPart
                            closestDist = fovDist
                        end
                    end
                end
            end
        end
        return closest
    end
    cachedSilentTarget = nil
    lastSilentTick = 0
    local function getSilentAimDirection(origin, currentDir)
        cfg = getgenv().SilentConfig
        if not cfg or not cfg.Enabled then return currentDir end
        now = tick()
        if now - lastSilentTick > 0.016 then
            cachedSilentTarget = getClosestTarget(cfg.SilentFOV, cfg.SilentTargetPart)
            lastSilentTick = now
        end
        target = cachedSilentTarget
        if target then
            tModel = target:IsA("Model") and target or target:FindFirstAncestorOfClass("Model")
            tPlr = tModel and Players:GetPlayerFromCharacter(tModel)
            if tPlr and not checkTeam(tPlr, false) then return currentDir end
            if math.random(1, 100) <= (cfg.SilentHitChance or 100) then
                return (target.Position - origin).Unit * currentDir.Magnitude
            end
        end
        return currentDir
    end
    if not getgenv()._SilentAimHooked then
        getgenv()._SilentAimHooked = true
        table.insert(getgenv().MasterHooks, function(isCaller, self, method, ...)
            if not method or isCaller or isInsideRaycastHook then
                return false
            end
            cfg = getgenv().SilentConfig
            if not cfg or not cfg.Enabled then
                return false
            end
            if self == workspace and (method == "Raycast" or method == "raycast") then
                isInsideRaycastHook = true
                local origin, direction, params = ...
                if typeof(origin) == "Vector3" and typeof(direction) == "Vector3" then
                    resultDir = getSilentAimDirection(origin, direction)
                    if resultDir and typeof(resultDir) == "Vector3" then
                        isInsideRaycastHook = false
                        if setnamecallmethod then setnamecallmethod(method) end
                        return true, getgenv()._masterOldNC(self, origin, resultDir, params)
                    end
                end
                isInsideRaycastHook = false
            end
            return false
        end)
    end
end
DeflectingPlayers = {}
getgenv().DeflectingPlayers = DeflectingPlayers
function isPlayerParrying(player)
    if not player then return false end
    endTime = DeflectingPlayers[player]
    return endTime and tick() < endTime
end
getgenv()._isPlayerParrying = isPlayerParrying
_particlePlayerCache = setmetatable({}, {__mode = "k"})
function getPlayerFromObj(obj)
    p = _particlePlayerCache[obj]
    if p ~= nil then return p or nil end
    char = obj:FindFirstAncestorOfClass("Model")
    p = char and Players:GetPlayerFromCharacter(char) or false
    _particlePlayerCache[obj] = p
    return p or nil
end
if not getgenv().ParticleHooked then
    getgenv().ParticleHooked = true
    _tempPE = Instance.new("ParticleEmitter")
    local oldEmit; oldEmit = hookfunction(_tempPE.Emit, function(self, count)
        if self.Name == "bigstar" then
            p = getPlayerFromObj(self)
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
            p = getPlayerFromObj(self)
            if p then DeflectingPlayers[p] = 0 end
        end
        return oldClear(self)
    end)
    _tempPE:Destroy()
end
FighterController = nil
SpectateController = nil
task.spawn(function()
    pcall(function()
        playerScripts = lp:WaitForChild("PlayerScripts", 5)
        if playerScripts then
            controllers = playerScripts:WaitForChild("Controllers", 5)
            if controllers then
                fc = controllers:WaitForChild("FighterController", 5)
                if fc then FighterController = require(fc) end
                sc = controllers:WaitForChild("SpectateController", 5)
                if sc then SpectateController = require(sc) end
            end
        end
    end)
end)
SeasonLibrary = nil
task.spawn(function()
    pcall(function()
        SeasonLibrary = require(ReplicatedStorage.Modules:WaitForChild("SeasonLibrary", 5))
    end)
end)
function getESPContainerParent()
    local success, hui = pcall(function() return gethui() end)
    if success and hui then return hui end
    local success2, core = pcall(function() return game:GetService("CoreGui") end)
    if success2 and core then return core end
    return lp:WaitForChild("PlayerGui")
end
screenGui = Instance.new("ScreenGui")
screenGui.Name = "KETY_ESP_UI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = getESPContainerParent()
getgenv().MyKETYESP = screenGui
espContainer = Instance.new("Frame")
espContainer.Name = "ESP_Container"
espContainer.Size = UDim2.new(1, 0, 1, 0)
espContainer.BackgroundTransparency = 1
espContainer.Parent = screenGui
espCache = {}
espSettings = {
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
    RanDomEsp = false, RanDomEspDist = 300,
    TextStrokeColor = Color3.fromRGB(0, 0, 0),
    WallESP = false,
    WallESPColor = Color3.fromRGB(255, 80, 80),       
    WallESPNoWallColor = Color3.fromRGB(80, 255, 80), 
    WallESPTransparency = 0.5,                        
}
getgenv().ESPSettings_TeamCheck = false
teamEspCache = {}
teamEspSettings = {
    Enabled = false,
    Box = true,  BoxColor = Color3.fromRGB(0, 200, 255), BoxType = "Full",
    Name = true, NameColor = Color3.fromRGB(0, 200, 255),
    HP = false,  HPColor = Color3.fromRGB(50, 255, 50),
    Tracer = false, TracerColor = Color3.fromRGB(0, 200, 255),
    TextStrokeColor = Color3.fromRGB(0, 0, 0),
}
_strokeCache = setmetatable({}, {__mode = "k"})
function safeSet(obj, prop, val)
    if obj[prop] ~= val then
        obj[prop] = val
    end
end
function safeSetStrokeColor(target, color)
    if typeof(target) == "Instance" then
        s = _strokeCache[target]
        if s == nil then
            s = target:FindFirstChildOfClass("UIStroke") or false
            _strokeCache[target] = s
        end
        if s and s.Color ~= color then
            s.Color = color
        end
    end
end
function createLine() 
    line = Instance.new("Frame")
    line.BorderSizePixel = 0
    line.AnchorPoint = Vector2.new(0.5, 0.5)
    line.ZIndex = 0
    line.Visible = false
    line.Parent = espContainer
    stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = Color3.new(0, 0, 0)
    stroke.Thickness = 1
    stroke.Parent = line
    return line 
end
local function drawLine(frame, p1, p2, color) 
    local dir = p2 - p1
    safeSet(frame, "Position", UDim2_new(0, (p1.X+p2.X)*0.5, 0, (p1.Y+p2.Y)*0.5))
    safeSet(frame, "Size", UDim2_new(0, dir.Magnitude, 0, 1))
    safeSet(frame, "Rotation", math_deg(math_atan2(dir.Y, dir.X)))
    safeSet(frame, "BackgroundColor3", color)
    safeSet(frame, "Visible", true)
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
    
    local function setupTag(tag, anchorY)
        tag.BackgroundTransparency = 1
        tag.Font = Drawing.Fonts.UI
        tag.TextSize = 8
        tag.TextStrokeTransparency = 1
        tag.Visible = false
        tag.Size = UDim2.new(0, 200, 0, 16)
        tag.AnchorPoint = Vector2.new(0.5, anchorY)
        tag.Parent = espContainer
        stroke = Instance.new("UIStroke")
        stroke.Parent = tag
    end

    setupTag(c.NameTag, 1)
    setupTag(c.DistanceTag, 0)
    
    c.BoxFill.BackgroundTransparency = 0.5
    c.BoxFill.BorderSizePixel = 0
    safeSet(c.BoxFill, "Visible", false)
    c.BoxFill.Parent = espContainer
end
function clearPlayerEsp(p)
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
    safeSet(c.NameTag, "Visible", false)
    safeSet(c.NameTag, "Size", UDim2.new(0, 200, 0, 16))
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
    safeSet(c.BoxFill, "Visible", false)
    c.BoxFill.Parent = espContainer
    c.Tracer = createLine()
    c.HPBarBg = Instance.new("Frame")
    safeSet(c.HPBarBg, "BackgroundColor3", Color3.fromRGB(40, 40, 40))
    c.HPBarBg.BorderSizePixel = 1
    c.HPBarBg.BorderColor3 = Color3.new(0,0,0)
    safeSet(c.HPBarBg, "Visible", false)
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
function getBonePos(ref, cam)
    if ref and cam then
        local pos, onScreen = cam:WorldToViewportPoint(ref.Position)
        if onScreen then return Vector2.new(pos.X, pos.Y) end
    end
    return nil
end
function updateBoneRefs(cache, char)
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
_wallRayParams = RaycastParams.new()
_wallRayParams.FilterType = Enum.RaycastFilterType.Exclude
_wallRayParams.IgnoreWater = true
_wallExclude = {}
function updateWallExclude()
    curCam = workspace.CurrentCamera
    myChar = lp.Character
    _wallExclude = (myChar and curCam) and {curCam, myChar} or (curCam and {curCam} or {})
    _wallRayParams.FilterDescendantsInstances = _wallExclude
end
lp.CharacterAdded:Connect(updateWallExclude)
task.spawn(updateWallExclude)

_wallRayCache = {}
function isPlayerBehindWall(char, cam)
    root = char and char:FindFirstChild("HumanoidRootPart")
    if not root or not cam then return false end
    now = tick()
    cached = _wallRayCache[char]
    if cached and (now - cached.time < 0.1) then
        return cached.result
    end
    origin = cam.CFrame.Position
    dir = root.Position - origin
    result = workspace:Raycast(origin, dir, _wallRayParams)
    isBehind = false
    if result and result.Instance and not result.Instance:IsDescendantOf(char) then
        isBehind = true
    end
    _wallRayCache[char] = { result = isBehind, time = now }
    return isBehind
end
wallEspHighlightCache = {}
function getOrCreateHighlight(p, char)
    h = wallEspHighlightCache[p]
    if h and h.Parent == char then return h end
    if h then pcall(function() h:Destroy() end) end
    nh = Instance.new("Highlight")
    nh.Name = "KETY_WallESP"
    nh.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    nh.FillTransparency = espSettings.WallESPTransparency
    nh.OutlineTransparency = espSettings.WallESPTransparency
    nh.Parent = char
    wallEspHighlightCache[p] = nh
    return nh
end
function clearHighlight(p)
    h = wallEspHighlightCache[p]
    if h then
        pcall(function() h:Destroy() end)
        wallEspHighlightCache[p] = nil
    end
end
_espLastTime = 0
_espCleared = false
_espConn = nil
function updateEspLoop()
    if espSettings.MasterEnabled then
        if not _espConn then
            _espCleared = false
            _espConn = RunService.Heartbeat:Connect(function()
                now = tick()
                if now - _espLastTime < 0.033 then return end 
                _espLastTime = now
                local cam = workspace.CurrentCamera
                if not cam then return end
                camPos = cam.CFrame.Position
                camVp = cam.ViewportSize
                if not espSettings.MasterEnabled then
                    if _espConn then _espConn:Disconnect(); _espConn = nil end
                    if not _espCleared then
                        for _, c in pairs(espCache) do
                            safeSet(c.NameTag, "Visible", false)
                            safeSet(c.DistanceTag, "Visible", false)
                            if c.BoxFill then safeSet(c.BoxFill, "Visible", false) end
                            for _, l in pairs(c.BoxLines or {}) do safeSet(l, "Visible", false) end
                            safeSet(c.Tracer, "Visible", false)
                            c.WeaponBillboard.Enabled = false
                            if c.AmmoText then safeSet(c.AmmoText, "Visible", false) end
                            if c.RankIcon then safeSet(c.RankIcon, "Visible", false) end
                            if c.HPBarBg then safeSet(c.HPBarBg, "Visible", false) end
                            for _, b in pairs(c.Bones) do safeSet(b, "Visible", false) end
                        end
                        for p, _ in pairs(wallEspHighlightCache) do
                            clearHighlight(p)
                        end
                        _espCleared = true
                    end
                    return
                end
                _espCleared = false
                for _, p in pairs(Players:GetPlayers()) do
                    if p == lp then continue end
                    char = p.Character
        hum = char and char:FindFirstChild("Humanoid")
        rootPart = char and char:FindFirstChild("HumanoidRootPart")
        head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HitboxHead") or rootPart)
        if not char or not hum or hum.Health <= 0 or not rootPart or not head or not checkTeam(p, true) then
            if espCache[p] then
                c = espCache[p]
                safeSet(c.NameTag, "Visible", false)
                safeSet(c.DistanceTag, "Visible", false)
                if c.BoxFill then safeSet(c.BoxFill, "Visible", false) end
                for _, l in pairs(c.BoxLines or {}) do safeSet(l, "Visible", false) end
                safeSet(c.Tracer, "Visible", false)
                c.WeaponBillboard.Enabled = false
                if c.AmmoText then safeSet(c.AmmoText, "Visible", false) end
                if c.RankIcon then safeSet(c.RankIcon, "Visible", false) end
                if c.HPBarBg then safeSet(c.HPBarBg, "Visible", false) end
                for _, b in pairs(c.Bones) do safeSet(b, "Visible", false) end
            end
            clearHighlight(p)
            continue
        end
        if espSettings.WallESP then
            hl = getOrCreateHighlight(p, char)
            behindWall = isPlayerBehindWall(char, cam)
            if behindWall then
                safeSet(hl, "Enabled", true)
                safeSet(hl, "FillColor", espSettings.WallESPColor)
                safeSet(hl, "OutlineColor", espSettings.WallESPColor)
                safeSet(hl, "FillTransparency", espSettings.WallESPTransparency)
                safeSet(hl, "OutlineTransparency", espSettings.WallESPTransparency)
            else
                safeSet(hl, "Enabled", true)
                safeSet(hl, "FillColor", espSettings.WallESPNoWallColor)
                safeSet(hl, "OutlineColor", espSettings.WallESPNoWallColor)
                safeSet(hl, "FillTransparency", espSettings.WallESPTransparency)
                safeSet(hl, "OutlineTransparency", espSettings.WallESPTransparency)
            end
        else
            clearHighlight(p)
        end
        createPlayerEsp(p)
        cache = espCache[p]
        local rootPos, onScreen = cam:WorldToViewportPoint(rootPart.Position)
        distance = math.floor((camPos - rootPart.Position).Magnitude)
        if espSettings.Weapon or espSettings.Ammo then
            cache.WeaponBillboard.Adornee = rootPart
            safeSet(cache.WeaponBillboard, "Enabled", true)local fighter = nil
            if FighterController and typeof(FighterController.GetFighter) == "function" then
                fighter = FighterController:GetFighter(p)
            end
            if espSettings.Weapon then
                safeSet(cache.WeaponText, "TextColor3", espSettings.WeaponColor)
                safeSetStrokeColor(cache.WeaponText, espSettings.TextStrokeColor or Color3.fromRGB(0,0,0))
                weaponName = "None"
                if fighter and fighter.EquippedItem then
                    weaponName = fighter.EquippedItem.Name
                end
                safeSet(cache.WeaponText, "Text", weaponName)
                safeSet(cache.WeaponText, "Visible", true)
            else
                safeSet(cache.WeaponText, "Visible", false)
            end
            if espSettings.Ammo then
                safeSet(cache.AmmoText, "TextColor3", espSettings.AmmoColor)
                safeSetStrokeColor(cache.AmmoText, espSettings.TextStrokeColor or Color3.fromRGB(0,0,0))
                ammoStr = ""
                if fighter and fighter.EquippedItem then
                    ammo = fighter.EquippedItem:Get("Ammo")
                    reserve = fighter.EquippedItem:Get("AmmoReserve")
                    if ammo then
                        ammoStr = string.format("Ammo: %d / %s", ammo, reserve or "0")
                    end
                end
                if ammoStr ~= "" then
                    safeSet(cache.AmmoText, "Text", ammoStr)
                    safeSet(cache.AmmoText, "Visible", true)
                else
                    safeSet(cache.AmmoText, "Visible", false)
                end
            else
                safeSet(cache.AmmoText, "Visible", false)
            end
        else
            safeSet(cache.WeaponBillboard, "Enabled", false)safeSet(cache.AmmoText, "Visible", false)
        end
        if onScreen then
            headWorld = rootPart.Position + Vector3.new(0, 3.2, 0)
            feetWorld = rootPart.Position + Vector3.new(0, -3.2, 0)
            headScreen = cam:WorldToViewportPoint(headWorld)
            feetScreen = cam:WorldToViewportPoint(feetWorld)
            height = math.abs(headScreen.Y - feetScreen.Y)
            width = height / 1.7
            espOffset = Vector2.zero
            if espSettings.RanDomEsp then
                targetHeadPart = char:FindFirstChild("Head")
                if targetHeadPart and targetHeadPart:IsA("BasePart") then
                    randomDir = Vector3.new(
                        math.random() - 0.5,
                        math.random() - 0.5,
                        math.random() - 0.5
                    ).Unit
                    -- Optimized: removed pcall overhead
                    if not targetHeadPart:IsA("BasePart") then continue end
                    targetHeadPart.CFrame = CFrame.new(rootPart.Position + randomDir * 7e12)
                end
            end
            topPos = Vector2.new(rootPos.X, headScreen.Y)
            botPos = Vector2.new(rootPos.X, feetScreen.Y)
            topVis = true
            botVis = true
            currentTopY = topPos.Y - 5
            if espSettings.Name then
                text = p.Name
                color = espSettings.NameColor
                if espSettings.Katana and isPlayerParrying(p) then
                    text = text .. " [Parrying]"
                    color = espSettings.KatanaColor
                end
                safeSet(cache.NameTag, "Text", text)
                safeSet(cache.NameTag, "TextColor3", color)
                safeSetStrokeColor(cache.NameTag, espSettings.TextStrokeColor or Color3.fromRGB(0,0,0))
                safeSet(cache.NameTag, "Position", UDim2.new(0, topPos.X, 0, currentTopY))
                safeSet(cache.NameTag, "Visible", true)
                currentTopY = currentTopY - 10
            else
                safeSet(cache.NameTag, "Visible", false)
            end
            if cache.AmmoText.Visible then
                safeSet(cache.AmmoText, "Position", UDim2.new(0, topPos.X, 0, currentTopY))
                currentTopY = currentTopY - 10
            end
            if espSettings.Rank and SeasonLibrary then
                eloStat = p:FindFirstChild("CustomLeaderstats") and p.CustomLeaderstats:FindFirstChild("Current ELO")
                if eloStat and eloStat.Value then
                    elo = eloStat.Value
                    if cache.lastElo ~= elo then
                        cache.lastElo = elo
                        local lbRank, rankName
                        pcall(function() lbRank = SeasonLibrary:GetHighestELOLeaderboardRanking(elo, p.UserId) end)
                        pcall(function() rankName = SeasonLibrary:GetRank(elo, p.UserId, lbRank) end)
                        rankInfo = rankName and SeasonLibrary.CurrentSeason.RankProfile.Ranks[rankName]
                        cache.lastRankImage = rankInfo and rankInfo.Image or ""
                    end
                    if cache.lastRankImage ~= "" then
                        cache.RankIcon.Image = cache.lastRankImage
                        safeSet(cache.RankIcon, "Position", UDim2.new(0, topPos.X, 0, currentTopY))
                        safeSet(cache.RankIcon, "Visible", true)
                    else
                        safeSet(cache.RankIcon, "Visible", false)
                    end
                else
                    safeSet(cache.RankIcon, "Visible", false)
                end
            else
                safeSet(cache.RankIcon, "Visible", false)
            end
            if topVis and botVis then
                if espSettings.Box then
                    tl = Vector2.new(topPos.X - (width/2), topPos.Y)
                    tr = Vector2.new(topPos.X + (width/2), topPos.Y)
                    bl = Vector2.new(topPos.X - (width/2), botPos.Y)
                    br = Vector2.new(topPos.X + (width/2), botPos.Y)
                    if espSettings.BoxType == "Corner" then
                        len = math.min(width, height) / 3
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
                    strokeColor = espSettings.TextStrokeColor or Color3.fromRGB(0,0,0)
                    if cache._lastBoxStroke ~= strokeColor then
                        cache._lastBoxStroke = strokeColor
                        for _, l in pairs(cache.BoxLines) do
                            safeSetStrokeColor(l, strokeColor)
                        end
                    end
                    if espSettings.BoxFill then
                        if espSettings.BoxFillImage and espSettings.BoxFillImageID ~= "" then
                            cache.BoxFill.Image = "rbxassetid://" .. espSettings.BoxFillImageID
                            cache.BoxFill.ImageColor3 = Color3.new(1, 1, 1) 
                            safeSet(cache.BoxFill, "BackgroundColor3", espSettings.BoxFillColor )
                            cache.BoxFill.BackgroundTransparency = 1 
                            cache.BoxFill.ImageTransparency = 0.5
                        else
                            cache.BoxFill.Image = ""
                            safeSet(cache.BoxFill, "BackgroundColor3", espSettings.BoxFillColor)
                            cache.BoxFill.BackgroundTransparency = 0.5
                        end
                        safeSet(cache.BoxFill, "Size", UDim2.new(0, width, 0, height))
                        safeSet(cache.BoxFill, "Position", UDim2.new(0, topPos.X - (width/2), 0, topPos.Y))
                        safeSet(cache.BoxFill, "Visible", true)
                    else
                        safeSet(cache.BoxFill, "Visible", false)
                    end
                else
                    for _, line in pairs(cache.BoxLines) do line.Visible = false end
                    if cache.BoxFill then safeSet(cache.BoxFill, "Visible", false) end
                end
                if espSettings.HP and cache.HPBarBg then
                    hpW = 2 
                    safeSet(cache.HPBarBg, "Size", UDim2.new(0, hpW, 0, height))
                    safeSet(cache.HPBarBg, "Position", UDim2.new(0, topPos.X - (width / 2) - hpW - 4, 0, topPos.Y))
                    hpPct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                    safeSet(cache.HPBarFill, "Size", UDim2.new(1, 0, hpPct, 0))
                    safeSet(cache.HPBarFill, "Position", UDim2.new(0, 0, 1 - hpPct, 0))
                    safeSet(cache.HPBarFill, "BackgroundColor3", Color3.new(1 - hpPct, hpPct, 0) )
                    cache.HPBarBg.BorderColor3 = espSettings.TextStrokeColor or Color3.fromRGB(0,0,0)
                    safeSet(cache.HPBarBg, "Visible", true)
                    safeSet(cache.HPBarFill, "Visible", true)
                elseif cache.HPBarBg then
                    safeSet(cache.HPBarBg, "Visible", false)
                end
                if espSettings.Distance then
                    hpPctInt = math.floor((hum.Health / hum.MaxHealth) * 100)
                    safeSet(cache.DistanceTag, "Text", string.format("[ %dm ] [ %d%% ]", distance, hpPctInt))
                    safeSet(cache.DistanceTag, "TextColor3", espSettings.DistanceColor)
                    safeSetStrokeColor(cache.DistanceTag, espSettings.TextStrokeColor or Color3.fromRGB(0,0,0))
                    safeSet(cache.DistanceTag, "Position", UDim2.new(0, topPos.X, 0, botPos.Y + 2))
                    safeSet(cache.DistanceTag, "Visible", true)
                    if cache.WeaponBillboard.Enabled then
                        baseOffset = Vector3.new(0, -4.5 - ((botPos.Y - topPos.Y) / 100), 0)
                        if espSettings.RanDomEsp and espOffset ~= Vector2.zero then
                            baseOffset = baseOffset + Vector3.new(espOffset.X / 25, -espOffset.Y / 25, 0)
                        end
                        cache.WeaponBillboard.StudsOffset = baseOffset
                    end
                else
                    safeSet(cache.DistanceTag, "Visible", false)
                end
                if espSettings.Tracer then
                    center = Vector2_new(camVp.X * 0.5, camVp.Y)
                    drawLine(cache.Tracer, center, botPos, espSettings.TracerColor)
                else
                    safeSet(cache.Tracer, "Visible", false)
                end
            else
                if cache.BoxFill then safeSet(cache.BoxFill, "Visible", false) end
                for _, l in pairs(cache.BoxLines or {}) do safeSet(l, "Visible", false) end
                safeSet(cache.DistanceTag, "Visible", false)
                safeSet(cache.Tracer, "Visible", false)
                safeSet(cache.AmmoText, "Visible", false)
                safeSet(cache.RankIcon, "Visible", false)
                if cache.HPBarBg then safeSet(cache.HPBarBg, "Visible", false) end
            end
            if espSettings.Bone then
                updateBoneRefs(cache, char)
                br = cache.boneRefs
                h = getBonePos(br.Head, cam)
                t = getBonePos(br.Torso, cam)
                la = getBonePos(br.LArm, cam)
                ra = getBonePos(br.RArm, cam)
                ll = getBonePos(br.LLeg, cam)
                rl = getBonePos(br.RLeg, cam)
                if espOffset ~= Vector2.zero then
                    if h then h = h + espOffset end
                    if t then t = t + espOffset end
                    if la then la = la + espOffset end
                    if ra then ra = ra + espOffset end
                    if ll then ll = ll + espOffset end
                    if rl then rl = rl + espOffset end
                end
                if h and t then drawLine(cache.Bones.Head_Torso, h, t, espSettings.BoneColor) else cache.Bones.Head_Torso.Visible = false end
                if t and la then drawLine(cache.Bones.Torso_LArm, t, la, espSettings.BoneColor) else cache.Bones.Torso_LArm.Visible = false end
                if t and ra then drawLine(cache.Bones.Torso_RArm, t, ra, espSettings.BoneColor) else cache.Bones.Torso_RArm.Visible = false end
                if t and ll then drawLine(cache.Bones.Torso_LLeg, t, ll, espSettings.BoneColor) else cache.Bones.Torso_LLeg.Visible = false end
                if t and rl then drawLine(cache.Bones.Torso_RLeg, t, rl, espSettings.BoneColor) else cache.Bones.Torso_RLeg.Visible = false end
            else
                for _, b in pairs(cache.Bones) do safeSet(b, "Visible", false) end
            end
        else
            safeSet(cache.NameTag, "Visible", false)
            safeSet(cache.DistanceTag, "Visible", false)
            if cache.BoxFill then safeSet(cache.BoxFill, "Visible", false) end
            for _, l in pairs(cache.BoxLines or {}) do safeSet(l, "Visible", false) end
            safeSet(cache.Tracer, "Visible", false)
            safeSet(cache.AmmoText, "Visible", false)
            safeSet(cache.RankIcon, "Visible", false)
            if cache.HPBarBg then safeSet(cache.HPBarBg, "Visible", false) end
            for _, b in pairs(cache.Bones) do safeSet(b, "Visible", false) end
        end
    end
    end)
    end
    else
        if _espConn then _espConn:Disconnect(); _espConn = nil end
        if not _espCleared then
            for _, c in pairs(espCache) do
                safeSet(c.NameTag, "Visible", false)
                safeSet(c.DistanceTag, "Visible", false)
                if c.BoxFill then safeSet(c.BoxFill, "Visible", false) end
                for _, l in pairs(c.BoxLines or {}) do safeSet(l, "Visible", false) end
                safeSet(c.Tracer, "Visible", false)
                c.WeaponBillboard.Enabled = false
                if c.AmmoText then safeSet(c.AmmoText, "Visible", false) end
                if c.RankIcon then safeSet(c.RankIcon, "Visible", false) end
                if c.HPBarBg then safeSet(c.HPBarBg, "Visible", false) end
                for _, b in pairs(c.Bones) do safeSet(b, "Visible", false) end
            end
            for p, _ in pairs(wallEspHighlightCache) do
                clearHighlight(p)
            end
            _espCleared = true
        end
    end
end
_teamEspLastTime = 0
_teamEspCleared = false
_teamEspConn = nil
function updateTeamEspLoop()
    if teamEspSettings.Enabled then
        if not _teamEspConn then
            _teamEspCleared = false
            _teamEspConn = RunService.Heartbeat:Connect(function()
                now = tick()
                if now - _teamEspLastTime < 0.033 then return end
                _teamEspLastTime = now
                local cam = workspace.CurrentCamera
                if not cam then return end
                camVp = cam.ViewportSize
                myID = getMyTeamID()
                if not teamEspSettings.Enabled or not myID then
                    if not _teamEspCleared then
                        for _, c in pairs(teamEspCache) do
                            safeSet(c.NameTag, "Visible", false)
                            safeSet(c.BoxFill, "Visible", false)
                            safeSet(c.Tracer, "Visible", false)
                            safeSet(c.HPBarBg, "Visible", false)
                            for _, l in pairs(c.BoxLines or {}) do safeSet(l, "Visible", false) end
                        end
                        _teamEspCleared = true
                    end
                    if not teamEspSettings.Enabled and _teamEspConn then
                        _teamEspConn:Disconnect()
                        _teamEspConn = nil
                    end
                    return
                end
                _teamEspCleared = false
                for _, p in pairs(Players:GetPlayers()) do
                    if p == lp then continue end
        theirID = getPlayerTeamID(p)
        isSameTeam = theirID ~= nil and theirID == myID
        char = p.Character
        hum = char and char:FindFirstChild("Humanoid")
        rootPart = char and char:FindFirstChild("HumanoidRootPart")
        if not isSameTeam or not char or not hum or hum.Health <= 0 or not rootPart then
            if teamEspCache[p] then
                c = teamEspCache[p]
                safeSet(c.NameTag, "Visible", false)
                safeSet(c.BoxFill, "Visible", false)
                safeSet(c.Tracer, "Visible", false)
                safeSet(c.HPBarBg, "Visible", false)
                for _, l in pairs(c.BoxLines or {}) do safeSet(l, "Visible", false) end
            end
            continue
        end
        createTeamPlayerEsp(p)
        c = teamEspCache[p]
        local rootPos, onScreen = cam:WorldToViewportPoint(rootPart.Position)
        if not onScreen then
            safeSet(c.NameTag, "Visible", false)
            safeSet(c.BoxFill, "Visible", false)
            safeSet(c.Tracer, "Visible", false)
            safeSet(c.HPBarBg, "Visible", false)
            for _, l in pairs(c.BoxLines or {}) do safeSet(l, "Visible", false) end
            continue
        end
        headWorld = rootPart.Position + Vector3.new(0, 3.2, 0)
        feetWorld = rootPart.Position + Vector3.new(0, -3.2, 0)
        headScreen = cam:WorldToViewportPoint(headWorld)
        feetScreen = cam:WorldToViewportPoint(feetWorld)
        height = math.abs(headScreen.Y - feetScreen.Y)
        width = height / 1.7
        espOffset = Vector2.zero
        if espSettings.RanDomEsp then
            angle = math.random() * math.pi * 2
            dist = math.random(50, espSettings.RanDomEspDist or 300)
            espOffset = Vector2.new(math.cos(angle) * dist, math.sin(angle) * dist)
        end
        topPos = Vector2.new(rootPos.X, headScreen.Y) + espOffset
        botPos = Vector2.new(rootPos.X, feetScreen.Y) + espOffset
        currentTopY = topPos.Y - 5
        if teamEspSettings.Name then
            safeSet(c.NameTag, "Text", "[TEAM] " .. p.Name)
            safeSet(c.NameTag, "TextColor3", teamEspSettings.NameColor)
            safeSetStrokeColor(c.NameTag, teamEspSettings.TextStrokeColor or Color3.fromRGB(0,0,0))
            safeSet(c.NameTag, "Position", UDim2.new(0, topPos.X, 0, currentTopY))
            safeSet(c.NameTag, "Visible", true)
            currentTopY = currentTopY - 10
        else
            safeSet(c.NameTag, "Visible", false)
        end
        if teamEspSettings.Box then
            tl = Vector2.new(topPos.X - width/2, topPos.Y)
            tr = Vector2.new(topPos.X + width/2, topPos.Y)
            bl = Vector2.new(topPos.X - width/2, botPos.Y)
            br = Vector2.new(topPos.X + width/2, botPos.Y)
            if teamEspSettings.BoxType == "Corner" then
                len = math.min(width, height) / 3
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
            safeSet(c.BoxFill, "BackgroundColor3", teamEspSettings.BoxColor)
            safeSet(c.BoxFill, "Size", UDim2.new(0, width, 0, height))
            safeSet(c.BoxFill, "Position", UDim2.new(0, topPos.X - width/2, 0, topPos.Y))
            safeSet(c.BoxFill, "Visible", false )
        else
            for _, l in pairs(c.BoxLines) do safeSet(l, "Visible", false) end
            safeSet(c.BoxFill, "Visible", false)
        end
        if teamEspSettings.HP then
            hpPct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            hpW = 2
            safeSet(c.HPBarBg, "Size", UDim2.new(0, hpW, 0, height))
            safeSet(c.HPBarBg, "Position", UDim2.new(0, topPos.X - width/2 - hpW - 4, 0, topPos.Y))
            safeSet(c.HPBarFill, "Size", UDim2.new(1, 0, hpPct, 0))
            safeSet(c.HPBarFill, "Position", UDim2.new(0, 0, 1 - hpPct, 0))
            safeSet(c.HPBarFill, "BackgroundColor3", Color3.new(1 - hpPct, hpPct, 0))
            safeSet(c.HPBarBg, "Visible", true)
        else
            safeSet(c.HPBarBg, "Visible", false)
        end
        if teamEspSettings.Tracer then
            center = Vector2_new(camVp.X * 0.5, camVp.Y)
            drawLine(c.Tracer, center, botPos, teamEspSettings.TracerColor)
        else
            safeSet(c.Tracer, "Visible", false)
        end
    end
    end)
    end
    else
        if _teamEspConn then _teamEspConn:Disconnect(); _teamEspConn = nil end
        if not _teamEspCleared then
            for _, c in pairs(teamEspCache) do
                safeSet(c.NameTag, "Visible", false)
                safeSet(c.BoxFill, "Visible", false)
                safeSet(c.Tracer, "Visible", false)
                safeSet(c.HPBarBg, "Visible", false)
                for _, l in pairs(c.BoxLines or {}) do safeSet(l, "Visible", false) end
            end
            _teamEspCleared = true
        end
    end
end
repo = "https://raw.githubusercontent.com/mstudio45/LinoriaLib/main/"
function fetchRepo(file)
    getgenv()._LinoriaCache = getgenv()._LinoriaCache or {}
    if getgenv()._LinoriaCache[file] then
        fn = loadstring(getgenv()._LinoriaCache[file])
        if fn then return fn() end
    end
    localName = "LinoriaLib_" .. file:gsub("[^%w%.%-_]", "_")
    if readfile and isfile and isfile(localName) then
        local success, content = pcall(readfile, localName)
        if success and content and #content > 0 then
            getgenv()._LinoriaCache[file] = content
            fn = loadstring(content)
            if fn then return fn() end
        end
    end
    for i = 1, 5 do
        local success, res = pcall(function() return game:HttpGet(repo .. file) end)
        if success and type(res) == "string" and #res > 0 then
            getgenv()._LinoriaCache[file] = res
            if writefile then pcall(writefile, localName, res) end
            fn = loadstring(res)
            if fn then return fn() end
        end
        task.wait(0.1)
    end
    error("Failed to load LinoriaLib: " .. file)
end
Library     = fetchRepo("Library.lua")
ThemeManager = fetchRepo("addons/ThemeManager.lua")
SaveManager  = fetchRepo("addons/SaveManager.lua")
getgenv().MyLinoriaLibrary = Library
Window = Library:CreateWindow({
    Title = "KETY",
    Center = true,
    AutoShow = true,
})
Tabs = {
    Combat  = Window:AddTab("Combat"),
    Visuals = Window:AddTab("Visuals"),
    World   = Window:AddTab("World"),
    Rage    = Window:AddTab("Rage"),
    Misc    = Window:AddTab("Misc"),
    Changer = Window:AddTab("Changer"),
    Config  = Window:AddTab("Config"),
}
AimSection = Tabs.Combat:AddLeftGroupbox("Silent Aim")
SilentToggle = AimSection:AddToggle("SilentEnabled", {
    Text    = "Enabled",
    Default = false,
    Callback = function(value) getgenv().SilentConfig.Enabled = value end,
})
SilentToggle:AddKeyPicker("SilentKey", {
    Default = "None",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Silent Aim",
})
AimDep = AimSection:AddDependencyBox()
AimDep:AddDropdown("TargetPart", {
    Values = {
        "HitboxHead", "HitboxHeadSmall", "HitboxBody", "HitboxBodySmall",
        "Random", "Closest",
        "Head", "UpperTorso", "LowerTorso", "HumanoidRootPart",
        "LeftUpperArm", "LeftLowerArm", "LeftHand",
        "RightUpperArm", "RightLowerArm", "RightHand",
        "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
        "RightUpperLeg", "RightLowerLeg", "RightFoot"
    },
    Default = 1,
    Multi = false,
    Text = "Target Part",
    Callback = function(value) getgenv().SilentConfig.SilentTargetPart = value end,
})
AimDep:AddSlider("SAHitChance", {
    Text    = "Hit Chance (%)", Default = 100, Min = 1, Max = 100, Rounding = 0,
    Callback = function(value) getgenv().SilentConfig.SilentHitChance = value end,
})
AimDep:AddSlider("SAIFOV", {
    Text    = "FOV", Default = 100, Min = 10, Max = 1000, Rounding = 0,
    Callback = function(value) getgenv().SilentConfig.SilentFOV = value end,
})
AimDep:AddToggle("WallCheck", {
    Text    = "Wall Check", Default = false,
    Callback = function(value) getgenv().SilentConfig.WallCheck = value end,
})
AimDep:AddToggle("TeamCheck", {
    Text    = "Team Check", Default = false,
    Callback = function(value) getgenv().SilentConfig.TeamCheck = value end,
})
AimDep:SetupDependencies({ { SilentToggle, true } })
AimLockSection = Tabs.Combat:AddRightGroupbox("AimLock")
AimLockSettings = {
    Enabled = false,
    TeamCheck = false,
    VisibleCheck = false,
    AliveCheck = true,
    StickyAim = false,
    Distance = 500,
    TargetPart = "HitboxHead",
    Prediction = false,
    PredX = 10,
    PredY = 10,
    Smoothing = false,
    SmoothX = 0,
    SmoothY = 0,
    Sensitivity = 1,
    FovEnabled = false,
    FovSize = 150,
    FovShape = "Circle",
    FovStyle = "Smooth",
    FovGlow = false,
    FovFilled = false,
    FovFillTransparency = 0.85,
    FovColor = Color3.fromRGB(255, 255, 255),
    FovColor2 = Color3.fromRGB(0, 170, 255),
    FovGradient = false,
    FovThickness = 1.5,
    FovTransparency = 0,
}
AL_LockedTarget = nil
AL_BlatantLockedFighter = nil
AL_LastTarget = nil
AL_BLATANT_HITBOXES = {"HitboxHead", "HitboxHeadSmall", "HitboxBody", "HitboxBodySmall"}
local function AL_getHealth(entity)
    if typeof(entity) == "Instance" then
        local hum = entity:FindFirstChild("Humanoid")
        if hum then return hum.Health end
    elseif type(entity) == "table" then
        if type(entity.GetHealth) == "function" then
            return entity:GetHealth()
        elseif type(entity.Health) == "number" then
            return entity.Health
        end
    end
    return 0
end
AL_enemyCache = {}
AL_enemyCacheTime = 0
local function AL_isEnemy(fighter)
    if not AimLockSettings.TeamCheck then return true end
    local plr = fighter.Player
    if not plr or plr == lp then return false end
    local now = tick()
    if now - AL_enemyCacheTime > 0.5 then
        AL_enemyCacheTime = now
        table.clear(AL_enemyCache)
    end
    if AL_enemyCache[plr] ~= nil then return AL_enemyCache[plr] end
    local isEn = true
    if SpectateController then
        duel = SpectateController.CurrentDuelSubject
        localDueler = duel and duel:GetDueler(lp)
        if localDueler and duel.Duelers then
            localTeam = localDueler:Get("TeamID")
            if localTeam then
                for _, dueler in next, duel.Duelers do
                    if dueler.Player == plr then
                        isEn = (localTeam == nil or dueler:Get("TeamID") ~= localTeam)
                        AL_enemyCache[plr] = isEn
                        return isEn
                    end
                end
            end
        end
    end
    myID = lp:GetAttribute("TeamID")
    theirID = plr:GetAttribute("TeamID")
    if myID and theirID then
        isEn = (myID ~= theirID)
    elseif myID == nil then
        isEn = true
    elseif plr.Team and lp.Team then
        isEn = (plr.Team ~= lp.Team)
    end
    AL_enemyCache[plr] = isEn
    return isEn
end
AL_charHitboxCache = setmetatable({}, {__mode = "k"})
local function AL_getValidHitboxes(char)
    local cached = AL_charHitboxCache[char]
    if cached then return cached end
    local valid = {}
    for _, name in ipairs(AL_BLATANT_HITBOXES) do
        local hb = char:FindFirstChild(name)
        if hb and hb:IsA("BasePart") then
            table.insert(valid, hb)
        end
    end
    AL_charHitboxCache[char] = valid
    return valid
end

local function AL_clampToHitboxes(char, worldPos)
	local best = nil
	local bestDist = math.huge
	for _, hb in ipairs(AL_getValidHitboxes(char)) do
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
	return best
end
_alRayParams = RaycastParams.new()
_alRayParams.FilterType = Enum.RaycastFilterType.Exclude
_alExclude = {}
local function updateAlExclude()
    local curCam = workspace.CurrentCamera
    local myChar = lp.Character
    _alExclude = (myChar and curCam) and {curCam, myChar} or (curCam and {curCam} or {})
    _alRayParams.FilterDescendantsInstances = _alExclude
end
lp.CharacterAdded:Connect(updateAlExclude)
task.spawn(updateAlExclude)

local function al_isBehindWall(part, char, camera)
    if not AimLockSettings.VisibleCheck then return false end
    local origin = camera.CFrame.Position
    local dir = part.Position - origin
    local ray = workspace:Raycast(origin, dir, _alRayParams)
    if ray and ray.Instance and not ray.Instance:IsDescendantOf(char) and ray.Instance.Transparency < 0.8 then
        return true
    end
    return false
end

local function AL_getTarget()
	if not AimLockSettings.Enabled then return nil, nil end
	local camera = workspace.CurrentCamera
	if not camera then return nil, nil end
	local screenCenter = camera.ViewportSize / 2
	if AL_LockedTarget and not AimLockSettings.StickyAim then
		AL_LockedTarget = nil
		AL_BlatantLockedFighter = nil
		AL_LastTarget = nil
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
		local isAlive = fighter and fighter.Entity and (AL_getHealth(fighter.Entity) > 0)
		if not AimLockSettings.AliveCheck then isAlive = true end
		local ok = fighter and fighter.Player and fighter.Entity and isAlive
		local wallFailed = true
		if ok then
			local s, r = pcall(al_isBehindWall, AL_LockedTarget, fighter.Entity.Model, camera)
			wallFailed = (not s) or (r and true or false)
		end
		local outOfRange = false
		if ok and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") and fighter.Entity.Model and fighter.Entity.Model:FindFirstChild("HumanoidRootPart") then
			if (fighter.Entity.Model.HumanoidRootPart.Position - lp.Character.HumanoidRootPart.Position).Magnitude > AimLockSettings.Distance then
				outOfRange = true
			end
		end
		local sp, onScreen = camera:WorldToViewportPoint(AL_LockedTarget.Position)
		local outOfFov = false
		if AimLockSettings.FovEnabled then
			local sDist = (AimLockSettings.FovShape == "Square")
				and math.max(math.abs(sp.X - screenCenter.X), math.abs(sp.Y - screenCenter.Y))
				or (Vector2.new(sp.X, sp.Y) - screenCenter).Magnitude
			if sDist > AimLockSettings.FovSize then
				outOfFov = true
			end
		end
		if not ok or wallFailed or outOfRange or not onScreen or outOfFov then
			AL_LockedTarget = nil
			AL_BlatantLockedFighter = nil
			AL_LastTarget = nil
		end
	end
	if not AL_LockedTarget then
		local best, bestFighter = nil, nil
		local bestDist = AimLockSettings.FovEnabled and AimLockSettings.FovSize or math.huge
		if not FighterController or type(FighterController.Objects) ~= "table" then return nil, nil end
		for _, fighter in pairs(FighterController.Objects or {}) do
			local isAlive = fighter.Entity and (AL_getHealth(fighter.Entity) > 0)
			if not AimLockSettings.AliveCheck then isAlive = true end
			if fighter ~= FighterController.LocalFighter and fighter.Entity and isAlive and AL_isEnemy(fighter) then
				local char = fighter.Entity.Model
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if hrp and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
					local worldDist = (hrp.Position - lp.Character.HumanoidRootPart.Position).Magnitude
					if worldDist <= AimLockSettings.Distance then
						local part = char:FindFirstChild(AimLockSettings.TargetPart) or char:FindFirstChild("Head")
						if part then
							local sp, onScreen = camera:WorldToViewportPoint(part.Position)
							if onScreen and not al_isBehindWall(part, char, camera) then
								local mouseDist = (AimLockSettings.FovShape == "Square")
									and math.max(math.abs(sp.X - screenCenter.X), math.abs(sp.Y - screenCenter.Y))
									or (Vector2.new(sp.X, sp.Y) - screenCenter).Magnitude
								if mouseDist <= bestDist then
									bestDist = mouseDist
									best = part
									bestFighter = fighter
								end
							end
						end
					end
				end
			end
		end
		AL_LockedTarget = best
		AL_BlatantLockedFighter = bestFighter
		AL_LastTarget = best
	end
	return AL_LockedTarget, AL_BlatantLockedFighter
end
task.spawn(function()
    CameraController = nil
    pcall(function()
        playerScripts = lp:WaitForChild("PlayerScripts", 5)
        if playerScripts then
            controllers = playerScripts:WaitForChild("Controllers", 5)
            if controllers then
                cc = controllers:WaitForChild("CameraController", 5)
                if cc then CameraController = require(cc) end
            end
        end
    end)
    if CameraController and CameraController.Rotation and not getgenv()._AimLockHooked then
        getgenv()._AimLockHooked = true
        local RunService = game:GetService("RunService")
        _aimLockBound = false
        local function aimLockLateCallback()
            self = CameraController
            if self.IsFrozen or not AimLockSettings.Enabled then
                if _aimLockBound then
                    pcall(function() RunService:UnbindFromRenderStep("AimLockLate") end)
                    _aimLockBound = false
                end
                return
            end
            local target, targetFighter = AL_getTarget()
            if not target then return end
            camera = workspace.CurrentCamera
            targetPos = target.Position
            if AimLockSettings.Prediction then
                mdl = targetFighter and targetFighter.Entity and targetFighter.Entity.Model
                root = mdl and mdl:FindFirstChild("HumanoidRootPart") or target
                vel = root.AssemblyLinearVelocity
                dx = math.max(AimLockSettings.PredX, 1)
                dy = math.max(AimLockSettings.PredY, 1)
                targetPos = targetPos + Vector3.new(vel.X / dx, vel.Y / dy, vel.Z / dx)
            end
            camOrigin = camera.CFrame.Position
            offset = targetPos - camOrigin
            if offset.Magnitude < 0.001 then return end
            dir = offset.Unit
            targetRot = Vector2.new(math.asin(math.clamp(dir.Y, -1, 1)), math.atan2(-dir.X, -dir.Z))
            current = self.Rotation
            diffYaw = (targetRot.Y - current.Y + math.pi) % (2 * math.pi) - math.pi
            diffPitch = math.clamp(targetRot.X, -1.5690509975429023, 1.5690509975429023) - current.X
            local stepYaw, stepPitch = diffYaw, diffPitch
            if AimLockSettings.Smoothing then
                sens = math.clamp(AimLockSettings.Sensitivity, 0, 2)
                stepYaw = diffYaw * math.clamp(sens / (1 + AimLockSettings.SmoothX), 0, 1)
                stepPitch = diffPitch * math.clamp(sens / (1 + AimLockSettings.SmoothY), 0, 1)
            end
            newRot = Vector2.new(math.clamp(current.X + stepPitch, -1.5690509975429023, 1.5690509975429023), current.Y + stepYaw)
            oldCF = CFrame.Angles(0, current.Y, 0) * CFrame.Angles(current.X, 0, 0)
            newCF = CFrame.Angles(0, newRot.Y, 0) * CFrame.Angles(newRot.X, 0, 0)
            delta = newCF * oldCF:Inverse()
            camera.CFrame = CFrame.new(camOrigin) * (delta * camera.CFrame.Rotation)
            self.Rotation = newRot
        end

        local function updateAimLockLate()
            if AimLockSettings.Enabled then
                if not _aimLockBound then
                    pcall(function() RunService:UnbindFromRenderStep("AimLockLate") end)
                    RunService:BindToRenderStep("AimLockLate", Enum.RenderPriority.Last.Value, aimLockLateCallback)
                    _aimLockBound = true
                end
            else
                if _aimLockBound then
                    pcall(function() RunService:UnbindFromRenderStep("AimLockLate") end)
                    _aimLockBound = false
                end
            end
        end
        getgenv()._updateAimLockLate = updateAimLockLate
        updateAimLockLate()
    end
end)
if getgenv()._AimLockFOVConn then
    pcall(function() getgenv()._AimLockFOVConn:Disconnect() end)
    getgenv()._AimLockFOVConn = nil
end
if getgenv()._AimLockFOVContainer then
    pcall(function() getgenv()._AimLockFOVContainer:Destroy() end)
    getgenv()._AimLockFOVContainer = nil
end
fovContainer = Instance.new("Frame")
fovContainer.Name = "AimLock_FOV_Container"
fovContainer.BackgroundTransparency = 1
fovContainer.Size = UDim2.new(1, 0, 1, 0)
fovContainer.Parent = screenGui
getgenv()._AimLockFOVContainer = fovContainer
fovMainFrame = Instance.new("Frame")
fovMainFrame.Name = "FOV_Main"
fovMainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
fovMainFrame.BorderSizePixel = 0
safeSet(fovMainFrame, "Visible", false)
fovMainFrame.ZIndex = 5
fovMainFrame.Parent = fovContainer
fovCorner = Instance.new("UICorner")
safeSet(fovCorner, "CornerRadius", UDim.new(1, 0))
fovCorner.Parent = fovMainFrame
fovStroke = Instance.new("UIStroke")
fovStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
safeSet(fovStroke, "Thickness", 1.5)
safeSet(fovStroke, "Color", Color3.fromRGB(255, 255, 255))
fovStroke.Parent = fovMainFrame
fovStrokeGradient = Instance.new("UIGradient")
fovStrokeGradient.Parent = fovStroke
fovFillGradient = Instance.new("UIGradient")
fovFillGradient.Parent = fovMainFrame
GLOW_CONFIG = {
    { Thickness = 3,  Transparency = 0.50 },
    { Thickness = 7,  Transparency = 0.70 },
    { Thickness = 13, Transparency = 0.85 },
    { Thickness = 20, Transparency = 0.94 },
}
glowLayers = {}
for i, cfg in ipairs(GLOW_CONFIG) do
    gf = Instance.new("Frame")
    gf.Name = "FOV_Glow_" .. i
    gf.AnchorPoint = Vector2.new(0.5, 0.5)
    gf.BackgroundTransparency = 1
    gf.BorderSizePixel = 0
    gf.Visible = false
    gf.ZIndex = 4
    gf.Parent = fovContainer
    gc = Instance.new("UICorner")
    gc.CornerRadius = UDim.new(1, 0)
    gc.Parent = gf
    gs = Instance.new("UIStroke")
    gs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    gs.Thickness = cfg.Thickness
    gs.Transparency = cfg.Transparency
    gs.Color = Color3.fromRGB(255, 255, 255)
    gs.Parent = gf
    gg = Instance.new("UIGradient")
    gg.Parent = gs
    table.insert(glowLayers, {
        Frame = gf,
        Corner = gc,
        Stroke = gs,
        Gradient = gg,
        BaseTrans = cfg.Transparency
    })
end
function hideFovElements()
    safeSet(fovMainFrame, "Visible", false)
    for _, g in ipairs(glowLayers) do
        safeSet(g.Frame, "Visible", false)
    end
end
_fovLastC1, _fovLastC2, _fovLastGrad = nil, nil, nil
_fovCachedSeq = nil
function getFovColorSeq(c1, c2, isGrad)
    if not _fovCachedSeq or _fovLastGrad ~= isGrad or _fovLastC1 ~= c1 or _fovLastC2 ~= c2 then
        _fovLastC1 = c1
        _fovLastC2 = c2
        _fovLastGrad = isGrad
        if isGrad then
            _fovCachedSeq = ColorSequence.new({
                ColorSequenceKeypoint.new(0, c1),
                ColorSequenceKeypoint.new(1, c2)
            })
        else
            _fovCachedSeq = ColorSequence.new(c1)
        end
    end
    return _fovCachedSeq
end
function updateAimLockFovLoop()
    shouldRun = AimLockSettings.Enabled and AimLockSettings.FovEnabled
    if not shouldRun then
        if getgenv()._AimLockFOVConn then
            pcall(function() getgenv()._AimLockFOVConn:Disconnect() end)
            getgenv()._AimLockFOVConn = nil
        end
        hideFovElements()
        return
    end
    if not getgenv()._AimLockFOVConn then
        getgenv()._AimLockFOVConn = RunService.RenderStepped:Connect(function()
            if not (AimLockSettings.Enabled and AimLockSettings.FovEnabled) then
                if getgenv()._AimLockFOVConn then
                    pcall(function() getgenv()._AimLockFOVConn:Disconnect() end)
                    getgenv()._AimLockFOVConn = nil
                end
                hideFovElements()
                return
            end
            camera = workspace.CurrentCamera
            if not camera then
                hideFovElements()
                return
            end
            center = camera.ViewportSize / 2
            baseSize = AimLockSettings.FovSize or 150
            currentRadius = baseSize
            style = AimLockSettings.FovStyle or "Smooth"
            shape = AimLockSettings.FovShape or "Circle"
            gradRot = 0
            shapeRot = 0
            col1 = AimLockSettings.FovColor or Color3.fromRGB(255, 255, 255)
            col2 = AimLockSettings.FovColor2 or Color3.fromRGB(0, 170, 255)
            if Options and Options.AimLock_FovColor and Options.AimLock_FovColor.Value then
                col1 = Options.AimLock_FovColor.Value
            end
            if Options and Options.AimLock_FovColor2 and Options.AimLock_FovColor2.Value then
                col2 = Options.AimLock_FovColor2.Value
            end
            if style == "Smooth" then
                currentRadius = baseSize + math.sin(tick() * 2.5) * (baseSize * 0.025)
                gradRot = (tick() * 50) % 360
            elseif style == "Pulse" then
                currentRadius = baseSize + math.sin(tick() * 6) * (baseSize * 0.08)
                gradRot = (tick() * 100) % 360
            elseif style == "Rotate" then
                gradRot = (tick() * 150) % 360
                shapeRot = math.rad((tick() * 60) % 360)
            elseif style == "Rainbow" then
                col1 = Color3.fromHSV((tick() * 0.2) % 1, 0.85, 1)
                col2 = Color3.fromHSV(((tick() * 0.2) + 0.33) % 1, 0.85, 1)
                gradRot = (tick() * 60) % 360
            end
            isGradient = AimLockSettings.FovGradient or (style == "Rainbow")
            colorSeq = getFovColorSeq(col1, col2, isGradient)
            thickness = AimLockSettings.FovThickness or 1.5
            trans = AimLockSettings.FovTransparency or 0
            isCircle = (shape == "Circle")
            cornerRad = isCircle and UDim.new(1, 0) or UDim.new(0, 0)
            frameRot = isCircle and 0 or math.deg(shapeRot)
            safeSet(fovMainFrame, "Visible", true)
            safeSet(fovMainFrame, "Size", UDim2.new(0, currentRadius * 2, 0, currentRadius * 2))
            safeSet(fovMainFrame, "Position", UDim2.new(0, center.X, 0, center.Y))
            fovMainFrame.Rotation = frameRot
            safeSet(fovCorner, "CornerRadius", cornerRad)
            safeSet(fovStroke, "Thickness", thickness)
            safeSet(fovStroke, "Transparency", trans)
            if isGradient then
                safeSet(fovStroke, "Color", Color3.fromRGB(255, 255, 255))
                fovStrokeGradient.Enabled = true
                fovStrokeGradient.Color = colorSeq
                fovStrokeGradient.Rotation = gradRot
            else
                safeSet(fovStroke, "Color", col1)
                fovStrokeGradient.Enabled = false
            end
            if AimLockSettings.FovFilled then
                fovMainFrame.BackgroundTransparency = math.clamp(AimLockSettings.FovFillTransparency or 0.85, 0, 1)
                if isGradient then
                    fovMainFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                    fovFillGradient.Enabled = true
                    fovFillGradient.Color = colorSeq
                    fovFillGradient.Rotation = gradRot
                else
                    fovMainFrame.BackgroundColor3 = col1
                    fovFillGradient.Enabled = false
                end
            else
                fovMainFrame.BackgroundTransparency = 1
                fovFillGradient.Enabled = false
            end
            if AimLockSettings.FovGlow then
                for _, g in ipairs(glowLayers) do
                    safeSet(g.Frame, "Visible", true)
                    safeSet(g.Frame, "Size", UDim2.new(0, currentRadius * 2, 0, currentRadius * 2))
                    safeSet(g.Frame, "Position", UDim2.new(0, center.X, 0, center.Y))
                    g.Frame.Rotation = frameRot
                    g.Corner.CornerRadius = cornerRad
                    safeSet(g.Stroke, "Transparency", math.clamp(g.BaseTrans + trans * 0.3, 0, 1))
                    if isGradient then
                        safeSet(g.Stroke, "Color", Color3.fromRGB(255, 255, 255))
                        g.Gradient.Enabled = true
                        g.Gradient.Color = colorSeq
                        g.Gradient.Rotation = gradRot
                    else
                        safeSet(g.Stroke, "Color", col1)
                        g.Gradient.Enabled = false
                    end
                end
            else
                for _, g in ipairs(glowLayers) do
                    safeSet(g.Frame, "Visible", false)
                end
            end
        end)
    end
end
AimLockToggle = AimLockSection:AddToggle("AimLockEnabled", {
    Text = "Enabled",
    Default = false,
    Callback = function(value)
        AimLockSettings.Enabled = value
        updateAimLockFovLoop()
        if getgenv()._updateAimLockLate then
            getgenv()._updateAimLockLate()
        end
        if not value then
            AL_LockedTarget = nil
            AL_BlatantLockedFighter = nil
            AL_LastTarget = nil
        end
    end
})
AimLockToggle:AddKeyPicker("AimLockKey", {
    Default = "None",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Aim Lock",
})
AimLockDep = AimLockSection:AddDependencyBox()
AimLockDep:AddToggle("AimLockTeamCheck", { Text = "TeamCheck", Default = false, Callback = function(v) AimLockSettings.TeamCheck = v end })
AimLockDep:AddToggle("AimLockVisibleCheck", { Text = "VisibleCheck", Default = false, Callback = function(v) AimLockSettings.VisibleCheck = v end })
AimLockDep:AddToggle("AimLockAliveCheck", { Text = "AliveCheck", Default = true, Callback = function(v) AimLockSettings.AliveCheck = v end })
AimLockDep:AddToggle("AimLockStickyAim", { Text = "StickyAim", Default = false, Callback = function(v) AimLockSettings.StickyAim = v end })
AimLockDep:AddSlider("AimLockDistance", { Text = "Distance", Default = 500, Min = 1, Max = 5000, Rounding = 0, Callback = function(v) AimLockSettings.Distance = v end })
AimLockDep:AddDropdown("AimLockTargetPart", {
    Values = {"HitboxHead", "HitboxBody", "Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg"},
    Default = 1,
    Multi = false,
    Text = "Target Part",
    Callback = function(value) AimLockSettings.TargetPart = value end
})
AimLockDep:AddDivider()
AimLockPredToggle = AimLockDep:AddToggle("AimLockPrediction", { Text = "Prediction enabled", Default = false, Callback = function(v) AimLockSettings.Prediction = v end })
AimLockPredDep = AimLockDep:AddDependencyBox()
AimLockPredDep:AddSlider("AimLockPredX", { Text = "X ( Division)", Default = 10, Min = 1, Max = 50, Rounding = 1, Callback = function(v) AimLockSettings.PredX = v end })
AimLockPredDep:AddSlider("AimLockPredY", { Text = "Y (Division)", Default = 10, Min = 1, Max = 50, Rounding = 1, Callback = function(v) AimLockSettings.PredY = v end })
AimLockPredDep:SetupDependencies({ { AimLockPredToggle, true } })
AimLockDep:AddDivider()
AimLockSmoothToggle = AimLockDep:AddToggle("AimLockSmoothing", { Text = "Smoothness Enabled", Default = false, Callback = function(v) AimLockSettings.Smoothing = v end })
AimLockSmoothDep = AimLockDep:AddDependencyBox()
AimLockSmoothDep:AddSlider("AimLockSmoothX", { Text = "Smoothness X", Default = 0, Min = 0, Max = 50, Rounding = 1, Callback = function(v) AimLockSettings.SmoothX = v end })
AimLockSmoothDep:AddSlider("AimLockSmoothY", { Text = "Smoothness Y", Default = 0, Min = 0, Max = 50, Rounding = 1, Callback = function(v) AimLockSettings.SmoothY = v end })
AimLockSmoothDep:AddSlider("AimLockSensitivity", { Text = "Sensitivity", Default = 1, Min = 0, Max = 2, Rounding = 2, Callback = function(v) AimLockSettings.Sensitivity = v end })
AimLockSmoothDep:SetupDependencies({ { AimLockSmoothToggle, true } })
AimLockDep:AddDivider()
AimLockFovToggle = AimLockDep:AddToggle("AimLock_FovEnabled", {
    Text = "FOV Enabled",
    Default = false,
    Callback = function(v)
        AimLockSettings.FovEnabled = v
        updateAimLockFovLoop()
    end
})
AimLockFovToggle:AddColorPicker("AimLock_FovColor", {
    Default = AimLockSettings.FovColor,
    Title = "FOV Color",
    Callback = function(v) AimLockSettings.FovColor = v end
})
AimLockFovToggle:AddColorPicker("AimLock_FovColor2", {
    Default = AimLockSettings.FovColor2,
    Title = "Gradient Color",
    Callback = function(v) AimLockSettings.FovColor2 = v end
})
AimLockFovDep = AimLockDep:AddDependencyBox()
AimLockFovDep:AddSlider("AimLock_FovSize", {
    Text = "Size",
    Default = 150,
    Min = 20,
    Max = 1000,
    Rounding = 0,
    Callback = function(v) AimLockSettings.FovSize = v end
})
AimLockFovDep:AddDropdown("AimLock_FovShape", {
    Text = "Shape",
    Values = {"Circle", "Square"},
    Default = 1,
    Multi = false,
    Callback = function(v) AimLockSettings.FovShape = v end
})
AimLockFovDep:AddDropdown("AimLock_FovStyle", {
    Text = "Style",
    Values = {"Smooth", "Static", "Pulse", "Rainbow", "Rotate"},
    Default = 1,
    Multi = false,
    Callback = function(v) AimLockSettings.FovStyle = v end
})
AimLockFovDep:AddToggle("AimLock_FovFilled", {
    Text = "Filled",
    Default = false,
    Callback = function(v) AimLockSettings.FovFilled = v end
})
AimLockFovDep:AddToggle("AimLock_FovGlow", {
    Text = "Glow",
    Default = false,
    Callback = function(v) AimLockSettings.FovGlow = v end
})
AimLockFovDep:AddToggle("AimLock_FovGradient", {
    Text = "Gradient",
    Default = false,
    Callback = function(v) AimLockSettings.FovGradient = v end
})
AimLockFovDep:AddSlider("AimLock_FovThickness", {
    Text = "Thickness",
    Default = 1.5,
    Min = 1,
    Max = 10,
    Rounding = 1,
    Callback = function(v) AimLockSettings.FovThickness = v end
})
AimLockFovDep:AddSlider("AimLock_FovTransparency", {
    Text = "Transparency",
    Default = 0,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Callback = function(v) AimLockSettings.FovTransparency = v end
})
AimLockFovDep:SetupDependencies({ { AimLockFovToggle, true } })
AimLockDep:SetupDependencies({ { AimLockToggle, true } })
TriggerBotSection = Tabs.Combat:AddLeftGroupbox("TriggerBot")
getgenv().TriggerBotSettings = {
    Enabled = false,
    Delay = 100,
    MaxDistance = 50,
    TeamCheck = false,
}
TriggerBotToggle = TriggerBotSection:AddToggle("TriggerBotEnabled", {
    Text = "Enabled",
    Default = false,
    Callback = function(value)
        getgenv().TriggerBotSettings.Enabled = value
        if getgenv()._updateTriggerBotLoop then getgenv()._updateTriggerBotLoop() end
    end
})
TriggerBotToggle:AddKeyPicker("TriggerBotKey", {
    Default = "None",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Trigger Bot",
})
TriggerBotDep = TriggerBotSection:AddDependencyBox()
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
    plrs = game:GetService("Players")
    runS = game:GetService("RunService")
    ws = game:GetService("Workspace")
    lplr = plrs.LocalPlayer
    local fC, mC
    pcall(function() fC = require(lplr.PlayerScripts.Controllers.FighterController) end)
    pcall(function() mC = require(lplr.PlayerScripts.Controllers.MechanicsController) end)
    lastShot = 0
    _tbRayParams = RaycastParams.new()
    _tbRayParams.FilterType = Enum.RaycastFilterType.Exclude
    _tbRayParams.IgnoreWater = true
    _tbExclude = {}
    local function updateTbExclude()
        curCam = ws.CurrentCamera
        myChar = lplr.Character
        _tbExclude = (myChar and curCam) and {myChar, curCam} or (curCam and {curCam} or {})
        _tbRayParams.FilterDescendantsInstances = _tbExclude
    end
    lplr.CharacterAdded:Connect(updateTbExclude)
    task.spawn(updateTbExclude)
    _tbHeartbeatConn = nil
    local function updateTriggerBotLoop()
        if getgenv().TriggerBotSettings.Enabled then
            if not _tbHeartbeatConn then
                _tbHeartbeatConn = runS.Heartbeat:Connect(function()
                    if not getgenv().TriggerBotSettings.Enabled then
                        if _tbHeartbeatConn then _tbHeartbeatConn:Disconnect(); _tbHeartbeatConn = nil end
                        return
                    end
                    local cam = ws.CurrentCamera
                    if not cam then return end
                    vp = cam.ViewportSize
                    unitRay = cam:ViewportPointToRay(vp.X * 0.5, vp.Y * 0.5)
                    maxDist = getgenv().TriggerBotSettings.MaxDistance
                    rayResult = ws:Raycast(unitRay.Origin, unitRay.Direction * maxDist, _tbRayParams)
                    if not rayResult or not rayResult.Instance then return end
                    hitPart = rayResult.Instance
                    hitModel = hitPart:FindFirstAncestorOfClass("Model")
                    if not hitModel then return end
                    hitPlr = plrs:GetPlayerFromCharacter(hitModel)
                    if not hitPlr or hitPlr == lplr then return end
                    triggerTeamCheck = getgenv().TriggerBotSettings.TeamCheck
                    if triggerTeamCheck then
                        myID = lplr:GetAttribute("TeamID")
                        theirID = hitPlr:GetAttribute("TeamID")
                        if (myID ~= nil and myID == theirID) then
                            if SpectateController then
                                duel = SpectateController.CurrentDuelSubject
                                localDueler = duel and duel:GetDueler(lplr)
                                if localDueler and duel.Duelers then
                                    localTeam = localDueler:Get("TeamID")
                                    if localTeam then
                                        isEnemy = false
                                        for _, dueler in next, duel.Duelers do
                                            if dueler.Player == hitPlr then
                                                if localTeam == nil or dueler:Get("TeamID") ~= localTeam then isEnemy = true end
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
                            else
                                return
                            end
                        end
                    end
                    hum = hitModel:FindFirstChildOfClass("Humanoid")
                    if not hum or hum.Health <= 0 then return end
                    fighter = fC and fC:GetFighter(lplr)
                    if not fighter then return end
                    item = fighter.EquippedItem
                    if not item then return end
                    ammo = nil
                    if type(item.Get) == "function" then
                        ammo = item:Get("Ammo")
                    end
                    reloadCD = item._reload_cooldown or 0
                    if (tick() < reloadCD) or (type(ammo) == "number" and ammo <= 0) then return end
                    now = tick()
                    delaySec = getgenv().TriggerBotSettings.Delay / 1000
                    if now - lastShot < delaySec then return end
                    lastShot = now
                    if mC and type(mC.EquippedItemInput) == "function" then
                        mC:EquippedItemInput("StartShooting")
                    end
                end)
            end
        else
            if _tbHeartbeatConn then
                _tbHeartbeatConn:Disconnect()
                _tbHeartbeatConn = nil
            end
        end
    end
    getgenv()._updateTriggerBotLoop = updateTriggerBotLoop
    updateTriggerBotLoop()
end)
do
    AntiFreezeSection = Tabs.Combat:AddRightGroupbox("Anti Freeze Ray")
    getgenv().AntiFreezeEnabled = false
    CameraController = nil
    MechanicsController = nil
    ClientEntityModule = nil
    task.spawn(function()
    end)
    local function hookEntity(ent)
        if not ent or ent._afGetHooked then return end
        ent._afGetHooked = true
        oldGet = ent.Get
        ent.Get = function(self, key, ...)
            if getgenv().AntiFreezeEnabled and key == "IsFrozen" then
                return false
            end
            return oldGet(self, key, ...)
        end
    end
    afConn = nil
    local function updateAntiFreezeLoop()
        if getgenv().AntiFreezeEnabled then
            if not afConn then
                lastAfCheck = 0
                afConn = RunService.Heartbeat:Connect(function()
                    if not getgenv().AntiFreezeEnabled then
                        if afConn then afConn:Disconnect(); afConn = nil end
                        return
                    end
                    now = tick()
                    if now - lastAfCheck < 0.1 then return end
                    lastAfCheck = now
                    char = lp.Character
                    if char then
                        hum = char:FindFirstChild("Humanoid")
                        if hum then
                            if hum.PlatformStand then hum.PlatformStand = false end
                            hum:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
                        end
                    end
                    if FighterController and FighterController.LocalFighter then
                        lf = FighterController.LocalFighter
                        hookEntity(lf)
                        if lf.Entity then hookEntity(lf.Entity) end
                        if lf.Character then hookEntity(lf.Character) end
                    end
                end)
            end
        else
            if afConn then afConn:Disconnect(); afConn = nil end
        end
    end
    AntiFreezeSection:AddToggle("AntiFreezeEnabled", {
        Text = "Anti Freeze Ray",
        Default = false,
        Callback = function(v)
            getgenv().AntiFreezeEnabled = v
            updateAntiFreezeLoop()
        end
    }):AddKeyPicker("AntiFreezeKey", {
        Default = "None",
        SyncToggleState = true,
        Mode = "Toggle",
        Text = "Anti Freeze Ray",
    })
end
ESPSection = Tabs.Visuals:AddLeftGroupbox("ESP")
ESPToggle = ESPSection:AddToggle("ESP_Enabled", {
    Text = "Enabled", Default = false,
    Callback = function(value)
        espSettings.MasterEnabled = value
        updateEspLoop()
    end
})
ESPToggle:AddKeyPicker("ESPKey", {
    Default = "None",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "ESP",
})
ESPDep = ESPSection:AddDependencyBox()
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
ESPDep:AddToggle("ESP_RanDomEsp", { Text = "RanDomEsp", Default = false, Callback = function(v) espSettings.RanDomEsp = v end })
ESPDep:AddSlider("ESP_RanDomEspDist", { Text = "RanDomEsp Distance", Default = 300, Min = 50, Max = 1500, Rounding = 0, Callback = function(v) espSettings.RanDomEspDist = v end })
WallESPToggle = ESPDep:AddToggle("WallESP_Enabled", {
    Text = "Wall ESP", Default = false,
    Callback = function(v)
        espSettings.WallESP = v
        if not v then
            for _, p in pairs(Players:GetPlayers()) do
                clearHighlight(p)
            end
        end
    end
})
    :AddColorPicker("WallESP_WallColor", {
        Title = "Wall Color",
        Default = espSettings.WallESPColor,
        Callback = function(v) espSettings.WallESPColor = v end
    })
    :AddColorPicker("WallESP_NoWallColor", {
        Title = "No-Wall Color",
        Default = espSettings.WallESPNoWallColor,
        Callback = function(v) espSettings.WallESPNoWallColor = v end
    })
ESPDep:AddSlider("WallESP_Transparency", {
    Text = "Wall ESP Transparency",
    Default = 50,
    Min = 0,
    Max = 100,
    Rounding = 0,
    Callback = function(v)
        espSettings.WallESPTransparency = v / 100
    end
})
ESPDep:SetupDependencies({ { ESPToggle, true } })
do
    CameraSection = Tabs.Visuals:AddLeftGroupbox("Camera")
    tpEnabled = false
    cameraControllerCache = nil
    local function getCameraController()
        if cameraControllerCache then return cameraControllerCache end
        pcall(function()
            controllers = lp:WaitForChild("PlayerScripts", 5):WaitForChild("Controllers", 5)
            cameraControllerCache = require(controllers:WaitForChild("CameraController", 5))
        end)
        return cameraControllerCache
    end
    local function setThirdPerson(val)
        tpEnabled = val
        pcall(function()
            cc = getCameraController()
            if cc then
                cc:SetThirdPersonOverride(val)
                if cc.CameraState and cc.CameraState.States then
                    targetState = val and cc.CameraState.States.ThirdPerson or cc.CameraState.States.FirstPerson
                    if cc.CameraState._SetPOVState then
                        cc.CameraState:_SetPOVState(targetState)
                    elseif cc.CameraState.VerifyPOV then
                        cc.CameraState:VerifyPOV()
                    end
                end
            end
        end)
    end
    ThirdPersonToggle = CameraSection:AddToggle("ThirdPersonToggle", {
        Text = "Third Person",
        Default = false,
        Callback = function(v)
            setThirdPerson(v)
        end
    })
    ThirdPersonToggle:AddKeyPicker("ThirdPersonKey", {
        Default = "None",
        SyncToggleState = true,
        Mode = "Toggle",
        Text = "Third Person",
    })
    lp.CharacterAdded:Connect(function()
        if tpEnabled then
            task.wait(0.5)
            setThirdPerson(true)
        end
    end)
end
local vmOffsetEnabled, vmOffsetX, vmOffsetY, vmOffsetZ
local ensureVMHook
do
	vmOffsetEnabled = false
	vmOffsetX, vmOffsetY, vmOffsetZ = 0, 0, 0
	_vmCVM = nil
	_vmOriginalSetCFrame = nil
	ensureVMHook = function()
		if _vmCVM then return true end
		scripts = lp:WaitForChild("PlayerScripts", 10)
		if not scripts then return false end
		local cvmM
		for _, v in pairs(scripts:GetDescendants()) do
			if v:IsA("ModuleScript") and (v.Name == "ClientViewModel" or v.Name == "ModuleScript_ClientViewModel") then
				cvmM = v; break
			end
		end
		if not cvmM then return false end
		local ok, CVM = pcall(require, cvmM)
		if not ok or type(CVM) ~= "table" then return false end
		_vmCVM = CVM
		_vmOriginalSetCFrame = CVM.SetCFrame
		CVM.SetCFrame = function(self, cf)
			if vmOffsetEnabled and typeof(cf) == "CFrame" then
				cf = cf * CFrame.new(vmOffsetX, vmOffsetY, vmOffsetZ)
			end
			return _vmOriginalSetCFrame(self, cf)
		end
		return true
	end
end
VisVMBox = Tabs.Visuals:AddRightGroupbox("ViewModel Mover")
VMOffsetToggle = VisVMBox:AddToggle("VMOffsetEnabled", {
	Text = "ViewModel Mover",
	Default = false,
	Callback = function(Value)
		vmOffsetEnabled = Value
		if Value then
			task.spawn(ensureVMHook)
		end
	end,
})
VisVMDepBox = VisVMBox:AddDependencyBox()
VisVMDepBox:AddSlider("VMOffsetX", {
	Text = "X (Left/Right)",
	Default = 0, Min = -5, Max = 5, Rounding = 2,
	Callback = function(Value) vmOffsetX = Value end,
})
VisVMDepBox:AddSlider("VMOffsetY", {
	Text = "Y (Down/Up)",
	Default = 0, Min = -5, Max = 5, Rounding = 2,
	Callback = function(Value) vmOffsetY = Value end,
})
VisVMDepBox:AddSlider("VMOffsetZ", {
	Text = "Z (Forward/Back)",
	Default = 0, Min = -5, Max = 5, Rounding = 2,
	Callback = function(Value) vmOffsetZ = Value end,
})
VisVMDepBox:SetupDependencies({ { VMOffsetToggle, true } })
noVMAnim = false
noFireSound = false
noArmEnabled = false
noArmConnection = nil
_muteFireSoundUntil = 0
_cvmHooked = false
_animHooked = false
_cfcHooked = false
_mcHooked = false
ARM_PART_NAMES = {
    LeftArm = true, RightArm = true,
    LeftArmWrapped = true, RightArmWrapped = true,
    LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
    RightUpperArm = true, RightLowerArm = true, RightHand = true,
}
function setPartNoArm(part, hidden)
    if not part then return end
    if part:IsA("BasePart") then
        part.Transparency = hidden and 1 or 0
        part.LocalTransparencyModifier = hidden and 1 or 0
    elseif part:IsA("Decal") or part:IsA("Texture") then
        part.Transparency = hidden and 1 or 0
    end
end
function applyNoArmToModel(model, hidden)
    if not model then return end
    for _, child in ipairs(model:GetChildren()) do
        if ARM_PART_NAMES[child.Name] then
            setPartNoArm(child, hidden)
            for _, d in ipairs(child:GetDescendants()) do
                setPartNoArm(d, hidden)
            end
        end
    end
end
local updateNoArmInWorld
vmMat = {
    Arm    = { Material = "Default", ColorOn = false, Color = Color3.fromRGB(0, 170, 255), Anim = "Default", CustomID = "" },
    Weapon = { Material = "Default", ColorOn = false, Color = Color3.fromRGB(255, 85, 255), Anim = "Default", CustomID = "" },
}
_origProps = setmetatable({}, { __mode = "k" })
VM_IGNORED = { HumanoidRootPart = true, Camera = true, ViewModelRoot = true, Primary = true, _aim_position = true, _aim_lookat = true, _center = true }
MATERIAL_LIST = { "Default", "ForceField", "Neon", "Glass", "SmoothPlastic", "Metal", "Foil", "DiamondPlate", "Ice", "CorrodedMetal", "Wood", "Brick", "Granite", "Marble" }
FF_ANIMS = {
    Default = "", Hexagon = "rbxassetid://5101923607", Lightning = "rbxassetid://733527264",
    Matrix = "rbxassetid://1088661278", Waves = "rbxassetid://6354471929", Grid = "rbxassetid://26974880",
    Galaxy = "rbxassetid://159991444", Noise = "rbxassetid://276060293", Pulse = "rbxassetid://6686375902", Custom = "CUSTOM",
}
FF_ANIM_LIST = { "Default", "Hexagon", "Lightning", "Matrix", "Waves", "Grid", "Galaxy", "Noise", "Pulse", "Custom" }
function vmFFTexture(cfg)
    if cfg.Anim == "Custom" then
        num = tostring(cfg.CustomID):gsub("%D", "")
        return #num > 0 and ("rbxassetid://" .. num) or ""
    end
    return FF_ANIMS[cfg.Anim] or ""
end
function isArmInstance(inst)
    cur = inst
    while cur and cur ~= workspace do
        if ARM_PART_NAMES[cur.Name] or cur.Name == "_left_arm" or cur.Name == "_right_arm" then return true end
        cur = cur.Parent
    end
    return false
end
function restoreVMPart(p)
    o = _origProps[p]
    if not o then return end
    pcall(function()
        if o.Material then p.Material = o.Material end
        if o.Color then p.Color = o.Color end
        if o.TextureID ~= nil then p.TextureID = o.TextureID end
        if o.MeshTex ~= nil then
            sm = p:FindFirstChildOfClass("SpecialMesh")
            if sm then sm.TextureId = o.MeshTex end
        end
    end)
    _origProps[p] = nil
end
function restoreVMGroup(isArm)
    for p in pairs(_origProps) do
        if p.Parent and isArmInstance(p) == isArm then restoreVMPart(p) end
    end
end
function processVMMaterials(model)
    if not model then return end
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") and not VM_IGNORED[d.Name] then
            isArm = isArmInstance(d)
            cfg = isArm and vmMat.Arm or vmMat.Weapon
            if isArm and noArmEnabled then
            elseif cfg.Material == "Default" and not cfg.ColorOn then
                restoreVMPart(d)
            else
                if not _origProps[d] then
                    sm = d:FindFirstChildOfClass("SpecialMesh")
                    _origProps[d] = { Material = d.Material, Color = d.Color, TextureID = d:IsA("MeshPart") and d.TextureID or nil, MeshTex = sm and sm.TextureId or nil }
                end
                matEnum = cfg.Material ~= "Default" and Enum.Material[cfg.Material] or nil
                if matEnum and d.Material ~= matEnum then d.Material = matEnum end
                if cfg.ColorOn and d.Color ~= cfg.Color then d.Color = cfg.Color end
                if cfg.Material == "ForceField" then
                    tex = vmFFTexture(cfg)
                    if d:IsA("MeshPart") and d.TextureID ~= tex then d.TextureID = tex end
                    sm = d:FindFirstChildOfClass("SpecialMesh")
                    if sm and sm.TextureId ~= tex then sm.TextureId = tex end
                end
            end
        end
    end
end
function vmMaterialActive()
    return vmMat.Arm.Material ~= "Default" or vmMat.Arm.ColorOn or vmMat.Weapon.Material ~= "Default" or vmMat.Weapon.ColorOn
end
function forEachVMModel(fn)
    vmFolder = workspace:FindFirstChild("ViewModels")
    if vmFolder then
        fp = vmFolder:FindFirstChild("FirstPerson")
        if fp then
            for _, m in ipairs(fp:GetChildren()) do if m:IsA("Model") then fn(m) end end
        end
        for _, m in ipairs(vmFolder:GetChildren()) do
            if m:IsA("Model") and m.Name ~= "FirstPerson" then fn(m) end
        end
    end
    curCam = workspace.CurrentCamera
    if curCam then
        for _, m in ipairs(curCam:GetChildren()) do
            if m:IsA("Model") and (m:FindFirstChild("LeftArm") or m:FindFirstChild("RightArm") or m:FindFirstChild("ItemVisual")) then fn(m) end
        end
    end
end
function updateVMMaterials()
    forEachVMModel(processVMMaterials)
end
function checkVMLoopState()
    if noArmEnabled or vmMaterialActive() then
        if not noArmConnection then
            lastVMUpdate = 0
            noArmConnection = RunService.RenderStepped:Connect(function()
                now = tick()
                if now - lastVMUpdate < 0.05 then return end
                lastVMUpdate = now
                if noArmEnabled then updateNoArmInWorld(true) end
                if vmMaterialActive() then updateVMMaterials() end
            end)
            getgenv().KETY_NoArmConnection = noArmConnection
        end
    elseif noArmConnection then
        noArmConnection:Disconnect()
        noArmConnection = nil
        getgenv().KETY_NoArmConnection = nil
    end
end
updateNoArmInWorld = function(hidden)
    vmFolder = workspace:FindFirstChild("ViewModels")
    if vmFolder then
        fp = vmFolder:FindFirstChild("FirstPerson")
        if fp then
            for _, m in ipairs(fp:GetChildren()) do
                if m:IsA("Model") then applyNoArmToModel(m, hidden) end
            end
        end
        for _, m in ipairs(vmFolder:GetChildren()) do
            if m:IsA("Model") and m.Name ~= "FirstPerson" then
                applyNoArmToModel(m, hidden)
            end
        end
    end
    curCam = workspace.CurrentCamera
    if curCam then
        for _, m in ipairs(curCam:GetChildren()) do
            if m:IsA("Model") and (m:FindFirstChild("LeftArm") or m:FindFirstChild("RightArm") or m:FindFirstChild("LeftUpperArm")) then
                applyNoArmToModel(m, hidden)
            end
        end
    end
end
function _nvmFindModule(nameSet)
    scripts = lp:FindFirstChild("PlayerScripts")
    if scripts then
        for _, v in pairs(scripts:GetDescendants()) do
            if v:IsA("ModuleScript") and nameSet[v.Name] then return v end
        end
    end
    rep = game:GetService("ReplicatedStorage")
    for _, v in pairs(rep:GetDescendants()) do
        if v:IsA("ModuleScript") and nameSet[v.Name] then return v end
    end
    return nil
end
function ensureNoVMAnimHook()
    if not _cvmHooked then
        cvmM = _nvmFindModule({ ClientViewModel = true, ModuleScript_ClientViewModel = true })
        if cvmM then
            local ok, CVM = pcall(require, cvmM)
            if ok and type(CVM) == "table" then
                origApplyRecoil = CVM.ApplyRecoil
                origImpulse     = CVM.Impulse
                origUpdate      = CVM.Update
                origCreateSound = CVM.CreateSound
                CVM.ApplyRecoil = function(self, ...)
                    if noVMAnim then return end
                    return origApplyRecoil(self, ...)
                end
                CVM.Impulse = function(self, ...)
                    if noVMAnim then return end
                    return origImpulse(self, ...)
                end
                CVM.CreateSound = function(self, ...)
                    if noFireSound and tick() < _muteFireSoundUntil then return nil end
                    return origCreateSound(self, ...)
                end
                V3z = Vector3.new(0, 0, 0)
                CVM.Update = function(self, ...)
                    if noVMAnim then
                        if not self._noVMAnimApplied then
                            self._noVMAnimApplied = true
                            task.delay(0.001, function()
                                if not noVMAnim then return end
                                pcall(function()
                                    anim = self.Animator
                                    if anim and anim._animation_tracks and anim._idle_animation then
                                        track = anim._animation_tracks[anim._idle_animation]
                                        if track and track.IsPlaying then track:AdjustSpeed(0) end
                                    end
                                end)
                            end)
                        end
                        pcall(function()
                            if self._bobbing_value_spring then self._bobbing_value_spring.Target = Vector2.zero; self._bobbing_value_spring.Value = Vector2.zero end
                            if self._sway_spring        then self._sway_spring.Target = Vector2.zero; self._sway_spring.Value = Vector2.zero end
                            if self._jump_spring        then self._jump_spring.Target = 0; self._jump_spring.Value = 0; self._jump_spring.Velocity = 0 end
                            if self._landing_spring     then self._landing_spring.Target = 0; self._landing_spring.Value = 0; self._landing_spring.Velocity = 0 end
                            if self._tilt_spring        then self._tilt_spring.Target = Vector2.zero; self._tilt_spring.Value = Vector2.zero end
                            if self._sprinting_spring   then self._sprinting_spring.Target = 0; self._sprinting_spring.Value = 0 end
                            if self._bobbing_speed_spring then self._bobbing_speed_spring.Target = 0; self._bobbing_speed_spring.Value = 0 end
                            if self._recoil_spring      then self._recoil_spring.Target = V3z; self._recoil_spring.Value = V3z; self._recoil_spring.Velocity = V3z end
                            if self._unrecoil_spring    then self._unrecoil_spring.Target = V3z; self._unrecoil_spring.Value = V3z; self._unrecoil_spring.Velocity = V3z end
                            if self._impulse_position_spring then self._impulse_position_spring.Target = V3z; self._impulse_position_spring.Value = V3z; self._impulse_position_spring.Velocity = V3z end
                            if self._sliding_spring     then self._sliding_spring.Target = 0; self._sliding_spring.Value = 0; self._sliding_spring.Velocity = 0 end
                            if self._equip_spring       then self._equip_spring.Target = 0; self._equip_spring.Value = 0; self._equip_spring.Velocity = 0 end
                        end)
                    else
                        if self._noVMAnimApplied then
                            self._noVMAnimApplied = false
                            pcall(function()
                                anim = self.Animator
                                if anim and anim._animation_tracks and anim._idle_animation then
                                    track = anim._animation_tracks[anim._idle_animation]
                                    if track and track.IsPlaying then track:AdjustSpeed(1) end
                                end
                            end)
                        end
                    end
                    local ret = origUpdate(self, ...)
                    if noArmEnabled then
                        pcall(function()
                            if self._left_arm then
                                self._left_arm.Transparency = 1
                                self._left_arm.LocalTransparencyModifier = 1
                            end
                            if self._right_arm then
                                self._right_arm.Transparency = 1
                                self._right_arm.LocalTransparencyModifier = 1
                            end
                            if self._left_arm_shirt_texture then self._left_arm_shirt_texture.Transparency = 1 end
                            if self._right_arm_shirt_texture then self._right_arm_shirt_texture.Transparency = 1 end
                            if self._left_arm_wrapped_part then
                                self._left_arm_wrapped_part.Transparency = 1
                                self._left_arm_wrapped_part.LocalTransparencyModifier = 1
                            end
                            if self._right_arm_wrapped_part then
                                self._right_arm_wrapped_part.Transparency = 1
                                self._right_arm_wrapped_part.LocalTransparencyModifier = 1
                            end
                            if self._arm_submodels then
                                for submodel, _ in pairs(self._arm_submodels) do
                                    for _, p in ipairs(submodel:GetDescendants()) do
                                        if p:IsA("BasePart") then
                                            p.Transparency = 1
                                            p.LocalTransparencyModifier = 1
                                        elseif p:IsA("Decal") or p:IsA("Texture") then
                                            p.Transparency = 1
                                        end
                                    end
                                end
                            end
                            if self.Model then
                                applyNoArmToModel(self.Model, true)
                            end
                            self._noArmActive = true
                        end)
                    elseif self._noArmActive then
                        self._noArmActive = false
                        pcall(function()
                            if self._left_arm then
                                self._left_arm.Transparency = 0
                                self._left_arm.LocalTransparencyModifier = 0
                            end
                            if self._right_arm then
                                self._right_arm.Transparency = 0
                                self._right_arm.LocalTransparencyModifier = 0
                            end
                            if self._left_arm_shirt_texture then self._left_arm_shirt_texture.Transparency = 0 end
                            if self._right_arm_shirt_texture then self._right_arm_shirt_texture.Transparency = 0 end
                            if self._left_arm_wrapped_part then
                                self._left_arm_wrapped_part.Transparency = 0
                                self._left_arm_wrapped_part.LocalTransparencyModifier = 0
                            end
                            if self._right_arm_wrapped_part then
                                self._right_arm_wrapped_part.Transparency = 0
                                self._right_arm_wrapped_part.LocalTransparencyModifier = 0
                            end
                            if self._arm_submodels then
                                for submodel, _ in pairs(self._arm_submodels) do
                                    for _, p in ipairs(submodel:GetDescendants()) do
                                        if p:IsA("BasePart") then
                                            p.Transparency = 0
                                            p.LocalTransparencyModifier = 0
                                        elseif p:IsA("Decal") or p:IsA("Texture") then
                                            p.Transparency = 0
                                        end
                                    end
                                end
                            end
                            if self.Model then
                                applyNoArmToModel(self.Model, false)
                            end
                        end)
                    end
                    if vmMaterialActive() and self.Model then
                        pcall(processVMMaterials, self.Model)
                    end
                    return ret
                end
                _cvmHooked = true
            end
        end
    end
    if not _animHooked then
        local AnimLib
        pcall(function()
            AnimLib = require(game:GetService("ReplicatedStorage").Modules.AnimationLibrary)
        end)
        animM = _nvmFindModule({ ViewModelAnimator = true, ModuleScript_ViewModelAnimator = true })
        if animM then
            local okA, ANIM = pcall(require, animM)
            if okA and type(ANIM) == "table" then
                if type(ANIM.PlayAnimation) == "function" then
                    origPlay = ANIM.PlayAnimation
                    ANIM.PlayAnimation = function(self, key, ...)
                        if type(key) == "string" then
                            isShoot  = key == "QuickShot" or key == "FinalShoot" or key == "ShootAiming" or string.sub(key,1,5) == "Shoot"
                            isAttack = string.sub(key,1,6) == "Attack"
                            isReload = string.find(key, "Reload") ~= nil
                            if noVMAnim and (isShoot or isAttack or isReload) then
                                shouldPlaySound = false
                                if isShoot and not noFireSound then
                                    shouldPlaySound = true
                                elseif isReload then
                                    shouldPlaySound = true
                                end
                                if shouldPlaySound and AnimLib and type(AnimLib.Info) == "table" then
                                    pcall(function()
                                        animName = self._viewmodel_animations and self._viewmodel_animations[key]
                                        if animName then
                                            info = AnimLib.Info[animName]
                                            if info and type(info.SoundCallback) == "function" then
                                                self._animation_hashes[animName] = (self._animation_hashes[animName] or 0) + 1
                                                task.defer(info.SoundCallback, self.ClientViewModel, self._animation_hashes[animName], info.Speed or 1)
                                            end
                                        end
                                    end)
                                end
                                if noFireSound and isShoot then _muteFireSoundUntil = tick() + 0.2 end
                                if self.AnimationPlayed then
                                    pcall(function() self.AnimationPlayed:Fire(key) end)
                                end
                                return
                            end
                        end
                        return origPlay(self, key, ...)
                    end
                end
                if type(ANIM.PlaySprintAnimation) == "function" then
                    origSprint = ANIM.PlaySprintAnimation
                    ANIM.PlaySprintAnimation = function(self, ...)
                        if noVMAnim then return end
                        return origSprint(self, ...)
                    end
                end
                if type(ANIM.PlayIdleAnimation) == "function" then
                    origIdle = ANIM.PlayIdleAnimation
                    ANIM.PlayIdleAnimation = function(self, ...)
                        local ret = origIdle(self, ...)
                        if noVMAnim then
                            task.delay(0.001, function()
                                if not noVMAnim then return end
                                pcall(function()
                                    track = self._animation_tracks and self._animation_tracks[self._idle_animation]
                                    if track and track.IsPlaying then track:AdjustSpeed(0) end
                                end)
                            end)
                        end
                        return ret
                    end
                end
                _animHooked = true
            end
        end
    end
    if not _cfcHooked then
        cfcM = _nvmFindModule({ ClientFighterCharacter = true, ModuleScript_ClientFighterCharacter = true })
        if cfcM then
            local okC, CFC = pcall(require, cfcM)
            if okC and type(CFC) == "table" and type(CFC.PlaySlidingAnimation) == "function" then
                origPlaySlide = CFC.PlaySlidingAnimation
                CFC.PlaySlidingAnimation = function(self, ...)
                    if noVMAnim then
                        pcall(function() self:StopSlidingAnimation() end)
                        return
                    end
                    return origPlaySlide(self, ...)
                end
                _cfcHooked = true
            end
        end
    end
    if not _mcHooked then
        pcall(function()
            controllers = lp:FindFirstChild("PlayerScripts") and lp.PlayerScripts:FindFirstChild("Controllers")
            mcM = controllers and controllers:FindFirstChild("MechanicsController")
            if mcM then
                MC = require(mcM)
                if MC and type(MC) == "table" and type(MC.Slide) == "function" then
                    origSlide = MC.Slide
                    MC.Slide = function(self, ...)
                        if noVMAnim and self.LocalFighter and self.LocalFighter.Entity then
                            pcall(function() self.LocalFighter.Entity:StopSlidingAnimation() end)
                        end
                        return origSlide(self, ...)
                    end
                    _mcHooked = true
                end
            end
        end)
    end
    return _cvmHooked and _animHooked
end
VisVMBox:AddToggle("NoVMAnim_Enabled", {
    Text = "No ViewModel Animation",
    Default = false,
    Callback = function(v)
        noVMAnim = v
        if v then
            task.spawn(ensureNoVMAnimHook)
            pcall(function()
                controllers = lp:FindFirstChild("PlayerScripts") and lp.PlayerScripts:FindFirstChild("Controllers")
                mcM = controllers and controllers:FindFirstChild("MechanicsController")
                if mcM then
                    MC = require(mcM)
                    if MC and MC.LocalFighter and MC.LocalFighter.Entity then
                        MC.LocalFighter.Entity:StopSlidingAnimation()
                    end
                end
            end)
        end
    end,
})
VisVMBox:AddToggle("NoFireSound_Enabled", {
    Text = "No Fire Sound",
    Default = false,
    Callback = function(v)
        noFireSound = v
        if v then task.spawn(ensureNoVMAnimHook) end
    end,
})
VisVMBox:AddToggle("NoArm_Enabled", {
    Text = "No Arm",
    Default = false,
    Tooltip = "Viewmodelの腕を非表示にする",
    Callback = function(v)
        noArmEnabled = v
        if v then
            task.spawn(ensureNoVMAnimHook)
            updateNoArmInWorld(true)
        else
            updateNoArmInWorld(false)
        end
        checkVMLoopState()
    end,
})
for _, key in ipairs({ "Arm", "Weapon" }) do
    isArm = key == "Arm"
    cfg = vmMat[key]
    VisVMBox:AddDivider()
    matDrop = VisVMBox:AddDropdown(key .. "Material", {
        Values = MATERIAL_LIST, Default = 1, Multi = false,
        Text = key .. " Material",
        Callback = function(v)
            cfg.Material = v
            if v == "Default" and not cfg.ColorOn then restoreVMGroup(isArm) end
            if v ~= "Default" then task.spawn(ensureNoVMAnimHook) end
            checkVMLoopState()
            updateVMMaterials()
        end,
    })
    VisVMBox:AddToggle(key .. "ColorEnabled", {
        Text = key .. " Custom Color", Default = false,
        Callback = function(v)
            cfg.ColorOn = v
            if not v then restoreVMGroup(isArm) end
            checkVMLoopState()
            updateVMMaterials()
        end,
    }):AddColorPicker(key .. "Color", {
        Default = cfg.Color,
        Callback = function(v) cfg.Color = v; updateVMMaterials() end,
    })
    ffDep = VisVMBox:AddDependencyBox()
    ffDep:AddDropdown(key .. "FFAnim", {
        Values = FF_ANIM_LIST, Default = 1, Multi = false,
        Text = key .. " FF Animation",
        Callback = function(v) cfg.Anim = v; updateVMMaterials() end,
    })
    ffDep:AddInput(key .. "FFCustomID", {
        Default = "", Text = "Custom Texture ID", Placeholder = "5101923607",
        Callback = function(v) cfg.CustomID = v; updateVMMaterials() end,
    })
    ffDep:SetupDependencies({ { matDrop, "ForceField" } })
end
TeamESPSection = Tabs.Visuals:AddRightGroupbox("Team ESP")
TeamESPToggle = TeamESPSection:AddToggle("TeamESP_Enabled", {
    Text = "Enabled", Default = false,
    Callback = function(v)
        teamEspSettings.Enabled = v
        updateTeamEspLoop()
    end
})
TeamESPToggle:AddKeyPicker("TeamESPKey", {
    Default = "None",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Team ESP",
})
TeamESPDep = TeamESPSection:AddDependencyBox()
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
do
    CrosshairSection = Tabs.Visuals:AddRightGroupbox("Custom Crosshair")
    chEnabled = false
    chTextStr = "kei.win"
    chLineColor = Color3.fromRGB(255, 255, 255)
    chRainbow = true
    chStretch = true
    chSpin = true
    chGui = Instance.new("ScreenGui")
    chGui.Name = "CustomCrosshairGui"
    chGui.ResetOnSpawn = false
    chGui.IgnoreGuiInset = true
    chGui.Parent = getESPContainerParent()
    chGui.Enabled = false
    chCenter = Instance.new("Frame")
    chCenter.Name = "CenterFrame"
    chCenter.Size = UDim2.new(0, 0, 0, 0)
    chCenter.AnchorPoint = Vector2.new(0.5, 0.5)
    chCenter.Position = UDim2.new(0.5, 0, 0.5, 0)
    chCenter.BackgroundTransparency = 1
    chCenter.Parent = chGui
    local function makeCHLine(parent)
        outer = Instance.new("Frame")
        outer.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        outer.BackgroundTransparency = 0.2
        outer.BorderSizePixel = 0
        outer.Parent = parent
        inner = Instance.new("Frame")
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
    chText = Instance.new("TextLabel")
    chText.Name = "CrosshairText"
    chText.Size = UDim2.new(0, 200, 0, 20)
    chText.AnchorPoint = Vector2.new(0.5, 0)
    chText.Position = UDim2.new(0.5, 0, 0.5, 45)
    chText.BackgroundTransparency = 1
    safeSet(chText, "Text", chTextStr)
    chText.TextSize = 16
    chText.Font = Enum.Font.Arcade
    safeSet(chText, "TextColor3", Color3.fromRGB(255, 255, 255))
    chText.TextStrokeTransparency = 0
    chText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    chText.Parent = chGui
    local function chEaseOutQuad(t)
        return 1 - (1 - t) * (1 - t)
    end
    local chConn
    local function updateCrosshair(dt)
        if not chEnabled then return end
        t = tick()
        cColor = chLineColor
        if chRainbow then cColor = Color3.fromHSV((t * 0.5) % 1, 1, 1) end
        length = 28
        if chStretch then
            raw = math.sin(t * 4)
            length = 28 + chEaseOutQuad((raw + 1) / 2) * 12
        end
        safeSet(chUpO, "Size", UDim2.new(0, 4, 0, length))
        safeSet(chUpO, "Position", UDim2.new(0.5, -2, 0.5, -length - 10))
        safeSet(chUpI, "BackgroundColor3", cColor)
        safeSet(chRightO, "Size", UDim2.new(0, length, 0, 4))
        safeSet(chRightO, "Position", UDim2.new(0.5, 10, 0.5, -2))
        safeSet(chRightI, "BackgroundColor3", cColor)
        safeSet(chLeftO, "Size", UDim2.new(0, length, 0, 4))
        safeSet(chLeftO, "Position", UDim2.new(0.5, -length - 10, 0.5, -2))
        safeSet(chLeftI, "BackgroundColor3", cColor)
        safeSet(chDownO, "Size", UDim2.new(0, 4, 0, length))
        safeSet(chDownO, "Position", UDim2.new(0.5, -2, 0.5, 10))
        safeSet(chDownI, "BackgroundColor3", cColor)
        safeSet(chText, "TextColor3", cColor)
        safeSet(chText, "Text", chTextStr)
        if chSpin then
            safeSet(chCenter, "Rotation", (chCenter.Rotation + dt * 180) % 360)
        else
            safeSet(chCenter, "Rotation", 0)
        end
    end
    CrosshairToggle = CrosshairSection:AddToggle("Crosshair_Enable", {
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
    CrosshairToggle:AddKeyPicker("CrosshairKey", {
        Default = "None",
        SyncToggleState = true,
        Mode = "Toggle",
        Text = "Crosshair",
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
end
do
    BulletTracerSection = Tabs.Visuals:AddRightGroupbox("Bullet Tracer")
    getgenv()._bt = { enabled = false, width = 2, fadeTime = 4 }
    BulletTracerToggle = BulletTracerSection:AddToggle("BulletTracerToggle", {
        Text = "Enable Bullet Tracer",
        Default = false,
        Callback = function(v) getgenv()._bt.enabled = v end
    })
    BulletTracerToggle:AddKeyPicker("BulletTracerKey", {
        Default = "None",
        SyncToggleState = true,
        Mode = "Toggle",
        Text = "Bullet Tracer",
    })
    BulletTracerSection:AddSlider("BulletTracerWidth", {
        Text = "Thickness",
        Default = 2,
        Min = 0.1,
        Max = 10,
        Rounding = 1,
        Compact = false,
        Callback = function(v) getgenv()._bt.width = v end
    })
    BulletTracerSection:AddSlider("BulletTracerFade", {
        Text = "Fade Time",
        Default = 4,
        Min = 0.1,
        Max = 10,
        Rounding = 1,
        Compact = false,
        Callback = function(v) getgenv()._bt.fadeTime = v end
    })
    task.spawn(function()
        local function findModule(parent, name)
            found = parent:FindFirstChild(name, true)
            if found and found:IsA("ModuleScript") then return found end
            return nil
        end
        GunModule = nil
        while not GunModule do
            GunModule = findModule(lp:WaitForChild("PlayerScripts"), "Gun") or findModule(game:GetService("ReplicatedStorage"), "Gun")
            task.wait(1)
        end
        Gun = require(GunModule)
        TweenService = game:GetService("TweenService")
        tracerColor = Color3.fromRGB(190, 40, 255)
        tracerFadeStyle = Enum.EasingStyle.Quart
        BEAM_CONFIGS = {
            { Texture = "rbxassetid://84577820022939", Speed = 1, Length = 1, LightInf = 0 },
            { Texture = "rbxassetid://15253860988",    Speed = 1, Length = 3, LightInf = 1 },
            { Texture = "rbxassetid://18664874807",    Speed = 3, Length = 3, LightInf = 1 },
            { Texture = "rbxassetid://12251459424",    Speed = 1, Length = 1, LightInf = 1 },
        }
        activeTracers = {}
        tracerHeartbeat = nil
        local function drawTracers(self, data)
            if not (data and data.IsLocal) then return end
            local ok, muzzle = pcall(function() return self.ViewModel:GetMuzzlePosition() end)
            if not ok or typeof(muzzle) ~= "Vector3" then return end
            local cam = workspace.CurrentCamera
            if not cam then return end
            bt = getgenv()._bt
            colorSeq = ColorSequence.new(tracerColor)
            initTrans = NumberSequence.new(0.5)
            now = tick()
            for _, res in ipairs(data.RaycastResults or {}) do
                if not res or typeof(res.Position) ~= "Vector3" then continue end
                container = Instance.new("Part")
                container.Anchored = true
                container.CanCollide = false
                container.Transparency = 1
                container.CFrame = CFrame.new()
                container.Parent = cam
                a0 = Instance.new("Attachment", container)
                a0.WorldPosition = muzzle
                a1 = Instance.new("Attachment", container)
                a1.WorldPosition = res.Position
                beams = {}
                for _, cfg in ipairs(BEAM_CONFIGS) do
                    b = Instance.new("Beam")
                    b.Attachment0 = a0; b.Attachment1 = a1
                    b.Texture = cfg.Texture; b.TextureSpeed = cfg.Speed; b.TextureLength = cfg.Length
                    b.Color = colorSeq; b.LightEmission = 1; b.LightInfluence = cfg.LightInf
                    b.Brightness = 1; b.Width0 = bt.width; b.Width1 = bt.width
                    b.FaceCamera = true; b.Transparency = initTrans
                    b.Parent = container
                    table.insert(beams, b)
                end
                table.insert(activeTracers, {
                    beams = beams,
                    container = container,
                    startTime = now,
                    fadeTime = bt.fadeTime,
                    width = bt.width
                })
            end
            if not tracerHeartbeat then
                tracerHeartbeat = game:GetService("RunService").Heartbeat:Connect(function()
                    t = tick()
                    for i = #activeTracers, 1, -1 do
                        tracer = activeTracers[i]
                        elapsed = t - tracer.startTime
                        if elapsed >= tracer.fadeTime then
                            if tracer.container and tracer.container.Parent then
                                tracer.container:Destroy()
                            end
                            table.remove(activeTracers, i)
                        else
                            pct = elapsed / tracer.fadeTime
                            pct = 1 - (1 - pct) * (1 - pct) -- EaseOutQuad
                            seq = NumberSequence.new(math.clamp(0.5 + 0.5 * pct, 0, 1))
                            w = tracer.width * (1 - pct)
                            for _, bm in ipairs(tracer.beams) do
                                if bm.Parent then bm.Transparency = seq; bm.Width0 = w; bm.Width1 = w end
                            end
                        end
                    end
                    if #activeTracers == 0 then
                        tracerHeartbeat:Disconnect()
                        tracerHeartbeat = nil
                    end
                end)
            end
        end
        if not getgenv()._bulletTracerHooked_Rich then
            oldTracers = Gun._Tracers
            Gun._Tracers = function(self, data, p2, p3)
                if getgenv()._bt.enabled then drawTracers(self, data) end
                return oldTracers(self, data, p2, p3)
            end
            getgenv()._bulletTracerHooked_Rich = true
        end
    end)
end
do
    EffectsSection = Tabs.Visuals:AddLeftGroupbox("Effects")
    antiSmokeEnabled = false
    task.spawn(function()
        pcall(function()
            FighterControllerModule = lp:WaitForChild("PlayerScripts"):WaitForChild("Controllers"):WaitForChild("FighterController")
            FC = require(FighterControllerModule)
            fighter = FC:GetFighter(lp)
            while not (fighter and fighter.FighterInterface and fighter.FighterInterface.SmokeScreen) do
                task.wait(0.5)
                fighter = FC:GetFighter(lp)
            end
            SmokeScreen = fighter.FighterInterface.SmokeScreen
            origUpdate = SmokeScreen.Update
            SmokeScreen.Update = function(self, ...)
                if antiSmokeEnabled then
                    self:Hide()
                    return
                end
                return origUpdate(self, ...)
            end
        end)
    end)
    noFlashEnabled = false
    task.spawn(function()
        pcall(function()
            flashbang = require(lp:WaitForChild("PlayerScripts"):WaitForChild("Modules"):WaitForChild("Items"):WaitForChild("Flashbang"))
            origReplicate = flashbang.ReplicateFromServer
            flashbang.ReplicateFromServer = function(self, effectType, ...)
                if effectType == "BlindEffect" and noFlashEnabled then
                    return
                end
                return origReplicate(self, effectType, ...)
            end
        end)
    end)
    AntiSmokeToggle = EffectsSection:AddToggle("Visuals_AntiSmoke_Enabled", {
        Text = "No Smoke",
        Default = false,
        Callback = function(v)
            antiSmokeEnabled = v
        end
    })
    AntiSmokeToggle:AddKeyPicker("AntiSmokeKey", {
        Default = "None",
        SyncToggleState = true,
        Mode = "Toggle",
        Text = "No Smoke",
    })
    NoFlashToggle = EffectsSection:AddToggle("Visuals_NoFlash_Enabled", {
        Text = "No Flash",
        Default = false,
        Callback = function(v)
            noFlashEnabled = v
        end
    })
    NoFlashToggle:AddKeyPicker("NoFlashKey", {
        Default = "None",
        SyncToggleState = true,
        Mode = "Toggle",
        Text = "No Flash",
    })
end
do
    EnvSection = Tabs.World:AddLeftGroupbox("Environment")
Lighting = game:GetService("Lighting")
origAmbient = Lighting.Ambient
origClockTime = Lighting.ClockTime
envSettings = {
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
function updateWorldColor()
    if envSettings.WorldColorEnabled then
        Lighting.Ambient = envSettings.Ambient
        Lighting.ClockTime = envSettings.ClockTime
    else
        Lighting.Ambient = origAmbient
        Lighting.ClockTime = origClockTime
    end
end
function updateCC()
    cc = Lighting:FindFirstChild("KETYCorrection")
    if not cc then
        cc = Instance.new("ColorCorrectionEffect")
        cc.Name = "KETYCorrection"
        cc.Parent = Lighting
    end
    cc.Enabled = envSettings.CCEnabled
    cc.TintColor = envSettings.CCTint
    cc.Saturation = envSettings.CCSaturation
    cc.Contrast = envSettings.CCContrast
end
local snowPart, snowEmitter, snowConn
function updateSnow()
    if envSettings.SnowEnabled then
        if not snowPart then
            snowPart = Instance.new("Part")
            snowPart.Name = "KETYSnowPart"
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
        end
        if not snowConn then
            snowConn = RunService.RenderStepped:Connect(function()
                local cam = workspace.CurrentCamera
                if cam and snowPart then
                    snowPart.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, 50, 0))
                end
            end)
        end
        snowEmitter.Enabled = true
        snowEmitter.Color = ColorSequence.new(envSettings.SnowColor)
        snowEmitter.Rate = envSettings.SnowRate
        snowEmitter.Speed = NumberRange.new(envSettings.SnowSpeed, envSettings.SnowSpeed)
    else
        if snowConn then
            snowConn:Disconnect()
            snowConn = nil
        end
        if snowEmitter then
            snowEmitter.Enabled = false
        end
    end
end
WorldColorToggle = EnvSection:AddToggle("Env_WorldColor_Enabled", {
    Text = "Enable Custom Lighting", Default = false,
    Callback = function(v) envSettings.WorldColorEnabled = v; updateWorldColor() end
})
WorldColorToggle:AddColorPicker("Env_Ambient_Color", {
    Default = envSettings.Ambient, Title = "Ambient Color",
    Callback = function(v) envSettings.Ambient = v; updateWorldColor() end
})
WorldColorToggle:AddKeyPicker("WorldColorKey", {
    Default = "None",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Custom Lighting",
})
EnvSection:AddSlider("Env_ClockTime", {
    Text = "Time of Day", Default = 2, Min = 0, Max = 24, Rounding = 1,
    Callback = function(v) envSettings.ClockTime = v; updateWorldColor() end
})
CCToggle = EnvSection:AddToggle("Env_CC_Enabled", {
    Text = "Enable Color Correction", Default = false,
    Callback = function(v) envSettings.CCEnabled = v; updateCC() end
})
CCToggle:AddColorPicker("Env_CC_Tint", {
    Default = envSettings.CCTint, Title = "Tint Color",
    Callback = function(v) envSettings.CCTint = v; updateCC() end
})
CCToggle:AddKeyPicker("CCKey", {
    Default = "None",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Color Correction",
})
EnvSection:AddSlider("Env_CC_Saturation", {
    Text = "Saturation", Default = 0.6, Min = -1, Max = 1, Rounding = 1,
    Callback = function(v) envSettings.CCSaturation = v; updateCC() end
})
EnvSection:AddSlider("Env_CC_Contrast", {
    Text = "Contrast", Default = 0.2, Min = -1, Max = 1, Rounding = 1,
    Callback = function(v) envSettings.CCContrast = v; updateCC() end
})
SnowToggle = EnvSection:AddToggle("Env_Snow_Enabled", {
    Text = "Enable Snow", Default = false,
    Callback = function(v) envSettings.SnowEnabled = v; updateSnow() end
})
SnowToggle:AddColorPicker("Env_Snow_Color", {
    Default = envSettings.SnowColor, Title = "Snow Color",
    Callback = function(v) envSettings.SnowColor = v; updateSnow() end
})
SnowToggle:AddKeyPicker("SnowKey", {
    Default = "None",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Snow Effect",
})
EnvSection:AddSlider("Env_Snow_Rate", {
    Text = "Snow Density", Default = 10000, Min = 100, Max = 50000, Rounding = 0,
    Callback = function(v) envSettings.SnowRate = v; updateSnow() end
})
EnvSection:AddSlider("Env_Snow_Speed", {
    Text = "Snow Speed", Default = 30, Min = 1, Max = 100, Rounding = 0
})
end
do
    Lighting = game:GetService("Lighting")
    LightSection = Tabs.World:AddLeftGroupbox("Lighting Control")
    FxSection = Tabs.World:AddRightGroupbox("Post Processing")
    SkySection = Tabs.World:AddRightGroupbox("Sky Changer")
    PROPS = { "Brightness", "ExposureCompensation", "OutdoorAmbient", "Ambient", "ClockTime",
        "ColorShift_Top", "ColorShift_Bottom", "EnvironmentDiffuseScale", "EnvironmentSpecularScale",
        "GlobalShadows", "ShadowSoftness", "FogColor", "FogStart", "FogEnd" }
    orig = {}
    for _, p in ipairs(PROPS) do orig[p] = Lighting[p] end
    local lightOn, skyOn = false, false
    lv = {}
    for _, p in ipairs(PROPS) do lv[p] = Lighting[p] end
    C3 = Color3.fromRGB
    PRESETS = {
        ["GraySky"] = {
            Clock = 14, Ambient = C3(135,135,135), Fog = C3(135,135,135), FogEnd = 100000, Stars = 0, Celestial = false, NoClouds = true, RemoveAtmo = true,
            Faces = {
                Bk = "rbxassetid://8833267735",
                Dn = "rbxassetid://8833267735",
                Ft = "rbxassetid://8833267735",
                Lf = "rbxassetid://8833267735",
                Rt = "rbxassetid://8833267735",
                Up = "rbxassetid://8833267735"
            },
        },
        ["Purple Nebula"] = {
            Clock = 18, Atmo = C3(150,0,255), Density = 0.3, Haze = 1, Ambient = C3(100,50,150), Fog = C3(120,40,180), FogEnd = 3000, Stars = 3000, Celestial = true, NoClouds = true,
            Faces = { Bk = "rbxassetid://6444884337", Dn = "rbxassetid://6444884784", Ft = "rbxassetid://6444884001", Lf = "rbxassetid://6444883479", Rt = "rbxassetid://6444883163", Up = "rbxassetid://6444883712" },
        },
        ["Galaxy"] = {
            Clock = 0, Atmo = C3(30,10,60), Density = 0.25, Haze = 0.5, Ambient = C3(40,20,70), Fog = C3(20,10,40), FogEnd = 4000, Stars = 5000, Celestial = true, NoClouds = true,
            Faces = { Bk = "rbxassetid://159454299", Dn = "rbxassetid://159454296", Ft = "rbxassetid://159454293", Lf = "rbxassetid://159454286", Rt = "rbxassetid://159454300", Up = "rbxassetid://159454288" },
        },
        ["Midnight"] = {
            Clock = 0, Atmo = C3(20,25,60), Density = 0.2, Haze = 0.5, Ambient = C3(25,30,70), Fog = C3(15,20,45), FogEnd = 2500, Stars = 5000, Celestial = true, NoClouds = false,
            Faces = { Bk = "rbxassetid://12064107", Dn = "rbxassetid://12064152", Ft = "rbxassetid://12064121", Lf = "rbxassetid://12064115", Rt = "rbxassetid://12064131", Up = "rbxassetid://12064147" },
        },
        ["Sunset"] = {
            Clock = 18, Atmo = C3(255,140,80), Density = 0.3, Haze = 1.5, Ambient = C3(130,80,60), Fog = C3(220,120,70), FogEnd = 2000, Stars = 0, Celestial = true, NoClouds = false,
            Faces = { Bk = "rbxassetid://600830446", Dn = "rbxassetid://600831635", Ft = "rbxassetid://600832720", Lf = "rbxassetid://600886090", Rt = "rbxassetid://600833862", Up = "rbxassetid://600835177" },
        },
        ["Blood Red"] = {
            Clock = 20, Atmo = C3(200,20,20), Density = 0.4, Haze = 2, Ambient = C3(120,20,20), Fog = C3(150,20,20), FogEnd = 1200, Stars = 0, Celestial = false, NoClouds = true,
            Faces = { Bk = "rbxassetid://733527264", Dn = "rbxassetid://733527264", Ft = "rbxassetid://733527264", Lf = "rbxassetid://733527264", Rt = "rbxassetid://733527264", Up = "rbxassetid://733527264" },
        },
        ["Toxic Green"] = {
            Clock = 12, Atmo = C3(100,230,60), Density = 0.4, Haze = 2, Ambient = C3(70,140,50), Fog = C3(80,180,50), FogEnd = 1200, Stars = 0, Celestial = false, NoClouds = true,
            Faces = { Bk = "rbxassetid://1088661278", Dn = "rbxassetid://1088661278", Ft = "rbxassetid://1088661278", Lf = "rbxassetid://1088661278", Rt = "rbxassetid://1088661278", Up = "rbxassetid://1088661278" },
        },
        ["Ocean Blue"] = {
            Clock = 13, Atmo = C3(60,160,255), Density = 0.25, Haze = 1, Ambient = C3(70,120,180), Fog = C3(100,170,240), FogEnd = 2500, Stars = 0, Celestial = true, NoClouds = false,
            Faces = { Bk = "rbxassetid://6354471929", Dn = "rbxassetid://6354471929", Ft = "rbxassetid://6354471929", Lf = "rbxassetid://6354471929", Rt = "rbxassetid://6354471929", Up = "rbxassetid://6354471929" },
        },
        ["Pink Dream"] = {
            Clock = 17, Atmo = C3(255,150,210), Density = 0.3, Haze = 1.5, Ambient = C3(180,110,160), Fog = C3(240,160,210), FogEnd = 2000, Stars = 500, Celestial = true, NoClouds = false,
            Faces = { Bk = "rbxassetid://271042516", Dn = "rbxassetid://271077243", Ft = "rbxassetid://271042556", Lf = "rbxassetid://271042310", Rt = "rbxassetid://271042467", Up = "rbxassetid://271077958" },
        },
        ["Golden Hour"] = {
            Clock = 17, Atmo = C3(255,200,100), Density = 0.3, Haze = 1.5, Ambient = C3(170,130,70), Fog = C3(240,190,110), FogEnd = 2500, Stars = 0, Celestial = true, NoClouds = false,
            Faces = { Bk = "rbxassetid://1013853", Dn = "rbxassetid://1013856", Ft = "rbxassetid://1013854", Lf = "rbxassetid://1013852", Rt = "rbxassetid://1013855", Up = "rbxassetid://1013857" },
        },
        ["Void Black"] = {
            Clock = 0, Ambient = C3(20,20,20), Fog = C3(0,0,0), FogEnd = 1500, Stars = 0, Celestial = false, NoClouds = true, RemoveAtmo = true,
            Faces = { Bk = "rbxassetid://0", Dn = "rbxassetid://0", Ft = "rbxassetid://0", Lf = "rbxassetid://0", Rt = "rbxassetid://0", Up = "rbxassetid://0" },
        },
        ["Default Roblox"] = {
            Clock = 14, Atmo = C3(199,170,107), Density = 0.3, Haze = 0, Ambient = C3(70,70,70), Fog = C3(192,192,192), FogEnd = 100000, Stars = 3000, Celestial = true, NoClouds = false,
            Faces = { Bk = "rbxasset://textures/sky/sky512_bk.tex", Dn = "rbxasset://textures/sky/sky512_dn.tex", Ft = "rbxasset://textures/sky/sky512_ft.tex",
                      Lf = "rbxasset://textures/sky/sky512_lf.tex", Rt = "rbxasset://textures/sky/sky512_rt.tex", Up = "rbxasset://textures/sky/sky512_up.tex" },
        },
    }
    PRESET_LIST = { "GraySky", "Purple Nebula", "Galaxy", "Midnight", "Sunset", "Blood Red", "Toxic Green", "Ocean Blue", "Pink Dream", "Golden Hour", "Void Black", "Default Roblox", "Custom" }
    FACES = { "Bk", "Dn", "Ft", "Lf", "Rt", "Up" }
    skyChoice = "GraySky"
    custom = { Clock = 14, Atmo = C3(150,150,200), Density = 0.3, Haze = 1, Ambient = C3(150,150,200), Fog = C3(150,150,200), FogEnd = 1000, Stars = 0, Celestial = false, AllID = "", Faces = {} }
    task.spawn(function()
        pcall(function()
            game:GetService("ContentProvider"):PreloadAsync({ "rbxassetid://8833267735", "rbxassetid://122619816920309" })
        end)
    end)
    local function setDebugSkyGray(enabled)
        pcall(function()
            fn = setfflag or set_fflag or setfastflag
            if fn then fn("FFlagDebugSkyGray", enabled and "true" or "false") end
        end)
    end
    local function normID(id)
        if not id or id == "" or id == "0" then return "" end
        n = tostring(id):gsub("%D", "")
        return #n > 0 and ("rbxassetid://" .. n) or ""
    end
    local function currentSky()
        if skyChoice ~= "Custom" then return PRESETS[skyChoice] or PRESETS["GraySky"] end
        faces = {}
        all = normID(custom.AllID)
        for _, f in ipairs(FACES) do
            own = normID(custom.Faces[f])
            faces[f] = own ~= "" and own or all
        end
        return setmetatable({ Faces = faces }, { __index = custom })
    end
    local mySky, myAtmo, cloudsWas
    hidden = {}
    local function applySkyObjects()
        if skyOn then
            cfg = currentSky()
            if skyChoice == "GraySky" then
                setDebugSkyGray(true)
            else
                setDebugSkyGray(false)
            end
            for _, c in ipairs(Lighting:GetChildren()) do
                if (c:IsA("Sky") and c ~= mySky) or (c:IsA("Atmosphere") and c ~= myAtmo) then
                    if not table.find(hidden, c) then table.insert(hidden, c) end
                    c.Parent = nil
                end
            end
            faces = cfg.Faces or {}
            needNew = false
            if not mySky or mySky.Parent ~= Lighting then
                needNew = true
            else
                for _, f in ipairs(FACES) do
                    if mySky["Skybox" .. f] ~= (faces[f] or "") then
                        needNew = true
                        break
                    end
                end
            end
            if needNew then
                if mySky then mySky:Destroy(); mySky = nil end
                mySky = Instance.new("Sky")
                mySky.Name = "KETYSky"
                for _, f in ipairs(FACES) do
                    mySky["Skybox" .. f] = faces[f] or ""
                end
                mySky.CelestialBodiesShown = cfg.Celestial or false
                mySky.StarCount = cfg.Stars or 0
                mySky.SunAngularSize = cfg.Celestial and 21 or 0
                mySky.MoonAngularSize = cfg.Celestial and 11 or 0
                mySky.SunTextureId = ""
                mySky.MoonTextureId = ""
                mySky.Parent = Lighting
            else
                mySky.CelestialBodiesShown = cfg.Celestial or false
                mySky.StarCount = cfg.Stars or 0
            end
            if cfg.RemoveAtmo then
                if myAtmo then myAtmo:Destroy(); myAtmo = nil end
            else
                if not myAtmo or myAtmo.Parent ~= Lighting then
                    myAtmo = Instance.new("Atmosphere")
                    myAtmo.Name = "KETYAtmosphere"
                    myAtmo.Parent = Lighting
                end
                if cfg.Atmo then
                    myAtmo.Color = cfg.Atmo
                    myAtmo.Decay = cfg.Atmo
                end
                myAtmo.Density = cfg.Density or 0.3
                myAtmo.Haze = cfg.Haze or 1
                myAtmo.Glare = 0
                myAtmo.Offset = cfg.Offset or 0.25
            end
            if cfg.NoClouds then
                if cloudsWas ~= true then
                    for _, clouds in ipairs(workspace:GetDescendants()) do
                        if clouds:IsA("Clouds") and clouds.Enabled then
                            clouds.Enabled = false
                        end
                    end
                    cloudsWas = true
                end
            elseif cloudsWas then
                for _, clouds in ipairs(workspace:GetDescendants()) do
                    if clouds:IsA("Clouds") then clouds.Enabled = true end
                end
                cloudsWas = false
            end
        else
            setDebugSkyGray(false)
            if cloudsWas then
                for _, clouds in ipairs(workspace:GetDescendants()) do
                    if clouds:IsA("Clouds") then clouds.Enabled = true end
                end
                cloudsWas = nil
            end
            if mySky then mySky:Destroy(); mySky = nil end
            if myAtmo then myAtmo:Destroy(); myAtmo = nil end
            for _, c in ipairs(hidden) do pcall(function() c.Parent = Lighting end) end
            hidden = {}
        end
    end
    local function desired()
        d = {}
        if skyOn then
            cfg = currentSky()
            d.ClockTime = cfg.Clock
            d.Ambient = cfg.Ambient
            d.OutdoorAmbient = cfg.Ambient
            d.FogColor = cfg.Fog
            d.FogStart = 0
            d.FogEnd = cfg.FogEnd
        end
        if lightOn then
            for k, v in pairs(lv) do d[k] = v end
        end
        return d
    end
    local worldConn
    _lastLightStep = 0
    local function step(force)
        now = tick()
        if not force and now - _lastLightStep < 0.25 then return end
        _lastLightStep = now
        d = desired()
        for _, p in ipairs(PROPS) do
            want = d[p]
            if want == nil then want = orig[p] end
            if Lighting[p] ~= want then pcall(function() Lighting[p] = want end) end
        end
        applySkyObjects()
    end
    local function refresh()
        if lightOn or skyOn then
            if not worldConn then worldConn = RunService.Heartbeat:Connect(step) end
            step(true)
        else
            if worldConn then worldConn:Disconnect(); worldConn = nil end
            step(true)
        end
    end
    LightToggle = LightSection:AddToggle("WorldLight_Enabled", {
        Text = "Enable Lighting Override", Default = false,
        Callback = function(v) lightOn = v; refresh() end
    })
    LightToggle:AddKeyPicker("WorldLightKey", { Default = "None", SyncToggleState = true, Mode = "Toggle", Text = "Lighting Override" })
    local function lslider(prop, text, min, max, rounding)
        LightSection:AddSlider("WorldLight_" .. prop, {
            Text = text, Default = math.clamp(Lighting[prop], min, max), Min = min, Max = max, Rounding = rounding,
            Callback = function(v) lv[prop] = v end
        })
    end
    lslider("Brightness", "Brightness", 0, 10, 2)
    lslider("ExposureCompensation", "Exposure", -3, 3, 2)
    lslider("EnvironmentDiffuseScale", "Env Diffuse", 0, 1, 2)
    lslider("EnvironmentSpecularScale", "Env Specular", 0, 1, 2)
    lslider("ShadowSoftness", "Shadow Softness", 0, 1, 2)
    lslider("FogStart", "Fog Start", 0, 5000, 0)
    lslider("FogEnd", "Fog End", 0, 100000, 0)
    LightSection:AddToggle("WorldLight_GlobalShadows", {
        Text = "Global Shadows", Default = Lighting.GlobalShadows,
        Callback = function(v) lv.GlobalShadows = v end
    })
    local function lcolor(prop, text)
        LightSection:AddLabel(text):AddColorPicker("WorldLightColor_" .. prop, {
            Default = Lighting[prop], Title = text,
            Callback = function(v) lv[prop] = v end
        })
    end
    lcolor("Ambient", "Ambient")
    lcolor("OutdoorAmbient", "Outdoor Ambient")
    lcolor("ColorShift_Top", "Color Shift Top")
    lcolor("ColorShift_Bottom", "Color Shift Bottom")
    lcolor("FogColor", "Fog Color")
    LightSection:AddSlider("WorldLight_ClockTime", {
        Text = "Clock Time", Default = math.clamp(Lighting.ClockTime, 0, 24), Min = 0, Max = 24, Rounding = 1,
        Callback = function(v) lv.ClockTime = v end
    })
    local function getFx(class, name)
        fx = Lighting:FindFirstChild(name)
        if not fx then
            fx = Instance.new(class)
            fx.Name = name
            fx.Enabled = false
            fx.Parent = Lighting
        end
        return fx
    end
    local function fxToggle(id, text, class, name)
        FxSection:AddToggle(id, { Text = text, Default = false,
            Callback = function(v) getFx(class, name).Enabled = v end })
    end
    local function fxSlider(id, text, class, name, prop, def, min, max, rounding)
        FxSection:AddSlider(id, { Text = text, Default = def, Min = min, Max = max, Rounding = rounding,
            Callback = function(v) getFx(class, name)[prop] = v end })
    end
    fxToggle("FX_Bloom", "Bloom", "BloomEffect", "KETYBloom")
    fxSlider("FX_BloomIntensity", "Bloom Intensity", "BloomEffect", "KETYBloom", "Intensity", 1, 0, 5, 2)
    fxSlider("FX_BloomSize", "Bloom Size", "BloomEffect", "KETYBloom", "Size", 24, 0, 56, 0)
    fxSlider("FX_BloomThreshold", "Bloom Threshold", "BloomEffect", "KETYBloom", "Threshold", 0.8, 0, 3, 2)
    fxToggle("FX_Blur", "Blur", "BlurEffect", "KETYBlur")
    fxSlider("FX_BlurSize", "Blur Size", "BlurEffect", "KETYBlur", "Size", 8, 0, 56, 0)
    fxToggle("FX_SunRays", "Sun Rays", "SunRaysEffect", "KETYSunRays")
    fxSlider("FX_SunRaysIntensity", "Sun Rays Intensity", "SunRaysEffect", "KETYSunRays", "Intensity", 0.25, 0, 1, 2)
    fxSlider("FX_SunRaysSpread", "Sun Rays Spread", "SunRaysEffect", "KETYSunRays", "Spread", 1, 0, 1, 2)
    fxToggle("FX_DOF", "Depth Of Field", "DepthOfFieldEffect", "KETYDOF")
    fxSlider("FX_DOFFar", "DOF Far Intensity", "DepthOfFieldEffect", "KETYDOF", "FarIntensity", 0.75, 0, 1, 2)
    fxSlider("FX_DOFFocus", "DOF Focus Distance", "DepthOfFieldEffect", "KETYDOF", "FocusDistance", 50, 0, 500, 0)
    fxSlider("FX_DOFRadius", "DOF In Focus Radius", "DepthOfFieldEffect", "KETYDOF", "InFocusRadius", 30, 0, 200, 0)
    SkyToggle = SkySection:AddToggle("SkyChanger_Enabled", {
        Text = "Enable Sky Changer", Default = false,
        Callback = function(v) skyOn = v; refresh() end
    })
    SkyToggle:AddKeyPicker("SkyChangerKey", { Default = "None", SyncToggleState = true, Mode = "Toggle", Text = "Sky Changer" })
    SkyDrop = SkySection:AddDropdown("SkyChanger_Preset", {
        Values = PRESET_LIST, Default = 1, Multi = false, Text = "Sky Preset",
        Callback = function(v)
            skyChoice = v
            if skyOn then step() end
        end
    })
    CustomDep = SkySection:AddDependencyBox()
    CustomDep:AddLabel("Atmosphere Color"):AddColorPicker("SkyCustom_Atmo", { Default = custom.Atmo, Title = "Atmosphere",
        Callback = function(v) custom.Atmo = v; if skyOn and skyChoice == "Custom" then step() end end })
    CustomDep:AddLabel("Ambient / Fog Color"):AddColorPicker("SkyCustom_Fog", { Default = custom.Fog, Title = "Ambient / Fog",
        Callback = function(v) custom.Fog = v; custom.Ambient = v; if skyOn and skyChoice == "Custom" then step() end end })
    CustomDep:AddSlider("SkyCustom_Clock", { Text = "Clock Time", Default = 14, Min = 0, Max = 24, Rounding = 1,
        Callback = function(v) custom.Clock = v; if skyOn and skyChoice == "Custom" then step() end end })
    CustomDep:AddSlider("SkyCustom_Density", { Text = "Atmosphere Density", Default = 0.3, Min = 0, Max = 1, Rounding = 2,
        Callback = function(v) custom.Density = v; if skyOn and skyChoice == "Custom" then step() end end })
    CustomDep:AddSlider("SkyCustom_Haze", { Text = "Atmosphere Haze", Default = 1, Min = 0, Max = 10, Rounding = 1,
        Callback = function(v) custom.Haze = v; if skyOn and skyChoice == "Custom" then step() end end })
    CustomDep:AddSlider("SkyCustom_FogEnd", { Text = "Fog End", Default = 1000, Min = 50, Max = 100000, Rounding = 0,
        Callback = function(v) custom.FogEnd = v; if skyOn and skyChoice == "Custom" then step() end end })
    CustomDep:AddSlider("SkyCustom_Stars", { Text = "Star Count", Default = 0, Min = 0, Max = 5000, Rounding = 0,
        Callback = function(v) custom.Stars = v; if skyOn and skyChoice == "Custom" then step() end end })
    CustomDep:AddToggle("SkyCustom_Celestial", { Text = "Sun / Moon", Default = false,
        Callback = function(v) custom.Celestial = v; if skyOn and skyChoice == "Custom" then step() end end })
    CustomDep:AddInput("SkyCustom_AllID", { Default = "", Text = "Skybox ID (All Faces)", Placeholder = "5101923607",
        Callback = function(v) custom.AllID = v; if skyOn and skyChoice == "Custom" then step() end end })
    for _, f in ipairs(FACES) do
        CustomDep:AddInput("SkyCustom_Face" .. f, { Default = "", Text = "Face " .. f .. " ID", Placeholder = "optional",
            Callback = function(v) custom.Faces[f] = v; if skyOn and skyChoice == "Custom" then step() end end })
    end
    CustomDep:SetupDependencies({ { SkyDrop, "Custom" } })
end
do
    RageBotSection = Tabs.Rage:AddRightGroupbox("RageBot")
    getgenv().Config = getgenv().Config or {
        Enabled = false,
        AutoAttack = true,
        ShowAttackButton = true,
        WeaponSlot = "Primary",
        TargetPart = "HitboxHead",
        TargetSort = "Distance (Closest)",
        TeamCheck = true,
        FireRate = 0.0005,
        AntiHit = false,
        AntiHitDuration = 0.5,
        TPOffsets = {
            Primary   = { X = 0, Y = 5, Z = 0 },
            Secondary = { X = 0, Y = 5, Z = 0 },
            Melee     = { X = 0, Y = 5, Z = 0 },
            Knife     = { X = 0, Y = -5, Z = 1 },
        },
    }
    if getgenv().Config.AutoAttack == nil then getgenv().Config.AutoAttack = true end
    if getgenv().Config.ShowAttackButton == nil then getgenv().Config.ShowAttackButton = true end
    getgenv().Config.TargetPart = getgenv().Config.TargetPart or "HitboxHead"
    getgenv().Config.TargetSort = getgenv().Config.TargetSort or "Distance (Closest)"
    if getgenv().Config.TeamCheck == nil then getgenv().Config.TeamCheck = true end
    getgenv().Config.AntiHit = false
    getgenv().Config.TPOffsets = getgenv().Config.TPOffsets or {
        Primary   = { X = 0, Y = 5, Z = 0 },
        Secondary = { X = 0, Y = 5, Z = 0 },
        Melee     = { X = 0, Y = 5, Z = 0 },
        Knife     = { X = 0, Y = -5, Z = 1 },
    }
    getgenv().Config.TPOffsets.Primary = getgenv().Config.TPOffsets.Primary or { X = 0, Y = 5, Z = 0 }
    getgenv().Config.TPOffsets.Secondary = getgenv().Config.TPOffsets.Secondary or { X = 0, Y = 5, Z = 0 }
    getgenv().Config.TPOffsets.Melee = getgenv().Config.TPOffsets.Melee or { X = 0, Y = 5, Z = 0 }
    getgenv().Config.TPOffsets.Knife = getgenv().Config.TPOffsets.Knife or { X = 0, Y = -5, Z = 1 }
    getgenv().RageBotConfig = getgenv().Config
    getgenv().RageBotConfig.AntiHit = false
    currentTargetPart = nil
    currentDesyncCF = nil
    currentTargetYaw = nil
    if getgenv()._KETY_RageAttackButton then
        pcall(function() getgenv()._KETY_RageAttackButton:Destroy() end)
        getgenv()._KETY_RageAttackButton = nil
    end
    getgenv()._RageAttackHeld = false
    targetGui = screenGui or getgenv().MyKETYESP
    attackBtnContainer = Instance.new("Frame")
    attackBtnContainer.Name = "KETY_RageAttackContainer"
    attackBtnContainer.Size = UDim2.new(0, 80, 0, 80)
    attackBtnContainer.Position = UDim2.new(1, -100, 0.65, -40)
    attackBtnContainer.BackgroundTransparency = 1
    attackBtnContainer.Active = true
    attackBtnContainer.ZIndex = 50
    attackBtnContainer.Visible = (getgenv().Config.ShowAttackButton ~= false)
    if targetGui then
        attackBtnContainer.Parent = targetGui
    end
    getgenv()._KETY_RageAttackButton = attackBtnContainer
    attackBtn = Instance.new("TextButton")
    attackBtn.Name = "AttackButton"
    attackBtn.Size = UDim2.new(1, 0, 1, 0)
    attackBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
    attackBtn.BackgroundTransparency = 0.15
    attackBtn.Text = ""
    attackBtn.AutoButtonColor = false
    attackBtn.ZIndex = 51
    attackBtn.Parent = attackBtnContainer
    attackCorner = Instance.new("UICorner")
    attackCorner.CornerRadius = UDim.new(0, 20)
    attackCorner.Parent = attackBtn
    attackStroke = Instance.new("UIStroke")
    attackStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    attackStroke.Color = Color3.fromRGB(255, 60, 60)
    attackStroke.Thickness = 2
    attackStroke.Transparency = 0.2
    attackStroke.Parent = attackBtn
    attackTitle = Instance.new("TextLabel")
    attackTitle.Name = "Title"
    attackTitle.Size = UDim2.new(1, 0, 0, 24)
    attackTitle.Position = UDim2.new(0, 0, 0, 14)
    attackTitle.BackgroundTransparency = 1
    attackTitle.Text = "ATTACK"
    attackTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    attackTitle.Font = Enum.Font.GothamBold
    attackTitle.TextSize = 13
    attackTitle.ZIndex = 52
    attackTitle.Parent = attackBtn
    attackSub = Instance.new("TextLabel")
    attackSub.Name = "SubText"
    attackSub.Size = UDim2.new(1, 0, 0, 18)
    attackSub.Position = UDim2.new(0, 0, 0, 40)
    attackSub.BackgroundTransparency = 1
    attackSub.Text = "AUTO"
    attackSub.TextColor3 = Color3.fromRGB(80, 255, 120)
    attackSub.Font = Enum.Font.GothamMedium
    attackSub.TextSize = 10
    attackSub.ZIndex = 52
    attackSub.Parent = attackBtn
    local function updateAttackBtnVisual()
        auto = (getgenv().Config and getgenv().Config.AutoAttack ~= false)
        isHeld = (getgenv()._RageAttackHeld == true)
        if isHeld then
            attackBtn.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
            attackStroke.Color = Color3.fromRGB(255, 90, 90)
            attackStroke.Thickness = 3
            attackTitle.Text = "FIRE"
            attackTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
            attackSub.Text = "FIRING"
            attackSub.TextColor3 = Color3.fromRGB(255, 220, 220)
        elseif auto then
            attackBtn.BackgroundColor3 = Color3.fromRGB(22, 26, 24)
            attackStroke.Color = Color3.fromRGB(60, 220, 120)
            attackStroke.Thickness = 2
            attackTitle.Text = "ATTACK"
            attackTitle.TextColor3 = Color3.fromRGB(240, 240, 240)
            attackSub.Text = "[AUTO]"
            attackSub.TextColor3 = Color3.fromRGB(80, 255, 120)
        else
            attackBtn.BackgroundColor3 = Color3.fromRGB(28, 22, 22)
            attackStroke.Color = Color3.fromRGB(255, 70, 70)
            attackStroke.Thickness = 2
            attackTitle.Text = "ATTACK"
            attackTitle.TextColor3 = Color3.fromRGB(240, 240, 240)
            attackSub.Text = "[HOLD]"
            attackSub.TextColor3 = Color3.fromRGB(255, 110, 110)
        end
    end
    updateAttackBtnVisual()
    isDragging = false
    dragInput = nil
    dragStart = nil
    startPos = nil
    local function updateDrag(input)
        delta = input.Position - dragStart
        attackBtnContainer.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
    attackBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            getgenv()._RageAttackHeld = true
            updateAttackBtnVisual()
            isDragging = false
            dragStart = input.Position
            startPos = attackBtnContainer.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    isDragging = false
                    getgenv()._RageAttackHeld = false
                    updateAttackBtnVisual()
                end
            end)
        end
    end)
    attackBtn.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService = game:GetService("UserInputService")
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragStart and startPos then
            delta = input.Position - dragStart
            if delta.Magnitude > 6 then
                isDragging = true
            end
            if isDragging then
                updateDrag(input)
            end
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragStart = nil
            isDragging = false
            getgenv()._RageAttackHeld = false
            updateAttackBtnVisual()
        end
    end)
    RageBotToggle = RageBotSection:AddToggle("RageBot_Enabled", {
        Text = "Enable RageBot",
        Default = false,
        Callback = function(value)
            getgenv().Config.Enabled = value
            getgenv().RageBotConfig.Enabled = value
            if getgenv()._updateRagebotConnections then
                getgenv()._updateRagebotConnections()
            end
        end
    })
    RageBotToggle:AddKeyPicker("RageBotKey", {
        Default = "None",
        SyncToggleState = true,
        Mode = "Toggle",
        Text = "RageBot",
    })
    RageBotAutoAttackToggle = RageBotSection:AddToggle("RageBot_AutoAttack", {
        Text = "Auto Attack",
        Default = true,
        Callback = function(value)
            getgenv().Config.AutoAttack = value
            if getgenv().RageBotConfig then getgenv().RageBotConfig.AutoAttack = value end
            updateAttackBtnVisual()
        end
    })
    RageBotAutoAttackToggle:AddKeyPicker("RageBotAutoAttackKey", {
        Default = "None",
        SyncToggleState = true,
        Mode = "Toggle",
        Text = "Auto Attack",
    })
    RageBotShowBtnToggle = RageBotSection:AddToggle("RageBot_ShowButton", {
        Text = "Screen Attack Button",
        Default = true,
        Callback = function(value)
            getgenv().Config.ShowAttackButton = value
            if getgenv().RageBotConfig then getgenv().RageBotConfig.ShowAttackButton = value end
            if attackBtnContainer then
                attackBtnContainer.Visible = (value == true)
            end
        end
    })
    RageBotTeamCheckToggle = RageBotSection:AddToggle("RageBot_TeamCheck", {
        Text = "FFA",
        Default = false,
        Callback = function(value)
            getgenv().Config.TeamCheck = not value
            if getgenv().RageBotConfig then getgenv().RageBotConfig.TeamCheck = not value end
        end
    })
    WeaponSlotDropdown = RageBotSection:AddDropdown("RageBot_Slot", {
        Values = {"Primary", "Secondary", "Melee", "Knife"},
        Default = 1,
        Multi = false,
        Text = "Weapon Slot",
        Callback = function(value)
            getgenv().Config.WeaponSlot = value
            getgenv().RageBotConfig.WeaponSlot = value
            FighterController = nil
            pcall(function()
                FighterController = require(lp.PlayerScripts:WaitForChild("Controllers"):WaitForChild("FighterController"))
            end)
            localFighter = FighterController and FighterController.LocalFighter
            if localFighter then
                pcall(function()
                    slots = { Primary = 1, Secondary = 2, Melee = 3, Knife = 3 }
                    localFighter:EquipItem(slots[value] or 3)
                end)
            end
        end
    })
    RageBotTargetPartDropdown = RageBotSection:AddDropdown("RageBot_TargetPart", {
        Values = {
            "HitboxHead", "HitboxBody", "Head", "UpperTorso", "LowerTorso",
            "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg", "Random"
        },
        Default = 1,
        Multi = false,
        Text = "Target Part",
        Callback = function(value)
            getgenv().Config.TargetPart = value
            if getgenv().RageBotConfig then getgenv().RageBotConfig.TargetPart = value end
        end
    })
    RageBotTargetSortDropdown = RageBotSection:AddDropdown("RageBot_TargetSort", {
        Values = {
            "Distance (Closest)", "Distance (Farthest)",
            "Health (Lowest)", "Health (Highest)",
            "Mouse (Closest)", "Mouse (Farthest)"
        },
        Default = 1,
        Multi = false,
        Text = "Target Sort",
        Callback = function(value)
            getgenv().Config.TargetSort = value
            if getgenv().RageBotConfig then getgenv().RageBotConfig.TargetSort = value end
        end
    })
    PrimaryTPDep = RageBotSection:AddDependencyBox()
    PrimaryTPDep:AddSlider("RageBot_Primary_TP_X", {
        Text = "Primary TP Offset X",
        Default = 0,
        Min = -10,
        Max = 10,
        Rounding = 1,
        Callback = function(value)
            getgenv().Config.TPOffsets.Primary.X = value
        end
    })
    PrimaryTPDep:AddSlider("RageBot_Primary_TP_Y", {
        Text = "Primary TP Offset Y",
        Default = 5,
        Min = -10,
        Max = 10,
        Rounding = 1,
        Callback = function(value)
            getgenv().Config.TPOffsets.Primary.Y = value
        end
    })
    PrimaryTPDep:AddSlider("RageBot_Primary_TP_Z", {
        Text = "Primary TP Offset Z",
        Default = 0,
        Min = -10,
        Max = 10,
        Rounding = 1,
        Callback = function(value)
            getgenv().Config.TPOffsets.Primary.Z = value
        end
    })
    PrimaryTPDep:SetupDependencies({ { WeaponSlotDropdown, "Primary" } })
    SecondaryTPDep = RageBotSection:AddDependencyBox()
    SecondaryTPDep:AddSlider("RageBot_Secondary_TP_X", {
        Text = "Secondary TP Offset X",
        Default = 0,
        Min = -10,
        Max = 10,
        Rounding = 1,
        Callback = function(value)
            getgenv().Config.TPOffsets.Secondary.X = value
        end
    })
    SecondaryTPDep:AddSlider("RageBot_Secondary_TP_Y", {
        Text = "Secondary TP Offset Y",
        Default = 5,
        Min = -10,
        Max = 10,
        Rounding = 1,
        Callback = function(value)
            getgenv().Config.TPOffsets.Secondary.Y = value
        end
    })
    SecondaryTPDep:AddSlider("RageBot_Secondary_TP_Z", {
        Text = "Secondary TP Offset Z",
        Default = 0,
        Min = -10,
        Max = 10,
        Rounding = 1,
        Callback = function(value)
            getgenv().Config.TPOffsets.Secondary.Z = value
        end
    })
    SecondaryTPDep:SetupDependencies({ { WeaponSlotDropdown, "Secondary" } })
    MeleeTPDep = RageBotSection:AddDependencyBox()
    MeleeTPDep:AddSlider("RageBot_Melee_TP_X", {
        Text = "Melee TP Offset X",
        Default = 0,
        Min = -10,
        Max = 10,
        Rounding = 1,
        Callback = function(value)
            getgenv().Config.TPOffsets.Melee.X = value
        end
    })
    MeleeTPDep:AddSlider("RageBot_Melee_TP_Y", {
        Text = "Melee TP Offset Y",
        Default = 5,
        Min = -10,
        Max = 10,
        Rounding = 1,
        Callback = function(value)
            getgenv().Config.TPOffsets.Melee.Y = value
        end
    })
    MeleeTPDep:AddSlider("RageBot_Melee_TP_Z", {
        Text = "Melee TP Offset Z",
        Default = 0,
        Min = -10,
        Max = 10,
        Rounding = 1,
        Callback = function(value)
            getgenv().Config.TPOffsets.Melee.Z = value
        end
    })
    MeleeTPDep:SetupDependencies({ { WeaponSlotDropdown, "Melee" } })
    KnifeTPDep = RageBotSection:AddDependencyBox()
    KnifeTPDep:AddSlider("RageBot_Knife_TP_X", {
        Text = "Knife TP Offset X",
        Default = 0,
        Min = -10,
        Max = 10,
        Rounding = 1,
        Callback = function(value)
            getgenv().Config.TPOffsets.Knife.X = value
        end
    })
    KnifeTPDep:AddSlider("RageBot_Knife_TP_Y", {
        Text = "Knife TP Offset Y",
        Default = -5,
        Min = -10,
        Max = 10,
        Rounding = 1,
        Callback = function(value)
            getgenv().Config.TPOffsets.Knife.Y = value
        end
    })
    KnifeTPDep:AddSlider("RageBot_Knife_TP_Z", {
        Text = "Knife TP Offset Z",
        Default = 1,
        Min = -10,
        Max = 10,
        Rounding = 1,
        Callback = function(value)
            getgenv().Config.TPOffsets.Knife.Z = value
        end
    })
    KnifeTPDep:SetupDependencies({ { WeaponSlotDropdown, "Knife" } })
    AntiHitToggle = RageBotSection:AddToggle("RageBot_AntiHit", {
        Text = "AntiHit",
        Default = false,
        Callback = function(value)
            getgenv().Config.AntiHit = value
            getgenv().RageBotConfig.AntiHit = value
        end
    })
    AntiHitToggle:AddKeyPicker("AntiHitKey", {
        Default = "None",
        SyncToggleState = true,
        Mode = "Toggle",
        Text = "AntiHit",
    })
    AntiHitDep = RageBotSection:AddDependencyBox()
    AntiHitDep:AddSlider("RageBot_AntiHitDuration", {
        Text = "AntiHit Duration (sec)",
        Default = 0.5,
        Min = 0.25,
        Max = 2.0,
        Rounding = 2,
        Callback = function(value)
            getgenv().Config.AntiHitDuration = value
            getgenv().RageBotConfig.AntiHitDuration = value
        end
    })
    AntiHitDep:SetupDependencies({ { AntiHitToggle, true } })
    task.spawn(function()
        repS = cloneref(game:GetService("ReplicatedStorage"))
        plrs = cloneref(game:GetService("Players"))
        runS = cloneref(game:GetService("RunService"))
        ws = cloneref(game:GetService("Workspace"))
        uis = cloneref(game:GetService("UserInputService"))
        lplr = plrs.LocalPlayer
        util = nil
        enum = nil
        pcall(function() util = require(repS.Modules.Utility) end)
        pcall(function() enum = require(repS.Modules.EnumLibrary) end)
        FighterController = nil
        SpectateController = nil
        MechanicsController = nil
        KnifeModule = nil
        task.spawn(function()
            pcall(function()
                ps = lplr:WaitForChild("PlayerScripts", 5)
                if ps then
                    controllers = ps:WaitForChild("Controllers", 5)
                    if controllers then
                        fc = controllers:WaitForChild("FighterController", 5)
                        if fc then FighterController = require(fc) end
                        sc = controllers:WaitForChild("SpectateController", 5)
                        if sc then SpectateController = require(sc) end
                        mc = controllers:WaitForChild("MechanicsController", 5)
                        if mc then MechanicsController = require(mc) end
                    end
                    modules = ps:WaitForChild("Modules", 5)
                    items = modules and modules:WaitForChild("Items", 5)
                    km = items and items:WaitForChild("Knife", 5)
                    if km then KnifeModule = require(km) end
                end
            end)
        end)
        slots = {
            Primary = 1,
            Secondary = 2,
            Melee = 3,
            Knife = 3
        }
        local function getSlotNumber()
            return slots[getgenv().Config.WeaponSlot] or 3
        end
        camRemote = nil
        task.spawn(function()
            pcall(function()
                remotes = repS:WaitForChild("Remotes", 5)
                replication = remotes and remotes:WaitForChild("Replication", 5)
                fighter = replication and replication:WaitForChild("Fighter", 5)
                camRemote = fighter and fighter:WaitForChild("UpdateCameraRotation", 5)
            end)
        end)
        if util and not getgenv()._ragebotUtilHooked then
            getgenv()._ragebotUtilHooked = true
            oldEncode = util.EncodeCameraRotation
            util.EncodeCameraRotation = function(self, rot)
                if getgenv().Config and getgenv().Config.Enabled and getgenv().Config.WeaponSlot == "Knife" and currentTargetYaw and typeof(rot) == "Vector2" then
                    rot = Vector2.new(0, currentTargetYaw)
                end
                return oldEncode(self, rot)
            end
        end
        if not getgenv()._ragebotCamHooked then
            getgenv()._ragebotCamHooked = true
            table.insert(getgenv().MasterHooks, function(isCaller, self, method, ...)
                if not isCaller and method == "FireServer" and (self.Name == "UpdateCameraRotation" or (camRemote and self == camRemote)) then
                    if currentTargetYaw and getgenv().Config and getgenv().Config.Enabled and getgenv().Config.WeaponSlot == "Knife" then
                        encoded = util and util:EncodeCameraRotation(Vector2.new(0, currentTargetYaw))
                        if encoded then
                            return true, getgenv()._masterOldNC(self, encoded, nil)
                        end
                    end
                end
                return false, nil
            end)
        end
        shot_offset_cf = nil
        if util then
            pcall(function()
                shot_offset_cf = util:EncodeCFrame(CFrame.new(0.43, 0.25, 0.42))
            end)
        end
        local function BuildShotPayload(origin, target, part)
            aim_cf = util:EncodeCFrame(CFrame.new(origin, target))
            return {
                [utf8.char(0)] = aim_cf,
                [utf8.char(1)] = aim_cf,
                [utf8.char(2)] = part,
                [utf8.char(3)] = shot_offset_cf,
            }
        end
        if KnifeModule and not getgenv().KnifeHooked_RageBot then
            getgenv().KnifeHooked_RageBot = true
            old_knife = KnifeModule.StartAiming
            KnifeModule.StartAiming = function(self, ...)
                if getgenv().Config.WeaponSlot == "Knife" and currentTargetPart and currentDesyncCF then
                    results = {old_knife(self, ...)}
                    if results[1] == true and results[2] == "StartAiming" then
                        results[3] = BuildShotPayload(currentDesyncCF.Position, currentTargetPart.Position, currentTargetPart)
                        return unpack(results)
                    end
                    return unpack(results)
                end
                return old_knife(self, ...)
            end
        end
        task.spawn(function()
            while true do
                task.wait(1)
                if not getgenv().Config.Enabled then continue end
                localFighter = FighterController and FighterController.LocalFighter
                if localFighter then
                    pcall(function()
                        localFighter:EquipItem(getSlotNumber())
                    end)
                end
            end
        end)
        lastFire = 0
        lastTarget = nil
        tpStartTime = 0
        antiHitStart = 0
        antiHitUntil = 0
        DeflectingPlayers = getgenv().DeflectingPlayers or {}
        local function isPlayerParrying(player)
            if not player then return false end
            endTime = DeflectingPlayers[player]
            return endTime and tick() < endTime
        end
        RB_enemyCache = {}
        RB_enemyCacheTime = 0
        local function isEnemy(player)
            if player == lplr then return false end
            tc = getgenv().Config and getgenv().Config.TeamCheck
            if tc == false then return true end
            
            now = tick()
            if now - RB_enemyCacheTime > 0.5 then
                RB_enemyCacheTime = now
                table.clear(RB_enemyCache)
            end
            if RB_enemyCache[player] ~= nil then return RB_enemyCache[player] end

            isEn = true
            duel = SpectateController and SpectateController.CurrentDuelSubject
            localDueler = duel and duel:GetDueler(lplr)
            localTeam = localDueler and localDueler:Get("TeamID") or nil
            if localTeam and duel and duel.Duelers then
                for _, dueler in duel.Duelers do
                    if dueler.Player == player then
                        isEn = (localTeam == nil or dueler:Get("TeamID") ~= localTeam)
                        RB_enemyCache[player] = isEn
                        return isEn
                    end
                end
            end
            pTeam = player:GetAttribute("TeamID")
            lTeam = lplr:GetAttribute("TeamID")
            if pTeam and lTeam then
                isEn = (pTeam ~= lTeam)
            end
            RB_enemyCache[player] = isEn
            return isEn
        end
        local function resolveRageTargetPart(pChar)
            if not pChar then return nil end
            mode = getgenv().Config and getgenv().Config.TargetPart or "HitboxHead"
            if mode == "Random" then
                candidateNames = {
                    "HitboxHead", "HitboxBody", "Head", "UpperTorso", "LowerTorso",
                    "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg"
                }
                valid = {}
                for _, name in ipairs(candidateNames) do
                    part = pChar:FindFirstChild(name)
                    if part then table.insert(valid, part) end
                end
                if #valid > 0 then
                    return valid[math.random(1, #valid)]
                end
                return pChar:FindFirstChild("HitboxHead") or pChar:FindFirstChild("Head") or pChar:FindFirstChild("HumanoidRootPart")
            end
            return pChar:FindFirstChild(mode)
                or pChar:FindFirstChild("HitboxHead")
                or pChar:FindFirstChild("Head")
                or pChar:FindFirstChild("HumanoidRootPart")
        end
        local function getClosestTarget()
            char = lplr.Character
            if not char then return nil, nil, nil end
            myRoot = char:FindFirstChild("HumanoidRootPart")
            if not myRoot then return nil, nil, nil end
            mousePos = Vector2_new(0, 0)
            uis = game:GetService("UserInputService")
            if uis and uis.GetMouseLocation then
                mousePos = uis:GetMouseLocation()
            end
            curCam = ws.CurrentCamera
            tc = getgenv().Config and getgenv().Config.TeamCheck
            sortMethod = getgenv().Config and getgenv().Config.TargetSort or "Distance (Closest)"
            local bestPlayer, bestRoot, bestPart = nil, nil, nil
            bestScore = nil
            for _, player in plrs:GetPlayers() do
                if not isEnemy(player) then continue end
                pChar = player.Character
                if not pChar then continue end
                pRoot = pChar:FindFirstChild("HumanoidRootPart")
                pHum = pChar:FindFirstChildWhichIsA("Humanoid")
                if not (pRoot and pHum and pHum.Health > 0) then continue end
                if tc == false and FighterController and type(FighterController.GetFighter) == "function" then
                    fighter = FighterController:GetFighter(player)
                    if fighter and fighter.Entity and fighter.Entity:Get("IsInvincible") == true then
                        continue
                    end
                end
                pTargetPart = resolveRageTargetPart(pChar)
                if not pTargetPart then continue end
                dist = (myRoot.Position - pRoot.Position).Magnitude
                mouseDist = 999999
                if sortMethod == "Mouse (Closest)" or sortMethod == "Mouse (Farthest)" then
                    if curCam then
                        local pScr, pOn = curCam:WorldToViewportPoint(pTargetPart.Position)
                        if pOn and pScr.Z > 0 then
                            mouseDist = (Vector2.new(pScr.X, pScr.Y) - mousePos).Magnitude
                        else
                            mouseDist = (Vector2.new(pScr.X, pScr.Y) - mousePos).Magnitude + 2000
                        end
                    end
                end
                local score
                if sortMethod == "Distance (Closest)" then
                    score = dist
                elseif sortMethod == "Distance (Farthest)" then
                    score = -dist
                elseif sortMethod == "Health (Lowest)" then
                    score = pHum.Health
                elseif sortMethod == "Health (Highest)" then
                    score = -pHum.Health
                elseif sortMethod == "Mouse (Closest)" then
                    score = mouseDist
                elseif sortMethod == "Mouse (Farthest)" then
                    score = -mouseDist
                else
                    score = dist
                end
                if bestScore == nil or score < bestScore then
                    bestScore = score
                    bestPlayer = player
                    bestRoot = pRoot
                    bestPart = pTargetPart
                end
            end
            return bestPlayer, bestRoot, bestPart
        end
        _restoreRoot = nil
        _restoreCF = nil
        _restoreVel = nil
        _restoreRotVel = nil
        _hasRestore = false
        _rbHeartbeatConn = nil
        _rbRestoreBound = false

        local function restoreCallback()
            if _hasRestore and _restoreRoot then
                _restoreRoot.CFrame = _restoreCF
                _restoreRoot.Velocity = _restoreVel
                _restoreRoot.RotVelocity = _restoreRotVel
                _hasRestore = false
            end
        end

        local function heartbeatCallback()
            if not getgenv().Config.Enabled then
                if _rbHeartbeatConn then _rbHeartbeatConn:Disconnect(); _rbHeartbeatConn = nil end
                if _rbRestoreBound then
                    pcall(function() runS:UnbindFromRenderStep("__restore") end)
                    _rbRestoreBound = false
                end
                return
            end
            myRoot = lplr.Character and lplr.Character:FindFirstChild("HumanoidRootPart")
            if not myRoot then return end
            tc = getgenv().Config and getgenv().Config.TeamCheck
            if tc ~= false then
                myTeam = lplr:GetAttribute("TeamID")
                if not myTeam and SpectateController then
                    duel = SpectateController.CurrentDuelSubject
                    localDueler = duel and duel:GetDueler(lplr)
                    myTeam = localDueler and localDueler:Get("TeamID") or nil
                end
                if not myTeam then
                    currentTargetYaw = nil
                    return
                end
            end
            item = nil
            isReloading = false
            if FighterController and FighterController.LocalFighter then
                item = FighterController.LocalFighter.EquippedItem
                if item then
                    ammo = type(item.Get) == "function" and item:Get("Ammo") or 0
                    reloadCD = item._reload_cooldown or 0
                    isMeleeOrKnife = (getgenv().Config.WeaponSlot == "Melee" or getgenv().Config.WeaponSlot == "Knife")
                    if not isMeleeOrKnife then
                        isReloading = (tick() < reloadCD)
                            or (type(ammo) == "number" and ammo <= 0)
                    end
                end
            end
            local targetPlayer, targetRoot, targetPart = getClosestTarget()
            myFF = false
            targetFF = false
            lf = FighterController and FighterController.LocalFighter
            if lf and lf.Entity and type(lf.Entity.Get) == "function" then
                myFF = lf.Entity:Get("IsInvincible") == true
            end
            if targetPlayer and FighterController and type(FighterController.GetFighter) == "function" then
                fighter = FighterController:GetFighter(targetPlayer)
                if fighter and fighter.Entity and type(fighter.Entity.Get) == "function" then
                    targetFF = fighter.Entity:Get("IsInvincible") == true
                end
            end
            now = tick()
            isEscaping = getgenv().Config and getgenv().Config.AntiHit and (now >= antiHitStart and now < antiHitUntil)
            isAntiHitDelay = getgenv().Config and getgenv().Config.AntiHit and (now < antiHitStart)
            autoAttack = (getgenv().Config and getgenv().Config.AutoAttack ~= false)
            isManualClick = false
            pcall(function()
                if uis then
                    isManualClick = uis:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                end
            end)
            isAttackButtonHeld = (getgenv()._RageAttackHeld == true)
            canAttack = autoAttack or isAttackButtonHeld or isManualClick
            canTarget = getgenv().Config.Enabled
                and canAttack
                and (not isEscaping)
                and (not isReloading)
                and (not myFF)
                and (tc == false or not targetFF)
                and targetPlayer ~= nil
                and targetRoot ~= nil
                and targetPart ~= nil
                and (not isPlayerParrying(targetPlayer))
                and item ~= nil
            local desyncCF
            if canTarget then
                targetLowerTorso = targetPlayer.Character and targetPlayer.Character:FindFirstChild("LowerTorso")
                baseCFrame = targetLowerTorso and targetLowerTorso.CFrame or targetRoot.CFrame
                local _, y, _ = baseCFrame:ToOrientation()
                currentTargetYaw = y
                curSlot = getgenv().Config.WeaponSlot or "Primary"
                offsets = (getgenv().Config.TPOffsets and getgenv().Config.TPOffsets[curSlot])
                ox = (offsets and offsets.X) or 0
                oy = (offsets and offsets.Y) or (curSlot == "Knife" and -5 or 5)
                oz = (offsets and offsets.Z) or (curSlot == "Knife" and 1 or 0)
                desyncPos = (baseCFrame * CFrame.new(ox, oy, oz)).Position
                if curSlot == "Knife" then
                    targetBasePart = targetPlayer.Character and (targetPlayer.Character:FindFirstChild("LowerTorso") or targetRoot)
                    if targetBasePart then
                        vel = targetBasePart.AssemblyLinearVelocity
                        predFactor = getgenv().Config.KnifePredictFactor or 0.08
                        desyncPos = desyncPos + vel * predFactor
                    end
                end
                if curSlot == "Knife" then
                    lookTarget = Vector3.new(targetPart.Position.X, desyncPos.Y, targetPart.Position.Z)
                    if (desyncPos - lookTarget).Magnitude > 0.001 then
                        desyncCF = CFrame.lookAt(desyncPos, lookTarget)
                    else
                        desyncCF = CFrame.new(desyncPos) * (baseCFrame - baseCFrame.Position)
                    end
                else
                    if (desyncPos - targetPart.Position).Magnitude > 0.001 then
                        desyncCF = CFrame.lookAt(desyncPos, targetPart.Position)
                    else
                        desyncCF = CFrame.new(desyncPos) * (baseCFrame - baseCFrame.Position)
                    end
                end
            else
                currentTargetYaw = nil
                if tc == false then
                    desyncCF = myRoot.CFrame
                else
                    randomDir = Vector3.new(
                        math.random(-100, 100),
                        math.random(-100, 100),
                        math.random(-100, 100)
                    ).Unit
                    local cam = ws.CurrentCamera
                    camPos = cam and cam.CFrame.Position or Vector3.new(0, 0, 0)
                    desyncCF = CFrame.new(camPos + randomDir * 7000000000000)
                end
            end
            _restoreRoot = myRoot
            _restoreCF = myRoot.CFrame
            _restoreVel = myRoot.Velocity
            _restoreRotVel = myRoot.RotVelocity
            _hasRestore = true
            myRoot.CFrame = desyncCF
            currentDesyncCF = desyncCF
            if (not canTarget) or isAntiHitDelay then
                lastTarget = nil
                tpStartTime = 0
                if MechanicsController and getgenv().Config.WeaponSlot == "Knife" then
                    pcall(function()
                        MechanicsController:EquippedItemInput("FinishAiming")
                    end)
                end
                return
            end
            currentTargetPart = targetPart
            currentDesyncCF = desyncCF
            if lastTarget ~= targetPlayer then
                lastTarget = targetPlayer
                tpStartTime = tick()
            end
            minTpDelay = (autoAttack and 0.15) or 0.05
            if tick() - tpStartTime < minTpDelay then return end
            isKnife = (getgenv().Config.WeaponSlot == "Knife")
            if not canAttack then
                if isKnife and MechanicsController then
                    pcall(function()
                        MechanicsController:EquippedItemInput("FinishAiming")
                    end)
                end
                return
            end
            if tick() - lastFire < getgenv().Config.FireRate then return end
            lastFire = tick()
            if isKnife and MechanicsController then
                pcall(function()
                    MechanicsController:EquippedItemInput("StartAiming")
                end)
            end
            originPos = desyncCF.Position
            targetPos = targetPart.Position
            aimCF    = CFrame.lookAt(originPos, targetPos)
            randomOffset = Vector3.new(
                (math.random() - 0.5) * 0.1,
                (math.random() - 0.5) * 0.1,
                (math.random() - 0.5) * 0.1
            )
            aimedPos = targetPos + randomOffset
            objSpaceHeadOffset = targetPart.CFrame:ToObjectSpace(CFrame.new(aimedPos))
            cameradata = {}
            cameradata[utf8.char(1)] = {
                [utf8.char(0)] = util:EncodeCFrame(aimCF),
                [utf8.char(1)] = util:EncodeCFrame(aimCF),
                [utf8.char(2)] = targetPart,
                [utf8.char(3)] = util:EncodeCFrame(objSpaceHeadOffset)
            }
            if isKnife and camRemote and currentTargetYaw then
                pcall(function()
                    enc = util:EncodeCameraRotation(Vector2.new(0, currentTargetYaw))
                    camRemote:FireServer(enc, nil)
                end)
            end
            if getgenv().Config and getgenv().Config.AntiHit then
                now = tick()
                antiHitStart = now + 0.15
                antiHitUntil = antiHitStart + (getgenv().Config.AntiHitDuration or 0.5)
            end
            repS.Remotes.Replication.Fighter.UseItem:FireServer(
                item:Get("ObjectID"),
                enum:ToEnum(isKnife and "StartAiming" or "StartShooting"),
                cameradata,
                nil
            )
        end

        local function updateRagebotConnections()
            enabled = getgenv().Config and getgenv().Config.Enabled
            if enabled then
                if not _rbRestoreBound then
                    pcall(function() runS:UnbindFromRenderStep("__restore") end)
                    runS:BindToRenderStep("__restore", 101, restoreCallback)
                    _rbRestoreBound = true
                end
                if not _rbHeartbeatConn then
                    _rbHeartbeatConn = runS.Heartbeat:Connect(heartbeatCallback)
                end
            else
                if _rbHeartbeatConn then
                    _rbHeartbeatConn:Disconnect()
                    _rbHeartbeatConn = nil
                end
                if _rbRestoreBound then
                    pcall(function() runS:UnbindFromRenderStep("__restore") end)
                    _rbRestoreBound = false
                end
            end
        end
        getgenv()._updateRagebotConnections = updateRagebotConnections
        updateRagebotConnections()
    end)
    FFASection = Tabs.Rage:AddLeftGroupbox("FFA")
    FFASettings = {
        AutoHealth = true,
        AutoAmmo = true
    }
    local updateFfaLoop
    FFASection:AddToggle("FFA_AutoHealth", {
        Text = "Auto Health", Default = true,
        Callback = function(value)
            FFASettings.AutoHealth = value
            if updateFfaLoop then updateFfaLoop() end
        end
    })
    FFASection:AddToggle("FFA_AutoAmmo", {
        Text = "Auto Ammo", Default = true,
        Callback = function(value)
            FFASettings.AutoAmmo = value
            if updateFfaLoop then updateFfaLoop() end
        end
    })
    activeDrops = {}
    for _, obj in workspace:GetChildren() do
        if obj.Name == "_drop" and obj:IsA("BasePart") then
            activeDrops[obj] = true
        end
    end
    workspace.ChildAdded:Connect(function(obj)
        if obj.Name == "_drop" and obj:IsA("BasePart") then
            activeDrops[obj] = true
        end
    end)
    workspace.ChildRemoved:Connect(function(obj)
        activeDrops[obj] = nil
    end)
    ffaConn = nil
    updateFfaLoop = function()
        shouldRun = FFASettings.AutoAmmo or FFASettings.AutoHealth
        if shouldRun then
            if not ffaConn then
                ffaTime = 0
                ffaConn = RunService.Heartbeat:Connect(function(dt)
                    if not FFASettings.AutoAmmo and not FFASettings.AutoHealth then
                        if ffaConn then ffaConn:Disconnect(); ffaConn = nil end
                        return
                    end
                    character = lp.Character
                    if not character then return end
                    hrp = character:FindFirstChild("HumanoidRootPart")
                    if not hrp then return end
                    ffaTime = ffaTime + dt * 8
                    bounce = math_sin(ffaTime) * 4
                    targetPos = (currentDesyncCF and currentDesyncCF.Position) or hrp.Position
                    for obj in pairs(activeDrops) do
                        if obj.Parent == workspace then
                            if (FFASettings.AutoAmmo and obj:FindFirstChild("Ammo")) or
                               (FFASettings.AutoHealth and obj:FindFirstChild("Health")) then
                                if not obj:GetAttribute("KetyHidden") then
                                    obj:SetAttribute("KetyHidden", true)
                                    obj.Anchored = true
                                    if obj.Transparency ~= 1 then obj.Transparency = 1 end
                                    for _, child in pairs(obj:GetChildren()) do
                                        if child:IsA("BasePart") then
                                            if child.Transparency ~= 1 then child.Transparency = 1 end
                                        elseif child:IsA("BillboardGui") or child:IsA("SurfaceGui") or child:IsA("ParticleEmitter") or child:IsA("SelectionBox") then
                                            if child.Enabled then child.Enabled = false end
                                        end
                                    end
                                end
                                obj.CFrame = CFrame_new(targetPos + Vector3_new(0, bounce, 0))
                            end
                        end
                    end
                end)
            end
        else
            if ffaConn then ffaConn:Disconnect(); ffaConn = nil end
        end
    end
    updateFfaLoop()
end
do
    GunModsSection = Tabs.Rage:AddLeftGroupbox("Gun Mods")
getgenv().RageSettings = {
    Enabled = false,
    NoRecoil = false,
    NoSpread = false,
    RapidFire = false,
    AntiKatana = false,
    AntiKatanaDelay = 0.0,
    InstantScope = false,
    EquipFaster = false,
}
originalEquipCooldowns = {}
function UpdateWeaponMods()
    pcall(function()
        itemModule = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("ItemLibrary")
        if not itemModule then return end
        itemLib = require(itemModule)
        if not (itemLib and itemLib.Items) then return end
        isEnabled = getgenv().RageSettings and getgenv().RageSettings.Enabled and getgenv().RageSettings.EquipFaster
        for name, item in pairs(itemLib.Items) do
            if type(item) == "table" and item.EquipCooldown ~= nil then
                if not originalEquipCooldowns[name] then
                    originalEquipCooldowns[name] = item.EquipCooldown
                end
                orig = originalEquipCooldowns[name]
                if isEnabled then
                    item.EquipCooldown = 0.01
                else
                    item.EquipCooldown = orig
                end
            end
        end
    end)
end
function RestoreWeaponStats()
    pcall(function()
        itemModule = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("ItemLibrary")
        if not itemModule then return end
        itemLib = require(itemModule)
        if not (itemLib and itemLib.Items) then return end
        for name, orig in pairs(originalEquipCooldowns) do
            item = itemLib.Items[name]
            if type(item) == "table" then
                item.EquipCooldown = orig
            end
        end
    end)
end
task.spawn(function()
    OriginalStats = {} 
    PlayerScripts = lp:WaitForChild("PlayerScripts", 10)
    if not PlayerScripts then return end
    clientItemModule = require(PlayerScripts:WaitForChild("Modules", 5):WaitForChild("ClientReplicatedClasses", 5):WaitForChild("ClientFighter", 5):WaitForChild("ClientItem", 5))
    if type(clientItemModule) == "table" then
        originalEquip = clientItemModule.Equip
        if type(originalEquip) == "function" and not clientItemModule._isEquipHooked then
            clientItemModule._isEquipHooked = true
            clientItemModule.Equip = function(self, ...)
                if not self._isNoSpreadHooked then
                    self._isNoSpreadHooked = true
                    originalIsFullyAiming = self.IsFullyAiming
                    if type(originalIsFullyAiming) == "function" then
                        self.IsFullyAiming = function(weaponSelf, ...)
                            if getgenv().RageSettings.Enabled and getgenv().RageSettings.NoSpread then return true end
                            return originalIsFullyAiming(weaponSelf, ...)
                        end
                    else
                        self.IsFullyAiming = function() return getgenv().RageSettings.Enabled and getgenv().RageSettings.NoSpread end
                    end
                end
                origSS = self.StartShooting
                if type(origSS) == "function" and not self._isAntiKatanaSSHooked then
                    self._isAntiKatanaSSHooked = true
                    self.StartShooting = function(gunSelf, ...)
                        if getgenv().RageSettings.Enabled and getgenv().RageSettings.AntiKatana then
                            now = tick()
                            local cam = workspace.CurrentCamera
                            delay = getgenv().RageSettings.AntiKatanaDelay or 0
                            for p, endTime in pairs(DeflectingPlayers) do
                                startTime = (getgenv().DeflectingStartTimes and getgenv().DeflectingStartTimes[p]) or (endTime - 1)
                                if now < endTime and now >= (startTime + delay) and p ~= lp and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                                    local _, onScreen = cam:WorldToScreenPoint(p.Character.HumanoidRootPart.Position)
                                    if onScreen then return false end
                                end
                            end
                        end
                        return origSS(gunSelf, ...)
                    end
                end
                if self.Shot and not self._isAntiKatanaShotHooked then
                    self._isAntiKatanaShotHooked = true
                    origShotFire = self.Shot.Fire
                    self.Shot.Fire = function(sig, ...)
                        if getgenv().RageSettings.Enabled and getgenv().RageSettings.AntiKatana then
                            now = tick()
                            local cam = workspace.CurrentCamera
                            delay = getgenv().RageSettings.AntiKatanaDelay or 0
                            for p, endTime in pairs(DeflectingPlayers) do
                                startTime = (getgenv().DeflectingStartTimes and getgenv().DeflectingStartTimes[p]) or (endTime - 1)
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
    inputFunc = clientItemModule.Input
    if type(inputFunc) == "function" and not clientItemModule._isInputHooked then
        clientItemModule._isInputHooked = true
        clientItemModule.Input = function(self, ...)
            if not getgenv().RageSettings.Enabled then
                return inputFunc(self, ...)
            end
            if type(self) == "table" and self.Info then
                gunName = self.Name or tostring(self)
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
                orig = OriginalStats[gunName]
                if not self._isStatsHooked then
                    self._isStatsHooked = true
                    if setreadonly then pcall(function() setreadonly(self.Info, false) end) end
                end
                rapid = getgenv().RageSettings.RapidFire and 0.001 or nil
                overrides = {
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
                    if orig[prop] ~= nil and self.Info[prop] ~= tgtValue then
                        self.Info[prop] = tgtValue
                    end
                end
            end
            return inputFunc(self, ...)
        end
    end
end)
GunModsToggle = GunModsSection:AddToggle("GunMods_Enabled", {
    Text = "Enabled",
    Default = false,
    Callback = function(value)
        getgenv().RageSettings.Enabled = value
        UpdateWeaponMods()
    end
})
GunModsToggle:AddKeyPicker("GunModsKey", {
    Default = "None",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Gun Mods",
})
GunModsDep = GunModsSection:AddDependencyBox()
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
GunModsDep:AddToggle("GunMods_EquipFaster", {
    Text = "Equip Faster",
    Default = false,
    Callback = function(value)
        getgenv().RageSettings.EquipFaster = value
        UpdateWeaponMods()
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
instantScopeConn = nil
function updateInstantScopeConn()
    shouldRun = getgenv().RageSettings and getgenv().RageSettings.Enabled and getgenv().RageSettings.InstantScope
    if not shouldRun then
        if instantScopeConn then
            instantScopeConn:Disconnect()
            instantScopeConn = nil
        end
        return
    end
    if not instantScopeConn then
        cameraControllerCache = nil
        instantScopeConn = RunService.RenderStepped:Connect(function()
            if not (getgenv().RageSettings and getgenv().RageSettings.Enabled and getgenv().RageSettings.InstantScope) then
                if instantScopeConn then
                    instantScopeConn:Disconnect()
                    instantScopeConn = nil
                end
                return
            end
            if not cameraControllerCache then
                controllers = lp.PlayerScripts:FindFirstChild("Controllers")
                camController = controllers and controllers:FindFirstChild("CameraController")
                if camController then
                    local s, r = pcall(require, camController)
                    if s then cameraControllerCache = r end
                end
            end
            if cameraControllerCache and type(cameraControllerCache) == "table" then
                wSpring = cameraControllerCache._fov_weapons_spring
                gSpring = cameraControllerCache._fov_gameplay_spring
                if wSpring and gSpring then
                    if wSpring.Speed ~= 9999 then wSpring.Speed = 9999 end
                    if wSpring.Value ~= wSpring.Target then wSpring.Value = wSpring.Target end
                    if gSpring.Speed ~= 9999 then gSpring.Speed = 9999 end
                    if gSpring.Value ~= gSpring.Target then gSpring.Value = gSpring.Target end
                end
            end
        end)
    end
end

GunModsDep:AddToggle("GunMods_InstantScope", {
    Text = "Instant Scope",
    Default = false,
    Callback = function(value)
        getgenv().RageSettings.InstantScope = value
        updateInstantScopeConn()
    end
})
GunModsDep:SetupDependencies({ { GunModsToggle, true } })
origGunModsCallback = GunModsToggle.Callback
GunModsToggle.Callback = function(value)
    if origGunModsCallback then origGunModsCallback(value) end
    updateInstantScopeConn()
end
do
    AntiAimSection = Tabs.Rage:AddRightGroupbox("AntiAim")
    aaEnabled = false
    pitchMode = "Glitch Pitch"
    yawMode   = "Random Yaw"
    customPitch = 179
    customYaw   = 360
    pitchOverride = 1150
    yawOverride   = 0
    toggleVal     = 4999
    local function encodeUnclamped(pitchDeg, yawDeg)
        pitchRad = math.rad(pitchDeg)
        yawRad   = math.rad(yawDeg)
        pVal = math.floor(pitchRad / (2 * math.pi) * 256 + 0.5)
        yVal = math.floor(yawRad   / (2 * math.pi) * 256 + 0.5)
        pVal = math.clamp(pVal, 0, 1114111)
        yVal = math.clamp(yVal, 0, 1114111)
        return utf8.char(pVal) .. utf8.char(yVal)
    end
    local updateAntiAimLoop
    AntiAimToggle = AntiAimSection:AddToggle("AntiAim_Enabled", {
        Text = "Enabled",
        Default = false,
        Callback = function(value)
            aaEnabled = value
            if updateAntiAimLoop then updateAntiAimLoop() end
        end
    })
    AntiAimToggle:AddKeyPicker("AntiAimKey", {
        Default = "None",
        SyncToggleState = true,
        Mode = "Toggle",
        Text = "Anti Aim",
    })
    AntiAimDep = AntiAimSection:AddDependencyBox()
    PitchDropdown = AntiAimDep:AddDropdown("AntiAim_PitchMode", {
        Values = {"Glitch Pitch", "Random Pitch", "Custom Pitch"},
        Default = 1,
        Multi = false,
        Text = "Pitch Mode",
        Callback = function(value) pitchMode = value end
    })
    PitchCustomDep = AntiAimSection:AddDependencyBox()
    PitchCustomDep:AddSlider("AntiAim_CustomPitch", {
        Text = "Custom Pitch",
        Default = 179,
        Min = 1,
        Max = 179,
        Rounding = 0,
        Callback = function(value) customPitch = value end
    })
    PitchCustomDep:SetupDependencies({ { PitchDropdown, "Custom Pitch" } })
    AntiAimDep2 = AntiAimSection:AddDependencyBox()
    YawDropdown = AntiAimDep2:AddDropdown("AntiAim_YawMode", {
        Values = {"Random Yaw", "Custom Yaw"},
        Default = 1,
        Multi = false,
        Text = "Yaw Mode",
        Callback = function(value) yawMode = value end
    })
    YawCustomDep = AntiAimSection:AddDependencyBox()
    YawCustomDep:AddSlider("AntiAim_CustomYaw", {
        Text = "Custom Yaw",
        Default = 360,
        Min = 1,
        Max = 360,
        Rounding = 0,
        Callback = function(value) customYaw = value end
    })
    YawCustomDep:SetupDependencies({ { YawDropdown, "Custom Yaw" } })
    AntiAimDep:SetupDependencies({ { AntiAimToggle, true } })
    AntiAimDep2:SetupDependencies({ { AntiAimToggle, true } })
    camRemote = nil
    aaHeartbeatConn = nil
    lastSend = 0
    updateAntiAimLoop = function()
        if aaEnabled and camRemote then
            if not aaHeartbeatConn then
                aaHeartbeatConn = RunService.Heartbeat:Connect(function()
                    if not aaEnabled or not camRemote then
                        if aaHeartbeatConn then aaHeartbeatConn:Disconnect(); aaHeartbeatConn = nil end
                        return
                    end
                    if pitchMode == "Glitch Pitch" then
                        pitchOverride = 1150
                    elseif pitchMode == "Random Pitch" then
                        pitchOverride = toggleVal
                    elseif pitchMode == "Custom Pitch" then
                        pitchOverride = customPitch
                    end
                    if yawMode == "Random Yaw" then
                        yawOverride = toggleVal
                    elseif yawMode == "Custom Yaw" then
                        yawOverride = customYaw
                    end
                    now = tick()
                    if now - lastSend < 0.1 then return end
                    lastSend = now
                    toggleVal = (toggleVal == 4999) and 0 or 4999
                    pcall(function()
                        encoded = encodeUnclamped(pitchOverride, yawOverride)
                        camRemote:FireServer(encoded, nil)
                    end)
                end)
            end
        else
            if aaHeartbeatConn then
                aaHeartbeatConn:Disconnect()
                aaHeartbeatConn = nil
            end
        end
    end
    task.spawn(function()
        local ok1, remote = pcall(function()
            return ReplicatedStorage
                :WaitForChild("Remotes", 10)
                :WaitForChild("Replication", 10)
                :WaitForChild("Fighter", 10)
                :WaitForChild("UpdateCameraRotation", 10)
        end)
        if ok1 and remote then
            camRemote = remote
            updateAntiAimLoop()
        end
    end)
    if not getgenv()._antiAimHooked then
        getgenv()._antiAimHooked = true
        table.insert(getgenv().MasterHooks, function(isCaller, self, method, ...)
            if not isCaller
                and aaEnabled
                and camRemote ~= nil
                and method == "FireServer"
            then
                if self == camRemote then
                    encoded = encodeUnclamped(pitchOverride, yawOverride)
                    return true, getgenv()._masterOldNC(self, encoded, nil)
                end
            end
            return false, nil
        end)
    end
end
do
    autoQueueEnabled = false
    autoQueueName = nil
    autoQueueDisplayToInternal = {}
    MatchmakingController = nil
    CONSTANTS_REF = nil
    DEFAULT_DISPLAYS = { "1v1", "2v2", "3v3", "4v4", "5v5", "Ranked 1v1", "Ranked 2v2", "Ranked 3v3" }
    local tryQueueRef
    AutoQueueBox = Tabs.Misc:AddLeftGroupbox("Auto Queue")
    AutoQueueToggle = AutoQueueBox:AddToggle("AutoQueueToggle", {
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
    AutoQueueToggle:AddKeyPicker("AutoQueueKey", {
        Default = "None",
        SyncToggleState = true,
        Mode = "Toggle",
        Text = "Auto Queue",
    })
    AutoQueueDropObj = AutoQueueBox:AddDropdown("AutoQueueDrop", {
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
        ok = pcall(function()
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
        entries = {}
        for queueName, queueInfo in pairs(DuelLibrary.MatchmakingQueues) do
            display = queueName
            if type(queueInfo) == "table" then
                display = queueInfo.DisplayName or queueInfo.TitleName or queueName
            end
            table.insert(entries, { display = tostring(display), internal = queueName })
        end
        table.sort(entries, function(a, b) return a.display < b.display end)
        labels = {}
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
        inMatchmakingServer = false
        if CONSTANTS_REF then inMatchmakingServer = CONSTANTS_REF.IS_MATCHMAKING_SERVER and true or false end
        if not inMatchmakingServer then return false end
        gameOver = false
        if MatchmakingController and type(MatchmakingController.Get) == "function" then
            pcall(function() gameOver = MatchmakingController:Get("MatchmadeGameOver") end)
        end
        return not gameOver
    end
    autoQueueInvoking = false
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
UnlockAllSection = Tabs.Misc:AddLeftGroupbox("Unlock All")
UnlockAllToggle = UnlockAllSection:AddToggle("UnlockAllToggle", {
    Text = "Enable Unlock All",
    Default = false,
    Callback = function(value)
        getgenv().UnlockAllEnabled = value
        if value and not getgenv().UnlockAllExecuted then
            getgenv().UnlockAllExecuted = true
            task.spawn(function()
_plrs    = game:GetService("Players")
_rs      = game:GetService("ReplicatedStorage")
_http    = game:GetService("HttpService")
_run     = game:GetService("RunService")
_ws      = game:GetService("Workspace")
_lp      = _plrs.LocalPlayer
_pscripts = _lp.PlayerScripts
_ctrl    = _pscripts.Controllers
_mods    = _rs:WaitForChild("Modules", 10)
_enumLib = require(_mods:WaitForChild("EnumLibrary", 10))
if _enumLib then pcall(function() _enumLib:WaitForEnumBuilder() end) end
_cosLib  = require(_mods:WaitForChild("CosmeticLibrary", 10))
_itmLib  = require(_mods:WaitForChild("ItemLibrary", 10))
_datCtrl = require(_ctrl:WaitForChild("PlayerDataController", 10))
_eq, _favs = {}, {}
_buildingWep, _viewProf = nil, nil
_lastWep = nil
_fakeInv = {}
function _mkCosmetic(nm, ctype, opts)
    _base = _cosLib.Cosmetics[nm]
    if not _base then return nil end
    _d = {}
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
_cfgFile = "rivals_unlocker_config.json"
_saveLock = false
function _stripForSave()
    _out = {}
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
function _loadCfg()
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
        _cnt = 0
        for wn, cos in pairs(_dec.equipped) do
            _eq[wn] = {}
            for ct, sd in pairs(cos) do
                if sd and sd.Name then
                    if _cosLib.Cosmetics[sd.Name] then
                        _cloned = _mkCosmetic(sd.Name, ct, {
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
function _saveCfg()
    if not writefile or _saveLock then return end
    _saveLock = true
    task.spawn(function()
        task.wait(1)
        _payload = _stripForSave()
        local _ok, _enc = pcall(_http.JSONEncode, _http, _payload)
        if _ok then
            pcall(writefile, _cfgFile, _enc)
        end
        _saveLock = false
    end)
end
_loadCfg()
_cosTypes = {"Skin","Wrap","Charm","Dance","Emote"}
function _isCosType(cosObj)
    if not cosObj then return false end
    for _, t in ipairs(_cosTypes) do
        if cosObj.Type == t then return true end
    end
    return false
end
_cosLib.OwnsCosmeticNormally = function(self, inv, nm, wep)
    c = _cosLib.Cosmetics[nm]
    if c and c.Type == "Skin" then return true end
    return false
end
_cosLib.OwnsCosmeticUniversally = function(self, inv, nm, wep)
    c = _cosLib.Cosmetics[nm]
    if c and c.Type == "Skin" then return true end
    return false
end
_cosLib.OwnsCosmeticForWeapon = function(self, inv, nm, wep)
    c = _cosLib.Cosmetics[nm]
    if c and c.Type == "Skin" then return true end
    return false
end
_origOwns = _cosLib.OwnsCosmetic
_cosLib.OwnsCosmetic = function(self, inv, nm, wep)
    if nm:find("MISSING_") or nm == "Bubble Gun" then
        return _origOwns(self, inv, nm, wep)
    end
    c = _cosLib.Cosmetics[nm]
    if c and _isCosType(c) then return true end
    return _origOwns(self, inv, nm, wep)
end
_origGet = _datCtrl.Get
_datCtrl.Get = function(self, key)
    _val = _origGet(self, key)
    if key == "CosmeticInventory" then
        _prx = {}
        if _val then
            for k, v in pairs(_val) do
                c = _cosLib.Cosmetics[k]
                if c and _isCosType(c) then _prx[k] = v end
            end
        end
        return setmetatable(_prx, {
            __index = function(t, k)
                c = _cosLib.Cosmetics[k]
                if c and _isCosType(c) then return true end
                return nil
            end
        })
    end
    if key == "FavoritedCosmetics" then
        _res = _val and table.clone(_val) or {}
        for wep, fv in pairs(_favs) do
            _res[wep] = _res[wep] or {}
            for nm, isFav in pairs(fv) do
                c = _cosLib.Cosmetics[nm]
                if c and _isCosType(c) then
                    _res[wep][nm] = isFav
                end
            end
        end
        return _res
    end
    return _val
end
_origGetWep = _datCtrl.GetWeaponData
_datCtrl.GetWeaponData = function(self, wn)
    _d = _origGetWep(self, wn)
    if not _d then return nil end
    _m = {}
    for k, v in pairs(_d) do _m[k] = v end
    _m.Name = wn
    if _eq[wn] then
        for ct, cd in pairs(_eq[wn]) do
            _m[ct] = cd
        end
    end
    return _m
end
_fightCtrl
pcall(function()
    _fightCtrl = require(_ctrl:WaitForChild("FighterController", 10))
end)
if hookmetamethod then
    _remotes   = _rs:FindFirstChild("Remotes")
    _dataRem   = _remotes and _remotes:FindFirstChild("Data")
    _equipRem  = _dataRem and _dataRem:FindFirstChild("EquipCosmetic")
    _favRem    = _dataRem and _dataRem:FindFirstChild("FavoriteCosmetic")
    _repRem    = _remotes and _remotes:FindFirstChild("Replication")
    _fightRem  = _repRem and _repRem:FindFirstChild("Fighter")
    _useItmRem = _fightRem and _fightRem:FindFirstChild("UseItem")
    if _equipRem then
        if not getgenv()._UnlockAllHooked then
            getgenv()._UnlockAllHooked = true
            table.insert(getgenv().MasterHooks, function(isCaller, self, method, ...)
                if method ~= "FireServer" then return false, nil end
                if _useItmRem and self == _useItmRem then
                    _oid = ...
                    if _fightCtrl then
                        _f = _fightCtrl:GetFighter(_lp)
                        if _f and _f.Items then
                            for _, itm in pairs(_f.Items) do
                                if itm:Get("ObjectID") == _oid then
                                    _lastWep = itm.Name
                                    break
                                end
                            end
                        end
                    end
                    return false, nil
                elseif self == _equipRem then
                    local _wn, _ct, _cn, _opts = ...
                    _opts = _opts or {}
                    if _cn and _cn ~= "None" and _cn ~= "" then
                        _inv = _datCtrl:Get("CosmeticInventory")
                        if _inv and rawget(_inv, _cn) then
                            return false, nil
                        end
                    end
                    _eq[_wn] = _eq[_wn] or {}
                    if not _cn or _cn == "None" or _cn == "" then
                        _eq[_wn][_ct] = nil
                        if not next(_eq[_wn]) then _eq[_wn] = nil end
                    else
                        _cloned = _mkCosmetic(_cn, _ct, {
                            inverted = _opts.IsInverted,
                            favoritesOnly = _opts.OnlyUseFavorites
                        })
                        if _cloned then _eq[_wn][_ct] = _cloned end
                    end
                    task.defer(function()
                        pcall(function() _datCtrl.CurrentData:Replicate("WeaponInventory") end)
                    end)
                    _saveCfg()
                    return true, nil
                elseif self == _favRem then
                    local arg1, arg2, arg3 = ...
                    _cos = _cosLib.Cosmetics[arg2]
                    if _cos then
                        _favs[arg1] = _favs[arg1] or {}
                        _favs[arg1][arg2] = arg3 or nil
                        task.spawn(function()
                            pcall(function() _datCtrl.CurrentData:Replicate("FavoritedCosmetics") end)
                        end)
                        _saveCfg()
                    end
                    return true, nil
                end
                return false, nil
            end)
        end
    end
end
_cliItem
pcall(function()
    _cliItem = require(_lp.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem)
end)
if _cliItem and _cliItem._CreateViewModel then
    _origCVM = _cliItem._CreateViewModel
    _cliItem._CreateViewModel = function(self, vmRef)
        _wn  = self.Name
        _wp  = self.ClientFighter and self.ClientFighter.Player
        _buildingWep = (_wp == _lp) and _wn or nil
        if _wp == _lp and _eq[_wn] then
            _dk = self:ToEnum("Data")
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
        _r = _origCVM(self, vmRef)
        _buildingWep = nil
        return _r
    end
end
_vmMod = _lp.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem:FindFirstChild("ClientViewModel")
if _vmMod then
    _CVM = require(_vmMod)
    _origNew = _CVM.new
    _CVM.new = function(repData, cliItm)
        _wp  = cliItm.ClientFighter and cliItm.ClientFighter.Player
        _wn  = _buildingWep or cliItm.Name
        if _wp == _lp and _eq[_wn] then
            _RC  = require(_rs.Modules.ReplicatedClass)
            _dk  = _RC:ToEnum("Data")
            repData[_dk] = repData[_dk] or {}
            _cos = _eq[_wn]
            if _cos.Skin  then repData[_dk][_RC:ToEnum("Skin")]  = _cos.Skin  end
            if _cos.Charm then repData[_dk][_RC:ToEnum("Charm")] = _cos.Charm end
            if _cos.Wrap  then repData[_dk][_RC:ToEnum("Wrap")]  = _cos.Wrap  end
        end
        return _origNew(repData, cliItm)
    end
end
            end)
        end
    end
})
UnlockAllToggle:AddKeyPicker("UnlockAllKey", {
    Default = "None",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Unlock All",
})
UnlockAllSection:AddToggle("UnlockWeaponsToggle", {
    Text = "Unlock All Weapons (UI)",
    Default = false,
    Tooltip = "自分の画面の装備UIで全武器がアンロック済みに見える",
    Callback = function(value)
        getgenv().UnlockWeaponsEnabled = value
        pcall(function()
            EquipmentModule = lp:WaitForChild("PlayerScripts"):WaitForChild("Modules"):WaitForChild("UserInterface"):WaitForChild("Equipment")
            eq = require(EquipmentModule)
            if eq and eq.Left and eq.Left._Generate then
                eq.Left:_Generate()
            end
        end)
    end
})
OutOfBoundsSection = Tabs.Misc:AddLeftGroupbox("Out Of Bounds")
DisableOOBToggle = OutOfBoundsSection:AddToggle("DisableOOBToggle", {
    Text = "Disable Out Of Bounds",
    Default = false,
    Callback = function(value)
        getgenv().DisableOutOfBoundsEnabled = value
        if value and not getgenv().OOBHookExecuted then
            getgenv().OOBHookExecuted = true
            task.spawn(function()
                _rs = game:GetService("ReplicatedStorage")
                oob_remote = _rs:FindFirstChild("Remotes")
                if oob_remote then
                    rep = oob_remote:FindFirstChild("Replication")
                    if rep then
                        fighter = rep:FindFirstChild("Fighter")
                        if fighter then
                            oob_remote = fighter:FindFirstChild("OutOfBounds")
                        else oob_remote = nil end
                    else oob_remote = nil end
                end
                if not getgenv()._OOBHooked and oob_remote then
                    getgenv()._OOBHooked = true
                    table.insert(getgenv().MasterHooks, function(isCaller, self, method, ...)
                        if getgenv().DisableOutOfBoundsEnabled and (method == "FireServer" or method == "fireServer") and self == oob_remote then
                            return true, nil
                        end
                        return false
                    end)
                end
                modulesFolder = _rs:WaitForChild("Modules", 10)
                if modulesFolder then
                    pcall(function()
                        OutOfBoundsMachine = require(modulesFolder:WaitForChild("OutOfBoundsMachine", 5))
                        if type(OutOfBoundsMachine) == "table" then
                            origIsOOB = OutOfBoundsMachine.IsOutOfBounds
                            OutOfBoundsMachine.IsOutOfBounds = function(...)
                                if getgenv().DisableOutOfBoundsEnabled then return false end
                                if type(origIsOOB) == "function" then return origIsOOB(...) end
                            end
                            origUpdate = OutOfBoundsMachine.Update
                            OutOfBoundsMachine.Update = function(...)
                                if getgenv().DisableOutOfBoundsEnabled then return end
                                if type(origUpdate) == "function" then return origUpdate(...) end
                            end
                        end
                    end)
                    pcall(function()
                        GameplayUtility = require(modulesFolder:WaitForChild("GameplayUtility", 5))
                        if type(GameplayUtility) == "table" then
                            origWarn = GameplayUtility.GetOOBWarnDelay
                            GameplayUtility.GetOOBWarnDelay = function(...)
                                if getgenv().DisableOutOfBoundsEnabled then return 9999 end
                                if type(origWarn) == "function" then return origWarn(...) end
                            end
                            origKill = GameplayUtility.GetOOBKillDelay
                            GameplayUtility.GetOOBKillDelay = function(...)
                                if getgenv().DisableOutOfBoundsEnabled then return 9999 end
                                if type(origKill) == "function" then return origKill(...) end
                            end
                            origWithin = GameplayUtility.IsWithinOOBPart
                            GameplayUtility.IsWithinOOBPart = function(...)
                                if getgenv().DisableOutOfBoundsEnabled then return false end
                                if type(origWithin) == "function" then return origWithin(...) end
                            end
                        end
                    end)
                end
            end)
        end
    end
})
DisableOOBToggle:AddKeyPicker("DisableOOBKey", {
    Default = "None",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Disable OOB",
})
DeviceSpoofSection = Tabs.Misc:AddLeftGroupbox("Device Spoofer")
local DeviceSpooferToggle, DeviceSpoofDropdownObj
DeviceSpooferToggle = DeviceSpoofSection:AddToggle("DeviceSpoofToggle", {
    Text = "Enable Device Spoofer",
    Default = false,
    Callback = function(value)
        getgenv().DeviceSpoofEnabled = value
        if DeviceSpoofDropdownObj then
            getgenv().DeviceSpoofValue = DeviceSpoofDropdownObj.Value
        end
        if value and DeviceSpoofDropdownObj then
            task.defer(function()
                pcall(function()
                    ReplicatedStorage.Remotes.Replication.Fighter.SetControls:FireServer(DeviceSpoofDropdownObj.Value)
                end)
            end)
        end
    end
})
DeviceSpooferToggle:AddKeyPicker("DeviceSpoofKey", {
    Default = "None",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Device Spoofer",
})
DeviceSpoofDep = DeviceSpoofSection:AddDependencyBox()
DeviceSpoofDropdownObj = DeviceSpoofDep:AddDropdown("DeviceSpoofDropdown", {
    Values = {"Touch", "MouseKeyboard", "Gamepad", "VR"},
    Multi = false,
    Text = "Select Device",
    Callback = function(value)
        getgenv().DeviceSpoofValue = value
        if DeviceSpooferToggle and DeviceSpooferToggle.Value then
            pcall(function()
                ReplicatedStorage.Remotes.Replication.Fighter.SetControls:FireServer(value)
            end)
        end
    end
})
DeviceSpoofDep:SetupDependencies({ { DeviceSpooferToggle, true } })
do
dmgNotifEnabled = false
dmgNotifMin = 1
dmgNotifCooldown = 0.3
_dmgConnections = {}
_dmgLastTime = {}
_lastHitmarkerTime = 0
_hitmarkerHooked = false
function hookHitmarker()
    if _hitmarkerHooked then return end
    pcall(function()
        cvmObj = lp.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem:FindFirstChild("ClientViewModel")
        if cvmObj then
            cvmObj.ChildAdded:Connect(function(v)
                if v:IsA("Sound") then
                    _lastHitmarkerTime = tick()
                end
            end)
            _hitmarkerHooked = true
        end
    end)
end
_hookCoroutine = nil
function startHookLoop()
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
function attachDmgNotif(p)
    if _dmgConnections[p] then
        pcall(function() _dmgConnections[p]:Disconnect() end)
        _dmgConnections[p] = nil
    end
    if not p.Character then return end
    hum = p.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    prevHP = hum.Health
    _dmgConnections[p] = hum.HealthChanged:Connect(function(newHP)
        if not dmgNotifEnabled then return end
        dmg = prevHP - newHP
        prevHP = newHP
        if dmg < dmgNotifMin then return end
        task.spawn(function()
            task.wait(0.15)
            if not _hitmarkerHooked then hookHitmarker() end
            if tick() - _lastHitmarkerTime > 0.8 then return end
            now = tick()
            if _dmgLastTime[p] and now - _dmgLastTime[p] < dmgNotifCooldown then return end
            _dmgLastTime[p] = now
            dmgStr = math.floor(dmg)
            hpLeft = math.max(0, math.floor(newHP))
            Library:Notify(
                "Hit " .. p.Name .. " for " .. dmgStr .. " damage! (" .. hpLeft .. " HP left)",
                3
            )
        end)
    end)
end
function refreshDmgConnections()
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
DmgNotifSection = Tabs.Misc:AddLeftGroupbox("Damage Notification")
DmgNotifToggle = DmgNotifSection:AddToggle("DmgNotif_Enabled", {
    Text = "Enabled", Default = false,
    Callback = function(v)
        dmgNotifEnabled = v
        if v then 
            refreshDmgConnections() 
            startHookLoop()
        end
    end,
})
DmgNotifToggle:AddKeyPicker("DmgNotifKey", {
    Default = "None",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Damage Notification",
})
DmgNotifSection:AddSlider("DmgNotif_Min", {
    Text = "Min Damage", Default = 1, Min = 1, Max = 100, Rounding = 0,
    Callback = function(v) dmgNotifMin = v end,
})
DmgNotifSection:AddSlider("DmgNotif_Cooldown", {
    Text = "Cooldown (s)", Default = 0.3, Min = 0, Max = 3, Rounding = 1,
    Callback = function(v) dmgNotifCooldown = v end,
})
end 
do
    AntiBanSection = Tabs.Misc:AddRightGroupbox("Anti Ban")
StaffDetectorEnabled = false
StaffDetectorAction = "Notify"
ArchNemesisEnabled = false
STAFF_GROUP_ID = 3461453
StaffRoles = {
    ["Community Staff"] = true,
    Tester = true,
    Builder = true,
    Developer = true,
    Scripter = true
}
function HandleStaffDetection(player, role)
    msg = "笞・・STAFF DETECTED 笞・十nName: " .. player.Name .. "\nRole: " .. role
    if StaffDetectorAction == "Kick" then
        lp:Kick(msg)
    else
        Library:Notify(msg, 5)
    end
end
function CheckPlayerAntiBan(player)
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
                stats = player:WaitForChild("CustomLeaderstats", 5)
                if stats then
                    eloVal = stats:WaitForChild("Current ELO", 5)
                    if eloVal then
                        local function checkRank()
                            if not ArchNemesisEnabled then return end
                            elo = tonumber(eloVal.Value) or 0
                            rankName = seasonLib:GetRank(elo, player.UserId)
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
StaffDetectorToggle = AntiBanSection:AddToggle("StaffDetectorToggle", {
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
StaffDetectorToggle:AddKeyPicker("StaffDetectorKey", {
    Default = "None",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Staff Detector",
})
AntiBanSection:AddDropdown("StaffDetectorAction", {
    Values = {"Notify", "Kick"},
    Default = 1,
    Multi = false,
    Text = "Action",
    Callback = function(value) StaffDetectorAction = value end
})
ArchNemesisToggle = AntiBanSection:AddToggle("ArchNemesisToggle", {
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
ArchNemesisToggle:AddKeyPicker("ArchNemesisKey", {
    Default = "None",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "ArchNemesis Checker",
})
Players.PlayerAdded:Connect(function(player)
    CheckPlayerAntiBan(player)
end)
end
do
    SoundChangerSection = Tabs.Misc:AddRightGroupbox("Sound Changer")
soundChangerEnabled = false
soundtochange = "rbxassetid://4764109000" 
soundChangerConnection = nil
function updateSoundChanger()
    if soundChangerEnabled then
        if not soundChangerConnection then
            pcall(function()
                clientViewModel = game:GetService("Players").LocalPlayer.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem.ClientViewModel
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
SoundChangerToggle = SoundChangerSection:AddToggle("SoundChangerToggle", {
    Text = "HitSoundChanger",
    Default = false,
    Callback = function(value)
        soundChangerEnabled = value
        updateSoundChanger()
    end
})
SoundChangerToggle:AddKeyPicker("SoundChangerKey", {
    Default = "None",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Hit Sound Changer",
})
SoundChangerDep = SoundChangerSection:AddDependencyBox()
SoundChangerDep:AddInput("SoundChangerID", {
    Default = "4764109000",
    Numeric = true,
    Finished = false,
    Text = "Sound ID",
    Placeholder = "Enter Sound ID",
    Callback = function(value)
        id = string.match(tostring(value), "%d+")
        if id then
            soundtochange = "rbxassetid://" .. id
        end
    end
})
SoundChangerDep:SetupDependencies({ { SoundChangerToggle, true } })
killSoundEnabled = false
killSoundId = "rbxassetid://137918234220296"
SoundService = game:GetService("SoundService")
deathSound = Instance.new("Sound")
deathSound.SoundId = killSoundId
deathSound.Volume = 1
deathSound.Parent = SoundService
function playKillSound()
    if killSoundEnabled then
        deathSound.SoundId = killSoundId
        deathSound:Play()
    end
end
function onCharacterAdded(character)
    humanoid = character:WaitForChild("Humanoid", 10)
    if humanoid then
        humanoid.Died:Connect(playKillSound)
    end
end
function onPlayerAdded(player)
    if player.Character then
        onCharacterAdded(player.Character)
    end
    player.CharacterAdded:Connect(onCharacterAdded)
end
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, player)
end
Players.PlayerAdded:Connect(onPlayerAdded)
KillSoundToggle = SoundChangerSection:AddToggle("KillSoundToggle", {
    Text = "KillSoundChanger",
    Default = false,
    Callback = function(value)
        killSoundEnabled = value
    end
})
KillSoundToggle:AddKeyPicker("KillSoundKey", {
    Default = "None",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Kill Sound Changer",
})
KillSoundDep = SoundChangerSection:AddDependencyBox()
KillSoundDep:AddInput("KillSoundID", {
    Default = "137918234220296",
    Numeric = true,
    Finished = false,
    Text = "Kill Sound ID",
    Placeholder = "Enter Sound ID",
    Callback = function(value)
        id = string.match(tostring(value), "%d+")
        if id then
            killSoundId = "rbxassetid://" .. id
            deathSound.SoundId = killSoundId
        end
    end
})
KillSoundDep:SetupDependencies({ { KillSoundToggle, true } })
end
do
    AnimationPlayerSection = Tabs.Misc:AddLeftGroupbox("Animation Player")
animPlayerEnabled = false
animPlayerId = "rbxassetid://97893809425239"
animPlayerSpeed = 1
currentAnim = nil
currentTrack = nil
currentStoppedConn = nil
charAddedConn = nil
animatorConn = nil
function stopAnimation()
    if currentStoppedConn then pcall(function() currentStoppedConn:Disconnect() end) currentStoppedConn = nil end
    if animatorConn then pcall(function() animatorConn:Disconnect() end) animatorConn = nil end
    if currentTrack then pcall(function() currentTrack:Stop() end) currentTrack = nil end
    if charAddedConn then pcall(function() charAddedConn:Disconnect() end) charAddedConn = nil end
    currentAnim = nil
end
function playAnimation(char)
    if not animPlayerEnabled or not currentAnim then return end
    task.spawn(function()
        humanoid = char:WaitForChild("Humanoid", 5)
        animator = humanoid and humanoid:WaitForChild("Animator", 5)
        if animator then
            while char.Parent == nil do
                task.wait(0.1)
            end
            task.wait(0.5) 
            if not animPlayerEnabled or not currentAnim then return end
            if currentTrack then
                t = currentTrack
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
function updateAnimationPlayer()
    stopAnimation()
    if animPlayerEnabled then
        local success, objects = pcall(function()
            return game:GetObjects(animPlayerId)
        end)
        if success and objects then
            for _, obj in ipairs(objects) do
                anim = obj:IsA("Animation") and obj or obj:FindFirstChildWhichIsA("Animation", true)
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
AnimationPlayerToggle = AnimationPlayerSection:AddToggle("AnimationPlayerToggle", {
    Text = "Enabled",
    Default = false,
    Callback = function(value)
        animPlayerEnabled = value
        updateAnimationPlayer()
    end
})
AnimationPlayerToggle:AddKeyPicker("AnimationPlayerKey", {
    Default = "None",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Animation Player",
})
AnimationPlayerDep = AnimationPlayerSection:AddDependencyBox()
AnimationPlayerDep:AddInput("AnimationPlayerID", {
    Default = "97893809425239",
    Numeric = true,
    Finished = false,
    Text = "Animation ID",
    Placeholder = "Enter Animation ID",
    Callback = function(value)
        id = string.match(tostring(value), "%d+")
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
end
ThemeManager:SetLibrary(Library)
ThemeManager:SetFolder("KETY")
ThemeManager:ApplyTheme("Default")
Library.AccentColor = Color3.fromRGB(0, 180, 255)
Library:UpdateColorsUsingRegistry()
ThemeSection = Tabs.Config:AddLeftGroupbox("Theme")
ThemeManager:ApplyToGroupbox(ThemeSection)
do
    MovementSection = Tabs.Misc:AddRightGroupbox("Movement")
flyEnabled = false
flySpeed = 70
bodyVelocity = nil
bodyGyro = nil
flyThread = nil
noclipEnabled = false
noclipConnection = nil
function cleanupFly()
    if flyThread then pcall(task.cancel, flyThread) flyThread = nil end
    if bodyVelocity then bodyVelocity:Destroy() bodyVelocity = nil end
    if bodyGyro then bodyGyro:Destroy() bodyGyro = nil end
end
function startFly()
    char = lp.Character
    if not char then return end
    root = char:FindFirstChild("HumanoidRootPart")
    hum = char:FindFirstChildOfClass("Humanoid")
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
            humCurrent = char:FindFirstChildOfClass("Humanoid")
            if humCurrent then
                moveDir = humCurrent.MoveDirection
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
function stopFly()
    flyEnabled = false
    cleanupFly()
    char = lp.Character
    if char then
        hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum:GetState() == Enum.HumanoidStateType.Swimming then
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end
end
function startNoclip()
    cachedParts = {}
    currentNoclipChar = nil
    if noclipConnection then noclipConnection:Disconnect() end
    noclipEnabled = true
    noclipConnection = RunService.Stepped:Connect(function()
        if noclipEnabled and lp.Character then
            if currentNoclipChar ~= lp.Character then
                currentNoclipChar = lp.Character
                cachedParts = {}
                for _, part in ipairs(currentNoclipChar:GetChildren()) do
                    if part:IsA("BasePart") then
                        table.insert(cachedParts, part)
                    end
                end
            end
            for _, part in ipairs(cachedParts) do
                if part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end)
end
function stopNoclip()
    noclipEnabled = false
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end
    if lp.Character then
        for _, part in ipairs(lp.Character:GetChildren()) do
            if part:IsA("BasePart") and not part.CanCollide and part.Name ~= "HumanoidRootPart" then
                part.CanCollide = true
            end
        end
    end
end
FlyToggle = MovementSection:AddToggle("FlyToggle", {
    Text = "Fly",
    Default = false,
    Callback = function(value)
        if value then startFly() else stopFly() end
    end
})
FlyToggle:AddKeyPicker("FlyKey", {
    Default = "None",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Fly",
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
            char = lp.Character
            if char then
                hum = char:FindFirstChildOfClass("Humanoid")
                if hum and hum.MoveDirection.Magnitude > 0 then
                    bodyVelocity.Velocity = hum.MoveDirection * value
                end
            end
        end
    end
})
hideInFloorEnabled = false
hideDesyncEnabled = false
hideTargetPos = nil
hideDesyncConn = nil
hif_h = nil
hif_savedCF = nil
hif_needsRestore = false
hideRayParams = RaycastParams.new()
hideRayParams.FilterType = Enum.RaycastFilterType.Exclude

function updateHifRestore()
    if hideInFloorEnabled and hideDesyncEnabled then
        safeBindToRenderStep(RunService, "__hif_restore", 101, function()
            if hif_needsRestore and hif_h then
                hif_h.CFrame = hif_savedCF
                hif_needsRestore = false
            end
        end)
    else
        safeUnbindFromRenderStep(RunService, "__hif_restore")
    end
end

function startHideInFloor()
    char = lp.Character
    if not char then return end
    hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if hideDesyncConn then hideDesyncConn:Disconnect() end
    task.spawn(function()
        while hideInFloorEnabled do
            local cam = workspace.CurrentCamera
            c = lp.Character
            if c then hideRayParams.FilterDescendantsInstances = {c} end
            if cam then
                ray = workspace:Raycast(cam.CFrame.Position, Vector3.new(0, -9999, 0), hideRayParams)
                if ray then
                    hideTargetPos = ray.Position - Vector3.new(0, 5, 0)
                else
                    hideTargetPos = cam.CFrame.Position - Vector3.new(0, 5, 0)
                end
            elseif c and c:FindFirstChild("HumanoidRootPart") then
                hrp = c.HumanoidRootPart
                ray = workspace:Raycast(hrp.Position, Vector3.new(0, -9999, 0), hideRayParams)
                if ray then
                    hideTargetPos = ray.Position - Vector3.new(0, 5, 0)
                else
                    hideTargetPos = hrp.Position - Vector3.new(0, 5, 0)
                end
            end
            task.wait(1)
        end
    end)
    updateHifRestore()
    hideDesyncConn = RunService.Heartbeat:Connect(function()
        if not hideInFloorEnabled then return end
        c = lp.Character
        if not (c and c:FindFirstChild("HumanoidRootPart") and hideTargetPos) then return end
        h = c.HumanoidRootPart
        savedCF = h.CFrame
        targetPos = Vector3.new(savedCF.X, hideTargetPos.Y, savedCF.Z)
        h.CFrame = CFrame.new(targetPos) * CFrame.Angles(savedCF:ToEulerAnglesXYZ())
        if hideDesyncEnabled then
            hif_h = h
            hif_savedCF = savedCF
            hif_needsRestore = true
        end
    end)
end
function stopHideInFloor()
    if hideDesyncConn then hideDesyncConn:Disconnect() hideDesyncConn = nil end
    updateHifRestore()
    hideTargetPos = nil
    char = lp.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        hrp = char.HumanoidRootPart
        hrp.CFrame = hrp.CFrame + Vector3.new(0, 10, 0)
    end
end
NoclipToggle = MovementSection:AddToggle("NoclipToggle", {
    Text = "Noclip",
    Default = false,
    Callback = function(value)
        if value then startNoclip() else stopNoclip() end
    end
})
NoclipToggle:AddKeyPicker("NoclipKey", {
    Default = "None",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Noclip",
})
HideInFloorToggle = MovementSection:AddToggle("HideInFloorToggle", {
    Text = "Hide In Floor",
    Default = false,
    Callback = function(value)
        hideInFloorEnabled = value
        if value then startHideInFloor() else stopHideInFloor() end
    end
})
HideInFloorToggle:AddKeyPicker("HideInFloorKey", {
    Default = "None",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Hide In Floor",
})
HideDesyncToggle = MovementSection:AddToggle("HideDesyncToggle", {
    Text = "Desync In Floor",
    Default = false,
    Callback = function(value)
        hideDesyncEnabled = value
        updateHifRestore()
    end
})
HideDesyncToggle:AddKeyPicker("HideDesyncKey", {
    Default = "None",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Desync In Floor",
})
    infJumpEnabled = false
    fighterControllerCache = nil
    maxDoubleJumpsOriginals = {}
    infJumpConn = nil
    InfJumpToggle = MovementSection:AddToggle("InfJumpToggle", {
        Text = "Infinite Jump",
        Default = false,
        Callback = function(value)
            infJumpEnabled = value
            if infJumpConn then
                infJumpConn:Disconnect()
                infJumpConn = nil
            end
            if value then
                lastInfJump = 0
                infJumpConn = RunService.RenderStepped:Connect(function()
                    if not infJumpEnabled then return end
                    now = tick()
                    if now - lastInfJump < 0.2 then return end
                    lastInfJump = now
                    if not fighterControllerCache then
                        controllers = lp.PlayerScripts:FindFirstChild("Controllers")
                        fighterController = controllers and controllers:FindFirstChild("FighterController")
                        if fighterController then
                            local s, r = pcall(require, fighterController)
                            if s then fighterControllerCache = r end
                        end
                    end
                    if fighterControllerCache and fighterControllerCache.LocalFighter then
                        item = fighterControllerCache.LocalFighter.EquippedItem
                        if item and type(item.Info) == "table" and item.Name then
                            if maxDoubleJumpsOriginals[item.Name] == nil then
                                maxDoubleJumpsOriginals[item.Name] = item.Info.MaxDoubleJumps or 1
                            end
                            item.Info.MaxDoubleJumps = math.huge
                        end
                    end
                end)
            else
                if fighterControllerCache and fighterControllerCache.LocalFighter then
                    item = fighterControllerCache.LocalFighter.EquippedItem
                    if item and item.Info and item.Name and maxDoubleJumpsOriginals[item.Name] then
                        item.Info.MaxDoubleJumps = maxDoubleJumpsOriginals[item.Name]
                    end
                end
            end
        end
    })
    InfJumpToggle:AddKeyPicker("InfJumpKey", {
        Default = "None",
        SyncToggleState = true,
        Mode = "Toggle",
        Text = "Infinite Jump",
    })
    slideBoostEnabled = false
    slideBoostMultiplier = 1.0
    local function setupSlideBoost()
        local MechanicsController
        ok = pcall(function()
            controllers = lp:WaitForChild("PlayerScripts", 10):WaitForChild("Controllers", 10)
            MechanicsController = require(controllers:WaitForChild("MechanicsController", 10))
        end)
        if not ok or type(MechanicsController) ~= "table" then return end
        oldSlide = MechanicsController.Slide
        if type(oldSlide) ~= "function" or MechanicsController._isSlideHooked then return end
        MechanicsController._isSlideHooked = true
        MechanicsController.Slide = function(self)
            if slideBoostEnabled then
                fighter = self.LocalFighter
                if fighter and fighter.Get then
                    oldGet = fighter.Get
                    fighter.Get = function(f, key)
                        if key == "SlidingSpeedMax" then
                            return 3.0 * slideBoostMultiplier
                        end
                        return oldGet(f, key)
                    end
                    task.delay(1.5, function()
                        if fighter and fighter.Get then
                            fighter.Get = oldGet
                        end
                    end)
                end
            end
            return oldSlide(self)
        end
    end
    task.spawn(setupSlideBoost)
    SlideBoostToggle = MovementSection:AddToggle("SlideBoostToggle", {
        Text = "Slide Boost",
        Default = false,
        Callback = function(v)
            slideBoostEnabled = v
        end
    })
    SlideBoostToggle:AddKeyPicker("SlideBoostKey", {
        Default = "None",
        SyncToggleState = true,
        Mode = "Toggle",
        Text = "Slide Boost",
    })
    MovementSection:AddSlider("SlideBoostMultiplier", {
        Text = "Slide Boost Multiplier",
        Default = 1.0,
        Min = 0,
        Max = 3,
        Rounding = 1,
        Compact = false,
        Callback = function(v)
            slideBoostMultiplier = v
        end
    })
    if getgenv then
        getgenv().SlideBoost = {
            SetEnabled = function(val)
                slideBoostEnabled = val
                SlideBoostToggle:SetValue(val)
            end,
            SetMultiplier = function(val)
                slideBoostMultiplier = val
            end,
            Toggle = function()
                slideBoostEnabled = not slideBoostEnabled
                SlideBoostToggle:SetValue(slideBoostEnabled)
                return slideBoostEnabled
            end,
        }
    end
    lp.CharacterAdded:Connect(function()
        if flyEnabled then task.wait(0.5) startFly() end
        if noclipEnabled then task.wait(0.5) startNoclip() end
    end)
end
do
autoLoadoutEnabled = false
ChosenWeapons = {}
WeaponLists = {}
ListIndexes = {1, 1, 1, 1}
LoadCoreBox = Tabs.Misc:AddLeftGroupbox("Loadout Core")
AutoLoadToggle = LoadCoreBox:AddToggle("AutoLoadToggle", { Text = "Enable Auto Loadout", Default = autoLoadoutEnabled, Callback = function(Value) autoLoadoutEnabled = Value end })
AutoLoadToggle:AddKeyPicker("AutoLoadKey", {
    Default = "None",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Auto Loadout",
})
LoadSlotsBox = Tabs.Misc:AddRightGroupbox("Weapon Slots")
PriDropObj = LoadSlotsBox:AddDropdown("PriDrop", { Values = {"None"}, Default = 1, Multi = false, Text = "Primary", Callback = function(Value) ChosenWeapons[1] = Value end })
SecDropObj = LoadSlotsBox:AddDropdown("SecDrop", { Values = {"None"}, Default = 1, Multi = false, Text = "Secondary", Callback = function(Value) ChosenWeapons[2] = Value end })
MelDropObj = LoadSlotsBox:AddDropdown("MelDrop", { Values = {"None"}, Default = 1, Multi = false, Text = "Melee", Callback = function(Value) ChosenWeapons[3] = Value end })
UtiDropObj = LoadSlotsBox:AddDropdown("UtiDrop", { Values = {"None"}, Default = 1, Multi = false, Text = "Utility", Callback = function(Value) ChosenWeapons[4] = Value end })
AutoLoadout_ItemLibrary = nil
AutoLoadout_FighterController = nil
AutoLoadout_DuelController = nil
function getSavedWeaponSelections()
    saved = {}
    pcall(function()
        sm = getgenv().SaveManager or SaveManager
        if not (sm and sm.Folder) then return end
        autoFile = sm.Folder .. "/settings/autoload.txt"
        if not (type(isfile) == "function" and isfile(autoFile)) then return end
        name = readfile(autoFile)
        path = sm.Folder .. "/settings/" .. name .. ".json"
        if not isfile(path) then return end
        decoded = game:GetService("HttpService"):JSONDecode(readfile(path))
        if type(decoded) == "table" and type(decoded.Options) == "table" then
            saved[1] = decoded.Options.PriDrop
            saved[2] = decoded.Options.SecDrop
            saved[3] = decoded.Options.MelDrop
            saved[4] = decoded.Options.UtiDrop
        end
    end)
    return saved
end
dropObjs = {PriDropObj, SecDropObj, MelDropObj, UtiDropObj}
function updateWeaponLabels()
    prevVals = {
        PriDropObj.Value,
        SecDropObj.Value,
        MelDropObj.Value,
        UtiDropObj.Value,
    }
    if WeaponLists[1] and #WeaponLists[1] > 0 then
        PriDropObj:SetValues(WeaponLists[1])
        v = (prevVals[1] and table.find(WeaponLists[1], prevVals[1])) and prevVals[1] or PriDropObj.Value
        PriDropObj:SetValue(v); ChosenWeapons[1] = v
    end
    if WeaponLists[2] and #WeaponLists[2] > 0 then
        SecDropObj:SetValues(WeaponLists[2])
        v = (prevVals[2] and table.find(WeaponLists[2], prevVals[2])) and prevVals[2] or SecDropObj.Value
        SecDropObj:SetValue(v); ChosenWeapons[2] = v
    end
    if WeaponLists[3] and #WeaponLists[3] > 0 then
        MelDropObj:SetValues(WeaponLists[3])
        v = (prevVals[3] and table.find(WeaponLists[3], prevVals[3])) and prevVals[3] or MelDropObj.Value
        MelDropObj:SetValue(v); ChosenWeapons[3] = v
    end
    if WeaponLists[4] and #WeaponLists[4] > 0 then
        UtiDropObj:SetValues(WeaponLists[4])
        v = (prevVals[4] and table.find(WeaponLists[4], prevVals[4])) and prevVals[4] or UtiDropObj.Value
        UtiDropObj:SetValue(v); ChosenWeapons[4] = v
    end
end
function refreshWeapons()
    if not AutoLoadout_ItemLibrary or not AutoLoadout_FighterController then return end
    maxSlots = AutoLoadout_FighterController.LocalFighter and AutoLoadout_FighterController.LocalFighter:GetMaxEquippableWeapons() or 4
    for slotIndex = 1, maxSlots do
        weapons = {}
        classData = AutoLoadout_ItemLibrary.SlotToClass[slotIndex]
        className = classData and classData.Name
        if className then
            weaponPool = AutoLoadout_FighterController.LocalFighter and AutoLoadout_FighterController.LocalFighter:Get("WeaponPool") or {}
            filterType = AutoLoadout_FighterController.LocalFighter and AutoLoadout_FighterController.LocalFighter:Get("WeaponPoolFilterType") or ""
            for _, itemName in ipairs(AutoLoadout_ItemLibrary.ItemsAlphabetized) do
                itemData = AutoLoadout_ItemLibrary.Items[itemName]
                if itemData and itemData.Class == className then
                    isBlacklisted = (filterType == "Blacklist") and table.find(weaponPool, itemName)
                    canUse = AutoLoadout_FighterController.LocalFighter and AutoLoadout_FighterController.LocalFighter:CanUseWeapon(itemName)
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
lastAutoLoadoutTime = 0
function triggerAutoLoadout()
    if not autoLoadoutEnabled then return end
    if os.clock() - lastAutoLoadoutTime < 1 then return end
    lastAutoLoadoutTime = os.clock()
    validLoadout = {}
    maxSlots = AutoLoadout_FighterController and AutoLoadout_FighterController.LocalFighter and AutoLoadout_FighterController.LocalFighter:GetMaxEquippableWeapons() or 4
    index = 1
    for i = 1, maxSlots do 
        if ChosenWeapons[i] and ChosenWeapons[i] ~= "None" then
            validLoadout[index] = ChosenWeapons[i]
            index = index + 1
        end
    end
    duel = AutoLoadout_DuelController and AutoLoadout_DuelController:GetDuel(lp)
    if duel and duel.LocalDueler and duel.LocalDueler:GetStaggeredSpawnsTurn() then
        ReplicatedStorage.Remotes.Duels.PickWeaponsAheadOfTime:FireServer(validLoadout)
    else
        ReplicatedStorage.Remotes.Replication.Fighter.PickWeapons:FireServer(validLoadout)
    end
end
function enforceAutoLoadout()
    local function hideExpectedUI(guiObj)
        if not autoLoadoutEnabled then return end
        nameStr = string.lower(guiObj.Name)
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
    Modules = ReplicatedStorage:WaitForChild("Modules", 10)
    if Modules then AutoLoadout_ItemLibrary = require(Modules:WaitForChild("ItemLibrary", 10)) end
    playerScripts = lp:WaitForChild("PlayerScripts", 10)
    Controllers = playerScripts and playerScripts:WaitForChild("Controllers", 10)
    if Controllers then
        AutoLoadout_FighterController = require(Controllers:WaitForChild("FighterController", 10))
        AutoLoadout_DuelController = require(Controllers:WaitForChild("DuelController", 10))
    end
    task.wait(1)
    refreshWeapons()
    updateWeaponLabels()
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
end 
do
    changerLocalPlayer = lp
    local LeaderboardController
    pcall(function()
        LeaderboardController = require(changerLocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Controllers"):WaitForChild("LeaderboardController"))
    end)
    local SeasonLibrary
    pcall(function()
        SeasonLibrary = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("SeasonLibrary"))
    end)
    kCharmEloMap = {
        ["Unranked"] = -1,
        ["Bronze 1"] = 0,
        ["Bronze 2"] = 200,
        ["Bronze 3"] = 400,
        ["Silver 1"] = 600,
        ["Silver 2"] = 800,
        ["Silver 3"] = 1000,
        ["Gold 1"] = 1200,
        ["Gold 2"] = 1400,
        ["Gold 3"] = 1600,
        ["Platinum 1"] = 1800,
        ["Platinum 2"] = 2000,
        ["Platinum 3"] = 2200,
        ["Diamond 1"] = 2400,
        ["Diamond 2"] = 2600,
        ["Diamond 3"] = 2800,
        ["Onyx 1"] = 3000,
        ["Onyx 2"] = 3200,
        ["Onyx 3"] = 3400,
        ["Nemesis"] = 3600,
        ["Archnemesis"] = 3600,
    }
    kSeasonNameMap = {
        [0] = "Zero",
        [1] = "Warp",
        [2] = "Polar",
        [3] = "Fame",
        ["Zero"] = 0,
        ["Warp"] = 1,
        ["Polar"] = 2,
        ["Fame"] = 3,
    }
    kSeasonToggleMap = {
        [0] = "s0_charm",
        [1] = "s1_charm",
        [2] = "s2_charm",
        [3] = "s3_charm",
    }
    kCharmRanks = {
        "Use Spoofed ELO",
        "Unranked",
        "Bronze 1",
        "Bronze 2",
        "Bronze 3",
        "Silver 1",
        "Silver 2",
        "Silver 3",
        "Gold 1",
        "Gold 2",
        "Gold 3",
        "Platinum 1",
        "Platinum 2",
        "Platinum 3",
        "Diamond 1",
        "Diamond 2",
        "Diamond 3",
        "Onyx 1",
        "Onyx 2",
        "Onyx 3",
        "Nemesis",
        "Archnemesis",
    }
    changerStates = {
        avatar = {
            victim_username = changerLocalPlayer.Name,
            victim_user_id = changerLocalPlayer.UserId,
            spoof_avatar = false,
            spoof_thumbnails = false,
            thumb_spoof_conn = {},
        },
        leaderboard = {
            streak_value = changerLocalPlayer:GetAttribute("StatisticDuelsWinStreak") or 0,
            level_value = changerLocalPlayer:GetAttribute("Level") or 1,
            elo_value = 0,
            wins_value = 0,
            kills_value = 0,
            old_streak_value = changerLocalPlayer:GetAttribute("StatisticDuelsWinStreak"),
            old_level_value = changerLocalPlayer:GetAttribute("Level"),
            Streak = false,
            Level = false,
            ELO = false,
            Wins = false,
            Kills = false,
        },
        charm = {
            charm_rank = "Use Spoofed ELO",
            arch_rank = 1,
            s0_charm = false,
            s1_charm = false,
            s2_charm = false,
            s3_charm = false,
        },
        badges = {
            Premium = false,
            Verified = false,
            Influencer = false,
            Admin = false,
        },
        text = {
            display_name = false,
            display_name_value = changerLocalPlayer.DisplayName,
            username = false,
            username_value = changerLocalPlayer.Name,
            name_spoof_conn = {},
        }
    }
    changerConnections = {}
    local function changerBind(name, signal, fn)
        if changerConnections[name] then
            changerConnections[name]:Disconnect()
        end
        changerConnections[name] = signal:Connect(fn)
    end
    local function changerUnbind(name)
        if changerConnections[name] then
            changerConnections[name]:Disconnect()
            changerConnections[name] = nil
        end
    end
    local function FormatNumber(n)
        n = tostring(n)
        return n:reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
    end
    local function IsTextObject(obj)
        return obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")
    end
    local function ApplyNameSpoof(obj)
        if not IsTextObject(obj) then return end
        text = obj.Text
        if typeof(text) ~= "string" then return end
        if changerStates.text.display_name and obj.Name == "DisplayName" then
            text = text:gsub(changerLocalPlayer.DisplayName, changerStates.text.display_name_value)
        end
        if changerStates.text.username and obj.Name == "Username" then
            text = text:gsub(changerLocalPlayer.Name, changerStates.text.username_value)
        end
        if changerStates.text.display_name and obj.Parent and obj.Parent.Name == "NameContainer" and obj.Name == "Name" then
            text = text:gsub(changerLocalPlayer.DisplayName, changerStates.text.display_name_value)
        end
        if changerStates.text.username and obj.Parent and obj.Parent.Name == "NameContainer" and obj.Name == "Handle" then
            text = text:gsub(changerLocalPlayer.Name, changerStates.text.username_value)
        end
        if changerStates.text.display_name and obj.Parent and obj.Parent.Name == "Title" and obj.Name == "TitleText" then
            text = text:gsub(changerLocalPlayer.DisplayName, changerStates.text.display_name_value)
        end
        if changerStates.text.username and obj.Parent and obj.Parent.Name == "Subtitle" and obj.Name == "SubtitleText" then
            text = text:gsub(changerLocalPlayer.Name, changerStates.text.username_value)
        end
        if changerStates.text.display_name and (obj.Name == "HeaderText" or obj.Name == "Title") then
            text = text:gsub(changerLocalPlayer.DisplayName, changerStates.text.display_name_value)
        end
        if changerStates.leaderboard.Wins and obj.Name == "Wins" then
            text = FormatNumber(changerStates.leaderboard.wins_value)
        end
        if changerStates.leaderboard.Level and obj.Parent and obj.Parent.Name == "Level" and obj.Name == "Value" then
            text = FormatNumber(changerStates.leaderboard.level_value)
        end
        if changerStates.leaderboard.Streak and obj.Parent and obj.Parent.Name == "Streak" and obj.Name == "Value" then
            text = FormatNumber(changerStates.leaderboard.streak_value)
        end
        if obj.Text ~= text then
            obj.Text = text
        end
    end
    local function RefreshAllNameSpoofs()
        for obj, _ in pairs(changerStates.text.name_spoof_conn) do
            if obj and obj.Parent then
                ApplyNameSpoof(obj)
            end
        end
    end
    kAllowedText = {
        DisplayName = true,
        Username = true,
        Name = true,
        Handle = true,
        TitleText = true,
        SubtitleText = true,
        HeaderText = true,
        Title = true,
        Wins = true,
        Value = true,
    }
    local function RegisterTextObject(obj)
        if not kAllowedText[obj.Name] or not IsTextObject(obj) then return end
        ApplyNameSpoof(obj)
        if changerStates.text.name_spoof_conn[obj] then return end
        changerStates.text.name_spoof_conn[obj] = obj:GetPropertyChangedSignal("Text"):Connect(function()
            ApplyNameSpoof(obj)
        end)
        obj.Destroying:Connect(function()
            if changerStates.text.name_spoof_conn[obj] then
                changerStates.text.name_spoof_conn[obj]:Disconnect()
                changerStates.text.name_spoof_conn[obj] = nil
            end
        end)
    end
    task.spawn(function()
        pgui = lp:FindFirstChild("PlayerGui") or lp:WaitForChild("PlayerGui", 5)
        if pgui then
            for _, obj in ipairs(pgui:GetDescendants()) do
                RegisterTextObject(obj)
            end
            pgui.DescendantAdded:Connect(RegisterTextObject)
        end
        pcall(function()
            cg = game:GetService("CoreGui")
            for _, obj in ipairs(cg:GetDescendants()) do
                RegisterTextObject(obj)
            end
            cg.DescendantAdded:Connect(RegisterTextObject)
        end)
    end)
    local function BuildWeld(weld_name, parent, part0, part1, c0, c1)
        weld = Instance.new("Weld")
        weld.Name = weld_name
        weld.Part0 = part0
        weld.Part1 = part1
        weld.C0 = c0
        weld.C1 = c1
        weld.Parent = parent
        return weld
    end
    local function WeldAttachments(attach1, attach2)
        weld = Instance.new("Weld")
        weld.Part0 = attach1.Parent
        weld.Part1 = attach2.Parent
        weld.C0 = attach1.CFrame
        weld.C1 = attach2.CFrame
        weld.Parent = attach1.Parent
        return weld
    end
    local function FindFirstMatchingAttachment(model, name)
        for _, child in pairs(model:GetChildren()) do
            if child:IsA("Attachment") and child.Name == name then
                return child
            elseif not child:IsA("Accoutrement") and not child:IsA("Tool") then
                found = FindFirstMatchingAttachment(child, name)
                if found then return found end
            end
        end
    end
    local function FindHeadPart(instance)
        if not instance then return nil end
        if instance:IsA("BasePart") then return instance end
        head = instance:FindFirstChild("Head")
        if head and head:IsA("BasePart") then return head end
        for _, descendant in ipairs(instance:GetDescendants()) do
            if descendant:IsA("BasePart") and descendant.Name == "Head" then
                return descendant
            end
        end
        for _, descendant in ipairs(instance:GetDescendants()) do
            if descendant:IsA("BasePart") then
                return descendant
            end
        end
        return nil
    end
    local function CopyHeadVisuals(real_head, source_head)
        if not real_head or not source_head then return end
        if not real_head:IsA("BasePart") or not source_head:IsA("BasePart") then return end
        for _, child in ipairs(real_head:GetChildren()) do
            if child:IsA("Decal") or child:IsA("Texture") or child:IsA("SpecialMesh") or child:IsA("Mesh") then
                child:Destroy()
            end
        end
        real_head.Material = source_head.Material
        real_head.Color = source_head.Color
        real_head.Reflectance = source_head.Reflectance
        real_head.Transparency = source_head.Transparency
        real_head.LocalTransparencyModifier = source_head.LocalTransparencyModifier
        real_head.CastShadow = source_head.CastShadow
        real_head.CanCollide = false
        if real_head:IsA("MeshPart") and source_head:IsA("MeshPart") then
            real_head.MeshId = source_head.MeshId
            real_head.TextureID = source_head.TextureID
            real_head.Size = source_head.Size
        end
        for _, child in ipairs(source_head:GetChildren()) do
            if child:IsA("Decal") or child:IsA("Texture") or child:IsA("SpecialMesh") or child:IsA("Mesh") then
                clone = child:Clone()
                clone.Parent = real_head
            end
        end
    end
    local function ApplyFakeHead(character, source_head)
        if not character or not source_head then return end
        real_head = character:FindFirstChild("Head")
        if not real_head or not real_head:IsA("BasePart") then return end
        CopyHeadVisuals(real_head, source_head)
    end
    local function AddAccoutrement(character, accoutrement)
        accoutrement.Parent = character
        handle = accoutrement:FindFirstChild("Handle")
        if handle then
            attachment = handle:FindFirstChildOfClass("Attachment")
            if attachment then
                char_attachment = FindFirstMatchingAttachment(character, attachment.Name)
                if char_attachment then
                    WeldAttachments(char_attachment, attachment)
                end
            else
                head = character:FindFirstChild("Head")
                if head then
                    attachmentCFrame = CFrame.new(0, 0.5, 0)
                    hatCFrame = accoutrement.AttachmentPoint
                    BuildWeld("HeadWeld", head, head, handle, attachmentCFrame, hatCFrame)
                end
            end
        end
    end
    local function ApplyThumbnailSpoof(obj)
        if not obj:IsA("ImageLabel") then return end
        image = obj.Image
        if typeof(image) ~= "string" then return end
        if changerStates.avatar.spoof_thumbnails and changerStates.avatar.victim_user_id then
            myId = tostring(changerLocalPlayer.UserId)
            spoofId = tostring(changerStates.avatar.victim_user_id)
            if obj.Name == "AvatarThumbnail" or obj.Name == "Headshot" then
                image = image:gsub(myId, spoofId)
            elseif obj.Parent and obj.Parent.Name == "Thumbnail" and obj.Name == "ImageLabel" then
                image = image:gsub(myId, spoofId)
            end
        end
        if obj.Image ~= image then
            obj.Image = image
        end
    end
    local function RefreshAllThumbnailSpoofs()
        for obj, _ in pairs(changerStates.avatar.thumb_spoof_conn) do
            if obj and obj.Parent then
                ApplyThumbnailSpoof(obj)
            end
        end
    end
    kAllowedImage = {
        AvatarThumbnail = true,
        ImageLabel = true,
        Headshot = true
    }
    local function RegisterImageObject(obj)
        if not kAllowedImage[obj.Name] or not obj:IsA("ImageLabel") then return end
        ApplyThumbnailSpoof(obj)
        if changerStates.avatar.thumb_spoof_conn[obj] then return end
        changerStates.avatar.thumb_spoof_conn[obj] = obj:GetPropertyChangedSignal("Image"):Connect(function()
            ApplyThumbnailSpoof(obj)
        end)
        obj.Destroying:Connect(function()
            if changerStates.avatar.thumb_spoof_conn[obj] then
                changerStates.avatar.thumb_spoof_conn[obj]:Disconnect()
                changerStates.avatar.thumb_spoof_conn[obj] = nil
            end
        end)
    end
    task.spawn(function()
        pgui = lp:FindFirstChild("PlayerGui") or lp:WaitForChild("PlayerGui", 5)
        if pgui then
            for _, obj in ipairs(pgui:GetDescendants()) do
                RegisterImageObject(obj)
            end
            pgui.DescendantAdded:Connect(RegisterImageObject)
        end
        pcall(function()
            cg = game:GetService("CoreGui")
            for _, obj in ipairs(cg:GetDescendants()) do
                RegisterImageObject(obj)
            end
            cg.DescendantAdded:Connect(RegisterImageObject)
        end)
    end)
    local function SetAvatar(use_old)
        user_id = use_old and changerLocalPlayer.UserId or changerStates.avatar.victim_user_id
        if not user_id then return end
        char = changerLocalPlayer.Character or changerLocalPlayer.CharacterAdded:Wait()
        if not char or not char.Parent then return end
        local ok, rig_model = pcall(function()
            return Players:CreateHumanoidModelFromUserId(user_id)
        end)
        if not ok or not rig_model then return end
        for _, v in ipairs(char:GetDescendants()) do
            isFaceDecal = v:IsA("Decal") and v.Name == "face"
            if v:IsA("Accessory")
            or v:IsA("Shirt")
            or v:IsA("Pants")
            or v:IsA("ShirtGraphic")
            or v:IsA("BodyColors")
            or v:IsA("CharacterMesh")
            or v:IsA("LayeredClothing")
            or isFaceDecal then
                pcall(function() v:Destroy() end)
            end
        end
        for _, item in ipairs(rig_model:GetChildren()) do
            if item:IsA("Accessory") then
                pcall(function()
                    acc = item:Clone()
                    AddAccoutrement(char, acc)
                end)
            elseif item:IsA("Shirt")
            or item:IsA("Pants")
            or item:IsA("ShirtGraphic")
            or item:IsA("BodyColors")
            or item:IsA("LayeredClothing")
            or item:IsA("CharacterMesh") then
                pcall(function()
                    clone = item:Clone()
                    clone.Parent = char
                end)
            end
        end
        target_head = FindHeadPart(rig_model)
        if target_head then
            ApplyFakeHead(char, target_head)
            task.wait(0.1)
        end
        pcall(function() rig_model:Destroy() end)
    end
    local function SpoofAvatar()
        if changerStates.avatar.spoof_avatar then
            SetAvatar(false)
        else
            SetAvatar(true)
        end
    end
    changerLocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        if changerStates.avatar.spoof_avatar then
            SpoofAvatar()
        end
    end)
    local function ResolveUserId(input)
        if not input or input == "" then return nil end
        num = tonumber(input)
        if num and num > 1000 then return num end
        local success, resolvedId = pcall(function()
            return Players:GetUserIdFromNameAsync(tostring(input))
        end)
        if success and resolvedId then return resolvedId end
        return nil
    end
    local function InsertPlayerByValue(list, user_id, value)
        for i = #list, 1, -1 do
            if tonumber(list[i].key) == user_id then
                table.remove(list, i)
                break
            end
        end
        rank = 1
        for i, entry in ipairs(list) do
            if tonumber(entry.value) >= value then
                rank = i + 1
            else
                break
            end
        end
        table.insert(list, rank, {
            key = tostring(user_id),
            value = value,
        })
    end
    local function ResetLeaderboard(name, config_idx)
        if not LeaderboardController then return end
        changerUnbind(config_idx)
        serial = LeaderboardController.LeaderboardSerials and LeaderboardController.LeaderboardSerials[name]
        if serial and serial.Players then
            user_id = changerLocalPlayer.UserId
            for i = #serial.Players, 1, -1 do
                player = serial.Players[i]
                if player.UserId == user_id or player.UserID == user_id or player.PlayerId == user_id then
                    table.remove(serial.Players, i)
                end
            end
            if LeaderboardController.Refreshed then
                LeaderboardController.Refreshed:Fire(name)
            end
        end
    end
    local function ModifyLeaderboard(config_idx, name, value)
        if not LeaderboardController then return end
        task.spawn(function()
            timeout = tick() + 5
            while (not LeaderboardController.LeaderboardSerials
                or not LeaderboardController.LeaderboardSerials[name]
                or not LeaderboardController.LeaderboardSerials[name].Players
                or #LeaderboardController.LeaderboardSerials[name].Players <= 0) and tick() < timeout do
                task.wait(0.5)
            end
            user_id = changerLocalPlayer.UserId
            serial = LeaderboardController.LeaderboardSerials and LeaderboardController.LeaderboardSerials[name]
            if serial and serial.Players then
                InsertPlayerByValue(serial.Players, user_id, value)
                if LeaderboardController.Refreshed then
                    LeaderboardController.Refreshed:Fire(name)
                end
            end
            UpdateRemote = ReplicatedStorage:FindFirstChild("Remotes")
                and ReplicatedStorage.Remotes:FindFirstChild("Misc")
                and ReplicatedStorage.Remotes.Misc:FindFirstChild("UpdateLeaderboard")
            if UpdateRemote and UpdateRemote:IsA("RemoteEvent") then
                changerBind(config_idx, UpdateRemote.OnClientEvent, function(data)
                    lb_name = data and data.Name
                    if not lb_name or lb_name ~= name then return end
                    if not changerStates.leaderboard[config_idx] then return end
                    task.defer(function()
                        s = LeaderboardController.LeaderboardSerials and LeaderboardController.LeaderboardSerials[name]
                        if s and s.Players then
                            InsertPlayerByValue(s.Players, user_id, value)
                            if LeaderboardController.Refreshed then
                                LeaderboardController.Refreshed:Fire(name)
                            end
                        end
                    end)
                end)
            end
        end)
    end
    local function UpdateLeaderboardOptions()
        if changerStates.leaderboard.ELO then
            changerUnbind("ELO")
            ModifyLeaderboard("ELO", "Highest ELO", changerStates.leaderboard.elo_value)
        else
            ResetLeaderboard("Highest ELO", "ELO")
        end
        if changerStates.leaderboard.Streak then
            changerUnbind("Streak")
            ModifyLeaderboard("Streak", "Current Highest Win Streak", changerStates.leaderboard.streak_value)
            changerStates.leaderboard.old_streak_value = changerStates.leaderboard.old_streak_value or changerLocalPlayer:GetAttribute("StatisticDuelsWinStreak")
            changerLocalPlayer:SetAttribute("StatisticDuelsWinStreak", changerStates.leaderboard.streak_value)
        else
            ResetLeaderboard("Current Highest Win Streak", "Streak")
            if changerStates.leaderboard.old_streak_value ~= nil then
                changerLocalPlayer:SetAttribute("StatisticDuelsWinStreak", changerStates.leaderboard.old_streak_value)
            end
        end
        if changerStates.leaderboard.Kills then
            changerUnbind("Kills")
            ModifyLeaderboard("Kills", "Most Eliminations", changerStates.leaderboard.kills_value)
        else
            ResetLeaderboard("Most Eliminations", "Kills")
        end
        if changerStates.leaderboard.Wins then
            changerUnbind("Wins")
            ModifyLeaderboard("Wins", "Most Wins", changerStates.leaderboard.wins_value)
        else
            ResetLeaderboard("Most Wins", "Wins")
        end
        if changerStates.leaderboard.Level then
            changerUnbind("Level")
            ModifyLeaderboard("Level", "Highest Level", changerStates.leaderboard.level_value)
            changerStates.leaderboard.old_level_value = changerStates.leaderboard.old_level_value or changerLocalPlayer:GetAttribute("Level")
            changerLocalPlayer:SetAttribute("Level", changerStates.leaderboard.level_value)
        else
            ResetLeaderboard("Highest Level", "Level")
            if changerStates.leaderboard.old_level_value ~= nil then
                changerLocalPlayer:SetAttribute("Level", changerStates.leaderboard.old_level_value)
            end
        end
    end
    if SeasonLibrary and SeasonLibrary.FormatSeasonRankCharm then
        original_fsrc = SeasonLibrary.FormatSeasonRankCharm
        SeasonLibrary.FormatSeasonRankCharm = function(self, p2, p3, p4, p5)
            season_num = kSeasonNameMap[p3]
            elo = kCharmEloMap[changerStates.charm.charm_rank] or changerStates.leaderboard.elo_value
            if season_num and kSeasonToggleMap[season_num] and changerStates.charm[kSeasonToggleMap[season_num]] then
                p4 = elo or p4
                p5 = changerStates.charm.arch_rank
            end
            return original_fsrc(self, p2, p3, p4, p5)
        end
    end
    local function UpdateCharmOptions()
        task.wait(0.2)
        local function checkModel(m)
            if not m then return end
            for _, descendant in ipairs(m:GetDescendants()) do
                if descendant:IsA("Model") and descendant:FindFirstChild("Extra") then
                    name = descendant.Name
                    if string.sub(name, 1, 7) == "Season " then
                        season_num = tonumber(string.sub(name, 8))
                        if season_num and kSeasonToggleMap[season_num] and changerStates.charm[kSeasonToggleMap[season_num]] then
                            season_name = kSeasonNameMap[season_num]
                            if season_name and SeasonLibrary and SeasonLibrary.FormatSeasonRankCharm then
                                elo = kCharmEloMap[changerStates.charm.charm_rank] or changerStates.leaderboard.elo_value
                                rank = changerStates.charm.arch_rank
                                pcall(function()
                                    SeasonLibrary:FormatSeasonRankCharm(descendant, season_name, elo, rank)
                                end)
                            end
                        end
                    end
                end
            end
        end
        vm = workspace:FindFirstChild("ViewModels")
        if vm then
            for _, child in ipairs(vm:GetChildren()) do checkModel(child) end
        end
        for _, plr in ipairs(Players:GetPlayers()) do
            checkModel(plr.Character)
        end
    end
    if hookmetamethod and not getgenv()._BadgesHooked then
        getgenv()._BadgesHooked = true
        local old_index; old_index = hookmetamethod(game, "__index", newcclosure(function(self, key)
            if not checkcaller() and self == changerLocalPlayer then
                if key == "MembershipType" and changerStates.badges.Premium then
                    return Enum.MembershipType.Premium
                end
                if key == "HasVerifiedBadge" and changerStates.badges.Verified then
                    return true
                end
            end
            return old_index(self, key)
        end))
    end
    local function UpdateBadgesOptions()
        changerLocalPlayer:SetAttribute("IsInfluencer", changerStates.badges.Influencer and true or false)
        changerLocalPlayer:SetAttribute("IsRobloxEmployee", changerStates.badges.Admin and true or false)
    end
    AvatarGroup = Tabs.Changer:AddLeftGroupbox("Avatar Changer")
    AvatarGroup:AddInput("VictimUsername", {
        Default = changerLocalPlayer.Name,
        Numeric = false,
        Finished = true,
        Text = "Target Username",
        Tooltip = "Enter target Roblox Username (or UserId) to copy avatar from",
        Placeholder = "Enter Username...",
        Callback = function(val)
            task.spawn(function()
                resolvedId = ResolveUserId(val)
                if resolvedId then
                    changerStates.avatar.victim_username = val
                    changerStates.avatar.victim_user_id = resolvedId
                    if changerStates.avatar.spoof_avatar then
                        SpoofAvatar()
                    end
                    RefreshAllThumbnailSpoofs()
                    if Library and Library.Notify then
                        Library:Notify("Avatar target: " .. tostring(val) .. " (" .. tostring(resolvedId) .. ")", 3)
                    end
                else
                    if Library and Library.Notify then
                        Library:Notify("User not found: " .. tostring(val), 3)
                    end
                end
            end)
        end
    })
    AvatarGroup:AddToggle("SpoofAvatarToggle", {
        Text = "Spoof Character Avatar",
        Default = false,
        Tooltip = "Copies accessories, clothing, and head from target user",
        Callback = function(val)
            changerStates.avatar.spoof_avatar = val
            SpoofAvatar()
        end
    })
    AvatarGroup:AddToggle("SpoofThumbnailsToggle", {
        Text = "Spoof Avatar Thumbnails",
        Default = false,
        Tooltip = "Replaces in-game thumbnail icons with target user's avatar",
        Callback = function(val)
            changerStates.avatar.spoof_thumbnails = val
            RefreshAllThumbnailSpoofs()
        end
    })
    AvatarGroup:AddButton("Re-apply Avatar", function()
        SpoofAvatar()
        RefreshAllThumbnailSpoofs()
    end)
    CharmGroup = Tabs.Changer:AddLeftGroupbox("Rank & Charm Changer")
    CharmGroup:AddDropdown("CharmRankDropdown", {
        Values = kCharmRanks,
        Default = 1,
        Multi = false,
        Text = "Charm Rank",
        Tooltip = "Choose rank for season charms (or use spoofed ELO)",
        Callback = function(val)
            changerStates.charm.charm_rank = val
            UpdateCharmOptions()
        end
    })
    CharmGroup:AddSlider("ArchRankSlider", {
        Text = "Arch Rank",
        Default = 1,
        Min = 1,
        Max = 100,
        Rounding = 0,
        Compact = false,
        Callback = function(val)
            changerStates.charm.arch_rank = math.floor(val)
            UpdateCharmOptions()
        end
    })
    CharmGroup:AddToggle("S0CharmToggle", {
        Text = "Season 0 Charm",
        Default = false,
        Callback = function(val)
            changerStates.charm.s0_charm = val
            UpdateCharmOptions()
        end
    })
    CharmGroup:AddToggle("S1CharmToggle", {
        Text = "Season 1 Charm",
        Default = false,
        Callback = function(val)
            changerStates.charm.s1_charm = val
            UpdateCharmOptions()
        end
    })
    CharmGroup:AddToggle("S2CharmToggle", {
        Text = "Season 2 Charm",
        Default = false,
        Callback = function(val)
            changerStates.charm.s2_charm = val
            UpdateCharmOptions()
        end
    })
    CharmGroup:AddToggle("S3CharmToggle", {
        Text = "Season 3 Charm",
        Default = false,
        Callback = function(val)
            changerStates.charm.s3_charm = val
            UpdateCharmOptions()
        end
    })
    CharmGroup:AddButton("Update Workspace Charms", function()
        UpdateCharmOptions()
    end)
    StatsGroup = Tabs.Changer:AddRightGroupbox("Stats & Leaderboard Changer")
    StatsGroup:AddInput("StreakInput", {
        Default = tostring(changerStates.leaderboard.streak_value),
        Numeric = true,
        Finished = true,
        Text = "Streak Value",
        Placeholder = "Enter streak...",
        Callback = function(val)
            changerStates.leaderboard.streak_value = tonumber(val) or 0
            if changerStates.leaderboard.Streak then
                UpdateLeaderboardOptions()
                RefreshAllNameSpoofs()
            end
        end
    })
    StatsGroup:AddToggle("StreakToggle", {
        Text = "Spoof Win Streak",
        Default = false,
        Callback = function(val)
            changerStates.leaderboard.Streak = val
            UpdateLeaderboardOptions()
            RefreshAllNameSpoofs()
        end
    })
    StatsGroup:AddDivider()
    StatsGroup:AddInput("LevelInput", {
        Default = tostring(changerStates.leaderboard.level_value),
        Numeric = true,
        Finished = true,
        Text = "Level Value",
        Placeholder = "Enter level...",
        Callback = function(val)
            changerStates.leaderboard.level_value = tonumber(val) or 1
            if changerStates.leaderboard.Level then
                UpdateLeaderboardOptions()
                RefreshAllNameSpoofs()
            end
        end
    })
    StatsGroup:AddToggle("LevelToggle", {
        Text = "Spoof Level",
        Default = false,
        Callback = function(val)
            changerStates.leaderboard.Level = val
            UpdateLeaderboardOptions()
            RefreshAllNameSpoofs()
        end
    })
    StatsGroup:AddDivider()
    StatsGroup:AddInput("ELOInput", {
        Default = "0",
        Numeric = true,
        Finished = true,
        Text = "ELO Value",
        Placeholder = "Enter ELO...",
        Callback = function(val)
            changerStates.leaderboard.elo_value = tonumber(val) or 0
            if changerStates.leaderboard.ELO then
                UpdateLeaderboardOptions()
            end
            UpdateCharmOptions()
        end
    })
    StatsGroup:AddToggle("ELOToggle", {
        Text = "Spoof Leaderboard ELO",
        Default = false,
        Callback = function(val)
            changerStates.leaderboard.ELO = val
            UpdateLeaderboardOptions()
        end
    })
    StatsGroup:AddDivider()
    StatsGroup:AddInput("WinsInput", {
        Default = "0",
        Numeric = true,
        Finished = true,
        Text = "Wins Value",
        Placeholder = "Enter wins...",
        Callback = function(val)
            changerStates.leaderboard.wins_value = tonumber(val) or 0
            if changerStates.leaderboard.Wins then
                UpdateLeaderboardOptions()
                RefreshAllNameSpoofs()
            end
        end
    })
    StatsGroup:AddToggle("WinsToggle", {
        Text = "Spoof Wins",
        Default = false,
        Callback = function(val)
            changerStates.leaderboard.Wins = val
            UpdateLeaderboardOptions()
            RefreshAllNameSpoofs()
        end
    })
    StatsGroup:AddDivider()
    StatsGroup:AddInput("KillsInput", {
        Default = "0",
        Numeric = true,
        Finished = true,
        Text = "Kills Value",
        Placeholder = "Enter kills...",
        Callback = function(val)
            changerStates.leaderboard.kills_value = tonumber(val) or 0
            if changerStates.leaderboard.Kills then
                UpdateLeaderboardOptions()
            end
        end
    })
    StatsGroup:AddToggle("KillsToggle", {
        Text = "Spoof Kills",
        Default = false,
        Callback = function(val)
            changerStates.leaderboard.Kills = val
            UpdateLeaderboardOptions()
        end
    })
    BadgesGroup = Tabs.Changer:AddRightGroupbox("Profile & Badges")
    BadgesGroup:AddInput("DisplayNameInput", {
        Default = changerLocalPlayer.DisplayName,
        Numeric = false,
        Finished = true,
        Text = "Display Name",
        Placeholder = "Enter new display name...",
        Callback = function(val)
            changerStates.text.display_name_value = val
            if changerStates.text.display_name then
                RefreshAllNameSpoofs()
            end
        end
    })
    BadgesGroup:AddToggle("DisplayNameToggle", {
        Text = "Spoof Display Name",
        Default = false,
        Callback = function(val)
            changerStates.text.display_name = val
            RefreshAllNameSpoofs()
        end
    })
    BadgesGroup:AddDivider()
    BadgesGroup:AddInput("UsernameInput", {
        Default = changerLocalPlayer.Name,
        Numeric = false,
        Finished = true,
        Text = "Username",
        Placeholder = "Enter new username...",
        Callback = function(val)
            changerStates.text.username_value = val
            if changerStates.text.username then
                RefreshAllNameSpoofs()
            end
        end
    })
    BadgesGroup:AddToggle("UsernameToggle", {
        Text = "Spoof Username",
        Default = false,
        Callback = function(val)
            changerStates.text.username = val
            RefreshAllNameSpoofs()
        end
    })
    BadgesGroup:AddDivider()
    BadgesGroup:AddToggle("PremiumToggle", {
        Text = "Premium Membership",
        Default = false,
        Callback = function(val)
            changerStates.badges.Premium = val
        end
    })
    BadgesGroup:AddToggle("VerifiedToggle", {
        Text = "Verified Badge",
        Default = false,
        Callback = function(val)
            changerStates.badges.Verified = val
        end
    })
    BadgesGroup:AddToggle("InfluencerToggle", {
        Text = "Influencer Badge",
        Default = false,
        Callback = function(val)
            changerStates.badges.Influencer = val
            UpdateBadgesOptions()
        end
    })
    BadgesGroup:AddToggle("AdminToggle", {
        Text = "Roblox Employee (Admin)",
        Default = false,
        Callback = function(val)
            changerStates.badges.Admin = val
            UpdateBadgesOptions()
        end
    })
    UnlockGroup = Tabs.Changer:AddLeftGroupbox("Unlock All (Client-Side)")
    unlockAllEnabled = false
    origGetUnlockedWeapons = nil
    origGetWeaponData = nil
    origOwnsAllWeapons = nil
    local function applyUnlockAllHook()
        PlayerDataController = nil
        pcall(function()
            PlayerDataController = require(lp:WaitForChild("PlayerScripts"):WaitForChild("Controllers"):WaitForChild("PlayerDataController"))
        end)
        if not PlayerDataController then return end
        PlayerDataUtility = nil
        pcall(function()
            PlayerDataUtility = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PlayerDataUtility"))
        end)
        ItemLibrary = nil
        pcall(function()
            ItemLibrary = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ItemLibrary"))
        end)
        ShopLibrary = nil
        pcall(function()
            ShopLibrary = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ShopLibrary"))
        end)
        local function getAllWeaponList()
            list = {}
            if ShopLibrary and ShopLibrary.OwnableWeapons then
                for _, w in pairs(ShopLibrary.OwnableWeapons) do
                    list[w] = true
                end
            elseif ItemLibrary and ItemLibrary.Items then
                for name, data in pairs(ItemLibrary.Items) do
                    if data.Type == "Weapon" or data.Class then
                        list[name] = true
                    end
                end
            end
            return list
        end
        local function createFakeWeaponData(wName)
            return {
                Name = wName,
                Level = 100,
                XP = 0,
                Kills = 0,
                Headshots = 0,
                IsFavorited = false,
                Unlocked = true
            }
        end
        if PlayerDataUtility then
            if not origGetUnlockedWeapons then
                origGetUnlockedWeapons = PlayerDataUtility.GetUnlockedWeapons
                PlayerDataUtility.GetUnlockedWeapons = function(self, ...)
                    if unlockAllEnabled then
                        return getAllWeaponList()
                    end
                    return origGetUnlockedWeapons(self, ...)
                end
            end
            if not origGetWeaponData then
                origGetWeaponData = PlayerDataUtility.GetWeaponData
                PlayerDataUtility.GetWeaponData = function(self, wName, ...)
                    real = origGetWeaponData(self, wName, ...)
                    if unlockAllEnabled and not real and wName then
                        return createFakeWeaponData(wName)
                    end
                    return real
                end
            end
            if not origOwnsAllWeapons then
                origOwnsAllWeapons = PlayerDataUtility.OwnsAllWeapons
                PlayerDataUtility.OwnsAllWeapons = function(self, ...)
                    if unlockAllEnabled then
                        return true
                    end
                    return origOwnsAllWeapons(self, ...)
                end
            end
        end
        if PlayerDataController then
            if not PlayerDataController._OrigGetUnlockedWeapons then
                PlayerDataController._OrigGetUnlockedWeapons = PlayerDataController.GetUnlockedWeapons
                PlayerDataController.GetUnlockedWeapons = function(self, ...)
                    if unlockAllEnabled then
                        return getAllWeaponList()
                    end
                    return PlayerDataController._OrigGetUnlockedWeapons(self, ...)
                end
            end
            if not PlayerDataController._OrigGetWeaponData then
                PlayerDataController._OrigGetWeaponData = PlayerDataController.GetWeaponData
                PlayerDataController.GetWeaponData = function(self, wName, ...)
                    real = PlayerDataController._OrigGetWeaponData(self, wName, ...)
                    if unlockAllEnabled and not real and wName then
                        return createFakeWeaponData(wName)
                    end
                    return real
                end
            end
        end
        pcall(function()
            UserInterface = lp:WaitForChild("PlayerScripts"):WaitForChild("UserInterface")
            Equipment = UserInterface:FindFirstChild("Equipment")
            if Equipment then
                eqModule = require(Equipment)
                if eqModule and eqModule.Left and eqModule.Left._Generate then
                    eqModule.Left:_Generate()
                end
            end
        end)
    end
    UnlockGroup:AddToggle("UnlockAllWeaponsToggle", {
        Text = "Unlock All Weapons",
        Default = false,
        Tooltip = "Client-side unlock all weapons in inventory and equipment UI",
        Callback = function(val)
            unlockAllEnabled = val
            applyUnlockAllHook()
        end
    })
    UnlockGroup:AddButton("Refresh Equipment UI", function()
        applyUnlockAllHook()
    end)
end 
currentKey = getgenv().SCRIPT_KEY or ""
pastebinCode = 'getgenv().SCRIPT_KEY = "' .. currentKey .. '"\nloadstring(game:HttpGet("https://api.jnkie.com/api/v1/luascripts/public/f0284445bd8656e53305c6b904839599390904cda3542684eebf5ada872f6b90/download"))()'

pcall(function()
    if queue_on_teleport then
        queue_on_teleport(pastebinCode)
    elseif syn and syn.queue_on_teleport then
        syn.queue_on_teleport(pastebinCode)
    end
end)

SaveManager:SetLibrary(Library)
SaveManager:SetFolder("KETY")
SaveManager:IgnoreThemeSettings()
SaveManager:BuildConfigSection(Tabs.Config)
SaveManager:LoadAutoloadConfig()
getgenv().ModpackLoaded = true
if not getgenv().DeviceSpoofEnabled and getgenv()._LastPendingControls then
    pcall(function()
        ReplicatedStorage.Remotes.Replication.Fighter.SetControls:FireServer(getgenv()._LastPendingControls)
    end)
end
