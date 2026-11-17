--[[
	WARNING: Heads up! This script has not been verified by ScriptBlox. Use at your own risk!
]]

--// Config



if not game:IsLoaded() then game.Loaded:Wait() end

-- require後にスレッド権限・Capabilityが下がる問題の対策（キャッシュ＋Identity8維持）
local _fixId = function() end
local require = require
do
    if not getgenv()._KETY_OrigRequire then
        getgenv()._KETY_OrigRequire = require
    end
    local _origRequire = getgenv()._KETY_OrigRequire
    if not getgenv()._KETY_ReqCache then
        getgenv()._KETY_ReqCache = {}
    end
    local _reqCache = getgenv()._KETY_ReqCache
    local _si = setthreadidentity or set_thread_identity or setidentity or (syn and syn.set_thread_identity)
    _fixId = function()
        if _si then
            pcall(_si, 8)
        end
    end
    _fixId()
    require = function(mod, ...)
        if mod ~= nil and _reqCache[mod] ~= nil then
            return _reqCache[mod]
        end
        _fixId()
        local res = table.pack(pcall(_origRequire, mod, ...))
        _fixId()
        if not res[1] then
            error(res[2], 2)
        end
        if mod ~= nil and res[2] ~= nil then
            _reqCache[mod] = res[2]
        end
        return table.unpack(res, 2, res.n)
    end
end
pcall(function() if clearconsole then clearconsole() end end)
pcall(function() if rconsoleclear then rconsoleclear() end end)
pcall(function()
    local LogService = game:GetService("LogService")
    if LogService and LogService.Clear then LogService:Clear() end
end)


-- ========== SETCONTROLS BLOCKING & SPEEDUP INITIALIZATION ==========
getgenv().ModpackLoaded = false
getgenv().DeviceSpoofEnabled = false
getgenv().DeviceSpoofValue = "Touch"
getgenv()._LastPendingControls = nil

-- 単一の __namecall ディスパッチャ（再実行時は既存チェーンをクリアして最新フックに差し替え）
if type(getgenv()._KETY_NCChains) == "table" then
    table.clear(getgenv()._KETY_NCChains)
    getgenv()._SetControlsHooked = false
    getgenv()._SilentNCHooked = false
    getgenv()._ragebotCamHooked = false
    getgenv()._antiAimHooked = false
    getgenv().OOBHookExecuted = false
end
if not getgenv()._KETY_NCChains and hookmetamethod and newcclosure then
    local chains = {}
    getgenv()._KETY_NCChains = chains
    local realOld
    local function callReal(self, ...) return realOld(self, ...) end
    realOld = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local ch = chains[getnamecallmethod()]
        if ch then return ch(self, ...) end
        return realOld(self, ...)
    end))
    getgenv().KETY_HookNamecall = function(methods, make)
        for i = 1, #methods do
            local m = methods[i]
            chains[m] = make(chains[m] or callReal)
        end
    end
end

if not getgenv()._SetControlsHooked and getgenv().KETY_HookNamecall then
    getgenv()._SetControlsHooked = true
    local _setCtrlRemote = nil
    task.spawn(function()
        pcall(function()
            _setCtrlRemote = game:GetService("ReplicatedStorage"):WaitForChild("Remotes", 10):WaitForChild("Replication", 10):WaitForChild("Fighter", 10):WaitForChild("SetControls", 10)
        end)
    end)
    getgenv().KETY_HookNamecall({"FireServer", "fireServer", "fireserver"}, function(old)
        return function(self, ...)
            if _setCtrlRemote and self == _setCtrlRemote then
                if not getgenv().ModpackLoaded then
                    getgenv()._LastPendingControls = ...
                    return nil
                end
                if getgenv().DeviceSpoofEnabled and getgenv().DeviceSpoofValue then
                    if checkcaller and not checkcaller() then
                        return old(self, getgenv().DeviceSpoofValue)
                    end
                end
            end
            return old(self, ...)
        end
    end)
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local _RealRunService = game:GetService("RunService")
local _RealUIS = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local lp = Players.LocalPlayer
while not lp do
    task.wait(0.05)
    lp = Players.LocalPlayer
end
local PlayerGui = lp:WaitForChild("PlayerGui")

if PlayerGui:FindFirstChild("LoadingScreen") then
    repeat task.wait(0.05) until not PlayerGui:FindFirstChild("LoadingScreen")
end

-- 過去実行分の接続を完全破棄＆以降の接続を自動追跡
if getgenv()._KETY_Conns then
    for _, c in ipairs(getgenv()._KETY_Conns) do
        pcall(function() c:Disconnect() end)
    end
end
getgenv()._KETY_Conns = {}
local _ketyConns = getgenv()._KETY_Conns

