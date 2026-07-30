-- Passive Observer Killer.lua
local function Init()
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local UserInputService = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    
    local player = Players.LocalPlayer
    local mouse = player:GetMouse()
    local character = player.Character or player.CharacterAdded:Wait()

    -- === БАЗА ДАННЫХ НАБЛЮДЕНИЙ ===
    -- Здесь хранятся все найденные способы нанесения урона в формате:
    -- [RemoteName] = {remoteObj = ..., bestPayload = ..., maxDamage = ...}
    local DamageLibrary = {}

    -- Текущая цель игрока
    local Target = nil

    local function n(text) pcall(function() game.StarterGui:SetCore("SendNotification", {Title="[Observer]", Text=text, Duration=2}) end) end

    -- Генерация тестовых пакетов для "пробива" защиты (когда библиотека пуста)
    local function generateTestPackets(target)
        return {
            target.Name,
            target:FindFirstChildOfClass("Humanoid"),
            {Victim = target.Name, Dmg = 999},
            {Target = target, Value = math.huge}
        }
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

    -- === 1. ПАССИВНОЕ НАБЛЮДЕНИЕ ЗА СЕРВЕРОМ ===
    -- Этот цикл работает всегда с самого запуска
    task.spawn(function()
        while true do
            local allRemotes = findAllRemotes()
            
            -- Вешаем слушателя на КАЖДЫЙ эвент
            for _, remote in ipairs(allRemotes) do
                -- Проверяем, не подключали ли мы уже этот эвент ранее
                if not rawget(DamageLibrary, remote.Name) then
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
                                        maxDamage = delta
                                    }
                                    print("[LOG] New Weapon Found:", remote:GetFullName(), "Dmg:", delta)
                                elseif delta > libEntry.maxDamage then
                                    -- Нашли более мощную версию использования этого же эвента
                                    DamageLibrary[remote.Name].bestPayload = args
                                    DamageLibrary[remote.Name].maxDamage = delta
                                    print("[LOG] Upgraded Weapon:", remote:GetFullName(), "New Dmg:", delta)
                                end
                            end
                        end
                    end)
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
                -- Отправляем ровно те данные, которые увидели со стороны
                pcall(function() BestWeaponData.remoteObj:FireServer(unpack(BestWeaponData.bestPayload)) end)
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

    n("[OBSERVER] Active. Watch others fight. [LMB]=Kill | [RMB]=Lock Target")
end

pcall(Init)
