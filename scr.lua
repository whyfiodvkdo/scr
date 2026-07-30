local function Init()
    local Players = game.GetService(game, "Players")
    local ReplicatedStorage = game.GetService(game, "ReplicatedStorage")
    local UserInputService = game.GetService("UserInputService")
    local RunService = game:GetService("RunService")
    
    -- === НАСТРОЙКИ И ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ ===
    local player = Players.LocalPlayer or Players.PlayerAdded:Wait() -- Ждём игрока
    if not player then return end

    local character = player.Character or player.CharacterAdded:Wait()
    local rootPart = character.PrimaryPart
    local humanoid = character:FindFirstChildOfClass("Humanoid") 
    local mouse = player:GetMouse()

    -- Минимальная пауза между ударами (секунды). Динамически адаптируется.
    local ATTACK_COOLDOWN = 0.7  
    -- Таймстамп последней успешной атаки
    local LastAttackTime = tick()   
    -- Текущая цель игрока
    local Target = nil                
    -- База знаний: [RemoteName] -> {remoteObj, bestPayload, maxDamage}
    local DamageLibrary = {}          
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
        if not mouse.Target then return nil end
        local char = mouse.Target:FindFirstAncestorWhichIsA("Model")
        if not char then return nil end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 and char ~= character then return {Char = char, Hum = hum} end
        return nil
    end

    -- Генерация тестовых пакетов для "пробива" защиты (когда библиотека пуста)
    local function generateTestPackets(target)
        return {
            target.Name,
            target.Hum,
            {Victim = target.Name, Dmg = math.huge},
            {Target = target.Char, Value = math.huge}
        }
    end

    -- Сбор всех RemoteEvent в игре
    local function findAllRemotes()
        local remotes = {}
        for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
            if obj:IsA("RemoteEvent") then table.insert(remotes, obj) end
        end
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("RemoteEvent") then table.insert(remotes, obj) end
        end
        return remotes
    end

    --- ⚙️⚙️ МОИ ДОБАВКИ ⚙️⚙️ ---

    -- 🔨 Сбор всех потенциальных физических триггеров (хитбокс-деталей)
    local function collectHits()
        local hits = {}
        
        -- Ищем во всей рабочей области
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("BasePart") and obj.Transparency >= 0.95 and not obj.CanCollide then
                table.insert(hits, {Part = obj})
            end
        end

        -- Дополнительно ищем в моделях других игроков (их оружие)
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Character then
                for _, tool in ipairs(plr.Character:GetChildren()) do
                    if tool:IsA("Tool") or string.find(tool.Name, "Weapon", 1, true) then
                        for _, part in ipairs(tool:GetDescendants()) do
                            if part:IsA("BasePart") and part.Transparency >= 0.95 and not part.CanCollide then
                                table.insert(hits, {
                                    Part = part,
                                    ToolName = tool.Name
                                })
                            end
                        end
                    end
                end
            end
        end

        return hits
    end

    -- 🔨 Профилирование одного RemoteEvent + связанного Hitbox'а
    local function profile(remoteData)
        if not Target then return end

        local victimHum = Target.Hum
        local currentHealth = victimHum.Health

        -- Пробуем отправить лучший известный пакет данных
        local payloads = #DamageLibrary[remoteData.Name] == 0 and generateTestPackets(Target.Char) or {DamageLibrary[remoteData.Name].bestPayload}

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
                    maxDamage = delta,
                    hitbox = remoteData.Part -- Запоминаем связанный хит
                }
                print("[LOG] New Best Weapon:", remoteData.remoteObj.Name, "| Payload Type:", typeof(data))
            end
        end
    end

    --- ⚙️⚙️ КОНЕЦ МОИХ ДОБАВОК ⚙️⚙️ ---

    -- === 1. ПАССИВНОЕ НАБЛЮДЕНИЕ ЗА СЕРВЕРОМ ===
    -- Этот цикл работает всегда с самого запуска
    task.spawn(function()
        while true do
            local allRemotes = findAllRemotes()
            local allHits = collectHits() -- <--- Добавил сканирование хитбоксов

            -- Вешаем слушателя на КАЖДЫЙ эвент
            for _, remote in ipairs(allRemotes) do
                -- Проверяем, не подключали ли мы уже этот эвент ранее
                if not rawget(DamageLibrary, remote.Name) then
                    -- Находим связанные с ним хитбоксы
                    for _, hit in ipairs(allHits) do
                        local script = hit.Part.Parent:FindFirstChildWhichIsA("LocalScript") or hit.Part.Parent.Parent:FindFirstChildWhichIsA("LocalScript")
                        if script then
                            local src = script.Source
                            if string.find(src, "%." .. remote.Name .. ":FireServer%(", 1, true) then
                                -- Нашли связь! Хит -> Эвент
                                remote.OnClientEvent:Connect(function(arg1, arg2, arg3, arg4)
                                    -- ПРОПУСКАЕМ события, которые вызвал сам игрок (чтобы не было петли)
                                    if debug.info(2, "f") == Init then return end 

                                    -- Собираем аргументы в таблицу для анализа
                                    local args = {arg1, arg2, arg3, arg4}
                                    
                                    local potentialVictim = nil
                                    local damageValue = -1

                                    -- Ищем в аргументах имя игрока или Humanoid
                                    for i, v in ipairs(args) do
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

                                    -- Если нашли потенциальную жертву
                                    if potentialVictim then
                                        local victimHum = potentialVictim:FindFirstChildOfClass("Humanoid")
                                        local healthBefore = victimHum.Health
                                        
                                        -- Ждем один кадр, чтобы увидеть изменение ХП от этого события
                                        RunService.RenderStepped:Wait()
                                        local delta = healthBefore - victimHum.Health

                                        if delta > 0 then
                                            -- УРОН ЗАФИКСИРОВАН!
                                            local libEntry = DamageLibrary[remote.Name]
                                            
                                            if not libEntry then
                                                DamageLibrary[remote.Name] = {
                                                    remoteObj = remote,
                                                    bestPayload = args,
                                                    maxDamage = delta,
                                                    hitbox = hit.Part -- <--- Сохраняем ссылку на хит
                                                }
                                                print("New Weapon Found:", remote:GetFullName(), "Dmg:", delta, "(via", hit.ToolName or hit.Part.Parent.Name, ")")
                                            elseif delta > libEntry.maxDamage then
                                                -- Нашли более мощную версию использования этого же эвента
                                                DamageLibrary[remote.Name].bestPayload = args
                                                DamageLibrary[remote.Name].maxDamage = delta
                                                DamageLibrary[remote.Name].hitbox = hit.Part -- <--- Обновляем хит
                                                print("Upgraded Weapon:", remote:GetFullName(), "New Dmg:", delta)
                                            end
                                        end
                                    end
                                end)
                                break -- Связь найдена, идём дальше
                            end
                        end
                    end
                end
            end
            wait(5) -- Пересканируем игру раз в 5 секунд на случай появления новых оружий
        end
    end)

    -- === 2. РУЧНОЙ КОНТРОЛЬ (ЛКМ) ===
    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end

        -- Выбор цели ПКМ (для удобства)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            Target = getTarget()
            if Target then
                n("Target locked: " .. Target.Char.Name)
            else
                n("Target cleared.")
            end
        end

        -- АТАКУЕМ ПО ЛКМ
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if not Target then 
                n("Select a target first (RMB).")
                return 
            end

            local victimHum = Target.Hum
            if not victimHum or victimHum.Health <= 0 then return end

            -- Если библиотека знаний еще пуста (мы никого не видели дерущимся)
            if next(DamageLibrary) == nil then
                n("Observing... Sending test packets.")
                local tests = generateTestPackets(Target.Char)
                local allRemotes = findAllRemotes()
                
                for _, r in ipairs(allRemotes) do
                    for _, data in ipairs(tests) do
                        pcall(function() r:FireServer(data) end)
                    end
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

                -- ⚙️⚙️ НОВАЯ ЧАСТЬ: Создание фантомного хита ⚙️⚙️
                if BestWeaponData.hitbox then
                    -- Создаём временный объект в той же форме
                    local phantom = Instance.new(BestWeaponData.hitbox.ClassName, workspace)
                    phantom.Anchored = true
                    phantom.CanCollide = false
                    phantom.Material = Enum.Material.Neon -- Для красоты можно сделать видимым
                    phantom.Color = Color3.fromRGB(255, 0, 0)
                    phantom.Transparency = 0.6
                    phantom.Size = BestWeaponData.hitbox.Size * Vector3.new(1, 1, 1.5) -- Немного больше для надёжности
                    phantom.CFrame = Target.Char.PrimaryPart.CFrame * CFrame.new(0, 0.8, 0) -- Над головой цели

                    -- Подключаем к нему ту же логику
                    phantom.Touched:Connect(function(targ)
                        if targ == Target.Char.PrimaryPart then
                            pcall(function() BestWeaponData.remoteObj:FireServer(unpack(BestWeaponData.bestPayload)) end)
                        end
                    end)

                    -- Имитируем касание
                    firetouchinterest(phantom, Target.Char.PrimaryPart, 0)
                    wait(0.1)
                    firetouchinterest(phantom, Target.Char.PrimaryPart, 1)
                    phantom:Destroy()
                else
                    -- Старый способ отправки только пакета
                    pcall(function() BestWeaponData.remoteObj:FireServer(unpack(BestWeaponData.bestPayload)) end)
                end
            else
                n("Error: No weapon selected.")
            end
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
            hl.Color3 = Color3.fromRGB(0, 255, 255)
        elseif hl then
            hl:Destroy(); hl = nil; Target = nil;
        end
    end)

    nOBSERVER Active. Watch others fight. [LMB]=Kill | [RMB]=Lock Target")
end

pcall(Init)
