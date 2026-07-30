local DAMAGE_MULTIPLIER = 9999 -- Умножитель урона (если есть)
local HITBOX_SCALE = Vector3.new(5000, 5000, 5000) -- Огромный хитбокс
local ATTACK_SPEED = 0      -- Мгновенная атака

local Players = game.Players
local player = Players.LocalPlayer or Players.LocalPlayer

coroutine.wrap(function()
    while true do
        local activeTool = nil
        
        if not player.Character then wait() continue end

        for _, obj in ipairs(player.Character:GetChildren()) do
            if obj.ClassName == "Tool" and obj.Parent == player.Character then
                activeTool = obj
                break
            end
        end

        if activeTool then
            -- ✅ Увеличиваем хитбокс
            local handle = activeTool:FindFirstChildWhichIsA("BasePart")
            if handle then
                handle.CanCollide = false
                handle.Size = HITBOX_SCALE
                
                -- Если есть стандартный параметр Damage — увеличиваем его
                if activeTool.Damage then
                    activeTool.Damage = activeTool.Damage * DAMAGE_MULTIPLIER
                end
            else
                warn("[WARNING] Инструмент без физического тела!")
            end

            -- ✅ Имитируем нажатие кнопок атаки
            local prompt = activeTool:FindFirstChildOfClass("ProximityPrompt") 
            if prompt then fireproximyprompt(prompt) end

            -- ✅ Запускаем все скрипты атаки
            for _, script in pairs(activeTool:GetChildren()) do
                if script.ClassName == "LocalScript" then
                    pcall(function()
                        -- Имитация стандартных событий мыши
                        script.MouseButton1Down:Fire()
                        script.OnButton1Down:Fire()
                        script.Attack:Fire()
                        
                        -- На всякий случай запускаем сам скрипт
                        script.Disabled = false
                    end)
                end
            end
            
            wait(ATTACK_SPEED)
        else
            wait(0.5)
        end
    end
end)()
