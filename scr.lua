-- Auto-Execute Profiler.lua
local function Init()
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local UserInputService = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    
    local player = Players.LocalPlayer
    local mouse = player:GetMouse()
    local character = player.Character or player.CharacterAdded:Wait()
    local rootPart = character:WaitForChild("HumanoidRootPart")

    -- === СОСТОЯНИЕ ===
    local Victim = nil              
    local BestRemote = nil          
    local BestPayload = nil         
    local MaxDamageDealt = -1       
    local isProfiling = false       
    local profileQueue = {}         
    local lastKnownHealth = 0       -- Хранит предыдущее значение HP для сравнения

    local function n(text) pcall(function() game.StarterGui:SetCore("SendNotification", {Title="[AutoExec]", Text=text, Duration=2}) end) end

    -- Поиск цели под курсором
    local function getTarget()
        if not mouse.Target then return nil end
        local char = mouse.Target:FindFirstAncestorWhichIsA("Model")
        if not char then return nil end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 and char ~= character then return {Char = char, Hum = hum, Name = char.Name} end
        return nil
    end

    -- Генерация тестовых пакетов
    local function generatePayloads(targetName, targetHum)
        return {
            {targetName, 9999},
            targetHum,
            {Victim = targetName, Damage = 9999, Part = targetHum.RootPart},
            {["player"] = player, ["enemy"] = targetName, ["dmg"] = math.huge},
            "GodWeapon_Debug",
            targetName
        }
    end

    -- Сбор всех RemoteEvent
    local function collectWeapons()
        local weapons = {}
        for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
            if obj:IsA("RemoteEvent") then table.insert(weapons, obj) end
        end
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("RemoteEvent") then table.insert(weapons, obj) end
        end
        return weapons
    end

    -- === ЯДРО ПРОФИЛИРОВАНИЯ (сбор лучшего оружия) ===
    task.spawn(function()
        while true do
            if isProfiling and #profileQueue > 0 and Victim and Victim.Hum.Health > 0 then
                local currentHealth = Victim.Hum.Health
                local job = table.remove(profileQueue, 1)
                
                pcall(function() job.remote:FireServer(job.data) end)
                task.wait(0.08) 
                
                local delta = currentHealth - Victim.Hum.Health
                if delta > 0 then
                    if delta > MaxDamageDealt then
                        MaxDamageDealt = delta; BestRemote = job.remote; BestPayload = job.data;
                        n("BEST FOUND: " .. job.remote.Name .. " | Dmg: " .. delta)
                        
                        -- Добиваем цель лучшим способом сразу после обнаружения
                        if Victim.Hum.Health > 0 then
                            pcall(function() BestRemote:FireServer(BestPayload) end)
                        end
                    end
                else
                    if currentHealth ~= Victim.Hum.Health then
                        pcall(function() Victim.Hum.Health = currentHealth end)
                    end
                end
            else
                task.wait(0.1)
            end
        end
    end)

    -- === АВТОМАТИЧЕСКИЙ БОЙ (новая логика) ===
    -- Этот цикл следит за целью и стреляет при любом изменении её ХП
    task.spawn(function()
        while true do
            if Victim and BestRemote and BestPayload and not isProfiling then
                local vHum = Victim.Hum
                if vHum and vHum.Health > 0 then
                    -- Проверяем, изменилось ли здоровье с прошлого кадра
                    if vHum.Health < lastKnownHealth then
                        -- Здоровье упало! Значит, игра разрешила наносить урон в этот тик.
                        -- Спамим нашим лучшим оружием.
                        pcall(function() BestRemote:FireServer(BestPayload) end)
                        pcall(function() BestRemote:FireServer(BestPayload) end) -- Дублируем для надежности
                    end
                    
                    -- Обновляем данные для следующей проверки
                    lastKnownHealth = vHum.Health
                else
                    -- Цель умерла или исчезла
                    if vHum then lastKnownHealth = 0 end
                    Victim = nil 
                end
            else
                -- Если профилирование активно или цели нет, сбрасываем ожидания
                if not Victim then lastKnownHealth = 0 end
            end
            task.wait() -- Работаем на частоте рендеринга (максимально быстро)
        end
    end)

    -- === УПРАВЛЕНИЕ ===
    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end

        -- F1: Выбрать цель и начать поиск ЛУЧШЕГО оружия
        if input.KeyCode == Enum.KeyCode.F1 then
            local t = getTarget()
            if t then
                Victim = t
                lastKnownHealth = t.Hum.Health
                isProfiling = true
                profileQueue = {}
                
                local weapons = collectWeapons()
                local basePayloads = generatePayloads(Victim.Name, Victim.Hum)
                
                for _, w in ipairs(weapons) do
                    for _, p in ipairs(basePayloads) do
                        table.insert(profileQueue, {remote = w, data = p})
                    end
                end
                n("Scanning " .. Victim.Name .. "... (" .. #profileQueue .. " tests)")
            end
        end

        -- T: Вкл/Выкл автоматического огня по текущей цели (без поиска нового оружия)
        -- Полезно, если вы уже знаете best weapon из прошлой сессии
        if input.KeyCode == Enum.KeyCode.T then
            if Victim and not isProfiling then
                Victim = nil
                n("Auto-fire disabled.")
            elseif not isProfiling then
                local t = getTarget()
                if t then
                    Victim = t
                    lastKnownHealth = t.Hum.Health
                    n("Auto-fire enabled on " .. t.Name)
                end
            end
        end

        -- X: Ручной выстрел лучшим оружием (если нужно ударить кого-то другого без включения авто-файра)
        if input.KeyCode == Enum.KeyCode.X then
            local t = getTarget()
            if t and BestRemote and BestPayload then
                pcall(function() BestRemote:FireServer(BestPayload) end)
            end
        end
    end)

    -- Визуализация
    local hl = nil
    RunService.RenderStepped:Connect(function()
        if Victim and Victim.Hum.Health > 0 then
            if not hl then
                hl = Instance.new("BoxHandleAdornment", workspace.CurrentCamera)
                hl.AlwaysOnTop = true; hl.ZIndex = 10; hl.Transparency = 0.7;
            end
            hl.Adornee = Victim.Char
            hl.Size = Victim.Char:GetExtentsSize() + Vector3.new(0.2, 0.2, 0.2)
            hl.Color3 = Color3.fromRGB(0, 255, 0)
        elseif hl then
            hl:Destroy(); hl = nil
        end
    end)

    n("[V2] Ready. [F1]=Profile & Hunt | [T]=Toggle Auto-Fire | [X]=Manual Shot")
end

pcall(Init)
