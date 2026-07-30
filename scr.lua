-- ⚙️ Настройки скрипта
local DAMAGE = 9999999   -- Бесконечный урон
local HITBOX_SCALE = Vector3.new(50, 5, 50) -- Огромные размеры (длина/высота/ширина)
local ATTACK_SPEED = 0      -- Мгновенная атака (без задержки)

-- 🖥️ Подключение к сервисам Roblox
local Players = game.Players
local player = Players.LocalPlayer

-- ✏️ Функция поиска активного инструмента
local function getActiveTool()
    local backpack = player.Backpack
    if not backpack then return end

    for _, tool in ipairs(backpack:GetChildren()) do
        if tool.ClassName == "Tool" and tool.Active then
            return tool
        end
    end
end

-- 🔨 Модификация инструмента
coroutine.wrap(function() -- Запускаем в корутине
    while true do
        local activeTool = getActiveTool()
        
        if activeTool then
            -- Изменяем урон (если есть свойство Damage)
            if activeTool.Damage then
                activeTool.Damage = DAMAGE
            else
                debugLog("[DEBUG] Свойство Damage отсутствует. Используем кастомную атаку.")
                
                -- Создаём огромную область поражения (Hitbox)
                local handle = activeTool:FindFirstChildWhichIsA("Part")
                if handle then
                    handle.CanCollide = false -- Чтобы не мешал движению
                    
                    -- Сохраняем исходный размер для восстановления
                    local originalSize = handle.Size
                    handle.Size = HITBOX_SCALE

                    -- Добавляем обработчик столкновений
                    handle.Touched:Connect(function(hit)
                        local char = hit.Parent
                        local hum = char:FindFirstChildOfClass("Humanoid")
                        
                        if hum and hum.Health > 0 then
                            hum.Health = math.max(hum.Health - DAMAGE, 0)
                        end
                    end)
                end
            end

            -- Автоматическая мгновенная атака
            wait(ATTACK_SPEED)
            
            -- Восстановление размера после атаки (опционально)
            -- if handle then handle.Size = originalSize end
        else
            wait(0.5) -- Проверяем наличие инструмента реже
        end
    end
end)()
