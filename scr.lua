-- Autonomous Damage Profiler.lua
local function Init()
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local UserInputService = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    
    local player = Players.LocalPlayer
    local mouse = player:GetMouse()
    local character = player.Character or player.CharacterAdded:Wait()
    local rootPart = character:WaitForChild("HumanoidRootPart")

    -- === СОСТОЯНИЕ СКРИПТА ===
    local Victim = nil              -- Текущая цель для тестов
    local BestRemote = nil          -- Самый эффективный RemoteEvent
    local BestPayload = nil         -- Лучший формат данных для него
    local MaxDamageDealt = -1       -- Рекорд нанесенного урона
    local isProfiling = false       -- Флаг работы сканера
    local profileQueue = {}         -- Очередь на проверку [ {remote, payload} ]

    local function n(text) pcall(function() game.StarterGui:SetCore("SendNotification", {Title="[Profiler]", Text=text, Duration=2}) end) end

    -- Поиск цели под курсором
    local function getTarget()
        if not mouse.Target then return nil end
        local char = mouse.Target:FindFirstAncestorWhichIsA("Model")
        if not char then return nil end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 and char ~= character then return {Char = char, Hum = hum, Name = char.Name} end
        return nil
    end

    -- Генерация тестовых пакетов (payloads)
    local function generatePayloads(targetName, targetHum)
        return {
            -- Формат 1: Простой урон числом
            {targetName, 9999},
            -- Формат 2: Объект Humanoid напрямую
            targetHum,
            -- Формат 3: Сложная таблица (самый частый случай в играх)
            {Victim = targetName, Damage = 9999, Part = targetHum.RootPart},
            {["player"] = player, ["enemy"] = targetName, ["dmg"] = math.huge},
            -- Формат 4: Попытка убить через инстанс оружия
            "GodWeapon_Debug",
            -- Формат 5: Только имя (для простых систем касания)
            targetName
        }
    end

    -- Сбор всех потенциальных точек входа
    local function collectWeapons()
        local weapons = {}
        local containers = {ReplicatedStorage, workspace}
        
        for _, cont in pairs(containers) do
            for _, obj in pairs(cont:GetDescendants()) do
                if obj:IsA("RemoteEvent") then
                    table.insert(weapons, obj)
                end
            end
        end
        return weapons
    end

    -- === ЯДРО ПРОФИЛИРОВАНИЯ ===
    task.spawn(function()
        while true do
            if isProfiling and #profileQueue > 0 and Victim and Victim.Hum.Health > 0 then
                local currentHealth = Victim.Hum.Health
                
                local job = table.remove(profileQueue, 1)
                local remote = job.remote
                local data = job.data
                
                -- Отправляем запрос
                pcall(function() remote:FireServer(data) end)
                
                -- Ждем репликацию урона от сервера (очень важный тайминг)
                task.wait(0.1) 
                
                local delta = currentHealth - Victim.Hum.Health
                
                -- Если сервер применил урон
                if delta > 0 then
                    n("Tested " .. remote.Name .. ": Dealt " .. tostring(delta))
                    
                    if delta > MaxDamageDealt then
                        MaxDamageDealt = delta
                        BestRemote = remote
                        BestPayload = data
                        n("NEW BEST! " .. remote:GetFullName() .. " | Dmg: " .. delta)
                        
                        -- Мгновенное убийство текущей цели лучшим способом
                        if Victim and Victim.Hum.Health > 0 then
                            pcall(function() BestRemote:FireServer(BestPayload) end)
                        end
                    end
                else
                    -- Восстанавливаем хп цели, если мы её не убили, но задели (чтобы тесты были чистыми)
                    if currentHealth ~= Victim.Hum.Health then
                        pcall(function() Victim.Hum.Health = currentHealth end)
                    end
                end
            else
                task.wait(0.1)
            end
        end
    end)

    -- === УПРАВЛЕНИЕ ===
    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end

        -- F1: Назначить новую жертву для профилирования
        if input.KeyCode == Enum.KeyCode.F1 then
            local t = getTarget()
            if t then
                Victim = t
                isProfiling = true
                profileQueue = {}
                
                -- Собираем оружие и генерируем пакеты
                local weapons = collectWeapons()
                local basePayloads = generatePayloads(Victim.Name, Victim.Hum)
                
                for _, w in ipairs(weapons) do
                    for _, p in ipairs(basePayloads) do
                        table.insert(profileQueue, {remote = w, data = p})
                    end
                end
                
                n("Profiling started on: " .. Victim.Name .. ". Queue size: " .. #profileQueue)
            else
                n("No valid target.")
            end
        end

        -- X: Принудительно применить ЛУЧШИЙ найденный метод к тому, кто сейчас под курсором
        if input.KeyCode == Enum.KeyCode.X then
            local t = getTarget()
            if t and BestRemote and BestPayload then
                n("Executing best vector on " .. t.Name)
                pcall(function() BestRemote:FireServer(BestPayload) end)
            elseif not BestRemote then
                n("Best weapon not found yet. Use F1 first.")
            end
        end

        -- P: Печать статуса лучшего оружия
        if input.KeyCode == Enum.KeyCode.P then
            if BestRemote then
                print("[PROFILER] Best Weapon:", BestRemote:GetFullName())
                print("[PROFILER] Payload Type:", typeof(BestPayload))
                print("[PROFILER] Max Damage:", MaxDamageDealt)
            else
                print("[PROFILER] No weapon discovered yet.")
            end
        end
    end)

    -- Визуализация жертвы теста
    local hl = nil
    RunService.RenderStepped:Connect(function()
        if Victim and Victim.Hum.Health > 0 then
            if not hl then
                hl = Instance.new("BoxHandleAdornment", workspace.CurrentCamera)
                hl.AlwaysOnTop = true; hl.ZIndex = 10; hl.Transparency = 0.7;
            end
            hl.Adornee = Victim.Char
            hl.Size = Victim.Char:GetExtentsSize() + Vector3.new(0.2, 0.2, 0.2)
            hl.Color3 = Color3.fromRGB(255, 100, 0)
        elseif hl then
            hl:Destroy(); hl = nil
        end
    end)

    n("Ready. [F1]=Profile Target | [X]=Use Best Weapon | [P]=Print Stats")
end

pcall(Init)
