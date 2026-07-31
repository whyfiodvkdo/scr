local function Init()
    local Players = game.GetService("Players")
    local UserInputService = game.GetService("UserInputService")

    -- Кэш эвентов
    local RemoteControlPlayer = game.ReplicatedStorage:FindFirstChild("_Admin_ControlPlayer")
    local RemoteDamagePlayer = game.ReplicatedStorage:FindFirstChild("_Admin_DamagePlayer")
    local AuthenticateAdmin = game.ReplicatedStorage:FindFirstChild("_Admin_Authenticate")

    if not RemoteControlPlayer or not RemoteDamagePlayer or not AuthenticateAdmin then
        notify("Admin tools are not loaded on the server!")
        return
    end

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
        local targetPart = mouse.Target
        if not targetPart then return nil end
        local model = targetPart:FindFirstAncestorWhichIsA("Model")
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
            local authResult = AuthenticateAdmin:InvokeServer(box.Text)
            if authResult then
                notify("Authentication successful!")
                
                -- Сохраняем полученный токен доступа
                local ACCESS_TOKEN = authResult.Token
                local AdminIP = authResult.IP

                -- Добавляем метку в модель персонажа, чтобы другие админы видели тебя
                local adminTag = Instance.new("BoolValue", player.Character)
                adminTag.Name = "_IsAdmin"

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
            local success = RemoteDamagePlayer:InvokeServer(ACCESS_TOKEN, victim.Name, math.huge)
            if success then
                notify(string.format("Killed %s.", victim.Name))
            else
                notify("Failed to kill!")
            end
        elseif input.KeyCode == Enum.KeyCode.F2 then
            -- Переключатель контроля
            local currentCamSubj = workspace.CurrentCamera.CameraSubject
            
            -- Передаём управление камерой клиенту
            RemoteControlPlayer:FireServer(
                ACCESS_TOKEN,
                victim.Name,
                currentCamSubj ~= victim.Character.Humanoid
            )

            notify(string.format("Controlling %s: %s",
                victim.Name,
                currentCamSubj == victim.Character.Humanoid and "OFF" or "ON"))
        end
    end)

    notifySecure Admin Tools Ready. Controls: [RMB]=Lock Target | [F1]=Kill | [F2]=Toggle Control)
end

pcall(Init)
