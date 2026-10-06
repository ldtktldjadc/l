-- NoDelaySnap.lua
-- HumanoidRootPart.Anchored = true にした後
-- sethiddenproperty(humanoid, "PhysicsRepRootPart", HitboxHead) で
-- 物理レプリケーションのルートをターゲットに差し替える
-- → サーバー・相手視点でも遅延なしで追従
-- refCount で複数箇所から呼んでも正常動作

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local lp = Players.LocalPlayer

local entry = {
    refCount      = 0,
    connection    = nil,
    prevAnchored  = false,
    prevRepRoot   = nil,
}

local function getChar()
    return lp.Character
end

local function getHumanoid(c)
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function getRoot(c)
    return c and c:FindFirstChild("HumanoidRootPart")
end

local config = {
    targetMode   = "RootPart",    -- "RootPart" | "HitboxHead"
    velocityMode = "None",        -- "None" (触らない) | "Zero" (0固定) | "Match" (相手速度)
    cframeMode   = "Direct",      -- "Direct" (rt.CFrame) | "Pivot" (PivotTo) | "None"
    repTarget    = "rt",          -- "rt" (HumanoidRootPart) | "hm" (Humanoid) | "OFF"
    stepTiming   = "Heartbeat",   -- "Heartbeat" | "RenderStepped" | "Stepped"
}

local function getTarget()
    local c = getChar()
    if not c then return nil end
    local myRoot = getRoot(c)
    if not myRoot then return nil end

    local closest, closestDist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp and p.Character then
            local targetPart
            if config.targetMode == "RootPart" then
                targetPart = p.Character:FindFirstChild("HumanoidRootPart")
            else
                targetPart = p.Character:FindFirstChild("HitboxHead")
                    or p.Character:FindFirstChild("HitboxHeadSmall")
                    or p.Character:FindFirstChild("Head")
            end

            if targetPart then
                local d = (targetPart.Position - myRoot.Position).Magnitude
                if d < closestDist then closestDist = d; closest = targetPart end
            end
        end
    end
    return closest
end

-- PhysicsRepRootPart をターゲットに設定
local function setRepRoot(targetObj, part)
    pcall(sethiddenproperty, targetObj, "PhysicsRepRootPart", part)
end

local function onStep()
    if entry.refCount == 0 then return end
    local ch  = getChar()
    local hm  = getHumanoid(ch)
    local rt  = getRoot(ch)
    if not ch or not hm or not rt then return end

    pcall(setsimulationradius, math.huge, math.huge)

    local target = getTarget()
    if not target or not target.Parent then return end

    -- PhysicsRepRootPart 設定
    if config.repTarget == "rt" then
        pcall(sethiddenproperty, rt, "PhysicsRepRootPart", target)
    elseif config.repTarget == "hm" then
        pcall(sethiddenproperty, hm, "PhysicsRepRootPart", target)
    end

    -- CFrame 同期
    if config.cframeMode == "Direct" then
        rt.CFrame = target.CFrame
    elseif config.cframeMode == "Pivot" then
        ch:PivotTo(target.CFrame)
    end

    -- Velocity 同期
    if config.velocityMode == "Zero" then
        rt.AssemblyLinearVelocity = Vector3.zero
        rt.AssemblyAngularVelocity = Vector3.zero
        pcall(function() rt.Velocity = Vector3.zero end)
    elseif config.velocityMode == "Match" then
        local tVel = target.AssemblyLinearVelocity
        rt.AssemblyLinearVelocity = tVel
        rt.AssemblyAngularVelocity = Vector3.zero
        pcall(function() rt.Velocity = tVel end)
    end
end

local function unbindStep()
    if entry.connection then
        entry.connection:Disconnect()
        entry.connection = nil
    end
end

local function bindStep()
    unbindStep()
    if entry.refCount <= 0 then return end
    if config.stepTiming == "Heartbeat" then
        entry.connection = RunService.Heartbeat:Connect(onStep)
    elseif config.stepTiming == "RenderStepped" then
        entry.connection = RunService.RenderStepped:Connect(onStep)
    elseif config.stepTiming == "Stepped" then
        entry.connection = RunService.Stepped:Connect(onStep)
    end
