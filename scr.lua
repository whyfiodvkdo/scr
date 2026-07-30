-- ⚙️ Настройки скрипта
local MESSAGE_DURATION = 3        -- Время отображения сообщений (секунды)
local MOVEMENT_SPEED = 16         -- Базовая скорость движения (используется как скорость следования к waypoints)
local ATTACK_RANGE = 8            -- Радиус ближнего боя
local AVOIDANCE_DISTANCE = 4      -- Расстояние для Raycast-а впереди
local WORLD_TRACK_INTERVAL = 1    -- Интервал в секундах для сканирования мира
local MOVE_CHECK_INTERVAL = 0.1   -- Интервал в секундах для AI цикла

-- Автономные параметры (бот "сам управляет цифрами и мышью")
local AUTO_MODE_ENABLED = true                -- включает автономные "нажатия"
local AUTO_ACTION_INTERVAL = 3.0              -- как часто бот принимает "действие" (сек)
local AUTO_TARGET_SELECTION_INTERVAL = 6.0    -- как часто бот выбирает/переназначает цель (сек)
local AUTO_RANDOMNESS = 0.25                  -- шанс выполнить произвольное действие при тике (0..1)

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

-- State / флаги управления (управляются клавишами или автоконтролером)
local botEnabled = true
local highlightsEnabled = true
local usePathfinding = true
local notificationsEnabled = true
local attackMode = "auto" -- "auto" или "manual"
local manualTarget = nil  -- если установлен (Character), ИИ будет целиться в него

-- ✏️ Функция вывода системного уведомления (через SetCore для LocalScripts)
local function showNotification(title, text, duration)
    if not notificationsEnabled then return end
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
    print(("[scr] %s"):format(tostring(msg)))
end

-- 🕸️ Управление подсветкой игроков (избегаем дубликатов и очищаем правильно)
local highlights = {}

local function createOrUpdateHighlight(targetCharacter, color)
    if not targetCharacter or not targetCharacter.PrimaryPart then return end
    local char = targetCharacter
    local key = tostring(char) -- простой ключ

    local box = highlights[key]
    if box and box.Parent then
        box.Color3 = color
        box.Adornee = char.PrimaryPart
        box.Size = char:GetExtentsSize() + Vector3.new(1, 1, 1)
        return box
    end

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
    if not targetCharacter then return end
    local key = tostring(targetCharacter)
    local box = highlights[key]
    if box then
        if box.Parent then box:Destroy() end
        highlights[key] = nil
    end
end

local function clearAllHighlights()
    for k, v in pairs(highlights) do
        if v and v.Parent then
            v:Destroy()
        end
        highlights[k] = nil
    end
end

-- рефакторинг: функции, которые можно вызывать как из ввода, так и из автоконтроллера
local function toggleBot()
    botEnabled = not botEnabled
    showNotification("Бот", botEnabled and "Включён" or "Выключен")
    debugLog("botEnabled -> " .. tostring(botEnabled))
end
local function toggleHighlights()
    highlightsEnabled = not highlightsEnabled
    if not highlightsEnabled then clearAllHighlights() end
    showNotification("Подсветка", highlightsEnabled and "Включена" or "Выключена")
    debugLog("highlightsEnabled -> " .. tostring(highlightsEnabled))
end
local function togglePathfinding()
    usePathfinding = not usePathfinding
    showNotification("Pathfinding", usePathfinding and "Включён" or "Отключён")
    debugLog("usePathfinding -> " .. tostring(usePathfinding))
end
local function toggleAttackMode()
    if attackMode == "auto" then attackMode = "manual" else attackMode = "auto" end
    showNotification("Режим атаки", "Режим: " .. attackMode)
    debugLog("attackMode -> " .. attackMode)
end
local function adjustAttackRange(delta)
    ATTACK_RANGE = math.max(1, ATTACK_RANGE + delta)
    showNotification("ATTACK_RANGE", tostring(ATTACK_RANGE))
    debugLog("ATTACK_RANGE -> " .. tostring(ATTACK_RANGE))
