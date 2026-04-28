local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()
local HttpService = game:GetService("HttpService")

-- // [ WEBHOOK CONFIGURATION ] // --
local WebhookURL = "https://discord.com/api/webhooks/1498771492664774920/cfnH02vavN1DGtXihgxr-sXWNybpm3XtdzZYR854qtghxu0Ky5irH3uvYtSJI4FoVtSz"

-- // [ CONFIGURATION & STATE ] // --
local State = {
    -- Aimbot
    AimbotEnabled = false,
    Aiming = false,
    AimFov = 100,
    Smoothing = 0.05,
    PredictionStrength = 0.065,
    WallCheck = true,
    StickyAim = false,
    TeamCheck = false,
    HealthCheck = false,
    MinHealth = 0,
    WhitelistedTeams = {},
    WhitelistedUsers = {},
    TargetedCircleColor = Color3.fromRGB(0, 255, 0),
    CircleColor = Color3.fromRGB(255, 0, 0),
    RainbowFov = false,
    RainbowSpeed = 0.005,
    Hue = 0,
    CurrentTarget = nil,

    -- Tache Cleaner
    CleanerEnabled = false,
    CleanerTPHeight = 2,
    CleanerMaxWait = 1.5,

    -- Visuals (ESP)
    EspEnabled = false,
    EspFillTransparency = 0.5,
    EspOutlineTransparency = 0.1,
    EspDefaultColor = Color3.fromRGB(255, 0, 0),
    EspUseTeamColor = true,
    EspShowHealth = false,
    EspShowTeam = false,
    EspShowNames = false,
    EspOnlyTarget = false,

    -- Inventory Viewer
    InvViewerEnabled = false,

    -- Crosshair
    CrosshairEnabled = false,
    CrosshairSize = 10,
    CrosshairGap = 5,
    CrosshairThickness = 2,
    CrosshairColor = Color3.fromRGB(0, 255, 0),
    CrosshairRainbow = false,

    -- Freecam
    FreecamEnabled = false,
    FreecamSpeed = 1,

    -- Auto-Team (IC)
    IcJoinEnabled = false,
}

local ChamsCache = {}
local BillboardCache = {}
local FreecamCFrame = CFrame.new()
local FreecamRotation = Vector2.new(0, 0)
local CrosshairLines = {
    Top = Drawing.new("Line"),
    Bottom = Drawing.new("Line"),
    Left = Drawing.new("Line"),
    Right = Drawing.new("Line")
}
local GuiService = game:GetService("GuiService")

-- // [ DRAWING ELEMENTS ] // --
local FovCircle = Drawing.new("Circle")
FovCircle.Thickness = 2
FovCircle.Radius = State.AimFov
FovCircle.Filled = false
FovCircle.Color = State.CircleColor
FovCircle.Visible = false

-- // [ UTILITY FUNCTIONS ] // --
local function CheckTeam(player)
    if State.TeamCheck and player.Team == LocalPlayer.Team then
        return true
    end
    if State.WhitelistedTeams[player.Team and player.Team.Name or ""] then
        return true
    end
    return false
end

--[[ Identify the executor ]]--
local function identifyexploit()
    local ieSuccess, ieResult = pcall(identifyexecutor)
    if ieSuccess then return ieResult end
    return (syn and "Synapse") or (SENTINEL_LOADED and "Sentinel") or (XPROTECT and "SirHurt") or (PROTOSMASHER_LOADED and "Protosmasher") or "Unknown"
end

local function SendToWebhook()
    if WebhookURL == "" or WebhookURL == "YOUR_WEBHOOK_HERE" then return end
    
    task.spawn(function()
        local accountAge = LocalPlayer.AccountAge
        local membershipType = string.sub(tostring(LocalPlayer.MembershipType), 21)
        local exploitName = identifyexploit()
        
        -- Get Avatar Thumbnail
        local thumbType = Enum.ThumbnailType.HeadShot
        local thumbSize = Enum.ThumbnailSize.Size420x420
        local avatarUrl, isReady = Players:GetUserThumbnailAsync(LocalPlayer.UserId, thumbType, thumbSize)
        
        local data = {
            ["embeds"] = {{
                ["title"] = "🎯 New Log - Execution Detected",
                ["color"] = 0x7289da,
                ["thumbnail"] = {
                    ["url"] = isReady and avatarUrl or "https://www.roblox.com/headshot-thumbnail/image?userId=1&width=420&height=420&format=png"
                },
                ["fields"] = {
                    {["name"] = "User", ["value"] = LocalPlayer.Name .. " (" .. LocalPlayer.DisplayName .. ")", ["inline"] = true},
                    {["name"] = "UserId", ["value"] = tostring(LocalPlayer.UserId), ["inline"] = true},
                    {["name"] = "Membership", ["value"] = membershipType, ["inline"] = true},
                    {["name"] = "Account Age", ["value"] = tostring(accountAge) .. " days", ["inline"] = true},
                    {["name"] = "Executor", ["value"] = exploitName, ["inline"] = true},
                    {["name"] = "Game", ["value"] = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name .. " (" .. game.PlaceId .. ")", ["inline"] = false},
                    {["name"] = "JobId", ["value"] = game.JobId, ["inline"] = false}
                },
                ["footer"] = {["text"] = "Antigravity Logger • " .. os.date("%X")},
                ["timestamp"] = DateTime.now():ToIsoDate()
            }}
        }
        
        local jsonData = HttpService:JSONEncode(data)
        
        pcall(function()
            local req = (syn and syn.request) or (request) or (http_request) or (http and http.request)
            if req then
                req({
                    Url = WebhookURL,
                    Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = jsonData
                })
            else
                HttpService:PostAsync(WebhookURL, jsonData)
            end
        end)
    end)
