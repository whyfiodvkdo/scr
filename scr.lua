-- Клиентский скрипт (для ссылки / loadstring)
local function Init()
    local plr = game.Players.LocalPlayer
    local mouse = plr:GetMouse()
    local uis = game:GetService("UserInputService")
    local rs = game:GetService("RunService")
    
    -- Ищем наш RemoteEvent, созданный вами ранее
    local event = game.ReplicatedStorage:FindFirstChild("CheatAction")
    
    if not event then
        warn("[G-Core] Серверная часть не найдена.")
        return
    end

    local highlight = nil
    local currentTarget = nil
    local isActive = false

    -- Функция создания рамки
    local function updateHighlight(char)
        if highlight then highlight:Destroy() end
        if not char or not char.PrimaryPart then return end
        
        highlight = Instance.new("BoxHandleAdornment")
        highlight.Adornee = char
        highlight.AlwaysOnTop = true
        highlight.ZIndex = 10
        highlight.Size = char:GetExtentsSize() + Vector3.new(0.2, 0.2, 0.2)
        highlight.Color3 = Color3.fromRGB(0, 255, 0)
        highlight.Transparency = 0.7
        highlight.Parent = workspace.CurrentCamera
    end

    -- Переключатель G
    uis.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.G then
            isActive = not isActive
            
            if highlight then highlight:Destroy(); highlight = nil; end
            currentTarget = nil
            
            game.StarterGui:SetCore("SendNotification", {
                Title = "[SANDBOX]";
                Text = isActive and "Режим АКТИВЕН" or "Режим отключен";
                Duration = 2;
            })
        end
    end)

    -- Наведение мыши
    mouse.Move:Connect(function()
        if not isActive then return end
        
        local target = mouse.Target
        if not target then 
            if highlight then highlight:Destroy(); highlight = nil; end
            currentTarget = nil
            return 
        end

        local char = target:FindFirstAncestorWhichIsA("Model")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        
        if hum and hum.Health > 0 then
            currentTarget = char
            updateHighlight(char)
        else
            if highlight then highlight:Destroy(); highlight = nil; end
            currentTarget = nil
        end
    end)

    -- Клик правой кнопкой (Убийство)
    uis.InputBegan:Connect(function(input, gpe)
        if gpe or not isActive then return end
        if input.UserInputType == Enum.UserInputType.MouseButton2 and currentTarget then
            -- Отправляем запрос на сервер. Здесь происходит магия синхронизации.
            event:FireServer("Kill", currentTarget)
        end
    end)

    -- Уведомление о запуске
    game.StarterGui:SetCore("SendNotification", {
        Title = "[SANDBOX LOADER]";
        Text = "Скрипт успешно активирован. [G] - вкл/выкл.";
        Icon = "rbxassetid://9114319780";
        Duration = 4;
    })
end

pcall(Init) -- Защита от ошибок выполнения
