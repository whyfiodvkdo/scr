-- ⚙️ Настройки скрипта (Бесконечный урон!)
local DAMAGE = 9999999   -- Бесконечный урон
local HITBOX_SCALE = Vector3.new(5000, 5000, 5000) -- Огромные размеры (длина/высота/ширина)
local ATTACK_SPEED = 0      -- Мгновенная атака (без задержки)

local Players = game.Players
local player = Players.LocalPlayer

-- ✏️ Функция поиска активного инструмента (исправлено ожидание Backpack)
local function getActiveTool()
    local backpack = player.Character and player.Character:FindFirstChild("Backpack")
    
    -- Если рюкзака нет, ждём его появления
    if not backpack then 
        repeat wait() until player.Character and player.Character:FindFirstChild("Backpack") == true
        backpack = player.Character:WaitForChild("Backpack", 10)
    end

    for _, tool in ipairs(player.Character:GetChildren()) do -- Ищем в Character!
        if tool.ClassName == "Tool" and tool.Parent == player.Character then
            return tool
        end
    end

    -- Теперь ищем только внутри гарантированно существующего Backpack
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
                handle.CanCollide = false -- Чтобы не мешал движению
                
                -- Сохраняем исходный размер для восстановления (опционально)
                local originalSize = handle.Size

                -- Создаём огромную область поражения (Hitbox)
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
