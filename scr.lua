-- ⚙️ Настройки скрипта
local KEY_TOGGLE = Enum.KeyCode.F -- Клавиша открытия/закрытия
local MIN_SPEED = 16              -- Минимальная скорость
local MAX_SPEED = 200             -- Максимальная скорость

-- 🛡️ Защита от повторного запуска
if script.Parent then return end

-- 🖥️ Подключение к сервисам Roblox
local UserInputService = game:GetService("UserInputService")
local Players = game.Players
local player = Players.LocalPlayer

-- ✏️ Создание интерфейса
local function createUI()
    local ui = Instance.new("ScreenGui", player.PlayerGui)
    ui.Name = "SpeedGUI"
    
    -- Основная панель
    local frame = Instance.new("Frame", ui)
    frame.Size = UDim2.fromScale(0.3, 0.4)
    frame.Position = UDim2.fromScale(0.5, 0.5) - UDim2.fromScale(frame.Size.X.Scale / 2, frame.Size.Y.Scale / 2)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel = 0

    -- Заголовок
    local title = Instance.new("TextLabel", frame)
    title.Text = "Скорость передвижения"
    title.FontFace = Font.new("rbxasset://fonts/faces/Font.ttf", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.BackgroundTransparency = 1
    title.Size = UDim2.fromScale(1, 0.2)
    title.Position = UDim2.fromScale(0, 0)

    -- Текущее значение
    local valueLabel = Instance.new("TextLabel", frame)
    valueLabel.Text = ""
    valueLabel.FontFace = Font.new("rbxasset://fonts/faces/Font.ttf", Enum.FontWeight.Medium, Enum.FontStyle.Normal)
    valueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Size = UDim2.fromScale(1, 0.1)
    valueLabel.Position = UDim2.fromScale(0, 0.2)

    -- Ползунок
    local sliderBar = Instance.new("Frame", frame)
    sliderBar.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    sliderBar.Size = UDim2.fromScale(0.9, 0.05)
    sliderBar.Position = UDim2.fromScale(0.05, 0.35)

    local thumb = Instance.new("Frame", sliderBar)
    thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    thumb.Size = UDim2.fromScale(0.1, 1)
    thumb.Position = UDim2.fromScale(0, 0)

    -- 🔧 Логика ползунка
    local dragStartX = nil
    local startThumbPos = nil

    local function updateValue(xPosition)
        local percent = math.clamp((xPosition - sliderBar.AbsolutePosition.X) / sliderBar.AbsoluteSize.X, 0, 1)
        
        local newSpeed = MIN_SPEED + (MAX_SPEED - MIN_SPEED) * percent
        player.Character.Humanoid.WalkSpeed = newSpeed
        
        thumb.Position = UDim2.fromScale(percent, 0)
        valueLabel.Text = string.format("Текущая скорость: %.0f", newSpeed)
    end

    -- Обработка перетаскивания
    local function onDrag(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or 
           input.UserInputType == Enum.UserInputType.Touch then
            local x = input.Position.X
            
            if not dragStartX then
                dragStartX = x
                startThumbPos = thumb.Position.X.Offset
            else
                local delta = x - dragStartX
                local newX = startThumbPos + delta / sliderBar.AbsoluteSize.X
                
                updateValue(sliderBar.AbsolutePosition.X + sliderBar.AbsoluteSize.X * newX)
            end
        end
    end

    thumb.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            dragStartX = nil
            startThumbPos = nil
            
            UserInputService.InputChanged:Connect(onDrag)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            UserInputService.InputChanged:Disconnect(onDrag)
        end
    end)

    -- Возвращаем объект UI для управления видимостью
    return {
        Gui = ui,
        SetVisible = function(visible)
            ui.Enabled = visible
        end
    }
end

-- 🕸️ Управление окном через клавиатуру
local uiInstance = createUI()
uiInstance.SetVisible(false)

UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Keyboard and
       input.KeyCode == KEY_TOGGLE then
        uiInstance.SetVisible(not uiInstance.Gui.Enabled)
    end
end)

