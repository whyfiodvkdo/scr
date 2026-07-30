local Players = game.Players
local player = Players.LocalPlayer or Players.LocalPlayer

-- Функция вывода структуры инструмента
local function printToolStructure(tool)
    local indent = ""
    
    -- Рекурсивный обход дерева объектов
    local function recursivePrint(obj, level)
        indent = string.rep(" ", level * 4)
        
        if obj.ClassName == "LocalScript" then
            debugLog(indent .. "[SCRIPT]: " .. obj.Name)
            
            -- Ищем все методы скрипта через метатаблицу
            for name, func in pairs(getmetatable(obj)) do
                -- Проверка наличия ключевых слов в названии
                if type(func) == 'function' and (
                    name:match(".*Button.*") or
                    name:match(".*Attack.*") or
                    name:match(".*Hit.*")
                ) then
                    debugLog(indent .. "  -> Обнаружена функция атаки: " .. name)
                elseif type(v) == 'table' and rawget(v, "__index") then
                    debugLog(indent .. "  -> Таблица: " .. name)
                end
            end
        elseif obj.ClassName == "ProximityPrompt" then
            debugLog(indent .. "[PROMPT]: " .. obj.Name)
        else
            debugLog(indent .. "[OBJ]: " .. obj.Name .. " (" .. obj.ClassName .. ")")
        end

        for _, child in ipairs(obj:GetChildren()) do
            recursivePrint(child, level + 1)
        end
    end

    recursivePrint(tool, 0)
end

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
            debugLog("\n[SCANNER] Анализируем активный инструмент: " .. activeTool.Name)
            printToolStructure(activeTool)

            -- Активируем найденные функции атак
            for _, script in ipairs(activeTool:GetChildren()) do
                if script.ClassName ~= "LocalScript" then continue end

                -- Получаем Метатаблицу скрипта
                local meta = getmetatable(script)
                if not meta then continue end

                -- Вызываем ВСЕ обнаруженные функции атак
                for name, func in pairs(meta) do
                    if type(func) == 'function' and (
                        name:match(".*Button.*") or
                        name:match(".*Attack.*") or
                        name:match(".*Hit.*")
                    ) then
                        pcall(func, script) -- Защищённый вызов
                    end
                end
            end

            -- Дополнительно нажимаем кнопку атаки (если есть ProximityPrompt)
            local prompt = activeTool:FindFirstChildOfClass("ProximityPrompt")
            if prompt then pcall(fireproximyprompt, prompt) end
        else
            wait(0.2)
        end

        wait(0.3) -- Повторяем сканирование каждые 0.3 секунды
    end
end)()
