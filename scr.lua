local function Init()
    local Players = game.GetService("Players")
    local UserInputService = game.GetService("UserInputService")

    -- ⚙️ Настройки по умолчанию (можно менять через GUI)
    local Settings = {
        MaxHealth = 500,
        MinHealthThreshold = 100,
        RegenerationSpeed = 200, -- HP per second
        ActiveMode = "Shield", -- Shield / Regen
    }

    -- Инициализация игрока
    local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
    if not player then return end

    local char = player.Character or player.CharacterAdded:Wait()
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then 
        notify("Character not found!")
        return 
    end

    -- Функция уведомления
    local function notify(text)
        pcall(function()
            game.StarterGui:SetCore("SendNotification", {
                Title = "Health Manager",
                Text = tostring(text),
                Duration = 3})
        end)
        print("" .. tostring(text))
    end

    -- ⚙️ Создание GUI
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "HealthManager"
    ScreenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")

    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 400, 0, 280)
    MainFrame.Position = UDim2.new(0.5, -200, 0.5, -140) -- Центр экрана
    MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    MainFrame.BorderSizePixel = 0
    MainFrame.Visible = true
    MainFrame.Parent = ScreenGui

    -- Заголовок
    local LabelTitle = Instance.new("TextLabel")
    LabelTitle.Text = "Health Manager v1.0"
    LabelTitle.Font = Enum.Font.SourceSansBold
    LabelTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    LabelTitle.BackgroundTransparency = 1
    LabelTitle.Size = UDim2.new(1, 0, 0, 30)
    LabelTitle.Position = UDim2.new(0, 0, 0, 0)
    LabelTitle.Parent = MainFrame

    -- Переключатель режимов
    local DropdownModes = Instance.new("DropDownList")
    DropdownModes.Position = UDim2.new(0, 10, 0, 40)
    DropdownModes.Size = UDim2.new(0, 170, 0, 30)
    DropdownModes.SelectedIndexChanged:Connect(function(index, text)
        Settings.ActiveMode = text
        notify(string.format("Active mode set to %s.", text))
    end)
    DropdownModes.Parent = MainFrame
    DropdownModes:AddItem("Shield") -- Щит
    DropdownModes:AddItem("Regen") -- Регенерация
    DropdownModes.SelectedIndex = 1

    -- Слайдер максимального здоровья
    local SliderMaxHP = Instance.new("NumberSlider")
    SliderMaxHP.Title = "Max Health:"
    SliderMaxHP.MinimumValue = 100
    SliderMaxHP.MaximumValue = 9999
    SliderMaxHP.Value = Settings.MaxHealth
    SliderMaxHP.Position = UDim2.new(0, 10, 0, 80)
    SliderMaxHP.Size = UDim2.new(0, 380, 0, 60)
    SliderMaxHP.Changed:Connect(function(value)
        Settings.MaxHealth = value
        hum.MaxHealth = value
        notify(string.format("Max Health set to %d.", value))
    end)
    SliderMaxHP.Parent = MainFrame

    -- Слайдер минимального порога (для режима щита)
    local SliderMinHP = Instance.new("NumberSlider")
    SliderMinHP.Title = "Shield Threshold:"
    SliderMinHP.MinimumValue = 0
    SliderMinHP.MaximumValue = Settings.MaxHealth
    SliderMinHP.Value = Settings.MinHealthThreshold
    SliderMinHP.Position = UDim2.new(0, 10, 0, 150)
    SliderMinHP.Size = UDim2.new(0, 380, 0, 60)
    SliderMinHP.Changed:Connect(function(value)
        Settings.MinHealthThreshold = value
        notify(string.format("Shield threshold set to %d.", value))
    end)
    SliderMinHP.Parent = MainFrame

    -- Слайдер скорости регенерации (для режима бесконечной жизни)
    local SliderRegen = Instance.new("NumberSlider")
    SliderRegen.Title = "Regen Speed (per sec):"
    SliderRegen.MinimumValue = 0
    SliderRegen.MaximumValue = 1000
    SliderRegen.Value = Settings.RegenerationSpeed
    SliderRegen.Position = UDim2.new(0, 10, 0, 220)
    SliderRegen.Size = UDim2.new(0, 380, 0, 60)
    SliderRegen.Changed:Connect(function(value)
        Settings.RegenerationSpeed = value
        notify(string.format("Regen speed set to %d HP/sec.", value))
    end)
    SliderRegen.Parent = MainFrame

    -- ⚙️ Логика работы
    task.spawn(function()
        while wait() do
            -- Устанавливаем максимум здоровья персонажа
            hum.MaxHealth = Settings.MaxHealth

            if Settings.ActiveMode == "Shield" then
                -- Режим щита: мгновенное восстановление при падении ниже порога
                if hum.Health < Settings.MinHealthThreshold then
                    hum.Health = math.min(Settings.MaxHealth, hum.MaxHealth)
                end
            elseif Settings.ActiveMode == "Regen" then
                -- Бесконечная регенерация
                hum:ChangeHealth(Settings.RegenerationSpeed * 0.03) -- 0.03 секунда между итерациями цикла
            else
                warn("Unknown active mode:", Settings.ActiveMode)
            end

            wait(0.03) -- Оптимальная частота обновления для плавности
        end
    end)

    notifyHealth Manager loaded. Use the GUI to configure settings.")
end

pcall(Init)
