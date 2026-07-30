local Players = game.Players -- Получаем сервис игроков
repeat wait() until Players.LocalPlayer and Players.LocalPlayer.Character -- Ждём появления игрока и его модели
local player = Players.LocalPlayer or nil
if not player then return end -- Если игрок так и не появился, выходим из скрипта

coroutine.wrap(function()
    while true do
        local activeTool = nil -- Переменная для хранения активного инструмента

        if not player.Character then 
            debugLog("[DEBUG] Персонаж ещё не готов.")
            wait(0.5) continue
        end

        for _, tool in ipairs(player.Character:GetChildren()) do
            if tool.ClassName == "Tool" then
                activeTool = tool
                break
            end
        end

        if activeTool then
            -- 1️⃣ Нажимаем кнопку атаки через ProximityPrompt
            local prompt = activeTool:FindFirstChildOfClass("ProximityPrompt")
            pcall(fireproximyprompt, prompt)

            -- 2️⃣ Имитация стандартного клика мышью (ЛКМ или Q)
            local mouse = player:GetMouse()
            if mouse then
                -- Пробуем нажать левую кнопку мыши
                pcall(mouse.Button1Down.Fire, mouse.Button1Down)
                
                -- Если игра настроена на клавиатуру, используем q
                pcall(mouse.KeyDown, "q")
            else
                debugLog("[DEBUG] Не удалось получить Mouse.")
            end

            -- 3️⃣ Активируем все анимационные контроллеры (для старых игр)
            local animController = player.Character:FindFirstChildWhichIsA("Animator")
            if animController then
                for _, track in ipairs(animController:GetPlayingAnimationTracks()) do
                    track:Play() -- Перезапускаем анимацию удара
                end
            end

            -- 4️⃣ Запускаем LocalScript'ы внутри оружия
            for _, script in ipairs(activeTool:GetChildren()) do
                if script.ClassName ~= "LocalScript" then continue end
                script.Disabled = false -- Просто включаем скрипт
            end
        else
            wait(0.5)
        end

        wait(0.1) -- Повторяем попытку каждые 0.1 секунды
    end
end)()
