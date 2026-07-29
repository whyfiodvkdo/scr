-- ⚙️ Настройки скрипта
local MESSAGE_DURATION = 3           -- Время отображения сообщения (секунды)

-- 🛡️ Защита от повторного запуска
if script.Parent then return end

-- 🖥️ Подключение к сервисам Roblox
local UserInputService = game:GetService("UserInputService")
local Players = game.Players.LocalPlayer
local mouse = player:GetMouse()

-- ✏️ Функция создания или обновления визуальной подсказки
local function createHighlight(targetCharacter)
    if not targetCharacter or not targetCharacter.PrimaryPart then return nil end

    local box = Instance.new("BoxHandleAdornment", workspace.CurrentCamera)
    box.Name = "G_Cheat_Highlight"
    box.AlwaysOnTop = true
    box.ZIndex = 10
    box.Color3 = Color3.fromRGB(255, 255, 0)   -- Жёлтый цвет рамки при выборе
    box.Transparency = 0.7                    -- Полупрозрачность
    box.Size = targetCharacter:GetExtentsSize() + Vector3.new(1, 1, 1)
    box.Adornee = targetCharacter             -- Прикрепляем к персонажу
    
    return box
end

-- 🗨️ Функция вывода системного уведомления рядом с игроком
local function showNameTag(character, nameText)
    if not character then return nil end

    local tag = Instance.new("Hint")       -- Текстовый объект
    tag.TextColor3 = Color3.fromRGB(255, 255, 255)
    tag.Outline = false                   -- Без контура
    tag.Text = "[🆘] " .. nameText
    tag.Parent = character                -- Привязываем к игроку
    task.wait(MESSAGE_DURATION)               -- Ждем заданное время
    tag:Destroy()                            -- Удаляем уведомление
    
    return tag
end

-- 🔹 Переменные состояния
local currentTarget = nil     -- Текущий игрок под курсором
local highlightObject = nil   -- Объект рамки выделения

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
                -- Если не удалось получить игрока из системы, просто выводим название модели
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

-- 🎮 Назначаем действия на кнопки
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end                     -- Игнорируем события ввода в чат

    -- Нажатие F: Мгновенная смерть
    if input.KeyCode == Enum.KeyCode.F then
        if currentTarget then
            local humanoid = currentTarget:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
                humanoid.Health = 0 
                
                -- Красная вспышка рамки при убийстве
                if highlightObject then
                    highlightObject.Color3 = Color3.fromRGB(255, 60, 60)
                    task.wait(0.1)
                    highlightObject.Color3 = Color3.fromRGB(255, 255, 0)
                end
            end
        end
    end

    -- Нажатие E: Подбросить вверх
    if input.KeyCode == Enum.KeyCode.E then
        if currentTarget then
            local root = currentTarget:WaitForChild("HumanoidRootPart")
            if root then
                root.Velocity = Vector3.new(0, 80, 0) -- Подбрасывает вверх
            end
        end
    end

    -- Нажатие Q: Оттолкнуть от себя
    if input.KeyCode == Enum.KeyCode.Q then
        if currentTarget then
            local myPos = player.Character:WaitForChild("HumanoidRootPart").Position
            local theirPos = currentTarget:WaitForChild("HumanoidRootPart").Position
            local direction = (myPos - theirPos).Unit * 40 -- Направление от них к нам

            local bv = Instance.new("BodyVelocity", currentTarget:WaitForChild("UpperTorso"))
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.P = 12000
            bv.Velocity = direction
            wait(0.2)
            bv:Destroy()
        end
    end
end)
