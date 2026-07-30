-- Passive Observer Killer v3: Dynamic Profiler & Sandbox Mode
local function Init()
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local UserInputService = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    
    -- === НАСТРОЙКИ ===
    local player = Players.LocalPlayer
    local mouse = player:GetService("Mouse")
    local character = player.Character or player.CharacterAdded:Wait()
    local rootPart = character and character.PrimaryPart
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")

    -- Минимальная пауза между ударами (секунды)
    local ATTACK_COOLDOWN = 0.7  
    -- Таймстамп последней успешной атаки
    local LastAttackTime = tick()   
    -- Текущая цель игрока
    local Target = nil                
    -- База знаний: [RemoteName] -> {remoteObj, bestPayload, maxDamage}
    local DamageLibrary = {}          
    -- Флаг наблюдения за всеми событиями
    local isProfiling = false        
    -- Последнее известное здоровье цели
    local lastKnownHealth = 0       
    -- Отключает всплывающие уведомления
    local NotificationsEnabled = true 

    -- Вспомогательные функции
    local function n(text) 
        if not NotificationsEnabled then return end
        pcall(function() 
            game.StarterGui:SetCore("SendNotification", {
                Title = "[Profiler]", Text = text, Duration = 2}) 
        end) 
    end

    -- Поиск цели под курсором
    local function getTarget()
        if not mouse.Target then return nil end
        local char = mouse.Target:FindFirstAncestorWhichIsA("Model")
        if not char then return nil end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 and char ~= character then return {Char = char, Hum = hum} end
        return nil
    end

    -- Генерация тестовых пакетов для пробива защиты
    local function generateTestPackets(target)
        return {
            target.Name,
            target.Hum,
            {Victim = target.Name, Dmg = math.huge},
            {["player"] = player, ["enemy"] = target.Char},
            "GodWeapon_Debug",
            target.Name .. "_DEBUG"
        }
    end

    -- Сбор всех потенциальных точек нанесения урона
    local function collectWeapons()
        local weapons = {}

        -- Ищем RemoteEvents во всех стандартных местах
        for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
            if obj:IsA("RemoteEvent") then table.insert(weapons, obj) end
        end
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("RemoteEvent") then table.insert(weapons, obj) end
        end

        -- Ищем вызовы событий внутри клиентских скриптов (LocalScripts)
        -- Это важно! Часто разработчики прячут эвенты внутри функций, а не просто оставляют их висящими в RS/WS.
        for _, script in ipairs(game:GetService("Lighting"):GetChildren()) do
            if script:IsA("LocalScript") then
                local src = script.Source
                for _, remote in ipairs(weapons) do
                    -- Проверяем, есть ли вызов этого события в скрипте
                    if string.find(src, "%."..remote.Name..":FireServer%(", 1, true) then
                        -- Если нашли — помечаем его как потенциально опасный
                        table.insert(weapons, remote)
                    end
                end
            end
        end

        return weapons
    end

    -- Профилирование одного конкретного RemoteEvent или TouchTrigger
    local function profile(remoteData)
        if not Target then return end

        local victimHum = Target.Hum
        local currentHealth = victimHum.Health

        -- Пробуем разные форматы данных
        local payloads = #DamageLibrary[remoteData.Name] == 0 and generateTestPackets(Target) or {DamageLibrary[remoteData.Name].bestPayload}

        for i, data in ipairs(payloads) do
            -- Отправляем пакет
            pcall(function() remoteData.remoteObj:FireServer(data) end)
            
            task.wait(0.05) -- Даем серверу время обработать урон

            -- Смотрим результат
            local delta = currentHealth - victimHum.Health
            if delta <= 0 then continue end

            -- Обновление базы знаний
            local entry = DamageLibrary[remoteData.Name]
            if not entry or delta > entry.maxDamage then
                DamageLibrary[remoteData.Name] = {
                    remoteObj = remoteData.remoteObj,
                    bestPayload = data,
                    maxDamage = delta
                }
                print("[LOG] New Best Weapon:", remoteData.remoteObj:GetFullName(), "| Payload Type:", typeof(data))
            end

            -- Восстанавливаем здоровье цели после теста
            if victimHum.Health < currentHealth then
                pcall(function() victimHum.Health = currentHealth end)
            end
        end
    end

    -- === ПАССИВНОЕ НАБЛЮДЕНИЕ ЗА ВСЕМИ СОБЫТИЯМИ В ИГРЕ ===
    -- Этот цикл работает всегда с момента запуска
    task.spawn(function()
        while wait(1) do -- Обновляем список раз в секунду
            local allRemotes = collectWeapons()

            -- Подписываемся на КАЖДОЕ событие в игре
            for _, r in ipairs(allRemotes) do
                -- Пропускаем уже подключенные
                if rawget(DamageLibrary, r.Name) then continue end

                r.OnClientEvent:Connect(function(arg1, arg2, arg3, arg4)
                    -- Игнорируем собственные запросы
                    if debug.info(2, "f") == Init then return end

                    -- Собираем аргументы
                    local args = {arg1, arg2, arg3, arg4}
                    
                    -- Ищем жертву среди аргументов
                    local potentialVictim = nil
                    for _, v in ipairs(args) do
                        if typeof(v) == "string" then
                            local plr = Players:FindFirstChild(v)
                            if plr and plr.Character and plr.Character:FindFirstChildOfClass("Humanoid") then
                                potentialVictim = plr.Character
                                break
                            end
                        elseif typeof(v) == "Instance" and v:IsA("Humanoid") then
                            potentialVictim = v.Parent
                            break
                        end
                    end

                    -- Анализируем изменение здоровья
                    if potentialVictim then
                        local victimHum = potentialVictim:FindFirstChildOfClass("Humanoid")
                        local healthBefore = victimHum.Health
                        
                        -- Ждем один кадр для получения точного результата
                        RunService.RenderStepped:Wait()
                        local delta = healthBefore - victimHum.Health

                        if delta > 0 then
                            -- Записали самый мощный способ использования этого эвента
                            DamageLibrary[r.Name] = {
                                remoteObj = r,
                                bestPayload = args,
                                maxDamage = delta
                            }
                            print("[LOG] Weapon Found:", r:GetFullName(), "| Dmg:", delta)
                        else
                            -- Иногда урон может быть отрицательным из-за регенерации
                            -- Мы игнорируем такие случаи
                        end
                    end
                end)
            end
        end
    end)

    -- === АВТОМАТИЧЕСКИЙ БОЙ ПО ЛКМ ===
    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end

        -- Выбор цели ПКМ (для удобства)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            Target = getTarget()
            if Target then
                lastKnownHealth = Target.Hum.Health
                n("Target locked: " .. Target.Char.Name)
            else
                n("Target cleared.")
            end
        end

        -- АТАКУЕМ ПО ЛКМ
        if input.UserInputType == Enum.UserInputType.MouseButton1 and not isProfiling then
            local now = tick()

            -- Анти-спам с динамической адаптацией задержки
            if now - LastAttackTime < ATTACK_COOLDOWN then 
                n("Cooldown active ("..math.floor((ATTACK_COOLDOWN - (now - LastAttackTime)) * 10 + 0.5)/10.."s)")
                -- Если система продолжает ругаться, увеличиваем паузу
                ATTACK_COOLDOWN = math.min(ATTACK_COOLDOWN + 0.1, 1.5)
            else
                -- Сбрасываем задержку до дефолтной
                ATTACK_COOLDOWN = 0.7
            end

            -- Основной алгоритм удара
            if not Target or Target.Hum.Health <= 0 then 
                n("Select a target first (RMB).")
                return 
            end

            -- Если база знаний пуста (мы никого не видели дерущимся)
            if next(DamageLibrary) == nil then
                n("Observing... Sending test packets.")
                local allRemotes = collectWeapons()
                for _, r in ipairs(allRemotes) do
                    pcall(function() r:FireServer(Target.Name) end)
                    task.wait(0.03) -- Небольшой интервал для избежания мгновенного баннера
                end
                return
            end

            -- Выбираем самое мощное оружие из библиотеки
            local BestWeaponData = nil
            for _, data in pairs(DamageLibrary) do
                if not BestWeaponData or data.maxDamage > BestWeaponData.maxDamage then
                    BestWeaponData = data
                end
            end

            if BestWeaponData then
                n("Firing best vector ("..BestWeaponData.remoteObj.Name..")")
                pcall(function() BestWeaponData.remoteObj:FireServer(unpack(BestWeaponData.bestPayload)) end)
                LastAttackTime = tick() -- Обновляем таймер
            else
                n("Error: No weapon selected.")
            end
        end
    end)

    -- === РЕЖИМ ПЕСОЧНИЦЫ (Sandbox Mode): Автоматический сбор информации ===
    -- Этот режим заставляет вашего персонажа бегать по карте и кликать мышью,
    -- что помогает найти хит-боксы и скрытые триггеры.
    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end

        -- F9: Включить/выключить Песочницу
        if input.KeyCode == Enum.KeyCode.F9 then
            isProfiling = not isProfiling
            n(isProfiling and "Sandbox mode ON" or "Sandbox mode OFF")
        end
    end)

    -- Логика песочницы
    task.spawn(function()
        while wait() do
            if not isProfiling then continue end

            -- Перемещаемся по карте
            if rootPart then
                local newPos = Vector3.new(math.random(-workspace.Terrain.Size.X / 2, workspace.Terrain.Size.X / 2),
                                          10, -- Высота над землей
                                          math.random(-workspace.Terrain.Size.Z / 2, workspace.Terrain.Size.Z / 2))
                rootPart.CFrame = CFrame.new(newPos)
                task.wait(0.1)
                humanoid.Jump = true -- Имитация активности
            end

            -- Случайно кликаем мышкой
            firetouchinterest(rootPart, mouse.Target, 0)
            task.wait(0.1)
            firetouchinterest(rootPart, mouse.Target, 1)

            -- Тестируем все найденные Remotes
            local remotes = collectWeapons()
            for _, r in ipairs(remotes) do
                profile({remoteObj = r})
            end

            -- Пауза перед следующим кругом сбора данных
            task.wait(5)
        end
    end)

    -- === УПРАВЛЕНИЕ ИНТЕРФЕЙСОМ ===
    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end

        -- NUMPAD0: Включить/выключить уведомления
        if input.KeyCode == Enum.KeyCode.KeypadZero then
            NotificationsEnabled = not NotificationsEnabled
            n(NotificationsEnabled and "Notifications enabled" or "Notifications disabled")
        end
    end)

    -- Визуализация цели
    local hl = nil
    RunService.RenderStepped:Connect(function()
        if Target and Target.Hum.Health > 0 then
            if not hl then
                hl = Instance.new("BoxHandleAdornment", workspace.CurrentCamera)
                hl.AlwaysOnTop = true; hl.ZIndex = 10; hl.Transparency = 0.7;
            end
            hl.Adornee = Target.Char
            hl.Size = Target.Char:GetExtentsSize() + Vector3.new(0.2, 0.2, 0.2)
            hl.Color3 = Color3.fromRGB(0, 255, 0)
        elseif hl then
            hl:Destroy(); hl = nil
        end
    end)

    n"[Profiler v3] Ready. [RMB]=Lock Target | [LMB]=Kill | [F9]=Sandbox Mode | [NUMPAD0]=Toggle Notifs")
end

pcall(Init)
