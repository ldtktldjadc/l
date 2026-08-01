if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local lp = Players.LocalPlayer
local PlayerGui = lp:WaitForChild("PlayerGui")

if PlayerGui:FindFirstChild("LoadingScreen") then
    repeat task.wait(0.5) until not PlayerGui:FindFirstChild("LoadingScreen")
    task.wait(1)
end

local __a1b2c3 = setmetatable({}, {
    __index = function(__d4e5f6, __g7h8i9)
        local __j0k1l2, __m3n4o5 = pcall(function()
            return game:GetService(__g7h8i9)
        end)
        if __m3n4o5 then
            return cloneref(__m3n4o5)
        end
        return nil
    end
})

local __p6q7r8 = getgenv()
if __p6q7r8.__s9t0u1 then
    __p6q7r8.__s9t0u1:Shutdown()
end

local __v2w3x4 = __a1b2c3.Players
local __y5z6a7 = __a1b2c3.RunService
local __b8c9d0 = __a1b2c3.ReplicatedStorage
local __e1f2g3 = __a1b2c3.Workspace
local __h4i5j6 = __a1b2c3.UserInputService
local __k7l8m9 = __v2w3x4.LocalPlayer
local __n0o1p2 = __e1f2g3.CurrentCamera
local __q3r4s5 = __k7l8m9.PlayerScripts
local __t6u7v8 = require(__q3r4s5.Modules.ItemTypes.Gun)
local __w9x0y1 = require(__b8c9d0.Modules.Utility)
local __cvm_module = require(__q3r4s5.Modules.ClientReplicatedClasses.ClientFighter.ClientItem.ClientViewModel)

if not getgenv().__nobannable_encode_hooked then
    getgenv().__nobannable_encode_hooked = true
    local __oldEncode = __w9x0y1.EncodeCameraRotation
    __w9x0y1.EncodeCameraRotation = function(self, rot)
        local cheat = getgenv().__s9t0u1
        if cheat and cheat.__desync and cheat.__spoofYaw then
            local pitch = rot and rot.X or 0
            rot = Vector2.new(pitch, cheat.__spoofYaw)
        end
        return __oldEncode(self, rot)
    end
end



local __z2a3b4 = setmetatable({}, {
    __index = function(_, __c5d6e7)
        local __f8g9h0 = __k7l8m9.Character
        if not __f8g9h0 then return nil end
        if __c5d6e7 == "__root" then
            return __f8g9h0:FindFirstChild("HumanoidRootPart")
        elseif __c5d6e7 == "__head" then
            return __f8g9h0:FindFirstChild("HitboxHead")
        end
        return nil
    end
})

__p6q7r8.__s9t0u1 = {}

