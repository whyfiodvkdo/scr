-- Player Puppet v0.9: Control other players via mouse and keyboard input
local function Init()
    local Players = game.GetService("Players")
    local RunService = game.GetService("RunService")
    local UserInputService = game.GetService("UserInputService")

    -- === STATE ===
    local player = Players.LocalPlayer or Players.PlayerAdded:Wait() 
    if not player then return end

    local ctx = {
        LocalCharacter = player.Character,
        Mouse = player:GetMouse(),
        Camera = workspace.CurrentCamera,
        Target = nil,          -- {Char=Model, Hum=Humanoid, RootPart=Instance}
        IsControlling = false, -- Режим управления чужим телом
    }

    -- ⚙️ Настройки репликатора движений
    local MOVEMENT_SPEED = 8      -- Скорость ходьбы (м/с)
    local JUMP_POWER = 16        -- Сила прыжка
    local MAX_CAMERA_ROTATION_PER_TICK = 0.1 -- Ограничение угла поворота камеры (радианы) для защиты от бана

    -- Вспомогательные функции
    local function notify(text)
        pcall(function()
            game.StarterGui:SetCore("SendNotification", {
                Title = "Puppet",
                Text = tostring(text),
                Duration = 3})
        end)
        print("" .. tostring(text))
    end

    -- Безопасная проверка цели под курсором
    local function getTarget()
        local targetPart = ctx.Mouse.Target
        if not targetPart then return nil end
        local model = targetPart:FindFirstAncestorWhichIsA("Model")
        if not model then return nil end
        local hum = model:FindFirstChildOfClass("Humanoid")
        local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
        
        -- Проверяем, что это не мы сами и персонаж загружен
        if hum and root and model ~= ctx.LocalCharacter and hum.Health > 0 then
            return {Char = model, Hum = hum, Root = root, Name = model.Name}
        end
        return nil
    end

    -- Переключение режима контроля
    local function toggleControlMode()
        if ctx.IsControlling then
            -- Возвращаем контроль над собой
            ctx.Camera.CameraSubject = ctx.LocalCharacter.Humanoid
            ctx.IsControlling = false
            notify("Returned control to yourself.")
        else
            -- Передаём контроль жертве
            if ctx.Target then
                ctx.Camera.CameraSubject = ctx.Target.Hum
                ctx.IsControlling = true
                notify(string.format("Now controlling %s.", ctx.Target.Name))
            else
                notify("No target selected!")
            end
        end
    end

    -- Обработка ввода пользователя
    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end

        -- Выбор цели ПКМ / RMB
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            ctx.Target = getTarget()
            if ctx.Target then
                notify(string.format("Target locked: %s", ctx.Target.Name))
            else
                notify("Target cleared.")
            end
        elseif input.KeyCode == Enum.KeyCode.F then
            toggleControlMode()
        end
    end)

    -- Репликация передвижения
    task.spawn(function()
        while wait(0.03) do
            if not ctx.IsControlling or not ctx.Target then continue end

            -- Получаем направление взгляда игрока
            local camCFrame = ctx.Camera.CFrame
            local moveDir = Vector3.new(camCFrame.LookVector.X, 0, camCFrame.LookVector.Z)
            
            -- Управление движением через Humanoid.MoveDirection
            -- Это самый безопасный способ для серверов, так как движок сам рассчитывает физику
            ctx.Target.Hum:MoveTo(ctx.Target.Root.Position + moveDir.unit * MOVEMENT_SPEED)

            -- Прыжки
            if ctx.Mouse.KeyDown["q"] then -- Можно заменить на любую другую кнопку
                ctx.Target.Hum.JumpPower = JUMP_POWER
                ctx.Target.Hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end

            -- Имитация вращения камеры
            -- Мы не можем напрямую управлять чужой камерой, но можем вращать гуманоида
            local currentRot = ctx.Target.Root.Rotation.Y
            local desiredRot = -math.deg(math.atan2(
                ctx.Mouse.X - ctx.Camera.ViewportSize.X/2,
                ctx.Camera.ViewportSize.Y/2 - ctx.Mouse.Y)) -- Угол относительно центра экрана

            -- Защищаемся от резких поворотов (защита от бана)
            local deltaRot = desiredRot - currentRot
            if deltaRot > 180 then deltaRot = deltaRot - 360 end
            if deltaRot < -180 then deltaRot = deltaRot + 360 end

            local maxDelta = math.rad(MAX_CAMERA_ROTATION_PER_TICK)
            if math.abs(deltaRot) > math.deg(maxDelta) then
                deltaRot = math.sign(deltaRot) * math.deg(maxDelta)
            end

            ctx.Target.Root.Orientation = Vector3.new(0, currentRot + deltaRot, 0)
        end
    end)

    -- Инициализация
    notifyPuppet loaded. Controls: [RMB]=Lock Target | [F]=Toggle Control Mode")
end

pcall(Init)
