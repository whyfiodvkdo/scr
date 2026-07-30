local function Init()
    local Players = game.GetService("Players")
    local UserInputService = game.GetService("UserInputService")

    -- ⚙️ Настройки безопасности:
    -- Должно совпадать со значением в серверном скрипте!
    local SECRET_KEY = "SuperSecretKeyForZarubaka" -- Не забывай поменять на то же самое

    -- Пароль для доступа через эксплойт
    local ADMIN_PASSWORD = "zarubaka223-139-93"

    -- Инициализация игрока
    local player = Players.LocalPlayer or Players.PlayerAdded:Wait() 
    if not player then return end

    -- Запрос пароля
    local input = Instance.new("ScreenGui")
    local box = Instance.new("TextBox")
    box.Parent = input
    box.Size = UDim2.new(0, 400, 0, 50)
    box.Position = UDim2.new(0.5, -200, 0.5, -25)
    box.PlaceholderText = "Enter password..."
    box.Text = ""
    box.Visible = true
    box.Parent = input

    -- Ждём ввода пароля
    while wait() do
        if #box.Text > 0 then
            if box.Text == ADMIN_PASSWORD then
                notify("Password accepted!")
                break
            else
                notify("Incorrect password!")
                box.Text = ""
            end
        end
    end

    input:Destroy() -- Убираем окно после успешного ввода

    -- Кэш эвентов
    local RemoteControlPlayer = game.ReplicatedStorage:FindFirstChild("_Admin_ControlPlayer")
    local RemoteDamagePlayer = game.ReplicatedStorage:FindFirstChild("_Admin_DamagePlayer")

    if not RemoteControlPlayer or not RemoteDamagePlayer then
        notify("Admin tools are not loaded on the server!")
        return
    end

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

    -- Обработка ввода пользователя
    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end

        -- Выбор жертвы ПКМ / RMB
        local victim = getTarget()
        if not victim then return end

        -- F1 - Снести всё ХП
        if input.KeyCode == Enum.KeyCode.F1 then
            local success = RemoteDamagePlayer:InvokeServer(SECRET_KEY, victim.Name, math.huge)
            if success then
                notify(string.format("Killed %s.", victim.Name))
            else
                notify("Failed to kill!")
            end
        elseif input.KeyCode == Enum.KeyCode.F2 then
            -- Переключатель контроля
            local currentCamSubj = workspace.CurrentCamera.CameraSubject
            
            -- Передаём контроль камере клиента
            RemoteControlPlayer:FireServer(
                SECRET_KEY,
                victim.Name,
                currentCamSubj ~= victim.Character.Humanoid
            )

            notify(string.format("Controlling %s: %s",
                victim.Name,
                currentCamSubj == victim.Character.Humanoid and "OFF" or "ON"))
        end
    end)

    notifyAdmin Tools Ready. Controls: [RMB]=Lock Target | [F1]=Kill | [F2]=Toggle Control)
end

pcall(Init)
