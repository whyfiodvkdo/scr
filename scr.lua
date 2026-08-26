local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = game.Players.LocalPlayer
local starterGui = game:GetService("StarterGui")

-- Переменная для сохранения начальной позиции
local originalPosition = nil

local isActive = false
local isScriptDisabled = false

starterGui:SetCore("SendNotification", {
    Title = "Phase",
    Text = "Controls:\n- Ctrl + K: Toggle\n- Alt + K: Fully Stop",
    Duration = 5
})

local function getCharacter()
    return player.Character or player.CharacterAdded:Wait()
end

local function showNotification(message)
    starterGui:SetCore("SendMicroNotification", message) -- Используем Micro для краткости
end

local function toggleNoClip()
    local character = getCharacter()
    if not character then return end

    isActive = not isActive
    showNotification(isActive and "🚫 Enabled!" or "🛑 Disabled!")

    -- Сохраняем позицию только при первом запуске
    if not originalPosition then
        originalPosition = character.PrimaryPart.Position
    end

    if isActive then
        -- Подключаем обработчик смерти
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.Died:Connect(function() disableScript() end)
        end

        -- Включаем режим
        RunService.Stepped:Connect(function()
            for _, part in pairs(character:GetChildren()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end)
    else
        -- ⚙️ Мгновенное восстановление коллизий
        for _, part in pairs(character:GetChildren()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end

        -- ⚙️ Микро-телепорт для исправления физики
        -- Мы поднимаем персонажа на 0.1 единицы и сразу опускаем обратно
        -- Это заставляет движок правильно рассчитать коллизии
        character.PrimaryPart.CFrame = CFrame.new(originalPosition.X, originalPosition.Y + 0.1, originalPosition.Z)
        wait(0.01)
        character.PrimaryPart.CFrame = CFrame.new(originalPosition)
    end
end

local function disableScript()
    isScriptDisabled = true
    isActive = false

    local character = getCharacter()
    if character then
        for _, part in pairs(character:GetChildren()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end

    showNotification("🔴 Script fully closed successfully!")
end

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end

    -- ⚙️ Теперь срабатывает моментально, без задержки canToggle
    if input.KeyCode == Enum.KeyCode.K and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        toggleNoClip()
    elseif input.KeyCode == Enum.KeyCode.K and UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) then
        disableScript()
    end
end)