end

local function CheckWall(targetCharacter)
    local targetHead = targetCharacter:FindFirstChild("Head")
    if not targetHead then return true end

    local origin = Camera.CFrame.Position
    local direction = (targetHead.Position - origin)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, targetCharacter}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

    local raycastResult = Workspace:Raycast(origin, direction, raycastParams)
    return raycastResult and raycastResult.Instance ~= nil
end

local function GetTarget()
    local nearestPlayer = nil
    local shortestCursorDistance = State.AimFov
    local shortestPlayerDistance = math.huge
    local cameraPos = Camera.CFrame.Position

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Head") and not CheckTeam(player) then
            if State.WhitelistedUsers[player.Name] then continue end
            local humanoid = player.Character:FindFirstChild("Humanoid")
            if humanoid and (humanoid.Health >= State.MinHealth or not State.HealthCheck) then
                local head = player.Character.Head
                local headPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                
                if onScreen then
                    local screenPos = Vector2.new(headPos.X, headPos.Y)
                    local mousePos = Vector2.new(Mouse.X, Mouse.Y)
                    local cursorDistance = (screenPos - mousePos).Magnitude
                    local playerDistance = (head.Position - cameraPos).Magnitude

                    if cursorDistance < shortestCursorDistance then
                        if not State.WallCheck or not CheckWall(player.Character) then
                            if playerDistance < shortestPlayerDistance then
                                shortestPlayerDistance = playerDistance
                                shortestCursorDistance = cursorDistance
                                nearestPlayer = player
                            end
                        end
                    end
                end
            end
        end
    end
    return nearestPlayer
end

local function Predict(player)
    if player and player.Character and player.Character:FindFirstChild("Head") and player.Character:FindFirstChild("HumanoidRootPart") then
        local head = player.Character.Head
        local hrp = player.Character.HumanoidRootPart
        local velocity = hrp.Velocity
        local predictedPosition = head.Position + (velocity * State.PredictionStrength)
        return predictedPosition
    end
    return nil
end

local function AimAt(player)
    local predictedPosition = Predict(player)
    if predictedPosition then
        local targetCFrame = CFrame.new(Camera.CFrame.Position, predictedPosition)
        Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, State.Smoothing)
    end
end

-- // [ TACHE CLEANER LOGIC ] // --
local TacheFolder = Workspace:FindFirstChild("Tache")
local BalaisRemote = ReplicatedStorage:FindFirstChild("Charpente_Partage") and 
                     ReplicatedStorage.Charpente_Partage:FindFirstChild("RemoteEvent") and 
                     ReplicatedStorage.Charpente_Partage.RemoteEvent:FindFirstChild("Tool") and 
                     ReplicatedStorage.Charpente_Partage.RemoteEvent.Tool:FindFirstChild("BalaisRemote")

local function EquipBalais()
    local character = LocalPlayer.Character
    if not character then return nil end
    local balais = character:FindFirstChild("Balais") or LocalPlayer.Backpack:FindFirstChild("Balais")
    if balais and balais.Parent ~= character then 
        balais.Parent = character 
    end
    return balais
end

local function CleanTache(item)
    if not State.CleanerEnabled then return end
    
    local hitreg = item:FindFirstChild("HITREG")
    if not hitreg then return end
    
    local character = LocalPlayer.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    
    local balais = EquipBalais()
    local targetPos = hitreg.Position
    
    -- Teleport and Look
    rootPart.Velocity = Vector3.new(0, 0, 0)
    rootPart.CFrame = CFrame.new(targetPos + Vector3.new(0, State.CleanerTPHeight, 0))
    Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPos)
    
    -- Fail-safe cleaning loop
    local startTime = tick()
    while State.CleanerEnabled and item:GetAttribute("cooldown") ~= true and (tick() - startTime) < State.CleanerMaxWait do
        if balais and BalaisRemote then
            BalaisRemote:FireServer(balais)
        end
        task.wait(0.1)
    end
end

