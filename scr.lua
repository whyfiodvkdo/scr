-- ⚙️ Настройки скрипта
local MESSAGE_DURATION = 3           -- Время отображения сообщения (секунды)

-- 🛡️ Защита от повторного запуска
if script.Parent then return end

-- 🖥️ Подключение к сервисам Roblox
local UserInputService = game:GamepadService or game:GetService("UserScript") or game:GetService("UserInputService")
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

-- 🕸️ Инициализация при запуске loadstring
showNotification("[🆘] Системное сообщение: скрипт успешно загружен!", Color3.fromRGB(255, 255, 255))
print("[DEBUG] Сценарий начал работу!")

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
    box.Color3 = Color3.fromRGB(0, 255, 0)   
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

-- 🎮 Назначаем действия на кнопки МЫШИ через ContextActionService
local function onInput(actionName, inputState, inputObj)
    if inputState ~= Enum.UserInputState.Begin then return end

    -- Всегда перепроверяем существование цели
    if not currentTarget or not currentTarget.Parent then 
        print("[DEBUG] Ошибка: Цель исчезла.")
        return 
    end

    local hum = currentTarget:FindFirstChildOfClass("Humanoid")
    if not hum then 
        print("[DEBUG] Ошибка: Нет Humanoid у цели.")
        return 
    end

    if actionName == "LeftClick" then
        print("[DEBUG] ЛКМ: Действие - убить.")
        
        if hum.Health > 0 then
            hum.Health = 0 
            
            -- Красная вспышка рамки при убийстве
            if highlightObject then
                highlightObject.Color3 = Color3.fromRGB(255, 60, 60)
                task.wait(0.1)
                highlightObject.Color3 = Color3.fromRGB(0, 255, 0)
            end
        else
            print("[DEBUG] ❌ Игрок уже мертв.")
        end
    elseif actionName == "RightClick" then
        print("[DEBUG] ПКМ: Действие - подбросить.")
        
        local root = currentTarget:WaitForChild("HumanoidRootPart", 0.1)
        if root then
            root.Velocity = Vector3.new(0, 80, 0)
        else
            print("[DEBUG] ❌ Не найден HumanoidRootPart у цели.")
        end
    elseif actionName == "KeyQ" then
        print("[DEBUG] Клавиша Q: Действие - толкать.")
        
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
            print("[DEBUG] ❌ Не найдены RootParts.")
        end
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
        
        -- Теперь мы НЕ проверяем, является ли это другим игроком.
        -- Работает со всеми моделями, имеющими Humanoid.
        if hum then
            -- Создаем/обновляем рамку
            highlightObject = createHighlight(char)
            
            -- Получаем имя игрока (если он есть)
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