do
    local __i1j2k3 = __p6q7r8.__s9t0u1

    function __i1j2k3:__init()
        self.__active = true
        self.__target = nil
        self.__desync = false
        self.__conn1 = nil
        self.__conn2 = nil
        self.__task1 = nil
        self.__oldfunc = nil
        self.__old_playanim_func = nil
        self.__spoofYaw = nil
        self.__meleeOffset = -2
        self.__teamCheck = true
        self.__ui = nil
        self.__meleeMode = "Sweep"
        self.__voidSpam = false
        self.__voidSpamConn = nil
        self.__magnetMelee = false
        self:__setup()
    end

    function __i1j2k3:__setup()
        self.__conn1 = __y5z6a7.Heartbeat:Connect(function()
            if not self.__active then return end
            self.__target = self:__find()
        end)

        local __l4m5n6 = __t6u7v8.StartShooting
        self.__oldfunc = __l4m5n6
        __t6u7v8.StartShooting = function(__o7p8q9, ...)
            local __r0s1t2 = {__l4m5n6(__o7p8q9, ...)}
            if not __o7p8q9.ClientFighter or not __o7p8q9.ClientFighter.IsLocalPlayer then
                return unpack(__r0s1t2)
            end

            local __u3v4w5 = __r0s1t2[3]
            if not __u3v4w5 or typeof(__u3v4w5) ~= "table" then
                return unpack(__r0s1t2)
            end

            __r0s1t2[4] = true
            local __x6y7z8 = self.__target

            if not self.__active or not __x6y7z8 or not __x6y7z8.Character then
                return unpack(__r0s1t2)
            end

            if not self.__desync or self.__curr ~= __x6y7z8 then
                self:__desync_start(__x6y7z8)
                task.wait(0.15)
            end

            if self.__task1 then
                task.cancel(self.__task1)
                self.__task1 = nil
            end

            local __a9b0c1 = __x6y7z8.Character:FindFirstChild("HitboxHead")
            if not __a9b0c1 then return unpack(__r0s1t2) end

            local __d2e3f4 = __a9b0c1.Position
            local __g5h6i7 = __a9b0c1.CFrame
            local __j8k9l0 = __d2e3f4 - Vector3.new(0, 5, 0)
            local __m1n2o3 = CFrame.lookAt(__j8k9l0, __d2e3f4)
            local __p4q5r6 = __g5h6i7:ToObjectSpace(CFrame.new(__d2e3f4 + Vector3.new(math.random(), math.random(), math.random())))

            __u3v4w5[utf8.char(0)] = __w9x0y1:EncodeCFrame(CFrame.new(__j8k9l0, __d2e3f4) * CFrame.Angles(__m1n2o3:ToOrientation()))
            __u3v4w5[utf8.char(1)] = __w9x0y1:EncodeCFrame(CFrame.new(__d2e3f4) * CFrame.Angles(__m1n2o3:ToOrientation()))
            __u3v4w5[utf8.char(2)] = __a9b0c1
            __u3v4w5[utf8.char(3)] = __w9x0y1:EncodeCFrame(__p4q5r6)

            self.__task1 = task.delay(0.15, function()
                self:__desync_stop()
            end)

            return unpack(__r0s1t2)
        end

        local __old_playanim = __cvm_module.PlayAnimation
        self.__old_playanim_func = __old_playanim
        __cvm_module.PlayAnimation = function(__self, animName, ...)
            if type(animName) == "string" then
                local animLower = string.lower(animName)
                
                -- ナイフのスタブ（重攻撃）
                if string.find(animLower, "heavyattack") then
                    local ok, isLocal = pcall(function()
                        return __self.ClientItem.ClientFighter.IsLocalPlayer == true
                    end)
                    if ok and isLocal then
                        pcall(function()
                            game:GetService("StarterGui"):SetCore("SendNotification", {
                                Title = "Backstab",
                                Text = "Target Locked!",
                                Duration = 1
                            })
                        end)

                        local target = self.__target
                        if self.__active and target and target.Character then
                            task.delay(0, function()
                                if self.__active and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                                    self:__desync_start_melee(target)
                                    task.wait(0.25)
                                    self:__desync_stop()
                                end
                            end)
                        end
                    end
                -- 通常の近接攻撃
                elseif string.find(animLower, "attack") then
                    local ok, isLocal = pcall(function()
                        return __self.ClientItem.ClientFighter.IsLocalPlayer == true
                    end)
                    if ok and isLocal then
                        -- 通知は邪魔にならないように短くする
                        pcall(function()
                            game:GetService("StarterGui"):SetCore("SendNotification", {
                                Title = "Melee Lock",
                                Text = "Auto Tracking...",
                                Duration = 0.3
                            })
                        end)

                        local target = self.__target
                        if self.__active and target and target.Character then
                            task.delay(0, function()
                                if self.__active and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                                    -- 通常攻撃用の追従も同じTP関数を使う
                                    self:__desync_start_melee(target)
                                    task.wait(0.25)
                                    self:__desync_stop()
                                end
                            end)
                        end
                    end
                end
            end
            return __old_playanim(__self, animName, ...)
        end

        local coreGui
        pcall(function() coreGui = game:GetService("CoreGui") end)
        if not coreGui then coreGui = __k7l8m9:WaitForChild("PlayerGui") end

        local sg = Instance.new("ScreenGui")
        sg.Name = "NobannableUI"
        sg.ResetOnSpawn = false

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 150, 0, 40)
        btn.Position = UDim2.new(0, 20, 0, 20)
        btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        btn.TextColor3 = Color3.fromRGB(0, 255, 0)
        btn.TextSize = 18
        btn.Font = Enum.Font.SourceSansBold
        btn.Text = "TeamCheck: ON"
        btn.Parent = sg

        btn.MouseButton1Click:Connect(function()
            self.__teamCheck = not self.__teamCheck
            btn.Text = "TeamCheck: " .. (self.__teamCheck and "ON" or "OFF")
            if self.__teamCheck then
                btn.TextColor3 = Color3.fromRGB(0, 255, 0)
            else
                btn.TextColor3 = Color3.fromRGB(255, 0, 0)
            end
        end)

        local btnVoid = Instance.new("TextButton")
        btnVoid.Size = UDim2.new(0, 150, 0, 40)
        btnVoid.Position = UDim2.new(0, 20, 0, 70)
        btnVoid.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        btnVoid.TextColor3 = Color3.fromRGB(255, 0, 0)
        btnVoid.TextSize = 18
        btnVoid.Font = Enum.Font.SourceSansBold
        btnVoid.Text = "VOIDSPAM: OFF"
        btnVoid.Parent = sg

        local btnMagnet = Instance.new("TextButton")
        btnMagnet.Size = UDim2.new(0, 150, 0, 40)
        btnMagnet.Position = UDim2.new(0, 20, 0, 120)
        btnMagnet.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        btnMagnet.TextColor3 = Color3.fromRGB(255, 0, 0)
        btnMagnet.TextSize = 18
        btnMagnet.Font = Enum.Font.SourceSansBold
        btnMagnet.Text = "MAGNET: OFF"
        btnMagnet.Parent = sg

        btnMagnet.MouseButton1Click:Connect(function()
            self.__magnetMelee = not self.__magnetMelee
            btnMagnet.Text = "MAGNET: " .. (self.__magnetMelee and "ON" or "OFF")
            if self.__magnetMelee then
                btnMagnet.TextColor3 = Color3.fromRGB(0, 255, 0)
            else
                btnMagnet.TextColor3 = Color3.fromRGB(255, 0, 0)
            end
        end)

        btnVoid.MouseButton1Click:Connect(function()
            self.__voidSpam = not self.__voidSpam
            btnVoid.Text = "VOIDSPAM: " .. (self.__voidSpam and "ON" or "OFF")
            
            if self.__voidSpam then
                btnVoid.TextColor3 = Color3.fromRGB(0, 255, 0)
                if not self.__voidSpamConn then
                    -- Heartbeat に変更して正しいDESYNCのタイミングにする
                    self.__voidSpamConn = __y5z6a7.Heartbeat:Connect(function()
                        -- メレーや銃の発射時のDESYNC中は干渉しないようにスキップする
                        if self.__desync or self.__active == false then return end
                        
                        local root = __z2a3b4.__root
                        if not root then return end
                        
                        local cam = __e1f2g3.CurrentCamera
                        if not cam then return end

                        -- カメラの位置から7兆スタッド先のランダムな方向
                        local randomDir = Vector3.new(
                            math.random(-100, 100),
                            math.random(-100, 100),
                            math.random(-100, 100)
                        ).Unit

                        local targetPos = cam.CFrame.Position + (randomDir * 7000000000000)
                        
                        -- Heartbeatでサーバー向けに位置をずらし、描画前(RenderStep)に戻す
                        local savedCF = root.CFrame
                        root.CFrame = CFrame.new(targetPos)

                        __y5z6a7:BindToRenderStep("__void_restore", 101, function()
                            root.CFrame = savedCF
                            __y5z6a7:UnbindFromRenderStep("__void_restore")
                        end)
                    end)
                end
            else
                btnVoid.TextColor3 = Color3.fromRGB(255, 0, 0)
                if self.__voidSpamConn then
                    self.__voidSpamConn:Disconnect()
                    self.__voidSpamConn = nil
                end
            end
        end)

        sg.Parent = coreGui
        self.__ui = sg
    end

    function __i1j2k3:__find()
        local myChar = __k7l8m9.Character
        if not myChar then return nil end
        local myRoot = myChar:FindFirstChild("HumanoidRootPart")
        if not myRoot then return nil end
       
        local closest = nil
        local closestDist = math.huge
        local MAX_DISTANCE = 200

        for _, player in next, __v2w3x4:GetPlayers() do
            if player == __k7l8m9 then continue end
            if self.__teamCheck and player:GetAttribute("TeamID") == __k7l8m9:GetAttribute("TeamID") then continue end
           
            local char = player.Character
            if not char then continue end

            local root = char:FindFirstChild("HumanoidRootPart")
            local head = char:FindFirstChild("HitboxHead")
            local hum = char:FindFirstChildWhichIsA("Humanoid")
            
            if not (root and head and hum and hum.Health > 0) then continue end
            local cam = __e1f2g3.CurrentCamera
            if not cam then continue end
           
            -- クライアントのカメラ位置からの距離を計算する
            local dist = (cam.CFrame.Position - root.Position).Magnitude
            
            if dist > MAX_DISTANCE then continue end
            
            if dist < closestDist then
                closestDist = dist
                closest = player
            end
        end
        
        return closest
    end

    function __i1j2k3:__desync_start(__c3d4e5)
        if self.__conn2 then self.__conn2:Disconnect() end
        self.__desync = true
        self.__curr = __c3d4e5

        self.__conn2 = __y5z6a7.Heartbeat:Connect(function()
            if not self.__desync then return end
            local __f6g7h8 = __z2a3b4.__root
            if not __f6g7h8 then return end

            local __i9j0k1 = __c3d4e5.Character and __c3d4e5.Character:FindFirstChild("HumanoidRootPart")
            if not __i9j0k1 then
                self:__desync_stop()
                return
            end

            local __l2m3n4 = __f6g7h8.CFrame

            -- 銃（__desync_start）のTP位置を変更
            -- 手動変更に合わせて、-5スタッド下（Y=-5）にTPする
            __f6g7h8.CFrame = __i9j0k1.CFrame * CFrame.new(0, -5, 0)

            __y5z6a7:BindToRenderStep("__restore", 101, function()
                __f6g7h8.CFrame = __l2m3n4
                __y5z6a7:UnbindFromRenderStep("__restore")
            end)
        end)
    end

    function __i1j2k3:__desync_start_melee(__c3d4e5)
        if self.__conn2 then self.__conn2:Disconnect() end
        self.__desync = true
        self.__curr = __c3d4e5
        self.__meleeStartTime = tick()
        
        self.__conn2 = __y5z6a7.Heartbeat:Connect(function()
            if not self.__desync then return end
            local __f6g7h8 = __z2a3b4.__root
            if not __f6g7h8 then return end

            local __i9j0k1 = __c3d4e5.Character and __c3d4e5.Character:FindFirstChild("HumanoidRootPart")
            if not __i9j0k1 then
                self:__desync_stop()
                return
            end

            local __savedCF = __f6g7h8.CFrame
            local __savedVel = __f6g7h8.Velocity
            local __savedRotVel = __f6g7h8.RotVelocity

            -- Mode: Direct (Dynamic Ping)
            -- 実際のPing値を取得して予測時間を動的に算出する
            -- ping取得に失敗した場合は80msにフォールバック
            local pingSeconds = 0.08
            pcall(function()
                local stat = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]
                pingSeconds = math.clamp(stat:GetValue() / 1000, 0.02, 0.3)
            end)
            -- サーバー処理遅延分（約40ms）を加算
            local predictTime = pingSeconds + 0.04

            local tVel = __i9j0k1.Velocity
            local predictedOffset = tVel * predictTime
            
            if self.__magnetMelee then
                -- MAGNET MELEE: ターゲットの目の前に張り付く（速度影響なしで強制固定）
                __f6g7h8.CFrame = __i9j0k1.CFrame * CFrame.new(0, 0, -2)
            else
                __f6g7h8.CFrame = __i9j0k1.CFrame + predictedOffset
            end

            local _, yaw, _ = __i9j0k1.CFrame:ToOrientation()
            self.__spoofYaw = yaw
            
            -- TP中は自分自身の慣性をゼロにしてすっぽ抜けを防ぐ
            __f6g7h8.Velocity = Vector3.new(0, 0, 0)
            __f6g7h8.RotVelocity = Vector3.new(0, 0, 0)

            __y5z6a7:BindToRenderStep("__melee_restore", 101, function()
                __f6g7h8.CFrame = __savedCF
                __f6g7h8.Velocity = __savedVel
                __f6g7h8.RotVelocity = __savedRotVel
                __y5z6a7:UnbindFromRenderStep("__melee_restore")
            end)
        end)
    end

    function __i1j2k3:__desync_stop()
        self.__desync = false
        self.__spoofYaw = nil
        self.__curr = nil
        if self.__conn2 then
            self.__conn2:Disconnect()
            self.__conn2 = nil
        end
        pcall(function() __y5z6a7:UnbindFromRenderStep("__melee_restore") end)
    end

    function __i1j2k3:Shutdown()
        self.__active = false
        if self.__conn1 then self.__conn1:Disconnect() end
        if self.__conn2 then self.__conn2:Disconnect() end
        if self.__conn1 then self.__conn1:Disconnect() end
        if self.__conn2 then self.__conn2:Disconnect() end
        if self.__voidSpamConn then self.__voidSpamConn:Disconnect() end
        if self.__task1 then task.cancel(self.__task1) end
        if self.__oldfunc then
            __t6u7v8.StartShooting = self.__oldfunc
        end
        if self.__old_playanim_func then
            __cvm_module.PlayAnimation = self.__old_playanim_func
        end
        if self.__ui then
            self.__ui:Destroy()
            self.__ui = nil
        end
    end

    __i1j2k3:__init()
end
