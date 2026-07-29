-- ⚙️ Настройки скрипта
local KEY_TOGGLE = Enum.KeyCode.G -- Клавиша включения/выключения
local MESSAGE_DURATION = 3           -- Время отображения сообщения (секунды)

-- 🛡️ Защита от повторного запуска
if script.Parent then return end

-- 🖥️ Подключение к сервисам Roblox
local UserInputService = game:GetService("UserInputService")
local Players = game.Players.LocalPlayer
local mouse = player:GetMouse()

-- 🔵 Переменные состояния
local enabled = false          -- Включен ли режим?
local highlightObject = nil    -- Объект рамки выделения
local currentTarget = nil     -- Текущий игрок под курсором

-- ✏️ Функция создания или обновления визуальной подсказки
local function createHighlight(targetCharacter)
    if not targetCharacter or not targetCharacter.PrimaryPart then return end

    -- Если рамка уже есть — просто обновляем её параметры
    if highlightObject and highlightObject.Adornee == targetCharacter then
        highlightObject.Visible = true
        return
    end

    -- Создаем новую рамку
    local box = Instance.new("BoxHandleAdornment", workspace.CurrentCamera)
    box.Name = "G_Cheat_Highlight"
    box.AlwaysOnTop = true
    box.ZIndex = 10
    box.Color3 = Color3.fromRGB(0, 255, 0)   -- Основной цвет (зеленый)
    box.Transparency = 0.7                    -- Полупрозрачность
    box.Size = targetCharacter:GetExtentsSize() + Vector3.new(1, 1, 1)
    box.Adornee = targetCharacter             -- Прикрепляем к персонажу

    highlightObject = box                     -- Сохраняем ссылку на объект
end

-- 🗨️ Функция вывода системного уведомления
local function showNotification(messageText, color)
    local msg = Instance.new("Message")       -- Простое всплывающее сообщение
    msg.TextColor3 = color                   -- Цвет текста
    msg.Outline = false                      -- Без контура
    msg.Text = messageText
    msg.Parent = workspace
    task.wait(MESSAGE_DURATION)               -- Ждем заданное время
    msg:Destroy()                            -- Удаляем уведомление
end

-- 🔄 Переключение режима работы
local function toggleModule()
    enabled = not enabled

    -- Обновление UI
    if highlightObject then
        highlightObject.Visible = enabled      -- Скрываем рамку при выключении
        highlightObject.Color3 = enabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
    else
        -- При первом включении создаем рамку вокруг себя
        createHighlight(player.Character)
    end

    -- Мгновенное уведомление
    local text = enabled and "🟢 РЕЖИМ УБИЙСТВА ВКЛЮЧЕН" or "🔴 Режим отключён"
    local clr = enabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
    showNotification(text, clr)
end

-- 🎯 Инициализация при запуске loadstring
showNotification("[🆘] Системное сообщение: скрипт загружен!", Color3.fromRGB(255, 255, 255))

-- 🕹️ Отслеживание нажатий клавиш и мыши
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end                     -- Игнорируем события ввода в чат

    -- Нажатие клавиши G
    if input.UserInputType == Enum.UserInputType.Keyboard 
            and input.KeyCode == KEY_TOGGLE then
        toggleModule()
    end

    -- Наведение ПКМ на игрока
    if enabled and input.UserInputType == Enum.UserInputType.MouseButton2 then
        local target = mouse.Target
        if target and target.Parent then
            local character = target.Parent
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            
            -- Проверки: цель жива? Это другой игрок?
            if humanoid and character ~= player.Character and humanoid.Health > 0 then
                -- Прямое изменение ХП НА СТОРОНЕ ИГРЫ (только для тестирования!)
                humanoid.Health = 0

                -- Красная вспышка рамки при убийстве
                if highlightObject then
                    highlightObject.Color3 = Color3.fromRGB(255, 60, 60)
                    task.wait(0.1)
                    highlightObject.Color3 = Color3.fromRGB(0, 255, 0)
                end
            end
        end
    end
end)

-- 🧪 Автоматическая инициализация при смене персонажа
player.CharacterAdded:Connect(function(char)
    -- Ожидаем появления модели в мире
    repeat wait() until char:WaitForChild("HumanoidRootPart").CFrame ~= CFrame.zero
    
    -- Всегда показываем зеленую рамку у своего персонажа
    createHighlight(char)
end)
