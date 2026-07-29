-- ⚙️ Настройки скрипта
local MESSAGE_DURATION = 4           -- Время отображения сообщения (секунды)

-- 🛡️ Защита от повторного запуска
if script.Parent then return end

-- 🖥️ Подключение к сервисам Roblox
local UserInputService = game:GamepadService or game:GetService("UserScript") or game:GetService("UserInputService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- ✏️ Функция вывода системного уведомления
local function showNotification(messageText, color)
    local msg = Instance.new("Message")       -- Текстовый объект
    msg.TextColor3 = color                   -- Цвет текста
    msg.Outline = false                      -- Без контура
    msg.Text = messageText
    msg.Parent = workspace
    task.wait(MESSAGE_DURATION)               -- Ждем заданное время
    msg:Destroy()                            -- Удаляем уведомление
end

-- 🔧 Отладочные функции
local function debugLog(msg)
    print("[DEBUG] " .. msg)
end

local function isValidTarget(character)
    if not character then 
        debugLog("❌ Ошибка: Нет цели под курсором.")
        return false
    end

    local hum = character:FindFirstChildOfClass("Humanoid")
    if not hum then 
        debugLog("❌ Ошибка: Цель — не живой персонаж.")
        return false
    end

    if hum.Health <= 0 then 
        debugLog("❌ Ошибка: Персонаж уже мертв.")
        return false
    end

    if character == player.Character then 
        debugLog("❌ Ошибка: Нельзя действовать против самого себя.")
        return false
    end

    return true
end

-- 🕸️ Инициализация при запуске loadstring
showNotification("[🆘] Системное сообщение: скрипт успешно загружен!", Color3.fromRGB(255, 255, 255))
debugLog("Сценарий начал работу!")

-- 🔹 Переменные состояния
local currentTarget = nil     -- Текущий игрок под курсором
local highlightObject = nil   -- Объект рамки выделения

-- ✏️ Создание/обновление визуальной подсказки
local function createHighlight(targetCharacter)
    if not targetCharacter or not targetCharacter.PrimaryPart then return nil end

    local box = Instance.new("BoxHandleAdornment", workspace.CurrentCamera)
    box.Name = "G_Cheat_Highlight"
    box.AlwaysOnTop = true
    box.ZIndex = 10
    box.Color3 = Color3.fromRGB(0, 255, 0)   -- Основной цвет рамки (зеленый)
    box.Transparency = 0.7                    -- Полупрозрачность
    box.Size = targetCharacter:GetExtentsSize() + Vector3.new(1, 1, 1)
    box.Adornee = targetCharacter             -- Прикрепляем рамку к персонажу

    return box
end

-- 🗨️ Вывод имени игрока рядом с ним
local function showNameTag(character, nameText)
    if not character then return nil end

    local tag = Instance.new("Hint")       
    tag.TextColor3 = Color3.fromRGB(255, 255, 255)
    tag.Outline = false                   
    tag.Text = "[🆘] " .. nameText
    tag.Parent = character                -- Привязываем его к игроку
    task.wait(MESSAGE_DURATION)               
    tag:Destroy()                            

    return tag
end

-- 🎮 Назначаем действия на кнопки МЫШИ через ContextActionService
local function onInput(actionName, inputState, inputObj)
    if inputState ~= Enum.UserInputState.Begin then return end

    if actionName == "LeftClick" and currentTarget then
        debugLog("ЛКМ: Проверка цели...")
        
        if not isValidTarget(currentTarget) then return end

        -- Действие ЛКМ: убить
        debugLog("✅ Действие: Убить")
        currentTarget.Humanoid.Health = 0 

        -- Красная вспышка рамки при убийстве
        if highlightObject then
            highlightObject.Color3 = Color3.fromRGB(255, 60, 60)
            task.wait(0.1)
            highlightObject.Color3 = Color3.fromRGB(0, 255, 0)
        end
    elseif actionName == "RightClick" and currentTarget then
        debugLog("ПКМ: Проверка цели...")
        
        if not isValidTarget(currentTarget) then return end

        -- Действие ПКМ: подбросить вверх
        debugLog("✅ Действие: Подбросить")
        local root = currentTarget:WaitForChild("HumanoidRootPart")
        if root then
            root.Velocity = Vector3.new(0, 80, 0)
        else
            debugLog("❌ Ошибка: Не найден HumanoidRootPart у цели.")
        end
    elseif actionName == "KeyQ" and currentTarget then
        debugLog("Q: Проверка цели...")
        
        if not isValidTarget(currentTarget) then return end

        -- Действие Q: оттолкнуть от себя
        debugLog("✅ Действие: Толкать")
        local myPos = player.Character:FindFirstChild("HumanoidRootPart").Position
        local theirPos = currentTarget:FindFirstChild("HumanoidRootPart").Position
        local direction = (myPos - theirPos).Unit * 40

        local bv = Instance.new("BodyVelocity", currentTarget:FindFirstChild("UpperTorso"))
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.P = 12000
        bv.Velocity = direction
        wait(0.2)
        bv:Destroy()
    end
end

-- 🔵 Регистрация действий в ContextActionService
local ContextActionService = game:GetService("ContextActionService")
ContextActionService:BindAction("LeftClick", onInput, false, Enum.UserInputType.MouseButton1)
ContextActionService:BindAction("RightClick", onInput, false, Enum.UserInputType.MouseButton2)
ContextActionService:BindAction("KeyQ", onInput, false, Enum.KeyCode.Q)

-- 🕸️ Отслеживание мыши для выбора цели
mouse.TargetChanged:Connect(function(newTarget)
    if newTarget and newTarget.Parent then
        local char = newTarget.Parent
        local hum = char:FindFirstChildOfClass("Humanoid")
        
        -- Проверки: это живой игрок? Не я ли это?
        if hum and char ~= player.Character and hum.Health > 0 then
            -- Создаем/обновляем рамку
            highlightObject = createHighlight(char)
            
            -- Получаем имя игрока
            local plr = Players:GetPlayerFromCharacter(char)
            if plr then
                -- Выводим ник над головой
                showNameTag(char.HumanoidRootPart, plr.Name)
            else
                showNameTag(char.HumanoidRootPart, char.Name)
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
