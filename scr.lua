-- ⚙️ Настройки скрипта
local MESSAGE_DURATION = 3     -- Время отображения сообщений (секунды)
local HOVER_HEIGHT = 80       -- Высота подъёма при "зависании"
local HOVER_TIME = 3         -- Длительность зависания (в секундах)

-- 🖥️ Подключение к сервисам Roblox
local Players = game.Players
local player = Players.LocalPlayer

-- ✏️ Функция вывода уведомления через SetCore()
local function showNotification(title, message, iconId, duration)
    game.StarterGui:SetCore(
        "SendNotification",
        {
            Title = title,
            Text = message,
            Icon = iconId or "",
            Duration = duration or 5
        }
    )
end

-- 🔧 Отладочные функции
local function debugLog(msg)
    print("[DEBUG] " .. msg)
end

-- 🕸️ Ожидание появления Character перед началом работы
repeat wait() until player.Character and player.Character.PrimaryPart

showNotification("🆘 Random Teleporter", 
                 string.format("Бесконечные телепорты активированы! Высота зависания: %.0f ст.", HOVER_HEIGHT),
                 "rbxassetid://9114319780")
debugLog("Сценарий начал работу!")

-- 💨 Основной цикл телепортаций
while true do
    if not player.Character or not player.Character.HumanoidRootPart then
        warn("[WARNING]: Персонаж исчез. Ждём восстановления...")
        repeat wait(0.5) until player.Character and player.Character.HumanoidRootPart
    else
        -- Шаг 1: Выбираем случайную точку в пределах игрового мира
        local mapSizeX = workspace.Terrain.Size.X / 2
        local mapSizeZ = workspace.Terrain.Size.Z / 2
        
        local randomPos = Vector3.new(
            math.random(-mapSizeX, mapSizeX),   -- X
            10,                                -- Y (начальная высота над полом)
            math.random(-mapSizeZ, mapSizeZ)   -- Z
        )

        -- Проверяем, есть ли под этой точкой пол
        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Exclude
        raycastParams.FilterDescendantsInstances = {player.Character}
        
        local result = workspace:Raycast(randomPos + Vector3.new(0, 100, 0), Vector3.new(0, -100, 0), raycastParams)

        if result then
            -- Если пол найден, телепортируем на него
            randomPos = result.Position + Vector3.new(0, 1, 0) -- Немного выше пола
            
            -- Шаг 2: Телепортация и подъём
            player.Character.HumanoidRootPart.CFrame = CFrame.new(randomPos)
            player.Character.HumanoidRootPart.Velocity = Vector3.new(0, HOVER_HEIGHT/HOVER_TIME, 0)

            -- Логируем координаты
            debugLog(string.format("Телепортировал на: [%.1f, %.1f, %.1f]", randomPos.X, randomPos.Y, randomPos.Z))
            showNotification("🆘 Координаты", 
                            string.format("Текущие: [%.1f, %.1f, %.1f]\nВысота зависания: %.0f ст.",
                                          randomPos.X, randomPos.Y, randomPos.Z, HOVER_HEIGHT),
                            nil, MESSAGE_DURATION * 2)

            -- Ждём, пока персонаж не опустится обратно
            wait(HOVER_TIME)
        else
            -- Если под точкой нет пола, просто ждём немного и пробуем снова
            debugLog("Под выбранной точкой нет поверхности. Поиск продолжается.")
            wait(1)
        end
    end
end