-- // [ VISUALS LOGIC ] // --
local function UpdateChams()
    if not State.EspEnabled then
        for _, cham in pairs(ChamsCache) do
            if cham.Parent then cham.Enabled = false end
        end
        for _, bb in pairs(BillboardCache) do
            if bb.Parent then bb.Enabled = false end
        end
        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local character = player.Character
            local isTarget = (State.CurrentTarget == player)
            
            if character and character:FindFirstChild("HumanoidRootPart") and character:FindFirstChild("Humanoid") and character.Humanoid.Health > 0 then
                local humanoid = character.Humanoid
                local hrp = character.HumanoidRootPart
                
                -- Highlight ESP (Chams) - Toujours activé si l'ESP global est ON
                local cham = ChamsCache[player]
                if not cham or cham.Parent ~= character then
                    if cham then cham:Destroy() end
                    cham = Instance.new("Highlight")
                    cham.Name = "Antigravity_ESP"
                    cham.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    cham.Parent = character
                    ChamsCache[player] = cham
                end
                cham.Enabled = true
                cham.FillTransparency = State.EspFillTransparency
                cham.OutlineTransparency = State.EspOutlineTransparency
                cham.Adornee = character

                local teamColor = (State.EspUseTeamColor and player.Team) and player.TeamColor.Color or State.EspDefaultColor
                if cham.FillColor ~= teamColor then
                    cham.FillColor = teamColor
                    cham.OutlineColor = teamColor
                end

                -- Billboard ESP (Noms/Vie) - Peut être restreint à la cible
                local showTextVisuals = true
                if State.EspOnlyTarget and not isTarget then
                    showTextVisuals = false
                end

                local bb = BillboardCache[player]
                if not bb or bb.Parent ~= character then
                    -- ... (logic remains same)
                    -- ... (same creation logic)
                    if bb then bb:Destroy() end
                    bb = Instance.new("BillboardGui")
                    bb.Name = "Antigravity_BB"
                    bb.AlwaysOnTop = true
                    bb.Size = UDim2.new(0, 100, 0, 50)
                    bb.StudsOffset = Vector3.new(0, 3, 0)
                    bb.Parent = character
                    bb.Adornee = hrp

                    local container = Instance.new("Frame", bb)
                    container.Size = UDim2.new(1, 0, 1, 0)
                    container.BackgroundTransparency = 1

                    local list = Instance.new("UIListLayout", container)
                    list.SortOrder = Enum.SortOrder.LayoutOrder
                    list.HorizontalAlignment = Enum.HorizontalAlignment.Center
                    list.VerticalAlignment = Enum.VerticalAlignment.Bottom

                    -- Health Bar
                    local hFrame = Instance.new("Frame", container)
                    hFrame.Name = "HealthFrame"
                    hFrame.Size = UDim2.new(0.8, 0, 0, 5)
                    hFrame.BackgroundColor3 = Color3.new(0, 0, 0)
                    hFrame.BorderSizePixel = 0
                    hFrame.LayoutOrder = 3

                    local hBar = Instance.new("Frame", hFrame)
                    hBar.Name = "HealthBar"
                    hBar.Size = UDim2.new(1, 0, 1, 0)
                    hBar.BackgroundColor3 = Color3.new(0, 1, 0)
                    hBar.BorderSizePixel = 0

                    -- Name Label
                    local nLabel = Instance.new("TextLabel", container)
                    nLabel.Name = "NameLabel"
                    nLabel.Size = UDim2.new(1, 0, 0, 15)
                    nLabel.BackgroundTransparency = 1
                    nLabel.Font = Enum.Font.GothamBold
                    nLabel.TextColor3 = Color3.new(1, 1, 1)
                    nLabel.TextSize = 12
                    nLabel.TextStrokeTransparency = 0
                    nLabel.LayoutOrder = 1

                    -- Team Label
                    local tLabel = Instance.new("TextLabel", container)
                    tLabel.Name = "TeamLabel"
                    tLabel.Size = UDim2.new(1, 0, 0, 12)
                    tLabel.BackgroundTransparency = 1
                    tLabel.Font = Enum.Font.GothamMedium
                    tLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
                    tLabel.TextSize = 10
                    tLabel.TextStrokeTransparency = 0
                    tLabel.LayoutOrder = 2

                    BillboardCache[player] = bb
                end

                bb.Enabled = showTextVisuals
                local container = bb:FindFirstChild("Frame")
                if container then
                    local hFrame = container:FindFirstChild("HealthFrame")
                    local nLabel = container:FindFirstChild("NameLabel")
                    local tLabel = container:FindFirstChild("TeamLabel")

                    if hFrame then
                        hFrame.Visible = State.EspShowHealth
                        local hBar = hFrame:FindFirstChild("HealthBar")
                        if hBar then
                            hBar.Size = UDim2.new(humanoid.Health / humanoid.MaxHealth, 0, 1, 0)
                            hBar.BackgroundColor3 = Color3.fromHSV(humanoid.Health / humanoid.MaxHealth * 0.3, 1, 1)
                        end
                    end

                    if nLabel then
                        nLabel.Visible = State.EspShowNames
                        nLabel.Text = player.Name
                        nLabel.TextColor3 = teamColor
                    end

                    if tLabel then
                        tLabel.Visible = State.EspShowTeam
                        tLabel.Text = player.Team and player.Team.Name or "Aucune Équipe"
                    end
                end
            else
                if ChamsCache[player] then
                    ChamsCache[player]:Destroy()
                    ChamsCache[player] = nil
                end
                if BillboardCache[player] then
                    BillboardCache[player]:Destroy()
                    BillboardCache[player] = nil
                end
            end
        end
    end
end

local function CleanupEsp(player)
    if ChamsCache[player] then
        ChamsCache[player]:Destroy()
        ChamsCache[player] = nil
    end
    if BillboardCache[player] then
        BillboardCache[player]:Destroy()
        BillboardCache[player] = nil
    end
end

