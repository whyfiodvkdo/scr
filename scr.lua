-- ⚙️ Настройки скрипта
local MOVEMENT_SPEED = 15      -- Скорость движения бота
local MESSAGE_DURATION = 3     -- Время отображения сообщений (секунды)

-- 🛡️ Защита от повторного запуска
if script.Parent then return end

-- 🖥️ Подключение к сервисам Roblox
local UserInputService = game.GamepadService or game.UserScript or game.GetService("UserInputService")
local Players = game.Players
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

-- 🕸️ Создание визуальной подсказки (рамки вокруг игроков)
local function createHighlight(targetCharacter)
    if not targetCharacter or not targetCharacter.PrimaryPart then return nil end

    local box = Instance.new("BoxHandleAdornment", workspace.CurrentCamera)
    box.Name = "Bot_Highlight"
    box.AlwaysOnTop = true
    box.ZIndex = 10
    box.Color3 = Color3.fromRGB(0, 255, 0)   
    box.Transparency = 0.7                    
    box.Size = targetCharacter:GetExtentsSize() + Vector3.new(1, 1, 1)
    box.Adornee = targetCharacter             
    
    return box
end

-- 🗨️ Вывод информации о других игроках
local function trackPlayers()
    while wait(1) do
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= player and plr.Character then
                local char = plr.Character
                local hum = char:FindFirstChildOfClass("Humanoid")
                
                if hum and hum.Health > 0 then
                    -- Создаем/обновляем рамку
                    createHighlight(char)
                    
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
    end
end

-- 👟 Управление персонажем
local function moveCharacter()
    -- Получаем контроллер передвижения
    local controller = player.Character:WaitForChild("Humanoid"):GetStateController(Enum.HumanoidStateType.Walking)

    -- Ходим прямо вперед
    -- controller:MoveTo(Vector3.new(player.Character.HumanoidRootPart.CFrame.LookVector * MOVEMENT_SPEED))

    -- Или следуем за мышью (более интересный вариант):
    repeat wait() until mouse.Target and mouse.Target.Parent
    while wait() do
        local target = mouse.Target
        if target and target.Parent then
            local char = target.Parent
            local hum = char:FindFirstChildOfClass("Humanoid")
            
            -- Если это живой игрок, идём к нему
            if hum and hum.Health > 0 then
                controller:MoveTo(mouse.Hit.p)
            elseif mouse.Target.CanCollide then
                -- Иначе идем просто к точке под курсором
                controller:MoveTo(mouse.Hit.p)
            end
        end
    end
end

-- 🎮 Назначаем реакцию на кнопки
UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.E then
        -- Прыжок по нажатию E
        player.Character.Humanoid.Jump = true
        
        -- Пример другого действия: подбросить себя вверх
        -- player.Character.HumanoidRootPart.Velocity = Vector3.new(0, 80, 0)
    end
end)

-- 💡 Инициализация при первом запуске loadstring
showNotification("[🆘] Системное сообщение: Автономный режим активен!", Color3.fromRGB(255, 255, 255))
debugLog("Сценарий начал работу!")

trackPlayers()   -- Запускаем отслеживание игроков
moveCharacter()  -- Запускаем управление персонажем
