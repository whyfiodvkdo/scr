-- ⚙️ Настройки скрипта
local MESSAGE_DURATION = 3        -- Время отображения сообщений (секунды)
local MOVEMENT_SPEED = 16         -- Базовая скорость движения (используется как скорость следования к waypoints)
local ATTACK_RANGE = 8            -- Радиус ближнего боя
local AVOIDANCE_DISTANCE = 4      -- Расстояние для Raycast-а впереди
local WORLD_TRACK_INTERVAL = 1    -- Интервал в секундах для сканирования мира
local MOVE_CHECK_INTERVAL = 0.1   -- Интервал в секундах для AI цикла

-- 🖥️ Подключение сервисов
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- Проверка контекста (скрипт должен быть LocalScript)
if not player then
    warn("[scr.lua] LocalPlayer не найден — убедитесь, что этот скрипт запускается как LocalScript.")
    return
end

-- ✏️ Функция вывода системного уведомления (через SetCore для LocalScripts)
local function showNotification(title, text, duration)
    local ok, err = pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title or "[Система]",
            Text = text or "",
            Duration = duration or MESSAGE_DURATION
        })
    end)
    if not ok then
        warn("[scr.lua] Не удалось показать уведомление: " .. tostring(err))
    end
end

-- 🔧 Отладочные функции
local function debugLog(msg)
    -- можно добавить переключатель логирования при необходимости
    print(("[scr] %s"):format(tostring(msg)))
end

-- 🕸️ Управление подсветкой игроков (избегаем дубликатов и очищаем правильно)
local highlights = {}

local function createOrUpdateHighlight(targetCharacter, color)
    if not targetCharacter or not targetCharacter.PrimaryPart then return end
    local char = targetCharacter
    local key = char:GetDebugId() or tostring(char) -- уникальный ключ для таблицы

    local box = highlights[key]
    if box and box.Parent then
        -- обновляем параметры
        box.Color3 = color
        -- обновляем размер и Adornee на всякий случай
        box.Adornee = char.PrimaryPart
        box.Size = char:GetExtentsSize() + Vector3.new(1, 1, 1)
        return box
    end

    -- создаём новый BoxHandleAdornment и храним его
    box = Instance.new("BoxHandleAdornment")
    box.Name = "Bot_Highlight"
    box.AlwaysOnTop = true
    box.ZIndex = 10
    box.Color3 = color
    box.Transparency = 0.35
    box.Size = char:GetExtentsSize() + Vector3.new(1, 1, 1)
    box.Adornee = char.PrimaryPart
    box.Parent = Workspace.CurrentCamera
    highlights[key] = box

    return box
end

local function removeHighlightForCharacter(targetCharacter)
    if not targetCharacter or not targetCharacter.PrimaryPart then return end
    local key = targetCharacter:GetDebugId() or tostring(targetCharacter)
    local box = highlights[key]
    if box then
        if box.Parent then box:Destroy() end
        highlights[key] = nil
    end
end

-- Очистка всех подсветок (на выход/перезагрузку)
local function clearAllHighlights()
    for k, v in pairs(highlights) do
        if v and v.Parent then
            v:Destroy()
        end
        highlights[k] = nil
    end
end