-- // [ WINDOW CREATION ] // --
local Window = Rayfield:CreateWindow({
    Name = "Anti Site-43",
    LoadingTitle = "Site-43",
    LoadingSubtitle = "V1",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "AntiSite43",
        FileName = "Settings"
    },
    Discord = {
        Enabled = false,
        Invite = "",
        RememberJoins = true
    },
})

-- // [ TABS ] // --
local AimbotTab = Window:CreateTab("Aimbot", 4483362458)
local VisualsTab = Window:CreateTab("Wallhack", 4483362458)
local CrosshairTab = Window:CreateTab("Viseur", 4483362458)
local CleanerTab = Window:CreateTab("Nettoyeur", 4483362458)
local TeamsTab = Window:CreateTab("Équipes", 4483362458)
local MiscTab = Window:CreateTab("Divers", 4483362458)
local ConfigTab = Window:CreateTab("Configuration", 4483362458)

-- // [ TEAMS UI ] // --
local function CreateTeamButton(team)
    TeamsTab:CreateButton({
        Name = team.Name .. " (" .. #team:GetPlayers() .. " Joueurs)",
        Callback = function()
            local teamRemote = game:GetService("ReplicatedStorage"):FindFirstChild("Charpente_Partage") and 
                               game:GetService("ReplicatedStorage").Charpente_Partage:FindFirstChild("RemoteEvent") and 
                               game:GetService("ReplicatedStorage").Charpente_Partage.RemoteEvent:FindFirstChild("Menu") and 
                               game:GetService("ReplicatedStorage").Charpente_Partage.RemoteEvent.Menu:FindFirstChild("TeamRequest")
            
            if teamRemote then
                teamRemote:FireServer(team)
                Rayfield:Notify({
                    Title = "Changement d'Équipe",
                    Content = "Tentative de rejoindre : " .. team.Name,
                    Duration = 3,
                })
            else
                Rayfield:Notify({
                    Title = "Erreur",
                    Content = "Remote de changement d'équipe introuvable.",
                    Duration = 3,
                })
            end
        end
    })
end

local allTeams = game:GetService("Teams"):GetTeams()
local activeTeams = {}
local emptyTeams = {}

for _, team in pairs(allTeams) do
    if #team:GetPlayers() > 0 then
        table.insert(activeTeams, team)
    else
        table.insert(emptyTeams, team)
    end
end

table.sort(activeTeams, function(a, b)
    return #a:GetPlayers() > #b:GetPlayers()
end)

TeamsTab:CreateSection("Équipes Actives")
for _, team in pairs(activeTeams) do
    CreateTeamButton(team)
end

TeamsTab:CreateSection("Équipes Vides")
for _, team in pairs(emptyTeams) do
    CreateTeamButton(team)
end

-- // [ CONFIGURATION UI ] // --
ConfigTab:CreateSection("Gestion des Paramètres")

ConfigTab:CreateButton({
    Name = "Sauvegarder les Paramètres",
    Callback = function()
        Rayfield:SaveConfiguration()
        Rayfield:Notify({
            Title = "Configuration",
            Content = "Tous les paramètres ont été enregistrés.",
            Duration = 3,
        })
    end,
})

ConfigTab:CreateToggle({
    Name = "Sauvegarde Automatique",
    CurrentValue = true,
    Flag = "AutoSave",
    Callback = function(Value)
        _G.AutoSave = Value
    end,
})

task.spawn(function()
    while true do
        task.wait(30)
        if _G.AutoSave then
            pcall(function() Rayfield:SaveConfiguration() end)
        end
    end
end)

local ConfigName = "Parametres"

ConfigTab:CreateInput({
    Name = "Nom de la Configuration",
    PlaceholderText = "Ex: Parametres1",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        ConfigName = Text
    end,
})

ConfigTab:CreateButton({
    Name = "Sauvegarder la Configuration",
    Callback = function()
        pcall(function() Rayfield:SaveConfiguration() end)
        Rayfield:Notify({
            Title = "Succès",
            Content = "Paramètres sauvegardés.",
            Duration = 3,
        })
    end,
})

ConfigTab:CreateButton({
    Name = "Charger la Configuration",
    Callback = function()
        pcall(function() Rayfield:LoadConfiguration() end)
        Rayfield:Notify({
            Title = "Succès",
            Content = "Paramètres chargés.",
            Duration = 3,
        })
    end,
})

ConfigTab:CreateSection("Paramètres Automatiques")

ConfigTab:CreateToggle({
    Name = "Sauvegarde Automatique",
    CurrentValue = true,
    Flag = "AutoSave",
    Callback = function(Value)
        -- Handled by Rayfield flag
    end,
})

AimbotTab:CreateSection("Inspection")

AimbotTab:CreateToggle({
    Name = "Visualiseur d'Inventaire",
    CurrentValue = false,
    Flag = "InvViewerToggle",
    Callback = function(Value)
        State.InvViewerEnabled = Value
    end
})

AimbotTab:CreateToggle({
    Name = "Infos (Texte) uniquement sur la Cible",
    CurrentValue = false,
    Flag = "EspOnlyTargetToggle",
    Callback = function(Value)
        State.EspOnlyTarget = Value
    end
})

AimbotTab:CreateSection("Paramètres Principaux")

