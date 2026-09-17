--[[ WARNING: Heads up! This script has not been verified by ScriptBlox. Use at your own risk! ]]
local player = game.Players.LocalPlayer
local UIS = game.GetService(game, "UserInputService")

local isInvisible = false -- Флаг состояния

UIS.InputEnded:Connect(function(inputObject)
	if inputObject.UserInputType == Enum.UserInputType.Keyboard then
		local keyCode = inputObject.KeyCode

		-- ⚠️ Кнопка V (на английской раскладке): Невидимость
		if keyCode == Enum.KeyCode.V then
			isInvisible = not isInvisible -- Переключаем состояние

			for _, child in ipairs(player.Character or {}) do
				if child.ClassName == 'Accessory' or child.Name == 'HumanoidRootPart' then
					child.RenderingState = if isInvisible then 1 else 0
				end
			end

			-- Обрабатываем части тела
			local humanoidDesc = player.Character and player.Character:FindFirstChildOfClass('Humanoid')
			if humanoidDesc then
				humanoidDesc:GetAppliedAnimationTrackClips():forEach(function(trackClip)
					trackClip.HumanoidObject.RenderingState = if isInvisible then 1 else 0
				end)
			end
		end
	end
end)
