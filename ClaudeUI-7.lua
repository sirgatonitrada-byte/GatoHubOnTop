--[[
╔══════════════════════════════════════════════════════════╗
║           ClaudeUI  –  Roblox UI Library  v4.0           ║
║  Dark Mode  ·  Laranja & Branco  ·  Lucide  ·  Acrylic  ║
╠══════════════════════════════════════════════════════════╣
║                                                          ║
║  SETUP:  coloque este ModuleScript em ReplicatedStorage  ║
║  Ícones são carregados via HttpGet automaticamente.      ║
║                                                          ║
║  API:                                                    ║
║    local UI  = require(RS.ClaudeUI)                      ║
║    local win = UI.new({                                  ║
║        Title   = "Config",                               ║
║        Icon    = "settings",  -- Lucide ou rbxassetid:// ║
║        Width   = 640,                                    ║
║        Height  = 440,                                    ║
║        Acrylic = true,        -- efeito de vidro fosco   ║
║    })                                                    ║
║                                                          ║
║    local tab = win:CreateTab({                           ║
║        Title = "Home",                                   ║
║        Icon  = "home",   -- ícone Lucide opcional        ║
║    })                                                    ║
║                                                          ║
║    tab:AddLabel(text, opts?)                             ║
║    tab:AddButton(text, callback, opts?)                  ║
║    tab:AddInput(placeholder, callback, opts?)            ║
║    tab:AddToggle(label, default, callback, opts?)        ║
║    tab:AddSlider(label,min,max,default,cb,opts?)         ║
║    tab:AddDropdown(label, items, callback, opts?)        ║
║    tab:AddSeparator()                                    ║
║                                                          ║
║    win:Toast(message, kind?, duration?)                  ║
║       kind: "success" | "warning" | "error" | "info"    ║
║    win:Destroy()                                         ║
╚══════════════════════════════════════════════════════════╝
--]]

local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players          = game:GetService("Players")

-- ════════════════════════════════════════════════════════
--   ACRYLIC BLUR SYSTEM (baseado na Starlight Library)
--   Funciona apenas fora do Studio em executores com getgenv()
-- ════════════════════════════════════════════════════════
local RunService  = game:GetService("RunService")
local Lighting    = game:GetService("Lighting")
local Camera      = workspace.CurrentCamera
local isStudio    = RunService:IsStudio()

-- Utilitários de viewport
local function _map(value, inMin, inMax, outMin, outMax)
    return (value - inMin) * (outMax - outMin) / (inMax - inMin) + outMin
end
local function _viewportPointToWorld(location, distance)
    local unitRay = Camera:ScreenPointToRay(location.X, location.Y)
    return unitRay.Origin + unitRay.Direction * distance
end
local function _getOffset()
    return _map(Camera.ViewportSize.Y, 0, 2560, 8, 56)
end

-- Verifica se o ambiente suporta acrílico
local function _acrylicSupported()
    return getgenv and (
        (getgenv().NoAnticheat == nil and true or getgenv().NoAnticheat)
        or not getgenv().SecureMode
    ) or isStudio
end

-- Cria a Part de vidro que serve de blur
local function _createAcrylicPart()
    if not _acrylicSupported() then return nil end
    local part = Instance.new("Part")
    part.Name          = "ClaudeUIBlur"
    part.Color         = Color3.new(0, 0, 0)
    part.Material      = Enum.Material.Glass
    part.Size          = Vector3.new(1.04, 1.12, 0)
    part.Anchored      = true
    part.CanCollide    = false
    part.Locked        = true
    part.CastShadow    = false
    part.Transparency  = 0.98
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Brick
    mesh.Offset   = Vector3.new(0, 0, -0.000001)
    mesh.Parent   = part
    return part
end

-- Inicializa o DepthOfField para o blur
local function _initDOF()
    if not _acrylicSupported() then return end
    local existing
    for _, v in ipairs(Lighting:GetChildren()) do
        if v:IsA("DepthOfFieldEffect") and v.Name ~= "ClaudeUIBlur" then
            existing = v; break
        end
    end
    if not existing then
        existing = Instance.new("DepthOfFieldEffect")
        existing.FarIntensity  = 0
        existing.NearIntensity = 0
        existing.FocusDistance = 500
        existing.InFocusRadius = 500
        existing.Enabled       = true
        existing.Parent        = Lighting
    end
    local blurDOF = Lighting:FindFirstChild("ClaudeUIBlur")
    if not blurDOF then
        blurDOF = existing:Clone()
        blurDOF.Name          = "ClaudeUIBlur"
        blurDOF.NearIntensity = 1
        blurDOF.Parent        = Lighting
    end
    -- Sincroniza com o DOF universal
    local function sync()
        blurDOF.FarIntensity  = existing.FarIntensity
        blurDOF.FocusDistance = existing.FocusDistance
        blurDOF.InFocusRadius = existing.InFocusRadius
    end
    existing:GetPropertyChangedSignal("FarIntensity"):Connect(sync)
    existing:GetPropertyChangedSignal("FocusDistance"):Connect(sync)
    existing:GetPropertyChangedSignal("InFocusRadius"):Connect(sync)
end

-- Folder para guardar as parts de blur
local function _getBlurFolder()
    local folder = Camera:FindFirstChild("ClaudeUI Blur Elements")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name   = "ClaudeUI Blur Elements"
        folder.Parent = Camera
    end
    return folder
end

