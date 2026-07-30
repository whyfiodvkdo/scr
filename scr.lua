-- Auto-Execute Profiler.lua (Safe Simulator & Refactor)
--
-- Безопасная и улучшенная версия профайлера для локальной разработки.
-- ВАЖНО: НИКАКИХ вызовов FireServer/InvokeServer не производится.
-- Этот скрипт собирает RemoteEvent/RemoteFunction, генерирует тестовые полезные нагрузки
-- и симулирует отправку, выдавая детализированный отчёт. Подходит для отладки и разработки
-- без воздействия на других игроков.

local function Init()
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")

    local player = Players.LocalPlayer
    if not player then return end

    local mouse = player:GetMouse and player:GetMouse()

    -- === STATE ===
    local Victim = nil              -- {Char=Model, Hum=Humanoid, Name=string}
    local BestRemoteInfo = nil      -- {remote=Instance, payload=payload, dmg=number}
    local MaxSimulatedDamage = -1
    local isProfiling = false
    local profileQueue = {}         -- {remote=Instance, payload=payload}
    local lastKnownHealth = 0
    local hl = nil

    local function notify(text)
        pcall(function()
            game.StarterGui:SetCore("SendNotification", {Title = "[AutoExec-Sim]", Text = tostring(text), Duration = 3})
        end)
        -- also print for console visibility
        print("[AutoExec-Sim] " .. tostring(text))
    end

    -- Safe target detection
    local function getTarget()
        if not mouse then return nil end
        local targetPart = mouse.Target
        if not targetPart then return nil end
        local model = targetPart:FindFirstAncestorWhichIsA("Model")
        if not model then return nil end
        local hum = model:FindFirstChildOfClass("Humanoid")
        local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
        if hum and hum.Health > 0 and model ~= (player.Character or player.CharacterAdded:Wait()) and root then
            return {Char = model, Hum = hum, Name = model.Name}
        end
        return nil
    end

    -- Standardized payload representation
    -- payload = { args = {...}, isTableSingleArg = boolean, desc = string }
    local function generatePayloads(targetName, targetHum)
        local t = {}
        -- (name, amount)
        table.insert(t, {args = {targetName, 9999}, isTableSingleArg = false, desc = "(name, number)"})
        -- pass Humanoid
        table.insert(t, {args = {targetHum}, isTableSingleArg = false, desc = "(Humanoid)"})
        -- single table with fields
        table.insert(t, {args = {{Victim = targetName, Damage = 9999, Part = (targetHum and targetHum.RootPart)}}, isTableSingleArg = true, desc = "{Victim=..,Damage=..,Part=..}"})
        -- map-like single table
        table.insert(t, {args = {{{player = player, enemy = targetName, dmg = math.huge}}}, isTableSingleArg = true, desc = "{player=..,enemy=..,dmg=..}"})
        -- simple string
        table.insert(t, {args = {"GodWeapon_Debug"}, isTableSingleArg = false, desc = "(string)"})
        -- just the name
        table.insert(t, {args = {targetName}, isTableSingleArg = false, desc = "(name)"})
        return t
    end

    -- Collect remotes safely (don't call them)
    local function collectRemotes()
        local remotes = {}
        local function scan(container)
            for _, obj in pairs(container:GetDescendants()) do
                if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                    table.insert(remotes, obj)
                end
            end
        end
        local ok, err = pcall(function()
            scan(ReplicatedStorage)
            scan(workspace)
            if ReplicatedStorage:FindFirstChild("Remotes") then scan(ReplicatedStorage.Remotes) end
            if workspace:FindFirstChild("Remotes") then scan(workspace.Remotes) end
        end)
        if not ok then
            warn("collectRemotes error:", err)
        end
        return remotes
    end

    -- Deterministic simulated damage calculator
    -- Uses remote name and payload description to produce reproducible numbers
    local function simulatedDamageFor(remote, payload)
        local name = tostring(remote and remote.Name or "<nil>")
        local s = name .. "|" .. (payload and tostring(payload.desc) or "<nil>")
        local hash = 0
        for i = 1, #s do
            hash = (hash * 31 + string.byte(s, i)) % 1000000007
        end
        -- map to a range (0..100) for simulated damage
        local dmg = (hash % 120) -- up to 119
        -- give larger values to payloads that include numbers like 9999 or math.huge
        for _, v in ipairs(payload.args) do
            if type(v) == "number" and (v >= 1000 or v == math.huge) then
                dmg = dmg + 50
                break
            end
        end
        return dmg
    end

    -- Profiling worker: consumes profileQueue and simulates results
    task.spawn(function()
        while true do
            if isProfiling and #profileQueue > 0 and Victim and Victim.Hum and Victim.Hum.Health > 0 then
                local job = table.remove(profileQueue, 1)
                if not job or not job.remote or not job.payload then
                    task.wait(0.05)
                    goto continue
                end

                local before = Victim.Hum and Victim.Hum.Health or 0

                -- Instead of calling server, we simulate a call and its effect
                local dmg = simulatedDamageFor(job.remote, job.payload)

                -- Log the simulated call
                print(string.format("[SIM] Remote=%s Type=%s Payload=%s SimDamage=%d",
                    tostring(job.remote:GetFullName()), job.remote.ClassName, job.payload.desc, dmg))

                -- Update best simulated result
                if dmg > MaxSimulatedDamage then
                    MaxSimulatedDamage = dmg
                    BestRemoteInfo = {remote = job.remote, payload = job.payload, dmg = dmg}
                    notify("New best simulated: " .. tostring(job.remote.Name) .. " dmg=" .. tostring(dmg))
                end

                -- artificial wait to mimic network/server processing
                task.wait(0.12)

                -- when queue finishes, stop profiling automatically
                if #profileQueue == 0 then
                    isProfiling = false
                    if BestRemoteInfo then
                        notify("Profiling complete. Best simulated damage=" .. tostring(BestRemoteInfo.dmg) .. " (" .. tostring(BestRemoteInfo.remote.Name) .. ")")
                    else
                        notify("Profiling complete. No simulated damage detected.")
                    end
                end
            else
                task.wait(0.08)
            end
            ::continue::
        end
    end)

    -- Auto-behaviour (visual only) — no auto-firing for safety
    task.spawn(function()
        while true do
            if Victim and BestRemoteInfo and not isProfiling then
                local vHum = Victim.Hum
                if vHum and vHum.Health > 0 then
                    -- detect health drop and log it (do not call the server)
                    if lastKnownHealth > 0 and vHum.Health < lastKnownHealth then
                        print(string.format("[SIM-AUTO] Detected health drop for %s: %s -> %s (no server calls made)", Victim.Name, tostring(lastKnownHealth), tostring(vHum.Health)))
                        notify("Health drop detected on " .. Victim.Name .. " — simulated response available: " .. tostring(BestRemoteInfo.dmg))
                    end
                    lastKnownHealth = vHum.Health
                else
                    Victim = nil
                    lastKnownHealth = 0
                end
            else
                if not Victim then lastKnownHealth = 0 end
            end
            task.wait(0.06)
        end
    end)

    -- Input handling: F1 start profiling (simulation), F2 stop, T toggle highlight, X manual simulated shot
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
                BestRemoteInfo = nil

                local remotes = collectRemotes()
                local payloads = generatePayloads(Victim.Name, Victim.Hum)

                for _, r in ipairs(remotes) do
                    for _, p in ipairs(payloads) do
                        table.insert(profileQueue, {remote = r, payload = p})
                    end
                end

                notify("[SIM] Scanning " .. Victim.Name .. " with " .. tostring(#remotes) .. " remotes and " .. tostring(#payloads) .. " payloads each (" .. tostring(#profileQueue) .. " tests)")
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
                    lastKnownHealth = t.Hum.Health
                    notify("Highlight enabled on " .. t.Name)
                else
                    notify("No valid target under cursor.")
                end
            end
        elseif input.KeyCode == Enum.KeyCode.X then
            local t = getTarget()
            if t and BestRemoteInfo then
                -- Simulate a manual shot using the best found simulated remote
                local dmg = BestRemoteInfo.dmg or simulatedDamageFor(BestRemoteInfo.remote, BestRemoteInfo.payload)
                notify("Manual simulated shot at " .. t.Name .. " (sim dmg=" .. tostring(dmg) .. ")")
                print(string.format("[SIM-MANUAL] Would have called %s with payload %s — sim damage=%s",
                    tostring(BestRemoteInfo.remote:GetFullName()), BestRemoteInfo.payload.desc, tostring(dmg)))
            else
                notify("No best simulated weapon available or no valid target.")
            end
        end
    end)

    -- Visualization: BoxHandleAdornment highlighting
    RunService.RenderStepped:Connect(function()
        if Victim and Victim.Hum and Victim.Hum.Health > 0 then
            if not hl then
                hl = Instance.new("BoxHandleAdornment")
                hl.Name = "AutoExecSim_Highlight"
                hl.Parent = workspace.CurrentCamera
                hl.AlwaysOnTop = true
                hl.ZIndex = 10
                hl.Transparency = 0.6
                hl.Size = Vector3.new(1,1,1)
                hl.Adornee = Victim.Char
            end
            if hl and Victim.Char then
                local success, extents = pcall(function() return Victim.Char:GetExtentsSize() end)
                if success and extents then
                    hl.Size = extents + Vector3.new(0.2, 0.2, 0.2)
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

    notify("[AutoExec-Sim] Ready. Controls: [F1]=Profile (sim) | [F2]=Stop | [T]=Toggle Highlight | [X]=Manual Sim Shot")
end

pcall(Init)
