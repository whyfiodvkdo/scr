-- Intelligent Combat Scanner.lua
local function Init()
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local UserInputService = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    
    local player = Players.LocalPlayer
    local mouse = player:GetMouse()
    local character = player.Character or player.CharacterAdded:Wait()
    local rootPart = character:WaitForChild("HumanoidRootPart")

    -- Ключевые слова для поиска боевых систем
    local COMBAT_KEYWORDS = {
        "hit", "damage", "dmg", "punch", "kick", "attack", "swing", 
        "melee", "shoot", "fire", "cast", "combat", "weapon", "skill"
    }

    local foundRemotes = {}
    local testTarget = nil
    local isScanning = false

    -- Функция уведомлений
    local function n(text) 
        pcall(function() game.StarterGui:SetCore("SendNotification", {Title="[Scanner]", Text=text, Duration=2}) end) 
    end

    -- Поиск целей под курсором
    local function getBestTarget()
        if not mouse.Target then return nil end
        local char = mouse.Target:FindFirstAncestorWhichIsA("Model")
        if not char then return nil end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local plr = Players:GetPlayerFromCharacter(char)
        
        if hum and hum.Health > 0 and char ~= character then
            return {Char = char, Hum = hum, Name = char.Name}
        end
        return nil
    end

    -- Сканирование иерархии игры
    local function deepScan()
        n("Starting Deep Scan...")
        table.clear(foundRemotes)
        
        local containers = {
            ReplicatedStorage,
            workspace:FindFirstChild("Game"),
            workspace:FindFirstChild("_NODES"),
            workspace:FindFirstChild("_REMOTES")
        }

        for _, cont in pairs(containers) do
            if not cont then continue end
            for _, obj in pairs(cont:GetDescendants()) do
                -- Ищем RemoteEvents по ключевым словам
                if obj:IsA("RemoteEvent") then
                    local nameLower = string.lower(obj.Name)
                    local score = 0
                    for _, kw in ipairs(COMBAT_KEYWORDS) do
                        if string.find(nameLower, kw) then score = score + 1 end
                    end
                    if score > 0 then
                        table.insert(foundRemotes, {Obj = obj, Score = score})
                    end
                end
                
                -- Ищем физические хитбоксы (невидимые детали)
                if obj:IsA("BasePart") and obj.Transparency > 0.9 and obj.CanCollide == false then
                    local parentName = string.lower(obj.Parent.Name)
                    if string.find(parentName, "hit") or string.find(parentName, "zone") then
                        table.insert(foundRemotes, {Obj = obj, Type = "TouchTrigger"})
                    end
                end
            end
        end

        -- Сортируем по релевантности
        table.sort(foundRemotes, function(a, b) 
            if a.Score and b.Score then return a.Score > b.Score else return false end
        end)

        if #foundRemotes > 0 then
            n("Found " .. #foundRemotes .. " potential vectors.")
        else
            n("No combat events found.")
        end
    end

    -- Тестирование конкретного Remotes
    local function probeRemote(remoteData)
        if not testTarget then n("Look at target to probe."); return end
        
        local remote = remoteData.Obj
        n("Probing: " .. remote:GetFullName())

        -- Пробуем разные форматы пакетов
        local formats = {
            testTarget.Name, -- Строка
            testTarget.Hum,   -- Объект Humanoid
            {["Victim"] = testTarget.Name, ["Dmg"] = 999}, -- Таблица
            {["plr"] = player, ["target"] = testTarget.Char} -- Сложный объект
        }

        for i, data in ipairs(formats) do
            pcall(function() remote:FireServer(data) end)
            task.wait(0.05) -- Даем серверу время обработать пакет
            
            if testTarget.Hum.Health <= 0 then
                n("SUCCESS! Format "..i.." killed via "..remote:GetFullName())
                return true
            end
        end
        return false
    end

    -- Активация физических триггеров
    local function touchTrigger(triggerObj)
        n("Teleporting to trigger: " .. triggerObj:GetFullName())
        rootPart.CFrame = triggerObj.CFrame + Vector3.new(0, 5, 0)
        -- Принудительно вызываем событие касания
        firetouchinterest(rootPart, triggerObj, 0)
        task.wait(0.1)
        firetouchinterest(rootPart, triggerObj, 1)
    end

    -- ГОРЯЧИЕ КЛАВИШИ
    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end

        -- F1 - Полное сканирование карты
        if input.KeyCode == Enum.KeyCode.F1 then
            spawn(deepScan)
        end

        -- F2 - Выбрать цель для тестов
        if input.KeyCode == Enum.KeyCode.F2 then
            testTarget = getBestTarget()
            if testTarget then
                n("Test Target set: " .. testTarget.Name)
            else
                n("No valid target under cursor.")
            end
        end

        -- X - Протестировать самый лучший найденный Remote
        if input.KeyCode == Enum.KeyCode.X and not isScanning then
            isScanning = true
            if #foundRemotes == 0 then 
                n("List empty. Press F1 first.") 
                isScanning = false; return 
            end

            for _, data in ipairs(foundRemotes) do
                if data.Type == "TouchTrigger" then
                    touchTrigger(data.Obj)
                    task.wait(1)
                elseif data.Obj:IsA("RemoteEvent") then
                    if probeRemote(data) then 
                        isScanning = false; return 
                    end
                end
            end
            isScanning = false
        end
    end)

    -- Визуальная рамка для тестовой цели
    local hl = nil
    RunService.RenderStepped:Connect(function()
        if testTarget and testTarget.Hum.Health > 0 then
            if not hl then
                hl = Instance.new("BoxHandleAdornment", workspace.CurrentCamera)
                hl.AlwaysOnTop = true
                hl.ZIndex = 10
                hl.Color3 = Color3.fromRGB(0, 255, 255)
            end
            hl.Adornee = testTarget.Char
            hl.Size = testTarget.Char:GetExtentsSize() + Vector3.new(0.2, 0.2, 0.2)
        elseif hl then
            hl:Destroy(); hl = nil
        end
    end)

    notify("[SCANNER] Ready. [F1] Scan | [F2] Set Target | [X] Execute.", 5)
end

pcall(Init)
