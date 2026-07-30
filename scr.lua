-- ⚙️ Настройки скрипта
local DAMAGE_MULTIPLIER = 9999 -- Умножитель урона (если есть Damage)
local HITBOX_SCALE = Vector3.new(5000, 5000, 5000) -- Огромные размеры (длина/высота/ширина)
local ATTACK_SPEED = 0      -- Мгновенная атака (без задержки)

local Players = game.Players
local player = Players.LocalPlayer

-- ✏️ Функция поиска активного инструмента с LocalScript
local function getActiveTool()
    local backpack = player.Character and player.Character:FindFirstChild("Backpack")
    
    if not backpack then 
        repeat wait() until player.Character and player.Character:WaitForChild("Backpack", 10)
        backpack = player.Character.Backpack
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

                -- Увеличиваем стандартный урон (если он есть)
                if activeTool.Damage then
                    activeTool.Damage = activeTool.Damage * DAMAGE_MULTIPLIER
                end

                -- 🔨 Самое важное — находим LocalScript атаки
                local attackScript = nil
                for _, script in pairs(activeTool:GetChildren()) do
                    if script.ClassName == "LocalScript" then
                        attackScript = script
                        break
                    end
                end

                if attackScript then
                    -- Находим функцию атаки по названию (обычно это OnButton1Down или Attack)
                    for k, v in pairs(getmetatable(attackScript)) do
                        if type(v) == 'function' and string.find(k, "Attack") or string.find(k, "Button1") then
                            -- Вызываем её бесконечно быстро
                            v()
                        end
                    end
                else
                    warn("[WARNING]: Не найден LocalScript атаки. Попробуй активировать удар вручную.")
                end

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
