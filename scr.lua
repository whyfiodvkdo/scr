-- Улучшённый Profiler для Remotes
-- Controls: F1=Profile | F2=Stop | F3=Toggle SafeMode | T=Toggle Highlight/Target | X=Manual Shot

local function Init()
    -- Services
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local Workspace = game:GetService("Workspace")
    local StarterGui = game:GetService("StarterGui")

    -- Player & input
    local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
    if not player then return end
    local mouse = player:GetMouse and player:GetMouse()

    -- ========== CONFIG ==========
    local isSafeMode = false            -- true: только анализ, без реальных вызовов
    local DAMAGE_VALUE = math.huge     -- можно заменить на число
    local ATTACK_COOLDOWN = 0.7
    -- ============================

    -- State
    local Victim = nil                 -- {Char=Model, Hum=Humanoid, Root=BasePart, Name=string}
    local BestWeaponInfo = nil         -- {remote=Instance, payload=payload, dmg=number}
    local MaxSimulatedDamage = -1
    local isProfiling = false
    local profileQueue = {}            -- очередь тестов {remote, payload}
    local lastKnownHealth = 0
    local hl = nil
    local LastAttackTime = 0

    -- Utils
    local function notify(text)
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "[Profiler]",
                Text = tostring(text),
                Duration = 3
            })
        end)
        print("[Profiler]: " .. tostring(text))
    end

    local function safeToString(x)
        if type(x) == "string" then return x end
        if typeof and typeof(x) == "Instance" then return x.Name or tostring(x) end
        return tostring(x)
    end

    -- Надёжная функция вызова удалённых методов (учёт safe mode)
    local function callRemote(remote, payload)
        if not remote then return false, "no remote" end
        local args = payload.args or {}
        -- если safe mode — не вызываем, но возвращаем как "успех" для симуляции
        if isSafeMode then
            return true, "[SAFE_MODE]"
        end

        local ok, err
        if remote.ClassName == "RemoteEvent" then
            ok, err = pcall(function()
                if payload.isTableSingleArg then
                    remote:FireServer(args[1])
                else
                    remote:FireServer(table.unpack(args))
                end
            end)
        elseif remote.ClassName == "RemoteFunction" then
            ok, err = pcall(function()
                if payload.isTableSingleArg then
                    remote:InvokeServer(args[1])
                else
                    remote:InvokeServer(table.unpack(args))
                end
            end)
        else
            return false, "unsupported remote type: " .. tostring(remote.ClassName)
        end

        if ok then return true, nil else return false, err end
    end

    -- Целевая модель под курсором (корректно возвращаем Root part)
    local function getTarget()
        if not mouse then return nil end
        local targetPart = mouse.Target
        if not targetPart then return nil end
        local model = targetPart:FindFirstAncestorWhichIsA("Model")
        if not model then return nil end
        local hum = model:FindFirstChildOfClass("Humanoid")
        local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso") or targetPart
        if hum and hum.Health and hum.Health > 0 and model ~= (player.Character or player.CharacterAdded:Wait()) and root and root:IsA("BasePart") then
            return {Char = model, Hum = hum, Root = root, Name = model.Name}
        end
        return nil
    end

    -- Генерация payloads (используем DAMAGE_VALUE)
    local function generatePayloads(targetName, targetHum)
        local t = {}
        table.insert(t, {args = {targetName, DAMAGE_VALUE}, isTableSingleArg = false, desc = "(name, number)"})
        table.insert(t, {args = {{Victim = targetName, Damage = DAMAGE_VALUE}}, isTableSingleArg = true, desc = "{Victim=..,Damage=..}"})
        table.insert(t, {args = {"GodWeapon_Debug"}, isTableSingleArg = false, desc = "(string)"})
        table.insert(t, {args = {targetHum}, isTableSingleArg = false, desc = "(Humanoid)"})
        table.insert(t, {args = {targetName}, isTableSingleArg = false, desc = "(name only)"})
        table.insert(t, {args = {{{player = player, enemy = targetName, dmg = DAMAGE_VALUE}}}, isTableSingleArg = true, desc = "{{player=..,enemy=..,dmg=..}}"})
        return t
    end

    -- Собираем RemoteEvent / RemoteFunction в указанных местах, с дедупликацией
    local function collectRemotes()
        local remotes = {}
        local seen = {}
        local function add(obj)
            if not obj or not obj:IsA then return end
            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                if not seen[obj] then
                    seen[obj] = true
                    table.insert(remotes, obj)
                end
            end
        end
        local function scan(container)
            if not container then return end
            for _, obj in ipairs(container:GetDescendants()) do
                add(obj)
            end
        end

        -- Common locations
        scan(ReplicatedStorage)
        scan(Workspace)
        if ReplicatedStorage:FindFirstChild("Remotes") then scan(ReplicatedStorage.Remotes) end
        if Workspace:FindFirstChild("Remotes") then scan(Workspace.Remotes) end
        if Workspace:FindFirstChild("_REMOTES") then scan(Workspace._REMOTES) end

        -- Weapons/tools in players' characters
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Character then
                for _, child in ipairs(plr.Character:GetChildren()) do
                    if child:IsA("Tool") or (type(child.Name) == "string" and string.find(child.Name, "Weapon", 1, true)) then
                        scan(child)
                    end
                end
            end
        end

        return remotes
    end

    -- Обновление BestWeaponInfo при успешном уроне
    local function considerResult(remote, payload, delta)
        if delta <= 0 then return end
        if delta > MaxSimulatedDamage then
            MaxSimulatedDamage = delta
            BestWeaponInfo = {remote = remote, payload = payload, dmg = delta}
            notify(string.format("New best weapon: %s (dmg=%d)", safeToString(remote.Name or remote), delta))
        end
    end

    -- Профайлер: потребляет очередь profileQueue
    task.spawn(function()
        while true do
            if isProfiling and #profileQueue > 0 and Victim and Victim.Hum and Victim.Hum.Health > 0 then
                local job = table.remove(profileQueue, 1)
                if not job or not job.remote or not job.payload then
                    -- skip
                else
                    local before = Victim.Hum.Health or 0
                    -- Выполняем вызов (если not safeMode, callRemote сделает pcall)
                    local ok, err = callRemote(job.remote, job.payload)
                    if not ok and err then
                        warn("Remote call error:", err)
                    end

                    -- Небольшая пауза, даём серверу обработать (несколько кадров надежнее)
                    -- Ждём рендер/heartbeat несколько раз, чтобы изменения успели примениться
                    for i=1,2 do
                        RunService.Heartbeat:Wait()
                    end

                    local after = Victim.Hum and Victim.Hum.Health or 0
                    local delta = before - after
                    if delta > 0 then
                        considerResult(job.remote, job.payload, delta)
                    end
                end

                if #profileQueue == 0 then
                    isProfiling = false
                    if BestWeaponInfo then
                        notify(string.format("%sScanning complete. Best=%s Dmg=%d",
                            isSafeMode and "[SAFE MODE] " or "",
                            safeToString(BestWeaponInfo.remote.Name or BestWeaponInfo.remote),
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

    -- Обработка ввода
    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        local key = input.KeyCode

        if key == Enum.KeyCode.F1 then
            local t = getTarget()
            if not t then
                notify("No valid target under cursor for profiling.")
                return
            end

            Victim = t
            lastKnownHealth = t.Hum.Health or 0
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

            notify(string.format("%sScanning %s: %d remotes × %d payloads = %d tests",
                isSafeMode and "[SAFE MODE] " or "",
                Victim.Name,
                #remotes,
                #payloads,
                #profileQueue))
        elseif key == Enum.KeyCode.F2 then
            if isProfiling then
                isProfiling = false
                profileQueue = {}
                notify("Profiling stopped.")
            else
                notify("Profiling is not running.")
            end
        elseif key == Enum.KeyCode.F3 then
            isSafeMode = not isSafeMode
            notify("Safe mode " .. (isSafeMode and "enabled" or "disabled"))
        elseif key == Enum.KeyCode.T then
            if Victim then
                Victim = nil
                notify("Highlight disabled.")
            else
                local t = getTarget()
                if t then
                    Victim = t
                    lastKnownHealth = t.Hum.Health or 0
                    notify("Highlight enabled on " .. t.Name)
                else
                    notify("No valid target under cursor.")
                end
            end
        elseif key == Enum.KeyCode.X then
            -- Manual shot
            if not Victim then
                Victim = getTarget()
                if not Victim then
                    notify("No valid target selected.")
                    return
                end
            end

            local now = tick()
            if now - LastAttackTime < ATTACK_COOLDOWN then
                notify(string.format("Cooldown active %.1f sec", ATTACK_COOLDOWN - (now - LastAttackTime)))
                return
            end
            LastAttackTime = now

            if BestWeaponInfo then
                local ok, err = callRemote(BestWeaponInfo.remote, BestWeaponInfo.payload)
                if not ok then
                    notify("Error sending packet: " .. tostring(err))
                    warn("Manual call error:", err)
                else
                    notify(string.format("Shot fired via %s | Payload=%s",
                        safeToString(BestWeaponInfo.remote.Name or BestWeaponInfo.remote),
                        BestWeaponInfo.payload.desc or ""))
                end
            else
                notify("No best weapon available yet.")
            end
        end
    end)

    -- Визуализация подсветки: BoxHandleAdornment
    RunService.RenderStepped:Connect(function()
        if Victim and Victim.Hum and Victim.Hum.Health > 0 and Victim.Root and Victim.Root:IsA("BasePart") then
            if not hl then
                hl = Instance.new("BoxHandleAdornment")
                hl.Name = "AutoExec_Highlight"
                hl.Parent = Workspace.CurrentCamera or Workspace
                hl.AlwaysOnTop = true
                hl.ZIndex = 10
                hl.Transparency = 0.6
                hl.Adornee = Victim.Root
                hl.Size = Victim.Root.Size + Vector3.new(0.2, 0.2, 0.2)
                hl.Color3 = Color3.fromRGB(0, 200, 0)
            else
                pcall(function()
                    if Victim.Root then
                        hl.Adornee = Victim.Root
                        hl.Size = Victim.Root.Size + Vector3.new(0.2, 0.2, 0.2)
                        hl.Color3 = Color3.fromRGB(0, 200, 0)
                    end
                end)
            end
        else
            if hl then
                pcall(function() hl:Destroy() end)
                hl = nil
            end
        end
    end)

    notify("Profiler loaded. Controls: [F1]=Profile | [F2]=Stop | [F3]=Toggle SafeMode | [T]=Toggle Highlight | [X]=Manual Shot")
end

pcall(Init)
