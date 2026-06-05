-- CHỜ GAME TẢI XONG ĐỂ TRÁNH LỖI KHỞI ĐỘNG
if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
-- Cách lấy Camera an toàn hơn, tự động cập nhật nếu Camera cũ bị reset
local function getCamera()
	return workspace.CurrentCamera or workspace:FindFirstChildOfClass("Camera")
end

-- CẤU HÌNH
local LockKeybind = Enum.KeyCode.E
local TargetPartName = "Head"
local MaxLockDistance = 500
local FOVRadius = 6000
local Smoothness = 4

local OUTLINE_COLOR = Color3.fromRGB(255, 255, 255)
local OUTLINE_TRANSPARENCY = 0
local FILL_TRANSPARENCY = 1

local lockedTarget = nil
local isHolding = false

-- ESP VIỀN TRẮNG (Bọc trong pcall để tránh crash script)
local function applyHighlight(character)
	if not character then return end
	pcall(function()
		local existingHighlight = character:FindFirstChild("PlayerESP")
		if existingHighlight then return end
		
		local newHighlight = Instance.new("Highlight")
		newHighlight.Name = "PlayerESP"
		newHighlight.Adornee = character
		newHighlight.OutlineColor = OUTLINE_COLOR
		newHighlight.OutlineTransparency = OUTLINE_TRANSPARENCY
		newHighlight.FillTransparency = FILL_TRANSPARENCY
		newHighlight.Enabled = true
		newHighlight.Parent = character
	end)
end

local function onPlayerAdded(player)
	if player == LocalPlayer then return end
	if player.Character then applyHighlight(player.Character) end
	player.CharacterAdded:Connect(function(character)
		task.wait(0.5) -- Chờ nhân vật load xong hẳn rồi vẽ viền
		applyHighlight(character)
	end)
end

-- LOGIC TÌM MỤC TIÊU
local function getClosestPlayerToMouse()
	local closestPlayer = nil
	local shortestDistance = FOVRadius
	local camera = getCamera()
	if not camera then return nil end
	
	local mousePos = UserInputService:GetMouseLocation()
	
	for _, player in Players:GetPlayers() do
		if player ~= LocalPlayer and player.Character then
			local aimPart = player.Character:FindFirstChild(TargetPartName)
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
			
			if aimPart and humanoid and humanoid.Health > 0 then
				local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
				local distance3D = localRoot and (aimPart.Position - localRoot.Position).Magnitude or 0
				
				if distance3D <= MaxLockDistance then
					-- Chuyển tọa độ 3D của ĐẦU sang tọa độ màn hình 2D
					local screenPos, onScreen = camera:WorldToViewportPoint(aimPart.Position)
					if onScreen then
						local mouseDistance = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
						if mouseDistance < shortestDistance then
							closestPlayer = player
							shortestDistance = mouseDistance
						end
					end
				end
			end
		end
	end
	return closestPlayer
end

-- SỰ KIỆN PHÍM BẤM
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == LockKeybind then
		isHolding = true
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if input.KeyCode == LockKeybind then
		isHolding = false
		lockedTarget = nil
	end
end)

-- VÒNG LẶP KHÓA MỤC TIÊU
RunService.RenderStepped:Connect(function()
	if not isHolding then return end
	
	local camera = getCamera()
	if not camera then return end
	
	if not lockedTarget or not lockedTarget.Parent or not lockedTarget.Character then
		lockedTarget = getClosestPlayerToMouse()
	else
		local targetHead = lockedTarget.Character:FindFirstChild(TargetPartName)
		local targetHumanoid = lockedTarget.Character:FindFirstChildOfClass("Humanoid")
		
		if not targetHead or not targetHumanoid or targetHumanoid.Health <= 0 then
			lockedTarget = getClosestPlayerToMouse()
		end
	end
	
	if not lockedTarget then return end
	
	local targetHead = lockedTarget.Character:FindFirstChild(TargetPartName)
	if not targetHead then return end
	
	-- Di chuyển camera mượt mà bám theo đầu đối thủ
	pcall(function()
		local currentCameraCFrame = camera.CFrame
		local targetRotation = CFrame.new(currentCameraCFrame.Position, targetHead.Position)
		camera.CFrame = currentCameraCFrame:Lerp(targetRotation, 1 / Smoothness)
	end)
end)

-- KÍCH HOẠT
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
Players.PlayerAdded:Connect(onPlayerAdded)
