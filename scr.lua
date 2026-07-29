-- Автономный GUI для Speed & Jump Power
local function Init()
    local player = game.Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")
    
    -- Значения по умолчанию
    local defaultSpeed = 16
    local defaultJump = 50

    -- --- СОЗДАНИЕ ИНТЕРФЕЙСА ---
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CheatControlPanel"
    screenGui.ResetOnSpawn = false -- Чтобы GUI не пропадал после смерти
    screenGui.Parent = player:WaitForChild("PlayerGui")

    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 250, 0, 140)
    mainFrame.Position = UDim2.new(0.5, -125, 0.3, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    mainFrame.BorderSizePixel = 0
    mainFrame.Visible = true
    mainFrame.Parent = screenGui

    -- Тень для красоты
    local shadow = Instance.new("ImageLabel")
    shadow.Image = "rbxassetid://789453280" -- Стандартная тень Roblox
    shadow.Size = UDim2.new(1, 0, 1, 0)
    shadow.BackgroundTransparency = 1
    shadow.ZIndex = -1
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(10, 10, 11, 11)
    shadow.Parent = mainFrame

    -- Заголовок
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.BackgroundTransparency = 1
    title.Text = "[PLAYER MODS]"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.TextColor3 = Color3.fromRGB(200, 200, 255)
    title.Parent = mainFrame

    -- Ползунок скорости
    local speedSlider = Instance.new("TextBox")
    speedSlider.Size = UDim2.new(1, -20, 0, 25)
    speedSlider.Position = UDim2.new(0, 10, 0, 40)
    speedSlider.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    speedSlider.PlaceholderText = "Speed: 16"
    speedSlider.Font = Enum.Font.Code
    speedSlider.TextSize = 14
    speedSlider.ClearTextOnFocus = false
    speedSlider.Parent = mainFrame

    local speedLine = Instance.new("Frame")
    speedLine.Size = UDim2.new(1, -20, 0, 2)
    speedLine.Position = UDim2.new(0, 10, 0, 65)
    speedLine.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    speedLine.Parent = mainFrame

    -- Ползунок прыжка
    local jumpSlider = Instance.new("TextBox")
    jumpSlider.Size = UDim2.new(1, -20, 0, 25)
    jumpSlider.Position = UDim2.new(0, 10, 0, 75)
    jumpSlider.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    jumpSlider.PlaceholderText = "Jump: 50"
    jumpSlider.Font = Enum.Font.Code
    jumpSlider.TextSize = 14
    jumpSlider.ClearTextOnFocus = false
    jumpSlider.Parent = mainFrame

    local jumpLine = Instance.new("Frame")
    jumpLine.Size = UDim2.new(1, -20, 0, 2)
    jumpLine.Position = UDim2.new(0, 10, 0, 100)
    jumpLine.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
    jumpLine.Parent = mainFrame

    -- Кнопка сброса
    local resetBtn = Instance.new("TextButton")
    resetBtn.Size = UDim2.new(1, -20, 0, 25)
    resetBtn.Position = UDim2.new(0, 10, 0, 110)
    resetBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    resetBtn.Text = "Reset to Default"
    resetBtn.Font = Enum.Font.Gotham
    resetBtn.TextSize = 12
    resetBtn.Parent = mainFrame

    -- --- ЛОГИКА РАБОТЫ ПОЛЗУНКОВ ---
    -- Мы используем TextBox как замену Slider, так как его проще реализовать из строки кода без картинок фона
    local function updateFill(bar, percentage)
        bar.Size = UDim2.new(percentage, 0, bar.Size.Y.Scale, bar.Size.Y.Offset)
    end

    local function applySpeed(text)
        local val = tonumber(text)
        if val and val >= 16 and val <= 200 then
            humanoid.WalkSpeed = val
            speedSlider.PlaceholderText = "Speed: " .. math.floor(val)
            updateFill(speedLine, (val - 16) / (200 - 16))
        else
            speedSlider.Text = ""
        end
    end

    local function applyJump(text)
        local val = tonumber(text)
        if val and val >= 50 and val <= 300 then
            humanoid.JumpPower = val
            jumpSlider.PlaceholderText = "Jump: " .. math.floor(val)
            updateFill(jumpLine, (val - 50) / (300 - 50))
        else
            jumpSlider.Text = ""
        end
    end

    -- События ввода
    speedSlider.FocusLost:Connect(function(enterPressed)
        if enterPressed then applySpeed(speedSlider.Text) end
    end)
    speedSlider:GetPropertyChangedSignal("Text"):Connect(function()
        applySpeed(speedSlider.Text)
    end)

    jumpSlider.FocusLost:Connect(function(enterPressed)
        if enterPressed then applyJump(jumpSlider.Text) end
    end)
    jumpSlider:GetPropertyChangedSignal("Text"):Connect(function()
        applyJump(jumpSlider.Text)
    end)

    -- Кнопка сброса
    resetBtn.MouseButton1Click:Connect(function()
        humanoid.WalkSpeed = defaultSpeed
        humanoid.JumpPower = defaultJump
        speedSlider.Text = ""
        jumpSlider.Text = ""
        speedSlider.PlaceholderText = "Speed: 16"
        jumpSlider.PlaceholderText = "Jump: 50"
        updateFill(speedLine, 0)
        updateFill(jumpLine, 0)
    end)

    -- --- УПРАВЛЕНИЕ ВИДИМОСТЬЮ (HOTKEY) ---
    local uis = game:GetService("UserInputService")
    local isVisible = true

    uis.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.Delete then
            isVisible = not isVisible
            mainFrame.Visible = isVisible
        end
    end)

    -- Уведомление о загрузке
    pcall(function()
        game.StarterGui:SetCore("SendNotification", {
            Title = "GUI Loaded";
            Text = "Press DELETE to toggle menu.";
            Duration = 4;
        })
    end)
end

pcall(Init)
