-- ⚙️ Настройки скрипта
local MESSAGE_DURATION = 3        -- Время отображения сообщений (секунды)
local MOVEMENT_SPEED = 20         -- Базовая скорость движения (используется как скорость следования к waypoints)
local ATTACK_RANGE = 8            -- Радиус ближнего боя
local AVOIDANCE_DISTANCE = 4      -- Расстояние для Raycast-а впереди
local WORLD_TRACK_INTERVAL = 0.5  -- Интервал в секундах для сканирования мира (обновл. метки/дистанции)
local MOVE_CHECK_INTERVAL = 0.1   -- Интервал в секундах для AI цикла

-- Автономные параметры (бот "сам управляет цифрами и мышью")
local AUTO_MODE_ENABLED = true                -- включает автономные "нажатия"
local AUTO_ACTION_INTERVAL = 2.0              -- как часто бот пытается атаковать/выполнить действие (сек)
local AUTO_TARGET_SELECTION_INTERVAL = 18.0   -- как часто бот выбирает/переназначает цель (сек)
local MANUAL_TARGET_LIFETIME = 20.0           -- сколько секунд бот держит выбранную цель прежде чем реселектить
local KEY_COOLDOWN = 15.0                     -- КД для цифровых "клавиш" (1..6) в секундах

-- 🖥️ Подключение сервисов
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

if not player then
    warn("[scr.lua] LocalPlayer не найден — убедитесь, что этот скрипт запускается как LocalScript.")
    return
end

-- State / флаги
local botEnabled = true
local highlightsEnabled = true
local usePathfinding = true
local notificationsEnabled = true
local attackMode = "auto" -- "auto" или "manual" (бот сам ставит manual при назначении цели)
local manualTarget = nil
local manualTargetSetTime = 0

-- Метки/подсветки
local highlights = {}
local specialMark = nil -- таблица {gui=..., target=Character}

-- КД по цифрам
local lastKeyUse = {} -- lastKeyUse[1..6] = timestamp

-- Утилиты
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

local function debugLog(msg)
    print(("[scr] %s"):format(tostring(msg)))
end

-- Подсветки
local function createOrUpdateHighlight(targetCharacter, color)
    if not targetCharacter or not targetCharacter.PrimaryPart then return end
    local key = tostring(targetCharacter)
    local box = highlights[key]
    if box and box.Parent then
        box.Color3 = color
        box.Adornee = targetCharacter.PrimaryPart
        box.Size = targetCharacter:GetExtentsSize() + Vector3.new(1,1,1)
        return box
    end
    box = Instance.new("BoxHandleAdornment")
    box.Name = "Bot_Highlight"
    box.AlwaysOnTop = true
    box.ZIndex = 10
    box.Color3 = color
    box.Transparency = 0.35
    box.Size = targetCharacter:GetExtentsSize() + Vector3.new(1,1,1)
    box.Adornee = targetCharacter.PrimaryPart
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
        if v and v.Parent then v:Destroy() end
        highlights[k] = nil
    end
end

-- Специальная метка над выбранной целью (BillboardGui с расстоянием)
local function createSpecialMark(targetCharacter)
    if not targetCharacter or not targetCharacter.PrimaryPart then return end
    -- Очистим старую
    if specialMark and specialMark.gui and specialMark.gui.Parent then
        specialMark.gui:Destroy()
        specialMark = nil
    end
    local primary = targetCharacter.PrimaryPart
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "Bot_TargetMark"
    billboard.Adornee = primary
    billboard.Size = UDim2.new(0,200,0,50)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1,0,1,0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.new(1,1,1)
    label.TextStrokeTransparency = 0
    label.TextScaled = true
    label.Font = Enum.Font.SourceSansBold
    label.Text = "Target"
    label.Parent = billboard

    billboard.Parent = primary
    specialMark = { gui = billboard, label = label, target = targetCharacter }
end

local function updateSpecialMarkDistance()
    if not specialMark or not specialMark.target or not specialMark.target.PrimaryPart then
        return
    end
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local troot = specialMark.target.PrimaryPart
    if root and troot then
        local dist = (troot.Position - root.Position).Magnitude
        specialMark.label.Text = string.format("Target | %.1fm", math.floor(dist * 10)/10)
    else
        specialMark.label.Text = "Target"
    end
end

local function clearSpecialMark()
    if specialMark and specialMark.gui and specialMark.gui.Parent then
        specialMark.gui:Destroy()
    end
    specialMark = nil
end

-- Поиск игрока/Character по Descendant (не используется для ручного клика сейчас, но полезно)
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

