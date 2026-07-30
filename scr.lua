local DAMAGE = 9999999   -- Бесконечный урон
local HITBOX_SCALE = Vector3.new(5000, 5000, 5000) -- Огромные размеры (длина/высота/ширина)
local ATTACK_SPEED = 0      -- Мгновенная атака (без задержки)

local Players = game.Players
local player = Players.LocalPlayer

-- ✏️ Функция поиска активного инструмента
local function getActiveTool()
    local backpack = player.Backpack
    if not backpack then return end

    for _, tool in ipairs(player.Character:GetChildren()) do -- Ищем в Character!
        if tool.ClassName == "Tool" and tool.Parent == player.Character then
            return tool
        end
    end

    -- Если в Character нет, ищем в Backpack (на случай если персонаж ещё не спавнился)
    for _, tool in ipairs(backpack:GetChildren()) do
        if tool.ClassName == "Tool" then
            return tool
        end
    end
end

coroutine.wrap(function() 
    while true do
        local activeTool = getActiveTool()
        
        if activeTool then
            debugLog("[DEBUG] Нашли активный инструмент!")
            
            -- Проверяем наличие физической основы (Handle)
            local handle = activeTool:FindFirstChildWhichIsA("BasePart")
            if handle then
                -- Сохраняем исходный размер для восстановления (опционально)
                local originalSize = handle.Size

                -- Создаём огромную область поражения (Hitbox)
                handle.CanCollide = false -- Чтобы не мешал движению
                handle.Size = HITBOX_SCALE

                -- Добавляем обработчик столкновений
                handle.Touched:Connect(function(hit)
                    local char = hit.Parent
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    
                    if hum and hum.Health > 0 then
                        hum.Health = math.max(hum.Health - DAMAGE, 0)
                    end
                end)

                wait(ATTACK_SPEED)
                
                -- Восстановление размера после атаки (можно закомментировать)
                -- handle.Size = originalSize
            else
                warn("[WARNING]: У этого инструмента нет физического тела (Handle)! Он не будет наносить урон.")
            end
        else
            wait(0.5) -- Проверяем наличие инструмента реже
        end
    end
end)()
