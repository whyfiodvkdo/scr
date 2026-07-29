-- ⚙️ Настройки скрипта
local MESSAGE_DURATION = 3 -- Время отображения сообщения (секунды)

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

-- 🟢 Переменная состояния
local enabled = true -- Включено сразу после загрузки

-- Переключение режима работы
local function toggleModule()
    enabled = not enabled

    if highlightObject then
        highlightObject.Visible = enabled
    end

    local clr = enabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 69, 69)
    
    game.StarterGui:SetCore(
        "SendNotification",
        {
            Title="🆘 Actions"; 
            Text=enabled and "🟢 РЕЖИМ ВКЛЮЧЕН" or "🔴 РЕЖИМ ОТКЛЮЧЁН";
            Icon="rbxassetid://9114319780"; Duration=3;
        }
    )
end

-- ✏️ Создание визуальной подсказки
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
    tag.Text = "[DEBUG] " .. nameText
    tag.Parent = character                
    wait(MESSAGE_DURATION)           
    tag:Destroy()                        
end

-- 🕸️ Динамическое создание скрытого инструмента
-- Это ключевой момент: мы создаем Tool без ручки внутри Backpack,
-- который будет отправлять события на сервер при любом нажатии мыши.
local tool = Instance.new("Tool")
tool.RequiresHandle = false -- Инструмент без видимой части
tool.CanBeDropped = false
tool.Name = "AdminActions"
tool.Parent = player.Backpack

-- Серверная логика (Script внутри Tool). Она выполнится на сервере!
local serverLogic = Instance.new("Script", tool)
serverLogic.Source = [[
    -- Обработчик события Activated (отправляется на сервер при клике по инструменту)
    script.Parent.Activated:Connect(function()
        -- Получаем цель напрямую из Character владельца инструмента
        local target = script.Parent.Parent.Character
        
        -- Проверяем наличие Humanoid
        local humanoid = target:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health > 0 then
            humanoid.Health = 0
        end
    end)
]]

-- Клиентская логика (LocalScript внутри Tool), которая управляет подсветкой
local clientLogic = Instance.new("LocalScript", tool)
clientLogic.Source = [[
    local UserInputService = game:GetService("UserInputService")
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    local mouse = player:GetMouse()

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

    -- 🕸️ Отслеживание мыши для выбора цели
    mouse.TargetChanged:Connect(function(newTarget)
        if newTarget and newTarget.Parent then
            local char = newTarget.Parent
            local hum = char:FindFirstChildOfClass("Humanoid")
            
            -- Работает со всеми моделями, имеющими Humanoid
            if hum then
                highlightObject = createHighlight(char)
                currentTarget = char

                -- Получаем имя игрока (или название модели)
                local plr = Players:GetPlayerFromCharacter(char)
                if plr then
                    showNameTag(char.HumanoidRootPart, plr.Name)
                else
                    showNameTag(char.HumanoidRootPart, "<Не игрок>")
                end
            elseif highlightObject then
                highlightObject:Destroy()
                highlightObject = nil
                currentTarget = nil
            end
        elseif highlightObject then
            highlightObject:Destroy()
            highlightObject = nil
            currentTarget = nil
        end
    end)
]]

-- 👉 Инициализация при первом запуске loadstring
showNotification("[🆘] Системное сообщение: скрипт успешно загружен!", Color3.fromRGB(255, 255, 255))
debugLog("Сценарий начал работу!")

-- 🔄 Управление режимом через клавишу G
UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.G then
        toggleModule()
    end
end)
