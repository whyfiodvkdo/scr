local uis = game:GetService("UserInputService")
local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid")

uis.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.LeftShift then
        hum.WalkSpeed = 50
    end
end)
uis.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.LeftShift then
        hum.WalkSpeed = 16 -- Возвращаем стандартную скорость
    end
end)
