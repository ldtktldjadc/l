local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local FighterController = nil
local CameraController = nil
local LockedTarget = nil

local function findModule(name)
	local scripts = LocalPlayer:WaitForChild("PlayerScripts")
	for _, v in pairs(scripts:GetDescendants()) do
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
	local camera = workspace.CurrentCamera
	local screenCenter = camera.ViewportSize / 2

	local function isBehindWall(targetPart, targetChar)
		local origin = camera.CFrame.Position
		local direction = (targetPart.Position - origin).Unit * (targetPart.Position - origin).Magnitude
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {LocalPlayer.Character, targetChar, camera}
		local ray = workspace:Raycast(origin, direction, params)
		if ray and ray.Instance and ray.Instance.Transparency < 0.8 then return true end
		return false
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
			local dist = (fighter.Entity.Model.HumanoidRootPart.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
			if dist > 500 then LockedTarget = nil end
		end
	end

	if not LockedTarget then
		local nearest = nil
		local minDist = 150
		if not FighterController or not FighterController.Objects then return nil end
		for _, fighter in pairs(FighterController.Objects) do
			if fighter ~= FighterController.LocalFighter and fighter.Entity and getHealth(fighter.Entity) > 0 and isEnemy(fighter) then
				local char = fighter.Entity.Model
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if hrp and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
					local distStuds = (hrp.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
					if distStuds < 500 then
						local part = char:FindFirstChild("HitboxHead") or char:FindFirstChild("Head")
						if part then
							local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
							if onScreen then
								local dist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
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
					local targetPos = target.Position
					local targetVel = (target.Parent and target.Parent:FindFirstChild("HumanoidRootPart")) and target.Parent.HumanoidRootPart.AssemblyLinearVelocity or Vector3.zero
					local myVel = (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")) and LocalPlayer.Character.HumanoidRootPart.AssemblyLinearVelocity or Vector3.zero
					targetPos = targetPos + (targetVel * dt * 2.2)
					local cameraOrigin = camera.CFrame.Position + (myVel * dt * 2.2)
					local direction = (targetPos - cameraOrigin).Unit
					local yaw = math.atan2(-direction.X, -direction.Z)
					local pitch = math.asin(direction.Y)
					local targetRot = Vector2.new(pitch, yaw)
					local current = self.Rotation
					local diffYaw = (targetRot.Y - current.Y + math.pi) % (2 * math.pi) - math.pi
					local targetRotAdjusted = Vector2.new(targetRot.X, current.Y + diffYaw)
					self.Rotation = self.Rotation:Lerp(targetRotAdjusted, 1)
				end
			end
		end
	end)

	print("[StrongLock] Ready.")
end)
