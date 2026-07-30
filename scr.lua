local Players = game.Players

repeat wait() until Players.LocalPlayer and Players.LocalPlayer.Character

local player = Players.LocalMouse or Players.LocalPlayer

coroutine.wrap(function()
    while true do
        local activeTool = nil

        if not player.Character then 
            debugLog("[DEBUG] Персонаж ещё не готов.")
            wait(0.5) continue end

        for _, tool in ipairs(player.Character:GetChildren()) do
            if tool.ClassName == "Tool" then
                activeTool = tool
                break
            end
        end

        if activeTool then
            -- ⚙️ Автоматическое нажатие кнопки атаки через ProximityPrompt
            local prompt = activeTool:FindFirstChildOfClass("ProximityPrompt")
            pcall(fireproximyprompt, prompt)

            -- ⚙️ Универсальная имитация атаки: пробуем ЛКМ, затем Q
            local mouse = player:GetMouse()
            if mouse then
                -- Сначала пытаемся нажать левую кнопку мыши
                pcall(mouse.Button1Down.Fire, mouse.Button1Down)
                
                -- Если игра настроена на клавиатуру, используем q
                pcall(mouse.KeyDown, "q")
            else
                debugLog("[DEBUG] Не удалось найти объект Mouse.")
            end

            -- ⚙️ Активируем все анимационные контроллеры (для старых игр)
            local animController = player.Character:FindFirstChildWhichIsA("Animator")
            if animController then
                for _, track in ipairs(animController:GetPlayingAnimationTracks()) do
                    track:Play() -- Перезапускаем анимацию удара
                end
            end

            -- ⚙️ Запускаем LocalScript'ы оружия
            for _, script in ipairs(activeTool:GetChildren()) do
                if script.ClassName ~= "LocalScript" then continue end
                script.Disabled = false
            end
        else
            wait(0.5)
        end

        wait(0.1) -- Повторяем попытку каждые 0.1 секунды
    end
end)()
