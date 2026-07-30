-- Hitbox Replicator v1: Physical Damage Profiler
local function Init()
    local Players = game.GetService(game, "Players")
    local UserInputService = game.GetService(game, "UserInputService") -- Защита от nil
    local RunService = game:GetService("RunService")
    
    -- === НАСТРОЙКИ И ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ ===
    local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
    if not player then return end

    local character = nil
    local rootPart = nil
    local humanoid = nil
    local mouse = nil

    -- База знаний: [ModelName] -> {Hitbox, RemoteObj, Payload}
    local HitLibrary = {}
    -- Текущая цель игрока
    local Target = nil                
    -- Флаг наблюдения за всеми событиями
    local isProfiling = true          -- Включаем авто-поиск сразу
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
    local function generateTestPackets(hitbox)
        return {
            hitbox.Parent.Name,
            hitbox.Parent,
            {Victim = hitbox.Parent.Name},
            {["player"] = player, ["weapon"] = hitbox.Parent},
            "GodWeapon_Debug",
            hitbox.Parent.Name .. "_DEBUG"
        }
    end

    -- Сбор всех потенциальных хитбоксов
    local function collectHits()
        local hits = {}

        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Transparency >= 0.9 and not obj.CanCollide then
                table.insert(hits, obj)
            end
        end

        -- Дополнительно проверяем оружие других игроков
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Character then
                for _, tool in ipairs(plr.Character:GetChildren()) do
                    if tool:IsA("Tool") then
                        for _, part in ipairs(tool:GetDescendants()) do
                            if part:IsA("BasePart") and part.Transparency >= 0.9 and not part.CanCollide then
                                table.insert(hits, part)
                            end
                        end
                    end
                end
            end
        end

        return hits
    end

    -- Профилирование одного конкретного хитбокса
    local function profile(hitData)
        if not Target then return end

        local victimHum = Target.Hum
        local currentHealth = victimHum.Health

        -- Пробуем отправить лучший известный пакет данных
        local payloads = #HitLibrary[hitData.Part.Parent.Name] == 0 and generateTestPackets(hitData.Part) or {HitLibrary[hitData.Part.Parent.Name].Payload}

        for i, data in ipairs(payloads) do
            -- Отправляем пакет
            pcall(function() hitData.Remote:FireServer(data) end)
            
            task.wait(0.15) -- Защита от анти-спам систем игры

            -- Смотрим результат
            local delta = currentHealth - victimHum.Health
            if delta <= 0 then continue end

            -- Обновление базы знаний
            local entry = HitLibrary[hitData.Part.Parent.Name]
            if not entry or delta > entry.maxDamage then
                HitLibrary[hitData.Part.Parent.Name] = {
                    Hitbox = hitData.Part,
                    Remote = hitData.Remote,
                    Payload = data,
                    maxDamage = delta
                }
                print("[LOG] New Best Weapon:", hitData.Part.Parent.Name, "| Dmg:", delta)
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

            -- Основной алгоритм удара
            if next(HitLibrary) == nil then
                n("Observing... Sending test packets.")
                local allHits = collectHits()
                for _, h in ipairs(allHits) do
                    pcall(function() h.Touched:Fire(Target.Char.PrimaryPart) end) -- Имитация физического контакта
                    task.wait(0.03)
                end
                return
            end

            -- Выбираем самое мощное оружие из библиотеки
            local BestWeaponData = nil
            for name, data in pairs(HitLibrary) do
                if not BestWeaponData or data.maxDamage > BestWeaponData.maxDamage then
                    BestWeaponData = data
                end
            end

            if BestWeaponData then
                -- Создаём фантомную копию хитбокса
                local phantom = Instance.new("Part", workspace)
                phantom.Anchored = true
                phantom.CanCollide = false
                phantom.Size = Vector3.new(1, 1, 1)
                phantom.CFrame = Target.Char.PrimaryPart.CFrame * CFrame.new(0, 0.8, 0) -- Над головой

                -- Подключаем к нему ту же логику
                phantom.Touched:Connect(function(targ)
                    if targ == Target.Char.PrimaryPart then
                        pcall(function() BestWeaponData.Remote:FireServer(BestWeaponData.Payload) end)
                    end
                end)

                -- Имитируем контакт
                firetouchinterest(phantom, Target.Char.PrimaryPart, 0)
                wait(0.1)
                firetouchinterest(phantom, Target.Char.PrimaryPart, 1)
                phantom:Destroy()

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

    -- === РЕЖИМ АВТО-ПОИСКА ХИТБОКСОВ ===
    task.spawn(function()
        while wait(1) do -- Обновляем список раз в секунду
            local allHits = collectHits()

            -- Подписываемся на КАЖДЫЙ хитбокс в игре
            for _, hit in ipairs(allHits) do
                -- Пропускаем уже изученные
                if rawget(HitLibrary, hit.Parent.Name) then continue end

                -- Находим связанный с ним RemoteEvent
                local remote = nil
                local script = hit.Parent:FindFirstChildWhichIsA("LocalScript") or hit.Parent.Parent:FindFirstChildWhichIsA("LocalScript")
                if script then
                    local src = script.Source
                    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
                        if obj:IsA("RemoteEvent") and string.find(src, "%."..obj.Name..":FireServer%(", 1, true) then
                            remote = obj
                            break
                        end
                    end
                end

                if remote then
                    hit.Touched:Connect(function(targ)
                        -- Игнорируем собственные запросы
                        if debug.info(2, "f") == Init then return end

                        local potentialVictim = nil
                        if typeof(targ) == "Instance" and targ.Parent then
                            local plr = Players:GetPlayerFromCharacter(targ.Parent)
                            if plr and plr.Character and plr.Character:FindFirstChildOfClass("Humanoid") then
                                potentialVictim = plr.Character
                            end
                        end

                        if potentialVictim then
                            local victimHum = potentialVictim:FindFirstChildOfClass("Humanoid")
                            local healthBefore = victimHum.Health
                            
                            -- Ждём один кадр для получения точного результата
                            RunService.RenderStepped:Wait()
                            local delta = healthBefore - victimHum.Health

                            if delta > 0 then
                                -- Записали самый мощный способ использования этого хитбокса
                                HitLibrary[hit.Parent.Name] = {
                                    Hitbox = hit,
                                    Remote = remote,
                                    Payload = {},
                                    maxDamage = delta
                                }
                                print("Found Hitbox:", hit.Parent.Name, "| Linked to:", remote.Name, "| Dmg:", delta)
                            end
                        end
                    end)
                end
            end
        end
    end)

    -- === МЕТОД ЗАГРУЗКИ ПЕРСОНАЖА ===
    local function AwaitCharacter()
        repeat
            character = player.Character or player.CharacterAdded:Wait()
            rootPart = character.PrimaryPart
            humanoid = character:FindFirstChildOfClass("Humanoid")
            mouse = player:GetMouse()
            wait(1) -- Даем объектам стабилизироваться
        until rootPart and humanoid and mouse

        nProfiler v4 loaded. Use F to select target, LMB to attack.)
    end

    -- Запускаем ожидание в корутине
    task.spawn(AwaitCharacter)
end

pcall(Init)
