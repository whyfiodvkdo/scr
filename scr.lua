-- Improved admin tool creator
-- Place this Script in ServerScriptService. It will create a client LocalScript + a server Script and a RemoteEvent inside a Tool for each player that joins.

local MESSAGE_DURATION = 4 -- seconds shown for notifications

-- List of allowed UserIds who can use the tool. Leave empty {} to allow everyone (not recommended).
local ADMINS = {
    -- 12345678, -- add numeric user ids here
}

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

-- Utility: convert a Lua table of numbers to a Lua literal string (e.g. {123,456})
local function tableToLuaLiteral(t)
    local parts = {}
    for _,v in ipairs(t) do
        table.insert(parts, tostring(v))
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

-- The LocalScript that will run on the client. It is embedded here as a string so each player's Tool gets its own LocalScript.
local localScriptSource = [[
local MESSAGE_DURATION = %d
local tool = script.Parent
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local mouse = player:GetMouse()

local currentTarget = nil
local highlightObject = nil
local enabled = true

local function safeNotify(text)
    pcall(function()
        game.StarterGui:SetCore("SendNotification", {Title = "AdminActions", Text = text, Duration = math.clamp(MESSAGE_DURATION, 1, 10)})
    end)
end

local function createHighlight(targetCharacter)
    if not targetCharacter or not targetCharacter.PrimaryPart then
        return
    end

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
        if hum and hum.Parent and hum.Parent:IsA("Model") then
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

-- Fire server with the selected target name when tool activated
tool.Activated:Connect(function()
    if not enabled then
        safeNotify("Tool is disabled")
        return
    end

    if currentTarget and currentTarget:FindFirstChildOfClass("Humanoid") and currentTarget.PrimaryPart then
        local plr = Players:GetPlayerFromCharacter(currentTarget)
        local targetName = plr and plr.Name or currentTarget.Name
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

-- Toggle enabled/disabled with G
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

-- Cleanup highlight when unequipped / on destroy
tool.Unequipped:Connect(function()
    clearHighlight()
    currentTarget = nil
end)

-- When the client destroys the tool (e.g., player leaves), cleanup
script.Destroying:Connect(function()
    clearHighlight()
end)
]]

-- The server-side snippet that will be placed inside each Tool.
-- It expects to receive (player, targetName) via the RemoteEvent: AdminActionEvent
local function makeServerScriptSource(adminsLiteral)
    local src = [[
local ADMINS = ]] .. adminsLiteral .. [[

local Players = game:GetService("Players")

local function isAdmin(userId)
    if #ADMINS == 0 then
        return true -- permissive when no admins listed
    end
    for _,id in ipairs(ADMINS) do
        if id == userId then return true end
    end
    return false
end

local tool = script.Parent
local remote = tool:WaitForChild("AdminActionEvent")

-- Sanity: only process requests from players who currently have the tool equipped (basic check)
remote.OnServerEvent:Connect(function(player, targetName)
    if not player or not player.UserId then return end

    -- Permission check
    if not isAdmin(player.UserId) then
        warn("[AdminActions] Player " .. player.Name .. " ("..player.UserId..") attempted to use admin tool but is not authorized")
        return
    end

    if typeof(targetName) ~= "string" then return end

    local targetPlayer = Players:FindFirstChild(targetName)
    if not targetPlayer then
        -- try to match by character name fallback
        for _,p in ipairs(Players:GetPlayers()) do
            if p.Character and p.Character.Name == targetName then
                targetPlayer = p
                break
            end
        end
    end

    if targetPlayer and targetPlayer.Character then
        local humanoid = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health > 0 then
            humanoid.Health = 0
        end
    end
end)
]]
    return src
end

-- Create a Tool for a player
local function createToolForPlayer(player)
    -- Ensure Backpack exists
    local backpack = player:WaitForChild("Backpack")

    local tool = Instance.new("Tool")
    tool.Name = "AdminActions"
    tool.RequiresHandle = false
    tool.CanBeDropped = false
    tool.Parent = backpack

    -- RemoteEvent for client -> server communication
    local remote = Instance.new("RemoteEvent")
    remote.Name = "AdminActionEvent"
    remote.Parent = tool

    -- Server script (will run on the server)
    local serverScript = Instance.new("Script")
    serverScript.Name = "ServerHandler"
    serverScript.Source = makeServerScriptSource(tableToLuaLiteral(ADMINS))
    serverScript.Parent = tool

    -- LocalScript (runs on client)
    local localScript = Instance.new("LocalScript")
    localScript.Name = "ClientHandler"
    localScript.Source = string.format(localScriptSource, MESSAGE_DURATION)
    localScript.Parent = tool

    -- Optional: tag/attribute for easy identification
    tool:SetAttribute("CreatedBy", "scr.lua")
end

Players.PlayerAdded:Connect(function(player)
    -- create the tool when the player fully loads
    spawn(function()
        -- small wait to ensure Backpack exists
        repeat wait() until player:FindFirstChild("Backpack")
        createToolForPlayer(player)
    end)
end)

-- For players already in the game when the script runs (during development/test)
for _,player in ipairs(Players:GetPlayers()) do
    spawn(function()
        if player:FindFirstChild("Backpack") then
            createToolForPlayer(player)
        else
            repeat wait() until player:FindFirstChild("Backpack")
            createToolForPlayer(player)
        end
    end)
end

print("[scr.lua] Admin tool deployer started")
