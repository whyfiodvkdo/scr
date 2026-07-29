-- ================== КЛИЕНТСКИЙ КОД ДЛЯ ИНЖЕКТОРА ==================
local UserInputService = game:GetService("UserInputService")
local player = game.Players.LocalPlayer
local mouse = player:GetMouse()

local enabled = false -- Флаг состояния
local highlight = nil  -- Объект рамки выделения

-- Функция создания/обновления рамки
local function createHighlight(targetChar)
    if not targetChar then return end

    -- Если рамка уже есть, просто меняем её свойства
    if highlight then 
        highlight.Adornee = targetChar or workspace.CurrentCamera
        return
    end

    -- Создаем новую рамку
    highlight = Instance.new("BoxHandleAdornment")
    highlight.Name = "G_Cheat_Highlight"
    highlight.AlwaysOnTop = true
    highlight.ZIndex = 1
    highlight.Parent = workspace.CurrentCamera
end

-- Переключение режима работы
local function toggleModule()
    enabled = not enabled

    local msgColor = enabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
    
    -- Мгновенные уведомления через Hint (работают быстрее Message)
    local hint = Instance.new("Hint") 
    hint.TextColor3 = msgColor
    hint.Outline = false
    hint.Text = ("[G-Script] %s"):format(
        enabled and "🟢 РЕЖИМ УБИЙСТВА ВКЛЮЧЕН" or "🔴 Режим выключен"
    )
    hint.Parent = workspace
    task.wait(2)
    hint:Destroy()

    -- ❗️ Ключевое изменение здесь — создание рамки сразу при активации!
    createHighlight(player.Character or workspace.CurrentCamera)
end

-- Основной цикл слежения за мышью
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end

    -- Нажатие клавиши G
    if input.KeyCode == Enum.KeyCode.G then
        toggleModule() -- Без задержки!
        
        -- Меняем цвет рамки сразу после переключения
        if highlight then
            highlight.Color3 = enabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
            highlight.Transparency = 0.8
            
            -- Обновляем размер рамки под персонажа
            if enabled and player.Character then
                highlight.Size = player.Character:GetExtentsSize() + Vector3.new(1, 1, 1)
                highlight.Visible = true
                highlight.Adornee = player.Character
            else
                highlight.Visible = false
                highlight.Size = Vector3.new(1, 1, 1)
            end
        end
    end

    -- Наведение курсора и ПКМ
    if enabled and input.UserInputType == Enum.UserInputType.MouseButton2 then
        local target = mouse.Target
        if target and target.Parent then
            local char = target.Parent
            local hum = char:FindFirstChildOfClass("Humanoid")
            
            -- Проверки: это живой игрок? Не я ли это?
            if hum and char ~= player.Character and hum.Health > 0 then
                -- Прямое изменение ХП НА КЛИЕНТЕ
                hum.Health = 0 
                
                -- Красная вспышка при убийстве
                highlight.Color3 = Color3.fromRGB(250, 60, 60)
                task.wait(0.1)
                highlight.Color3 = Color3.fromRGB(0, 255, 0)
            end
        end
    end
end)

-- Автоматическая чистка при выходе персонажа
player.CharacterAdded:Connect(function(char)
    -- Ждем немного, чтобы персонаж появился в мире
    task.wait(0.5)
    createHighlight(player.Character) -- Рамка всегда будет зеленой у своего персонажа
end)
    task.wait(0.5)
    createHighlight(player.Character) -- Рамка всегда будет зеленой у своего персонажа
end)