local function _wrapSignal(sig)
    return setmetatable({}, {
        __index = function(_, k)
            if k == "Connect" or k == "connect" then
                return function(_, fn)
                    local c = sig:Connect(function(...)
                        _fixId()
                        return fn(...)
                    end)
                    _ketyConns[#_ketyConns + 1] = c
                    return c
                end
            elseif k == "Once" or k == "once" then
                return function(_, fn)
                    local c = sig:Once(function(...)
                        _fixId()
                        return fn(...)
                    end)
                    _ketyConns[#_ketyConns + 1] = c
                    return c
                end
            elseif k == "Wait" or k == "wait" then
                return function() return sig:Wait() end
            end
            local v = sig[k]
            if type(v) == "function" then
                return function(_, ...) return v(sig, ...) end
            end
            return v
        end
    })
end

local RunService = setmetatable({
    RenderStepped = _wrapSignal(_RealRunService.RenderStepped),
    Heartbeat = _wrapSignal(_RealRunService.Heartbeat),
    Stepped = _wrapSignal(_RealRunService.Stepped),
}, {
    __index = function(_, k)
        local v = _RealRunService[k]
        if type(v) == "function" then
            return function(_, ...) return v(_RealRunService, ...) end
        end
        return v
    end
})

local boundRenderSteps = {}
local function safeBindToRenderStep(rs, name, priority, func)
    local wrapped = function(...)
        _fixId()
        return func(...)
    end
    if type(_RealRunService.BindToRenderStep) == "function" then
        pcall(function() _RealRunService:BindToRenderStep(name, priority, wrapped) end)
    else
        if boundRenderSteps[name] then boundRenderSteps[name]:Disconnect() end
        boundRenderSteps[name] = RunService.RenderStepped:Connect(wrapped)
    end
end
local function safeUnbindFromRenderStep(rs, name)
    if type(_RealRunService.UnbindFromRenderStep) == "function" then
        pcall(function() _RealRunService:UnbindFromRenderStep(name) end)
    end
    if boundRenderSteps[name] then
        boundRenderSteps[name]:Disconnect()
        boundRenderSteps[name] = nil
    end
end

-- 多重ロード防止（5秒以内に連続で実行された場合は弾く）
if getgenv().KETY_Executing then return end
getgenv().KETY_Executing = true
task.delay(5, function() getgenv().KETY_Executing = false end)

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
if getgenv().MyKETYESP then
    pcall(function() getgenv().MyKETYESP:Destroy() end)
end
if getgenv().KETY_NoArmConnection then
    pcall(function() getgenv().KETY_NoArmConnection:Disconnect() end)
    getgenv().KETY_NoArmConnection = nil
end
if getgenv().KETY_HideCharConnection then
    pcall(function() getgenv().KETY_HideCharConnection:Disconnect() end)
    getgenv().KETY_HideCharConnection = nil
end
if getgenv().KETY_HideCharAddedConnection then
    pcall(function() getgenv().KETY_HideCharAddedConnection:Disconnect() end)
    getgenv().KETY_HideCharAddedConnection = nil
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

-- ========== SILENT AIM CONFIG ==========
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

-- 共通TeamCheck: 自分と同じ試合の敵だけtrue（ロビー/別試合/TeamID不明はfalse）
local _kSpectate = nil
getgenv().KETY_IsEnemy = function(plr)
    if not plr or plr == lp then return false end
    if not _kSpectate then
        pcall(function()
            _kSpectate = require(lp.PlayerScripts.Controllers.SpectateController)
        end)
    end
    if _kSpectate then
        local duel = _kSpectate.CurrentDuelSubject
        if duel then
            local byPlr = rawget(duel, "_duelers_by_player")
            if byPlr then
                local localDueler = byPlr[lp]
                local targetDueler = byPlr[plr]
                if localDueler and targetDueler then
                    local lt = localDueler:Get("TeamID")
                    if lt ~= nil then
                        return targetDueler:Get("TeamID") ~= lt
                    end
                elseif localDueler then
                    return false
                end
            end
            local localDueler = duel:GetDueler(lp)
            local localTeam = localDueler and localDueler:Get("TeamID") or nil
            if localTeam and duel.Duelers then
                for _, dueler in next, duel.Duelers do
                    if dueler.Player == plr then
                        return dueler:Get("TeamID") ~= localTeam
                    end
                end
                return false
            end
        end
    end
    local myID, theirID = lp:GetAttribute("TeamID"), plr:GetAttribute("TeamID")
    if myID == nil or theirID == nil then return false end
    return myID ~= theirID
end

-- 共通WallCheck: カメラからtargetPosへの直線上に壁があればtrue
local _kWallParams = RaycastParams.new()
_kWallParams.FilterType = Enum.RaycastFilterType.Exclude
_kWallParams.IgnoreWater = true
getgenv().KETY_IsBehindWall = function(targetPos, targetChar, ignoreTransparent)
    local cam = workspace.CurrentCamera
    if not cam or not targetPos then return false end
    local ign = { cam }
    if lp.Character then table.insert(ign, lp.Character) end
    if targetChar then table.insert(ign, targetChar) end
    _kWallParams.FilterDescendantsInstances = ign
    local origin = cam.CFrame.Position
    local ok, result = pcall(workspace.Raycast, workspace, origin, targetPos - origin, _kWallParams)
    if not (ok and result and result.Instance) then return false end
    if ignoreTransparent and result.Instance.Transparency >= 0.8 then return false end
    return true
end

-- 共通TargetPart: Hitbox4種 + R15全パーツ
local _kParts = {
    "HitboxHead", "HitboxHeadSmall", "HitboxBody", "HitboxBodySmall",
    "Head", "UpperTorso", "LowerTorso", "HumanoidRootPart",
    "LeftUpperArm", "LeftLowerArm", "LeftHand",
    "RightUpperArm", "RightLowerArm", "RightHand",
    "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
    "RightUpperLeg", "RightLowerLeg", "RightFoot",
}
getgenv().KETY_TargetParts = _kParts
getgenv().KETY_TargetPartValues = { "HitboxHead", "HitboxHeadSmall", "HitboxBody", "HitboxBodySmall", "Random", "Closest" }
for i = 5, #_kParts do table.insert(getgenv().KETY_TargetPartValues, _kParts[i]) end

-- mode: 部位名 / "Random" / "Closest"（Closestはcam,mousePos省略時は現在のカメラ/マウス）
getgenv().KETY_ResolveTargetPart = function(char, mode, cam, mousePos)
    if not char then return nil end
    local fallback = char:FindFirstChild("HitboxHead") or char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    if mode == "Random" then
        local valid = {}
        for _, n in ipairs(_kParts) do
            local p = char:FindFirstChild(n)
            if p and p:IsA("BasePart") then table.insert(valid, p) end
        end
        return valid[math.random(1, math.max(#valid, 1))] or fallback
    elseif mode == "Closest" then
        cam = cam or workspace.CurrentCamera
        mousePos = mousePos or game:GetService("UserInputService"):GetMouseLocation()
        local best, bestDist = nil, math.huge
        for _, n in ipairs(_kParts) do
            local p = char:FindFirstChild(n)
            if p and p:IsA("BasePart") and cam then
                local sp, on = cam:WorldToViewportPoint(p.Position)
                if on and sp.Z > 0 then
                    local d = (Vector2.new(sp.X, sp.Y) - mousePos).Magnitude
                    if d < bestDist then bestDist, best = d, p end
                end
            end
        end
        return best or fallback
    end
    return char:FindFirstChild(mode) or fallback
end

local function checkTeam(plr, isESP)
    if not plr then return false end
    if plr == lp then return false end
    local tc = isESP and getgenv().ESPSettings_TeamCheck or (getgenv().SilentConfig and getgenv().SilentConfig.TeamCheck)
    if not tc then return true end
    return getgenv().KETY_IsEnemy(plr)
end

-- ========== SILENT AIM (Raycast Hook) ==========
do
    local UserInputService = game:GetService("UserInputService")
    local rawRaycast = workspace.Raycast
    local isInsideRaycastHook = false

    local staticRayParams = RaycastParams.new()
    staticRayParams.FilterType = Enum.RaycastFilterType.Exclude
    staticRayParams.IgnoreWater = true

    local wallCheckRayParams = RaycastParams.new()
    wallCheckRayParams.FilterType = Enum.RaycastFilterType.Exclude
    wallCheckRayParams.IgnoreWater = true


    local function getClosestTarget(maxFOV, partMode)
        local cfg = getgenv().SilentConfig
        local closest, closestDist = nil, (maxFOV == 100 and 500 or (maxFOV or 300))
        local mousePos = UserInputService:GetMouseLocation()
        local myChar = lp.Character
        local curCam = workspace.CurrentCamera
        if not curCam then return nil end

        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= lp and checkTeam(p, false) then
                local char = p.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local root = char and char:FindFirstChild("HumanoidRootPart")

                if char and hum and hum.Health > 0 and root then
                    local hitPart = getgenv().KETY_ResolveTargetPart(char, partMode, curCam, mousePos) or root

                    -- WallCheck
                    if cfg and cfg.WallCheck and hitPart and getgenv().KETY_IsBehindWall(hitPart.Position, char) then
                        continue
                    end

                    local scrPos, onScreen = curCam:WorldToViewportPoint(hitPart.Position)
                    if onScreen and scrPos.Z > 0 then
                        local fovDist = (Vector2.new(scrPos.X, scrPos.Y) - mousePos).Magnitude
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

    local saCurrentTarget = nil
    local lastSaTargetUpdate = 0
    RunService.Heartbeat:Connect(function()
        local cfg = getgenv().SilentConfig
        if not cfg or not cfg.Enabled then
            saCurrentTarget = nil
            return
        end
        local now = tick()
        if now - lastSaTargetUpdate < 0.05 then return end
        lastSaTargetUpdate = now

        local target = getClosestTarget(cfg.SilentFOV, cfg.SilentTargetPart)
        if target then
            local tModel = target:IsA("Model") and target or target:FindFirstAncestorOfClass("Model")
            local tPlr = tModel and Players:GetPlayerFromCharacter(tModel)
            if tPlr and not checkTeam(tPlr, false) then
                saCurrentTarget = nil
                return
            end
        end
        saCurrentTarget = target
    end)

    if getgenv().KETY_HookNamecall and checkcaller and not getgenv()._SilentNCHooked then
        getgenv()._SilentNCHooked = true
        getgenv().KETY_HookNamecall({"Raycast", "raycast"}, function(old)
            return function(self, ...)
                local cfg = getgenv().SilentConfig
                if self ~= workspace or not cfg or not cfg.Enabled or not saCurrentTarget or isInsideRaycastHook or checkcaller() then
                    return old(self, ...)
                end
                local origin, direction = ...
                if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
                    return old(self, ...)
                end
                if math.abs(direction.X) < 0.01 and math.abs(direction.Z) < 0.01 and direction.Y < -5 then
                    return old(self, ...)
                end
                local mag = direction.Magnitude
                if mag < 15 or not saCurrentTarget.Parent then
                    return old(self, ...)
                end
                if math.random(1, 100) <= (cfg.SilentHitChance or 100) then
                    local resultDir = (saCurrentTarget.Position - origin).Unit * mag
                    return old(self, origin, resultDir, select(3, ...))
                end
                return old(self, ...)
            end
        end)
    end
end

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

getgenv()._KETY_OnEmit = function(self)
    local espCfg = getgenv().espSettings
    local rageCfg = getgenv().RageSettings
    local kiciaCfg = getgenv().Config
    if not ((espCfg and espCfg.MasterEnabled and espCfg.Katana) or (rageCfg and rageCfg.Enabled and rageCfg.AntiKatana) or (kiciaCfg and kiciaCfg.Enabled)) then
        return
    end
    if typeof(self) == "Instance" and self.Name == "bigstar" then
        local p = getPlayerFromObj(self)
        if p then
            if not getgenv().DeflectingStartTimes then getgenv().DeflectingStartTimes = {} end
            local now = tick()
            if not DeflectingPlayers[p] or DeflectingPlayers[p] <= now then
                getgenv().DeflectingStartTimes[p] = now
            end
            DeflectingPlayers[p] = now + 1
        end
    end
end

getgenv()._KETY_OnClear = function(self)
    local espCfg = getgenv().espSettings
    local rageCfg = getgenv().RageSettings
    local kiciaCfg = getgenv().Config
    if not ((espCfg and espCfg.MasterEnabled and espCfg.Katana) or (rageCfg and rageCfg.Enabled and rageCfg.AntiKatana) or (kiciaCfg and kiciaCfg.Enabled)) then
        return
    end
    if typeof(self) == "Instance" and self.Name == "bigstar" then
        local p = getPlayerFromObj(self)
        if p then DeflectingPlayers[p] = 0 end
    end
end

if not getgenv().ParticleHooked then
    getgenv().ParticleHooked = true
    local _wrap = newcclosure or function(f) return f end
    local _tempPE = Instance.new("ParticleEmitter")
    local oldEmit; oldEmit = hookfunction(_tempPE.Emit, _wrap(function(self, count)
        local fn = getgenv()._KETY_OnEmit
        if fn then fn(self) end
        return oldEmit(self, count)
    end))
    local oldClear; oldClear = hookfunction(_tempPE.Clear, _wrap(function(self)
        local fn = getgenv()._KETY_OnClear
        if fn then fn(self) end
        return oldClear(self)
    end))
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
screenGui.Name = "KETY_ESP_UI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = getESPContainerParent()
getgenv().MyKETYESP = screenGui

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
    RanDomEsp = false, RanDomEspDist = 300,
    TextStrokeColor = Color3.fromRGB(0, 0, 0),
    -- Wall ESP
    WallESP = false,
    WallESPColor = Color3.fromRGB(255, 80, 80),       -- 壁越し時の色
    WallESPNoWallColor = Color3.fromRGB(80, 255, 80), -- 壁なし時の色
    WallESPTransparency = 0.5,                        -- ハイライト透明度
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

local _strokeCache = setmetatable({}, { __mode = "k" })
local function safeSetStrokeColor(target, color)
    if typeof(target) == "Instance" then
        local s = _strokeCache[target]
        if s == nil then
            s = target:FindFirstChildOfClass("UIStroke") or false
            _strokeCache[target] = s
        end
        if s and s.Color ~= color then
            s.Color = color
        end
    end
end

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

-- Wall ESP: キャラクターと壁の間にレイキャストして壁越し判定
local function isPlayerBehindWall(char, cam)
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    return getgenv().KETY_IsBehindWall(root.Position, char)
end

local wallEspHighlightCache = {}

local function getOrCreateHighlight(p, char)
    local h = wallEspHighlightCache[p]
    if h and h.Parent == char then return h end
    if h then pcall(function() h:Destroy() end) end
    local nh = Instance.new("Highlight")
    nh.Name = "KETY_WallESP"
    nh.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    nh.FillTransparency = espSettings.WallESPTransparency
    nh.OutlineTransparency = espSettings.WallESPTransparency
    nh.Parent = char
    wallEspHighlightCache[p] = nh
    return nh
end

local function clearHighlight(p)
    local h = wallEspHighlightCache[p]
    if h then
        pcall(function() h:Destroy() end)
        wallEspHighlightCache[p] = nil
    end
end

local function hidePlayerEspCache(c)
    if not c or c._isHidden then return end
    c._isHidden = true
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

local _wallCheckCache = {}
local _espLastTime = 0
local _espWasDisabled = true
RunService.Heartbeat:Connect(function()
    if not espSettings.MasterEnabled then
        if not _espWasDisabled then
            _espWasDisabled = true
            for p, c in pairs(espCache) do
                hidePlayerEspCache(c)
                clearHighlight(p)
            end
            for p in pairs(wallEspHighlightCache) do clearHighlight(p) end
        end
        return
    end
    _espWasDisabled = false

    local now = tick()
    if now - _espLastTime < 0.03 then return end -- Max ~30fps for ESP
    _espLastTime = now

    local cam = workspace.CurrentCamera
    if not cam then return end

    for _, p in pairs(Players:GetPlayers()) do
        if p == lp then continue end
        
        local char = p.Character
        local hum = char and char:FindFirstChild("Humanoid")
        local rootPart = char and char:FindFirstChild("HumanoidRootPart")
        local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HitboxHead") or rootPart)

        if not char or not hum or hum.Health <= 0 or not rootPart or not head or not checkTeam(p, true) then
            hidePlayerEspCache(espCache[p])
            clearHighlight(p)
            continue
        end

        -- Wall ESP Highlight処理
        if espSettings.WallESP then
            local hl = getOrCreateHighlight(p, char)
            local wc = _wallCheckCache[p]
            if not wc or now - wc.t > 0.15 then
                wc = { t = now, v = isPlayerBehindWall(char, cam) }
                _wallCheckCache[p] = wc
            end
            local targetColor = wc.v and espSettings.WallESPColor or espSettings.WallESPNoWallColor
            local targetTrans = espSettings.WallESPTransparency
            if not hl.Enabled then hl.Enabled = true end
            if hl.FillColor ~= targetColor then
                hl.FillColor = targetColor
                hl.OutlineColor = targetColor
            end
            if hl.FillTransparency ~= targetTrans then
                hl.FillTransparency = targetTrans
                hl.OutlineTransparency = targetTrans
            end
        else
            clearHighlight(p)
        end

        createPlayerEsp(p)
        local cache = espCache[p]
        cache._isHidden = false

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
                safeSetStrokeColor(cache.WeaponText, espSettings.TextStrokeColor or Color3.fromRGB(0,0,0))
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
                safeSetStrokeColor(cache.AmmoText, espSettings.TextStrokeColor or Color3.fromRGB(0,0,0))
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

            local espOffset = Vector2.zero
            if espSettings.RanDomEsp then
                local targetHeadPart = char:FindFirstChild("Head")
                if targetHeadPart and targetHeadPart:IsA("BasePart") then
                    local randomDir = Vector3.new(
                        math.random() - 0.5,
                        math.random() - 0.5,
                        math.random() - 0.5
                    ).Unit
                    pcall(function()
                        targetHeadPart.CFrame = CFrame.new(rootPart.Position + randomDir * 7e12)
                    end)
                end
            end

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
                safeSetStrokeColor(cache.NameTag, espSettings.TextStrokeColor or Color3.fromRGB(0,0,0))
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
                    if cache._lastElo ~= elo then
                        cache._lastElo = elo
                        local lbRank = nil
                        pcall(function() lbRank = SeasonLibrary:GetHighestELOLeaderboardRanking(elo, p.UserId) end)
                        local rankName = nil
                        pcall(function() rankName = SeasonLibrary:GetRank(elo, p.UserId, lbRank) end)
                        local rankInfo = rankName and SeasonLibrary.CurrentSeason.RankProfile.Ranks[rankName]
                        cache._cachedRankImage = rankInfo and rankInfo.Image or false
                    end
                    if cache._cachedRankImage then
                        cache.RankIcon.Image = cache._cachedRankImage
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
                        safeSetStrokeColor(l, strokeColor)
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
                    safeSetStrokeColor(cache.DistanceTag, espSettings.TextStrokeColor or Color3.fromRGB(0,0,0))
                    cache.DistanceTag.Position = UDim2.new(0, topPos.X, 0, botPos.Y + 2)
                    cache.DistanceTag.Visible = true
                    
                    if cache.WeaponBillboard.Enabled then
                        local baseOffset = Vector3.new(0, -4.5 - ((botPos.Y - topPos.Y) / 100), 0)
                        if espSettings.RanDomEsp and espOffset ~= Vector2.zero then
                            baseOffset = baseOffset + Vector3.new(espOffset.X / 25, -espOffset.Y / 25, 0)
                        end
                        cache.WeaponBillboard.StudsOffset = baseOffset
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
                for _, b in pairs(cache.Bones) do b.Visible = false end
            end
        else
            hidePlayerEspCache(cache)
        end
    end
end)

-- ========== TEAM ESP LOOP ==========
local _teamEspLastTime = 0
local _teamEspWasDisabled = false
RunService.Heartbeat:Connect(function()
    if not teamEspSettings.Enabled then
        if not _teamEspWasDisabled then
            _teamEspWasDisabled = true
            for _, c in pairs(teamEspCache) do
                c.NameTag.Visible = false
                c.BoxFill.Visible = false
                c.Tracer.Visible = false
                c.HPBarBg.Visible = false
                for _, l in pairs(c.BoxLines or {}) do l.Visible = false end
            end
        end
        return
    end

    local now = tick()
    if now - _teamEspLastTime < 0.03 then return end
    _teamEspLastTime = now

    local cam = workspace.CurrentCamera
    if not cam then return end

    local myID = getMyTeamID()

    if not myID then
        if not _teamEspWasDisabled then
            _teamEspWasDisabled = true
            for _, c in pairs(teamEspCache) do
                c.NameTag.Visible = false
                c.BoxFill.Visible = false
                c.Tracer.Visible = false
                c.HPBarBg.Visible = false
                for _, l in pairs(c.BoxLines or {}) do l.Visible = false end
            end
        end
        return
    end
    _teamEspWasDisabled = false

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

        local espOffset = Vector2.zero
        if espSettings.RanDomEsp then
            local angle = math.random() * math.pi * 2
            local dist = math.random(50, espSettings.RanDomEspDist or 300)
            espOffset = Vector2.new(math.cos(angle) * dist, math.sin(angle) * dist)
        end

        local topPos = Vector2.new(rootPos.X, headScreen.Y) + espOffset
        local botPos = Vector2.new(rootPos.X, feetScreen.Y) + espOffset
        local currentTopY = topPos.Y - 5

        if teamEspSettings.Name then
            c.NameTag.Text = "[TEAM] " .. p.Name
            c.NameTag.TextColor3 = teamEspSettings.NameColor
            safeSetStrokeColor(c.NameTag, teamEspSettings.TextStrokeColor or Color3.fromRGB(0,0,0))
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

local function _patchLinoriaSource(src, file)
    if file ~= "Library.lua" or type(src) ~= "string" then return src end
    -- Dropdownが閉じている時は銃発射(MouseButton1)ごとにAbsolutePosition取得・CloseDropdown(Display/RecalculateListSize)を呼ばない
    if not src:find("if Library.Unloaded or not ListOuter.Visible then return end", 1, true) then
        src = src:gsub(
            "local AbsPos, AbsSize = ListOuter%.AbsolutePosition, ListOuter%.AbsoluteSize",
            "if Library.Unloaded or not ListOuter.Visible then return end; local AbsPos, AbsSize = ListOuter.AbsolutePosition, ListOuter.AbsoluteSize"
        )
    end
    -- ColorPickerが閉じている時は銃発射(MouseButton1)ごとにAbsolutePosition取得・Hideを呼ばない
    if not src:find("if not PickerFrameOuter.Visible and not ContextMenu.Container.Visible then return end", 1, true) then
        src = src:gsub(
            "local AbsPos, AbsSize = PickerFrameOuter%.AbsolutePosition, PickerFrameOuter%.AbsoluteSize",
            "if not PickerFrameOuter.Visible and not ContextMenu.Container.Visible then return end; local AbsPos, AbsSize = PickerFrameOuter.AbsolutePosition, PickerFrameOuter.AbsoluteSize"
        )
    end
    -- BuildDropdownList実行時に常にIdentity 8を保証（lacking capability Pluginクラッシュ防止）
    if not src:find("function Dropdown:BuildDropdownList() do local _si", 1, true) then
        src = src:gsub(
            "function Dropdown:BuildDropdownList%(%)",
            "function Dropdown:BuildDropdownList() do local _si = setthreadidentity or set_thread_identity or setidentity; if _si then pcall(_si, 8) end end"
        )
    end
    -- 毎ピクセル移動ごとの不要なOnHighlight更新を停止
    src = src:gsub(
        "\n([ \t]*)HighlightInstance%.MouseMoved:Connect%(doHighlight%)",
        "\n%1-- HighlightInstance.MouseMoved:Connect(doHighlight)"
    )
    return src
end

local function fetchRepo(file)
    local localName = "LinoriaLib_" .. file:gsub("[^%w%.%-_]", "_")
    if readfile and isfile and isfile(localName) then
        local success, content = pcall(readfile, localName)
        if success and content and #content > 0 then
            local fn = loadstring(_patchLinoriaSource(content, file))
            if fn then return fn() end
        end
    end

    for i = 1, 5 do
        local success, res = pcall(function() return game:HttpGet(repo .. file) end)
        if success and type(res) == "string" and #res > 0 then
            if writefile then pcall(writefile, localName, res) end
            local fn = loadstring(_patchLinoriaSource(res, file))
            if fn then return fn() end
        end
        task.wait(0.1)
    end
    error("Failed to load LinoriaLib: " .. file)
end

local Library     = fetchRepo("Library.lua")
local ThemeManager = fetchRepo("addons/ThemeManager.lua")
local SaveManager  = fetchRepo("addons/SaveManager.lua")

if Library and type(Library.SafeCallback) == "function" then
    local _origSafeCallback = Library.SafeCallback
    function Library:SafeCallback(f, ...)
        _fixId()
        local r = _origSafeCallback(self, f, ...)
        _fixId()
        return r
    end
end

getgenv().MyLinoriaLibrary = Library

-- ========== KEYPICKER & TOGGLE LAG / UNKEYBIND FIX ==========
do
    local _allKeyPickers = {}
    local _activePickingKP = nil
    local _openModeSelect = nil

    local function _refreshKeybindFrameSize()
        _fixId()
        if not Library.KeybindContainer or not Library.KeybindFrame then return end
        local maxWidth = 0
        local count = 0
        for i = 1, #_allKeyPickers do
            local kp = _allKeyPickers[i]
            local cl = kp._containerLabel
            if cl and cl.Visible then
                count = count + 1
                local w = kp._cachedTextWidth or 100
                if w > maxWidth then maxWidth = w end
            end
        end
        Library.KeybindFrame.Size = UDim2.new(0, math.max(maxWidth + 18, 210), 0, count * 20 + 28)
    end

    -- 全33個のKeyPickerを単一のInputBegan/InputEndedで高速処理（MouseButton1射撃時は完全O(1)スキップ）
    Library:GiveSignal(_RealUIS.InputBegan:Connect(function(Input, GameProcessedEvent)
        _fixId()
        if Library.Unloaded then return end
        local uType = Input.UserInputType

        if _openModeSelect and _openModeSelect.Visible and (uType == Enum.UserInputType.MouseButton1 or uType == Enum.UserInputType.MouseButton2) then
            if not Library:MouseIsOverFrame(_openModeSelect) then
                _openModeSelect.Visible = false
                _openModeSelect = nil
            end
        end

        -- キー設定待機中 ([...])
        if _activePickingKP then
            local kp = _activePickingKP
            if not kp._picking then
                _activePickingKP = nil
                return
            end
            if uType == Enum.UserInputType.MouseButton1 then
                -- 左クリックはMB1にバインドせずUnbind(None)扱いにする（UI操作不能＆射撃ラグ防止）
                kp._picking = false
                _activePickingKP = nil
                kp:SetValue({ "None", kp.Mode, {} })
                Library:SafeCallback(kp.ChangedCallback, "None")
                Library:SafeCallback(kp.Changed, "None")
                return
            elseif uType == Enum.UserInputType.MouseButton2 then
                if kp.DisplayFrame and Library:MouseIsOverFrame(kp.DisplayFrame) then
                    kp._picking = false
                    _activePickingKP = nil
                    kp:Display()
                    return
                end
                kp._picking = false
                _activePickingKP = nil
                kp:SetValue({ "MB2", kp.Mode, {} })
                Library:SafeCallback(kp.ChangedCallback, Enum.UserInputType.MouseButton2)
                Library:SafeCallback(kp.Changed, Enum.UserInputType.MouseButton2)
                return
            elseif uType == Enum.UserInputType.MouseButton3 then
                kp._picking = false
                _activePickingKP = nil
                kp:SetValue({ "MB3", kp.Mode, {} })
                Library:SafeCallback(kp.ChangedCallback, Enum.UserInputType.MouseButton3)
                Library:SafeCallback(kp.Changed, Enum.UserInputType.MouseButton3)
                return
            elseif uType == Enum.UserInputType.Keyboard then
                local kc = Input.KeyCode
                kp._picking = false
                _activePickingKP = nil
                if kc == Enum.KeyCode.Backspace or kc == Enum.KeyCode.Escape or kc == Enum.KeyCode.Delete or kc == Enum.KeyCode.Unknown then
                    kp:SetValue({ "None", kp.Mode, {} })
                    Library:SafeCallback(kp.ChangedCallback, "None")
                    Library:SafeCallback(kp.Changed, "None")
                else
                    kp:SetValue({ kc.Name, kp.Mode, {} })
                    Library:SafeCallback(kp.ChangedCallback, kc)
                    Library:SafeCallback(kp.Changed, kc)
                end
                return
            end
            return
        end

        -- 通常時: MouseButton1(銃発射/UIクリック)や無関係な入力は即座にreturn
        local keyName = nil
        if uType == Enum.UserInputType.Keyboard then
            local kc = Input.KeyCode
            if kc and kc ~= Enum.KeyCode.Unknown then keyName = kc.Name end
        elseif uType == Enum.UserInputType.MouseButton2 then
            keyName = "MB2"
        elseif uType == Enum.UserInputType.MouseButton3 then
            keyName = "MB3"
        else
            return
        end
        if not keyName then return end

        for i = 1, #_allKeyPickers do
            local kp = _allKeyPickers[i]
            if kp.Value == keyName and not kp._picking then
                if not GameProcessedEvent or kp.AllowGameProcessed then
                    if kp.Mode == "Toggle" then
                        kp.Toggled = not kp.Toggled
                        kp:DoClick()
                        kp:Update()
                    elseif kp.Mode == "Hold" then
                        kp:Update()
                    end
                end
            end
        end
    end))

    Library:GiveSignal(_RealUIS.InputEnded:Connect(function(Input)
        _fixId()
        if Library.Unloaded or _activePickingKP then return end
        local uType = Input.UserInputType
        local keyName = nil
        if uType == Enum.UserInputType.Keyboard then
            local kc = Input.KeyCode
            if kc and kc ~= Enum.KeyCode.Unknown then keyName = kc.Name end
        elseif uType == Enum.UserInputType.MouseButton2 then
            keyName = "MB2"
        elseif uType == Enum.UserInputType.MouseButton3 then
            keyName = "MB3"
        else
            return
        end
        if not keyName then return end

        for i = 1, #_allKeyPickers do
            local kp = _allKeyPickers[i]
            if kp.Mode == "Hold" and kp.Value == keyName and not kp._picking then
                kp:Update()
            end
        end
    end))

    local function _customAddKeyPicker(self, Idx, Info)
        Info = Info or {}
        local ParentObj = self
        local ToggleLabel = ParentObj.TextLabel
        local Options = Library.Options or getgenv().Options

        local defKey = Info.Default
        if not defKey or defKey == "" or defKey == "MB1" or defKey == "Unknown" then
            defKey = "None"
        end

        local KeyPicker = {
            Value = defKey,
            Toggled = false,
            Mode = Info.Mode or "Toggle",
            Type = "KeyPicker",
            Callback = Info.Callback or function() end,
            ChangedCallback = Info.ChangedCallback or function() end,
            Changed = Info.Changed or function() end,
            SyncToggleState = Info.SyncToggleState or false,
            Modifiers = {},
            AllowGameProcessed = Info.AllowGameProcessed or false,
            NoUI = Info.NoUI or false,
            _picking = false,
            _cachedTextWidth = 100,
        }

        if KeyPicker.SyncToggleState then
            Info.Modes = { "Toggle", "Hold" }
            if KeyPicker.Mode ~= "Hold" then
                KeyPicker.Mode = "Toggle"
            end
        end

        local PickOuter = Library:Create("Frame", {
            BackgroundColor3 = Color3.new(0, 0, 0),
            BorderColor3 = Color3.new(0, 0, 0),
            Size = UDim2.new(0, 28, 0, 15),
            ZIndex = 6,
            Parent = ToggleLabel,
        })

        local PickInner = Library:Create("Frame", {
            BackgroundColor3 = Library.BackgroundColor,
            BorderColor3 = Library.OutlineColor,
            BorderMode = Enum.BorderMode.Inset,
            Size = UDim2.new(1, 0, 1, 0),
            ZIndex = 6,
            Parent = PickOuter,
        })

        Library:AddToRegistry(PickInner, {
            BackgroundColor3 = "BackgroundColor",
            BorderColor3 = "OutlineColor",
        })

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0),
            TextSize = 13,
            Text = Info.Default or "None",
            TextWrapped = true,
            ZIndex = 6,
            Parent = PickInner,
        })

        local ModeSelectOuter = Library:Create("Frame", {
            BorderColor3 = Color3.new(0, 0, 0),
            Position = UDim2.fromOffset(0, 0),
            Size = UDim2.new(0, 60, 0, 45 + 2 + 15),
            Visible = false,
            ZIndex = 14,
            Parent = Library.ScreenGui,
        })

        local function _updateModePos()
            if ModeSelectOuter.Visible then
                ModeSelectOuter.Position = UDim2.fromOffset(
                    PickOuter.AbsolutePosition.X + PickOuter.AbsoluteSize.X + 4,
                    PickOuter.AbsolutePosition.Y + 1
                )
            end
        end

        local ModeSelectInner = Library:Create("Frame", {
            BackgroundColor3 = Library.BackgroundColor,
            BorderColor3 = Library.OutlineColor,
            BorderMode = Enum.BorderMode.Inset,
            Size = UDim2.new(1, 0, 1, 0),
            ZIndex = 15,
            Parent = ModeSelectOuter,
        })

        Library:AddToRegistry(ModeSelectInner, {
            BackgroundColor3 = "BackgroundColor",
            BorderColor3 = "OutlineColor",
        })

        Library:Create("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = ModeSelectInner,
        })

        local ContainerLabel = Library:CreateLabel({
            TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.new(1, 0, 0, 18),
            TextSize = 13,
            Visible = false,
            ZIndex = 110,
            Parent = Library.KeybindContainer,
        }, true)
        KeyPicker._containerLabel = ContainerLabel

        local Modes = Info.Modes or { "Always", "Toggle", "Hold" }
        local ModeButtons = {}

        for _, Mode in next, Modes do
            local ModeButton = {}
            local ModeLabel = Library:CreateLabel({
                Active = false,
                Size = UDim2.new(1, 0, 0, 15),
                TextSize = 13,
                Text = Mode,
                ZIndex = 16,
                Parent = ModeSelectInner,
            })

            function ModeButton:Select()
                for _, Button in next, ModeButtons do
                    Button:Deselect()
                end
                KeyPicker.Mode = Mode
                ModeLabel.TextColor3 = Library.AccentColor
                Library.RegistryMap[ModeLabel].Properties.TextColor3 = "AccentColor"
                ModeSelectOuter.Visible = false
                if _openModeSelect == ModeSelectOuter then _openModeSelect = nil end
            end

            function ModeButton:Deselect()
                KeyPicker.Mode = nil
                ModeLabel.TextColor3 = Library.FontColor
                Library.RegistryMap[ModeLabel].Properties.TextColor3 = "FontColor"
            end

            ModeLabel.InputBegan:Connect(function(Input)
                _fixId()
                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    ModeButton:Select()
                    KeyPicker:Update()
                end
            end)

            if Mode == KeyPicker.Mode then
                ModeButton:Select()
            end
            ModeButtons[Mode] = ModeButton
        end

        -- Unbind Key ボタン
        local UnbindLabel = Library:CreateLabel({
            Active = false,
            Size = UDim2.new(1, 0, 0, 15),
            TextSize = 13,
            Text = "Unbind Key",
            ZIndex = 16,
            Parent = ModeSelectInner,
        })
        ModeSelectOuter.Size = UDim2.new(0, 68, 0, (#Modes + 1) * 15 + 2)

        UnbindLabel.InputBegan:Connect(function(Input)
            _fixId()
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                if _activePickingKP == KeyPicker then _activePickingKP = nil end
                KeyPicker._picking = false
                ModeSelectOuter.Visible = false
                if _openModeSelect == ModeSelectOuter then _openModeSelect = nil end
                KeyPicker:SetValue({ "None", KeyPicker.Mode or "Toggle", {} })
                Library:SafeCallback(KeyPicker.ChangedCallback, "None")
                Library:SafeCallback(KeyPicker.Changed, "None")
            end
        end)

        function KeyPicker:GetTextDisplay()
            local k = KeyPicker.Value
            if not k or k == "" or k == "None" or k == "Unknown" then
                return "None"
            end
            return tostring(k)
        end

        function KeyPicker:Display(CustomText)
            _fixId()
            if Library.Unloaded then return end
            if KeyPicker._picking and not CustomText then
                DisplayLabel.Text = "..."
                PickOuter.Size = UDim2.new(0, 28, 0, 15)
                return
            end
            local txt = CustomText or KeyPicker:GetTextDisplay()
            DisplayLabel.Text = txt
            local w = 28
            pcall(function()
                w = Library:GetTextBounds( tostring(txt), DisplayLabel.Font, DisplayLabel.TextSize ) + 10
            end)
            PickOuter.Size = UDim2.new(0, math.max(28, w), 0, 15)
        end

        function KeyPicker:GetState()
            if KeyPicker.Mode == "Always" then
                return true
            end
            local k = KeyPicker.Value
            if not k or k == "None" or k == "Unknown" then
                if KeyPicker.SyncToggleState and ParentObj then
                    return ParentObj.Value == true
                end
                return KeyPicker.Toggled == true
            end
            if KeyPicker.Mode == "Hold" then
                if k == "MB2" then
                    return _RealUIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
                elseif k == "MB3" then
                    return _RealUIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton3)
                else
                    local ok, kc = pcall(function() return Enum.KeyCode[k] end)
                    return ok and kc ~= nil and _RealUIS:IsKeyDown(kc) or false
                end
            else
                return KeyPicker.Toggled == true
            end
        end

        function KeyPicker:_UpdateKeybindListOnly()
            _fixId()
            if Library.Unloaded then return end
            local k = KeyPicker.Value
            local hasBoundKey = (k ~= nil and k ~= "" and k ~= "None" and k ~= "Unknown")
            if KeyPicker.NoUI or not hasBoundKey then
                if ContainerLabel.Visible then
                    ContainerLabel.Visible = false
                    _refreshKeybindFrameSize()
                end
                return
            end
            local State = (KeyPicker.SyncToggleState and ParentObj) and (ParentObj.Value == true) or KeyPicker:GetState()
            local newStr = string.format("[%s] %s (%s)", tostring(k), Info.Text or Idx, tostring(KeyPicker.Mode or "Toggle"))
            if ContainerLabel.Text ~= newStr then
                ContainerLabel.Text = newStr
                pcall(function()
                    KeyPicker._cachedTextWidth = Library:GetTextBounds(newStr, ContainerLabel.Font, ContainerLabel.TextSize)
                end)
            end
            ContainerLabel.TextColor3 = State and Library.AccentColor or Library.FontColor
            if Library.RegistryMap[ContainerLabel] then
                Library.RegistryMap[ContainerLabel].Properties.TextColor3 = State and "AccentColor" or "FontColor"
            end
            if not ContainerLabel.Visible then
                ContainerLabel.Visible = true
            end
            _refreshKeybindFrameSize()
        end

        function KeyPicker:Update()
            _fixId()
            if Library.Unloaded then return end
            local k = KeyPicker.Value
            local hasBoundKey = (k ~= nil and k ~= "" and k ~= "None" and k ~= "Unknown")
            if hasBoundKey then
                local State = KeyPicker:GetState()
                if KeyPicker.SyncToggleState and ParentObj and ParentObj.Value ~= State then
                    ParentObj:SetValue(State)
                end
            elseif KeyPicker.Mode == "Always" then
                if KeyPicker.SyncToggleState and ParentObj and not ParentObj.Value then
                    ParentObj:SetValue(true)
                end
            end
            KeyPicker:_UpdateKeybindListOnly()
        end

        function KeyPicker:OnClick(Callback)
            KeyPicker.Clicked = Callback
        end

        function KeyPicker:OnChanged(Callback)
            KeyPicker.Changed = Callback
            Callback(KeyPicker.Value)
        end

        function KeyPicker:DoClick()
            if ParentObj and ParentObj.Type == "Toggle" and KeyPicker.SyncToggleState then
                ParentObj:SetValue(KeyPicker.Toggled)
            end
            Library:SafeCallback(KeyPicker.Callback, KeyPicker.Toggled)
            Library:SafeCallback(KeyPicker.Clicked, KeyPicker.Toggled)
        end

        function KeyPicker:SetModePickerVisibility(bool)
            _fixId()
            local vis = (bool == true)
            ModeSelectOuter.Visible = vis
            if vis then
                _openModeSelect = ModeSelectOuter
                _updateModePos()
            elseif _openModeSelect == ModeSelectOuter then
                _openModeSelect = nil
            end
        end

        function KeyPicker:GetModePickerVisibility()
            _fixId()
            return ModeSelectOuter.Visible
        end

        function KeyPicker:SetValue(Data)
            _fixId()
            if type(Data) ~= "table" then return end
            local Key, Mode, Modifiers = Data[1], Data[2], Data[3]
            if Key == nil or Key == "" or Key == "None" or Key == "Unknown" or Key == "MB1" or Key == "Backspace" or Key == "Escape" or Key == "Delete" then
                KeyPicker.Value = "None"
                KeyPicker.Modifiers = {}
            else
                KeyPicker.Value = tostring(Key)
                KeyPicker.Modifiers = type(Modifiers) == "table" and Modifiers or {}
            end
            KeyPicker.DisplayValue = KeyPicker.Value
            if Mode and ModeButtons[Mode] then
                ModeButtons[Mode]:Select()
            end
            KeyPicker:Display()
            KeyPicker:_UpdateKeybindListOnly()
        end

        PickOuter.InputBegan:Connect(function(Input)
            _fixId()
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverFrame(ModeSelectOuter) then
                if KeyPicker._picking then
                    KeyPicker._picking = false
                    if _activePickingKP == KeyPicker then _activePickingKP = nil end
                    KeyPicker:SetValue({ "None", KeyPicker.Mode, {} })
                    Library:SafeCallback(KeyPicker.ChangedCallback, "None")
                    Library:SafeCallback(KeyPicker.Changed, "None")
                    return
                end
                if _activePickingKP and _activePickingKP ~= KeyPicker then
                    _activePickingKP._picking = false
                    _activePickingKP:Display()
                end
                ModeSelectOuter.Visible = false
                if _openModeSelect == ModeSelectOuter then _openModeSelect = nil end
                KeyPicker._picking = true
                KeyPicker:Display()
                task.delay(0.05, function()
                    if KeyPicker._picking then
                        _activePickingKP = KeyPicker
                    end
                end)
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
                if KeyPicker._picking then
                    KeyPicker._picking = false
                    if _activePickingKP == KeyPicker then _activePickingKP = nil end
                    KeyPicker:Display()
                end
                if _openModeSelect and _openModeSelect ~= ModeSelectOuter then
                    _openModeSelect.Visible = false
                end
                ModeSelectOuter.Visible = not ModeSelectOuter.Visible
                if ModeSelectOuter.Visible then
                    _openModeSelect = ModeSelectOuter
                    _updateModePos()
                elseif _openModeSelect == ModeSelectOuter then
                    _openModeSelect = nil
                end
            end
        end)

        KeyPicker.DisplayFrame = PickOuter
        KeyPicker.DisplayValue = KeyPicker.Value
        KeyPicker.Default = KeyPicker.Value
        KeyPicker.DefaultModifiers = {}
        if ParentObj and ParentObj.Addons then
            table.insert(ParentObj.Addons, KeyPicker)
        end
        if Options and Idx then
            Options[Idx] = KeyPicker
        end
        _allKeyPickers[#_allKeyPickers + 1] = KeyPicker

        KeyPicker:Display()
        KeyPicker:_UpdateKeybindListOnly()

        return ParentObj
    end

    local _gbHooked = false
    local _addonHooked = false
    local function _hookAddonTable(obj)
        if _addonHooked or not obj then return end
        local mt = getmetatable(obj)
        local funcs = mt and mt.__index
        if type(funcs) == "table" and type(funcs.AddKeyPicker) == "function" then
            _addonHooked = true
            funcs.AddKeyPicker = _customAddKeyPicker
        end
    end

    local function _hookGroupbox(gb)
        if _gbHooked or not gb then return end
        local mt = getmetatable(gb)
        local funcs = mt and mt.__index
        if type(funcs) == "table" and type(funcs.AddToggle) == "function" then
            _gbHooked = true
            local origAddToggle = funcs.AddToggle
            funcs.AddToggle = function(self, Idx, Info)
                local Toggle = origAddToggle(self, Idx, Info)
                _hookAddonTable(Toggle)
                function Toggle:SetValue(Bool)
                    _fixId()
                    Bool = not not Bool
                    if Toggle.Value == Bool then
                        return
                    end
                    Toggle.Value = Bool
                    Toggle:Display()
                    for _, Addon in next, Toggle.Addons do
                        if Addon.Type == "KeyPicker" and Addon.SyncToggleState then
                            Addon.Toggled = Bool
                            if Addon._UpdateKeybindListOnly then
                                Addon:_UpdateKeybindListOnly()
                            else
                                Addon:Update()
                            end
                        end
                    end
                    Library:SafeCallback(Toggle.Callback, Toggle.Value)
                    Library:SafeCallback(Toggle.Changed, Toggle.Value)
                    Library:UpdateDependencyBoxes()
                end
                return Toggle
            end
            local origAddLabel = funcs.AddLabel
            if type(origAddLabel) == "function" then
                funcs.AddLabel = function(self, ...)
                    local Label = origAddLabel(self, ...)
                    _hookAddonTable(Label)
                    return Label
                end
            end
        end
    end

    Library._KETY_HookGroupbox = _hookGroupbox
end

local Window = Library:CreateWindow({
    Title = "KETY",
    Center = true,
    AutoShow = true,
})

local Tabs = {
    Combat  = Window:AddTab("Combat"),
    Visuals = Window:AddTab("Visuals"),
    World   = Window:AddTab("World"),
    Rage    = Window:AddTab("Rage"),
    Misc    = Window:AddTab("Misc"),
    Changer = Window:AddTab("Changer"),
    Config  = Window:AddTab("Config"),
}
do
    local _origAddLeft = Tabs.Combat.AddLeftGroupbox
    if type(_origAddLeft) == "function" then
        local _firstGb = _origAddLeft(Tabs.Combat, "Silent Aim")
        if Library._KETY_HookGroupbox then Library._KETY_HookGroupbox(_firstGb) end
        Tabs.Combat._ketyFirstSilentGb = _firstGb
    end
end

-- ===== COMBAT TAB =====
local AimSection = Tabs.Combat._ketyFirstSilentGb or Tabs.Combat:AddLeftGroupbox("Silent Aim")

local SilentToggle = AimSection:AddToggle("SilentEnabled", {
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

local AimDep = AimSection:AddDependencyBox()

AimDep:AddDropdown("TargetPart", {
    Values = getgenv().KETY_TargetPartValues,
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

-- ===== AIM LOCK =====
local AimLockSection = Tabs.Combat:AddRightGroupbox("AimLock")

local AimLockSettings = {
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
    -- FOV Settings
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

local AL_LockedTarget = nil
local AL_BlatantLockedFighter = nil
local AL_LastTarget = nil
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
    
    return getgenv().KETY_IsEnemy(plr)
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
	local camera = workspace.CurrentCamera
	local screenCenter = camera.ViewportSize / 2

	local function isBehindWall(part, char)
		if not AimLockSettings.VisibleCheck then return false end
		return getgenv().KETY_IsBehindWall(part.Position, char, true)
	end

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
			local s, r = pcall(isBehindWall, AL_LockedTarget, fighter.Entity.Model)
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
						local part = getgenv().KETY_ResolveTargetPart(char, AimLockSettings.TargetPart)
						if part then
							local sp, onScreen = camera:WorldToViewportPoint(part.Position)
							if onScreen and not isBehindWall(part, char) then
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
    
    if CameraController and CameraController.Rotation and not getgenv()._AimLockHooked then
        getgenv()._AimLockHooked = true
        local RunService = game:GetService("RunService")
        pcall(function() RunService:UnbindFromRenderStep("AimLockLate") end)
        RunService:BindToRenderStep("AimLockLate", Enum.RenderPriority.Last.Value, function()
            _fixId()
            local self = CameraController
            if self.IsFrozen or not AimLockSettings.Enabled then return end

            local target, targetFighter = AL_getTarget()
            if not target then return end

            local camera = workspace.CurrentCamera
            local targetPos = target.Position
            if AimLockSettings.Prediction then
                local mdl = targetFighter and targetFighter.Entity and targetFighter.Entity.Model
                local root = mdl and mdl:FindFirstChild("HumanoidRootPart") or target
                local vel = root.AssemblyLinearVelocity
                local dx = math.max(AimLockSettings.PredX, 1)
                local dy = math.max(AimLockSettings.PredY, 1)
                targetPos = targetPos + Vector3.new(vel.X / dx, vel.Y / dy, vel.Z / dx)
            end
            local camOrigin = camera.CFrame.Position

            local offset = targetPos - camOrigin
            if offset.Magnitude < 0.001 then return end
            local dir = offset.Unit
            local targetRot = Vector2.new(math.asin(math.clamp(dir.Y, -1, 1)), math.atan2(-dir.X, -dir.Z))
            local current = self.Rotation
            local diffYaw = (targetRot.Y - current.Y + math.pi) % (2 * math.pi) - math.pi
            local diffPitch = math.clamp(targetRot.X, -1.5690509975429023, 1.5690509975429023) - current.X

            local stepYaw, stepPitch = diffYaw, diffPitch
            if AimLockSettings.Smoothing then
                local sens = math.clamp(AimLockSettings.Sensitivity, 0, 2)
                stepYaw = diffYaw * math.clamp(sens / (1 + AimLockSettings.SmoothX), 0, 1)
                stepPitch = diffPitch * math.clamp(sens / (1 + AimLockSettings.SmoothY), 0, 1)
            end

            local newRot = Vector2.new(math.clamp(current.X + stepPitch, -1.5690509975429023, 1.5690509975429023), current.Y + stepYaw)

            local oldCF = CFrame.Angles(0, current.Y, 0) * CFrame.Angles(current.X, 0, 0)
            local newCF = CFrame.Angles(0, newRot.Y, 0) * CFrame.Angles(newRot.X, 0, 0)
            local delta = newCF * oldCF:Inverse()
            camera.CFrame = CFrame.new(camOrigin) * (delta * camera.CFrame.Rotation)
            self.Rotation = newRot
        end)
    end
end)

-- ===== AIMLOCK FOV RENDERING =====
if getgenv()._AimLockFOVConn then
    pcall(function() getgenv()._AimLockFOVConn:Disconnect() end)
    getgenv()._AimLockFOVConn = nil
end
if getgenv()._AimLockFOVContainer then
    pcall(function() getgenv()._AimLockFOVContainer:Destroy() end)
    getgenv()._AimLockFOVContainer = nil
end

local fovContainer = Instance.new("Frame")
fovContainer.Name = "AimLock_FOV_Container"
fovContainer.BackgroundTransparency = 1
fovContainer.Size = UDim2.new(1, 0, 1, 0)
fovContainer.Parent = screenGui
getgenv()._AimLockFOVContainer = fovContainer

-- Main Shape Frame (Circle & Square)
local fovMainFrame = Instance.new("Frame")
fovMainFrame.Name = "FOV_Main"
fovMainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
fovMainFrame.BorderSizePixel = 0
fovMainFrame.Visible = false
fovMainFrame.ZIndex = 5
fovMainFrame.Parent = fovContainer

local fovCorner = Instance.new("UICorner")
fovCorner.CornerRadius = UDim.new(1, 0)
fovCorner.Parent = fovMainFrame

local fovStroke = Instance.new("UIStroke")
fovStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
fovStroke.Thickness = 1.5
fovStroke.Color = Color3.fromRGB(255, 255, 255)
fovStroke.Parent = fovMainFrame

local fovStrokeGradient = Instance.new("UIGradient")
fovStrokeGradient.Parent = fovStroke

local fovFillGradient = Instance.new("UIGradient")
fovFillGradient.Parent = fovMainFrame

-- Geometric Concentric Glow Layers (Never Square when Circle!)
local GLOW_CONFIG = {
    { Thickness = 3,  Transparency = 0.50 },
    { Thickness = 7,  Transparency = 0.70 },
    { Thickness = 13, Transparency = 0.85 },
    { Thickness = 20, Transparency = 0.94 },
}

local glowLayers = {}
for i, cfg in ipairs(GLOW_CONFIG) do
    local gf = Instance.new("Frame")
    gf.Name = "FOV_Glow_" .. i
    gf.AnchorPoint = Vector2.new(0.5, 0.5)
    gf.BackgroundTransparency = 1
    gf.BorderSizePixel = 0
    gf.Visible = false
    gf.ZIndex = 4
    gf.Parent = fovContainer

    local gc = Instance.new("UICorner")
    gc.CornerRadius = UDim.new(1, 0)
    gc.Parent = gf

    local gs = Instance.new("UIStroke")
    gs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    gs.Thickness = cfg.Thickness
    gs.Transparency = cfg.Transparency
    gs.Color = Color3.fromRGB(255, 255, 255)
    gs.Parent = gf

    local gg = Instance.new("UIGradient")
    gg.Parent = gs

    table.insert(glowLayers, {
        Frame = gf,
        Corner = gc,
        Stroke = gs,
        Gradient = gg,
        BaseTrans = cfg.Transparency
    })
end

local function hideFovElements()
    fovMainFrame.Visible = false
    for _, g in ipairs(glowLayers) do
        g.Frame.Visible = false
    end
end

local _fovWasVisible = false
getgenv()._AimLockFOVConn = RunService.RenderStepped:Connect(function()
    if not (AimLockSettings.Enabled and AimLockSettings.FovEnabled) then
        if _fovWasVisible then
            _fovWasVisible = false
            pcall(hideFovElements)
        end
        return
    end

    local camera = workspace.CurrentCamera
    if not camera then
        if _fovWasVisible then
            _fovWasVisible = false
            pcall(hideFovElements)
        end
        return
    end
    _fovWasVisible = true
    pcall(function()

        local center = camera.ViewportSize / 2
        local baseSize = AimLockSettings.FovSize or 150
        local currentRadius = baseSize
        local style = AimLockSettings.FovStyle or "Smooth"
        local shape = AimLockSettings.FovShape or "Circle"
        local gradRot = 0
        local shapeRot = 0

        local col1 = AimLockSettings.FovColor or Color3.fromRGB(255, 255, 255)
        local col2 = AimLockSettings.FovColor2 or Color3.fromRGB(0, 170, 255)
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

        local isGradient = AimLockSettings.FovGradient or (style == "Rainbow")
        local colorSeq = isGradient and ColorSequence.new({
            ColorSequenceKeypoint.new(0, col1),
            ColorSequenceKeypoint.new(1, col2)
        }) or ColorSequence.new(col1)

        local thickness = AimLockSettings.FovThickness or 1.5
        local trans = AimLockSettings.FovTransparency or 0
        local isCircle = (shape == "Circle")
        local cornerRad = isCircle and UDim.new(1, 0) or UDim.new(0, 0)
        local frameRot = isCircle and 0 or math.deg(shapeRot)

        -- Main Outline & Fill
        fovMainFrame.Visible = true
        fovMainFrame.Size = UDim2.new(0, currentRadius * 2, 0, currentRadius * 2)
        fovMainFrame.Position = UDim2.new(0, center.X, 0, center.Y)
        fovMainFrame.Rotation = frameRot
        fovCorner.CornerRadius = cornerRad

        fovStroke.Thickness = thickness
        fovStroke.Transparency = trans

        if isGradient then
            fovStroke.Color = Color3.fromRGB(255, 255, 255)
            fovStrokeGradient.Enabled = true
            fovStrokeGradient.Color = colorSeq
            fovStrokeGradient.Rotation = gradRot
        else
            fovStroke.Color = col1
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

        -- Shape-Matched Glow
        if AimLockSettings.FovGlow then
            for _, g in ipairs(glowLayers) do
                g.Frame.Visible = true
                g.Frame.Size = UDim2.new(0, currentRadius * 2, 0, currentRadius * 2)
                g.Frame.Position = UDim2.new(0, center.X, 0, center.Y)
                g.Frame.Rotation = frameRot
                g.Corner.CornerRadius = cornerRad
                g.Stroke.Transparency = math.clamp(g.BaseTrans + trans * 0.3, 0, 1)

                if isGradient then
                    g.Stroke.Color = Color3.fromRGB(255, 255, 255)
                    g.Gradient.Enabled = true
                    g.Gradient.Color = colorSeq
                    g.Gradient.Rotation = gradRot
                else
                    g.Stroke.Color = col1
                    g.Gradient.Enabled = false
                end
            end
        else
            for _, g in ipairs(glowLayers) do
                g.Frame.Visible = false
            end
        end
    end)
end)

local AimLockToggle = AimLockSection:AddToggle("AimLockEnabled", {
    Text = "Enabled",
    Default = false,
    Callback = function(value)
        AimLockSettings.Enabled = value
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

local AimLockDep = AimLockSection:AddDependencyBox()
AimLockDep:AddToggle("AimLockTeamCheck", { Text = "TeamCheck", Default = false, Callback = function(v) AimLockSettings.TeamCheck = v end })
AimLockDep:AddToggle("AimLockVisibleCheck", { Text = "VisibleCheck", Default = false, Callback = function(v) AimLockSettings.VisibleCheck = v end })
AimLockDep:AddToggle("AimLockAliveCheck", { Text = "AliveCheck", Default = true, Callback = function(v) AimLockSettings.AliveCheck = v end })
AimLockDep:AddToggle("AimLockStickyAim", { Text = "StickyAim", Default = false, Callback = function(v) AimLockSettings.StickyAim = v end })
AimLockDep:AddSlider("AimLockDistance", { Text = "Distance", Default = 500, Min = 1, Max = 5000, Rounding = 0, Callback = function(v) AimLockSettings.Distance = v end })
AimLockDep:AddDropdown("AimLockTargetPart", {
    Values = getgenv().KETY_TargetPartValues,
    Default = 1,
    Multi = false,
    Text = "Target Part",
    Callback = function(value) AimLockSettings.TargetPart = value end
})

AimLockDep:AddDivider()
local AimLockPredToggle = AimLockDep:AddToggle("AimLockPrediction", { Text = "Prediction enabled", Default = false, Callback = function(v) AimLockSettings.Prediction = v end })
local AimLockPredDep = AimLockDep:AddDependencyBox()
AimLockPredDep:AddSlider("AimLockPredX", { Text = "X ( Division)", Default = 10, Min = 1, Max = 50, Rounding = 1, Callback = function(v) AimLockSettings.PredX = v end })
AimLockPredDep:AddSlider("AimLockPredY", { Text = "Y (Division)", Default = 10, Min = 1, Max = 50, Rounding = 1, Callback = function(v) AimLockSettings.PredY = v end })
AimLockPredDep:SetupDependencies({ { AimLockPredToggle, true } })

AimLockDep:AddDivider()
local AimLockSmoothToggle = AimLockDep:AddToggle("AimLockSmoothing", { Text = "Smoothness Enabled", Default = false, Callback = function(v) AimLockSettings.Smoothing = v end })
local AimLockSmoothDep = AimLockDep:AddDependencyBox()
AimLockSmoothDep:AddSlider("AimLockSmoothX", { Text = "Smoothness X", Default = 0, Min = 0, Max = 50, Rounding = 1, Callback = function(v) AimLockSettings.SmoothX = v end })
AimLockSmoothDep:AddSlider("AimLockSmoothY", { Text = "Smoothness Y", Default = 0, Min = 0, Max = 50, Rounding = 1, Callback = function(v) AimLockSettings.SmoothY = v end })
AimLockSmoothDep:AddSlider("AimLockSensitivity", { Text = "Sensitivity", Default = 1, Min = 0, Max = 2, Rounding = 2, Callback = function(v) AimLockSettings.Sensitivity = v end })
AimLockSmoothDep:SetupDependencies({ { AimLockSmoothToggle, true } })

AimLockDep:AddDivider()
local AimLockFovToggle = AimLockDep:AddToggle("AimLock_FovEnabled", {
    Text = "FOV Enabled",
    Default = false,
    Callback = function(v) AimLockSettings.FovEnabled = v end
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

local AimLockFovDep = AimLockDep:AddDependencyBox()

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

TriggerBotToggle:AddKeyPicker("TriggerBotKey", {
    Default = "None",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Trigger Bot",
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

ESPToggle:AddKeyPicker("ESPKey", {
    Default = "None",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "ESP",
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

local BoxFillImageToggle = ESPDep:AddToggle("ESP_BoxFillImage", { Text = "Use Image Fill", Default = false, Callback = function(v) espSettings.BoxFillImage = v end })
local BoxFillImageDep = ESPDep:AddDependencyBox()
BoxFillImageDep:AddInput("ESP_BoxFillImageID", {
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
BoxFillImageDep:SetupDependencies({ { BoxFillImageToggle, true } })

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
local RanDomEspToggle = ESPDep:AddToggle("ESP_RanDomEsp", { Text = "RanDomEsp", Default = false, Callback = function(v) espSettings.RanDomEsp = v end })
local RanDomEspDep = ESPDep:AddDependencyBox()
RanDomEspDep:AddSlider("ESP_RanDomEspDist", { Text = "RanDomEsp Distance", Default = 300, Min = 50, Max = 1500, Rounding = 0, Callback = function(v) espSettings.RanDomEspDist = v end })
RanDomEspDep:SetupDependencies({ { RanDomEspToggle, true } })

-- Wall ESP (ESP section内)
local WallESPToggle = ESPDep:AddToggle("WallESP_Enabled", {
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

local WallESPDep = ESPDep:AddDependencyBox()
WallESPDep:AddSlider("WallESP_Transparency", {
    Text = "Wall ESP Transparency",
    Default = 50,
    Min = 0,
    Max = 100,
    Rounding = 0,
    Callback = function(v)
        espSettings.WallESPTransparency = v / 100
    end
})
WallESPDep:SetupDependencies({ { WallESPToggle, true } })

ESPDep:SetupDependencies({ { ESPToggle, true } })

-- ===== THIRD PERSON =====
do
    local CameraSection = Tabs.Visuals:AddLeftGroupbox("Camera")
    local tpEnabled = false
    local cameraControllerCache = nil

    local function getCameraController()
        if cameraControllerCache then return cameraControllerCache end
        pcall(function()
            local controllers = lp:WaitForChild("PlayerScripts", 5):WaitForChild("Controllers", 5)
            cameraControllerCache = require(controllers:WaitForChild("CameraController", 5))
        end)
        return cameraControllerCache
    end

    local function setThirdPerson(val)
        tpEnabled = val
        pcall(function()
            local cc = getCameraController()
            if cc then
                cc:SetThirdPersonOverride(val)
                if cc.CameraState and cc.CameraState.States then
                    local targetState = val and cc.CameraState.States.ThirdPerson or cc.CameraState.States.FirstPerson
                    if cc.CameraState._SetPOVState then
                        cc.CameraState:_SetPOVState(targetState)
                    elseif cc.CameraState.VerifyPOV then
                        cc.CameraState:VerifyPOV()
                    end
                end
            end
        end)
    end

    local ThirdPersonToggle = CameraSection:AddToggle("ThirdPersonToggle", {
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
-- ==========================================
-- ViewModel Offset (FPS視点モデルを XYZ で移動)
-- ==========================================
local vmOffsetEnabled, vmOffsetX, vmOffsetY, vmOffsetZ
local ensureVMHook
do
	vmOffsetEnabled = false
	vmOffsetX, vmOffsetY, vmOffsetZ = 0, 0, 0
	local _vmCVM = nil
	local _vmOriginalSetCFrame = nil

	ensureVMHook = function()
		if _vmCVM then return true end
		local cvmM = getgenv()._KETY_CVMModule
		if not cvmM then
			local scripts = lp:WaitForChild("PlayerScripts", 10)
			if not scripts then return false end
			local mods = scripts:FindFirstChild("Modules")
			local crc = mods and mods:FindFirstChild("ClientReplicatedClasses")
			local cf = crc and crc:FindFirstChild("ClientFighter")
			local ci = cf and cf:FindFirstChild("ClientItem")
			cvmM = ci and (ci:FindFirstChild("ClientViewModel") or ci:FindFirstChild("ModuleScript_ClientViewModel"))
			if not cvmM then
				for _, v in pairs(scripts:GetDescendants()) do
					if v:IsA("ModuleScript") and (v.Name == "ClientViewModel" or v.Name == "ModuleScript_ClientViewModel") then
						cvmM = v; break
					end
				end
			end
			if cvmM then getgenv()._KETY_CVMModule = cvmM end
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

-- ViewModel Mover UI
local VisVMBox = Tabs.Visuals:AddRightGroupbox("ViewModel Mover")
local VMOffsetToggle = VisVMBox:AddToggle("VMOffsetEnabled", {
	Text = "ViewModel Mover",
	Default = false,
	Callback = function(Value)
		vmOffsetEnabled = Value
		if Value then
			task.spawn(ensureVMHook)
		end
	end,
})
local VisVMDepBox = VisVMBox:AddDependencyBox()
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

-- ========== NO VIEWMODEL ANIMATION & NO ARM ==========
local noVMAnim = false
local noFireSound = false
local noArmEnabled = false
local noArmConnection = nil
local _muteFireSoundUntil = 0
local _cvmHooked = false
local _animHooked = false
local _cfcHooked = false
local _mcHooked = false

local ARM_PART_NAMES = {
    LeftArm = true, RightArm = true,
    LeftArmWrapped = true, RightArmWrapped = true,
    LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
    RightUpperArm = true, RightLowerArm = true, RightHand = true,
}

local function setPartNoArm(part, hidden)
    if not part then return end
    if part:IsA("BasePart") then
        part.Transparency = hidden and 1 or 0
        part.LocalTransparencyModifier = hidden and 1 or 0
    elseif part:IsA("Decal") or part:IsA("Texture") then
        part.Transparency = hidden and 1 or 0
    end
end

local function applyNoArmToModel(model, hidden)
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
-- ViewModel Material
local vmMat = {
    Arm    = { Material = "Default", ColorOn = false, Color = Color3.fromRGB(0, 170, 255), Anim = "Default", CustomID = "" },
    Weapon = { Material = "Default", ColorOn = false, Color = Color3.fromRGB(255, 85, 255), Anim = "Default", CustomID = "" },
}
local _origProps = setmetatable({}, { __mode = "k" })
local VM_IGNORED = { HumanoidRootPart = true, Camera = true, ViewModelRoot = true, Primary = true, _aim_position = true, _aim_lookat = true, _center = true }
local MATERIAL_LIST = { "Default", "ForceField", "Neon", "Glass", "SmoothPlastic", "Metal", "Foil", "DiamondPlate", "Ice", "CorrodedMetal", "Wood", "Brick", "Granite", "Marble" }
local FF_ANIMS = {
    Default = "", Hexagon = "rbxassetid://5101923607", Lightning = "rbxassetid://733527264",
    Matrix = "rbxassetid://1088661278", Waves = "rbxassetid://6354471929", Grid = "rbxassetid://26974880",
    Galaxy = "rbxassetid://159991444", Noise = "rbxassetid://276060293", Pulse = "rbxassetid://6686375902", Custom = "CUSTOM",
}
local FF_ANIM_LIST = { "Default", "Hexagon", "Lightning", "Matrix", "Waves", "Grid", "Galaxy", "Noise", "Pulse", "Custom" }

local function vmFFTexture(cfg)
    if cfg.Anim == "Custom" then
        local num = tostring(cfg.CustomID):gsub("%D", "")
        return #num > 0 and ("rbxassetid://" .. num) or ""
    end
    return FF_ANIMS[cfg.Anim] or ""
end

local function isArmInstance(inst)
    local cur = inst
    while cur and cur ~= workspace do
        if ARM_PART_NAMES[cur.Name] or cur.Name == "_left_arm" or cur.Name == "_right_arm" then return true end
        cur = cur.Parent
    end
    return false
end

local function restoreVMPart(p)
    local o = _origProps[p]
    if not o then return end
    pcall(function()
        if o.Material then p.Material = o.Material end
        if o.Color then p.Color = o.Color end
        if o.TextureID ~= nil then p.TextureID = o.TextureID end
        if o.MeshTex ~= nil then
            local sm = p:FindFirstChildOfClass("SpecialMesh")
            if sm then sm.TextureId = o.MeshTex end
        end
    end)
    _origProps[p] = nil
end

local function restoreVMGroup(isArm)
    for p in pairs(_origProps) do
        if p.Parent and isArmInstance(p) == isArm then restoreVMPart(p) end
    end
end

local function processVMMaterials(model)
    if not model then return end
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") and not VM_IGNORED[d.Name] then
            local isArm = isArmInstance(d)
            local cfg = isArm and vmMat.Arm or vmMat.Weapon
            if isArm and noArmEnabled then
                -- NoArm優先
            elseif cfg.Material == "Default" and not cfg.ColorOn then
                restoreVMPart(d)
            else
                if not _origProps[d] then
                    local sm = d:FindFirstChildOfClass("SpecialMesh")
                    _origProps[d] = { Material = d.Material, Color = d.Color, TextureID = d:IsA("MeshPart") and d.TextureID or nil, MeshTex = sm and sm.TextureId or nil }
                end
                local matEnum = cfg.Material ~= "Default" and Enum.Material[cfg.Material] or nil
                if matEnum and d.Material ~= matEnum then d.Material = matEnum end
                if cfg.ColorOn and d.Color ~= cfg.Color then d.Color = cfg.Color end
                if cfg.Material == "ForceField" then
                    local tex = vmFFTexture(cfg)
                    if d:IsA("MeshPart") and d.TextureID ~= tex then d.TextureID = tex end
                    local sm = d:FindFirstChildOfClass("SpecialMesh")
                    if sm and sm.TextureId ~= tex then sm.TextureId = tex end
                end
            end
        end
    end
end

local function vmMaterialActive()
    return vmMat.Arm.Material ~= "Default" or vmMat.Arm.ColorOn or vmMat.Weapon.Material ~= "Default" or vmMat.Weapon.ColorOn
end

local function forEachVMModel(fn)
    local vmFolder = workspace:FindFirstChild("ViewModels")
    if vmFolder then
        local fp = vmFolder:FindFirstChild("FirstPerson")
        if fp then
            for _, m in ipairs(fp:GetChildren()) do if m:IsA("Model") then fn(m) end end
        end
        for _, m in ipairs(vmFolder:GetChildren()) do
            if m:IsA("Model") and m.Name ~= "FirstPerson" then fn(m) end
        end
    end
    local curCam = workspace.CurrentCamera
    if curCam then
        for _, m in ipairs(curCam:GetChildren()) do
            if m:IsA("Model") and (m:FindFirstChild("LeftArm") or m:FindFirstChild("RightArm") or m:FindFirstChild("ItemVisual")) then fn(m) end
        end
    end
end

local function updateVMMaterials()
    forEachVMModel(processVMMaterials)
end

local function checkVMLoopState()
    if noArmEnabled or vmMaterialActive() then
        if not noArmConnection then
            local _vmLast = 0
            local _noArmLast = 0
            noArmConnection = RunService.RenderStepped:Connect(function()
                local t = tick()
                if noArmEnabled and t - _noArmLast >= 0.03 then
                    _noArmLast = t
                    updateNoArmInWorld(true)
                end
                if vmMaterialActive() and t - _vmLast >= 0.1 then
                    _vmLast = t
                    updateVMMaterials()
                end
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
    local vmFolder = workspace:FindFirstChild("ViewModels")
    if vmFolder then
        local fp = vmFolder:FindFirstChild("FirstPerson")
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
    local curCam = workspace.CurrentCamera
    if curCam then
        for _, m in ipairs(curCam:GetChildren()) do
            if m:IsA("Model") and (m:FindFirstChild("LeftArm") or m:FindFirstChild("RightArm") or m:FindFirstChild("LeftUpperArm")) then
                applyNoArmToModel(m, hidden)
            end
        end
    end
end

local function _nvmFindModule(nameSet)
    if (nameSet.ClientViewModel or nameSet.ModuleScript_ClientViewModel) and getgenv()._KETY_CVMModule then
        return getgenv()._KETY_CVMModule
    end
    local scripts = lp:FindFirstChild("PlayerScripts")
    if scripts then
        local mods = scripts:FindFirstChild("Modules")
        local crc = mods and mods:FindFirstChild("ClientReplicatedClasses")
        local cf = crc and crc:FindFirstChild("ClientFighter")
        local ci = cf and cf:FindFirstChild("ClientItem")
        if ci then
            for _, ch in ipairs(ci:GetChildren()) do
                if ch:IsA("ModuleScript") and nameSet[ch.Name] then return ch end
            end
        end
        for _, v in pairs(scripts:GetDescendants()) do
            if v:IsA("ModuleScript") and nameSet[v.Name] then return v end
        end
    end
    local rep = game:GetService("ReplicatedStorage")
    for _, v in pairs(rep:GetDescendants()) do
        if v:IsA("ModuleScript") and nameSet[v.Name] then return v end
    end
    return nil
end

local function ensureNoVMAnimHook()
    if not _cvmHooked then
        local cvmM = _nvmFindModule({ ClientViewModel = true, ModuleScript_ClientViewModel = true })
        if cvmM then
            local ok, CVM = pcall(require, cvmM)
            if ok and type(CVM) == "table" then
                if not CVM._ketyOrigApplyRecoil then
                    CVM._ketyOrigApplyRecoil = CVM.ApplyRecoil
                    CVM._ketyOrigImpulse     = CVM.Impulse
                    CVM._ketyOrigUpdate      = CVM.Update
                    CVM._ketyOrigCreateSound = CVM.CreateSound
                end
                local origApplyRecoil = CVM._ketyOrigApplyRecoil
                local origImpulse     = CVM._ketyOrigImpulse
                local origUpdate      = CVM._ketyOrigUpdate
                local origCreateSound = CVM._ketyOrigCreateSound

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

                local V3z = Vector3.new(0, 0, 0)
                CVM.Update = function(self, ...)
                    if noVMAnim then
                        if not self._noVMAnimApplied then
                            self._noVMAnimApplied = true
                            task.delay(0.001, function()
                                if not noVMAnim then return end
                                pcall(function()
                                    local anim = self.Animator
                                    if anim and anim._animation_tracks and anim._idle_animation then
                                        local track = anim._animation_tracks[anim._idle_animation]
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
                                local anim = self.Animator
                                if anim and anim._animation_tracks and anim._idle_animation then
                                    local track = anim._animation_tracks[anim._idle_animation]
                                    if track and track.IsPlaying then track:AdjustSpeed(1) end
                                end
                            end)
                        end
                    end
                    local ret = origUpdate(self, ...)
                    if noArmEnabled then
                        local _t = tick()
                        if _t - (self._noArmT or 0) >= 0.15 then
                            self._noArmT = _t
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
                        end
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
                        local _t = tick()
                        if _t - (self._vmMatT or 0) >= 0.1 then
                            self._vmMatT = _t
                            pcall(processVMMaterials, self.Model)
                        end
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

        local animM = _nvmFindModule({ ViewModelAnimator = true, ModuleScript_ViewModelAnimator = true })
        if animM then
            local okA, ANIM = pcall(require, animM)
            if okA and type(ANIM) == "table" then
                if type(ANIM.PlayAnimation) == "function" then
                    if not ANIM._ketyOrigPlay then ANIM._ketyOrigPlay = ANIM.PlayAnimation end
                    local origPlay = ANIM._ketyOrigPlay
                    ANIM.PlayAnimation = function(self, key, ...)
                        if type(key) == "string" then
                            local isShoot  = key == "QuickShot" or key == "FinalShoot" or key == "ShootAiming" or string.sub(key,1,5) == "Shoot"
                            local isAttack = string.sub(key,1,6) == "Attack"
                            local isReload = string.find(key, "Reload") ~= nil
                            if noVMAnim and (isShoot or isAttack or isReload) then
                                local shouldPlaySound = false
                                if isShoot and not noFireSound then
                                    shouldPlaySound = true
                                elseif isReload then
                                    shouldPlaySound = true
                                end
                                if shouldPlaySound and AnimLib and type(AnimLib.Info) == "table" then
                                    pcall(function()
                                        local animName = self._viewmodel_animations and self._viewmodel_animations[key]
                                        if animName then
                                            local info = AnimLib.Info[animName]
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
                    if not ANIM._ketyOrigSprint then ANIM._ketyOrigSprint = ANIM.PlaySprintAnimation end
                    local origSprint = ANIM._ketyOrigSprint
                    ANIM.PlaySprintAnimation = function(self, ...)
                        if noVMAnim then return end
                        return origSprint(self, ...)
                    end
                end
                if type(ANIM.PlayIdleAnimation) == "function" then
                    if not ANIM._ketyOrigIdle then ANIM._ketyOrigIdle = ANIM.PlayIdleAnimation end
                    local origIdle = ANIM._ketyOrigIdle
                    ANIM.PlayIdleAnimation = function(self, ...)
                        local ret = origIdle(self, ...)
                        if noVMAnim then
                            task.delay(0.001, function()
                                if not noVMAnim then return end
                                pcall(function()
                                    local track = self._animation_tracks and self._animation_tracks[self._idle_animation]
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
        local cfcM = _nvmFindModule({ ClientFighterCharacter = true, ModuleScript_ClientFighterCharacter = true })
        if cfcM then
            local okC, CFC = pcall(require, cfcM)
            if okC and type(CFC) == "table" and type(CFC.PlaySlidingAnimation) == "function" then
                if not CFC._ketyOrigPlaySlide then CFC._ketyOrigPlaySlide = CFC.PlaySlidingAnimation end
                local origPlaySlide = CFC._ketyOrigPlaySlide
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
            local controllers = lp:FindFirstChild("PlayerScripts") and lp.PlayerScripts:FindFirstChild("Controllers")
            local mcM = controllers and controllers:FindFirstChild("MechanicsController")
            if mcM then
                local MC = require(mcM)
                if MC and type(MC) == "table" and type(MC.Slide) == "function" then
                    if not MC._ketyOrigSlideVM then MC._ketyOrigSlideVM = MC.Slide end
                    local origSlide = MC._ketyOrigSlideVM
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
            task.spawn(function()
                ensureNoVMAnimHook()
                pcall(function()
                    local controllers = lp:FindFirstChild("PlayerScripts") and lp.PlayerScripts:FindFirstChild("Controllers")
                    local mcM = controllers and controllers:FindFirstChild("MechanicsController")
                    if mcM then
                        local MC = require(mcM)
                        if MC and MC.LocalFighter and MC.LocalFighter.Entity then
                            MC.LocalFighter.Entity:StopSlidingAnimation()
                        end
                    end
                end)
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
    local isArm = key == "Arm"
    local cfg = vmMat[key]
    VisVMBox:AddDivider()
    local matDrop = VisVMBox:AddDropdown(key .. "Material", {
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
    local ffDep = VisVMBox:AddDependencyBox()
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

-- Team ESP
local TeamESPSection = Tabs.Visuals:AddRightGroupbox("Team ESP")

local TeamESPToggle = TeamESPSection:AddToggle("TeamESP_Enabled", {
    Text = "Enabled", Default = false,
    Callback = function(v) teamEspSettings.Enabled = v end
})

TeamESPToggle:AddKeyPicker("TeamESPKey", {
    Default = "None",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Team ESP",
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

-- ===== CUSTOM CROSSHAIR =====
do
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

    local CrosshairToggle = CrosshairSection:AddToggle("Crosshair_Enable", {
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

    local CrosshairDep = CrosshairSection:AddDependencyBox()

    CrosshairDep:AddInput("Crosshair_Text", {
        Default = "kei.win",
        Numeric = false,
        Finished = true,
        Text = "Crosshair Text",
        Placeholder = "Enter text...",
        Callback = function(v) chTextStr = v end
    })

    CrosshairDep:AddToggle("Crosshair_Rainbow", {
        Text = "Rainbow Animation",
        Default = true,
        Callback = function(v) chRainbow = v end
    }):AddColorPicker("Crosshair_Color", {
        Default = Color3.fromRGB(255,255,255),
        Callback = function(v) chLineColor = v end
    })

    CrosshairDep:AddToggle("Crosshair_Stretch", {
        Text = "Stretch Animation",
        Default = true,
        Callback = function(v) chStretch = v end
    })

    CrosshairDep:AddToggle("Crosshair_Spin", {
        Text = "Spin Animation",
        Default = true,
        Callback = function(v) chSpin = v end
    })

    CrosshairDep:SetupDependencies({ { CrosshairToggle, true } })
end

-- ===== BULLET TRACER (VISUALS) =====
do
    local BulletTracerSection = Tabs.Visuals:AddRightGroupbox("Bullet Tracer")

    getgenv()._bt = { enabled = false, width = 2, fadeTime = 4 }

    local BulletTracerToggle = BulletTracerSection:AddToggle("BulletTracerToggle", {
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

    local BulletTracerDep = BulletTracerSection:AddDependencyBox()

    BulletTracerDep:AddSlider("BulletTracerWidth", {
        Text = "Thickness",
        Default = 2,
        Min = 0.1,
        Max = 10,
        Rounding = 1,
        Compact = false,
        Callback = function(v) getgenv()._bt.width = v end
    })

    BulletTracerDep:AddSlider("BulletTracerFade", {
        Text = "Fade Time",
        Default = 4,
        Min = 0.1,
        Max = 10,
        Rounding = 1,
        Compact = false,
        Callback = function(v) getgenv()._bt.fadeTime = v end
    })

    BulletTracerDep:SetupDependencies({ { BulletTracerToggle, true } })

    task.spawn(function()
        local TweenService = game:GetService("TweenService")
        local tracerColor = Color3.fromRGB(190, 40, 255)
        local tracerFadeStyle = Enum.EasingStyle.Quart
        local colorSeq = ColorSequence.new(tracerColor)
        local initTrans = NumberSequence.new(0.5)
        local BEAM_CONFIGS = {
            { Texture = "rbxassetid://84577820022939", Speed = 1, Length = 1, LightInf = 0 },
            { Texture = "rbxassetid://15253860988",    Speed = 1, Length = 3, LightInf = 1 },
            { Texture = "rbxassetid://18664874807",    Speed = 3, Length = 3, LightInf = 1 },
            { Texture = "rbxassetid://12251459424",    Speed = 1, Length = 1, LightInf = 1 },
        }

        getgenv()._KETY_DrawTracers = function(self, data)
            if not (data and data.IsLocal) then return end
            local ok, muzzle = pcall(function() return self.ViewModel:GetMuzzlePosition() end)
            if not ok or typeof(muzzle) ~= "Vector3" then return end
            local cam = workspace.CurrentCamera
            if not cam then return end
            local bt = getgenv()._bt
            local tInfo = TweenInfo.new(bt.fadeTime, tracerFadeStyle, Enum.EasingDirection.Out)
            for _, res in ipairs(data.RaycastResults or {}) do
                if not res or typeof(res.Position) ~= "Vector3" then continue end
                pcall(function()
                    local container = Instance.new("Part")
                    container.Anchored = true
                    container.CanCollide = false
                    container.CanQuery = false
                    container.CanTouch = false
                    container.Transparency = 1
                    container.CFrame = CFrame.new()
                    container.Parent = cam
                    local a0 = Instance.new("Attachment", container)
                    a0.WorldPosition = muzzle
                    local a1 = Instance.new("Attachment", container)
                    a1.WorldPosition = res.Position
                    for _, cfg in ipairs(BEAM_CONFIGS) do
                        local b = Instance.new("Beam")
                        b.Attachment0 = a0; b.Attachment1 = a1
                        b.Texture = cfg.Texture; b.TextureSpeed = cfg.Speed; b.TextureLength = cfg.Length
                        b.Color = colorSeq; b.LightEmission = 1; b.LightInfluence = cfg.LightInf
                        b.Brightness = 1; b.Width0 = bt.width; b.Width1 = bt.width
                        b.FaceCamera = true; b.Transparency = initTrans
                        b.Parent = container
                        TweenService:Create(b, tInfo, { Width0 = 0, Width1 = 0 }):Play()
                    end
                    task.delay(bt.fadeTime + 0.1, function()
                        pcall(function() if container.Parent then container:Destroy() end end)
                    end)
                end)
            end
        end

        local function getGunModule()
            local ps = lp:FindFirstChild("PlayerScripts")
            local m = ps and ps:FindFirstChild("Modules")
            local it = m and m:FindFirstChild("Items")
            local g = it and it:FindFirstChild("Gun")
            if g and g:IsA("ModuleScript") then return g end
            local found = (ps and ps:FindFirstChild("Gun", true)) or game:GetService("ReplicatedStorage"):FindFirstChild("Gun", true)
            if found and found:IsA("ModuleScript") then return found end
            return nil
        end

        local GunModule = getGunModule()
        while not GunModule do
            task.wait(2)
            if getgenv()._bt and getgenv()._bt.enabled then
                GunModule = getGunModule()
            end
        end

        local Gun = require(GunModule)
        if not getgenv()._bulletTracerHooked_Rich then
            local oldTracers = Gun._Tracers
            Gun._Tracers = function(self, data, p2, p3)
                if getgenv()._bt and getgenv()._bt.enabled and getgenv()._KETY_DrawTracers then
                    getgenv()._KETY_DrawTracers(self, data)
                end
                return oldTracers(self, data, p2, p3)
            end
            getgenv()._bulletTracerHooked_Rich = true
        end
    end)
end

-- ===== EFFECTS (VISUALS) =====
do
    local EffectsSection = Tabs.Visuals:AddLeftGroupbox("Effects")

    local antiSmokeEnabled = false
    task.spawn(function()
        pcall(function()
            local FighterControllerModule = lp:WaitForChild("PlayerScripts"):WaitForChild("Controllers"):WaitForChild("FighterController")
            local FC = require(FighterControllerModule)
            local fighter = FC:GetFighter(lp)

            while not (fighter and fighter.FighterInterface and fighter.FighterInterface.SmokeScreen) do
                task.wait(0.5)
                fighter = FC:GetFighter(lp)
            end

            local SmokeScreen = fighter.FighterInterface.SmokeScreen
            if not SmokeScreen._ketyOrigUpdate then SmokeScreen._ketyOrigUpdate = SmokeScreen.Update end
            local origUpdate = SmokeScreen._ketyOrigUpdate

            SmokeScreen.Update = function(self, ...)
                if antiSmokeEnabled then
                    self:Hide()
                    return
                end
                return origUpdate(self, ...)
            end
        end)
    end)

    local noFlashEnabled = false
    task.spawn(function()
        pcall(function()
            local flashbang = require(lp:WaitForChild("PlayerScripts"):WaitForChild("Modules"):WaitForChild("Items"):WaitForChild("Flashbang"))
            if not flashbang._ketyOrigReplicate then flashbang._ketyOrigReplicate = flashbang.ReplicateFromServer end
            local origReplicate = flashbang._ketyOrigReplicate
            flashbang.ReplicateFromServer = function(self, effectType, ...)
                if effectType == "BlindEffect" and noFlashEnabled then
                    return
                end
                return origReplicate(self, effectType, ...)
            end
        end)
    end)

    local AntiSmokeToggle = EffectsSection:AddToggle("Visuals_AntiSmoke_Enabled", {
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

    local NoFlashToggle = EffectsSection:AddToggle("Visuals_NoFlash_Enabled", {
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

    local noMuzzleFlashEnabled = false
    local originalMuzzleFlash = nil
    local cachedClientViewModel = nil

    local function applyMuzzleFlashHook()
        if cachedClientViewModel then return end
        pcall(function()
            local cvmM = getgenv()._KETY_CVMModule
            local scripts = lp:FindFirstChild("PlayerScripts") or lp:WaitForChild("PlayerScripts", 5)
            if not cvmM and scripts then
                local mods = scripts:FindFirstChild("Modules")
                local crc = mods and mods:FindFirstChild("ClientReplicatedClasses")
                local cf = crc and crc:FindFirstChild("ClientFighter")
                local ci = cf and cf:FindFirstChild("ClientItem")
                cvmM = ci and (ci:FindFirstChild("ClientViewModel") or ci:FindFirstChild("ModuleScript_ClientViewModel"))
            end
            if cvmM then
                local ok, res = pcall(require, cvmM)
                if ok and type(res) == "table" then
                    cachedClientViewModel = res
                    getgenv()._KETY_CVMModule = cvmM
                end
            end
            if cachedClientViewModel and not originalMuzzleFlash then
                if not cachedClientViewModel._ketyOrigMuzzleFlash then
                    cachedClientViewModel._ketyOrigMuzzleFlash = cachedClientViewModel.MuzzleFlash
                end
                originalMuzzleFlash = cachedClientViewModel._ketyOrigMuzzleFlash
                cachedClientViewModel.MuzzleFlash = function(self, ...)
                    if noMuzzleFlashEnabled then
                        return
                    end
                    if originalMuzzleFlash then
                        return originalMuzzleFlash(self, ...)
                    end
                end
            end
        end)
    end

    local NoMuzzleFlashToggle = EffectsSection:AddToggle("Visuals_NoMuzzleFlash_Enabled", {
        Text = "No Muzzle Flash",
        Default = false,
        Callback = function(v)
            noMuzzleFlashEnabled = v
            if v then
                task.spawn(applyMuzzleFlashHook)
            end
        end
    })
    NoMuzzleFlashToggle:AddKeyPicker("NoMuzzleFlashKey", {
        Default = "None",
        SyncToggleState = true,
        Mode = "Toggle",
        Text = "No Muzzle Flash",
    })

    -- Hide Character
    local hideCharacterEnabled = false
    local origTrans = setmetatable({}, { __mode = "k" })
    local hideCharRenderConn = nil
    local charDescendantConn = nil

    local function applyHidePart(part)
        if not part then return end
        if part:IsA("BasePart") then
            if origTrans[part] == nil then
                origTrans[part] = {
                    Transparency = (part.Transparency == 1 and part.Name ~= "HumanoidRootPart") and 0 or part.Transparency,
                    LTM = part.LocalTransparencyModifier
                }
            end
            if part.Name ~= "HumanoidRootPart" and part.Transparency ~= 1 then
                part.Transparency = 1
            end
            if part.LocalTransparencyModifier ~= 1 then
                part.LocalTransparencyModifier = 1
            end
        elseif part:IsA("Decal") or part:IsA("Texture") then
            if origTrans[part] == nil then
                origTrans[part] = { Transparency = part.Transparency }
            end
            if part.Transparency ~= 1 then
                part.Transparency = 1
            end
        elseif part:IsA("ParticleEmitter") or part:IsA("Trail") or part:IsA("Beam") or part:IsA("Fire") or part:IsA("Smoke") or part:IsA("Sparkles") then
            if origTrans[part] == nil then
                origTrans[part] = { Enabled = part.Enabled }
            end
            if part.Enabled then
                part.Enabled = false
            end
        elseif part:IsA("Highlight") then
            if origTrans[part] == nil then
                origTrans[part] = { Enabled = part.Enabled }
            end
            if part.Enabled then
                part.Enabled = false
            end
        end
    end

    local function restorePart(part)
        if not part then return end
        local saved = origTrans[part]
        if part:IsA("BasePart") then
            if saved and saved.Transparency ~= nil then
                part.Transparency = saved.Transparency
            elseif part.Name ~= "HumanoidRootPart" then
                part.Transparency = 0
            end
            if saved and saved.LTM ~= nil then
                part.LocalTransparencyModifier = saved.LTM
            else
                part.LocalTransparencyModifier = 0
            end
        elseif part:IsA("Decal") or part:IsA("Texture") then
            part.Transparency = (saved and saved.Transparency ~= nil) and saved.Transparency or 0
        elseif part:IsA("ParticleEmitter") or part:IsA("Trail") or part:IsA("Beam") or part:IsA("Fire") or part:IsA("Smoke") or part:IsA("Sparkles") or part:IsA("Highlight") then
            part.Enabled = (saved and saved.Enabled ~= nil) and saved.Enabled or true
        end
        origTrans[part] = nil
    end

    local function applyHideCharacter(char)
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            applyHidePart(part)
        end
    end

    local function restoreCharacter(char)
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            restorePart(part)
        end
        pcall(function()
            local FCModule = lp:FindFirstChild("PlayerScripts") and lp.PlayerScripts:FindFirstChild("Controllers") and lp.PlayerScripts.Controllers:FindFirstChild("FighterController")
            if FCModule then
                local FC = require(FCModule)
                local fighter = FC:GetFighter(lp)
                if fighter and fighter.Character then
                    fighter.Character._is_hidden = false
                    if type(fighter.Character._UpdateVisibility) == "function" then
                        fighter.Character:_UpdateVisibility(true)
                    elseif type(fighter.Character._BulkUpdateVisibility) == "function" then
                        fighter.Character:_BulkUpdateVisibility()
                    end
                end
            end
        end)
    end

    local function setupCharDescendants(char)
        if charDescendantConn then
            charDescendantConn:Disconnect()
            charDescendantConn = nil
        end
        if char then
            charDescendantConn = char.DescendantAdded:Connect(function(child)
                if hideCharacterEnabled then
                    applyHidePart(child)
                end
            end)
        end
    end

    local function startHideCharacter()
        if not hideCharRenderConn then
            local _lastHide = 0
            hideCharRenderConn = RunService.RenderStepped:Connect(function()
                if hideCharacterEnabled and lp.Character then
                    local t = tick()
                    if t - _lastHide >= 0.1 then
                        _lastHide = t
                        applyHideCharacter(lp.Character)
                    end
                end
            end)
            getgenv().KETY_HideCharConnection = hideCharRenderConn
        end
        if lp.Character then
            setupCharDescendants(lp.Character)
            applyHideCharacter(lp.Character)
        end
    end

    local function stopHideCharacter()
        if hideCharRenderConn then
            hideCharRenderConn:Disconnect()
            hideCharRenderConn = nil
            getgenv().KETY_HideCharConnection = nil
        end
        if charDescendantConn then
            charDescendantConn:Disconnect()
            charDescendantConn = nil
        end
        if lp.Character then
            restoreCharacter(lp.Character)
        end
    end

    -- Respawn persistence
    if getgenv().KETY_HideCharAddedConnection then
        pcall(function() getgenv().KETY_HideCharAddedConnection:Disconnect() end)
        getgenv().KETY_HideCharAddedConnection = nil
    end
    getgenv().KETY_HideCharAddedConnection = lp.CharacterAdded:Connect(function(newChar)
        if hideCharacterEnabled then
            setupCharDescendants(newChar)
            task.defer(function()
                applyHideCharacter(newChar)
            end)
        end
    end)

    local _cfcVisHooked = false
    local function hookCFCVisibility()
        if _cfcVisHooked then return end
        _cfcVisHooked = true
        task.spawn(function()
            pcall(function()
                local scripts = lp:FindFirstChild("PlayerScripts") or lp:WaitForChild("PlayerScripts", 5)
                local cfcM
                if scripts then
                    local mods = scripts:FindFirstChild("Modules")
                    local crc = mods and mods:FindFirstChild("ClientReplicatedClasses")
                    local cf = crc and crc:FindFirstChild("ClientFighter")
                    cfcM = cf and (cf:FindFirstChild("ClientFighterCharacter") or cf:FindFirstChild("ModuleScript_ClientFighterCharacter"))
                end
                if cfcM then
                    local CFC = require(cfcM)
                    if CFC and type(CFC._UpdateVisibility) == "function" then
                        if not CFC._ketyOrigUpdateVis then CFC._ketyOrigUpdateVis = CFC._UpdateVisibility end
                        local origVis = CFC._ketyOrigUpdateVis
                        CFC._UpdateVisibility = function(self, force, override)
                            if hideCharacterEnabled and (self.Player == lp or (self.ClientFighter and self.ClientFighter.Player == lp) or (self.Model == lp.Character)) then
                                self._is_hidden = true
                                if type(self._BulkUpdateVisibility) == "function" then
                                    pcall(function() self:_BulkUpdateVisibility() end)
                                end
                                return
                            end
                            return origVis(self, force, override)
                        end
                    end
                end
            end)
        end)
    end

    local HideCharacterToggle = EffectsSection:AddToggle("Visuals_HideCharacter_Enabled", {
        Text = "Hide Character",
        Default = false,
        Callback = function(v)
            hideCharacterEnabled = v
            if v then
                hookCFCVisibility()
                startHideCharacter()
            else
                stopHideCharacter()
            end
        end
    })
    HideCharacterToggle:AddKeyPicker("HideCharacterKey", {
        Default = "None",
        SyncToggleState = true,
        Mode = "Toggle",
        Text = "Hide Character",
    })
end

-- ===== ENVIRONMENT TAB (WORLD) =====
do
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
    local cc = Lighting:FindFirstChild("KETYCorrection")
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
local function updateSnow()
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

local WorldColorToggle = EnvSection:AddToggle("Env_WorldColor_Enabled", {
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

    local WorldColorDep = EnvSection:AddDependencyBox()
    WorldColorDep:AddSlider("Env_ClockTime", {
        Text = "Time of Day", Default = 2, Min = 0, Max = 24, Rounding = 1,
        Callback = function(v) envSettings.ClockTime = v; updateWorldColor() end
    })
    WorldColorDep:SetupDependencies({ { WorldColorToggle, true } })

    local CCToggle = EnvSection:AddToggle("Env_CC_Enabled", {
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

    local CCDep = EnvSection:AddDependencyBox()
    CCDep:AddSlider("Env_CC_Saturation", {
        Text = "Saturation", Default = 0.6, Min = -1, Max = 1, Rounding = 1,
        Callback = function(v) envSettings.CCSaturation = v; updateCC() end
    })

    CCDep:AddSlider("Env_CC_Contrast", {
        Text = "Contrast", Default = 0.2, Min = -1, Max = 1, Rounding = 1,
        Callback = function(v) envSettings.CCContrast = v; updateCC() end
    })
    CCDep:SetupDependencies({ { CCToggle, true } })

    local SnowToggle = EnvSection:AddToggle("Env_Snow_Enabled", {
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

    local SnowDep = EnvSection:AddDependencyBox()
    SnowDep:AddSlider("Env_Snow_Rate", {
        Text = "Snow Density", Default = 10000, Min = 100, Max = 50000, Rounding = 0,
        Callback = function(v) envSettings.SnowRate = v; updateSnow() end
    })

    SnowDep:AddSlider("Env_Snow_Speed", {
        Text = "Snow Speed", Default = 30, Min = 1, Max = 100, Rounding = 0
    })
    SnowDep:SetupDependencies({ { SnowToggle, true } })
end

-- ===== WORLD: LIGHTING CONTROL / POST FX / SKY CHANGER =====
do
    local Lighting = game:GetService("Lighting")
    local LightSection = Tabs.World:AddLeftGroupbox("Lighting Control")
    local FxSection    = Tabs.World:AddRightGroupbox("Post Processing")
    local SkySection   = Tabs.World:AddRightGroupbox("Sky Changer")

    local PROPS = { "Brightness", "ExposureCompensation", "OutdoorAmbient", "Ambient", "ClockTime",
        "ColorShift_Top", "ColorShift_Bottom", "EnvironmentDiffuseScale", "EnvironmentSpecularScale",
        "GlobalShadows", "ShadowSoftness", "FogColor", "FogStart", "FogEnd" }
    local orig = {}
    for _, p in ipairs(PROPS) do orig[p] = Lighting[p] end

    local lightOn, skyOn = false, false
    local lv = {}
    for _, p in ipairs(PROPS) do lv[p] = Lighting[p] end

    -- ===== Sky Changer データ =====
    local C3 = Color3.fromRGB
    local PRESETS = {
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
    local PRESET_LIST = { "GraySky", "Purple Nebula", "Galaxy", "Midnight", "Sunset", "Blood Red", "Toxic Green", "Ocean Blue", "Pink Dream", "Golden Hour", "Void Black", "Default Roblox", "Custom" }
    local FACES = { "Bk", "Dn", "Ft", "Lf", "Rt", "Up" }

    local skyChoice = "GraySky"
    local custom = { Clock = 14, Atmo = C3(150,150,200), Density = 0.3, Haze = 1, Ambient = C3(150,150,200), Fog = C3(150,150,200), FogEnd = 1000, Stars = 0, Celestial = false, AllID = "", Faces = {} }

    task.spawn(function()
        pcall(function()
            game:GetService("ContentProvider"):PreloadAsync({ "rbxassetid://8833267735", "rbxassetid://122619816920309" })
        end)
    end)

    local function setDebugSkyGray(enabled)
        pcall(function()
            local fn = setfflag or set_fflag or setfastflag
            if fn then fn("FFlagDebugSkyGray", enabled and "true" or "false") end
        end)
    end

    local function normID(id)
        if not id or id == "" or id == "0" then return "" end
        local n = tostring(id):gsub("%D", "")
        return #n > 0 and ("rbxassetid://" .. n) or ""
    end

    local function currentSky()
        if skyChoice ~= "Custom" then return PRESETS[skyChoice] or PRESETS["GraySky"] end
        local faces = {}
        local all = normID(custom.AllID)
        for _, f in ipairs(FACES) do
            local own = normID(custom.Faces[f])
            faces[f] = own ~= "" and own or all
        end
        return setmetatable({ Faces = faces }, { __index = custom })
    end

    local mySky, myAtmo, cloudsWas
    local _lastCloudScan = 0
    local hidden = {}

    local function applySkyObjects()
        if skyOn then
            local cfg = currentSky()
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

            local faces = cfg.Faces or {}
            local needNew = false
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
                local _cn = tick()
                if _cn - _lastCloudScan > 2 then
                    _lastCloudScan = _cn
                    local terrain = workspace.Terrain
                    local clouds = terrain and terrain:FindFirstChildOfClass("Clouds")
                    if clouds and clouds.Enabled then
                        cloudsWas = true
                        clouds.Enabled = false
                    end
                end
            elseif cloudsWas then
                local terrain = workspace.Terrain
                local clouds = terrain and terrain:FindFirstChildOfClass("Clouds")
                if clouds then clouds.Enabled = true end
                cloudsWas = nil
            end
        else
            setDebugSkyGray(false)
            if cloudsWas then
                local terrain = workspace.Terrain
                local clouds = terrain and terrain:FindFirstChildOfClass("Clouds")
                if clouds then clouds.Enabled = true end
                cloudsWas = nil
            end
            if mySky then mySky:Destroy(); mySky = nil end
            if myAtmo then myAtmo:Destroy(); myAtmo = nil end
            for _, c in ipairs(hidden) do pcall(function() c.Parent = Lighting end) end
            hidden = {}
        end
    end

    local function desired()
        local d = {}
        if skyOn then
            local cfg = currentSky()
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
    local _lastWorldStep = 0
    local function step()
        local d = desired()
        for _, p in ipairs(PROPS) do
            local want = d[p]
            if want == nil then want = orig[p] end
            if Lighting[p] ~= want then pcall(function() Lighting[p] = want end) end
        end
        applySkyObjects()
    end

    local function refresh()
        if lightOn or skyOn then
            step()
            if not worldConn then
                worldConn = RunService.Heartbeat:Connect(function()
                    local t = tick()
                    if t - _lastWorldStep >= 0.25 then
                        _lastWorldStep = t
                        step()
                    end
                end)
            end
        else
            if worldConn then worldConn:Disconnect(); worldConn = nil end
            step()
        end
    end

    -- ===== Lighting Control UI =====
    local LightToggle = LightSection:AddToggle("WorldLight_Enabled", {
        Text = "Enable Lighting Override", Default = false,
        Callback = function(v) lightOn = v; refresh() end
    })
    LightToggle:AddKeyPicker("WorldLightKey", { Default = "None", SyncToggleState = true, Mode = "Toggle", Text = "Lighting Override" })

    local LightDep = LightSection:AddDependencyBox()

    local function lslider(prop, text, min, max, rounding)
        LightDep:AddSlider("WorldLight_" .. prop, {
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
    LightDep:AddToggle("WorldLight_GlobalShadows", {
        Text = "Global Shadows", Default = Lighting.GlobalShadows,
        Callback = function(v) lv.GlobalShadows = v end
    })
    local function lcolor(prop, text)
        LightDep:AddLabel(text):AddColorPicker("WorldLightColor_" .. prop, {
            Default = Lighting[prop], Title = text,
            Callback = function(v) lv[prop] = v end
        })
    end
    lcolor("Ambient", "Ambient")
    lcolor("OutdoorAmbient", "Outdoor Ambient")
    lcolor("ColorShift_Top", "Color Shift Top")
    lcolor("ColorShift_Bottom", "Color Shift Bottom")
    lcolor("FogColor", "Fog Color")
    LightDep:AddSlider("WorldLight_ClockTime", {
        Text = "Clock Time", Default = math.clamp(Lighting.ClockTime, 0, 24), Min = 0, Max = 24, Rounding = 1,
        Callback = function(v) lv.ClockTime = v end
    })

    LightDep:SetupDependencies({ { LightToggle, true } })

    -- ===== Post Processing =====
    local function getFx(class, name)
        local fx = Lighting:FindFirstChild(name)
        if not fx then
            fx = Instance.new(class)
            fx.Name = name
            fx.Enabled = false
            fx.Parent = Lighting
        end
        return fx
    end
    local function fxToggle(id, text, class, name)
        return FxSection:AddToggle(id, { Text = text, Default = false,
            Callback = function(v) getFx(class, name).Enabled = v end })
    end

    local bloomToggle = fxToggle("FX_Bloom", "Bloom", "BloomEffect", "KETYBloom")
    local bloomDep = FxSection:AddDependencyBox()
    bloomDep:AddSlider("FX_BloomIntensity", { Text = "Bloom Intensity", Default = 1, Min = 0, Max = 5, Rounding = 2,
        Callback = function(v) getFx("BloomEffect", "KETYBloom").Intensity = v end })
    bloomDep:AddSlider("FX_BloomSize", { Text = "Bloom Size", Default = 24, Min = 0, Max = 56, Rounding = 0,
        Callback = function(v) getFx("BloomEffect", "KETYBloom").Size = v end })
    bloomDep:AddSlider("FX_BloomThreshold", { Text = "Bloom Threshold", Default = 0.8, Min = 0, Max = 3, Rounding = 2,
        Callback = function(v) getFx("BloomEffect", "KETYBloom").Threshold = v end })
    bloomDep:SetupDependencies({ { bloomToggle, true } })

    local blurToggle = fxToggle("FX_Blur", "Blur", "BlurEffect", "KETYBlur")
    local blurDep = FxSection:AddDependencyBox()
    blurDep:AddSlider("FX_BlurSize", { Text = "Blur Size", Default = 8, Min = 0, Max = 56, Rounding = 0,
        Callback = function(v) getFx("BlurEffect", "KETYBlur").Size = v end })
    blurDep:SetupDependencies({ { blurToggle, true } })

    local sunRaysToggle = fxToggle("FX_SunRays", "Sun Rays", "SunRaysEffect", "KETYSunRays")
    local sunRaysDep = FxSection:AddDependencyBox()
    sunRaysDep:AddSlider("FX_SunRaysIntensity", { Text = "Sun Rays Intensity", Default = 0.25, Min = 0, Max = 1, Rounding = 2,
        Callback = function(v) getFx("SunRaysEffect", "KETYSunRays").Intensity = v end })
    sunRaysDep:AddSlider("FX_SunRaysSpread", { Text = "Sun Rays Spread", Default = 1, Min = 0, Max = 1, Rounding = 2,
        Callback = function(v) getFx("SunRaysEffect", "KETYSunRays").Spread = v end })
    sunRaysDep:SetupDependencies({ { sunRaysToggle, true } })

    local dofToggle = fxToggle("FX_DOF", "Depth Of Field", "DepthOfFieldEffect", "KETYDOF")
    local dofDep = FxSection:AddDependencyBox()
    dofDep:AddSlider("FX_DOFFar", { Text = "DOF Far Intensity", Default = 0.75, Min = 0, Max = 1, Rounding = 2,
        Callback = function(v) getFx("DepthOfFieldEffect", "KETYDOF").FarIntensity = v end })
    dofDep:AddSlider("FX_DOFFocus", { Text = "DOF Focus Distance", Default = 50, Min = 0, Max = 500, Rounding = 0,
        Callback = function(v) getFx("DepthOfFieldEffect", "KETYDOF").FocusDistance = v end })
    dofDep:AddSlider("FX_DOFRadius", { Text = "DOF In Focus Radius", Default = 30, Min = 0, Max = 200, Rounding = 0,
        Callback = function(v) getFx("DepthOfFieldEffect", "KETYDOF").InFocusRadius = v end })
    dofDep:SetupDependencies({ { dofToggle, true } })

    -- ===== Sky Changer UI =====
    local SkyToggle = SkySection:AddToggle("SkyChanger_Enabled", {
        Text = "Enable Sky Changer", Default = false,
        Callback = function(v) skyOn = v; refresh() end
    })
    SkyToggle:AddKeyPicker("SkyChangerKey", { Default = "None", SyncToggleState = true, Mode = "Toggle", Text = "Sky Changer" })

    local SkyDep = SkySection:AddDependencyBox()
    local SkyDrop = SkyDep:AddDropdown("SkyChanger_Preset", {
        Values = PRESET_LIST, Default = 1, Multi = false, Text = "Sky Preset",
        Callback = function(v)
            skyChoice = v
            if skyOn then step() end
        end
    })
    SkyDep:SetupDependencies({ { SkyToggle, true } })

    local CustomDep = SkySection:AddDependencyBox()
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
    CustomDep:SetupDependencies({ { SkyToggle, true }, { SkyDrop, "Custom" } })
end


do
    local RageBotSection = Tabs.Rage:AddRightGroupbox("RageBot")

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
        AntiHitStayDuration = 0.15,
        Method = "Normal",
        AttachPart = "Head",
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
    if getgenv().Config.AntiHitStayDuration == nil then getgenv().Config.AntiHitStayDuration = 0.15 end
    getgenv().Config.Method = getgenv().Config.Method or "Normal"
    getgenv().Config.AttachPart = getgenv().Config.AttachPart or "Head"
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
    getgenv().Config.VoidSpamType = "Normal"
    if getgenv().Config.KR_Offset == nil then getgenv().Config.KR_Offset = -0.002 end
    if getgenv().Config.KR_VoidTime == nil then getgenv().Config.KR_VoidTime = 0.3 end
    if getgenv().Config.KR_GroundTime == nil then getgenv().Config.KR_GroundTime = 0.3 end
    if getgenv().Config.DevMode == nil then getgenv().Config.DevMode = false end
    getgenv().RageBotConfig = getgenv().Config
    getgenv().RageBotConfig.AntiHit = false

    local currentTargetPart = nil
    local currentDesyncCF = nil
    local currentTargetPitch, currentTargetYaw, currentTargetRoll = nil, nil, nil

    -- ========== ON-SCREEN ATTACK BUTTON ==========
    if getgenv()._KETY_RageAttackButton then
        pcall(function() getgenv()._KETY_RageAttackButton:Destroy() end)
        getgenv()._KETY_RageAttackButton = nil
    end

    getgenv()._RageAttackHeld = false

    local targetGui = screenGui or getgenv().MyKETYESP
    local attackBtnContainer = Instance.new("Frame")
    attackBtnContainer.Name = "KETY_RageAttackContainer"
    attackBtnContainer.Size = UDim2.new(0, 80, 0, 80)
    attackBtnContainer.Position = UDim2.new(1, -100, 0.65, -40)
    attackBtnContainer.BackgroundTransparency = 1
    attackBtnContainer.Active = true
    attackBtnContainer.ZIndex = 50
    attackBtnContainer.Visible = (getgenv().Config.ShowAttackButton ~= false)
    do local _si=setthreadidentity or set_thread_identity or setidentity; if _si then pcall(_si,8) end end
    if targetGui then
        attackBtnContainer.Parent = targetGui
    end
    getgenv()._KETY_RageAttackButton = attackBtnContainer

    local attackBtn = Instance.new("TextButton")
    attackBtn.Name = "AttackButton"
    attackBtn.Size = UDim2.new(1, 0, 1, 0)
    attackBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
    attackBtn.BackgroundTransparency = 0.15
    attackBtn.Text = ""
    attackBtn.AutoButtonColor = false
    attackBtn.ZIndex = 51
    attackBtn.Parent = attackBtnContainer

    local attackCorner = Instance.new("UICorner")
    attackCorner.CornerRadius = UDim.new(0, 20)
    attackCorner.Parent = attackBtn

    local attackStroke = Instance.new("UIStroke")
    attackStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    attackStroke.Color = Color3.fromRGB(255, 60, 60)
    attackStroke.Thickness = 2
    attackStroke.Transparency = 0.2
    attackStroke.Parent = attackBtn

    local attackTitle = Instance.new("TextLabel")
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

    local attackSub = Instance.new("TextLabel")
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
        local auto = (getgenv().Config and getgenv().Config.AutoAttack ~= false)
        local isHeld = (getgenv()._RageAttackHeld == true)
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

    local isDragging = false
    local dragInput = nil
    local dragStart = nil
    local startPos = nil

    local function updateDrag(input)
        local delta = input.Position - dragStart
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

    local UserInputService = game:GetService("UserInputService")
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragStart and startPos then
            local delta = input.Position - dragStart
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
            if not dragStart and not isDragging and not getgenv()._RageAttackHeld then return end
            dragStart = nil
            isDragging = false
            getgenv()._RageAttackHeld = false
            updateAttackBtnVisual()
        end
    end)

    -- ========== RAGEBOT TOGGLES ==========
    local origFallenHeight = workspace.FallenPartsDestroyHeight
    local RageBotToggle = RageBotSection:AddToggle("RageBot_Enabled", {
        Text = "Enable RageBot",
        Default = false,
        Callback = function(value)
            getgenv().Config.Enabled = value
            getgenv().RageBotConfig.Enabled = value
            if value then
                pcall(function()
                    workspace.FallenPartsDestroyHeight = 0/0
                    if workspace.FallenPartsDestroyHeight == workspace.FallenPartsDestroyHeight then
                        workspace.FallenPartsDestroyHeight = -9e9
                    end
                end)
            else
                pcall(function()
                    if origFallenHeight then
                        workspace.FallenPartsDestroyHeight = origFallenHeight
                    end
                end)
            end
        end
    })

    RageBotToggle:AddKeyPicker("RageBotKey", {
        Default = "None",
        SyncToggleState = true,
        Mode = "Toggle",
        Text = "RageBot",
    })

    -- Enabled が ON の時のみ RageBot 設定を表示する
    local RageEnabledDep = RageBotSection:AddDependencyBox()
    local RageMethodDropdown = RageEnabledDep:AddDropdown("RageBot_Method", {
        Values = {"Normal", "Kicia", "KillRagers"},
        Default = 1,
        Multi = false,
        Text = "Rage Type",
        Callback = function(value)
            getgenv().Config.Method = value
            if getgenv().RageBotConfig then getgenv().RageBotConfig.Method = value end
        end
    })
    RageEnabledDep:AddToggle("RageBot_DevMode", {
        Text = "DevMode",
        Default = false,
        Callback = function(value)
            getgenv().Config.DevMode = value
            if getgenv().RageBotConfig then getgenv().RageBotConfig.DevMode = value end
        end
    })
    RageEnabledDep:SetupDependencies({ { RageBotToggle, true } })

    local KRDep = RageBotSection:AddDependencyBox()
    KRDep:AddSlider("RageBot_KR_Offset", {
        Text = "Offset",
        Default = -0.002,
        Min = -5,
        Max = 5,
        Rounding = 4,
        Callback = function(value) getgenv().Config.KR_Offset = value end
    })
    KRDep:AddSlider("RageBot_KR_VoidTime", {
        Text = "VoidTime",
        Default = 0.3,
        Min = 0.05,
        Max = 5,
        Rounding = 2,
        Callback = function(value) getgenv().Config.KR_VoidTime = value end
    })
    KRDep:AddSlider("RageBot_KR_GroundTime", {
        Text = "GroundTime",
        Default = 0.3,
        Min = 0.05,
        Max = 5,
        Rounding = 2,
        Callback = function(value) getgenv().Config.KR_GroundTime = value end
    })
    KRDep:SetupDependencies({ { RageBotToggle, true }, { RageMethodDropdown, "KillRagers" } })

    local RageBotAutoAttackToggle = RageEnabledDep:AddToggle("RageBot_AutoAttack", {
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

    local RageBotShowBtnToggle = RageEnabledDep:AddToggle("RageBot_ShowButton", {
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

    local RageBotTeamCheckToggle = RageEnabledDep:AddToggle("RageBot_TeamCheck", {
        Text = "FFA",
        Default = false,
        Callback = function(value)
            getgenv().Config.TeamCheck = not value
            if getgenv().RageBotConfig then getgenv().RageBotConfig.TeamCheck = not value end
        end
    })

    local WeaponSlotDropdown = RageEnabledDep:AddDropdown("RageBot_Slot", {
        Values = {"Primary", "Secondary", "Melee", "Knife"},
        Default = 1,
        Multi = false,
        Text = "Weapon Slot",
        Callback = function(value)
            getgenv().Config.WeaponSlot = value
            getgenv().RageBotConfig.WeaponSlot = value
            local FighterController = nil
            pcall(function()
                FighterController = require(lp.PlayerScripts:WaitForChild("Controllers"):WaitForChild("FighterController"))
            end)
            local localFighter = FighterController and FighterController.LocalFighter
            if localFighter then
                pcall(function()
                    local slots = { Primary = 1, Secondary = 2, Melee = 3, Knife = 3 }
                    localFighter:EquipItem(slots[value] or 3)
                end)
            end
        end
    })

    local RageBotTargetPartDropdown = RageEnabledDep:AddDropdown("RageBot_TargetPart", {
        Values = getgenv().KETY_TargetPartValues,
        Default = 1,
        Multi = false,
        Text = "Target Part",
        Callback = function(value)
            getgenv().Config.TargetPart = value
            if getgenv().RageBotConfig then getgenv().RageBotConfig.TargetPart = value end
        end
    })

    local RageBotTargetSortDropdown = RageEnabledDep:AddDropdown("RageBot_TargetSort", {
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

    -- Kicia 専用: 接着パーツ選択
    local KiciaDep = RageBotSection:AddDependencyBox()
    local KiciaAttachPartDropdown = KiciaDep:AddDropdown("RageBot_AttachPart", {
        Values = {
            "Head", "HumanoidRootPart", "UpperTorso", "LowerTorso",
            "Left Arm", "Right Arm", "Left Leg", "Right Leg",
            "HitboxHead", "HitboxBody"
        },
        Default = 1,
        Multi = false,
        Text = "Attach Part",
        Callback = function(value)
            getgenv().Config.AttachPart = value
            if getgenv().RageBotConfig then getgenv().RageBotConfig.AttachPart = value end
        end
    })
    KiciaDep:SetupDependencies({ { RageBotToggle, true }, { RageMethodDropdown, "Kicia" } })

    local PrimaryTPDep = RageBotSection:AddDependencyBox()
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
    PrimaryTPDep:SetupDependencies({ { RageBotToggle, true }, { RageMethodDropdown, "Normal" }, { WeaponSlotDropdown, "Primary" } })

    local SecondaryTPDep = RageBotSection:AddDependencyBox()
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
    SecondaryTPDep:SetupDependencies({ { RageBotToggle, true }, { RageMethodDropdown, "Normal" }, { WeaponSlotDropdown, "Secondary" } })

    local MeleeTPDep = RageBotSection:AddDependencyBox()
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
    MeleeTPDep:SetupDependencies({ { RageBotToggle, true }, { RageMethodDropdown, "Normal" }, { WeaponSlotDropdown, "Melee" } })

    local AntiHitToggle = RageEnabledDep:AddToggle("RageBot_AntiHit", {
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

    local AntiHitDep = RageBotSection:AddDependencyBox()
    AntiHitDep:AddSlider("RageBot_AntiHitDuration", {
        Text = "Hide Duration (sec)",
        Default = 0.5,
        Min = 0.25,
        Max = 2.0,
        Rounding = 2,
        Callback = function(value)
            getgenv().Config.AntiHitDuration = value
            getgenv().RageBotConfig.AntiHitDuration = value
        end
    })
    AntiHitDep:AddSlider("RageBot_AntiHitStayDuration", {
        Text = "Stay Duration (sec)",
        Default = 0.15,
        Min = 0.01,
        Max = 1.0,
        Rounding = 2,
        Callback = function(value)
            getgenv().Config.AntiHitStayDuration = value
            getgenv().RageBotConfig.AntiHitStayDuration = value
        end
    })
    AntiHitDep:SetupDependencies({ { RageBotToggle, true }, { AntiHitToggle, true } })

    task.spawn(function()
        local repS = cloneref(game:GetService("ReplicatedStorage"))
        local plrs = cloneref(game:GetService("Players"))
        local runS = cloneref(game:GetService("RunService"))
        local ws = cloneref(game:GetService("Workspace"))
        local uis = cloneref(game:GetService("UserInputService"))
        local lplr = plrs.LocalPlayer

        local util = nil
        local enum = nil
        pcall(function() util = require(repS.Modules.Utility) end)
        pcall(function() enum = require(repS.Modules.EnumLibrary) end)

        local FighterController = nil
        local SpectateController = nil
        local MechanicsController = nil
        local KnifeModule = nil

        task.spawn(function()
            pcall(function()
                local ps = lplr:WaitForChild("PlayerScripts", 5)
                if ps then
                    local controllers = ps:WaitForChild("Controllers", 5)
                    if controllers then
                        local fc = controllers:WaitForChild("FighterController", 5)
                        if fc then FighterController = require(fc) end
                        local sc = controllers:WaitForChild("SpectateController", 5)
                        if sc then SpectateController = require(sc) end
                        local mc = controllers:WaitForChild("MechanicsController", 5)
                        if mc then MechanicsController = require(mc) end
                    end
                    local modules = ps:WaitForChild("Modules", 5)
                    local items = modules and modules:WaitForChild("Items", 5)
                    local km = items and items:WaitForChild("Knife", 5)
                    if km then KnifeModule = require(km) end
                end
            end)
        end)

        local slots = {
            Primary = 1,
            Secondary = 2,
            Melee = 3,
            Knife = 3
        }

        local function getSlotNumber()
            return slots[getgenv().Config.WeaponSlot] or 3
        end

        local camRemote = nil
        task.spawn(function()
            pcall(function()
                local remotes = repS:WaitForChild("Remotes", 5)
                local replication = remotes and remotes:WaitForChild("Replication", 5)
                local fighter = replication and replication:WaitForChild("Fighter", 5)
                camRemote = fighter and fighter:WaitForChild("UpdateCameraRotation", 5)
            end)
        end)

        if util and not getgenv()._ragebotUtilHooked then
            getgenv()._ragebotUtilHooked = true
            local oldEncode = util.EncodeCameraRotation
            util.EncodeCameraRotation = function(self, rot)
                if getgenv().Config and getgenv().Config.Enabled and getgenv().Config.WeaponSlot == "Knife" and currentTargetYaw and typeof(rot) == "Vector2" then
                    rot = Vector2.new(currentTargetPitch or 0, currentTargetYaw)
                end
                return oldEncode(self, rot)
            end
        end

        if not getgenv()._ragebotCamHooked and getgenv().KETY_HookNamecall then
            getgenv()._ragebotCamHooked = true
            getgenv().KETY_HookNamecall({"FireServer"}, function(oldNamecall)
                return function(self, ...)
                    local cfg = getgenv().Config
                    local knifeMode = cfg and cfg.Enabled and cfg.WeaponSlot == "Knife" and currentTargetYaw
                    if not kiciaActive and not knifeMode then
                        return oldNamecall(self, ...)
                    end
                    if checkcaller() then return oldNamecall(self, ...) end
                    if knifeMode and camRemote and self == camRemote then
                        local encoded = util and util:EncodeCameraRotation(Vector2.new(currentTargetPitch or 0, currentTargetYaw))
                        if encoded then
                            return oldNamecall(self, encoded, nil)
                        end
                    end
                    local sname = self.Name
                    if sname == "UpdateState" and kiciaActive and enum and (...) == enum:ToEnum("IsCrouching") then return oldNamecall(self, (...), true) end
                    if sname == "UpdateCameraRotation" and knifeMode then
                        local encoded = util and util:EncodeCameraRotation(Vector2.new(currentTargetPitch or 0, currentTargetYaw))
                        if encoded then
                            return oldNamecall(self, encoded, nil)
                        end
                    end
                    return oldNamecall(self, ...)
                end
            end)
        end

        local shot_offset_cf = nil
        if util then
            pcall(function()
                shot_offset_cf = util:EncodeCFrame(CFrame.new(0.43, 0.25, 0.42))
            end)
        end

        local function BuildShotPayload(origin, target, part)
            local aim_cf = util:EncodeCFrame(CFrame.new(origin, target))
            if getgenv().Config and getgenv().Config.WeaponSlot == "Knife" and currentTargetYaw and aim_cf then aim_cf[utf8.char(4)] = currentTargetYaw; aim_cf[utf8.char(5)] = currentTargetRoll or 0 end
            return {
                [utf8.char(0)] = aim_cf,
                [utf8.char(1)] = aim_cf,
                [utf8.char(2)] = part,
                [utf8.char(3)] = shot_offset_cf,
            }
        end

        if KnifeModule and not getgenv().KnifeHooked_RageBot then
            getgenv().KnifeHooked_RageBot = true
            local old_knife = KnifeModule.StartAiming
            KnifeModule.StartAiming = function(self, ...)
                if getgenv().Config.WeaponSlot == "Knife" and currentTargetPart and currentDesyncCF then
                    local results = {old_knife(self, ...)}
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
                local localFighter = FighterController and FighterController.LocalFighter
                if localFighter then
                    pcall(function()
                        localFighter:EquipItem(getSlotNumber())
                    end)
                end
            end
        end)

        -- ========== KICIA (NoDelaySnap.lua の TP ロジック) ==========
        local getthreadidentity_ = getthreadidentity or getidentity
        local setthreadidentity_ = setthreadidentity or setidentity
        local sethiddenproperty_ = sethiddenproperty or set_hidden_property
        local setsimulationradius_ = setsimulationradius or set_simulation_radius
        local KiciaInstanceHandle = getgenv().InstanceHandle or { new = function(x) return x end }
        local kiciaActive = false
        local kiciaLastPart = nil

        local function kiciaSetRepRoot(part, target)
            if not part or not sethiddenproperty_ then return false end
            local oldIdentity = getthreadidentity_ and getthreadidentity_()
            if setthreadidentity_ then pcall(setthreadidentity_, 8) end
            local handle = nil
            if target then
                local hok, h = pcall(KiciaInstanceHandle.new, target)
                handle = hok and h or target
            end
            local ok, res = pcall(sethiddenproperty_, part, "PhysicsRepRootRef", handle)
            if setthreadidentity_ then
                local restId = (type(oldIdentity) == "number" and oldIdentity >= 7) and oldIdentity or 8
                pcall(setthreadidentity_, restId)
            end
            return ok, res
        end

        local function kiciaReset(myRoot)
            if not kiciaActive then return end
            kiciaActive = false
            kiciaLastPart = nil
            if myRoot then kiciaSetRepRoot(myRoot, myRoot) end
            pcall(function() if enum then repS.Remotes.Replication.Fighter.UpdateState:FireServer(enum:ToEnum("IsCrouching"), MechanicsController and MechanicsController.IsCrouching or false) end end)
        end

        local KICIA_PART_NAMES = {
            ["Head"] = { "Head" },
            ["HumanoidRootPart"] = { "HumanoidRootPart" },
            ["UpperTorso"] = { "UpperTorso", "Torso" },
            ["LowerTorso"] = { "LowerTorso", "Torso" },
            ["Left Arm"] = { "LeftUpperArm", "Left Arm" },
            ["Right Arm"] = { "RightUpperArm", "Right Arm" },
            ["Left Leg"] = { "LeftUpperLeg", "Left Leg" },
            ["Right Leg"] = { "RightUpperLeg", "Right Leg" },
            ["HitboxHead"] = { "HitboxHead", "Head" },
            ["HitboxBody"] = { "HitboxBody", "HumanoidRootPart" },
        }
        local function resolveKiciaAttachPart(pChar)
            if not pChar then return nil end
            local mode = getgenv().Config and getgenv().Config.AttachPart or "Head"
            local names = KICIA_PART_NAMES[mode] or { mode }
            for _, n in ipairs(names) do
                local p = pChar:FindFirstChild(n)
                if p and p:IsA("BasePart") then return p end
            end
            return pChar:FindFirstChild("HumanoidRootPart")
        end

        local lastFire = 0
        local lastTarget = nil
        local tpStartTime = 0
        local antiHitStart = 0
        local antiHitUntil = 0
        local DeflectingPlayers = getgenv().DeflectingPlayers or {}
        local function isPlayerParrying(player)
            if not player then return false end
            local endTime = DeflectingPlayers[player]
            return endTime and tick() < endTime
        end

        local function isEnemy(player)
            if player == lplr then return false end
            local tc = getgenv().Config and getgenv().Config.TeamCheck
            if tc == false then return true end
            return getgenv().KETY_IsEnemy(player)
        end

        local function resolveRageTargetPart(pChar)
            if not pChar then return nil end
            local mode = getgenv().Config and getgenv().Config.TargetPart or "HitboxHead"
            return getgenv().KETY_ResolveTargetPart(pChar, mode)
        end

        local function getClosestTarget()
            local char = lplr.Character
            if not char then return nil, nil, nil end
            local myRoot = char:FindFirstChild("HumanoidRootPart")
            if not myRoot then return nil, nil, nil end

            local mousePos = Vector2.new(0, 0)
            local uisOk, uis = pcall(function() return game:GetService("UserInputService") end)
            if uisOk and uis and uis.GetMouseLocation then
                pcall(function() mousePos = uis:GetMouseLocation() end)
            end
            local curCam = ws.CurrentCamera

            local tc = getgenv().Config and getgenv().Config.TeamCheck
            local candidates = {}
            for _, player in plrs:GetPlayers() do
                if not isEnemy(player) then continue end
                local pChar = player.Character
                if not pChar then continue end
                local pRoot = pChar:FindFirstChild("HumanoidRootPart")
                local pHum = pChar:FindFirstChildWhichIsA("Humanoid")
                if not (pRoot and pHum and pHum.Health > 0) then continue end

                if tc == false then
                    local isInvincible = false
                    pcall(function()
                        if FighterController and type(FighterController.GetFighter) == "function" then
                            local fighter = FighterController:GetFighter(player)
                            if fighter and fighter.Entity then
                                isInvincible = fighter.Entity:Get("IsInvincible") == true
                            end
                        end
                    end)
                    if isInvincible then continue end
                end

                local pTargetPart = resolveRageTargetPart(pChar)
                if not pTargetPart then continue end

                local dist = (myRoot.Position - pRoot.Position).Magnitude
                local maxDist = (tc == false) and 300 or math.huge
                if dist > maxDist then continue end

                local mouseDist = 999999
                if curCam then
                    local pScr, pOn = curCam:WorldToViewportPoint(pTargetPart.Position)
                    if pOn and pScr.Z > 0 then
                        mouseDist = (Vector2.new(pScr.X, pScr.Y) - mousePos).Magnitude
                    else
                        mouseDist = (Vector2.new(pScr.X, pScr.Y) - mousePos).Magnitude + 2000
                    end
                end

                table.insert(candidates, {
                    player = player,
                    root = pRoot,
                    targetPart = pTargetPart,
                    worldDist = dist,
                    health = pHum.Health,
                    mouseDist = mouseDist,
                })
            end

            if #candidates == 0 then return nil, nil, nil end

            local sortMethod = getgenv().Config and getgenv().Config.TargetSort or "Distance (Closest)"
            table.sort(candidates, function(a, b)
                if sortMethod == "Distance (Closest)" then
                    return a.worldDist < b.worldDist
                elseif sortMethod == "Distance (Farthest)" then
                    return a.worldDist > b.worldDist
                elseif sortMethod == "Health (Lowest)" then
                    return a.health < b.health
                elseif sortMethod == "Health (Highest)" then
                    return a.health > b.health
                elseif sortMethod == "Mouse (Closest)" then
                    return a.mouseDist < b.mouseDist
                elseif sortMethod == "Mouse (Farthest)" then
                    return a.mouseDist > b.mouseDist
                else
                    return a.worldDist < b.worldDist
                end
            end)

            local chosen = candidates[1]
            return chosen.player, chosen.root, chosen.targetPart
        end

        -- ========== KillRagers VoidSpam ==========
        local kr = { active = false, inVoid = true, phaseStart = 0, lastWarp = 0, frozen = nil, angle = 0, cx = 0, cz = 0, cache = nil }
        local krRng = Random.new()
        local krRadius, krSpeed = 80, 20

        local function krComputeVoidPos()
            local map = ws:FindFirstChild("Map")
            local folder = map and map:FindFirstChild("Barriers")
            local barriers = {}
            if folder then
                for _, part in ipairs(folder:GetChildren()) do
                    if part:IsA("BasePart") then table.insert(barriers, part) end
                end
            end
            if #barriers == 0 then return nil end
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Include
            params.FilterDescendantsInstances = barriers
            local spawns = ws:FindFirstChild("Spawns")
            if not spawns then return nil end
            for _, obj in ipairs(spawns:GetDescendants()) do
                local origin
                if obj:IsA("Model") then
                    local pv = obj:FindFirstChild("Position")
                    if pv and pv:IsA("Vector3Value") then origin = pv.Value end
                elseif obj:IsA("BasePart") then
                    origin = obj.Position
                end
                if origin then
                    local ok, res = pcall(ws.Raycast, ws, origin + Vector3.new(0, 2, 0), Vector3.new(0, -500, 0), params)
                    if ok and res and res.Position.Y < 0 then return res.Position end
                end
            end
            return nil
        end

        local function krTranslocateCF(root)
            if not kr.cache then kr.cache = krComputeVoidPos() end
            local off = getgenv().Config.KR_Offset or -0.002
            if kr.cache then
                return CFrame.new(kr.cache.X, kr.cache.Y + off, kr.cache.Z)
            end
            for _, part in ipairs(game:GetService("CollectionService"):GetTagged("OutOfBoundsPart")) do
                if part:GetAttribute("KillDelay") == 0 then
                    return part.CFrame * CFrame.new(0, -part.Size.Y / 2 + off, 0)
                end
            end
            return CFrame.new(root.Position.X, -100 + off, root.Position.Z)
        end

        local function krStep(root)
            local cfg = getgenv().Config
            local now = tick()
            if not kr.active then
                kr.active = true
                kr.inVoid = true
                kr.phaseStart = now
                kr.lastWarp = 0
                kr.frozen = nil
            end
            local elapsed = now - kr.phaseStart
            local cf
            if kr.inVoid then
                if kr.lastWarp == 0 then
                    cf = krTranslocateCF(root)
                    kr.frozen = cf
                    kr.cx, kr.cz, kr.angle = cf.Position.X, cf.Position.Z, 0
                    kr.lastWarp = 1
                elseif kr.frozen then
                    kr.angle = kr.angle + krSpeed / 60
                    cf = CFrame.new(kr.cx + math.cos(kr.angle) * krRadius, kr.frozen.Position.Y, kr.cz + math.sin(kr.angle) * krRadius)
                end
                if elapsed >= (cfg.KR_VoidTime or 0.3) then
                    kr.inVoid = false
                    kr.phaseStart = now
                    kr.lastWarp = 0
                    kr.frozen = nil
                end
            else
                local ang = krRng:NextNumber(0, math.pi * 2)
                local p = root.Position
                cf = CFrame.new(p.X + math.cos(ang) * 900000000, p.Y, p.Z + math.sin(ang) * 900000000)
                if elapsed >= (cfg.KR_GroundTime or 0.3) then
                    kr.inVoid = true
                    kr.phaseStart = now
                    kr.lastWarp = 0
                end
            end
            return cf
        end

        runS.Heartbeat:Connect(function()
            if not getgenv().Config.Enabled then
                if kiciaActive then
                    kiciaReset(lplr.Character and lplr.Character:FindFirstChild("HumanoidRootPart"))
                end
                return
            end
            pcall(function()
                if workspace.FallenPartsDestroyHeight == workspace.FallenPartsDestroyHeight and workspace.FallenPartsDestroyHeight > -100000 then
                    workspace.FallenPartsDestroyHeight = 0/0
                    if workspace.FallenPartsDestroyHeight == workspace.FallenPartsDestroyHeight then
                        workspace.FallenPartsDestroyHeight = -9e9
                    end
                end
            end)
            local myRoot = lplr.Character and lplr.Character:FindFirstChild("HumanoidRootPart")
            if not myRoot then return end

            local isKicia = (getgenv().Config.Method == "Kicia")
            if (not isKicia) and kiciaActive then kiciaReset(myRoot) end

            local tc = getgenv().Config and getgenv().Config.TeamCheck
            if tc ~= false then
                local myTeam = lplr:GetAttribute("TeamID")
                if not myTeam and SpectateController then
                    local duel = SpectateController.CurrentDuelSubject
                    local localDueler = duel and duel:GetDueler(lplr)
                    myTeam = localDueler and localDueler:Get("TeamID") or nil
                end
                if not myTeam then
                    currentTargetPitch, currentTargetYaw, currentTargetRoll = nil, nil, nil
                    kiciaReset(myRoot)
                    return
                end
            end

            local item = nil
            local isReloading = false
            if FighterController and FighterController.LocalFighter then
                item = FighterController.LocalFighter.EquippedItem
                if item then
                    pcall(function()
                        local ammo = item:Get("Ammo")
                        local reloadCD = item._reload_cooldown or 0
                        local isMeleeOrKnife = (getgenv().Config.WeaponSlot == "Melee" or getgenv().Config.WeaponSlot == "Knife")
                        if not isMeleeOrKnife then
                            isReloading = (tick() < reloadCD)
                                or (type(ammo) == "number" and ammo <= 0)
                        end
                    end)
                end
            end

            local targetPlayer, targetRoot, targetPart = getClosestTarget()

            local myFF = false
            local targetFF = false
            pcall(function()
                local lf = FighterController and FighterController.LocalFighter
                if lf and lf.Entity then
                    myFF = lf.Entity:Get("IsInvincible") == true
                end
            end)
            if targetPlayer then
                pcall(function()
                    local fighter = FighterController:GetFighter(targetPlayer)
                    if fighter and fighter.Entity then
                        targetFF = fighter.Entity:Get("IsInvincible") == true
                    end
                end)
            end

            local now = tick()
            local isEscaping = getgenv().Config and getgenv().Config.AntiHit and (now >= antiHitStart and now < antiHitUntil)
            local isAntiHitDelay = getgenv().Config and getgenv().Config.AntiHit and (now < antiHitStart)

            local autoAttack = (getgenv().Config and getgenv().Config.AutoAttack ~= false)
            local isManualClick = false
            pcall(function()
                if uis then
                    isManualClick = uis:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                end
            end)
            local isAttackButtonHeld = (getgenv()._RageAttackHeld == true)
            local canAttack = autoAttack or isAttackButtonHeld or isManualClick

            local canTarget = getgenv().Config.Enabled
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
            local kiciaTarget = nil
            if canTarget then

                local baseCFrame = targetRoot.CFrame
                local p, y, r = baseCFrame:ToOrientation()
                currentTargetPitch, currentTargetYaw, currentTargetRoll = p, y, r


                local curSlot = getgenv().Config.WeaponSlot or "Primary"
                if isKicia then
                    -- Kicia: 接着パーツへ NoDelaySnap 方式でスナップ（オフセット無し）
                    local kiciaPart = resolveKiciaAttachPart(targetPlayer.Character)
                    if kiciaPart then
                        local attachPos = kiciaPart.Position + Vector3.new(0, -0.7, 0.05)
                        if curSlot == "Knife" then
                            desyncCF = CFrame.new(attachPos) * (baseCFrame - baseCFrame.Position)
                        elseif (attachPos - targetPart.Position).Magnitude > 0.001 then
                            desyncCF = CFrame.lookAt(attachPos, targetPart.Position)
                        else
                            desyncCF = kiciaPart.CFrame
                        end
                        kiciaTarget = kiciaPart
                    end
                end
                if not desyncCF then
                local ox, oy, oz
                if curSlot == "Knife" then
                    ox = 0
                    oy = 5
                    oz = 0
                else
                    local offsets = (getgenv().Config.TPOffsets and getgenv().Config.TPOffsets[curSlot])
                    ox = (offsets and offsets.X) or 0
                    oy = (offsets and offsets.Y) or 5
                    oz = (offsets and offsets.Z) or 0
                end

                local desyncPos = (baseCFrame * CFrame.new(ox, oy, oz)).Position
                if curSlot == "Knife" then
                    local lookTarget = Vector3.new(targetPart.Position.X, desyncPos.Y, targetPart.Position.Z)
                    if (desyncPos - lookTarget).Magnitude > 0.001 then
                        desyncCF = CFrame.new(desyncPos) * (baseCFrame - baseCFrame.Position)
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
                end
            else
                currentTargetPitch, currentTargetYaw, currentTargetRoll = nil, nil, nil
                kiciaReset(myRoot)
                if getgenv().Config.Method == "KillRagers" then
                    desyncCF = krStep(myRoot) or myRoot.CFrame
                elseif tc == false then
                    desyncCF = myRoot.CFrame + Vector3.new(0, 900000000, 0)
                elseif getgenv().Config.DevMode then
                    desyncCF = targetRoot and (targetRoot.CFrame + Vector3.new(0, 5, 0)) or myRoot.CFrame
                else
                    local randomDir = Vector3.new(
                        math.random(-100, 100),
                        math.random(-100, 100),
                        math.random(-100, 100)
                    ).Unit
                    local cam = ws.CurrentCamera
                    local camPos = cam and cam.CFrame.Position or Vector3.new(0, 0, 0)
                    desyncCF = CFrame.new(camPos + randomDir * 7000000000000)
                end
            end
            if canTarget or getgenv().Config.Method ~= "KillRagers" then kr.active = false end

            local ffaOn = getgenv().FFA and getgenv().FFA.Want()
            local ffaPickup = ffaOn and (tc == false) or false
            if ffaOn then getgenv().FFA.Touch() end

            local oldCF     = myRoot.CFrame
            local oldVel    = myRoot.Velocity
            local oldRotVel = myRoot.RotVelocity
            myRoot.CFrame = desyncCF
            if ffaPickup then getgenv().FFA.Move(desyncCF.Position) end
            if kiciaTarget then
                -- NoDelaySnap 方式: 物理レプリケーションルートを接着パーツに差し替え
                if setsimulationradius_ then pcall(setsimulationradius_, math.huge, math.huge) end
                local myChar = lplr.Character
                if myChar then
                    for _, p in ipairs(myChar:GetDescendants()) do
                        if p:IsA("BasePart") then p.CanCollide = false end
                    end
                end
                local tChar = kiciaTarget.Parent
                if tChar then
                    for _, p in ipairs(tChar:GetDescendants()) do
                        if p:IsA("BasePart") then p.CanCollide = false end
                    end
                end
                if kiciaLastPart ~= kiciaTarget then
                    kiciaLastPart = kiciaTarget
                    myRoot.AssemblyLinearVelocity = Vector3.zero
                    myRoot.AssemblyAngularVelocity = Vector3.zero
                    myRoot.Anchored = true
                    kiciaSetRepRoot(myRoot, kiciaTarget)
                    myRoot.Anchored = false
                end
                if not kiciaActive then
                    kiciaActive = true
                    pcall(function() if enum then repS.Remotes.Replication.Fighter.UpdateState:FireServer(enum:ToEnum("IsCrouching"), true) end end)
                end
                kiciaSetRepRoot(myRoot, kiciaTarget)
                local kVel = kiciaTarget.AssemblyLinearVelocity
                myRoot.AssemblyLinearVelocity = kVel
                myRoot.AssemblyAngularVelocity = kiciaTarget.AssemblyAngularVelocity
                pcall(function() myRoot.Velocity = kVel end)
            elseif kiciaActive then
                kiciaReset(myRoot)
            end
            currentDesyncCF = desyncCF
            pcall(function() runS:UnbindFromRenderStep("__restore") end)
            runS:BindToRenderStep("__restore", 101, function()
                _fixId()
                if myRoot then
                    myRoot.CFrame    = oldCF
                    myRoot.Velocity  = oldVel
                    myRoot.RotVelocity = oldRotVel
                end
                pcall(function() runS:UnbindFromRenderStep("__restore") end)
            end)

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

            local isKnife = (getgenv().Config.WeaponSlot == "Knife")
            local ping = 0
            pcall(function()
                ping = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
            end)
            if ping <= 0 then
                pcall(function() ping = lplr:GetNetworkPing() end)
            end
            local minTpDelay = isKnife and (ping + 0.01) or (ping + 0.05)
            if tick() - tpStartTime < minTpDelay then return end

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

            local originPos = desyncCF.Position
            local targetPos = targetPart.Position
            local aimCF    = (isKnife and currentTargetYaw) and (CFrame.new(originPos) * CFrame.fromOrientation(currentTargetPitch or 0, currentTargetYaw, currentTargetRoll or 0)) or CFrame.lookAt(originPos, targetPos)
            local randomOffset = Vector3.new(
                (math.random() - 0.5) * 0.1,
                (math.random() - 0.5) * 0.1,
                (math.random() - 0.5) * 0.1
            )
            local aimedPos = targetPos + randomOffset
            local objSpaceHeadOffset = targetPart.CFrame:ToObjectSpace(CFrame.new(aimedPos))
            local cameradata = {}
            cameradata[utf8.char(1)] = {
                [utf8.char(0)] = util:EncodeCFrame(aimCF),
                [utf8.char(1)] = util:EncodeCFrame(aimCF),
                [utf8.char(2)] = targetPart,
                [utf8.char(3)] = util:EncodeCFrame(objSpaceHeadOffset)
            }
            if isKnife and camRemote and currentTargetYaw then
                pcall(function()
                    local enc = util:EncodeCameraRotation(Vector2.new(currentTargetPitch or 0, currentTargetYaw))
                    camRemote:FireServer(enc, nil)
                end)
            end

            -- AntiHit: FireServer の前にタイマーをセット（撃つ前にTP予約）
            if getgenv().Config and getgenv().Config.AntiHit then
                local now = tick()
                local stayDur = getgenv().Config.AntiHitStayDuration or 0.15
                antiHitStart = now + stayDur
                antiHitUntil = antiHitStart + (getgenv().Config.AntiHitDuration or 0.5)
            end

            repS.Remotes.Replication.Fighter.UseItem:FireServer(
                item:Get("ObjectID"),
                enum:ToEnum(isKnife and "StartAiming" or "StartShooting"),
                cameradata,
                nil
            )
        end)
    end)

    -- ===== FFA =====
    local FFASection = Tabs.Rage:AddLeftGroupbox("FFA")
    local FFASettings = {
        AutoHealth = true,
        AutoAmmo = true,
    }

    FFASection:AddToggle("FFA_AutoHealth", {
        Text = "Auto Health", Default = true,
        Callback = function(value) FFASettings.AutoHealth = value end
    })
    FFASection:AddToggle("FFA_AutoAmmo", {
        Text = "Auto Ammo", Default = true,
        Callback = function(value) FFASettings.AutoAmmo = value end
    })

    local function wantDrop(obj)
        if obj.Name ~= "_drop" or not obj:IsA("BasePart") then return false end
        if FFASettings.AutoAmmo and (obj:FindFirstChild("AmmoBalanced") or obj:FindFirstChild("Ammo")) then return true end
        if FFASettings.AutoHealth and obj:FindFirstChild("Health") then return true end
        return false
    end

    getgenv().FFA = {
        Want = function()
            for _, obj in workspace:GetChildren() do
                if wantDrop(obj) then return true end
            end
            return false
        end,
        Pos = function()
            for _, obj in workspace:GetChildren() do
                if wantDrop(obj) then return obj.Position end
            end
        end,
        Touch = function()
            if not firetouchinterest then return end
            local char = lp.Character
            local body = char and (char:FindFirstChild("HitboxBody") or char:FindFirstChild("HumanoidRootPart"))
            if not body then return end
            for _, obj in workspace:GetChildren() do
                if wantDrop(obj) then
                    pcall(function()
                        firetouchinterest(obj, body, 0)
                        firetouchinterest(obj, body, 1)
                    end)
                end
            end
        end,
        Move = function(pos)
            local cf = CFrame.new(pos)
            for _, obj in workspace:GetChildren() do
                if wantDrop(obj) then
                    obj.Anchored = false
                    obj.CanCollide = false
                    obj.AssemblyLinearVelocity = Vector3.zero
                    obj.CFrame = cf
                    obj.Transparency = 1
                    for _, child in pairs(obj:GetDescendants()) do
                        if child:IsA("BasePart") or child:IsA("UnionOperation") or child:IsA("MeshPart") or child:IsA("SpecialMesh") then
                            pcall(function() child.Transparency = 1 end)
                        end
                        if child:IsA("BillboardGui") or child:IsA("SurfaceGui") or child:IsA("ParticleEmitter") or child:IsA("SelectionBox") then
                            pcall(function() child.Enabled = false end)
                        end
                    end
                end
            end
        end,
    }
end
-- ========== ANTI AIM ==========
do
    local AntiAimSection = Tabs.Rage:AddRightGroupbox("AntiAim")

    local aaEnabled = false
    local pitchMode = "Glitch"
    local yawMode   = "0"
    local customYaw = 0
    local customPitch = 179
    local pitchOverride = 99999
    local yawOverride   = 0
    local toggleVal     = 4999
    local glitchPitchVal = 99999
    local glitchTask    = nil
    local camRemote     = nil

    local function encodeUnclamped(pitchDeg, yawDeg)
        if pitchDeg < 0 then pitchDeg = pitchDeg % 360 end
        if yawDeg < 0 then yawDeg = yawDeg % 360 end
        local pVal = math.floor(math.rad(pitchDeg) / (2 * math.pi) * 256 + 0.5)
        local yVal = math.floor(math.rad(yawDeg)   / (2 * math.pi) * 256 + 0.5)
        pVal = math.clamp(pVal, 0, 1114111)
        yVal = math.clamp(yVal, 0, 1114111)
        return utf8.char(pVal) .. utf8.char(yVal)
    end

    local function triggerGlitchPitch()
        if glitchTask then
            pcall(task.cancel, glitchTask)
            glitchTask = nil
        end
        glitchTask = task.spawn(function()
            glitchPitchVal = 0
            pitchOverride = 0
            if aaEnabled and camRemote then
                pcall(function() camRemote:FireServer(encodeUnclamped(0, yawOverride), nil) end)
            end
            task.wait(0.2)
            glitchPitchVal = 74568
            pitchOverride = 74568
            if aaEnabled and camRemote then
                pcall(function() camRemote:FireServer(encodeUnclamped(74568, yawOverride), nil) end)
            end
            task.wait(0.1)
            glitchPitchVal = 99999
            pitchOverride = 99999
            if aaEnabled and camRemote then
                pcall(function() camRemote:FireServer(encodeUnclamped(99999, yawOverride), nil) end)
            end
            glitchTask = nil
        end)
    end

    local AntiAimToggle = AntiAimSection:AddToggle("AntiAim_Enabled", {
        Text = "Enabled",
        Default = false,
        Callback = function(value)
            aaEnabled = value
            if value and pitchMode == "Glitch" then triggerGlitchPitch() end
            if not value then
                local hum = lp and lp.Character and lp.Character:FindFirstChildWhichIsA("Humanoid")
            end
        end
    })

    AntiAimToggle:AddKeyPicker("AntiAimKey", {
        Default = "None",
        SyncToggleState = true,
        Mode = "Toggle",
        Text = "Anti Aim",
    })

    local AntiAimDep = AntiAimSection:AddDependencyBox()

    local PitchDropdown = AntiAimDep:AddDropdown("AntiAim_PitchMode", {
        Values = {"Glitch", "Up", "Down", "Random", "Extended Random", "Custom", "0"},
        Default = 1,
        Multi = false,
        Text = "Pitch",
        Callback = function(value)
            pitchMode = value
            if value == "Glitch" then triggerGlitchPitch() end
        end
    })

    local PitchCustomDep = AntiAimSection:AddDependencyBox()
    PitchCustomDep:AddSlider("AntiAim_CustomPitch", {
        Text = "Custom Pitch",
        Default = 179,
        Min = 0,
        Max = 360,
        Rounding = 0,
        Callback = function(value) customPitch = value end
    })
    PitchCustomDep:SetupDependencies({ { AntiAimToggle, true }, { PitchDropdown, "Custom" } })

    local YawDropdown = AntiAimDep:AddDropdown("AntiAim_YawMode", {
        Values = {"0", "Custom", "Random"},
        Default = 1,
        Multi = false,
        Text = "Yaw",
        Callback = function(value) yawMode = value end
    })

    local YawCustomDep = AntiAimSection:AddDependencyBox()
    YawCustomDep:AddSlider("AntiAim_CustomYaw", {
        Text = "Custom Yaw",
        Default = 0,
        Min = 0,
        Max = 360,
        Rounding = 0,
        Callback = function(value) customYaw = value end
    })
    YawCustomDep:SetupDependencies({ { AntiAimToggle, true }, { YawDropdown, "Custom" } })

    AntiAimDep:SetupDependencies({ { AntiAimToggle, true } })

    task.spawn(function()
        local ok1, remote = pcall(function()
            return ReplicatedStorage
                :WaitForChild("Remotes", 10)
                :WaitForChild("Replication", 10)
                :WaitForChild("Fighter", 10)
                :WaitForChild("UpdateCameraRotation", 10)
        end)
        if ok1 and remote then camRemote = remote end
    end)

    if not getgenv()._antiAimHooked and getgenv().KETY_HookNamecall then
        getgenv().KETY_HookNamecall({"FireServer"}, function(oldNamecall)
            return function(self, ...)
                if aaEnabled and camRemote ~= nil and self == camRemote and not checkcaller() then
                    local encoded = encodeUnclamped(pitchOverride, yawOverride)
                    return oldNamecall(self, encoded, nil)
                end
                return oldNamecall(self, ...)
            end
        end)
        getgenv()._antiAimHooked = true
    end

    local lastSend = 0
    RunService.Heartbeat:Connect(function(dt)
        if not aaEnabled then return end

        if pitchMode == "Glitch" then
            pitchOverride = glitchPitchVal or 99999
        elseif pitchMode == "Up" then
            pitchOverride = 90
        elseif pitchMode == "Down" then
            pitchOverride = 270
        elseif pitchMode == "Extended Random" then
            pitchOverride = toggleVal
        elseif pitchMode == "Custom" then
            pitchOverride = customPitch
        elseif pitchMode == "0" then
            pitchOverride = 0
        end

        if yawMode == "Custom" then
            yawOverride = customYaw
        elseif yawMode ~= "Random" then
            yawOverride = 0
        end

        local now = tick()
        if now - lastSend >= 0.1 then
            lastSend = now
            toggleVal = (toggleVal == 4999) and 0 or 4999
            if pitchMode == "Random" then pitchOverride = math.random(0, 360) end
            if yawMode == "Random" then yawOverride = math.random(0, 360) end
            if camRemote then
                local p, y = pitchOverride, yawOverride % 360
                pcall(function() camRemote:FireServer(encodeUnclamped(p, y), nil) end)
            end
        end

    end)
end
-- ===== GUN MODS (MISC) =====
do
    local GunModsSection = Tabs.Misc:AddLeftGroupbox("Gun Mods")

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

local originalEquipCooldowns = {}
local function UpdateWeaponMods()
    pcall(function()
        local itemModule = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("ItemLibrary")
        if not itemModule then return end
        local itemLib = require(itemModule)
        if not (itemLib and itemLib.Items) then return end

        local isEnabled = getgenv().RageSettings and getgenv().RageSettings.Enabled and getgenv().RageSettings.EquipFaster
        for name, item in pairs(itemLib.Items) do
            if type(item) == "table" and item.EquipCooldown ~= nil then
                if not originalEquipCooldowns[name] then
                    originalEquipCooldowns[name] = item.EquipCooldown
                end

                local orig = originalEquipCooldowns[name]
                if isEnabled then
                    item.EquipCooldown = 0.01
                else
                    item.EquipCooldown = orig
                end
            end
        end
    end)
end

local function RestoreWeaponStats()
    pcall(function()
        local itemModule = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("ItemLibrary")
        if not itemModule then return end
        local itemLib = require(itemModule)
        if not (itemLib and itemLib.Items) then return end

        for name, orig in pairs(originalEquipCooldowns) do
            local item = itemLib.Items[name]
            if type(item) == "table" then
                item.EquipCooldown = orig
            end
        end
    end)
end

task.spawn(function()
    local OriginalStats = {} 
    local PlayerScripts = lp and lp:WaitForChild("PlayerScripts", 10)
    if not PlayerScripts then return end
    
    local okCI, clientItemModule = pcall(function()
        local mods = PlayerScripts:WaitForChild("Modules", 5)
        local crc = mods and mods:WaitForChild("ClientReplicatedClasses", 5)
        local cf = crc and crc:WaitForChild("ClientFighter", 5)
        local ci = cf and cf:WaitForChild("ClientItem", 5)
        return ci and require(ci)
    end)
    if not okCI then return end
    
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

    if type(clientItemModule.Input) == "function" then
        if not clientItemModule._origInput then
            clientItemModule._origInput = clientItemModule.Input
        end
        local inputFunc = clientItemModule._origInput
        clientItemModule._isInputHooked = true
        clientItemModule.Input = function(self, ...)
            local rs = getgenv().RageSettings
            if not (rs and rs.Enabled) then
                return inputFunc(self, ...)
            end
            if type(self) == "table" then
                local info = rawget(self, "Info") or self.Info
                if info then
                    local gunName = rawget(self, "Name") or self.Name or tostring(self)
                    local orig = OriginalStats[gunName]
                    if not orig then
                        orig = {
                            ShootRecoil = info.ShootRecoil,
                            ShootSpread = info.ShootSpread,
                            ShootCooldown = info.ShootCooldown,
                            QuickShotCooldown = info.QuickShotCooldown,
                            ShootBurstCooldown = info.ShootBurstCooldown,
                            AttackCooldown = info.AttackCooldown,
                            SwingCooldown = info.SwingCooldown,
                            MeleeCooldown = info.MeleeCooldown,
                            Cooldown = info.Cooldown,
                            RecoveryTime = info.RecoveryTime,
                            ResetTime = info.ResetTime
                        }
                        OriginalStats[gunName] = orig
                    end
                    if not rawget(self, "_isStatsHooked") then
                        rawset(self, "_isStatsHooked", true)
                        if setreadonly then pcall(setreadonly, info, false) end
                    end

                    local rec = rs.NoRecoil and 0 or orig.ShootRecoil
                    if orig.ShootRecoil ~= nil and info.ShootRecoil ~= rec then info.ShootRecoil = rec end
                    local spr = rs.NoSpread and 0 or orig.ShootSpread
                    if orig.ShootSpread ~= nil and info.ShootSpread ~= spr then info.ShootSpread = spr end

                    local rapid = rs.RapidFire and 0.001 or nil
                    local v
                    v = rapid or orig.ShootCooldown; if orig.ShootCooldown ~= nil and info.ShootCooldown ~= v then info.ShootCooldown = v end
                    v = rapid or orig.QuickShotCooldown; if orig.QuickShotCooldown ~= nil and info.QuickShotCooldown ~= v then info.QuickShotCooldown = v end
                    v = rapid or orig.ShootBurstCooldown; if orig.ShootBurstCooldown ~= nil and info.ShootBurstCooldown ~= v then info.ShootBurstCooldown = v end
                    v = rapid or orig.AttackCooldown; if orig.AttackCooldown ~= nil and info.AttackCooldown ~= v then info.AttackCooldown = v end
                    v = rapid or orig.SwingCooldown; if orig.SwingCooldown ~= nil and info.SwingCooldown ~= v then info.SwingCooldown = v end
                    v = rapid or orig.MeleeCooldown; if orig.MeleeCooldown ~= nil and info.MeleeCooldown ~= v then info.MeleeCooldown = v end
                    v = rapid or orig.Cooldown; if orig.Cooldown ~= nil and info.Cooldown ~= v then info.Cooldown = v end
                    v = rapid or orig.RecoveryTime; if orig.RecoveryTime ~= nil and info.RecoveryTime ~= v then info.RecoveryTime = v end
                    v = rapid or orig.ResetTime; if orig.ResetTime ~= nil and info.ResetTime ~= v then info.ResetTime = v end
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
        UpdateWeaponMods()
    end
})

GunModsToggle:AddKeyPicker("GunModsKey", {
    Default = "None",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Gun Mods",
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

GunModsDep:AddToggle("GunMods_InstantScope", {
    Text = "Instant Scope",
    Default = false,
    Callback = function(value)
        getgenv().RageSettings.InstantScope = value
    end
})

GunModsDep:SetupDependencies({ { GunModsToggle, true } })

task.spawn(function()
    local cameraControllerCache = nil
    RunService.RenderStepped:Connect(function()
        if getgenv().RageSettings and getgenv().RageSettings.Enabled and getgenv().RageSettings.InstantScope then
            if not cameraControllerCache then
                pcall(function()
                    local ps = lp:FindFirstChild("PlayerScripts")
                    local ctrl = ps and ps:FindFirstChild("Controllers")
                    local cc = ctrl and ctrl:FindFirstChild("CameraController")
                    if cc then cameraControllerCache = require(cc) end
                end)
            end
            if cameraControllerCache and type(cameraControllerCache) == "table" then
                local wSpring = cameraControllerCache._fov_weapons_spring
                local gSpring = cameraControllerCache._fov_gameplay_spring
                if wSpring and gSpring then
                    wSpring.Speed = 9999
                    wSpring.Value = wSpring.Target
                    gSpring.Speed = 9999
                    gSpring.Value = gSpring.Target
                end
            end
        end
    end)
end)

    -- ========== AUTO WEPON ==========
local autoLoadoutEnabled = false
local ChosenWeapons = {}
local WeaponLists = {}
local ListIndexes = {1, 1, 1, 1}

local AutoLoadout_ItemLibrary = nil
local AutoLoadout_FighterController = nil
local AutoLoadout_DuelController = nil

pcall(function()
    local Modules = ReplicatedStorage:FindFirstChild("Modules") or ReplicatedStorage:WaitForChild("Modules", 3)
    if Modules and Modules:FindFirstChild("ItemLibrary") then
        AutoLoadout_ItemLibrary = require(Modules.ItemLibrary)
    end
end)
pcall(function()
    local ps = lp:FindFirstChild("PlayerScripts") or lp:WaitForChild("PlayerScripts", 3)
    local Controllers = ps and (ps:FindFirstChild("Controllers") or ps:WaitForChild("Controllers", 3))
    if Controllers then
        if Controllers:FindFirstChild("FighterController") then
            AutoLoadout_FighterController = require(Controllers.FighterController)
        end
        if Controllers:FindFirstChild("DuelController") then
            AutoLoadout_DuelController = require(Controllers.DuelController)
        end
    end
end)

local function getSavedWeaponSelections()
    local saved = {}
    pcall(function()
        local sm = getgenv().SaveManager or SaveManager
        if not sm then return end
        local folder = sm.Folder or "KETY"
        local autoFile = folder .. "/settings/autoload.txt"
        if sm.CheckSubFolder and sm:CheckSubFolder(true) and sm.SubFolder and sm.SubFolder ~= "" then
            autoFile = folder .. "/settings/" .. sm.SubFolder .. "/autoload.txt"
        end
        if not (type(isfile) == "function" and isfile(autoFile)) then return end
        local name = readfile(autoFile)
        if not name or name == "" or name == "none" then return end
        name = name:gsub("\r", ""):gsub("\n", ""):match("^%s*(.-)%s*$")
        local path = folder .. "/settings/" .. name .. ".json"
        if sm.CheckSubFolder and sm:CheckSubFolder(true) and sm.SubFolder and sm.SubFolder ~= "" then
            path = folder .. "/settings/" .. sm.SubFolder .. "/" .. name .. ".json"
        end
        if not isfile(path) then return end
        local content = readfile(path)
        local decoded = game:GetService("HttpService"):JSONDecode(content)
        if type(decoded) == "table" then
            if type(decoded.objects) == "table" then
                for _, obj in ipairs(decoded.objects) do
                    if type(obj) == "table" and obj.idx and obj.value then
                        if obj.idx == "PriDrop" then saved[1] = obj.value
                        elseif obj.idx == "SecDrop" then saved[2] = obj.value
                        elseif obj.idx == "MelDrop" then saved[3] = obj.value
                        elseif obj.idx == "UtiDrop" then saved[4] = obj.value
                        end
                    end
                end
            end
            if type(decoded.Options) == "table" then
                saved[1] = saved[1] or decoded.Options.PriDrop
                saved[2] = saved[2] or decoded.Options.SecDrop
                saved[3] = saved[3] or decoded.Options.MelDrop
                saved[4] = saved[4] or decoded.Options.UtiDrop
            end
        end
    end)
    return saved
end

local function refreshWeapons()
    _fixId()
    if not AutoLoadout_ItemLibrary then
        pcall(function()
            local Modules = ReplicatedStorage:FindFirstChild("Modules")
            if Modules and Modules:FindFirstChild("ItemLibrary") then
                AutoLoadout_ItemLibrary = require(Modules.ItemLibrary)
            end
        end)
    end
    if not AutoLoadout_FighterController then
        pcall(function()
            local ps = lp:FindFirstChild("PlayerScripts")
            local Controllers = ps and ps:FindFirstChild("Controllers")
            if Controllers and Controllers:FindFirstChild("FighterController") then
                AutoLoadout_FighterController = require(Controllers.FighterController)
            end
        end)
    end
    if not AutoLoadout_DuelController then
        pcall(function()
            local ps = lp:FindFirstChild("PlayerScripts")
            local Controllers = ps and ps:FindFirstChild("Controllers")
            if Controllers and Controllers:FindFirstChild("DuelController") then
                AutoLoadout_DuelController = require(Controllers.DuelController)
            end
        end)
    end
    _fixId()
    if not AutoLoadout_ItemLibrary then return end

    local localFighter = AutoLoadout_FighterController and AutoLoadout_FighterController.LocalFighter
    local maxSlots = (localFighter and type(localFighter.GetMaxEquippableWeapons) == "function" and localFighter:GetMaxEquippableWeapons()) or 4
    for slotIndex = 1, maxSlots do
        local weapons = {}
        local classData = AutoLoadout_ItemLibrary.SlotToClass and AutoLoadout_ItemLibrary.SlotToClass[slotIndex]
        local className = classData and classData.Name
        if className then
            local weaponPool = (localFighter and type(localFighter.Get) == "function" and localFighter:Get("WeaponPool")) or {}
            local filterType = (localFighter and type(localFighter.Get) == "function" and localFighter:Get("WeaponPoolFilterType")) or ""
            local itemsList = AutoLoadout_ItemLibrary.ItemsAlphabetized or {}
            for _, itemName in ipairs(itemsList) do
                local itemData = AutoLoadout_ItemLibrary.Items and AutoLoadout_ItemLibrary.Items[itemName]
                if itemData and itemData.Class == className then
                    local isBlacklisted = (filterType == "Blacklist") and table.find(weaponPool, itemName)
                    local canUse = localFighter and type(localFighter.CanUseWeapon) == "function" and localFighter:CanUseWeapon(itemName)
                    if (canUse or isBlacklisted) or (not localFighter) then
                        table.insert(weapons, itemName)
                    end
                end
            end
        end
        if #weapons > 0 then
            WeaponLists[slotIndex] = weapons
        elseif not WeaponLists[slotIndex] or #WeaponLists[slotIndex] == 0 then
            WeaponLists[slotIndex] = {"None"}
        end
        if ChosenWeapons[slotIndex] == nil or ChosenWeapons[slotIndex] == "None" then
            if localFighter and WeaponLists[slotIndex] and WeaponLists[slotIndex][1] and WeaponLists[slotIndex][1] ~= "None" then
                ChosenWeapons[slotIndex] = WeaponLists[slotIndex][1]
            end
        end
    end
    _fixId()
end

-- 初期リストを事前に生成
refreshWeapons()
local savedInitial = getSavedWeaponSelections()

do local _si=setthreadidentity or set_thread_identity or setidentity; if _si then pcall(_si,8) end end
local enforceAutoLoadout
local AutoWeponToggle = GunModsSection:AddToggle("AutoLoadToggle", {
    Text = "AutoWepon",
    Default = autoLoadoutEnabled,
    Callback = function(Value)
        autoLoadoutEnabled = Value
        if Value and enforceAutoLoadout then
            enforceAutoLoadout()
        end
    end
})

AutoWeponToggle:AddKeyPicker("AutoLoadKey", {
    Default = "None",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "AutoWepon",
})

local AutoWeponDep = GunModsSection:AddDependencyBox()

local list1 = (WeaponLists[1] and #WeaponLists[1] > 0 and WeaponLists[1]) or {"None"}
local def1 = (savedInitial[1] and table.find(list1, savedInitial[1])) or 1
local PriDropObj = AutoWeponDep:AddDropdown("PriDrop", { Values = list1, Default = def1, Multi = false, Text = "Primary", Callback = function(Value) ChosenWeapons[1] = Value end })

local list2 = (WeaponLists[2] and #WeaponLists[2] > 0 and WeaponLists[2]) or {"None"}
local def2 = (savedInitial[2] and table.find(list2, savedInitial[2])) or 1
local SecDropObj = AutoWeponDep:AddDropdown("SecDrop", { Values = list2, Default = def2, Multi = false, Text = "Secondary", Callback = function(Value) ChosenWeapons[2] = Value end })

local list3 = (WeaponLists[3] and #WeaponLists[3] > 0 and WeaponLists[3]) or {"None"}
local def3 = (savedInitial[3] and table.find(list3, savedInitial[3])) or 1
local MelDropObj = AutoWeponDep:AddDropdown("MelDrop", { Values = list3, Default = def3, Multi = false, Text = "Melee", Callback = function(Value) ChosenWeapons[3] = Value end })

local list4 = (WeaponLists[4] and #WeaponLists[4] > 0 and WeaponLists[4]) or {"None"}
local def4 = (savedInitial[4] and table.find(list4, savedInitial[4])) or 1
local UtiDropObj = AutoWeponDep:AddDropdown("UtiDrop", { Values = list4, Default = def4, Multi = false, Text = "Utility", Callback = function(Value) ChosenWeapons[4] = Value end })

AutoWeponDep:AddButton({
    Text = "Refresh Weapons Data",
    Func = function()
        refreshWeapons()
        updateWeaponLabels()
    end,
})

AutoWeponDep:SetupDependencies({ { AutoWeponToggle, true } })

local dropObjs = {PriDropObj, SecDropObj, MelDropObj, UtiDropObj}

local function updateWeaponLabels()
    _fixId()
    local saved = getSavedWeaponSelections()
    for i = 1, 4 do
        local drop = dropObjs[i]
        local list = WeaponLists[i]
        if drop and list and #list > 0 then
            drop:SetValues(list)
            local current = drop.Value
            local targetVal = nil
            if current and current ~= "None" and table.find(list, current) then
                targetVal = current
            elseif saved[i] and table.find(list, saved[i]) then
                targetVal = saved[i]
            elseif ChosenWeapons[i] and ChosenWeapons[i] ~= "None" and table.find(list, ChosenWeapons[i]) then
                targetVal = ChosenWeapons[i]
            else
                targetVal = list[1]
            end
            if targetVal then
                drop:SetValue(targetVal)
                ChosenWeapons[i] = targetVal
            end
        end
    end
end



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
    
    if #validLoadout == 0 then return end

    local duel = AutoLoadout_DuelController and AutoLoadout_DuelController:GetDuel(lp)
    if duel and duel.LocalDueler and duel.LocalDueler:GetStaggeredSpawnsTurn() then
        ReplicatedStorage.Remotes.Duels.PickWeaponsAheadOfTime:FireServer(validLoadout)
    else
        ReplicatedStorage.Remotes.Replication.Fighter.PickWeapons:FireServer(validLoadout)
    end
end

local _autoLoadoutEnforced = false
enforceAutoLoadout = function()
    if _autoLoadoutEnforced then return end
    _autoLoadoutEnforced = true
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
    PlayerGui.DescendantAdded:Connect(hideExpectedUI)
    task.spawn(function()
        for i, desc in ipairs(PlayerGui:GetDescendants()) do
            hideExpectedUI(desc)
            if i % 300 == 0 then task.wait() end
        end
    end)

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
    pcall(function()
        local Modules = ReplicatedStorage and ReplicatedStorage:WaitForChild("Modules", 10)
        local il = Modules and Modules:WaitForChild("ItemLibrary", 10)
        if il then AutoLoadout_ItemLibrary = require(il) end
        local playerScripts = lp and lp:WaitForChild("PlayerScripts", 10)
        local Controllers = playerScripts and playerScripts:WaitForChild("Controllers", 10)
        if Controllers then
            local fc = Controllers:WaitForChild("FighterController", 10)
            if fc then AutoLoadout_FighterController = require(fc) end
            local dc = Controllers:WaitForChild("DuelController", 10)
            if dc then AutoLoadout_DuelController = require(dc) end
        end
    end)
    
    task.wait(1)
    refreshWeapons()
    updateWeaponLabels()
    if autoLoadoutEnabled and enforceAutoLoadout then
        enforceAutoLoadout()
    end
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
    local autoQueueEnabled = false
    local autoQueueName = nil
    local autoQueueDisplayToInternal = {}
    local MatchmakingController = nil
    local CONSTANTS_REF = nil
    local DEFAULT_DISPLAYS = { "1v1", "2v2", "3v3", "4v4", "5v5", "Ranked 1v1", "Ranked 2v2", "Ranked 3v3" }
    local tryQueueRef
    
    local AutoQueueBox = Tabs.Misc:AddLeftGroupbox("Auto Queue")
    
    local AutoQueueToggle = AutoQueueBox:AddToggle("AutoQueueToggle", {
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
    
    local AutoQueueDep = AutoQueueBox:AddDependencyBox()

    local AutoQueueDropObj = AutoQueueDep:AddDropdown("AutoQueueDrop", {
        Values = DEFAULT_DISPLAYS,
        Default = 1,
        Multi = false,
        Text = "Queue Type",
        Callback = function(Value)
            autoQueueName = autoQueueDisplayToInternal[Value] or Value
        end,
    })

    AutoQueueDep:SetupDependencies({ { AutoQueueToggle, true } })
    
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
            _fixId()
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
local UnlockAllToggle = UnlockAllSection:AddToggle("UnlockAllToggle", {
    Text = "Enable Unlock All",
    Default = false,
    Callback = function(value)
        getgenv().UnlockAllEnabled = value
        if value and not getgenv().UnlockAllExecuted then
            getgenv().UnlockAllExecuted = true
            task.spawn(function()
                -- [EMBEDDED UNLOCKALL.LUA]
local _cloneref = cloneref or function(x) return x end
local _getid = getthreadidentity or getidentity or function() return 8 end
local _rawsetid = setthreadidentity or set_thread_identity or setidentity or function() end
local function _setid(id)
    pcall(_rawsetid, id)
end
local function _restoreId(oldId)
    local target = (type(oldId) == "number" and oldId >= 7) and oldId or 8
    pcall(_rawsetid, target)
end

local _plrs = _cloneref(game:GetService("Players"))
local _rs   = _cloneref(game:GetService("ReplicatedStorage"))
local _http = _cloneref(game:GetService("HttpService"))
local _cs   = _cloneref(game:GetService("CollectionService"))
local _lp   = _plrs.LocalPlayer or lp
local _pscripts = _lp and _lp:WaitForChild("PlayerScripts", 10)
local _ctrl = _pscripts and _pscripts:WaitForChild("Controllers", 10)
local _pmods = _pscripts and _pscripts:WaitForChild("Modules", 10)
local _mods = _rs and _rs:WaitForChild("Modules", 10)

local _enumLib
pcall(function() if _mods then _enumLib = require(_mods:WaitForChild("EnumLibrary", 10)) end end)
if _enumLib then pcall(function() _enumLib:WaitForEnumBuilder() end) end
local _toEnumTbl = _enumLib and rawget(_enumLib, "_to_enum")
local function _encKey(k)
    if type(k) ~= "string" then return k end
    if _toEnumTbl and rawget(_toEnumTbl, k) ~= nil then return rawget(_toEnumTbl, k) end
    if _enumLib and _enumLib.ToEnum then
        local ok, v = pcall(_enumLib.ToEnum, _enumLib, k)
        if ok and v ~= nil then return v end
    end
    return k
end
local function _encTable(t)
    local out = {}
    for k, v in next, t, nil do
        out[type(k) == "string" and _encKey(k) or k] = v
    end
    return out
end

local _cosLib, _itmLib, _datUtil, _datCtrl, _fightCtrl
pcall(function() if _mods then _cosLib  = require(_mods:WaitForChild("CosmeticLibrary", 10)) end end)
pcall(function() if _mods then _itmLib  = require(_mods:WaitForChild("ItemLibrary", 10)) end end)
pcall(function() if _mods then _datUtil = require(_mods:WaitForChild("PlayerDataUtility", 10)) end end)
pcall(function() if _ctrl then _datCtrl = require(_ctrl:WaitForChild("PlayerDataController", 10)) end end)
pcall(function() if _ctrl then _fightCtrl = require(_ctrl:WaitForChild("FighterController", 10)) end end)

local _uiFolder = _pmods and _pmods:FindFirstChild("UserInterface")
local _equipment, _lobby, _cosmeticSlot, _cosmeticViewportFrame
pcall(function() if _uiFolder then _equipment = require(_uiFolder:WaitForChild("Equipment", 5)) end end)
pcall(function() if _uiFolder then _lobby = require(_uiFolder:WaitForChild("Lobby", 5)) end end)
pcall(function() if _pmods then _cosmeticSlot = require(_pmods:WaitForChild("CosmeticSlot", 5)) end end)
pcall(function() if _pmods then _cosmeticViewportFrame = require(_pmods:WaitForChild("CosmeticViewportFrame", 5)) end end)

local _crc = _pmods and _pmods:FindFirstChild("ClientReplicatedClasses")
local _clientEntity, _clientItem, _clientViewModel
pcall(function() if _crc then _clientEntity = require(_crc:WaitForChild("ClientEntity", 5)) end end)
pcall(function() if _crc then _clientItem = require(_crc.ClientFighter:WaitForChild("ClientItem", 5)) end end)
pcall(function() if _crc then _clientViewModel = require(_crc.ClientFighter.ClientItem:WaitForChild("ClientViewModel", 5)) end end)

local _eq, _favs = {}, {}
local _lastWep = nil
local _isInvertedState = false
local _noneCosmetic = "NONE_COSMETIC"

local _cosTypes = {"Skin","Wrap","Charm","Finisher","Dance","Emote"}
local _itemCosSet = { Skin = true, Wrap = true, Charm = true, Finisher = true }
local function _isCosType(cosObj)
    if not cosObj then return false end
    local t = rawget(cosObj, "Type") or cosObj.Type
    for _, ct in ipairs(_cosTypes) do
        if t == ct then return true end
    end
    return false
end

local function _mkCosmetic(nm, ctype, opts)
    if not nm or nm == "None" or nm == "" or nm == _noneCosmetic then return nil end
    local _base = _cosLib.Cosmetics[nm]
    local _d = {}
    if _base then
        for k, v in pairs(_base) do _d[k] = v end
    end
    _d.Name = nm
    _d.Type = _d.Type or ctype
    if opts then
        if opts.inverted ~= nil then _d.Inverted = opts.inverted or nil end
        if opts.favoritesOnly ~= nil then _d.OnlyUseFavorites = opts.favoritesOnly or nil end
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
    if _dec.favorites then _favs = _dec.favorites end
    if _dec.equipped then
        _eq = {}
        for wn, cos in pairs(_dec.equipped) do
            _eq[wn] = {}
            for ct, sd in pairs(cos) do
                if sd and sd.Name then
                    local _cloned = _mkCosmetic(sd.Name, ct, {
                        inverted = sd.Inverted,
                        favoritesOnly = sd.OnlyUseFavorites
                    })
                    if _cloned then _eq[wn][ct] = _cloned end
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
        _restoreId(8)
        task.wait(1)
        _restoreId(8)
        local _payload = _stripForSave()
        local _ok, _enc = pcall(_http.JSONEncode, _http, _payload)
        if _ok then pcall(writefile, _cfgFile, _enc) end
        _saveLock = false
    end)
end

_loadCfg()

-- Catalog & Inventory builder (dZ in あいうえお5)
local _cachedInv = nil
local function _buildFullInv()
    if _cachedInv then return _cachedInv end
    local _allItems = {}
    if _itmLib and rawget(_itmLib, "Items") then
        for k in next, rawget(_itmLib, "Items"), nil do
            _allItems[k] = true
        end
    end
    local _inv = {}
    if _cosLib and rawget(_cosLib, "Cosmetics") then
        for k, v in next, rawget(_cosLib, "Cosmetics"), nil do
            local ct = rawget(v, "Type")
            if ct == "Skin" or ct == "Finisher" or ct == "Emote" or ct == "Dance" then
                _inv[k] = true
            elseif ct == "Wrap" or ct == "Charm" then
                _inv[k] = _allItems
            end
        end
    end
    _cachedInv = _inv
    return _inv
end

-- OwnsCosmetic hooks
for _, fnName in ipairs({"OwnsCosmeticNormally", "OwnsCosmeticUniversally", "OwnsCosmeticForWeapon", "OwnsCosmetic"}) do
    local orig = _cosLib[fnName]
    if type(orig) == "function" then
        _cosLib[fnName] = function(self, inv, nm, wep)
            if type(nm) == "string" and (nm:find("MISSING_") or nm == "Bubble Gun") then
                return orig(self, inv, nm, wep)
            end
            local c = _cosLib.Cosmetics[nm]
            if c and _isCosType(c) then return true end
            return orig(self, inv, nm, wep)
        end
    end
end

-- DataHook on CurrentData.Data (dR in あいうえお5)
local _dataRestore = nil
local function _getOriginalData(key)
    if _dataRestore and _dataRestore.Inner then
        return rawget(_dataRestore.Inner, key)
    end
    local cd = rawget(_datCtrl, "CurrentData")
    local d = cd and rawget(cd, "Data")
    return d and rawget(d, key)
end

local function _getSpoofedField(key)
    if key == "CosmeticInventory" then
        return _buildFullInv()
    elseif key == "FavoritedCosmetics" then
        local orig = _getOriginalData("FavoritedCosmetics")
        local res = orig and table.clone(orig) or {}
        for wep, fv in pairs(_favs) do
            res[wep] = res[wep] and table.clone(res[wep]) or {}
            for nm, isFav in pairs(fv) do
                res[wep][nm] = isFav
            end
        end
        return res
    end
    return nil
end

local function _hookCurrentData(curData)
    if not curData then return end
    if _dataRestore and _dataRestore.Current == curData then return end
    local inner = rawget(curData, "Data")
    if not inner then return end
    _dataRestore = { Current = curData, Inner = inner }
    local proxy = {}
    for k, v in next, inner, nil do
        if k ~= "CosmeticInventory" and k ~= "FavoritedCosmetics" then
            rawset(proxy, k, v)
        end
    end
    rawset(proxy, "CosmeticInventory", _buildFullInv())
    rawset(curData, "Data", setmetatable(proxy, {
        __index = function(t, key)
            local sp = _getSpoofedField(key)
            if sp ~= nil then return sp end
            local val = rawget(inner, key)
            if val ~= nil then rawset(t, key, val) end
            return val
        end,
        __newindex = function(t, key, val)
            rawset(inner, key, val)
            if key ~= "CosmeticInventory" and key ~= "FavoritedCosmetics" then
                rawset(t, key, val)
            end
        end,
    }))
end

if rawget(_datCtrl, "CurrentData") then
    _hookCurrentData(rawget(_datCtrl, "CurrentData"))
end
if rawget(_datCtrl, "PlayerDataAdded") then
    pcall(function()
        rawget(_datCtrl, "PlayerDataAdded"):Connect(function()
            _hookCurrentData(rawget(_datCtrl, "CurrentData"))
        end)
    end)
end

local _origGet = _datCtrl.Get
if type(_origGet) == "function" then
    _datCtrl.Get = function(self, key)
        local sp = _getSpoofedField(key)
        if sp ~= nil then return sp end
        return _origGet(self, key)
    end
end

local function _triggerDataChanged(key)
    local curData = (_dataRestore and _dataRestore.Current) or rawget(_datCtrl, "CurrentData")
    if not curData then return end
    local evs = rawget(curData, "_value_changed_events")
    local ev = evs and rawget(evs, key)
    if ev ~= nil then
        local mt = getmetatable(ev)
        local idx = mt and rawget(mt, "__index")
        local fire = type(idx) == "table" and rawget(idx, "Fire")
        if fire then
            coroutine.wrap(fire)(ev)
        end
    end
end

-- Scene Refreshers (ec in あいうえお5)
local function _callMethod(obj, methodName)
    if not obj then return end
    local mt = getmetatable(obj)
    local idx = mt and rawget(mt, "__index")
    local fn = type(idx) == "table" and rawget(idx, methodName) or rawget(obj, methodName)
    if type(fn) == "function" then
        coroutine.wrap(fn)(obj)
    end
end

local function _cosmeticsSelectionScene()
    task.spawn(function()
        local oldId = _getid()
        _setid(2)
        pcall(function()
            local cosUI = _equipment and _equipment.Interface and _equipment.Interface.Customize and _equipment.Interface.Customize.Cosmetics
            _callMethod(cosUI, "OnStateChanged")
        end)
        _restoreId(oldId)
    end)
end

local function _equipmentScene()
    task.spawn(function()
        local oldId = _getid()
        _setid(2)
        pcall(function()
            local cosUI = _equipment and _equipment.Interface and _equipment.Interface.Customize and _equipment.Interface.Customize.Cosmetics
            local fltMod = _equipment and rawget(_equipment, "FloatingModel")
            local btns = _lobby and rawget(_lobby, "Buttons")
            _callMethod(cosUI, "_BulkUpdateEquipped")
            _callMethod(btns, "_UpdateButtonInformation")
            _callMethod(fltMod, "_GenerateViewModel")
        end)
        _restoreId(oldId)
    end)
end

-- ItemDataHook / GetWeaponData (eh in あいうえお5)
local function _buildPatchedWeaponData(origWep, wn)
    if not origWep then return nil end
    local sel = _eq[wn]
    if not sel then return origWep end
    local m = table.clone(origWep)
    m.Name = wn
    for ct in pairs(_itemCosSet) do
        local cd = sel[ct]
        if cd ~= nil then
            if cd.Name == _noneCosmetic or cd.Name == "None" then
                m[ct] = nil
            elseif ct == "Wrap" then
                m.Wrap = { Name = cd.Name, Inverted = cd.Inverted or nil, OnlyUseFavorites = cd.OnlyUseFavorites or nil }
            else
                m[ct] = { Name = cd.Name, OnlyUseFavorites = cd.OnlyUseFavorites or nil }
            end
        end
    end
    m.Level = rawget(origWep, "Level")
    m.Prestige = rawget(origWep, "Prestige")
    m.XP = rawget(origWep, "XP")
    return m
end

pcall(function()
    local mt = getmetatable(_datCtrl)
    local idx = mt and rawget(mt, "__index")
    local gwd = idx and rawget(idx, "GetWeaponData")
    if type(gwd) == "function" and debug and debug.getconstants and debug.setconstant then
        for k, v in debug.getconstants(gwd) do
            if v == "GetWeaponData" then
                debug.setconstant(gwd, k, "GetWeaponData\0ohaio")
                break
            end
        end
        rawset(_datUtil, "GetWeaponData\0ohaio", function(selfUtil, dataObj, wn)
            local origInv = _getOriginalData("WeaponInventory")
            local origWep = nil
            if origInv then
                for _, item in next, origInv, nil do
                    if rawget(item, "Name") == wn then
                        origWep = item
                        break
                    end
                end
            end
            if not origWep and _datUtil.GetWeaponData then
                pcall(function() origWep = _datUtil:GetWeaponData(dataObj, wn) end)
            end
            return _buildPatchedWeaponData(origWep, wn)
        end)
    end
end)

local _origGetWep = _datCtrl.GetWeaponData
if type(_origGetWep) == "function" then
    _datCtrl.GetWeaponData = function(self, wn)
        local d = _origGetWep(self, wn)
        return _buildPatchedWeaponData(d, wn)
    end
end

-- ViewModel Cosmetic Application & Reloader (ev, ew, eA in あいうえお5)
local _vmRestoreDatas = {}
local function _applyVmCosmetics(wn, dataTbl, encFn)
    local sel = _eq[wn]
    if not sel or not dataTbl then return dataTbl end
    encFn = encFn or function(x) return x end
    if sel.Skin and sel.Skin.Name then
        dataTbl[encFn("Name")] = sel.Skin.Name == _noneCosmetic and wn or sel.Skin.Name
    end
    if sel.Wrap and sel.Wrap.Name then
        if sel.Wrap.Name == _noneCosmetic then
            dataTbl[encFn("Wrap")] = nil
        else
            dataTbl[encFn("Wrap")] = { Name = sel.Wrap.Name, Inverted = sel.Wrap.Inverted == true }
        end
    end
    if sel.Charm and sel.Charm.Name then
        if sel.Charm.Name == _noneCosmetic then
            dataTbl[encFn("Charm")] = nil
        else
            dataTbl[encFn("Charm")] = { Name = sel.Charm.Name }
        end
    end
    return dataTbl
end

local function _getLocalFighter()
    if not _fightCtrl then return nil end
    local ptf = rawget(_fightCtrl, "_player_to_fighter")
    if ptf and ptf[_lp] then return ptf[_lp] end
    local ok, f = pcall(_fightCtrl.GetFighter, _fightCtrl, _lp)
    return ok and f or nil
end

local function _reloadViewModel(wn)
    pcall(function()
        local f = _getLocalFighter()
        if not f or not rawget(f, "Items") or not _clientItem or not _clientViewModel then return end
        for _, itm in pairs(rawget(f, "Items")) do
            if rawget(itm, "Name") == wn then
                local vm = rawget(itm, "ViewModel")
                local data = vm and rawget(vm, "Data")
                if vm and data then
                    if _eq[wn] and not _vmRestoreDatas[wn] then
                        _vmRestoreDatas[wn] = table.clone(data)
                    end
                    local restoreData = _vmRestoreDatas[wn]
                    coroutine.wrap(function()
                        local oldId = _getid()
                        _setid(2)
                        coroutine.wrap(rawget(_clientViewModel, "Destroy"))(vm)
                        _restoreId(oldId)
                    end)()
                    local newData
                    if _eq[wn] then
                        newData = _applyVmCosmetics(wn, { Name = wn }, nil)
                    else
                        newData = restoreData or data
                    end
                    local payload = _encTable({ Data = _encTable(newData) })
                    local newVm = coroutine.wrap(function()
                        local oldId = _getid()
                        _setid(2)
                        local created = coroutine.wrap(rawget(_clientItem, "_CreateViewModel"))(itm, payload)
                        _restoreId(oldId)
                        return created
                    end)()
                    if newVm then
                        rawset(itm, "ViewModel", newVm)
                        local fMt = getmetatable(f)
                        local getArms = fMt and rawget(fMt, "__index") and rawget(rawget(fMt, "__index"), "GetArmsData")
                        if type(getArms) == "function" then
                            local armsData = table.pack(coroutine.wrap(getArms)(f))
                            coroutine.wrap(function()
                                local oldId = _getid()
                                _setid(2)
                                coroutine.wrap(rawget(_clientViewModel, "SetArmsData"))(newVm, unpack(armsData, 1, armsData.n))
                                coroutine.wrap(rawget(_clientViewModel, "Equip"))(newVm, true)
                                _restoreId(oldId)
                            end)()
                        end
                        local eqSpring = rawget(newVm, "_equip_spring")
                        if eqSpring then
                            rawset(eqSpring, "_position0", 0)
                            rawset(eqSpring, "_velocity0", 0)
                        end
                    end
                end
            end
        end
    end)
end

-- ViewModelHook on ClientItem.new prototype (ew in あいうえお5)
pcall(function()
    if not _clientItem or not debug or not debug.getupvalues or not debug.getstack then return end
    local newFn = rawget(_clientItem, "new")
    if type(newFn) ~= "function" then return end
    local upTbl, upKey, proto = nil, nil, nil
    for _, uv in debug.getupvalues(newFn) do
        if type(uv) == "table" then
            for k, v in next, uv, nil do
                if type(v) == "table" and rawget(v, "CreateSpectatorSound") ~= nil then
                    upTbl, upKey, proto = uv, k, v
                    break
                end
            end
            if proto then break end
        end
    end
    if upTbl and upKey and proto then
        upTbl[upKey] = {
            __index = function(_, k) return proto[k] end,
            __newindex = function(itemSelf, k, v)
                if k ~= "Info" then
                    rawset(itemSelf, k, v)
                    return
                end
                rawset(itemSelf, "Info", v)
                setmetatable(itemSelf, proto)
                pcall(function()
                    local st = debug.getstack(2, 1)
                    if type(st) ~= "table" then st = debug.getstack(2) end
                    local arg1 = type(st) == "table" and (st[1] or st)
                    local vmDataWrap = type(arg1) == "table" and rawget(arg1, "ViewModel")
                    local cf = rawget(itemSelf, "ClientFighter")
                    local plr = cf and rawget(cf, "Player")
                    local wn = rawget(itemSelf, "Name")
                    if plr == _lp and wn and vmDataWrap then
                        local dTbl = vmDataWrap[_encKey("Data")]
                        if type(dTbl) == "table" and _eq[wn] then
                            if not _vmRestoreDatas[wn] then
                                _vmRestoreDatas[wn] = table.clone(dTbl)
                            end
                            _applyVmCosmetics(wn, dTbl, _encKey)
                        end
                    end
                end)
            end,
        }
    end
end)

-- Fallback hook on ClientViewModel.new
if _clientViewModel and _clientViewModel.new then
    local _origVmNew = _clientViewModel.new
    _clientViewModel.new = function(repData, cliItm)
        pcall(function()
            local wp = cliItm and cliItm.ClientFighter and cliItm.ClientFighter.Player
            local wn = cliItm and cliItm.Name
            if wp == _lp and wn and _eq[wn] and type(repData) == "table" then
                local dk = _encKey("Data")
                repData[dk] = repData[dk] or {}
                _applyVmCosmetics(wn, repData[dk], _encKey)
            end
        end)
        return _origVmNew(repData, cliItm)
    end
end

local function _refreshWeaponCosmetics(wn)
    _triggerDataChanged("WeaponInventory")
    _triggerDataChanged("WeaponData")
    _equipmentScene()
    if wn then _reloadViewModel(wn) end
    _saveCfg()
end

-- Interactions: RemoteEventBlocker (eM), InvertedState (eL), SlotBinder (eN), Favorited (eK) (あいうえお5 lines 39948-40388)
local function _pushItemChoiceFromUI()
    if not _equipment then return end
    local eqState = rawget(_equipment, "EquipmentState")
    if not eqState then return end
    local wn = rawget(eqState, "SelectedWeapon")
    local ct = rawget(eqState, "CustomizingType")
    local cn = rawget(eqState, "SelectedCosmetic")
    if not wn or not ct or not _itemCosSet[ct] then return end
    _eq[wn] = _eq[wn] or {}
    if not cn or cn == "None" or cn == "" or cn == _noneCosmetic then
        _eq[wn][ct] = nil
        if not next(_eq[wn]) then _eq[wn] = nil end
    else
        local cloned = _mkCosmetic(cn, ct, {
            inverted = (ct == "Wrap") and (_isInvertedState == true) or nil,
            favoritesOnly = _eq[wn][ct] and _eq[wn][ct].OnlyUseFavorites
        })
        if cloned then _eq[wn][ct] = cloned end
    end
    _refreshWeaponCosmetics(wn)
end

-- RemoteEventBlocker (eM): prevent Options._Init from firing server remotes
pcall(function()
    local opts = _equipment and _equipment.Interface and _equipment.Interface.Customize and _equipment.Interface.Customize.Options
    local mt = opts and getmetatable(opts)
    local idx = mt and rawget(mt, "__index")
    local initFn = idx and rawget(idx, "_Init")
    if type(initFn) == "function" and debug and debug.getprotos and debug.getproto and debug.getconstants and debug.setconstant then
        for k in debug.getprotos(initFn) do
            local protos = debug.getproto(initFn, k, true)
            local p = type(protos) == "table" and protos[1]
            if p then
                for k2, c in debug.getconstants(p) do
                    if c == "FireServer" then
                        debug.setconstant(p, k2, "GetChildren")
                        break
                    end
                end
            end
        end
    end
end)

-- InvertedState hook on Equipment.EquipmentState (eL)
pcall(function()
    local eqState = _equipment and rawget(_equipment, "EquipmentState")
    local mt = eqState and getmetatable(eqState)
    local idx = mt and rawget(mt, "__index")
    if eqState and mt and idx then
        rawset(eqState, "CosmeticInverted", nil)
        setmetatable(eqState, {
            __index = function(_, k)
                if k == "CosmeticInverted" then
                    local wn = rawget(eqState, "SelectedWeapon")
                    if wn then
                        local inv = _eq[wn] and _eq[wn].Wrap and _eq[wn].Wrap.Inverted == true or false
                        _isInvertedState = inv
                        return inv
                    end
                end
                return rawget(idx, k)
            end,
            __newindex = function(t, k, v)
                if k ~= "CosmeticInverted" or v == nil then
                    rawset(t, k, v)
                    return
                end
                _isInvertedState = (v == true)
                _pushItemChoiceFromUI()
            end,
        })
    end
end)

-- SlotBinder hook on CosmeticSlot.new upvalue 1 (eN in あいうえお5)
pcall(function()
    if not _cosmeticSlot or not debug or not debug.getupvalue or not debug.setupvalue or not debug.info then return end
    local newFn = rawget(_cosmeticSlot, "new")
    if type(newFn) ~= "function" then return end
    local proto = debug.getupvalue(newFn, 1)
    if type(proto) ~= "table" then return end
    debug.setupvalue(newFn, 1, {
        __index = function(slotSelf, k)
            if k ~= "Frame" then
                return rawget(proto, k)
            end
            local src, callerFn = debug.info(2, "sf")
            if src ~= nil and callerFn ~= nil and src:match("Cosmetics$") ~= nil then
                local uvs = debug.getupvalues(callerFn)
                if type(uvs) == "table" and type(uvs[9]) == "boolean" then
                    debug.setupvalue(callerFn, 9, false)
                end
            end
            return rawget(slotSelf, "Frame\0rahh")
        end,
        __newindex = function(slotSelf, k, v)
            if k ~= "Frame" then
                rawset(slotSelf, k, v)
                return
            end
            local src = debug.info(3, "s")
            if src ~= nil and src:match("Cosmetics$") ~= nil and not rawget(slotSelf, "IsLocked") then
                local btn = typeof(v) == "Instance" and v:FindFirstChild("Button")
                if btn and btn:IsA("GuiButton") then
                    btn.MouseButton1Click:Connect(function()
                        _pushItemChoiceFromUI()
                    end)
                end
            end
            rawset(slotSelf, "Frame\0rahh", v)
        end,
    })
end)

-- Favorited & OnlyUseFavorites UI button hooks (eJ, eK in あいうえお5)
pcall(function()
    local opts = _equipment and _equipment.Interface and _equipment.Interface.Customize and _equipment.Interface.Customize.Options
    local container = opts and rawget(opts, "Container")
    if container then
        task.spawn(function()
            local favFrame = container:WaitForChild("Favorited", 15)
            local favBtn = favFrame and favFrame:WaitForChild("Container", 5) and favFrame.Container:WaitForChild("Button", 5)
            if favBtn then
                favBtn.MouseButton1Click:Connect(function()
                    local eqState = _equipment and rawget(_equipment, "EquipmentState")
                    local wn = eqState and rawget(eqState, "SelectedWeapon")
                    local ct = eqState and rawget(eqState, "CustomizingType")
                    local cn = eqState and rawget(eqState, "SelectedCosmetic")
                    if wn and ct and _itemCosSet[ct] and cn then
                        _favs[wn] = _favs[wn] or {}
                        _favs[wn][cn] = not _favs[wn][cn] or nil
                        _triggerDataChanged("FavoritedCosmetics")
                        _saveCfg()
                    end
                end)
            end
        end)
    end
end)

-- Trigger initial inventory refresh so UI unlocks all slots immediately (eP in あいうえお5)
_triggerDataChanged("CosmeticInventory")
_cosmeticsSelectionScene()
_refreshWeaponCosmetics(nil)

-- Fallback Namecall hook for EquipCosmetic / FavoriteCosmetic / UseItem
if hookmetamethod then
    local _remotes   = _rs:FindFirstChild("Remotes")
    local _dataRem   = _remotes and _remotes:FindFirstChild("Data")
    local _equipRem  = _dataRem and _dataRem:FindFirstChild("EquipCosmetic")
    local _favRem    = _dataRem and _dataRem:FindFirstChild("FavoriteCosmetic")
    local _repRem    = _remotes and _remotes:FindFirstChild("Replication")
    local _fightRem  = _repRem and _repRem:FindFirstChild("Fighter")
    local _useItmRem = _fightRem and _fightRem:FindFirstChild("UseItem")

    if _equipRem and getgenv().KETY_HookNamecall then
        getgenv().KETY_HookNamecall({"FireServer"}, function(_onc) return function(self, ...)
            if _useItmRem and self == _useItmRem then
                local _f = _getLocalFighter()
                local _eqItm = _f and rawget(_f, "EquippedItem")
                if _eqItm and _eqItm.Name then
                    _lastWep = _eqItm.Name
                end
                return _onc(self, ...)
            end
            if self ~= _equipRem and self ~= _favRem then
                return _onc(self, ...)
            end
            local _a = {...}

            if self == _equipRem then
                local _wn   = _a[1]
                local _ct   = _a[2]
                local _cn   = _a[3]
                local _opts = _a[4] or {}
                _eq[_wn] = _eq[_wn] or {}
                if not _cn or _cn == "None" or _cn == "" or _cn == _noneCosmetic then
                    _eq[_wn][_ct] = nil
                    if not next(_eq[_wn]) then _eq[_wn] = nil end
                else
                    local _cloned = _mkCosmetic(_cn, _ct, {
                        inverted = _opts.IsInverted,
                        favoritesOnly = _opts.OnlyUseFavorites
                    })
                    if _cloned then _eq[_wn][_ct] = _cloned end
                end
                task.defer(function()
                    _restoreId(8)
                    _refreshWeaponCosmetics(_wn)
                end)
                return
            end

            if self == _favRem then
                local _cos = _cosLib.Cosmetics[_a[2]]
                if _cos then
                    _favs[_a[1]] = _favs[_a[1]] or {}
                    _favs[_a[1]][_a[2]] = _a[3] or nil
                    task.defer(function()
                        _restoreId(8)
                        _triggerDataChanged("FavoritedCosmetics")
                        _saveCfg()
                    end)
                end
                return
            end

            return _onc(self, ...)
        end end)
    end
end

-- FinisherCloneCache (et) & FinisherHook (eu) from あいうえお5 (lines 37877-38250)
pcall(function()
    local _finFolder = _mods:FindFirstChild("Finishers")
    if not (_clientEntity and _finFolder) then return end
    local _repFromServer = rawget(_clientEntity, "ReplicateFromServer")
    local _origPlayFinisher = rawget(_clientEntity, "_PlayFinisher")
    if type(_repFromServer) ~= "function" or type(_origPlayFinisher) ~= "function" then return end

    local _stripClasses = {
        LocalScript = true, Script = true, ModuleScript = true,
        BillboardGui = true, SurfaceGui = true, Beam = true,
        Trail = true, Fire = true, Sparkles = true,
        ForceField = true, Smoke = true, Light = true, IKControl = true,
    }
    local _r15Parts = {
        "HumanoidRootPart", "Humanoid", "Head", "UpperTorso", "LowerTorso",
        "LeftFoot", "LeftLowerLeg", "LeftUpperLeg", "RightFoot", "RightLowerLeg", "RightUpperLeg",
        "LeftHand", "LeftLowerArm", "LeftUpperArm", "RightHand", "RightLowerArm", "RightUpperArm",
    }

    local function _rawClone(model)
        if not model then return nil end
        local arch = model.Archivable
        model.Archivable = true
        local ok, c = pcall(model.Clone, model)
        model.Archivable = arch
        return ok and c or nil
    end

    local function _cleanClone(model)
        local c = _rawClone(model)
        if not c then return nil end
        for _, d in ipairs(c:GetDescendants()) do
            if _stripClasses[d.ClassName] then
                d:Destroy()
            elseif d:IsA("BasePart") then
                d.Anchored = false
                if d.Transparency < 1 then
                    d.Transparency = 0
                end
            elseif d:IsA("ParticleEmitter") then
                d:Clear()
                d:Destroy()
            end
        end
        for _, tag in ipairs(_cs:GetTags(c)) do
            _cs:RemoveTag(c, tag)
        end
        return c
    end

    local _cloneByPlayer = {}
    local function _hasAnyFinisherEquipped()
        for _, slots in pairs(_eq) do
            if type(slots) == "table" and slots.Finisher ~= nil then
                return true
            end
        end
        return false
    end
    local function _cachePlayerCharacter(plr, char)
        if not plr or plr == _lp or not char then return end
        if not _hasAnyFinisherEquipped() then return end
        if getgenv().KETY_IsEnemy and not getgenv().KETY_IsEnemy(plr) then return end
        task.spawn(function()
            for _, pName in ipairs(_r15Parts) do
                if not char:WaitForChild(pName, 10) then return end
            end
            if plr.Character ~= char then return end
            if _cloneByPlayer[plr] then
                pcall(function() _cloneByPlayer[plr]:Destroy() end)
            end
            _cloneByPlayer[plr] = _cleanClone(char)
        end)
    end

    for _, plr in ipairs(_plrs:GetPlayers()) do
        if plr ~= _lp then
            plr.CharacterAdded:Connect(function(ch) _cachePlayerCharacter(plr, ch) end)
            plr.CharacterRemoving:Connect(function()
                if _cloneByPlayer[plr] then
                    pcall(function() _cloneByPlayer[plr]:Destroy() end)
                    _cloneByPlayer[plr] = nil
                end
            end)
            if plr.Character then _cachePlayerCharacter(plr, plr.Character) end
        end
    end
    _plrs.PlayerAdded:Connect(function(plr)
        if plr ~= _lp then
            plr.CharacterAdded:Connect(function(ch) _cachePlayerCharacter(plr, ch) end)
            plr.CharacterRemoving:Connect(function()
                if _cloneByPlayer[plr] then
                    pcall(function() _cloneByPlayer[plr]:Destroy() end)
                    _cloneByPlayer[plr] = nil
                end
            end)
        end
    end)
    _plrs.PlayerRemoving:Connect(function(plr)
        if _cloneByPlayer[plr] then
            pcall(function() _cloneByPlayer[plr]:Destroy() end)
            _cloneByPlayer[plr] = nil
        end
    end)

    local function _acquireClone(model)
        local plr = _plrs:GetPlayerFromCharacter(model)
        if plr and _cloneByPlayer[plr] then
            local c = _cloneByPlayer[plr]
            _cloneByPlayer[plr] = nil
            return c
        end
        return _cleanClone(model)
    end

    local function _hideVictim(m)
        for _, d in ipairs(m:GetDescendants()) do
            if d:IsA("BasePart") then
                d.Transparency = 1
            elseif d:IsA("Decal") then
                d:Destroy()
            elseif d:IsA("BillboardGui") then
                d.Enabled = false
            end
        end
    end

    local function _runFinisher(clone, origModel, finMod, arg4, arg5, arg6, entSelf)
        local hum = clone:FindFirstChildOfClass("Humanoid")
        local hrp = clone:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then clone:Destroy() return end
        hrp.AssemblyLinearVelocity = Vector3.zero
        hum.Health = 0
        local parts = {}
        for _, c in ipairs(clone:GetChildren()) do
            if c:IsA("BasePart") then
                c.CollisionGroup = "Players"
                table.insert(parts, c)
            end
        end
        for i = 1, #parts do
            for j = i + 1, #parts do
                local nc = Instance.new("NoCollisionConstraint")
                nc.Part0 = parts[i]
                nc.Part1 = parts[j]
                nc.Parent = parts[i]
            end
        end
        clone:PivotTo(origModel:GetPivot())
        clone.Parent = origModel.Parent
        coroutine.wrap(function()
            local oldId = _getid()
            _setid(2)
            local curFin = rawget(entSelf, "_current_finisher")
            if curFin ~= nil then
                coroutine.wrap(curFin.Destroy)(curFin)
            end
            local finObj = coroutine.wrap(rawget(finMod, "new"))(hum, arg4, arg5)
            rawset(entSelf, "_current_finisher", finObj)
            finObj:SetSerial(arg6)
            origModel.Destroying:Once(function()
                if clone.Parent ~= nil then clone:Destroy() end
            end)
            task.spawn(pcall, finObj.PlayServer, finObj)
            task.spawn(pcall, finObj.PlayClient, finObj)
            _restoreId(oldId)
        end)()
    end

    local _hookedFinisher = function(entSelf, arg3, arg4, arg5, arg6)
        local function _fallback()
            return coroutine.wrap(_origPlayFinisher)(entSelf, arg3, arg4, arg5, arg6)
        end
        if arg5 == _lp then
            local wn = _lastWep
            local f = _getLocalFighter()
            if f then
                local eqItm = rawget(f, "EquippedItem")
                if eqItm and rawget(eqItm, "Name") then
                    wn = rawget(eqItm, "Name")
                end
            end
            local finData = wn and _eq[wn] and _eq[wn].Finisher
            local finName = finData and finData.Name
            if not finName or finName == _noneCosmetic then return _fallback() end
            local finScript = _finFolder:FindFirstChild(finName)
            if not finScript then return _fallback() end
            local model = rawget(entSelf, "Model")
            if not model then return _fallback() end
            local clone = _acquireClone(model)
            if not clone then return _fallback() end
            local ok, finMod = pcall(require, finScript)
            if ok and type(finMod) == "table" then
                _hideVictim(model)
                _runFinisher(clone, model, finMod, arg4, arg5, arg6, entSelf)
                return
            else
                clone:Destroy()
            end
        end
        return _fallback()
    end

    if debug and debug.getconstants and debug.setconstant then
        for idx, cst in debug.getconstants(_repFromServer) do
            if cst == "_PlayFinisher" then
                debug.setconstant(_repFromServer, idx, "_PlayFinisher\0hello")
                rawset(_clientEntity, "_PlayFinisher\0hello", _hookedFinisher)
                break
            end
        end
    end
    rawset(_clientEntity, "_PlayFinisher", _hookedFinisher)
end)

                -- [END EMBEDDED UNLOCKALL.LUA]
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
        -- Equipment UIをリフレッシュ
        pcall(function()
            local EquipmentModule = lp:WaitForChild("PlayerScripts"):WaitForChild("Modules"):WaitForChild("UserInterface"):WaitForChild("Equipment")
            local eq = require(EquipmentModule)
            if eq and eq.Left and eq.Left._Generate then
                eq.Left:_Generate()
            end
        end)
    end
})
-- ========== DISABLE OUT OF BOUNDS ==========
local OutOfBoundsSection = Tabs.Misc:AddLeftGroupbox("Out Of Bounds")
local DisableOOBToggle = OutOfBoundsSection:AddToggle("DisableOOBToggle", {
    Text = "Disable Out Of Bounds",
    Default = false,
    Callback = function(value)
        getgenv().DisableOutOfBoundsEnabled = value
        if value and not getgenv().OOBHookExecuted then
            getgenv().OOBHookExecuted = true
            task.spawn(function()
                local _rs = game:GetService("ReplicatedStorage")
                local oob_remote = _rs:FindFirstChild("Remotes")
                if oob_remote then
                    local rep = oob_remote:FindFirstChild("Replication")
                    if rep then
                        local fighter = rep:FindFirstChild("Fighter")
                        if fighter then
                            oob_remote = fighter:FindFirstChild("OutOfBounds")
                        else oob_remote = nil end
                    else oob_remote = nil end
                end

                if getgenv().KETY_HookNamecall and oob_remote then
                    getgenv().KETY_HookNamecall({"FireServer"}, function(oldNamecall)
                        return function(self, ...)
                            if self == oob_remote and getgenv().DisableOutOfBoundsEnabled then
                                return nil
                            end
                            return oldNamecall(self, ...)
                        end
                    end)
                end

                local modulesFolder = _rs:WaitForChild("Modules", 10)
                if modulesFolder then
                    pcall(function()
                        local OutOfBoundsMachine = require(modulesFolder:WaitForChild("OutOfBoundsMachine", 5))
                        if type(OutOfBoundsMachine) == "table" then
                            local origIsOOB = OutOfBoundsMachine.IsOutOfBounds
                            OutOfBoundsMachine.IsOutOfBounds = function(...)
                                if getgenv().DisableOutOfBoundsEnabled then return false end
                                if type(origIsOOB) == "function" then return origIsOOB(...) end
                            end
                            local origUpdate = OutOfBoundsMachine.Update
                            OutOfBoundsMachine.Update = function(...)
                                if getgenv().DisableOutOfBoundsEnabled then return end
                                if type(origUpdate) == "function" then return origUpdate(...) end
                            end
                        end
                    end)

                    pcall(function()
                        local GameplayUtility = require(modulesFolder:WaitForChild("GameplayUtility", 5))
                        if type(GameplayUtility) == "table" then
                            local origWarn = GameplayUtility.GetOOBWarnDelay
                            GameplayUtility.GetOOBWarnDelay = function(...)
                                if getgenv().DisableOutOfBoundsEnabled then return 9999 end
                                if type(origWarn) == "function" then return origWarn(...) end
                            end
                            local origKill = GameplayUtility.GetOOBKillDelay
                            GameplayUtility.GetOOBKillDelay = function(...)
                                if getgenv().DisableOutOfBoundsEnabled then return 9999 end
                                if type(origKill) == "function" then return origKill(...) end
                            end
                            local origWithin = GameplayUtility.IsWithinOOBPart
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

local DeviceSpoofSection = Tabs.Misc:AddLeftGroupbox("Device Spoofer")

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

local DeviceSpoofDep = DeviceSpoofSection:AddDependencyBox()
DeviceSpoofDropdownObj = DeviceSpoofDep:AddDropdown("DeviceSpoofDropdown", {
    Values = {"Touch", "MouseKeyboard", "Gamepad", "VR"},
    Default = 1,
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
local DmgNotifToggle = DmgNotifSection:AddToggle("DmgNotif_Enabled", {
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

    local DmgNotifDep = DmgNotifSection:AddDependencyBox()

    DmgNotifDep:AddSlider("DmgNotif_Min", {
        Text = "Min Damage", Default = 1, Min = 1, Max = 100, Rounding = 0,
        Callback = function(v) dmgNotifMin = v end,
    })
    DmgNotifDep:AddSlider("DmgNotif_Cooldown", {
        Text = "Cooldown (s)", Default = 0.3, Min = 0, Max = 3, Rounding = 1,
        Callback = function(v) dmgNotifCooldown = v end,
    })

    DmgNotifDep:SetupDependencies({ { DmgNotifToggle, true } })
end -- do DamageNotification

-- ========== ANTI BAN ==========

do
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

local StaffDetectorToggle = AntiBanSection:AddToggle("StaffDetectorToggle", {
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

    local StaffDetectorDep = AntiBanSection:AddDependencyBox()
    StaffDetectorDep:AddDropdown("StaffDetectorAction", {
        Values = {"Notify", "Kick"},
        Default = 1,
        Multi = false,
        Text = "Action",
        Callback = function(value) StaffDetectorAction = value end
    })
    StaffDetectorDep:SetupDependencies({ { StaffDetectorToggle, true } })

local ArchNemesisToggle = AntiBanSection:AddToggle("ArchNemesisToggle", {
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

-- ========== SOUND CHANGER ==========
do
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

SoundChangerToggle:AddKeyPicker("SoundChangerKey", {
    Default = "None",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Hit Sound Changer",
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
    if not character then return end
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

KillSoundToggle:AddKeyPicker("KillSoundKey", {
    Default = "None",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Kill Sound Changer",
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

end

-- ========== ANIMATION PLAYER ==========
do
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
    if not animPlayerEnabled or not currentAnim or not char then return end
    
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

AnimationPlayerToggle:AddKeyPicker("AnimationPlayerKey", {
    Default = "None",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Animation Player",
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

end

-- ========== THEME MANAGER ==========
ThemeManager:SetLibrary(Library)
ThemeManager:SetFolder("KETY")
ThemeManager:ApplyTheme("Tokyo Night")
Library:UpdateColorsUsingRegistry()

-- ========== FLY & NOCLIP ==========
do
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
    local noclipParts, noclipLast, noclipChar = {}, 0, nil
    noclipConnection = RunService.Stepped:Connect(function()
        local ch = lp.Character
        if noclipEnabled and ch then
            local now = tick()
            if ch ~= noclipChar or now - noclipLast > 0.5 then
                noclipChar, noclipLast = ch, now
                noclipParts = {}
                for _, part in ipairs(ch:GetDescendants()) do
                    if part:IsA("BasePart") then noclipParts[#noclipParts + 1] = part end
                end
            end
            for i = 1, #noclipParts do
                local p = noclipParts[i]
                if p.CanCollide then p.CanCollide = false end
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

local FlyToggle = MovementSection:AddToggle("FlyToggle", {
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

local FlyDep = MovementSection:AddDependencyBox()

FlyDep:AddSlider("FlySpeedSlider", {
    Text = "Fly Speed",
    Default = 70,
    Min = 20,
    Max = 1000,
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

FlyDep:SetupDependencies({ { FlyToggle, true } })

do local _si=setthreadidentity or set_thread_identity or setidentity; if _si then pcall(_si,8) end end
local hideInFloorEnabled = false
local hideInFloorDepth = 5
local hideDesyncConn = nil
local lastSavedCF = nil
local hifRayParams = RaycastParams.new()
hifRayParams.FilterType = Enum.RaycastFilterType.Exclude

local function startHideInFloor()
    local char = lp.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    if hideDesyncConn then hideDesyncConn:Disconnect() hideDesyncConn = nil end
    pcall(function() RunService:UnbindFromRenderStep("__hif_restore") end)

    hideDesyncConn = RunService.Heartbeat:Connect(function()
        if not hideInFloorEnabled then return end
        local c = lp.Character
        if not (c and c:FindFirstChild("HumanoidRootPart")) then return end
        local h = c.HumanoidRootPart
        local savedCF = h.CFrame
        local savedVel = h.Velocity
        local savedRotVel = h.RotVelocity
        lastSavedCF = savedCF

        hifRayParams.FilterDescendantsInstances = {c}
        local ray = workspace:Raycast(savedCF.Position + Vector3.new(0, 1, 0), Vector3.new(0, -100, 0), hifRayParams)
        local floorY = (ray and ray.Position.Y) or (savedCF.Y - 2.5)
        local targetY = floorY - hideInFloorDepth
        local targetPos = Vector3.new(savedCF.X, targetY, savedCF.Z)

        -- HRPの角度を仰向け（math.rad(-90)で顔・胸が真上、背中が下）
        local _, yaw = savedCF:ToEulerAnglesYXZ()
        local desyncCF = CFrame.new(targetPos) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(-90), 0, 0)

        h.CFrame = desyncCF
        h.Velocity = Vector3.zero
        h.RotVelocity = Vector3.zero

        -- 次フレーム描画前にクライアント側CFrame・速度を復元してDesync成立
        pcall(function() RunService:UnbindFromRenderStep("__hif_restore") end)
        RunService:BindToRenderStep("__hif_restore", 101, function()
            _fixId()
            if h then
                h.CFrame = savedCF
                h.Velocity = savedVel
                h.RotVelocity = savedRotVel
            end
            pcall(function() RunService:UnbindFromRenderStep("__hif_restore") end)
        end)
    end)
end

local function stopHideInFloor()
    if hideDesyncConn then hideDesyncConn:Disconnect() hideDesyncConn = nil end
    pcall(function() RunService:UnbindFromRenderStep("__hif_restore") end)

    local char = lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp and lastSavedCF then
        hrp.CFrame = lastSavedCF
        hrp.Velocity = Vector3.zero
        hrp.RotVelocity = Vector3.zero
    end
end

local NoclipToggle = MovementSection:AddToggle("NoclipToggle", {
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

local HideInFloorToggle = MovementSection:AddToggle("HideInFloorToggle", {
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

local HideInFloorDep = MovementSection:AddDependencyBox()

HideInFloorDep:AddSlider("HideInFloorDepth", {
    Text = "Floor Depth",
    Default = 5,
    Min = 1,
    Max = 50,
    Rounding = 1,
    Compact = false,
    Callback = function(value)
        hideInFloorDepth = value
    end
})

HideInFloorDep:SetupDependencies({ { HideInFloorToggle, true } })

    local infJumpEnabled = false
    local fighterControllerCache = nil
    local maxDoubleJumpsOriginals = {}

    local InfJumpToggle = MovementSection:AddToggle("InfJumpToggle", {
        Text = "Infinite Jump",
        Default = false,
        Callback = function(value)
            infJumpEnabled = value
            if not value and fighterControllerCache and fighterControllerCache.LocalFighter then
                local item = fighterControllerCache.LocalFighter.EquippedItem
                if item and item.Info and item.Name and maxDoubleJumpsOriginals[item.Name] then
                    item.Info.MaxDoubleJumps = maxDoubleJumpsOriginals[item.Name]
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

    RunService.RenderStepped:Connect(function()
        if not infJumpEnabled then return end
        if not fighterControllerCache then
            pcall(function()
                local ps = lp:FindFirstChild("PlayerScripts")
                local ctrl = ps and ps:FindFirstChild("Controllers")
                local fc = ctrl and ctrl:FindFirstChild("FighterController")
                if fc then fighterControllerCache = require(fc) end
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
    end)

    -- Slide Boost
    local slideBoostEnabled = false
    local slideBoostMultiplier = 1.0
    local autoSlideJumpEnabled = false

    local function setupSlideBoost()
        local MechanicsController
        local ok = pcall(function()
            local controllers = lp:WaitForChild("PlayerScripts", 10):WaitForChild("Controllers", 10)
            MechanicsController = require(controllers:WaitForChild("MechanicsController", 10))
        end)

        if not ok or type(MechanicsController) ~= "table" then return end

        local oldSlide = MechanicsController.Slide
        if type(oldSlide) ~= "function" or MechanicsController._isSlideHooked then return end
        MechanicsController._isSlideHooked = true

        MechanicsController.Slide = function(self)
            if slideBoostEnabled then
                local fighter = self.LocalFighter
                if fighter and fighter.Get then
                    local oldGet = fighter.Get
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
            if autoSlideJumpEnabled then
                task.spawn(function()
                    task.wait()
                    pcall(function()
                        if self:IsAlive() then
                            if type(self.HighJump) == "function" then
                                self:HighJump()
                            elseif type(self.Jump) == "function" then
                                self:Jump()
                            end
                            local char = lp.Character
                            local hum = char and char:FindFirstChildOfClass("Humanoid")
                            if hum then
                                hum.Jump = true
                            end
                        end
                    end)
                end)
            end
            return oldSlide(self)
        end
    end

    task.spawn(setupSlideBoost)

    local SlideBoostToggle = MovementSection:AddToggle("SlideBoostToggle", {
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

    local SlideBoostDep = MovementSection:AddDependencyBox()

    SlideBoostDep:AddSlider("SlideBoostMultiplier", {
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

    SlideBoostDep:SetupDependencies({ { SlideBoostToggle, true } })

    local AutoSlideJumpToggle = MovementSection:AddToggle("AutoSlideJumpToggle", {
        Text = "Auto Slide Jump",
        Default = false,
        Callback = function(v)
            autoSlideJumpEnabled = v
        end
    })

    AutoSlideJumpToggle:AddKeyPicker("AutoSlideJumpKey", {
        Default = "None",
        SyncToggleState = true,
        Mode = "Toggle",
        Text = "Auto Slide Jump",
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
        if hideInFloorEnabled then task.wait(0.5) startHideInFloor() end
    end)
end


-- ========== ANTI FREEZE RAY (MISC) ==========
do
    local AntiFreezeSection = Tabs.Misc:AddRightGroupbox("Anti Freeze Ray")

    getgenv().AntiFreezeEnabled = false

    local CameraController = nil
    local MechanicsController = nil
    local ClientEntityModule = nil

    task.spawn(function()
    end)

    -- entity:Get("IsFrozen")をhookしてローカルプレイヤーには常にfalseを返す
    local function hookEntity(ent)
        if not ent or ent._afGetHooked then return end
        ent._afGetHooked = true
        local oldGet = ent.Get
        ent.Get = function(self, key, ...)
            if getgenv().AntiFreezeEnabled and key == "IsFrozen" then
                return false
            end
            return oldGet(self, key, ...)
        end
    end

    -- 毎フレーム：PlatformStand解除 + entityをhook
    RunService.Heartbeat:Connect(function()
        if not getgenv().AntiFreezeEnabled then return end
        pcall(function()
            -- PlatformStand直接解除
            local char = lp.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    if hum.PlatformStand then hum.PlatformStand = false end
                    hum:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
                end
            end
            -- FighterController.LocalFighter.Entity の Get("IsFrozen") をhook
            if FighterController and FighterController.LocalFighter then
                local lf = FighterController.LocalFighter
                hookEntity(lf)
                if lf.Entity then hookEntity(lf.Entity) end
                if lf.Character then hookEntity(lf.Character) end
            end
        end)
    end)

    AntiFreezeSection:AddToggle("AntiFreezeEnabled", {
        Text = "Anti Freeze Ray",
        Default = false,
        Callback = function(v)
            getgenv().AntiFreezeEnabled = v
        end
    }):AddKeyPicker("AntiFreezeKey", {
        Default = "None",
        SyncToggleState = true,
        Mode = "Toggle",
        Text = "Anti Freeze Ray",
    })
end

-- ========== CHANGER TAB ==========
;(function()
    local changerLocalPlayer = lp
    local LeaderboardController
    pcall(function()
        LeaderboardController = require(changerLocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Controllers"):WaitForChild("LeaderboardController"))
    end)

    local SeasonLibrary
    pcall(function()
        SeasonLibrary = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("SeasonLibrary"))
    end)

    local kCharmEloMap = {
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

    local kSeasonNameMap = {
        [0] = "Zero",
        [1] = "Warp",
        [2] = "Polar",
        [3] = "Fame",
        ["Zero"] = 0,
        ["Warp"] = 1,
        ["Polar"] = 2,
        ["Fame"] = 3,
    }

    local kSeasonToggleMap = {
        [0] = "s0_charm",
        [1] = "s1_charm",
        [2] = "s2_charm",
        [3] = "s3_charm",
    }

    local kCharmRanks = {
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

    local changerStates = {
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

    local changerConnections = {}
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
        local text = obj.Text
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

    local ensureTextSpoofWatcher
    local function isTextSpoofActive()
        return changerStates.text.display_name
            or changerStates.text.username
            or changerStates.leaderboard.Wins
            or changerStates.leaderboard.Level
            or changerStates.leaderboard.Streak
    end

    local function RefreshAllNameSpoofs()
        if isTextSpoofActive() and ensureTextSpoofWatcher then
            ensureTextSpoofWatcher()
        end
        for obj, _ in pairs(changerStates.text.name_spoof_conn) do
            if obj and obj.Parent then
                ApplyNameSpoof(obj)
            end
        end
    end

    local kTextAllowed = {
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
        if not kTextAllowed[obj.Name] then return end
        if not IsTextObject(obj) then return end

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

    local _textSpoofWatched = false
    ensureTextSpoofWatcher = function()
        if _textSpoofWatched then return end
        _textSpoofWatched = true
        local pg = changerLocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return end
        task.spawn(function()
            local n = 0
            for _, obj in ipairs(pg:GetDescendants()) do
                RegisterTextObject(obj)
                n = n + 1
                if n % 500 == 0 then task.wait() end
            end
        end)
        pg.DescendantAdded:Connect(RegisterTextObject)
    end

    -- Avatar helper functions
    local function BuildWeld(weld_name, parent, part0, part1, c0, c1)
        local weld = Instance.new("Weld")
        weld.Name = weld_name
        weld.Part0 = part0
        weld.Part1 = part1
        weld.C0 = c0
        weld.C1 = c1
        weld.Parent = parent
        return weld
    end

    local function WeldAttachments(attach1, attach2)
        local weld = Instance.new("Weld")
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
                local found = FindFirstMatchingAttachment(child, name)
                if found then return found end
            end
        end
    end

    local function FindHeadPart(instance)
        if not instance then return nil end
        if instance:IsA("BasePart") then return instance end
        local head = instance:FindFirstChild("Head")
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
                local clone = child:Clone()
                clone.Parent = real_head
            end
        end
    end

    local function ApplyFakeHead(character, source_head)
        if not character or not source_head then return end
        local real_head = character:FindFirstChild("Head")
        if not real_head or not real_head:IsA("BasePart") then return end
        CopyHeadVisuals(real_head, source_head)
    end

    local function AddAccoutrement(character, accoutrement)
        accoutrement.Parent = character
        local handle = accoutrement:FindFirstChild("Handle")
        if handle then
            local attachment = handle:FindFirstChildOfClass("Attachment")
            if attachment then
                local char_attachment = FindFirstMatchingAttachment(character, attachment.Name)
                if char_attachment then
                    WeldAttachments(char_attachment, attachment)
                end
            else
                local head = character:FindFirstChild("Head")
                if head then
                    local attachmentCFrame = CFrame.new(0, 0.5, 0)
                    local hatCFrame = accoutrement.AttachmentPoint
                    BuildWeld("HeadWeld", head, head, handle, attachmentCFrame, hatCFrame)
                end
            end
        end
    end

    local function ApplyThumbnailSpoof(obj)
        if not obj:IsA("ImageLabel") then return end
        local image = obj.Image
        if typeof(image) ~= "string" then return end

        if changerStates.avatar.spoof_thumbnails and changerStates.avatar.victim_user_id then
            local myId = tostring(changerLocalPlayer.UserId)
            local spoofId = tostring(changerStates.avatar.victim_user_id)
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

    local ensureThumbSpoofWatcher
    local function RefreshAllThumbnailSpoofs()
        if changerStates.avatar.spoof_thumbnails and ensureThumbSpoofWatcher then
            ensureThumbSpoofWatcher()
        end
        for obj, _ in pairs(changerStates.avatar.thumb_spoof_conn) do
            if obj and obj.Parent then
                ApplyThumbnailSpoof(obj)
            end
        end
    end

    local kImageAllowed = {
            AvatarThumbnail = true,
            ImageLabel = true,
            Headshot = true
        }
    local function RegisterImageObject(obj)
        if not kImageAllowed[obj.Name] then return end
        if not obj:IsA("ImageLabel") then return end

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

    local _thumbSpoofWatched = false
    ensureThumbSpoofWatcher = function()
        if _thumbSpoofWatched then return end
        _thumbSpoofWatched = true
        local pg = changerLocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return end
        task.spawn(function()
            local n = 0
            for _, obj in ipairs(pg:GetDescendants()) do
                RegisterImageObject(obj)
                n = n + 1
                if n % 500 == 0 then task.wait() end
            end
        end)
        pg.DescendantAdded:Connect(RegisterImageObject)
    end

    local function SetAvatar(use_old)
        local user_id = use_old and changerLocalPlayer.UserId or changerStates.avatar.victim_user_id
        if not user_id then return end

        local char = changerLocalPlayer.Character or changerLocalPlayer.CharacterAdded:Wait()
        if not char or not char.Parent then return end

        local ok, rig_model = pcall(function()
            return Players:CreateHumanoidModelFromUserId(user_id)
        end)
        if not ok or not rig_model then return end

        for _, v in ipairs(char:GetDescendants()) do
            local isFaceDecal = v:IsA("Decal") and v.Name == "face"
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
                    local acc = item:Clone()
                    AddAccoutrement(char, acc)
                end)
            elseif item:IsA("Shirt")
            or item:IsA("Pants")
            or item:IsA("ShirtGraphic")
            or item:IsA("BodyColors")
            or item:IsA("LayeredClothing")
            or item:IsA("CharacterMesh") then
                pcall(function()
                    local clone = item:Clone()
                    clone.Parent = char
                end)
            end
        end

        local target_head = FindHeadPart(rig_model)
        if target_head then
            ApplyFakeHead(char, target_head)
            task.wait(0.1)
        end

        pcall(function() rig_model:Destroy() end)
    end

    local _avatarWasSpoofed = false
    local function SpoofAvatar()
        if changerStates.avatar.spoof_avatar then
            _avatarWasSpoofed = true
            SetAvatar(false)
        elseif _avatarWasSpoofed then
            _avatarWasSpoofed = false
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
        local num = tonumber(input)
        if num and num > 1000 then return num end
        local success, resolvedId = pcall(function()
            return Players:GetUserIdFromNameAsync(tostring(input))
        end)
        if success and resolvedId then return resolvedId end
        return nil
    end

    -- Leaderboard logic
    local function InsertPlayerByValue(list, user_id, value)
        for i = #list, 1, -1 do
            if tonumber(list[i].key) == user_id then
                table.remove(list, i)
                break
            end
        end
        local rank = 1
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

        local serial = LeaderboardController.LeaderboardSerials and LeaderboardController.LeaderboardSerials[name]
        if serial and serial.Players then
            local user_id = changerLocalPlayer.UserId
            for i = #serial.Players, 1, -1 do
                local player = serial.Players[i]
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
            local timeout = tick() + 5
            while (not LeaderboardController.LeaderboardSerials
                or not LeaderboardController.LeaderboardSerials[name]
                or not LeaderboardController.LeaderboardSerials[name].Players
                or #LeaderboardController.LeaderboardSerials[name].Players <= 0) and tick() < timeout do
                task.wait(0.5)
            end

            local user_id = changerLocalPlayer.UserId
            local serial = LeaderboardController.LeaderboardSerials and LeaderboardController.LeaderboardSerials[name]
            if serial and serial.Players then
                InsertPlayerByValue(serial.Players, user_id, value)
                if LeaderboardController.Refreshed then
                    LeaderboardController.Refreshed:Fire(name)
                end
            end

            local UpdateRemote = ReplicatedStorage:FindFirstChild("Remotes")
                and ReplicatedStorage.Remotes:FindFirstChild("Misc")
                and ReplicatedStorage.Remotes.Misc:FindFirstChild("UpdateLeaderboard")

            if UpdateRemote and UpdateRemote:IsA("RemoteEvent") then
                changerBind(config_idx, UpdateRemote.OnClientEvent, function(data)
                    local lb_name = data and data.Name
                    if not lb_name or lb_name ~= name then return end
                    if not changerStates.leaderboard[config_idx] then return end

                    task.defer(function()
                        local s = LeaderboardController.LeaderboardSerials and LeaderboardController.LeaderboardSerials[name]
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

    -- Rank / Charm logic
    if SeasonLibrary and SeasonLibrary.FormatSeasonRankCharm then
        local original_fsrc = SeasonLibrary.FormatSeasonRankCharm
        SeasonLibrary.FormatSeasonRankCharm = function(self, p2, p3, p4, p5)
            local season_num = kSeasonNameMap[p3]
            local elo = kCharmEloMap[changerStates.charm.charm_rank] or changerStates.leaderboard.elo_value
            if season_num and kSeasonToggleMap[season_num] and changerStates.charm[kSeasonToggleMap[season_num]] then
                p4 = elo or p4
                p5 = changerStates.charm.arch_rank
            end
            return original_fsrc(self, p2, p3, p4, p5)
        end
    end

    local _charmUpdatePending = false
    local function UpdateCharmOptions()
        if not (changerStates.charm.s0_charm or changerStates.charm.s1_charm or changerStates.charm.s2_charm or changerStates.charm.s3_charm) then
            return
        end
        if _charmUpdatePending then return end
        _charmUpdatePending = true
        task.spawn(function()
            task.wait(0.2)
            _charmUpdatePending = false
            local vmFolder = Workspace:FindFirstChild("ViewModels")
            local roots = { vmFolder, changerLocalPlayer.Character }
            for _, root in ipairs(roots) do
                if root then
                    for _, descendant in ipairs(root:GetDescendants()) do
                        if descendant:IsA("Model") and descendant:FindFirstChild("Extra") then
                            local name = descendant.Name
                            if string.sub(name, 1, 7) == "Season " then
                                local season_num = tonumber(string.sub(name, 8))
                                if season_num and kSeasonToggleMap[season_num] and changerStates.charm[kSeasonToggleMap[season_num]] then
                                    local season_name = kSeasonNameMap[season_num]
                                    if season_name and SeasonLibrary and SeasonLibrary.FormatSeasonRankCharm then
                                        local elo = kCharmEloMap[changerStates.charm.charm_rank] or changerStates.leaderboard.elo_value
                                        local rank = changerStates.charm.arch_rank
                                        pcall(function()
                                            SeasonLibrary:FormatSeasonRankCharm(descendant, season_name, elo, rank)
                                        end)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end)
    end

    -- Badges Spoofs
    local function ensureBadgesHook()
        if not hookmetamethod or getgenv()._BadgesHooked then return end
        getgenv()._BadgesHooked = true
        local old_index
        local indexHook = function(self, key)
            if self == changerLocalPlayer then
                if key == "MembershipType" and changerStates.badges.Premium then
                    return Enum.MembershipType.Premium
                end
                if key == "HasVerifiedBadge" and changerStates.badges.Verified then
                    return true
                end
            end
            return old_index(self, key)
        end
        if newcclosure then indexHook = newcclosure(indexHook) end
        old_index = hookmetamethod(game, "__index", indexHook)
    end

    local function UpdateBadgesOptions()
        changerLocalPlayer:SetAttribute("IsInfluencer", changerStates.badges.Influencer and true or false)
        changerLocalPlayer:SetAttribute("IsRobloxEmployee", changerStates.badges.Admin and true or false)
    end

    -- ========== CHANGER UI SETUP ==========
    local AvatarGroup = Tabs.Changer:AddLeftGroupbox("Avatar Changer")

    AvatarGroup:AddInput("VictimUsername", {
        Default = changerLocalPlayer.Name,
        Numeric = false,
        Finished = true,
        Text = "Target Username",
        Tooltip = "Enter target Roblox Username (or UserId) to copy avatar from",
        Placeholder = "Enter Username...",
        Callback = function(val)
            task.spawn(function()
                local resolvedId = ResolveUserId(val)
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

    local CharmGroup = Tabs.Changer:AddLeftGroupbox("Rank & Charm Changer")

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

    local StatsGroup = Tabs.Changer:AddRightGroupbox("Stats & Leaderboard Changer")

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

    local BadgesGroup = Tabs.Changer:AddRightGroupbox("Profile & Badges")

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
            if val then ensureBadgesHook() end
        end
    })

    BadgesGroup:AddToggle("VerifiedToggle", {
        Text = "Verified Badge",
        Default = false,
        Callback = function(val)
            changerStates.badges.Verified = val
            if val then ensureBadgesHook() end
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

    -- ========== UNLOCK ALL WEAPONS (CLIENT-SIDE) ==========
    local UnlockGroup = Tabs.Changer:AddLeftGroupbox("Unlock All (Client-Side)")

    local unlockAllEnabled = false
    local origGetUnlockedWeapons = nil
    local origGetWeaponData = nil
    local origOwnsAllWeapons = nil

    local function applyUnlockAllHook()
        local PlayerDataController = nil
        pcall(function()
            PlayerDataController = require(lp:WaitForChild("PlayerScripts"):WaitForChild("Controllers"):WaitForChild("PlayerDataController"))
        end)
        if not PlayerDataController then return end

        local PlayerDataUtility = nil
        pcall(function()
            PlayerDataUtility = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PlayerDataUtility"))
        end)

        local ItemLibrary = nil
        pcall(function()
            ItemLibrary = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ItemLibrary"))
        end)

        local ShopLibrary = nil
        pcall(function()
            ShopLibrary = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ShopLibrary"))
        end)

        local function getAllWeaponList()
            local list = {}
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
                    local real = origGetWeaponData(self, wName, ...)
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
                    local real = PlayerDataController._OrigGetWeaponData(self, wName, ...)
                    if unlockAllEnabled and not real and wName then
                        return createFakeWeaponData(wName)
                    end
                    return real
                end
            end
        end

        -- Refresh Equipment UI if open
        pcall(function()
            local UserInterface = lp:WaitForChild("PlayerScripts"):WaitForChild("UserInterface")
            local Equipment = UserInterface:FindFirstChild("Equipment")
            if Equipment then
                local eqModule = require(Equipment)
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
end)() -- do Changer

-- ========== AUTO EXECUTE ==========
local AutoExecSection = Tabs.Config:AddRightGroupbox("Auto Execute")

local function getAutoExecCode()
    local key = tostring(getgenv().SCRIPT_KEY or "")
    return string.format('getgenv().SCRIPT_KEY = %q\nloadstring(game:HttpGet("https://api.jnkie.com/api/v1/luascripts/public/d5ea756428802c506bf03e43cbd7e64f054d50c8921bcbe55f0bfbe46b1802a9/download"))()', tostring(key))
end

local _autoExecOn = false
pcall(function()
    if isfile then
        _autoExecOn = isfile("autoexec/KETY.lua") or isfile("KETY_AutoExec.lua") or false
    end
end)

-- 起動時にファイルが存在していれば queue_on_teleport を再登録 & ファイル更新
if _autoExecOn then
    pcall(function()
        local execCode = getAutoExecCode()
        if queue_on_teleport then queue_on_teleport(execCode)
        elseif syn and syn.queue_on_teleport then syn.queue_on_teleport(execCode) end
        if isfile and isfile("autoexec/KETY.lua") then writefile("autoexec/KETY.lua", execCode) end
        if isfile and isfile("KETY_AutoExec.lua") then writefile("KETY_AutoExec.lua", execCode) end
    end)
end

AutoExecSection:AddToggle("AutoExecuteToggle", {
    Text = "Auto Execute (Keep Script)",
    Default = _autoExecOn,
    Callback = function(value)
        if value then
            local execCode = getAutoExecCode()
            pcall(function()
                if queue_on_teleport then
                    queue_on_teleport(execCode)
                elseif syn and syn.queue_on_teleport then
                    syn.queue_on_teleport(execCode)
                end
            end)
            pcall(function()
                if isfolder and not isfolder("autoexec") then makefolder("autoexec") end
                writefile("autoexec/KETY.lua", execCode)
            end)
            pcall(function() writefile("KETY_AutoExec.lua", execCode) end)
        else
            pcall(function() if isfile("autoexec/KETY.lua") then delfile("autoexec/KETY.lua") end end)
            pcall(function() if isfile("KETY_AutoExec.lua") then delfile("KETY_AutoExec.lua") end end)
        end
    end
})

-- ========== SAVE MANAGER ==========
SaveManager:SetLibrary(Library)
SaveManager:SetFolder("KETY")
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({"AutoExecuteToggle"})
do
    local HttpService = game:GetService("HttpService") -- import json
    local function OPT() return Library.Options or getgenv().Options end
    local function B(box, text, fn)
        box:AddButton(text, function()
            local ok, e = pcall(fn)
            if not ok then Library:Notify(tostring(e), 6) end
        end)
    end
    local DISCORD = "https://discord.gg/7Vhu2xrBP9"

    local DiscordBox = Tabs.Config:AddRightGroupbox("Discord")
    B(DiscordBox, "Copy discord invite", function()
        local ok = pcall(function() (setclipboard or toclipboard or (syn and syn.write_clipboard))(DISCORD) end)
        Library:Notify(ok and "Copied" or DISCORD, 3)
    end)

    local CfgBox = Tabs.Config:AddRightGroupbox("Config")
    CfgBox:AddInput("SaveManager_ConfigName", { Text = "Config name" })
    B(CfgBox, "Create config", function()
        local name = OPT().SaveManager_ConfigName.Value
        if name:gsub(" ", "") == "" then return Library:Notify("Enter a name", 3) end
        local ok, err = SaveManager:Save(name)
        if not ok then return Library:Notify("Create failed: " .. tostring(err), 4) end
        Library:Notify("Created: " .. name, 3)
        OPT().SaveManager_ConfigList:SetValues(SaveManager:RefreshConfigList())
        OPT().SaveManager_ConfigList:SetValue(nil)
    end)
    CfgBox:AddDropdown("SaveManager_ConfigList", { Text = "Config list", Values = SaveManager:RefreshConfigList(), AllowNull = true })
    B(CfgBox, "Load config", function()
        local name = OPT().SaveManager_ConfigList.Value
        if not name then return Library:Notify("Select a config", 3) end
        local ok, err = SaveManager:Load(name)
        Library:Notify(ok and ("Loaded: " .. name) or ("Load failed: " .. tostring(err)), 3)
    end)
    B(CfgBox, "Save", function()
        local name = OPT().SaveManager_ConfigList.Value
        if not name then return Library:Notify("Select a config", 3) end
        local ok, err = SaveManager:Save(name)
        Library:Notify(ok and ("Saved: " .. name) or ("Save failed: " .. tostring(err)), 3)
    end)
    B(CfgBox, "Delete config", function()
        local name = OPT().SaveManager_ConfigList.Value
        if not name then return Library:Notify("Select a config", 3) end
        local ok, err = SaveManager:Delete(name)
        if not ok then return Library:Notify("Delete failed: " .. tostring(err), 4) end
        Library:Notify("Deleted: " .. name, 3)
        OPT().SaveManager_ConfigList:SetValues(SaveManager:RefreshConfigList())
        OPT().SaveManager_ConfigList:SetValue(nil)
    end)
    B(CfgBox, "Refresh list", function()
        OPT().SaveManager_ConfigList:SetValues(SaveManager:RefreshConfigList())
        OPT().SaveManager_ConfigList:SetValue(nil)
    end)
    local AutoLabel = CfgBox:AddLabel("Autoload: " .. tostring(SaveManager:GetAutoloadConfig()), true)
    B(CfgBox, "Set as autoload", function()
        local name = OPT().SaveManager_ConfigList.Value
        if not name then return Library:Notify("Select a config", 3) end
        local ok, err = SaveManager:SaveAutoloadConfig(name)
        if not ok then return Library:Notify("Failed: " .. tostring(err), 4) end
        AutoLabel:SetText("Autoload: " .. name)
    end)
    B(CfgBox, "Reset autoload", function()
        SaveManager:DeleteAutoLoadConfig()
        AutoLabel:SetText("Autoload: none")
    end)

    SaveManager:SetIgnoreIndexes({"AutoExecuteToggle", "SaveManager_ConfigName", "SaveManager_ConfigList"})
end
task.delay(0.1, function()
    pcall(function() SaveManager:LoadAutoloadConfig() end)
end)

getgenv().ModpackLoaded = true
if not getgenv().DeviceSpoofEnabled and getgenv()._LastPendingControls then
    pcall(function()
        ReplicatedStorage.Remotes.Replication.Fighter.SetControls:FireServer(getgenv()._LastPendingControls)
    end)
end
