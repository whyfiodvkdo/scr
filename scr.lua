local Players = game.Players
local player = Players.LocalPlayer or Players.LocalPlayer

coroutine.wrap(function()
    while true do
        local activeTool = nil

        -- Находим ТОЛЬКО активный инструмент в руках персонажа
        if not player.Character then wait(0.2); continue end

        for _, tool in ipairs(player.Character:GetChildren()) do
            if tool.ClassName == "Tool" then
                activeTool = tool
                break
            end
        end

        if activeTool then
            -- ✅ Автоматическое нажатие кнопки атаки (если есть ProximityPrompt)
            local prompt = activeTool:FindFirstChildOfClass("ProximityPrompt")
            if prompt then 
                pcall(fireproximyprompt, prompt) -- Защищённый вызов
            else
                debugLog("[DEBUG] No Prompt found.")
            end

            -- ✅ Имитация стандартного клика мышью
            local mouse = player:GetMouse()
            pcall(mouse.KeyDown:Fire, "q") -- q — стандартная клавиша атаки в Roblox
            
            -- ✅ Активируем все анимационные контроллеры (для старых игр)
            local animController = player.Character:FindFirstChildWhichIsA("Animator")
            if animController then
                for _, track in ipairs(animController:GetPlayingAnimationTracks()) do
                    track:Play() -- Перезапускаем анимацию удара
                end
            end

            -- ✅ Дополнительно запускаем LocalScript'ы оружия
            for _, script in ipairs(activeTool:GetChildren()) do
                if script.ClassName ~= "LocalScript" then continue end
                
                -- Просто включаем скрипт, не вызывая конкретные функции
                script.Disabled = false
            end
        else
            wait(0.2)
        end

        wait(0.1) -- Повторяем попытку каждые 0.1 секунды
    end
end)()
