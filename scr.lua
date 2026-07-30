local Players = game.Players
local player = Players.LocalPlayer or Players.LocalPlayer

-- ✏️ Функция вывода структуры инструмента
local function printToolStructure(tool)
    -- 1. Выводим все числовые свойства
    for propName, value in pairs(tool:GetProperties()) do
        if type(value) == 'number' then
            debugLog(string.format("[DEBUG] Свойство %s = %.0f", propName, value))
        end
    end

    -- 2. Выводим иерархию объектов внутри инструмента
    local indent = ""
    local function recursivePrint(obj, level)
        indent = string.rep(" ", level * 4)
        
        -- Проверяем тип объекта
        if obj.ClassName == "LocalScript" then
            debugLog(indent .. "[SCRIPT]: " .. obj.Name)
            
            -- Ищем ВСЕ методы внутри скрипта через метатаблицу
            for k, v in pairs(getmetatable(obj)) do
                if type(v) == 'function' then
                    debugLog(indent .. "  -> Обнаружена функция: " .. k)
                elseif type(v) == 'table' and rawget(v, "__index") then
                    debugLog(indent .. "  -> Таблица: " .. k)
                end
            end
        elseif obj.ClassName == "ProximityPrompt" then
            debugLog(indent .. "[PROMPT]: " .. obj.Name)
        else
            debugLog(indent .. "[OBJ]: " .. obj.Name .. " (" .. obj.ClassName .. ")")
        end

        -- Рекурсивно проходим по всем детям
        for _, child in ipairs(obj:GetChildren()) do
            recursivePrint(child, level + 1)
        end
    end

    recursivePrint(tool, 0)
end

coroutine.wrap(function()
    while true do
        local activeTool = nil

        if not player.Character then wait(0.5) continue end

        for _, tool in ipairs(player.Character:GetChildren()) do
            if tool.ClassName == "Tool" and tool.Parent == player.Character then
                activeTool = tool
                break
            end
        end

        if activeTool then
            debugLog("\n[SCANNER] Анализируем активный инструмент: " .. activeTool.Name)
            printToolStructure(activeTool)

            -- ⚙️ Безопасная активация атак
            -- Нажимаем кнопку атаки (если есть ProximityPrompt)
            local prompt = activeTool:FindFirstChildOfClass("ProximityPrompt")
            if prompt then 
                pcall(fireproximyprompt, prompt) -- Защищённый вызов
            end

            -- Имитация стандартных событий мыши ВНУТРИ скриптов оружия
            for _, script in pairs(activeTool:GetChildren()) do
                if script.ClassName ~= "LocalScript" then continue end

                -- Используем защищённые вызовы для каждого потенциального события
                pcall(script.MouseButton1Down.Fire, script.MouseButton1Down)
                pcall(script.OnButton1Down.Fire, script.OnButton1Down)
                pcall(script.Attack.Fire, script.Attack)
                
                -- Дополнительно проверяем Метатаблицу скрипта
                local meta = getmetatable(script)
                if meta then
                    for name, func in pairs(meta) do
                        if type(func) == 'function' and 
                            (name == "OnButton1Down" or name == "Attack" or name == "Hit" or name == "Activate") then
                                pcall(func, script) -- Вызываем найденные функции атак
                        end
                    end
                end
            end
        else
            debugLog("[INFO] Инструмент не найден.")
        end

        wait(3) -- Повторяем сканирование каждые 3 секунды
    end
end)()