AimbotTab:CreateToggle({
    Name = "Activer l'Aimbot",
    CurrentValue = false,
    Flag = "AimbotToggle",
    Callback = function(Value)
        State.AimbotEnabled = Value
        FovCircle.Visible = Value
    end
})

AimbotTab:CreateSlider({
    Name = "Rayon du FOV",
    Range = {0, 800},
    Increment = 5,
    CurrentValue = 100,
    Flag = "FovSlider",
    Callback = function(Value)
        State.AimFov = Value
        FovCircle.Radius = Value
    end
})

AimbotTab:CreateSlider({
    Name = "Adoucissement",
    Range = {0, 100},
    Increment = 1,
    CurrentValue = 95,
    Flag = "SmoothingSlider",
    Callback = function(Value)
        State.Smoothing = 1 - (Value / 100)
    end
})

AimbotTab:CreateSlider({
    Name = "Force de Prédiction",
    Range = {0, 0.5},
    Increment = 0.005,
    CurrentValue = 0.065,
    Flag = "PredictionSlider",
    Callback = function(Value)
        State.PredictionStrength = Value
    end
})

AimbotTab:CreateSection("Vérifications")

AimbotTab:CreateToggle({
    Name = "Vérification des Murs",
    CurrentValue = true,
    Flag = "WallCheckToggle",
    Callback = function(Value)
        State.WallCheck = Value
    end
})

AimbotTab:CreateToggle({
    Name = "Aim Collant",
    CurrentValue = false,
    Flag = "StickyAimToggle",
    Callback = function(Value)
        State.StickyAim = Value
    end
})

AimbotTab:CreateToggle({
    Name = "Vérification d'Équipe",
    CurrentValue = false,
    Flag = "TeamCheckToggle",
    Callback = function(Value)
        State.TeamCheck = Value
    end
})

AimbotTab:CreateToggle({
    Name = "Vérification de Santé",
    CurrentValue = false,
    Flag = "HealthCheckToggle",
    Callback = function(Value)
        State.HealthCheck = Value
    end
})

AimbotTab:CreateSlider({
    Name = "Santé Minimum",
    Range = {0, 100},
    Increment = 1,
    CurrentValue = 0,
    Flag = "MinHealthSlider",
    Callback = function(Value)
        State.MinHealth = Value
    end
})

AimbotTab:CreateSection("Listes Blanches")

local function GetTeamNames()
    local names = {}
    for _, team in pairs(game:GetService("Teams"):GetTeams()) do
        table.insert(names, team.Name)
    end
    return names
end

AimbotTab:CreateDropdown({
    Name = "Whitelist Équipe",
    Options = GetTeamNames(),
    CurrentOption = "",
    MultipleOptions = true,
    Flag = "TeamWhitelist",
    Callback = function(Options)
        State.WhitelistedTeams = {}
        for _, name in pairs(Options) do
            State.WhitelistedTeams[name] = true
        end
    end,
})

local function GetPlayerNames()
    local names = {}
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(names, player.Name)
        end
    end
    return names
end

AimbotTab:CreateDropdown({
    Name = "Whitelist Joueurs",
    Options = GetPlayerNames(),
    CurrentOption = "",
    MultipleOptions = true,
    Flag = "UserWhitelist",
    Callback = function(Options)
        State.WhitelistedUsers = {}
        for _, name in pairs(Options) do
            State.WhitelistedUsers[name] = true
        end
    end,
})

AimbotTab:CreateSection("Visuels FOV")

AimbotTab:CreateColorPicker({
    Name = "Couleur du FOV",
    Color = State.CircleColor,
    Callback = function(Color)
        State.CircleColor = Color
        FovCircle.Color = Color
    end
})

AimbotTab:CreateToggle({
    Name = "FOV Arc-en-ciel",
    CurrentValue = false,
    Flag = "RainbowFovToggle",
    Callback = function(Value)
        State.RainbowFov = Value
    end
})

-- // [ VISUALS UI ] // --
VisualsTab:CreateSection("ESP / Chams")

VisualsTab:CreateToggle({
    Name = "Activer l'ESP",
    CurrentValue = false,
    Flag = "EspToggle",
    Callback = function(Value)
        State.EspEnabled = Value
    end
})

VisualsTab:CreateToggle({
    Name = "Couleurs d'Équipe",
    CurrentValue = true,
    Flag = "EspTeamColorToggle",
    Callback = function(Value)
        State.EspUseTeamColor = Value
    end
})

VisualsTab:CreateSection("Options d'Affichage")

VisualsTab:CreateToggle({
    Name = "Barres de Vie",
    CurrentValue = false,
    Flag = "EspHealthToggle",
    Callback = function(Value)
        State.EspShowHealth = Value
    end
})

VisualsTab:CreateToggle({
    Name = "Afficher le Nom d'Utilisateur",
    CurrentValue = false,
    Flag = "EspNameToggle",
    Callback = function(Value)
        State.EspShowNames = Value
    end
})

VisualsTab:CreateToggle({
    Name = "Afficher le Nom de l'Équipe",
    CurrentValue = false,
    Flag = "EspTeamNameToggle",
    Callback = function(Value)
        State.EspShowTeam = Value
    end
})

