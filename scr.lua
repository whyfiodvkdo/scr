-- ================== КЛИЕНТСКИЙ КОД ДЛЯ ИНЖЕКТОРА ==================
local UserInputService = game:GetService("UserInputService")
local player = game.Players.LocalPlayer
local mouse = player:GetMouse()

local enabled = false
local highlight = nil

local function createHighlight(targetChar)
    if highlight then highlight:Destroy() end
    highlight = Instance.new("BoxHandleAdornment")
    highlight.Name = "G_Cheat_Highlight"
    highlight.Adornee = targetChar
    highlight.Size = targetChar:GetExtentsSize() + Vector3.new(1, 1, 1)
    highlight.Color3 = Color3.fromRGB(0, 255, 0) -- Зеленый при включении
    highlight.Transparency = 0.6
    highlight.AlwaysOnTop = true
    highlight.ZIndex = 1
    highlight.Parent = workspace.CurrentCamera
end

local function destroyUI()
    if highlight then
        highlight:Destroy()
        highlight = nil
    end
end

-- Функция активации/деактивации
local function toggleModule()
    enabled = not enabled
    
    if enabled then
        -- АКТИВАЦИЯ
        createHighlight(nil) -- Создаем пустой объект UI
        
        print("\27[32m[G-Script] Активирован. Наведитесь на игрока и нажмите ПКМ.\27[0m")
        
        local hint = Instance.new("Message")
        hint.Text = "[G-Script] РЕЖИМ УБИЙСТВА ВКЛЮЧЕН"
        hint.Parent = workspace
        task.wait(2)
        hint:Destroy()
    else
        -- ДЕАКТИВАЦИЯ
        destroyUI()
        print("\27[31m[G-Script] Деактивирован. Права сняты.\27[0m")
        
        local hint = Instance.new("Message")
        hint.Text = "[G-Script] Режим выключен"
        hint.Parent = workspace
        task.wait(2)
        hint:Destroy()
    end
end

-- ОСНОВНОЙ ЦИКЛ
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    -- Нажатие клавиши G
    if input.KeyCode == Enum.KeyCode.G then
        toggleModule()
    end

    -- Если модуль включен и нажата ПКМ
    if enabled and input.UserInputType == Enum.UserInputType.MouseButton2 then
        local target = mouse.Target
        if target and target.Parent then
            local char = target.Parent
            local hum = char:FindFirstChildOfClass("Humanoid")
            
            -- Проверки: это живой игрок? Не я ли это?
            if hum and char ~= player.Character and hum.Health > 0 then
                -- ПРЯМОЕ ИЗМЕНЕНИЕ ХП НА КЛИЕНТЕ
                hum.Health = 0 
                
                -- Визуальное подтверждение
                highlight.Color3 = Color3.fromRGB(255, 0, 0) -- Мигает красным
                task.wait(0.1)
                highlight.Color3 = Color3.fromRGB(0, 255, 0)
            end
        end
    end
end)

-- Автоматическая чистка при выходе персонажа
player.CharacterAdded:Connect(function()
    if not enabled then return end
    task.wait(0.5)
    local root = player.Character:FindFirstChild("HumanoidRootPart") or player.Character.PrimaryPart
    if root then
        createHighlight(player.Character)
    end
end)
-- ====================================================================
