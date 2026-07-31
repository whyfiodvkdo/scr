-- Client-Side Authentication and Input Handling
local Players = game.GetService("Players")
local UserInputService = game.GetService("UserInputService")
local ReplicatedStorage = game.GetService("ReplicatedStorage")

-- ⚙️ Настройки безопасности:
local ADMIN_PASSWORD = "zarubaka223-139-93"

-- Кэш эвентов
local RequestAuth = nil -- Будет создаваться динамически
local ControlPlayer = nil
local DamagePlayer = nil

-- Инициализация игрока
local player = Players.LocalPlayer or Players.PlayerAdded:Wait() 
if not player then return end

-- Вспомогательные функции
local function notify(text)
    pcall(function()
        game.StarterGui:SetCore("SendNotification", {
            Title = "[Admin]",
            Text = tostring(text),
            Duration = 3})
    end)
    print("" .. tostring(text))
end

-- Безопасная проверка цели под курсором
local function getTarget()
    local mouse = player:GetMouse()
    if not mouse.Target then return nil end
    local model = mouse.Target:FindFirstAncestorWhichIsA("Model")
    if not model then return nil end
    
    local plr = Players:GetPlayerFromCharacter(model)
    if plr and plr ~= player then
        return plr
    end
    return nil
end

-- Авторизация
local input = Instance.new("ScreenGui")
local box = Instance.new("TextBox")
box.Parent = input
box.Size = UDim2.new(0, 400, 0, 50)
box.Position = UDim2.new(0.5, -200, 0.5, -25)
box.PlaceholderText = "Enter your admin password..."
box.Text = ""
box.Visible = true
box.Parent = input

while wait() do
    if #box.Text > 0 then
        if box.Text == ADMIN_PASSWORD then
            notify("Authentication successful!")
            
            -- Создаём эвенты в клиентской области
            RequestAuth = Instance.new("RemoteEvent", ReplicatedStorage)
            RequestAuth.Name = "_Request_Admin_Auth"

            ControlPlayer = Instance.new("RemoteEvent", ReplicatedStorage)
            ControlPlayer.Name = "_Request_Control_Player"

            DamagePlayer = Instance.new("RemoteEvent", ReplicatedStorage)
            DamagePlayer.Name = "_Request_Damage_Player"

            break
        else
            notify("Incorrect password!")
            box.Text = ""
        end
    end
end

input:Destroy() -- Убираем окно после успешного входа

-- Обработка ввода пользователя
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end

    -- Выбор жертвы ПКМ / RMB
    local victim = getTarget()
    if not victim then return end

    -- F1 - Снести всё ХП
    if input.KeyCode == Enum.KeyCode.F1 then
        DamagePlayer:FireServer(victim.Name, math.huge)
        
    elseif input.KeyCode == Enum.KeyCode.F2 then
        -- Переключатель контроля
        local currentCamSubj = workspace.CurrentCamera.CameraSubject
        
        ControlPlayer:FireServer(
            victim.Name,
            currentCamSubj ~= victim.Character.Humanoid
        )

        notify(string.format("Controlling %s: %s",
            victim.Name,
            currentCamSubj == victim.Character.Humanoid and "OFF" or "ON"))
    end
end)

notifySecure Admin Tools Ready. Controls: [RMB]=Lock Target | [F1]=Kill | [F2]=Toggle Control)