end

local function forceReAlign()
    local ch = getChar()
    local rt = getRoot(ch)
    local hm = getHumanoid(ch)
    local target = getTarget()
    if rt and target then
        rt.CFrame = target.CFrame
        if config.repTarget == "rt" then
            pcall(sethiddenproperty, rt, "PhysicsRepRootPart", target)
        elseif config.repTarget == "hm" and hm then
            pcall(sethiddenproperty, hm, "PhysicsRepRootPart", target)
        end
    end
end

local function enableSnap()
    entry.refCount = entry.refCount + 1

    if entry.refCount == 1 then
        local c    = getChar()
        local hum  = getHumanoid(c)
        local root = getRoot(c)
        if not root or not hum then return end

        pcall(function()
            local ok, val = gethiddenproperty(hum, "PhysicsRepRootPart")
            if ok then entry.prevRepRoot = val end
        end)
        entry.prevAnchored = root.Anchored

        local target = getTarget()
        if target then
            root.CFrame = target.CFrame
            if config.repTarget == "rt" then
                pcall(sethiddenproperty, root, "PhysicsRepRootPart", target)
            elseif config.repTarget == "hm" then
                pcall(sethiddenproperty, hum, "PhysicsRepRootPart", target)
            end
        end

        bindStep()
    end
end

local function disableSnap()
    if entry.refCount <= 0 then return end
    entry.refCount = entry.refCount - 1

    if entry.refCount == 0 then
        unbindStep()

        local c    = getChar()
        local hum  = getHumanoid(c)
        local root = getRoot(c)

        if hum and root then
            if entry.prevRepRoot then
                setRepRoot(hum, entry.prevRepRoot)
                setRepRoot(root, entry.prevRepRoot)
            else
                setRepRoot(hum, root)
                setRepRoot(root, root)
            end
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
        end
    end
end

-- ============================================================
-- UI
-- ============================================================
local CoreGui   = game:GetService("CoreGui")
local guiOk     = pcall(function() return CoreGui.Name end)
local guiParent = guiOk and CoreGui or lp:WaitForChild("PlayerGui")

if guiParent:FindFirstChild("NoDelaySnapGui") then
    guiParent.NoDelaySnapGui:Destroy()
end

local sg = Instance.new("ScreenGui")
sg.Name = "NoDelaySnapGui"; sg.ResetOnSpawn = false; sg.Parent = guiParent

local frame = Instance.new("Frame", sg)
frame.Size             = UDim2.new(0, 210, 0, 285)
frame.Position         = UDim2.new(0, 50, 0, 180)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
frame.BorderSizePixel  = 0
frame.Active = true; frame.Draggable = true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
local stk = Instance.new("UIStroke", frame)
stk.Color = Color3.fromRGB(60,60,70); stk.Thickness = 1

local titleLbl = Instance.new("TextLabel", frame)
titleLbl.Size = UDim2.new(1,0,0,24); titleLbl.BackgroundTransparency = 1
titleLbl.Text = "NoDelay Snap (Debug)"; titleLbl.TextColor3 = Color3.fromRGB(220,220,220)
titleLbl.Font = Enum.Font.GothamBold; titleLbl.TextSize = 12

