-- Улучшённый Profiler для Remotes (обновлённая версия с фильтрацией оружия и улучшенным поиском)
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
    local mouse = (player.GetMouse and player:GetMouse and player:GetMouse(player)) or (player:GetMouse and player:GetMouse())

    -- ========== CONFIG ==========
    local CONFIG = {
        SAFE_MODE = false,            -- true: только анализ, без реальных вызовов
        DAMAGE_VALUE = math.huge,     -- можно заменить на число
        ATTACK_COOLDOWN = 0.7,
        MAX_TESTS = 1000,             -- ограничение общего числа тестов
        TEST_DELAY_FRAMES = 2,        -- сколько heartbeat'ов ждать после каждого вызова
        ENABLE_HUD = true,            -- показывать статус в HUD
        REMOTE_NAME_BLACKLIST = {     -- имена remotes, которые стоит игнорировать
            ["Ping"] = true,
            ["Heartbeat"] = true
        },
        REMOTE_PARENT_WHITELIST = {}, -- если указано, будут браться remotes только из этих контейнеров (по имени)

        -- Новые опции: фильтрация и приоритизация оружия
        ONLY_WEAPON_RELATED = false,  -- если true: учитываются только remotes/инструменты, связанные с оружием
        WEAPON_PARENT_KEYWORDS = {"Weapon", "Tool", "Gun"}, -- если родитель объекта содержит эти слова, считаем его связанным с оружием
        WEAPON_REMOTE_KEYWORDS = {"Attack", "Damage", "Hit", "Fire", "Shoot", "Slash", "Stab", "Bullet", "Projectile"}, -- ключевые слова в именах remote'ов
        EXTRA_REMOTE_NAME_INCLUDES = {"Damage", "Attack"}, -- дополнительные включения
    }
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

    -- HUD
    local hudGui, hudLabel
    if CONFIG.ENABLE_HUD then
        pcall(function()
            hudGui = Instance.new("ScreenGui")
            hudGui.Name = "ProfilerHUD"
            hudGui.ResetOnSpawn = false
            hudGui.Parent = player:FindFirstChildOfClass("PlayerGui") or player.PlayerGui or player:WaitForChild("PlayerGui", 2) or script:FindFirstAncestorOfClass("PlayerGui")

            hudLabel = Instance.new("TextLabel")
            hudLabel.Size = UDim2.new(0, 320, 0, 100)
            hudLabel.Position = UDim2.new(0, 10, 0.5, -50)
            hudLabel.BackgroundTransparency = 0.4
            hudLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
            hudLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            hudLabel.TextScaled = true
            hudLabel.Font = Enum.Font.SourceSansSemibold
            hudLabel.Text = "[Profiler] Idle"
            hudLabel.Parent = hudGui
        end)
    end

    -- Utils
    local function notify(text)
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "[Profiler]",
                Text = tostring(text),
                Duration = 4
            })
        end)
        pcall(function() if hudLabel then hudLabel.Text = "[Profiler] " .. tostring(text) end end)
        print("[Profiler]: " .. tostring(text))
    end

    local function safeToString(x)
        if type(x) == "string" then return x end
        if typeof and typeof(x) == "Instance" then return x.Name or tostring(x) end
        return tostring(x)
    end

    local function isBlacklisted(remote)
        if not remote or not remote.Name then return false end
        return CONFIG.REMOTE_NAME_BLACKLIST[remote.Name] == true
    end

    local function containsAnyKeyword(str, keywords)
        if not str or type(str) ~= "string" then return false end
        for _, kw in ipairs(keywords) do
            if string.find(str:lower(), kw:lower(), 1, true) then
                return true
            end
        end
        return false
    end

    -- Надёжная функция вызова удалённых методов (учёт safe mode)
    local function callRemote(remote, payload)
        if not remote then return false, "no remote" end
        local args = payload.args or {}
        if CONFIG.SAFE_MODE then
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

    -- Генерация payloads (используем DAMAGE_VALUE). Более осторожные варианты.
    local function generatePayloads(victimName, victimHum)
        local t = {}
        table.insert(t, {args = {victimName, CONFIG.DAMAGE_VALUE}, isTableSingleArg = false, desc = "(name, number)"})
        table.insert(t, {args = {{Victim = victimName, Damage = CONFIG.DAMAGE_VALUE}}, isTableSingleArg = true, desc = "{Victim=..,Damage=..}"})
        table.insert(t, {args = {"GodWeapon_Debug"}, isTableSingleArg = false, desc = "(string)"})
        if victimHum then
            table.insert(t, {args = {victimHum}, isTableSingleArg = false, desc = "(Humanoid)"})
        end
        table.insert(t, {args = {victimName}, isTableSingleArg = false, desc = "(name only)"})
        table.insert(t, {args = {{{player = player, enemy = victimName, dmg = CONFIG.DAMAGE_VALUE}}}, isTableSingleArg = true, desc = "{{player=..,enemy=..,dmg=..}}"})
        return t
    end

    -- Собираем RemoteEvent / RemoteFunction в указанных местах, с дедупликацией и улучшенной фильтрацией/приоритизацией
    local function collectRemotes()
        local remotes = {}
        local scored = {} -- {remote = score}
        local seen = {}

        local function scoreFor(obj)
            local score = 0
            if not obj then return score end
            -- match by remote name keywords
            if obj.Name and containsAnyKeyword(obj.Name, CONFIG.WEAPON_REMOTE_KEYWORDS) then
                score = score + 50
            end
            -- parent/tool name
            if obj.Parent then
                if containsAnyKeyword(obj.Parent.Name or "", CONFIG.WEAPON_PARENT_KEYWORDS) then
                    score = score + 40
                end
                -- parent might be a tool instance
                if obj.Parent:IsA and obj.Parent:IsA("Tool") then
                    score = score + 30
                end
            end
            -- additional includes
            if obj.Name and containsAnyKeyword(obj.Name, CONFIG.EXTRA_REMOTE_NAME_INCLUDES) then
                score = score + 20
            end
            -- deprioritize common names in blacklist
            if CONFIG.REMOTE_NAME_BLACKLIST[obj.Name] then
                score = score - 1000
            end
            return score
        end

        local function add(obj)
            if not obj or not obj.IsA then return end
            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                if seen[obj] then return end
                seen[obj] = true
                local s = scoreFor(obj)
                scored[#remotes + 1] = {obj = obj, score = s}
                table.insert(remotes, obj)
            end
        end

        local function scan(container)
            if not container or not container.GetDescendants then return end
            for _, obj in ipairs(container:GetDescendants()) do
                add(obj)
            end
        end

        pcall(function()
            -- приоритизируем вероятные места
            if ReplicatedStorage then scan(ReplicatedStorage) end
            if ReplicatedStorage:FindFirstChild("Remotes") then scan(ReplicatedStorage.Remotes) end
            if ReplicatedStorage:FindFirstChild("_REMOTES") then scan(ReplicatedStorage._REMOTES) end
            -- оружие и инструменты в Workspace/Players
            if Workspace then
                if Workspace:FindFirstChild("Weapons") then scan(Workspace.Weapons) end
                scan(Workspace)
                if Workspace:FindFirstChild("Remotes") then scan(Workspace.Remotes) end
                if Workspace:FindFirstChild("_REMOTES") then scan(Workspace._REMOTES) end
            end
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr.Character then
                    for _, child in ipairs(plr.Character:GetChildren()) do
                        -- сканируем инструменты отдельно и даём им приоритет
                        if child:IsA("Tool") or (type(child.Name) == "string" and containsAnyKeyword(child.Name, CONFIG.WEAPON_PARENT_KEYWORDS)) then
                            scan(child)
                        end
                    end
                end
            end
        end)

        -- Применяем фильтр ONLY_WEAPON_RELATED — убираем не связанные с оружием remotes
        local filtered = {}
        if CONFIG.ONLY_WEAPON_RELATED then
            for _, entry in ipairs(scored) do
                local obj = entry.obj
                local score = entry.score
                if score > 0 then
                    table.insert(filtered, entry)
                end
            end
        else
            for _, entry in ipairs(scored) do
                table.insert(filtered, entry)
            end
        end

        -- Сортируем по очкам (высший сначала)
        table.sort(filtered, function(a, b) return (a.score or 0) > (b.score or 0) end)

        -- Вернём только объекты
        local out = {}
        for _, e in ipairs(filtered) do
            table.insert(out, e.obj)
        end

        return out
    end

    -- Обновление BestWeaponInfo при успешном уроне
    local function considerResult(remote, payload, delta)
        if delta <= 0 then return end
        if delta > MaxSimulatedDamage then
            MaxSimulatedDamage = delta
            BestWeaponInfo = {remote = remote, payload = payload, dmg = delta}
            notify(string.format("New best weapon: %s (dmg=%d)", safeToString(remote.Name or remote), delta))
            pcall(function()
                if hudLabel then
                    hudLabel.Text = string.format("[Profiler] Best: %s (dmg=%d)", safeToString(remote.Name or remote), delta)
                end
            end)
        end
    end

    -- Очередь тестов: формируем, но обрезаем до MAX_TESTS
    local function buildProfileQueue(remotes, payloads)
        local q = {}
        for _, r in ipairs(remotes) do
            if #q >= CONFIG.MAX_TESTS then break end
            for _, p in ipairs(payloads) do
                table.insert(q, {remote = r, payload = p})
                if #q >= CONFIG.MAX_TESTS then break end
            end
        end
        return q
    end

    -- Профайлер: выполняет тесты из profileQueue асинхронно, с задержками между ними и безопасными проверками
    local function runProfiler()
        if isProfiling then return end
        if not Victim or not Victim.Hum then
            notify("No victim set for profiling.")
            return
        end

        isProfiling = true
        MaxSimulatedDamage = -1
        BestWeaponInfo = nil

        task.spawn(function()
            while isProfiling and #profileQueue > 0 do
                if not Victim or not Victim.Hum or Victim.Hum.Health <= 0 then
                    notify("Victim is dead or invalid. Stopping profiling.")
                    isProfiling = false
                    break
                end

                local job = table.remove(profileQueue, 1)
                if job and job.remote and job.payload then
                    local before = Victim.Hum.Health or 0
                    local ok, err = callRemote(job.remote, job.payload)
                    if not ok and err then
                        warn("Remote call error:", err)
                    end

                    for i = 1, math.max(1, CONFIG.TEST_DELAY_FRAMES) do
                        RunService.Heartbeat:Wait()
                    end

                    local after = Victim.Hum and Victim.Hum.Health or 0
                    local delta = before - after
                    if delta > 0 then
                        considerResult(job.remote, job.payload, delta)
                    end
                end

                -- Обновление HUD о прогрессе
                pcall(function()
                    if hudLabel then
                        hudLabel.Text = string.format("[Profiler] Testing... Remaining: %d | Best: %s (%s)",
                            #profileQueue,
                            BestWeaponInfo and safeToString(BestWeaponInfo.remote.Name or BestWeaponInfo.remote) or "-",
                            BestWeaponInfo and tostring(BestWeaponInfo.dmg) or "-")
                    end
                end)

                task.wait(0.01)
            end

            if isProfiling then
                isProfiling = false
            end

            if BestWeaponInfo then
                notify(string.format("%sScanning complete. Best=%s Dmg=%d",
                    CONFIG.SAFE_MODE and "[SAFE MODE] " or "",
                    safeToString(BestWeaponInfo.remote.Name or BestWeaponInfo.remote),
                    BestWeaponInfo.dmg))
            else
                notify(CONFIG.SAFE_MODE and "[SAFE MODE] No simulated damage detected." or "No damage detected.")
            end
        end)
    end

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
            BestWeaponInfo = nil
            MaxSimulatedDamage = -1

            local remotes = collectRemotes()
            if not remotes or #remotes == 0 then
                notify("No remotes found to profile.")
                return
            end

            local payloads = generatePayloads(Victim.Name, Victim.Hum)
            profileQueue = buildProfileQueue(remotes, payloads)

            notify(string.format("%sScanning %s: %d remotes × %d payloads = %d tests (max %d) | WeaponFilter=%s",
                CONFIG.SAFE_MODE and "[SAFE MODE] " or "",
                Victim.Name,
                #remotes,
                #payloads,
                #profileQueue,
                CONFIG.MAX_TESTS,
                tostring(CONFIG.ONLY_WEAPON_RELATED)))

            runProfiler()
        elseif key == Enum.KeyCode.F2 then
            if isProfiling then
                isProfiling = false
                profileQueue = {}
                notify("Profiling stopped.")
            else
                notify("Profiling is not running.")
            end
        elseif key == Enum.KeyCode.F3 then
            CONFIG.SAFE_MODE = not CONFIG.SAFE_MODE
            notify("Safe mode " .. (CONFIG.SAFE_MODE and "enabled" or "disabled"))
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
            if now - LastAttackTime < CONFIG.ATTACK_COOLDOWN then
                notify(string.format("Cooldown active %.1f sec", CONFIG.ATTACK_COOLDOWN - (now - LastAttackTime)))
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

    -- Визуализация подсветки: BoxHandleAdornment (RenderStepped)
    RunService.RenderStepped:Connect(function()
        if Victim and Victim.Hum and Victim.Hum.Health > 0 and Victim.Root and Victim.Root:IsA("BasePart") then
            if not hl then
                hl = Instance.new("BoxHandleAdornment")
                hl.Name = "AutoExec_Highlight"
                hl.Parent = workspace.CurrentCamera or Workspace
                hl.AlwaysOnTop = true
                hl.ZIndex = 10
                hl.Transparency = 0.6
                hl.Adornee = Victim.Root
                pcall(function() hl.Size = Victim.Root.Size + Vector3.new(0.2, 0.2, 0.2) end)
                hl.Color3 = Color3.fromRGB(0, 200, 0)
            else
                pcall(function()
                    if Victim and Victim.Root then
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
