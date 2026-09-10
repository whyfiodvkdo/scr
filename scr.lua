--[[ WARNING: Heads up! This script has not been verified by ScriptBlox. Use at your own risk! ]]
local player = game.Players.LocalPlayer
local UIS = game:GetService("UserInputService")

UIS.InputEnded:Connect(function(inputObject)
	if inputObject.UserInputType == Enum.UserInputType.Keyboard and 
	   inputObject.KeyCode == Enum.KeyCode.Y then -- Активация по клавише Y
		local character = player.Character or player.CharacterAdded:Wait()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Sit = true -- Персонаж садится
		end
	end
end)