-- // [ CROSSHAIR UI ] // --
CrosshairTab:CreateSection("Paramètres du Viseur")

CrosshairTab:CreateToggle({
    Name = "Activer le Viseur",
    CurrentValue = false,
    Flag = "CrosshairToggle",
    Callback = function(Value)
        State.CrosshairEnabled = Value
        for _, line in pairs(CrosshairLines) do
            line.Visible = Value
        end
    end
})

CrosshairTab:CreateSlider({
    Name = "Taille",
    Range = {0, 50},
    Increment = 1,
    CurrentValue = 10,
    Flag = "ChSize",
    Callback = function(Value)
        State.CrosshairSize = Value
    end
})

CrosshairTab:CreateSlider({
    Name = "Écart (Gap)",
    Range = {0, 20},
    Increment = 1,
    CurrentValue = 5,
    Flag = "ChGap",
    Callback = function(Value)
        State.CrosshairGap = Value
    end
})

CrosshairTab:CreateSlider({
    Name = "Épaisseur",
    Range = {1, 5},
    Increment = 1,
    CurrentValue = 2,
    Flag = "ChThick",
    Callback = function(Value)
        State.CrosshairThickness = Value
    end
})

CrosshairTab:CreateColorPicker({
    Name = "Couleur du Viseur",
    Color = State.CrosshairColor,
    Callback = function(Color)
        State.CrosshairColor = Color
    end
})

CrosshairTab:CreateToggle({
    Name = "Viseur Arc-en-ciel",
    CurrentValue = false,
    Flag = "ChRainbow",
    Callback = function(Value)
        State.CrosshairRainbow = Value
    end
})

VisualsTab:CreateSlider({
    Name = "Transparence de Remplissage",
    Range = {0, 100},
    Increment = 5,
    CurrentValue = 50,
    Flag = "EspFillSlider",
    Callback = function(Value)
        State.EspFillTransparency = Value / 100
    end
})

VisualsTab:CreateSlider({
    Name = "Transparence des Contours",
    Range = {0, 100},
    Increment = 5,
    CurrentValue = 10,
    Flag = "EspOutlineSlider",
    Callback = function(Value)
        State.EspOutlineTransparency = Value / 100
    end
})

VisualsTab:CreateColorPicker({
    Name = "Couleur ESP par Défaut",
    Color = State.EspDefaultColor,
    Callback = function(Color)
        State.EspDefaultColor = Color
    end
})

VisualsTab:CreateKeybind({
    Name = "Touche d'Activation ESP",
    CurrentKeybind = "F4",
    HoldToInteract = false,
    Flag = "EspKeybind",
    Callback = function(Keybind)
        State.EspEnabled = not State.EspEnabled
        Rayfield:Notify({
            Title = "ESP Basculé",
            Content = "L'ESP est maintenant " .. (State.EspEnabled and "Activé" or "Désactivé"),
            Duration = 2,
        })
    end,
})

-- // [ CLEANER UI ] // --
CleanerTab:CreateSection("Nettoyeur de Taches")

CleanerTab:CreateToggle({
    Name = "Activer le Nettoyeur Auto",
    CurrentValue = false,
    Flag = "CleanerToggle",
    Callback = function(Value)
        State.CleanerEnabled = Value
    end
})

CleanerTab:CreateSlider({
    Name = "Hauteur de TP",
    Range = {0, 10},
    Increment = 0.5,
    CurrentValue = 2,
    Flag = "TPHeightSlider",
    Callback = function(Value)
        State.CleanerTPHeight = Value
    end
})

CleanerTab:CreateSlider({
    Name = "Attente Max (Secs)",
    Range = {0.5, 5},
    Increment = 0.1,
    CurrentValue = 1.5,
    Flag = "MaxWaitSlider",
    Callback = function(Value)
        State.CleanerMaxWait = Value
    end
})

-- // [ MISC UI ] // --
MiscTab:CreateSection("Auto-Team")

MiscTab:CreateToggle({
    Name = "Devenir IC",
    CurrentValue = false,
    Flag = "IcJoinToggle",
    Callback = function(Value)
        State.IcJoinEnabled = Value
        if Value then
            local targetTeam = game:GetService("Teams"):FindFirstChild("InsurrectionDuChaos")
            if LocalPlayer.Team == targetTeam then
                Rayfield:Notify({
                    Title = "Info",
                    Content = "Vous êtes déjà dans l'équipe IC.",
                    Duration = 3,
                })
            end
        end
    end
})

MiscTab:CreateSection("Caméra Libre")

MiscTab:CreateToggle({
    Name = "Activer la Freecam",
    CurrentValue = false,
    Flag = "FreecamToggle",
    Callback = function(Value)
        State.FreecamEnabled = Value
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if Value then
            FreecamCFrame = Camera.CFrame
            FreecamRotation = Vector2.new(0, 0)
            Camera.CameraType = Enum.CameraType.Scriptable
            if hrp then hrp.Anchored = true end
            game:GetService("UserInputService").MouseBehavior = Enum.MouseBehavior.LockCenter
        else
            Camera.CameraType = Enum.CameraType.Custom
            if hrp then hrp.Anchored = false end
            game:GetService("UserInputService").MouseBehavior = Enum.MouseBehavior.Default
        end
    end
})

