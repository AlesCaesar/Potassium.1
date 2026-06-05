-- SERVICES
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- CẤU HÌNH HỆ THỐNG LOCK-ON (HOLD PHÍM E)
local LockKeybind = Enum.KeyCode.E -- Phím bấm (Đè giữ)
local MaxLockDistance = 500       -- Khoảng cách tối đa (Studs)
local FOVRadius = 150             -- Vòng quét mục tiêu xung quanh chuột
local Smoothness = 4              -- Độ mượt khi dí theo (càng cao càng mượt)

-- CẤU HÌNH HIỆU ỨNG VIỀN TRẮNG (ESP)
local OUTLINE_COLOR = Color3.fromRGB(255, 255, 255) -- Đổi thành màu TRẮNG
local OUTLINE_TRANSPARENCY = 0                      -- 0 là viền đậm, rõ nét nhất
local FILL_TRANSPARENCY = 1                         -- 1 là trong suốt hoàn toàn (chỉ giữ lại viền ngoài)

-- VARIABLES TRẠNG THÁI
local lockedTarget = nil          -- Lưu trữ nhân vật đang bị khóa
local isHolding = false           -- Trạng thái có đang đè phím hay không

-- ==========================================
-- PHẦN 1: LOGIC HỆ THỐNG VIỀN TRẮNG (ESP)
-- ==========================================

-- HÀM TẠO HIGHLIGHT CHO NHÂN VẬT
local function applyHighlight(character)
	if not character then return end
	
	-- Kiểm tra nếu nhân vật đã có Highlight rồi thì bỏ qua không tạo trùng
	local existingHighlight = character:FindFirstChildOfClass("Highlight")
	if existingHighlight then return end
	
	-- Tạo một Highlight mới tinh
	local newHighlight = Instance.new("Highlight")
	newHighlight.Name = "PlayerESP"
	newHighlight.Adornee = character
	newHighlight.OutlineColor = OUTLINE_COLOR
	newHighlight.OutlineTransparency = OUTLINE_TRANSPARENCY
	newHighlight.FillTransparency = FILL_TRANSPARENCY -- Làm rỗng ruột bên trong
	newHighlight.Enabled = true
	
	-- Đặt vào nhân vật
	newHighlight.Parent = character
end

-- HÀM QUẢN LÝ TỪNG NGƯỜI CHƠI THAM GIA
local function onPlayerAdded(player)
	-- Bỏ qua không tạo Highlight cho chính bản thân bạn
	if player == Players.LocalPlayer then return end
	
	-- Nếu họ đã có nhân vật sẵn trên map, tạo Highlight ngay
	if player.Character then
		applyHighlight(player.Character)
	end
	
	-- Lắng nghe mỗi khi họ bị chết và hồi sinh lại (CharacterAdded)
	player.CharacterAdded:Connect(function(character)
		applyHighlight(character)
	end)
end

-- ==========================================
-- PHẦN 2: LOGIC KHÓA MỤC TIÊU (LOCK-ON)
-- ==========================================

-- HÀM TÌM MỤC TIÊU PHÙ HỢP GẦN CHUỘT NHẤT
local function getClosestPlayerToMouse()
	local closestPlayer = nil
	local shortestDistance = FOVRadius
	local mousePos = UserInputService:GetMouseLocation()
	
	for _, player in Players:GetPlayers() do
		if player ~= LocalPlayer and player.Character then
			local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
			
			if rootPart and humanoid and humanoid.Health > 0 then
				local distance3D = (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")) 
					and (rootPart.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude or 0
				
				if distance3D <= MaxLockDistance then
					local screenPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
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

-- LOGIC ĐÈ GIỮ (HOLD) VÀ NHẢ PHÍM (RELEASE)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.KeyCode == LockKeybind then
		isHolding = true
		-- Khi vừa đè phím, lập tức quét tìm mục tiêu gần chuột nhất để khóa
		lockedTarget = getClosestPlayerToMouse()
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if input.KeyCode == LockKeybind then
		isHolding = false
		lockedTarget = nil -- Nhả phím E = Hủy khóa ngay lập tức
	end
end)

-- VÒNG LẶP CẬP NHẬT CAMERA THEO KHUNG HÌNH (RENDER STEPPED)
RunService.RenderStepped:Connect(function()
	-- Nếu không đè phím hoặc không có mục tiêu thì dừng xử lý camera
	if not isHolding or not lockedTarget then return end
	
	-- KIỂM TRA ĐIỀU KIỆN TỰ ĐỘNG HỦY KHÓA KHI MỤC TIÊU KHÔNG CÒN HỢP LỆ
	if not lockedTarget.Parent or not lockedTarget.Character then
		lockedTarget = nil
		return
	end
	
	local targetRoot = lockedTarget.Character:FindFirstChild("HumanoidRootPart")
	local targetHumanoid = lockedTarget.Character:FindFirstChildOfClass("Humanoid")
	
	if not targetRoot or not targetHumanoid or targetHumanoid.Health <= 0 then
		-- Nếu mục tiêu chết, tự động quét tìm mục tiêu mới luôn (khi vẫn đang đè giữ E)
		lockedTarget = getClosestPlayerToMouse()
		return
	end
	
	-- TỰ ĐỘNG XOAY CAMERA BÁM THEO MỤC TIÊU
	local currentCameraCFrame = Camera.CFrame
	local targetRotation = CFrame.new(currentCameraCFrame.Position, targetRoot.Position)
	
	Camera.CFrame = currentCameraCFrame:Lerp(targetRotation, 1 / Smoothness)
end)

-- ==========================================
-- PHẦN 3: KÍCH HOẠT HỆ THỐNG KHI VÀO GAME
-- ==========================================

-- 1. Quét những người chơi đã vào game trước bạn để vẽ viền trắng
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

-- 2. Lắng nghe những người chơi mới sẽ vào game sau này để vẽ viền trắng
Players.PlayerAdded:Connect(onPlayerAdded)
