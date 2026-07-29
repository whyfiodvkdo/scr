-- ⚙️ Настройки скрипта
local MESSAGE_DURATION = 3           -- Время отображения сообщения (секунды)

-- 🛡️ Защита от повторного запуска
if script.Parent then return end

-- 🖥️ Подключение к сервисам Roblox
local UserInputService = game:GamepadService or game:GetService("UserInputService") -- Для совместимости
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- ✏️ Функция создания или обновления визуальной подсказки
local function createHighlight(targetCharacter)
    if not targetCharacter or not targetCharacter.PrimaryPart then return nil end

    local box = Instance.new("BoxHandleAdornment", workspace.CurrentCamera)
    box.Name = "G_Cheat_Highlight"
    box.AlwaysOnTop = true
    box.ZIndex = 10
    box.Color3 = Color3.fromRGB(0, 255, 0)   -- Основной цвет рамки (зеленый)
    box.Transparency = 0.7                    -- Полупрозрачность
    box.Size = targetCharacter:GetExtentsSize() + Vector3.new(1, 1, 1)
    box.Adornee = targetCharacter             -- Прикрепляем рамку к персонажу

    return box
end

-- 🗨️ Функция вывода системного уведомления рядом с игроком
local function showNameTag(character, nameText)
    if not character then return nil end

    local tag = Instance.new("Hint")       -- Текстовый объект
    tag.TextColor3 = Color3.fromRGB(255, 255, 255)
    tag.Outline = false                   -- Без контура
    tag.Text = "[🆘] " .. nameText
    tag.Parent = character                -- Привязываем его к игроку
    task.wait(MESSAGE_DURATION)               -- Ждем заданное время
    tag:Destroy()                            -- Удаляем уведомление

    return tag
end

-- 🔹 Переменные состояния
local currentTarget = nil     -- Текущий игрок под курсором
local highlightObject = nil   -- Объект рамки выделения
local actionMenu = nil        -- Наше кастомное меню

-- 📋 Создание интерфейса действия
local function createActionMenu()
    if actionMenu then return end

    local gui = Instance.new("ScreenGui")
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 9999
    gui.Parent = player.PlayerGui

    -- Контейнер для кнопок
    local frame = Instance.new("Frame", gui)
    frame.BackgroundTransparency = 1
    frame.Position = UDim2.new(mouse.X/workspace.CurrentCamera.ViewportSize.X - 0.5,
                               mouse.Y/workspace.CurrentCamera.ViewportSize.Y - 0.5)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)

    -- Кнопка 1: Убить 💀
    local btnKill = Instance.new("TextButton", frame)
    btnKill.AutoButtonColor = false
    btnKill.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    btnKill.BackgroundTransparency = 0.8
    btnKill.Size = UDim2.new(0, 60, 0, 60)
    btnKill.Position = UDim2.new(-0.5, 0, -0.5, 0)
    btnKill.FontFace = Font.new("rbxasset://fonts/faces/Font.ttf", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
    btnKill.Text = "💀" -- Эмодзи черепа
    btnKill.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnKill.TextScaled = true

    -- Кнопка 2: Подбросить 🪄
    local btnJump = Instance.new("TextButton", frame)
    btnJump.AutoButtonColor = false
    btnJump.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    btnJump.BackgroundTransparency = 0.8
    btnJump.Size = UDim2.new(0, 60, 0, 60)
    btnJump.Position = UDim2.new(0, 0, -0.5, 0)
    btnJump.FontFace = Font.new("rbxasset://fonts/faces/Font.ttf", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
    btnJump.Text = "🪄" -- Эмодзи ракеты
    btnJump.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnJump.TextScaled = true

    -- Кнопка 3: Толкать 🧊
    local btnPush = Instance.new("TextButton", frame)
    btnPush.AutoButtonColor = false
    btnPush.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    btnPush.BackgroundTransparency = 0.8
    btnPush.Size = UDim2.new(0, 60, 0, 60)
    btnPush.Position = UDim2.new(0.5, 0, -0.5, 0)
    btnPush.FontFace = Font.new("rbxasset://fonts/faces/Font.ttf", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
    btnPush.Text = "🧊" -- Эмодзи руки
    btnPush.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnPush.TextScaled = true

    -- Обработчик кликов по кнопкам
    local function onClick(action)
        if currentTarget and currentTarget.Humanoid.Health > 0 then
            if action == "kill" then
                currentTarget.Humanoid.Health = 0
                if highlightObject then
                    highlightObject.Color3 = Color3.fromRGB(255, 60, 60)
                    task.wait(0.1)
                    highlightObject.Color3 = Color3.fromRGB(0, 255, 0)
                end
            elseif action == "jump" then
                local root = currentTarget:FindFirstChild("HumanoidRootPart")
                if root then
                    root.Velocity = Vector3.new(0, 80, 0)
                end
            elseif action == "push" then
                local myPos = player.Character:FindFirstChild("HumanoidRootPart").Position
                local theirPos = currentTarget:FindFirstChild("HumanoidRootPart").Position
                local direction = (myPos - theirPos).Unit * 40

                local bv = Instance.new("BodyVelocity", currentTarget:FindFirstChild("UpperTorso"))
                bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bv.P = 12000
                bv.Velocity = direction
                wait(0.2)
                bv:Destroy()
            end
        end
        
        -- Скрываем меню после нажатия
        destroyMenu()
    end

    btnKill.Activated:Connect(function() onClick("kill") end)
    btnJump.Activated:Connect(function() onClick("jump") end)
    btnPush.Activated:Connect(function() onClick("push") end)

    actionMenu = {
        Gui = gui,
        UpdatePosition = function(x, y)
            frame.Position = UDim2.new(
                x / workspace.CurrentCamera.ViewportSize.X - 0.5,
                y / workspace.CurrentCamera.ViewportSize.Y - 0.5
            )
        end
    }

    return actionMenu
end

local function destroyMenu()
    if actionMenu then
        actionMenu.Gui:Destroy()
        actionMenu = nil
    end
end

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
                showNameTag(char.HumanoidRootPart, char.Name)
            end

            -- Запоминаем текущую цель
            currentTarget = char

            -- Показываем наше меню
            destroyMenu()
            createActionMenu().UpdatePosition(mouse.X, mouse.Y)
        elseif highlightObject then
            -- Убираем старую рамку, если цель потеряна
            highlightObject:Destroy()
            highlightObject = nil
            currentTarget = nil
            destroyMenu()
        end
    elseif highlightObject then
        -- Убираем старую рамку, если мы смотрим в пустоту
        highlightObject:Destroy()
        highlightObject = nil
        currentTarget = nil
        destroyMenu()
    end
end)

-- 🌐 Следим за движением мыши, чтобы двигалось и меню
RunService.RenderStepped:Connect(function()
    if actionMenu then
        actionMenu.UpdatePosition(mouse.X, mouse.Y)
    end
end)

-- 👉 Ловим клик по экрану вне нашего меню
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end                     -- Игнорируем события ввода в чат

    -- Если нажата любая кнопка мыши, а курсор НЕ внутри наших кнопок
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.MouseButton2 then
        if actionMenu and not actionMenu.Gui:FindFirstAncestorWhichIsA("TextButton"):IsMouseOver() then
            destroyMenu()
        end
    end
end)
