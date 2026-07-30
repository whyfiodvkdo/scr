-- ⚙️ Настройки скрипта
local MESSAGE_DURATION = 3     -- Время отображения сообщений (секунды)
local HOVER_HEIGHT = 0       -- Высота подъёма при "зависании"
local HOVER_TIME = 3         -- Длительность зависания (в секундах)

-- 🛡️ Защита от повторного запуска
if script.Parent then return end

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

-- 🕸️ Определение зоны по координатам X/Z
local function getZoneName(posX, posZ)
    local mapSizeX = workspace.Terrain.Size.X / 2
    local mapSizeZ = workspace.Terrain.Size.Z / 2

    if math.abs(posX) > mapSizeX * 1.2 or math.abs(posZ) > mapSizeZ * 1.2 then
        return "🌊 Вне карты" -- За пределами видимой области
    elseif math.abs(posX) < mapSizeX/4 and math.abs(posZ) < mapSizeZ/4 then
        return "🏢 Центр карты"
    else
        local xDir = posX >= 0 and "Восток" or "Запад"
        local zDir = posZ >= 0 and "Север" or "Юг"
        return string.format("🗺 %s-%s", xDir, zDir)
    end
end

-- 💨 Основной цикл телепортаций
while true do
    if not player.Character or not player.Character.HumanoidRootPart then
        warn("[WARNING]: Персонаж исчез. Ждём восстановления...")
        repeat wait(0.5) until player.Character and player.Character.HumanoidRootPart
    else
        -- Шаг 1: Выбираем абсолютно случайную точку в пределах игрового мира
        -- Мы увеличили диапазон, чтобы иногда выпадали точки за краем карты
        local randomPos = Vector3.new(
            math.random(-workspace.Terrain.Size.X/2 * 1.2, workspace.Terrain.Size.X/2 * 1.2),
            math.random(-100, 100),   -- Может появиться глубоко под землёй или высоко в небе!
            math.random(-workspace.Terrain.Size.Z/2 * 1.2, workspace.Terrain.Size.Z/2 * 1.2)
        )

        -- МГНОВЕННАЯ ТЕЛЕПОРТАЦИЯ без проверки пола
        player.Character.HumanoidRootPart.CFrame = CFrame.new(randomPos)
        
        -- Логируем координаты и зону
        local zone = getZoneName(randomPos.X, randomPos.Z)
        debugLog(string.format("%s | Координаты: [%.1f, %.1f, %.1f]", 
                               zone, randomPos.X, randomPos.Y, randomPos.Z))

        -- Шаг 3: Создаём иллюзию зависания с помощью BodyVelocity
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.P = 12000
        bv.Velocity = Vector3.new(0, HOVER_HEIGHT/HOVER_TIME, 0) -- Скорость подъёма
        bv.Parent = player.Character.PrimaryPart

        -- Показываем уведомление о текущем положении
        showNotification("🆘 Координаты", 
                        string.format("%s\n[%.1f, %.1f, %.1f]",
                                      zone, randomPos.X, randomPos.Y, randomPos.Z),
                        nil, MESSAGE_DURATION * 2)

        -- Ждём, пока персонаж не опустится обратно
        wait(HOVER_TIME + 1) -- Добавил секунду, чтобы падение выглядело плавнее
        bv:Destroy()
    end
end
