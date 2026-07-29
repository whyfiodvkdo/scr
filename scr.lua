-- scr.lua
-- Server-side deployer: создаёт для каждого игрока Tool с LocalScript + RemoteEvent + server Script.
-- Поместите этот файл в ServerScriptService.

local MESSAGE_DURATION = 4 -- seconds for client notifications

-- Список UserId, которым разрешено использовать инструменты. Оставьте пустым {} для разрешения всем (не рекомендовано).
local ADMINS = {
    -- 12345678,
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local function tableToLuaLiteral(t)
    local parts = {}
    for _, v in ipairs(t) do
        table.insert(parts, tostring(v))
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

-- Шаблон LocalScript (будет добавлен в Tool, выполняется на клиенте)
local localScriptTemplate = [[
local MESSAGE_DURATION = %d
local tool = script.Parent
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local currentTarget = nil
local highlightObject = nil
local enabled = true

local function safeNotify(text)
    pcall(function()
        game.StarterGui:SetCore("SendNotification", {
            Title = "AdminActions",
            Text = text,
            Duration = math.clamp(MESSAGE_DURATION or 3, 1, 10),
        })
    end)
end

local function createHighlight(targetCharacter)
    if not targetCharacter or not targetCharacter.PrimaryPart then return end
    if highlightObject then
        highlightObject:Destroy()
        highlightObject = nil
    end

    local camera = workspace.CurrentCamera
    if not camera then return end

    local box = Instance.new("BoxHandleAdornment")
    box.Name = "G_Cheat_Highlight"
    box.AlwaysOnTop = true
    box.ZIndex = 10
    box.Color3 = Color3.fromRGB(0, 255, 0)
    box.Transparency = 0.6
    box.Size = targetCharacter:GetExtentsSize() + Vector3.new(1, 1, 1)
    box.Adornee = targetCharacter
    box.Parent = camera

    highlightObject = box
end

local function clearHighlight()
    if highlightObject then
        highlightObject:Destroy()
        highlightObject = nil
    end
end

mouse.TargetChanged:Connect(function(newTarget)
    if not enabled then return end
    if newTarget and newTarget.Parent then
        local char = newTarget.Parent
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and char:IsA("Model") then
            currentTarget = char
            createHighlight(char)
            local plr = Players:GetPlayerFromCharacter(char)
            if plr then
                safeNotify("Target: " .. plr.Name)
            else
                safeNotify("Target: <Non-player model>")
            end
            return
        end
    end

    currentTarget = nil
    clearHighlight()
end)

tool.Activated:Connect(function()
    if not enabled then
        safeNotify("Tool is disabled")
        return
    end

    if currentTarget and currentTarget:FindFirstChildOfClass("Humanoid") and currentTarget.PrimaryPart then
        local plr = Players:GetPlayerFromCharacter(currentTarget)
        local targetName = (plr and plr.Name) or currentTarget.Name or ""
        local remote = tool:FindFirstChild("AdminActionEvent")
        if remote and remote:IsA("RemoteEvent") then
            remote:FireServer(targetName)
        else
            safeNotify("Server communication unavailable")
        end
    else
        safeNotify("No valid target selected")
    end
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.G then
        enabled = not enabled
        if highlightObject then
            highlightObject.Visible = enabled
        end
        safeNotify(enabled and "Mode enabled" or "Mode disabled")
    end
end)

tool.Unequipped:Connect(function()
    clearHighlight()
    currentTarget = nil
end)

script.Destroying:Connect(function()
    clearHighlight()
end)
]]

-- Создаёт серверный Script (обработчик) как строку
local function makeServerScriptSource(adminsLiteral)
    return [[
local ADMINS = ]] .. adminsLiteral .. [[

local Players = game:GetService("Players")

local function isAdmin(userId)
    if #ADMINS == 0 then
        return true -- permissive when no admins listed
    end
    for _, id in ipairs(ADMINS) do
        if id == userId then return true end
    end
    return false
end

local tool = script.Parent
local remote = tool:WaitForChild("AdminActionEvent", 5)

if not remote or not remote:IsA("RemoteEvent") then
    warn("[AdminActions] RemoteEvent AdminActionEvent not found in tool")
    return
end

remote.OnServerEvent:Connect(function(player, targetName)
    -- Basic validation
    if typeof(targetName) ~= "string" then return end
    if not player or not player.UserId then return end

    -- Permission check
    if not isAdmin(player.UserId) then
        warn("[AdminActions] Unauthorized use by " .. tostring(player.Name) .. " (" .. tostring(player.UserId) .. ")")
        return
    end

    -- Find target player by name
    local targetPlayer = game:GetService("Players"):FindFirstChild(targetName)
    if not targetPlayer then
        -- fallback: try to match character name
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character and p.Character.Name == targetName then
                targetPlayer = p
                break
            end
        end
    end

    if targetPlayer and targetPlayer.Character then
        local humanoid = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health > 0 then
            -- Setting Health to 0 is one approach; consider :TakeDamage for better events
            humanoid.Health = 0
        end
    end
end)
]]
end

local function createToolForPlayer(player)
    if not player then return end
    -- Avoid creating multiple tools
    if player:FindFirstChild("Backpack") and player.Backpack:FindFirstChild("AdminActions") then
        return
    end

    -- Wait for Backpack
    local backpack = player:WaitForChild("Backpack", 10)
    if not backpack then return end

    local tool = Instance.new("Tool")
    tool.Name = "AdminActions"
    tool.RequiresHandle = false
    tool.CanBeDropped = false
    tool.Parent = backpack

    local remote = Instance.new("RemoteEvent")
    remote.Name = "AdminActionEvent"
    remote.Parent = tool

    local serverScript = Instance.new("Script")
    serverScript.Name = "ServerHandler"
    serverScript.Source = makeServerScriptSource(tableToLuaLiteral(ADMINS))
    serverScript.Parent = tool

    local localScript = Instance.new("LocalScript")
    localScript.Name = "ClientHandler"
    localScript.Source = string.format(localScriptTemplate, MESSAGE_DURATION)
    localScript.Parent = tool

    tool:SetAttribute("CreatedBy", "scr.lua")
end

Players.PlayerAdded:Connect(function(player)
    -- Small delay to ensure player is fully initialized
    spawn(function()
        if not player then return end
        -- Wait until Backpack exists
        local ok = pcall(function()
            player:WaitForChild("Backpack", 15)
        end)
        if ok then
            createToolForPlayer(player)
        end
    end)
end)

-- For testing when script starts mid-game
for _, player in ipairs(Players:GetPlayers()) do
    spawn(function()
        createToolForPlayer(player)
    end)
end

print("[scr.lua] Admin tool deployer started")
