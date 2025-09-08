-- UI Discord Notification Script (LuaU/Roblox)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Criar ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DiscordNotification"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- Frame principal
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 450, 0, 200)
mainFrame.Position = UDim2.new(0.5, -225, 0.5, -100)
mainFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
mainFrame.BackgroundTransparency = 0.05
mainFrame.BorderSizePixel = 0
mainFrame.Active = false -- Não arrastável
mainFrame.Parent = screenGui

-- Corner radius para o frame principal
local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 16)
mainCorner.Parent = mainFrame

-- Shadow effect
local shadow = Instance.new("ImageLabel")
shadow.Name = "Shadow"
shadow.Size = UDim2.new(1, 20, 1, 20)
shadow.Position = UDim2.new(0, -10, 0, -10)
shadow.BackgroundTransparency = 1
shadow.Image = "rbxasset://textures/ui/Controls/DropShadow.png"
shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
shadow.ImageTransparency = 0.8
shadow.ScaleType = Enum.ScaleType.Slice
shadow.SliceCenter = Rect.new(12, 12, 244, 244)
shadow.ZIndex = mainFrame.ZIndex - 1
shadow.Parent = mainFrame

-- Título
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.Size = UDim2.new(1, -40, 0, 80)
titleLabel.Position = UDim2.new(0, 20, 0, 20)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "O script foi atualizado. Entre no servidor do Discord pra pegar o novo script."
titleLabel.TextColor3 = Color3.fromRGB(45, 55, 72)
titleLabel.TextScaled = true
titleLabel.TextWrapped = true
titleLabel.Font = Enum.Font.GothamMedium
titleLabel.Parent = mainFrame

-- Text size constraint para o título
local titleTextSize = Instance.new("UITextSizeConstraint")
titleTextSize.MaxTextSize = 20
titleTextSize.MinTextSize = 14
titleTextSize.Parent = titleLabel

-- Botão Copiar Discord
local copyButton = Instance.new("TextButton")
copyButton.Name = "CopyButton"
copyButton.Size = UDim2.new(0, 180, 0, 50)
copyButton.Position = UDim2.new(0.5, -90, 1, -80)
copyButton.BackgroundColor3 = Color3.fromRGB(139, 92, 246)
copyButton.BorderSizePixel = 0
copyButton.Text = "Copiar Discord"
copyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
copyButton.TextScaled = true
copyButton.Font = Enum.Font.GothamBold
copyButton.Parent = mainFrame

-- Corner radius para o botão
local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 12)
buttonCorner.Parent = copyButton

-- Text size constraint para o botão
local buttonTextSize = Instance.new("UITextSizeConstraint")
buttonTextSize.MaxTextSize = 16
buttonTextSize.MinTextSize = 12
buttonTextSize.Parent = copyButton

-- Gradiente para o botão
local buttonGradient = Instance.new("UIGradient")
buttonGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(139, 92, 246)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(124, 58, 237))
}
buttonGradient.Rotation = 135
buttonGradient.Parent = copyButton

-- Mensagem de sucesso
local successLabel = Instance.new("TextLabel")
successLabel.Name = "SuccessLabel"
successLabel.Size = UDim2.new(1, -40, 0, 20)
successLabel.Position = UDim2.new(0, 20, 1, -25)
successLabel.BackgroundTransparency = 1
successLabel.Text = "Link copiado com sucesso!"
successLabel.TextColor3 = Color3.fromRGB(16, 185, 129)
successLabel.TextScaled = true
successLabel.Font = Enum.Font.GothamMedium
successLabel.TextTransparency = 1
successLabel.Parent = mainFrame

-- Text size constraint para mensagem de sucesso
local successTextSize = Instance.new("UITextSizeConstraint")
successTextSize.MaxTextSize = 14
successTextSize.MinTextSize = 10
successTextSize.Parent = successLabel

-- Função para copiar o link do Discord
local function copyDiscordLink()
    -- Verifica se setclipboard existe
    if setclipboard then
        setclipboard("https://discord.gg/T7kqyhrBy7")
        
        -- Animação do botão
        local buttonTweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true)
        local buttonTween = TweenService:Create(copyButton, buttonTweenInfo, {
            Size = UDim2.new(0, 190, 0, 55)
        })
        buttonTween:Play()
        
        -- Mostrar mensagem de sucesso
        local successTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local successTween = TweenService:Create(successLabel, successTweenInfo, {
            TextTransparency = 0
        })
        successTween:Play()
        
        -- Esconder mensagem de sucesso após 2 segundos
        wait(2)
        local hideTween = TweenService:Create(successLabel, successTweenInfo, {
            TextTransparency = 1
        })
        hideTween:Play()
    else
        warn("setclipboard não está disponível neste executor")
    end
end

-- Efeito hover para o botão
copyButton.MouseEnter:Connect(function()
    local hoverTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local hoverTween = TweenService:Create(copyButton, hoverTweenInfo, {
        BackgroundColor3 = Color3.fromRGB(124, 58, 237),
        Size = UDim2.new(0, 185, 0, 52)
    })
    hoverTween:Play()
end)

copyButton.MouseLeave:Connect(function()
    local leaveTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local leaveTween = TweenService:Create(copyButton, leaveTweenInfo, {
        BackgroundColor3 = Color3.fromRGB(88, 28, 135),
        Size = UDim2.new(0, 180, 0, 50)
    })
    leaveTween:Play()
end)

-- Conectar função ao clique do botão
copyButton.MouseButton1Click:Connect(copyDiscordLink)

-- Animação de entrada
mainFrame.Size = UDim2.new(0, 0, 0, 0)
local entranceTweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local entranceTween = TweenService:Create(mainFrame, entranceTweenInfo, {
    Size = UDim2.new(0, 450, 0, 200)
})
entranceTween:Play()

print("UI Discord Notification carregada com sucesso!")
