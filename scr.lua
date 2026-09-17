--[[ WARNING: Heads up! This script has not been verified by ScriptBlox. Use at your own risk! ]]
local player = game.Players.LocalPlayer
local UIS = game.GetService(game, "UserInputService")

-- Внутриигровое уведомление
local notification = Instance.new("ScreenGui", player.PlayerGui)
notification.Name = "FlyNotification"
local label = Instance.new("TextLabel", notification)
label.BackgroundTransparency = 1 -- Прозрачный фон
label.TextColor3 = Color3.fromRGB(255, 255, 0) -- Жёлтый текст
label.Position = UDim2.new(0.5, -75, 0.9, 0) -- По центру внизу экрана
label.Size = UDim2.new(0, 150, 0, 40)
label.FontSize = Enum.FontSize.Size18

local flyEnabled = false

UIS.InputEnded:Connect(function(inputObject)
	if inputObject.UserInputType == Enum.UserInputType.Keyboard then
		local keyCode = inputObject.KeyCode

		-- ⚡️ Кнопка T (на английской раскладке): Переключение флая
		if keyCode == Enum.KeyCode.T then
			flyEnabled = not flyEnabled
			label.Visible = true
			if flyEnabled then
				label.Text = "[FLY] Активен\nУправление:\n= — вверх (+1)\n- — вниз (-1)"
				wait(3) -- Показываем инструкцию на 3 секунды
			else
				label.Text = "[FLY] Выключен"
				wait(1)
			end
			label.Visible = false

		elseif flyEnabled and keyCode == Enum.KeyCode.Equal then -- Клавиша "="
			local rootPart = player.Character and player.Character.PrimaryPart
			if rootPart then
				rootPart.CFrame = rootPart.CFrame * CFrame.new(0, 1, 0)
			end

		elseif flyEnabled and keyCode == Enum.KeyCode.Minus then -- Клавиша "-"
			local rootPart = player.Character and player.Character.PrimaryPart
			if rootPart then
				rootPart.CFrame = rootPart.CFrame * CFrame.new(0, -1, 0)
			end
		end
	end
end)
