-- Tool Grabber v0.9: Find and equip all tools in the game
local function Init()
    local Players = game.GetService("Players")
    local ReplicatedStorage = game.GetService("ReplicatedStorage")
    local UserInputService = game.GetService("UserInputService")

    -- ⚙️ Настройки
    local SEARCH_DELAY = 2       -- Задержка перед повторным поиском (сек)
    local TOOL_TIMEOUT = 30     -- Сколько секунд держать тул в руке после выбора (или пока не выберешь другой)

    -- Инициализация игрока
    local player = Players.LocalPlayer or Players.PlayerAdded:Wait() 
    if not player then return end

    local char = player.Character or player.CharacterAdded:Wait()
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then notify("Character not found!"); return end

    -- Функция уведомления
    local function notify(text)
        pcall(function()
            game.StarterGui:SetCore("SendNotification", {
                Title = "Tool Grabber",
                Text = tostring(text),
                Duration = 3})
        end)
        print("" .. tostring(text))
    end

    -- ⚙️ Создание GUI
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "ToolGrabber"
    ScreenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")

    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 450, 0, 600)
    MainFrame.Position = UDim2.new(0.5, -225, 0.5, -300) -- Центр экрана
    MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    MainFrame.BorderSizePixel = 0
    MainFrame.Visible = false
    MainFrame.Parent = ScreenGui

    -- Заголовок
    local LabelTitle = Instance.new("TextLabel")
    LabelTitle.Text = "Tool Grabber v0.9"
    LabelTitle.Font = Enum.Font.SourceSansBold
    LabelTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    LabelTitle.BackgroundTransparency = 1
    LabelTitle.Size = UDim2.new(1, 0, 0, 30)
    LabelTitle.Position = UDim2.new(0, 0, 0, 0)
    LabelTitle.Parent = MainFrame

    -- Поисковая строка
    local SearchBox = Instance.new("SearchBox")
    SearchBox.PlaceholderText = "Filter by name..."
    SearchBox.Position = UDim2.new(0, 10, 0, 40)
    SearchBox.Size = UDim2.new(0, 430, 0, 30)
    SearchBox.Parent = MainFrame

    -- Список инструментов
    local ListTools = Instance.new("ScrollingFrame")
    ListTools.ScrollBarThickness = 8
    ListTools.CanvasSize = UDim2.new(0, 0, 0, 0) -- Будет автоматически расти
    ListTools.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    ListTools.Position = UDim2.new(0, 10, 0, 80)
    ListTools.Size = UDim2.new(0, 430, 0, 470)
    ListTools.Parent = MainFrame

    -- Кнопка обновления списка
    local BtnRefresh = Instance.new("TextButton")
    BtnRefresh.Text = "🔄 Refresh Tools"
    BtnRefresh.AutoButtonColor = true
    BtnRefresh.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    BtnRefresh.Position = UDim2.new(0, 10, 0, 560)
    BtnRefresh.Size = UDim2.new(0, 120, 0, 30)
    BtnRefresh.Parent = MainFrame

    -- Переключатель видимости
    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.F then
            MainFrame.Visible = not MainFrame.Visible
            if MainFrame.Visible then
                notify("Tool Grabber opened.")
            else
                notify("Tool Grabber closed.")
            end
        end
    end)

    -- ⚙️ Логика работы
    local EquippedTool = nil

    -- Вспомогательная функция: найти оригинальную модель оружия
    local function GetOriginalModel(toolInstance)
        -- Сначала ищем внутри самой модели
        for _, child in ipairs(toolInstance:GetChildren()) do
            if child.ClassName == "Model" then
                return child
            end
        end

        -- Затем проверяем стандартные папки
        local toolName = toolInstance.Name:lower()
        local possibleFolders = {workspace, ReplicatedStorage}
        for _, folder in pairs(possibleFolders) do
            for _, obj in ipairs(folder:GetDescendants()) do
                if obj.ClassName == "Model" and obj.Name:lower():find(toolName) then
                    return obj
                end
            end
        end

        -- Если ничего не нашли, создаём простую копию
        warn(string.format("No original model found for %s. Creating a simple copy.", toolName))
        local newModel = Instance.new("Model")
        newModel.PrimaryPart = toolInstance.Handle:Clone()
        newModel.PrimaryPart.CanCollide = false
        newModel.PrimaryPart.Anchored = false
        newModel.PrimaryPart.Transparency = 0.5
        newModel.Parent = workspace
        return newModel
    end

    -- Обработчик кликов на списке
    ListTools.ChildAdded:Connect(function(btn)
        btn.MouseButton1Click:Connect(function()
            -- Удаляем старый тул
            if EquippedTool then
                EquippedTool.Parent = nil
                task.wait(TOOL_TIMEOUT) -- Ждём немного, чтобы сервер успел обработать удаление
            end

            -- Получаем новый тул
            local toolInst = script.ToolCache[btn.Text]
            if not toolInst then return end

            -- Создаем модель (оригинальную или копию)
            local model = GetOriginalModel(toolInst)
            model.Parent = workspace

            -- Добавляем тул игроку
            local newTool = toolInst:Clone()
            newTool.Parent = player.Backpack
            EquippedTool = newTool

            -- Сразу берём в руки
            wait(0.1) -- Даем время Backpack обработаться
            hum:EquipTool(newTool)

            notify(string.format("Equipped: %s", btn.Text))
        end)
    end)

    -- Обновление списка инструментов
    local function UpdateList(filterStr)
        filterStr = (filterStr or ""):lower()
        ListTools.CanvasSize = UDim2.new(0, 0, 0, 0)
        
        -- Очищаем текущий список кнопок
        for _, child in ipairs(ListTools:GetChildren()) do
            if child.ClassName == "TextButton" then
                child:Destroy()
            end
        end

        -- Перебираем кэш найденных инструментов
        local yPos = 0
        for toolName, _ in pairs(script.ToolCache) do
            if string.find(toolName:lower(), filterStr) then
                local btn = Instance.new("TextButton")
                btn.Text = toolName
                btn.AutoButtonColor = true
                btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                btn.Position = UDim2.new(0, 0, 0, yPos)
                btn.Size = UDim2.new(1, 0, 0, 30)
                btn.Parent = ListTools

                yPos = yPos + 30
                ListTools.CanvasSize = UDim2.new(0, 0, 0, yPos)
            end
        end
    end

    -- Первоначальный поиск инструментов
    local function ScanGame()
        script.ToolCache = {}

        -- Стандартные места поиска
        local searchContainers = {workspace, ReplicatedStorage}
        for _, container in ipairs(searchContainers) do
            for _, obj in ipairs(container:GetDescendants()) do
                if obj.ClassName == "Tool" then
                    script.ToolCache[obj.Name] = obj
                end
            end
        end

        -- Внутри моделей других игроков (оружие)
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= player and plr.Character then
                for _, tool in ipairs(plr.Character:GetChildren()) do
                    if tool.ClassName == "Tool" then
                        script.ToolCache[tool.Name] = tool
                    end
                end
            end
        end

        -- Обновляем список в GUI
        UpdateList(SearchBox.Text)
        notify(string.format("Found %d unique tools!", #script.ToolCache))
    end

    -- Подключаем события
    BtnRefresh.MouseButton1Click:Connect(ScanGame)
    SearchBox.Changed:Connect(function(prop)
        if prop == "Text" then
            UpdateList(SearchBox.Text)
        end
    end)

    -- Запускаем первый поиск при загрузке
    ScanGame()
    
    -- Повторный поиск каждые N секунд (на случай появления новых предметов)
    while wait(SEARCH_DELAY) do
        ScanGame()
    end
end

pcall(Init)
