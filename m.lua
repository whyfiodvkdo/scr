local function Init()
    local Players = game:GetService("Players") -- Исправил синтаксис с ':' вместо '.'
    local UserInputService = game.GetService(game, "UserInputService")
    local ReplicatedStorage = game.GetService("ReplicatedStorage")

    -- Кэш эвентов
    local RequestAuth = ReplicatedStorage:WaitForChild("_Request_Admin_Auth")
    local ControlPlayer = ReplicatedStorage:WaitForChild("_Request_Control_Player")
    local DamagePlayer = ReplicatedStorage:WaitForChild("_Request_Damage_Player")

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

    -- Автоматическая проверка прав администратора
    local isAdmin = RequestAuth:FireServer()

    if not isAdmin then
        -- Удаляем все эвенты, чтобы обычный игрок не мог ими воспользоваться
        RequestAuth:Destroy()
        ControlPlayer:Destroy()
        DamagePlayer:Destroy()
        notify("You are not authorized to use these tools!")
        return
    end

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

    notifyAdmin Tools Ready. Controls: [RMB]=Lock Target | [F1]=Kill | [F2]=Toggle Control)
end

pcall(Init)