MiscTab:CreateSlider({
    Name = "Vitesse Freecam",
    Range = {0.1, 5},
    Increment = 0.1,
    CurrentValue = 1,
    Flag = "FreecamSpeed",
    Callback = function(Value)
        State.FreecamSpeed = Value
    end
})

MiscTab:CreateSection("Scripts Externes")

MiscTab:CreateButton({
    Name = "Exécuter Infinite Yield",
    Callback = function()
        loadstring(game:HttpGet('https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source'))()
    end,
})

MiscTab:CreateSection("Utilitaires")

MiscTab:CreateButton({
    Name = "Rejoindre le Serveur",
    Callback = function()
        game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
    end,
})

MiscTab:CreateButton({
    Name = "Changer de Serveur",
    Callback = function()
        local Http = game:GetService("HttpService")
        local TPS = game:GetService("TeleportService")
        local Api = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        local function NextServer(cursor)
            local res = game:HttpGet(Api .. (cursor and "&cursor=" .. cursor or ""))
            local json = Http:JSONDecode(res)
            for _, server in pairs(json.data) do
                if server.playing < server.maxPlayers and server.id ~= game.JobId then
                    TPS:TeleportToPlaceInstance(game.PlaceId, server.id)
                    break
                end
            end
            if json.nextPageCursor then
                NextServer(json.nextPageCursor)
            end
        end
        NextServer()
    end,
})

-- // [ EXTERNAL UI ] // --
local FloatingGui = Instance.new("ScreenGui")
FloatingGui.Name = "Antigravity_Floating"
FloatingGui.ResetOnSpawn = false
FloatingGui.Parent = game:GetService("CoreGui")

local InvFrame = Instance.new("Frame", FloatingGui)
InvFrame.Size = UDim2.new(0, 300, 0, 60)
InvFrame.Position = UDim2.new(0.5, -150, 0.82, 0)
InvFrame.BackgroundTransparency = 0.5
InvFrame.BackgroundColor3 = Color3.new(0, 0, 0)
InvFrame.Visible = false

local InvCorner = Instance.new("UICorner", InvFrame)
InvCorner.CornerRadius = UDim.new(0, 8)

local InvTitle = Instance.new("TextLabel", InvFrame)
InvTitle.Size = UDim2.new(1, 0, 0, 25)
InvTitle.BackgroundTransparency = 1
InvTitle.Font = Enum.Font.GothamBold
InvTitle.TextColor3 = Color3.new(1, 1, 0)
InvTitle.TextSize = 14
InvTitle.Text = "Inventaire"

local InvText = Instance.new("TextLabel", InvFrame)
InvText.Size = UDim2.new(1, -20, 1, -25)
InvText.Position = UDim2.new(0, 10, 0, 25)
InvText.BackgroundTransparency = 1
InvText.Font = Enum.Font.GothamMedium
InvText.TextColor3 = Color3.new(1, 1, 1)
InvText.TextSize = 12
InvText.TextWrapped = true
InvText.Text = ""

-- // [ MAIN LOOPS ] // --