-- Cria um componente de acrílico completo para um Frame pai
local function createAcrylicComponent(parentFrame, windowBg)
    if not _acrylicSupported() then return nil end

    _initDOF()

    local part     = _createAcrylicPart()
    if not part then return nil end
    part.Color     = windowBg or Color3.fromRGB(28, 28, 28)
    part.Parent    = _getBlurFolder()

    local mesh     = part:FindFirstChildWhichIsA("SpecialMesh")
    local cleanups = {}
    local positions = {
        topLeft     = Vector2.new(),
        topRight    = Vector2.new(),
        bottomRight = Vector2.new(),
    }

    local function updatePositions(size, position)
        positions.topLeft     = position
        positions.topRight    = position + Vector2.new(size.X, 0)
        positions.bottomRight = position + size
    end

    local function render()
        local cam = workspace.CurrentCamera
        if not cam then return end
        local cf  = cam.CFrame
        local tl  = _viewportPointToWorld(positions.topLeft,     0.001)
        local tr  = _viewportPointToWorld(positions.topRight,    0.001)
        local br  = _viewportPointToWorld(positions.bottomRight, 0.001)
        local w   = (tr - tl).Magnitude
        local h   = (tr - br).Magnitude
        part.CFrame = CFrame.fromMatrix((tl + br) / 2, cf.XVector, cf.YVector, cf.ZVector)
        if mesh then mesh.Scale = Vector3.new(w, h, 0) end
    end

    local function onChange()
        local offset   = _getOffset()
        local abs      = parentFrame.AbsoluteSize
        local absPos   = parentFrame.AbsolutePosition
        local size     = abs    - Vector2.new(offset, offset)
        local position = absPos + Vector2.new(offset / 2, offset / 2)
        updatePositions(size, position)
        task.spawn(render)
    end

    local function hookCamera()
        local cam = workspace.CurrentCamera
        if not cam then return end
        cleanups[#cleanups+1] = cam:GetPropertyChangedSignal("CFrame"):Connect(render)
        cleanups[#cleanups+1] = cam:GetPropertyChangedSignal("ViewportSize"):Connect(render)
        cleanups[#cleanups+1] = cam:GetPropertyChangedSignal("FieldOfView"):Connect(render)
        task.spawn(render)
    end

    -- Conecta mudanças do frame pai
    cleanups[#cleanups+1] = parentFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(onChange)
    cleanups[#cleanups+1] = parentFrame:GetPropertyChangedSignal("AbsolutePosition"):Connect(onChange)

    -- Limpeza ao destruir
    part.Destroying:Connect(function()
        for _, c in ipairs(cleanups) do pcall(function() c:Disconnect() end) end
    end)

    hookCamera()
    task.spawn(onChange)

    -- Camadas visuais de acrílico (noise + tint + shadow)
    local acrylicFrame = Instance.new("Frame")
    acrylicFrame.Name                  = "AcrylicLayer"
    acrylicFrame.Size                  = UDim2.fromScale(1, 1)
    -- Base levemente branca para realçar o efeito fosco
    acrylicFrame.BackgroundColor3      = Color3.fromRGB(255, 255, 255)
    acrylicFrame.BackgroundTransparency= 0.94
    acrylicFrame.BorderSizePixel       = 0
    acrylicFrame.ZIndex                = 0

    -- Sombra suave ao redor da janela
    local shadow = Instance.new("ImageLabel")
    shadow.Image              = "rbxassetid://8992230677"
    shadow.ScaleType          = Enum.ScaleType.Slice
    shadow.SliceCenter        = Rect.new(99, 99, 99, 99)
    shadow.AnchorPoint        = Vector2.new(0.5, 0.5)
    shadow.Size               = UDim2.new(1, 140, 1, 130)
    shadow.Position           = UDim2.new(0.5, 0, 0.5, 0)
    shadow.BackgroundTransparency = 1
    shadow.ImageColor3        = Color3.fromRGB(0, 0, 0)
    shadow.ImageTransparency  = 0.55   -- sombra mais escura = janela mais destacada
    shadow.Name               = "Shadow"
    shadow.ZIndex             = 0
    shadow.Parent             = acrylicFrame

    -- Tint escuro para dar sensação de vidro tintado
    local tint = Instance.new("ImageLabel")
    tint.Image              = "rbxassetid://9968344105"
    tint.ImageTransparency  = 0.82    -- mais visível que 0.98
    tint.ImageColor3        = Color3.fromRGB(20, 20, 30)  -- azulado frio
    tint.ScaleType          = Enum.ScaleType.Tile
    tint.TileSize           = UDim2.new(0, 128, 0, 128)
    tint.Size               = UDim2.fromScale(1, 1)
    tint.BackgroundTransparency = 1
    tint.Name               = "Tint"
    tint.ZIndex             = 0
    tint.Parent             = acrylicFrame

    -- Noise para textura granulada fosca
    local noise = Instance.new("ImageLabel")
    noise.Image             = "rbxassetid://9968344227"
    noise.ImageTransparency = 0.75    -- granulado mais perceptível
    noise.ScaleType         = Enum.ScaleType.Tile
    noise.TileSize          = UDim2.new(0, 128, 0, 128)
    noise.Size              = UDim2.fromScale(1, 1)
    noise.BackgroundTransparency = 1
    noise.Name              = "Noise"
    noise.ZIndex            = 0
    noise.Parent            = acrylicFrame

    -- Brilho sutil no topo (highlight de vidro)
    local highlight = Instance.new("Frame")
    highlight.Name               = "GlassHighlight"
    highlight.Size               = UDim2.new(1, 0, 0, 1)
    highlight.Position           = UDim2.new(0, 0, 0, 0)
    highlight.BackgroundColor3   = Color3.fromRGB(255, 255, 255)
    highlight.BackgroundTransparency = 0.7
    highlight.BorderSizePixel    = 0
    highlight.ZIndex             = 1
    highlight.Parent             = acrylicFrame

    acrylicFrame.Parent = parentFrame

    local function setVisible(v)
        pcall(function() part.Transparency = v and 0.98 or 1 end)
        acrylicFrame.Visible = v
    end

    return {
        Frame      = acrylicFrame,
        Part       = part,
        SetVisible = setVisible,
        Destroy    = function()
            pcall(function() part:Destroy() end)
            pcall(function() acrylicFrame:Destroy() end)
        end,
    }
end

-- ════════════════════════════════════════════════════════
--   LUCIDE ICONS  (carrega de forma lazy / segura)
-- ════════════════════════════════════════════════════════
local LucideIcons = nil
local function getLucide()
    if LucideIcons then return LucideIcons end
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(
            "https://raw.githubusercontent.com/Nebula-Softworks/Nebula-Icon-Library/refs/heads/master/LucideIcons.luau"
        ))()
    end)
    if ok then LucideIcons = result end
    return LucideIcons
end

-- Retorna "rbxassetid://XXXXX" ou nil
local function iconAsset(name)
    if not name or name == "" then return nil end
    local lib = getLucide()
    if not lib then return nil end
    local id = lib[name]
    if not id then return nil end
    return "rbxassetid://" .. tostring(id)
end

-- ════════════════════════════════════════════════════════
--   TEMA
-- ════════════════════════════════════════════════════════
local T = {
    WindowBg      = Color3.fromRGB(28,  28,  28),
    WindowBorder  = Color3.fromRGB(52,  52,  52),

    TitleBg       = Color3.fromRGB(20,  20,  20),
    TitleBorder   = Color3.fromRGB(45,  45,  45),

    SidebarBg     = Color3.fromRGB(22,  22,  22),
    SidebarBorder = Color3.fromRGB(45,  45,  45),

    TabNormal     = Color3.fromRGB(22,  22,  22),
    TabHover      = Color3.fromRGB(36,  36,  36),
    TabActive     = Color3.fromRGB(207, 100, 54),
    TabNormalText = Color3.fromRGB(140, 140, 140),
    TabActiveText = Color3.fromRGB(255, 255, 255),

    ContentBg     = Color3.fromRGB(31,  31,  31),
    Surface       = Color3.fromRGB(40,  40,  40),
    SurfaceHover  = Color3.fromRGB(50,  50,  50),
    SurfaceActive = Color3.fromRGB(58,  58,  58),

    Primary       = Color3.fromRGB(207, 100, 54),
    PrimaryHover  = Color3.fromRGB(224, 120, 72),
    PrimaryText   = Color3.fromRGB(255, 255, 255),

    Border        = Color3.fromRGB(55,  55,  55),
    BorderFocus   = Color3.fromRGB(207, 100, 54),

    TextPrimary   = Color3.fromRGB(232, 232, 232),
    TextSecondary = Color3.fromRGB(148, 148, 148),
    TextMuted     = Color3.fromRGB(85,  85,  85),

    Success       = Color3.fromRGB(52,  168, 83),
    Warning       = Color3.fromRGB(251, 188, 4),
    Error         = Color3.fromRGB(220, 53,  69),
    Info          = Color3.fromRGB(66,  133, 244),

    ScrollBar     = Color3.fromRGB(68,  68,  68),
    ToggleOn      = Color3.fromRGB(207, 100, 54),
    ToggleOff     = Color3.fromRGB(58,  58,  58),
    IconTint      = Color3.fromRGB(148, 148, 148),
    IconTintActive= Color3.fromRGB(255, 255, 255),
}

-- ════════════════════════════════════════════════════════
--   HELPERS
-- ════════════════════════════════════════════════════════
local function inst(class, props)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    return o
end

local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = p
    return c
end

local function mkStroke(p, col, thick)
    local s = Instance.new("UIStroke")
    s.Color     = col   or T.Border
    s.Thickness = thick or 1
    s.Parent    = p
    return s
end

local function mkPad(p, t, r, b, l)
    local u = Instance.new("UIPadding")
    u.PaddingTop    = UDim.new(0, t or 8)
    u.PaddingRight  = UDim.new(0, r or 8)
    u.PaddingBottom = UDim.new(0, b or 8)
    u.PaddingLeft   = UDim.new(0, l or 8)
    u.Parent = p
    return u
end

local function tw(obj, info, props)
    TweenService:Create(obj, info, props):Play()
end

local fast = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local med  = TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Cria um ImageLabel com ícone Lucide dentro de `parent`
-- size: number (pixels quadrados), color: Color3
-- Retorna o ImageLabel (ou nil se ícone não encontrado)
local function mkIcon(parent, iconName, size, color, zIndex, anchorPoint, position)
    local asset = iconAsset(iconName)
    if not asset then return nil end

    size      = size      or 16
    color     = color     or T.IconTint
    zIndex    = zIndex    or 3
    anchorPoint = anchorPoint or Vector2.new(0, 0.5)
    position  = position  or UDim2.new(0, 0, 0.5, 0)

    local img = inst("ImageLabel", {
        Size            = UDim2.new(0, size, 0, size),
        AnchorPoint     = anchorPoint,
        Position        = position,
        BackgroundTransparency = 1,
        Image           = asset,
        ImageColor3     = color,
        ScaleType       = Enum.ScaleType.Fit,
        ZIndex          = zIndex,
        Parent          = parent,
    })
    return img
end

-- Dragging
local function makeDraggable(frame, handle)
    local drag, ds, sp = false, nil, nil
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            drag = true; ds = i.Position; sp = frame.Position
        end
    end)
    handle.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - ds
            frame.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
        end
    end)
end

-- ════════════════════════════════════════════════════════
--   CONSTANTES DE LAYOUT
-- ════════════════════════════════════════════════════════
local SIDEBAR_W  = 152
local TITLEBAR_H = 42
local TAB_H      = 38
local TAB_ICON_S = 15  -- tamanho dos ícones nas tabs
local TITLE_ICON_S = 16

-- ════════════════════════════════════════════════════════
--   JANELA PRINCIPAL
-- ════════════════════════════════════════════════════════
local ClaudeUI = {}
ClaudeUI.__index = ClaudeUI

function ClaudeUI.new(config)
    local self = setmetatable({}, ClaudeUI)
    -- Aceita tanto .new({Title=...}) quanto .new("título") por compatibilidade
    if type(config) == "string" then
        config = { Title = config }
    end
    config = config or {}

    local title = config.Title or "ClaudeUI"
    local W     = config.Width  or 640
    local H     = config.Height or 440

    -- ScreenGui
    local gui = inst("ScreenGui", {
        Name           = "ClaudeUI_" .. title,
        ResetOnSpawn   = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent         = Players.LocalPlayer:WaitForChild("PlayerGui"),
    })
    self.ScreenGui = gui

    -- Sombra
    local shadow = inst("Frame", {
        AnchorPoint     = Vector2.new(0.5, 0.5),
        Position        = UDim2.new(0.5, 0, 0.5, 10),
        Size            = UDim2.new(0, W + 40, 0, H + 40),
        BackgroundColor3= Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.55,
        BorderSizePixel = 0,
        ZIndex          = 0,
        Parent          = gui,
    })
    corner(shadow, 4)

    local useAcrylic = config.Acrylic == true

    -- Janela com cantos arredondados
    local WIN_RADIUS = 10
    -- Com acrílico: fundo bem transparente (0.78) pra deixar o blur vazar
    -- Sem acrílico: fundo sólido
    local winBgTransp = useAcrylic and 0.78 or 1

    -- CanvasGroup respeita UICorner no clipping (Frame+ClipsDescendants não respeita)
    local win = inst("CanvasGroup", {
        Name             = "Window",
        Size             = UDim2.new(0, W, 0, 0),
        Position         = UDim2.new(0.5, -W/2, 0.5, -H/2),
        BackgroundColor3 = T.WindowBg,
        BackgroundTransparency = winBgTransp,
        BorderSizePixel  = 0,
        ZIndex           = 1,
        Parent           = gui,
    })
    corner(win, WIN_RADIUS)
    mkStroke(win, T.WindowBorder, 1)
    self.Window   = win
    self._W, self._H = W, H

    -- Acrílico (adicionado ANTES do conteúdo, ZIndex 0)
    self._acrylic = nil
    if useAcrylic then
        local ac = createAcrylicComponent(win, T.WindowBg)
        if ac then
            self._acrylic = ac
            ac.Frame.ZIndex = 0
        end
    end

    -- Animação de abertura
    tw(win, med, { Size = UDim2.new(0, W, 0, H), BackgroundTransparency = winBgTransp })

    -- ── TitleBar ──────────────────────────────────────────
    local tb = inst("Frame", {
        Name            = "TitleBar",
        Size            = UDim2.new(1, 0, 0, TITLEBAR_H),
        BackgroundColor3= T.TitleBg,
        BorderSizePixel = 0,
        ZIndex          = 5,
        Parent          = win,
    })
    -- Linha separadora inferior
    inst("Frame", {
        Size            = UDim2.new(1, 0, 0, 1),
        Position        = UDim2.new(0, 0, 1, -1),
        BackgroundColor3= T.TitleBorder,
        BorderSizePixel = 0,
        ZIndex          = 6,
        Parent          = tb,
    })

    -- Ícone na titlebar: suporta nome Lucide OU rbxassetid:// customizado
    local titleIconW = 0
    local titleIcon  = nil

    local iconCfg = config.Icon
    if iconCfg and iconCfg ~= "" then
        local asset
        if iconCfg:match("^rbxassetid://") then
            -- Asset ID personalizado passado diretamente
            asset = iconCfg
        else
            -- Nome de ícone Lucide
            asset = iconAsset(iconCfg)
        end

        if asset then
            titleIcon = inst("ImageLabel", {
                Size            = UDim2.new(0, TITLE_ICON_S, 0, TITLE_ICON_S),
                AnchorPoint     = Vector2.new(0, 0.5),
                Position        = UDim2.new(0, 14, 0.5, 0),
                BackgroundTransparency = 1,
                Image           = asset,
                ImageColor3     = T.Primary,
                ScaleType       = Enum.ScaleType.Fit,
                ZIndex          = 6,
                Parent          = tb,
            })
            titleIconW = TITLE_ICON_S + 8
        end
    end

    -- Bolinha laranja (só aparece se NÃO tiver ícone)
    if not titleIcon then
        local dot = inst("Frame", {
            Size            = UDim2.new(0, 8, 0, 8),
            Position        = UDim2.new(0, 14, 0.5, -4),
            BackgroundColor3= T.Primary,
            BorderSizePixel = 0,
            ZIndex          = 6,
            Parent          = tb,
        })
        corner(dot, 4)
        titleIconW = 8 + 8
    end

    -- Label do título
    inst("TextLabel", {
        Size            = UDim2.new(1, -(14 + titleIconW + 70), 1, 0),
        Position        = UDim2.new(0, 14 + titleIconW + 4, 0, 0),
        BackgroundTransparency = 1,
        Text            = title,
        TextColor3      = T.TextPrimary,
        TextSize        = 13,
        Font            = Enum.Font.GothamMedium,
        TextXAlignment  = Enum.TextXAlignment.Left,
        ZIndex          = 6,
        Parent          = tb,
    })

    -- Botões da titlebar
    local function mkTbBtn(xOff, label)
        local btn = inst("TextButton", {
            Size            = UDim2.new(0, 26, 0, 26),
            Position        = UDim2.new(1, xOff, 0.5, -13),
            BackgroundColor3= T.Surface,
            Text            = label,
            TextColor3      = T.TextSecondary,
            TextSize        = 11,
            Font            = Enum.Font.GothamMedium,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            ZIndex          = 6,
            Parent          = tb,
        })
        corner(btn, 4)
        btn.MouseEnter:Connect(function() tw(btn, fast, { BackgroundColor3 = T.Primary, TextColor3 = T.PrimaryText }) end)
        btn.MouseLeave:Connect(function() tw(btn, fast, { BackgroundColor3 = T.Surface, TextColor3 = T.TextSecondary }) end)
        return btn
    end

    local closeBtn = mkTbBtn(-34, "✕")
    local minBtn   = mkTbBtn(-64, "─")

    local minimized = false
    minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        tw(win, med, { Size = UDim2.new(0, W, 0, minimized and TITLEBAR_H or H) })
        if self._acrylic then self._acrylic.SetVisible(not minimized) end
    end)
    closeBtn.MouseButton1Click:Connect(function()
        tw(win,    fast, { Size = UDim2.new(0, W, 0, 0), BackgroundTransparency = 1 })
        tw(shadow, fast, { BackgroundTransparency = 1 })
        if self._acrylic then self._acrylic.SetVisible(false) end
        task.delay(0.22, function() gui:Destroy() end)
    end)

    makeDraggable(win, tb)

    -- ── Body ──────────────────────────────────────────────
    local body = inst("Frame", {
        Name            = "Body",
        Size            = UDim2.new(1, 0, 1, -TITLEBAR_H),
        Position        = UDim2.new(0, 0, 0, TITLEBAR_H),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex          = 2,
        Parent          = win,
    })

    -- ── Sidebar ───────────────────────────────────────────
    local sidebar = inst("Frame", {
        Name            = "Sidebar",
        Size            = UDim2.new(0, SIDEBAR_W, 1, 0),
        BackgroundColor3= T.SidebarBg,
        BorderSizePixel = 0,
        ZIndex          = 3,
        Parent          = body,
    })
    -- Linha divisória direita da sidebar
    inst("Frame", {
        Size            = UDim2.new(0, 1, 1, 0),
        Position        = UDim2.new(1, -1, 0, 0),
        BackgroundColor3= T.SidebarBorder,
        BorderSizePixel = 0,
        ZIndex          = 4,
        Parent          = sidebar,
    })

    -- Lista de tabs
    local tabList = inst("Frame", {
        Name          = "TabList",
        Size          = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ZIndex        = 4,
        Parent        = sidebar,
    })
    inst("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding   = UDim.new(0, 2),
        Parent    = tabList,
    })
    mkPad(tabList, 8, 6, 8, 6)

    -- ── Área de conteúdo ──────────────────────────────────
    local contentArea = inst("Frame", {
        Name             = "ContentArea",
        Size             = UDim2.new(1, -SIDEBAR_W, 1, 0),
        Position         = UDim2.new(0, SIDEBAR_W, 0, 0),
        BackgroundColor3 = T.ContentBg,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
        ZIndex           = 3,
        Parent           = body,
    })

    self._tabList    = tabList
    self._contentArea= contentArea
    self._tabs       = {}
    self._tabData    = {}
    self._tabOrder   = 0
    self._activeTab  = nil

    return self
