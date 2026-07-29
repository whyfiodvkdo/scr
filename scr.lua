-- Автономный скрипт на Teleport (Ctrl + LMB)
local function Init()
    local UserInputService = game:GetService("UserInputService")
    local Players = game:GetService("Players")
    
    local player = Players.LocalPlayer
    local mouse = player:GetMouse()
    local character = player.Character or player.CharacterAdded:Wait()
    local rootPart = character:WaitForChild("HumanoidRootPart")

    -- Уведомление о запуске
    pcall(function()
        game.StarterGui:SetCore("SendNotification", {
            Title = "[TP]";
            Text = "Активировано. Ctrl + ЛКМ — Телепорт.";
            Duration = 3;
        })
    end)

    -- Функция самого перемещения
    local function teleportToCursor()
        if not mouse.Hit then return end

        -- Позиция, куда указывает курсор (с учетом высоты поверхности)
        local targetPos = mouse.Hit.Position
        
        -- Чтобы игрок не проваливался сквозь текстуры и не улетал под карту,
        -- поднимаем его на высоту HumanoidRootPart (обычно около 4-5 ст.)
        targetPos = Vector3.new(targetPos.X, targetPos.Y + rootPart.Size.Y / 2, targetPos.Z)

        -- Отключаем состояния персонажа на долю секунды, чтобы избежать конфликтов с анимациями падения/прыжка
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.Physics)
        end

        -- Мгновенное перемещение
        rootPart.CFrame = CFrame.new(targetPos)

        -- Возвращаем управление физике тела
        task.wait(0.1) 
        if humanoid and humanoid.Health > 0 then
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end

    -- Отслеживание ввода
    UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
        if gameProcessedEvent then return end -- Не срабатывать при печати в чат

        -- Проверяем комбинацию CTRL + ЛЕВАЯ КНОПКА МЫШИ
        if input.UserInputType == Enum.UserInputType.MouseButton1 and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            teleportToCursor()
        end
    end)
end

pcall(Init)
