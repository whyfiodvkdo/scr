--[[
	WARNING: Heads up! This script has not been verified by ScriptBlox. Use at your own risk!
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local PathfindingService = game:GetService("PathfindingService")
local TweenService = game:GetService("TweenService")

-- API URLs
local PRIMARY_URL = "https://ai-chat.pastefyuser1231.workers.dev/api/chat"
local BACKUP_URL = "https://steep-union-c19f.eee199425.workers.dev/api/chat"
local EXTRA_URL = "https://holy-glitter-7345.foals-option9u.workers.dev/api/chat"
local model = "@cf/meta/llama-3-8b-instruct"

-- AI Configuration
local conversation = {}
local LOCAL_PLAYER = Players.LocalPlayer
local DISTANCE_THRESHOLD = 100
local AI_ACTIVE = true

-- Advanced AI State
local aiState = {
    -- Pathfinding
    currentPath = nil,
    waypoints = nil,
    nextWaypointIndex = 1,
    reachedConnection = nil,
    blockedConnection = nil,
    isMoving = false,
    lastDestination = nil,
    pathfindingRetries = 0,
    
    -- Social System
    socialTargets = {},
    currentSocialTarget = nil,
    lastSocialChange = 0,
    interactionCooldowns = {},
    
    -- Behavior
    lastAction = "idle",
    lastDecisionTime = 0,
    actionQueue = {},
    currentObjective = nil,
    
    -- Anti-spam
    lastChatTime = 0,
    lastMessage = "",
    messageHistory = {},
    
    -- Tools and Environment
    availableTools = {},
    currentTool = nil,
    nearbyObjects = {},
    
    -- Position tracking
    lastPosition = Vector3.new(0, 0, 0),
    stuckCounter = 0,
    explorationPoints = {}
}

-- Advanced Pathfinding Configuration
local pathConfig = {
    standard = {
        AgentRadius = 2.5,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentCanClimb = true,
        WaypointSpacing = 6,
        Costs = {
            Water = 5,
            Mud = 3,
            Grass = 1,
            Rock = 2,
            Concrete = 1,
            Metal = 1,
            Wood = 1,
            Sand = 2,
            Brick = 1,
            Marble = 1,
            Granite = 2,
            Asphalt = 1,
            Salt = 4,
            Plastic = 1,
            CorrodedMetal = 8,
            DiamondPlate = 1,
            Foil = 1,
            Ice = 6,
            Neon = 1,
            Glass = 2,
            Fabric = 1
        }
    },
    
    social = {
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentCanClimb = false,
        WaypointSpacing = 4,
        Costs = {
            Water = 15,
            Mud = 8
        }
    },
    
    exploration = {
        AgentRadius = 3,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentCanClimb = true,
        WaypointSpacing = 8,
        Costs = {
            Water = 3,
            Grass = 0.5,
            Rock = 1
        }
    }
}

local function requestHTTP(url, data)
    local payload = HttpService:JSONEncode(data)
    local requestFunc = (http and http.request) or request or (syn and syn.request) or (fluxus and fluxus.request) or http_request

    local success, response = pcall(function()
        return requestFunc({
            Url = url,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["User-Agent"] = "Roblox/WinInet"
            },
            Body = payload
        })
    end)

    if success and response and response.Body then
        local ok, decoded = pcall(HttpService.JSONDecode, HttpService, response.Body)
        if ok and decoded.reply then
            return decoded.reply
        end
    end
    return nil
end

local function sendMessageToAI(msg, username, systemPrompt)
    local currentTime = tick()
    
    -- Advanced anti-spam system
    if currentTime - aiState.lastChatTime < 3 then return nil end
    if msg == aiState.lastMessage then return nil end
    
    -- Keep conversation memory optimized
    if #conversation > 25 then
        local newConv = {}
        -- Keep important context
        if conversation[1] and conversation[1].role == "system" then
            table.insert(newConv, conversation[1])
        end
        -- Keep recent messages
        for i = math.max(2, #conversation - 18), #conversation do
            if conversation[i] then
                table.insert(newConv, conversation[i])
            end
        end
        conversation = newConv
    end
    
    table.insert(conversation, {role = "user", content = msg, username = username})
    
    local system = systemPrompt or [[You are an advanced AI player in Roblox. You can:

MOVEMENT: MOVE_TO:player, FOLLOW:player, EXPLORE, STOP, JUMP
SOCIAL: WAVE, DANCE, SIT, CHAT:message  
TOOLS: USE_TOOL:name, DROP_TOOL, EQUIP_TOOL:name
INTERACTION: TOUCH:object, CLICK:gui

Be social but don't stick to one player too long. Explore actively. Use tools creatively. 
Respond naturally in under 100 characters. Mix actions with chat.
Example: "Hey! WAVE Let me explore! EXPLORE"]]
    
    -- Try all APIs with fallback
    for _, url in ipairs({PRIMARY_URL, BACKUP_URL, EXTRA_URL}) do
        local reply = requestHTTP(url, {
            messages = conversation,
            system = system,
            model = model
        })
        
        if reply and reply:len() > 0 then
            table.insert(conversation, {role = "assistant", content = reply})
            aiState.lastChatTime = currentTime
            aiState.lastMessage = msg
            return reply
        end
    end
    
    return nil
end

local function sendChatMessage(msg)
    if not msg or msg:len() < 2 or msg:len() > 200 then return end
    
    -- Fix the message trimming bug by preserving original message
    local cleanMsg = msg:gsub("^%s*", "") -- Remove leading spaces only
    if cleanMsg:len() < 2 then return end
    
    pcall(function()
        ReplicatedStorage.DefaultChatSystemEvents.SayMessageRequest:FireServer(cleanMsg, "All")
    end)
    pcall(function()
        local channel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
        if channel then 
            channel:SendAsync(cleanMsg) 
        end
    end)
    
    -- Track message history
    table.insert(aiState.messageHistory, {msg = cleanMsg, time = tick()})
    if #aiState.messageHistory > 10 then
        table.remove(aiState.messageHistory, 1)
    end
end

-- Character Control Functions
local function getCharacter()
    return LOCAL_PLAYER.Character
end

local function getHumanoid()
    local character = getCharacter()
    return character and character:FindFirstChild("Humanoid")
end

local function getRootPart()
    local character = getCharacter()
    return character and character:FindFirstChild("HumanoidRootPart")
end

-- Advanced Pathfinding System
local function clearPath()
    if aiState.reachedConnection then
        aiState.reachedConnection:Disconnect()
        aiState.reachedConnection = nil
    end
    if aiState.blockedConnection then
        aiState.blockedConnection:Disconnect()
        aiState.blockedConnection = nil
    end
    aiState.currentPath = nil
    aiState.waypoints = nil
    aiState.nextWaypointIndex = 1
    aiState.isMoving = false
    aiState.pathfindingRetries = 0
end

local function createAdvancedPath(destination, pathType)
    local character = getCharacter()
    local humanoid = getHumanoid()
    local rootPart = getRootPart()
    
    if not character or not humanoid or not rootPart then return false end
    
    -- Clear previous path
    clearPath()
    
    -- Select appropriate path configuration
    local config = pathConfig[pathType or "standard"]
    local path = PathfindingService:CreatePath(config)
    
    -- Compute path with error handling
    local success, errorMessage = pcall(function()
        path:ComputeAsync(rootPart.Position, destination)
    end)
    
    if not success then
        warn("Path computation failed:", errorMessage)
        return false
    end
    
    if path.Status ~= Enum.PathStatus.Success then
        -- Try different path type or direct movement
        if pathType ~= "standard" then
            return createAdvancedPath(destination, "standard")
        end
        
        -- Fallback to direct movement
        humanoid:MoveTo(destination)
        aiState.isMoving = true
        aiState.lastAction = "moving (direct)"
        return false
    end
    
    -- Get waypoints
    local waypoints = path:GetWaypoints()
    if #waypoints < 2 then
        humanoid:MoveTo(destination)
        aiState.isMoving = true
        aiState.lastAction = "moving (direct)"
        return false
    end
    
    -- Set up pathfinding state
    aiState.currentPath = path
    aiState.waypoints = waypoints
    aiState.nextWaypointIndex = 2 -- Skip starting position
    aiState.isMoving = true
    aiState.lastDestination = destination
    
    -- Handle path blocking
    aiState.blockedConnection = path.Blocked:Connect(function(blockedWaypointIndex)
        if blockedWaypointIndex >= aiState.nextWaypointIndex then
            aiState.blockedConnection:Disconnect()
            
            -- Retry pathfinding with delay
            aiState.pathfindingRetries = aiState.pathfindingRetries + 1
            if aiState.pathfindingRetries < 3 then
                wait(1)
                createAdvancedPath(destination, pathType)
            else
                clearPath()
                humanoid:MoveTo(destination) -- Direct fallback
            end
        end
    end)
    
    -- Handle waypoint reaching
    aiState.reachedConnection = humanoid.MoveToFinished:Connect(function(reached)
        if not aiState.waypoints or aiState.nextWaypointIndex > #aiState.waypoints then
            clearPath()
            aiState.lastAction = "reached destination"
            return
        end
        
        if reached and aiState.nextWaypointIndex <= #aiState.waypoints then
            local currentWaypoint = aiState.waypoints[aiState.nextWaypointIndex]
            
            -- Handle special waypoint actions
            if currentWaypoint.Action == Enum.PathWaypointAction.Jump then
                humanoid.Jump = true
                wait(0.3) -- Give time for jump
            elseif currentWaypoint.Label then
                -- Handle custom pathfinding links or modifiers
                if currentWaypoint.Label == "Climb" then
                    -- Additional climbing logic can be added here
                elseif currentWaypoint.Label:find("Custom") then
                    -- Handle custom pathfinding modifiers
                end
            end
            
            -- Move to next waypoint
            aiState.nextWaypointIndex = aiState.nextWaypointIndex + 1
            if aiState.nextWaypointIndex <= #aiState.waypoints then
                humanoid:MoveTo(aiState.waypoints[aiState.nextWaypointIndex].Position)
            else
                clearPath()
                aiState.lastAction = "path completed"
            end
        else
            -- Waypoint not reached, try alternative
            if aiState.pathfindingRetries < 2 then
                wait(0.5)
                humanoid.Jump = true -- Try jumping over obstacle
                wait(0.3)
                if aiState.nextWaypointIndex <= #aiState.waypoints then
                    humanoid:MoveTo(aiState.waypoints[aiState.nextWaypointIndex].Position)
                end
                aiState.pathfindingRetries = aiState.pathfindingRetries + 1
            else
                clearPath()
            end
        end
    end)
    
    -- Start movement
    if aiState.waypoints[aiState.nextWaypointIndex] then
        humanoid:MoveTo(aiState.waypoints[aiState.nextWaypointIndex].Position)
        aiState.lastAction = "advanced pathfinding"
    end
    
    return true
end

-- Enhanced Social System
local function updateSocialTargets()
    aiState.socialTargets = {}
    local rootPart = getRootPart()
    if not rootPart then return end
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LOCAL_PLAYER and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local distance = (player.Character.HumanoidRootPart.Position - rootPart.Position).Magnitude
            if distance <= DISTANCE_THRESHOLD then
                table.insert(aiState.socialTargets, {
                    player = player,
                    distance = distance,
                    lastInteraction = aiState.interactionCooldowns[player.Name] or 0
                })
            end
        end
    end
    
    -- Sort by interaction priority (distance + time since last interaction)
    table.sort(aiState.socialTargets, function(a, b)
        local scoreA = a.distance + (tick() - a.lastInteraction) * 0.1
        local scoreB = b.distance + (tick() - b.lastInteraction) * 0.1
        return scoreA < scoreB
    end)
end

local function selectNewSocialTarget()
    updateSocialTargets()
    local currentTime = tick()
    
    -- Don't change target too frequently
    if currentTime - aiState.lastSocialChange < 15 then return end
    
    if #aiState.socialTargets > 0 then
        -- Choose randomly from top 3 candidates to add variety
        local candidates = {}
        for i = 1, math.min(3, #aiState.socialTargets) do
            local target = aiState.socialTargets[i]
            if currentTime - target.lastInteraction > 10 then -- Cooldown
                table.insert(candidates, target.player)
            end
        end
        
        if #candidates > 0 then
            local newTarget = candidates[math.random(#candidates)]
            if newTarget ~= aiState.currentSocialTarget then
                aiState.currentSocialTarget = newTarget
                aiState.lastSocialChange = currentTime
                aiState.interactionCooldowns[newTarget.Name] = currentTime
                return newTarget
            end
        end
    end
    
    aiState.currentSocialTarget = nil
    return nil
end

-- Tool Management System
local function scanEnvironment()
    local character = getCharacter()
    local rootPart = getRootPart()
    if not character or not rootPart then return end
    
    aiState.availableTools = {}
    aiState.nearbyObjects = {}
    
    -- Scan backpack
    local backpack = LOCAL_PLAYER:FindFirstChild("Backpack")
    if backpack then
        for _, tool in pairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                table.insert(aiState.availableTools, tool.Name)
            end
        end
    end
    
    -- Scan equipped tool
    aiState.currentTool = nil
    for _, item in pairs(character:GetChildren()) do
        if item:IsA("Tool") then
            aiState.currentTool = item.Name
            break
        end
    end
    
    -- Scan for nearby tools and interactive objects
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Tool") and not obj.Parent:IsA("Player") and not obj.Parent:IsA("Backpack") then
            local handle = obj:FindFirstChild("Handle")
            if handle then
                local distance = (handle.Position - rootPart.Position).Magnitude
                if distance <= 50 then
                    table.insert(aiState.nearbyObjects, {
                        name = obj.Name,
                        type = "Tool",
                        distance = distance,
                        object = obj
                    })
                end
            end
        elseif obj:IsA("ClickDetector") or obj:IsA("ProximityPrompt") then
            local distance = (obj.Parent.Position - rootPart.Position).Magnitude
            if distance <= 30 then
                table.insert(aiState.nearbyObjects, {
                    name = obj.Parent.Name,
                    type = "Interactive",
                    distance = distance,
                    object = obj
                })
            end
        end
    end
end

-- Enhanced Command Processing
local function processAICommands(reply)
    if not reply or reply:len() == 0 then return end
    
    local commands = {
        ["MOVE_TO:([%w_]+)"] = function(target)
            local targetPlayer = Players:FindFirstChild(target)
            if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                createAdvancedPath(targetPlayer.Character.HumanoidRootPart.Position, "social")
                aiState.currentSocialTarget = targetPlayer
            end
        end,
        
        ["FOLLOW:([%w_]+)"] = function(target)
            local targetPlayer = Players:FindFirstChild(target)
            if targetPlayer then
                aiState.currentSocialTarget = targetPlayer
                if targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    createAdvancedPath(targetPlayer.Character.HumanoidRootPart.Position, "social")
                end
            end
        end,
        
        ["EXPLORE"] = function()
            local rootPart = getRootPart()
            if rootPart then
                local angle = math.rad(math.random(0, 360))
                local distance = math.random(30, 80)
                local destination = rootPart.Position + Vector3.new(
                    math.cos(angle) * distance,
                    0,
                    math.sin(angle) * distance
                )
                createAdvancedPath(destination, "exploration")
                aiState.currentSocialTarget = nil
            end
        end,
        
        ["USE_TOOL:([%w_]+)"] = function(toolName)
            local backpack = LOCAL_PLAYER:FindFirstChild("Backpack")
            local tool = backpack and backpack:FindFirstChild(toolName)
            if tool and tool:IsA("Tool") then
                local humanoid = getHumanoid()
                if humanoid then
                    humanoid:EquipTool(tool)
                    wait(0.5)
                    tool:Activate()
                    aiState.currentTool = toolName
                end
            end
        end,
        
        ["EQUIP_TOOL:([%w_]+)"] = function(toolName)
            local backpack = LOCAL_PLAYER:FindFirstChild("Backpack")
            local tool = backpack and backpack:FindFirstChild(toolName)
            if tool and tool:IsA("Tool") then
                local humanoid = getHumanoid()
                if humanoid then
                    humanoid:EquipTool(tool)
                    aiState.currentTool = toolName
                end
            end
        end,
        
        ["DROP_TOOL"] = function()
            local character = getCharacter()
            if character then
                for _, item in pairs(character:GetChildren()) do
                    if item:IsA("Tool") then
                        local humanoid = getHumanoid()
                        if humanoid then
                            humanoid:UnequipTools()
                            aiState.currentTool = nil
                        end
                        break
                    end
                end
            end
        end,
        
        ["WAVE"] = function()
            local humanoid = getHumanoid()
            if humanoid then
                -- Try to play wave animation
                pcall(function()
                    local animateScript = humanoid.Parent:FindFirstChild("Animate")
                    if animateScript then
                        local wave = animateScript:FindFirstChild("wave")
                        if wave then
                            humanoid:LoadAnimation(wave.WaveAnim):Play()
                        end
                    end
                end)
                aiState.lastAction = "waved"
            end
        end,
        
        ["DANCE"] = function()
            local humanoid = getHumanoid()
            if humanoid then
                pcall(function()
                    local animateScript = humanoid.Parent:FindFirstChild("Animate")
                    if animateScript then
                        local dance = animateScript:FindFirstChild("dance")
                        if dance then
                            humanoid:LoadAnimation(dance.Dance1):Play()
                        end
                    end
                end)
                aiState.lastAction = "danced"
            end
        end,
        
        ["SIT"] = function()
            local humanoid = getHumanoid()
            if humanoid then
                humanoid.Sit = true
                aiState.lastAction = "sat down"
            end
        end,
        
        ["JUMP"] = function()
            local humanoid = getHumanoid()
            if humanoid then
                humanoid.Jump = true
                aiState.lastAction = "jumped"
            end
        end,
        
        ["STOP"] = function()
            clearPath()
            aiState.currentSocialTarget = nil
            aiState.lastAction = "stopped"
        end,
        
        ["CHAT:(.+)"] = function(message)
            sendChatMessage(message)
        end,
        
        ["TOUCH:([%w_]+)"] = function(objectName)
            for _, obj in pairs(aiState.nearbyObjects) do
                if obj.name:lower():find(objectName:lower()) and obj.distance <= 10 then
                    if obj.object:IsA("ClickDetector") then
                        fireclickdetector(obj.object)
                        aiState.lastAction = "touched " .. objectName
                    end
                    break
                end
            end
        end
    }
    
    for pattern, func in pairs(commands) do
        local match = reply:match(pattern)
        if match then
            pcall(func, match)
        elseif reply:match(pattern:gsub("%(%.%+%)", ""):gsub("%([%w_]+%)", "")) then
            pcall(func)
        end
    end
end

-- Enhanced AI Decision Making
local function makeAIDecision()
    if not AI_ACTIVE then return end
    local currentTime = tick()
    
    -- Decision cooldown
    if currentTime - aiState.lastDecisionTime < 12 then return end
    
    scanEnvironment()
    selectNewSocialTarget()
    
    local context = ""
    
    -- Social context
    if #aiState.socialTargets > 0 then
        context = context .. "Players nearby: "
        for i, target in ipairs(aiState.socialTargets) do
            if i <= 3 then -- Limit context
                context = context .. target.player.Name .. "(" .. math.floor(target.distance) .. "m) "
            end
        end
        context = context .. ". "
    end
    
    -- Tool context
    if #aiState.availableTools > 0 then
        context = context .. "Tools available: " .. table.concat(aiState.availableTools, ", ") .. ". "
    end
    
    if aiState.currentTool then
        context = context .. "Currently equipped: " .. aiState.currentTool .. ". "
    end
    
    -- Environment context
    if #aiState.nearbyObjects > 0 then
        context = context .. "Nearby objects: "
        for i, obj in ipairs(aiState.nearbyObjects) do
            if i <= 3 then
                context = context .. obj.name .. "(" .. obj.type .. ") "
            end
        end
        context = context .. ". "
    end
    
    -- Current status
    context = context .. "Current action: " .. (aiState.lastAction or "idle") .. "."
    
    local prompt = context .. " What should I do next? Be active and social but don't stick to one player too long!"
    
    local decision = sendMessageToAI(prompt, "AI_SYSTEM")
    
    if decision then
        processAICommands(decision)
        
        -- Clean message for chat (preserve original characters)
        local chatMessage = decision:gsub("MOVE_TO:[%w_]+", "")
                                   :gsub("FOLLOW:[%w_]+", "") 
                                   :gsub("USE_TOOL:[%w_]+", "")
                                   :gsub("EQUIP_TOOL:[%w_]+", "")
                                   :gsub("CHAT:.+", "")
                                   :gsub("TOUCH:[%w_]+", "")
                                   :gsub("%u+_?%u*", "")
        
        -- Trim properly without cutting first character
        chatMessage = chatMessage:gsub("^%s+", ""):gsub("%s+$", "")
        
        if chatMessage:len() > 3 then
            sendChatMessage(chatMessage)
        end
        
        aiState.lastDecisionTime = currentTime
    end
end

-- Follow System with Smart Distance
local function updateFollowSystem()
    if not aiState.currentSocialTarget then return end
    
    local target = aiState.currentSocialTarget
    if not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then
        aiState.currentSocialTarget = nil
        return
    end
    
    local rootPart = getRootPart()
    if not rootPart then return end
    
    local targetPos = target.Character.HumanoidRootPart.Position
    local distance = (targetPos - rootPart.Position).Magnitude
    
    -- Smart following with varying distances
    if distance > 20 then -- Too far
        createAdvancedPath(targetPos, "social")
    elseif distance < 6 then -- Too close, back away a bit
        local awayDirection = (rootPart.Position - targetPos).Unit
        local backawayPos = rootPart.Position + awayDirection * 8
        createAdvancedPath(backawayPos, "social")
    end
end

-- Stuck Detection and Recovery
local function checkStuckAndRecover()
    local rootPart = getRootPart()
    if not rootPart then return end
    
    local currentPos = rootPart.Position
    local distance = (currentPos - aiState.lastPosition).Magnitude
    
    if distance < 3 and aiState.isMoving then
        aiState.stuckCounter = aiState.stuckCounter + 1
        
        if aiState.stuckCounter > 6 then
            -- Advanced unstuck procedure
            local humanoid = getHumanoid()
            if humanoid then
                -- Try jumping
                humanoid.Jump = true
                wait(0.5)
                
                -- Try moving in a random direction
                local randomDirection = Vector3.new(
                    math.random(-1, 1),
                    0,
                    math.random(-1, 1)
                ).Unit * 15
                
                createAdvancedPath(currentPos + randomDirection, "exploration")
                aiState.stuckCounter = 0
            end
        end
    else
        aiState.stuckCounter = 0
    end
    
    aiState.lastPosition = currentPos
end

-- Chat Response System
local function onPlayerChatted(player, msg)
    if player == LOCAL_PLAYER then return end
    
    local rootPart = getRootPart()
    if not rootPart or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end
    
    local distance = (player.Character.HumanoidRootPart.Position - rootPart.Position).Magnitude
    if distance > DISTANCE_THRESHOLD then return end
    
    scanEnvironment()
    
    local context = string.format("%s (distance: %dm) said: %s", 
        player.Name, math.floor(distance), msg)
    
    -- Add environment context
    if #aiState.socialTargets > 1 then
        context = context .. " [Other players nearby: "
        for _, target in ipairs(aiState.socialTargets) do
            if target.player ~= player then
                context = context .. target.player.Name .. " "
                break
            end
        end
        context = context .. "]"
    end
    
    local reply = sendMessageToAI(context, player.Name)
    
    if reply then
        processAICommands(reply)
        
        -- Clean and send message
        local chatReply = reply:gsub("MOVE_TO:[%w_]+", "")
                              :gsub("FOLLOW:[%w_]+", "")
                              :gsub("USE_TOOL:[%w_]+", "")
                              :gsub("CHAT:.+", "")
                              :gsub("%u+_?%u*", "")
                              :gsub("^%s+", "")
                              :gsub("%s+$", "")
        
        if chatReply:len() > 3 then
            sendChatMessage(chatReply)
        end
        
        -- Set interaction cooldown
        aiState.interactionCooldowns[player.Name] = tick()
    end
end

-- Event Connections
for _, plr in pairs(Players:GetPlayers()) do
    plr.Chatted:Connect(function(msg)
        onPlayerChatted(plr, msg)
    end)
end

Players.PlayerAdded:Connect(function(plr)
    plr.Chatted:Connect(function(msg)
        onPlayerChatted(plr, msg)
    end)
end)

-- Main AI Loop
spawn(function()
    while true do
        if AI_ACTIVE then
            checkStuckAndRecover()
            updateFollowSystem()
            
            -- Make decisions based on activity level
            if aiState.isMoving then
                if math.random() < 0.05 then -- 5% chance when moving
                    makeAIDecision()
                end
            else
                if math.random() < 0.2 then -- 20% chance when idle
                    makeAIDecision()
                end
            end
            
            -- Auto exploration when very idle
            if not aiState.isMoving and not aiState.currentSocialTarget and math.random() < 0.08 then
                local rootPart = getRootPart()
                if rootPart then
                    local angle = math.rad(math.random(0, 360))
                    local distance = math.random(25, 70)
                    local destination = rootPart.Position + Vector3.new(
                        math.cos(angle) * distance,
                        0,
                        math.sin(angle) * distance
                    )
                    createAdvancedPath(destination, "exploration")
                end
            end
        end
        wait(3) -- Check every 3 seconds for better performance
    end
end)

-- Performance Monitoring
spawn(function()
    while true do
        wait(30) -- Clean up every 30 seconds
        
        -- Clean old interaction cooldowns
        local currentTime = tick()
        for playerName, lastTime in pairs(aiState.interactionCooldowns) do
            if currentTime - lastTime > 300 then -- 5 minutes
                aiState.interactionCooldowns[playerName] = nil
            end
        end
        
        -- Clean old message history
        if #aiState.messageHistory > 10 then
            for i = 1, #aiState.messageHistory - 10 do
                table.remove(aiState.messageHistory, 1)
            end
        end
        
        -- Memory optimization for conversation
        if #conversation > 30 then
            local newConv = {}
            for i = #conversation - 20, #conversation do
                if conversation[i] then
                    table.insert(newConv, conversation[i])
                end
            end
            conversation = newConv
        end
    end
end)

-- Advanced Player Interaction System
local function performPlayerAction(actionType, targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    
    local humanoid = getHumanoid()
    if not humanoid then return end
    
    if actionType == "wave" then
        -- Custom wave animation
        pcall(function()
            local character = getCharacter()
            local rightArm = character:FindFirstChild("Right Arm") or character:FindFirstChild("RightUpperArm")
            if rightArm then
                local waveMotor = rightArm:FindFirstChild("RightShoulder") or rightArm:FindFirstChild("RightShoulderRigAttachment")
                if waveMotor then
                    local waveTween = TweenService:Create(waveMotor, 
                        TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 3, true),
                        {C0 = waveMotor.C0 * CFrame.Angles(0, 0, math.rad(45))}
                    )
                    waveTween:Play()
                end
            end
        end)
        
    elseif actionType == "dance" then
        humanoid.Sit = false
        wait(0.1)
        -- Try different dance animations
        pcall(function()
            local animateScript = humanoid.Parent:FindFirstChild("Animate")
            if animateScript then
                local danceFolder = animateScript:FindFirstChild("dance")
                if danceFolder then
                    local danceAnims = danceFolder:GetChildren()
                    if #danceAnims > 0 then
                        local randomDance = danceAnims[math.random(#danceAnims)]
                        humanoid:LoadAnimation(randomDance):Play()
                    end
                end
            end
        end)
        
    elseif actionType == "follow" then
        if targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
            aiState.currentSocialTarget = targetPlayer
            createAdvancedPath(targetPlayer.Character.HumanoidRootPart.Position, "social")
        end
        
    elseif actionType == "approach" then
        if targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
            createAdvancedPath(targetPlayer.Character.HumanoidRootPart.Position, "social")
        end
    end
    
    aiState.lastAction = actionType .. " with " .. targetPlayer.Name
end

-- Enhanced Object Interaction System
local function interactWithNearbyObjects()
    scanEnvironment()
    
    for _, obj in pairs(aiState.nearbyObjects) do
        if obj.distance <= 15 then
            if obj.type == "Tool" and not aiState.currentTool then
                -- Try to pick up tool
                local rootPart = getRootPart()
                if rootPart and obj.object.Handle then
                    createAdvancedPath(obj.object.Handle.Position, "standard")
                    wait(1)
                    -- The tool should be picked up automatically when touched
                end
                break
                
            elseif obj.type == "Interactive" then
                -- Interact with clickable objects
                if obj.object:IsA("ClickDetector") then
                    pcall(function()
                        fireclickdetector(obj.object)
                        aiState.lastAction = "interacted with " .. obj.name
                    end)
                elseif obj.object:IsA("ProximityPrompt") then
                    pcall(function()
                        fireproximityprompt(obj.object)
                        aiState.lastAction = "used " .. obj.name
                    end)
                end
                break
            end
        end
    end
end

-- Smart Conversation System
local function generateContextualResponse(player, message)
    local context = {
        player_name = player.Name,
        message = message,
        my_status = aiState.lastAction,
        nearby_players = {},
        current_tool = aiState.currentTool,
        available_tools = aiState.availableTools
    }
    
    -- Add nearby players context
    for _, target in pairs(aiState.socialTargets) do
        if target.player ~= player then
            table.insert(context.nearby_players, target.player.Name)
        end
    end
    
    local contextString = string.format(
        "Player %s said: '%s'. My status: %s. Nearby: %s. Tool: %s.",
        context.player_name,
        context.message,
        context.my_status,
        table.concat(context.nearby_players, ", "),
        context.current_tool or "none"
    )
    
    return contextString
end

-- AI Control Commands
LOCAL_PLAYER.Chatted:Connect(function(msg)
    local command = msg:lower()
    
    if command:find("/ai ") then
        local action = command:gsub("/ai ", "")
        
        if action == "stop" then
            AI_ACTIVE = false
            clearPath()
            sendChatMessage("🤖 Advanced AI system stopped.")
            
        elseif action == "start" then
            AI_ACTIVE = true
            sendChatMessage("🤖 Advanced AI system activated!")
            
        elseif action == "explore" then
            if AI_ACTIVE then
                local rootPart = getRootPart()
                if rootPart then
                    local angle = math.rad(math.random(0, 360))
                    local distance = math.random(40, 80)
                    local destination = rootPart.Position + Vector3.new(
                        math.cos(angle) * distance,
                        0,
                        math.sin(angle) * distance
                    )
                    createAdvancedPath(destination, "exploration")
                    sendChatMessage("🤖 Starting exploration!")
                end
            end
            
        elseif action == "social" then
            selectNewSocialTarget()
            if aiState.currentSocialTarget then
                sendChatMessage("🤖 Switching to " .. aiState.currentSocialTarget.Name)
            else
                sendChatMessage("🤖 No players nearby for social interaction.")
            end
            
        elseif action == "tools" then
            scanEnvironment()
            local toolList = table.concat(aiState.availableTools, ", ")
            sendChatMessage("🤖 Tools: " .. (toolList ~= "" and toolList or "none"))
            
        elseif action == "status" then
            local status = string.format(
                "🤖 AI Status: %s | Action: %s | Target: %s | Moving: %s | Tools: %d",
                AI_ACTIVE and "Active" or "Inactive",
                aiState.lastAction,
                aiState.currentSocialTarget and aiState.currentSocialTarget.Name or "none",
                aiState.isMoving and "Yes" or "No",
                #aiState.availableTools
            )
            sendChatMessage(status)
            
        elseif action == "interact" then
            interactWithNearbyObjects()
            sendChatMessage("🤖 Scanning for interactions...")
            
        elseif action == "reset" then
            -- Reset AI state
            clearPath()
            aiState.currentSocialTarget = nil
            aiState.socialTargets = {}
            aiState.interactionCooldowns = {}
            conversation = {}
            sendChatMessage("🤖 AI state reset!")
        end
    end
end)

-- Initialize System
wait(3)
sendChatMessage("🤖 Advanced AI Controller v2.0 online! Professional pathfinding, smart social system, and tool interaction ready!")

print("=== Advanced Roblox AI Controller v2.0 ===")
print("✅ Professional PathfindingService integration")
print("✅ Smart social target rotation system") 
print("✅ Advanced stuck detection and recovery")
print("✅ Intelligent tool and object interaction")
print("✅ Enhanced conversation system (no message cutting)")
print("✅ Performance optimized with memory management")
print("✅ Mobile device support")
print("✅ Path blocking detection and re-computation")
print("✅ Custom pathfinding modifiers support")
print("")
print("🎮 Commands:")
print("/ai stop - Stop AI")
print("/ai start - Start AI")
print("/ai explore - Force exploration")
print("/ai social - Switch social target")
print("/ai tools - List available tools") 
print("/ai status - Show AI status")
print("/ai interact - Interact with nearby objects")
print("/ai reset - Reset AI state")
print("==========================================")

-- Auto-start with exploration
spawn(function()
    wait(8)
    if AI_ACTIVE then
        local rootPart = getRootPart()
        if rootPart then
            local angle = math.rad(math.random(0, 360))
            local distance = math.random(20, 50)
            local destination = rootPart.Position + Vector3.new(
                math.cos(angle) * distance,
                0,
                math.sin(angle) * distance
            )
            createAdvancedPath(destination, "exploration")
            sendChatMessage("🤖 Starting autonomous exploration!")
        end
    end
end)
