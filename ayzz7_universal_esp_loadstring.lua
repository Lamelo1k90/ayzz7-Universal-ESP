loadstring([=[
--[[
    UNIVERSAL ESP | made by ayzz7
    Menu key: Insert  |  Drag menu by its title bar.

    Features: corner boxes, names, team-colored outline chams,
    optional health-based fill, team check, RGB palette,
    and per-body-part exposure indicators (green = clear sight,
    white = blocked by world geometry).

    Client-side Roblox Luau. Uses ordinary Instances (no Drawing API).
    Visibility is approximate and intentionally updated at a reduced rate.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local environment = _G
do
    if type(getgenv) == "function" then
        local ok, env = pcall(getgenv)
        if ok and type(env) == "table" then
            environment = env
        end
    end
end
if environment.__AYZZ7_UNIVERSAL_ESP then
    pcall(function() environment.__AYZZ7_UNIVERSAL_ESP:Destroy() end)
end

local config = {
    cornerBoxes = true,
    chams = true,
    healthChams = false,
    teamCheck = false,
    nameESP = true,
    exposedParts = true,
    rgb = {45, 99, 255},
}

local BOX_INTERVAL = 1 / 30           -- GUI update: at most 30 FPS
local EXPOSURE_INTERVAL = 0.20       -- Per-part rays: 5 times/second
local MAX_DISTANCE = 900             -- Studs; lowers distant-player cost
local BOX_THICKNESS = 2
local VISIBLE_COLOR = Color3.fromRGB(0, 255, 65)
local HIDDEN_COLOR = Color3.fromRGB(255, 255, 255)
local PANEL_BG = Color3.fromRGB(14, 14, 15)
local OFF_BG = Color3.fromRGB(27, 27, 28)
local ON_BG = Color3.fromRGB(45, 99, 255)
local TEXT_DIM = Color3.fromRGB(112, 112, 116)
local tracked = {}
local connections = {}
local destroyed = false
local currentAccent = Color3.fromRGB(45, 99, 255)
local buttons = {}
local paletteUpdates = {}

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    connections[#connections + 1] = connection
    return connection
end

local function create(className, properties, parent)
    local obj = Instance.new(className)
    for property, value in pairs(properties or {}) do
        obj[property] = value
    end
    obj.Parent = parent
    return obj
end

local function round(parent, radius)
    return create("UICorner", {CornerRadius = UDim.new(0, radius)}, parent)
end

local function getColor()
    return Color3.fromRGB(config.rgb[1], config.rgb[2], config.rgb[3])
end

local function sameTeam(other)
    return LocalPlayer.Team ~= nil and other.Team ~= nil and LocalPlayer.Team == other.Team
end

local function shouldShow(player)
    return not config.teamCheck or not sameTeam(player)
end

local function teamColor(player)
    if player.Team ~= nil then
        return player.TeamColor.Color
    end
    return Color3.fromRGB(240, 240, 240)
end

-- Place UI where the executor allows it (gethui is optional).
local uiParent = CoreGui
if type(gethui) == "function" then
    local ok, result = pcall(gethui)
    if ok and typeof(result) == "Instance" then
        uiParent = result
    end
end

local screen = create("ScreenGui", {
    Name = "ayzz7_UniversalESP",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 900,
}, nil)
local okParent = pcall(function() screen.Parent = uiParent end)
if not okParent then
    screen.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local overlay = create("Frame", {
    Name = "ESP_Overlay", BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1),
    Position = UDim2.fromScale(0, 0),
    ClipsDescendants = false,
}, screen)

-- =========================== MENU ===========================
local panel = create("Frame", {
    Name = "Menu", BackgroundColor3 = PANEL_BG, BorderSizePixel = 0,
    Position = UDim2.fromOffset(40, 38),
    Size = UDim2.fromOffset(218, 452),
    Active = true,
}, screen)
round(panel, 11)

local titleBar = create("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 43),
    Active = true,
}, panel)
create("TextLabel", {
    BackgroundTransparency = 1, Text = "UNIVERSAL ESP", TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold, TextSize = 13,
    Size = UDim2.new(1, -28, 1, 0), Position = UDim2.fromOffset(8, 0),
    TextXAlignment = Enum.TextXAlignment.Center,
}, titleBar)
local closeButton = create("TextButton", {
    BackgroundTransparency = 1, Text = "×", TextColor3 = TEXT_DIM,
    Font = Enum.Font.GothamBold, TextSize = 17,
    Position = UDim2.new(1, -25, 0, 10), Size = UDim2.fromOffset(20, 22),
}, titleBar)

local function section(label, y)
    create("TextLabel", {
        BackgroundTransparency = 1, Text = label, TextColor3 = TEXT_DIM,
        Font = Enum.Font.GothamBold, TextSize = 9,
        Position = UDim2.fromOffset(11, y), Size = UDim2.fromOffset(196, 14),
        TextXAlignment = Enum.TextXAlignment.Left,
    }, panel)
    create("Frame", {
        BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(34, 34, 35),
        Position = UDim2.fromOffset(11, y + 17), Size = UDim2.fromOffset(196, 1),
    }, panel)
end

section("VISUALS", 42)

local applyVisuals = function() end -- assigned after ESP helper definitions

local function toggleButton(key, caption, y)
    local button = create("TextButton", {
        Name = key, AutoButtonColor = true, BorderSizePixel = 0,
        Position = UDim2.fromOffset(11, y), Size = UDim2.fromOffset(196, 28),
        Font = Enum.Font.Gotham, TextSize = 11,
        TextColor3 = Color3.fromRGB(231, 231, 235),
    }, panel)
    round(button, 6)
    local function update()
        button.Text = caption .. ": " .. (config[key] and "ON" or "OFF")
        button.BackgroundColor3 = config[key] and ON_BG or OFF_BG
    end
    buttons[key] = update
    update()
    connect(button.MouseButton1Click, function()
        config[key] = not config[key]
        update()
        applyVisuals()
    end)
end

toggleButton("cornerBoxes", "Corner ESP", 62)
toggleButton("chams", "Chams", 94)
toggleButton("nameESP", "Name ESP", 126)
toggleButton("exposedParts", "Exposure ESP", 158)
section("SETTINGS", 191)
toggleButton("healthChams", "Health Chams", 211)
toggleButton("teamCheck", "Team Check", 243)
section("COLORS", 277)

local palettePanel = create("Frame", {
    BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(20, 20, 21),
    Position = UDim2.fromOffset(11, 299), Size = UDim2.fromOffset(196, 103),
}, panel)
round(palettePanel, 7)

local activeSlider
local sliderMap = {}
local channelColors = {
    Color3.fromRGB(255, 80, 91), Color3.fromRGB(75, 255, 89), Color3.fromRGB(82, 81, 255)
}

local function makeSlider(index, letter, y)
    create("TextLabel", {
        BackgroundTransparency = 1, Text = letter, TextColor3 = channelColors[index],
        Font = Enum.Font.GothamBold, TextSize = 11,
        Position = UDim2.fromOffset(13, y - 7), Size = UDim2.fromOffset(17, 16),
    }, palettePanel)
    local track = create("Frame", {
        BackgroundColor3 = Color3.fromRGB(48, 48, 49), BorderSizePixel = 0,
        Position = UDim2.fromOffset(47, y), Size = UDim2.fromOffset(132, 4),
        Active = true,
    }, palettePanel)
    round(track, 2)
    local knob = create("Frame", {
        BackgroundColor3 = channelColors[index], BorderSizePixel = 0,
        Size = UDim2.fromOffset(11, 11), AnchorPoint = Vector2.new(0.5, 0.5),
        Active = true,
    }, track)
    round(knob, 20)
    local function updateKnob()
        knob.Position = UDim2.fromScale(config.rgb[index] / 255, 0.5)
    end
    paletteUpdates[index] = updateKnob
    updateKnob()
    local function setFromX(x)
        local width = track.AbsoluteSize.X
        if width < 1 then return end
        local fraction = math.clamp((x - track.AbsolutePosition.X) / width, 0, 1)
        config.rgb[index] = math.floor(fraction * 255 + 0.5)
        updateKnob()
        currentAccent = getColor()
    end
    sliderMap[index] = setFromX
    local function begin(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            activeSlider = {index = index, input = input}
            setFromX(input.Position.X)
        end
    end
    connect(track.InputBegan, begin)
    connect(knob.InputBegan, begin)
end

makeSlider(1, "R", 19)
makeSlider(2, "G", 49)
makeSlider(3, "B", 79)

create("TextLabel", {
    BackgroundTransparency = 1, Text = "Menu Key: Insert", TextColor3 = TEXT_DIM,
    Font = Enum.Font.Gotham, TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Left,
    Position = UDim2.fromOffset(11, 427), Size = UDim2.fromOffset(130, 17),
}, panel)
create("TextLabel", {
    BackgroundTransparency = 1, Text = "by ayzz7", TextColor3 = TEXT_DIM,
    Font = Enum.Font.Gotham, TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Right,
    Position = UDim2.fromOffset(140, 427), Size = UDim2.fromOffset(67, 17),
}, panel)
create("TextLabel", {
    BackgroundTransparency = 1, Text = "Green: exposed  /  White: covered", TextColor3 = TEXT_DIM,
    Font = Enum.Font.Gotham, TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Center,
    Position = UDim2.fromOffset(8, 405), Size = UDim2.fromOffset(202, 16),
}, panel)

-- Mouse/touch drag without deprecated Draggable.
local dragging = false
local dragInput, dragStart, panelStart
connect(titleBar.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragInput = input
        dragStart = input.Position
        panelStart = panel.Position
    end
end)
connect(UserInputService.InputChanged, function(input)
    if dragging and dragStart and (
        input.UserInputType == Enum.UserInputType.MouseMovement
        or (input.UserInputType == Enum.UserInputType.Touch and input == dragInput)
    ) then
        local delta = input.Position - dragStart
        panel.Position = UDim2.new(
            panelStart.X.Scale, panelStart.X.Offset + delta.X,
            panelStart.Y.Scale, panelStart.Y.Offset + delta.Y
        )
    end
    if activeSlider and (
        input.UserInputType == Enum.UserInputType.MouseMovement
        or (input.UserInputType == Enum.UserInputType.Touch and input == activeSlider.input)
    ) then
        sliderMap[activeSlider.index](input.Position.X)
    end
end)
connect(UserInputService.InputEnded, function(input)
    if dragging and (input == dragInput or input.UserInputType == Enum.UserInputType.MouseButton1) then
        dragging = false
    end
    if activeSlider and (input == activeSlider.input
        or input.UserInputType == Enum.UserInputType.MouseButton1) then
        activeSlider = nil
    end
end)
connect(UserInputService.InputBegan, function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.Insert then
        panel.Visible = not panel.Visible
    end
end)

-- ========================= PLAYER ESP =========================
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function makeLine(parent)
    return create("Frame", {
        BorderSizePixel = 0, BackgroundColor3 = currentAccent,
        Size = UDim2.fromOffset(2, 2), Visible = false,
    }, parent)
end

local function setRectangle(line, x, y, w, h, color)
    line.Position = UDim2.fromOffset(math.floor(x + 0.5), math.floor(y + 0.5))
    line.Size = UDim2.fromOffset(math.max(1, math.floor(w + 0.5)), math.max(1, math.floor(h + 0.5)))
    line.BackgroundColor3 = color
end

local function removeCharacterVisuals(rec)
    if rec.highlight then rec.highlight:Destroy() rec.highlight = nil end
    for _, adorn in ipairs(rec.adornments) do
        adorn:Destroy()
    end
    table.clear(rec.adornments)
    table.clear(rec.parts)
    rec.character = nil
    rec.humanoid = nil
    rec.head = nil
    rec.root = nil
    rec.active = false
    for i = 1, 8 do rec.lines[i].Visible = false end
    rec.nameLabel.Visible = false
end

local function buildCharacter(rec, char)
    removeCharacterVisuals(rec)
    if not char then return end
    rec.character = char
    rec.humanoid = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 4)
    rec.head = char:FindFirstChild("Head") or char:WaitForChild("Head", 4)
    rec.root = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", 4)
    if not rec.humanoid or not rec.head or not rec.root then return end

    -- Always keep the outline in the player's TEAM color.
    local highlight = Instance.new("Highlight")
    highlight.Name = "ayzz7_TeamOutline"
    highlight.Adornee = char
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.OutlineColor = teamColor(rec.player)
    highlight.OutlineTransparency = 0
    highlight.FillTransparency = 1
    highlight.Enabled = false -- disabled until the first valid visibility update
    highlight.Parent = char
    rec.highlight = highlight

    -- Use one reusable world-space adornment for each body part.
    -- Adornments give each limb its own independent white/green state;
    -- the team-colored Highlight outline never changes for exposure.
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("BasePart") and child.Name ~= "HumanoidRootPart"
            and child.Transparency < 1 then
            rec.parts[#rec.parts + 1] = child
            local adorn = Instance.new("BoxHandleAdornment")
            adorn.Name = "ayzz7_Exposure"
            adorn.Adornee = child
            adorn.AlwaysOnTop = true
            adorn.ZIndex = 5
            adorn.Size = child.Size * 1.025
            adorn.Color3 = HIDDEN_COLOR
            adorn.Transparency = 0.58 -- vivid limbs with visible team outlines
            adorn.Visible = false -- avoid drawing excluded or distant players before update
            adorn.Parent = child
            rec.adornments[#rec.adornments + 1] = adorn
        end
    end
end

local function makePlayer(player)
    if player == LocalPlayer or tracked[player] then return end
    local rec = {
        player = player, character = nil, humanoid = nil, root = nil, head = nil,
        highlight = nil, parts = {}, adornments = {}, lines = {},
        active = false, connections = {}, rayIgnore = {},
    }
    tracked[player] = rec
    local container = create("Frame", {
        Name = "P_" .. player.UserId,
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
    }, overlay)
    rec.container = container
    for i = 1, 8 do
        rec.lines[i] = makeLine(container)
    end
    rec.nameLabel = create("TextLabel", {
        BackgroundTransparency = 1, TextColor3 = currentAccent,
        Font = Enum.Font.GothamBold, TextSize = 13,
        TextStrokeColor3 = Color3.fromRGB(0, 0, 0), TextStrokeTransparency = 0.15,
        TextXAlignment = Enum.TextXAlignment.Center,
        Size = UDim2.fromOffset(200, 20), Visible = false,
        Text = player.DisplayName,
    }, container)
    rec.connections[#rec.connections + 1] = player.CharacterAdded:Connect(function(char)
        if not destroyed then buildCharacter(rec, char) end
    end)
    rec.connections[#rec.connections + 1] = player.CharacterRemoving:Connect(function(char)
        if rec.character == char then removeCharacterVisuals(rec) end
    end)
    rec.connections[#rec.connections + 1] = player.CharacterAppearanceLoaded:Connect(function(char)
        if not destroyed and rec.character == char then
            buildCharacter(rec, char)
        end
    end)
    if player.Character then
        -- A task to avoid waiting for Humanoid/head during initial player enumeration.
        task.defer(function()
            if not destroyed and tracked[player] == rec then
                buildCharacter(rec, player.Character)
            end
        end)
    end
end

local function removePlayer(player)
    local rec = tracked[player]
    if not rec then return end
    tracked[player] = nil
    for _, conn in ipairs(rec.connections) do conn:Disconnect() end
    removeCharacterVisuals(rec)
    rec.container:Destroy()
end

local function hideScreen(rec)
    -- Always hide, even if this record was never onscreen.
    rec.active = false
    for i = 1, 8 do rec.lines[i].Visible = false end
    rec.nameLabel.Visible = false
    if rec.highlight then rec.highlight.Enabled = false end
    for _, adorn in ipairs(rec.adornments) do adorn.Visible = false end
end

local function drawCorners(lines, x, y, w, h)
    local a = math.max(5, math.min(w * 0.28, 18))
    local b = math.max(5, math.min(h * 0.20, 18))
    local t = BOX_THICKNESS
    -- top-left, top-right, bottom-left, bottom-right (two segments each)
    setRectangle(lines[1], x, y, a, t, currentAccent)
    setRectangle(lines[2], x, y, t, b, currentAccent)
    setRectangle(lines[3], x + w - a, y, a, t, currentAccent)
    setRectangle(lines[4], x + w - t, y, t, b, currentAccent)
    setRectangle(lines[5], x, y + h - t, a, t, currentAccent)
    setRectangle(lines[6], x, y + h - b, t, b, currentAccent)
    setRectangle(lines[7], x + w - a, y + h - t, a, t, currentAccent)
    setRectangle(lines[8], x + w - t, y + h - b, t, b, currentAccent)
    for i = 1, 8 do lines[i].Visible = true end
end

local function updateScreenESP()
    Camera = workspace.CurrentCamera
    if not Camera then return end
    local cameraPosition = Camera.CFrame.Position
    for player, rec in pairs(tracked) do
        local hum, root, head = rec.humanoid, rec.root, rec.head
        if not hum or not root or not head or hum.Health <= 0
            or not rec.character or not rec.character.Parent
            or not shouldShow(player)
            or (root.Position - cameraPosition).Magnitude > MAX_DISTANCE then
            hideScreen(rec)
        else
            local top3D = head.Position + Vector3.new(0, 0.65, 0)
            local bottom3D = root.Position - Vector3.new(0, 3, 0)
            local top2D, topVisible = Camera:WorldToViewportPoint(top3D)
            local bottom2D, bottomVisible = Camera:WorldToViewportPoint(bottom3D)
            if top2D.Z <= 0 or bottom2D.Z <= 0
                or not (topVisible or bottomVisible) then
                hideScreen(rec)
            else
                rec.active = true
                local height = math.clamp(math.abs(bottom2D.Y - top2D.Y), 12, 1500)
                local width = height * 0.52
                local x = top2D.X - width / 2
                local y = math.min(top2D.Y, bottom2D.Y)
                if config.cornerBoxes then
                    drawCorners(rec.lines, x, y, width, height)
                else
                    for i = 1, 8 do rec.lines[i].Visible = false end
                end
                rec.nameLabel.Visible = config.nameESP
                if config.nameESP then
                    rec.nameLabel.Position = UDim2.fromOffset(
                        math.floor(top2D.X - 100 + 0.5), math.floor(y - 22 + 0.5))
                    if rec.nameLabel.TextColor3 ~= currentAccent then
                        rec.nameLabel.TextColor3 = currentAccent
                    end
                end
                if rec.highlight then
                    if rec.highlight.Enabled ~= config.chams then
                        rec.highlight.Enabled = config.chams
                    end
                    local outline = teamColor(player)
                    if rec.highlight.OutlineColor ~= outline then
                        rec.highlight.OutlineColor = outline
                    end
                    if config.healthChams and config.chams then
                        local fraction = math.clamp(hum.Health / math.max(1, hum.MaxHealth), 0, 1)
                        local fill = Color3.fromRGB(
                            math.floor(255 * (1 - fraction)),
                            math.floor(255 * fraction), 35)
                        if rec.highlight.FillColor ~= fill then
                            rec.highlight.FillColor = fill
                        end
                        if rec.highlight.FillTransparency ~= 0.70 then
                            rec.highlight.FillTransparency = 0.70
                        end
                    else
                        if rec.highlight.FillTransparency ~= 1 then
                            rec.highlight.FillTransparency = 1
                        end
                    end
                end
                for _, adorn in ipairs(rec.adornments) do
                    if adorn.Visible ~= config.exposedParts then
                        adorn.Visible = false -- avoid drawing excluded or distant players before update
                    end
                end
            end
        end
    end
end

local function isExposed(part, origin, cameraRight)
    -- The character itself is ignored in the raycast filter so a nearby arm
    -- does not cause the torso (or the reverse) to appear "behind a wall".
    local target = part.Position
    if workspace:Raycast(origin, target - origin, rayParams) == nil then
        return true
    end
    -- A second, offset ray catches partially exposed limbs.
    local offset = cameraRight * math.min(0.4, part.Size.X * 0.32)
    return workspace:Raycast(origin, target + offset - origin, rayParams) == nil
end

local function updateExposure()
    if not config.exposedParts then return end
    Camera = workspace.CurrentCamera
    if not Camera then return end
    local origin = Camera.CFrame.Position
    local right = Camera.CFrame.RightVector
    local localCharacter = LocalPlayer.Character
    for _, rec in pairs(tracked) do
        if rec.active and rec.character and #rec.parts > 0 then
            -- Exclude the local avatar and the target's own limbs, but not walls.
            local exclude = rec.rayIgnore
            exclude[1] = rec.character
            exclude[2] = localCharacter
            rayParams.FilterDescendantsInstances = exclude
            for i, part in ipairs(rec.parts) do
                local adorn = rec.adornments[i]
                if adorn and part.Parent then
                    -- Only rebuild size if a game changed the part size.
                    if adorn.Size ~= part.Size * 1.025 then
                        adorn.Size = part.Size * 1.025
                    end
                    local exposed = isExposed(part, origin, right)
                    local wanted = exposed and VISIBLE_COLOR or HIDDEN_COLOR
                    if adorn.Color3 ~= wanted then
                        adorn.Color3 = wanted
                    end
                end
            end
        end
    end
end

applyVisuals = function()
    -- Changes are consumed by the single frame update; turn off instantly too.
    for _, rec in pairs(tracked) do
        if not config.cornerBoxes then
            for i = 1, 8 do rec.lines[i].Visible = false end
        end
        if not config.nameESP then rec.nameLabel.Visible = false end
        if rec.highlight and not config.chams then rec.highlight.Enabled = false end
        if not config.exposedParts then
            for _, adorn in ipairs(rec.adornments) do adorn.Visible = false end
        end
    end
end

for _, player in ipairs(Players:GetPlayers()) do makePlayer(player) end
connect(Players.PlayerAdded, makePlayer)
connect(Players.PlayerRemoving, removePlayer)

local boxElapsed, exposureElapsed = 0, 0
connect(RunService.RenderStepped, function(dt)
    if destroyed then return end
    boxElapsed = boxElapsed + dt
    exposureElapsed = exposureElapsed + dt
    if boxElapsed >= BOX_INTERVAL then
        boxElapsed = 0
        updateScreenESP()
    end
    if exposureElapsed >= EXPOSURE_INTERVAL then
        exposureElapsed = 0
        updateExposure()
    end
end)

local controller = {}
function controller:Destroy()
    if destroyed then return end
    destroyed = true
    for _, conn in ipairs(connections) do conn:Disconnect() end
    local playersToRemove = {}
    for player in pairs(tracked) do
        playersToRemove[#playersToRemove + 1] = player
    end
    for _, player in ipairs(playersToRemove) do
        removePlayer(player)
    end
    screen:Destroy()
    if environment.__AYZZ7_UNIVERSAL_ESP == self then
        environment.__AYZZ7_UNIVERSAL_ESP = nil
    end
end
connect(closeButton.MouseButton1Click, function() controller:Destroy() end)
environment.__AYZZ7_UNIVERSAL_ESP = controller
]=])()
