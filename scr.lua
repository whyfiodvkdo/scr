-- Автономный GUI для Speed & Jump Power (LocalScript)
local function Init()
    local Players = game:GetService("Players")
    local uis = game:GetService("UserInputService")

    local player = Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")

    -- Пересвязываем humanoid при респавне
    local function bindCharacter(char)
        humanoid = char:WaitForChild("Humanoid")
        -- при необходимости можно восстановить значения
    end
    player.CharacterAdded:Connect(bindCharacter)

    -- Значения по умолчанию
    local defaultSpeed = 16
    local defaultJump = 50

    -- Создание интерфейса
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CheatControlPanel"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = player:WaitForChild("PlayerGui")

    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 250, 0, 140)
    mainFrame.Position = UDim2.new(0.5, -125, 0.3, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    mainFrame.BorderSizePixel = 0
    mainFrame.Visible = true
    mainFrame.Parent = screenGui

    local shadow = Instance.new("ImageLabel")
    shadow.Image = "rbxassetid://789453280"
    shadow.Size = UDim2.new(1, 0, 1, 0)
    shadow.BackgroundTransparency = 1
    shadow.ZIndex = -1
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(10, 10, 11, 11)
    shadow.Parent = mainFrame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.BackgroundTransparency = 1
    title.Text = "[PLAYER MODS]"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.TextColor3 = Color3.fromRGB(200, 200, 255)
    title.Parent = mainFrame

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
    speedLine.Size = UDim2.new(0, 0, 0, 2) -- начнём с 0 заполнения
    speedLine.Position = UDim2.new(0, 10, 0, 65)
    speedLine.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    speedLine.Parent = mainFrame

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
    jumpLine.Size = UDim2.new(0, 0, 0, 2)
    jumpLine.Position = UDim2.new(0, 10, 0, 100)
    jumpLine.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
    jumpLine.Parent = mainFrame

    local resetBtn = Instance.new("TextButton")
    resetBtn.Size = UDim2.new(1, -20, 0, 25)
    resetBtn.Position = UDim2.new(0, 10, 0, 110)
    resetBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    resetBtn.Text = "Reset to Default"
    resetBtn.Font = Enum.Font.Gotham
    resetBtn.TextSize = 12
    resetBtn.Parent = mainFrame

    -- Обновление заполнения: сохраняем отступ (offset) и используем percentage 0..1
    local function updateFill(bar, percentage)
        percentage = math.clamp(percentage, 0, 1)
        -- ширина с учётом отступа слева/справа: оставим отступы через Position/Offset в родителе
        -- здесь мы изменяем только Scale X; offset оставляем 0 чтобы ширина пропорционально работала
        local yScale, yOffset = bar.Size.Y.Scale, bar.Size.Y.Offset
        bar.Size = UDim2.new(percentage, 0, yScale, yOffset)
    end

    local function safeSetWalkSpeed(hum, val)
        if not hum then return end
        if hum.WalkSpeed ~= nil then
            hum.WalkSpeed = val
        end
    end
    local function safeSetJump(hum, val)
        if not hum then return end
        if hum.JumpPower ~= nil then
            pcall(function() hum.JumpPower = val end)
        end
        if hum.JumpHeight ~= nil then
            pcall(function() hum.JumpHeight = val end)
        end
    end

    local function applySpeed(text)
        local val = tonumber(text)
        if val and val >= 16 and val <= 200 then
            safeSetWalkSpeed(humanoid, val)
            speedSlider.PlaceholderText = "Speed: " .. math.floor(val)
            updateFill(speedLine, (val - 16) / (200 - 16))
        else
            speedSlider.Text = ""
        end
    end

    local function applyJump(text)
        local val = tonumber(text)
        if val and val >= 50 and val <= 300 then
            safeSetJump(humanoid, val)
            jumpSlider.PlaceholderText = "Jump: " .. math.floor(val)
            updateFill(jumpLine, (val - 50) / (300 - 50))
        else
            jumpSlider.Text = ""
        end
    end

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

    resetBtn.MouseButton1Click:Connect(function()
        safeSetWalkSpeed(humanoid, defaultSpeed)
        safeSetJump(humanoid, defaultJump)
        speedSlider.Text = ""
        jumpSlider.Text = ""
        speedSlider.PlaceholderText = "Speed: 16"
        jumpSlider.PlaceholderText = "Jump: 50"
        updateFill(speedLine, 0)
        updateFill(jumpLine, 0)
    end)

    -- Toggle меню: игнорируем когда фокус в TextBox
    local isVisible = true
    uis.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if uis:GetFocusedTextBox() then return end
        if input.KeyCode == Enum.KeyCode.Delete then
            isVisible = not isVisible
            mainFrame.Visible = isVisible
        end
    end)

    -- Уведомление (попытка)
    pcall(function()
        game.StarterGui:SetCore("SendNotification", {
            Title = "GUI Loaded";
            Text = "Press DELETE to toggle menu.";
            Duration = 4;
        })
    end)
end

pcall(Init)