end
local function showStatus()
    local status = string.format("Bot:%s PF:%s HL:%s Mode:%s AR:%.1f",
        tostring(botEnabled), tostring(usePathfinding), tostring(highlightsEnabled), attackMode, ATTACK_RANGE)
    showNotification("Статус", status, 4)
    debugLog(status)
end
local function resetSettings()
    botEnabled = true
    highlightsEnabled = true
    usePathfinding = true
    attackMode = "auto"
    notificationsEnabled = true
    showNotification("Сброс", "Настройки сброшены")
    debugLog("settings reset to defaults")
end
local function clearManualTarget()
    manualTarget = nil
    showNotification("Цель", "Ручная цель очищена")
    debugLog("manualTarget cleared")
end

-- 🗨️ Сбор информации о мире (неблокирующий цикл)
local function trackWorld()
    task.spawn(function()
        while true do
            local ok, err = pcall(function()
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= player and plr.Character then
                        local char = plr.Character
                        local hum = char:FindFirstChildOfClass("Humanoid")
                        local root = char:FindFirstChild("HumanoidRootPart")
                        if hum and root and hum.Health > 0 then
                            if highlightsEnabled then
                                local clr = Color3.fromRGB(0, 255, 0)
                                if hum.Health < 50 then
                                    clr = Color3.fromRGB(255, 255, 0)
                                elseif hum.Health == 100 then
                                    clr = Color3.fromRGB(255, 0, 0)
                                end
                                createOrUpdateHighlight(char, clr)
                            else
                                removeHighlightForCharacter(char)
                            end

                            debugLog(string.format("%s | Health: %.1f | Position: %.1f, %.1f, %.1f",
                                plr.Name, hum.Health, root.Position.X, root.Position.Y, root.Position.Z))
                        else
                            removeHighlightForCharacter(char)
                        end
                    end
                end

                for _, part in ipairs(Workspace:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name == "Heal" and part.CanCollide then
                        local pos = part.Position
                        debugLog(string.format("Найдена аптечка: %.1f, %.1f, %.1f", pos.X, pos.Y, pos.Z))
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

-- Вспомогательная: найти игрока по кликнутой части
local function playerFromDescendant(desc)
    if not desc then return nil end
    local cur = desc
    while cur and cur.Parent do
        local pl = Players:GetPlayerFromCharacter(cur.Parent)
        if pl then return pl, cur.Parent end
        cur = cur.Parent
    end
    return nil
end

-- Симуляция "щелчка" по цели (не реальный ввод, а внутренняя имитация)
local function simulateMouseClickOnCharacter(char)
    if not char or not char.Parent then return false end
    manualTarget = char
    attackMode = "manual"
    local pl = Players:GetPlayerFromCharacter(char)
    if pl then
        showNotification("Авто-клик", "Назначена цель: " .. pl.Name)
        debugLog("simulateMouseClick -> " .. pl.Name)
    else
        debugLog("simulateMouseClick -> target set (no player found)")
    end
    return true
end

-- Локальная имитация атаки (визуальная/логирование)
local function performLocalAttackIfInRange()
    if not manualTarget or not manualTarget.Parent then return end
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local troot = manualTarget:FindFirstChild("HumanoidRootPart")
    if not root or not troot then return end
    local dist = (troot.Position - root.Position).Magnitude
    if dist <= ATTACK_RANGE then
        local pl = Players:GetPlayerFromCharacter(manualTarget) or {Name = "Unknown"}
        showNotification("Атака", "Атакую " .. pl.Name, 1)
        debugLog("performLocalAttackIfInRange -> attacked " .. tostring(pl.Name) .. " dist=" .. string.format("%.1f", dist))
        -- Здесь можно: воспроизвести анимацию, отправить RemoteEvent на сервер и т.д.
    end
end

-- Безопасный MoveTo с таймаутом и защитой от удаления humanoid
local function safeMoveTo(humanoid, position, timeout)
    if not humanoid or not humanoid.Parent then return false end
    local reached = false
    local conn
    local ok, err = pcall(function()
        conn = humanoid.MoveToFinished:Connect(function(success)
            reached = success
        end)
    end)
    if not ok then
        if conn then conn:Disconnect() end
        return false
    end

    local success, err2 = pcall(function()
        humanoid:MoveTo(position)
    end)
    if not success then
        if conn then conn:Disconnect() end
        return false
    end

    timeout = timeout or 3.0
    local elapsed = 0
    while elapsed < timeout do
        if reached then break end
        if not humanoid.Parent then break end -- humanoid удалён (мы умерли)
        task.wait(0.1)
        elapsed = elapsed + 0.1
    end

    if conn then conn:Disconnect() end
    return reached
end

-- 👟 Управление персонажем (ИИ) с использованием Pathfinding — теперь устойчиво к смерти/респавну
local function moveAI()
    task.spawn(function()
        while true do
            local ok, err = pcall(function()
                -- Если бот выключен — просто подождём и продолжим цикл (не выходим из функции)
                if not botEnabled then
                    task.wait(MOVE_CHECK_INTERVAL)
                    return
                end

                -- Ждём наличия Character и ключевых частей, не завершая цикл при смерти
                local char = player.Character
                local humanoid = char and char:FindFirstChildOfClass("Humanoid")
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if not (char and humanoid and root) then
                    -- Ждём событие CharacterAdded чтобы возобновить работу
                    debugLog("moveAI: ожидаю появления Character/Humanoid/HRP...")
                    local waiting = true
                    local connAdded
                    connAdded = player.CharacterAdded:Connect(function(c)
                        waiting = false
                        if connAdded then connAdded:Disconnect() end
                    end)
                    local waitTimeout = 10
                    local elapsed = 0
                    while waiting and elapsed < waitTimeout do
                        task.wait(0.2)
                        elapsed = elapsed + 0.2
                        -- если персонаж появился — выйдем из ожидания
                        char = player.Character
                        humanoid = char and char:FindFirstChildOfClass("Humanoid")
                        root = char and char:FindFirstChild("HumanoidRootPart")
                        if char and humanoid and root then
                            waiting = false
                        end
                    end
                    if connAdded then connAdded:Disconnect() end
                    -- следующий проход цикла выполнится с обновлёнными ссылками
                    return
                end

                -- Переназначаем цель, если ручная цель умерла
                if manualTarget and (not manualTarget.Parent or (manualTarget:FindFirstChildOfClass("Humanoid") and manualTarget:FindFirstChildOfClass("Humanoid").Health <= 0)) then
                    manualTarget = nil
                    debugLog("moveAI: ручная цель умерла — очищена")
                end

                local bestTargetChar = nil
                if manualTarget and manualTarget.Parent then
                    local mHum = manualTarget:FindFirstChildOfClass("Humanoid")
                    if mHum and mHum.Health > 0 then
                        bestTargetChar = manualTarget
                    else
                        manualTarget = nil
                    end
                end

                -- избегание
                local rayParams = RaycastParams.new()
                rayParams.FilterType = Enum.RaycastFilterType.Blacklist
                rayParams.FilterDescendantsInstances = {char, Workspace.CurrentCamera}
                local origin = root.Position
                local direction = root.CFrame.LookVector * AVOIDANCE_DISTANCE
                local result = Workspace:Raycast(origin, direction, rayParams)

                if result and result.Instance and result.Instance.CanCollide then
                    local normal = result.Normal
                    local sideOffset = Vector3.new(normal.Z, 0, -normal.X) * (AVOIDANCE_DISTANCE + 1)
                    local avoidPos = origin + sideOffset
                    safeMoveTo(humanoid, avoidPos, 1.0)
                    task.wait(0.25)
                    return
                end

                if not bestTargetChar then
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
                end

                if bestTargetChar and bestTargetChar:FindFirstChild("HumanoidRootPart") then
                    local targetPos = bestTargetChar.HumanoidRootPart.Position
                    local distToTarget = (targetPos - root.Position).Magnitude
                    if attackMode == "manual" and manualTarget == nil then
                        safeMoveTo(humanoid, root.Position, 0.5)
                    else
                        if distToTarget <= ATTACK_RANGE then
                            safeMoveTo(humanoid, root.Position, 0.5) -- стоим и атакуем
                        else
                            if usePathfinding then
                                local path = PathfindingService:CreatePath({
                                    AgentRadius = 2,
                                    AgentHeight = 5,
                                    AgentCanJump = true,
                                    CostMultiplier = 1.0
                                })
                                local ok2, err2 = pcall(function()
                                    path:ComputeAsync(root.Position, targetPos)
                                end)
                                if not ok2 then
                                    debugLog("path ComputeAsync error: " .. tostring(err2))
                                    safeMoveTo(humanoid, targetPos, 2.0)
                                else
                                    if path.Status == Enum.PathStatus.Success then
                                        local waypoints = path:GetWaypoints()
                                        for _, waypoint in ipairs(waypoints) do
                                            if not bestTargetChar.Parent or (bestTargetChar:FindFirstChildOfClass("Humanoid") and bestTargetChar:FindFirstChildOfClass("Humanoid").Health <= 0) then
                                                break
                                            end
                                            safeMoveTo(humanoid, waypoint.Position, 2.0)
                                            -- короткая пауза, чтобы не заблокировать основной цикл
                                            task.wait(0.02)
                                            -- если наш humanoid был удалён (мы умерли) — прерываем
                                            if not humanoid.Parent then break end
                                        end
                                    else
                                        safeMoveTo(humanoid, targetPos, 2.0)
                                    end
                                end
                            else
                                safeMoveTo(humanoid, targetPos, 2.0)
                            end
                        end
                    end
                else
                    -- нет целей — идём немного вперед (небольшой шаг)
                    local forwardPos = root.Position + (root.CFrame.LookVector * MOVEMENT_SPEED)
                    safeMoveTo(humanoid, forwardPos, 1.0)
                end

                -- если в ручной цели и в зоне — попытаться "атаковать"
                if manualTarget then
                    performLocalAttackIfInRange()
                end
            end)
            if not ok then
                warn("[scr.lua] Ошибка в moveAI: " .. tostring(err))
            end
            task.wait(MOVE_CHECK_INTERVAL)
        end
    end)
end

-- 🔧 Обработка ввода с клавиатуры и мыши (назначение ручной цели, переключатели)
local function setupInput(mouse)
    -- Клавиши: 1..0 (Alpha1..Alpha0)
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            local key = input.KeyCode
            if key == Enum.KeyCode.One then toggleBot()
            elseif key == Enum.KeyCode.Two then toggleHighlights()
            elseif key == Enum.KeyCode.Three then togglePathfinding()
            elseif key == Enum.KeyCode.Four then toggleAttackMode()
            elseif key == Enum.KeyCode.Five then
                notificationsEnabled = not notificationsEnabled
                showNotification("Уведомления", notificationsEnabled and "Включены" or "Выключены")
                debugLog("notificationsEnabled -> " .. tostring(notificationsEnabled))
            elseif key == Enum.KeyCode.Six then adjustAttackRange(2)
            elseif key == Enum.KeyCode.Seven then adjustAttackRange(-2)
            elseif key == Enum.KeyCode.Eight then showStatus()
            elseif key == Enum.KeyCode.Nine then clearManualTarget()
            elseif key == Enum.KeyCode.Zero then resetSettings()
            end
        end
    end)

    -- Мышь: левая кнопка — назначить цель по клику, правая — очистить
    if mouse then
        mouse.Button1Down:Connect(function()
            local target = mouse.Target
            local pl, char = playerFromDescendant(target)
            if pl and char then
                manualTarget = char
                attackMode = "manual"
                showNotification("Цель", "Назначена цель: " .. pl.Name)
                debugLog("manualTarget set -> " .. tostring(pl.Name))
            else
                showNotification("Клик мыши", "Цель не распознана")
                debugLog("mouse click: no player found")
            end
        end)
        mouse.Button2Down:Connect(function()
            clearManualTarget()
        end)
    else
        warn("[scr.lua] mouse не доступен; события мыши не подключены.")
    end
end

-- Автоконтроллер: сам принимает решения и вызывает те же функции, что и ручной ввод
local function autoController()
    task.spawn(function()
        local lastAction = 0
        local lastTargetSelect = 0
        while true do
            if not AUTO_MODE_ENABLED then
                task.wait(1.0)
            else
                local now = os.clock()
                -- периодическое переназначение цели
                if now - lastTargetSelect >= AUTO_TARGET_SELECTION_INTERVAL then
                    lastTargetSelect = now
                    -- выбрать лучшую цель (ближайшую или с низким HP)
                    local bestChar = nil
                    local bestDist = math.huge
                    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                    if root then
                        for _, plr in ipairs(Players:GetPlayers()) do
                            if plr ~= player and plr.Character then
                                local th = plr.Character
                                local thum = th:FindFirstChildOfClass("Humanoid")
                                local troot = th:FindFirstChild("HumanoidRootPart")
                                if thum and troot and thum.Health > 0 then
                                    local dist = (troot.Position - root.Position).Magnitude
                                    if thum.Health <= 50 or dist < bestDist then
                                        bestChar = th
                                        bestDist = dist
                                    end
                                end
                            end
                        end
                    end
                    if bestChar then
                        simulateMouseClickOnCharacter(bestChar)
                    end
                end

                -- случайное действие: переключить флаги, очистить цель, "кликнуть" по цели (атака)
                if now - lastAction >= AUTO_ACTION_INTERVAL then
                    lastAction = now
                    local r = math.random()
                    if r < 0.12 then
                        toggleBot()
                    elseif r < 0.24 then
                        toggleHighlights()
                    elseif r < 0.36 then
                        togglePathfinding()
                    elseif r < 0.48 then
                        toggleAttackMode()
                    elseif r < 0.60 then
                        if math.random() < 0.5 then adjustAttackRange(2) else adjustAttackRange(-2) end
                    elseif r < 0.72 then
                        clearManualTarget()
                    else
                        -- в большинстве случаев - попытаться "кликнуть/атаковать" текущую цель
                        if manualTarget and manualTarget.Parent then
                            performLocalAttackIfInRange()
                        else
                            -- если нет цели, попытаться назначить (поиск ближайшей)
                            local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                            if root then
                                local bestChar = nil
                                local bestDist = math.huge
                                for _, plr in ipairs(Players:GetPlayers()) do
                                    if plr ~= player and plr.Character then
                                        local th = plr.Character
                                        local thum = th:FindFirstChildOfClass("Humanoid")
                                        local troot = th:FindFirstChild("HumanoidRootPart")
                                        if thum and troot and thum.Health > 0 then
                                            local dist = (troot.Position - root.Position).Magnitude
                                            if dist < bestDist then
                                                bestChar = th
                                                bestDist = dist
                                            end
                                        end
                                    end
                                end
                                if bestChar then
                                    simulateMouseClickOnCharacter(bestChar)
                                end
                            end
                        end
                    end
                end

                task.wait(0.5)
            end
        end
    end)
end

-- 🔄 Инициализация
showNotification("Автономный режим", "Сценарий активирован. Бот может сам управлять 'цифрами' и 'мышью'.", MESSAGE_DURATION)
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
    warn("[scr.lua] Персонаж не появился за отведённое время — логика будет ждать при необходимости.")
end

-- Получаем mouse и настраиваем ввод
local ok, mouse = pcall(function() return player:GetMouse() end)
if not ok or not mouse then
    warn("[scr.lua] Не удалось получить mouse через player:GetMouse(). Попробуйте другой метод.")
    mouse = nil
end

setupInput(mouse)

-- Запуск процессов
trackWorld()
moveAI()
autoController()  -- включаем автономное управление

-- Обработка выхода/очищения (например, при смене персонажа)
player.CharacterRemoving:Connect(function(char)
    -- очищаем подсветки, связанные с этим Character (и, в целом, все)
    clearAllHighlights()
    -- если мы умерли, humanoid исчезнет; оставляем циклы работать — они будут ждать CharacterAdded
    debugLog("CharacterRemoving: очищены подсветки, логика будет ждать респавна")
end)

player.CharacterAdded:Connect(function(char)
    debugLog("CharacterAdded: персонаж появился — продолжаем работу")
    -- при респавне не стираем авто-настройки, но можно слегка подождать части
    task.wait(0.5)
    -- очистим ручную цель если она была самим собой (на всякий случай)
    if manualTarget and not manualTarget.Parent then
        manualTarget = nil
    end
end)
