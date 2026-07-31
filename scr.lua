-- Auto-Execute Profiler v2.0: Real Server Calls & Safe Mode
--
-- Этот скрипт ищет RemoteEvent/RemoteFunction в игре,
-- генерирует тестовые полезные нагрузки и отправляет их на сервер.
-- Включает безопасный режим для анализа без воздействия на игру.

local function Init()
    local Players = game.GetService(game, "Players")
    local ReplicatedStorage = game.GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local UserInputService = game.GetService(game, "UserInputService") -- Защита от nil

    local player = Players.LocalPlayer or Players.PlayerAdded:Wait() 
    if not player then return end

    local mouse = player:GetMouse and player:GetMouse()

    -- === STATE ===
    -- ⚙️⚙️ НАСТРОЙКИ БЕЗОПАСНОСТИ ⚙️⚙️
    -- Если true - скрипт НЕ отправляет ничего на сервер. Только анализирует.
    -- ЕСЛИ FALSE — РЕАЛЬНЫЕ вызовы FireServer/InvokeServer.
    local isSafeMode = false -- <--- РАБОЧИЙ РЕЖИМ ВКЛЮЧЕН!

    local Victim = nil              -- {Char=Model, Hum=Humanoid, Name=string}
    local BestWeaponInfo = nil      -- {remote=Instance, payload=payload, dmg=number}
    local MaxSimulatedDamage = -1
    local isProfiling = false
    local profileQueue = {}         -- {remote=Instance, payload=payload}
    local lastKnownHealth = 0
    local hl = nil

    local ATTACK_COOLDOWN = 0.7     -- Минимальная пауза между ударами
    local LastAttackTime = tick()   

    local function notify(text)
        pcall(function()
            game.StarterGui:SetCore("SendNotification", {
                Title = "[Profiler]",
                Text = tostring(text),
                Duration = 3})
        end)
        print("" .. tostring(text))
    end

    -- Безопасная проверка цели под курсором
    local function getTarget()
        if not mouse then return nil end
        local targetPart = mouse.Target
        if not targetPart then return nil end
        local model = targetPart:FindFirstAncestorWhichIsA("Model")
        if not model then return nil end
        local hum = model:FindFirstChildOfClass("Humanoid")
        local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
        if hum and hum.Health > 0 and model ~= (player.Character or player.CharacterAdded:Wait()) and root then
            return {Char = model, Hum = hum, Root = root, Name = model.Name}
        end
        return nil
    end

    -- Стандартные тестовые полезности (Payloads)
    -- payload = { args = {...}, isTableSingleArg = boolean, desc = string }
    local function generatePayloads(targetName, targetHum)
        local t = {}
        table.insert(t, {args = {targetName, 9999}, isTableSingleArg = false, desc = "(name, number)"})          -- Common damage format
        table.insert(t, {args = {targetHum}, isTableSingleArg = false, desc = "(Humanoid)"})                     -- Passing Humanoid directly
        table.insert(t, {args = {{Victim = targetName, Damage = math.huge, Part = targetHum.RootPart}}, isTableSingleArg = true, desc = "{Victim=..,Damage=..,Part=..}"}) -- Table with fields
        table.insert(t, {args = {{{player = player, enemy = targetName, dmg = math.huge}}}, isTableSingleArg = true, desc = "{{player=..,enemy=..,dmg=..}}"}) -- Nested map-like table
        table.insert(t, {args = {"GodWeapon_Debug"}, isTableSingleArg = false, desc = "(string)"})                 -- Debug strings
        table.insert(t, {args = {targetName}, isTableSingleArg = false, desc = "(name only)"})                    -- Just name
        return t
    end

    -- Сбор всех удалённых объектов в игре
    local function collectRemotes()
        local remotes = {}
        local function scan(container)
            for _, obj in pairs(container:GetDescendants()) do
                if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                    table.insert(remotes, obj)
                end
            end
        end
        -- Standard places
        scan(ReplicatedStorage)
        scan(workspace)
        -- Special folders
        if ReplicatedStorage:FindFirstChild("Remotes") then scan(ReplicatedStorage.Remotes) end
        if workspace:FindFirstChild("Remotes") then scan(workspace.Remotes) end
        if workspace:FindFirstChild("_REMOTES") then scan(workspace._REMOTES) end
        -- Inside players' weapons/models
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Character then
                for _, tool in ipairs(plr.Character:GetChildren()) do
                    if tool:IsA("Tool") or string.find(tool.Name, "Weapon", 1, true) then
                        scan(tool)
                    end
                end
            end
        end
        return remotes
    end

    -- Профилирование worker: потребляет очередь profileQueue и выполняет тесты
    task.spawn(function()
        while wait() do
            if isProfiling and #profileQueue > 0 and Victim and Victim.Hum and Victim.Hum.Health > 0 then
                local job = table.remove(profileQueue, 1)
                if not job or not job.remote or not job.payload then goto continue end

                local before = Victim.Hum.Health or 0

                -- Реальный вызов на сервер (если не в безопасном режиме)
                if not isSafeMode then
                    local success, err
                    if job.remote.ClassName == "RemoteEvent" then
                        if job.payload.isTableSingleArg then
                            success, err = pcall(job.remote.FireServer, job.remote, unpack(job.payload.args)[1])
                        else
                            success, err = pcall(job.remote.FireServer, job.remote, unpack(job.payload.args))
                        end
                    elseif job.remote.ClassName == "RemoteFunction" then
                        if job.payload.isTableSingleArg then
                            success, err = pcall(job.remote.InvokeServer, job.remote, unpack(job.payload.args)[1])
                        else
                            success, err = pcall(job.remote.InvokeServer, job.remote, unpack(job.payload.args))
                        end
                    end
                    if not success then warn("Call error:", err) end
                end

                -- Ждём один кадр, чтобы увидеть изменение ХП от этого события
                RunService.RenderStepped:Wait()

                -- Смотрим результат
                local delta = before - (Victim.Hum.Health or 0)
                if delta <= 0 then goto continue end

                -- Update best result
                if delta > MaxSimulatedDamage then
                    MaxSimulatedDamage = delta
                    BestWeaponInfo = {remote = job.remote, payload = job.payload, dmg = delta}
                    notify(string.format("New best weapon found! %s (%d HP)", job.remote.Name, delta))
                end

                ::continue::

                -- Когда очередь тестов заканчивается, профайлинг завершается автоматически
                if #profileQueue == 0 then
                    isProfiling = false
                    if BestWeaponInfo then
                        notify(string.format(
                            "%s Scanning complete. Best weapon=%s Dmg=%d",
                            isSafeMode and "[SAFE MODE]" or "",
                            BestWeaponInfo.remote.Name,
                            BestWeaponInfo.dmg))
                    else
                        notify(isSafeMode and "[SAFE MODE] No simulated damage detected." or "No damage detected.")
                    end
                end
            else
                task.wait(0.08)
            end
        end
    end)

    -- Input handling: F1 start profiling, F2 stop, T toggle highlight, X manual shot
    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.F1 then
            local t = getTarget()
            if t then
                Victim = t
                lastKnownHealth = t.Hum.Health
                isProfiling = true
                profileQueue = {}
                MaxSimulatedDamage = -1
                BestWeaponInfo = nil

                local remotes = collectRemotes()
                local payloads = generatePayloads(Victim.Name, Victim.Hum)

                for _, r in ipairs(remotes) do
                    for _, p in ipairs(payloads) do
                        table.insert(profileQueue, {remote = r, payload = p})
                    end
                end

                notify(string.format(
                    "%s Scanning %s with %d remotes and %d payloads each (%d tests)",
                    isSafeMode and "[SAFE MODE]" or "",
                    Victim.Name,
                    #remotes,
                    #payloads,
                    #profileQueue))
            else
                notify("No valid target under cursor for profiling.")
            end
        elseif input.KeyCode == Enum.KeyCode.F2 then
            if isProfiling then
                isProfiling = false
                profileQueue = {}
                notify("Profiling stopped.")
            else
                notify("Profiling is not running.")
            end
        elseif input.KeyCode == Enum.KeyCode.T then
            -- Toggle highlight of current target
            if Victim then
                Victim = nil
                notify("Highlight disabled.")
            else
                local t = getTarget()
                if t then
                    Victim = t
                    lastKnownHeight = t.Hum.Health
                    notify("Highlight enabled on " .. t.Name)
                else
                    notify("No valid target under cursor.")
                end
            end
        elseif input.KeyCode == Enum.KeyCode.X then
            -- Manual real shot at the victim
            if not Victim then
                Victim = getTarget()
                if not Victim then
                    notify("No valid target selected.")
                    return
                end
            end

            if BestWeaponInfo then
                local now = tick()
                if now - LastAttackTime < ATTACK_COOLDOWN then
                    notify(string.format("Cooldown active %.1f sec", ATTACK_COOLDOWN - (now - LastAttackTime)))
                    return
                end

                LastAttackTime = now

                -- Вызов на сервер
                if not isSafeMode then
                    local remote = BestWeaponInfo.remote
                    local payload = BestWeaponInfo.payload
                    local success, err
                    if remote.ClassName == "RemoteEvent" then
                        if payload.isTableSingleArg then
                            success, err = pcall(remote.FireServer, remote, unpack(payload.args)[1])
                        else
                            success, err = pcall(remote.FireServer, remote, unpack(payload.args))
                        end
                    elseif remote.ClassName == "RemoteFunction" then
                        if payload.isTableSingleArg then
                            success, err = pcall(remote.InvokeServer, remote, unpack(payload.args)[1])
                        else
                            success, err = pcall(remote.InvokeServer, remote, unpack(payload.args))
                        end
                    end
                    if not success then
                        warn("Manual call error:", err)
                        notify("Error sending packet!")
                    else
                        notify(string.format("Shot fired via %s | Payload=%s", remote.Name, payload.desc))
                    end
                else
                    notify("In SAFE MODE. No packets are sent.")
                end
            else
                notify("No best weapon available yet. Profile a target first.")
            end
        end
    end)

    -- Visualization: BoxHandleAdornment highlighting
    RunService.RenderStepped:Connect(function()
        if Victim and Victim.Hum and Victim.Hum.Health > 0 then
            if not hl then
                hl = Instance.new("BoxHandleAdornment")
                hl.Name = "AutoExec_Highlight"
                hl.Parent = workspace.CurrentCamera
                hl.AlwaysOnTop = true
                hl.ZIndex = 10
                hl.Transparency = 0.6
                hl.Adornee = Victim.Char
            end
            if hl and Victim.Char then
                local extents = pcall(function() return Victim.Char:GetExtentsSize() + Vector3.new(0.2, 0.2, 0.2) end)
                if extents then
                    hl.Size = extents
                end
                hl.Color3 = Color3.fromRGB(0, 200, 0)
                hl.Adornee = Victim.Char
            end
        else
            if hl then
                pcall(function() hl:Destroy() end)
                hl = nil
            end
        end
    end)

    notifyProfiler loaded. Controls: [F1]=Profile | [F2]=Stop | [T]=Toggle Highlight | [X]=Manual Shot")
end

pcall(Init)
