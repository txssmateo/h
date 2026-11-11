-- Saint's Hub Christmas Integrated V31 Preview (NO REAL KEY YET)

-- FINAL SESSION ACCESS KEYS
local __saintsKeyRng=Random.new()
local SESSION_ACCESS_KEYS={}
local SESSION_ACCESS_LOOKUP={}
while #SESSION_ACCESS_KEYS<10 do
    local k=tostring(__saintsKeyRng:NextInteger(100,999))
    if not SESSION_ACCESS_LOOKUP[k] then
        SESSION_ACCESS_LOOKUP[k]=true
        SESSION_ACCESS_KEYS[#SESSION_ACCESS_KEYS+1]=k
    end
end
local SESSION_DISPLAY_KEY=SESSION_ACCESS_KEYS[1]
local SoundService=game:GetService("SoundService")
if _G.SaintsChristmasIntegratedCleanup then pcall(_G.SaintsChristmasIntegratedCleanup) end
local mutedGameSounds={}
local soundAddedConn=nil
local introFinished=false
local function looksLikeGameMusic(s)
    if not s:IsA("Sound") or s.Name:match("^Saints") then return false end
    local n=string.lower(s.Name or "")
    return s.Looped or n:find("music",1,true) or n:find("lobby",1,true) or n:find("theme",1,true)
end
local function rememberAndMute(s)
    if mutedGameSounds[s]~=nil then return end
    if looksLikeGameMusic(s) then mutedGameSounds[s]=s.Volume; s.Volume=0 end
end
local function muteFTFMusic()
    for _,o in ipairs(game:GetDescendants()) do if o:IsA("Sound") then rememberAndMute(o) end end
    soundAddedConn=game.DescendantAdded:Connect(function(o)
        if not introFinished and o:IsA("Sound") then task.defer(function() if o.Parent and not introFinished then rememberAndMute(o) end end) end
    end)
end
local function restoreFTFMusic()
    introFinished=true
    if soundAddedConn then pcall(function() soundAddedConn:Disconnect() end); soundAddedConn=nil end
    for s,v in pairs(mutedGameSounds) do if s and s.Parent then pcall(function() s.Volume=v end) end end
    table.clear(mutedGameSounds)
end

local function startCrossy(onCrossyComplete)
--[[
    Saints Crossy Road - V1
    Standalone client-side GUI prototype.

    Controls:
      W / Up Arrow    = Hop forward
      S / Down Arrow  = Hop backward
      A / Left Arrow  = Hop left
      D / Right Arrow = Hop right
      R                = Restart after death/win
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- V12 CROSSY PLAYER FREEZE
-- Freeze only the real Roblox avatar; do not sink W/A/S/D, so Crossy still receives input.
local crossyFrozenRoot=nil
local crossyRootWasAnchored=nil
local function freezeActualCharacterForCrossy()
    local character=player.Character or player.CharacterAdded:Wait()
    local root=character:WaitForChild("HumanoidRootPart",5)
    if root then
        crossyFrozenRoot=root
        crossyRootWasAnchored=root.Anchored
        root.AssemblyLinearVelocity=Vector3.zero
        root.AssemblyAngularVelocity=Vector3.zero
        root.Anchored=true
    end
end
local function releaseActualCharacterAfterCrossy()
    local root=crossyFrozenRoot
    if root and root.Parent then
        root.AssemblyLinearVelocity=Vector3.zero
        root.AssemblyAngularVelocity=Vector3.zero
        root.Anchored=(crossyRootWasAnchored==true)
    end
    crossyFrozenRoot=nil
    crossyRootWasAnchored=nil
end
freezeActualCharacterForCrossy()


-- ===== VOLT LOCAL AUDIO =====
-- Audio-only addition. Volt's isfile() can report false for files that the
-- executor custom-asset resolver can still load, so resolve candidates directly.
local AUDIO_FILES = {
    hop = "freesound_gamestudio-bar-increase-cartoon-funny-jump-384919.mp3",
    impact = "universfield-cartoon-impact-02-278820.mp3",
    win = "puyopuyomegafan1234-winner-game-sound-404167.mp3",
}

local AUDIO_SEARCH_PATHS = {
    "",
    "workspace/",
    "Workspace/",
    "scripts/",
    "Scripts/",
}

local function getResolvers()
    local out = {}
    for _, resolver in ipairs({getcustomasset, getsynasset, getasset}) do
        if type(resolver) == "function" then
            out[#out + 1] = resolver
        end
    end
    return out
end

local function resolveAudioAsset(fileName)
    local resolvers = getResolvers()
    if #resolvers == 0 then
        warn("[Saints Crossy] Volt custom-asset resolver unavailable")
        return nil
    end

    -- Important: do NOT gate these attempts behind isfile().
    for _, prefix in ipairs(AUDIO_SEARCH_PATHS) do
        local candidate = prefix .. fileName
        for _, resolver in ipairs(resolvers) do
            local ok, result = pcall(resolver, candidate)
            if ok and type(result) == "string" and result ~= "" then
                return result, candidate
            end
        end
    end

    warn("[Saints Crossy] Volt could not resolve local MP3: " .. fileName)
    return nil
end

local tempAudio = {}
local function playLocalSfx(name, volume)
    local fileName = AUDIO_FILES[name]
    if not fileName then return nil end

    local asset, resolvedPath = resolveAudioAsset(fileName)
    if not asset then return nil end

    local sound = Instance.new("Sound")
    sound.Name = "SaintsCrossy_" .. name
    sound.SoundId = asset
    sound.Volume = volume or 0.8
    sound.Parent = SoundService
    tempAudio[#tempAudio + 1] = sound

    sound:Play()

    task.delay(1.5, function()
        if sound and sound.Parent and not sound.IsPlaying then
            warn("[Saints Crossy] Resolved but playback stayed silent: " .. tostring(resolvedPath) .. " | SoundId=" .. tostring(asset))
        end
    end)

    sound.Ended:Connect(function()
        pcall(function() sound:Destroy() end)
    end)

    task.delay(10, function()
        if sound and sound.Parent then
            pcall(function() sound:Destroy() end)
        end
    end)

    return sound
end

-- Cleanup previous copy.
if _G.SaintsCrossyRoadV1Cleanup then
    pcall(_G.SaintsCrossyRoadV1Cleanup)
end

local old = playerGui:FindFirstChild("SaintsCrossyRoadV1")
if old then
    old:Destroy()
end

-- ===== TUNING =====
local TILE = 54
local COLS = 11
local ROWS = 13
local HOP_TIME = 0.072
local CAR_HEIGHT = 34
local PLAYER_SIZE = 32

-- Bottom -> top.
-- "safe" = grass/safe zone
-- "road" = traffic lane
local laneData = {
    {kind="safe"},
    {kind="safe"},
    {kind="road", speed=245, dir= 1, spacing=250, offset=25},
    {kind="road", speed=315, dir=-1, spacing=285, offset=145},
    {kind="safe"},
    {kind="road", speed=275, dir= 1, spacing=245, offset=90},
    {kind="road", speed=345, dir=-1, spacing=305, offset=15},
    {kind="road", speed=295, dir= 1, spacing=260, offset=180},
    {kind="safe"},
    {kind="road", speed=330, dir=-1, spacing=255, offset=70},
    {kind="road", speed=285, dir= 1, spacing=275, offset=155},
    {kind="road", speed=360, dir=-1, spacing=300, offset=110},
    {kind="safe"}, -- finish
}

local gui = Instance.new("ScreenGui")
gui.Name = "SaintsCrossyRoadV1"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 999999
gui.Parent = playerGui

local backdrop = Instance.new("Frame")
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.fromRGB(8, 14, 24)
backdrop.BorderSizePixel = 0
backdrop.Parent = gui

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 20, 0, 16)
title.Size = UDim2.new(0, 340, 0, 30)
title.Font = Enum.Font.GothamBold
title.Text = "SAINTS • CHRISTMAS CROSSING"
title.TextColor3 = Color3.fromRGB(242, 242, 244)
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = backdrop
title.Visible = false

local titleStroke = Instance.new("UIStroke")
titleStroke.Thickness = 1
titleStroke.Color = Color3.fromRGB(170, 210, 235)
titleStroke.Transparency = 0.48
titleStroke.Parent = title

-- Winter-night atmosphere.
local moonGlow = Instance.new("Frame")
moonGlow.AnchorPoint = Vector2.new(0.5, 0.5)
moonGlow.Position = UDim2.new(0.86, 0, 0.12, 0)
moonGlow.Size = UDim2.fromOffset(86, 86)
moonGlow.BackgroundColor3 = Color3.fromRGB(180, 205, 232)
moonGlow.BackgroundTransparency = 0.88
moonGlow.BorderSizePixel = 0
moonGlow.ZIndex = 0
moonGlow.Parent = backdrop
local mgc = Instance.new("UICorner")
mgc.CornerRadius = UDim.new(1, 0)
mgc.Parent = moonGlow

local moon = Instance.new("Frame")
moon.AnchorPoint = Vector2.new(0.5, 0.5)
moon.Position = UDim2.new(0.86, 0, 0.12, 0)
moon.Size = UDim2.fromOffset(43, 43)
moon.BackgroundColor3 = Color3.fromRGB(240, 244, 237)
moon.BorderSizePixel = 0
moon.ZIndex = 1
moon.Parent = backdrop
local mc = Instance.new("UICorner")
mc.CornerRadius = UDim.new(1, 0)
mc.Parent = moon

-- Distant stars and snowy skyline for depth.
local starRng = Random.new(1225)
for i = 1, 38 do
    local star = Instance.new("Frame")
    local sz = starRng:NextInteger(1, 3)
    star.Size = UDim2.fromOffset(sz, sz)
    star.Position = UDim2.fromScale(starRng:NextNumber(0.03, 0.97), starRng:NextNumber(0.05, 0.40))
    star.BackgroundColor3 = Color3.fromRGB(235, 242, 250)
    star.BackgroundTransparency = starRng:NextNumber(0.18, 0.65)
    star.BorderSizePixel = 0
    star.ZIndex = 0
    star.Parent = backdrop
    local sc = Instance.new("UICorner")
    sc.CornerRadius = UDim.new(1, 0)
    sc.Parent = star
end

local skyline = Instance.new("Frame")
skyline.AnchorPoint = Vector2.new(0.5, 1)
skyline.Position = UDim2.new(0.5, 0, 1, -6)
skyline.Size = UDim2.new(1, 0, 0, 90)
skyline.BackgroundTransparency = 1
skyline.ZIndex = 0
skyline.Parent = backdrop

for i = 1, 16 do
    local hill = Instance.new("Frame")
    hill.AnchorPoint = Vector2.new(0.5, 1)
    hill.Position = UDim2.new((i-0.5)/16, 0, 1, 0)
    hill.Size = UDim2.fromOffset(95, 42 + (i%3)*12)
    hill.BackgroundColor3 = Color3.fromRGB(18, 32, 48)
    hill.BorderSizePixel = 0
    hill.Rotation = 45
    hill.ZIndex = 0
    hill.Parent = skyline
end

local help = Instance.new("TextLabel")
help.BackgroundTransparency = 1
help.AnchorPoint = Vector2.new(0.5, 1)
help.Position = UDim2.new(0.5, 0, 1, -14)
help.Size = UDim2.new(0.9, 0, 0, 28)
help.Font = Enum.Font.Gotham
help.Text = "WASD / ARROWS  •  CROSS THE WINTER ROAD"
help.TextColor3 = Color3.fromRGB(175, 178, 185)
help.TextSize = 14
help.Parent = backdrop

local board = Instance.new("Frame")
board.Name = "Board"
board.AnchorPoint = Vector2.new(0.5, 0.5)
board.Position = UDim2.fromScale(0.5, 0.52)
board.Size = UDim2.fromOffset(COLS * TILE, ROWS * TILE)
board.BackgroundColor3 = Color3.fromRGB(211, 226, 234)
board.BorderSizePixel = 0
board.ClipsDescendants = true
board.Parent = backdrop

local boardGlow = Instance.new("UIStroke")
boardGlow.Thickness = 5
boardGlow.Color = Color3.fromRGB(150, 196, 226)
boardGlow.Transparency = 0.72
boardGlow.Parent = board

local boardStroke = Instance.new("UIStroke")
boardStroke.Thickness = 2
boardStroke.Color = Color3.fromRGB(235, 235, 238)
boardStroke.Transparency = 0.55
boardStroke.Parent = board

-- Lane visuals.
for row, lane in ipairs(laneData) do
    local laneFrame = Instance.new("Frame")
    laneFrame.Name = "Lane_" .. row
    laneFrame.Position = UDim2.fromOffset(0, (ROWS - row) * TILE)
    laneFrame.Size = UDim2.fromOffset(COLS * TILE, TILE)
    laneFrame.BorderSizePixel = 0
    laneFrame.ZIndex = 1

    if lane.kind == "road" then
        laneFrame.BackgroundColor3 = Color3.fromRGB(38, 45, 55)

        local dashY = Instance.new("Frame")
        dashY.AnchorPoint = Vector2.new(0, 0.5)
        dashY.Position = UDim2.new(0, 0, 0.5, 0)
        dashY.Size = UDim2.new(1, 0, 0, 2)
        dashY.BackgroundColor3 = Color3.fromRGB(185, 185, 188)
        dashY.BackgroundTransparency = 0.58
        dashY.BorderSizePixel = 0
        dashY.ZIndex = 2
        dashY.Parent = laneFrame
    else
        laneFrame.BackgroundColor3 =
            (row == ROWS) and Color3.fromRGB(228, 239, 244) or Color3.fromRGB(204, 220, 228)
    end

    laneFrame.Parent = board

    if lane.kind == "road" then
        -- Snowy curb edges.
        for _, edgeY in ipairs({0, TILE - 3}) do
            local curb = Instance.new("Frame")
            curb.Position = UDim2.fromOffset(0, edgeY)
            curb.Size = UDim2.new(1, 0, 0, 3)
            curb.BackgroundColor3 = Color3.fromRGB(224, 232, 237)
            curb.BackgroundTransparency = 0.18
            curb.BorderSizePixel = 0
            curb.ZIndex = 3
            curb.Parent = laneFrame
        end

        -- Dashed lane reflectors.
        for x = 18, COLS*TILE, 58 do
            local reflector = Instance.new("Frame")
            reflector.AnchorPoint = Vector2.new(0.5, 0.5)
            reflector.Position = UDim2.fromOffset(x, TILE/2)
            reflector.Size = UDim2.fromOffset(22, 2)
            reflector.BackgroundColor3 = Color3.fromRGB(231, 214, 148)
            reflector.BackgroundTransparency = 0.38
            reflector.BorderSizePixel = 0
            reflector.ZIndex = 3
            reflector.Parent = laneFrame
        end
    end
end

-- Finish stripe.
local finishStripe = Instance.new("Frame")
finishStripe.Position = UDim2.fromOffset(0, 0)
finishStripe.Size = UDim2.fromOffset(COLS * TILE, 5)
finishStripe.BackgroundColor3 = Color3.fromRGB(242, 242, 244)
finishStripe.BorderSizePixel = 0
finishStripe.ZIndex = 4
finishStripe.Parent = board

local finishText = Instance.new("TextLabel")
finishText.BackgroundTransparency = 1
finishText.Position = UDim2.fromOffset(0, 6)
finishText.Size = UDim2.fromOffset(COLS * TILE, 30)
finishText.Font = Enum.Font.GothamBold
finishText.Text = "FINISH"
finishText.TextColor3 = Color3.fromRGB(238, 238, 240)
finishText.TextSize = 14
finishText.ZIndex = 4
finishText.Parent = board

-- ===== CHRISTMAS VISUAL LAYER =====
-- Decorative only. Nothing here participates in gameplay/collision.

local decor = Instance.new("Frame")
decor.Name = "ChristmasDecor"
decor.BackgroundTransparency = 1
decor.Size = UDim2.fromScale(1, 1)
decor.ZIndex = 3
decor.Parent = board

local function rounded(frame, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = frame
end

local function makePine(x, y, scale)
    local trunk = Instance.new("Frame")
    trunk.AnchorPoint = Vector2.new(0.5, 1)
    trunk.Position = UDim2.fromOffset(x, y)
    trunk.Size = UDim2.fromOffset(7*scale, 15*scale)
    trunk.BackgroundColor3 = Color3.fromRGB(93, 65, 48)
    trunk.BorderSizePixel = 0
    trunk.ZIndex = 4
    trunk.Parent = decor

    local widths = {30, 23, 17}
    for i, w in ipairs(widths) do
        local tier = Instance.new("Frame")
        tier.AnchorPoint = Vector2.new(0.5, 1)
        tier.Position = UDim2.fromOffset(x, y - (10 + (i-1)*11)*scale)
        tier.Size = UDim2.fromOffset(w*scale, 20*scale)
        tier.BackgroundColor3 = Color3.fromRGB(29, 83, 59)
        tier.BorderSizePixel = 0
        tier.Rotation = 45
        tier.ZIndex = 4
        tier.Parent = decor
    end

    local cap = Instance.new("Frame")
    cap.AnchorPoint = Vector2.new(0.5, 0.5)
    cap.Position = UDim2.fromOffset(x, y - 40*scale)
    cap.Size = UDim2.fromOffset(11*scale, 5*scale)
    cap.BackgroundColor3 = Color3.fromRGB(249, 251, 252)
    cap.BorderSizePixel = 0
    cap.ZIndex = 5
    cap.Parent = decor
    rounded(cap, 4)
end

local function makeSnowbank(x, y, w)
    local b = Instance.new("Frame")
    b.AnchorPoint = Vector2.new(0.5, 0.5)
    b.Position = UDim2.fromOffset(x, y)
    b.Size = UDim2.fromOffset(w, 10)
    b.BackgroundColor3 = Color3.fromRGB(247, 250, 252)
    b.BorderSizePixel = 0
    b.ZIndex = 3
    b.Parent = decor
    rounded(b, 8)
end

-- Decorations remain near edges of safe rows.
makePine(28, TILE*2 - 5, 0.70)
makePine(COLS*TILE - 28, TILE*5 - 5, 0.66)
makePine(30, TILE*9 - 5, 0.68)
makePine(COLS*TILE - 29, TILE*12 - 5, 0.72)
makeSnowbank(88, TILE*2 - 7, 48)
makeSnowbank(COLS*TILE - 86, TILE*9 - 7, 52)


local function makeLamp(x, y)
    local post = Instance.new("Frame")
    post.AnchorPoint = Vector2.new(0.5, 1)
    post.Position = UDim2.fromOffset(x, y)
    post.Size = UDim2.fromOffset(4, 29)
    post.BackgroundColor3 = Color3.fromRGB(46, 49, 55)
    post.BorderSizePixel = 0
    post.ZIndex = 5
    post.Parent = decor

    local glow = Instance.new("Frame")
    glow.AnchorPoint = Vector2.new(0.5, 0.5)
    glow.Position = UDim2.new(0.5, 0, 0, -2)
    glow.Size = UDim2.fromOffset(24, 24)
    glow.BackgroundColor3 = Color3.fromRGB(255, 217, 132)
    glow.BackgroundTransparency = 0.78
    glow.BorderSizePixel = 0
    glow.ZIndex = 4
    glow.Parent = post
    rounded(glow, 20)

    local bulb = Instance.new("Frame")
    bulb.AnchorPoint = Vector2.new(0.5, 0.5)
    bulb.Position = UDim2.new(0.5, 0, 0, -2)
    bulb.Size = UDim2.fromOffset(9, 9)
    bulb.BackgroundColor3 = Color3.fromRGB(255, 228, 158)
    bulb.BorderSizePixel = 0
    bulb.ZIndex = 6
    bulb.Parent = post
    rounded(bulb, 9)
end

local function makeGift(x, y, color)
    local gift = Instance.new("Frame")
    gift.AnchorPoint = Vector2.new(0.5, 1)
    gift.Position = UDim2.fromOffset(x, y)
    gift.Size = UDim2.fromOffset(19, 17)
    gift.BackgroundColor3 = color
    gift.BorderSizePixel = 0
    gift.ZIndex = 6
    gift.Parent = decor
    rounded(gift, 3)

    local ribbonV = Instance.new("Frame")
    ribbonV.AnchorPoint = Vector2.new(0.5, 0.5)
    ribbonV.Position = UDim2.fromScale(0.5, 0.5)
    ribbonV.Size = UDim2.new(0, 4, 1, 0)
    ribbonV.BackgroundColor3 = Color3.fromRGB(245, 220, 129)
    ribbonV.BorderSizePixel = 0
    ribbonV.ZIndex = 7
    ribbonV.Parent = gift

    local ribbonH = Instance.new("Frame")
    ribbonH.AnchorPoint = Vector2.new(0.5, 0.5)
    ribbonH.Position = UDim2.fromScale(0.5, 0.5)
    ribbonH.Size = UDim2.new(1, 0, 0, 4)
    ribbonH.BackgroundColor3 = Color3.fromRGB(245, 220, 129)
    ribbonH.BorderSizePixel = 0
    ribbonH.ZIndex = 7
    ribbonH.Parent = gift
end

makeLamp(19, TILE*2 - 4)
makeLamp(COLS*TILE - 19, TILE*9 - 4)
makeGift(58, TILE*2 - 3, Color3.fromRGB(183, 49, 54))
makeGift(COLS*TILE - 60, TILE*12 - 3, Color3.fromRGB(46, 126, 82))

-- Warm bulbs across the finish edge.
local bulbColors = {
    Color3.fromRGB(235, 76, 69),
    Color3.fromRGB(247, 204, 83),
    Color3.fromRGB(73, 185, 108),
    Color3.fromRGB(91, 150, 235),
}
for i = 1, 17 do
    local bulb = Instance.new("Frame")
    bulb.AnchorPoint = Vector2.new(0.5, 0.5)
    bulb.Position = UDim2.fromOffset((i - 0.5) * ((COLS*TILE)/17), 13)
    bulb.Size = UDim2.fromOffset(7, 7)
    bulb.BackgroundColor3 = bulbColors[((i-1) % #bulbColors)+1]
    bulb.BorderSizePixel = 0
    bulb.ZIndex = 7
    bulb.Parent = decor
    rounded(bulb, 7)
end

-- Player.
local character = Instance.new("Frame")
character.Name = "Player"
character.AnchorPoint = Vector2.new(0.5, 0.5)
character.Size = UDim2.fromOffset(PLAYER_SIZE, PLAYER_SIZE)
character.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
character.BorderSizePixel = 0
character.BackgroundTransparency = 1
character.Visible = true
character.ZIndex = 20
character.Parent = board

local charCorner = Instance.new("UICorner")
charCorner.CornerRadius = UDim.new(0, 6)
charCorner.Parent = character

local charStroke = Instance.new("UIStroke")
charStroke.Thickness = 0
charStroke.Color = Color3.fromRGB(30, 32, 38)
charStroke.Transparency = 0.15
charStroke.Parent = character

local eye1 = Instance.new("Frame")
eye1.Size = UDim2.fromOffset(5, 5)
eye1.Position = UDim2.new(0.24, 0, 0.18, 0)
eye1.BackgroundTransparency = 1
eye1.BorderSizePixel = 0
eye1.ZIndex = 21
eye1.Parent = character

local eye2 = eye1:Clone()
eye2.Position = UDim2.new(0.61, 0, 0.18, 0)
eye2.Parent = character

-- Crossy Road chicken visual, parented to the existing movement/collision root.
local chickenBody = Instance.new("Frame")
chickenBody.Name = "ChickenBody"
chickenBody.AnchorPoint = Vector2.new(0.5, 0.5)
chickenBody.Position = UDim2.fromScale(0.5, 0.55)
chickenBody.Size = UDim2.fromOffset(27, 25)
chickenBody.BackgroundColor3 = Color3.fromRGB(250, 247, 231)
chickenBody.BorderSizePixel = 0
chickenBody.ZIndex = 22
chickenBody.Parent = character
local chickenBodyCorner = Instance.new("UICorner")
chickenBodyCorner.CornerRadius = UDim.new(0, 6)
chickenBodyCorner.Parent = chickenBody

local chickenHead = Instance.new("Frame")
chickenHead.AnchorPoint = Vector2.new(0.5, 0.5)
chickenHead.Position = UDim2.new(0.5, 0, 0, -5)
chickenHead.Size = UDim2.fromOffset(22, 20)
chickenHead.BackgroundColor3 = Color3.fromRGB(255, 252, 238)
chickenHead.BorderSizePixel = 0
chickenHead.ZIndex = 23
chickenHead.Parent = chickenBody
local chickenHeadCorner = Instance.new("UICorner")
chickenHeadCorner.CornerRadius = UDim.new(0, 5)
chickenHeadCorner.Parent = chickenHead

local comb = Instance.new("Frame")
comb.AnchorPoint = Vector2.new(0.5, 1)
comb.Position = UDim2.new(0.5, 0, 0, -8)
comb.Size = UDim2.fromOffset(10, 7)
comb.BackgroundColor3 = Color3.fromRGB(222, 65, 61)
comb.BorderSizePixel = 0
comb.ZIndex = 24
comb.Parent = chickenHead
local combCorner = Instance.new("UICorner")
combCorner.CornerRadius = UDim.new(1, 0)
combCorner.Parent = comb

local beak = Instance.new("Frame")
beak.AnchorPoint = Vector2.new(0.5, 0.5)
beak.Position = UDim2.new(0.5, 0, 1, 3)
beak.Size = UDim2.fromOffset(9, 6)
beak.BackgroundColor3 = Color3.fromRGB(245, 174, 56)
beak.BorderSizePixel = 0
beak.Rotation = 45
beak.ZIndex = 24
beak.Parent = chickenHead

for _, ex in ipairs({0.28, 0.72}) do
    local eye = Instance.new("Frame")
    eye.AnchorPoint = Vector2.new(0.5, 0.5)
    eye.Position = UDim2.new(ex, 0, 0.45, 0)
    eye.Size = UDim2.fromOffset(4, 4)
    eye.BackgroundColor3 = Color3.fromRGB(28, 29, 32)
    eye.BorderSizePixel = 0
    eye.ZIndex = 25
    eye.Parent = chickenHead
    local ec = Instance.new("UICorner")
    ec.CornerRadius = UDim.new(1, 0)
    ec.Parent = eye
end

for _, lx in ipairs({0.30, 0.70}) do
    local leg = Instance.new("Frame")
    leg.AnchorPoint = Vector2.new(0.5, 0)
    leg.Position = UDim2.new(lx, 0, 1, -1)
    leg.Size = UDim2.fromOffset(3, 8)
    leg.BackgroundColor3 = Color3.fromRGB(230, 158, 50)
    leg.BorderSizePixel = 0
    leg.ZIndex = 21
    leg.Parent = chickenBody
end


-- Soft chicken shadow to separate it from the snow/road.
local chickenShadow = Instance.new("Frame")
chickenShadow.Name = "ChickenShadow"
chickenShadow.AnchorPoint = Vector2.new(0.5, 0.5)
chickenShadow.Size = UDim2.fromOffset(27, 9)
chickenShadow.BackgroundColor3 = Color3.fromRGB(10, 14, 18)
chickenShadow.BackgroundTransparency = 0.58
chickenShadow.BorderSizePixel = 0
chickenShadow.ZIndex = 18
chickenShadow.Parent = board
local shadowCorner = Instance.new("UICorner")
shadowCorner.CornerRadius = UDim.new(1, 0)
shadowCorner.Parent = chickenShadow


local screenFlash = Instance.new("Frame")
screenFlash.Size = UDim2.fromScale(1, 1)
screenFlash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
screenFlash.BackgroundTransparency = 1
screenFlash.BorderSizePixel = 0
screenFlash.ZIndex = 45
screenFlash.Parent = backdrop

local function flashScreen(color, peakTransparency)
    screenFlash.BackgroundColor3 = color
    screenFlash.BackgroundTransparency = 1
    TweenService:Create(
        screenFlash,
        TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundTransparency = peakTransparency}
    ):Play()
    task.delay(0.09, function()
        if screenFlash and screenFlash.Parent then
            TweenService:Create(
                screenFlash,
                TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {BackgroundTransparency = 1}
            ):Play()
        end
    end)
end

-- Status overlay.
local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.AnchorPoint = Vector2.new(0.5, 0.5)
status.Position = UDim2.fromScale(0.5, 0.43)
status.Size = UDim2.new(0.8, 0, 0, 60)
status.Font = Enum.Font.GothamBold
status.Text = ""
status.TextColor3 = Color3.fromRGB(250, 250, 252)
status.TextSize = 31
status.ZIndex = 50
status.Parent = backdrop

local statusSub = Instance.new("TextLabel")
statusSub.BackgroundTransparency = 1
statusSub.AnchorPoint = Vector2.new(0.5, 0.5)
statusSub.Position = UDim2.fromScale(0.5, 0.48)
statusSub.Size = UDim2.new(0.8, 0, 0, 40)
statusSub.Font = Enum.Font.Gotham
statusSub.Text = ""
statusSub.TextColor3 = Color3.fromRGB(198, 199, 204)
statusSub.TextSize = 15
statusSub.ZIndex = 50
statusSub.Parent = backdrop

status.Visible = false
statusSub.Visible = false

-- ===== POLISHED ARCADE RESULT MODAL =====
local resultShade = Instance.new("Frame")
resultShade.Name = "ResultShade"
resultShade.Size = UDim2.fromScale(1, 1)
resultShade.BackgroundColor3 = Color3.fromRGB(4, 8, 14)
resultShade.BackgroundTransparency = 1
resultShade.BorderSizePixel = 0
resultShade.Visible = false
resultShade.ZIndex = 60
resultShade.Parent = backdrop

local resultCardGlow = Instance.new("Frame")
resultCardGlow.AnchorPoint = Vector2.new(0.5, 0.5)
resultCardGlow.Position = UDim2.fromScale(0.5, 0.5)
resultCardGlow.Size = UDim2.fromOffset(430, 226)
resultCardGlow.BackgroundColor3 = Color3.fromRGB(113, 171, 210)
resultCardGlow.BackgroundTransparency = 0.76
resultCardGlow.BorderSizePixel = 0
resultCardGlow.ZIndex = 61
resultCardGlow.Parent = resultShade
local resultGlowCorner = Instance.new("UICorner")
resultGlowCorner.CornerRadius = UDim.new(0, 24)
resultGlowCorner.Parent = resultCardGlow

local resultCard = Instance.new("Frame")
resultCard.AnchorPoint = Vector2.new(0.5, 0.5)
resultCard.Position = UDim2.fromScale(0.5, 0.5)
resultCard.Size = UDim2.fromOffset(402, 202)
resultCard.BackgroundColor3 = Color3.fromRGB(13, 20, 31)
resultCard.BackgroundTransparency = 0.06
resultCard.BorderSizePixel = 0
resultCard.ZIndex = 62
resultCard.Parent = resultShade
local resultCorner = Instance.new("UICorner")
resultCorner.CornerRadius = UDim.new(0, 19)
resultCorner.Parent = resultCard
local resultStroke = Instance.new("UIStroke")
resultStroke.Thickness = 2
resultStroke.Color = Color3.fromRGB(209, 229, 240)
resultStroke.Transparency = 0.16
resultStroke.Parent = resultCard

local resultAccent = Instance.new("Frame")
resultAccent.AnchorPoint = Vector2.new(0.5, 0)
resultAccent.Position = UDim2.new(0.5, 0, 0, 0)
resultAccent.Size = UDim2.new(0.72, 0, 0, 4)
resultAccent.BackgroundColor3 = Color3.fromRGB(207, 61, 65)
resultAccent.BorderSizePixel = 0
resultAccent.ZIndex = 63
resultAccent.Parent = resultCard
local resultAccentCorner = Instance.new("UICorner")
resultAccentCorner.CornerRadius = UDim.new(1, 0)
resultAccentCorner.Parent = resultAccent

local resultIcon = Instance.new("TextLabel")
resultIcon.BackgroundTransparency = 1
resultIcon.Position = UDim2.new(0, 0, 0, 17)
resultIcon.Size = UDim2.new(1, 0, 0, 28)
resultIcon.Font = Enum.Font.SourceSansBold
resultIcon.Text = ""
resultIcon.TextSize = 27
resultIcon.TextColor3 = Color3.fromRGB(235, 210, 126)
resultIcon.ZIndex = 64
resultIcon.Parent = resultCard
resultIcon.Visible = false

-- Reliable skull built from GUI shapes (no emoji/font dependency).
local skull = Instance.new("Frame")
skull.Name = "DrawnSkull"
skull.AnchorPoint = Vector2.new(0.5, 0.5)
skull.Position = UDim2.new(0.5, 0, 0, 31)
skull.Size = UDim2.fromOffset(25, 22)
skull.BackgroundColor3 = Color3.fromRGB(242, 242, 236)
skull.BorderSizePixel = 0
skull.ZIndex = 66
skull.Parent = resultCard
skull.Visible = false
local skullCorner = Instance.new("UICorner")
skullCorner.CornerRadius = UDim.new(0, 8)
skullCorner.Parent = skull

for _, ex in ipairs({0.31, 0.69}) do
    local socket = Instance.new("Frame")
    socket.AnchorPoint = Vector2.new(0.5, 0.5)
    socket.Position = UDim2.new(ex, 0, 0.45, 0)
    socket.Size = UDim2.fromOffset(6, 7)
    socket.BackgroundColor3 = Color3.fromRGB(25, 29, 36)
    socket.BorderSizePixel = 0
    socket.ZIndex = 67
    socket.Parent = skull
    local sc = Instance.new("UICorner")
    sc.CornerRadius = UDim.new(1, 0)
    sc.Parent = socket
end

local nose = Instance.new("Frame")
nose.AnchorPoint = Vector2.new(0.5, 0.5)
nose.Position = UDim2.new(0.5, 0, 0.68, 0)
nose.Size = UDim2.fromOffset(4, 4)
nose.BackgroundColor3 = Color3.fromRGB(25, 29, 36)
nose.BorderSizePixel = 0
nose.Rotation = 45
nose.ZIndex = 67
nose.Parent = skull

local jaw = Instance.new("Frame")
jaw.AnchorPoint = Vector2.new(0.5, 0)
jaw.Position = UDim2.new(0.5, 0, 1, -4)
jaw.Size = UDim2.fromOffset(15, 8)
jaw.BackgroundColor3 = Color3.fromRGB(242, 242, 236)
jaw.BorderSizePixel = 0
jaw.ZIndex = 66
jaw.Parent = skull
local jc = Instance.new("UICorner")
jc.CornerRadius = UDim.new(0, 3)
jc.Parent = jaw

for i = 1, 3 do
    local tooth = Instance.new("Frame")
    tooth.Position = UDim2.new((i-1)/3, 2, 0, 3)
    tooth.Size = UDim2.fromOffset(2, 5)
    tooth.BackgroundColor3 = Color3.fromRGB(35, 39, 45)
    tooth.BorderSizePixel = 0
    tooth.ZIndex = 67
    tooth.Parent = jaw
end

local keyBadge = Instance.new("Frame")
keyBadge.AnchorPoint = Vector2.new(0.5, 0.5)
keyBadge.Position = UDim2.new(0.5, 0, 0, 104)
keyBadge.Size = UDim2.fromOffset(188, 34)
keyBadge.BackgroundColor3 = Color3.fromRGB(45, 38, 19)
keyBadge.BackgroundTransparency = 0.05
keyBadge.BorderSizePixel = 0
keyBadge.Visible = false
keyBadge.ZIndex = 65
keyBadge.Parent = resultCard
local kbc = Instance.new("UICorner")
kbc.CornerRadius = UDim.new(0, 10)
kbc.Parent = keyBadge
local kbs = Instance.new("UIStroke")
kbs.Thickness = 1.5
kbs.Color = Color3.fromRGB(244, 211, 107)
kbs.Transparency = 0.12
kbs.Parent = keyBadge

local keyBadgeText = Instance.new("TextLabel")
keyBadgeText.Size = UDim2.fromScale(1, 1)
keyBadgeText.BackgroundTransparency = 1
keyBadgeText.Font = Enum.Font.GothamBlack
keyBadgeText.Text = "KEY - 12345"
keyBadgeText.TextSize = 18
keyBadgeText.TextColor3 = Color3.fromRGB(255, 224, 119)
keyBadgeText.ZIndex = 66
keyBadgeText.Parent = keyBadge

local resultTitle = Instance.new("TextLabel")
resultTitle.BackgroundTransparency = 1
resultTitle.Position = UDim2.new(0, 18, 0, 52)
resultTitle.Size = UDim2.new(1, -36, 0, 39)
resultTitle.Font = Enum.Font.GothamBlack
resultTitle.Text = "ROADKILL"
resultTitle.TextSize = 31
resultTitle.TextColor3 = Color3.fromRGB(250, 250, 247)
resultTitle.TextXAlignment = Enum.TextXAlignment.Center
resultTitle.ZIndex = 64
resultTitle.Parent = resultCard


local resultKey = Instance.new("TextLabel")
resultKey.BackgroundTransparency = 1
resultKey.Position = UDim2.new(0, 18, 0, 94)
resultKey.Size = UDim2.new(1, -36, 0, 30)
resultKey.Font = Enum.Font.GothamBold
resultKey.Text = "ACCESS KEY: "..SESSION_DISPLAY_KEY
resultKey.TextSize = 20
resultKey.TextColor3 = Color3.fromRGB(255, 222, 105)
resultKey.TextXAlignment = Enum.TextXAlignment.Center
resultKey.Visible = false
resultKey.ZIndex = 64
resultKey.Parent = resultCard

local resultPrompt = Instance.new("TextLabel")
resultPrompt.BackgroundTransparency = 1
resultPrompt.Position = UDim2.new(0, 18, 0, 139)
resultPrompt.Size = UDim2.new(1, -36, 0, 25)
resultPrompt.Font = Enum.Font.GothamBold
resultPrompt.Text = "PRESS  R  TO  RETRY"
resultPrompt.TextSize = 18
resultPrompt.TextColor3 = Color3.fromRGB(213, 227, 237)
resultPrompt.TextXAlignment = Enum.TextXAlignment.Center
resultPrompt.ZIndex = 64
resultPrompt.Parent = resultCard


local unlockText = Instance.new("TextLabel")
unlockText.BackgroundTransparency = 1
unlockText.Position = UDim2.new(0, 18, 0, 126)
unlockText.Size = UDim2.new(1, -36, 0, 16)
unlockText.Font = Enum.Font.GothamMedium
unlockText.Text = "AUTH KEY UNLOCKED"
unlockText.TextSize = 10
unlockText.TextColor3 = Color3.fromRGB(158, 184, 199)
unlockText.Visible = false
unlockText.ZIndex = 64
unlockText.Parent = resultCard

local resultHint = Instance.new("TextLabel")
resultHint.BackgroundTransparency = 1
resultHint.Position = UDim2.new(0, 18, 1, -23)
resultHint.Size = UDim2.new(1, -36, 0, 14)
resultHint.Font = Enum.Font.GothamMedium
resultHint.Text = ""
resultHint.TextSize = 10
resultHint.TextColor3 = Color3.fromRGB(120, 145, 164)
resultHint.TextXAlignment = Enum.TextXAlignment.Center
resultHint.ZIndex = 64
resultHint.Parent = resultCard
resultHint.Visible = false

local function showResult(kind)
    resultShade.Visible = true
    resultShade.BackgroundTransparency = 1
    resultCard.Size = UDim2.fromOffset(350, 170)
    resultCardGlow.Size = UDim2.fromOffset(372, 188)

    if kind == "win" then
        resultTitle.Text = "YOU MADE IT!"
        resultPrompt.Text = ""
        resultIcon.Text = ""
        resultIcon.Visible = false
        skull.Visible = false
        resultKey.Text = "ACCESS KEY: "..SESSION_DISPLAY_KEY
        resultKey.Visible = true
        keyBadge.Visible = false
        unlockText.Visible = false
        resultAccent.BackgroundColor3 = Color3.fromRGB(61, 160, 103)
        resultCardGlow.BackgroundColor3 = Color3.fromRGB(100, 191, 143)
    else
        resultTitle.Text = "ROADKILL"
        resultPrompt.Text = "PRESS  R  TO  RETRY"
        resultKey.Visible = false
        resultIcon.Text = ""
        resultIcon.Font = Enum.Font.SourceSansBold
        resultKey.Visible = false
        resultAccent.BackgroundColor3 = Color3.fromRGB(207, 61, 65)
        resultCardGlow.BackgroundColor3 = Color3.fromRGB(194, 76, 79)
    end

    TweenService:Create(resultShade, TweenInfo.new(0.16), {
        BackgroundTransparency = 0.35
    }):Play()
    TweenService:Create(resultCard, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.fromOffset(402, 202)
    }):Play()
    TweenService:Create(resultCardGlow, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.fromOffset(430, 226)
    }):Play()
end

local function hideResult()
    resultShade.Visible = false
end


-- Festive finish arch.
local function makeCandyPost(x)
    local post = Instance.new("Frame")
    post.AnchorPoint = Vector2.new(0.5, 0)
    post.Position = UDim2.fromOffset(x, 2)
    post.Size = UDim2.fromOffset(10, 44)
    post.BackgroundColor3 = Color3.fromRGB(245, 245, 239)
    post.BorderSizePixel = 0
    post.ZIndex = 8
    post.Parent = decor
    rounded(post, 5)

    for y = 5, 38, 12 do
        local stripe = Instance.new("Frame")
        stripe.Position = UDim2.fromOffset(0, y)
        stripe.Size = UDim2.fromOffset(10, 5)
        stripe.BackgroundColor3 = Color3.fromRGB(205, 50, 56)
        stripe.BorderSizePixel = 0
        stripe.Rotation = -18
        stripe.ZIndex = 9
        stripe.Parent = post
    end
end

makeCandyPost(16)
makeCandyPost(COLS*TILE - 16)

local archTop = Instance.new("Frame")
archTop.AnchorPoint = Vector2.new(0.5, 0)
archTop.Position = UDim2.fromOffset(COLS*TILE/2, 2)
archTop.Size = UDim2.new(1, -32, 0, 7)
archTop.BackgroundColor3 = Color3.fromRGB(35, 104, 69)
archTop.BorderSizePixel = 0
archTop.ZIndex = 8
archTop.Parent = decor
rounded(archTop, 7)

-- Cars.
local cars = {}
local carColors = {
    Color3.fromRGB(210, 70, 70),
    Color3.fromRGB(78, 132, 215),
    Color3.fromRGB(232, 178, 65),
    Color3.fromRGB(168, 90, 202),
    Color3.fromRGB(65, 175, 155),
}

local function createCar(row, lane, index, x)
    local widths = {72, 84, 96}
    local carW = widths[((index - 1) % #widths) + 1]

    local car = Instance.new("Frame")
    car.Name = "Car"
    car.AnchorPoint = Vector2.new(0.5, 0.5)
    car.Size = UDim2.fromOffset(carW, CAR_HEIGHT)
    car.BackgroundColor3 = carColors[((row + index - 2) % #carColors) + 1]
    car.BorderSizePixel = 0
    car.ZIndex = 10
    car.Parent = board

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = car

    local window = Instance.new("Frame")
    window.AnchorPoint = Vector2.new(0.5, 0.5)
    window.Position = UDim2.fromScale(0.5, 0.5)
    window.Size = UDim2.new(0.42, 0, 0.58, 0)
    window.BackgroundColor3 = Color3.fromRGB(32, 37, 44)
    window.BorderSizePixel = 0
    window.ZIndex = 11
    window.Parent = car

    local wc = Instance.new("UICorner")
    wc.CornerRadius = UDim.new(0, 4)
    wc.Parent = window

    -- Decorative tires.
    for _, px in ipairs({0.22, 0.78}) do
        local tire = Instance.new("Frame")
        tire.AnchorPoint = Vector2.new(0.5, 0.5)
        tire.Position = UDim2.new(px, 0, 1, -1)
        tire.Size = UDim2.fromOffset(13, 7)
        tire.BackgroundColor3 = Color3.fromRGB(16, 18, 22)
        tire.BorderSizePixel = 0
        tire.ZIndex = 9
        tire.Parent = car
        local tc = Instance.new("UICorner")
        tc.CornerRadius = UDim.new(1, 0)
        tc.Parent = tire
    end

    -- Headlight on the travel-facing side.
    local lamp = Instance.new("Frame")
    lamp.AnchorPoint = Vector2.new(0.5, 0.5)
    lamp.Position = lane.dir > 0 and UDim2.new(1, -4, 0.5, 0) or UDim2.new(0, 4, 0.5, 0)
    lamp.Size = UDim2.fromOffset(5, 13)
    lamp.BackgroundColor3 = Color3.fromRGB(255, 237, 174)
    lamp.BorderSizePixel = 0
    lamp.ZIndex = 12
    lamp.Parent = car
    local lampCorner = Instance.new("UICorner")
    lampCorner.CornerRadius = UDim.new(1, 0)
    lampCorner.Parent = lamp

    -- Thin snow dusting along the roof.
    local roofSnow = Instance.new("Frame")
    roofSnow.AnchorPoint = Vector2.new(0.5, 0)
    roofSnow.Position = UDim2.new(0.5, 0, 0, -2)
    roofSnow.Size = UDim2.new(0.48, 0, 0, 4)
    roofSnow.BackgroundColor3 = Color3.fromRGB(244, 248, 250)
    roofSnow.BorderSizePixel = 0
    roofSnow.ZIndex = 12
    roofSnow.Parent = car
    local rsc = Instance.new("UICorner")
    rsc.CornerRadius = UDim.new(1, 0)
    rsc.Parent = roofSnow



    -- Windshield shine + lower bumper give the cars more shape.
    local shine = Instance.new("Frame")
    shine.AnchorPoint = Vector2.new(0.5, 0.5)
    shine.Position = UDim2.new(0.5, 0, 0.35, 0)
    shine.Size = UDim2.new(0.22, 0, 0, 2)
    shine.BackgroundColor3 = Color3.fromRGB(196, 226, 244)
    shine.BackgroundTransparency = 0.38
    shine.BorderSizePixel = 0
    shine.ZIndex = 13
    shine.Parent = car

    local bumper = Instance.new("Frame")
    bumper.AnchorPoint = Vector2.new(0.5, 1)
    bumper.Position = UDim2.new(0.5, 0, 1, 1)
    bumper.Size = UDim2.new(0.72, 0, 0, 3)
    bumper.BackgroundColor3 = Color3.fromRGB(30, 33, 38)
    bumper.BorderSizePixel = 0
    bumper.ZIndex = 11
    bumper.Parent = car

    -- Rear red marker on the opposite side.
    local tail = Instance.new("Frame")
    tail.AnchorPoint = Vector2.new(0.5, 0.5)
    tail.Position = lane.dir > 0 and UDim2.new(0, 4, 0.5, 0) or UDim2.new(1, -4, 0.5, 0)
    tail.Size = UDim2.fromOffset(4, 11)
    tail.BackgroundColor3 = Color3.fromRGB(219, 54, 48)
    tail.BorderSizePixel = 0
    tail.ZIndex = 12
    tail.Parent = car
    local tailCorner = Instance.new("UICorner")
    tailCorner.CornerRadius = UDim.new(1, 0)
    tailCorner.Parent = tail


    -- V10 vehicle depth: shadow, side trim, and icy reflection.
    local carShadow = Instance.new("Frame")
    carShadow.AnchorPoint = Vector2.new(0.5, 0)
    carShadow.Position = UDim2.new(0.5, 0, 1, 3)
    carShadow.Size = UDim2.new(0.82, 0, 0, 5)
    carShadow.BackgroundColor3 = Color3.fromRGB(5, 8, 12)
    carShadow.BackgroundTransparency = 0.55
    carShadow.BorderSizePixel = 0
    carShadow.ZIndex = 7
    carShadow.Parent = car
    local csc = Instance.new("UICorner")
    csc.CornerRadius = UDim.new(1,0)
    csc.Parent = carShadow

    local sideTrim = Instance.new("Frame")
    sideTrim.AnchorPoint = Vector2.new(0.5, 1)
    sideTrim.Position = UDim2.new(0.5, 0, 1, -4)
    sideTrim.Size = UDim2.new(0.58, 0, 0, 2)
    sideTrim.BackgroundColor3 = Color3.fromRGB(220, 228, 233)
    sideTrim.BackgroundTransparency = 0.52
    sideTrim.BorderSizePixel = 0
    sideTrim.ZIndex = 12
    sideTrim.Parent = car

    local iceReflection = Instance.new("Frame")
    iceReflection.AnchorPoint = Vector2.new(0.5, 0)
    iceReflection.Position = UDim2.new(0.5, 0, 1, 7)
    iceReflection.Size = UDim2.new(0.52, 0, 0, 3)
    iceReflection.BackgroundColor3 = car.BackgroundColor3
    iceReflection.BackgroundTransparency = 0.78
    iceReflection.BorderSizePixel = 0
    iceReflection.ZIndex = 6
    iceReflection.Parent = car

    table.insert(cars, {
        frame = car,
        row = row,
        speed = lane.speed,
        dir = lane.dir,
        spacing = lane.spacing,
        x = x,
        width = carW,
    })
end

local boardWidth = COLS * TILE

for row, lane in ipairs(laneData) do
    if lane.kind == "road" then
        local count = math.ceil(boardWidth / lane.spacing) + 2
        for i = 1, count do
            local x = lane.offset + (i - 1) * lane.spacing
            createCar(row, lane, i, x)
        end
    end
end

local col = math.ceil(COLS / 2)
local row = 1
local alive = true
local won = false
local hopping = false
local bufferedMove = nil
local connections = {}

local function cellCenter(c, r)
    local x = (c - 0.5) * TILE
    local y = (ROWS - r + 0.5) * TILE
    return x, y
end

local function setCharacterInstant()
    local x, y = cellCenter(col, row)
    character.Position = UDim2.fromOffset(x, y)
    character.Rotation = 0
    character.Size = UDim2.fromOffset(PLAYER_SIZE, PLAYER_SIZE)
end

local function reset()
    if hideResult then hideResult() end
    col = math.ceil(COLS / 2)
    row = 1
    alive = true
    won = false
    hopping = false
    bufferedMove = nil
    status.Text = ""
    statusSub.Text = ""
    character.Visible = true
    setCharacterInstant()
end

local function die()
    if not alive or won then return end
    playLocalSfx("impact", 0.90)
    alive = false
    hopping = false
    bufferedMove = nil

    character.Rotation = 90
    character.Size = UDim2.fromOffset(PLAYER_SIZE + 10, math.floor(PLAYER_SIZE * 0.38))

    flashScreen(Color3.fromRGB(210, 55, 55), 0.78)
    showResult("dead")
    status.Text = "ROADKILL"
    statusSub.Text = "PRESS R TO RETRY"
end

local function win()
    if won then return end
    playLocalSfx("win", 0.88)
    won = true
    alive = false
    hopping = false
    bufferedMove = nil
    flashScreen(Color3.fromRGB(240, 215, 130), 0.76)
    showResult("win")
    status.Text = "YOU MADE IT!"
    statusSub.Text = ""

    -- Final intro flow: lock Crossy after a win, show the placeholder key briefly,
    -- then fade the Crossy UI away and hand off to the Pennywise balloon.
    task.delay(4.15, function()
        if not gui or not gui.Parent then return end

        local fadeGroup = Instance.new("CanvasGroup")
        fadeGroup.Name = "SaintsCrossyExitFade"
        fadeGroup.Size = UDim2.fromScale(1, 1)
        fadeGroup.BackgroundTransparency = 1
        fadeGroup.GroupTransparency = 0
        fadeGroup.Parent = gui

        for _, child in ipairs(gui:GetChildren()) do
            if child ~= fadeGroup and child:IsA("GuiObject") then
                child.Parent = fadeGroup
            end
        end

        TweenService:Create(
            fadeGroup,
            TweenInfo.new(.62, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {GroupTransparency = 1}
        ):Play()

        task.delay(.68, function()
            if _G.SaintsCrossyRoadV1Cleanup then
                pcall(_G.SaintsCrossyRoadV1Cleanup)
            elseif gui and gui.Parent then
                pcall(function() gui:Destroy() end)
            end
            if type(onCrossyComplete) == "function" then
                task.defer(onCrossyComplete)
            end
        end)
    end)
end

local function hop(dc, dr)
    if not alive or won then return end

    -- Crossy-Road-style input buffer: if another direction is tapped
    -- during the current hop, remember the most recent tap and execute
    -- it immediately when the current hop finishes.
    if hopping then
        bufferedMove = {dc, dr}
        return
    end

    local newCol = math.clamp(col + dc, 1, COLS)
    local newRow = math.clamp(row + dr, 1, ROWS)

    if newCol == col and newRow == row then
        return
    end

    col = newCol
    row = newRow
    hopping = true
    playLocalSfx("hop", 0.62)

    local x, y = cellCenter(col, row)

    local up = TweenService:Create(
        character,
        TweenInfo.new(HOP_TIME * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {
            Position = UDim2.fromOffset(x, y - 6),
            Size = UDim2.fromOffset(PLAYER_SIZE - 2, PLAYER_SIZE + 4),
        }
    )

    local down = TweenService:Create(
        character,
        TweenInfo.new(HOP_TIME * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {
            Position = UDim2.fromOffset(x, y),
            Size = UDim2.fromOffset(PLAYER_SIZE, PLAYER_SIZE),
        }
    )

    up:Play()
    up.Completed:Once(function()
        if not character.Parent or not alive then return end
        down:Play()
        down.Completed:Once(function()
            if not character.Parent or not alive then return end

            hopping = false

            if row >= ROWS then
                bufferedMove = nil
                win()
                return
            end

            if bufferedMove then
                local move = bufferedMove
                bufferedMove = nil
                hop(move[1], move[2])
            end
        end)
    end)
end

local function overlaps(aPos, aSize, bPos, bSize)
    local ax1 = aPos.X - aSize.X / 2
    local ay1 = aPos.Y - aSize.Y / 2
    local ax2 = aPos.X + aSize.X / 2
    local ay2 = aPos.Y + aSize.Y / 2

    local bx1 = bPos.X - bSize.X / 2
    local by1 = bPos.Y - bSize.Y / 2
    local bx2 = bPos.X + bSize.X / 2
    local by2 = bPos.Y + bSize.Y / 2

    return ax1 < bx2 and ax2 > bx1 and ay1 < by2 and ay2 > by1
end

local inputConn = UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end

    local key = input.KeyCode

    if key == Enum.KeyCode.W or key == Enum.KeyCode.Up then
        hop(0, 1)
    elseif key == Enum.KeyCode.S or key == Enum.KeyCode.Down then
        hop(0, -1)
    elseif key == Enum.KeyCode.A or key == Enum.KeyCode.Left then
        hop(-1, 0)
    elseif key == Enum.KeyCode.D or key == Enum.KeyCode.Right then
        hop(1, 0)
    elseif key == Enum.KeyCode.R and (not alive) and (not won) then
        reset()
    end
end)
table.insert(connections, inputConn)




-- ===== PREMIUM ARCADE PRESENTATION =====
local hudPill = Instance.new("Frame")
hudPill.AnchorPoint = Vector2.new(0.5, 0)
hudPill.Position = UDim2.new(0.5, 0, 0, 10)
hudPill.Size = UDim2.fromOffset(255, 36)
hudPill.BackgroundColor3 = Color3.fromRGB(10, 18, 29)
hudPill.BackgroundTransparency = 0.12
hudPill.BorderSizePixel = 0
hudPill.ZIndex = 35
hudPill.Parent = backdrop
hudPill.Visible = false
local hpc = Instance.new("UICorner")
hpc.CornerRadius = UDim.new(1, 0)
hpc.Parent = hudPill
local hps = Instance.new("UIStroke")
hps.Thickness = 1
hps.Color = Color3.fromRGB(172, 208, 229)
hps.Transparency = 0.48
hps.Parent = hudPill

local hudText = Instance.new("TextLabel")
hudText.Size = UDim2.fromScale(1, 1)
hudText.BackgroundTransparency = 1
hudText.Font = Enum.Font.GothamBold
hudText.Text = ""
hudText.TextSize = 12
hudText.TextColor3 = Color3.fromRGB(231, 241, 247)
hudText.ZIndex = 36
hudText.Parent = hudPill
hudText.Visible = false

-- Soft road-edge neon depth strips.
for rowIndex, lane in ipairs(laneData) do
    if lane.kind == "road" then
        local y = (ROWS-rowIndex) * TILE
        for _, edgeY in ipairs({y + 1, y + TILE - 2}) do
            local strip = Instance.new("Frame")
            strip.Position = UDim2.fromOffset(0, edgeY)
            strip.Size = UDim2.new(1, 0, 0, 1)
            strip.BackgroundColor3 = Color3.fromRGB(138, 178, 204)
            strip.BackgroundTransparency = 0.58
            strip.BorderSizePixel = 0
            strip.ZIndex = 4
            strip.Parent = board
        end
    end
end

-- Snow sparkle layer around the board.
local sparkleRng = Random.new(2512)
local sparkles = {}
for i = 1, 18 do
    local sp = Instance.new("TextLabel")
    sp.BackgroundTransparency = 1
    sp.Text = ""
    sp.Font = Enum.Font.GothamBold
    sp.TextSize = sparkleRng:NextInteger(7, 13)
    sp.TextColor3 = Color3.fromRGB(221, 239, 249)
    sp.TextTransparency = sparkleRng:NextNumber(0.30, 0.72)
    sp.Size = UDim2.fromOffset(15, 15)
    sp.Position = UDim2.fromScale(sparkleRng:NextNumber(0.02,0.98), sparkleRng:NextNumber(0.05,0.95))
    sp.ZIndex = 2
    sp.Parent = backdrop
    sp.Visible = false
    sparkles[#sparkles+1] = {obj=sp, phase=sparkleRng:NextNumber(0,6.28)}
end

-- Bottom instruction glass pill.
local controlPill = Instance.new("Frame")
controlPill.AnchorPoint = Vector2.new(0.5, 1)
controlPill.Position = UDim2.new(0.5, 0, 1, -12)
controlPill.Size = UDim2.fromOffset(220, 31)
controlPill.BackgroundColor3 = Color3.fromRGB(9, 16, 25)
controlPill.BackgroundTransparency = 0.20
controlPill.BorderSizePixel = 0
controlPill.ZIndex = 34
controlPill.Parent = backdrop
controlPill.Visible = false
local cpc = Instance.new("UICorner")
cpc.CornerRadius = UDim.new(1, 0)
cpc.Parent = controlPill

local controlText = Instance.new("TextLabel")
controlText.Size = UDim2.fromScale(1,1)
controlText.BackgroundTransparency = 1
controlText.Font = Enum.Font.GothamMedium
controlText.Text = ""
controlText.TextSize = 10
controlText.TextColor3 = Color3.fromRGB(190, 209, 222)
controlText.ZIndex = 35
controlText.Parent = controlPill
controlText.Visible = false

-- ===== CINEMATIC CHRISTMAS AMBIENCE =====
local auroraLayer = Instance.new("Frame")
auroraLayer.Size = UDim2.fromScale(1, 1)
auroraLayer.BackgroundTransparency = 1
auroraLayer.ZIndex = 0
auroraLayer.Parent = backdrop

local aurora1 = Instance.new("Frame")
aurora1.AnchorPoint = Vector2.new(0.5, 0.5)
aurora1.Position = UDim2.new(0.22, 0, 0.28, 0)
aurora1.Size = UDim2.fromOffset(420, 76)
aurora1.BackgroundColor3 = Color3.fromRGB(75, 155, 137)
aurora1.BackgroundTransparency = 0.91
aurora1.BorderSizePixel = 0
aurora1.Rotation = -13
aurora1.ZIndex = 0
aurora1.Parent = auroraLayer
local a1c = Instance.new("UICorner")
a1c.CornerRadius = UDim.new(1, 0)
a1c.Parent = aurora1

local aurora2 = aurora1:Clone()
aurora2.Position = UDim2.new(0.78, 0, 0.36, 0)
aurora2.Size = UDim2.fromOffset(500, 62)
aurora2.BackgroundColor3 = Color3.fromRGB(88, 115, 181)
aurora2.Rotation = 11
aurora2.Parent = auroraLayer

local frostTop = Instance.new("Frame")
frostTop.Size = UDim2.new(1, 0, 0, 3)
frostTop.BackgroundColor3 = Color3.fromRGB(210, 231, 242)
frostTop.BackgroundTransparency = 0.28
frostTop.BorderSizePixel = 0
frostTop.ZIndex = 40
frostTop.Parent = backdrop

-- Decorative outer Christmas bulbs frame the playfield.
local outerBulbColors = {
    Color3.fromRGB(225, 67, 68),
    Color3.fromRGB(237, 192, 70),
    Color3.fromRGB(65, 166, 103),
    Color3.fromRGB(78, 137, 217),
}
for side = 0, 1 do
    for i = 1, 11 do
        local bulb = Instance.new("Frame")
        bulb.AnchorPoint = Vector2.new(0.5, 0.5)
        bulb.Position = UDim2.new(side, side == 0 and 18 or -18, i/12, 0)
        bulb.Size = UDim2.fromOffset(6, 6)
        bulb.BackgroundColor3 = outerBulbColors[((i + side*2 - 1) % #outerBulbColors)+1]
        bulb.BackgroundTransparency = 0.15
        bulb.BorderSizePixel = 0
        bulb.ZIndex = 30
        bulb.Parent = backdrop
        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(1, 0)
        bc.Parent = bulb
    end
end


-- ===== V10 CINEMATIC CHRISTMAS WORLD LAYER =====
-- Visual-only. No gameplay/collision values are modified.

local worldFX = Instance.new("Frame")
worldFX.Name = "WorldFX"
worldFX.Size = UDim2.fromScale(1, 1)
worldFX.BackgroundTransparency = 1
worldFX.ZIndex = 1
worldFX.Parent = backdrop
worldFX.Visible = false

-- Layered distant snowy hills.
for i = 1, 9 do
    local hill = Instance.new("Frame")
    hill.AnchorPoint = Vector2.new(0.5, 1)
    hill.Position = UDim2.new((i - 0.5)/9, 0, 1, 0)
    hill.Size = UDim2.fromOffset(150, 68 + (i % 3) * 18)
    hill.BackgroundColor3 = (i % 2 == 0)
        and Color3.fromRGB(19, 34, 51)
        or Color3.fromRGB(23, 40, 59)
    hill.BackgroundTransparency = 0.08
    hill.BorderSizePixel = 0
    hill.Rotation = 45
    hill.ZIndex = 1
    hill.Parent = worldFX
end

-- Warm cabin windows in the distant winter scene.
for i = 1, 8 do
    local cabin = Instance.new("Frame")
    cabin.AnchorPoint = Vector2.new(0.5, 1)
    cabin.Position = UDim2.new((i-0.5)/8, 0, 1, -18 - (i%2)*9)
    cabin.Size = UDim2.fromOffset(34, 23)
    cabin.BackgroundColor3 = Color3.fromRGB(36, 43, 51)
    cabin.BorderSizePixel = 0
    cabin.ZIndex = 2
    cabin.Parent = worldFX

    local cc = Instance.new("UICorner")
    cc.CornerRadius = UDim.new(0, 4)
    cc.Parent = cabin

    local roof = Instance.new("Frame")
    roof.AnchorPoint = Vector2.new(0.5, 0.5)
    roof.Position = UDim2.new(0.5, 0, 0, -3)
    roof.Size = UDim2.fromOffset(28, 28)
    roof.BackgroundColor3 = Color3.fromRGB(72, 49, 42)
    roof.BorderSizePixel = 0
    roof.Rotation = 45
    roof.ZIndex = 2
    roof.Parent = cabin

    local snowCap = Instance.new("Frame")
    snowCap.AnchorPoint = Vector2.new(0.5, 0)
    snowCap.Position = UDim2.new(0.5, 0, 0, -8)
    snowCap.Size = UDim2.fromOffset(30, 4)
    snowCap.BackgroundColor3 = Color3.fromRGB(235, 242, 246)
    snowCap.BorderSizePixel = 0
    snowCap.ZIndex = 4
    snowCap.Parent = cabin
    local scc = Instance.new("UICorner")
    scc.CornerRadius = UDim.new(1, 0)
    scc.Parent = snowCap

    for w = 1, 2 do
        local window = Instance.new("Frame")
        window.Position = UDim2.new(w == 1 and 0.18 or 0.62, 0, 0.38, 0)
        window.Size = UDim2.fromOffset(7, 8)
        window.BackgroundColor3 = Color3.fromRGB(255, 205, 105)
        window.BorderSizePixel = 0
        window.ZIndex = 4
        window.Parent = cabin
    end
end

-- Road reflections: translucent strips under each road lane.
local roadReflections = {}
for rowIndex, lane in ipairs(laneData) do
    if lane.kind == "road" then
        local y = (ROWS-rowIndex) * TILE
        local reflection = Instance.new("Frame")
        reflection.Position = UDim2.fromOffset(0, y + TILE - 8)
        reflection.Size = UDim2.new(1, 0, 0, 6)
        reflection.BackgroundColor3 = Color3.fromRGB(116, 153, 177)
        reflection.BackgroundTransparency = 0.86
        reflection.BorderSizePixel = 0
        reflection.ZIndex = 5
        reflection.Parent = board
        roadReflections[#roadReflections+1] = reflection
    end
end

-- Warm roadside light pools, built with frames instead of unsupported symbols.
local lightPools = {}
for _, data in ipairs({
    {0.10, 0.29}, {0.91, 0.46}, {0.11, 0.69}, {0.90, 0.83}
}) do
    local pool = Instance.new("Frame")
    pool.AnchorPoint = Vector2.new(0.5, 0.5)
    pool.Position = UDim2.fromScale(data[1], data[2])
    pool.Size = UDim2.fromOffset(96, 32)
    pool.BackgroundColor3 = Color3.fromRGB(255, 213, 124)
    pool.BackgroundTransparency = 0.90
    pool.BorderSizePixel = 0
    pool.ZIndex = 2
    pool.Parent = board
    local pc = Instance.new("UICorner")
    pc.CornerRadius = UDim.new(1, 0)
    pc.Parent = pool
    lightPools[#lightPools+1] = pool
end

-- Premium finish banner, pure ASCII.
local finishBanner = Instance.new("Frame")
finishBanner.AnchorPoint = Vector2.new(0.5, 0)
finishBanner.Position = UDim2.new(0.5, 0, 0, 9)
finishBanner.Size = UDim2.fromOffset(196, 34)
finishBanner.BackgroundColor3 = Color3.fromRGB(18, 72, 49)
finishBanner.BackgroundTransparency = 0.05
finishBanner.BorderSizePixel = 0
finishBanner.ZIndex = 12
finishBanner.Parent = board
local fbc = Instance.new("UICorner")
fbc.CornerRadius = UDim.new(0, 9)
fbc.Parent = finishBanner
local fbs = Instance.new("UIStroke")
fbs.Thickness = 2
fbs.Color = Color3.fromRGB(244, 214, 118)
fbs.Transparency = 0.05
fbs.Parent = finishBanner

local finishBannerText = Instance.new("TextLabel")
finishBannerText.Size = UDim2.fromScale(1, 1)
finishBannerText.BackgroundTransparency = 1
finishBannerText.Font = Enum.Font.GothamBlack
finishBannerText.Text = "FINISH"
finishBannerText.TextSize = 17
finishBannerText.TextColor3 = Color3.fromRGB(244, 247, 241)
finishBannerText.ZIndex = 13
finishBannerText.Parent = finishBanner

-- Premium finish treatment.
local finishInner = Instance.new("Frame")
finishInner.AnchorPoint = Vector2.new(0.5, 0.5)
finishInner.Position = UDim2.fromScale(0.5, 0.5)
finishInner.Size = UDim2.new(1, -10, 1, -10)
finishInner.BackgroundTransparency = 1
finishInner.BorderSizePixel = 0
finishInner.ZIndex = 12
finishInner.Parent = finishBanner
local finishInnerStroke = Instance.new("UIStroke")
finishInnerStroke.Thickness = 1
finishInnerStroke.Color = Color3.fromRGB(255, 239, 177)
finishInnerStroke.Transparency = 0.58
finishInnerStroke.Parent = finishInner
local fic = Instance.new("UICorner")
fic.CornerRadius = UDim.new(0, 6)
fic.Parent = finishInner

local finishShineClip = Instance.new("Frame")
finishShineClip.Size = UDim2.fromScale(1, 1)
finishShineClip.BackgroundTransparency = 1
finishShineClip.ClipsDescendants = true
finishShineClip.ZIndex = 14
finishShineClip.Parent = finishBanner
local fscc = Instance.new("UICorner")
fscc.CornerRadius = UDim.new(0, 9)
fscc.Parent = finishShineClip

local finishShine = Instance.new("Frame")
finishShine.AnchorPoint = Vector2.new(0.5, 0.5)
finishShine.Position = UDim2.new(-0.20, 0, 0.5, 0)
finishShine.Size = UDim2.fromOffset(32, 58)
finishShine.BackgroundColor3 = Color3.fromRGB(255, 245, 202)
finishShine.BackgroundTransparency = 0.72
finishShine.BorderSizePixel = 0
finishShine.Rotation = 18
finishShine.ZIndex = 14
finishShine.Parent = finishShineClip

local finishGlow = Instance.new("Frame")
finishGlow.AnchorPoint = Vector2.new(0.5, 0.5)
finishGlow.Position = UDim2.fromScale(0.5, 0.5)
finishGlow.Size = UDim2.fromOffset(216, 46)
finishGlow.BackgroundColor3 = Color3.fromRGB(68, 175, 111)
finishGlow.BackgroundTransparency = 0.88
finishGlow.BorderSizePixel = 0
finishGlow.ZIndex = 10
finishGlow.Parent = finishBanner
local fgc = Instance.new("UICorner")
fgc.CornerRadius = UDim.new(1, 0)
fgc.Parent = finishGlow

local finishTopLine = Instance.new("Frame")
finishTopLine.AnchorPoint = Vector2.new(0.5, 0)
finishTopLine.Position = UDim2.new(0.5, 0, 0, 3)
finishTopLine.Size = UDim2.new(0.64, 0, 0, 2)
finishTopLine.BackgroundColor3 = Color3.fromRGB(255, 225, 126)
finishTopLine.BackgroundTransparency = 0.08
finishTopLine.BorderSizePixel = 0
finishTopLine.ZIndex = 15
finishTopLine.Parent = finishBanner
local ftlc = Instance.new("UICorner")
ftlc.CornerRadius = UDim.new(1, 0)
ftlc.Parent = finishTopLine

-- Decorative garland on the finish banner.
for i = 1, 9 do
    local bulb = Instance.new("Frame")
    bulb.AnchorPoint = Vector2.new(0.5, 0.5)
    bulb.Position = UDim2.new(i/10, 0, 1, 2)
    bulb.Size = UDim2.fromOffset(5, 5)
    bulb.BackgroundColor3 = ({
        Color3.fromRGB(215, 58, 62),
        Color3.fromRGB(238, 191, 67),
        Color3.fromRGB(61, 157, 98),
        Color3.fromRGB(71, 129, 205)
    })[((i-1)%4)+1]
    bulb.BorderSizePixel = 0
    bulb.ZIndex = 14
    bulb.Parent = finishBanner
    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(1,0)
    bc.Parent = bulb
end

-- Chicken ground glow gives the player more visual presence.
local chickenGlow = Instance.new("Frame")
chickenGlow.AnchorPoint = Vector2.new(0.5, 0.5)
chickenGlow.Size = UDim2.fromOffset(42, 15)
chickenGlow.BackgroundColor3 = Color3.fromRGB(255, 221, 133)
chickenGlow.BackgroundTransparency = 0.84
chickenGlow.BorderSizePixel = 0
chickenGlow.ZIndex = 17
chickenGlow.Parent = board
local cgc = Instance.new("UICorner")
cgc.CornerRadius = UDim.new(1, 0)
cgc.Parent = chickenGlow

-- Extra snowbanks along safe-zone edges.
for rowIndex, lane in ipairs(laneData) do
    if lane.kind == "safe" then
        local y = (ROWS-rowIndex) * TILE
        for x = 24, COLS*TILE - 24, 92 do
            local bank = Instance.new("Frame")
            bank.AnchorPoint = Vector2.new(0.5, 0.5)
            bank.Position = UDim2.fromOffset(x, y + TILE - 5)
            bank.Size = UDim2.fromOffset(38 + ((x/92)%2)*8, 7)
            bank.BackgroundColor3 = Color3.fromRGB(245, 249, 251)
            bank.BackgroundTransparency = 0.08
            bank.BorderSizePixel = 0
            bank.ZIndex = 4
            bank.Parent = board
            local bc = Instance.new("UICorner")
            bc.CornerRadius = UDim.new(1, 0)
            bc.Parent = bank
        end
    end
end

-- Lightweight visual snowfall.
local snowRng = Random.new()
local snowflakes = {}
for i = 1, 30 do
    local flake = Instance.new("Frame")
    local size = snowRng:NextInteger(2, 4)
    flake.Size = UDim2.fromOffset(size, size)
    flake.AnchorPoint = Vector2.new(0.5, 0.5)
    flake.BackgroundColor3 = Color3.fromRGB(247, 250, 252)
    flake.BackgroundTransparency = snowRng:NextNumber(0.10, 0.42)
    flake.BorderSizePixel = 0
    flake.ZIndex = 100
    flake.Parent = backdrop
    local fc = Instance.new("UICorner")
    fc.CornerRadius = UDim.new(1, 0)
    fc.Parent = flake

    snowflakes[i] = {
        frame = flake,
        x = snowRng:NextNumber(0, 1),
        y = snowRng:NextNumber(0, 1),
        fall = snowRng:NextNumber(0.035, 0.075),
        drift = snowRng:NextNumber(-0.012, 0.012),
    }
end

local renderConn = RunService.RenderStepped:Connect(function(dt)
    dt = math.min(dt, 1/20)




    for _, sp in ipairs(sparkles) do
        sp.obj.TextTransparency = 0.42 + (math.sin(os.clock()*1.7 + sp.phase)+1)*0.20
    end

    -- Very slow aurora drift; presentation only.
    local now = os.clock()
    aurora1.Position = UDim2.new(0.22, math.sin(now * 0.22) * 18, 0.28, math.cos(now * 0.18) * 5)
    aurora2.Position = UDim2.new(0.78, math.cos(now * 0.19) * 22, 0.36, math.sin(now * 0.16) * 6)

    -- Keep the chicken's soft shadow beneath its actual animated position.
    if chickenShadow and character and character.Parent then
        chickenShadow.Position = UDim2.fromOffset(
            character.Position.X.Offset,
            character.Position.Y.Offset + PLAYER_SIZE/2 - 1
        )
        chickenShadow.Size = UDim2.fromOffset(
            math.max(18, character.AbsoluteSize.X * 0.78),
            8
        )
    end



    -- Premium finish animation.
    local finishT = os.clock()
    local sweep = ((finishT * 0.34) % 1.45) - 0.22
    finishShine.Position = UDim2.new(sweep, 0, 0.5, 0)
    finishGlow.BackgroundTransparency = 0.875 + math.sin(finishT * 2.0) * 0.025
    finishBanner.Size = UDim2.fromOffset(
        196 + math.sin(finishT * 1.7) * 2,
        34 + math.sin(finishT * 1.7) * 0.6
    )

    -- V10 cinematic animation, presentation only.
    local fxNow = os.clock()

    if chickenGlow and character and character.Parent then
        chickenGlow.Position = UDim2.fromOffset(
            character.Position.X.Offset,
            character.Position.Y.Offset + PLAYER_SIZE/2 + 2
        )
        chickenGlow.BackgroundTransparency = 0.82 + math.sin(fxNow * 4.2) * 0.025
    end

    for i, pool in ipairs(lightPools) do
        pool.BackgroundTransparency = 0.885 + math.sin(fxNow * 1.3 + i) * 0.025
    end

    for i, reflection in ipairs(roadReflections) do
        reflection.BackgroundTransparency = 0.84 + math.sin(fxNow * 0.75 + i * 0.7) * 0.025
    end

    -- Decorative snow update only.
    for _, flake in ipairs(snowflakes) do
        flake.y += flake.fall * dt
        flake.x += flake.drift * dt

        if flake.y > 1.03 then
            flake.y = -0.03
            flake.x = snowRng:NextNumber(0, 1)
        end
        if flake.x < -0.02 then flake.x = 1.02 end
        if flake.x > 1.02 then flake.x = -0.02 end

        flake.frame.Position = UDim2.fromScale(flake.x, flake.y)
    end

    -- Move/wrap cars.
    for _, car in ipairs(cars) do
        car.x += car.speed * car.dir * dt

        local margin = car.width + 30
        if car.dir > 0 and car.x > boardWidth + margin then
            car.x = -margin
        elseif car.dir < 0 and car.x < -margin then
            car.x = boardWidth + margin
        end

        local y = (ROWS - car.row + 0.5) * TILE
        car.frame.Position = UDim2.fromOffset(car.x, y)
    end

    -- Collision uses the player's actual animated GUI position.
    if alive and not won then
        local p = character.AbsolutePosition
        local ps = character.AbsoluteSize
        local playerCenter = Vector2.new(p.X + ps.X/2, p.Y + ps.Y/2)
        local playerSize = Vector2.new(ps.X * 0.72, ps.Y * 0.72)

        for _, car in ipairs(cars) do
            if car.row == row then
                local cp = car.frame.AbsolutePosition
                local cs = car.frame.AbsoluteSize
                local carCenter = Vector2.new(cp.X + cs.X/2, cp.Y + cs.Y/2)
                local carSize = Vector2.new(cs.X * 0.92, cs.Y * 0.82)

                if overlaps(playerCenter, playerSize, carCenter, carSize) then
                    die()
                    break
                end
            end
        end
    end
end)
table.insert(connections, renderConn)

-- Wait one rendered frame so AbsolutePosition/AbsoluteSize and the board
-- layout are valid before placing the starting character.
RunService.RenderStepped:Wait()
reset()
RunService.RenderStepped:Wait()
setCharacterInstant()
character.Visible = true

_G.SaintsCrossyRoadV1Cleanup = function()
    for _, conn in ipairs(connections) do
        pcall(function()
            conn:Disconnect()
        end)
    end

    if gui and gui.Parent then
        gui:Destroy()
    end

    -- Crossy is now over; the next stage is the Pennywise balloon.
    releaseActualCharacterAfterCrossy()
    _G.SaintsCrossyRoadV1Cleanup = nil
end

end

local function startBalloon(onBalloonComplete)
-- Saint's Hub - Pennywise Balloon Transition Test V2
-- Custom Roblox image balloon + local MP3 pop/laugh.
-- No visible instructions. Live gameplay remains visible.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

if _G.SaintsBalloonTransitionCleanup then pcall(_G.SaintsBalloonTransitionCleanup) end

local alive, settled, popped = true, false, false
local connections, tempAudio = {}, {}

local BALLOON_IMAGE = "rbxassetid://96307777033937"
local LAUGH_FILE = "IT Pennywise laugh + reverb sound effect.mp3"
local POP_FILE = "universfield-balloon-burst-383750.mp3"

-- Put both MP3 files in the same executor workspace/folder where Volt can read them.
-- These are deliberately executor-local paths, NOT ChatGPT's /mnt/data paths.
local AUDIO_SEARCH_PATHS = {
    "",
    "workspace/",
    "Workspace/",
    "scripts/",
    "Scripts/",
}

-- Volt-friendly local audio loader.
-- Do NOT gate custom-asset resolution behind isfile(): Volt can resolve files
-- from its workspace even when isfile() reports them inconsistently.
local function getBalloonAudioResolvers()
    local out = {}
    for _, resolver in ipairs({getcustomasset, getsynasset, getasset}) do
        if type(resolver) == "function" then
            out[#out + 1] = resolver
        end
    end
    return out
end

local function resolveLocalAsset(fileName)
    local resolvers = getBalloonAudioResolvers()
    if #resolvers == 0 then
        warn("[Saints Balloon] Volt custom-asset resolver unavailable")
        return nil
    end

    -- Same direct-resolution strategy already used by the working Crossy SFX.
    for _, prefix in ipairs(AUDIO_SEARCH_PATHS) do
        local candidate = prefix .. fileName
        for _, resolver in ipairs(resolvers) do
            local ok, result = pcall(resolver, candidate)
            if ok and type(result) == "string" and result ~= "" then
                return result, candidate
            end
        end
    end

    -- Extra Volt fallback: ask workspace for the exact path it sees, then feed
    -- that returned path directly to the resolver. This also tolerates case.
    if type(listfiles) == "function" then
        local wanted = fileName:lower()
        for _, folder in ipairs({"", "workspace"}) do
            local ok, files = pcall(listfiles, folder)
            if ok and type(files) == "table" then
                for _, p in ipairs(files) do
                    local normalized = tostring(p):gsub("\\", "/")
                    local base = normalized:match("([^/]+)$") or normalized
                    if base:lower() == wanted then
                        for _, resolver in ipairs(resolvers) do
                            local rok, result = pcall(resolver, p)
                            if rok and type(result) == "string" and result ~= "" then
                                return result, p
                            end
                        end
                    end
                end
            end
        end
    end

    warn("[Saints Balloon] Volt could not resolve local MP3: " .. fileName)
    return nil
end

local function playLocal(fileName, volume)
    local asset, resolvedPath = resolveLocalAsset(fileName)
    if not asset then return nil end

    local s = Instance.new("Sound")
    s.Name = "SaintsLocalAudio"
    s.SoundId = asset
    s.Volume = volume or 1
    s.Parent = game:GetService("SoundService")
    tempAudio[#tempAudio+1] = s

    s:Play()

    task.delay(1.5, function()
        if s and s.Parent and not s.IsPlaying then
            warn("[Saints Balloon] Resolved but playback stayed silent: " .. tostring(resolvedPath) .. " | SoundId=" .. tostring(asset))
        end
    end)

    s.Ended:Connect(function()
        pcall(function() s:Destroy() end)
    end)

    task.delay(10, function()
        if s and s.Parent then
            pcall(function() s:Destroy() end)
        end
    end)

    return s
end

local gui = Instance.new("ScreenGui")
gui.Name = "SaintsPennywiseBalloonTransitionV2"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 999999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local dim = Instance.new("Frame")
dim.Size = UDim2.fromScale(1,1)
dim.BackgroundColor3 = Color3.fromRGB(7,8,12)
dim.BackgroundTransparency = 1
dim.BorderSizePixel = 0
dim.ZIndex = 1
dim.Parent = gui

local root = Instance.new("Frame")
root.AnchorPoint = Vector2.new(.5,.5)
root.Position = UDim2.new(.5,0,0,-220)
root.Size = UDim2.fromOffset(230,390)
root.BackgroundTransparency = 1
root.ZIndex = 10
root.Parent = gui

-- Actual uploaded custom balloon image.
local balloon = Instance.new("ImageButton")
balloon.Name = "PennywiseBalloon"
balloon.AnchorPoint = Vector2.new(.5,.5)
balloon.Position = UDim2.new(.5,0,.46,0)
balloon.Size = UDim2.fromOffset(210,350)
balloon.BackgroundTransparency = 1
balloon.Image = BALLOON_IMAGE
balloon.ScaleType = Enum.ScaleType.Fit
balloon.AutoButtonColor = false
balloon.ZIndex = 12
balloon.Parent = root

-- Invisible enlarged hit area, so the user doesn't have to pixel-perfect the PNG.
local hit = Instance.new("TextButton")
hit.AnchorPoint = Vector2.new(.5,.5)
hit.Position = UDim2.new(.5,0,.38,0)
hit.Size = UDim2.fromOffset(190,245)
hit.BackgroundTransparency = 1
hit.Text = ""
hit.AutoButtonColor = false
hit.ZIndex = 20
hit.Parent = root

-- Clean balloon presentation: no aura/halo behind the balloon.
local aura = Instance.new("Frame")
aura.AnchorPoint = Vector2.new(.5,.5)
aura.Position = UDim2.new(.5,0,.36,0)
aura.Size = UDim2.fromOffset(185,210)
aura.BackgroundColor3 = Color3.fromRGB(130,0,8)
aura.BackgroundTransparency = 1
aura.BorderSizePixel = 0
aura.ZIndex = 9
aura.Parent = root
local ac = Instance.new("UICorner")
ac.CornerRadius = UDim.new(1,0)
ac.Parent = aura

local function burstParticle(angle, dist, size)
    local p = Instance.new("Frame")
    p.AnchorPoint = Vector2.new(.5,.5)
    p.Position = UDim2.new(.5,0,.33,0)
    p.Size = UDim2.fromOffset(size,size)
    p.BackgroundColor3 = Color3.fromRGB(math.random(175,235), math.random(7,25), math.random(10,30))
    p.BorderSizePixel = 0
    p.Rotation = math.random(0,180)
    p.ZIndex = 30
    p.Parent = root
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(1,0); c.Parent=p
    TweenService:Create(p,TweenInfo.new(.28,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{
        Position=UDim2.new(.5,math.cos(angle)*dist,.33,math.sin(angle)*dist),
        Size=UDim2.fromOffset(1,1),
        BackgroundTransparency=1
    }):Play()
    task.delay(.32,function() pcall(function() p:Destroy() end) end)
end

-- Keep live gameplay completely unobstructed behind the balloon.
dim.BackgroundTransparency = 1

TweenService:Create(root,TweenInfo.new(1.7,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{
    Position=UDim2.new(.5,0,.5,0)
}):Play()

task.delay(1.55,function()
    if alive and not popped then settled=true end
end)

connections[#connections+1]=RunService.RenderStepped:Connect(function()
    if not alive or not settled or popped then return end
    local t=os.clock()
    root.Position=UDim2.new(.5,math.sin(t*.72)*7,.5,math.sin(t*1.45)*8)
    root.Rotation=math.sin(t*.78)*1.8
    aura.BackgroundTransparency=1
end)

local function popBalloon()
    if popped or not settled then return end
    popped=true
    hit.Active=false
    balloon.Active=false

    -- Pop happens first.
    playLocal(POP_FILE, 1.25)

    for i=1,24 do
        burstParticle((math.pi*2)*(i/24)+math.random()*.10,math.random(65,145),math.random(4,10))
    end

    TweenService:Create(balloon,TweenInfo.new(.07,Enum.EasingStyle.Back,Enum.EasingDirection.In),{
        Size=UDim2.fromOffset(235,390),
        ImageTransparency=1
    }):Play()
    TweenService:Create(aura,TweenInfo.new(.10),{BackgroundTransparency=1}):Play()

    -- Let the sharp balloon burst land, then Pennywise laughs.
    task.delay(.12,function()
        if alive then playLocal(LAUGH_FILE,1.20) end
    end)

    -- Return to unobstructed live gameplay while laugh continues.
    task.delay(.42,function()
        if alive then
            TweenService:Create(dim,TweenInfo.new(.5,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{
                BackgroundTransparency=1
            }):Play()
        end
    end)

    -- Continue into Christmas authentication while the Pennywise laugh tails out.
    -- Let Pennywise's laugh finish completely before opening authentication.
    -- playLocal() returns the Sound object, so wait for its Ended event instead
    -- of destroying it on a fixed timer.
    task.delay(.12,function()
        if not alive then return end

        local laughSound = nil
        -- The laugh was started above at the same .12-second mark. Find the
        -- active local audio instance associated with that playback.
        for i = #tempAudio, 1, -1 do
            local s = tempAudio[i]
            if s and s.Parent and s:IsA("Sound") and s.IsPlaying then
                laughSound = s
                break
            end
        end

        local advanced = false
        local function advanceToAuth()
            if advanced or not alive then return end
            advanced = true
            if _G.SaintsBalloonTransitionCleanup then
                pcall(_G.SaintsBalloonTransitionCleanup)
            end
            if type(onBalloonComplete) == "function" then
                task.defer(onBalloonComplete)
            end
        end

        if laughSound then
            local endedConn
            endedConn = laughSound.Ended:Connect(function()
                if endedConn then endedConn:Disconnect() end
                -- Tiny cinematic breathing room after the final laugh tail.
                task.delay(.18, advanceToAuth)
            end)

            -- Safety fallback only; normal path is Sound.Ended.
            task.delay(math.max((laughSound.TimeLength or 0) + 1.5, 8), function()
                if endedConn then pcall(function() endedConn:Disconnect() end) end
                advanceToAuth()
            end)
        else
            -- If Volt reports playback late, give the laugh enough time rather
            -- than cutting it off like the previous fixed 1.05-second handoff.
            task.delay(6.5, advanceToAuth)
        end
    end)
end

connections[#connections+1]=hit.MouseButton1Click:Connect(popBalloon)
connections[#connections+1]=balloon.MouseButton1Click:Connect(popBalloon)

_G.SaintsBalloonTransitionCleanup=function()
    alive=false
    for _,c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    for _,s in ipairs(tempAudio) do pcall(function() s:Destroy() end) end
    pcall(function() gui:Destroy() end)
    _G.SaintsBalloonTransitionCleanup=nil
end

end

local function startChristmasAuth(onAuthComplete)
-- Saint's Hub - Christmas Authentication Preview V2
-- Full-image auth window. No gold styling. Standalone visual preview.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local authMusic = nil
local AUTH_MUSIC_FILE = "evil_christmas_dropbox_ready.mp3"

local function resolveAuthMusic(fileName)
    local paths = {"", "workspace/", "Workspace/", "scripts/", "Scripts/"}
    local resolvers = {getcustomasset, getsynasset, getasset}
    for _, prefix in ipairs(paths) do
        local candidate = prefix .. fileName
        local exists = true
        if type(isfile) == "function" then
            local ok, result = pcall(isfile, candidate)
            exists = ok and result == true
        end
        if exists then
            for _, resolver in ipairs(resolvers) do
                if type(resolver) == "function" then
                    local ok, asset = pcall(resolver, candidate)
                    if ok and type(asset) == "string" and asset ~= "" then return asset end
                end
            end
        end
    end
end

local function startAuthMusic()
    local asset = resolveAuthMusic(AUTH_MUSIC_FILE)
    if not asset then warn("[Saints Christmas Auth] Could not resolve "..AUTH_MUSIC_FILE); return end
    authMusic = Instance.new("Sound")
    authMusic.Name = "SaintsEvilChristmas"
    authMusic.SoundId = asset
    authMusic.Volume = .50
    authMusic.Looped = true
    authMusic.Parent = game:GetService("SoundService")
    authMusic:Play()
end

local function fadeAuthMusicOut(done)
    if not authMusic or not authMusic.Parent then if done then done() end; return end
    TweenService:Create(authMusic,TweenInfo.new(.65,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Volume=0}):Play()
    task.delay(.68,function()
        pcall(function() authMusic:Stop(); authMusic:Destroy() end)
        authMusic=nil
        if done then done() end
    end)
end


if _G.SaintsChristmasAuthCleanup then pcall(_G.SaintsChristmasAuthCleanup) end

local alive = true
local conns = {}

local gui = Instance.new("ScreenGui")
gui.Name = "SaintsChristmasAuthPreviewV2"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 999998
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

-- Live gameplay stays visible around the floating auth.
local dim = Instance.new("Frame")
dim.Size = UDim2.fromScale(1,1)
dim.BackgroundColor3 = Color3.fromRGB(3,4,6)
dim.BackgroundTransparency = 1
dim.BorderSizePixel = 0
dim.ZIndex = 1
dim.Parent = gui
dim.BackgroundTransparency = 1

local shell = Instance.new("Frame")
shell.AnchorPoint = Vector2.new(.5,.5)
shell.Position = UDim2.fromScale(.5,.51)
shell.Size = UDim2.fromOffset(860,520)
shell.BackgroundColor3 = Color3.fromRGB(5,5,7)
shell.BackgroundTransparency = 1
shell.BorderSizePixel = 0
shell.ClipsDescendants = true
shell.ZIndex = 10
shell.ClipsDescendants = false
shell.Parent = gui
local corner=Instance.new("UICorner"); corner.CornerRadius=UDim.new(0,16); corner.Parent=shell

-- Neutral dark border, deliberately no gold.
local stroke=Instance.new("UIStroke")
stroke.Color=Color3.fromRGB(92,92,98)
stroke.Thickness=1.25
stroke.Transparency=1
stroke.Parent=shell

-- Correct Christmas Pennywise image covers the WHOLE window.
local image=Instance.new("ImageLabel")
image.Size=UDim2.fromScale(1,1)
image.BackgroundColor3=Color3.fromRGB(5,5,7)
image.BorderSizePixel=0
image.Image="rbxassetid://83802363529146"
image.ScaleType=Enum.ScaleType.Crop
image.ImageTransparency=1
image.ZIndex=10
image.Parent=shell

-- Cinematic readability wash. Image is still visible across entire panel.
local wash=Instance.new("Frame")
wash.Size=UDim2.fromScale(1,1)
wash.BackgroundColor3=Color3.fromRGB(4,4,6)
wash.BackgroundTransparency=.68
wash.BorderSizePixel=0
wash.ZIndex=11
wash.Parent=shell

-- Darker lower fade behind controls.
local lower=Instance.new("Frame")
lower.AnchorPoint=Vector2.new(.5,1)
lower.Position=UDim2.fromScale(.5,1)
lower.Size=UDim2.fromScale(1,.52)
lower.BackgroundColor3=Color3.fromRGB(4,4,6)
lower.BackgroundTransparency=.18
lower.BorderSizePixel=0
lower.ZIndex=12
lower.Parent=shell
local lowerGrad=Instance.new("UIGradient")
lowerGrad.Rotation=90
lowerGrad.Transparency=NumberSequence.new({
    NumberSequenceKeypoint.new(0,1),
    NumberSequenceKeypoint.new(.35,.58),
    NumberSequenceKeypoint.new(1,.05)
})
lowerGrad.Parent=lower

-- Thin blood-red top accent.
local topAccent=Instance.new("Frame")
-- Overlay the auth shell's top stroke exactly instead of sitting beneath it.
topAccent.AnchorPoint=Vector2.new(0.5,0)
-- Extend 2px past each side and cover the complete anti-aliased gray top stroke.
topAccent.Position=UDim2.new(0.5,0,0,-2)
-- Exact shell width: retains the 4px vertical mask without protruding at either end.
topAccent.Size=UDim2.new(1,0,0,4)
topAccent.BackgroundColor3=Color3.fromRGB(151,15,23)
topAccent.BorderSizePixel=0
topAccent.BackgroundTransparency=.15
topAccent.ZIndex=20
topAccent.Parent=shell

-- Saint's Hub is treated like a cinematic title stamped over the artwork.
local brand=Instance.new("TextLabel")
brand.Position=UDim2.fromOffset(35,28)
brand.Size=UDim2.fromOffset(420,58)
brand.BackgroundTransparency=1
brand.Text="SAINT'S HUB"
brand.TextXAlignment=Enum.TextXAlignment.Left
brand.TextColor3=Color3.fromRGB(242,240,236)
brand.TextSize=37
brand.Font=Enum.Font.GothamBold
brand.TextTransparency=1
brand.ZIndex=20
brand.Parent=shell

local brandShadow=brand:Clone()
brandShadow.Position=UDim2.fromOffset(37,30)
brandShadow.TextColor3=Color3.new(0,0,0)
brandShadow.TextTransparency=1
brandShadow.ZIndex=19
brandShadow.Parent=shell

local season=Instance.new("TextLabel")
season.Position=UDim2.fromOffset(39,82)
season.Size=UDim2.fromOffset(300,22)
season.BackgroundTransparency=1
season.Text="CHRISTMAS EDITION"
season.TextXAlignment=Enum.TextXAlignment.Left
season.TextColor3=Color3.fromRGB(184,184,184)
season.TextSize=10
season.Font=Enum.Font.GothamMedium
season.TextTransparency=1
season.ZIndex=20
season.Parent=shell

local redRule=Instance.new("Frame")
redRule.Position=UDim2.fromOffset(38,111)
redRule.Size=UDim2.fromOffset(74,2)
redRule.BackgroundColor3=Color3.fromRGB(164,17,25)
redRule.BackgroundTransparency=.08
redRule.BorderSizePixel=0
redRule.ZIndex=20
redRule.Parent=shell

-- Compact floating auth controls at the bottom-right.
local auth=Instance.new("Frame")
auth.AnchorPoint=Vector2.new(1,1)
auth.Position=UDim2.new(1,-35,1,-34)
auth.Size=UDim2.fromOffset(390,192)
auth.BackgroundColor3=Color3.fromRGB(5,5,7)
auth.BackgroundTransparency=.24
auth.BorderSizePixel=0
auth.ZIndex=20
auth.Parent=shell
local ac=Instance.new("UICorner"); ac.CornerRadius=UDim.new(0,12); ac.Parent=auth
local ast=Instance.new("UIStroke")
ast.Color=Color3.fromRGB(76,76,82)
ast.Thickness=1
ast.Transparency=.32
ast.Parent=auth

local authTitle=Instance.new("TextLabel")
authTitle.Position=UDim2.fromOffset(20,16)
authTitle.Size=UDim2.new(1,-40,0,30)
authTitle.BackgroundTransparency=1
authTitle.Text="AUTHENTICATION"
authTitle.TextXAlignment=Enum.TextXAlignment.Left
authTitle.TextColor3=Color3.fromRGB(239,237,232)
authTitle.TextSize=20
authTitle.Font=Enum.Font.GothamBold
authTitle.ZIndex=21
authTitle.Parent=auth

local box=Instance.new("TextBox")
box.Position=UDim2.fromOffset(20,57)
box.Size=UDim2.new(1,-40,0,48)
box.BackgroundColor3=Color3.fromRGB(4,4,6)
box.BackgroundTransparency=.08
box.BorderSizePixel=0
box.Text=""
box.PlaceholderText="ENTER ACCESS KEY"
box.PlaceholderColor3=Color3.fromRGB(117,117,122)
box.TextColor3=Color3.fromRGB(242,242,240)
box.TextSize=13
box.Font=Enum.Font.GothamMedium
box.ClearTextOnFocus=false
box.ZIndex=22
box.Parent=auth
local bc=Instance.new("UICorner"); bc.CornerRadius=UDim.new(0,7); bc.Parent=box
local bst=Instance.new("UIStroke")
bst.Color=Color3.fromRGB(75,75,80)
bst.Transparency=.25
bst.Parent=box

local button=Instance.new("TextButton")
button.Position=UDim2.fromOffset(20,119)
button.Size=UDim2.new(1,-40,0,52)
button.BackgroundColor3=Color3.fromRGB(119,13,20)
button.BorderSizePixel=0
button.Text="AUTHENTICATE"
button.TextColor3=Color3.fromRGB(248,245,240)
button.TextSize=18
button.Font=Enum.Font.GothamBold
button.AutoButtonColor=false
button.ZIndex=22
button.Parent=auth
local btnc=Instance.new("UICorner"); btnc.CornerRadius=UDim.new(0,7); btnc.Parent=button
local btns=Instance.new("UIStroke")
btns.Color=Color3.fromRGB(183,38,45)
btns.Thickness=1
btns.Transparency=.20
btns.Parent=button

-- Tiny corner signature gives Saint's Hub another subtle branded detail.
local signature=Instance.new("TextLabel")
signature.AnchorPoint=Vector2.new(0,1)
signature.Position=UDim2.new(0,37,1,-34)
signature.Size=UDim2.fromOffset(230,24)
signature.BackgroundTransparency=1
signature.Text="SAINT'S HUB  /  PRIVATE ACCESS"
signature.TextXAlignment=Enum.TextXAlignment.Left
signature.TextColor3=Color3.fromRGB(156,156,160)
signature.TextSize=9
signature.Font=Enum.Font.GothamMedium
signature.TextTransparency=.18
signature.ZIndex=20
signature.Parent=shell


-- V3 layout override: preserve the artwork and keep gameplay outside completely untouched.
auth.Visible = false
signature.Visible = false

-- Bottom authentication strip.
local authStrip = Instance.new("Frame")
authStrip.AnchorPoint = Vector2.new(.5,1)
authStrip.Position = UDim2.new(.5,0,1,-25)
authStrip.Size = UDim2.new(1,-70,0,94)
authStrip.BackgroundColor3 = Color3.fromRGB(4,4,6)
authStrip.BackgroundTransparency = .18
authStrip.BorderSizePixel = 0
authStrip.ZIndex = 30
authStrip.Parent = shell
local stripCorner=Instance.new("UICorner")
stripCorner.CornerRadius=UDim.new(0,10)
stripCorner.Parent=authStrip
local stripStroke=Instance.new("UIStroke")
stripStroke.Color=Color3.fromRGB(72,72,78)
stripStroke.Thickness=1
stripStroke.Transparency=.32
stripStroke.Parent=authStrip

local stripTitle=Instance.new("TextLabel")
stripTitle.Position=UDim2.fromOffset(18,9)
stripTitle.Size=UDim2.fromOffset(170,20)
stripTitle.BackgroundTransparency=1
stripTitle.Text="AUTHENTICATION"
stripTitle.TextXAlignment=Enum.TextXAlignment.Left
stripTitle.TextColor3=Color3.fromRGB(238,236,232)
stripTitle.TextSize=14
stripTitle.Font=Enum.Font.GothamBold
stripTitle.ZIndex=31
stripTitle.Parent=authStrip

local newBox=Instance.new("TextBox")
newBox.Position=UDim2.fromOffset(18,36)
newBox.Size=UDim2.new(.58,-25,0,42)
newBox.BackgroundColor3=Color3.fromRGB(3,3,5)
newBox.BackgroundTransparency=.05
newBox.BorderSizePixel=0
newBox.Text=""
newBox.PlaceholderText="ENTER 3-DIGIT ACCESS KEY"
newBox.PlaceholderColor3=Color3.fromRGB(113,113,118)
newBox.TextColor3=Color3.fromRGB(244,243,240)
newBox.TextSize=22
newBox.Font=Enum.Font.GothamMedium
newBox.ClearTextOnFocus=false
newBox.ZIndex=31
newBox.Parent=authStrip
local nbc=Instance.new("UICorner"); nbc.CornerRadius=UDim.new(0,6); nbc.Parent=newBox
local nbs=Instance.new("UIStroke"); nbs.Color=Color3.fromRGB(73,73,79); nbs.Transparency=.25; nbs.Parent=newBox

local newButton=Instance.new("TextButton")
newButton.AnchorPoint=Vector2.new(1,0)
newButton.Position=UDim2.new(1,-18,0,36)
newButton.Size=UDim2.new(.40,-8,0,42)
newButton.BackgroundColor3=Color3.fromRGB(119,13,20)
newButton.BorderSizePixel=0
newButton.Text="AUTHENTICATE"
newButton.TextColor3=Color3.fromRGB(248,246,242)
newButton.TextSize=16
newButton.Font=Enum.Font.GothamBold
newButton.AutoButtonColor=false
newButton.ZIndex=31
newButton.Parent=authStrip
local nbtc=Instance.new("UICorner"); nbtc.CornerRadius=UDim.new(0,6); nbtc.Parent=newButton
local nbts=Instance.new("UIStroke"); nbts.Color=Color3.fromRGB(184,37,44); nbts.Transparency=.18; nbts.Parent=newButton

-- Snowfall layer across the entire auth artwork, clipped by the main shell.
local snowLayer=Instance.new("Frame")
snowLayer.Size=UDim2.fromScale(1,1)
snowLayer.BackgroundTransparency=1
snowLayer.ZIndex=26
snowLayer.Parent=shell

local snowflakes={}
local rng=Random.new()

local function resetFlake(f, initial)
    local size=rng:NextInteger(2,5)
    f.Size=UDim2.fromOffset(size,size)
    f.Position=UDim2.new(rng:NextNumber(),0,initial and rng:NextNumber(-.05,1) or -.04,rng:NextInteger(-10,0))
    f.BackgroundTransparency=rng:NextNumber(.12,.55)
    f:SetAttribute("Speed",rng:NextNumber(.060,.135))
    -- Match the artwork: steady wind carries snow diagonally down-left.
    f:SetAttribute("Drift",rng:NextNumber(-.105,-.055))
    f:SetAttribute("Gust",rng:NextNumber(.006,.018))
    f:SetAttribute("Phase",rng:NextNumber(0,math.pi*2))
end

for i=1,72 do
    local f=Instance.new("Frame")
    f.BackgroundColor3=Color3.fromRGB(248,248,248)
    f.BorderSizePixel=0
    f.ZIndex=26
    f.Parent=snowLayer
    local fc=Instance.new("UICorner")
    fc.CornerRadius=UDim.new(1,0)
    fc.Parent=f
    resetFlake(f,true)
    snowflakes[#snowflakes+1]=f
end

local snowStart=os.clock()
conns[#conns+1]=game:GetService("RunService").RenderStepped:Connect(function(dt)
    if not alive then return end
    local t=os.clock()-snowStart
    for _,f in ipairs(snowflakes) do
        local p=f.Position
        local speed=f:GetAttribute("Speed") or .08
        local drift=f:GetAttribute("Drift") or -.075
        local gust=f:GetAttribute("Gust") or .01
        local phase=f:GetAttribute("Phase") or 0
        local wind = drift + math.sin(t*1.25+phase)*gust
        local nx=p.X.Scale + wind*dt
        local ny=p.Y.Scale + speed*dt
        if ny>1.04 or nx<-.04 then
            resetFlake(f,false)
            -- Wind-blown flakes can also enter from the upper-right edge.
            if rng:NextNumber() < .42 then
                f.Position=UDim2.new(rng:NextNumber(.82,1.04),0,rng:NextNumber(-.02,.42),0)
            end
        else
            f.Position=UDim2.new(nx,0,ny,p.Y.Offset)
        end
    end
end)

conns[#conns+1]=newButton.MouseEnter:Connect(function()
    TweenService:Create(newButton,TweenInfo.new(.14),{BackgroundColor3=Color3.fromRGB(153,17,25)}):Play()
    TweenService:Create(nbts,TweenInfo.new(.14),{Transparency=0}):Play()
end)
conns[#conns+1]=newButton.MouseLeave:Connect(function()
    TweenService:Create(newButton,TweenInfo.new(.14),{BackgroundColor3=Color3.fromRGB(119,13,20)}):Play()
    TweenService:Create(nbts,TweenInfo.new(.14),{Transparency=.18}):Play()
end)
local authAdvancing=false
local __saintsFilteringKey=false
conns[#conns+1]=newBox:GetPropertyChangedSignal("Text"):Connect(function()
    if __saintsFilteringKey then return end
    local digits=tostring(newBox.Text or ""):gsub("%D",""):sub(1,3)
    if digits~=newBox.Text then
        __saintsFilteringKey=true
        newBox.Text=digits
        newBox.CursorPosition=#digits+1
        __saintsFilteringKey=false
    end
end)
conns[#conns+1]=newButton.MouseButton1Click:Connect(function()
    if authAdvancing then return end
    local entered=tostring(newBox.Text or "")
    if not SESSION_ACCESS_LOOKUP[entered] then
        newButton.Text="INVALID KEY"
        task.delay(.75,function()
            if alive and not authAdvancing then newButton.Text="AUTHENTICATE" end
        end)
        return
    end
    authAdvancing=true
    newButton.Text="ACCESS GRANTED"
    newButton.Active=false
    newBox.Text=""
    newBox.PlaceholderText=""
    TweenService:Create(newButton,TweenInfo.new(.12),{BackgroundColor3=Color3.fromRGB(92,18,24)}):Play()

    -- Let ACCESS GRANTED register briefly, then bring the Hub + Phone in
    -- underneath the auth while the complete auth panel fades as one unit.
    task.delay(.16,function()
        if not alive then return end
        if type(onAuthComplete)=="function" then task.defer(onAuthComplete) end
        fadeAuthMusicOut()

        -- Native object fades keep the artwork/text crisp before the transition.
        local fadeInfo=TweenInfo.new(.58,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
        for _,obj in ipairs(gui:GetDescendants()) do
            if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
                TweenService:Create(obj,fadeInfo,{ImageTransparency=1,BackgroundTransparency=1}):Play()
            elseif obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                TweenService:Create(obj,fadeInfo,{TextTransparency=1,BackgroundTransparency=1}):Play()
            elseif obj:IsA("Frame") then
                TweenService:Create(obj,fadeInfo,{BackgroundTransparency=1}):Play()
            elseif obj:IsA("UIStroke") then
                TweenService:Create(obj,fadeInfo,{Transparency=1}):Play()
            end
        end
        task.delay(.60,function()
            if not alive then return end
            alive=false
            for _,c in ipairs(conns) do pcall(function() c:Disconnect() end) end
            newButton.Visible=false
            newButton.Text=""
            pcall(function() gui:Destroy() end)
            _G.SaintsChristmasAuthCleanup=nil
        end)
    end)
end)

startAuthMusic()

-- Entrance.
-- Keep the auth panel at its FINAL size from the very first frame.
-- The old .94 -> 1 UIScale tween made every word briefly render smaller.
local scale=Instance.new("UIScale")
scale.Scale=1
scale.Parent=shell

-- Visible auth-strip text starts transparent and fades in without changing size.
stripTitle.TextTransparency=1
newBox.TextTransparency=1
newButton.TextTransparency=1

TweenService:Create(shell,TweenInfo.new(.55,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{BackgroundTransparency=0}):Play()
TweenService:Create(stroke,TweenInfo.new(.55),{Transparency=.18}):Play()
TweenService:Create(image,TweenInfo.new(.70),{ImageTransparency=0}):Play()

task.delay(.10,function()
    if not alive then return end
    TweenService:Create(brandShadow,TweenInfo.new(.42,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{TextTransparency=.42}):Play()
    TweenService:Create(brand,TweenInfo.new(.48,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{TextTransparency=0}):Play()
    TweenService:Create(season,TweenInfo.new(.52,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{TextTransparency=.08}):Play()
    TweenService:Create(stripTitle,TweenInfo.new(.42,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{TextTransparency=0}):Play()
    TweenService:Create(newBox,TweenInfo.new(.46,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{TextTransparency=0}):Play()
    TweenService:Create(newButton,TweenInfo.new(.46,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{TextTransparency=0}):Play()
end)

-- Clean red hover, no gold.
conns[#conns+1]=button.MouseEnter:Connect(function()
    TweenService:Create(button,TweenInfo.new(.14),{BackgroundColor3=Color3.fromRGB(151,17,25)}):Play()
    TweenService:Create(btns,TweenInfo.new(.14),{Transparency=0}):Play()
end)
conns[#conns+1]=button.MouseLeave:Connect(function()
    TweenService:Create(button,TweenInfo.new(.14),{BackgroundColor3=Color3.fromRGB(119,13,20)}):Play()
    TweenService:Create(btns,TweenInfo.new(.14),{Transparency=.20}):Play()
end)

-- Preview-only click response.
conns[#conns+1]=button.MouseButton1Click:Connect(function()
    TweenService:Create(button,TweenInfo.new(.07),{BackgroundColor3=Color3.fromRGB(183,22,31)}):Play()
    task.delay(.1,function()
        if alive then TweenService:Create(button,TweenInfo.new(.16),{BackgroundColor3=Color3.fromRGB(119,13,20)}):Play() end
    end)
end)

_G.SaintsChristmasAuthCleanup=function()
    alive=false
    for _,c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    if authMusic then pcall(function() authMusic:Stop(); authMusic:Destroy() end); authMusic=nil end
    pcall(function() gui:Destroy() end)
    _G.SaintsChristmasAuthCleanup=nil
end

end


-- ================= UPDATED HUB =================
local function startSaintsHub()
-- Saint's Hub - Visual Test V16.42 // Music Library Sort + Hub Seek Reset
-- UI interaction preview only; gameplay logic will be integrated after visual approval.

local Players=game:GetService("Players")
local TweenService=game:GetService("TweenService")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local SoundService=game:GetService("SoundService")
local HttpService=game:GetService("HttpService")
local CoreGui=game:GetService("CoreGui")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
local pg=player:WaitForChild("PlayerGui")

if _G.SaintsHubV4Cleanup then pcall(_G.SaintsHubV4Cleanup) end

local gui=Instance.new("ScreenGui")
gui.Name="SaintsHubVisualV13"; gui.IgnoreGuiInset=true; gui.ResetOnSpawn=false
gui.DisplayOrder=999999; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui.Parent=pg


-- ============================================================
-- PRIVATE CHAT V20 (integrated, lazy-loaded from Settings)
-- Networking/UI behavior is preserved from the approved standalone build.
-- ============================================================
local privateChatController=nil
local privateChatEnabled=false

-- Survivor Ping [C] // proven standalone V5
local survivorPingEnabled=false
local survivorPingLastSent=0
local SURVIVOR_PING_COOLDOWN=4
local survivorPingMarker=nil

local function clearSurvivorPingMarker()
 if survivorPingMarker then pcall(function() survivorPingMarker:Destroy() end) survivorPingMarker=nil end
end

local function showSurvivorPingMarker(senderName,pos)
 clearSurvivorPingMarker()

 local holder=Instance.new("Part")
 holder.Name="SaintsSurvivorPing"
 holder.Anchored=true
 holder.CanCollide=false
 holder.CanTouch=false
 holder.CanQuery=false
 holder.Transparency=1
 holder.Size=Vector3.new(.2,.2,.2)
 holder.CFrame=CFrame.new(pos)
 holder.Parent=workspace
 survivorPingMarker=holder

 -- Clean light-blue diamond survivorPingMarker: no name, no distance, no text.
 local gui=Instance.new("BillboardGui",holder)
 gui.Name="LightBluePing"
 gui.AlwaysOnTop=true
 gui.Size=UDim2.fromOffset(38,38)
 gui.StudsOffset=Vector3.new(0,2.1,0)
 gui.MaxDistance=10000

 local diamond=Instance.new("Frame",gui)
 diamond.AnchorPoint=Vector2.new(.5,.5)
 diamond.Position=UDim2.fromScale(.5,.5)
 diamond.Size=UDim2.fromOffset(18,18)
 diamond.Rotation=45
 diamond.BackgroundColor3=Color3.fromRGB(90,200,255)
 diamond.BorderSizePixel=0

 local corner=Instance.new("UICorner",diamond)
 corner.CornerRadius=UDim.new(0,3)

 local stroke=Instance.new("UIStroke",diamond)
 stroke.Color=Color3.fromRGB(185,235,255)
 stroke.Thickness=2
 stroke.Transparency=.08

 local glow=Instance.new("Frame",gui)
 glow.AnchorPoint=Vector2.new(.5,.5)
 glow.Position=UDim2.fromScale(.5,.5)
 glow.Size=UDim2.fromOffset(28,28)
 glow.Rotation=45
 glow.BackgroundColor3=Color3.fromRGB(65,175,245)
 glow.BackgroundTransparency=.78
 glow.BorderSizePixel=0
 glow.ZIndex=0
 local gc=Instance.new("UICorner",glow)
 gc.CornerRadius=UDim.new(0,5)

 -- Subtle pulse so the survivorPingMarker reads as a ping without adding text.
 task.spawn(function()
  local thisMarker=holder
  while thisMarker.Parent do
   local tw=game:GetService("TweenService"):Create(
    glow,
    TweenInfo.new(.65,Enum.EasingStyle.Sine,Enum.EasingDirection.Out),
    {Size=UDim2.fromOffset(36,36),BackgroundTransparency=.94}
   )
   tw:Play()
   tw.Completed:Wait()
   if not thisMarker.Parent then break end
   glow.Size=UDim2.fromOffset(24,24)
   glow.BackgroundTransparency=.76
  end
 end)

 local thisMarker=holder
 task.delay(9,function()
  if survivorPingMarker==thisMarker then clearSurvivorPingMarker()
  else pcall(function() thisMarker:Destroy() end) end
 end)
end


-- Fresh Hub execution always starts Private Chat truly OFF.
-- Remove any standalone/older integrated chat GUI left in CoreGui.
local stalePrivateChat=CoreGui:FindFirstChild("SaintsPrivateChatTest",true)
if stalePrivateChat then
 local staleGui=stalePrivateChat
 while staleGui.Parent and not staleGui:IsA("ScreenGui") do
  staleGui=staleGui.Parent
 end
 pcall(function() staleGui:Destroy() end)
end

local function startPrivateChat()
 if privateChatController then return true end

 local function buildPrivateChat()

-- Preserve V20's original service name inside the integrated builder.
local UserInputService = UIS

local LocalPlayer = player
local MY_ID = tostring(LocalPlayer.UserId)

local USERS = {
    ["558142136"] = {name = "Mateo", peer = "998914239"},
    ["998914239"] = {name = "Nina", peer = "558142136"},
}

local me = USERS[MY_ID]
if not me then
    warn("[Saint's Private Chat] Unauthorized Roblox UserId: " .. MY_ID)
    return nil
end

local RELAY = "wss://saints-multiplayer-relay.onrender.com/ws"

local function connectSocket(url)
    local candidates = {
        function() if WebSocket and WebSocket.connect then return WebSocket.connect(url) end end,
        function() if WebSocket and WebSocket.Connect then return WebSocket.Connect(url) end end,
        function() if websocket and websocket.connect then return websocket.connect(url) end end,
        function() if websocket and websocket.Connect then return websocket.Connect(url) end end,
        function() if syn and syn.websocket and syn.websocket.connect then return syn.websocket.connect(url) end end,
    }
    for _, fn in ipairs(candidates) do
        local ok, result = pcall(fn)
        if ok and result then return result end
    end
    return nil
end

local function socketSend(ws, payload)
    local ok = pcall(function() ws:Send(payload) end)
    if ok then return true end
    ok = pcall(function() ws:send(payload) end)
    return ok
end

local function socketClose(ws)
    if not ws then return end
    if pcall(function() ws:Close() end) then return end
    pcall(function() ws:close() end)
end

local old = CoreGui:FindFirstChild("SaintsPrivateChatTest")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "SaintsPrivateChatTest"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 2 -- gameplay overlay; final Saint\'s Hub will render above this
gui.Parent = CoreGui

-- Positioned directly beneath the Saint's Hub / SAVE dock area.
local shell = Instance.new("Frame")
shell.Name = "ChatShell"
shell.AnchorPoint = Vector2.new(0, 0)
shell.Position = UDim2.fromOffset(22, 339)
shell.Size = UDim2.fromOffset(340, 285)
shell.BackgroundColor3 = Color3.fromRGB(8, 9, 11)
shell.BackgroundTransparency = 0.24
shell.BorderSizePixel = 0
shell.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 9)
corner.Parent = shell

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(92, 96, 104)
stroke.Transparency = 0.45
stroke.Thickness = 1
stroke.Parent = shell

local top = Instance.new("Frame")
top.Size = UDim2.new(1, 0, 0, 31)
top.BackgroundTransparency = 1
top.Parent = shell

local title = Instance.new("TextLabel")
title.Position = UDim2.fromOffset(11, 5)
title.Size = UDim2.new(1, -80, 0, 20)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "PRIVATE CHAT"
title.TextSize = 12
title.TextColor3 = Color3.fromRGB(240, 240, 242)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = top

local statusDot = Instance.new("Frame")
statusDot.AnchorPoint = Vector2.new(1, 0.5)
statusDot.Position = UDim2.new(1, -100, 0.5, 0)
statusDot.Size = UDim2.fromOffset(7, 7)
statusDot.BackgroundColor3 = Color3.fromRGB(120, 120, 125)
statusDot.BorderSizePixel = 0
statusDot.Parent = top
Instance.new("UICorner", statusDot).CornerRadius = UDim.new(1,0)

local status = Instance.new("TextLabel")
status.AnchorPoint = Vector2.new(1, 0)
status.Position = UDim2.new(1, -53, 0, 6)
status.Size = UDim2.fromOffset(44, 18)
status.BackgroundTransparency = 1
status.Font = Enum.Font.GothamMedium
status.Text = "..."
status.TextSize = 10
status.TextColor3 = Color3.fromRGB(165,165,170)
status.TextXAlignment = Enum.TextXAlignment.Right
status.Parent = top

local line = Instance.new("Frame")
line.Position = UDim2.fromOffset(10, 30)
line.Size = UDim2.new(1, -20, 0, 1)
line.BackgroundColor3 = Color3.fromRGB(145, 28, 36)
line.BackgroundTransparency = 0.25
line.BorderSizePixel = 0
line.Parent = shell

local feed = Instance.new("ScrollingFrame")
feed.Position = UDim2.fromOffset(10, 39)
feed.Size = UDim2.new(1, -20, 1, -102)
feed.BackgroundTransparency = 1
feed.BorderSizePixel = 0
feed.ScrollBarThickness = 2
feed.ScrollBarImageColor3 = Color3.fromRGB(110,110,115)
feed.CanvasSize = UDim2.fromOffset(0,0)
feed.AutomaticCanvasSize = Enum.AutomaticSize.Y
feed.Parent = shell

local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 5)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = feed

local chatBottomSpacer = Instance.new("Frame")
chatBottomSpacer.Name = "ChatBottomSpacer"
chatBottomSpacer.Size = UDim2.new(1, 0, 0, 14)
chatBottomSpacer.BackgroundTransparency = 1
chatBottomSpacer.BorderSizePixel = 0
chatBottomSpacer.LayoutOrder = 2147483647
chatBottomSpacer.Parent = feed

local inputWrap = Instance.new("Frame")
inputWrap.Position = UDim2.new(0, 10, 1, -35)
inputWrap.Size = UDim2.new(1, -20, 0, 30)
inputWrap.BackgroundColor3 = Color3.fromRGB(19,20,24)
inputWrap.BackgroundTransparency = 0.08
inputWrap.BorderSizePixel = 0
inputWrap.Parent = shell
Instance.new("UICorner", inputWrap).CornerRadius = UDim.new(0,6)

local inputStroke = Instance.new("UIStroke")
inputStroke.Color = Color3.fromRGB(75,77,84)
inputStroke.Transparency = 0.45
inputStroke.Parent = inputWrap

local box = Instance.new("TextBox")
box.Position = UDim2.fromOffset(8, 0)
box.Size = UDim2.new(1, -16, 1, 0)
box.BackgroundTransparency = 1
box.ClearTextOnFocus = false
box.Font = Enum.Font.Gotham
box.PlaceholderText = "Press . to message " .. (me.name == "Mateo" and "Nina" or "Mateo") .. "..."
box.PlaceholderColor3 = Color3.fromRGB(115,117,124)
box.Text = ""
box.TextSize = 15
box.TextColor3 = Color3.fromRGB(235,235,238)
box.TextXAlignment = Enum.TextXAlignment.Left
box.Parent = inputWrap

local minimized = true
local CHAT_INACTIVITY_SECONDS = 20
local inactivityRevision = 0
local resetPrivateChatInactivity

local minimize = Instance.new("TextButton")
minimize.AnchorPoint = Vector2.new(1, 0)
minimize.Position = UDim2.new(1, -9, 0, 4)
minimize.Size = UDim2.fromOffset(28, 22)
minimize.BackgroundColor3 = Color3.fromRGB(24,25,29)
minimize.BackgroundTransparency = 0.12
minimize.BorderSizePixel = 0
minimize.Font = Enum.Font.GothamBold
minimize.Text = "▰"
minimize.TextSize = 12
minimize.TextColor3 = Color3.fromRGB(205,205,210)
minimize.Parent = top
Instance.new("UICorner", minimize).CornerRadius = UDim.new(0,5)

local unreadCount = 0
local unreadBadge = Instance.new("TextLabel")
unreadBadge.AnchorPoint = Vector2.new(1, 0.5)
unreadBadge.Position = UDim2.new(1, -37, 0.5, 0)
unreadBadge.Size = UDim2.fromOffset(18, 18)
unreadBadge.BackgroundColor3 = Color3.fromRGB(170, 34, 43)
unreadBadge.BorderSizePixel = 0
unreadBadge.Font = Enum.Font.GothamBold
unreadBadge.TextSize = 10
unreadBadge.TextColor3 = Color3.fromRGB(255,255,255)
unreadBadge.Text = ""
unreadBadge.Visible = false
unreadBadge.ZIndex = 10
unreadBadge.Parent = top
Instance.new("UICorner", unreadBadge).CornerRadius = UDim.new(1,0)

local function updateUnreadBadge()
    unreadBadge.Visible = minimized and unreadCount > 0
    if unreadCount > 99 then
        unreadBadge.Text = "99+"
        unreadBadge.Size = UDim2.fromOffset(27,18)
    else
        unreadBadge.Text = tostring(unreadCount)
        unreadBadge.Size = UDim2.fromOffset(18,18)
    end
end

local expandedPosition = UDim2.fromOffset(22, 339)
local collapsedPosition = UDim2.fromOffset(22, 339)

local function hardReleasePrivateFocus()
    pcall(function()
        box:ReleaseFocus(false)
    end)

    -- Some executors keep a hidden TextBox focused after ReleaseFocus().
    -- Temporarily removing it from the GUI forces that stale focus to die.
    if UserInputService:GetFocusedTextBox() == box then
        local oldParent = box.Parent
        box.Parent = nil
        task.wait()
        box.Parent = oldParent
    end
end

local typingIndicator = Instance.new("TextLabel")
typingIndicator.Name = "TypingIndicator"
typingIndicator.BackgroundTransparency = 1
typingIndicator.Position = UDim2.new(0, 12, 1, -51)
typingIndicator.Size = UDim2.new(1, -24, 0, 13)
typingIndicator.Font = Enum.Font.Gotham
typingIndicator.TextSize = 10
typingIndicator.TextColor3 = Color3.fromRGB(155,157,164)
typingIndicator.TextXAlignment = Enum.TextXAlignment.Left
typingIndicator.TextYAlignment = Enum.TextYAlignment.Center
typingIndicator.Text = ""
typingIndicator.Visible = false
typingIndicator.ZIndex = 8
typingIndicator.Parent = shell

local function setMinimized(v)
    if v then
        if localTyping ~= nil and localTyping then
            -- sendTypingState is defined later; minimizing before networking setup
            -- happens only during initial startup, where no typing packet is needed.
        end
        hardReleasePrivateFocus()
    end
    minimized = v
    feed.Visible = not v
    inputWrap.Visible = not v
    line.Visible = not v
    title.Visible = not v
    status.Visible = not v
    statusDot.Visible = not v
    if v then
        typingIndicator.Visible = false
    elseif typingIndicator.Text ~= "" then
        typingIndicator.Visible = true
    end

    if v then
        shell.Position = collapsedPosition
        shell.Size = UDim2.fromOffset(42, 38)
        shell.BackgroundTransparency = 0.08
        minimize.AnchorPoint = Vector2.new(0, 0)
        minimize.Position = UDim2.fromOffset(-1, 4)
        minimize.Size = UDim2.new(1, 2, 1, -1)
        minimize.BackgroundTransparency = 1
        minimize.Text = "💬"
        minimize.TextSize = 16
        minimize.TextXAlignment = Enum.TextXAlignment.Center
        minimize.TextYAlignment = Enum.TextYAlignment.Center
        -- Emoji glyph has asymmetric visual padding in Roblox's fallback font.
        -- A tiny left/down compensation makes the bubble visually dead-center.
        minimize.TextStrokeTransparency = 1
        unreadBadge.AnchorPoint = Vector2.new(0.5, 0.5)
        unreadBadge.Position = UDim2.new(1, -1, 0, 1)
    else
        unreadCount = 0
        shell.Position = expandedPosition
        shell.Size = UDim2.fromOffset(340,285)
        shell.BackgroundTransparency = 0.24
        minimize.AnchorPoint = Vector2.new(1, 0)
        minimize.Position = UDim2.new(1, -9, 0, 4)
        minimize.Size = UDim2.fromOffset(28,22)
        minimize.TextXAlignment = Enum.TextXAlignment.Center
        minimize.TextYAlignment = Enum.TextYAlignment.Center
        minimize.BackgroundTransparency = 0.12
        minimize.Text = "—"
        minimize.TextSize = 12
        unreadBadge.AnchorPoint = Vector2.new(1, 0.5)
        unreadBadge.Position = UDim2.new(1, -37, 0.5, 0)
    end

    updateUnreadBadge()
end

resetPrivateChatInactivity = function(clearUnread)
    inactivityRevision += 1
    local myRevision = inactivityRevision
    if clearUnread then
        unreadCount = 0
        updateUnreadBadge()
    end
    if minimized then return end
    task.delay(CHAT_INACTIVITY_SECONDS, function()
        if myRevision == inactivityRevision and not minimized then
            setMinimized(true)
        end
    end)
end

minimize.MouseButton1Click:Connect(function()
    local opening = minimized
    setMinimized(not minimized)
    if opening then
        resetPrivateChatInactivity(true)
    else
        inactivityRevision += 1
    end
end)

-- Start as the compact chat icon. The full chat only opens when clicked
-- or when "." is pressed.
setMinimized(true)


local function addMessage(author, text, mine)
    if author=="SYSTEM" then return end
    text = tostring(text or "")
    if text == "" then return end
    if #text > 180 then text = string.sub(text, 1, 180) end

    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -2, 0, 0)
    row.AutomaticSize = Enum.AutomaticSize.Y
    row.BackgroundTransparency = 1
    row.LayoutOrder = math.max(1, #feed:GetChildren())
    row.Parent = feed

    local name = Instance.new("TextLabel")
    name.Size = UDim2.new(1, 0, 0, 16)
    name.BackgroundTransparency = 1
    name.Font = Enum.Font.GothamBold
    name.Text = author
    name.TextSize = 13
    name.TextColor3 = mine and Color3.fromRGB(210,67,74) or Color3.fromRGB(210,212,218)
    name.TextXAlignment = Enum.TextXAlignment.Left
    name.Parent = row

    local msg = Instance.new("TextLabel")
    msg.Position = UDim2.fromOffset(0, 17)
    msg.Size = UDim2.new(1, -2, 0, 0)
    msg.AutomaticSize = Enum.AutomaticSize.Y
    msg.BackgroundTransparency = 1
    msg.Font = Enum.Font.Gotham
    msg.Text = text
    msg.TextWrapped = true
    msg.TextSize = 16
    msg.TextColor3 = Color3.fromRGB(235,235,238)
    msg.TextXAlignment = Enum.TextXAlignment.Left
    msg.TextYAlignment = Enum.TextYAlignment.Top
    msg.Parent = row

    task.defer(function()
        task.wait()
        feed.CanvasPosition = Vector2.new(0, math.max(0, feed.AbsoluteCanvasSize.Y - feed.AbsoluteWindowSize.Y))
    end)
end

addMessage("SYSTEM", "Connecting to private relay...", false)

local socket = connectSocket(RELAY)
if not socket then
    status.Text = "ERROR"
    status.TextColor3 = Color3.fromRGB(220,80,80)
    addMessage("SYSTEM", "Volt WebSocket connection failed.", false)
    return
end

local peerOnline = false
local connected = true

local function send(tbl)
    if not connected then return false end
    return socketSend(socket, HttpService:JSONEncode(tbl))
end

local localTyping = false
local typingRevision = 0
local remoteTypingRevision = 0

local function sendTypingState(isTyping)
    if localTyping == isTyping then return end
    localTyping = isTyping
    send({
        type = "typing",
        to = me.peer,
        payload = { typing = isTyping }
    })
end

local function showRemoteTyping(isTyping)
    remoteTypingRevision += 1
    local rev = remoteTypingRevision

    if isTyping then
        local peerName = (me.name == "Mateo") and "Nina" or "Mateo"
        typingIndicator.Text = peerName .. " is typing..."
        typingIndicator.Visible = not minimized

        task.delay(2.5, function()
            if remoteTypingRevision == rev then
                typingIndicator.Text = ""
                typingIndicator.Visible = false
            end
        end)
    else
        typingIndicator.Text = ""
        typingIndicator.Visible = false
    end
end

local function setPeerOnline(v)
    peerOnline = v
    status.Text = v and "ONLINE" or "OFFLINE"
    status.TextColor3 = v and Color3.fromRGB(170,220,180) or Color3.fromRGB(165,165,170)
    statusDot.BackgroundColor3 = v and Color3.fromRGB(82,190,105) or Color3.fromRGB(115,115,120)
end

local function handle(raw)
    local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok or type(data) ~= "table" then return end

    if data.type == "hello_ok" then
        addMessage("SYSTEM", "Connected as " .. me.name .. ".", false)
    elseif data.type == "presence" then
        local found = false
        if type(data.online) == "table" then
            for _, id in ipairs(data.online) do
                if tostring(id) == me.peer then found = true break end
            end
        end
        setPeerOnline(found)
    elseif data.type == "chat_message" and tostring(data.from) == me.peer then
        local payload = data.payload
        if type(payload) == "table" and payload.saintsType == "survivor_ping" then
            local x,y,z=tonumber(payload.x),tonumber(payload.y),tonumber(payload.z)
            local state=ReplicatedStorage:FindFirstChild("State")
            local char=player.Character
            local hum=char and char:FindFirstChildOfClass("Humanoid")
            local root=char and char:FindFirstChild("HumanoidRootPart")
            local backpack=player:FindFirstChildOfClass("Backpack")
            local beast=(player:GetAttribute("Beast")==true)
                or (char and char:FindFirstChild("Hammer")~=nil)
                or (backpack and backpack:FindFirstChild("Hammer")~=nil)
            if survivorPingEnabled and x and y and z and state and state.Value=="Round"
                and hum and hum.Health>0 and root and not beast then
                showSurvivorPingMarker("",Vector3.new(x,y,z))
            end
        else
            local text = type(payload) == "table" and payload.text or nil
            if text then
                addMessage(me.name == "Mateo" and "Nina" or "Mateo", text, false)
                unreadCount += 1
                updateUnreadBadge()
            end
        end
    elseif data.type == "typing" and tostring(data.from) == me.peer then
        local payload = type(data.payload) == "table" and data.payload or {}
        showRemoteTyping(payload.typing == true)
    elseif data.type == "presence_probe" and tostring(data.from) == me.peer then
        -- A probe reaching us proves the peer is connected to this relay.
        setPeerOnline(true)
        send({
            type = "presence_ack",
            to = me.peer,
            payload = {}
        })
    elseif data.type == "presence_ack" and tostring(data.from) == me.peer then
        setPeerOnline(true)
    elseif data.type == "delivery" then
        -- Relay delivery is authoritative even if a presence broadcast was missed.
        if tostring(data.to) == me.peer then
            setPeerOnline(data.ok == true)
        end
    elseif data.type == "error" then
        addMessage("SYSTEM", "Relay error: " .. tostring(data.message), false)
    end
end

-- Support common executor WebSocket event styles.
local messageBound = false
for _, eventName in ipairs({"OnMessage", "Message", "onmessage"}) do
    local ok, ev = pcall(function() return socket[eventName] end)
    if ok and ev then
        local hooked = pcall(function()
            ev:Connect(handle)
        end)
        if hooked then messageBound = true break end
    end
end

for _, eventName in ipairs({"OnClose", "Close", "onclose"}) do
    local ok, ev = pcall(function() return socket[eventName] end)
    if ok and ev then
        local hooked = pcall(function()
            ev:Connect(function()
                connected = false
                setPeerOnline(false)
                addMessage("SYSTEM", "Relay disconnected.", false)
            end)
        end)
        if hooked then break end
    end
end

if not messageBound then
    addMessage("SYSTEM", "Connected socket, but Volt message event was not detected.", false)
end

local helloOK = send({type = "hello", userId = MY_ID})
if not helloOK then
    status.Text = "ERROR"
    status.TextColor3 = Color3.fromRGB(220,80,80)
    addMessage("SYSTEM", "Socket opened, but sending HELLO failed.", false)
end

-- Presence recovery:
-- If a join/leave broadcast is missed by an executor WebSocket event,
-- periodically ask the relay to deliver a tiny packet to the peer.
-- The relay's delivery response becomes the authoritative online state.
task.spawn(function()
    while connected and gui.Parent do
        send({
            type = "presence_probe",
            to = me.peer,
            payload = {}
        })
        task.wait(2)
    end
end)

local EMOJI_SHORTCODES = {
    [":joy:"] = "😂",
    [":sob:"] = "😭",
    [":skull:"] = "💀",
    [":heart:"] = "❤️",
    [":fire:"] = "🔥",
    [":eyes:"] = "👀",
    [":pray:"] = "🙏",
    [":laughing:"] = "😆",
    [":100:"] = "💯",
    [":clown:"] = "🤡",
    [":thinking:"] = "🤔",
    [":smirk:"] = "😏",
    [":wave:"] = "👋",
    [":check:"] = "✅",
    [":x:"] = "❌",
}

local replacingEmoji = false
local fullDraft = ""
local MAX_VISIBLE_INPUT_CHARS = 39

local function markLocalTyping()
    typingRevision += 1
    local rev = typingRevision

    if fullDraft ~= "" then
        sendTypingState(true)
    else
        sendTypingState(false)
    end

    task.delay(1.8, function()
        if typingRevision == rev then
            sendTypingState(false)
        end
    end)
end

local function applyEmojiShortcodes(value)
    local converted = value
    for shortcode, emojiChar in pairs(EMOJI_SHORTCODES) do
        converted = converted:gsub(shortcode:gsub("(%W)","%%%1"), emojiChar)
    end
    return converted
end

local function renderDraft()
    local visible = fullDraft
    if #visible > MAX_VISIBLE_INPUT_CHARS then
        visible = string.sub(visible, #visible - MAX_VISIBLE_INPUT_CHARS + 1)
    end

    replacingEmoji = true
    box.Text = visible
    box.CursorPosition = #visible + 1
    replacingEmoji = false
end

box:GetPropertyChangedSignal("Text"):Connect(function()
    if replacingEmoji then return end

    -- Roblox/Volt can draw a long TextBox string outside its visual bounds.
    -- Keep the complete draft separately and only render the tail that fits.
    local visibleNow = box.Text
    local previousVisible = fullDraft
    if #previousVisible > MAX_VISIBLE_INPUT_CHARS then
        previousVisible = string.sub(previousVisible, #previousVisible - MAX_VISIBLE_INPUT_CHARS + 1)
    end

    if #visibleNow >= #previousVisible then
        local added = string.sub(visibleNow, #previousVisible + 1)
        fullDraft = applyEmojiShortcodes(fullDraft .. added)
    else
        local removed = #previousVisible - #visibleNow
        if removed > 0 then
            fullDraft = string.sub(fullDraft, 1, math.max(0, #fullDraft - removed))
        end
    end

    renderDraft()
    markLocalTyping()
    if not minimized then resetPrivateChatInactivity(true) end
end)

local openingFromHotkey = false

local privateChatInputConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    local focused = UserInputService:GetFocusedTextBox()

    -- Recover from stale PRIVATE CHAT focus while minimized.
    if minimized and focused == box then
        hardReleasePrivateFocus()
        focused = UserInputService:GetFocusedTextBox()
    end

    -- Roblox/public chat or another textbox owns the keyboard: do nothing.
    if gameProcessed or focused then return end

    if input.KeyCode == Enum.KeyCode.Period then
        setMinimized(false)
        resetPrivateChatInactivity(true)
        openingFromHotkey = true

        task.defer(function()
            box:CaptureFocus()
            task.wait()
            if openingFromHotkey and (box.Text == "." or fullDraft == ".") then
                fullDraft = ""
                renderDraft()
            end
            openingFromHotkey = false
        end)
    end
end)

box.Focused:Connect(function()
    resetPrivateChatInactivity(true)
    inputStroke.Color = Color3.fromRGB(150,38,46)
    inputStroke.Transparency = 0.15
end)

box.FocusLost:Connect(function(enterPressed)
    typingRevision += 1
    sendTypingState(false)
    inputStroke.Color = Color3.fromRGB(75,77,84)
    inputStroke.Transparency = 0.45

    if enterPressed then
        local text = fullDraft:gsub("^%s+",""):gsub("%s+$","")
        fullDraft = ""
        renderDraft()

        if text ~= "" then
            addMessage(me.name, text, true)
            send({
                type = "chat_message",
                to = me.peer,
                payload = {text = text}
            })
            resetPrivateChatInactivity(true)
        end
    else
        fullDraft = ""
        renderDraft()
    end

    -- Enter/click-away must always return keyboard ownership to Roblox.
    task.defer(function()
        pcall(function() box:ReleaseFocus(false) end)
    end)
end)

-- Integrated controller cleanup.
local chatCleaned = false
local function cleanupPrivateChat()
    if chatCleaned then return end
    chatCleaned = true
    connected = false
    pcall(function() sendTypingState(false) end)
    pcall(function() privateChatInputConn:Disconnect() end)
    pcall(function() socketClose(socket) end)
    pcall(function() gui:Destroy() end)
end

return {
    gui = gui,
    cleanup = cleanupPrivateChat,
    setMinimized = setMinimized,
    relaySend = send,
    peerId = me.peer,
}

 end

 local ok,result=pcall(buildPrivateChat)
 if ok and result then
  privateChatController=result
  -- V20's own compact state: only the 💬 icon is visible on enable.
  pcall(function() privateChatController.setMinimized(true) end)
  return true
 end
 if not ok then
  warn("[Saint's Hub] Private Chat failed to start: "..tostring(result))
 end
 return false
end

local function stopPrivateChat()
 if privateChatController then
  pcall(function() privateChatController.cleanup() end)
  privateChatController=nil
 end
end

local function cr(o,r) local c=Instance.new("UICorner",o); c.CornerRadius=UDim.new(0,r or 8) return c end
local function st(o,c,t,tr) local s=Instance.new("UIStroke",o); s.Color=c; s.Thickness=t or 1; s.Transparency=tr or 0 return s end
local RED=Color3.fromRGB(204,17,31)
local OFF=Color3.fromRGB(42,42,48)
local WHITE=Color3.fromRGB(245,245,248)
local MUTED=Color3.fromRGB(192,192,198)

-- short UI click. Asset can be swapped later if a different click character is preferred.
local clickSound=Instance.new("Sound",gui)
clickSound.Name="SaintsHubClick"
clickSound.SoundId="rbxassetid://6895079853"
clickSound.Volume=.42
clickSound.PlaybackSpeed=1.08
local function click()
 clickSound.TimePosition=0
 clickSound:Play()
end
local images={"rbxassetid://82426788532803","rbxassetid://123528408260727","rbxassetid://109978924592339","rbxassetid://81917208237623","rbxassetid://114728673859382","rbxassetid://85526411503184","rbxassetid://136601461738845","rbxassetid://135962336144475"}
local HUB_SETTINGS_FOLDER="SaintsHub"
local HUB_SETTINGS_FILE=HUB_SETTINGS_FOLDER.."/settings.json"

local function loadSavedHubImage()
 local selected=1
 pcall(function()
  if isfile and isfile(HUB_SETTINGS_FILE) then
   local data=HttpService:JSONDecode(readfile(HUB_SETTINGS_FILE))
   local n=tonumber(data and data.selectedHubImage)
   if n and n>=1 and n<=#images then selected=math.floor(n) end
  end
 end)
 return selected
end

local function saveHubImage(index)
 pcall(function()
  if makefolder and isfolder and not isfolder(HUB_SETTINGS_FOLDER) then makefolder(HUB_SETTINGS_FOLDER) end
  if writefile then writefile(HUB_SETTINGS_FILE,HttpService:JSONEncode({selectedHubImage=index})) end
 end)
end

local selectedHubImage=loadSavedHubImage()

-- gameplay overlay
local dock=Instance.new("Frame",gui)
dock.Position=UDim2.new(0,22,.5,-42); dock.Size=UDim2.fromOffset(116,80); dock.BackgroundTransparency=1
local open=Instance.new("TextButton",dock)
open.Size=UDim2.fromOffset(116,36); open.BackgroundColor3=Color3.fromRGB(8,8,11); open.BackgroundTransparency=.08; open.BorderSizePixel=0
open.Text="SAINT'S HUB"; open.TextColor3=WHITE; open.TextSize=10; open.Font=Enum.Font.GothamBold; cr(open,8); st(open,Color3.fromRGB(150,150,158),1,.55); open.Visible=false
local save=Instance.new("TextButton",dock)
save.Position=UDim2.fromOffset(0,43); save.Size=UDim2.fromOffset(116,37); save.BackgroundColor3=Color3.fromRGB(55,55,60); save.BorderSizePixel=0
save.Text="Save"; save.TextColor3=Color3.fromRGB(125,125,132); save.TextSize=13; save.Font=Enum.Font.GothamBold; save.AutoButtonColor=false; cr(save,8)
local saveEnabled=false

-- Auto Door Hop keybind state.
local DHK={enabled=false,waiting=false,key=nil,bind=nil,toggle=nil,setRuntime=nil}
function DHK.refresh()
 if DHK.bind then DHK.bind.Text=(DHK.waiting or not DHK.key) and "Press key..." or DHK.key.Name end
 if DHK.toggle then
  DHK.toggle.Text=DHK.enabled and "ON" or "OFF"
  DHK.toggle.BackgroundColor3=DHK.enabled and RED or OFF
  DHK.toggle.TextColor3=DHK.enabled and WHITE or MUTED
 end
end
function DHK.set(v)
 DHK.enabled=v==true;DHK.refresh()
 if DHK.setRuntime then DHK.setRuntime(DHK.enabled) end
end
UIS.InputBegan:Connect(function(input,gpe)
 if DHK.waiting then
  if input.KeyCode~=Enum.KeyCode.Unknown then DHK.key=input.KeyCode;DHK.waiting=false;DHK.refresh() end
  return
 end
 if not gpe and DHK.key and input.KeyCode==DHK.key then DHK.set(not DHK.enabled) end
end)

-- shell
local shellBack=Instance.new("Frame",gui)
shellBack.AnchorPoint=Vector2.new(.5,.5); shellBack.Position=UDim2.fromScale(.5,.5); shellBack.Size=UDim2.fromOffset(850,520)
shellBack.BackgroundColor3=Color3.fromRGB(3,3,5); shellBack.BackgroundTransparency=.04; shellBack.BorderSizePixel=0; shellBack.ZIndex=0; cr(shellBack,14)
local backStroke=st(shellBack,Color3.fromRGB(105,10,20),2,.42)

local shell=Instance.new("Frame",gui)
shell.AnchorPoint=Vector2.new(.5,.5); shell.Position=UDim2.fromScale(.5,.5); shell.Size=UDim2.fromOffset(850,520)
shell.BackgroundColor3=Color3.fromRGB(5,5,7); shell.BorderSizePixel=0; shell.ClipsDescendants=true; cr(shell,14)

-- Lightweight recycled snow: TweenService only, no per-frame snow updates.
local snowLayer=Instance.new("Frame",shell)
snowLayer.Name="LightweightSnow"; snowLayer.Size=UDim2.fromScale(1,1)
snowLayer.BackgroundTransparency=1; snowLayer.BorderSizePixel=0
snowLayer.ClipsDescendants=true; snowLayer.ZIndex=30

local SNOW_COUNT=20
local snowflakes={}
local snowRunning=false
local snowGeneration=0

local function prepSnowflake(f)
 local px=math.random(2,5)
 f.Size=UDim2.fromOffset(px,px)
 f.Position=UDim2.new(math.random(),0,-.04,0)
 f.BackgroundColor3=Color3.fromRGB(255,255,255)
 f.BackgroundTransparency=math.random(20,58)/100
 f.BorderSizePixel=0; f.ZIndex=31
end

for i=1,SNOW_COUNT do
 local f=Instance.new("Frame",snowLayer)
 f.Name="Snowflake"..i; f.Visible=false
 local c=Instance.new("UICorner",f); c.CornerRadius=UDim.new(1,0)
 prepSnowflake(f); snowflakes[i]=f
end

local function startSnow()
 if snowRunning or not shell.Visible then return end
 snowRunning=true; snowGeneration=snowGeneration+1
 local gen=snowGeneration
 for _,f in ipairs(snowflakes) do
  task.spawn(function()
   task.wait(math.random()*0.75)
   while snowRunning and snowGeneration==gen and shell.Visible and gui.Parent do
    prepSnowflake(f); f.Visible=true
    local tw=TweenService:Create(f,TweenInfo.new(math.random(45,80)/10,Enum.EasingStyle.Linear),{
     Position=UDim2.new(f.Position.X.Scale,math.random(-45,45),1.06,0),
     BackgroundTransparency=math.min(.82,f.BackgroundTransparency+.18)
    })
    tw:Play(); tw.Completed:Wait()
   end
   f.Visible=false
  end)
 end
end

local function stopSnow()
 snowRunning=false; snowGeneration=snowGeneration+1
 for _,f in ipairs(snowflakes) do f.Visible=false end
end

local outerStroke=st(shell,Color3.fromRGB(214,214,220),1,.38)
local scale=Instance.new("UIScale",shell); scale.Scale=1
local backScale=Instance.new("UIScale",shellBack); backScale.Scale=1

local art=Instance.new("ImageLabel",shell)
art.Size=UDim2.fromScale(1,1); art.BackgroundColor3=Color3.fromRGB(5,5,7); art.BorderSizePixel=0
art.Image=images[selectedHubImage]; art.ScaleType=Enum.ScaleType.Crop; art.ZIndex=1
if selectedHubImage==4 then
 art.Position=UDim2.new(0,-17,0,-11)
 art.Size=UDim2.new(1,34,1,22)
end

-- only left-side readability wash; artwork stays exposed
local wash=Instance.new("Frame",shell)
wash.Size=UDim2.fromScale(1,1); wash.BackgroundColor3=Color3.fromRGB(2,2,4); wash.BackgroundTransparency=.76
local premiumVignette=Instance.new("Frame",shell)
premiumVignette.Size=UDim2.fromScale(1,1); premiumVignette.BackgroundColor3=Color3.fromRGB(0,0,0)
premiumVignette.BackgroundTransparency=.90; premiumVignette.BorderSizePixel=0; premiumVignette.ZIndex=4
local pvg=Instance.new("UIGradient",premiumVignette)
pvg.Transparency=NumberSequence.new({
 NumberSequenceKeypoint.new(0,.18),
 NumberSequenceKeypoint.new(.22,.58),
 NumberSequenceKeypoint.new(.52,.94),
 NumberSequenceKeypoint.new(.82,.98),
 NumberSequenceKeypoint.new(1,.76)
}); wash.BorderSizePixel=0; wash.ZIndex=2
local grad=Instance.new("UIGradient",wash); grad.Rotation=0
grad.Transparency=NumberSequence.new({
 NumberSequenceKeypoint.new(0,.22), NumberSequenceKeypoint.new(.42,.48),
 NumberSequenceKeypoint.new(.68,.86), NumberSequenceKeypoint.new(1,.98)
})

-- precision luxury frame: every decorative layer stays INSIDE the shell footprint
local edge1=Instance.new("Frame",shell)
edge1.Position=UDim2.fromOffset(5,5); edge1.Size=UDim2.new(1,-10,1,-10)
edge1.BackgroundTransparency=1; edge1.BorderSizePixel=0; edge1.ZIndex=11; cr(edge1,11)
local edge1Stroke=st(edge1,Color3.fromRGB(228,228,233),1,.48)

local edge2=Instance.new("Frame",shell)
edge2.Position=UDim2.fromOffset(9,9); edge2.Size=UDim2.new(1,-18,1,-18)
edge2.BackgroundTransparency=1; edge2.BorderSizePixel=0; edge2.ZIndex=11; cr(edge2,9)
local edge2Stroke=st(edge2,Color3.fromRGB(82,82,92),1,.28)

local edge3=Instance.new("Frame",shell)
edge3.Position=UDim2.fromOffset(12,12); edge3.Size=UDim2.new(1,-24,1,-24)
edge3.BackgroundTransparency=1; edge3.BorderSizePixel=0; edge3.ZIndex=11; cr(edge3,8)
local edge3Stroke=st(edge3,Color3.fromRGB(214,214,220),1,.78)

-- crimson light is inset, never extends below/around the shell
local crimsonTop=Instance.new("Frame",shell)
crimsonTop.Position=UDim2.fromOffset(70,5); crimsonTop.Size=UDim2.new(1,-140,0,1)
crimsonTop.BackgroundColor3=RED; crimsonTop.BackgroundTransparency=.08; crimsonTop.BorderSizePixel=0; crimsonTop.ZIndex=13
local ctg=Instance.new("UIGradient",crimsonTop)
ctg.Transparency=NumberSequence.new({
 NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.12,.58),
 NumberSequenceKeypoint.new(.5,0),NumberSequenceKeypoint.new(.88,.58),NumberSequenceKeypoint.new(1,1)
})

local crimsonBottom=Instance.new("Frame",shell)
crimsonBottom.AnchorPoint=Vector2.new(0,1); crimsonBottom.Position=UDim2.new(0,70,1,-5)
crimsonBottom.Size=UDim2.new(1,-140,0,1); crimsonBottom.BackgroundColor3=RED
crimsonBottom.BackgroundTransparency=.58; crimsonBottom.BorderSizePixel=0; crimsonBottom.ZIndex=13
local cbg=Instance.new("UIGradient",crimsonBottom)
cbg.Transparency=NumberSequence.new({
 NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.20,.72),
 NumberSequenceKeypoint.new(.5,.24),NumberSequenceKeypoint.new(.80,.72),NumberSequenceKeypoint.new(1,1)
})

-- clean uninterrupted frame: artwork bleeds under the trim, no visible L-corners
local brand=Instance.new("TextLabel",shell); brand.Position=UDim2.fromOffset(30,27); brand.Size=UDim2.fromOffset(280,35); brand.BackgroundTransparency=1
brand.Text="SAINT'S HUB"; brand.TextXAlignment=Enum.TextXAlignment.Left; brand.TextColor3=WHITE; brand.TextSize=23; brand.Font=Enum.Font.GothamBold; brand.ZIndex=12
local rule=Instance.new("Frame",shell); rule.Position=UDim2.fromOffset(30,86); rule.Size=UDim2.fromOffset(68,2); rule.BackgroundColor3=RED; rule.BorderSizePixel=0; rule.ZIndex=12

local min=Instance.new("TextButton",shell); min.AnchorPoint=Vector2.new(1,0); min.Position=UDim2.new(1,-22,0,20); min.Size=UDim2.fromOffset(34,28)
min.BackgroundColor3=Color3.fromRGB(12,12,15); min.BackgroundTransparency=.12; min.BorderSizePixel=0; min.Text="−"; min.TextColor3=Color3.fromRGB(224,224,230); min.TextSize=16; min.Font=Enum.Font.GothamMedium; min.ZIndex=20; cr(min,7)
local minStroke=st(min,Color3.fromRGB(120,120,130),1,.55)

local nav=Instance.new("Frame",shell); nav.Position=UDim2.fromOffset(30,116); nav.Size=UDim2.fromOffset(125,320); nav.BackgroundTransparency=1; nav.ZIndex=12
local content=Instance.new("Frame",shell); content.Position=UDim2.fromOffset(170,116); content.Size=UDim2.fromOffset(390,360)
content.BackgroundColor3=Color3.fromRGB(8,8,12); content.BackgroundTransparency=.48; content.BorderSizePixel=0; content.ZIndex=10; cr(content,10); st(content,Color3.fromRGB(184,184,194),1,.62)
content.Visible=false
local contentGlow=Instance.new("Frame",content)
contentGlow.Position=UDim2.fromOffset(1,1); contentGlow.Size=UDim2.new(1,-2,0,52)
contentGlow.BackgroundColor3=Color3.fromRGB(255,255,255); contentGlow.BackgroundTransparency=.965
contentGlow.BorderSizePixel=0; contentGlow.ZIndex=content.ZIndex+1; cr(contentGlow,9)
local cg=Instance.new("UIGradient",contentGlow)
cg.Rotation=90
cg.Transparency=NumberSequence.new({
 NumberSequenceKeypoint.new(0,.70),
 NumberSequenceKeypoint.new(1,1)
})



local pages,navButtons={},{}
local pageShells={}
local function page(name,title)
 local p=Instance.new("Frame",content)
 p.Size=UDim2.fromScale(1,1); p.BackgroundTransparency=1; p.BorderSizePixel=0; p.Visible=false; p.ZIndex=11

 local t=Instance.new("TextLabel",p)
 t.Position=UDim2.fromOffset(16,14); t.Size=UDim2.new(1,-32,0,28)
 t.BackgroundTransparency=1; t.Text=title; t.TextXAlignment=Enum.TextXAlignment.Left
 t.TextColor3=WHITE; t.TextSize=15; t.Font=Enum.Font.GothamBold; t.ZIndex=14

 local titleRule=Instance.new("Frame",p)
 titleRule.Position=UDim2.fromOffset(16,48); titleRule.Size=UDim2.new(1,-32,0,1)
 titleRule.BackgroundColor3=Color3.fromRGB(180,180,188); titleRule.BackgroundTransparency=.82
 titleRule.BorderSizePixel=0; titleRule.ZIndex=14

 local sc=Instance.new("ScrollingFrame",p)
 sc.Name="Rows"; sc.Position=UDim2.fromOffset(0,55); sc.Size=UDim2.new(1,0,1,-55)
 sc.BackgroundTransparency=1; sc.BorderSizePixel=0; sc.ScrollBarThickness=3
 sc.ScrollBarImageColor3=RED; sc.AutomaticCanvasSize=Enum.AutomaticSize.Y; sc.CanvasSize=UDim2.new()
 sc.ZIndex=12

 local pad=Instance.new("UIPadding",sc)
 pad.PaddingLeft=UDim.new(0,16); pad.PaddingRight=UDim.new(0,16)
 pad.PaddingTop=UDim.new(0,4); pad.PaddingBottom=UDim.new(0,15)

 local lay=Instance.new("UIListLayout",sc)
 lay.Padding=UDim.new(0,8); lay.SortOrder=Enum.SortOrder.LayoutOrder

 pages[name]=p
 pageShells[name]=p
 return sc
end
local function row(parent,label,h)
 local r=Instance.new("Frame",parent); r.Size=UDim2.new(1,0,0,h or 48); r.BackgroundColor3=Color3.fromRGB(17,17,21); r.BackgroundTransparency=.08; r.BorderSizePixel=0; r.ZIndex=12; cr(r,7)
 local l=Instance.new("TextLabel",r); l.Position=UDim2.fromOffset(12,0); l.Size=UDim2.new(1,-128,1,0); l.BackgroundTransparency=1; l.Text=label; l.TextXAlignment=Enum.TextXAlignment.Left; l.TextColor3=Color3.fromRGB(230,230,234); l.TextSize=11; l.Font=Enum.Font.GothamMedium; l.ZIndex=13
 return r,l
end
local function feature(parent,label,states)
 local r=row(parent,label); local b=Instance.new("TextButton",r)
 b.AnchorPoint=Vector2.new(1,.5); b.Position=UDim2.new(1,-9,.5,0); b.Size=UDim2.fromOffset(105,30); b.BackgroundColor3=OFF; b.BorderSizePixel=0
 b.Text="OFF"; b.TextColor3=MUTED; b.TextSize=10; b.Font=Enum.Font.GothamBold; b.ZIndex=14; cr(b,7)
 local i=1
 b.MouseButton1Click:Connect(function()
  click()
  i=i%#states+1; b.Text=states[i]:upper()
  local active=i~=1; b.BackgroundColor3=active and RED or OFF; b.TextColor3=active and WHITE or MUTED
 end)
 return b
end


--==================================================
-- V21 OPTIMIZED ESP RUNTIME
-- Cached object tracking: no repeated workspace-wide rebuild loops.
--==================================================
local PlayersESP=game:GetService("Players")
local RunESP=game:GetService("RunService")
local RSESP=game:GetService("ReplicatedStorage")
local meESP=PlayersESP.LocalPlayer

local espRuntime={Survivor=false,Beast=0,Computer=false,LockerVent=false,Exit=true,Hatch=false}
local espCache={computers={},lockerVents={},exits={},hatches={}}

local function rootOf(x)
 if not x then return nil end
 if x:IsA("BasePart") then return x end
 if x:IsA("Model") then return x.PrimaryPart or x:FindFirstChildWhichIsA("BasePart",true) end
end
local function distTo(x)
 local a=meESP.Character and meESP.Character:FindFirstChild("HumanoidRootPart")
 local b=rootOf(x)
 if not a or not b then return 0 end
 return math.floor((a.Position-b.Position).Magnitude+.5)
end
local function mkHL(parent,name,col)
 local h=parent:FindFirstChild(name)
 if not h then h=Instance.new("Highlight");h.Name=name;h.Parent=parent end
 h.Adornee=parent;h.FillColor=col;h.OutlineColor=col
 h.FillTransparency=.76;h.OutlineTransparency=0;h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
 return h
end
local function mkTag(part,name,col)
 if not part then return nil end
 local b=part:FindFirstChild(name)
 if not b then
  b=Instance.new("BillboardGui");b.Name=name;b.Adornee=part;b.AlwaysOnTop=true
  b.Size=UDim2.fromOffset(180,44);b.StudsOffsetWorldSpace=Vector3.new(0,2.7,0);b.Parent=part
  local top=Instance.new("TextLabel");top.Name="Top";top.Size=UDim2.new(1,0,0,21)
  top.BackgroundTransparency=1;top.Font=Enum.Font.GothamBold;top.TextSize=14
  top.TextStrokeTransparency=.3;top.TextColor3=col;top.Parent=b
  local bottom=Instance.new("TextLabel");bottom.Name="Bottom";bottom.Position=UDim2.fromOffset(0,19)
  bottom.Size=UDim2.new(1,0,0,20);bottom.BackgroundTransparency=1
  bottom.Font=Enum.Font.GothamBold;bottom.TextSize=13;bottom.TextStrokeTransparency=.3
  bottom.TextColor3=col;bottom.Parent=b
 end
 return b
end
local function setTag(tag,top,bottom,col)
 if not tag then return end
 local a=tag:FindFirstChild("Top");local b=tag:FindFirstChild("Bottom")
 if a then a.Text=top or "";a.TextColor3=col end
 if b then b.Text=bottom or "";b.TextColor3=col;b.Visible=(bottom~=nil and bottom~="") end
end
local function del(parent,name)
 if parent then local x=parent:FindFirstChild(name);if x then x:Destroy() end end
end
local function beastESP(p)
 if p:GetAttribute("Beast")==true or p:GetAttribute("IsBeast")==true then return true end
 local c=p.Character;local bp=p:FindFirstChildOfClass("Backpack")
 if (c and c:FindFirstChild("Hammer")) or (bp and bp:FindFirstChild("Hammer")) then return true end
 for _,n in ipairs({"Beast","Beast1","Beast2"}) do
  local v=RSESP:FindFirstChild(n,true)
  if v and v:IsA("ObjectValue") and v.Value==p then return true end
 end
 return false
end
local function aliveESP(p)
 local c=p.Character;local h=c and c:FindFirstChildOfClass("Humanoid")
 return h and h.Health>0
end
local function clearPlayer(p)
 local c=p.Character;if not c then return end
 del(c,"SaintsSurvivorESP");del(c,"SaintsBeastESP")
 local head=c:FindFirstChild("Head")
 del(head,"SaintsSurvivorTag");del(head,"SaintsBeastTag")
end
local function updatePlayersESP()
 for _,p in ipairs(PlayersESP:GetPlayers()) do
  if p~=meESP and p.Character then
   local c=p.Character;local head=c:FindFirstChild("Head")
   local isB=beastESP(p)
   if isB then
    del(c,"SaintsSurvivorESP");del(head,"SaintsSurvivorTag")
    if espRuntime.Beast>0 and aliveESP(p) then
     mkHL(c,"SaintsBeastESP",Color3.fromRGB(255,45,45))
     if espRuntime.Beast==2 then
      local t=mkTag(head,"SaintsBeastTag",Color3.fromRGB(255,65,65))
      setTag(t,p.Name,tostring(distTo(c)).." studs",Color3.fromRGB(255,65,65))
     else del(head,"SaintsBeastTag") end
    else del(c,"SaintsBeastESP");del(head,"SaintsBeastTag") end
   else
    del(c,"SaintsBeastESP");del(head,"SaintsBeastTag")
    local escaped=p:GetAttribute("Escaped")==true
    if espRuntime.Survivor and aliveESP(p) and not escaped then
     mkHL(c,"SaintsSurvivorESP",Color3.fromRGB(70,180,255))
     local t=mkTag(head,"SaintsSurvivorTag",Color3.fromRGB(105,205,255))
     setTag(t,p.Name,"",Color3.fromRGB(105,205,255))
    else del(c,"SaintsSurvivorESP");del(head,"SaintsSurvivorTag") end
   end
  end
 end
end

local function isComputer(o)
 return o:IsA("Model") and (o.Name=="ComputerTable" or o:FindFirstChild("Screen",true)~=nil and o.Name:lower():find("computer",1,true))
end
local function lvKind(o)
 if not o:IsA("Model") then return nil end
 local n=o.Name:lower()
 if n:find("vent",1,true) then return "VENT" end
 if n:find("locker",1,true) then return "LOCKER" end
end
local function isExit(o)
 if not o:IsA("Model") then return false end
 local n=o.Name:lower()
 return n=="exitdoor" or n:find("exitdoor",1,true)~=nil
end
local function isHatch(o)
 if not o:IsA("Model") and not o:IsA("BasePart") then return false end
 return o.Name:lower():find("hatch",1,true)~=nil
end
local function compPct(o)
 local v=tonumber(o:GetAttribute("Progress"))
 if v==nil then return 0 end
 return math.clamp(math.floor(v+.5),0,100)
end
local function exitOpen(o)
 for _,n in ipairs({"Open","Opened","IsOpen","DoorOpen"}) do
  local a=o:GetAttribute(n);if a==true then return true end
  local x=o:FindFirstChild(n,true);if x and x:IsA("BoolValue") and x.Value then return true end
 end
 return false
end
local function cacheObject(o)
 if isComputer(o) then espCache.computers[o]=true end
 local k=lvKind(o);if k then espCache.lockerVents[o]=k end
 if isExit(o) then espCache.exits[o]=true end
 if isHatch(o) then espCache.hatches[o]=true end
end
local function initialScan()
 table.clear(espCache.computers);table.clear(espCache.lockerVents);table.clear(espCache.exits);table.clear(espCache.hatches)
 for _,o in ipairs(workspace:GetDescendants()) do cacheObject(o) end
end
local function cleanDead()
 for _,tab in pairs(espCache) do for o in pairs(tab) do if not o.Parent then tab[o]=nil end end end
end
-- Remove stale exit highlights from this or older Saint's Hub builds.
for _,obj in ipairs(workspace:GetDescendants()) do
 if obj:IsA("Highlight") and (obj.Name=="SaintsExitESP" or obj.Name=="MateoExitHighlight") then
  obj:Destroy()
 end
end
local exitWasOpen={}
local exitAlertToken=0
local function showExitOpenAlert()
 exitAlertToken+=1
 local token=exitAlertToken
 local pg=meESP:FindFirstChildOfClass("PlayerGui")
 if not pg then return end
 local old=pg:FindFirstChild("SaintsExitOpenAlert")
 if old then old:Destroy() end
 local sg=Instance.new("ScreenGui")
 sg.Name="SaintsExitOpenAlert";sg.ResetOnSpawn=false;sg.IgnoreGuiInset=true
 sg.DisplayOrder=999;sg.Parent=pg
 local label=Instance.new("TextLabel")
 label.AnchorPoint=Vector2.new(.5,.5)
 label.Position=UDim2.fromScale(.5,.34)
 label.Size=UDim2.fromOffset(430,62)
 label.BackgroundColor3=Color3.fromRGB(10,10,13)
 label.BackgroundTransparency=.16
 label.BorderSizePixel=0
 label.Text="An Exit Is Open!"
 label.TextColor3=Color3.fromRGB(100,255,135)
 label.TextStrokeTransparency=.42
 label.Font=Enum.Font.GothamBold
 label.TextSize=28
 label.Parent=sg
 local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,10);corner.Parent=label
 local stroke=Instance.new("UIStroke");stroke.Color=Color3.fromRGB(100,255,135)
 stroke.Thickness=1.2;stroke.Transparency=.18;stroke.Parent=label
 task.delay(3,function()
  if token==exitAlertToken and sg.Parent then sg:Destroy() end
 end)
end

local function updateWorldESP()
 cleanDead()
 for o in pairs(espCache.computers) do
  if espRuntime.Computer then
   mkHL(o,"SaintsComputerESP",Color3.fromRGB(255,205,45))
   local p=rootOf(o);local t=mkTag(p,"SaintsComputerTag",Color3.fromRGB(255,215,55))
   setTag(t,tostring(compPct(o)).."%","",Color3.fromRGB(255,215,55))
  else del(o,"SaintsComputerESP");local p=rootOf(o);del(p,"SaintsComputerTag") end
 end
 for o,k in pairs(espCache.lockerVents) do
  if espRuntime.LockerVent then
   local col=k=="VENT" and Color3.fromRGB(85,215,255) or Color3.fromRGB(205,205,220)
   mkHL(o,"SaintsLockerVentESP",col)
  else del(o,"SaintsLockerVentESP") end
 end
 for o in pairs(espCache.exits) do
  -- Exit ESP is text-only. Explicitly purge any highlight left by older builds/state.
  del(o,"SaintsExitESP")
  for _,desc in ipairs(o:GetDescendants()) do
   if desc:IsA("Highlight") and (desc.Name=="SaintsExitESP" or desc.Name=="MateoExitHighlight") then
    desc:Destroy()
   end
  end
  local p=rootOf(o)
  local t=mkTag(p,"SaintsExitTag",Color3.fromRGB(90,255,130))
  local opened=exitOpen(o)
  if opened then
   setTag(t,"OPEN","",Color3.fromRGB(90,255,130))
   if exitWasOpen[o]==false then showExitOpenAlert() end
  else
   setTag(t,"EXIT","",Color3.fromRGB(90,255,130))
  end
  if exitWasOpen[o]==nil then
   -- Establish initial state silently so joining after an exit is already open
   -- does not fake a new-open notification.
   exitWasOpen[o]=opened
  else
   exitWasOpen[o]=opened
  end
 end
 for o in pairs(espCache.hatches) do
  if espRuntime.Hatch then
   local hatchYellow=Color3.fromRGB(255,245,35)
   mkHL(o,"SaintsHatchESP",hatchYellow)
   local p=rootOf(o);local t=mkTag(p,"SaintsHatchTag",hatchYellow)
   setTag(t,"[HATCH]",tostring(distTo(o)).." studs",hatchYellow)
  else del(o,"SaintsHatchESP");local p=rootOf(o);del(p,"SaintsHatchTag") end
 end
end

initialScan()
local computerProgressConnections={}
local function hookComputerProgress(o)
 if computerProgressConnections[o] then return end
 computerProgressConnections[o]=o:GetAttributeChangedSignal("Progress"):Connect(function()
  if not espRuntime.Computer then return end
  local p=rootOf(o); local t=p and p:FindFirstChild("SaintsComputerTag")
  if t then setTag(t,tostring(compPct(o)).."%","",Color3.fromRGB(255,215,55)) end
 end)
end
for o in pairs(espCache.computers) do hookComputerProgress(o) end
workspace.DescendantAdded:Connect(function(o)
 -- Cheap incremental classification; never rescan the whole workspace here.
 task.defer(function()
  if o.Parent then cacheObject(o); if espCache.computers[o] then hookComputerProgress(o) end end
 end)
end)
workspace.DescendantRemoving:Connect(function(o)
 espCache.computers[o]=nil;espCache.lockerVents[o]=nil;espCache.exits[o]=nil;espCache.hatches[o]=nil
end)
for _,p in ipairs(PlayersESP:GetPlayers()) do
 p.CharacterAdded:Connect(function() task.wait(.3);updatePlayersESP() end)
end
PlayersESP.PlayerAdded:Connect(function(p)
 p.CharacterAdded:Connect(function() task.wait(.3);updatePlayersESP() end)
end)

-- Player labels/distances are cheap and can update smoothly.
task.spawn(function()
 while gui and gui.Parent do
  if espRuntime.Survivor or espRuntime.Beast>0 then pcall(updatePlayersESP) end
  task.wait(.15)
 end
end)
-- World ESP values update without rebuilding highlights/tags or rescanning the map.
task.spawn(function()
 while gui and gui.Parent do
  -- Performance: skip the world-cache update entirely while all world ESP is OFF.
  if espRuntime.Computer or espRuntime.LockerVent or espRuntime.Hatch then
   pcall(updateWorldESP)
  end
  task.wait(.35)
 end
end)

local esp=page("ESP","ESP OPTIONS")
local survivorESPBtn=feature(esp,"Survivor ESP",{"OFF","ON"})
local beastESPBtn=feature(esp,"Beast ESP",{"OFF","HL ONLY","FULL"})
local computerESPBtn=feature(esp,"Computer ESP",{"OFF","ON"})
local lockerVentESPBtn=feature(esp,"Locker / Vent ESP",{"OFF","ON"})
local hatchESPBtn=feature(esp,"Hatch ESP",{"OFF","ON"})

survivorESPBtn.MouseButton1Click:Connect(function()
 task.defer(function()
  espRuntime.Survivor=survivorESPBtn.Text=="ON"; pcall(updatePlayersESP); pcall(updateWorldESP)
 end)
end)
beastESPBtn.MouseButton1Click:Connect(function()
 task.defer(function()
  espRuntime.Beast=(beastESPBtn.Text=="FULL" and 2) or (beastESPBtn.Text=="HL ONLY" and 1) or 0
  pcall(updatePlayersESP); pcall(updateWorldESP)
 end)
end)
computerESPBtn.MouseButton1Click:Connect(function()
 task.defer(function() espRuntime.Computer=computerESPBtn.Text=="ON"; pcall(updatePlayersESP); pcall(updateWorldESP) end)
end)
lockerVentESPBtn.MouseButton1Click:Connect(function()
 task.defer(function() espRuntime.LockerVent=lockerVentESPBtn.Text=="ON"; pcall(updatePlayersESP); pcall(updateWorldESP) end)
end)
hatchESPBtn.MouseButton1Click:Connect(function()
 task.defer(function() espRuntime.Hatch=hatchESPBtn.Text=="ON"; pcall(updatePlayersESP); pcall(updateWorldESP) end)
end)

local mov=page("Movement","MOVEMENT")
local survivorSpeedBtn=feature(mov,"Survivor Walk Speed",{"OFF","ON (16.5)"})
local beastSpeedBtn=feature(mov,"Beast Walk Speed",{"OFF","ON (17.5)"})
local ventCrawlBtn=feature(mov,"Vent Crawl Speed",{"OFF","ON (8.0)"})
do
 local r,l=row(mov,"Auto Door Hop")
 l.Size=UDim2.new(1,-230,1,0)
 local kb=Instance.new("TextButton",r)
 kb.AnchorPoint=Vector2.new(1,.5);kb.Position=UDim2.new(1,-122,.5,0);kb.Size=UDim2.fromOffset(104,30)
 kb.BackgroundColor3=OFF;kb.BorderSizePixel=0;kb.Text="Press key...";kb.TextColor3=Color3.fromRGB(205,205,212)
 kb.TextSize=9;kb.Font=Enum.Font.GothamBold;kb.ZIndex=14;cr(kb,7);DHK.bind=kb
 local tg=Instance.new("TextButton",r)
 tg.AnchorPoint=Vector2.new(1,.5);tg.Position=UDim2.new(1,-9,.5,0);tg.Size=UDim2.fromOffset(105,30)
 tg.BackgroundColor3=OFF;tg.BorderSizePixel=0;tg.Text="OFF";tg.TextColor3=MUTED
 tg.TextSize=10;tg.Font=Enum.Font.GothamBold;tg.ZIndex=14;cr(tg,7);DHK.toggle=tg
 kb.MouseButton1Click:Connect(function() click();DHK.waiting=true;DHK.refresh() end)
 tg.MouseButton1Click:Connect(function() click();DHK.set(not DHK.enabled) end)
 DHK.refresh()
end

-- V31 MOVEMENT RUNTIME RESTORE - COMPACT
-- One Hub-scope local only, to avoid Luau's per-function local/register ceiling.
local MV={survivor=false,beast=false,vent=false,door=false,shift=UIS:IsKeyDown(Enum.KeyCode.LeftShift),ventHum=nil,doorWorker=false,writing=false}

function MV.hum()
 local c=player.Character
 return c and c:FindFirstChildOfClass("Humanoid")
end
function MV.isBeast()
 local c=player.Character
 local bp=player:FindFirstChildOfClass("Backpack")
 return player:GetAttribute("Beast")==true or (c and c:FindFirstChild("Hammer")~=nil) or (bp and bp:FindFirstChild("Hammer")~=nil)
end
function MV.beastSpecial()
 local c=player.Character
 if not c then return true end
 return player:GetAttribute("Sprint") or player:GetAttribute("Phaser") or player:GetAttribute("Watcher")
  or player:GetAttribute("WatcherStalking") or player:GetAttribute("DwellerBoost") or player:GetAttribute("SurveyorDetecting")
  or c:GetAttribute("Stalker") or c:GetAttribute("StalkerUnpopBoost") or c:GetAttribute("PhaserPause")
  or c:GetAttribute("LeaperActive") or c:GetAttribute("ThrowerLocked")
  or c:GetAttribute("LeaperChargingSpeed")~=nil or c:GetAttribute("BreacherMoveSpeed")~=nil
end
function MV.applySpeed()
 if MV.writing then return end
 local h=MV.hum()
 if not h or h.Health<=0 then return end
 if MV.isBeast() then
  if MV.beast and not MV.beastSpecial() and math.abs(h.WalkSpeed-17)<.2 then
   MV.writing=true h.WalkSpeed=17.5 MV.writing=false
  end
 elseif MV.survivor and math.abs(h.WalkSpeed-16)<.2 then
  MV.writing=true h.WalkSpeed=16.5 MV.writing=false
 end
end
function MV.restoreVent()
 local h=MV.ventHum
 if h and h.Parent and math.abs(h.WalkSpeed-8)<.25 then h.WalkSpeed=6 end
 MV.ventHum=nil
end
function MV.bind(c)
 if MV.speedConn then pcall(function() MV.speedConn:Disconnect() end) end
 local h=c:WaitForChild("Humanoid",5)
 if not h then return end
 MV.speedConn=h:GetPropertyChangedSignal("WalkSpeed"):Connect(function() task.defer(MV.applySpeed) end)
 task.defer(MV.applySpeed)
end
function MV.cacheDoorUI()
 if not MV.interactionFrame or not MV.interactionFrame.Parent then
  local x=pg:FindFirstChild("Interaction")
  MV.interactionFrame=x and x:FindFirstChild("Frame")
  MV.interactionLabel=MV.interactionFrame and MV.interactionFrame:FindFirstChild("Label")
 end
 if not MV.progressFrame or not MV.progressFrame.Parent then
  local x=pg:FindFirstChild("Progress")
  MV.progressFrame=x and x:FindFirstChild("Frame")
  MV.progressFill=MV.progressFrame and MV.progressFrame:FindFirstChild("Fill")
 end
end
function MV.doorReady()
 MV.cacheDoorUI()
 return MV.interactionFrame and MV.interactionLabel
  and MV.interactionFrame.Visible and MV.interactionLabel.Text=="Open Door"
end
function MV.charParts()
 local c=player.Character
 if not c then return end
 return c:FindFirstChildOfClass("Humanoid"),c:FindFirstChild("HumanoidRootPart")
end
function MV.grounded(h)
 if not h or h.Health<=0 then return false end
 local st=h:GetState()
 return st~=Enum.HumanoidStateType.Jumping
  and st~=Enum.HumanoidStateType.Freefall
  and st~=Enum.HumanoidStateType.FallingDown
  and st~=Enum.HumanoidStateType.Dead
end
function MV.key(k,down)
 pcall(game:GetService("VirtualInputManager").SendKeyEvent,game:GetService("VirtualInputManager"),down,k,false,game)
end
function MV.release()
 MV.key(Enum.KeyCode.E,false)
 MV.key(Enum.KeyCode.Space,false)
end
function MV.ratio()
 MV.cacheDoorUI()
 if not MV.progressFrame or not MV.progressFill then return nil end
 local w=MV.progressFrame.AbsoluteSize.X
 if w>0 then
  return math.clamp(MV.progressFill.AbsoluteSize.X/w,0,1)
 end
 return math.clamp(MV.progressFill.Size.X.Scale,0,1)
end
function MV.doorCycle()
 if MV.doorBusy or not MV.door or not MV.doorReady() then return end
 local h,root=MV.charParts()
 if not h or not root or not MV.grounded(h) then return end
 MV.doorBusy=true

 local startY=root.Position.Y
 -- Proven V9 behavior: hold E immediately when the cycle starts.
 MV.key(Enum.KeyCode.E,true)

 local started=os.clock()
 local hit=false
 while MV.door and os.clock()-started<3 do
  local r=MV.ratio()
  if r and r>=0.50 then hit=true break end
  if not MV.doorReady() and (not r or r<=.01) and os.clock()-started>.20 then break end
  task.wait(.015)
 end

 if hit and MV.door then
  MV.key(Enum.KeyCode.Space,true)

  local limiter
  limiter=RunService.Heartbeat:Connect(function()
   if not MV.door or not root.Parent then
    limiter:Disconnect()
    return
   end
   local v=root.AssemblyLinearVelocity
   if root.Position.Y-startY>=3.50 and v.Y>0 then
    root.AssemblyLinearVelocity=Vector3.new(v.X,0,v.Z)
    limiter:Disconnect()
   end
  end)

  task.wait(.020)
  MV.key(Enum.KeyCode.E,false)
  task.wait(.035)
  MV.key(Enum.KeyCode.Space,false)
  task.wait(.025)
  MV.key(Enum.KeyCode.E,true)
  task.wait(.040)
  MV.key(Enum.KeyCode.E,false)

  local landStart=os.clock()
  repeat
   task.wait(.02)
   h=MV.charParts()
  until not MV.door or MV.grounded(h) or os.clock()-landStart>.75
 else
  MV.key(Enum.KeyCode.E,false)
 end

 MV.doorBusy=false
end
function MV.startDoor()
 if MV.doorWorker then return end
 MV.doorWorker=true
 task.spawn(function()
  while gui.Parent do
   if MV.door and not MV.doorBusy and MV.doorReady() then MV.doorCycle() end
   if MV.door then
    RunService.Heartbeat:Wait()
   else
    task.wait(.15)
   end
  end
  MV.release()
  MV.doorWorker=false
 end)
end
MV.startDoor()

-- Movement speed runtime bindings restored.
-- Auto Door Juke above is intentionally left unchanged.
if player.Character then task.spawn(MV.bind,player.Character) end
player.CharacterAdded:Connect(MV.bind)

UIS.InputBegan:Connect(function(i)
 if i.KeyCode==Enum.KeyCode.LeftShift then MV.shift=true end
end)
UIS.InputEnded:Connect(function(i)
 if i.KeyCode==Enum.KeyCode.LeftShift then
  MV.shift=false
  MV.restoreVent()
 end
end)

RunService.Heartbeat:Connect(function()
 -- Performance: with all three speed features OFF there is nothing to maintain.
 -- Door Hop has its own worker above and is intentionally unaffected.
 if not MV.vent and not MV.survivor and not MV.beast then return end

 local h=MV.hum()

 -- Vent crawl: normal crawl baseline 6 -> 8 while Shift-crawling and moving.
 if MV.vent and h and h.Health>0 and MV.shift and h.MoveDirection.Magnitude>.05
  and math.abs(h.HipHeight-(-2))<=.2
  and (math.abs(h.WalkSpeed-6)<.25 or h==MV.ventHum) then
  if h.WalkSpeed<8 then h.WalkSpeed=8 end
  MV.ventHum=h
 else
  MV.restoreVent()
 end

 -- Survivor 16 -> 16.5 / Beast 17 -> 17.5.
 MV.applySpeed()
end)

-- Survivor visual cadence: keep actual upright speed at 16.5, but make
-- walk/run animation look like the normal 16-speed cadence. Crawl is untouched.
function MV.visualPace()
 if not MV.survivor or MV.isBeast() then return end
 local h=MV.hum()
 if not h or h.Health<=0 or h.MoveDirection.Magnitude<=.05 then return end
 if MV.shift or h.HipHeight<0 then return end
 if math.abs(h.WalkSpeed-16.5)>.2 then return end
 local animator=h:FindFirstChildOfClass("Animator")
 if not animator then return end
 for _,track in ipairs(animator:GetPlayingAnimationTracks()) do
  local n=string.lower(track.Name or "")
  if n:find("walk") or n:find("run") then
   pcall(function() track:AdjustSpeed(16/16.5) end)
  end
 end
end
RunService.RenderStepped:Connect(MV.visualPace)

doorHopRuntimeSetEnabled=function(v)
 MV.door=v==true
 if not MV.door then MV.release() end
end
DHK.setRuntime=doorHopRuntimeSetEnabled
DHK.set(DHK.enabled)
survivorSpeedBtn.MouseButton1Click:Connect(function()
 task.defer(function()
  MV.survivor=survivorSpeedBtn.Text~="OFF"
  if not MV.survivor then
   local h=MV.hum()
   if h and not MV.isBeast() and math.abs(h.WalkSpeed-16.5)<.2 then h.WalkSpeed=16 end
  end
  MV.applySpeed()
 end)
end)
beastSpeedBtn.MouseButton1Click:Connect(function()
 task.defer(function()
  MV.beast=beastSpeedBtn.Text~="OFF"
  if not MV.beast then
   local h=MV.hum()
   if h and MV.isBeast() and math.abs(h.WalkSpeed-17.5)<.2 then h.WalkSpeed=17 end
  end
  MV.applySpeed()
 end)
end)
ventCrawlBtn.MouseButton1Click:Connect(function()
 task.defer(function()
  MV.vent=ventCrawlBtn.Text~="OFF"
  if not MV.vent then MV.restoreVent() end
 end)
end)
-- END V31 MOVEMENT RUNTIME RESTORE


-- Auto Hack: automatically enabled whenever Saint's Hub loads.
local autoHackEnabled=true
local ComputerChallenge=nil
pcall(function()
 local ps=meESP:WaitForChild("PlayerScripts")
 local interact=ps:FindFirstChild("Interact")
 local module=interact and interact:FindFirstChild("ComputerChallenge")
 if module and module:IsA("ModuleScript") then ComputerChallenge=require(module) end
end)
local ChallengeFrame,ChallengeMarker,ChallengeSpace=nil,nil,nil
local lastChallengeSearch=0
local skillPressedThisChallenge=false
local function findAutoHackChallenge()
 if ChallengeFrame and ChallengeFrame.Parent and ChallengeMarker and ChallengeMarker.Parent and ChallengeSpace and ChallengeSpace.Parent then
  return ChallengeFrame,ChallengeMarker,ChallengeSpace
 end
 if os.clock()-lastChallengeSearch<.5 then return nil end
 lastChallengeSearch=os.clock()
 local pg=meESP:FindFirstChildOfClass("PlayerGui"); if not pg then return nil end
 for _,obj in ipairs(pg:GetDescendants()) do
  if obj:IsA("GuiObject") then
   local marker=obj:FindFirstChild("Marker");local space=obj:FindFirstChild("Space")
   if marker and space and marker:IsA("GuiObject") and space:IsA("GuiObject") then
    ChallengeFrame,ChallengeMarker,ChallengeSpace=obj,marker,space
    return obj,marker,space
   end
  end
 end
end
RunESP.Heartbeat:Connect(function()
 if not autoHackEnabled or not ComputerChallenge then skillPressedThisChallenge=false;return end
 if ComputerChallenge.InChallenge~=true then skillPressedThisChallenge=false;return end
 if skillPressedThisChallenge or ComputerChallenge.Pressed==true then return end
 local _,marker,space=findAutoHackChallenge();if not marker or not space then return end
 local center=marker.AbsolutePosition.X+marker.AbsoluteSize.X/2
 local left=space.AbsolutePosition.X;local right=left+space.AbsoluteSize.X
 local margin=math.min(2,space.AbsoluteSize.X*.10)
 if center>=left+margin and center<=right-margin then
  ComputerChallenge.Pressed=true;skillPressedThisChallenge=true
 end
end)

local util=page("Utility","UTILITY")
local autoRopeBtn=feature(util,"Auto Rope",{"OFF","ON"})
local survivorPingBtn=feature(util,"Survivor Ping [C]",{"OFF","ON"})
survivorPingBtn.MouseButton1Click:Connect(function()
 task.defer(function()
  survivorPingEnabled=survivorPingBtn.Text=="ON"
  if not survivorPingEnabled then clearSurvivorPingMarker() end
 end)
end)

-- hitbox with true draggable 0-2 slider and OFF at zero
local hitboxLevel=0
local setHitboxLevel
do
 local r,l=row(util,"Hitbox Expander",66)
 l.Size=UDim2.new(1,-130,0,34)
 local state=Instance.new("TextLabel",r); state.AnchorPoint=Vector2.new(1,0); state.Position=UDim2.new(1,-9,0,8); state.Size=UDim2.fromOffset(78,26)
 state.BackgroundColor3=OFF; state.BorderSizePixel=0; state.Text="OFF"; state.TextColor3=MUTED; state.TextSize=10; state.Font=Enum.Font.GothamBold; state.ZIndex=15; cr(state,6)
 local track=Instance.new("Frame",r); track.Position=UDim2.fromOffset(13,45); track.Size=UDim2.new(1,-52,0,5); track.BackgroundColor3=Color3.fromRGB(58,58,64); track.BorderSizePixel=0; track.ZIndex=14; cr(track,99)
 local fill=Instance.new("Frame",track); fill.Size=UDim2.fromScale(0,1); fill.BackgroundColor3=RED; fill.BorderSizePixel=0; fill.ZIndex=15; cr(fill,99)
 local knob=Instance.new("TextButton",track); knob.AnchorPoint=Vector2.new(.5,.5); knob.Position=UDim2.fromScale(0,.5); knob.Size=UDim2.fromOffset(16,16); knob.BackgroundColor3=WHITE; knob.BorderSizePixel=0; knob.Text=""; knob.ZIndex=17; cr(knob,99)
 local val=Instance.new("TextLabel",r); val.AnchorPoint=Vector2.new(1,.5); val.Position=UDim2.new(1,-10,0,48); val.Size=UDim2.fromOffset(25,20); val.BackgroundTransparency=1; val.Text="0"; val.TextColor3=WHITE; val.TextSize=10; val.Font=Enum.Font.GothamBold; val.ZIndex=15
 local dragging=false
 setHitboxLevel=function(n)
  n=math.clamp(math.floor(tonumber(n) or 0),0,2)
  hitboxLevel=n
  knob.Position=UDim2.fromScale(n/2,.5); fill.Size=UDim2.fromScale(n/2,1); val.Text=tostring(n)
  state.Text=n==0 and "OFF" or "ON"; state.BackgroundColor3=n==0 and OFF or RED; state.TextColor3=n==0 and MUTED or WHITE
 end
 local function setFromX(x)
  local a=track.AbsolutePosition.X; local w=track.AbsoluteSize.X
  local raw=math.clamp((x-a)/w,0,1); local n=math.floor(raw*2+.5)
  setHitboxLevel(n)
 end
 setHitboxLevel(0)
 knob.MouseButton1Down:Connect(function() click(); dragging=true end)
 track.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then click(); dragging=true; setFromX(i.Position.X) end end)
 UIS.InputChanged:Connect(function(i) if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then setFromX(i.Position.X) end end)
 UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end)
end


-- Survivor Ping [C] sender // proven V5 transport // 4s cooldown.
UIS.InputBegan:Connect(function(input,processed)
 if processed or input.KeyCode~=Enum.KeyCode.C then return end
 if UIS:GetFocusedTextBox() then return end
 if not survivorPingEnabled then return end

 local state=ReplicatedStorage:FindFirstChild("State")
 if not state or state.Value~="Round" then return end

 local char=player.Character
 local hum=char and char:FindFirstChildOfClass("Humanoid")
 local root=char and char:FindFirstChild("HumanoidRootPart")
 local backpack=player:FindFirstChildOfClass("Backpack")
 local beast=(player:GetAttribute("Beast")==true)
     or (char and char:FindFirstChild("Hammer")~=nil)
     or (backpack and backpack:FindFirstChild("Hammer")~=nil)
 if beast or not hum or hum.Health<=0 or not root then return end

 local now=os.clock()
 if now-survivorPingLastSent<SURVIVOR_PING_COOLDOWN then return end
 if not privateChatController or not privateChatController.relaySend or not privateChatController.peerId then return end

 local ok=privateChatController.relaySend({
  type="chat_message",
  to=tostring(privateChatController.peerId),
  payload={
   saintsType="survivor_ping",
   x=root.Position.X,
   y=root.Position.Y,
   z=root.Position.Z
  }
 })
 if ok then survivorPingLastSent=now end
end)


--==================================================
-- BEAST HITBOX REMINDER // EXACT BEAST GAMEPLAY GATE
--==================================================
local beastPrompt=Instance.new("Frame",gui)
beastPrompt.AnchorPoint=Vector2.new(.5,.5)
beastPrompt.Position=UDim2.fromScale(.5,.43)
beastPrompt.Size=UDim2.fromOffset(430,190)
beastPrompt.BackgroundColor3=Color3.fromRGB(10,10,13)
beastPrompt.BackgroundTransparency=.04
beastPrompt.BorderSizePixel=0
beastPrompt.Visible=false
beastPrompt.ZIndex=250
cr(beastPrompt,12)
st(beastPrompt,RED,1.4,.12)

local promptAccent=Instance.new("Frame",beastPrompt)
promptAccent.Size=UDim2.new(1,0,0,3)
promptAccent.BackgroundColor3=RED
promptAccent.BorderSizePixel=0
promptAccent.ZIndex=251
cr(promptAccent,99)

local promptTitle=Instance.new("TextLabel",beastPrompt)
promptTitle.Position=UDim2.fromOffset(18,17)
promptTitle.Size=UDim2.new(1,-36,0,24)
promptTitle.BackgroundTransparency=1
promptTitle.Text="HITBOX EXPANDER IS OFF"
promptTitle.TextColor3=WHITE
promptTitle.TextSize=15
promptTitle.Font=Enum.Font.GothamBold
promptTitle.ZIndex=251

local promptBody=Instance.new("TextLabel",beastPrompt)
promptBody.Position=UDim2.fromOffset(25,48)
promptBody.Size=UDim2.new(1,-50,0,34)
promptBody.BackgroundTransparency=1
promptBody.Text="You're the Beast. Would you like to enable Hitbox Expander?"
promptBody.TextColor3=Color3.fromRGB(194,194,201)
promptBody.TextSize=12
promptBody.TextWrapped=true
promptBody.Font=Enum.Font.Gotham
promptBody.ZIndex=251

local NEUTRAL_BOX=Color3.fromRGB(24,24,29)
local NEUTRAL_STROKE=Color3.fromRGB(90,90,98)
local SELECTED_BOX=Color3.fromRGB(235,28,45)

local yesBox=Instance.new("Frame",beastPrompt)
yesBox.Position=UDim2.fromOffset(24,98)
yesBox.Size=UDim2.fromOffset(180,67)
yesBox.BackgroundColor3=NEUTRAL_BOX
yesBox.BorderSizePixel=0
yesBox.ZIndex=251
cr(yesBox,8)
local yesStroke=st(yesBox,NEUTRAL_STROKE,1,.35)

local yesKey=Instance.new("TextLabel",yesBox)
yesKey.Position=UDim2.fromOffset(10,7)
yesKey.Size=UDim2.new(1,-20,0,25)
yesKey.BackgroundTransparency=1
yesKey.Text="[ 1 ]  YES"
yesKey.TextColor3=WHITE
yesKey.TextSize=14
yesKey.Font=Enum.Font.GothamBold
yesKey.ZIndex=252

local yesHint=Instance.new("TextLabel",yesBox)
yesHint.Position=UDim2.fromOffset(10,34)
yesHint.Size=UDim2.new(1,-20,0,18)
yesHint.BackgroundTransparency=1
yesHint.Text="Press 1 to enable • Level 1"
yesHint.TextColor3=Color3.fromRGB(174,174,181)
yesHint.TextSize=10
yesHint.Font=Enum.Font.Gotham
yesHint.ZIndex=252

local noBox=Instance.new("Frame",beastPrompt)
noBox.Position=UDim2.fromOffset(226,98)
noBox.Size=UDim2.fromOffset(180,67)
noBox.BackgroundColor3=NEUTRAL_BOX
noBox.BorderSizePixel=0
noBox.ZIndex=251
cr(noBox,8)
local noStroke=st(noBox,NEUTRAL_STROKE,1,.35)

local noKey=Instance.new("TextLabel",noBox)
noKey.Position=UDim2.fromOffset(10,7)
noKey.Size=UDim2.new(1,-20,0,25)
noKey.BackgroundTransparency=1
noKey.Text="[ 2 ]  NO"
noKey.TextColor3=WHITE
noKey.TextSize=14
noKey.Font=Enum.Font.GothamBold
noKey.ZIndex=252

local noHint=Instance.new("TextLabel",noBox)
noHint.Position=UDim2.fromOffset(10,34)
noHint.Size=UDim2.new(1,-20,0,18)
noHint.BackgroundTransparency=1
noHint.Text="Press 2 to leave it OFF"
noHint.TextColor3=Color3.fromRGB(174,174,181)
noHint.TextSize=10
noHint.Font=Enum.Font.Gotham
noHint.ZIndex=252

local beastPromptActive=false
local beastPromptLocked=false
local beastPromptAskedThisRound=false
local beastPromptInputArmed=false
local beastPromptShownAt=0
local wasInBeastRound=false

local function localPlayerIsBeast()
 return player:GetAttribute("Beast")==true
end

local function inBeastRound()
 local state=ReplicatedStorage:FindFirstChild("State")
 return state~=nil and state.Value=="Round" and localPlayerIsBeast()
end

-- FTF can already parent Hammer during the Beast power/head-start screen.
-- Do NOT treat Hammer alone as "live gameplay". The power picker must be gone too.
local function beastPickerIsClosed()
 local pg=player:FindFirstChildOfClass("PlayerGui")
 local picker=pg and pg:FindFirstChild("BeastPowers")
 return picker==nil or picker.Enabled==false
end

local function hasLiveBeastGameplay()
 if not inBeastRound() or not beastPickerIsClosed() then return false end
 local char=player.Character
 if not char or not char.Parent then return false end
 local hammer=char:FindFirstChild("Hammer")
 if not hammer or hammer.Parent~=char then return false end

 -- These are the same pieces Main.Beast expects before wiring live hammer controls.
 local humanoid=char:FindFirstChildOfClass("Humanoid")
 local attack=hammer:FindFirstChild("Attack")
 local cooldown=hammer:FindFirstChild("Cooldown")
 return humanoid~=nil and attack~=nil and cooldown~=nil
end

local function resetPromptChoiceVisuals()
 yesBox.BackgroundColor3=NEUTRAL_BOX
 noBox.BackgroundColor3=NEUTRAL_BOX
 yesStroke.Color=NEUTRAL_STROKE
 noStroke.Color=NEUTRAL_STROKE
 yesStroke.Transparency=.35
 noStroke.Transparency=.35
 yesStroke.Thickness=1
 noStroke.Thickness=1
 yesKey.TextColor3=WHITE
 noKey.TextColor3=WHITE
end

local function hideBeastPrompt()
 beastPromptActive=false
 beastPromptLocked=false
 beastPromptInputArmed=false
 beastPrompt.Visible=false
 resetPromptChoiceVisuals()
end

local function showBeastPrompt()
 if beastPromptActive or beastPromptAskedThisRound or hitboxLevel~=0 then return end
 beastPromptAskedThisRound=true
 beastPromptActive=true
 beastPromptLocked=false
 beastPromptInputArmed=false
 beastPromptShownAt=os.clock()
 resetPromptChoiceVisuals()
 beastPrompt.Visible=true
 beastPrompt.Size=UDim2.fromOffset(410,176)
 beastPrompt.BackgroundTransparency=.35
 TweenService:Create(beastPrompt,TweenInfo.new(.18,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{
  Size=UDim2.fromOffset(430,190),
  BackgroundTransparency=.04
 }):Play()
 task.delay(.35,function()
  if beastPromptActive and not beastPromptLocked and os.clock()-beastPromptShownAt>=.3 then
   beastPromptInputArmed=true
  end
 end)
end

local function confirmPromptChoice(choseYes)
 if beastPromptLocked then return end
 beastPromptLocked=true
 click()
 local chosenBox=choseYes and yesBox or noBox
 local chosenStroke=choseYes and yesStroke or noStroke
 resetPromptChoiceVisuals()
 chosenBox.BackgroundColor3=SELECTED_BOX
 chosenStroke.Color=Color3.fromRGB(255,70,82)
 chosenStroke.Thickness=2
 chosenStroke.Transparency=0
 if choseYes then
  yesKey.TextColor3=WHITE
 else
  noKey.TextColor3=WHITE
 end
 if choseYes and setHitboxLevel then
  setHitboxLevel(1)
 end
 task.delay(.4,function()
  if beastPromptActive then hideBeastPrompt() end
 end)
end

local beastPromptKeyConn=UIS.InputBegan:Connect(function(input,gpe)
 if not beastPromptActive or beastPromptLocked or not beastPromptInputArmed or gpe then return end
 if input.KeyCode==Enum.KeyCode.One or input.KeyCode==Enum.KeyCode.KeypadOne then
  confirmPromptChoice(true)
 elseif input.KeyCode==Enum.KeyCode.Two or input.KeyCode==Enum.KeyCode.KeypadTwo then
  confirmPromptChoice(false)
 end
end)

-- Picker-safe gameplay gate:
-- State == Round + Beast + BeastPowers picker CLOSED + live Hammer control pieces.
-- Hammer alone is intentionally insufficient because FTF gives it to Beast during head start.
local beastPromptMonitorConn=RunService.Heartbeat:Connect(function()
 local beastRound=inBeastRound()

 if beastRound and not wasInBeastRound then
  beastPromptAskedThisRound=false
 end

 if beastRound and not beastPromptAskedThisRound and hitboxLevel==0 and hasLiveBeastGameplay() then
  showBeastPrompt()
 end

 if not beastRound and wasInBeastRound then
  hideBeastPrompt()
  beastPromptAskedThisRound=false
 end

 wasInBeastRound=beastRound
end)

local autoBtn=feature(util,"Auto Save",{"OFF","ON"})
autoBtn.MouseButton1Click:Connect(function()
 task.defer(function()
  saveEnabled=autoBtn.Text=="ON"
  save.BackgroundColor3=saveEnabled and RED or Color3.fromRGB(55,55,60)
  save.TextColor3=saveEnabled and WHITE or Color3.fromRGB(125,125,132)
  save.AutoButtonColor=saveEnabled
 end)
end)


-- Settings: image selector + Saint's Music
local settings=page("Settings","SETTINGS")

local imageTitle=Instance.new("TextLabel",settings)
imageTitle.Size=UDim2.new(1,0,0,22); imageTitle.BackgroundTransparency=1
imageTitle.Text="HUB IMAGE"; imageTitle.TextXAlignment=Enum.TextXAlignment.Left
imageTitle.TextColor3=WHITE; imageTitle.TextSize=11; imageTitle.Font=Enum.Font.GothamBold; imageTitle.ZIndex=13

local imageBox=Instance.new("Frame",settings)
imageBox.Size=UDim2.new(1,0,0,150); imageBox.BackgroundColor3=Color3.fromRGB(17,17,21)
imageBox.BackgroundTransparency=.08; imageBox.BorderSizePixel=0; imageBox.ZIndex=12; cr(imageBox,7)
local imageBtns={}
local imageCount=#images
local cols=4
local thumbW=76
local thumbH=50
local cellW=84
local cellH=67
local startX=8
local startY=9

for i=1,imageCount do
 local idx=i-1
 local col=idx%cols
 local rowIndex=math.floor(idx/cols)

 local b=Instance.new("ImageButton",imageBox)
 b.Position=UDim2.fromOffset(startX+col*cellW,startY+rowIndex*cellH)
 b.Size=UDim2.fromOffset(thumbW,thumbH)
 b.BackgroundColor3=Color3.fromRGB(25,25,29); b.BorderSizePixel=0
 b.Image=images[i]; b.ScaleType=Enum.ScaleType.Crop; b.ZIndex=14; cr(b,7)

 local ss=st(b,i==selectedHubImage and RED or Color3.fromRGB(65,65,72),i==selectedHubImage and 2 or 1)
 imageBtns[i]={b,ss}

 local lab=Instance.new("TextLabel",imageBox)
 lab.Position=UDim2.fromOffset(startX+col*cellW,startY+rowIndex*cellH+52)
 lab.Size=UDim2.fromOffset(thumbW,12)
 lab.BackgroundTransparency=1
 lab.Text=i==1 and "DEFAULT" or ("IMAGE "..i)
 lab.TextColor3=MUTED; lab.TextSize=7; lab.Font=Enum.Font.GothamBold; lab.ZIndex=14

 b.MouseButton1Click:Connect(function()
  click()
  selectedHubImage=i
  saveHubImage(i)
  art.Image=images[i]
  art.AnchorPoint=Vector2.new(0,0)

  if i==4 then
   -- Preserve the approved Image 4 framing behavior for its replacement asset.
   art.Position=UDim2.new(0,-17,0,-11)
   art.Size=UDim2.new(1,34,1,22)
  else
   art.Position=UDim2.new(0,0,0,0)
   art.Size=UDim2.new(1,0,1,0)
  end
  art.ScaleType=Enum.ScaleType.Crop

  for j,x in ipairs(imageBtns) do
   x[2].Color=j==i and RED or Color3.fromRGB(65,65,72)
   x[2].Thickness=j==i and 2 or 1
  end
 end)
end

-- Private Chat: dedicated Settings toggle.
-- Do not use feature() here: chat lifecycle and visual state must change atomically.
local privateChatRow=select(1,row(settings,"Private Chat"))
local privateChatToggle=Instance.new("TextButton",privateChatRow)
privateChatToggle.AnchorPoint=Vector2.new(1,.5)
privateChatToggle.Position=UDim2.new(1,-9,.5,0)
privateChatToggle.Size=UDim2.fromOffset(105,30)
privateChatToggle.BorderSizePixel=0
privateChatToggle.TextSize=10
privateChatToggle.Font=Enum.Font.GothamBold
privateChatToggle.ZIndex=14
privateChatToggle.AutoButtonColor=false
cr(privateChatToggle,7)

local function refreshPrivateChatSetting()
 privateChatToggle.Text=privateChatEnabled and "ON" or "OFF"
 privateChatToggle.BackgroundColor3=privateChatEnabled and RED or OFF
 privateChatToggle.TextColor3=privateChatEnabled and WHITE or MUTED
end

privateChatEnabled=false
refreshPrivateChatSetting()

privateChatToggle.MouseButton1Click:Connect(function()
 click()

 if privateChatEnabled then
  -- OFF feedback is immediate too.
  privateChatEnabled=false
  refreshPrivateChatSetting()
  task.defer(stopPrivateChat)
  return
 end

 -- Flip the Hub control immediately; do not wait for relay/network startup.
 privateChatEnabled=true
 refreshPrivateChatSetting()

 task.defer(function()
  if not privateChatEnabled then return end
  if not startPrivateChat() then
   -- Only roll back if V20 itself fails to initialize.
   privateChatEnabled=false
   refreshPrivateChatSetting()
  end
 end)
end)

local musicTitle=Instance.new("TextLabel",settings)
musicTitle.Size=UDim2.new(1,0,0,25); musicTitle.BackgroundTransparency=1

musicTitle.Text="SAINT'S MUSIC  //  LOBBY ONLY"; musicTitle.TextXAlignment=Enum.TextXAlignment.Left
musicTitle.TextColor3=WHITE; musicTitle.TextSize=11; musicTitle.Font=Enum.Font.GothamBold; musicTitle.ZIndex=13

local musicBox=Instance.new("Frame",settings)
musicBox.Size=UDim2.new(1,0,0,248); musicBox.BackgroundColor3=Color3.fromRGB(12,12,16)
musicBox.BackgroundTransparency=.04; musicBox.BorderSizePixel=0; musicBox.ZIndex=12; cr(musicBox,8)
st(musicBox,Color3.fromRGB(100,100,110),1,.68)

local now=Instance.new("TextLabel",musicBox)
now.Position=UDim2.fromOffset(14,10); now.Size=UDim2.new(1,-145,0,18)
now.BackgroundTransparency=1; now.Text="NO TRACK SELECTED"; now.TextXAlignment=Enum.TextXAlignment.Left
now.TextColor3=WHITE; now.TextSize=9; now.Font=Enum.Font.GothamBold; now.ZIndex=14
now.TextTruncate=Enum.TextTruncate.AtEnd

local status=Instance.new("TextLabel",musicBox)
status.Position=UDim2.fromOffset(14,29); status.Size=UDim2.new(1,-28,0,16)
status.BackgroundTransparency=1; status.Text="CUSTOM MUSIC OFF  //  SELECTING DOES NOT ENABLE"
status.TextXAlignment=Enum.TextXAlignment.Left; status.TextColor3=MUTED
status.TextSize=8; status.Font=Enum.Font.Gotham; status.ZIndex=14

local enable=Instance.new("TextButton",musicBox)
enable.AnchorPoint=Vector2.new(1,0); enable.Position=UDim2.new(1,-12,0,10)
enable.Size=UDim2.fromOffset(86,29); enable.BackgroundColor3=OFF; enable.BorderSizePixel=0
enable.Text="OFF"; enable.TextColor3=MUTED; enable.TextSize=9; enable.Font=Enum.Font.GothamBold
enable.ZIndex=15; cr(enable,6)

local prev=Instance.new("TextButton",musicBox)
prev.Position=UDim2.fromOffset(14,53); prev.Size=UDim2.fromOffset(38,29)
prev.BackgroundColor3=Color3.fromRGB(29,29,35); prev.BorderSizePixel=0
prev.Text="|<"; prev.TextColor3=WHITE; prev.Font=Enum.Font.GothamBold; prev.TextSize=10; prev.ZIndex=15; cr(prev,6)

local play=Instance.new("TextButton",musicBox)
play.Position=UDim2.fromOffset(58,53); play.Size=UDim2.fromOffset(55,29)
play.BackgroundColor3=RED; play.BorderSizePixel=0; play.Text="PLAY"
play.TextColor3=WHITE; play.Font=Enum.Font.GothamBold; play.TextSize=9; play.ZIndex=15; cr(play,6)

local nxt=Instance.new("TextButton",musicBox)
nxt.Position=UDim2.fromOffset(119,53); nxt.Size=UDim2.fromOffset(38,29)
nxt.BackgroundColor3=Color3.fromRGB(29,29,35); nxt.BorderSizePixel=0
nxt.Text=">|"; nxt.TextColor3=WHITE; nxt.Font=Enum.Font.GothamBold; nxt.TextSize=10; nxt.ZIndex=15; cr(nxt,6)

local shuffle=Instance.new("TextButton",musicBox)
shuffle.Position=UDim2.fromOffset(174,53); shuffle.Size=UDim2.fromOffset(82,29)
shuffle.BackgroundColor3=Color3.fromRGB(29,29,35); shuffle.BorderSizePixel=0
shuffle.Text="SHUFFLE"; shuffle.TextColor3=MUTED; shuffle.Font=Enum.Font.GothamBold
shuffle.TextSize=8; shuffle.ZIndex=15; cr(shuffle,6)
local progress=Instance.new("Frame",musicBox)
progress.Position=UDim2.fromOffset(14,90); progress.Size=UDim2.new(1,-28,0,4)
progress.BackgroundColor3=Color3.fromRGB(53,53,60); progress.BorderSizePixel=0; progress.ZIndex=14; cr(progress,99)
local progressFill=Instance.new("Frame",progress)
progressFill.Size=UDim2.fromScale(0,1); progressFill.BackgroundColor3=RED
progressFill.BorderSizePixel=0; progressFill.ZIndex=15; cr(progressFill,99)

local library=Instance.new("ScrollingFrame",musicBox)
library.Position=UDim2.fromOffset(10,103); library.Size=UDim2.new(1,-20,1,-113)
library.BackgroundTransparency=1; library.BorderSizePixel=0; library.ScrollBarThickness=3
library.ScrollBarImageColor3=RED; library.AutomaticCanvasSize=Enum.AutomaticSize.Y
library.CanvasSize=UDim2.new(); library.ZIndex=13
local libLayout=Instance.new("UIListLayout",library)
libLayout.Padding=UDim.new(0,4); libLayout.SortOrder=Enum.SortOrder.LayoutOrder

local tracks={
 "Black Eyed Peas - Meet Me Halfway .mp3",
 "50 Cent - 21 Questions .mp3",
 "Alice Deejay - Better Off Alone .mp3",
 "Amaarae - SAD GIRLZ LUV MONEY Remix ft Kali Uchis .mp3",
 "Arash feat. Helena - Broken Angel .mp3",
 "ARIA VEGA, Ryan Castro - CHÉVERE .mp3",
 "Ava Max - Sweet but Psycho .mp3",
 "Aventura - Dile Al Amor .mp3",
 "Bad Romance (ELECTRIC) .mp3",
 "Beny JR - Luna Llena .mp3",
 "BENY JR - VALKYRIE .mp3",
 "bleood - on E .mp3",
 "Casper TNG & 100bandplan - The Market .mp3",
 "Casper TNG - Know Me .mp3",
 "Chief Keef - Save Me .mp3",
 "Childish Gambino - Heartbeat .mp3",
 "Chris Isaak - Wicked Game .mp3",
 "Chris Travis - Smoke That Shit .mp3",
 "Chris Travis - Where My Money.mp3",
 "Clarent, Omar Courtz - Ojos Brujos .mp3",
 "D-Block Europe x Morad x Big Papa313 - SEPA .mp3",
 "David Guetta - Sexy Bitch .mp3",
 "Deftones - Cherry Waves .mp3",
 "Deftones – Risk .mp3",
 "DELLAFUENTE & Morad - Manos Rotas .mp3",
 "Disclosure - Latch ft. Sam Smith .mp3",
 "Drake & Lil Wayne - Love Me .mp3",
 "Drake & PND - Wednesday Night Interlude .mp3",
 "Drake - Best I Ever Had .mp3",
 "Drake - Don’t Worry .mp3",
 "Drake - Fancy .mp3",
 "Drake - Headlines .mp3",
 "Drake - Nonstop .mp3",
 "Drake - Pipe Down .mp3",
 "Drake - Practice .mp3",
 "Drake - Trust Issues .mp3",
 "Drake, 21 Savage - Rich Flex .mp3",
 "Edward Maya, Vika Jigulina - Stereo love .mp3",
 "Enrique Iglesias - Bailando .mp3",
 "Enrique Iglesias - DUELE EL CORAZON .mp3",
 "G O D D E S S - Omar Courtz .mp3",
 "Gazo - FIESTA feat. Morad .mp3",
 "George Michael - Cowboys and Angels .mp3",
 "Gorillaz, Kali Uchis - She's My Collar .mp3",
 "i kno u kno wat u did.mp3",
 "Imany - Don't Be So Shy (Filatov & Karas Remix) .mp3",
 "Jay Wheeler, Omar Courtz - De Lejitos Remix .mp3",
 "Jugohoe - Hittin Low .mp3",
 "Jugohoe - Ready To Go (feat. Xaviersobased) .mp3",
 "Kavinsky - Odd Look (ft. The Weeknd) .mp3",
 "Ken Carson - 2000 .mp3",
 "Ken Carson - Freestyle 2 .mp3",
 "Ken Carson - Rock N Roll .mp3",
 "Ken Carson, Playboi Carti, Destroy Lonely - Off The Meter .mp3",
 "Kendrick Lamar - Swimming Pools .mp3",
 "Key Glock - Russian Cream .mp3",
 "Kodak Black - NO FLOCKIN .mp3",
 "La Bouche - Be My Lover .mp3",
 "Legendary Lovers x Summer .mp3",
 "Lil Baby, Gunna, Drake - Never Recover .mp3",
 "Lil Tjay - F.N .mp3",
 "Lil Uzi Vert - 20 Min .mp3",
 "LONOWN - ONE SUMMER NIGHT .mp3",
 "LUCKI & F1LTHY - Where I Be .mp3",
 "LUCKI - Leave Her .mp3",
 "Lucki - New Drank .mp3",
 "LUCKI - Super Urus .mp3",
 "M83 - Midnight City .mp3",
 "Majid Jordan with Drake - Stars Align .mp3",
 "Metro Boomin - Around Me ft. Don Toliver .mp3",
 "Morad, Beny Jr, Rvfv - Lo Que Tiene .mp3",
 "Myke Towers & Quevedo - SOLEAO .mp3",
 "Myke Towers - LA CAPI .mp3",
 "Nicky Jam - Hasta El Amanecer .mp3",
 "novulent - scars .mp3",
 "OMAR COURTZ - KOKO .mp3",
 "One Of The Girls (ELECTRIC) .mp3",
 "Ozuna & Omar Courtz - ZIZI .mp3",
 "PARTYNEXTDOOR - Belong to the City .mp3",
 "PARTYNEXTDOOR - Break from Toronto .mp3",
 "PARTYNEXTDOOR - Dreamin .mp3",
 "PARTYNEXTDOOR - Some Of Your Love .mp3",
 "PARTYNEXTDOOR - TBH .mp3",
 "Playboi Carti - ALL RED .mp3",
 "Playboi Carti - HBA .mp3",
 "Playboi Carti - Over .mp3",
 "Playboi Carti - Vamp Anthem .mp3",
 "QUEVEDO - BZRP Music Sessions #52 .mp3",
 "Quevedo - Columbia .mp3",
 "R. City - Locked Away ft. Adam Levine .mp3",
 "R2 - Ruinart .mp3",
 "Rauw Alejandro - Desesperados .mp3",
 "Rihanna - Only Girl (In The World) .mp3",
 "RnBoi - MON BÉBÉ .mp3",
 "Robin Schulz - Sugar .mp3",
 "Ryan Castro - Mujeriego .mp3",
 "Sade - Paradise .mp3",
 "Saint Levant, Fares Sokar - DO YOU LOVE ME .mp3",
 "Sasy - Gentleman .mp3",
 "Selena Gomez - Love You Like a Love Song .mp3",
 "Shakira & Burna Boy - Dai Dai .mp3",
 "siah - ilu .mp3",
 "Side To Side (ELECTRIC) .mp3",
 "Snow Strippers - Aching Like It's .mp3",
 "Snow Strippers - Just Your Doll .mp3",
 "Snow Strippers - Stab The Voice .mp3",
 "SNOW STRIPPERS - UNDER YOUR SPELL .mp3",
 "Stop Waiting - Cigarettes After Sex .mp3",
 "Suki Waterhouse - Good Looking .mp3",
 "Tears For Fears - Everybody Wants To Rule The World .mp3",
 "The Neighbourhood - Sweater Weather .mp3",
 "The Noise - X-Ray .mp3",
 "The Weeknd & Playboi Carti - Timeless .mp3",
 "The Weeknd - Adaptation .mp3",
 "The Weeknd - Belong To The World .mp3",
 "The Weeknd - Coming Down .mp3",
 "The Weeknd - House Of Balloons Glass Table Girls .mp3",
 "The Weeknd - In The Night .mp3",
 "The Weeknd - Kiss Land .mp3",
 "The Weeknd - Lost in the Fire ft. Gesaffelstein .mp3",
 "The Weeknd - Love In The Sky .mp3",
 "The Weeknd - Montreal .mp3",
 "The Weeknd - Niagara Falls .mp3",
 "The Weeknd - Out of Time .mp3",
 "The Weeknd - Pretty .mp3",
 "The Weeknd - Professional .mp3",
 "The Weeknd - Tears In The Rain .mp3",
 "The Weeknd - The Birds Pt 1 .mp3",
 "The Weeknd - The Birds Pt 2 .mp3",
 "The Weeknd - The Town .mp3",
 "The Weeknd - Wicked Games .mp3",
 "The Weeknd, JENNIE & Lily Rose Depp - One Of The Girls .mp3",
 "Tory Lanez - Lavender Sunflower .mp3",
 "TV Girl - Cigarettes out the Window .mp3",
 "TV Girl - Daughter of a Cop .mp3",
 "TV Girl - Lovers Rock .mp3",
 "TV Girl - The Blonde .mp3",
 "twentythree - Queen St .mp3",
 "Violet Indiana - Killer Eyes .mp3",
 "whatsaheart & removeface - sharp fangs .mp3",
 "whatsaheart - ALL MINE .mp3",
 "whatsaheart - for her .mp3",
 "whatsaheart - LIE .mp3",
 "whatsaheart - sky (falling for you) .mp3",
 "xaviersobased - love hate .mp3",
 "XXXTENTACION & MATT OX - $$$ .mp3",
 "Yandel - Encantadora .mp3",
 "Yeat - Double .mp3",
 "Young Cister - QLOO .mp3",
 "YoungBoy Never Broke Again - Make No Sense .mp3",
}

local musicSound=Instance.new("Sound",SoundService)
musicSound.Name="SaintsHubLobbyMusic"; musicSound.Volume=1; musicSound.Looped=false

-- Saint's Music always starts OFF on fresh execution.
-- Selecting a song while OFF only selects/loads it; it never enables playback.
local musicEnabled=false
local currentTrack=0
local trackButtons={}
local shuffleEnabled=false
local shuffleBag={}
local shuffleBagPos=1

local function rebuildShuffleBag(excludeTrack)
 shuffleBag={}
 for i=1,#tracks do
  if i~=excludeTrack then table.insert(shuffleBag,i) end
 end
 for i=#shuffleBag,2,-1 do
  local j=math.random(1,i)
  shuffleBag[i],shuffleBag[j]=shuffleBag[j],shuffleBag[i]
 end
 shuffleBagPos=1
end

local function nextShuffledTrack()
 if #tracks<=1 then return currentTrack>0 and currentTrack or 1 end
 if shuffleBagPos>#shuffleBag or #shuffleBag==0 then
  rebuildShuffleBag(currentTrack)
 end
 local target=shuffleBag[shuffleBagPos]
 shuffleBagPos=shuffleBagPos+1
 return target
end

local userPaused=false
local pausedForRound=false
local wasRound=false
local resetMiniProgressVisual=function() end

local customAsset=(getcustomasset or (getgenv and getgenv().getcustomasset))
local isFile=(isfile or (getgenv and getgenv().isfile))

local function prettyName(s)
 return (s:gsub("%.mp3$",""):gsub("%s+$",""))
end

local function resolveFile(name)
 if type(isFile)~="function" then return nil end
 local compact=name:gsub("%s+%.mp3$",".mp3")
 local spaced=name:gsub("%.mp3$"," .mp3")
 local candidates={
  name,compact,spaced,
  "SaintsHubMusic/"..name,"SaintsHubMusic/"..compact,"SaintsHubMusic/"..spaced,
  "saints_hub_music/"..name,"saints_hub_music/"..compact,"saints_hub_music/"..spaced,
  "workspace/"..name,"workspace/"..compact,"workspace/"..spaced
 }
 for _,p in ipairs(candidates) do
  local ok,yes=pcall(isFile,p)
  if ok and yes then return p end
 end

 -- Volt fallback: tolerate filename case and a space before ".mp3".
 if type(listfiles)=="function" then
  local wanted=compact:lower()
  local ok,files=pcall(listfiles,"SaintsHubMusic")
  if ok and type(files)=="table" then
   for _,p in ipairs(files) do
    local normalized=tostring(p):gsub("\\","/")
    local base=normalized:match("([^/]+)$") or normalized
    local compare=base:gsub("%s+%.mp3$",".mp3"):lower()
    if compare==wanted then return p end

    -- Bailando-specific robust match: ignore punctuation/spacing differences
    -- and return the exact path reported by Volt's SaintsHubMusic folder.
    if wanted=="enrique iglesias - bailando.mp3" then
     local loose=base:lower():gsub("%.mp3$",""):gsub("[^%w]","")
     if loose=="enriqueiglesiasbailando" then return p end
    end
   end
  end
 end
 return nil
end

local function updateTrackButtons()
 for i,b in ipairs(trackButtons) do
  local active=i==currentTrack
  b.BackgroundColor3=active and Color3.fromRGB(49,16,22) or Color3.fromRGB(21,21,26)
  local rail=b:FindFirstChild("Rail")
  if rail then rail.BackgroundTransparency=active and 0 or 1 end
 end
end

-- FTF round-state helper. We intentionally pause the existing Sound instead of
-- stopping/reloading it, so TimePosition survives the whole round.
-- Performance: cache FTF round-state discovery instead of scanning all of
-- ReplicatedStorage every rendered frame. Calls remain API-compatible everywhere.
local cachedRoundState=false
local lastRoundScan=0
local ROUND_SCAN_INTERVAL=.12

local function scanRoundState()
 local candidates={
  ReplicatedStorage:FindFirstChild("State"),
  workspace:FindFirstChild("State"),
  player:FindFirstChild("State"),
 }
 for _,obj in ipairs(candidates) do
  if obj and obj:IsA("ValueBase") then
   local ok,v=pcall(function() return obj.Value end)
   if ok then
    if typeof(v)=="string" and string.lower(v)=="round" then return true end
    if typeof(v)=="boolean" and v then return true end
   end
  end
 end
 for _,obj in ipairs(ReplicatedStorage:GetDescendants()) do
  if obj.Name=="State" and obj:IsA("ValueBase") then
   local ok,v=pcall(function() return obj.Value end)
   if ok and typeof(v)=="string" and string.lower(v)=="round" then return true end
  end
 end
 return false
end

local function readRoundState(force)
 local nowClock=os.clock()
 if force or nowClock-lastRoundScan>=ROUND_SCAN_INTERVAL then
  lastRoundScan=nowClock
  cachedRoundState=scanRoundState()
 end
 return cachedRoundState
end

local function loadTrack(i,autoPlay)
 if #tracks==0 then return end
 if i<1 then i=#tracks elseif i>#tracks then i=1 end
 currentTrack=i
 local filename=tracks[i]
 now.Text=prettyName(filename):upper()
 updateTrackButtons()

 -- Every new selection starts both music UIs at 0:00 immediately.
 progressFill.Size=UDim2.fromScale(0,1)
 resetMiniProgressVisual()

 local path=resolveFile(filename)
 if not path then
  status.Text="FILE NOT FOUND IN VOLT"
  musicSound:Stop(); musicSound.SoundId=""; play.Text="PLAY"
  return
 end
 if type(customAsset)~="function" then
  status.Text="GETCUSTOMASSET UNAVAILABLE"
  return
 end

 local ok,asset=pcall(customAsset,path)
 if not ok then
  status.Text="LOAD ERROR  //  "..tostring(asset)
  return
 end

 musicSound:Stop()
 musicSound.SoundId=asset

 -- A manual seek on the previous song can carry across a local SoundId swap.
 -- Reset only when loading/selecting a new track; normal pause/resume keeps position.
 pcall(function() musicSound.TimePosition=0 end)

 userPaused=false
 pausedForRound=false

 if autoPlay and musicEnabled and not readRoundState() then
  -- Reassert 0:00 immediately before the proven direct Play() transition.
  pcall(function() musicSound.TimePosition=0 end)
  musicSound:Play()
  play.Text="PAUSE"
  status.Text="PLAYING  //  LOBBY ONLY"
 elseif musicEnabled and readRoundState() then
  play.Text="PLAY"
  status.Text="SELECTED  //  WAITING FOR LOBBY"
 else
  play.Text="PLAY"
  status.Text=musicEnabled and "SELECTED  //  READY" or "SELECTED  //  MUSIC OFF"
 end
end

for i,name in ipairs(tracks) do
 local b=Instance.new("TextButton",library)
 b.Size=UDim2.new(1,-4,0,38); b.BackgroundColor3=Color3.fromRGB(21,21,26)
 b.BackgroundTransparency=.05; b.BorderSizePixel=0; b.Text=""
 b.ZIndex=14; cr(b,6); trackButtons[i]=b
 local rail=Instance.new("Frame",b); rail.Name="Rail"; rail.Size=UDim2.fromOffset(2,17)
 rail.Position=UDim2.fromOffset(0,10); rail.BackgroundColor3=RED
 rail.BackgroundTransparency=1; rail.BorderSizePixel=0; rail.ZIndex=16; cr(rail,99)
 local num=Instance.new("TextLabel",b); num.Position=UDim2.fromOffset(9,0); num.Size=UDim2.fromOffset(22,38)
 num.BackgroundTransparency=1; num.Text=string.format("%02d",i); num.TextColor3=Color3.fromRGB(125,125,134)
 num.TextSize=9; num.Font=Enum.Font.GothamBold; num.ZIndex=15
 local txt=Instance.new("TextLabel",b); txt.Position=UDim2.fromOffset(37,0); txt.Size=UDim2.new(1,-45,1,0)
 txt.BackgroundTransparency=1; txt.Text=prettyName(name); txt.TextXAlignment=Enum.TextXAlignment.Left
 txt.TextColor3=Color3.fromRGB(235,235,239); txt.TextSize=10; txt.Font=Enum.Font.GothamMedium; txt.ZIndex=15
 b.MouseButton1Click:Connect(function()
  click()
  -- OFF: select only. ON: selection starts the chosen song in lobby.
  loadTrack(i,musicEnabled)
 end)
end


-- Gameplay mini-player (isolated): all construction is protected so it can never
-- prevent the main Saint's Hub from finishing initialization.
local mini,miniSong,miniSeek,miniSeekFill,miniKnob,miniTime
local miniPrev,miniReplay,miniPlay,miniNext,miniShuffle
local miniSeeking=false

local function miniFmt(sec)
 sec=math.max(0,math.floor(tonumber(sec) or 0))
 return string.format("%d:%02d",math.floor(sec/60),sec%60)
end

local miniBuilt=false
local miniBuildOk=pcall(function()
 mini=Instance.new("Frame")
 mini.Name="SaintsMusicGameplayPlayer"
 mini.AnchorPoint=Vector2.new(1,0)
 mini.Position=UDim2.new(1,-8,0,470)
 mini.Size=UDim2.fromOffset(214,122)
 mini.BackgroundColor3=Color3.fromRGB(8,8,11)
 mini.BackgroundTransparency=.05
 mini.BorderSizePixel=0
 mini.Visible=false
 mini.ZIndex=40
 mini.Parent=gui
 cr(mini,9); st(mini,Color3.fromRGB(125,125,135),1,.45)

 local topRail=Instance.new("Frame",mini)
 topRail.Size=UDim2.new(1,0,0,3); topRail.BackgroundColor3=RED
 topRail.BorderSizePixel=0; topRail.ZIndex=41; cr(topRail,9)

 local mt=Instance.new("TextLabel",mini)
 mt.Position=UDim2.fromOffset(10,8); mt.Size=UDim2.new(1,-20,0,16)
 mt.BackgroundTransparency=1; mt.Text="SAINT'S MUSIC"; mt.TextColor3=WHITE
 mt.Font=Enum.Font.GothamBold; mt.TextSize=10; mt.TextXAlignment=Enum.TextXAlignment.Left; mt.ZIndex=41

 miniSong=Instance.new("TextLabel",mini)
 miniSong.Position=UDim2.fromOffset(10,26); miniSong.Size=UDim2.new(1,-20,0,17)
 miniSong.BackgroundTransparency=1; miniSong.Text="NO SONG SELECTED"; miniSong.TextColor3=MUTED
 miniSong.Font=Enum.Font.GothamMedium; miniSong.TextSize=9
 miniSong.TextXAlignment=Enum.TextXAlignment.Left; miniSong.TextTruncate=Enum.TextTruncate.AtEnd; miniSong.ZIndex=41

 miniSeek=Instance.new("TextButton",mini)
 miniSeek.Position=UDim2.fromOffset(10,49); miniSeek.Size=UDim2.new(1,-20,0,7)
 miniSeek.BackgroundColor3=Color3.fromRGB(52,52,59); miniSeek.BorderSizePixel=0
 miniSeek.Text=""; miniSeek.AutoButtonColor=false; miniSeek.ZIndex=42; cr(miniSeek,99)

 miniSeekFill=Instance.new("Frame",miniSeek)
 miniSeekFill.Size=UDim2.fromScale(0,1); miniSeekFill.BackgroundColor3=RED
 miniSeekFill.BorderSizePixel=0; miniSeekFill.ZIndex=43; cr(miniSeekFill,99)

 miniKnob=Instance.new("Frame",miniSeek)
 miniKnob.AnchorPoint=Vector2.new(.5,.5); miniKnob.Position=UDim2.fromScale(0,.5)
 miniKnob.Size=UDim2.fromOffset(10,10); miniKnob.BackgroundColor3=WHITE
 miniKnob.BorderSizePixel=0; miniKnob.ZIndex=44; cr(miniKnob,99)

 miniTime=Instance.new("TextLabel",mini)
 miniTime.Position=UDim2.fromOffset(10,59); miniTime.Size=UDim2.new(1,-20,0,12)
 miniTime.BackgroundTransparency=1; miniTime.Text="0:00 / 0:00"
 miniTime.TextColor3=Color3.fromRGB(155,155,164); miniTime.Font=Enum.Font.Gotham
 miniTime.TextSize=8; miniTime.TextXAlignment=Enum.TextXAlignment.Right; miniTime.ZIndex=41

 local function mb(x,w,text)
  local b=Instance.new("TextButton",mini)
  b.Position=UDim2.fromOffset(x,78); b.Size=UDim2.fromOffset(w,31)
  b.BackgroundColor3=Color3.fromRGB(27,27,33); b.BorderSizePixel=0
  b.Text=text; b.TextColor3=WHITE; b.Font=Enum.Font.GothamBold; b.TextSize=9
  b.AutoButtonColor=false; b.ZIndex=45; cr(b,6)
  return b
 end
 miniPrev=mb(10,32,"|<")
 miniReplay=mb(47,32,"R")
 miniPlay=mb(84,43,"PLAY"); miniPlay.BackgroundColor3=RED
 miniNext=mb(132,32,">|")
 miniShuffle=mb(169,35,"SHF"); miniShuffle.TextColor3=MUTED
 miniBuilt=true
end)

resetMiniProgressVisual=function()
 if not miniBuilt then return end
 miniSeeking=false
 pcall(function()
  miniSeekFill.Size=UDim2.fromScale(0,1)
  miniKnob.Position=UDim2.fromScale(0,.5)
  miniTime.Text="0:00 / 0:00"
 end)
end

local function refreshGameplayMusic()
 if not miniBuilt then return end
 mini.Visible=musicEnabled
 miniPlay.Text=musicSound.Playing and "PAUSE" or "PLAY"
 miniSong.Text=currentTrack>0 and prettyName(tracks[currentTrack] or ""):upper() or "NO SONG SELECTED"
 miniShuffle.BackgroundColor3=shuffleEnabled and RED or Color3.fromRGB(27,27,33)
 miniShuffle.TextColor3=shuffleEnabled and WHITE or MUTED
 miniShuffle.Text=shuffleEnabled and "SHF*" or "SHF"
end

enable.MouseButton1Click:Connect(function()
 click()
 musicEnabled=not musicEnabled
 enable.Text=musicEnabled and "ON" or "OFF"
 enable.BackgroundColor3=musicEnabled and RED or OFF
 enable.TextColor3=musicEnabled and WHITE or MUTED
 refreshGameplayMusic()

 if musicEnabled then
  -- Enabling alone NEVER chooses a song and NEVER auto-plays Track 1.
  if currentTrack==0 or musicSound.SoundId=="" then
   status.Text="MUSIC ON  //  SELECT A SONG"
   play.Text="PLAY"
  elseif readRoundState() then
   status.Text="MUSIC ON  //  WAITING FOR LOBBY"
   play.Text="PLAY"
  else
   status.Text="MUSIC ON  //  PRESS PLAY OR SELECT A SONG"
   play.Text="PLAY"
  end
 else
  if musicSound.Playing then musicSound:Pause() end
  pausedForRound=false
  userPaused=false
  play.Text="PLAY"
  status.Text=currentTrack>0 and "CUSTOM MUSIC OFF  //  TRACK SELECTED" or "CUSTOM MUSIC OFF"
 end
end)

play.MouseButton1Click:Connect(function()
 click()
 -- Play button never auto-selects a track and never bypasses the master switch.
 if not musicEnabled then
  status.Text="TURN SAINT'S MUSIC ON FIRST"
  return
 end
 if currentTrack==0 or musicSound.SoundId=="" then
  status.Text="SELECT A SONG FIRST"
  return
 end
 if readRoundState() then
  status.Text="LOBBY ONLY  //  RESUMES AFTER ROUND"
  return
 end

 if musicSound.Playing then
  musicSound:Pause()
  userPaused=true
  pausedForRound=false
  play.Text="PLAY"
  status.Text="PAUSED"
 else
  -- Resume preserves the exact position of a paused selected track.
  musicSound:Resume()
  userPaused=false
  pausedForRound=false
  play.Text="PAUSE"
  status.Text="PLAYING  //  LOBBY ONLY"
 end
 refreshGameplayMusic()
end)

prev.MouseButton1Click:Connect(function()
 click()
 if currentTrack==0 then
  status.Text=musicEnabled and "SELECT A SONG FIRST" or "MUSIC OFF  //  SELECT A SONG"
  return
 end
 local target
 if shuffleEnabled and #tracks>1 then
  target=nextShuffledTrack()
 else
  target=currentTrack<=1 and #tracks or currentTrack-1
 end
 resetMiniProgressVisual()
 loadTrack(target,musicEnabled)
 refreshGameplayMusic()
end)

nxt.MouseButton1Click:Connect(function()
 click()
 if currentTrack==0 then
  status.Text=musicEnabled and "SELECT A SONG FIRST" or "MUSIC OFF  //  SELECT A SONG"
  return
 end
 local target
 if shuffleEnabled and #tracks>1 then
  target=nextShuffledTrack()
 else
  target=currentTrack>=#tracks and 1 or currentTrack+1
 end
 resetMiniProgressVisual()
 loadTrack(target,musicEnabled)
 refreshGameplayMusic()
end)

shuffle.MouseButton1Click:Connect(function()
 click()
 shuffleEnabled=not shuffleEnabled
 if shuffleEnabled then rebuildShuffleBag(currentTrack) else shuffleBag={}; shuffleBagPos=1 end
 shuffle.BackgroundColor3=shuffleEnabled and RED or Color3.fromRGB(29,29,35)
 shuffle.TextColor3=shuffleEnabled and WHITE or MUTED
 shuffle.Text=shuffleEnabled and "SHUFFLE ON" or "SHUFFLE"
 refreshGameplayMusic()
end)

musicSound.Ended:Connect(function()
 if not musicEnabled or currentTrack==0 then return end
 local finishedTrack=currentTrack
 local target
 if shuffleEnabled and #tracks>1 then
  target=nextShuffledTrack()
 else
  target=finishedTrack>=#tracks and 1 or finishedTrack+1
 end
 resetMiniProgressVisual()
 loadTrack(target,true)
 refreshGameplayMusic()
end)


-- Mini-player connections are also protected and do not affect Hub controls.
if miniBuilt then
 pcall(function()
  miniPrev.MouseButton1Click:Connect(function()
   click()
   if currentTrack==0 then return end
   miniSeeking=false
   local target
   if shuffleEnabled and #tracks>1 then
    target=nextShuffledTrack()
   else
    target=currentTrack<=1 and #tracks or currentTrack-1
   end
   resetMiniProgressVisual()
   loadTrack(target,musicEnabled)
   refreshGameplayMusic()
  end)
  miniNext.MouseButton1Click:Connect(function()
   click()
   if currentTrack==0 then return end
   miniSeeking=false
   local target
   if shuffleEnabled and #tracks>1 then
    target=nextShuffledTrack()
   else
    target=currentTrack>=#tracks and 1 or currentTrack+1
   end
   resetMiniProgressVisual()
   loadTrack(target,musicEnabled)
   refreshGameplayMusic()
  end)
  miniReplay.MouseButton1Click:Connect(function()
   click()
   if currentTrack==0 or musicSound.SoundId=="" then return end
   pcall(function() musicSound.TimePosition=0 end)
   resetMiniProgressVisual()
   if musicEnabled and not readRoundState() and not musicSound.Playing then
    pcall(function() musicSound:Resume() end); userPaused=false; pausedForRound=false
    play.Text="PAUSE"; status.Text="PLAYING  //  LOBBY ONLY"
   end
   refreshGameplayMusic()
  end)
  miniPlay.MouseButton1Click:Connect(function()
   click()
   if not musicEnabled or currentTrack==0 or musicSound.SoundId=="" or readRoundState() then return end
   if musicSound.Playing then
    musicSound:Pause()
    userPaused=true
    pausedForRound=false
    play.Text="PLAY"
    status.Text="PAUSED"
   else
    -- Resume preserves TimePosition. Do not call Play() for a paused track.
    local ok=pcall(function() musicSound:Resume() end)
    if not ok then return end
    userPaused=false
    pausedForRound=false
    play.Text="PAUSE"
    status.Text="PLAYING  //  LOBBY ONLY"
   end
   refreshGameplayMusic()
  end)
  miniShuffle.MouseButton1Click:Connect(function()
   click()
   shuffleEnabled=not shuffleEnabled
   if shuffleEnabled then rebuildShuffleBag(currentTrack) else shuffleBag={}; shuffleBagPos=1 end
   shuffle.BackgroundColor3=shuffleEnabled and RED or Color3.fromRGB(29,29,35)
   shuffle.TextColor3=shuffleEnabled and WHITE or MUTED
   shuffle.Text=shuffleEnabled and "SHUFFLE ON" or "SHUFFLE"
   refreshGameplayMusic()
  end)

  local function seekAt(x)
   if currentTrack==0 or musicSound.TimeLength<=0 then return end
   local width=math.max(1,miniSeek.AbsoluteSize.X)
   local ratio=math.clamp((x-miniSeek.AbsolutePosition.X)/width,0,1)

   -- Move the UI immediately so dragging visibly follows the cursor.
   miniSeekFill.Size=UDim2.fromScale(ratio,1)
   miniKnob.Position=UDim2.fromScale(ratio,.5)

   -- Seek the actual sound to the same percentage.
   local target=ratio*musicSound.TimeLength
   pcall(function() musicSound.TimePosition=target end)
   miniTime.Text=miniFmt(target).." / "..miniFmt(musicSound.TimeLength)
  end

  miniSeek.MouseButton1Down:Connect(function(x)
   miniSeeking=true
   seekAt(x)
  end)

  UserInputService.InputChanged:Connect(function(i)
   if miniSeeking and i.UserInputType==Enum.UserInputType.MouseMovement then
    seekAt(i.Position.X)
   end
  end)

  UserInputService.InputEnded:Connect(function(i)
   if i.UserInputType==Enum.UserInputType.MouseButton1 then
    -- The drag already updated TimePosition continuously.
    -- Release ONLY clears the seek lock so the normal 30 Hz live updater resumes.
    miniSeeking=false
   end
  end)

  -- Extra release path for the seek button itself.
  miniSeek.MouseButton1Up:Connect(function()
   miniSeeking=false
  end)
 end)
end

-- Performance: music UI does not need a full rewrite every rendered frame.
-- 20 Hz handles round/UI transitions; 30 Hz keeps progress/time extra smooth.
local roundUiAccum=0
local musicUiAccum=0
local lastHubPlayText=nil
local lastMiniPlayText=nil
local lastMiniSongText=nil
local lastMiniShuffleState=nil
local lastMiniVisible=nil

local perfConn=RunService.RenderStepped:Connect(function(dt)
 roundUiAccum=roundUiAccum+dt
 musicUiAccum=musicUiAccum+dt

 if roundUiAccum>=.05 then
  roundUiAccum=0
  local inRound=readRoundState()

  local desiredHubPlay=(musicEnabled and currentTrack>0 and musicSound.SoundId~="" and musicSound.Playing) and "PAUSE" or "PLAY"
  if desiredHubPlay~=lastHubPlayText then
   play.Text=desiredHubPlay
   lastHubPlayText=desiredHubPlay
  end

  -- Entering the map: Pause() preserves exact TimePosition.
  if inRound and not wasRound then
   if musicEnabled and currentTrack>0 and musicSound.Playing then
    musicSound:Pause()
    pausedForRound=true
    play.Text="PLAY"; lastHubPlayText="PLAY"
    status.Text="ROUND ACTIVE  //  MUSIC PAUSED"
   end

  -- Back in lobby after round end/death: resume only if the round paused it.
  elseif not inRound and wasRound then
   if musicEnabled and currentTrack>0 and musicSound.SoundId~="" and pausedForRound and not userPaused then
    pausedForRound=false
    musicSound:Resume()
    play.Text="PAUSE"; lastHubPlayText="PAUSE"
    status.Text="RESUMED  //  LOBBY ONLY"
   else
    pausedForRound=false
   end
  end
  wasRound=inRound

  if miniBuilt then
   pcall(function()
    if lastMiniVisible~=musicEnabled then
     mini.Visible=musicEnabled
     lastMiniVisible=musicEnabled
    end

    local desiredMiniPlay=musicSound.Playing and "PAUSE" or "PLAY"
    if desiredMiniPlay~=lastMiniPlayText then
     miniPlay.Text=desiredMiniPlay
     lastMiniPlayText=desiredMiniPlay
    end

    local desiredSong=currentTrack>0 and prettyName(tracks[currentTrack] or ""):upper() or "NO SONG SELECTED"
    if desiredSong~=lastMiniSongText then
     miniSong.Text=desiredSong
     lastMiniSongText=desiredSong
    end

    if shuffleEnabled~=lastMiniShuffleState then
     miniShuffle.BackgroundColor3=shuffleEnabled and RED or Color3.fromRGB(27,27,33)
     miniShuffle.TextColor3=shuffleEnabled and WHITE or MUTED
     miniShuffle.Text=shuffleEnabled and "SHF*" or "SHF"
     lastMiniShuffleState=shuffleEnabled
    end
   end)
  end
 end

 if musicUiAccum>=1/30 then
  musicUiAccum=0
  local length=musicSound.TimeLength
  if length>0 then
   local pos=musicSound.TimePosition
   local ratio=math.clamp(pos/length,0,1)
   progressFill.Size=UDim2.fromScale(ratio,1)

   if miniBuilt then
    pcall(function()
     -- Mirror the same live audio ratio used by the Hub progress bar.
     -- seekAt() moves this instantly while dragging; afterward this live updater
     -- keeps the mini-player fill/knob synchronized with musicSound.TimePosition.
     miniSeekFill.Size=UDim2.fromScale(ratio,1)
     miniKnob.Position=UDim2.fromScale(ratio,.5)
     miniTime.Text=miniFmt(pos).." / "..miniFmt(length)
    end)
   end
  else
   progressFill.Size=UDim2.fromScale(0,1)
   if miniBuilt then
    pcall(function()
     miniSeekFill.Size=UDim2.fromScale(0,1)
     miniKnob.Position=UDim2.fromScale(0,.5)
     miniTime.Text="0:00 / 0:00"
    end)
   end
  end
 end
end)

local currentPage=nil
local switching=false
local function select(name)
 if switching or currentPage==name then return end
 switching=true
 local incoming=pages[name]
 local function bringIn()
  content.Visible=true
  incoming.Visible=true
  incoming.Position=UDim2.new(0,28,0,0)
  for n,p in pairs(pages) do if n~=name then p.Visible=false end end
  for n,b in pairs(navButtons) do
  local active=n==name
  b.BackgroundColor3=active and Color3.fromRGB(42,14,19) or Color3.fromRGB(13,13,17)
  local ar=b:FindFirstChild("ActiveRail"); if ar then ar.BackgroundTransparency=active and 0 or 1 end
 end
  TweenService:Create(incoming,TweenInfo.new(.27,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Position=UDim2.new(0,0,0,0)}):Play()
  currentPage=name
  task.delay(.28,function() switching=false end)
 end
 if currentPage and pages[currentPage] and pages[currentPage].Visible then
  local old=pages[currentPage]
  TweenService:Create(old,TweenInfo.new(.20,Enum.EasingStyle.Quart,Enum.EasingDirection.In),{Position=UDim2.new(0,-28,0,0)}):Play()
  task.delay(.21,function() old.Visible=false; old.Position=UDim2.new(0,0,0,0); bringIn() end)
 else
  bringIn()
 end
end
for i,name in ipairs({"ESP","Movement","Utility","Settings"}) do
 local b=Instance.new("TextButton",nav); b.Position=UDim2.fromOffset(-28,(i-1)*48); b.Size=UDim2.fromOffset(125,40); b.BackgroundColor3=Color3.fromRGB(13,13,17); b.BackgroundTransparency=1; b.BorderSizePixel=0; b.Text=name:upper(); b.TextTransparency=1; b.TextColor3=Color3.fromRGB(229,229,234); b.TextSize=10; b.Font=Enum.Font.GothamMedium; b.ZIndex=13; cr(b,8); navButtons[name]=b
 local bs=st(b,Color3.fromRGB(118,118,128),1,.70); b:SetAttribute("BaseY",(i-1)*48); b:SetAttribute("Order",i)
 local activeRail=Instance.new("Frame",b); activeRail.Name="ActiveRail"; activeRail.Position=UDim2.fromOffset(0,8); activeRail.Size=UDim2.fromOffset(2,24); activeRail.BackgroundColor3=RED; activeRail.BackgroundTransparency=1; activeRail.BorderSizePixel=0; activeRail.ZIndex=15; cr(activeRail,99)
 b.MouseEnter:Connect(function() if not pages[name].Visible then TweenService:Create(b,TweenInfo.new(.14),{BackgroundColor3=Color3.fromRGB(24,24,29)}):Play(); bs.Transparency=.42 end end)
 b.MouseLeave:Connect(function() if not pages[name].Visible then TweenService:Create(b,TweenInfo.new(.14),{BackgroundColor3=Color3.fromRGB(13,13,17)}):Play(); bs.Transparency=.70 end end)
 local sheen=Instance.new("Frame",b); sheen.Size=UDim2.new(1,0,.48,0); sheen.BackgroundColor3=Color3.fromRGB(255,255,255); sheen.BackgroundTransparency=.975; sheen.BorderSizePixel=0; sheen.ZIndex=14; cr(sheen,8)
 local sg=Instance.new("UIGradient",sheen); sg.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.82),NumberSequenceKeypoint.new(1,1)})
 b.MouseButton1Click:Connect(function() click(); select(name) end)
end
-- No category panel on initial open; artwork + navigation only.

-- Snow effect removed.
local navAnimating=false
local function resetNavHidden()
 for _,b in pairs(navButtons) do
  b.Position=UDim2.fromOffset(-28,b:GetAttribute("BaseY") or 0)
  b.BackgroundTransparency=1; b.TextTransparency=1
 end
end
local function animateNavIn()
 if navAnimating then return end
 navAnimating=true
 local ordered={}
 for _,b in pairs(navButtons) do ordered[b:GetAttribute("Order")]=b end
 for i=1,4 do
  local b=ordered[i]
  task.delay((i-1)*.065,function()
   if b and b.Parent and shell.Visible then
    TweenService:Create(b,TweenInfo.new(.30,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{
     Position=UDim2.fromOffset(0,b:GetAttribute("BaseY") or 0),
     BackgroundTransparency=.05,TextTransparency=0
    }):Play()
   end
  end)
 end
 task.delay(.55,function() navAnimating=false end)
end

resetNavHidden()
task.delay(.28,function()
 if shell.Visible then animateNavIn() end
end)
task.defer(startSnow)

-- true smooth scale/fade using CanvasGroup
local group=Instance.new("CanvasGroup",shell)
group.Name="AnimationOverlay"; group.Size=UDim2.fromScale(1,1); group.BackgroundTransparency=1; group.GroupTransparency=1; group.ZIndex=0
-- CanvasGroup cannot wrap existing siblings after creation, so animate shell scale + image/control transparencies via overlay veil.
local anim=false
local fadeProps={}
local function cacheFadeObjects()
 fadeProps={}
 for _,o in ipairs(shell:GetDescendants()) do
  if o:IsA("GuiObject") then
   local d={}
   if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then d.TextTransparency=o.TextTransparency end
   if o:IsA("ImageLabel") or o:IsA("ImageButton") then d.ImageTransparency=o.ImageTransparency end
   if o:IsA("Frame") or o:IsA("TextButton") or o:IsA("TextLabel") or o:IsA("ImageLabel") or o:IsA("ImageButton") or o:IsA("ScrollingFrame") then d.BackgroundTransparency=o.BackgroundTransparency end
   fadeProps[o]=d
  elseif o:IsA("UIStroke") then
   fadeProps[o]={StrokeTransparency=o.Transparency}
  end
 end
end
cacheFadeObjects()

local function tweenShellFade(toHidden,duration)
 for o,d in pairs(fadeProps) do
  if o and o.Parent then
   local goal={}
   if d.TextTransparency~=nil then goal.TextTransparency=toHidden and 1 or d.TextTransparency end
   if d.ImageTransparency~=nil then goal.ImageTransparency=toHidden and 1 or d.ImageTransparency end
   if d.BackgroundTransparency~=nil then goal.BackgroundTransparency=toHidden and 1 or d.BackgroundTransparency end
   if d.StrokeTransparency~=nil and o:IsA("UIStroke") then goal.Transparency=toHidden and 1 or d.StrokeTransparency end
   if next(goal) then TweenService:Create(o,TweenInfo.new(duration,Enum.EasingStyle.Quart,toHidden and Enum.EasingDirection.In or Enum.EasingDirection.Out),goal):Play() end
  end
 end
end

local function closeHub()
 if anim or not shell.Visible then return end
 stopSnow()
 anim=true
 tweenShellFade(true,.30)
 TweenService:Create(scale,TweenInfo.new(.30,Enum.EasingStyle.Quart,Enum.EasingDirection.In),{Scale=.965}):Play()
 TweenService:Create(backScale,TweenInfo.new(.30,Enum.EasingStyle.Quart,Enum.EasingDirection.In),{Scale=.965}):Play()
 TweenService:Create(shellBack,TweenInfo.new(.30,Enum.EasingStyle.Quart,Enum.EasingDirection.In),{BackgroundTransparency=1}):Play()
 task.delay(.31,function()
  shell.Visible=false; shellBack.Visible=false
  scale.Scale=1; backScale.Scale=1
  open.Visible=true; open.BackgroundTransparency=1; open.TextTransparency=1
  TweenService:Create(open,TweenInfo.new(.22,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{BackgroundTransparency=.08,TextTransparency=0}):Play()
  anim=false
 end)
end

local function openHub()
 if anim or shell.Visible then return end
 anim=true
 TweenService:Create(open,TweenInfo.new(.18,Enum.EasingStyle.Quart,Enum.EasingDirection.In),{BackgroundTransparency=1,TextTransparency=1}):Play()
 task.delay(.18,function()
  open.Visible=false
  if currentPage and pages[currentPage] then pages[currentPage].Visible=false end
  currentPage=nil; content.Visible=false
  for _,b in pairs(navButtons) do
   b.BackgroundColor3=Color3.fromRGB(13,13,17)
   local ar=b:FindFirstChild("ActiveRail"); if ar then ar.BackgroundTransparency=1 end
  end
  resetNavHidden()
  shellBack.Visible=true; shell.Visible=true
  startSnow()
  scale.Scale=.965; backScale.Scale=.965
  shellBack.BackgroundTransparency=1
  -- all cached shell objects begin fully transparent, then restore together
  for o,d in pairs(fadeProps) do
   if o and o.Parent then
    if d.TextTransparency~=nil and (o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox")) then o.TextTransparency=1 end
    if d.ImageTransparency~=nil and (o:IsA("ImageLabel") or o:IsA("ImageButton")) then o.ImageTransparency=1 end
    if d.BackgroundTransparency~=nil and o:IsA("GuiObject") then o.BackgroundTransparency=1 end
    if d.StrokeTransparency~=nil and o:IsA("UIStroke") then o.Transparency=1 end
   end
  end
  tweenShellFade(false,.34)
  TweenService:Create(shellBack,TweenInfo.new(.34,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{BackgroundTransparency=.04}):Play()
  TweenService:Create(scale,TweenInfo.new(.34,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Scale=1}):Play()
  TweenService:Create(backScale,TweenInfo.new(.34,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Scale=1}):Play()
  task.delay(.20,function() if shell.Visible then animateNavIn() end end)
  task.delay(.56,function() anim=false end)
 end)
end
min.MouseButton1Click:Connect(function() click(); closeHub() end)
open.MouseButton1Click:Connect(function() click(); openHub() end)
local keyConn=UIS.InputBegan:Connect(function(i,g) if not g and i.KeyCode==Enum.KeyCode.F6 then if shell.Visible then closeHub() else openHub() end end end)

_G.SaintsHubV4Cleanup=function()
 stopPrivateChat(); stopSnow(); pcall(function() keyConn:Disconnect() end); pcall(function() perfConn:Disconnect() end); pcall(function() musicSound:Stop(); musicSound:Destroy() end); pcall(function() gui:Destroy() end); _G.SaintsHubV4Cleanup=nil
end

-- Proven Clean V7 manual Save subsystem transplanted from the old hub.
-- Mechanics/timings are retained; only the current rectangular gameplay button
-- is reused and the ready label is "Save" instead of "FP".
task.delay(0.10,function()
 pcall(function()
  local VIM=game:GetService("VirtualInputManager")
  local active=true
  local rescuing=false
  local attemptId=0
  local originalCFrame=nil
  local podConnections={}

  save.Size=UDim2.fromOffset(116,37)
  save.Text="Save"

  local function podConnect(signal,callback)
   local connection=signal:Connect(callback)
   table.insert(podConnections,connection)
   return connection
  end

  local function setPodDisplay(label,color,resetAfter)
   if not active or not save.Parent then return end
   save.Text=label
   save.BackgroundColor3=color
   if resetAfter then
    local id=attemptId
    task.delay(resetAfter,function()
     if active and not rescuing and attemptId==id and save.Parent then
      save.Text="Save"
      save.BackgroundColor3=saveEnabled and RED or Color3.fromRGB(55,55,60)
     end
    end)
   end
  end

  local function getRoot()
   local character=player.Character
   return character and character:FindFirstChild("HumanoidRootPart")
  end

  local function findOccupiedPod()
   local map=workspace:FindFirstChild("Map")
   if not map then return nil end
   for _,object in ipairs(map:GetDescendants()) do
    if object:IsA("Model") and object.Name=="FreezePod" and object:GetAttribute("Player")~=nil then
     return object
    end
   end
   return nil
  end

  local function findTrigger(pod)
   if not pod then return nil end
   local trigger=pod:FindFirstChild("PodTrigger",true)
   if trigger and trigger:IsA("BasePart") then return trigger end
   return nil
  end

  local function returnToStart()
   local root=getRoot()
   if root and originalCFrame then
    root.AssemblyLinearVelocity=Vector3.zero
    root.AssemblyAngularVelocity=Vector3.zero
    root.CFrame=originalCFrame
   end
   originalCFrame=nil
  end

  local function finishAttempt(id,label,color)
   if not active or not rescuing or id~=attemptId then return end
   returnToStart()
   rescuing=false
   setPodDisplay(label,color,1.2)
  end

  local function spamE(id)
   task.spawn(function()
    for i=1,5 do
     if not active or not rescuing or id~=attemptId then break end
     VIM:SendKeyEvent(true,Enum.KeyCode.E,false,game)
     task.wait(0.012)
     VIM:SendKeyEvent(false,Enum.KeyCode.E,false,game)
     if i<5 then task.wait(0.025) end
    end
   end)
  end

  task.spawn(function()
   local podFreed=ReplicatedStorage:WaitForChild("PodFreed")
   if not active or not podFreed:IsA("RemoteEvent") then return end
   podConnect(podFreed.OnClientEvent,function(...)
    if not rescuing then return end
    local id=attemptId
    task.wait()
    finishAttempt(id,"OK",Color3.fromRGB(45,120,70))
   end)
  end)

  podConnect(save.MouseButton1Click,function()
   if not active or rescuing or not saveEnabled then return end
   attemptId+=1
   local id=attemptId

   local pod=findOccupiedPod()
   local trigger=findTrigger(pod)
   local root=getRoot()
   local freezePodRemote=ReplicatedStorage:FindFirstChild("FreezePod")

   if not pod then
    setPodDisplay("NP",Color3.fromRGB(55,55,60),1.2)
    return
   end
   if not trigger or not root or not freezePodRemote or not freezePodRemote:IsA("RemoteEvent") then
    setPodDisplay("NA",Color3.fromRGB(55,55,60),1.2)
    return
   end

   rescuing=true
   originalCFrame=root.CFrame
   setPodDisplay("...",RED)

   local target=trigger.Position+trigger.CFrame.LookVector*3+Vector3.new(0,2.5,0)
   local lookAt=Vector3.new(trigger.Position.X,target.Y,trigger.Position.Z)

   root.AssemblyLinearVelocity=Vector3.zero
   root.AssemblyAngularVelocity=Vector3.zero
   root.CFrame=CFrame.lookAt(target,lookAt)

   spamE(id)
   task.wait(0.13)
   if not active or not rescuing or id~=attemptId then return end

   local fired=pcall(function() freezePodRemote:FireServer(pod) end)
   if not fired then
    finishAttempt(id,"NA",Color3.fromRGB(55,55,60))
    return
   end

   task.delay(1.5,function()
    finishAttempt(id,"??",Color3.fromRGB(105,80,25))
   end)
  end)
 end)
end)

-- V29 Utility gameplay is intentionally deferred until Saint's Hub has fully loaded.
task.defer(function()
 pcall(function()
  -- AUTO ROPE
  local ropeEnabled=false
  local Carry=ReplicatedStorage:FindFirstChild("Carry")
  local handled={}
  local function attempt(p,c)
   if not ropeEnabled or not Carry or p==player or not c or c:GetAttribute("Ragdolled")~=true or handled[c] then return end
   local root=c:FindFirstChild("HumanoidRootPart");if not root then return end
   handled[c]=true;Carry:FireServer(c,root,root.CFrame)
  end
  local function hookChar(p,c)
   handled[c]=false
   c:GetAttributeChangedSignal("Ragdolled"):Connect(function()
    if c:GetAttribute("Ragdolled")==true then task.delay(.05,function() attempt(p,c) end) else handled[c]=false end
   end)
  end
  local function hookPlayer(p)
   if p==player then return end
   if p.Character then hookChar(p,p.Character) end
   p.CharacterAdded:Connect(function(c) task.wait(.25);hookChar(p,c) end)
  end
  for _,p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
  Players.PlayerAdded:Connect(hookPlayer)
  autoRopeBtn.MouseButton1Click:Connect(function()
   task.defer(function()
    ropeEnabled=autoRopeBtn.Text=="ON"
    if ropeEnabled then for _,p in ipairs(Players:GetPlayers()) do if p~=player and p.Character then attempt(p,p.Character) end end end
   end)
  end)

  -- HITBOX: bind to existing setHitboxLevel without changing the slider UI.
  local originals={}
  local function restore()
   for root,o in pairs(originals) do
    if root.Parent then
     root.Size=o.Size;root.Transparency=o.Transparency;root.CanCollide=o.CanCollide;root.CanTouch=o.CanTouch;root.CanQuery=o.CanQuery
    end
    originals[root]=nil
   end
  end
  local function apply()
   if hitboxLevel==0 then restore();return end
   for _,p in ipairs(Players:GetPlayers()) do
    if p~=player and p.Character then
     local root=p.Character:FindFirstChild("HumanoidRootPart")
     if root then
      if not originals[root] then originals[root]={Size=root.Size,Transparency=root.Transparency,CanCollide=root.CanCollide,CanTouch=root.CanTouch,CanQuery=root.CanQuery} end
      local n=(hitboxLevel==1) and 5 or 6
      root.Size=Vector3.new(n,n,n);root.Transparency=1;root.CanCollide=false;root.CanTouch=true;root.CanQuery=true
     end
    end
   end
  end
  local oldSet=setHitboxLevel
  setHitboxLevel=function(n)
   if oldSet then oldSet(n) end
   restore();apply()
  end
  task.spawn(function()
   while gui and gui.Parent do if hitboxLevel>0 then pcall(apply) end task.wait(.4) end
   pcall(restore)
  end)

 end)
end)

end

-- ================= SAINT'S PHONE =================
local function startSaintsPhone()
-- PHASE 1.81 // V1.80 LOCKED // 4-APP HOME LAYOUT
--[[
    SAINT'S PHONE // PHASE 1.73 // PROVEN V5.3 DIRECT RPS TRANSPORT
    Authorized: Mateo + Nina only

    Phase 1:
      - Creates "Saint's Phone" Tool in Backpack/hotbar
      - Equip/click opens a private local phone UI
      - Games / Invites / Stats / Achievements screens
      - Clean black/red Saint's aesthetic
      - Phase 2 placeholders for live invites + persistent stats
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
if not player then return end

local AUTH = {
    [558142136] = {name="Mateo", peer="Nina"},
    [998914239] = {name="Nina", peer="Mateo"},
}
local me = AUTH[player.UserId]
if not me then return end

local LP=player
local MY_ID=tostring(player.UserId)
local PEER_ID=(player.UserId==558142136) and "998914239" or "558142136"
local PEER_NAME=me.peer
local RELAY="wss://saints-multiplayer-relay.onrender.com/ws"

-- Shared relay locals are forward-declared here because Force Chat UI/functions
-- are created before the relay implementation later in this file.
local socket=nil
local connected=false
local sendPacket

-- Game/UI hooks must exist before invite functions capture them.
local openEmbeddedTicTacToe
local handleEmbeddedTicTacToePacket
local openEmbeddedMidnightRun
local handleEmbeddedMidnightPacket
local restorePhoneAlpha
local setHomeAppsFade
local animateHomeAppsAfterShell

local function connectSocket(url)
    local candidates={
        function() if WebSocket and WebSocket.connect then return WebSocket.connect(url) end end,
        function() if WebSocket and WebSocket.Connect then return WebSocket.Connect(url) end end,
        function() if websocket and websocket.connect then return websocket.connect(url) end end,
        function() if websocket and websocket.Connect then return websocket.Connect(url) end end,
        function() if syn and syn.websocket and syn.websocket.connect then return syn.websocket.connect(url) end end,
    }
    for _,fn in ipairs(candidates) do
        local ok,result=pcall(fn)
        if ok and result then return result end
    end
    return nil
end

local function socketSend(ws,payload)
    local ok=pcall(function() ws:Send(payload) end)
    if ok then return true end
    ok=pcall(function() ws:send(payload) end)
    return ok
end

local function socketClose(ws)
    if not ws then return end
    if pcall(function() ws:Close() end) then return end
    pcall(function() ws:close() end)
end

-- Prevent duplicate executions.
local pg = player:WaitForChild("PlayerGui")
local oldGui = pg:FindFirstChild("SaintsPhoneUI")
if oldGui then oldGui:Destroy() end
local backpack = player:WaitForChild("Backpack")
for _,where in ipairs({backpack, player.Character}) do
    local old = where and where:FindFirstChild("Saint's Phone")
    if old then old:Destroy() end
end

local RED = Color3.fromRGB(204,17,31)
local RED2 = Color3.fromRGB(155,12,24)
local BG = Color3.fromRGB(8,8,10)
local PANEL = Color3.fromRGB(18,18,22)
local PANEL2 = Color3.fromRGB(27,27,33)
local WHITE = Color3.fromRGB(245,245,248)
local MUTED = Color3.fromRGB(155,155,166)
local GREEN = Color3.fromRGB(74,205,118)

local function corner(obj,r)
    local c=Instance.new("UICorner")
    c.CornerRadius=UDim.new(0,r)
    c.Parent=obj
    return c
end

local function stroke(obj,color,thickness,transparency)
    local s=Instance.new("UIStroke")
    s.Color=color or Color3.fromRGB(60,60,68)
    s.Thickness=thickness or 1
    s.Transparency=transparency or 0
    s.Parent=obj
    return s
end

local function label(parent,text,size,pos,font,textSize,color,align)
    local l=Instance.new("TextLabel")
    l.BackgroundTransparency=1
    l.Text=text
    l.Size=size
    l.Position=pos or UDim2.new()
    l.Font=font or Enum.Font.Gotham
    l.TextSize=textSize or 14
    l.TextColor3=color or WHITE
    l.TextXAlignment=align or Enum.TextXAlignment.Left
    l.Parent=parent
    return l
end

local function button(parent,text,size,pos)
    local b=Instance.new("TextButton")
    b.AutoButtonColor=false
    b.Text=text
    b.Size=size
    b.Position=pos
    b.BackgroundColor3=PANEL2
    b.TextColor3=WHITE
    b.Font=Enum.Font.GothamSemibold
    b.TextSize=13
    b.Parent=parent
    corner(b,12)
    stroke(b,Color3.fromRGB(52,52,60),1,.25)
    b.MouseEnter:Connect(function()
        TweenService:Create(b,TweenInfo.new(.12),{BackgroundColor3=Color3.fromRGB(36,36,43)}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b,TweenInfo.new(.12),{BackgroundColor3=PANEL2}):Play()
    end)
    return b
end

-- Tool in inventory/hotbar.
local tool=Instance.new("Tool")
tool.Name="Saint's Phone"
tool.RequiresHandle=false
tool.CanBeDropped=false
tool.ToolTip="Private Saint's multiplayer phone"
tool.Parent=backpack

-- Screen GUI.
local gui=Instance.new("ScreenGui")
gui.Name="SaintsPhoneUI"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=250
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
gui.Parent=pg

-- Phase 1.15 smooth fade brighter wallpaper:
-- FTF can hide locally-created Backpack Tools behind its custom inventory UI,
-- so this button guarantees the phone remains accessible while we wire the real inventory later.
local launcher=Instance.new("TextButton")
launcher.Name="SaintsPhoneLauncher"
launcher.AnchorPoint=Vector2.new(.5,1)
launcher.Position=UDim2.new(.5,0,1,-22)
launcher.Size=UDim2.fromOffset(48,48)
launcher.BackgroundColor3=Color3.fromRGB(20,21,26)
launcher.Text=""
launcher.TextColor3=Color3.fromRGB(204,17,31)
launcher.Font=Enum.Font.GothamBold
launcher.TextSize=22
launcher.AutoButtonColor=false
launcher.ZIndex=200
launcher.Parent=gui
launcher.ClipsDescendants=false
corner(launcher,4)
stroke(launcher,Color3.fromRGB(35,35,38),1,.65)

-- Phase 1.12: Roblox-uploaded custom phone artwork.
-- Keep the approved 48x48 bottom-center launcher; use the image itself as the icon.
launcher.BackgroundColor3=Color3.fromRGB(18,18,18)
launcher.ClipsDescendants=false

local phoneImage=Instance.new("ImageLabel")
phoneImage.Name="PhoneArtwork"
phoneImage.AnchorPoint=Vector2.new(.5,.5)
phoneImage.Position=UDim2.fromScale(.5,.5)
phoneImage.Size=UDim2.new(1,0,1,0)
phoneImage.BackgroundTransparency=1
phoneImage.Image="rbxassetid://84050593321231"
phoneImage.ImageColor3=Color3.fromRGB(255,255,255)
phoneImage.ImageTransparency=0
phoneImage.ScaleType=Enum.ScaleType.Crop
phoneImage.ZIndex=201
phoneImage.Parent=launcher
corner(phoneImage,3)

-- Pending-invite badge floats independently OUTSIDE the 48x48 inventory icon.
-- Launcher center is screen center; launcher top is 70px above bottom (22px margin + 48px height).
local badgeShadow=Instance.new("Frame")
badgeShadow.Name="InviteBadgeShadow"
badgeShadow.AnchorPoint=Vector2.new(.5,.5)
badgeShadow.Position=UDim2.new(.5,29,1,-75)
badgeShadow.Size=UDim2.fromOffset(24,24)
badgeShadow.BackgroundColor3=Color3.fromRGB(0,0,0)
badgeShadow.BackgroundTransparency=.28
badgeShadow.Visible=false
badgeShadow.ZIndex=209
badgeShadow.Parent=gui
corner(badgeShadow,12)

local inviteBadge=Instance.new("TextLabel")
inviteBadge.Name="InviteBadge"
inviteBadge.AnchorPoint=Vector2.new(.5,.5)
inviteBadge.Position=UDim2.new(.5,27,1,-77)
inviteBadge.Size=UDim2.fromOffset(22,22)
inviteBadge.BackgroundColor3=RED
inviteBadge.Text="1"
inviteBadge.TextColor3=WHITE
inviteBadge.Font=Enum.Font.GothamBold
inviteBadge.TextSize=12
inviteBadge.Visible=false
inviteBadge.ZIndex=210
inviteBadge.Parent=gui
corner(inviteBadge,11)
stroke(inviteBadge,Color3.fromRGB(245,245,248),1,.15)

-- Dim background only while phone is open.
local shade=Instance.new("TextButton")
shade.Name="Shade"
shade.Text=""
shade.AutoButtonColor=false
shade.BackgroundColor3=Color3.new(0,0,0)
shade.BackgroundTransparency=.58
shade.Size=UDim2.fromScale(1,1)
shade.Visible=false
shade.ZIndex=1
shade.Parent=gui

-- Phone body.
local phone=Instance.new("Frame")
phone.Name="Phone"
phone.AnchorPoint=Vector2.new(.5,.5)
phone.Position=UDim2.fromScale(.5,.54)
phone.Size=UDim2.fromOffset(318,620)
phone.BackgroundColor3=Color3.fromRGB(3,3,4)
phone.Visible=false
phone.ZIndex=5
phone.Parent=gui
corner(phone,38)
stroke(phone,Color3.fromRGB(80,80,88),2,.15)

local shell=Instance.new("Frame")
shell.Position=UDim2.fromOffset(7,7)
shell.Size=UDim2.new(1,-14,1,-14)
shell.BackgroundColor3=BG
shell.ZIndex=6
shell.Parent=phone
corner(shell,32)

local wallpaper=Instance.new("ImageLabel")
wallpaper.Name="Wallpaper"
wallpaper.BackgroundTransparency=1
wallpaper.Size=UDim2.fromScale(1,1)
wallpaper.Image="rbxassetid://138844787629066"
wallpaper.ScaleType=Enum.ScaleType.Crop
wallpaper.ZIndex=7
wallpaper.Parent=shell
corner(wallpaper,32)

local wallpaperShade=Instance.new("Frame")
wallpaperShade.BackgroundColor3=Color3.fromRGB(0,0,0)
wallpaperShade.BackgroundTransparency=.86
wallpaperShade.BorderSizePixel=0
wallpaperShade.Size=UDim2.fromScale(1,1)
wallpaperShade.ZIndex=8
wallpaperShade.Parent=shell
corner(wallpaperShade,32)

local notch=Instance.new("Frame")
notch.AnchorPoint=Vector2.new(.5,0)
notch.Position=UDim2.new(.5,0,0,10)
notch.Size=UDim2.fromOffset(104,24)
notch.BackgroundColor3=Color3.fromRGB(1,1,2)
notch.ZIndex=20
notch.Parent=shell
corner(notch,14)

local speaker=Instance.new("Frame")
speaker.AnchorPoint=Vector2.new(.5,.5)
speaker.Position=UDim2.fromScale(.5,.5)
speaker.Size=UDim2.fromOffset(36,4)
speaker.BackgroundColor3=Color3.fromRGB(45,45,50)
speaker.ZIndex=21
speaker.Parent=notch
corner(speaker,3)


local close=Instance.new("TextButton")
close.Text="×"
close.AutoButtonColor=false
close.BackgroundTransparency=1
close.Size=UDim2.fromOffset(32,32)
close.Position=UDim2.new(1,-42,0,43)
close.TextColor3=MUTED
close.Font=Enum.Font.GothamMedium
close.TextSize=24
close.ZIndex=15
close.Parent=shell


-- Home content.
local home=Instance.new("Frame")
home.Name="Home"
home.BackgroundTransparency=1
home.Position=UDim2.fromOffset(16,108)
home.Size=UDim2.new(1,-32,1,-140)
home.ZIndex=8
home.Parent=shell


local appGrid=Instance.new("Frame")
appGrid.BackgroundTransparency=1
appGrid.Position=UDim2.fromOffset(0,8)
appGrid.Size=UDim2.new(1,0,0,353)
appGrid.ZIndex=9
appGrid.Parent=home

local grid=Instance.new("UIGridLayout")
grid.CellSize=UDim2.fromOffset(132,105)
grid.CellPadding=UDim2.fromOffset(8,10)
grid.SortOrder=Enum.SortOrder.LayoutOrder
grid.Parent=appGrid

local pages={}
local currentPage=nil

local function appCard(title,icon,desc,order)
    local b=Instance.new("TextButton")
    b.AutoButtonColor=false
    b.Text=""
    b.LayoutOrder=order
    b.BackgroundColor3=PANEL
    b.BackgroundTransparency=.38
    b.ZIndex=10
    b.ClipsDescendants=true
    b.Parent=appGrid
    corner(b,16)
    stroke(b,Color3.fromRGB(48,48,56),1,.2)

    local ic=label(b,icon,UDim2.fromOffset(42,34),UDim2.fromOffset(12,10),Enum.Font.GothamBold,23,RED)
    ic.ZIndex=11
    local ti=label(b,title,UDim2.new(1,-20,0,20),UDim2.fromOffset(12,49),Enum.Font.GothamBold,13,WHITE)
    ti.ZIndex=11
    local de=label(b,desc,UDim2.new(1,-20,0,26),UDim2.fromOffset(12,70),Enum.Font.Gotham,9,MUTED)
    de.TextWrapped=true
    de.ZIndex=11
    return b
end

local gamesApp=appCard("GAMES","▶","Play together",1)
local invitesApp=appCard("INVITES","✉","Pending requests",2)
local controlApp=appCard("CONTROL","◆","Remote control",3)
local forceChatApp=appCard("FORCE CHAT","...","Send through "..me.peer,4)

local invitesTileBadge=Instance.new("TextLabel")
invitesTileBadge.Name="InviteCountBadge"
invitesTileBadge.AnchorPoint=Vector2.new(.5,.5)
invitesTileBadge.Position=UDim2.new(1,-9,0,9)
invitesTileBadge.Size=UDim2.fromOffset(20,20)
invitesTileBadge.BackgroundColor3=RED
invitesTileBadge.Text="1"
invitesTileBadge.TextColor3=WHITE
invitesTileBadge.Font=Enum.Font.GothamBold
invitesTileBadge.TextSize=11
invitesTileBadge.Visible=false
invitesTileBadge.ZIndex=15
invitesTileBadge.Parent=invitesApp
corner(invitesTileBadge,10)
stroke(invitesTileBadge,Color3.fromRGB(12,12,15),2,0)

-- Home footer removed for clean phone layout.

local function makePage(name,title,subtitle)
    local p=Instance.new("Frame")
    p.Name=name
    p.BackgroundTransparency=1
    p.Position=UDim2.fromOffset(16,106)
    p.Size=UDim2.new(1,-32,1,-132)
    p.Visible=false
    p.ZIndex=9
    p.Parent=shell

    local back=button(p,"‹",UDim2.fromOffset(38,34),UDim2.fromOffset(0,0))
    back.TextSize=24
    back.ZIndex=10
    local ttl=label(p,title,UDim2.new(1,-50,0,24),UDim2.fromOffset(50,1),Enum.Font.GothamBold,18,WHITE)
    ttl.ZIndex=10
    local st=label(p,subtitle,UDim2.new(1,-50,0,18),UDim2.fromOffset(50,27),Enum.Font.Gotham,10,MUTED)
    st.ZIndex=10
    back.MouseButton1Click:Connect(function()
        p.Visible=false
        home.Visible=true
        currentPage=nil
    end)
    pages[name]=p
    return p
end

local function openPage(name)
    home.Visible=false
    for _,p in pairs(pages) do p.Visible=false end
    pages[name].Visible=true
    currentPage=pages[name]
end

-- Control
local controlPage=makePage("Control","Control","private control with "..me.peer)

local controlPanel=Instance.new("Frame")
controlPanel.Position=UDim2.fromOffset(0,66)
controlPanel.Size=UDim2.new(1,0,0,180)
controlPanel.BackgroundColor3=PANEL
controlPanel.BackgroundTransparency=.14
controlPanel.ZIndex=10
controlPanel.Parent=controlPage
corner(controlPanel,16)
stroke(controlPanel,Color3.fromRGB(55,55,64),1,.16)

local controlStatus=label(controlPanel,"CONTROL SLOT • FREE",UDim2.new(1,-24,0,22),UDim2.fromOffset(12,15),Enum.Font.GothamBold,12,WHITE)
controlStatus.ZIndex=11

local peerPresenceLabel=label(controlPanel,string.upper(me.peer).." • OFFLINE",UDim2.new(1,-24,0,18),UDim2.fromOffset(12,36),Enum.Font.GothamBold,10,Color3.fromRGB(145,145,152))
peerPresenceLabel.ZIndex=11
local controlInfo=label(controlPanel,"First person to claim the slot controls the other player.",UDim2.new(1,-24,0,42),UDim2.fromOffset(12,57),Enum.Font.Gotham,10,MUTED)
controlInfo.TextWrapped=true
controlInfo.ZIndex=11

local controlButton=button(controlPanel,"CONTROL "..string.upper(me.peer),UDim2.new(1,-24,0,44),UDim2.fromOffset(12,116))
controlButton.BackgroundColor3=Color3.fromRGB(142,27,38)
controlButton.TextColor3=WHITE
controlButton.Font=Enum.Font.GothamBold
controlButton.TextSize=12
controlButton.ZIndex=12

-- Force Chat
local forceChatPage=makePage("ForceChat","Force Chat","send through "..me.peer.."'s normal Roblox chat")

local forceChatPanel=Instance.new("Frame")
forceChatPanel.Position=UDim2.fromOffset(0,66)
forceChatPanel.Size=UDim2.new(1,0,0,210)
forceChatPanel.BackgroundColor3=PANEL
forceChatPanel.BackgroundTransparency=.14
forceChatPanel.ZIndex=10
forceChatPanel.Parent=forceChatPage
corner(forceChatPanel,16)
stroke(forceChatPanel,Color3.fromRGB(55,55,64),1,.16)

local forceChatPresence=label(forceChatPanel,string.upper(PEER_NAME).." • OFFLINE",UDim2.new(1,-24,0,18),UDim2.fromOffset(12,14),Enum.Font.GothamBold,10,Color3.fromRGB(145,145,152))
forceChatPresence.ZIndex=11

local forceChatHint=label(forceChatPanel,"Message will be sent by "..PEER_NAME.." through Roblox's normal public chat.",UDim2.new(1,-24,0,34),UDim2.fromOffset(12,38),Enum.Font.Gotham,10,MUTED)
forceChatHint.TextWrapped=true
forceChatHint.ZIndex=11

local forceChatBox=Instance.new("TextBox")
forceChatBox.Name="ForceChatBox"
forceChatBox.Position=UDim2.fromOffset(12,84)
forceChatBox.Size=UDim2.new(1,-24,0,54)
forceChatBox.BackgroundColor3=Color3.fromRGB(12,12,16)
forceChatBox.BackgroundTransparency=.08
forceChatBox.Text=""
forceChatBox.PlaceholderText="type what "..PEER_NAME.." should say..."
forceChatBox.PlaceholderColor3=Color3.fromRGB(115,115,125)
forceChatBox.TextColor3=WHITE
forceChatBox.ClearTextOnFocus=false
forceChatBox.MultiLine=false
forceChatBox.TextWrapped=false
forceChatBox.TextXAlignment=Enum.TextXAlignment.Left
forceChatBox.Font=Enum.Font.Gotham
forceChatBox.TextSize=12
forceChatBox.ClipsDescendants=true
forceChatBox.ZIndex=12
forceChatBox.Parent=forceChatPanel
corner(forceChatBox,12)
stroke(forceChatBox,Color3.fromRGB(52,52,60),1,.2)

local forceChatPadding=Instance.new("UIPadding")
forceChatPadding.PaddingLeft=UDim.new(0,10)
forceChatPadding.PaddingRight=UDim.new(0,10)
forceChatPadding.Parent=forceChatBox

local forceChatSend=button(forceChatPanel,"SEND AS "..string.upper(PEER_NAME),UDim2.new(1,-24,0,44),UDim2.fromOffset(12,151))
forceChatSend.BackgroundColor3=Color3.fromRGB(142,27,38)
forceChatSend.Font=Enum.Font.GothamBold
forceChatSend.TextSize=12
forceChatSend.ZIndex=12

local function sendPublicRobloxChat(text)
    text=tostring(text or "")
    text=text:gsub("^%s+",""):gsub("%s+$","")
    if text=="" then return false end

    -- Modern TextChatService path. Roblox handles its normal filtering/moderation.
    local ok=pcall(function()
        local channels=TextChatService:FindFirstChild("TextChannels")
        local general=channels and channels:FindFirstChild("RBXGeneral")
        if not general then error("RBXGeneral unavailable") end
        general:SendAsync(text)
    end)
    if ok then return true end

    -- Legacy chat fallback for experiences still using DefaultChatSystemChatEvents.
    ok=pcall(function()
        local events=ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
        local say=events and events:FindFirstChild("SayMessageRequest")
        if not say then error("legacy chat unavailable") end
        say:FireServer(text,"All")
    end)
    return ok
end

local function sendForceChat(text)
    text=tostring(text or "")
    text=text:gsub("^%s+",""):gsub("%s+$","")
    if text=="" or not connected or type(sendPacket)~="function" then return false end

    return sendPacket({
        type="chat_message",
        to=PEER_ID,
        payload={
            __saints_force_chat=true,
            text=text
        }
    })
end

local forceChatBusy=false
local function submitForceChat()
    if forceChatBusy then return end
    local text=tostring(forceChatBox.Text or "")
    text=text:gsub("^%s+",""):gsub("%s+$","")
    if text=="" then return end

    forceChatBusy=true
    local normalColor=Color3.fromRGB(38,38,46)
    forceChatSend.BackgroundColor3=RED
    forceChatSend.Text="SENDING..."

    local ok=sendForceChat(text)
    if ok then
        forceChatBox.Text=""
        forceChatSend.Text="SENT AS "..string.upper(PEER_NAME)
    else
        forceChatSend.Text="NOT SENT"
    end

    task.delay(.8,function()
        if forceChatSend and forceChatSend.Parent then
            forceChatSend.BackgroundColor3=normalColor
            forceChatSend.Text="SEND AS "..string.upper(PEER_NAME)
        end
        forceChatBusy=false
    end)
end

forceChatSend.Activated:Connect(submitForceChat)
forceChatBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then submitForceChat() end
end)

-- Games
local games=makePage("Games","Games","pick what you wanna play with "..me.peer)

local function gameAppCard(parent,y,title,desc,imageId)
    local card=Instance.new("Frame")
    card.Position=UDim2.fromOffset(0,y)
    card.Size=UDim2.new(1,0,0,128)
    card.BackgroundColor3=PANEL
    card.BackgroundTransparency=.16
    card.ZIndex=10
    card.Parent=parent
    card.ClipsDescendants=true
    corner(card,16)
    stroke(card,Color3.fromRGB(55,55,64),1,.16)

    local cover=Instance.new("ImageLabel")
    cover.Name="Cover"
    cover.BackgroundTransparency=1
    cover.Position=UDim2.fromOffset(10,10)
    cover.Size=UDim2.fromOffset(108,108)
    cover.Image="rbxassetid://"..tostring(imageId)
    cover.ScaleType=Enum.ScaleType.Crop
    cover.ZIndex=11
    cover.Parent=card
    corner(cover,13)

    local coverShade=Instance.new("Frame")
    coverShade.BackgroundColor3=Color3.fromRGB(0,0,0)
    coverShade.BackgroundTransparency=.88
    coverShade.BorderSizePixel=0
    coverShade.Size=UDim2.fromScale(1,1)
    coverShade.ZIndex=12
    coverShade.Parent=cover
    corner(coverShade,13)

    local titleLabel=label(card,title,UDim2.new(1,-140,0,24),UDim2.fromOffset(132,17),Enum.Font.GothamBold,14,WHITE)
    titleLabel.ZIndex=12

    local descLabel=label(card,desc,UDim2.new(1,-145,0,36),UDim2.fromOffset(132,45),Enum.Font.Gotham,9,MUTED)
    descLabel.TextWrapped=true
    descLabel.ZIndex=12

    local invite=Instance.new("TextButton")
    invite.BackgroundColor3=Color3.fromRGB(33,10,14)
    invite.BackgroundTransparency=.08
    invite.Position=UDim2.fromOffset(132,88)
    invite.Size=UDim2.new(1,-144,0,27)
    invite.Text="INVITE "..string.upper(me.peer)
    invite.TextColor3=Color3.fromRGB(238,52,67)
    invite.Font=Enum.Font.GothamBold
    invite.TextSize=9
    invite.AutoButtonColor=true
    invite.Active=true
    invite.Selectable=true
    invite.ZIndex=30
    invite.Parent=card
    corner(invite,8)
    stroke(invite,Color3.fromRGB(120,25,35),1,.35)

    return card,invite
end

local ticTacToeCard,ticTacToeInviteButton=gameAppCard(
    games,
    62,
    "Tic-Tac-Toe",
    "Private 1v1 board game.",
    133964961960693
)

local midnightRunCard,midnightRunInviteButton=gameAppCard(
    games,
    200,
    "Midnight Run",
    "Race each other through the course.",
    139153863617297
)

midnightRunInviteButton.Text="INVITE "..string.upper(me.peer)
midnightRunInviteButton.TextColor3=Color3.fromRGB(238,52,67)
midnightRunInviteButton.BackgroundColor3=Color3.fromRGB(33,10,14)
midnightRunInviteButton.TextColor3=Color3.fromRGB(238,52,67)
midnightRunInviteButton.BackgroundColor3=Color3.fromRGB(33,10,14)
midnightRunInviteButton.Active=true
midnightRunInviteButton.AutoButtonColor=true

local rpsCard,rpsInviteButton=gameAppCard(
    games,
    338,
    "Rock Paper Scissors",
    "Best of 5 • first to 3.",
    74784608539737
)
rpsInviteButton.Text="INVITE "..string.upper(me.peer)
rpsInviteButton.TextColor3=Color3.fromRGB(238,52,67)
rpsInviteButton.BackgroundColor3=Color3.fromRGB(33,10,14)
rpsInviteButton.Active=true
rpsInviteButton.AutoButtonColor=true

-- V1.55 SOLO GAME DISPLAY TEST
-- Temporarily bypass multiplayer invites so Mateo can verify that both complete
-- embedded game UIs actually render without Nina being online.
local SOLO_GAME_DISPLAY_TEST=false

if SOLO_GAME_DISPLAY_TEST then
    ticTacToeInviteButton.Text="PLAY"
    midnightRunInviteButton.Text="PLAY"
    ticTacToeInviteButton.AutoButtonColor=true
    midnightRunInviteButton.AutoButtonColor=true
end

-- Invites
local invites=makePage("Invites","Invites","game requests from "..me.peer)

local invBox=Instance.new("Frame")
invBox.Position=UDim2.fromOffset(0,70)
invBox.Size=UDim2.new(1,0,0,184)
invBox.BackgroundColor3=PANEL
invBox.BackgroundTransparency=.12
invBox.ZIndex=10
invBox.Parent=invites
corner(invBox,16)
stroke(invBox,Color3.fromRGB(48,48,56),1,.2)

local invIcon=label(invBox,"!",UDim2.new(1,0,0,34),UDim2.fromOffset(0,20),Enum.Font.GothamBold,25,RED,Enum.TextXAlignment.Center)
invIcon.ZIndex=11
local invTitle=label(invBox,"No pending invites",UDim2.new(1,-24,0,22),UDim2.fromOffset(12,60),Enum.Font.GothamBold,13,WHITE,Enum.TextXAlignment.Center)
invTitle.ZIndex=11
local invDesc=label(invBox,"Tic-Tac-Toe invites will appear here.",UDim2.new(1,-30,0,34),UDim2.fromOffset(15,87),Enum.Font.Gotham,10,MUTED,Enum.TextXAlignment.Center)
invDesc.TextWrapped=true
invDesc.ZIndex=11

local acceptInvite=button(invBox,"ACCEPT",UDim2.fromOffset(112,34),UDim2.fromOffset(13,132))
acceptInvite.BackgroundColor3=Color3.fromRGB(92,23,31)
acceptInvite.TextColor3=Color3.fromRGB(245,245,248)
acceptInvite.ZIndex=12
acceptInvite.Visible=false

local declineInvite=button(invBox,"DECLINE",UDim2.fromOffset(112,34),UDim2.fromOffset(133,132))
declineInvite.BackgroundColor3=Color3.fromRGB(35,35,40)
declineInvite.ZIndex=12
declineInvite.Visible=false

-- Stats
local stats=makePage("Stats","Stats","your all-time record vs "..me.peer)
local statsData={
    {"OVERALL W/L","— / —"},
    {"WIN RATE","—"},
    {"CURRENT STREAK","—"},
    {"BEST STREAK","—"},
    {"GAMES PLAYED","—"},
}
for i,row in ipairs(statsData) do
    local f=Instance.new("Frame")
    f.Position=UDim2.fromOffset(0,58+(i-1)*62)
    f.Size=UDim2.new(1,0,0,52)
    f.BackgroundColor3=PANEL
    f.ZIndex=10; f.Parent=stats
    corner(f,13)
    local a=label(f,row[1],UDim2.new(.7,0,1,0),UDim2.fromOffset(14,0),Enum.Font.GothamSemibold,10,MUTED)
    a.TextYAlignment=Enum.TextYAlignment.Center; a.ZIndex=11
    local b=label(f,row[2],UDim2.new(.3,-14,1,0),UDim2.new(.7,0,0,0),Enum.Font.GothamBold,14,WHITE,Enum.TextXAlignment.Right)
    b.TextYAlignment=Enum.TextYAlignment.Center; b.ZIndex=11
end
local statsNote=label(stats,"Persistent server stats will be wired in a later phase.",UDim2.new(1,0,0,34),UDim2.fromOffset(0,382),Enum.Font.Gotham,9,MUTED,Enum.TextXAlignment.Center)
statsNote.TextWrapped=true; statsNote.ZIndex=10

-- Achievements
local ach=makePage("Achievements","Achievements","permanent Saint's milestones")
local achievements={
    {"★","FIRST WIN","Win your first Saint's game."},
    {"◆","ON A ROLL","Reach a 5-game win streak."},
    {"✦","VETERAN","Play 100 multiplayer games."},
    {"♛","RIVALRY","Win 50 games against "..me.peer.."."},
}
for i,a in ipairs(achievements) do
    local f=Instance.new("Frame")
    f.Position=UDim2.fromOffset(0,58+(i-1)*76)
    f.Size=UDim2.new(1,0,0,66)
    f.BackgroundColor3=PANEL
    f.ZIndex=10; f.Parent=ach
    corner(f,14)
    local ic=label(f,a[1],UDim2.fromOffset(40,40),UDim2.fromOffset(12,13),Enum.Font.GothamBold,20,Color3.fromRGB(75,75,84),Enum.TextXAlignment.Center)
    ic.ZIndex=11
    local ti=label(f,a[2],UDim2.new(1,-70,0,18),UDim2.fromOffset(60,13),Enum.Font.GothamBold,11,MUTED)
    ti.ZIndex=11
    local de=label(f,a[3],UDim2.new(1,-74,0,26),UDim2.fromOffset(60,33),Enum.Font.Gotham,9,Color3.fromRGB(110,110,120))
    de.TextWrapped=true; de.ZIndex=11
end



local rpsSharedSend=nil

-- -------------------------
-- ROCK PAPER SCISSORS // V5.3 PREMIUM PHONE EMBED
-- Phone invite owns matchmaking; this opens directly into the accepted match.
-- -------------------------
local rpsEmbedded=nil

local function openEmbeddedRPS(startId)
    -- Self-contained launch: do not depend on later local helper declarations.
    if embeddedGameGui then
        pcall(function() embeddedGameGui:Destroy() end)
        embeddedGameGui=nil
    end
    phone.Visible=false
    opened=false
    launcher.Visible=false

    local g=Instance.new("ScreenGui")
    g.Name="SaintsPhone_RPS_V53"
    g.ResetOnSpawn=false
    g.IgnoreGuiInset=true
    g.DisplayOrder=300
    g.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    g.Parent=pg
    embeddedGameGui=g

    local function RN(c,p,par)
        local o=Instance.new(c)
        for k,v in pairs(p or {}) do o[k]=v end
        o.Parent=par
        return o
    end
    local function rr(o,r) RN("UICorner",{CornerRadius=UDim.new(0,r)},o) end
    local function rl(o,col,t) return RN("UIStroke",{Color=col,Thickness=t or 1},o) end
    local function rtw(o,p) TweenService:Create(o,TweenInfo.new(.12,Enum.EasingStyle.Quart),p):Play() end
    local C={
        bg=Color3.fromRGB(10,10,13),card=Color3.fromRGB(18,18,23),card2=Color3.fromRGB(25,25,31),
        red=Color3.fromRGB(226,43,61),darkred=Color3.fromRGB(105,23,34),white=Color3.fromRGB(246,246,248),
        muted=Color3.fromRGB(145,145,156),green=Color3.fromRGB(71,207,116),yellow=Color3.fromRGB(241,188,67),
        border=Color3.fromRGB(53,53,64)
    }

    local root=RN("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(520,410),
        BackgroundColor3=C.bg,BorderSizePixel=0,ClipsDescendants=true},g); rr(root,22); rl(root,C.border,1.2)
    RN("TextLabel",{Position=UDim2.fromOffset(58,18),Size=UDim2.new(1,-116,0,34),BackgroundTransparency=1,
        Text="ROCK PAPER SCISSORS",TextColor3=C.white,TextSize=22,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Center},root)
    local x=RN("TextButton",{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-18,0,18),Size=UDim2.fromOffset(34,34),
        BackgroundColor3=C.card2,Text="×",TextColor3=C.muted,TextSize=24,Font=Enum.Font.GothamMedium,AutoButtonColor=false},root); rr(x,10)
    RN("Frame",{Position=UDim2.fromOffset(20,79),Size=UDim2.new(1,-40,0,1),BackgroundColor3=C.border,BorderSizePixel=0},root)
    local body=RN("Frame",{Position=UDim2.fromOffset(20,92),Size=UDim2.new(1,-40,1,-112),BackgroundTransparency=1},root)

    -- V5.3 accepted matches start at the score HUD, not its standalone invite lobby.
    local status=RN("TextLabel",{Position=UDim2.fromOffset(0,-2),Size=UDim2.new(1,0,0,22),BackgroundTransparency=1,
        Text=string.upper(me.peer).." IS ONLINE!",TextColor3=C.green,TextSize=11,Font=Enum.Font.GothamBold},body)
    local scoreBar=RN("Frame",{AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,27),Size=UDim2.fromOffset(350,42),
        BackgroundColor3=C.card,BorderSizePixel=0},body);rr(scoreBar,13);rl(scoreBar,C.border,1)
    RN("TextLabel",{Position=UDim2.fromOffset(16,0),Size=UDim2.fromOffset(105,42),BackgroundTransparency=1,
        Text="MATEO",TextColor3=C.white,TextSize=13,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left},scoreBar)
    local scoreNums=RN("TextLabel",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(110,42),
        BackgroundTransparency=1,Text="0  —  0",TextColor3=C.white,TextSize=19,Font=Enum.Font.GothamBold},scoreBar)
    RN("TextLabel",{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-16,0,0),Size=UDim2.fromOffset(105,42),
        BackgroundTransparency=1,Text="NINA",TextColor3=C.white,TextSize=13,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Right},scoreBar)
    local rnd=RN("TextLabel",{Position=UDim2.fromOffset(0,76),Size=UDim2.new(1,0,0,20),BackgroundTransparency=1,
        Text="ROUND 1",TextColor3=C.muted,TextSize=11,Font=Enum.Font.GothamMedium},body)
    local msg=RN("TextLabel",{Position=UDim2.fromOffset(0,102),Size=UDim2.new(1,0,0,38),BackgroundTransparency=1,
        Text="CHOOSE YOUR MOVE",TextColor3=C.white,TextSize=18,Font=Enum.Font.GothamBold},body)
    local area=RN("Frame",{Position=UDim2.fromOffset(0,138),Size=UDim2.new(1,0,0,105),BackgroundTransparency=1},body)

    local function choice(name,sym,xp)
        local b=RN("TextButton",{Position=UDim2.new(xp,0,0,0),Size=UDim2.new(.31,0,1,0),BackgroundColor3=C.card,Text="",AutoButtonColor=false},area)
        rr(b,16); local st=rl(b,C.border,1.2)
        local ic=RN("TextLabel",{Position=UDim2.fromOffset(0,10),Size=UDim2.new(1,0,0,52),BackgroundTransparency=1,Text=sym,
            TextColor3=C.white,TextSize=40,Font=Enum.Font.GothamBold},b)
        local lb=RN("TextLabel",{Position=UDim2.new(0,0,1,-34),Size=UDim2.new(1,0,0,20),BackgroundTransparency=1,Text=name,
            TextColor3=C.muted,TextSize=11,Font=Enum.Font.GothamBold},b)
        return {b=b,st=st,ic=ic,lb=lb,name=name}
    end
    local cs={choice("ROCK","●",0),choice("PAPER","▤",.345),choice("SCISSORS","✂",.69)}
    local act=RN("TextButton",{AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,-90,1,0),Size=UDim2.fromOffset(170,42),
        BackgroundColor3=C.darkred,Text="REMATCH",TextColor3=C.white,TextSize=13,Font=Enum.Font.GothamBold,AutoButtonColor=false,Visible=false},body);rr(act,13);rl(act,C.red,1)
    local sec=RN("TextButton",{AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,90,1,0),Size=UDim2.fromOffset(170,42),
        BackgroundColor3=C.card2,Text="LEAVE",TextColor3=C.muted,TextSize=12,Font=Enum.Font.GothamBold,AutoButtonColor=false,Visible=false},body);rr(sec,12)
    local L=RN("TextLabel",{Position=UDim2.new(0,0,0,138),Size=UDim2.new(.48,0,0,105),BackgroundColor3=C.card,Text="",TextColor3=C.white,
        TextSize=44,Font=Enum.Font.GothamBold,Visible=false},body);rr(L,16);rl(L,C.border,1)
    local R=RN("TextLabel",{Position=UDim2.new(.52,0,0,138),Size=UDim2.new(.48,0,0,105),BackgroundColor3=C.card,Text="",TextColor3=C.white,
        TextSize=44,Font=Enum.Font.GothamBold,Visible=false},body);rr(R,16);rl(R,C.border,1)
    RN("TextLabel",{AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-7),Size=UDim2.new(1,0,0,16),BackgroundTransparency=1,
        Text=(tonumber(MY_ID)==558142136 and "MATEO" or "NINA"),TextColor3=C.muted,TextSize=10,Font=Enum.Font.GothamBold},L)
    RN("TextLabel",{AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-7),Size=UDim2.new(1,0,0,16),BackgroundTransparency=1,
        Text=string.upper(me.peer),TextColor3=C.muted,TextSize=10,Font=Enum.Font.GothamBold},R)

    -- Live RPS gameplay uses one deterministic shared session key on both clients.
    -- Phone invite/accept still owns launching the match; this only prevents each client
    -- from rejecting the other's choices because their local handoff IDs differ.
    local gid="SAINTS_RPS_MATEO_NINA_ACTIVE"
    local function leaveRPSView()
        if embeddedGameGui==g then embeddedGameGui=nil end
        pcall(function()
            g.Enabled=false
            g:Destroy()
        end)
        rpsEmbedded=nil
        rpsInviteEpoch+=1
        rpsLaunchToken+=1
        rpsLaunchReady=false
        rpsInviteState="idle"
        rpsInviteGameId=nil
        rpsInviteButton.Text="INVITE "..string.upper(me.peer)
        rpsInviteButton.Active=true

        -- Leaving RPS returns to gameplay, NOT to the opened phone.
        phone.Visible=false
        opened=false
        launcher.Visible=true
        inviteBadge.Visible=false
        badgeShadow.Visible=false

        -- Clear any phone-owned fullscreen dimmer/overlay that may have survived game mode.
        for _,obj in ipairs(gui:GetChildren()) do
            if obj~=phone and obj~=launcher and obj~=inviteBadge and obj~=badgeShadow and obj:IsA("GuiObject") then
                local n=string.lower(obj.Name)
                if string.find(n,"dim") or string.find(n,"overlay") or string.find(n,"backdrop") then
                    obj.Visible=false
                end
            end
        end
    end
    local mateoScore,ninaScore,roundNo=0,0,1
    local mine,theirs=nil,nil
    local mateoChoice,ninaChoice=nil,nil
    local resolved=false
    local resolvedRound=0
    local remMine,remPeer=false,false
    local state="playing"
    local sym={ROCK="●",PAPER="▤",SCISSORS="✂"}

    local function rsend(kind,data)
        data=data or {}
        data.__saints_rps=true
        data.kind=kind
        data.from=tonumber(MY_ID)
        data.gameId=gid
        if not rpsSharedSend then return false end
        return rpsSharedSend(kind,data)
    end
    local function scores()
        scoreNums.Text=("%d  —  %d"):format(mateoScore,ninaScore)
    end
    local function buttons(v) area.Visible=v for _,c in ipairs(cs) do c.b.Active=v end end
    local function resetVisual()
        for _,c in ipairs(cs) do c.b.BackgroundColor3=C.card;c.st.Color=C.border;c.ic.TextColor3=C.white;c.lb.TextColor3=C.muted;c.b.Active=true end
    end
    local function newRound()
        state="playing";resolved=false;mine=nil;theirs=nil;mateoChoice=nil;ninaChoice=nil;L.Visible=false;R.Visible=false
        resetVisual();buttons(true);act.Visible=false;sec.Visible=false
        rnd.Text="ROUND "..roundNo;msg.TextColor3=C.white;msg.Text="CHOOSE YOUR MOVE"
    end
    local function beats(a,b)
        return (a=="ROCK" and b=="SCISSORS")
            or (a=="SCISSORS" and b=="PAPER")
            or (a=="PAPER" and b=="ROCK")
    end
    local function finish()
        state="finished";buttons(false);L.Visible=true;R.Visible=true;rnd.Text="FINAL"
        local mateoWon=mateoScore>=3
        msg.Text=mateoWon and "MATEO WINS THE MATCH" or "NINA WINS THE MATCH"
        local localWon=(tonumber(MY_ID)==558142136 and mateoWon) or (tonumber(MY_ID)==998914239 and not mateoWon)
        msg.TextColor3=localWon and C.green or C.red
        act.Visible=true;sec.Visible=true;act.Text="REMATCH";sec.Text="LEAVE";remMine=false;remPeer=false
    end
    local function resolve()
        if resolved or not mine or not theirs then return end
        resolved=true;state="reveal";buttons(false)
        L.Text=sym[mine];R.Text=sym[theirs];L.Visible=true;R.Visible=true
        for _,v in ipairs({"3","2","1","SHOOT!"}) do
            msg.Text=v;task.wait(.3)
            if state~="reveal" then return end
        end

        -- Convert each client's local mine/theirs view into the same named choices.
        local mateoChoice,ninaChoice
        if tonumber(MY_ID)==558142136 then
            mateoChoice=mine
            ninaChoice=theirs
        else
            mateoChoice=theirs
            ninaChoice=mine
        end

        local tie=(mateoChoice==ninaChoice)
        if tie then
            msg.Text="TIE • RUN IT BACK"
            msg.TextColor3=C.yellow
        elseif beats(mateoChoice,ninaChoice) then
            mateoScore+=1
            msg.Text="MATEO WINS THE ROUND"
            msg.TextColor3=(tonumber(MY_ID)==558142136) and C.green or C.red
        else
            ninaScore+=1
            msg.Text="NINA WINS THE ROUND"
            msg.TextColor3=(tonumber(MY_ID)==998914239) and C.green or C.red
        end

        scores();task.wait(1.35)
        if state~="reveal" then return end
        if mateoScore>=3 or ninaScore>=3 then
            finish()
        else
            if not tie then roundNo+=1 end
            newRound()
        end
    end
    local function start(newId)
        mateoScore=0;ninaScore=0;roundNo=1;resolved=false;remMine=false;remPeer=false;scores();newRound()
    end
    local function lock(name)
        if state~="playing" or mine then return end
        mine=name
        for _,c in ipairs(cs) do
            c.b.Active=false
            if c.name==name then c.b.BackgroundColor3=Color3.fromRGB(52,25,31);c.st.Color=C.red;c.lb.TextColor3=C.white
            else c.ic.TextColor3=Color3.fromRGB(90,90,98);c.lb.TextColor3=Color3.fromRGB(80,80,88) end
        end
        msg.Text=name.." LOCKED • WAITING FOR "..string.upper(me.peer)
        rsend("choice",{choice=name,round=roundNo,userId=MY_ID})
        rsend("choice_probe",{round=roundNo,userId=MY_ID})
        local sentRound=roundNo
        task.spawn(function()
            for _=1,12 do
                task.wait(.25)
                if state~="playing" or roundNo~=sentRound or mine~=name or resolved then return end
                rsend("choice",{choice=name,round=sentRound,userId=MY_ID})
                rsend("choice_probe",{round=sentRound,userId=MY_ID})
            end
        end)
        if theirs then task.spawn(resolve) end
    end

    for _,c in ipairs(cs) do
        c.b.MouseButton1Click:Connect(function() lock(c.name) end)
        c.b.MouseEnter:Connect(function()
            if state=="playing" and not mine then rtw(c.b,{BackgroundColor3=Color3.fromRGB(43,27,32)});c.st.Color=C.red;rtw(c.ic,{TextColor3=Color3.fromRGB(255,255,255)}) end
        end)
        c.b.MouseLeave:Connect(function()
            if state=="playing" and not mine then rtw(c.b,{BackgroundColor3=C.card});c.st.Color=C.border end
        end)
    end

    local function premiumButton(btn,base,hoverColor,pressColor,strokeColor)
        btn.AutoButtonColor=false
        local sc=btn:FindFirstChildOfClass("UIStroke")
        btn.MouseEnter:Connect(function() if not btn.Visible then return end rtw(btn,{BackgroundColor3=hoverColor});if sc then rtw(sc,{Color=strokeColor or C.red,Thickness=1.35}) end end)
        btn.MouseLeave:Connect(function() if not btn.Visible then return end rtw(btn,{BackgroundColor3=base});if sc then rtw(sc,{Color=C.border,Thickness=1}) end end)
        btn.MouseButton1Down:Connect(function() rtw(btn,{BackgroundColor3=pressColor}) end)
        btn.MouseButton1Up:Connect(function() rtw(btn,{BackgroundColor3=hoverColor}) end)
    end
    premiumButton(act,C.darkred,Color3.fromRGB(139,29,43),Color3.fromRGB(92,18,29),C.red)
    premiumButton(sec,C.card2,Color3.fromRGB(43,43,52),Color3.fromRGB(25,25,31),Color3.fromRGB(91,91,105))
    premiumButton(x,C.card2,Color3.fromRGB(48,48,58),Color3.fromRGB(27,27,34),Color3.fromRGB(91,91,105))

    act.MouseButton1Click:Connect(function()
        if state=="finished" and not remMine then
            remMine=true;act.Text="REMATCH REQUESTED";rsend("rematch_request")
            if remPeer then
                if MY_ID==558142136 then
                    local id=HttpService:GenerateGUID(false)
                    rsend("rematch_start",{newGameId=id})
                    start(id)
                else
                    msg.Text="WAITING FOR MATEO TO START REMATCH"
                end
            end
        end
    end)
    sec.MouseButton1Click:Connect(function()
        if state=="finished" then rsend("leave");rpsEmbedded=nil;leaveRPSView() end
    end)
    x.MouseButton1Click:Connect(function()
        rsend("leave");rpsEmbedded=nil;leaveRPSView()
    end)

    rpsEmbedded={
        gui=g,
        gameId=function() return gid end,
        packet=function(p)
            if not p then return end
            local incomingGameId=tostring(p.gameId or "")
            if incomingGameId~=gid then return end
            local k=p.kind
            if k=="choice" and (state=="playing" or state=="reveal") and tonumber(p.round)==roundNo then
                local c=tostring(p.choice or ""):upper()
                if c=="ROCK" or c=="PAPER" or c=="SCISSORS" then
                    if not theirs then theirs=c end
                    rsend("choice_ack",{round=roundNo})
                    if mine and theirs then
                        task.spawn(resolve)
                    elseif not mine then
                        msg.Text=string.upper(me.peer).." LOCKED IN • YOUR MOVE"
                    end
                end
            elseif k=="choice_probe" and state=="playing" and tonumber(p.round)==roundNo then
                if mine then rsend("choice",{choice=mine,round=roundNo}) end
            elseif k=="choice_ack" and state=="playing" and tonumber(p.round)==roundNo then
                if mine and theirs then task.spawn(resolve) end
            elseif k=="rematch_request" and state=="finished" then
                remPeer=true
                if remMine then
                    if MY_ID==558142136 then
                        local id=HttpService:GenerateGUID(false)
                        rsend("rematch_start",{newGameId=id})
                        start(id)
                    else
                        msg.Text="WAITING FOR MATEO TO START REMATCH"
                    end
                else
                    msg.Text=string.upper(me.peer).." WANTS A REMATCH"
                    act.Text="ACCEPT REMATCH"
                end
            elseif k=="rematch_start" and state=="finished" and p.newGameId then
                start(p.newGameId)
            elseif k=="leave" then
                -- Peer leaving closes RPS immediately on this client too.
                leaveRPSView()
            end
        end
    }
    scores();newRound()
end

-- Tic-Tac-Toe invite transport.
-- Invites are intentionally temporary: 11 seconds on both clients.
-- Uses the phone's forward-declared shared socket.
local peerOnline=false
local tttState="idle" -- idle, invited, incoming, starting
local tttGameId=nil
local pendingInviteCount=0
local inviteEpoch=0
local INVITE_LIFETIME=11
local updateInviteBadge -- forward declaration: launchers need the local, not a nil global

local midnightInviteState="idle"
local midnightInviteGameId=nil
local midnightInviteEpoch=0
local rpsInviteState="idle"
local rpsInviteGameId=nil
local rpsInviteEpoch=0
local rpsLaunchReady=false
local rpsLaunchToken=0

-- Phase 1.49 start hook. The embedded board will replace this transition next.
local function launchTicTacToe(gameId,xPlayer)
    inviteEpoch+=1
    pendingInviteCount=0
    tttState="starting"
    tttGameId=tostring(gameId or "")
    updateInviteBadge()
    acceptInvite.Visible=false
    declineInvite.Visible=false
    invIcon.Text="!"
    invTitle.Text="Starting Tic-Tac-Toe"
    invDesc.Text="Both players accepted • opening game..."
    ticTacToeInviteButton.Text="STARTING..."
    ticTacToeInviteButton.TextColor3=GREEN
    ticTacToeInviteButton.BackgroundColor3=Color3.fromRGB(20,45,28)

    if openEmbeddedTicTacToe then
        openEmbeddedTicTacToe(tttGameId,tostring(xPlayer or MY_ID))
    end

    task.delay(.15,function()
        if tttState=="starting" and tostring(tttGameId)==tostring(gameId) then
            tttState="idle"
            tttGameId=nil
            ticTacToeInviteButton.Text="INVITE "..string.upper(me.peer)
            ticTacToeInviteButton.TextColor3=Color3.fromRGB(238,52,67)
            ticTacToeInviteButton.BackgroundColor3=Color3.fromRGB(33,10,14)
            invTitle.Text="No pending invites"
            invDesc.Text="Game started."
        end
    end)
end

sendPacket=function(tbl)
    if not connected or not socket then return false end
    return socketSend(socket,HttpService:JSONEncode(tbl))
end

-- =========================================================
-- PHASE 1.49 // EMBEDDED GAMES // SHARED PHONE RELAY
-- =========================================================
local embeddedGameGui=nil
local gameSuspendedPhone=false

local function suspendPhoneForGame()
    gameSuspendedPhone=true
    phone.Visible=false
    shade.Visible=false
    launcher.Visible=false
    inviteBadge.Visible=false
    badgeShadow.Visible=false
end

local function resumePhoneAfterGame()
    if not gameSuspendedPhone then return end
    gameSuspendedPhone=false

    opened=false
    phone.Visible=false
    shade.Visible=false
    shade.BackgroundTransparency=1

    home.Visible=true
    for _,p in pairs(pages) do p.Visible=false end
    currentPage=nil

    launcher.Visible=true
    updateInviteBadge()
end

local function closeEmbeddedGame(restorePhone)
    local oldGui=embeddedGameGui
    embeddedGameGui=nil
    if oldGui and oldGui.Parent then oldGui:Destroy() end
    if restorePhone~=false then task.defer(resumePhoneAfterGame) end
end

local function gameSend(gameName,kind,payload)
    payload=payload or {}
    payload.game=gameName
    payload.kind=kind
    payload.senderUserId=MY_ID
    return sendPacket({
        type="chat_message",
        to=PEER_ID,
        payload={__saints_game=true,game=payload}
    })
end

-- RPS V5.3 uses the already-proven phone relay without changing invite transport.
rpsSharedSend=function(kind,data)
    data=data or {}
    data.__saints_rps=true
    data.kind=kind
    data.from=tonumber(MY_ID)
    -- gameId is already supplied by the embedded RPS rsend()
    return sendPacket({
        type="chat_message",
        to=PEER_ID,
        payload=data
    })
end

-- -------------------------
-- TIC-TAC-TOE V4 PREMIUM
-- -------------------------
local tttEmbedded=nil

openEmbeddedTicTacToe=function(startId,xPlayer)
    closeEmbeddedGame(false)
    suspendPhoneForGame()

    local g=Instance.new("ScreenGui")
    g.Name="SaintsPhone_TicTacToe"
    g.ResetOnSpawn=false
    g.IgnoreGuiInset=true
    g.DisplayOrder=300
    g.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    g.Parent=pg
    embeddedGameGui=g

    local shell2=Instance.new("Frame")
    shell2.AnchorPoint=Vector2.new(.5,.5)
    shell2.Position=UDim2.fromScale(.5,.5)
    shell2.Size=UDim2.fromOffset(390,500)
    shell2.BackgroundColor3=Color3.fromRGB(7,7,10)
    shell2.BackgroundTransparency=.08
    shell2.BorderSizePixel=0
    shell2.Parent=g
    corner(shell2,16)
    stroke(shell2,Color3.fromRGB(112,28,37),1.25,.18)

    local ttl=label(shell2,"TIC  TAC  TOE",UDim2.new(1,-90,0,28),UDim2.fromOffset(20,13),Enum.Font.GothamBold,18,Color3.fromRGB(242,242,245))
    local xbtn=button(shell2,"×",UDim2.fromOffset(32,32),UDim2.new(1,-46,0,11))
    xbtn.BackgroundColor3=Color3.fromRGB(29,29,34); xbtn.TextSize=19

    local line2=Instance.new("Frame")
    line2.Position=UDim2.fromOffset(0,53); line2.Size=UDim2.new(1,0,0,1)
    line2.BackgroundColor3=Color3.fromRGB(105,29,36); line2.BackgroundTransparency=.25
    line2.BorderSizePixel=0; line2.Parent=shell2

    local accent=Instance.new("Frame")
    accent.Position=UDim2.fromOffset(20,51); accent.Size=UDim2.fromOffset(58,2)
    accent.BackgroundColor3=Color3.fromRGB(205,38,50); accent.BorderSizePixel=0; accent.Parent=shell2
    corner(accent,99)

    local statusDot=Instance.new("Frame")
    statusDot.Position=UDim2.fromOffset(20,72); statusDot.Size=UDim2.fromOffset(8,8)
    statusDot.BackgroundColor3=peerOnline and Color3.fromRGB(82,190,105) or Color3.fromRGB(110,110,115)
    statusDot.BorderSizePixel=0; statusDot.Parent=shell2; corner(statusDot,99)

    local status2=label(shell2,PEER_NAME..(peerOnline and " ONLINE" or " OFFLINE"),UDim2.new(1,-55,0,22),UDim2.fromOffset(35,65),Enum.Font.GothamMedium,11,Color3.fromRGB(175,218,183))
    local pill=label(shell2,"WAITING",UDim2.fromOffset(112,26),UDim2.new(1,-132,0,65),Enum.Font.GothamBold,10,Color3.fromRGB(190,190,198),Enum.TextXAlignment.Center)
    pill.BackgroundTransparency=0; pill.BackgroundColor3=Color3.fromRGB(25,25,31); corner(pill,99)

    local info2=label(shell2,"",UDim2.new(1,-40,0,38),UDim2.fromOffset(20,95),Enum.Font.GothamBold,14,Color3.fromRGB(210,210,215),Enum.TextXAlignment.Center)
    info2.TextWrapped=true

    local boardFrame=Instance.new("Frame")
    boardFrame.Position=UDim2.fromOffset(35,145); boardFrame.Size=UDim2.fromOffset(320,320)
    boardFrame.BackgroundColor3=Color3.fromRGB(11,11,15); boardFrame.BorderSizePixel=0; boardFrame.Parent=shell2
    corner(boardFrame,14); stroke(boardFrame,Color3.fromRGB(66,29,36),1,.18)

    local grid=Instance.new("UIGridLayout")
    grid.CellSize=UDim2.fromOffset(96,96); grid.CellPadding=UDim2.fromOffset(8,8)
    grid.FillDirectionMaxCells=3; grid.HorizontalAlignment=Enum.HorizontalAlignment.Center
    grid.VerticalAlignment=Enum.VerticalAlignment.Center; grid.Parent=boardFrame

    local cells={}
    for i=1,9 do
        local c=Instance.new("TextButton")
        c.Name="Cell"..i; c.LayoutOrder=i; c.BackgroundColor3=Color3.fromRGB(20,20,26)
        c.BackgroundTransparency=.06; c.BorderSizePixel=0; c.AutoButtonColor=false
        c.Font=Enum.Font.GothamBold; c.Text=""; c.TextSize=46; c.TextColor3=Color3.fromRGB(235,235,238)
        c.Parent=boardFrame; corner(c,12); stroke(c,Color3.fromRGB(67,67,76),1,.28)
        cells[i]=c
    end

    local action2=button(shell2,"REMATCH",UDim2.fromOffset(240,38),UDim2.new(.5,-120,1,-52))
    action2.BackgroundColor3=Color3.fromRGB(122,30,38); action2.Font=Enum.Font.GothamBold; action2.TextSize=12
    action2.Visible=false

    local state="playing"
    local board={"","","","","","","","",""}
    local myMark,peerMark,turn,winner
    local gameId=tostring(startId or "")

    local function refresh()
        for i=1,9 do
            local c=cells[i]
            local old=c.Text
            c.Text=board[i]
            c.BackgroundColor3=Color3.fromRGB(20,20,26)
            c.TextColor3=(board[i]=="X") and Color3.fromRGB(225,48,62) or Color3.fromRGB(238,238,242)
            if old=="" and board[i]~="" then
                c.TextTransparency=1; c.TextSize=34
                TweenService:Create(c,TweenInfo.new(.16,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{TextTransparency=0,TextSize=46}):Play()
            end
        end
    end

    local WINS={{1,2,3},{4,5,6},{7,8,9},{1,4,7},{2,5,8},{3,6,9},{1,5,9},{3,5,7}}
    local function result()
        for _,w in ipairs(WINS) do
            local a,b,c=w[1],w[2],w[3]
            if board[a]~="" and board[a]==board[b] and board[a]==board[c] then return board[a],w end
        end
        for i=1,9 do if board[i]=="" then return nil end end
        return "DRAW",nil
    end

    local function update()
        status2.Text=PEER_NAME..(peerOnline and " ONLINE" or " OFFLINE")
        statusDot.BackgroundColor3=peerOnline and Color3.fromRGB(82,190,105) or Color3.fromRGB(110,110,115)
        if state=="playing" then
            action2.Visible=false
            if turn==MY_ID then
                info2.Text="Your move  •  You are "..tostring(myMark)
                pill.Text="YOUR TURN"; pill.BackgroundColor3=Color3.fromRGB(116,28,38)
            else
                info2.Text=PEER_NAME.."'s move  •  You are "..tostring(myMark)
                pill.Text=string.upper(PEER_NAME).."'S TURN"; pill.BackgroundColor3=Color3.fromRGB(31,31,37)
            end
        elseif state=="ended" then
            pill.Text="GAME OVER"; pill.BackgroundColor3=Color3.fromRGB(31,31,37)
            info2.Text=(winner=="DRAW" and "Draw game.") or (winner==myMark and "You won.") or (PEER_NAME.." won.")
            action2.Text="REMATCH"; action2.Visible=true
        elseif state=="rematch_wait" then
            info2.Text="Waiting for "..PEER_NAME.." to rematch..."
            action2.Text="CANCEL"; action2.Visible=true
        elseif state=="incoming_rematch" then
            info2.Text=PEER_NAME.." wants a rematch."
            action2.Text="ACCEPT REMATCH"; action2.Visible=true
        end
    end

    local function startRound(id,xp)
        gameId=tostring(id); board={"","","","","","","","",""}; winner=nil
        myMark=(tostring(xp)==MY_ID) and "X" or "O"
        peerMark=(myMark=="X") and "O" or "X"
        turn=tostring(xp); state="playing"; refresh(); update()
    end

    local function finish()
        local r,w=result()
        if not r then return false end
        winner=r; state="ended"; turn=nil; update()
        if w then
            for _,n in ipairs(w) do
                local c=cells[n]
                TweenService:Create(c,TweenInfo.new(.22,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{
                    BackgroundColor3=(r=="X") and Color3.fromRGB(72,22,29) or Color3.fromRGB(48,48,57)
                }):Play()
            end
        end
        return true
    end

    for i,c in ipairs(cells) do
        c.MouseButton1Click:Connect(function()
            if state~="playing" or turn~=MY_ID or board[i]~="" then return end
            board[i]=myMark; refresh()
            gameSend("tic_tac_toe","move",{gameId=gameId,cell=i,mark=myMark})
            if not finish() then turn=PEER_ID; update() end
        end)
    end

    action2.MouseButton1Click:Connect(function()
        if state=="ended" then
            state="rematch_wait"; gameSend("tic_tac_toe","rematch",{gameId=gameId}); update()
        elseif state=="rematch_wait" then
            gameSend("tic_tac_toe","rematch_cancel",{gameId=gameId}); state="ended"; update()
        elseif state=="incoming_rematch" then
            local nextX=(myMark=="X") and PEER_ID or MY_ID
            local newId=HttpService:GenerateGUID(false)
            gameSend("tic_tac_toe","rematch_start",{gameId=newId,xPlayer=nextX})
            startRound(newId,nextX)
        end
    end)

    xbtn.MouseButton1Click:Connect(function()
        if state=="playing" then gameSend("tic_tac_toe","leave",{gameId=gameId}) end
        closeEmbeddedGame()
    end)

    tttEmbedded={
        gui=g,
        packet=function(p)
            if not g.Parent or type(p)~="table" or p.game~="tic_tac_toe" then return end
            local kind=p.kind
            if kind=="move" and state=="playing" and tostring(p.gameId)==gameId then
                local cell=tonumber(p.cell)
                if cell and cell>=1 and cell<=9 and turn==PEER_ID and board[cell]=="" and tostring(p.mark)==peerMark then
                    board[cell]=peerMark; refresh()
                    if not finish() then turn=MY_ID; update() end
                end
            elseif kind=="rematch" and state=="ended" then
                state="incoming_rematch"; update()
            elseif kind=="rematch" and state=="rematch_wait" then
                local nextX=(myMark=="X") and PEER_ID or MY_ID
                local newId=HttpService:GenerateGUID(false)
                gameSend("tic_tac_toe","rematch_start",{gameId=newId,xPlayer=nextX})
                startRound(newId,nextX)
            elseif kind=="rematch_start" then
                startRound(tostring(p.gameId),tostring(p.xPlayer))
            elseif kind=="rematch_cancel" and state=="rematch_wait" then
                state="ended"; update()
            elseif kind=="leave" and tostring(p.gameId)==gameId then
                state="ended"; winner=myMark; info2.Text=PEER_NAME.." left."; action2.Visible=true
            end
        end
    }

    startRound(gameId,tostring(xPlayer or MY_ID))
end

handleEmbeddedTicTacToePacket=function(p)
    if tttEmbedded and tttEmbedded.packet then tttEmbedded.packet(p) end
end

-- -------------------------
-- MIDNIGHT RUN V7
-- -------------------------
local midnightEmbedded=nil
local MIDNIGHT_ACTION="SaintsPhone_MidnightRun_Capture"

openEmbeddedMidnightRun=function(startPacket)
    closeEmbeddedGame(false)
    suspendPhoneForGame()

    local g=Instance.new("ScreenGui")
    g.Name="SaintsPhone_MidnightRun"
    g.ResetOnSpawn=false; g.IgnoreGuiInset=false; g.DisplayOrder=300
    g.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; g.Parent=pg
    embeddedGameGui=g

    local shell2=Instance.new("Frame")
    shell2.AnchorPoint=Vector2.new(.5,.5); shell2.Position=UDim2.fromScale(.5,.5)
    shell2.Size=UDim2.fromOffset(520,704); shell2.BackgroundColor3=Color3.fromRGB(3,6,14)
    shell2.BorderSizePixel=0; shell2.Parent=g; corner(shell2,18); stroke(shell2,Color3.fromRGB(45,66,112),1.25,0)

    local top2=Instance.new("Frame")
    top2.Size=UDim2.new(1,0,0,58); top2.BackgroundColor3=Color3.fromRGB(5,9,20); top2.BorderSizePixel=0; top2.Parent=shell2; corner(top2,14)
    local ttl=label(top2,"MIDNIGHT  RUN",UDim2.new(1,-90,1,0),UDim2.fromOffset(20,0),Enum.Font.GothamBold,20,Color3.fromRGB(245,245,248))
    local xbtn=button(top2,"×",UDim2.fromOffset(34,34),UDim2.new(1,-46,.5,-17)); xbtn.TextSize=20; xbtn.BackgroundColor3=Color3.fromRGB(26,26,31)

    local statusBar=Instance.new("Frame")
    statusBar.Position=UDim2.fromOffset(16,70); statusBar.Size=UDim2.new(1,-32,0,42); statusBar.BackgroundColor3=Color3.fromRGB(7,12,25); statusBar.BorderSizePixel=0; statusBar.Parent=shell2; corner(statusBar,10)
    local dot=Instance.new("Frame"); dot.Position=UDim2.fromOffset(13,16); dot.Size=UDim2.fromOffset(10,10); dot.BorderSizePixel=0; dot.Parent=statusBar; corner(dot,99)
    local peerStatus=label(statusBar,"",UDim2.new(.5,-31,1,0),UDim2.fromOffset(31,0),Enum.Font.GothamBold,11,Color3.fromRGB(170,170,178))
    local raceStatus=label(statusBar,"WAITING",UDim2.new(.5,-17,1,0),UDim2.new(.5,5,0,0),Enum.Font.GothamBold,11,Color3.fromRGB(205,205,212),Enum.TextXAlignment.Right)

    local gameFrame=Instance.new("Frame")
    gameFrame.Position=UDim2.fromOffset(16,123); gameFrame.Size=UDim2.new(1,-32,0,492)
    gameFrame.BackgroundColor3=Color3.fromRGB(4,8,18); gameFrame.BorderSizePixel=0; gameFrame.ClipsDescendants=true; gameFrame.Parent=shell2; corner(gameFrame,11)

    local WORLD_W,WORLD_H,PLAYER_SIZE,START_Y,FINISH_Y=488,492,20,454,24
    local bg=Instance.new("Frame"); bg.Size=UDim2.fromScale(1,1); bg.BackgroundColor3=Color3.fromRGB(6,10,22); bg.BorderSizePixel=0; bg.Parent=gameFrame

    local wash=Instance.new("Frame"); wash.Size=UDim2.fromOffset(WORLD_W,128); wash.BackgroundColor3=Color3.fromRGB(8,15,36); wash.BackgroundTransparency=.08; wash.BorderSizePixel=0; wash.Parent=bg
    local grad=Instance.new("UIGradient"); grad.Rotation=90; grad.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(12,22,52)),ColorSequenceKeypoint.new(1,Color3.fromRGB(5,10,23))}); grad.Parent=wash

    local glow=Instance.new("Frame"); glow.AnchorPoint=Vector2.new(.5,.5); glow.Position=UDim2.fromOffset(432,53); glow.Size=UDim2.fromOffset(64,64); glow.BackgroundColor3=Color3.fromRGB(151,177,226); glow.BackgroundTransparency=.84; glow.BorderSizePixel=0; glow.ZIndex=2; glow.Parent=bg; corner(glow,99)
    local moon=Instance.new("Frame"); moon.AnchorPoint=Vector2.new(.5,.5); moon.Position=UDim2.fromOffset(432,53); moon.Size=UDim2.fromOffset(34,34); moon.BackgroundColor3=Color3.fromRGB(232,238,250); moon.BorderSizePixel=0; moon.ZIndex=3; moon.Parent=bg; corner(moon,99)
    local cut=Instance.new("Frame"); cut.Position=UDim2.fromOffset(10,-4); cut.Size=UDim2.fromOffset(32,32); cut.BackgroundColor3=Color3.fromRGB(9,17,39); cut.BorderSizePixel=0; cut.ZIndex=4; cut.Parent=moon; corner(cut,99)

    for _,st in ipairs({{28,25,2},{63,47,1},{103,20,2},{142,56,1},{181,31,1},{225,18,2},{268,49,1},{309,27,2},{346,61,1},{384,22,1},{463,84,1},{333,93,1},{196,83,1},{82,91,1}}) do
        local star=Instance.new("Frame"); star.Position=UDim2.fromOffset(st[1],st[2]); star.Size=UDim2.fromOffset(st[3],st[3]); star.BackgroundColor3=Color3.fromRGB(211,222,246); star.BackgroundTransparency=(st[3]==1) and .38 or .12; star.BorderSizePixel=0; star.ZIndex=3; star.Parent=bg; corner(star,99)
    end
    for _,b in ipairs({{0,45},{116,145},{218,247},{424,492}}) do
        local f=Instance.new("Frame"); f.Position=UDim2.fromOffset(0,b[1]); f.Size=UDim2.fromOffset(WORLD_W,b[2]-b[1]); f.BackgroundColor3=Color3.fromRGB(8,24,29); f.BorderSizePixel=0; f.Parent=bg
    end
    for _,y in ipairs({73,169,276,382}) do
        local ln=Instance.new("Frame"); ln.Position=UDim2.fromOffset(0,y); ln.Size=UDim2.fromOffset(WORLD_W,2); ln.BackgroundColor3=Color3.fromRGB(70,88,122); ln.BackgroundTransparency=.45; ln.BorderSizePixel=0; ln.Parent=bg
        for x=8,WORLD_W-20,38 do local d=Instance.new("Frame"); d.Position=UDim2.fromOffset(x,-1); d.Size=UDim2.fromOffset(19,2); d.BackgroundColor3=Color3.fromRGB(135,155,194); d.BackgroundTransparency=.45; d.BorderSizePixel=0; d.Parent=ln end
    end
    local finish=Instance.new("Frame"); finish.Position=UDim2.fromOffset(0,FINISH_Y); finish.Size=UDim2.fromOffset(WORLD_W,4); finish.BackgroundColor3=Color3.fromRGB(215,35,49); finish.BorderSizePixel=0; finish.Parent=bg
    for x=0,WORLD_W-12,12 do local ck=Instance.new("Frame"); ck.Position=UDim2.fromOffset(x,FINISH_Y-5); ck.Size=UDim2.fromOffset(12,5); ck.BackgroundColor3=((math.floor(x/12)%2)==0) and Color3.fromRGB(235,235,240) or Color3.fromRGB(42,42,47); ck.BorderSizePixel=0; ck.ZIndex=6; ck.Parent=bg end

    local function runner(txt,color,x)
        local h=Instance.new("Frame"); h.Size=UDim2.fromOffset(PLAYER_SIZE,PLAYER_SIZE); h.Position=UDim2.fromOffset(x,START_Y); h.BackgroundColor3=color; h.BorderSizePixel=0; h.ZIndex=20; h.Parent=gameFrame; corner(h,6); stroke(h,Color3.fromRGB(235,235,240),1.2,.28)
        local core=Instance.new("Frame"); core.AnchorPoint=Vector2.new(.5,.5); core.Position=UDim2.fromScale(.5,.5); core.Size=UDim2.fromOffset(8,8); core.BackgroundColor3=Color3.fromRGB(250,250,252); core.BackgroundTransparency=.15; core.BorderSizePixel=0; core.ZIndex=21; core.Parent=h; corner(core,99)
        local nm=label(h,txt,UDim2.fromOffset(70,16),UDim2.new(.5,-35,0,-19),Enum.Font.GothamBold,9,Color3.fromRGB(245,245,248),Enum.TextXAlignment.Center); nm.ZIndex=21
        return h
    end
    local myRunner=runner(me.name,Color3.fromRGB(196,38,49),205)
    local peerRunner=runner(PEER_NAME,Color3.fromRGB(225,225,230),247); peerRunner.BackgroundTransparency=.08

    local overlay=Instance.new("Frame"); overlay.Size=UDim2.fromScale(1,1); overlay.BackgroundColor3=Color3.fromRGB(3,7,16); overlay.BackgroundTransparency=.22; overlay.BorderSizePixel=0; overlay.ZIndex=50; overlay.Parent=gameFrame
    local big=label(overlay,"MIDNIGHT RUN",UDim2.new(1,-40,0,50),UDim2.new(0,20,.44,-25),Enum.Font.GothamBlack,30,Color3.fromRGB(248,248,250),Enum.TextXAlignment.Center); big.ZIndex=51
    local small=label(overlay,"Race beneath the moon through midnight traffic",UDim2.new(1,-50,0,42),UDim2.new(0,25,.56,-21),Enum.Font.GothamMedium,11,Color3.fromRGB(172,172,182),Enum.TextXAlignment.Center); small.TextWrapped=true; small.ZIndex=51

    local action=button(shell2,"",UDim2.new(1,-32,0,48),UDim2.fromOffset(16,627)); action.BackgroundColor3=Color3.fromRGB(188,31,44); action.Font=Enum.Font.GothamBold; action.TextSize=12
    local hint=label(shell2,"WASD / ARROWS  •  dodge traffic  •  first to finish wins",UDim2.new(1,-32,0,16),UDim2.fromOffset(16,680),Enum.Font.GothamMedium,9,Color3.fromRGB(105,105,115),Enum.TextXAlignment.Center)

    local state="idle"; local gameId=nil; local winner=nil; local seed=nil
    local myX,myY=205,START_Y; local peerX,peerY=247,START_Y; local peerTX,peerTY=247,START_Y
    local myAlive=true; local raceStartedAt=0; local lastMoveSend=0; local sendInterval=.04
    local cars={}; local defs={}; local keys={up=false,down=false,left=false,right=false}; local raceStartedAt=0
    local renderConn=nil

    local function setPresence()
        dot.BackgroundColor3=peerOnline and Color3.fromRGB(56,190,100) or Color3.fromRGB(105,105,112)
        peerStatus.Text=PEER_NAME..(peerOnline and " ONLINE" or " OFFLINE")
    end
    local function clearCars()
        for _,c in ipairs(cars) do if c.frame then c.frame:Destroy() end end
        cars={}; defs={}
    end
    local function resetPos()
        myX,myY=205,START_Y; peerX,peerY=247,START_Y; peerTX,peerTY=247,START_Y; myAlive=true
        myRunner.Position=UDim2.fromOffset(myX,myY); peerRunner.Position=UDim2.fromOffset(peerX,peerY)
    end
    local function updateUI()
        setPresence()
        if state=="idle" then overlay.Visible=true; big.Text="MIDNIGHT RUN"; small.Text=peerOnline and ("Invite "..PEER_NAME.." to race") or ("Waiting for "..PEER_NAME.." to come online"); action.Text="INVITE "..string.upper(PEER_NAME); action.Active=peerOnline; raceStatus.Text="WAITING"
        elseif state=="invited" then overlay.Visible=true; big.Text="INVITE SENT"; small.Text="Waiting for "..PEER_NAME.."..."; action.Text="WAITING..."; action.Active=false; raceStatus.Text="INVITED"
        elseif state=="incoming" then overlay.Visible=true; big.Text=PEER_NAME.." CHALLENGED YOU"; small.Text="Press ACCEPT to start Midnight Run"; action.Text="ACCEPT RACE"; action.Active=true; raceStatus.Text="INVITE"
        elseif state=="countdown" then overlay.Visible=true; action.Text="GET READY"; action.Active=false; raceStatus.Text="COUNTDOWN"
        elseif state=="playing" then overlay.Visible=false; action.Text="RACE IN PROGRESS"; action.Active=false; raceStatus.Text="RACING"
        elseif state=="ended" then overlay.Visible=true; big.Text=(winner==tonumber(MY_ID)) and "YOU WIN" or ((winner==tonumber(PEER_ID)) and (PEER_NAME.." WINS") or "RACE OVER"); small.Text="Run it back?"; action.Text="REMATCH"; action.Active=peerOnline; raceStatus.Text="FINISHED" end
    end

    local LANES={{y=42,speed=104,dir=1,count=3,width=46},{y=72,speed=128,dir=-1,count=3,width=50},{y=101,speed=112,dir=1,count=4,width=40},{y=137,speed=136,dir=-1,count=3,width=52},{y=167,speed=116,dir=1,count=4,width=42},{y=198,speed=148,dir=-1,count=3,width=48},{y=244,speed=122,dir=1,count=4,width=44},{y=274,speed=154,dir=-1,count=3,width=54},{y=305,speed=130,dir=1,count=4,width=42},{y=352,speed=138,dir=-1,count=3,width=50},{y=383,speed=120,dir=1,count=4,width=43},{y=413,speed=160,dir=-1,count=3,width=48}}
    local function makeCourse(sd)
        clearCars(); seed=sd; local rng=Random.new(sd)
        for li,lane in ipairs(LANES) do
            local spacing=WORLD_W/lane.count; local phase=rng:NextNumber(0,spacing)
            for i=1,lane.count do
                local w=lane.width+rng:NextInteger(-4,7)
                local d={lane=li,y=lane.y,speed=lane.speed*lane.dir,width=w,x0=phase+(i-1)*spacing,tint=rng:NextInteger(0,2)}
                table.insert(defs,d)
                local f=Instance.new("Frame"); f.Size=UDim2.fromOffset(w,21); f.BackgroundColor3=(d.tint==0 and Color3.fromRGB(148,34,44)) or (d.tint==1 and Color3.fromRGB(67,70,78)) or Color3.fromRGB(188,188,194); f.BorderSizePixel=0; f.ZIndex=10; f.Parent=gameFrame; corner(f,5)
                local hl=Instance.new("Frame"); hl.Size=UDim2.fromOffset(4,5); hl.Position=(d.speed>0) and UDim2.new(1,-4,.5,-2) or UDim2.new(0,0,.5,-2); hl.BackgroundColor3=Color3.fromRGB(244,232,176); hl.BorderSizePixel=0; hl.Parent=f
                local tl=Instance.new("Frame"); tl.Size=UDim2.fromOffset(3,5); tl.Position=(d.speed>0) and UDim2.new(0,0,.5,-2) or UDim2.new(1,-3,.5,-2); tl.BackgroundColor3=Color3.fromRGB(221,48,61); tl.BorderSizePixel=0; tl.Parent=f
                table.insert(cars,{frame=f,def=d,x=d.x0})
            end
        end
    end
    local function updateCars(t)
        for _,c in ipairs(cars) do local d=c.def; local span=WORLD_W+d.width+35; local x=(d.speed>0) and (((d.x0+t*math.abs(d.speed))%span)-d.width) or (WORLD_W-((d.x0+t*math.abs(d.speed))%span)); c.x=x; c.frame.Position=UDim2.fromOffset(x,d.y) end
    end
    local function overlaps(px,py,pw,ph,cx,cy,cw,ch) return px<cx+cw and px+pw>cx and py<cy+ch and py+ph>cy end
    local function hitCar(x,y) for _,c in ipairs(cars) do if overlaps(x+2,y+2,PLAYER_SIZE-4,PLAYER_SIZE-4,c.x,c.def.y,c.def.width,21) then return true end end return false end
    local function respawn()
        myAlive=false; myRunner.BackgroundTransparency=.65
        task.delay(.42,function() if not g.Parent then return end; myX,myY=205,START_Y; myRunner.Position=UDim2.fromOffset(myX,myY); myRunner.BackgroundTransparency=0; myAlive=true; gameSend("midnight_run","position",{gameId=gameId,x=myX,y=myY,respawn=true}) end)
    end
    local function begin(sd,id)
        gameId=tostring(id); makeCourse(sd); resetPos(); winner=nil; state="countdown"; updateUI()
        task.spawn(function()
            for n=5,1,-1 do if state~="countdown" then return end; big.Text=tostring(n); small.Text="Get ready..."; task.wait(1) end
            if state~="countdown" then return end; big.Text="GO!"; small.Text=""; task.wait(.35)
            if state~="countdown" then return end; raceStartedAt=os.clock(); state="playing"; updateUI()
        end)
    end
    local function endRace(w,broadcast)
        if state=="ended" then return end; winner=tonumber(w); state="ended"; keys={up=false,down=false,left=false,right=false}; updateUI()
        if broadcast then gameSend("midnight_run","finish",{gameId=gameId,winner=winner}) end
    end

    ContextActionService:BindActionAtPriority(MIDNIGHT_ACTION,function(_,inputState,inputObject)
        local down=(inputState==Enum.UserInputState.Begin or inputState==Enum.UserInputState.Change)
        local released=(inputState==Enum.UserInputState.End or inputState==Enum.UserInputState.Cancel)
        if down or released then
            local v=down
            local k=inputObject.KeyCode
            if k==Enum.KeyCode.W or k==Enum.KeyCode.Up then keys.up=v elseif k==Enum.KeyCode.S or k==Enum.KeyCode.Down then keys.down=v elseif k==Enum.KeyCode.A or k==Enum.KeyCode.Left then keys.left=v elseif k==Enum.KeyCode.D or k==Enum.KeyCode.Right then keys.right=v end
        end
        return Enum.ContextActionResult.Sink
    end,false,10000,Enum.KeyCode.W,Enum.KeyCode.A,Enum.KeyCode.S,Enum.KeyCode.D,Enum.KeyCode.Up,Enum.KeyCode.Down,Enum.KeyCode.Left,Enum.KeyCode.Right)

    action.MouseButton1Click:Connect(function()
        if state=="idle" and peerOnline then gameId=HttpService:GenerateGUID(false); state="invited"; updateUI(); gameSend("midnight_run","invite",{gameId=gameId})
        elseif state=="incoming" then local sd=math.random(100000,999999999); gameSend("midnight_run","accept",{gameId=gameId,seed=sd}); gameSend("midnight_run","start",{gameId=gameId,seed=sd}); begin(sd,gameId)
        elseif state=="ended" and peerOnline then gameId=HttpService:GenerateGUID(false); state="invited"; updateUI(); gameSend("midnight_run","rematch",{gameId=gameId}) end
    end)

    xbtn.MouseButton1Click:Connect(function()
        if state=="playing" or state=="countdown" then gameSend("midnight_run","leave",{gameId=gameId}) end
        pcall(function() ContextActionService:UnbindAction(MIDNIGHT_ACTION) end)
        if renderConn then renderConn:Disconnect() end
        closeEmbeddedGame()
    end)
    g.Destroying:Connect(function()
        pcall(function() ContextActionService:UnbindAction(MIDNIGHT_ACTION) end)
        if renderConn then pcall(function() renderConn:Disconnect() end) end
    end)

    midnightEmbedded={
        gui=g,
        packet=function(p)
            if not g.Parent or type(p)~="table" or p.game~="midnight_run" then return end
            local kind=p.kind
            if kind=="invite" then gameId=tostring(p.gameId); state="incoming"; updateUI()
            elseif kind=="accept" and state=="invited" and tonumber(p.seed) then begin(tonumber(p.seed),p.gameId)
            elseif kind=="start" and tonumber(p.seed) then begin(tonumber(p.seed),p.gameId)
            elseif kind=="position" and tostring(p.gameId)==gameId then local x,y=tonumber(p.x),tonumber(p.y); if x and y then peerTX=math.clamp(x,0,WORLD_W-PLAYER_SIZE); peerTY=math.clamp(y,FINISH_Y,START_Y) end
            elseif kind=="hit" and tostring(p.gameId)==gameId then peerRunner.BackgroundTransparency=.65; task.delay(.42,function() if peerRunner.Parent then peerX,peerY=247,START_Y; peerTX,peerTY=peerX,peerY; peerRunner.Position=UDim2.fromOffset(peerX,peerY); peerRunner.BackgroundTransparency=.08 end end)
            elseif kind=="finish" and tostring(p.gameId)==gameId then endRace(p.winner,false)
            elseif kind=="leave" and tostring(p.gameId)==gameId then winner=tonumber(MY_ID); state="ended"; updateUI(); big.Text=PEER_NAME.." LEFT"; small.Text="Race ended."
            elseif kind=="rematch" and state=="ended" then gameId=tostring(p.gameId); state="incoming"; updateUI(); big.Text="REMATCH?"; small.Text=PEER_NAME.." wants another race" end
        end
    }

    local packet=startPacket
    if type(packet)=="table" and packet.gameId and packet.phoneAccepted and tonumber(packet.seed) then
        gameId=tostring(packet.gameId)
        begin(tonumber(packet.seed),gameId)
    elseif type(packet)=="table" and packet.gameId then
        gameId=tostring(packet.gameId); state=packet.incoming and "incoming" or "invited"; updateUI()
    else
        state="idle"; updateUI()
    end

    local last=os.clock()
    renderConn=RunService.RenderStepped:Connect(function()
        local now=os.clock(); local dt=math.min(now-last,.05); last=now
        if state=="playing" then
            local t=now-raceStartedAt; updateCars(t)
            local a=math.clamp(dt*18,0,1); peerX=peerX+(peerTX-peerX)*a; peerY=peerY+(peerTY-peerY)*a; peerRunner.Position=UDim2.fromOffset(peerX,peerY)
            if myAlive then
                local dx,dy=0,0; if keys.left then dx-=1 end; if keys.right then dx+=1 end; if keys.up then dy-=1 end; if keys.down then dy+=1 end
                if dx~=0 or dy~=0 then local mag=math.sqrt(dx*dx+dy*dy); dx,dy=dx/mag,dy/mag; local speed=132; myX=math.clamp(myX+dx*speed*dt,0,WORLD_W-PLAYER_SIZE); myY=math.clamp(myY+dy*speed*dt,FINISH_Y-2,START_Y); myRunner.Position=UDim2.fromOffset(myX,myY) end
                if hitCar(myX,myY) then gameSend("midnight_run","hit",{gameId=gameId,x=myX,y=myY}); respawn() elseif myY<=FINISH_Y then endRace(MY_ID,true) end
                if now-lastMoveSend>=sendInterval then lastMoveSend=now; gameSend("midnight_run","position",{gameId=gameId,x=math.floor(myX*10+.5)/10,y=math.floor(myY*10+.5)/10}) end
            end
        end
    end)
end

handleEmbeddedMidnightPacket=function(p)
    if midnightEmbedded and midnightEmbedded.packet then midnightEmbedded.packet(p) end
end


-- ===== Saint's Remote Control V6.1 mechanics, integrated into the PHONE'S shared relay =====
local controlling=false
local beingControlled=false
local claimPending=false
local controlOwner=nil
local held={W=false,A=false,S=false,D=false}
local jumpHeld=false
local shiftHeld=false
local remote={x=0,z=0,jump=false,shift=false,seq=0}
local remotePrevJump=false
local remoteExtraJumps=1
local remoteJumpResetToken=0
local savedCameraSubject=nil
local savedCameraType=nil
local crawlSnapshot=nil
local lastRemoteAt=0
local seq=0
local freezeSnapshot=nil
local sessionId=0
local endingSession=false
local controlSinkBound=false

local function sendControl(kind,payload)
    payload=payload or {}
    payload.__saints_remote_control=true
    payload.kind=kind
    return sendPacket({type="chat_message",to=PEER_ID,payload=payload})
end

local function updatePeerPresenceUI()
    if not peerPresenceLabel then return end
    if peerOnline then
        peerPresenceLabel.Text=string.upper(PEER_NAME).." • ONLINE"
        peerPresenceLabel.TextColor3=Color3.fromRGB(112,214,139)
    else
        peerPresenceLabel.Text=string.upper(PEER_NAME).." • OFFLINE"
        peerPresenceLabel.TextColor3=Color3.fromRGB(145,145,152)
    end
    if forceChatPresence then
        forceChatPresence.Text=string.upper(PEER_NAME)..(peerOnline and " • ONLINE" or " • OFFLINE")
        forceChatPresence.TextColor3=peerOnline and GREEN or Color3.fromRGB(145,145,152)
    end
end

local function updateControlUI()
    updatePeerPresenceUI()
    if not controlButton then return end
    if controlling then
        controlStatus.Text="CONTROL ACTIVE • YOU → "..string.upper(PEER_NAME)
        controlInfo.Text="WASD + SPACE + SHIFT • camera locked to "..PEER_NAME.."."
        controlButton.Text="END CONTROL"
        controlButton.BackgroundColor3=Color3.fromRGB(85,31,38)
        controlButton.Active=true
        controlButton.AutoButtonColor=false
    elseif beingControlled then
        controlStatus.Text=string.upper(PEER_NAME).." IS CONTROLLING YOU"
        controlInfo.Text="Your own movement stays active — you can fight the remote input."
        controlButton.Text="CONTROL SLOT OCCUPIED"
        controlButton.BackgroundColor3=Color3.fromRGB(48,48,54)
        controlButton.Active=false
        controlButton.AutoButtonColor=false
    elseif claimPending then
        controlStatus.Text="CLAIMING CONTROL..."
        controlInfo.Text="Waiting for the shared control slot."
        controlButton.Text="CLAIMING..."
        controlButton.BackgroundColor3=Color3.fromRGB(55,55,62)
        controlButton.Active=false
    elseif controlOwner and tostring(controlOwner)~=MY_ID then
        controlStatus.Text="CONTROL SLOT • OCCUPIED"
        controlInfo.Text=PEER_NAME.." currently owns the control slot."
        controlButton.Text="UNAVAILABLE"
        controlButton.BackgroundColor3=Color3.fromRGB(48,48,54)
        controlButton.Active=false
    else
        controlOwner=nil
        controlStatus.Text="CONTROL SLOT • FREE"
        controlInfo.Text="First person to claim the slot controls the other player."
        controlButton.Text="CONTROL "..string.upper(PEER_NAME)
        controlButton.BackgroundColor3=Color3.fromRGB(142,27,38)
        controlButton.Active=true
    end
end

local function currentHum()
 local c=LP.Character
 return c and c:FindFirstChildOfClass("Humanoid"),c and c:FindFirstChild("HumanoidRootPart")
end
local function peerHum()
 -- Phone me.peer is the DISPLAY NAME ("Nina"/"Mateo").
 -- V6.1 requires the numeric peer UserId here.
 local peer=Players:GetPlayerByUserId(tonumber(PEER_ID))
 local c=peer and peer.Character
 return c and c:FindFirstChildOfClass("Humanoid")
end
local function setPeerPOV(on)
 local cam=workspace.CurrentCamera
 if not cam then return end
 if on then
  if savedCameraSubject==nil then savedCameraSubject=cam.CameraSubject; savedCameraType=cam.CameraType end
  local ph=peerHum()
  if ph then cam.CameraType=Enum.CameraType.Custom; cam.CameraSubject=ph end
 else
  local h=currentHum()
  cam.CameraType=savedCameraType or Enum.CameraType.Custom
  cam.CameraSubject=(savedCameraSubject and savedCameraSubject.Parent and savedCameraSubject) or h
  savedCameraSubject=nil; savedCameraType=nil
 end
end
-- Exact FTF crawl, verified in solo V9.7.
local crawlTrack=nil
local crawlMoveTrack=nil
local crawlMoving=false

local function loadRemoteCrawlTrack(h,id,name)
 local animator=h:FindFirstChildOfClass("Animator") or Instance.new("Animator",h)
 local a=Instance.new("Animation"); a.AnimationId="rbxassetid://"..id
 local t=animator:LoadAnimation(a)
 t.Name=name; t.Priority=Enum.AnimationPriority.Movement; t.Looped=true
 return t
end

local function clearRemoteCrawlTracks(fade)
 fade=fade or .10
 if crawlTrack and crawlTrack.IsPlaying then pcall(function() crawlTrack:Stop(fade) end) end
 if crawlMoveTrack and crawlMoveTrack.IsPlaying then pcall(function() crawlMoveTrack:Stop(fade) end) end
 crawlTrack=nil; crawlMoveTrack=nil; crawlMoving=false
end

local function ensureRemoteCrawlTracks(h)
 if crawlTrack and crawlMoveTrack then return end
 clearRemoteCrawlTracks(0)
 crawlTrack=loadRemoteCrawlTrack(h,"17616199626","Prone")
 crawlMoveTrack=loadRemoteCrawlTrack(h,"17616193642","ProneMove")
end

local function applyRemoteCrawl(on,moving)
 local h=currentHum()
 local c=LP.Character
 if not h or not c then return end

 if on then
  local rr=c:FindFirstChild("HumanoidRootPart")
  if beingControlled and rr and rr.Anchored then rr.Anchored=false end
  if not crawlSnapshot or crawlSnapshot.hum~=h then
   clearRemoteCrawlTracks(0)
   crawlSnapshot={hum=h,char=c,hip=h.HipHeight,ws=h.WalkSpeed,crouching=c:GetAttribute("Crouching")}
   ensureRemoteCrawlTracks(h)
   c:SetAttribute("Crouching",true)
   h.WalkSpeed=6
   h.HipHeight=-2
   crawlMoving=false
   crawlTrack.TimePosition=0
   crawlTrack:Play(.12,1,1)
  else
   if h.WalkSpeed>6.05 then h.WalkSpeed=6 end
   if math.abs(h.HipHeight+2)>.05 then h.HipHeight=-2 end
   if c:GetAttribute("Crouching")~=true then c:SetAttribute("Crouching",true) end
  end

  moving=moving==true
  if crawlMoving~=moving then
   crawlMoving=moving
   if moving then
    local phase=(crawlTrack and crawlTrack.IsPlaying) and crawlTrack.TimePosition or 0
    if crawlTrack and crawlTrack.IsPlaying then crawlTrack:Stop(.10) end
    if crawlMoveTrack and not crawlMoveTrack.IsPlaying then
     crawlMoveTrack.TimePosition=phase
     crawlMoveTrack:Play(.10,1,1)
    end
   else
    local phase=(crawlMoveTrack and crawlMoveTrack.IsPlaying) and crawlMoveTrack.TimePosition or 0
    if crawlMoveTrack and crawlMoveTrack.IsPlaying then crawlMoveTrack:Stop(.10) end
    if crawlTrack and not crawlTrack.IsPlaying then
     crawlTrack.TimePosition=phase
     crawlTrack:Play(.10,1,1)
    end
   end
  end
 else
  local snap=crawlSnapshot
  crawlSnapshot=nil
  clearRemoteCrawlTracks(.12)
  if snap and snap.hum and snap.hum.Parent then
   if math.abs(snap.hum.HipHeight+2)<.2 then snap.hum.HipHeight=snap.hip end
   if math.abs(snap.hum.WalkSpeed-6)<.25 then snap.hum.WalkSpeed=snap.ws end
  end
  if snap and snap.char and snap.char.Parent then
   snap.char:SetAttribute("Crouching",snap.crouching)
  elseif c and c.Parent then
   c:SetAttribute("Crouching",false)
  end
 end
end

local function freezeOwn(on)
 local h,r=currentHum()
 if on then
  if not h or not r or freezeSnapshot then return end
  freezeSnapshot={
   root=r,
   anchored=r.Anchored,
   ws=(h.WalkSpeed>0 and h.WalkSpeed or 16),
   ar=h.AutoRotate,
   hip=h.HipHeight,
   crouching=(LP.Character and LP.Character:GetAttribute("Crouching"))
  }
  r.AssemblyLinearVelocity=Vector3.zero
  r.AssemblyAngularVelocity=Vector3.zero
  r.Anchored=true
  h.WalkSpeed=0
  h.AutoRotate=false
  if LP.Character then LP.Character:SetAttribute("Crouching",false) end
  local animator=h:FindFirstChildOfClass("Animator")
  if animator then
   for _,track in ipairs(animator:GetPlayingAnimationTracks()) do
    if track.Name=="Prone" or track.Name=="ProneMove" then
     pcall(function() track:Stop(0) end)
    end
   end
  end
 else
  local snap=freezeSnapshot
  freezeSnapshot=nil
  if r and r.Parent then
   -- END CONTROL always releases our local root.
   r.Anchored=false
   r.AssemblyLinearVelocity=Vector3.zero
   r.AssemblyAngularVelocity=Vector3.zero
  end
  if h and h.Parent then
   h.WalkSpeed=(snap and snap.ws and snap.ws>0) and snap.ws or 16
   h.AutoRotate=true
   h.PlatformStand=false
   h.Sit=false
   if snap and snap.hip~=nil and not crawlSnapshot then h.HipHeight=snap.hip end
  end
  local ch=LP.Character
  if ch and snap and snap.crouching~=nil and not crawlSnapshot then
   ch:SetAttribute("Crouching",snap.crouching)
  end
 end
end
local function isGroundedFTF(h)
 if h.FloorMaterial~=Enum.Material.Air then return true end
 local st=h:GetState()
 return st==Enum.HumanoidStateType.Landed
     or st==Enum.HumanoidStateType.Running
     or st==Enum.HumanoidStateType.RunningNoPhysics
     or st==Enum.HumanoidStateType.Seated
end

local function scheduleRemoteDoubleJumpReset(h)
 remoteJumpResetToken+=1
 local token=remoteJumpResetToken
 task.spawn(function()
  task.wait(3)
  while connected and h and h.Parent and token==remoteJumpResetToken do
   if h.Health<=0 then remoteExtraJumps=1 return end
   if isGroundedFTF(h) then remoteExtraJumps=1 return end
   task.wait(.1)
  end
  if token==remoteJumpResetToken then remoteExtraJumps=1 end
 end)
end

local function processRemoteJumpPress(h)
 if not h or not h.Parent then return end
 if not h:GetStateEnabled(Enum.HumanoidStateType.Jumping) or h.JumpPower<=0 then return end
 if h:GetState()==Enum.HumanoidStateType.Freefall then
  if remoteExtraJumps>=1 then
   remoteExtraJumps-=1
   h:ChangeState(Enum.HumanoidStateType.Jumping,true)
   if remoteExtraJumps==0 then scheduleRemoteDoubleJumpReset(h) end
  end
 else
  h.Jump=true
 end
end


local CONTROL_SINK_ACTION="SaintsRemoteControllerShiftSink"
local controlSinkBound=false
local function setControllerInputIsolation(on)
 -- V1.60: isolate ONLY Shift from FTF's local crouch handler while controlling.
 -- UIS still receives Shift so it can be relayed to the peer. WASD/Space are never sunk.
 pcall(function() ContextActionService:UnbindAction(CONTROL_SINK_ACTION) end)
 controlSinkBound=false
 if on then
  pcall(function()
   ContextActionService:BindActionAtPriority(
    CONTROL_SINK_ACTION,
    function()
     return Enum.ContextActionResult.Sink
    end,
    false,
    Enum.ContextActionPriority.High.Value+100,
    Enum.KeyCode.LeftShift,
    Enum.KeyCode.RightShift
   )
   controlSinkBound=true
  end)
 end
end

local function hardRestoreLocal()
 -- V1.53: END CONTROL is a forced playable-state restore, not a snapshot restore.
 -- Clear roles FIRST so no RenderStepped path can re-apply controller/target state.
 controlling=false
 beingControlled=false
 outgoingRequest=false
 incomingRequest=false
 claimPending=false
 controlOwner=nil

 held.W=false; held.A=false; held.S=false; held.D=false
 jumpHeld=false
 shiftHeld=false
 remote.x=0; remote.z=0; remote.jump=false; remote.shift=false
 remote.seq=0
 remotePrevJump=false
 remoteExtraJumps=1
 remoteJumpResetToken+=1
 lastRemoteAt=0

 -- Restore POV and release the high-priority WASD/Space/Shift sink.
 setPeerPOV(false)
 setControllerInputIsolation(false)
 controlSinkBound=false
 pcall(function() ContextActionService:UnbindAction(CONTROL_SINK_ACTION) end)

 -- Remove any remote crawl state before normalizing the character.
 applyRemoteCrawl(false,false)
 clearRemoteCrawlTracks(0)
 crawlSnapshot=nil

 -- Restore from controller freeze, then guarantee no stale snapshot remains.
 freezeOwn(false)
 freezeSnapshot=nil

 local function forcePlayable()
  local h,r=currentHum()
  local ch=LP.Character
  if r and r.Parent then
   r.Anchored=false
   r.AssemblyLinearVelocity=Vector3.zero
   r.AssemblyAngularVelocity=Vector3.zero
  end
  if h and h.Parent then
   if h.WalkSpeed<=0 or math.abs(h.WalkSpeed-6)<.25 then h.WalkSpeed=16 end
   h.AutoRotate=true
   h.PlatformStand=false
   h.Sit=false
   if h:GetState()==Enum.HumanoidStateType.Physics or h:GetState()==Enum.HumanoidStateType.PlatformStanding then
    h:ChangeState(Enum.HumanoidStateType.GettingUp)
   end
  end
  if ch and ch.Parent then
   ch:SetAttribute("Crouching",false)
  end
 end

 forcePlayable()
 updateControlUI()

 -- FTF/Roblox movement scripts may write on the next frame. Reassert a playable
 -- state briefly after END, then get completely out of the way.
 task.spawn(function()
  for _=1,6 do
   RunService.Heartbeat:Wait()
   if controlling or beingControlled then return end
   forcePlayable()
  end
 end)
end

local function stopControl(notify)
 if endingSession then return end
 endingSession=true

 local wasActive=controlling or beingControlled
 sessionId+=1
 local sid=sessionId

 -- Send exactly one synchronized END before clearing local state.
 if notify and wasActive and connected then
  sendControl("end",{session=sid})
 end

 hardRestoreLocal()

 -- Short lock prevents the same physical click from becoming a new request.
 task.delay(.35,function()
  if sessionId==sid then endingSession=false end
 end)
end


local function beginController()
 endingSession=false
 sessionId+=1
 controlling=true; beingControlled=false; outgoingRequest=false; incomingRequest=false
 freezeOwn(true); setControllerInputIsolation(true); setPeerPOV(true)
 updateControlUI()
end
local function prepareAsTarget()
 -- A role handoff can happen immediately after we controlled the peer.
 -- Clear every controller-only state before allowing remote movement on us.
 setControllerInputIsolation(false)
 freezeOwn(false)

 local h,r=currentHum()
 if r then
  r.Anchored=false
  r.AssemblyLinearVelocity=Vector3.zero
  r.AssemblyAngularVelocity=Vector3.zero
 end
 if h then
  if h.WalkSpeed<=0 then h.WalkSpeed=16 end
  h.AutoRotate=true
 end

 remote.x=0; remote.z=0; remote.jump=false; remote.shift=false
 remotePrevJump=false
 remoteExtraJumps=1
 remoteJumpResetToken+=1
 lastRemoteAt=os.clock()
end

local function beginTarget()
 endingSession=false
 sessionId+=1
 prepareAsTarget()
 beingControlled=true; controlling=false; incomingRequest=false; outgoingRequest=false
 updateControlUI()
end



local function acceptPeerClaim()
    claimPending=false
    controlOwner=PEER_ID
    if not beingControlled and not controlling then
        beginTarget()
    end
    updateControlUI()
end

local function handleControlPayload(p)
    if type(p)~="table" or p.__saints_remote_control~=true then return false end
    local kind=tostring(p.kind or "")

    if kind=="claim" then
        local claimant=tostring(p.claimant or PEER_ID)

        -- If we're already the controller, reject the peer's late/conflicting claim.
        if controlling then
            sendControl("busy",{owner=MY_ID})
            return true
        end

        -- If peer's claim arrives while our own claim was made at virtually the
        -- same time, use one deterministic winner on both clients.
        if claimPending then
            local winner=(tonumber(MY_ID)<tonumber(PEER_ID)) and MY_ID or PEER_ID
            if winner==MY_ID then
                claimPending=false
                controlOwner=MY_ID
                if not controlling then beginController() end
                sendControl("busy",{owner=MY_ID})
                updateControlUI()
            else
                -- We lose the simultaneous race: undo any local controller state,
                -- then become the peer's target.
                claimPending=false
                if controlling then hardRestoreLocal() end
                acceptPeerClaim()
            end
            return true
        end

        if claimant==PEER_ID then
            acceptPeerClaim()
        end
        return true

    elseif kind=="busy" then
        local owner=tostring(p.owner or "")
        if owner==PEER_ID and controlling then
            -- Peer won a simultaneous race after we optimistically started.
            hardRestoreLocal()
            acceptPeerClaim()
        elseif owner==MY_ID then
            claimPending=false
            controlOwner=MY_ID
            if not controlling and not beingControlled then beginController() end
            updateControlUI()
        end
        return true

    elseif kind=="end" then
        endingSession=false
        sessionId+=1
        claimPending=false
        controlOwner=nil
        hardRestoreLocal()
        updateControlUI()
        return true

    elseif kind=="input" and beingControlled then
        local n=tonumber(p.seq) or 0
        if n>=remote.seq then
            remote.seq=n
            remote.x=math.clamp(tonumber(p.x) or 0,-1,1)
            remote.z=math.clamp(tonumber(p.z) or 0,-1,1)
            remote.jump=p.jump==true
            remote.shift=p.shift==true
            lastRemoteAt=os.clock()
        end
        return true
    end
    return true
end

controlButton.MouseButton1Click:Connect(function()
    if controlling then
        controlOwner=nil
        stopControl(true)
        updateControlUI()
        return
    end
    if beingControlled or endingSession or claimPending or controlOwner then return end
    if not connected or not peerOnline then
        controlInfo.Text=PEER_NAME.." is offline."
        return
    end

    -- V1.36: start controller mode immediately on the claimant.
    -- The peer packet is now only responsible for putting the other client
    -- into target mode, eliminating the stuck "CLAIMING..." acknowledgment wait.
    claimPending=true
    controlOwner=MY_ID
    beginController()
    claimPending=false
    updateControlUI()

    sendControl("claim",{claimant=MY_ID})

    -- Repeat the target-start packet briefly for relay reliability.
    local mySession=sessionId
    task.spawn(function()
        for _=1,3 do
            task.wait(.30)
            if mySession~=sessionId or not controlling then return end
            sendControl("claim",{claimant=MY_ID})
        end
    end)
end)

local function keySet(k,v)
 if k==Enum.KeyCode.W then held.W=v return true elseif k==Enum.KeyCode.A then held.A=v return true elseif k==Enum.KeyCode.S then held.S=v return true elseif k==Enum.KeyCode.D then held.D=v return true end
end
UIS.InputBegan:Connect(function(i,gpe)
 if UIS:GetFocusedTextBox() then return end
 local k=i.KeyCode
 local controlKey=(k==Enum.KeyCode.W or k==Enum.KeyCode.A or k==Enum.KeyCode.S or k==Enum.KeyCode.D
  or k==Enum.KeyCode.Space or k==Enum.KeyCode.LeftShift or k==Enum.KeyCode.RightShift)
 if gpe and not (controlling and controlKey) then return end
 local changed=false
 if keySet(i.KeyCode,true) then changed=true
 elseif i.KeyCode==Enum.KeyCode.Space then jumpHeld=true; changed=true
 elseif i.KeyCode==Enum.KeyCode.LeftShift or i.KeyCode==Enum.KeyCode.RightShift then shiftHeld=true; changed=true end
 if changed then task.defer(sendInputNow) end
end)
UIS.InputEnded:Connect(function(i)
 local changed=false
 if keySet(i.KeyCode,false) then changed=true
 elseif i.KeyCode==Enum.KeyCode.Space then jumpHeld=false; changed=true
 elseif i.KeyCode==Enum.KeyCode.LeftShift or i.KeyCode==Enum.KeyCode.RightShift then shiftHeld=false; changed=true end
 if changed then task.defer(sendInputNow) end
end)

local function controllerVector()
 local cam=workspace.CurrentCamera; if not cam then return Vector3.zero end
 local look=Vector3.new(cam.CFrame.LookVector.X,0,cam.CFrame.LookVector.Z); local right=Vector3.new(cam.CFrame.RightVector.X,0,cam.CFrame.RightVector.Z)
 if look.Magnitude>0 then look=look.Unit end; if right.Magnitude>0 then right=right.Unit end
 local v=Vector3.zero
 if held.W then v+=look end; if held.S then v-=look end; if held.D then v+=right end; if held.A then v-=right end
 return v.Magnitude>1 and v.Unit or v
end

local function sendInputNow()
 if not controlling then return end
 local v=controllerVector()
 seq+=1
 sendControl("input",{x=v.X,z=v.Z,jump=jumpHeld,shift=shiftHeld,seq=seq})
end
local lastControlKeepalive=0
task.spawn(function()
 -- Keep this loop alive even though the phone creates it before the relay connects.
 while gui.Parent do
  if connected and controlling then
   local v=controllerVector()
   local active=(v.Magnitude>.001 or jumpHeld or shiftHeld)
   local now=os.clock()
   if active or (now-(lastControlKeepalive or 0))>=.35 then
    lastControlKeepalive=now
    seq+=1
    sendControl("input",{x=v.X,z=v.Z,jump=jumpHeld,shift=shiftHeld,seq=seq})
   end
  end
  task.wait(1/20) -- 20 Hz active refresh; key edges remain immediate
 end
end)

RunService.RenderStepped:Connect(function()
 if controlling then
  local cam=workspace.CurrentCamera; local ph=peerHum()
  if cam and ph and cam.CameraSubject~=ph then cam.CameraType=Enum.CameraType.Custom; cam.CameraSubject=ph end

  -- Controller avatar stays frozen upright. Shift belongs only to the remote target.
  local ownH=select(1,currentHum())
  local ownC=LP.Character
  if ownC and ownC:GetAttribute("Crouching")==true then ownC:SetAttribute("Crouching",false) end
  if ownH then
   if freezeSnapshot and freezeSnapshot.hip~=nil and math.abs(ownH.HipHeight-freezeSnapshot.hip)>.05 then
    ownH.HipHeight=freezeSnapshot.hip
   end
   local animator=ownH:FindFirstChildOfClass("Animator")
   if animator then
    for _,track in ipairs(animator:GetPlayingAnimationTracks()) do
     if track.Name=="Prone" or track.Name=="ProneMove" then
      pcall(function() track:Stop(0) end)
     end
    end
   end
  end
 end
 if not beingControlled then return end
 local h,r=currentHum(); if not h then return end
 if r and r.Anchored then r.Anchored=false end
 if not remote.shift and h.WalkSpeed<=0 then h.WalkSpeed=16 end
 h.AutoRotate=true

 -- Network packets update held-state; actual movement is simulated locally every render frame.
 -- This avoids visible "packet stepping" even though the relay still has unavoidable network latency.
 if os.clock()-lastRemoteAt>.35 then
  remote.x=0; remote.z=0; remote.jump=false; remote.shift=false
 end

 local rv=Vector3.new(remote.x,0,remote.z)
 applyRemoteCrawl(remote.shift,rv.Magnitude>0.05)

 -- Preserve the target player's own movement so they can still fight remote control.
 local combined=h.MoveDirection+rv
 if combined.Magnitude>1 then combined=combined.Unit end
 h:Move(combined,false)

 -- FTF-style fresh-press double jump. Holding Space still requests normal jumps.
 local freshJump=remote.jump and not remotePrevJump
 if freshJump then processRemoteJumpPress(h) end
 if remote.jump and h:GetState()~=Enum.HumanoidStateType.Freefall
    and h:GetStateEnabled(Enum.HumanoidStateType.Jumping) and h.JumpPower>0 then
  h.Jump=true
 end
 remotePrevJump=remote.jump
end)



updateControlUI()
updatePeerPresenceUI()
-- ===== End Remote Control integration =====

local function sendGame(kind,payload)
    payload=payload or {}
    payload.kind=kind
    payload.game="tic_tac_toe_invite"
    return sendPacket({
        type="chat_message",
        to=PEER_ID,
        payload={
            __saints_game=true,
            game=payload
        }
    })
end

updateInviteBadge=function()
    local count=math.max(0,pendingInviteCount)
    local shown=tostring(math.max(1,count))
    inviteBadge.Text=shown
    inviteBadge.Visible=(count>0 and not opened and not phone.Visible)
    badgeShadow.Visible=inviteBadge.Visible
    invitesTileBadge.Text=shown
    invitesTileBadge.Visible=(count>0)
end

local function resetInviteUI(message)
    inviteEpoch+=1
    pendingInviteCount=0
    tttState="idle"
    tttGameId=nil
    updateInviteBadge()
    invIcon.Text="!"
    invTitle.Text="No pending invites"
    invDesc.Text=message or "Tic-Tac-Toe invites will appear here."
    acceptInvite.Visible=false
    declineInvite.Visible=false
    acceptInvite.Text="ACCEPT"
    ticTacToeInviteButton.Text="INVITE "..string.upper(me.peer)
    ticTacToeInviteButton.TextColor3=Color3.fromRGB(238,52,67)
    ticTacToeInviteButton.BackgroundColor3=Color3.fromRGB(33,10,14)
end

local function beginExpiry(gameId,mode)
    inviteEpoch+=1
    local myEpoch=inviteEpoch
    task.spawn(function()
        local expiresAt=os.clock()+INVITE_LIFETIME
        while myEpoch==inviteEpoch and tostring(tttGameId)==tostring(gameId) do
            local left=math.max(0,math.ceil(expiresAt-os.clock()))
            if mode=="incoming" and tttState=="incoming" then
                invDesc.Text="Tic-Tac-Toe • expires in "..left.."s"
            elseif mode=="outgoing" and tttState=="invited" then
                ticTacToeInviteButton.Text="CANCEL • "..left.."s"
            else
                return
            end
            if left<=0 then break end
            task.wait(.2)
        end

        if myEpoch~=inviteEpoch or tostring(tttGameId)~=tostring(gameId) then return end
        if mode=="outgoing" and tttState=="invited" and myEpoch==inviteEpoch then
            local expiredId=tostring(tttGameId)
            resetInviteUI("Invite expired. Send another whenever you're ready.")
            sendGame("invite_expired",{gameId=expiredId})
        elseif mode=="incoming" and tttState=="incoming" and myEpoch==inviteEpoch then
            local expiredId=tostring(tttGameId)
            resetInviteUI("Invite expired.")
            sendGame("invite_expired",{gameId=expiredId})
        end
    end)
end

local function showIncomingInvite(gameId)
    invIcon.Text="!"
    invTitle.Text=me.peer.." invited you"
    acceptInvite.Visible=true
    declineInvite.Visible=true
    pendingInviteCount=1
    updateInviteBadge()
    beginExpiry(gameId,"incoming")
end

local function resetMidnightInviteUI()
    midnightInviteState="idle"
    midnightInviteGameId=nil
    midnightRunInviteButton.Text="INVITE "..string.upper(me.peer)
    midnightRunInviteButton.TextColor3=Color3.fromRGB(238,52,67)
    midnightRunInviteButton.BackgroundColor3=Color3.fromRGB(33,10,14)
    midnightRunInviteButton.Active=true
end

local function launchMidnightRun(gameId,seed)
    midnightInviteEpoch+=1
    midnightInviteState="starting"
    midnightInviteGameId=tostring(gameId or "")
    midnightRunInviteButton.Text="STARTING..."
    if openEmbeddedMidnightRun then
        openEmbeddedMidnightRun({gameId=midnightInviteGameId,phoneAccepted=true,seed=tonumber(seed)})
    end
    task.delay(.2,function()
        if midnightInviteState=="starting" and tostring(midnightInviteGameId)==tostring(gameId) then
            resetMidnightInviteUI()
        end
    end)
end

midnightRunInviteButton.Activated:Connect(function()
    if SOLO_GAME_DISPLAY_TEST then return end
    if midnightInviteState=="invited" and midnightInviteGameId then
        local oldId=midnightInviteGameId
        midnightInviteEpoch+=1
        gameSend("midnight_run_invite","decline",{gameId=oldId})
        resetMidnightInviteUI()
        return
    end
    if not connected then
        invDesc.Text="Connecting to Saint's multiplayer relay..."
        return
    end
    if midnightInviteState~="idle" then return end
    midnightInviteEpoch+=1
    local epoch=midnightInviteEpoch
    local id=HttpService:GenerateGUID(false)
    midnightInviteGameId=id
    midnightInviteState="invited"
    midnightRunInviteButton.Text="CANCEL • 11s"
    gameSend("midnight_run_invite","invite",{gameId=id})

    task.spawn(function()
        for remaining=10,1,-1 do
            task.wait(1)
            if epoch~=midnightInviteEpoch or midnightInviteState~="invited" or midnightInviteGameId~=id then return end
            midnightRunInviteButton.Text="CANCEL • "..remaining.."s"
        end
        task.wait(1)
        if epoch~=midnightInviteEpoch or midnightInviteState~="invited" or midnightInviteGameId~=id then return end
        gameSend("midnight_run_invite","invite_expired",{gameId=id})
        resetMidnightInviteUI()
    end)
end)

ticTacToeInviteButton.Activated:Connect(function()
    if SOLO_GAME_DISPLAY_TEST then return end
    if not connected then
        invDesc.Text="Connecting to Saint's multiplayer relay..."
        return
    end

    if tttState=="idle" then
        tttGameId=HttpService:GenerateGUID(false)
        tttState="invited"
        invTitle.Text="Invite sent"
        invDesc.Text="Waiting for "..me.peer.." to accept."
        sendGame("invite",{gameId=tttGameId,expiresIn=INVITE_LIFETIME})
        beginExpiry(tttGameId,"outgoing")
    elseif tttState=="invited" then
        local oldId=tttGameId
        sendGame("invite_cancel",{gameId=oldId})
        resetInviteUI("Invite cancelled.")
    end
end)


local function resetRPSInviteUI()
    rpsInviteEpoch+=1
    rpsLaunchToken+=1
    rpsLaunchReady=false
    rpsInviteState="idle"
    rpsInviteGameId=nil
    rpsInviteButton.Text="INVITE "..string.upper(me.peer)
    rpsInviteButton.TextColor3=Color3.fromRGB(238,52,67)
    rpsInviteButton.BackgroundColor3=Color3.fromRGB(33,10,14)
    rpsInviteButton.Active=true
end

local function sendRPSInvite(kind,payload)
    payload=payload or {}
    payload.gameId=payload.gameId or rpsInviteGameId
    return gameSend("rock_paper_scissors_invite",kind,payload)
end

rpsInviteButton.Activated:Connect(function()
    if rpsInviteState=="invited" and rpsInviteGameId then
        local id=rpsInviteGameId
        sendRPSInvite("decline",{gameId=id,reason="cancelled"})
        resetRPSInviteUI()
        return
    end
    if not connected or rpsInviteState~="idle" then return end
    rpsInviteEpoch+=1
    local epoch=rpsInviteEpoch
    local id=HttpService:GenerateGUID(false)
    rpsInviteGameId=id
    rpsInviteState="invited"
    rpsInviteButton.Text="CANCEL • 11s"
    sendRPSInvite("invite",{gameId=id})
    task.spawn(function()
        for n=10,1,-1 do
            task.wait(1)
            if epoch~=rpsInviteEpoch or rpsInviteState~="invited" or rpsInviteGameId~=id then return end
            rpsInviteButton.Text="CANCEL • "..n.."s"
        end
        task.wait(1)
        if epoch~=rpsInviteEpoch or rpsInviteState~="invited" or rpsInviteGameId~=id then return end
        sendRPSInvite("invite_expired",{gameId=id})
        resetRPSInviteUI()
    end)
end)

-- Direct local launchers for V1.55 display verification.
ticTacToeInviteButton.Activated:Connect(function()
    if not SOLO_GAME_DISPLAY_TEST then return end
    local soloId="solo_ttt_"..HttpService:GenerateGUID(false)
    openEmbeddedTicTacToe(soloId,MY_ID)
end)

midnightRunInviteButton.Activated:Connect(function()
    if not SOLO_GAME_DISPLAY_TEST then return end
    local soloId="solo_midnight_"..HttpService:GenerateGUID(false)
    -- incoming=true opens the complete Midnight Run V7 screen in its waiting
    -- state without requiring a peer packet.
    openEmbeddedMidnightRun({gameId=soloId,incoming=true})
end)

acceptInvite.MouseButton1Click:Connect(function()
    if rpsInviteState=="incoming" and rpsInviteGameId then
        local id=tostring(rpsInviteGameId)
        rpsInviteEpoch+=1
        rpsLaunchToken+=1
        local token=rpsLaunchToken
        rpsInviteState="starting"
        rpsLaunchReady=false
        pendingInviteCount=0; updateInviteBadge()
        acceptInvite.Visible=false; declineInvite.Visible=false
        acceptInvite.Text="ACCEPT"

        -- Acknowledge the phone invite, then explicitly command both clients to launch.
        sendRPSInvite("accept",{gameId=id})
        sendRPSInvite("start",{gameId=id})

        local ok,err=pcall(function() openEmbeddedRPS(id) end)
        if ok and embeddedGameGui and embeddedGameGui.Parent then
            rpsInviteState="playing"
            rpsLaunchReady=true
            sendRPSInvite("ready",{gameId=id})
        else
            warn("Saint's Phone RPS launch failed:",err)
            sendRPSInvite("launch_failed",{gameId=id})
            resetRPSInviteUI()
            task.defer(resumePhoneAfterGame)
        end

        -- Never allow a failed handoff to wedge the RPS button.
        task.delay(3,function()
            if token==rpsLaunchToken and rpsInviteState=="starting" then
                resetRPSInviteUI()
                task.defer(resumePhoneAfterGame)
            end
        end)
        return
    end

    if midnightInviteState=="incoming" and midnightInviteGameId then
        local acceptedId=tostring(midnightInviteGameId)
        midnightInviteEpoch+=1
        midnightInviteState="starting"
        pendingInviteCount=0
        updateInviteBadge()
        acceptInvite.Visible=false
        declineInvite.Visible=false
        local raceSeed=math.random(100000,999999999)
        gameSend("midnight_run_invite","accept",{gameId=acceptedId,accepted=true,seed=raceSeed})
        launchMidnightRun(acceptedId,raceSeed)
        return
    end

    if tttState~="incoming" or not tttGameId then return end
    local acceptedId=tostring(tttGameId)
    inviteEpoch+=1
    tttState="starting"
    pendingInviteCount=0
    updateInviteBadge()
    acceptInvite.Visible=false
    declineInvite.Visible=false
    sendGame("accept",{gameId=acceptedId,xPlayer=PEER_ID,accepted=true})
    launchTicTacToe(acceptedId,PEER_ID)
end)

declineInvite.MouseButton1Click:Connect(function()
    if rpsInviteState=="incoming" and rpsInviteGameId then
        local id=tostring(rpsInviteGameId)
        sendRPSInvite("decline",{gameId=id})
        pendingInviteCount=0; updateInviteBadge()
        acceptInvite.Visible=false; declineInvite.Visible=false
        acceptInvite.Text="ACCEPT"
        resetRPSInviteUI()
        invTitle.Text="No pending invites"
        invDesc.Text="Invites expire after 11 seconds."
        return
    end

    if midnightInviteState=="incoming" and midnightInviteGameId then
        local oldId=midnightInviteGameId
        midnightInviteEpoch+=1
        gameSend("midnight_run_invite","decline",{gameId=oldId})
        pendingInviteCount=0
        updateInviteBadge()
        acceptInvite.Visible=false
        declineInvite.Visible=false
        resetMidnightInviteUI()
        invTitle.Text="No pending invites"
        invDesc.Text="Invites expire after 11 seconds."
        return
    end

    if tttState~="incoming" or not tttGameId then return end
    local oldId=tttGameId
    sendGame("decline",{gameId=oldId})
    acceptInvite.Text="ACCEPT"
    resetInviteUI("Invite declined.")
    task.delay(1.2,function()
        if tttState=="idle" then invDesc.Text="Tic-Tac-Toe invites will appear here." end
    end)
end)

local function handleGame(payload)
    if type(payload)~="table" then return end

    if payload.game=="rock_paper_scissors_invite" then
        local kind=payload.kind
        local id=tostring(payload.gameId or "")
        if kind=="invite" then
            -- A fresh invite always supersedes a stale non-playing handoff.
            if rpsInviteState~="playing" then
                rpsInviteEpoch+=1
                rpsLaunchToken+=1
                rpsLaunchReady=false
            end
            local epoch=rpsInviteEpoch
            rpsInviteState="incoming"; rpsInviteGameId=id
            pendingInviteCount=1; updateInviteBadge()
            invTitle.Text=PEER_NAME.." invited you to Rock Paper Scissors"
            invDesc.Text="Accept within 11 seconds."
            acceptInvite.Text="ACCEPT"
            acceptInvite.Visible=true; declineInvite.Visible=true
            task.spawn(function()
                local deadline=os.clock()+INVITE_LIFETIME
                while epoch==rpsInviteEpoch and rpsInviteState=="incoming" and rpsInviteGameId==id and os.clock()<deadline do
                    invDesc.Text="Accept within "..math.max(0,math.ceil(deadline-os.clock())).." seconds."
                    task.wait(.15)
                end
            end)
            task.delay(INVITE_LIFETIME,function()
                if epoch~=rpsInviteEpoch or rpsInviteState~="incoming" or rpsInviteGameId~=id then return end
                sendRPSInvite("invite_expired",{gameId=id})
                pendingInviteCount=0; updateInviteBadge()
                acceptInvite.Visible=false; declineInvite.Visible=false; acceptInvite.Text="ACCEPT"
                resetRPSInviteUI()
            end)
        elseif (kind=="accept" or kind=="start") and (rpsInviteState=="invited" or rpsInviteState=="starting") and id==tostring(rpsInviteGameId) then
            rpsInviteEpoch+=1
            rpsLaunchToken+=1
            local token=rpsLaunchToken
            rpsInviteState="starting"
            rpsLaunchReady=false
            rpsInviteButton.Text="STARTING..."
            rpsInviteButton.Active=false

            local ok,err=pcall(function() openEmbeddedRPS(id) end)
            if ok and embeddedGameGui and embeddedGameGui.Parent then
                rpsInviteState="playing"
                rpsLaunchReady=true
                sendRPSInvite("ready",{gameId=id})
            else
                warn("Saint's Phone RPS launch failed:",err)
                sendRPSInvite("launch_failed",{gameId=id})
                resetRPSInviteUI()
                task.defer(resumePhoneAfterGame)
                return
            end

            -- Retry READY so a single missed relay packet cannot strand the peer.
            task.spawn(function()
                for _=1,4 do
                    task.wait(.35)
                    if token~=rpsLaunchToken or rpsInviteState~="playing" or rpsInviteGameId~=id then return end
                    sendRPSInvite("ready",{gameId=id})
                end
            end)
        elseif kind=="ready" and id==tostring(rpsInviteGameId) then
            rpsLaunchReady=true
            if rpsInviteState=="starting" then rpsInviteState="playing" end
        elseif kind=="launch_failed" and id==tostring(rpsInviteGameId) then
            resetRPSInviteUI()
            task.defer(resumePhoneAfterGame)
        elseif (kind=="decline" or kind=="invite_expired") and id==tostring(rpsInviteGameId) then
            resetRPSInviteUI()
        end
        return
    elseif payload.game=="rock_paper_scissors" then
        if rpsEmbedded and rpsEmbedded.gui and rpsEmbedded.gui.Parent and rpsEmbedded.packet then
            rpsEmbedded.packet(payload)
        end
        return
    end

    if payload.game=="midnight_run_invite" then
        local kind=payload.kind
        local id=tostring(payload.gameId or "")

        if kind=="invite" then
            midnightInviteEpoch+=1
            local epoch=midnightInviteEpoch
            midnightInviteState="incoming"
            midnightInviteGameId=id
            pendingInviteCount=1
            updateInviteBadge()
            invIcon.Text="!"
            invTitle.Text=PEER_NAME.." invited you to Midnight Run"
            invDesc.Text="Accept within 11 seconds."
            acceptInvite.Visible=true
            declineInvite.Visible=true
            acceptInvite.Text="ACCEPT"

            task.delay(INVITE_LIFETIME,function()
                if epoch~=midnightInviteEpoch or midnightInviteState~="incoming" or midnightInviteGameId~=id then return end
                gameSend("midnight_run_invite","invite_expired",{gameId=id})
                pendingInviteCount=0
                updateInviteBadge()
                acceptInvite.Visible=false
                declineInvite.Visible=false
                resetMidnightInviteUI()
                invTitle.Text="No pending invites"
                invDesc.Text="Invites expire after 11 seconds."
            end)
        elseif kind=="accept" and midnightInviteState=="invited" and id==tostring(midnightInviteGameId) then
            midnightInviteEpoch+=1
            launchMidnightRun(id,tonumber(payload.seed))
        elseif (kind=="decline" or kind=="invite_expired") and id==tostring(midnightInviteGameId) then
            midnightInviteEpoch+=1
            resetMidnightInviteUI()
        end
        return
    end

    -- Active embedded games get first shot at their own namespaced packets.
    if payload.game=="tic_tac_toe" then
        if handleEmbeddedTicTacToePacket then handleEmbeddedTicTacToePacket(payload) end
        return
    elseif payload.game=="midnight_run" then
        if midnightEmbedded and midnightEmbedded.gui and midnightEmbedded.gui.Parent then
            handleEmbeddedMidnightPacket(payload)
        elseif payload.kind=="start" and tonumber(payload.seed) then
            openEmbeddedMidnightRun({gameId=payload.gameId,accepted=false})
            if handleEmbeddedMidnightPacket then handleEmbeddedMidnightPacket(payload) end
        elseif payload.kind=="invite" or payload.kind=="rematch" then
            openEmbeddedMidnightRun({gameId=payload.gameId,incoming=true})
        end
        return
    elseif payload.game~="tic_tac_toe_invite" and payload.game~=nil then
        return
    end

    local kind=payload.kind

    if kind=="invite" then
        if tttState=="idle" or tttState=="invited" then
            -- Same deterministic collision rule as standalone.
            if tttState=="invited" and tonumber(MY_ID)<tonumber(PEER_ID) then return end
            tttGameId=tostring(payload.gameId or "")
            tttState="incoming"
            acceptInvite.Text="ACCEPT"
            showIncomingInvite(tttGameId)
        end

    elseif (kind=="invite_cancel" or kind=="invite_expired") and tttState=="incoming" then
        if tostring(payload.gameId)==tostring(tttGameId) then
            resetInviteUI(kind=="invite_cancel" and (me.peer.." cancelled the invite.") or "Invite expired.")
            task.delay(1.2,function()
                if tttState=="idle" then invDesc.Text="Tic-Tac-Toe invites will appear here." end
            end)
        end

    elseif kind=="decline" and tttState=="invited" then
        if tostring(payload.gameId)==tostring(tttGameId) then
            resetInviteUI(me.peer.." declined your invite.")
            task.delay(1.2,function()
                if tttState=="idle" then invDesc.Text="Tic-Tac-Toe invites will appear here." end
            end)
        end

    elseif kind=="accept" then
        local acceptedId=tostring(payload.gameId or "")
        if acceptedId~="" and tostring(tttGameId)==acceptedId and tttState=="invited" then
            -- Kill outgoing expiry before changing screens. A late timeout can no
            -- longer reset this accepted game.
            inviteEpoch+=1
            pendingInviteCount=0
            updateInviteBadge()
            launchTicTacToe(acceptedId,payload.xPlayer or MY_ID)
        end
    end
end

local function handleRelay(raw)
    local ok,data=pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok or type(data)~="table" then return end

    if data.type=="presence" then
        local found=false
        if type(data.online)=="table" then
            for _,id in ipairs(data.online) do
                if tostring(id)==PEER_ID then found=true break end
            end
        end
        peerOnline=found
    elseif data.type=="presence_probe" and tostring(data.from)==PEER_ID then
        peerOnline=true
            pcall(updatePeerPresenceUI)
        sendPacket({type="presence_ack",to=PEER_ID,payload={}})
    elseif data.type=="presence_ack" and tostring(data.from)==PEER_ID then
        peerOnline=true
            pcall(updatePeerPresenceUI)
    elseif data.type=="delivery" and tostring(data.to)==PEER_ID then
        peerOnline=(data.ok==true)
    elseif data.type=="chat_message" and tostring(data.from)==PEER_ID then
        local payload=data.payload
        if type(payload)=="table" and payload.__saints_remote_control==true then
            peerOnline=true
            pcall(updatePeerPresenceUI)
            handleControlPayload(payload)
        elseif type(payload)=="table" and payload.__saints_force_chat==true then
            peerOnline=true
            pcall(updatePeerPresenceUI)
            local forcedText=tostring(payload.text or "")
            if forcedText~="" then
                task.defer(function()
                    sendPublicRobloxChat(forcedText)
                end)
            end
        elseif type(payload)=="table" and payload.__saints_rps==true and tonumber(payload.from)==tonumber(PEER_ID) then
            -- Exact proven V5.3 live-game transport, routed through the phone's one shared socket.
            peerOnline=true
            pcall(updatePeerPresenceUI)
            if rpsEmbedded and rpsEmbedded.gui and rpsEmbedded.gui.Parent and rpsEmbedded.packet then
                rpsEmbedded.packet(payload)
            end
        elseif type(payload)=="table" and payload.__saints_game==true and type(payload.game)=="table" then
            peerOnline=true
            pcall(updatePeerPresenceUI)
            handleGame(payload.game)
        end
    end
end

socket=connectSocket(RELAY)
if socket then
    connected=true
    local messageBound=false
    for _,eventName in ipairs({"OnMessage","Message","onmessage"}) do
        local ok,ev=pcall(function() return socket[eventName] end)
        if ok and ev then
            local hooked=pcall(function() ev:Connect(handleRelay) end)
            if hooked then messageBound=true break end
        end
    end
    for _,eventName in ipairs({"OnClose","Close","onclose"}) do
        local ok,ev=pcall(function() return socket[eventName] end)
        if ok and ev then
            local hooked=pcall(function()
                ev:Connect(function()
                    connected=false
                    peerOnline=false
                    pcall(updatePeerPresenceUI)
                    claimPending=false
                    controlOwner=nil
                    endingSession=false
                    pcall(hardRestoreLocal)
                    pcall(updateControlUI)
                    if tttState=="invited" or tttState=="incoming" then
                        resetInviteUI("Connection lost. Re-open the invite when connected.")
                    end
                end)
            end)
            if hooked then break end
        end
    end
    if messageBound then
        sendPacket({type="hello",userId=MY_ID})
        task.spawn(function()
            while connected and gui.Parent do
                sendPacket({type="presence_probe",to=PEER_ID,payload={}})
                task.wait(2)
            end
        end)
    else
        connected=false
        resetInviteUI("Relay connected, but Volt message events were not detected.")
    end
else
    resetInviteUI("Could not connect to Saint's multiplayer relay.")
end

gamesApp.MouseButton1Click:Connect(function() openPage("Games") end)
invitesApp.MouseButton1Click:Connect(function()
    openPage("Invites")
    if tttState=="incoming" then
        pendingInviteCount=0
        updateInviteBadge()
    end
end)
controlApp.MouseButton1Click:Connect(function()
    updateControlUI()
    openPage("Control")
end)
forceChatApp.MouseButton1Click:Connect(function()
    pcall(updatePeerPresenceUI)
    openPage("ForceChat")
end)

local opened=false
local fadeObjects={}

local function collectFadeObjects(root)
    fadeObjects={}
    for _,obj in ipairs(root:GetDescendants()) do
        if obj:IsA("GuiObject") then
            local data={obj=obj}
            if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                data.text=obj.TextTransparency
            end
            if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
                data.image=obj.ImageTransparency
            end
            if obj:IsA("Frame") or obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") or obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
                data.bg=obj.BackgroundTransparency
            end
            table.insert(fadeObjects,data)
        end
    end
end

collectFadeObjects(phone)

local function setPhoneAlpha(alpha)
    for _,data in ipairs(fadeObjects) do
        local obj=data.obj
        if obj and obj.Parent then
            if data.text~=nil then obj.TextTransparency=math.clamp(data.text+alpha,0,1) end
            if data.image~=nil then obj.ImageTransparency=math.clamp(data.image+alpha,0,1) end
            if data.bg~=nil then obj.BackgroundTransparency=math.clamp(data.bg+alpha,0,1) end
        end
    end
end

restorePhoneAlpha=function()
    for _,data in ipairs(fadeObjects) do
        local obj=data.obj
        if obj and obj.Parent then
            if data.text~=nil then obj.TextTransparency=data.text end
            if data.image~=nil then obj.ImageTransparency=data.image end
            if data.bg~=nil then obj.BackgroundTransparency=data.bg end
        end
    end
end

local openToken=0

local function animatePhoneFade(fromAlpha,toAlpha,duration,token,onDone)
    task.spawn(function()
        local started=os.clock()
        while token==openToken do
            local p=math.clamp((os.clock()-started)/duration,0,1)
            local eased=1-(1-p)^3
            local alpha=fromAlpha+(toAlpha-fromAlpha)*eased
            restorePhoneAlpha()
            setPhoneAlpha(alpha)
            if p>=1 then break end
            task.wait()
        end
        if token==openToken then
            if toAlpha<=0 then restorePhoneAlpha() end
            if onDone then onDone() end
        end
    end)
end

-- V1.45: shell/wallpaper opens first, then home apps reveal in a
-- top-left -> bottom-right cascade:
-- Games -> Invites -> Control -> Force Chat.
-- Opacity only; no app movement/size tweening.
local homeAppCards={gamesApp,invitesApp,controlApp,forceChatApp}
local homeAppVisuals={}

local function captureHomeAppVisuals()
    homeAppVisuals={}
    for index,card in ipairs(homeAppCards) do
        local visuals={}
        homeAppVisuals[index]=visuals
        if card and card.Parent then
            local items={card}
            for _,obj in ipairs(card:GetDescendants()) do
                if obj:IsA("GuiObject") then
                    table.insert(items,obj)
                end
            end
            for _,obj in ipairs(items) do
                local data={obj=obj}
                if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                    data.text=obj.TextTransparency
                end
                if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
                    data.image=obj.ImageTransparency
                end
                data.bg=obj.BackgroundTransparency
                table.insert(visuals,data)
            end
        end
    end
end

captureHomeAppVisuals()

local function setOneHomeAppFade(index,alpha)
    local visuals=homeAppVisuals[index]
    if not visuals then return end
    for _,data in ipairs(visuals) do
        local obj=data.obj
        if obj and obj.Parent then
            if data.text~=nil then
                obj.TextTransparency=data.text+(1-data.text)*alpha
            end
            if data.image~=nil then
                obj.ImageTransparency=data.image+(1-data.image)*alpha
            end
            if data.bg~=nil then
                obj.BackgroundTransparency=data.bg+(1-data.bg)*alpha
            end
        end
    end
end

setHomeAppsFade=function(alpha)
    for index=1,#homeAppCards do
        setOneHomeAppFade(index,alpha)
    end
end

local function restoreHomeApps()
    setHomeAppsFade(0)
end

animateHomeAppsAfterShell=function(token)
    task.spawn(function()
        -- Let the .30s phone shell/wallpaper tween finish first.
        task.wait(.31)
        if token~=openToken or not opened then return end

        -- Reveal each card separately in reading order.
        local stagger=.075
        local duration=.18

        for index=1,#homeAppCards do
            if token~=openToken or not opened then return end

            task.spawn(function()
                local started=os.clock()
                while token==openToken and opened do
                    local p=math.clamp((os.clock()-started)/duration,0,1)
                    local eased=1-(1-p)^3
                    setOneHomeAppFade(index,1-eased)
                    if p>=1 then break end
                    task.wait()
                end
                if token==openToken and opened then
                    setOneHomeAppFade(index,0)
                end
            end)

            if index<#homeAppCards then
                task.wait(stagger)
            end
        end
    end)
end

-- V1.29: black power-off overlay. Opening remains V1.27.
local powerOffBlack=Instance.new("Frame")
powerOffBlack.Name="PowerOffBlack"
powerOffBlack.BackgroundColor3=Color3.fromRGB(0,0,0)
powerOffBlack.BackgroundTransparency=1
powerOffBlack.BorderSizePixel=0
powerOffBlack.Size=UDim2.fromScale(1,1)
powerOffBlack.Position=UDim2.fromScale(0,0)
powerOffBlack.ZIndex=200
powerOffBlack.Visible=false
powerOffBlack.Parent=phone
local powerOffCorner=Instance.new("UICorner")
powerOffCorner.CornerRadius=UDim.new(0,28)
powerOffCorner.Parent=powerOffBlack

-- Translucent shutdown tint: darkens the REAL phone without replacing its visuals.
local naturalDim=Instance.new("Frame")
naturalDim.Name="NaturalPhoneDim"
naturalDim.BackgroundColor3=Color3.fromRGB(0,0,0)
naturalDim.BackgroundTransparency=1
naturalDim.BorderSizePixel=0
naturalDim.Size=UDim2.fromScale(1,1)
naturalDim.Position=UDim2.fromScale(0,0)
naturalDim.ZIndex=199
naturalDim.Visible=false
naturalDim.Parent=phone
local naturalDimCorner=Instance.new("UICorner")
naturalDimCorner.CornerRadius=UDim.new(0,28)
naturalDimCorner.Parent=naturalDim

local function runBlackPowerOff(token,done)
    -- V1.47 unified sleep close:
    -- keep every app/icon intact; darken and shrink the complete phone as one object.
    -- This avoids individual descendant fades during shutdown.
    powerOffBlack.Visible=false
    powerOffBlack.BackgroundTransparency=1
    naturalDim.Visible=true
    naturalDim.BackgroundTransparency=1

    -- Darken the real screen while all existing UI remains untouched underneath.
    TweenService:Create(naturalDim,TweenInfo.new(.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{
        BackgroundTransparency=.38
    }):Play()

    TweenService:Create(shade,TweenInfo.new(.28,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{
        BackgroundTransparency=1
    }):Play()

    -- Subtle ~3% center shrink of the complete phone.
    TweenService:Create(phone,TweenInfo.new(.30,Enum.EasingStyle.Quart,Enum.EasingDirection.InOut),{
        Size=UDim2.fromOffset(308,601),
        Position=UDim2.fromScale(.5,.54)
    }):Play()

    task.delay(.30,function()
        if token~=openToken then return end

        -- Final unified disappearance. Do not fade individual phone descendants.
        local phoneGroupTransparency=Instance.new("NumberValue")
        phoneGroupTransparency.Value=0
        local conn
        conn=phoneGroupTransparency.Changed:Connect(function(v)
            if token~=openToken then
                if conn then conn:Disconnect() end
                return
            end
            -- Use the existing dim overlay as the single visual shutdown layer.
            -- Raising its opacity hides the complete intact UI uniformly.
            naturalDim.BackgroundTransparency=math.clamp(.38-(v*.38),0,.38)
        end)

        local tw=TweenService:Create(phoneGroupTransparency,TweenInfo.new(.12,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Value=1})
        tw:Play()
        tw.Completed:Connect(function()
            if conn then conn:Disconnect() end
            phoneGroupTransparency:Destroy()
            if token~=openToken then return end
            phone.Visible=false
            shade.Visible=false
            naturalDim.Visible=false
            naturalDim.BackgroundTransparency=1
            if done then done() end
        end)
    end)
end

local function setOpen(v)
    openToken+=1
    local token=openToken

    if v then
        opened=true

        -- The launcher represents the phone in inventory; hide it while the phone is open.
        launcher.Visible=false
        inviteBadge.Visible=false
        badgeShadow.Visible=false

        powerOffBlack.Visible=false
        powerOffBlack.BackgroundTransparency=1
        naturalDim.Visible=false
        naturalDim.BackgroundTransparency=1
        shade.Visible=true
        shade.BackgroundTransparency=1
        phone.Visible=true
        phone.Size=UDim2.fromOffset(300,585)
        phone.Position=UDim2.fromScale(.5,.55)
        restorePhoneAlpha()

        -- Keep the home apps fully hidden while the shell/wallpaper opens.
        setHomeAppsFade(1)

        TweenService:Create(shade,TweenInfo.new(.28,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{
            BackgroundTransparency=.45
        }):Play()

        TweenService:Create(phone,TweenInfo.new(.30,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{
            Size=UDim2.fromOffset(318,620),
            Position=UDim2.fromScale(.5,.54)
        }):Play()

        -- The shell is already visible and simply settles into place.
        -- Apps are revealed separately only after that tween completes.
        animateHomeAppsAfterShell(token)
    else
        if not phone.Visible then
            opened=false
            launcher.Visible=true
            updateInviteBadge()
            shade.Visible=false
            return
        end

        opened=false

        -- V1.48: instant clean close. No descendant fades, dimming, or shrinking.
        -- Hide the complete phone as one intact UI so icons/apps never glitch on exit.
        restoreHomeApps()
        restorePhoneAlpha()
        powerOffBlack.Visible=false
        powerOffBlack.BackgroundTransparency=1
        naturalDim.Visible=false
        naturalDim.BackgroundTransparency=1
        phone.Visible=false
        shade.Visible=false
        shade.BackgroundTransparency=1

        home.Visible=true
        for _,p in pairs(pages) do p.Visible=false end
        currentPage=nil

        launcher.Visible=true
        updateInviteBadge()
    end
end

-- V13: Saint's Phone cannot be opened while the local player is Beast.
-- This prevents the phone's [1] shortcut from colliding with the Beast
-- Hitbox Expander reminder's [1] YES choice.
local function phoneIsBeast()
    local c=player.Character
    if player:GetAttribute("Beast") then return true end
    local bp=player:FindFirstChildOfClass("Backpack")
    return (c and c:FindFirstChild("Hammer"))~=nil or (bp and bp:FindFirstChild("Hammer"))~=nil
end

launcher.MouseButton1Click:Connect(function()
    if not opened and phoneIsBeast() then return end
    setOpen(not opened)
end)

-- Press 1 to toggle Saint's Phone. Ignore the shortcut while typing.
UIS.InputBegan:Connect(function(input,gameProcessed)
    if gameProcessed then return end
    if UIS:GetFocusedTextBox() then return end
    if input.KeyCode==Enum.KeyCode.One then
        if not opened and phoneIsBeast() then return end
        setOpen(not opened)
    end
end)

tool.Equipped:Connect(function()
    if phoneIsBeast() then return end
    setOpen(true)
end)

tool.Activated:Connect(function()
    if phoneIsBeast() then return end
    setOpen(true)
end)

tool.Unequipped:Connect(function()
    setOpen(false)
end)

close.MouseButton1Click:Connect(function()
    setOpen(false)
    pcall(function()
        local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:UnequipTools() end
    end)
end)

shade.MouseButton1Click:Connect(function()
    setOpen(false)
    pcall(function()
        local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:UnequipTools() end
    end)
end)

-- Keep the phone Tool available after respawn.
player.CharacterAdded:Connect(function()
    claimPending=false
    controlOwner=nil
    endingSession=false
    pcall(hardRestoreLocal)
    pcall(updateControlUI)
    task.wait(1)
    if not backpack:FindFirstChild("Saint's Phone") and not (player.Character and player.Character:FindFirstChild("Saint's Phone")) then
        tool.Parent=backpack
    end
    setOpen(false)
end)

gui.Destroying:Connect(function()
    if (controlling or beingControlled) and connected then
        pcall(function()
            sessionId+=1
            sendControl("end",{session=sessionId,reason="phone_destroyed"})
        end)
    end
    endingSession=false
    pcall(hardRestoreLocal)
    connected=false
    socketClose(socket)
end)

print("[Saint's Phone] Phase 1.46 fade clip + Force Chat text fix ready for "..me.name..".")

end

local function cleanupEverything()
    pcall(function() for _,p in ipairs(PlayersESP:GetPlayers()) do clearPlayer(p) end end)
    if _G.SaintsCrossyRoadV1Cleanup then pcall(_G.SaintsCrossyRoadV1Cleanup) end
    if _G.SaintsBalloonTransitionCleanup then pcall(_G.SaintsBalloonTransitionCleanup) end
    if _G.SaintsChristmasAuthCleanup then pcall(_G.SaintsChristmasAuthCleanup) end
    if _G.SaintsHubV4Cleanup then pcall(_G.SaintsHubV4Cleanup) end
    restoreFTFMusic()
    _G.SaintsChristmasIntegratedCleanup=nil
end
_G.SaintsChristmasIntegratedCleanup=cleanupEverything
muteFTFMusic()
-- V16: preserve the proven V14 startup path. Crossy must begin immediately;
-- only post-auth/heavier systems are frame-budgeted.
startCrossy(function()
    startBalloon(function()
        startChristmasAuth(function()
            restoreFTFMusic()
            -- V15 startup budgeting: build the Hub first, then let one short
            -- slice of frame time pass before the larger Phone runtime starts.
            -- Visible behavior/features stay the same; this only avoids both
            -- systems doing their heaviest initialization in the same frame.
            task.spawn(startSaintsHub)
            task.delay(0.18,function()
                startSaintsPhone()
            end)
        end)
    end)
end)