-- Симуляция "нажатия" цифровой клавиши (1..6) с КД
local function simulateKeyAction(keyNumber)
    if keyNumber < 1 or keyNumber > 6 then return end
    local now = os.clock()
    local last = lastKeyUse[keyNumber] or 0
    if now - last < KEY_COOLDOWN then
        debugLog(("Клавиша %d на КД (%.1fs left)"):format(keyNumber, KEY_COOLDOWN - (now - last)))
        return false
    end
    lastKeyUse[keyNumber] = now
    -- безопасные логические действия вместо реального ввода
    if keyNumber >=1 and keyNumber <=3 then
        -- стандартная атака слот 1..3
        showNotification("Автоклавиша", ("Клавиша %d -> атака"):format(keyNumber), 1)
        debugLog("simulateKeyAction: attack slot " .. tostring(keyNumber))
    elseif keyNumber == 4 then
        showNotification("Автоклавиша", "Клавиша 4 -> спецатака (лог)", 1)
        debugLog("simulateKeyAction: special attack (4)")
    elseif keyNumber == 5 then
        showNotification("Автоклавиша", "Клавиша 5 -> попытка использовать Heal (лог)", 1)
        debugLog("simulateKeyAction: use heal (5) [not implemented]")
    elseif keyNumber == 6 then
        showNotification("Автоклавиша", "Клавиша 6 -> таунт (лог)", 1)
        debugLog("simulateKeyAction: taunt (6) [not implemented]")
    end
    return true
end

-- Эмуляция физического ввода для атаки: LMB или одна из цифр 1..6 (учитываются КД)
local function simulatePhysicalInputForAttack()
    -- Попытка выбрать цифру (40%) или LMB (60%)
    local pickDigit = (math.random() < 0.4)
    if pickDigit then
        -- Пытаемся выбрать случайную цифру с доступным КД
        local candidates = {}
        for i=1,6 do
            local last = lastKeyUse[i] or 0
            if os.clock() - last >= KEY_COOLDOWN then
                table.insert(candidates, i)
            end
        end
        if #candidates > 0 then
            local idx = candidates[math.random(1, #candidates)]
            local ok = simulateKeyAction(idx)
            if ok then return end
            -- fallthrough to LMB if somehow failed
        end
        -- если нет доступных цифр, делаем LMB
    end
    -- LMB simulated
    showNotification("Авто-клик", "Эмуляция LMB -> атака", 1)
    debugLog("simulatePhysicalInputForAttack -> simulated LMB")
end

-- Локальная имитация атаки (визуальная/логирование) — вызывает эмуляцию ввода
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
        simulatePhysicalInputForAttack()
        -- При необходимости: отправка RemoteEvent/анимации и т.д.
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

    local success2, err2 = pcall(function()
        humanoid:MoveTo(position)
    end)
    if not success2 then
        if conn then conn:Disconnect() end
        return false
    end

    timeout = timeout or 3.0
    local elapsed = 0
    while elapsed < timeout do
        if reached then break end
        if not humanoid.Parent then break end
        task.wait(0.1)
        elapsed = elapsed + 0.1
    end

    if conn then conn:Disconnect() end
    return reached
end

-- moveAI: учитывает botEnabled; движение/поиск цели/избегание
local function moveAI()
    task.spawn(function()
        while true do
            local ok, err = pcall(function()
                -- Ждём необходимое состояние Character -> humanoid -> HRP
                local char = player.Character
                local humanoid = char and char:FindFirstChildOfClass("Humanoid")
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if not (char and humanoid and root) then
                    task.wait(0.2)
                    return
                end

                -- При выключенном боте — не двигаться
                if not botEnabled then
                    task.wait(MOVE_CHECK_INTERVAL)
                    return
                end

                -- Если цель умерла — очистить
                if manualTarget and (not manualTarget.Parent or (manualTarget:FindFirstChildOfClass("Humanoid") and manualTarget:FindFirstChildOfClass("Humanoid").Health <= 0)) then
                    clearManualTarget()
                    clearSpecialMark()
                end

                local bestTargetChar = nil
                if manualTarget and manualTarget.Parent then
                    bestTargetChar = manualTarget
                else
                    -- если нет ручной цели — moveAI не выбирает новую; autoController делает выбор
                end

                -- избегание препятствий
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

                if bestTargetChar and bestTargetChar:FindFirstChild("HumanoidRootPart") then
                    local targetPos = bestTargetChar.HumanoidRootPart.Position
                    local distToTarget = (targetPos - root.Position).Magnitude
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
                            local ok2, err2 = pcall(function() path:ComputeAsync(root.Position, targetPos) end)
                            if ok2 and path.Status == Enum.PathStatus.Success then
                                local waypoints = path:GetWaypoints()
                                for _, waypoint in ipairs(waypoints) do
                                    if not bestTargetChar.Parent then break end
                                    safeMoveTo(humanoid, waypoint.Position, 2.0)
                                    task.wait(0.02)
                                    if not humanoid.Parent then break end
                                end
                            else
                                safeMoveTo(humanoid, targetPos, 2.0)
                            end
                        else
                            safeMoveTo(humanoid, targetPos, 2.0)
                        end
                    end
                else
                    -- нет цели — идём немного вперед
                    local forwardPos = root.Position + (root.CFrame.LookVector * MOVEMENT_SPEED)
                    safeMoveTo(humanoid, forwardPos, 1.0)
                end
            end)
            if not ok then
                warn("[scr.lua] Ошибка в moveAI: " .. tostring(err))
            end
            task.wait(MOVE_CHECK_INTERVAL)
        end
    end)
end

-- trackWorld: обновляет подсветки и special mark (дистанция)
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
                        else
                            removeHighlightForCharacter(char)
                        end
                    end
                end

                -- обновление special mark distance
                updateSpecialMarkDistance()
            end)
            if not ok then
                warn("[scr.lua] Ошибка в trackWorld: " .. tostring(err))
            end
            task.wait(WORLD_TRACK_INTERVAL)
        end
    end)
