-- Настройки скрипта
local MESSAGE_DURATION = 3 -- Время отображения сообщения (секунды)

-- Защита от повторного запуска
if script.Parent then return end

-- Подключение к сервисам Roblox
local UserInputService = game.GamepadService or game.UserScript or game.GetService("UserInputService")
local ContextActionService = game.ContextActionService
local Players = game.Players
local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Функция создания визуальной подсказки
local function createHighlight(targetCharacter)
    if not targetCharacter or not targetCharacter.PrimaryPart then return nil end

    local box = Instance.new("BoxHandleAdornment", workspace.CurrentCamera)
    box.Name = "G_Cheat_Highlight"
    box.AlwaysOnTop = true
    box.ZIndex = 10
    box.Color3 = Color3.fromRGB(0, 255, 0)   -- Основной цвет рамки
    box.Transparency = 0.7                    -- Полупрозрачность
    box.Size = targetCharacter:GetExtentsSize() + Vector3.new(1, 1, 1)
    box.Adornee = targetCharacter             -- Прикрепляем рамку к персонажу

    return box
end

-- Вывод имени игрока рядом с ним
local function showNameTag(character, nameText)
    if not character then return nil end

    local tag = Instance.new("Hint")       
    tag.TextColor3 = Color3.fromRGB(255, 255, 255)
    tag.Outline = false                   
    tag.Text = "[DEBUG] " .. nameText
    tag.Parent = character                
    task.wait(MESSAGE_DURATION)           
    tag:Destroy()                        
end

-- Переменные состояния
local currentTarget = nil     -- Текущий игрок под курсором
local highlightObject = nil   -- Объект рамки выделения

-- Переключение режима работы
local function toggleModule()
    local enabled = _G.GCHActions == nil and true or not _G.GCHActions

    game.StarterGui:SetCore(
        "SendNotification",
        {
            Title="[DEBUG] Actions"; 
            Text=enabled and "Режим действий ВКЛЮЧЕН" or "Режим действий ОТКЛЮЧЁН";
            Icon="rbxassetid://9114319780"; Duration=3;
        }
    )

    _G.GCHActions = enabled

    if highlightObject then
        highlightObject.Visible = enabled
    end
end

-- Назначаем действия на кнопки МЫШИ через ContextActionService
local function onInput(actionName, inputState, inputObj)
    if inputState ~= Enum.UserInputState.Begin then return end

    -- Проверка флага _G (если скрипт уже был запущен ранее)
    if not (_G.GCHActions == nil or _G.GCHActions) then return end

    if actionName == "LeftClick" then
        if not currentTarget or not currentTarget.HumanoidRootPart then return end
        
        local root = currentTarget.HumanoidRootPart
        root.Velocity = Vector3.new(0, 80, 0) -- Подбрасывает вверх
    elseif actionName == "RightClick" then
        if not currentTarget or not currentTarget.Humanoid then return end
        
        local hum = currentTarget.Humanoid
        if hum.Health > 0 then
            hum.Health = 0 
            
            -- Красная вспышка рамки при убийстве
            if highlightObject then
                highlightObject.Color3 = Color3.fromRGB(255, 60, 60)
                task.wait(0.1)
                highlightObject.Color3 = Color3.fromRGB(0, 255, 0)
            end
        else
            game.StarterGui:SetCore(
                "SendNotification",
                {Title="[DEBUG] Actions"; Text="Игрок уже мертв."; Duration=3;}
            )
        end
    elseif actionName == "KeyQ" then
        if not currentTarget or not currentTarget.HumanoidRootPart then return end
        
        local myPos = player.Character.HumanoidRootPart.Position
        local theirPos = currentTarget.HumanoidRootPart.Position
        if myPos and theirPos then
            local direction = (myPos - theirPos).Unit * 40

            local bv = Instance.new("BodyVelocity", currentTarget.UpperTorso)
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.P = 12000
            bv.Velocity = direction
            wait(0.2)
            bv:Destroy()
        end
    end
end

-- Регистрация действий в ContextActionService
ContextActionService:BindAction("LeftClick", onInput, false, Enum.UserInputType.MouseButton1)
ContextActionService:BindAction("RightClick", onInput, false, Enum.UserInputType.MouseButton2)
ContextActionService:BindAction("KeyQ", onInput, false, Enum.KeyCode.Q)

-- Отслеживание мыши для выбора цели
mouse.TargetChanged:Connect(function(newTarget)
    if newTarget and newTarget.Parent then
        local char = newTarget.Parent
        local hum = char:FindFirstChildOfClass("Humanoid")
        
        -- Работает со всеми моделями, имеющими Humanoid
        if hum then
            highlightObject = createHighlight(char)
            currentTarget = char

            -- Получаем имя игрока (или название модели)
            local plr = Players:GetPlayerFromCharacter(char)
            if plr then
                showNameTag(char.HumanoidRootPart, plr.Name)
            else
                showNameTag(char.HumanoidRootPart, "<Не игрок>")
            end
        elseif highlightObject then
            highlightObject:Destroy()
            highlightObject = nil
            currentTarget = nil
        end
    elseif highlightObject then
        highlightObject:Destroy()
        highlightObject = nil
        currentTarget = nil
    end
end)

-- Инициализация при первом запуске loadstring
if _G.GCHActions == nil then
	_G.GCHActions = true -- Включено по умолчанию

	game.StarterGui:SetCore(
		"SendNotification",
		{
			Title="[DEBUG] Actions"; 
			Text="Скрипт успешно загружен!";
			Icon="rbxassetid://9114319780"; Duration=3;
		}
	)
else
	toggleModule() -- Повторный вызов меняет состояние
end
