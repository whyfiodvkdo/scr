-- ⚙️ Настройки скрипта
local MESSAGE_DURATION = 3           -- Время отображения сообщения (секунды)

-- 🛡️ Защита от повторного запуска
if script.Parent then return end

-- 🖥️ Подключение к сервисам Roblox
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- ✏️ Функция вывода системного уведомления
local function showNotification(messageText, color)
    local msg = Instance.new("Message")       
    msg.TextColor3 = color                   
    msg.Outline = false                      
    msg.Text = messageText
    msg.Parent = workspace
    task.wait(MESSAGE_DURATION)               
    msg:Destroy()                            
end

-- 🔧 Отладочные функции
local function debugLog(msg)
    print("[DEBUG] " .. msg)
end

-- 🟢 Переменная состояния
local enabled = true -- Включено сразу после загрузки

-- ✏️ Создание/обновление визуальной подсказки
local function createHighlight(targetCharacter)
    if not targetCharacter or not targetCharacter.PrimaryPart then return nil end

    local box = Instance.new("BoxHandleAdornment", workspace.CurrentCamera)
    box.Name = "G_Cheat_Highlight"
    box.AlwaysOnTop = true
    box.ZIndex = 10
    box.Color3 = Color3.fromRGB(0, 255, 0)   -- Основной цвет рамки (зеленый)
    box.Transparency = 0.7                    
    box.Size = targetCharacter:GetExtentsSize() + Vector3.new(1, 1, 1)
    box.Adornee = targetCharacter             
    
    return box
end

-- 🗨️ Вывод имени игрока рядом с ним
local function showNameTag(character, nameText)
    if not character then return nil end

    local tag = Instance.new("Hint")       
    tag.TextColor3 = Color3.fromRGB(255, 255, 255)
    tag.Outline = false                   
    tag.Text = "[🆘] " .. nameText
    tag.Parent = character                
    task.wait(MESSAGE_DURATION)           
    tag:Destroy()                        

    return tag
end

-- 🕸️ Переключение режима работы
local function toggleModule()
    enabled = not enabled

    local clr = enabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 69, 69)
    showNotification(
        ("[🆘] %s"):format(enabled and "🟢 РЕЖИМ ВКЛЮЧЕН" or "🔴 РЕЖИМ ОТКЛЮЧЕН"),
        clr
    )

    if highlightObject then
        highlightObject.Visible = enabled
    end
end

-- 🔹 Переменные состояния
local currentTarget = nil     -- Текущий игрок под курсором
local highlightObject = nil   -- Объект рамки выделения

-- 🎮 Назначаем действия на кнопки МЫШИ через ContextActionService
local function onInput(actionName, inputState, inputObj)
    if inputState ~= Enum.UserInputState.Begin then return end

    if actionName == "LeftClick" then
        if not enabled then return end

        if not currentTarget or not currentTarget.Parent then 
            debugLog("❌ Нет цели.")
            return 
        end

        local hum = currentTarget:FindFirstChildOfClass("Humanoid")
        if not hum then 
            debugLog("❌ Цель — не живой персонаж.")
            return 
        end

        if hum.Health > 0 then
            hum.Health = 0 
            
            -- Красная вспышка рамки при убийстве
            if highlightObject then
                highlightObject.Color3 = Color3.fromRGB(255, 60, 60)
                task.wait(0.1)
                highlightObject.Color3 = Color3.fromRGB(0, 255, 0)
            end
        else
            debugLog("❌ Игрок уже мертв.")
        end
    elseif actionName == "RightClick" then
        if not enabled then return end

        if not currentTarget or not currentTarget.Parent then 
            debugLog("❌ Нет цели.")
            return 
        end

        local root = currentTarget:WaitForChild("HumanoidRootPart", 0.1)
        if root then
            root.Velocity = Vector3.new(0, 80, 0)
        else
            debugLog("❌ Не найден HumanoidRootPart у цели.")
        end
    elseif actionName == "KeyQ" then
        if not enabled then return end

        if not currentTarget or not currentTarget.Parent then 
            debugLog("❌ Нет цели.")
            return 
        end

        local myPos = player.Character:FindFirstChild("HumanoidRootPart").Position
        local theirPos = currentTarget:FindFirstChild("HumanoidRootPart").Position
        if myPos and theirPos then
            local direction = (myPos - theirPos).Unit * 40

            local bv = Instance.new("BodyVelocity", currentTarget:FindFirstChild("UpperTorso"))
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.P = 12000
            bv.Velocity = direction
            wait(0.2)
            bv:Destroy()
        else
            debugLog("❌ Не найдены RootParts.")
        end
    end
end

-- 🔄 Регистрация действий в ContextActionService
local ContextActionService = game:GetService("ContextActionService")
ContextActionService:BindAction("LeftClick", onInput, false, Enum.UserInputType.MouseButton1)
ContextActionService:BindAction("RightClick", onInput, false, Enum.UserInputType.MouseButton2)
ContextActionService:BindAction("KeyQ", onInput, false, Enum.KeyCode.Q)

-- 👉 Команда чата для включения/выключения
player.Chatted:Connect(function(msg)
    if string.lower(msg) == "/toggle" then
        toggleModule()
    end
end)

-- 🕸️ Отслеживание мыши для выбора цели
mouse.TargetChanged:Connect(function(newTarget)
    if newTarget and newTarget.Parent then
        local char = newTarget.Parent
        local hum = char:FindFirstChildOfClass("Humanoid")
        
        -- Проверяем только наличие Humanoid
        if hum then
            -- Создаем/обновляем рамку
            highlightObject = createHighlight(char)
            highlightObject.Visible = enabled

            -- Получаем имя игрока
            local plr = Players:GetPlayerFromCharacter(char)
            if plr then
                showNameTag(char.HumanoidRootPart, plr.Name)
            else
                showNameTag(char.HumanoidRootPart, "<Не игрок>")
            end

            -- Запоминаем текущую цель
            currentTarget = char
        elseif highlightObject then
            -- Убираем старую рамку, если цель потеряна
            highlightObject:Destroy()
            highlightObject = nil
            currentTarget = nil
        end
    elseif highlightObject then
        -- Убираем старую рамку, если мы смотрим в пустоту
        highlightObject:Destroy()
        highlightObject = nil
        currentTarget = nil
    end
end)