end

-- autoController: выбирает цель и инициирует атаки (учитывает botEnabled)
local function autoController()
    task.spawn(function()
        local lastSelection = 0
        local lastAction = 0
        while true do
            if not AUTO_MODE_ENABLED then
                task.wait(1.0)
            else
                local now = os.clock()
                -- выбор цели раз в AUTO_TARGET_SELECTION_INTERVAL или когда цель отсутствует/просрочена
                if botEnabled and (not manualTarget or (now - manualTargetSetTime) >= MANUAL_TARGET_LIFETIME or (manualTarget and (not manualTarget.Parent or (manualTarget:FindFirstChildOfClass("Humanoid") and manualTarget:FindFirstChildOfClass("Humanoid").Health <= 0)))) then
                    if now - lastSelection >= AUTO_TARGET_SELECTION_INTERVAL then
                        lastSelection = now
                        -- выберем ближайшую или с низким HP
                        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                        if root then
                            local bestChar = nil
                            local bestDist = math.huge
                            for _, plr in ipairs(Players:GetPlayers()) do
                                if plr ~= player and plr.Character then
                                    local tch = plr.Character
                                    local thum = tch:FindFirstChildOfClass("Humanoid")
                                    local troot = tch:FindFirstChild("HumanoidRootPart")
                                    if thum and troot and thum.Health > 0 then
                                        local dist = (troot.Position - root.Position).Magnitude
                                        if thum.Health <= 50 or dist < bestDist then
                                            bestChar = tch
                                            bestDist = dist
                                        end
                                    end
                                end
                            end
                            if bestChar then
                                manualTarget = bestChar
                                manualTargetSetTime = now
                                attackMode = "manual"
                                createSpecialMark(manualTarget)
                                showNotification("Авто-цель", "Назначена цель: " .. (Players:GetPlayerFromCharacter(bestChar) and Players:GetPlayerFromCharacter(bestChar).Name or "Unknown"), 3)
                                debugLog("autoController: new manualTarget set")
                            end
                        end
                    end
                end

                -- действие (атака) каждые AUTO_ACTION_INTERVAL, но только если бот включён и есть цель
                if botEnabled and manualTarget and manualTarget.Parent and (now - lastAction) >= AUTO_ACTION_INTERVAL then
                    lastAction = now
                    -- если цель в зоне атаки - атакуем (performLocalAttackIfInRange)
                    performLocalAttackIfInRange()
                    -- если цель вне зоны, moveAI будет идти к ней
                end

                -- если цель просрочена по времени — очистить ее (и special mark)
                if manualTarget and (os.clock() - manualTargetSetTime) >= MANUAL_TARGET_LIFETIME then
                    clearManualTarget()
                    clearSpecialMark()
                    debugLog("autoController: manualTarget lifetime expired -> cleared")
                end

                task.wait(0.2)
            end
        end
    end)
end

-- Обработка ввода: только F для включить/выключить бота (не меняем подсветку/режим атаки при этом)
local function setupInput()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            if input.KeyCode == Enum.KeyCode.F then
                botEnabled = not botEnabled
                showNotification("Бот", botEnabled and "Включён" or "Выключен")
                debugLog("botEnabled -> " .. tostring(botEnabled))
                -- при отключении бот не изменяет highlightsEnabled или attackMode — они сохраняются
                if not botEnabled then
                    -- при выключении прекращаем атаки/действия; оставляем manualTarget и метку (по желанию можно очистить)
                    debugLog("Бот отключён: автоконтроль и движение приостановлены")
                else
                    debugLog("Бот включён: автоконтроль и движение возобновлены")
                end
            end
        end
    end)
end

-- Инициализация
showNotification("Автономный режим", "Сценарий активирован. Нажмите F для вкл/выкл бота.", MESSAGE_DURATION)
debugLog("Сценарий начал работу!")

-- wait for character (не останавливаем все циклы при отсутствии персонажа)
local function waitForCharacter(timeout)
    local elapsed = 0
    while (not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") or not player.Character:FindFirstChildOfClass("Humanoid")) and elapsed < (timeout or 10) do
        task.wait(0.2)
        elapsed = elapsed + 0.2
    end
    return player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChildOfClass("Humanoid")
end

waitForCharacter(10) -- продолжаем даже если не успело

-- Запуск основных задач
trackWorld()
moveAI()
autoController()
setupInput()

-- Обработчики respawn
player.CharacterRemoving:Connect(function(char)
    clearAllHighlights()
    clearSpecialMark()
    debugLog("CharacterRemoving: очищены подсветки и метки; логика будет ждать респавн")
end)

player.CharacterAdded:Connect(function(char)
    debugLog("CharacterAdded: персонаж появился — продолжаем работу")
    task.wait(0.5)
end)
