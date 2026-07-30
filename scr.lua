local Players = game.Players -- Сервис со списком игроков
local ReplicatedStorage = game.ReplicatedStorage -- Место хранения событий
local ServerStorage = game.ServerStorage -- Альтернативное место поиска

-- Ждём появления LocalPlayer и его Character
repeat wait() until Players.LocalPlayer and Players.LocalPlayer.Character
local player = Players.LocalPlayer or nil

-- Ищем событие KillPlayer в стандартных местах
local killEvent = ReplicatedStorage:FindFirstChild("KillPlayer") 
if not killEvent then
    killEvent = ServerStorage:FindFirstChild("KillPlayer")
end

coroutine.wrap(function()
    while true do
        local myChar = player.Character
        if not myChar then wait(0.5) continue end -- Персонаж ещё не готов

        for _, other in ipairs(Players:GetChildren()) do
            if other ~= player and other.Character then -- Игнорируем себя и проверяем наличие модели
                local distance = (myChar.PrimaryPart.Position - other.Character.PrimaryPart.Position).Magnitude
                
                -- Радиус действия: 720 метров
                if distance <= 720 then
                    debugLog("[DEBUG] Обнаружен враг в зоне поражения!")
                    
                    -- ✅ Безопасный способ: отправка команды на сервер
                    if killEvent then
                        pcall(killEvent.FireServer, killEvent, other.Name)
                        wait(0.1) -- Небольшая задержка между вызовами
                    else
                        -- ⚠️ Менее надёжный способ: имитация урона
                        -- Этот код может не работать во многих играх!
                        local humanoid = other.Character:FindFirstChildWhichIsA("Humanoid")
                        if humanoid then
                            pcall(setmetatable, humanoid, {Health = 0})
                            pcall(function() humanoid.Health = 0 end)
                        end
                    end
                end
            end
        end

        wait(0.1) -- Повторяем проверку каждые 0.1 секунды
    end
end)()
