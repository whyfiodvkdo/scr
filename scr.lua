-- ⚙️ Настройки скрипта
local MESSAGE_DURATION = 3     -- Время отображения сообщений (секунды)
local MOVEMENT_SPEED = 16      -- Базовая скорость движения
local ATTACK_RANGE = 8        -- Радиус ближнего боя
local AVOIDANCE_DISTANCE = 4   -- Минимальное расстояние до стен

-- 🛡️ Защита от повторного запуска
if script.Parent then return end

-- 🖥️ Подключение к сервисам Roblox
local UserInputService = game.GamepadService or game.UserScript or game.GetService("UserInputService")
local Players = game.Players
local player = Players.LocalPlayer

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

-- 🕸️ Создание визуальной подсказки (рамки вокруг игроков)
local function createHighlight(targetCharacter, color)
    if not targetCharacter or not targetCharacter.PrimaryPart then return nil end

    local box = Instance.new("BoxHandleAdornment", workspace.CurrentCamera)
    box.Name = "Bot_Highlight"
    box.AlwaysOnTop = true
    box.ZIndex = 10
    box.Color3 = color   
    box.Transparency = 0.7                    
    box.Size = targetCharacter:GetExtentsSize() + Vector3.new(1, 1, 1)
    box.Adornee = targetCharacter             
    
    return box
end

-- 🗨️ Сбор информации о мире
local function trackWorld(mouse)
    while wait(1) do
        -- Анализируем игроков
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= player and plr.Character then
                local char = plr.Character
                local hum = char:FindFirstChildOfClass("Humanoid")
                
                if hum and hum.Health > 0 then
                    -- Создаем/обновляем рамку
                    local clr = Color3.fromRGB(0, 255, 0)
                    if hum.Health < 50 then
                        clr = Color3.fromRGB(255, 255, 0) -- Жёлтый цвет для раненых
                    elseif hum.Health == 100 then
                        clr = Color3.fromRGB(255, 0, 0) -- Красный цвет для самых опасных
                    end
                    createHighlight(char, clr)
                    
                    -- Логируем данные
                    local rootPos = char.HumanoidRootPart.Position
                    debugLog(string.format(
                        "%s | Health: %d | Position: %.1f, %.1f, %.1f",
                        plr.Name,
                        hum.Health,
                        rootPos.X, rootPos.Y, rootPos.Z
                    ))
                else
                    -- Убираем старую рамку, если игрок умер
                    for _, obj in pairs(workspace.CurrentCamera:GetChildren()) do
                        if obj.Name == "Bot_Highlight" and obj.Adornee == char then
                            obj:Destroy()
                        end
                    end
                end
            end
        end

        -- Пример памяти: поиск аптечек (добавь их в свою карту как Part с названием Heal)
        for _, part in ipairs(workspace:GetDescendants()) do
            if part.Name == "Heal" and part.CanCollide then
                -- Запоминаем позицию аптечки
                debugLog(string.format("Найдена аптечка: %.1f, %.1f, %.1f", 
                                      part.Position.X, part.Position.Y, part.Position.Z))
                -- Здесь можно добавить логику поиска пути к ней при низком HP
            end
        end
    end
end

-- 👟 Управление персонажем (ИИ)
local function moveAI(controller, mouse)
    -- Основной цикл принятия решений
    while wait(0.1) do
        -- Шаг 1: Избегание столкновений со стенами
        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Exclude
        raycastParams.FilterDescendantsInstances = {player.Character}
        
        local result = workspace:Raycast(player.Character.HumanoidRootPart.Position, 
                                        player.Character.HumanoidRootPart.CFrame.LookVector * AVOIDANCE_DISTANCE, 
                                        raycastParams)
        
        if result and result.Instance.CanCollide then
            -- Стена впереди, идём вправо
            controller.MoveTo(Vector3.new(result.Normal.X, 0, -result.Normal.Z).Unit * MOVEMENT_SPEED)
        else
            -- Шаг 2: Выбор цели
            local bestTarget = nil
            local closestDistance = math.huge

            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= player and plr.Character then
                    local char = plr.Character
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    
                    if hum and hum.Health > 0 then
                        local dist = (char.HumanoidRootPart.Position - player.Character.HumanoidRootPart.Position).Magnitude
                        
                        -- Приоритет: атаковать слабых или тех, кто ближе всего
                        if hum.Health <= 50 or dist < closestDistance then
                            bestTarget = char
                            closestDistance = dist
                        end
                    end
                end
            end

            -- Принятие решения
            if bestTarget then
                if closestDistance <= ATTACK_RANGE then
                    -- Мы в зоне атаки, останавливаемся
                    controller.MoveTo(player.Character.HumanoidRootPart.Position)
                    -- Здесь можно добавить анимацию удара
                else
                    -- Идём к цели
                    controller.MoveTo(bestTarget.HumanoidRootPart.Position)
                end
            else
                -- Если целей нет, идём вперёд
                controller.MoveTo(player.Character.HumanoidRootPart.CFrame.LookVector * MOVEMENT_SPEED)
            end
        end
    end
end

-- 💡 Инициализация при первом запуске loadstring
showNotification("[🆘] Системное сообщение: Автономный режим активен!", Color3.fromRGB(255, 255, 255))
debugLog("Сценарий начал работу!")

-- 🔄 Ожидание появления Character перед началом работы
repeat wait() until player.Character

-- Получение контроллера передвижения
local humanoid = player.Character:WaitForChild("Humanoid", 5)
if not humanoid then 
    error("[ERROR]: Персонаж не появился за отведённое время!")
end

local controller = humanoid:GetStateController(Enum.HumanoidStateType.Walking)
if not controller then 
    warn("[DEBUG] Не удалось найти StateController! Бот будет двигаться напрямую.")
    
    -- Резервный метод управления движением (на случай старых версий движка)
    controller = {
        MoveTo = function(pos)
            humanoid.MoveTo(humanoid, pos)
        end
    }
else
    debugLog("Контроллер движения найден.")
end

-- Теперь, когда Character точно существует, получаем мышь
local mouse = player:GetMouse()

trackWorld(mouse)   -- Запускаем отслеживание мира
moveAI(controller, mouse)       -- Запускаем искусственный интеллект