-- 🗨️ Сбор информации о мире (неблокирующий цикл)
local function trackWorld()
    task.spawn(function()
        while true do
            local ok, err = pcall(function()
                -- Анализ игроков
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= player and plr.Character then
                        local char = plr.Character
                        local hum = char:FindFirstChildOfClass("Humanoid")
                        local root = char:FindFirstChild("HumanoidRootPart")
                        if hum and root and hum.Health > 0 then
                            -- Выбор цвета подсветки
                            local clr = Color3.fromRGB(0, 255, 0)
                            if hum.Health < 50 then
                                clr = Color3.fromRGB(255, 255, 0) -- жёлтый
                            elseif hum.Health == 100 then
                                clr = Color3.fromRGB(255, 0, 0) -- красный
                            end
                            createOrUpdateHighlight(char, clr)

                            -- Логирование позиции и здоровья
                            debugLog(string.format("%s | Health: %.1f | Position: %.1f, %.1f, %.1f",
                                plr.Name, hum.Health, root.Position.X, root.Position.Y, root.Position.Z))
                        else
                            -- удаляем подсветку если игрок умер или нет Character
                            removeHighlightForCharacter(char)
                        end
                    end
                end

                -- Поиск аптечек (Part с именем "Heal")
                for _, part in ipairs(Workspace:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name == "Heal" and part.CanCollide then
                        local pos = part.Position
                        debugLog(string.format("Найдена аптечка: %.1f, %.1f, %.1f", pos.X, pos.Y, pos.Z))
                        -- Здесь можно хранить позиции аптечек в кэше для поведения ИИ
                    end
                end
            end)
            if not ok then
                warn("[scr.lua] Ошибка в trackWorld: " .. tostring(err))
            end
            task.wait(WORLD_TRACK_INTERVAL)
        end
    end)
end

-- 👟 Управление персонажем (ИИ) с использованием Pathfinding
local function moveAI()
    task.spawn(function()
        while true do
            local ok, err = pcall(function()
                local char = player.Character
                if not char then
                    -- Ждём появления персонажа
                    return
                end
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                local root = char:FindFirstChild("HumanoidRootPart")
                if not humanoid or not root then
                    return
                end

                -- 1) Избегание столкновений: raycast вперед
                local rayParams = RaycastParams.new()
                rayParams.FilterType = Enum.RaycastFilterType.Blacklist
                rayParams.FilterDescendantsInstances = {char, Workspace.CurrentCamera}
                local origin = root.Position
                local direction = root.CFrame.LookVector * AVOIDANCE_DISTANCE
                local result = Workspace:Raycast(origin, direction, rayParams)

                if result and result.Instance and result.Instance.CanCollide then
                    -- Найдена преграда впереди: пытаемся отклониться вправо/влево
                    local normal = result.Normal
                    -- смещение в сторону относительно нормали
                    local sideOffset = Vector3.new(normal.Z, 0, -normal.X) * (AVOIDANCE_DISTANCE + 1)
                    local avoidPos = origin + sideOffset
                    -- простой MoveTo (без pathfinding) для избегания
                    humanoid:MoveTo(avoidPos)
                    -- небольшой тайм-аут, даём время пройти уклонение
                    task.wait(0.25)
                    return
                end

                -- 2) Поиск лучшей цели
                local bestTargetChar = nil
                local bestDist = math.huge
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= player and plr.Character then
                        local tch = plr.Character
                        local thum = tch:FindFirstChildOfClass("Humanoid")
                        local troot = tch:FindFirstChild("HumanoidRootPart")
                        if thum and troot and thum.Health > 0 then
                            local dist = (troot.Position - root.Position).Magnitude
                            if (thum.Health <= 50) or (dist < bestDist) then
                                bestTargetChar = tch
                                bestDist = dist
                            end
                        end
                    end
                end

                -- 3) Принятие решения по движению
                if bestTargetChar and bestTargetChar:FindFirstChild("HumanoidRootPart") then
                    local targetPos = bestTargetChar.HumanoidRootPart.Position
                    if bestDist <= ATTACK_RANGE then
                        -- в зоне атаки -> стоим на месте и можно выполнить атаку
                        humanoid:MoveTo(root.Position)
                        -- Здесь можно вызвать функцию атаки/анимации
                    else
                        -- планируем путь до цели через Pathfinding
                        local path = PathfindingService:CreatePath({
                            AgentRadius = 2,
                            AgentHeight = 5,
                            AgentCanJump = true,
                            CostMultiplier = 1.0
                        })
                        path:ComputeAsync(root.Position, targetPos)
                        if path.Status == Enum.PathStatus.Success then
                            local waypoints = path:GetWaypoints()
                            for _, waypoint in ipairs(waypoints) do
                                -- если во время движения цель исчезла или игрок умер — прервать
                                if not bestTargetChar.Parent or (bestTargetChar:FindFirstChildOfClass("Humanoid") and bestTargetChar:FindFirstChildOfClass("Humanoid").Health <= 0) then
                                    break
                                end
                                humanoid:MoveTo(waypoint.Position)
                                -- ждём либо окончания движения к точке, либо таймаута
                                local reached = humanoid.MoveToFinished:Wait()
                                -- небольшой yield чтобы избежать блокировки
                                task.wait(0.02)
                            end
                        else
                            -- fallback: прямо идти к позиции цели
                            humanoid:MoveTo(targetPos)
                        end
                    end
                else
                    -- нет целей — идём немного вперед (небольшой шаг)
                    local forwardPos = root.Position + (root.CFrame.LookVector * MOVEMENT_SPEED)
                    humanoid:MoveTo(forwardPos)
                end
            end)
            if not ok then
                warn("[scr.lua] Ошибка в moveAI: " .. tostring(err))
            end
            task.wait(MOVE_CHECK_INTERVAL)
        end
    end)
end

-- 🔄 Инициализация
showNotification("Автономный режим", "Сценарий активирован", MESSAGE_DURATION)
debugLog("Сценарий начал работу!")

-- Ждём Character и ключевых частей
local function waitForCharacter(timeout)
    local elapsed = 0
    while (not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") or not player.Character:FindFirstChildOfClass("Humanoid")) and elapsed < (timeout or 10) do
        task.wait(0.2)
        elapsed = elapsed + 0.2
    end
    return player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChildOfClass("Humanoid")
end

local got = waitForCharacter(10)
if not got then
    error("[scr.lua] Персонаж не появился за отведённое время!")
end

-- Запуск процессов
trackWorld()
moveAI()

-- Обработка выхода/очищения (например, при смене персонажа)
player.CharacterRemoving:Connect(function(char)
    -- очищаем подсветки, связанные с этим Character (и, в целом, все)
    clearAllHighlights()
end)

-- Дополнительно: при смене персонажа перезапускаем AI/отслеживание автоматически (скрипты выше выдерживают это)
player.CharacterAdded:Connect(function(char)
    debugLog("CharacterAdded: перезапуск логики (авто).")
    -- короткая пауза, чтобы части успели создаться
    task.wait(0.5)
end)
