-- Smart Touch Killer.lua
local function Init()
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local UserInputService = game:GetService("UserInputService")
    
    local player = Players.LocalPlayer
    local mouse = player:GetMouse()

    local killerRemote = nil      -- Найденный Remote для убийства
    local lastScanTime = 0        -- Защита от спама (сканируем раз в N секунд)
    local SCAN_COOLDOWN = 5       -- Интервал между проверками новых Remotes

    -- Вспомогательная функция уведомлений
    local function notify(text, dur)
        pcall(function()
            game.StarterGui:SetCore("SendNotification", {
                Title = "[TouchKill]"; Text = text; Duration = dur or 3;
            })
        end)
    end

    -- Функция поиска цели под курсором
    local function getTarget()
        if not mouse.Target then return nil end
        local char = mouse.Target:FindFirstAncestorWhichIsA("Model")
        if not char then return nil end
        
        local hum = char:FindFirstChildOfClass("Humanoid")
        local plr = Players:GetPlayerFromCharacter(char)
        
        -- Цель должна быть живым игроком или NPC
        if hum and hum.Health > 0 and char ~= player.Character then
            return {Character = char, Humanoid = hum, Name = char.Name}
        end
        return nil
    end

    -- Основной цикл: ищем уязвимость при нажатии ПКМ
    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end

        -- Если мы уже нашли способ убивать
        if killerRemote and input.UserInputType == Enum.UserInputType.MouseButton2 then
            local target = getTarget()
            if target then
                -- Пробуем разные форматы данных (самые частые)
                killerRemote:FireServer(target.Name) 
                task.wait(0.05)
                killerRemote:FireServer(target.Humanoid)
                
                -- Проверяем результат
                if target.Humanoid.Health <= 0 then
                    notify("Eliminated: " .. target.Name, 2)
                else
                    notify("Failed to kill "..target.Name..". Try again.", 2)
                end
            else
                notify("No valid target under cursor.", 2)
            end
            return
        end

        -- Если киллера еще нет, пытаемся найти его (защита от частого запуска)
        if not killerRemote and (tick() - lastScanTime > SCAN_COOLDOWN) then
            lastScanTime = tick()
            local target = getTarget()
            
            if not target then 
                notify("Look at a player/target to test weapons.", 2)
                return 
            end

            notify("Scanning for vulnerability...", 2)
            
            local remotesFound = {}
            local function scanContainer(container)
                for _, obj in pairs(container:GetDescendants()) do
                    if obj:IsA("RemoteEvent") then
                        table.insert(remotesFound, obj)
                    end
                end
            end

            -- Собираем все реплицируемые объекты
            scanContainer(ReplicatedStorage)
            if workspace:FindFirstChild("Game") then scanContainer(workspace.Game) end
            if workspace:FindFirstChild("_NETWORK") then scanContainer(workspace._NETWORK) end

            -- Тестируем каждый Remote
            for _, remote in ipairs(remotesFound) do
                -- Пропускаем системные эвенты Roblox (часто содержат CharacterAppearance и т.д.)
                if string.find(string.lower(remote.Name), "character") or string.find(string.lower(remote.Name), "respawn") then continue end

                -- Отправляем тестовую порцию урона
                pcall(function()
                    remote:FireServer(target.Name)
                    remote:FireServer({["Victim"] = target.Name, ["Damage"] = 9999})
                end)
                
                -- Ждем применения урона сервером
                task.wait(0.1)

                -- Если цель мертва — это наш ключ
                if target.Humanoid.Health <= 0 then
                    killerRemote = remote
                    notify("WEAPON FOUND: " .. remote:GetFullName(), 4)
                    
                    -- Воскресим цель для дальнейшей игры (если нужно, можно закомментировать)
                    --[[
                    spawn(function()
                        task.wait(3)
                        if target and target.Parent then
                            pcall(function()
                                local newHum = target.Character:FindFirstChildOfClass("Humanoid")
                                if newHum then newHum.Health = newHum.MaxHealth end
                            end)
                        end
                    end)
                    ]]
                    break
                else
                    -- Восстанавливаем хп, если случайно сбили ему часть здоровья, но не убили
                    if target.Humanoid.Health < target.Humanoid.MaxHealth then
                        pcall(function() target.Humanoid.Health = target.Humanoid.MaxHealth end)
                    end
                end
            end

            if not killerRemote then
                notify("Vulnerability not found.", 3)
            end
        end
    end)

    -- Визуальная подсказка (рамка)
    local highlight = nil
    mouse.Move:Connect(function()
        if killerRemote then
            local t = getTarget()
            if t then
                if not highlight then
                    highlight = Instance.new("BoxHandleAdornment", workspace.CurrentCamera)
                    highlight.AlwaysOnTop = true
                    highlight.ZIndex = 10
                    highlight.Transparency = 0.7
                    highlight.Color3 = Color3.fromRGB(255, 60, 60)
                end
                highlight.Adornee = t.Character
                highlight.Size = t.Character:GetExtentsSize() + Vector3.new(0.5, 0.5, 0.5)
            elseif highlight then
                highlight:Destroy(); highlight = nil
            end
        end
    end)

    notify("Smart-Touch Initialized. [RMB] to find weapon/kill.", 5)
end

pcall(Init)

print("[scr.lua] Admin tool deployer started")