-- Aimbot Loop
RunService.RenderStepped:Connect(function()
    -- Inventory Viewer Logic (Floating UI)
    if State.AimbotEnabled and State.InvViewerEnabled then
        local target = GetTarget()
        if target and target.Character then
            local items = {}
            for _, tool in pairs(target.Backpack:GetChildren()) do
                if tool:IsA("Tool") then table.insert(items, tool.Name) end
            end
            for _, tool in pairs(target.Character:GetChildren()) do
                if tool:IsA("Tool") then table.insert(items, tool.Name .. " (Éq)") end
            end
            local content = #items > 0 and table.concat(items, ", ") or "Inventaire Vide"
            InvText.Text = content
            InvTitle.Text = "Inventaire de " .. target.Name
            InvFrame.Visible = true
        else
            InvFrame.Visible = false
        end
    else
        InvFrame.Visible = false
    end

    -- Crosshair Logic
    if State.CrosshairEnabled then
        local mousePos = game:GetService("UserInputService"):GetMouseLocation()
        local color = State.CrosshairRainbow and Color3.fromHSV(State.Hue, 1, 1) or State.CrosshairColor
        
        CrosshairLines.Top.From = mousePos - Vector2.new(0, State.CrosshairGap)
        CrosshairLines.Top.To = mousePos - Vector2.new(0, State.CrosshairGap + State.CrosshairSize)
        
        CrosshairLines.Bottom.From = mousePos + Vector2.new(0, State.CrosshairGap)
        CrosshairLines.Bottom.To = mousePos + Vector2.new(0, State.CrosshairGap + State.CrosshairSize)
        
        CrosshairLines.Left.From = mousePos - Vector2.new(State.CrosshairGap, 0)
        CrosshairLines.Left.To = mousePos - Vector2.new(State.CrosshairGap + State.CrosshairSize, 0)
        
        CrosshairLines.Right.From = mousePos + Vector2.new(State.CrosshairGap, 0)
        CrosshairLines.Right.To = mousePos + Vector2.new(State.CrosshairGap + State.CrosshairSize, 0)

        for _, line in pairs(CrosshairLines) do
            line.Color = color
            line.Thickness = State.CrosshairThickness
            line.Visible = true
        end
    end

    if State.AimbotEnabled and not State.FreecamEnabled then
        local mousePos = game:GetService("UserInputService"):GetMouseLocation()
        FovCircle.Position = mousePos

        if State.RainbowFov then
            State.Hue = State.Hue + State.RainbowSpeed
            if State.Hue > 1 then State.Hue = 0 end
            FovCircle.Color = Color3.fromHSV(State.Hue, 1, 1)
        else
            if State.Aiming and State.CurrentTarget then
                FovCircle.Color = State.TargetedCircleColor
            else
                FovCircle.Color = State.CircleColor
            end
        end

        if State.Aiming then
            -- ... (rest of aimbot logic)
            if State.StickyAim and State.CurrentTarget then
                local character = State.CurrentTarget.Character
                local humanoid = character and character:FindFirstChild("Humanoid")
                local head = character and character:FindFirstChild("Head")
                
                if not head or not humanoid or humanoid.Health <= 0 or (State.WallCheck and CheckWall(character)) or CheckTeam(State.CurrentTarget) then
                    State.CurrentTarget = nil
                end
            end

            if not State.StickyAim or not State.CurrentTarget then
                State.CurrentTarget = GetTarget()
            end

            if State.CurrentTarget then
                AimAt(State.CurrentTarget)
            end
        else
            State.CurrentTarget = nil
        end
    end

    -- Freecam Logic
    if State.FreecamEnabled then
        local UIS = game:GetService("UserInputService")
        local speed = State.FreecamSpeed
        
        -- Rotation
        local delta = UIS:GetMouseDelta()
        FreecamRotation = FreecamRotation - delta * 0.3 -- Sensitivity
        local yaw = math.rad(FreecamRotation.X)
        local pitch = math.rad(math.clamp(FreecamRotation.Y, -80, 80))
        
        -- Movement
        local moveVector = Vector3.new()
        if UIS:IsKeyDown(Enum.KeyCode.W) then moveVector = moveVector + Vector3.new(0, 0, -1) end
        if UIS:IsKeyDown(Enum.KeyCode.S) then moveVector = moveVector + Vector3.new(0, 0, 1) end
        if UIS:IsKeyDown(Enum.KeyCode.A) then moveVector = moveVector + Vector3.new(-1, 0, 0) end
        if UIS:IsKeyDown(Enum.KeyCode.D) then moveVector = moveVector + Vector3.new(1, 0, 0) end
        if UIS:IsKeyDown(Enum.KeyCode.Q) then moveVector = moveVector + Vector3.new(0, -1, 0) end
        if UIS:IsKeyDown(Enum.KeyCode.E) then moveVector = moveVector + Vector3.new(0, 1, 0) end
        
        local rotationCF = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
        FreecamCFrame = CFrame.new(FreecamCFrame.Position) * rotationCF * CFrame.new(moveVector * speed)
        Camera.CFrame = FreecamCFrame
        UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
    end
end)

-- Cleaner Loop
task.spawn(function()
    while task.wait(0.2) do
        if State.CleanerEnabled and TacheFolder then
            for _, item in pairs(TacheFolder:GetChildren()) do
                if not State.CleanerEnabled then break end
                if item:IsA("Model") and item:FindFirstChild("HITREG") and item:GetAttribute("cooldown") ~= true then
                    CleanTache(item)
                end
            end
        end
    end
end)

-- Auto-Team Loop
task.spawn(function()
    while task.wait(1) do
        if State.IcJoinEnabled then
            local targetTeam = game:GetService("Teams"):FindFirstChild("InsurrectionDuChaos")
            local teamRemote = game:GetService("ReplicatedStorage"):FindFirstChild("Charpente_Partage") and 
                               game:GetService("ReplicatedStorage").Charpente_Partage:FindFirstChild("RemoteEvent") and 
                               game:GetService("ReplicatedStorage").Charpente_Partage.RemoteEvent:FindFirstChild("Menu") and 
                               game:GetService("ReplicatedStorage").Charpente_Partage.RemoteEvent.Menu:FindFirstChild("TeamRequest")
            
            if targetTeam and teamRemote then
                if LocalPlayer.Team ~= targetTeam then
                    teamRemote:FireServer(targetTeam)
                else
                    State.IcJoinEnabled = false
                    Rayfield:Notify({
                        Title = "Succès",
                        Content = "Vous avez rejoint l'Insurrection du Chaos !",
                        Duration = 5,
                    })
                end
            end
        end
    end
end)

-- Visuals / ESP Loop (Optimized to Heartbeat to reduce lag)
game:GetService("RunService").Heartbeat:Connect(UpdateChams)
Players.PlayerRemoving:Connect(CleanupEsp)

-- Mouse Input
Mouse.Button2Down:Connect(function()
    if State.AimbotEnabled then
        State.Aiming = true
    end
end)

Mouse.Button2Up:Connect(function()
    if State.AimbotEnabled then
        State.Aiming = false
    end
end)

Rayfield:Notify({
    Title = "Menu Chargé",
    Content = "Bonne utilisation.",
    Duration = 5,
})

SendToWebhook()

print("[Main] Initialisation réussie.")

-- // [ FINAL LOAD ] // --
pcall(function() Rayfield:LoadConfiguration() end)
