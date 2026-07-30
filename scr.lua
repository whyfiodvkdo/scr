-- Passive Observer Killer v4: Dynamic Profiler & Sandbox Mode
local function Init()
    local Players = game:GetService("Players")
    local UserInputService = game.GetService(game, "UserInputService") -- Защита от nil
    local RunService = game:GetService("RunService")
    
    -- === НАСТРОЙКИ И ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ ===
    local player = Players.LocalPlayer or Players.PlayerAdded:Wait()  -- Ждём игрока
    if not player then return end

    local character = nil
    local rootPart = nil
    local humanoid = nil
    local mouse = nil

    -- Минимальная пауза между ударами (секунды). Динамически адаптируется.
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
        if not mouse or not mouse.Target then return nil end
        local char = mouse.Target:FindFirstAncestorWhichIsA("Model")
        if not char then return nil end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 and char ~= character then return {Char = char, Hum = hum} end
        return nil
    end

    -- Генерация тестовых пакетов данных
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

        -- Ищем вызовы событий внутри клиентских скриптов (LocalScripts).
        -- Это критически важно! Многие игровые механики реализованы именно так.
        for _, script in ipairs(game.Lighting:GetChildren()) do
            if script:IsA("LocalScript") then
                local src = script.Source
                for _, remote in ipairs(weapons) do
                    -- Проверяем, есть ли вызов этого события в скрипте
                    if string.find(src, "%."..remote.Name..":FireServer%(", 1, true) then
                        table.insert(weapons, remote)
                    end
                end
            end
        end

        return weapons
    end

    -- Профилирование одного конкретного RemoteEvent
    local function profile(remoteData)
        if not Target then return end

        local victimHum = Target.Hum
        local currentHealth = victimHum.Health

        -- Пробуем отправить лучший известный пакет данных
        local payloads = #DamageLibrary[remoteData.Name] == 0 and generateTestPackets(Target) or {DamageLibrary[remoteData.Name].bestPayload}

        for i, data in ipairs(payloads) do
            -- Отправляем пакет
            pcall(function() remoteData.remoteObj:FireServer(data) end)
            
            task.wait(0.15) -- Защита от анти-спама Roblox

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
        end
    end

    -- === ЦЕНТРАЛИЗОВАННЫЙ ОБРАБОТЧИК ВСЕХ КЛАВИШ ===
    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end

        -- Выбор цели клавишей F
        if input.KeyCode == Enum.KeyCode.F then
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
            if not character or not Target or Target.Hum.Health <= 0 then 
                n("Select a target first (F key).")
                return 
            end

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

        -- Управление режимом Песочницы
        if input.KeyCode == Enum.KeyCode.F1 then
            isProfiling = not isProfiling
            n(isProfiling and "Sandbox mode ON" or "Sandbox mode OFF")
        end

        -- Отключение уведомлений
        if input.KeyCode == Enum.KeyCode.F3 then
            NotificationsEnabled = not NotificationsEnabled
            n(NotificationsEnabled and "Notifications enabled" or "Notifications disabled")
        end
    end)

    -- === ПАССИВНОЕ НАБЛЮДЕНИЕ ЗА СОБЫТИЯМИ ===
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
                            print("Weapon Found:", r:GetFullName(), "| Dmg:", delta)
                        end
                    end
                end)
            end
        end
    end)

    -- === РЕЖИМ ПЕСОЧНИЦЫ (Sandbox Mode): Автоматический сбор информации ===
    task.spawn(function()
        while wait() do
            if not isProfiling then continue end

            -- Ожидание загрузки персонажа
            repeat
                character = player.Character or player.CharacterAdded:Wait()
                rootPart = character.PrimaryPart
                humanoid = character:FindFirstChildOfClass("Humanoid")
                mouse = player:GetMouse()
                wait(1) -- Даем объектам стабилизироваться
            until rootPart and humanoid and mouse

            -- Перемещаемся по карте
            local newPos = Vector3.new(
                math.random(-workspace.Terrain.Size.X / 2, workspace.Terrain.Size.X / 2),
                10, -- Высота над землей
                math.random(-workspace.Terrain.Size.Z / 2, workspace.Terrain.Size.Z / 2)
            )
            rootPart.CFrame = CFrame.new(newPos)
            task.wait(0.1)
            humanoid.Jump = true -- Имитация активности

            -- Случайные клики мышкой только если у нас есть цель
            if Target then
                firetouchinterest(rootPart, Target.Char.PrimaryPart, 0)
                task.wait(0.1)
                firetouchinterest(rootPart, Target.Char.PrimaryPart, 1)
            end

            -- Тестируем все найденные Remotes
            local remotes = collectWeapons()
            for _, r in ipairs(remotes) do
                profile({remoteObj = r})
            end

            -- Пауза перед следующим кругом сбора данных
            task.wait(5)
        end
    end)

    -- === ВИЗУАЛИЗАЦИЯ ЦЕЛИ ===
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

    -- === МЕТОД ЗАГРУЗКИ ПЕРСОНАЖА ===
    -- Этот метод гарантирует, что ни одна функция не будет вызвана раньше времени.
    local function AwaitCharacter()
        repeat
            character = player.Character or player.CharacterAdded:Wait()
            rootPart = character.PrimaryPart
            humanoid = character:FindFirstChildOfClass("Humanoid")
            mouse = player:GetMouse()
            wait(1) -- Даем объектам стабилизироваться
        until rootPart and humanoid and mouse

        n("Profiler v4 loaded. Use F to select target, LMB to attack.")
    end

    -- Запускаем ожидание в корутине, чтобы не блокировать выполнение loadstring
    task.spawn(AwaitCharacter)
end

pcall(Init)