end


-- ════════════════════════════════════════════════════════
--   HOME TAB  (CreateHomeTab)
-- ════════════════════════════════════════════════════════
function ClaudeUI:CreateHomeTab(config)
    config = config or {}

    -- ── Cria a tab normalmente na sidebar ─────────────────
    self._tabOrder = self._tabOrder + 1
    local isFirst  = (#self._tabs == 0)
    local TAB_TITLE = "Home"

    local btn = inst("Frame", {
        Name            = "TabBtn_Home",
        Size            = UDim2.new(1, 0, 0, TAB_H),
        BackgroundColor3= isFirst and T.TabActive or T.TabNormal,
        BorderSizePixel = 0,
        LayoutOrder     = 0,  -- sempre primeiro
        ZIndex          = 5,
        Parent          = self._tabList,
    })
    corner(btn, 5)

    local indicator = inst("Frame", {
        Size            = UDim2.new(0, 3, 0.55, 0),
        Position        = UDim2.new(0, 0, 0.225, 0),
        BackgroundColor3= T.PrimaryText,
        BorderSizePixel = 0,
        Visible         = isFirst,
        ZIndex          = 6,
        Parent          = btn,
    })
    corner(indicator, 2)

    local homeIconImg = mkIcon(btn, "house", TAB_ICON_S,
        isFirst and T.IconTintActive or T.IconTint,
        6, Vector2.new(0, 0.5), UDim2.new(0, 10, 0.5, 0))
    local textOff = homeIconImg and (10 + TAB_ICON_S + 7) or 10

    local btnLabel = inst("TextLabel", {
        Size            = UDim2.new(1, -(textOff + 4), 1, 0),
        Position        = UDim2.new(0, textOff, 0, 0),
        BackgroundTransparency = 1,
        Text            = TAB_TITLE,
        TextColor3      = isFirst and T.TabActiveText or T.TabNormalText,
        TextSize        = 13,
        Font            = isFirst and Enum.Font.GothamMedium or Enum.Font.Gotham,
        TextXAlignment  = Enum.TextXAlignment.Left,
        ZIndex          = 6,
        Parent          = btn,
    })

    local clickArea = inst("TextButton", {
        Size            = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text            = "",
        ZIndex          = 7,
        Parent          = btn,
    })

    -- ── Painel principal: wrapper controla Visible, scroll dentro ─────
    local panel = inst("Frame", {
        Name             = "Panel_Home",
        Size             = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
        Visible          = false,   -- sempre começa oculto; forçado ativo no final
        ZIndex           = 4,
        Parent           = self._contentArea,
    })

    local homeScroll = inst("ScrollingFrame", {
        Name                 = "HomeScroll",
        Size                 = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel      = 0,
        ScrollBarThickness   = 5,
        ScrollBarImageColor3 = T.ScrollBar,
        ScrollingDirection   = Enum.ScrollingDirection.Y,
        CanvasSize           = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize  = Enum.AutomaticSize.None,
        ElasticBehavior      = Enum.ElasticBehavior.Never,
        ZIndex               = 4,
        Parent               = panel,
    })

    local inner = inst("Frame", {
        Size          = UDim2.new(1, -8, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ZIndex        = 4,
        Parent        = homeScroll,
    })
    mkPad(inner, 14, 14, 14, 14)
    local innerLayout = inst("UIListLayout", {
        SortOrder           = Enum.SortOrder.LayoutOrder,
        FillDirection       = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        VerticalAlignment   = Enum.VerticalAlignment.Top,
        Padding             = UDim.new(0, 10),
        Parent              = inner,
    })
    innerLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        homeScroll.CanvasSize = UDim2.new(0, 0, 0, innerLayout.AbsoluteContentSize.Y + 28)
    end)

    -- ─────────────────────────────────────────────────────
    --   HELPER: cria um card com título + ícone Lucide
    -- ─────────────────────────────────────────────────────
    local function mkCard(layoutOrder, heightOverride)
        local card = inst("Frame", {
            Size            = UDim2.new(1, 0, 0, heightOverride or 80),
            BackgroundColor3= T.Surface,
            BorderSizePixel = 0,
            LayoutOrder     = layoutOrder,
            ZIndex          = 5,
            Parent          = inner,
        })
        corner(card, 7)
        mkStroke(card, T.Border, 1)
        return card
    end

    local function mkCardTitle(parent, iconName, titleText, xOff)
        xOff = xOff or 12
        local iconImg2 = mkIcon(parent, iconName, 14, T.Primary, 6,
            Vector2.new(0, 0), UDim2.new(0, xOff, 0, 10))
        local iconOff = iconImg2 and (xOff + 14 + 6) or xOff
        inst("TextLabel", {
            Size            = UDim2.new(1, -(iconOff + 10), 0, 20),
            Position        = UDim2.new(0, iconOff, 0, 8),
            BackgroundTransparency = 1,
            Text            = titleText,
            TextColor3      = T.TextPrimary,
            TextSize        = 13,
            Font            = Enum.Font.GothamBold,
            TextXAlignment  = Enum.TextXAlignment.Left,
            ZIndex          = 6,
            Parent          = parent,
        })
        return iconOff
    end

    local function mkCardBody(parent, bodyText, yOff)
        inst("TextLabel", {
            Size            = UDim2.new(1, -24, 0, 0),
            Position        = UDim2.new(0, 12, 0, yOff or 30),
            AutomaticSize   = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Text            = bodyText,
            TextColor3      = T.TextSecondary,
            TextSize        = 11,
            Font            = Enum.Font.Gotham,
            TextXAlignment  = Enum.TextXAlignment.Left,
            TextWrapped     = true,
            ZIndex          = 6,
            Parent          = parent,
        })
    end

    -- ─────────────────────────────────────────────────────
    --   LINHA 0: Backdrop + Boas-vindas + Relógio
    -- ─────────────────────────────────────────────────────
    local topRow = inst("Frame", {
        Size            = UDim2.new(1, 0, 0, 90),
        BackgroundColor3= T.Surface,
        BorderSizePixel = 0,
        LayoutOrder     = 0,
        ZIndex          = 5,
        Parent          = inner,
    })
    corner(topRow, 7)
    mkStroke(topRow, T.Border, 1)

    -- Backdrop (imagem de fundo do card)
    local backdropAsset = "rbxassetid://9968344227" -- void padrão
    if config.Backdrop == 0 then
        -- Thumbnail do jogo
        backdropAsset = ("https://www.roblox.com/asset-thumbnail/image?assetId="
            .. tostring(game.PlaceId) .. "&width=768&height=432&format=png")
    elseif type(config.Backdrop) == "string" and config.Backdrop ~= "" then
        backdropAsset = config.Backdrop
    end

    local backdrop = inst("ImageLabel", {
        Size            = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Image           = backdropAsset,
        ImageTransparency = 0.72,
        ScaleType       = Enum.ScaleType.Crop,
        ZIndex          = 5,
        Parent          = topRow,
    })
    corner(backdrop, 7)

    -- Avatar do jogador
    local avatarFrame = inst("Frame", {
        Size            = UDim2.new(0, 60, 0, 60),
        Position        = UDim2.new(0, 14, 0.5, -30),
        BackgroundColor3= T.SurfaceActive,
        BorderSizePixel = 0,
        ZIndex          = 7,
        Parent          = topRow,
    })
    corner(avatarFrame, 8)
    mkStroke(avatarFrame, T.Primary, 2)

    local avatarImg = inst("ImageLabel", {
        Size            = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Image           = "",
        ScaleType       = Enum.ScaleType.Crop,
        ZIndex          = 8,
        Parent          = avatarFrame,
    })
    corner(avatarImg, 8)

    -- Carrega thumbnail do avatar
    local plr = Players.LocalPlayer
    if plr then
        local thumbOk, thumbUrl = pcall(function()
            return Players:GetUserThumbnailAsync(
                plr.UserId,
                Enum.ThumbnailType.HeadShot,
                Enum.ThumbnailSize.Size100x100
            )
        end)
        if thumbOk then avatarImg.Image = thumbUrl end
    end

    -- Texto de boas-vindas
    inst("TextLabel", {
        Size            = UDim2.new(0.55, 0, 0, 24),
        Position        = UDim2.new(0, 86, 0, 18),
        BackgroundTransparency = 1,
        Text            = "Welcome, " .. (plr and plr.DisplayName or "Player"),
        TextColor3      = T.TextPrimary,
        TextSize        = 16,
        Font            = Enum.Font.GothamBold,
        TextXAlignment  = Enum.TextXAlignment.Left,
        TextTruncate    = Enum.TextTruncate.AtEnd,
        ZIndex          = 7,
        Parent          = topRow,
    })
    inst("TextLabel", {
        Size            = UDim2.new(0.55, 0, 0, 16),
        Position        = UDim2.new(0, 86, 0, 44),
        BackgroundTransparency = 1,
        Text            = "How's Your Day Going? | " .. (plr and plr.Name or ""),
        TextColor3      = T.TextSecondary,
        TextSize        = 11,
        Font            = Enum.Font.Gotham,
        TextXAlignment  = Enum.TextXAlignment.Left,
        TextTruncate    = Enum.TextTruncate.AtEnd,
        ZIndex          = 7,
        Parent          = topRow,
    })

    -- Relógio / data (canto direito)
    local clockLbl = inst("TextLabel", {
        Size            = UDim2.new(0, 90, 0, 20),
        Position        = UDim2.new(1, -104, 0, 16),
        BackgroundTransparency = 1,
        Text            = "00 : 00 : 00",
        TextColor3      = T.TextPrimary,
        TextSize        = 13,
        Font            = Enum.Font.GothamMedium,
        TextXAlignment  = Enum.TextXAlignment.Right,
        ZIndex          = 7,
        Parent          = topRow,
    })
    local dateLbl = inst("TextLabel", {
        Size            = UDim2.new(0, 90, 0, 16),
        Position        = UDim2.new(1, -104, 0, 38),
        BackgroundTransparency = 1,
        Text            = "00 / 00 / 00",
        TextColor3      = T.TextSecondary,
        TextSize        = 11,
        Font            = Enum.Font.Gotham,
        TextXAlignment  = Enum.TextXAlignment.Right,
        ZIndex          = 7,
        Parent          = topRow,
    })

    -- Atualiza relógio a cada segundo
    local function updateClock()
        local t = os.date("*t")
        clockLbl.Text = string.format("%02d : %02d : %02d", t.hour, t.min, t.sec)
        dateLbl.Text  = string.format("%02d / %02d / %02d", t.day, t.month, t.year % 100)
    end
    updateClock()
    task.spawn(function()
        while panel.Parent do
            updateClock()
            task.wait(1)
        end
    end)

    -- ─────────────────────────────────────────────────────
    --   LINHA 1: Discord  |  Changelog  |  Account (3 cols)
    -- ─────────────────────────────────────────────────────
    local row1 = inst("Frame", {
        Size            = UDim2.new(1, 0, 0, 100),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder     = 1,
        ZIndex          = 5,
        Parent          = inner,
    })
    inst("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding       = UDim.new(0, 8),
        SortOrder     = Enum.SortOrder.LayoutOrder,
        Parent        = row1,
    })

    -- Card Discord
    local discordCard = inst("Frame", {
        Size            = UDim2.new(0.32, -6, 1, 0),
        BackgroundColor3= T.Surface,
        BorderSizePixel = 0,
        LayoutOrder     = 1,
        ZIndex          = 5,
        Parent          = row1,
    })
    corner(discordCard, 7)
    mkStroke(discordCard, T.Border, 1)
    mkCardTitle(discordCard, "message-circle", "Discord")
    mkCardBody(discordCard, "Tap to join the discord of your script.", 30)
    if config.DiscordInvite and config.DiscordInvite ~= "" then
        local discordBtn = inst("TextButton", {
            Size            = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text            = "",
            ZIndex          = 8,
            Parent          = discordCard,
        })
        discordBtn.MouseButton1Click:Connect(function()
            pcall(function()
                setclipboard("https://discord.gg/" .. config.DiscordInvite)
            end)
        end)
        discordCard.MouseEnter:Connect(function()
            tw(discordCard, fast, { BackgroundColor3 = T.SurfaceHover })
        end)
        discordCard.MouseLeave:Connect(function()
            tw(discordCard, fast, { BackgroundColor3 = T.Surface })
        end)
    end

    -- Card Changelog
    local changelogCard = inst("Frame", {
        Size            = UDim2.new(0.36, -6, 1, 0),
        BackgroundColor3= T.Surface,
        BorderSizePixel = 0,
        LayoutOrder     = 2,
        ZIndex          = 5,
        Parent          = row1,
    })
    corner(changelogCard, 7)
    mkStroke(changelogCard, T.Border, 1)
    mkCardTitle(changelogCard, "scroll-text", "Changelog")

    -- Mostra o primeiro update
    local firstLog = config.Changelog and config.Changelog[1]
    if firstLog then
        inst("TextLabel", {
            Size            = UDim2.new(1, -24, 0, 14),
            Position        = UDim2.new(0, 12, 0, 30),
            BackgroundTransparency = 1,
            Text            = firstLog.Title or "",
            TextColor3      = T.TextPrimary,
            TextSize        = 12,
            Font            = Enum.Font.GothamMedium,
            TextXAlignment  = Enum.TextXAlignment.Left,
            ZIndex          = 6,
            Parent          = changelogCard,
        })
        inst("TextLabel", {
            Size            = UDim2.new(1, -24, 0, 12),
            Position        = UDim2.new(0, 12, 0, 46),
            BackgroundTransparency = 1,
            Text            = firstLog.Date or "",
            TextColor3      = T.Primary,
            TextSize        = 10,
            Font            = Enum.Font.Gotham,
            TextXAlignment  = Enum.TextXAlignment.Left,
            ZIndex          = 6,
            Parent          = changelogCard,
        })
        inst("TextLabel", {
            Size            = UDim2.new(1, -24, 0, 0),
            Position        = UDim2.new(0, 12, 0, 62),
            AutomaticSize   = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Text            = firstLog.Description or "",
            TextColor3      = T.TextSecondary,
            TextSize        = 10,
            Font            = Enum.Font.Gotham,
            TextXAlignment  = Enum.TextXAlignment.Left,
            TextWrapped     = true,
            ZIndex          = 6,
            Parent          = changelogCard,
        })
    end

    -- Card Account
    local accountCard = inst("Frame", {
        Size            = UDim2.new(0.32, -6, 1, 0),
        BackgroundColor3= T.Surface,
        BorderSizePixel = 0,
        LayoutOrder     = 3,
        ZIndex          = 5,
        Parent          = row1,
    })
    corner(accountCard, 7)
    mkStroke(accountCard, T.Border, 1)
    mkCardTitle(accountCard, "circle-user", "Account")
    mkCardBody(accountCard, "Coming Soon.", 30)

    -- ─────────────────────────────────────────────────────
    --   LINHA 2: Server Info  |  Changelog completo  |  Friends
    -- ─────────────────────────────────────────────────────
    local row2 = inst("Frame", {
        Size            = UDim2.new(1, 0, 0, 180),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder     = 2,
        ZIndex          = 5,
        Parent          = inner,
    })
    inst("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding       = UDim.new(0, 8),
        SortOrder     = Enum.SortOrder.LayoutOrder,
        Parent        = row2,
    })

    -- ── Card Server ──
    local serverCard = inst("Frame", {
        Size            = UDim2.new(0.32, -6, 1, 0),
        BackgroundColor3= T.Surface,
        BorderSizePixel = 0,
        LayoutOrder     = 1,
        ZIndex          = 5,
        Parent          = row2,
    })
    corner(serverCard, 7)
    mkStroke(serverCard, T.Border, 1)
    mkCardTitle(serverCard, "server", "Server")

    -- Nome do jogo atual
    local gameName = "Unknown"
    pcall(function() gameName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name end)
    inst("TextLabel", {
        Size            = UDim2.new(1, -24, 0, 14),
        Position        = UDim2.new(0, 12, 0, 30),
        BackgroundTransparency = 1,
        Text            = "Currently Playing",
        TextColor3      = T.TextMuted,
        TextSize        = 10,
        Font            = Enum.Font.Gotham,
        TextXAlignment  = Enum.TextXAlignment.Left,
        ZIndex          = 6,
        Parent          = serverCard,
    })
    inst("TextLabel", {
        Size            = UDim2.new(1, -24, 0, 14),
        Position        = UDim2.new(0, 12, 0, 43),
        BackgroundTransparency = 1,
        Text            = gameName,
        TextColor3      = T.TextPrimary,
        TextSize        = 11,
        Font            = Enum.Font.GothamMedium,
        TextXAlignment  = Enum.TextXAlignment.Left,
        TextTruncate    = Enum.TextTruncate.AtEnd,
        ZIndex          = 6,
        Parent          = serverCard,
    })

    -- Linha divisória
    inst("Frame", {
        Size            = UDim2.new(1, -24, 0, 1),
        Position        = UDim2.new(0, 12, 0, 62),
        BackgroundColor3= T.Border,
        BorderSizePixel = 0,
        ZIndex          = 6,
        Parent          = serverCard,
    })

    -- Grid 2x2 de estatísticas do servidor
    local statsGrid = inst("Frame", {
        Size            = UDim2.new(1, -24, 0, 100),
        Position        = UDim2.new(0, 12, 0, 70),
        BackgroundTransparency = 1,
        ZIndex          = 6,
        Parent          = serverCard,
    })
    inst("UIGridLayout", {
        CellSize        = UDim2.new(0.5, -4, 0.5, -4),
        CellPadding     = UDim2.new(0, 8, 0, 8),
        SortOrder       = Enum.SortOrder.LayoutOrder,
        Parent          = statsGrid,
    })

    local function mkStat(order, label, val)
        local cell = inst("Frame", {
            BackgroundColor3= T.SurfaceActive,
            BorderSizePixel = 0,
            LayoutOrder     = order,
            ZIndex          = 7,
            Parent          = statsGrid,
        })
        corner(cell, 5)
        inst("TextLabel", {
            Size            = UDim2.new(1, -8, 0, 14),
            Position        = UDim2.new(0, 6, 0, 4),
            BackgroundTransparency = 1,
            Text            = label,
            TextColor3      = T.TextSecondary,
            TextSize        = 10,
            Font            = Enum.Font.GothamMedium,
            TextXAlignment  = Enum.TextXAlignment.Left,
            ZIndex          = 8,
            Parent          = cell,
        })
        local valLbl = inst("TextLabel", {
            Size            = UDim2.new(1, -8, 0, 14),
            Position        = UDim2.new(0, 6, 0, 18),
            BackgroundTransparency = 1,
            Text            = tostring(val),
            TextColor3      = T.TextPrimary,
            TextSize        = 11,
            Font            = Enum.Font.Gotham,
            TextXAlignment  = Enum.TextXAlignment.Left,
            TextTruncate    = Enum.TextTruncate.AtEnd,
            ZIndex          = 8,
            Parent          = cell,
        })
        return valLbl
    end

    local plrsInServer = game:GetService("Players"):GetPlayers()
    local playersLbl   = mkStat(1, "Players",  #plrsInServer .. " in server")
    local capacityLbl  = mkStat(2, "Capacity", game:GetService("Players").MaxPlayers .. " can join")
    local latencyLbl   = mkStat(3, "Latency",  math.floor((Players.LocalPlayer:GetNetworkPing() * 1000)) .. "ms")
    local regionLbl    = mkStat(4, "Region",   "—")

    -- Atualiza latência
    task.spawn(function()
        while panel.Parent do
            pcall(function()
                latencyLbl.Text = math.floor((Players.LocalPlayer:GetNetworkPing() * 1000)) .. "ms"
                playersLbl.Text = #game:GetService("Players"):GetPlayers() .. " in server"
            end)
            task.wait(3)
        end
    end)

    -- ── Card Changelog completo ──
    local clScroll = inst("ScrollingFrame", {
        Size                 = UDim2.new(0.36, -6, 1, 0),
        BackgroundColor3     = T.Surface,
        BorderSizePixel      = 0,
        ScrollBarThickness   = 3,
        ScrollBarImageColor3 = T.ScrollBar,
        CanvasSize           = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize  = Enum.AutomaticSize.Y,
        LayoutOrder          = 2,
        ZIndex               = 5,
        Parent               = row2,
    })
    corner(clScroll, 7)
    mkStroke(clScroll, T.Border, 1)

    local clInner = inst("Frame", {
        Size          = UDim2.new(1, -6, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ZIndex        = 6,
        Parent        = clScroll,
    })
    mkPad(clInner, 10, 10, 10, 10)
    inst("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding   = UDim.new(0, 8),
        Parent    = clInner,
    })

    -- Título "Changelog" dentro do scroll
    local clHdrRow = inst("Frame", {
        Size            = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
        LayoutOrder     = 0,
        ZIndex          = 6,
        Parent          = clInner,
    })
    mkIcon(clHdrRow, "scroll-text", 13, T.Primary, 7,
        Vector2.new(0, 0.5), UDim2.new(0, 0, 0.5, 0))
    inst("TextLabel", {
        Size            = UDim2.new(1, -20, 1, 0),
        Position        = UDim2.new(0, 20, 0, 0),
        BackgroundTransparency = 1,
        Text            = "Changelog",
        TextColor3      = T.TextPrimary,
        TextSize        = 13,
        Font            = Enum.Font.GothamBold,
        TextXAlignment  = Enum.TextXAlignment.Left,
        ZIndex          = 7,
        Parent          = clHdrRow,
    })

    for i, entry in ipairs(config.Changelog or {}) do
        local entryFrame = inst("Frame", {
            Size            = UDim2.new(1, 0, 0, 0),
            AutomaticSize   = Enum.AutomaticSize.Y,
            BackgroundColor3= T.SurfaceActive,
            BorderSizePixel = 0,
            LayoutOrder     = i,
            ZIndex          = 6,
            Parent          = clInner,
        })
        corner(entryFrame, 5)
        mkPad(entryFrame, 8, 8, 8, 8)
        inst("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding   = UDim.new(0, 2),
            Parent    = entryFrame,
        })
        inst("TextLabel", {
            Size            = UDim2.new(1, 0, 0, 14),
            BackgroundTransparency = 1,
            Text            = entry.Title or "",
            TextColor3      = T.TextPrimary,
            TextSize        = 12,
            Font            = Enum.Font.GothamMedium,
            TextXAlignment  = Enum.TextXAlignment.Left,
            LayoutOrder     = 1,
            ZIndex          = 7,
            Parent          = entryFrame,
        })
        inst("TextLabel", {
            Size            = UDim2.new(1, 0, 0, 12),
            BackgroundTransparency = 1,
            Text            = entry.Date or "",
            TextColor3      = T.Primary,
            TextSize        = 10,
            Font            = Enum.Font.Gotham,
            TextXAlignment  = Enum.TextXAlignment.Left,
            LayoutOrder     = 2,
            ZIndex          = 7,
            Parent          = entryFrame,
        })
        if entry.Description and entry.Description ~= "" then
            inst("TextLabel", {
                Size            = UDim2.new(1, 0, 0, 0),
                AutomaticSize   = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                Text            = entry.Description,
                TextColor3      = T.TextSecondary,
                TextSize        = 10,
                Font            = Enum.Font.Gotham,
                TextXAlignment  = Enum.TextXAlignment.Left,
                TextWrapped     = true,
                LayoutOrder     = 3,
                ZIndex          = 7,
                Parent          = entryFrame,
            })
        end
    end

    -- ── Card Friends ──
    local friendsCard = inst("Frame", {
        Size            = UDim2.new(0.32, -6, 1, 0),
        BackgroundColor3= T.Surface,
        BorderSizePixel = 0,
        LayoutOrder     = 3,
        ZIndex          = 5,
        Parent          = row2,
    })
    corner(friendsCard, 7)
    mkStroke(friendsCard, T.Border, 1)
    mkCardTitle(friendsCard, "users", "Friends")

    local friendsGrid = inst("Frame", {
        Size            = UDim2.new(1, -24, 0, 100),
        Position        = UDim2.new(0, 12, 0, 34),
        BackgroundTransparency = 1,
        ZIndex          = 6,
        Parent          = friendsCard,
    })
    inst("UIGridLayout", {
        CellSize    = UDim2.new(0.5, -4, 0.5, -4),
        CellPadding = UDim2.new(0, 8, 0, 8),
        SortOrder   = Enum.SortOrder.LayoutOrder,
        Parent      = friendsGrid,
    })

    local function mkFriendStat(order, label, val, color)
        local cell = inst("Frame", {
            BackgroundColor3= T.SurfaceActive,
            BorderSizePixel = 0,
            LayoutOrder     = order,
            ZIndex          = 7,
            Parent          = friendsGrid,
        })
        corner(cell, 5)
        inst("TextLabel", {
            Size            = UDim2.new(1, -8, 0, 14),
            Position        = UDim2.new(0, 6, 0, 4),
            BackgroundTransparency = 1,
            Text            = label,
            TextColor3      = color or T.TextSecondary,
            TextSize        = 11,
            Font            = Enum.Font.GothamMedium,
            TextXAlignment  = Enum.TextXAlignment.Left,
            ZIndex          = 8,
            Parent          = cell,
        })
        local valLabel = inst("TextLabel", {
            Size            = UDim2.new(1, -8, 0, 14),
            Position        = UDim2.new(0, 6, 0, 20),
            BackgroundTransparency = 1,
            Text            = tostring(val),
            TextColor3      = T.TextSecondary,
            TextSize        = 11,
            Font            = Enum.Font.Gotham,
            TextXAlignment  = Enum.TextXAlignment.Left,
            ZIndex          = 8,
            Parent          = cell,
        })
        return valLabel
    end

    local inServerFriendsLbl = mkFriendStat(1, "In Server", "...", T.Success)
    local offlineFriendsLbl  = mkFriendStat(2, "Offline",   "...", T.TextMuted)
    local onlineFriendsLbl   = mkFriendStat(3, "Online",    "...", T.Info)
    local totalFriendsLbl    = mkFriendStat(4, "Total",     "...", T.TextPrimary)

    -- Busca dados de amigos de forma assíncrona
    task.spawn(function()
        pcall(function()
            local friends = Players:GetFriendsAsync(Players.LocalPlayer.UserId)
            local total, online, offline, inServer = 0, 0, 0, 0
            local serverPlayers = {}
            for _, p in ipairs(Players:GetPlayers()) do serverPlayers[p.UserId] = true end

            repeat
                local page = friends:GetCurrentPage()
                for _, f in ipairs(page) do
                    total = total + 1
                    if serverPlayers[f.Id] then
                        inServer = inServer + 1
                    elseif f.IsOnline then
                        online = online + 1
                    else
                        offline = offline + 1
                    end
                end
                if not friends.IsFinished then friends:AdvanceToNextPageAsync() end
            until friends.IsFinished

            inServerFriendsLbl.Text = inServer .. " friends"
            offlineFriendsLbl.Text  = offline  .. " friends"
            onlineFriendsLbl.Text   = online   .. " friends"
            totalFriendsLbl.Text    = total    .. " friends"
        end)
    end)

    -- ─────────────────────────────────────────────────────
    --   LINHA 3: Executor Info
    -- ─────────────────────────────────────────────────────
    local execCard = inst("Frame", {
        Size            = UDim2.new(1, 0, 0, 52),
        BackgroundColor3= T.Surface,
        BorderSizePixel = 0,
        LayoutOrder     = 3,
        ZIndex          = 5,
        Parent          = inner,
    })
    corner(execCard, 7)
    mkStroke(execCard, T.Border, 1)

    -- Detecta executor
    local execName = "Unknown Executor"
    local execStatus = "maybe"  -- "supported", "unsupported", "maybe"
    local execStatusColor = T.Warning

    pcall(function()
        if identifyexecutor then
            execName = identifyexecutor()
        elseif syn and syn.request then
            execName = "Synapse X"
        elseif KRNL_LOADED then
            execName = "Krnl"
        elseif getgenv and getgenv().fluxus then
            execName = "Fluxus"
        end
    end)

    -- Verifica se está em lista de suportados/não suportados
    local supported   = config.SupportedExecutors   or {}
    local unsupported = config.UnsupportedExecutors or {}
    for _, v in ipairs(supported) do
        if v:lower() == execName:lower() then execStatus = "supported"; execStatusColor = T.Success; break end
    end
    for _, v in ipairs(unsupported) do
        if v:lower() == execName:lower() then execStatus = "unsupported"; execStatusColor = T.Error; break end
    end

    local statusIcon  = execStatus == "supported" and "circle-check"
                     or execStatus == "unsupported" and "circle-x"
                     or "help-circle"
    local statusText  = execStatus == "supported" and "Your Executor Is Supported."
                     or execStatus == "unsupported" and "Your Executor Is NOT Supported!"
                     or "Your Executor Seems To Be Supported By This Script."

    mkIcon(execCard, statusIcon, 14, execStatusColor, 6,
        Vector2.new(0, 0.5), UDim2.new(0, 12, 0.5, 0))

    inst("TextLabel", {
        Size            = UDim2.new(0.4, 0, 0, 16),
        Position        = UDim2.new(0, 32, 0, 10),
        BackgroundTransparency = 1,
        Text            = execName,
        TextColor3      = T.TextPrimary,
        TextSize        = 12,
        Font            = Enum.Font.GothamMedium,
        TextXAlignment  = Enum.TextXAlignment.Left,
        ZIndex          = 6,
        Parent          = execCard,
    })
    inst("TextLabel", {
        Size            = UDim2.new(0.6, -12, 0, 14),
        Position        = UDim2.new(0, 32, 0, 28),
        BackgroundTransparency = 1,
        Text            = statusText,
        TextColor3      = execStatusColor,
        TextSize        = 10,
        Font            = Enum.Font.Gotham,
        TextXAlignment  = Enum.TextXAlignment.Left,
        ZIndex          = 6,
        Parent          = execCard,
    })

    -- ── Registrar tab ──
    local tabData = {
        name      = TAB_TITLE,
        btn       = btn,
        btnLabel  = btnLabel,
        iconImg   = homeIconImg,
        indicator = indicator,
        panel     = panel,
    }
    table.insert(self._tabs, 1, tabData)
    self._tabData[TAB_TITLE] = tabData

    -- HomeTab força-se como ativa: esconde todos os outros painéis existentes
    -- e ativa o estilo correto nos botões da sidebar
    for _, td in ipairs(self._tabs) do
        if td.name ~= TAB_TITLE then
            td.panel.Visible     = false
            td.indicator.Visible = false
            tw(td.btn,      fast, { BackgroundColor3 = T.TabNormal })
            tw(td.btnLabel, fast, { TextColor3 = T.TabNormalText })
            td.btnLabel.Font = Enum.Font.Gotham
            if td.iconImg then td.iconImg.ImageColor3 = T.IconTint end
        end
    end
    panel.Visible        = true
    indicator.Visible    = true
    btn.BackgroundColor3 = T.TabActive
    btnLabel.TextColor3  = T.TabActiveText
    btnLabel.Font        = Enum.Font.GothamMedium
    if homeIconImg then homeIconImg.ImageColor3 = T.IconTintActive end
    self._activeTab = TAB_TITLE

    -- Hover/click
    clickArea.MouseEnter:Connect(function()
        if self._activeTab ~= TAB_TITLE then
            tw(btn, fast, { BackgroundColor3 = T.TabHover })
            tw(btnLabel, fast, { TextColor3 = T.TextPrimary })
        end
    end)
    clickArea.MouseLeave:Connect(function()
        if self._activeTab ~= TAB_TITLE then
            tw(btn, fast, { BackgroundColor3 = T.TabNormal })
            tw(btnLabel, fast, { TextColor3 = T.TabNormalText })
            if homeIconImg then tw(homeIconImg, fast, { ImageColor3 = T.IconTint }) end
        end
    end)
    clickArea.MouseButton1Click:Connect(function()
        self:_switchTab(TAB_TITLE)
    end)
