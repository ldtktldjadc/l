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

local function getTarget()
    local c = getChar()
    if not c then return nil end
    local myRoot = getRoot(c)
    if not myRoot then return nil end

    local closest, closestDist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp and p.Character then
            local hb = p.Character:FindFirstChild("HitboxHead")
                    or p.Character:FindFirstChild("HitboxHeadSmall")
                    or p.Character:FindFirstChild("Head")
            if hb then
                local d = (hb.Position - myRoot.Position).Magnitude
                if d < closestDist then closestDist = d; closest = hb end
            end
        end
    end
    return closest
end

-- PhysicsRepRootPart をターゲットに設定
local function setRepRoot(hum, part)
    pcall(sethiddenproperty, hum, "PhysicsRepRootPart", part)
end

local function enableSnap()
    entry.refCount = entry.refCount + 1

    if entry.refCount == 1 then
        local c    = getChar()
        local hum  = getHumanoid(c)
        local root = getRoot(c)
        if not root or not hum then return end

        -- PhysicsRepRootPart の現在値を保存
        pcall(function()
            local ok, val = gethiddenproperty(hum, "PhysicsRepRootPart")
            if ok then entry.prevRepRoot = val end
        end)

        -- RenderStepped で毎フレーム CFrame + PhysicsRepRootPart を更新
        -- Anchored は使わない（他クライアントで止まって見えるため）
        entry.connection = RunService.RenderStepped:Connect(function()
            if entry.refCount == 0 then return end
            local ch  = getChar()
            local hm  = getHumanoid(ch)
            local rt  = getRoot(ch)
            if not ch or not hm or not rt then return end

            -- Humanoid を Physics 状態にして外力を無効化
            hm:ChangeState(Enum.HumanoidStateType.Physics)

            local target = getTarget()
            if target and target.Parent then
                rt.CFrame = target.CFrame
                rt.AssemblyLinearVelocity = Vector3.zero
                setRepRoot(hm, target)
            end
        end)
    end
end

local function disableSnap()
    if entry.refCount <= 0 then return end
    entry.refCount = entry.refCount - 1

    if entry.refCount == 0 then
        if entry.connection then
            entry.connection:Disconnect()
            entry.connection = nil
        end

        local c    = getChar()
        local hum  = getHumanoid(c)
        local root = getRoot(c)

        if hum then
            if entry.prevRepRoot then
                setRepRoot(hum, entry.prevRepRoot)
            elseif root then
                setRepRoot(hum, root)
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
frame.Size             = UDim2.new(0, 200, 0, 110)
frame.Position         = UDim2.new(0, 50, 0, 180)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
frame.BorderSizePixel  = 0
frame.Active = true; frame.Draggable = true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
local stk = Instance.new("UIStroke", frame)
stk.Color = Color3.fromRGB(60,60,70); stk.Thickness = 1

local titleLbl = Instance.new("TextLabel", frame)
titleLbl.Size = UDim2.new(1,0,0,26); titleLbl.BackgroundTransparency = 1
titleLbl.Text = "NoDelay Snap"; titleLbl.TextColor3 = Color3.fromRGB(220,220,220)
titleLbl.Font = Enum.Font.GothamBold; titleLbl.TextSize = 13

local toggleBtn = Instance.new("TextButton", frame)
toggleBtn.Size = UDim2.new(1,-20,0,34); toggleBtn.Position = UDim2.new(0,10,0,30)
toggleBtn.BackgroundColor3 = Color3.fromRGB(45,45,55); toggleBtn.BorderSizePixel = 0
toggleBtn.Text = "Snap: OFF (F)"; toggleBtn.TextColor3 = Color3.fromRGB(200,200,200)
toggleBtn.Font = Enum.Font.GothamSemibold; toggleBtn.TextSize = 13
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0,6)

local statusLbl = Instance.new("TextLabel", frame)
statusLbl.Size = UDim2.new(1,-20,0,20); statusLbl.Position = UDim2.new(0,10,0,70)
statusLbl.BackgroundTransparency = 1; statusLbl.Text = "refCount: 0 | 待機中"
statusLbl.TextColor3 = Color3.fromRGB(150,150,160)
statusLbl.Font = Enum.Font.Gotham; statusLbl.TextSize = 11

local function updateUI()
    if entry.refCount > 0 then
        toggleBtn.BackgroundColor3 = Color3.fromRGB(40,160,90)
        toggleBtn.Text = "Snap: ON (F)"
        toggleBtn.TextColor3 = Color3.fromRGB(255,255,255)
        statusLbl.Text = "refCount: "..entry.refCount.." | 追従中"
        statusLbl.TextColor3 = Color3.fromRGB(100,230,140)
    else
        toggleBtn.BackgroundColor3 = Color3.fromRGB(45,45,55)
        toggleBtn.Text = "Snap: OFF (F)"
        toggleBtn.TextColor3 = Color3.fromRGB(200,200,200)
        statusLbl.Text = "refCount: 0 | 待機中"
        statusLbl.TextColor3 = Color3.fromRGB(150,150,160)
    end
end

local function toggle()
    if entry.refCount == 0 then enableSnap() else disableSnap() end
    updateUI()
end

toggleBtn.MouseButton1Click:Connect(toggle)

local UIS = game:GetService("UserInputService")
UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.F then toggle() end
end)

lp.CharacterAdded:Connect(function()
    if entry.refCount > 0 then
        task.wait(0.1)
        enableSnap()
    end
end)

return { enable = enableSnap, disable = disableSnap, entry = entry, gui = sg }
