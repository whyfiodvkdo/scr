-- ⚙️ Настройки скрипта
local MESSAGE_DURATION = 3     -- Время отображения сообщений (секунды)
local MOVEMENT_SPEED = 50      -- Скорость полёта
local HOVER_HEIGHT = 8        -- Высота зависания над точкой под курсом

-- 🖥️ Подключение к сервисам Roblox
local UserInputService = game.GamepadService or game.UserScript or game.GetService("UserInputService")
local Players = game.Players
local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- ✏️ Функция вывода уведомления через SetCore()
local function showNotification(title, message, iconId, duration)
    game.StarterGui:SetCore(
        "SendNotification",
        {
            Title = title,
            Text = message,
            Icon = iconId or "",
            Duration = duration or 5
        }
    )
end

-- 🔧 Отладочные функции
local function debugLog(msg)
    print("[DEBUG] " .. msg)
end

-- 🕸️ Создание визуальной подсказки (рамки вокруг игроков)
local function createHighlight(targetCharacter)
    if not targetCharacter or not targetCharacter.PrimaryPart then return nil end

    local box = Instance.new("BoxHandleAdornment", workspace.CurrentCamera)
    box.Name = "Drone_Highlight"
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
    tag.TextColor3 = Color3.fromRGB(256, 256, 256)
    tag.Outline = false                   
    tag.Text = "[DEBUG] " .. nameText
    tag.Parent = character                
    wait(MESSAGE_DURATION)           
    tag:Destroy()                        
end

-- 🟢 Переменная состояния
local hoverMode = false -- По умолчанию управляемся мышью

-- Переключение режима работы
local function toggleHover()
    hoverMode = not hoverMode

    if hoverMode then
        showNotification("🆘 Drone Mode", 
                        "🔴 Режим зависания активирован!", 
                        "rbxassetid://9114319780")
    else
        showNotification("🆘 Drone Mode", 
                        "🟢 Управление по курсу мыши!", 
                        "rbxassetid://9114319780")
    end
end

-- 👟 Основной цикл управления персонажем
local function flyAI()
    repeat wait() until player.Character and player.Character.HumanoidRootPart

    while true do
        if not player.Character or not player.Character.HumanoidRootPart then
            warn("[WARNING]: Персонаж исчез. Ждём восстановления...")
            repeat wait(0.5) until player.Character and player.Character.HumanoidRootPart
        else
            -- 🌐 Анализируем мир
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= player and plr.Character then
                    local char = plr.Character
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    
                    if hum and hum.Health > 0 then
                        createHighlight(char)
                        showNameTag(char.HumanoidRootPart, plr.Name)
                    elseif highlightObject then
                        for _, obj in pairs(workspace.CurrentCamera:GetChildren()) do
                            if obj.Name == "Drone_Highlight" and obj.Adornee == char then
                                obj:Destroy()
                            end
                        end
                    end
                end
            end

            -- 🛰️ Движение
            if not hoverMode then
                -- Следуем за курсором мыши
                if mouse.Target and mouse.Target.Parent then
                    local targetPos = mouse.Hit.p + Vector3.new(0, HOVER_HEIGHT, 0)
                    player.Character.HumanoidRootPart.CFrame =
                        CFrame.new(player.Character.HumanoidRootPart.Position, targetPos) *
                        CFrame.new(Vector3.new(0, 0, -MOVEMENT_SPEED))
                end
            else
                -- Просто висим на месте
                player.Character.Humanoid.AutoRotate = false
                player.Character.Humanoid.WalkSpeed = 0
            end
            
            wait(0.05)
        end
    end
end

-- 🔄 Инициализация при первом запуске loadstring
showNotification("[🆘] Системное сообщение:", 
                 "Летающий дрон активирован!\nНажмите G для зависания.", 
                 "rbxassetid://9114319780")
debugLog("Сценарий начал работу!")

-- 🤝 Назначение кнопки переключения
UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.G then
        toggleHover()
    end
end)

flyAI() -- Запуск основного цикла