end

-- ════════════════════════════════════════════════════════
--   CRIAR TAB
--   win:CreateTab({ Title = "Home", Icon = "home" })
-- ════════════════════════════════════════════════════════
function ClaudeUI:CreateTab(config)
    config = config or {}
    local tabTitle = config.Title or ("Tab " .. (self._tabOrder + 1))
    local tabIcon  = config.Icon  -- nome do ícone Lucide (string) ou nil

    self._tabOrder = self._tabOrder + 1
    local isFirst  = (#self._tabs == 0)

    -- ── Botão na sidebar ──────────────────────────────────
    local btn = inst("Frame", {
        Name            = "TabBtn_" .. tabTitle,
        Size            = UDim2.new(1, 0, 0, TAB_H),
        BackgroundColor3= isFirst and T.TabActive or T.TabNormal,
        BorderSizePixel = 0,
        LayoutOrder     = self._tabOrder,
        ZIndex          = 5,
        Parent          = self._tabList,
    })
    corner(btn, 5)

    -- Barra indicadora esquerda (ativa)
    local indicator = inst("Frame", {
        Name            = "Indicator",
        Size            = UDim2.new(0, 3, 0.55, 0),
        Position        = UDim2.new(0, 0, 0.225, 0),
        BackgroundColor3= T.PrimaryText,
        BorderSizePixel = 0,
        Visible         = isFirst,
        ZIndex          = 6,
        Parent          = btn,
    })
    corner(indicator, 2)

    -- Ícone Lucide na tab (se tiver)
    local iconImg = nil
    local textOffsetLeft = 10

    if tabIcon then
        iconImg = mkIcon(btn, tabIcon, TAB_ICON_S,
            isFirst and T.IconTintActive or T.IconTint,
            6,
            Vector2.new(0, 0.5),
            UDim2.new(0, 10, 0.5, 0)
        )
        if iconImg then
            textOffsetLeft = 10 + TAB_ICON_S + 7
        end
    end

    -- Texto da tab
    local btnLabel = inst("TextLabel", {
        Name            = "Label",
        Size            = UDim2.new(1, -(textOffsetLeft + 4), 1, 0),
        Position        = UDim2.new(0, textOffsetLeft, 0, 0),
        BackgroundTransparency = 1,
        Text            = tabTitle,
        TextColor3      = isFirst and T.TabActiveText or T.TabNormalText,
        TextSize        = 13,
        Font            = isFirst and Enum.Font.GothamMedium or Enum.Font.Gotham,
        TextXAlignment  = Enum.TextXAlignment.Left,
        ZIndex          = 6,
        Parent          = btn,
    })

    -- Área clicável
    local clickArea = inst("TextButton", {
        Size            = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text            = "",
        ZIndex          = 7,
        Parent          = btn,
    })

    -- ── Painel de conteúdo (wrapper controla Visible, scroll dentro) ──
    local panel = inst("Frame", {
        Name             = "Panel_" .. tabTitle,
        Size             = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
        Visible          = isFirst,
        ZIndex           = 4,
        Parent           = self._contentArea,
    })

    local tabScroll = inst("ScrollingFrame", {
        Name                 = "Scroll",
        Size                 = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel      = 0,
        ScrollBarThickness   = 5,
        ScrollBarImageColor3 = T.ScrollBar,
        ScrollingDirection   = Enum.ScrollingDirection.Y,
        CanvasSize           = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize  = Enum.AutomaticSize.None,
        ElasticBehavior      = Enum.ElasticBehavior.Never,
        ZIndex               = 4,
        Parent               = panel,
    })

    -- inner: largura total menos espaço da scrollbar; altura cresce automaticamente
    local inner = inst("Frame", {
        Name          = "Inner",
        Size          = UDim2.new(1, -8, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ZIndex        = 4,
        Parent        = tabScroll,
    })
    mkPad(inner, 20, 20, 20, 20)

    local listLayout = inst("UIListLayout", {
        SortOrder           = Enum.SortOrder.LayoutOrder,
        FillDirection       = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        VerticalAlignment   = Enum.VerticalAlignment.Top,
        Padding             = UDim.new(0, 10),
        Parent              = inner,
    })

    -- Sincroniza CanvasSize com o tamanho real do conteúdo
    local function updateCanvas()
        tabScroll.CanvasSize = UDim2.new(0, 0, 0,
            listLayout.AbsoluteContentSize.Y + 40)
    end
    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)

    -- Cabeçalho interno do painel
    local headerFrame = inst("Frame", {
        Name          = "PanelHeader",
        Size          = UDim2.new(1, 0, 0, 26),
        BackgroundTransparency = 1,
        LayoutOrder   = 0,
        ZIndex        = 4,
        Parent        = inner,
    })

    -- Ícone Lucide no cabeçalho do painel
    local panelIconW = 0
    local panelIcon = mkIcon(headerFrame, tabIcon, 18, T.Primary, 5,
        Vector2.new(0, 0.5), UDim2.new(0, 0, 0.5, 0))
    if panelIcon then panelIconW = 18 + 8 end

    inst("TextLabel", {
        Size            = UDim2.new(1, -panelIconW, 1, 0),
        Position        = UDim2.new(0, panelIconW, 0, 0),
        BackgroundTransparency = 1,
        Text            = tabTitle,
        TextColor3      = T.TextPrimary,
        TextSize        = 16,
        Font            = Enum.Font.GothamBold,
        TextXAlignment  = Enum.TextXAlignment.Left,
        ZIndex          = 5,
        Parent          = headerFrame,
    })

    -- Linha divisória após cabeçalho
    inst("Frame", {
        Name            = "Divider",
        Size            = UDim2.new(1, 0, 0, 1),
        BackgroundColor3= T.Border,
        BorderSizePixel = 0,
        LayoutOrder     = 1,
        ZIndex          = 4,
        Parent          = inner,
    })

    -- ── Hover / clique ────────────────────────────────────
    clickArea.MouseEnter:Connect(function()
        if self._activeTab ~= tabTitle then
            tw(btn, fast, { BackgroundColor3 = T.TabHover })
            tw(btnLabel, fast, { TextColor3 = T.TextPrimary })
        end
    end)
    clickArea.MouseLeave:Connect(function()
        if self._activeTab ~= tabTitle then
            tw(btn, fast, { BackgroundColor3 = T.TabNormal })
            tw(btnLabel, fast, { TextColor3 = T.TabNormalText })
            if iconImg then tw(iconImg, fast, { ImageColor3 = T.IconTint }) end
        end
    end)
    clickArea.MouseButton1Click:Connect(function()
        self:_switchTab(tabTitle)
    end)

    -- Registrar tab
    local tabData = {
        name      = tabTitle,
        btn       = btn,
        btnLabel  = btnLabel,
        iconImg   = iconImg,
        indicator = indicator,
        panel     = panel,
    }
    table.insert(self._tabs, tabData)
    self._tabData[tabTitle] = tabData
    if isFirst then self._activeTab = tabTitle end

    -- Objeto Tab com API de componentes
    local tabObj = {
        _inner = inner,
        _order = 2,       -- 0 = header, 1 = divider, 2+ = componentes
        _win   = self,
    }
    setmetatable(tabObj, { __index = ClaudeUI._TabAPI })

    return tabObj
end

-- Troca de tab ativa
function ClaudeUI:_switchTab(name)
    if self._activeTab == name then return end

    -- Desativar anterior
    local prev = self._tabData[self._activeTab]
    if prev then
        tw(prev.btn,      fast, { BackgroundColor3 = T.TabNormal })
        tw(prev.btnLabel, fast, { TextColor3 = T.TabNormalText })
        prev.btnLabel.Font = Enum.Font.Gotham
        if prev.iconImg then tw(prev.iconImg, fast, { ImageColor3 = T.IconTint }) end
        prev.indicator.Visible = false
        prev.panel.Visible     = false
    end

    -- Ativar nova
    local next = self._tabData[name]
    if next then
        tw(next.btn,      fast, { BackgroundColor3 = T.TabActive })
        tw(next.btnLabel, fast, { TextColor3 = T.TabActiveText })
        next.btnLabel.Font = Enum.Font.GothamMedium
        if next.iconImg then tw(next.iconImg, fast, { ImageColor3 = T.IconTintActive }) end
        next.indicator.Visible = true
        next.panel.Visible     = true
    end

    self._activeTab = name
end

-- ════════════════════════════════════════════════════════
--   API DOS COMPONENTES DENTRO DAS TABS
-- ════════════════════════════════════════════════════════
ClaudeUI._TabAPI = {}
ClaudeUI._TabAPI.__index = ClaudeUI._TabAPI

function ClaudeUI._TabAPI:_o()
    self._order = self._order + 1
    return self._order
end

-- ── AddLabel ─────────────────────────────────────────────
function ClaudeUI._TabAPI:AddLabel(text, opts)
    opts = opts or {}
    return inst("TextLabel", {
        Size          = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text          = text,
        TextColor3    = opts.Color or T.TextSecondary,
        TextSize      = opts.TextSize or 13,
        Font          = opts.Font or Enum.Font.Gotham,
        TextXAlignment= opts.Align or Enum.TextXAlignment.Left,
        TextWrapped   = true,
        RichText      = opts.Rich or false,
        LayoutOrder   = opts.Order or self:_o(),
        ZIndex        = 4,
        Parent        = self._inner,
    })
end

-- ── AddSeparator ─────────────────────────────────────────
function ClaudeUI._TabAPI:AddSeparator()
    return inst("Frame", {
        Size            = UDim2.new(1, 0, 0, 1),
        BackgroundColor3= T.Border,
        BorderSizePixel = 0,
        LayoutOrder     = self:_o(),
        ZIndex          = 4,
        Parent          = self._inner,
    })
end

-- ── AddButton ────────────────────────────────────────────
-- opts.Icon = nome lucide (opcional), renderizado à esquerda do texto
function ClaudeUI._TabAPI:AddButton(text, callback, opts)
    opts = opts or {}
    local isPrimary = opts.Primary or false
    local bgN = isPrimary and T.Primary or T.Surface
    local bgH = isPrimary and T.PrimaryHover or T.SurfaceHover

    local btn = inst("TextButton", {
        Size            = UDim2.new(1, 0, 0, opts.Height or 36),
        BackgroundColor3= bgN,
        Text            = "",
        BorderSizePixel = 0,
        LayoutOrder     = opts.Order or self:_o(),
        AutoButtonColor = false,
        ZIndex          = 4,
        Parent          = self._inner,
    })
    corner(btn, 5)
    if not isPrimary then mkStroke(btn, T.Border, 1) end

    -- Ícone Lucide no botão
    local iconW = 0
    local iconImg = mkIcon(btn, opts.Icon, 14,
        isPrimary and T.PrimaryText or T.TextSecondary,
        5, Vector2.new(0, 0.5), UDim2.new(0, 12, 0.5, 0))
    if iconImg then iconW = 14 + 8 end

    inst("TextLabel", {
        Size            = UDim2.new(1, -(12 + iconW), 1, 0),
        Position        = UDim2.new(0, 12 + iconW, 0, 0),
        BackgroundTransparency = 1,
        Text            = text,
        TextColor3      = isPrimary and T.PrimaryText or T.TextPrimary,
        TextSize        = 13,
        Font            = Enum.Font.GothamMedium,
        TextXAlignment  = iconW > 0 and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center,
        ZIndex          = 5,
        Parent          = btn,
    })

    btn.MouseEnter:Connect(function()    tw(btn, fast, { BackgroundColor3 = bgH }) end)
    btn.MouseLeave:Connect(function()    tw(btn, fast, { BackgroundColor3 = bgN }) end)
    btn.MouseButton1Down:Connect(function() tw(btn, fast, { BackgroundColor3 = T.SurfaceActive }) end)
    btn.MouseButton1Up:Connect(function()   tw(btn, fast, { BackgroundColor3 = bgH }) end)
    btn.MouseButton1Click:Connect(function() if callback then callback() end end)
    return btn
end

-- ── AddInput ─────────────────────────────────────────────
-- opts.Icon = nome lucide (ícone decorativo à esquerda)
function ClaudeUI._TabAPI:AddInput(placeholder, callback, opts)
    opts = opts or {}

    local container = inst("Frame", {
        Size            = UDim2.new(1, 0, 0, opts.Height or 38),
        BackgroundColor3= T.Surface,
        BorderSizePixel = 0,
        LayoutOrder     = opts.Order or self:_o(),
        ZIndex          = 4,
        Parent          = self._inner,
    })
    corner(container, 5)
    local s = mkStroke(container, T.Border, 1)

    local iconW = 0
    local iconImg = mkIcon(container, opts.Icon, 14, T.TextMuted, 6,
        Vector2.new(0, 0.5), UDim2.new(0, 11, 0.5, 0))
    if iconImg then iconW = 14 + 6 end

    local PLACEHOLDER_SIZE = 14
    local CONTENT_SIZE     = 20

    local box = inst("TextBox", {
        Size              = UDim2.new(1, -(12 + iconW), 1, 0),
        Position          = UDim2.new(0, 10 + iconW, 0, 0),
        BackgroundTransparency = 1,
        PlaceholderText   = placeholder or "",
        PlaceholderColor3 = T.TextMuted,
        Text              = opts.Default or "",
        TextColor3        = T.TextPrimary,
        -- Começa no tamanho do placeholder; muda para CONTENT_SIZE quando há texto
        TextSize          = (opts.Default and opts.Default ~= "") and CONTENT_SIZE or PLACEHOLDER_SIZE,
        Font              = Enum.Font.Gotham,
        ClearTextOnFocus  = false,
        ZIndex            = 6,
        Parent            = container,
    })

    -- Troca o TextSize conforme o conteúdo: vazio = placeholder size, preenchido = content size
    box:GetPropertyChangedSignal("Text"):Connect(function()
        box.TextSize = (box.Text ~= "") and CONTENT_SIZE or PLACEHOLDER_SIZE
    end)

    box.Focused:Connect(function()
        tw(s, fast, { Color = T.BorderFocus })
        if iconImg then tw(iconImg, fast, { ImageColor3 = T.Primary }) end
    end)
    box.FocusLost:Connect(function(enter)
        tw(s, fast, { Color = T.Border })
        if iconImg then tw(iconImg, fast, { ImageColor3 = T.TextMuted }) end
        if callback then callback(box.Text, enter) end
    end)
    return box
end

-- ── AddToggle ────────────────────────────────────────────
-- opts.Icon = nome lucide
function ClaudeUI._TabAPI:AddToggle(label, default, callback, opts)
    opts  = opts  or {}
    local state = default or false

    local row = inst("Frame", {
        Size            = UDim2.new(1, 0, 0, 40),
        BackgroundColor3= T.Surface,
        BorderSizePixel = 0,
        LayoutOrder     = opts.Order or self:_o(),
        ZIndex          = 4,
        Parent          = self._inner,
    })
    corner(row, 5)
    mkStroke(row, T.Border, 1)
    mkPad(row, 0, 14, 0, 12)

    -- Ícone opcional à esquerda
    local iconW = 0
    local iconImg = mkIcon(row, opts.Icon, 14, T.TextSecondary, 6,
        Vector2.new(0, 0.5), UDim2.new(0, 0, 0.5, 0))
    if iconImg then iconW = 14 + 8 end

    inst("TextLabel", {
        Size            = UDim2.new(1, -(iconW + 56), 1, 0),
        Position        = UDim2.new(0, iconW, 0, 0),
        BackgroundTransparency = 1,
        Text            = label,
        TextColor3      = T.TextPrimary,
        TextSize        = 13,
        Font            = Enum.Font.Gotham,
        TextXAlignment  = Enum.TextXAlignment.Left,
        ZIndex          = 5,
        Parent          = row,
    })

    local track = inst("Frame", {
        Size            = UDim2.new(0, 40, 0, 22),
        Position        = UDim2.new(1, -40, 0.5, -11),
        BackgroundColor3= state and T.ToggleOn or T.ToggleOff,
        BorderSizePixel = 0,
        ZIndex          = 5,
        Parent          = row,
    })
    corner(track, 11)

    local knob = inst("Frame", {
        Size            = UDim2.new(0, 18, 0, 18),
        Position        = UDim2.new(0, state and 20 or 2, 0.5, -9),
        BackgroundColor3= Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ZIndex          = 6,
        Parent          = track,
    })
    corner(knob, 9)

    local function set(v)
        state = v
        tw(track, fast, { BackgroundColor3 = state and T.ToggleOn or T.ToggleOff })
        tw(knob,  fast, { Position = UDim2.new(0, state and 20 or 2, 0.5, -9) })
    end

    inst("TextButton", {
        Size            = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text            = "",
        ZIndex          = 7,
        Parent          = row,
    }).MouseButton1Click:Connect(function()
        set(not state)
        if callback then callback(state) end
    end)

    return { Get = function() return state end, Set = set }
end

-- ── AddSlider ────────────────────────────────────────────
function ClaudeUI._TabAPI:AddSlider(label, min, max, default, callback, opts)
    opts  = opts or {}
    min   = min or 0
    max   = max or 100
    local value = math.clamp(default or min, min, max)

    local container = inst("Frame", {
        Size            = UDim2.new(1, 0, 0, 58),
        BackgroundColor3= T.Surface,
        BorderSizePixel = 0,
        LayoutOrder     = opts.Order or self:_o(),
        ZIndex          = 4,
        Parent          = self._inner,
    })
    corner(container, 5)
    mkStroke(container, T.Border, 1)
    mkPad(container, 8, 14, 8, 14)

    local hdr = inst("Frame", {
        Size            = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        ZIndex          = 5,
        Parent          = container,
    })
    inst("TextLabel", {
        Size            = UDim2.new(0.7, 0, 1, 0),
        BackgroundTransparency = 1,
        Text            = label,
        TextColor3      = T.TextPrimary,
        TextSize        = 13,
        Font            = Enum.Font.Gotham,
        TextXAlignment  = Enum.TextXAlignment.Left,
        ZIndex          = 5,
        Parent          = hdr,
    })
    local valLbl = inst("TextLabel", {
        Size            = UDim2.new(0.3, 0, 1, 0),
        Position        = UDim2.new(0.7, 0, 0, 0),
        BackgroundTransparency = 1,
        Text            = tostring(value),
        TextColor3      = T.Primary,
        TextSize        = 13,
        Font            = Enum.Font.GothamMedium,
        TextXAlignment  = Enum.TextXAlignment.Right,
        ZIndex          = 5,
        Parent          = hdr,
    })

    local track = inst("Frame", {
        Size            = UDim2.new(1, 0, 0, 5),
        Position        = UDim2.new(0, 0, 1, -5),
        BackgroundColor3= T.Border,
        BorderSizePixel = 0,
        ZIndex          = 5,
        Parent          = container,
    })
    corner(track, 3)

    local pct  = (value - min) / (max - min)
    local fill = inst("Frame", {
        Size            = UDim2.new(pct, 0, 1, 0),
        BackgroundColor3= T.Primary,
        BorderSizePixel = 0,
        ZIndex          = 6,
        Parent          = track,
    })
    corner(fill, 3)

    local knob = inst("Frame", {
        Size            = UDim2.new(0, 13, 0, 13),
        Position        = UDim2.new(pct, -6, 0.5, -6),
        BackgroundColor3= Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ZIndex          = 7,
        Parent          = track,
    })
    corner(knob, 7)

    local dragging = false
    local function update(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        value = math.floor(min + rel * (max - min) + 0.5)
        valLbl.Text = tostring(value)
        tw(fill,  fast, { Size     = UDim2.new(rel, 0, 1, 0) })
        tw(knob,  fast, { Position = UDim2.new(rel, -6, 0.5, -6) })
        if callback then callback(value) end
    end

    knob.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
    end)
    track.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; update(i.Position.X) end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then update(i.Position.X) end
    end)

    return {
        Get = function() return value end,
        Set = function(v)
            value = math.clamp(v, min, max)
            local r = (value - min) / (max - min)
            valLbl.Text = tostring(value)
            tw(fill, fast, { Size = UDim2.new(r, 0, 1, 0) })
            tw(knob, fast, { Position = UDim2.new(r, -6, 0.5, -6) })
        end,
    }
