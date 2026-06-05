-- SERVICES
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ==========================================
-- CẤU HÌNH HỆ THỐNG MẶC ĐỊNH (TỰ ĐỘNG BẬT)
-- ==========================================
local LockKeybind = Enum.KeyCode.E        -- Phím ngắm mặc định (Đè giữ)
local ToggleGuiKeybind = Enum.KeyCode.RightShift -- Phím tắt ẩn/hiển thị bảng điều khiển UI

local TargetPartName = "Head"             -- Mục tiêu khóa vào ĐẦU
local MaxLockDistance = 500              -- Khoảng cách tối đa (Studs)
local FOVRadius = 1500                    -- Diện tích ESP quét xung quanh chuột
local Smoothness = 4                     -- Độ mượt khi dí theo (càng cao càng mượt)

-- TRẠNG THÁI (ĐÃ TỰ ĐỘNG ENABLE SẴN)
local AimbotEnabled = true
local EspEnabled = true

local lockedTarget = nil
local isHolding = false
local isChangingKeybind = false

-- CẤU HÌNH MÀU SẮC ESP VIỀN TRẮNG RỖNG RUỘT
local OUTLINE_COLOR = Color3.fromRGB(255, 255, 255)
local OUTLINE_TRANSPARENCY = 0
local FILL_TRANSPARENCY = 1

-- ==========================================
-- PHẦN 1: TẠO GIAO DIỆN (UI) ĐIỀU KHIỂN & ĐỔI PHÍM
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TestEnvironmentUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 240, 0, 160)
MainFrame.Position = UDim2.new(0.05, 0, 0.3, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true -- Cho phép giữ chuột kéo bảng đi khắp màn hình
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 6)
UICorner.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 35)
Title.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
Title.Text = "  SETTINGS SYSTEM"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 14
Title.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 6)
TitleCorner.Parent = Title

-- Dòng trạng thái thông báo tự động bật
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, 0, 0, 25)
StatusLabel.Position = UDim2.new(0, 0, 0, 40)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "ESP: ENABLED | AIMBOT: ENABLED"
StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
StatusLabel.Font = Enum.Font.SourceSansBold
StatusLabel.TextSize = 13
StatusLabel.Parent = MainFrame

-- Nút đổi phím tắt Aimbot
local KeybindButton = Instance.new("TextButton")
KeybindButton.Size = UDim2.new(0, 200, 0, 35)
KeybindButton.Position = UDim2.new(0, 20, 0, 75)
KeybindButton.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
KeybindButton.Text = "Aimbot Key: " .. LockKeybind.Name
KeybindButton.TextColor3 = Color3.fromRGB(255, 255, 255)
KeybindButton.Font = Enum.Font.SourceSans
KeybindButton.TextSize = 14
KeybindButton.Parent = MainFrame

local BtnCorner = Instance.new("UICorner")
BtnCorner.CornerRadius = UDim.new(0, 4)
BtnCorner.Parent = KeybindButton

-- Ghi chú cách ẩn bảng dưới menu
local HintLabel = Instance.new("TextLabel")
HintLabel.Size = UDim2.new(1, 0, 0, 20)
HintLabel.Position = UDim2.new(0, 0, 0, 125)
HintLabel.BackgroundTransparency = 1
HintLabel.Text = "Bấm [RightShift] để Ẩn / Hiện bảng này"
HintLabel.TextColor3 = Color3.fromRGB(170, 170, 170)
HintLabel.Font = Enum.Font.SourceSansItalic
HintLabel.TextSize = 12
HintLabel.Parent = MainFrame

-- Xử lý click đổi phím ngắm bắn
KeybindButton.MouseButton1Click:Connect(function()
	isChangingKeybind = true
	KeybindButton.Text = "Đang chờ bấm phím mới..."
	KeybindButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
end)

-- Lắng nghe bấm phím từ người chơi (Đổi phím + Ẩn hiện bảng)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	-- Logic đổi phím ngắm bắn
	if isChangingKeybind then
		if input.UserInputType == Enum.UserInputType.Keyboard then
			LockKeybind = input.KeyCode
			KeybindButton.Text = "Aimbot Key: " .. LockKeybind.Name
			KeybindButton.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
			isChangingKeybind = false
		end
		return
	end
	
	-- Logic ẩn/hiện bảng điều khiển bằng phím tắt gán sẵn (RightShift)
	if input.KeyCode == ToggleGuiKeybind then
		MainFrame.Visible = not MainFrame.Visible
	end
end)

-- ==========================================
-- PHẦN 2: LOGIC HỆ THỐNG VIỀN TRẮNG (ESP)
-- ==========================================
local function applyHighlight(character)
	if not character or not EspEnabled then return end
	
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
	if player == LocalPlayer then return end
	if player.Character then applyHighlight(player.Character) end
	player.CharacterAdded:Connect(function(character)
		applyHighlight(character)
	end)
end

-- ==========================================
-- PHẦN 3: LOGIC KHÓA MỤC TIÊU (AIMBOT CHỈ HOLD)
-- ==========================================
local function getClosestPlayerToMouse()
	if not AimbotEnabled then return nil end
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

-- Ghi nhận đè giữ phím
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or isChangingKeybind then return end
	
	if input.KeyCode == LockKeybind then
		isHolding = true
		lockedTarget = getClosestPlayerToMouse()
	end
end)

-- Ghi nhận nhả phím (Giải phóng ngắm)
UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if input.KeyCode == LockKeybind then
		isHolding = false
		lockedTarget = nil
	end
end)

-- Vòng lặp ghìm camera liên tục vào Đầu mục tiêu theo khung hình
RunService.RenderStepped:Connect(function()
	if not isHolding or not lockedTarget or not AimbotEnabled then return end
	
	if not lockedTarget.Parent or not lockedTarget.Character then
		lockedTarget = nil
		return
	end
	
	local targetHead = lockedTarget.Character:FindFirstChild(TargetPartName)
	local targetHumanoid = lockedTarget.Character:FindFirstChildOfClass("Humanoid")
	
	if not targetHead or not targetHumanoid or targetHumanoid.Health <= 0 then
		lockedTarget = getClosestPlayerToMouse()
		return
	end
	
	local currentCameraCFrame = Camera.CFrame
	local targetRotation = CFrame.new(currentCameraCFrame.Position, targetHead.Position)
	
	Camera.CFrame = currentCameraCFrame:Lerp(targetRotation, 1 / Smoothness)
end)

-- ==========================================
-- PHẦN 4: KÍCH HOẠT KHI VÀO TRÒ CHƠI
-- ==========================================
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
Players.PlayerAdded:Connect(onPlayerAdded)
