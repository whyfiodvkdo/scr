-- ⚙️ Настройки скрипта
local MESSAGE_DURATION = 3           -- Время отображения сообщения (секунды)

-- 🛡️ Защита от повторного запуска
if script.Parent then return end

-- 🖥️ Подключение к сервисам Roblox
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- ✏️ Функция создания или обновления визуальной подсказки
local function createHighlight(targetCharacter)
    if not targetCharacter or not targetCharacter.PrimaryPart then return end

    local box = Instance.new("BoxHandleAdornment", workspace.CurrentCamera)
    box.Name = "G_Cheat_Highlight"
    box.AlwaysOnTop = true
    box.ZIndex = 10
    box.Color3 = Color3.fromRGB(0, 255, 0)   -- Основной цвет (зеленый)
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

-- 🕹️ Отслеживание мыши в реальном времени
while wait(0.05) do
    local target = mouse.Target
    if target and target.Parent then
        local char = target.Parent
        local hum = char:FindFirstChildOfClass("Humanoid")
        
        -- Проверки: это живой игрок? Не я ли это?
        if hum and char ~= player.Character and hum.Health > 0 then
            -- Создаем/обновляем рамку
            local highlight = createHighlight(char)
            
            -- Получаем имя игрока
            local plr = Players:GetPlayerFromCharacter(char)
            if plr then
                -- Выводим ник над головой
                showNameTag(char.HumanoidRootPart, plr.Name)
            else
                -- Если не удалось получить игрока из системы, просто выводим название модели
                showNameTag(char.HumanoidRootPart, char.Name)
            end
        elseif highlight then
            -- Убираем старую рамку, если цель потеряна
            highlight:Destroy()
            highlight = nil
        end
    elseif highlight then
        -- Убираем старую рамку, если мы смотрим в пустоту
        highlight:Destroy()
        highlight = nil
    end
end