end

-- ── AddDropdown ──────────────────────────────────────────
-- opts.Icon = nome lucide (ícone à esquerda)
function ClaudeUI._TabAPI:AddDropdown(label, items, callback, opts)
    opts = opts or {}
    local selected = opts.Default or items[1] or ""
    local open     = false
    local ITEM_H   = 30
    local MAX_VIS  = math.min(#items, 5)
    local HDR_H    = 38
    local LIST_H   = MAX_VIS * ITEM_H + 6

    -- O container expande sua própria altura quando abre,
    -- empurrando os elementos abaixo e atualizando o CanvasSize naturalmente.
    local container = inst("Frame", {
        Size            = UDim2.new(1, 0, 0, HDR_H),
        BackgroundColor3= T.Surface,
        BorderSizePixel = 0,
        ClipsDescendants= true,   -- lista fica DENTRO, container cresce
        LayoutOrder     = opts.Order or self:_o(),
        ZIndex          = 10,
        Parent          = self._inner,
    })
    corner(container, 5)
    local s = mkStroke(container, T.Border, 1)

    -- Header (altura fixa no topo do container)
    local hdr = inst("TextButton", {
        Size            = UDim2.new(1, 0, 0, HDR_H),
        BackgroundTransparency = 1,
        Text            = "",
        AutoButtonColor = false,
        ZIndex          = 11,
        Parent          = container,
    })

    -- Ícone opcional
    local iconW = 0
    local iconImg = mkIcon(hdr, opts.Icon, 14, T.TextSecondary, 12,
        Vector2.new(0, 0.5), UDim2.new(0, 11, 0.5, 0))
    if iconImg then iconW = 14 + 8 end

    local selLbl = inst("TextLabel", {
        Size            = UDim2.new(1, -(iconW + 11 + 20), 1, 0),
        Position        = UDim2.new(0, iconW + 11, 0, 0),
        BackgroundTransparency = 1,
        Text            = selected,
        TextColor3      = T.TextPrimary,
        TextSize        = 13,
        Font            = Enum.Font.Gotham,
        TextXAlignment  = Enum.TextXAlignment.Left,
        ZIndex          = 12,
        Parent          = hdr,
    })

    local arrow = inst("TextLabel", {
        Size            = UDim2.new(0, 16, 0, HDR_H),
        Position        = UDim2.new(1, -20, 0, 0),
        BackgroundTransparency = 1,
        Text            = "▾",
        TextColor3      = T.TextSecondary,
        TextSize        = 13,
        ZIndex          = 12,
        Parent          = hdr,
    })

    -- Lista posicionada logo abaixo do header, dentro do container
    local list = inst("Frame", {
        Size            = UDim2.new(1, 0, 0, LIST_H),
        Position        = UDim2.new(0, 0, 0, HDR_H + 3),
        BackgroundColor3= T.SurfaceHover,
        BorderSizePixel = 0,
        ClipsDescendants= true,
        ZIndex          = 20,
        Parent          = container,
    })
    corner(list, 5)
    mkStroke(list, T.Border, 1)
    mkPad(list, 3, 3, 3, 3)
    inst("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2), Parent = list })

    local function close()
        open = false
        tw(container, fast, { Size = UDim2.new(1, 0, 0, HDR_H) })
        tw(s, fast, { Color = T.Border })
        tw(arrow, fast, { Rotation = 0 })
    end

    for i, item in ipairs(items) do
        local active = (item == selected)
        local ib = inst("TextButton", {
            Size            = UDim2.new(1, 0, 0, ITEM_H),
            BackgroundColor3= T.SurfaceHover,
            BackgroundTransparency = active and 0 or 1,
            Text            = item,
            TextColor3      = active and T.TextPrimary or T.TextSecondary,
            TextSize        = 16,
            Font            = Enum.Font.Gotham,
            BorderSizePixel = 0,
            LayoutOrder     = i,
            AutoButtonColor = false,
            ZIndex          = 21,
            Parent          = list,
        })
        corner(ib, 4)
        mkPad(ib, 0, 8, 0, 8)
        ib.MouseEnter:Connect(function()
            if item ~= selected then
                tw(ib, fast, { BackgroundTransparency = 0, TextColor3 = T.TextPrimary })
            end
        end)
        ib.MouseLeave:Connect(function()
            if item ~= selected then
                tw(ib, fast, { BackgroundTransparency = 1, TextColor3 = T.TextSecondary })
            end
        end)
        ib.MouseButton1Click:Connect(function()
            for _, ch in ipairs(list:GetChildren()) do
                if ch:IsA("TextButton") then
                    local sel = ch.Text == item
                    ch.BackgroundTransparency = sel and 0 or 1
                    ch.TextColor3 = sel and T.TextPrimary or T.TextSecondary
                end
            end
            selected = item
            selLbl.Text = item
            close()
            if callback then callback(selected) end
        end)
    end

    hdr.MouseButton1Click:Connect(function()
        open = not open
        if open then
            -- Expande o container inteiro: header + gap + lista
            tw(container, fast, { Size = UDim2.new(1, 0, 0, HDR_H + 3 + LIST_H) })
            tw(s, fast, { Color = T.BorderFocus })
            tw(arrow, fast, { Rotation = 180 })
        else
            close()
        end
    end)

    return {
        Get = function() return selected end,
        Set = function(v) selected = v; selLbl.Text = v end,
    }
end

-- ════════════════════════════════════════════════════════
--   TOAST
-- ════════════════════════════════════════════════════════
function ClaudeUI:Toast(message, kind, duration)
    kind     = kind or "info"
    duration = duration or 3

    local colorMap = { success = T.Success, warning = T.Warning, error = T.Error, info = T.Info }
    local iconMap  = { success = "circle-check", warning = "triangle-alert", error = "circle-x", info = "info" }
    local accent   = colorMap[kind] or T.Info
    local iconName = iconMap[kind]

    local pGui  = Players.LocalPlayer:WaitForChild("PlayerGui")
    local tGui  = pGui:FindFirstChild("ClaudeUI_Toasts")
    if not tGui then
        tGui = inst("ScreenGui", {
            Name = "ClaudeUI_Toasts", ResetOnSpawn = false,
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = pGui,
        })
        inst("UIListLayout", {
            SortOrder           = Enum.SortOrder.LayoutOrder,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            VerticalAlignment   = Enum.VerticalAlignment.Bottom,
            Padding             = UDim.new(0, 8),
            Parent              = tGui,
        })
        mkPad(tGui, 0, 16, 16, 0)
    end

    local toast = inst("Frame", {
        Size            = UDim2.new(0, 300, 0, 52),
        BackgroundColor3= T.Surface,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex          = 100,
        Parent          = tGui,
    })
    corner(toast, 5)
    mkStroke(toast, T.WindowBorder, 1)

    -- Barra lateral colorida
    inst("Frame", {
        Size            = UDim2.new(0, 3, 1, 0),
        BackgroundColor3= accent,
        BorderSizePixel = 0,
        ZIndex          = 101,
        Parent          = toast,
    })

    -- Ícone Lucide (com fallback para texto)
    local iconPlaced = mkIcon(toast, iconName, 15, accent, 102,
        Vector2.new(0, 0.5), UDim2.new(0, 12, 0.5, 0))
    if not iconPlaced then
        -- fallback: emoji
        local fallback = { success = "✓", warning = "⚠", error = "✕", info = "ℹ" }
        inst("TextLabel", {
            Size            = UDim2.new(0, 30, 1, 0),
            Position        = UDim2.new(0, 6, 0, 0),
            BackgroundTransparency = 1,
            Text            = fallback[kind] or "ℹ",
            TextColor3      = accent,
            TextSize        = 14,
            Font            = Enum.Font.GothamBold,
            ZIndex          = 102,
            Parent          = toast,
        })
    end

    inst("TextLabel", {
        Size            = UDim2.new(1, -50, 1, 0),
        Position        = UDim2.new(0, 44, 0, 0),
        BackgroundTransparency = 1,
        Text            = message,
        TextColor3      = T.TextPrimary,
        TextSize        = 13,
        Font            = Enum.Font.Gotham,
        TextXAlignment  = Enum.TextXAlignment.Left,
        TextWrapped     = true,
        ZIndex          = 101,
        Parent          = toast,
    })

    tw(toast, med, { BackgroundTransparency = 0 })
    task.delay(duration, function()
        tw(toast, med, { BackgroundTransparency = 1 })
        task.delay(0.25, function() toast:Destroy() end)
    end)
    return toast
end

-- ════════════════════════════════════════════════════════
--   DESTROY
-- ════════════════════════════════════════════════════════
function ClaudeUI:Destroy()
    if self._acrylic then
        self._acrylic.Destroy()
    end
    self.ScreenGui:Destroy()
end

return ClaudeUI
