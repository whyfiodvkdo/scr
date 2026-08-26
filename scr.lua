local UserInputService = game:GetService('UserInputService')
local RunService = game:GetService('RunService')
local Players = game.Players
local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local starterGui = game:GetService('StarterGui')

-- ⚙️ Ключевая переменная: теперь она отвечает за состояние полёта
local isFlying = false

starterGui:SetCore('SendNotification', {
	Title = 'Phase',
	Text = 'Controls:\n- Ctrl + K: Toggle\n- Alt + K: Fully Stop',
	Duration = 5,
})

local function getCharacter()
	return player.Character or player.CharacterAdded:Wait()
end

local function showNotification(message)
	starterGui:SetCore('SendMicroNotification', message) 
end

-- ⚙️ Функция переключения состояния полёта
local function toggleFlyMode()
	local character = getCharacter()
	if not character then return end

	isFlying = not isFlying
	showNotification(isFlying and "🚫 Flying!" or "🛑 Landed!")

	-- Микро-телепорт для корректного выхода из объектов
	if not isFlying then
		local root = character.PrimaryPart
		root.CFrame = CFrame.new(root.Position.X, root.Position.Y + 0.1, root.Position.Z)
		wait(0.01)
		root.CFrame = CFrame.new(root.Position)
	end
end

local function disableScript()
	isFlying = false
	player.CharacterAdded:Disconnect() -- Очистим старые коннекты
	showNotification("🔴 Script fully closed successfully!")
end

-- ⚙️ Главный цикл обработки коллизий
RunService.RenderStepped:Connect(function()
	local char = getCharacter()
	if not char then return end

	local hum = char:FindFirstChildOfClass('Humanoid')
	if not hum then return end

	-- Включаем коллизию ВСЕГДА, если мы не находимся в состоянии полёта ИЛИ стоим на земле
	for _, part in ipairs(char:GetDescendants()) do
		if part.ClassName == 'BasePart' then
			part.CanCollide = not (isFlying or hum.MoveDirection.Magnitude > 0.1)
		end
	end
end)

-- ⚙️ Обработчик смерти
player.CharacterAdded:Connect(function()
	task.wait(0.5) -- Ждём загрузки нового чара
	toggleFlyMode() -- Выключаем режим при респауне
end)

-- ⚙️ Горячие клавиши
UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end

	if input.KeyCode == Enum.KeyCode.K and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
		toggleFlyMode()
	elseif input.KeyCode == Enum.KeyCode.K and UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) then
		disableScript()
	end
end)
