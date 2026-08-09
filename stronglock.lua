local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local FighterController = nil
local CameraController = nil
local LockedTarget = nil

local Settings = {
	Mode = "OFF", -- "OFF" | "STRONG" | "SMOOTH"
	Smoothness = 0.65,
	FOV = 150,
}

local function findModule(name)
	for _, v in pairs(LocalPlayer:WaitForChild("PlayerScripts"):GetDescendants()) do
		if v:IsA("ModuleScript") and (v.Name == name or v.Name == "ModuleScript_" .. name) then return v end
	end
	for _, v in pairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
		if v:IsA("ModuleScript") and (v.Name == name or v.Name == "ModuleScript_" .. name) then return v end
	end
	return nil
end

local function getHealth(entity)
	local h = 0
	pcall(function()
		if entity.GetHealth then h = entity:GetHealth()
		elseif entity.Health then h = entity.Health
		elseif entity.Humanoid then h = entity.Humanoid.Health end
	end)
	return h
end

local function isEnemy(fighter)
	local localTeam = LocalPlayer:GetAttribute("TeamID") or (FighterController and FighterController.LocalFighter and FighterController.LocalFighter:Get("TeamID"))
	local targetTeam = fighter.Player:GetAttribute("TeamID") or (fighter.Get and fighter:Get("TeamID"))
	return localTeam ~= targetTeam
end

local function getTarget()
	if Settings.Mode == "OFF" then return nil end
	local camera = workspace.CurrentCamera
	local screenCenter = camera.ViewportSize / 2

	local function isBehindWall(part, char)
		local origin = camera.CFrame.Position
		local dir = (part.Position - origin).Unit * (part.Position - origin).Magnitude
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {LocalPlayer.Character, char, camera}
		local ray = workspace:Raycast(origin, dir, params)
		return ray and ray.Instance and ray.Instance.Transparency < 0.8
	end

	if LockedTarget then
		local fighter = nil
		if FighterController and FighterController.Objects then
			for _, f in pairs(FighterController.Objects) do
				if f.Entity and f.Entity.Model and (f.Entity.Model:IsAncestorOf(LockedTarget) or f.Entity.Model == LockedTarget.Parent) then
					fighter = f; break
				end
			end
		end
		if not fighter or not fighter.Player or getHealth(fighter.Entity) <= 0 or isBehindWall(LockedTarget, fighter.Entity.Model) then
			LockedTarget = nil
		elseif LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and fighter.Entity.Model:FindFirstChild("HumanoidRootPart") then
			if (fighter.Entity.Model.HumanoidRootPart.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude > 500 then
				LockedTarget = nil
			end
		end
	end

	if not LockedTarget then
		local nearest, minDist = nil, Settings.FOV
		if not FighterController or not FighterController.Objects then return nil end
		for _, fighter in pairs(FighterController.Objects) do
			if fighter ~= FighterController.LocalFighter and fighter.Entity and getHealth(fighter.Entity) > 0 and isEnemy(fighter) then
				local char = fighter.Entity.Model
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if hrp and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
					if (hrp.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude < 500 then
						local part = char:FindFirstChild("HitboxHead") or char:FindFirstChild("Head")
						if part then
							local sp, onScreen = camera:WorldToViewportPoint(part.Position)
							if onScreen then
								local dist = (Vector2.new(sp.X, sp.Y) - screenCenter).Magnitude
								if dist < minDist and not isBehindWall(part, char) then
									minDist = dist; nearest = part
								end
							end
						end
					end
				end
			end
		end
		LockedTarget = nearest
	end
	return LockedTarget
end

-- UI
local function buildUI()
	local oldUI = LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("AimUI")
	if oldUI then oldUI:Destroy() end

	local sg = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
	sg.Name = "AimUI"; sg.ResetOnSpawn = false

	local frame = Instance.new("Frame", sg)
	frame.Size = UDim2.new(0, 180, 0, 55)
	frame.Position = UDim2.new(0.05, 0, 0.42, 0)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	frame.BorderSizePixel = 0
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
	local stroke = Instance.new("UIStroke", frame)
	stroke.Color = Color3.fromRGB(120, 0, 220); stroke.Thickness = 1.5

	local layout = Instance.new("UIListLayout", frame)
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 4)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	Instance.new("UIPadding", frame).PaddingLeft = UDim.new(0, 6)

	local modes = {"OFF", "STRONG", "SMOOTH"}
	local colors = {
		OFF    = Color3.fromRGB(70, 70, 70),
		STRONG = Color3.fromRGB(200, 0, 80),
		SMOOTH = Color3.fromRGB(80, 0, 200),
	}
	local activeColors = {
		OFF    = Color3.fromRGB(110, 110, 110),
		STRONG = Color3.fromRGB(255, 30, 100),
		SMOOTH = Color3.fromRGB(130, 0, 255),
	}

	local buttons = {}

	local function refresh()
		for mode, btn in pairs(buttons) do
			btn.BackgroundColor3 = (mode == Settings.Mode) and activeColors[mode] or colors[mode]
			btn.TextColor3 = (mode == Settings.Mode) and Color3.new(1,1,1) or Color3.fromRGB(160,160,160)
		end
	end

	for _, mode in ipairs(modes) do
		local btn = Instance.new("TextButton", frame)
		btn.Size = UDim2.new(0, 50, 0, 34)
		btn.BackgroundColor3 = colors[mode]
		btn.TextColor3 = Color3.fromRGB(160, 160, 160)
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 11
		btn.Text = mode
		btn.BorderSizePixel = 0
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)
		buttons[mode] = btn

		btn.MouseButton1Click:Connect(function()
			Settings.Mode = mode
			if mode == "OFF" then LockedTarget = nil end
			refresh()
		end)
	end

	refresh()
end

-- Hook
task.spawn(function()
	repeat task.wait(1) until LocalPlayer:FindFirstChild("PlayerScripts")

	pcall(function()
		local fcM = findModule("FighterController")
		if fcM then FighterController = require(fcM) end
	end)

	pcall(function()
		local ccM = findModule("CameraController")
		if ccM then
			CameraController = require(ccM)
			local oldUpdate = CameraController.Update
			CameraController.Update = function(self, dt)
				oldUpdate(self, dt)
				local target = getTarget()
				if target then
					local camera = workspace.CurrentCamera
					local targetPos = target.Position + ((target.Parent and target.Parent:FindFirstChild("HumanoidRootPart")) and target.Parent.HumanoidRootPart.AssemblyLinearVelocity * dt * 2.2 or Vector3.zero)
					local camOrigin = camera.CFrame.Position + ((LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")) and LocalPlayer.Character.HumanoidRootPart.AssemblyLinearVelocity * dt * 2.2 or Vector3.zero)
					local dir = (targetPos - camOrigin).Unit
					local yaw = math.atan2(-dir.X, -dir.Z)
					local pitch = math.asin(dir.Y)
					local targetRot = Vector2.new(pitch, yaw)
					local current = self.Rotation
					local diffYaw = (targetRot.Y - current.Y + math.pi) % (2 * math.pi) - math.pi
					local targetRotAdj = Vector2.new(targetRot.X, current.Y + diffYaw)
					local alpha = (Settings.Mode == "STRONG") and 1 or math.clamp((1 - Settings.Smoothness) * 0.5, 0.01, 1)
					self.Rotation = self.Rotation:Lerp(targetRotAdj, alpha)
				end
			end
		end
	end)

	buildUI()
	print("[AimBot] Ready.")
end)
