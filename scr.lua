local Players = game.Players -- Сервис со списком игроков
repeat wait() until Players.LocalPlayer and Players.LocalPlayer.Character -- Ждём появления персонажа
local player = Players.LocalPlayer or nil

coroutine.wrap(function()
    while true do
        local myChar = player.Character
        if not myChar then 
            debugLog("[DEBUG] Персонаж ещё не готов.")
            wait(0.5) continue
        end

        for _, other in ipairs(Players:GetChildren()) do
            if other ~= player and other.Character then -- Игнорируем себя и проверяем наличие модели
                local distance = (myChar.PrimaryPart.Position - other.Character.PrimaryPart.Position).Magnitude
                
                -- Радиус действия: 720 метров
                if distance <= 720 then
                    debugLog("[DEBUG] Обнаружен враг в зоне поражения!")
                    
                    -- ✅ Исправленный способ убийства через изменение Health по индексу
                    local humanoid = other.Character:FindFirstChildWhichIsA("Humanoid")
                    if humanoid and humanoid.Health > 0 then
                        pcall(function() humanoid["Health"] = -math.huge end)
                    end
                end
            end
        end

        wait(0.1) -- Повторяем проверку каждые 0.1 секунды
    end
end)()
