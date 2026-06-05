-- SERVICES
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- CẤU HÌNH HỆ THỐNG LOCK-ON (HOLD PHÍM E - CHỈ NGẮM ĐẦU)
local LockKeybind = Enum.KeyCode.E -- Phím bấm (Đè giữ)
local TargetPartName = "Head"      -- Thay đổi mục tiêu khóa từ HumanoidRootPart sang ĐẦU (Head)
local MaxLockDistance = 500       -- Khoảng cách tối đa (Studs)
local FOVRadius = 6000             -- Vòng quét mục tiêu xung quanh chuột
local Smoothness = 4              -- Độ mượt khi dí theo (càng cao càng mượt)

-- CẤU HÌNH HIỆU ỨNG VIỀN TRẮNG (ESP RỖNG RUỘT)
local OUTLINE_COLOR = Color3.fromRGB(255, 255, 255) -- Màu TRẮNG
local OUTLINE_TRANSPARENCY = 0                      -- 0 là viền đậm, rõ nét nhất
local FILL_TRANSPARENCY = 1                         -- 1 là trong suốt hoàn toàn (chỉ giữ lại viền ngoài)

-- VARIABLES TRẠNG THÁI
local lockedTarget = nil          -- Lưu trữ nhân vật đang bị khóa
local isHolding = false           -- Trạng thái có đang đè phím hay không

-- ==========================================
-- PHẦN 1: LOGIC HỆ THỐNG VIỀN TRẮNG (ESP)
-- ==========================================

local function applyHighlight(character)
	if not character then return end
	
	local existingHighlight = character:FindFirstChildOfClass("Highlight")
	if existingHighlight then return end
	
	local newHighlight = Instance.new("Highlight")
	newHighlight.Name = "PlayerESP"
	newHighlight.Adornee = character
	newHighlight.OutlineColor = OUTLINE_COLOR
	newHighlight.OutlineTransparency = OUTLINE_TRANSPARENCY
	newHighlight.FillTransparency = FILL_TRANSPARENCY
	newHighlight.Enabled = true
	
	newHighlight.Parent = character
end

local function onPlayerAdded(player)
	if player == Players.LocalPlayer then return end
	
	if player.Character then
		applyHighlight(player.Character)
	end
	
	player.CharacterAdded:Connect(function(character)
		applyHighlight(character)
	end)
end

-- ==========================================
-- PHẦN 2: LOGIC KHÓA MỤC TIÊU (LOCK-ON CẢI TIẾN)
-- ==========================================

local function getClosestPlayerToMouse()
	local closestPlayer = nil
	local shortestDistance = FOVRadius
	local mousePos = UserInputService:GetMouseLocation()
	
	for _, player in Players:GetPlayers() do
		if player ~= LocalPlayer and player.Character then
			local aimPart = player.Character:FindFirstChild(TargetPartName)
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
			
			if aimPart and humanoid and humanoid.Health > 0 then
				local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
				local distance3D = localRoot and (aimPart.Position - localRoot.Position).Magnitude or 0
				
				if distance3D <= MaxLockDistance then
					local screenPos, onScreen = Camera:WorldToViewportPoint(aimPart.Position)
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

-- ĐÈ GIỮ VÀ NHẢ PHÍM
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == LockKeybind then
		isHolding = true
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if input.KeyCode == LockKeybind then
		isHolding = false
		lockedTarget = nil -- Hủy khóa ngay lập tức
	end
end)

-- VÒNG LẶP RENDER STEPPED (CẬP NHẬT LIÊN TỤC TRÁNH ĐƠ TÂM)
RunService.RenderStepped:Connect(function()
	if not isHolding then return end
	
	-- SỬA LỖI ĐƠ: Nếu chưa có mục tiêu, hoặc mục tiêu cũ không hợp lệ/đã chết -> Quét tìm liên tục từng khung hình
	if not lockedTarget or not lockedTarget.Parent or not lockedTarget.Character then
		lockedTarget = getClosestPlayerToMouse()
	else
		local targetHead = lockedTarget.Character:FindFirstChild(TargetPartName)
		local targetHumanoid = lockedTarget.Character:FindFirstChildOfClass("Humanoid")
		
		if not targetHead or not targetHumanoid or targetHumanoid.Health <= 0 then
			lockedTarget = getClosestPlayerToMouse()
		end
	end
	
	-- Nếu sau khi quét lại vẫn không thấy ai trong FOV thì dừng xử lý frame này
	if not lockedTarget then return end
	
	local targetHead = lockedTarget.Character:FindFirstChild(TargetPartName)
	if not targetHead then return end
	
	-- XOAY CAMERA BÁM THEO MỤC TIÊU
	local currentCameraCFrame = Camera.CFrame
	local targetRotation = CFrame.new(currentCameraCFrame.Position, targetHead.Position)
	
	Camera.CFrame = currentCameraCFrame:Lerp(targetRotation, 1 / Smoothness)
end)

-- ==========================================
-- PHẦN 3: KÍCH HOẠT HỆ THỐNG KHI VÀO GAME
-- ==========================================

for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

-- Fix lỗi mất ESP khi người chơi out/vào lại hoặc hồi sinh
Players.PlayerAdded:Connect(onPlayerAdded)
