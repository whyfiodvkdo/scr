-- Health Manager (исправленный)
local function Init()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local StarterGui = game:GetService("StarterGui")

    -- Настройки по умолчанию (можно менять через GUI)
    local Settings = {
        MaxHealth = 500,
        MinHealthThreshold = 100,
        RegenerationSpeed = 200, -- HP per second
        ActiveMode = "Shield", -- "Shield" или "Regen"
    }

    -- Функция уведомления
    local function notify(text)
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "Health Manager",
                Text = tostring(text),
                Duration = 3,
            })
        end)
        print("[HealthManager] " .. tostring(text))
    end

    -- Получаем игрока
    local player = Players.LocalPlayer
    if not player then
        player = Players.PlayerAdded:Wait()
    end
    if not player then
        warn("Player не найден.")
        return
    end

    local playerGui = player:WaitForChild("PlayerGui")

    -- Переменные персонажа/хуманоид
    local char = player.Character or player.CharacterAdded:Wait()
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then
        notify("Humanoid не найден в персонаже.")
        -- продолжим, т.к. CharacterAdded обработчик обновит hum позже
    end

    -- Обновляем hum при респаунe
    player.CharacterAdded:Connect(function(c)
        char = c
        hum = char:WaitForChild("Humanoid")
        notify("Character загружен.")
    end)

    -- Создаём GUI (если уже есть — пересоздаём)
    local existing = playerGui:FindFirstChild("HealthManager")
    if existing then
        existing:Destroy()
    end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "HealthManager"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = playerGui

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 360, 0, 220)
    MainFrame.Position = UDim2.new(0.5, -180, 0.5, -110)
    MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui

    -- Заголовок
    local LabelTitle = Instance.new("TextLabel")
    LabelTitle.Size = UDim2.new(1, 0, 0, 28)
    LabelTitle.Position = UDim2.new(0, 0, 0, 0)
    LabelTitle.BackgroundTransparency = 1
    LabelTitle.Font = Enum.Font.SourceSansBold
    LabelTitle.TextSize = 18
    LabelTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    LabelTitle.Text = "Health Manager v1.0"
    LabelTitle.Parent = MainFrame

    -- Mode toggle button
    local ModeButton = Instance.new("TextButton")
    ModeButton.Size = UDim2.new(0, 140, 0, 28)
    ModeButton.Position = UDim2.new(0, 10, 0, 36)
    ModeButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    ModeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ModeButton.Font = Enum.Font.SourceSans
    ModeButton.TextSize = 16
    ModeButton.Text = "Mode: " .. Settings.ActiveMode
    ModeButton.Parent = MainFrame

    ModeButton.MouseButton1Click:Connect(function()
        if Settings.ActiveMode == "Shield" then
            Settings.ActiveMode = "Regen"
        else
            Settings.ActiveMode = "Shield"
        end
        ModeButton.Text = "Mode: " .. Settings.ActiveMode
        notify("Active mode set to " .. Settings.ActiveMode)
    end)

    -- helper: create label + textbox + apply button
    local function createSettingRow(y, labelText, initialValue, onApply)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0, 120, 0, 24)
        lbl.Position = UDim2.new(0, 10, 0, y)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.SourceSans
        lbl.TextSize = 14
        lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
        lbl.Text = labelText
        lbl.Parent = MainFrame

        local txt = Instance.new("TextBox")
        txt.Size = UDim2.new(0, 150, 0, 24)
        txt.Position = UDim2.new(0, 135, 0, y)
        txt.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        txt.TextColor3 = Color3.fromRGB(255, 255, 255)
        txt.Font = Enum.Font.SourceSans
        txt.TextSize = 14
        txt.Text = tostring(initialValue)
        txt.ClearTextOnFocus = false
        txt.Parent = MainFrame

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 70, 0, 24)
        btn.Position = UDim2.new(0, 295, 0, y)
        btn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        btn.Font = Enum.Font.SourceSans
        btn.TextSize = 14
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Text = "Apply"
        btn.Parent = MainFrame

        btn.MouseButton1Click:Connect(function()
            local val = tonumber(txt.Text)
            if not val then
                notify("Некорректное значение: " .. tostring(txt.Text))
                return
            end
            onApply(val, txt)
        end)
        return txt, btn, lbl
    end

    -- Max Health
    local maxTxt = createSettingRow(70, "Max Health:", Settings.MaxHealth, function(val)
        if val < 1 then val = 1 end
        Settings.MaxHealth = val
        if hum then
            hum.MaxHealth = val
            hum.Health = math.min(hum.Health, hum.MaxHealth)
        end
        notify(string.format("Max Health set to %d.", val))
    end)

    -- Min threshold (shield)
    local minTxt = createSettingRow(106, "Shield Threshold:", Settings.MinHealthThreshold, function(val)
        if val < 0 then val = 0 end
        if val > Settings.MaxHealth then val = Settings.MaxHealth end
        Settings.MinHealthThreshold = val
        notify(string.format("Shield threshold set to %d.", val))
    end)

    -- Regen speed
    local regenTxt = createSettingRow(142, "Regen Speed (HP/sec):", Settings.RegenerationSpeed, function(val)
        if val < 0 then val = 0 end
        Settings.RegenerationSpeed = val
        notify(string.format("Regen speed set to %d HP/sec.", val))
    end)

    -- Close button
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 60, 0, 22)
    CloseBtn.Position = UDim2.new(1, -70, 0, 6)
    CloseBtn.AnchorPoint = Vector2.new(0, 0)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(100, 30, 30)
    CloseBtn.Font = Enum.Font.SourceSansBold
    CloseBtn.TextSize = 14
    CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseBtn.Text = "Close"
    CloseBtn.Parent = MainFrame
    CloseBtn.MouseButton1Click:Connect(function()
        ScreenGui:Destroy()
    end)

    -- Главная логика: использовать Heartbeat для плавной регенерации
    do
        local lastDt = 0
        RunService.Heartbeat:Connect(function(dt)
            lastDt = dt
            if not hum then return end

            -- Устанавливаем максимум здоровья персонажа
            if hum.MaxHealth ~= Settings.MaxHealth then
                hum.MaxHealth = Settings.MaxHealth
            end

            if Settings.ActiveMode == "Shield" then
                -- Мгновенное восстановление при падении ниже порога
                if hum.Health < Settings.MinHealthThreshold then
                    hum.Health = math.min(Settings.MaxHealth, Settings.MaxHealth)
                end
            elseif Settings.ActiveMode == "Regen" then
                -- Плавная регенерация: прирост = speed * dt
                if hum.Health < hum.MaxHealth then
                    local newHealth = math.min(hum.MaxHealth, hum.Health + Settings.RegenerationSpeed * dt)
                    hum.Health = newHealth
                end
            else
                warn("Unknown active mode:", Settings.ActiveMode)
            end
        end)
    end

    notify("Health Manager loaded. Use the GUI to configure settings.")
end

-- Безопасный запуск
local ok, err = pcall(Init)
if not ok then
    warn("Health Manager failed to start: ", err)
end