local function createBtn(text, yPos, height)
    local btn = Instance.new("TextButton", frame)
    btn.Size = UDim2.new(1, -16, 0, height or 24)
    btn.Position = UDim2.new(0, 8, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(210, 210, 220)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 11
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
    return btn
end

local toggleBtn  = createBtn("Snap: OFF", 26, 28)
local modeBtn    = createBtn("Target: " .. config.targetMode, 58)
local velBtn     = createBtn("Velocity: " .. config.velocityMode, 86)
local cfBtn      = createBtn("CFrame: " .. config.cframeMode, 114)
local repBtn     = createBtn("RepRoot: " .. config.repTarget, 142)
local stepBtn    = createBtn("Step: " .. config.stepTiming, 170)
local realignBtn = createBtn("[ Force Re-Align ]", 198)
realignBtn.BackgroundColor3 = Color3.fromRGB(70, 45, 95)
realignBtn.TextColor3 = Color3.fromRGB(230, 205, 255)

local statusLbl = Instance.new("TextLabel", frame)
statusLbl.Size = UDim2.new(1, -16, 0, 50); statusLbl.Position = UDim2.new(0, 8, 0, 228)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = "待機中 | ref: 0\nDist: -"
statusLbl.TextColor3 = Color3.fromRGB(150,150,160)
statusLbl.Font = Enum.Font.Gotham; statusLbl.TextSize = 11
statusLbl.TextWrapped = true

local function updateUI()
    if entry.refCount > 0 then
        toggleBtn.BackgroundColor3 = Color3.fromRGB(40,160,90)
        toggleBtn.Text = "Snap: ON"
        toggleBtn.TextColor3 = Color3.fromRGB(255,255,255)
        local t = getTarget()
        local r = getRoot(getChar())
        local d = (t and r) and string.format("%.1f", (t.Position - r.Position).Magnitude) or "-"
        statusLbl.Text = "追従中 | ref:" .. entry.refCount .. "\nTargetDist: " .. d .. " studs"
        statusLbl.TextColor3 = Color3.fromRGB(100,230,140)
    else
        toggleBtn.BackgroundColor3 = Color3.fromRGB(45,45,55)
        toggleBtn.Text = "Snap: OFF"
        toggleBtn.TextColor3 = Color3.fromRGB(200,200,200)
        statusLbl.Text = "待機中 | ref: 0\nDist: -"
        statusLbl.TextColor3 = Color3.fromRGB(150,150,160)
    end
    modeBtn.Text  = "Target: " .. config.targetMode
    velBtn.Text   = "Velocity: " .. config.velocityMode
    cfBtn.Text    = "CFrame: " .. config.cframeMode
    repBtn.Text   = "RepRoot: " .. config.repTarget
    stepBtn.Text  = "Step: " .. config.stepTiming
end

local function toggle()
    if entry.refCount == 0 then enableSnap() else disableSnap() end
    updateUI()
end
toggleBtn.MouseButton1Click:Connect(toggle)

modeBtn.MouseButton1Click:Connect(function()
    config.targetMode = (config.targetMode == "RootPart") and "HitboxHead" or "RootPart"
    updateUI()
end)

velBtn.MouseButton1Click:Connect(function()
    if config.velocityMode == "None" then
        config.velocityMode = "Zero"
    elseif config.velocityMode == "Zero" then
        config.velocityMode = "Match"
    else
        config.velocityMode = "None"
    end
    updateUI()
end)

cfBtn.MouseButton1Click:Connect(function()
    if config.cframeMode == "Direct" then
        config.cframeMode = "Pivot"
    elseif config.cframeMode == "Pivot" then
        config.cframeMode = "None"
    else
        config.cframeMode = "Direct"
    end
    updateUI()
end)

repBtn.MouseButton1Click:Connect(function()
    if config.repTarget == "rt" then
        config.repTarget = "hm"
    elseif config.repTarget == "hm" then
        config.repTarget = "OFF"
    else
        config.repTarget = "rt"
    end
    updateUI()
end)

stepBtn.MouseButton1Click:Connect(function()
    if config.stepTiming == "Heartbeat" then
        config.stepTiming = "RenderStepped"
    elseif config.stepTiming == "RenderStepped" then
        config.stepTiming = "Stepped"
    else
        config.stepTiming = "Heartbeat"
    end
    bindStep()
    updateUI()
end)

realignBtn.MouseButton1Click:Connect(function()
    forceReAlign()
    updateUI()
end)

local UIS = game:GetService("UserInputService")
UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.F then
        toggle()
    end
end)

lp.CharacterAdded:Connect(function()
    if entry.refCount > 0 then
        task.wait(0.1)
        bindStep()
    end
end)

return { enable = enableSnap, disable = disableSnap, entry = entry, config = config, gui = sg }
