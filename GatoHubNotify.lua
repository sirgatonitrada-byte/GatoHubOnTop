repeat wait() until game:IsLoaded() and game.Players.LocalPlayer
-- Teleport simples somente se estiver em place diferente
local TARGET_PLACEID = 109983668079237
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local function hopAnyServer(placeId)
    local tries = {
        function() return TeleportService:Teleport(placeId, Players.LocalPlayer) end,
        function() return TeleportService:Teleport(tostring(placeId), Players.LocalPlayer) end,
        function() return TeleportService:Teleport(placeId) end,
        function() return TeleportService:Teleport(tostring(placeId)) end,
    }

    for i, fn in ipairs(tries) do
        local ok, err = pcall(fn)
        if ok then
            print(("[Hop] Teleport chamado com sucesso (tentativa %d)."):format(i))
            return true
        else
            warn(("[Hop] Tentativa %d falhou: %s"):format(i, tostring(err)))
            task.wait(0.4)
        end
    end

    warn("[Hop] Todas as tentativas falharam.")
    return false
end

-- Checagem: só teleporta se o Place atual for diferente do alvo
if game.PlaceId ~= TARGET_PLACEID then
    print(("[Hop] Place atual (%s) é diferente do alvo (%s). Iniciando hop..."):format(tostring(game.PlaceId), tostring(TARGET_PLACEID)))
    hopAnyServer(TARGET_PLACEID)
else
    print(("[Hop] Já está no PlaceID alvo (%s). Nenhum teleport executado."):format(tostring(TARGET_PLACEID)))
end

--// Serviços
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local plots = Workspace:WaitForChild("Plots")

--// Lista de nomes especiais (exemplo)
local specialNames = {
    "67", "Agarrini la Palini", "Ballerina", "Bisonte Giuppitere", "Blackhole Goat",
    "Celularcini Viciosini", "Chimpanzini Spiderini", "Cicleteira Bicicleteira", "Dragon Cannelloni",
    "Dul Dul Dul", "Esok Sekolah", "Extinct", "Extinct Matteo", "Extinct Tralalero",
    "Garama and Madundung", "Garama e Madundung", "Graipuss Medussi", "Guerriro Digitale",
    "Job Job Job Sahur", "Karkerkar Kurkur", "Ketchuru and Musturu", "Ketupat Kepat",
    "La Grande Combinasion", "La Karkerkar Combinasion", "La Sahur Combinacion", "La Supreme Combinasion",
    "La Vacca Saturno Saturnita", "Las sis", "Las Tralaleritas", "Las Vaquitas Saturnitas", "Los Bros",
    "Los Bros Spaghetti Tualetti", "Los Combinasionas", "Los Hotspotsitos", "Los Nooo My Hotspotsitos",
    "Los Spyderinis", "Los Tralaleritos", "Nuclearo Dinossauro", "Pot Hotspot", "Sammyni Spyderini",
    "Spaghetti Tualetti", "Strawberry Elephant", "Tacorita Bicicleta", "Tortuginni Dragonfruitini", "Tralaledon"
}

--// Conversor string para número
local function conversor(valor)
    if not valor then return 0 end
    local mult = 1
    local number = valor:match("[%d%.]+")
    if valor:find("K") then mult = 1_000
    elseif valor:find("M") then mult = 1_000_000
    elseif valor:find("B") then mult = 1_000_000_000 end
    return tonumber(number) and tonumber(number) * mult or 0
end

--// XOR compatível Lua 5.1
local function xor(a, b)
    local r = 0
    local bitval = 1
    while a > 0 or b > 0 do
        local abit = a % 2
        local bbit = b % 2
        if abit ~= bbit then
            r = r + bitval
        end
        a = (a - abit) / 2
        b = (b - bbit) / 2
        bitval = bitval * 2
    end
    return r
end

local function hex_to_bytes(hex)
    local bytes = {}
    if not hex then return bytes end
    hex = hex:gsub("%s+", "")
    for i = 1, #hex, 2 do
        local byte_hex = hex:sub(i, i+1)
        local num = tonumber(byte_hex, 16)
        if num then table.insert(bytes, num) end
    end
    return bytes
end

local function bytes_to_hex(bytes)
    local parts = {}
    for i = 1, #bytes do
        table.insert(parts, string.format("%02x", bytes[i]))
    end
    return table.concat(parts)
end

local function xor_bytes_with_key(data_bytes, key_bytes)
    local out = {}
    local key_len = #key_bytes
    if key_len == 0 then return out end
    for i = 1, #data_bytes do
        local k = key_bytes[((i-1) % key_len) + 1]
        out[i] = xor(data_bytes[i], k) % 256
    end
    return out
end

local function string_to_bytes(s)
    local bytes = {}
    for i = 1, #s do
        bytes[i] = string.byte(s, i)
    end
    return bytes
end

--// Chave XOR (hex)
local XOR_KEY_HEX = "c201c6ac4ef91c87feded16de296f3f914d4b0a997475b8e6afa8177b45731bededfb2f7092ba815e8053a87d578a1b2cdba1e1c71279ff1337419f8c460542d0eb1e5618e8dYYnoskid"
local XOR_KEY_BYTES = hex_to_bytes(XOR_KEY_HEX)

--// Função para enviar webhook e API
local function sendSecretWebhook(nome, gen, jobId, raridade)
    local valor = conversor(gen)
    local webhookURL
    if valor >= 1 and valor <= 4_990_000 then
        webhookURL = "https://discord.com/api/webhooks/1421921160110674052/A-jaEk9TaGD9Ijjd3e89jAevSJs7_LTGvPhkx25XZ62S_thx9ICVRq3nhM2o7yUQNsAn"
    elseif valor >= 5_000_000 and valor <= 9_990_000 then
        webhookURL = "https://discord.com/api/webhooks/1421921355716235264/Fcvxmxiz3hjBkh88dOdPui10GAQBEzU5fstruuBG0Pw0-CytKY6AmknKFs-zqlOYwN1_"
    elseif valor >= 10_000_000 and valor <= 49_990_000 then
        webhookURL = "https://discord.com/api/webhooks/1421921447651180566/YZqKz35nVJrn7J9d65hZdW0ifI51kfM6hF31-LNHr-AaogreCCxpfTo-HhFiWSwS3pv6"
    elseif valor >= 50_000_000 and valor <= 99_990_000 then
        webhookURL = "https://discord.com/api/webhooks/1421921543016939632/ebjxt3C2ytqcNpevGOlAY7bc_MUR6JVJYAzPT_BlXg80hCl1fIJJhAojuFr0xy935RnJ"
    elseif valor >= 100_000_000 and valor <= 299_990_000 then
        webhookURL = "https://discord.com/api/webhooks/1421921644842057961/hf0oD6FfbddkejoUJBdX7MfJxqnhfzelH6BvhhOEcJ3pDcbh369ebW-eNgFy_Hkld9YM"
    elseif valor >= 300_000_000 then
        webhookURL = "https://discord.com/api/webhooks/1421921785938706463/jkqo2jo-3cPbqfmJNReJUcgYipVbOYKXjFWgvlCVqEuuvRyLeeeR4FltExRyb12fGlw_"
    else
        print("[Webhook] Geração inválida, não enviado: "..tostring(gen))
        return
    end

    local PlaceID = game.PlaceId
    local joinerUrl = string.format("https://chillihub1.github.io/chillihub-joiner/?placeId=%s&gameInstanceId=%s", PlaceID, jobId)

    local embedColor = 16753920 -- amarelo default (Secret)
    local extraContent = nil
    local titleText = "🏷️ Secret Found!"

    if raridade == "OG" then
        embedColor = 16711680 -- vermelho
        extraContent = "@everyone"
        titleText = "🔥 OG Found!"
    end

    local payload = {
        content = extraContent,
        embeds = {{
            title = titleText,
            color = embedColor,
            fields = {
                {name="Name", value="```"..(nome or "Unknown").."```", inline=true},
                {name="Generation", value="```"..(gen or "0").."```", inline=true},
                {name="Rarity", value="```"..(raridade or "Unknown").."```", inline=true},
                {name="JOB ID MOBILE", value="```"..jobId.."```"},
                {name="JOB ID PC", value="```"..jobId.."```"},
                {name="🔗 Link Rápido", value="[**CLIQUE AQUI PARA ENTRAR**]("..joinerUrl..")", inline=false},
                {name="📜 Comando (PC)", value=string.format('```lua\ngame:GetService("TeleportService"):TeleportToPlaceInstance(%d,"%s",game.Players.LocalPlayer)\n```',PlaceID,jobId), inline=false}
            }
        }}
    }

    local encoded = HttpService:JSONEncode(payload)
    local requestFunc = http_request or request or (syn and syn.request) or (fluxus and fluxus.request) or (http and http.request)
    if requestFunc then
        pcall(function()
            requestFunc({Url = webhookURL, Method="POST", Headers={["Content-Type"]="application/json"}, Body=encoded})
        end)
    end

    -- Envio para API (XOR)
    if XOR_KEY_BYTES and #XOR_KEY_BYTES > 0 and requestFunc then
        local job_bytes = string_to_bytes(tostring(jobId))
        local encrypted_bytes = xor_bytes_with_key(job_bytes, XOR_KEY_BYTES)
        local encrypted_hex = bytes_to_hex(encrypted_bytes)

        local body = {}
        if valor >= 1 and valor <= 4_990_000 then body.jobId1M = encrypted_hex
        elseif valor >= 5_000_000 and valor <= 9_990_000 then body.jobId5M = encrypted_hex
        elseif valor >= 10_000_000 and valor <= 49_990_000 then body.jobId10M = encrypted_hex
        elseif valor >= 50_000_000 and valor <= 99_990_000 then body.jobId50M = encrypted_hex
        elseif valor >= 100_000_000 and valor <= 299_990_000 then body.jobId100M = encrypted_hex
        elseif valor >= 300_000_000 then body.jobId300M = encrypted_hex
        end

        pcall(function()
            requestFunc({
                Url = "https://apifoda-ei7u.vercel.app/job",
                Method="POST",
                Headers={["Content-Type"]="application/json"},
                Body=HttpService:JSONEncode(body)
            })
        end)
    end
end

--// Cache de Secrets
local lastSecrets = {}

--// Checker de Secrets
local function checker()
    local currentSecrets = {}
    for _, plot in ipairs(plots:GetChildren()) do
        local animalPodiums = plot:FindFirstChild("AnimalPodiums")
        if animalPodiums then
            for _, model in ipairs(animalPodiums:GetChildren()) do
                local base = model:FindFirstChild("Base")
                local spawn = base and base:FindFirstChild("Spawn")
                local attach = spawn and spawn:FindFirstChild("Attachment")
                local overhead = attach and attach:FindFirstChild("AnimalOverhead")
                if overhead then
                    local nomeObj = overhead:FindFirstChild("DisplayName")
                    local genObj = overhead:FindFirstChild("Generation")
                    local rarityObj = overhead:FindFirstChild("Rarity")
                    local nomeText = (nomeObj and nomeObj.Text) or "Unknown"
                    local genText = (genObj and genObj.Text) or "0"
                    local valorcorreto = conversor(genText)

                    if rarityObj and (rarityObj.Text == "Secret" or rarityObj.Text == "OG") and valorcorreto >= 200_000 then
                        local secretId = nomeText.."_"..genText.."_"..rarityObj.Text
                        currentSecrets[secretId] = {nome=nomeText, gen=genText, raridade=rarityObj.Text}
                    end
                end
            end
        end
    end

    for id, data in pairs(currentSecrets) do
        if not lastSecrets[id] then
            print("[Checker] Novo encontrado: "..data.nome.." | "..data.gen.." | "..data.raridade)
            sendSecretWebhook(data.nome, data.gen, game.JobId, data.raridade)
        end
    end

    lastSecrets = currentSecrets
end

--// Server Hop
local SERVER_HOP_COOLDOWN = 1
local lastServerHop = 0
local foundAnything = ""
local PlaceID = game.PlaceId
local HUNTER_COUNT = 6
local myHunterId = Players.LocalPlayer and (Players.LocalPlayer.UserId % HUNTER_COUNT) or 0

local function TPReturner()
    if tick() - lastServerHop < SERVER_HOP_COOLDOWN then return end
    lastServerHop = tick()
    local url = 'https://games.roblox.com/v1/games/'..PlaceID..'/servers/Public?sortOrder=Asc&limit=100'
    if foundAnything ~= "" then url = url.."&cursor="..foundAnything end
    local success, result = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(url))
    end)
    if not success or not result or not result.data then return end
    foundAnything = result.nextPageCursor or ""
    local candidateServerID
    for i, serverInfo in ipairs(result.data) do
        if (i-1) % HUNTER_COUNT == myHunterId then
            if serverInfo.playing < serverInfo.maxPlayers then
                candidateServerID = tostring(serverInfo.id)
                break
            end
        end
    end
    if candidateServerID then
        print("Caçador #"..myHunterId.." encontrou servidor:", candidateServerID)
        pcall(function()
            TeleportService:TeleportToPlaceInstance(PlaceID, candidateServerID, Players.LocalPlayer)
        end)
    else
        print("Caçador #"..myHunterId.." não encontrou servidor disponível. Procurando...")
    end
end

checker()
--// Serviços
local Players = game:GetService("Players")
local Player = Players.LocalPlayer

--// URL do backend
local url = "https://apifoda-ei7u.vercel.app/status"

--// Dados a enviar
local data = {
    nome = Player.Name
}

--// Função para enviar o POST usando http_request
local function sendUsername()
    local request = http_request or request or syn.request -- compatibilidade
    local response = request({
        Url = url,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json"
        },
        Body = game:GetService("HttpService"):JSONEncode(data)
    })

    if response.Success then
        print("Enviado com sucesso! Resposta:", response.Body)
    else
        warn("Erro ao enviar:", response.Body)
    end
end

--// Enviar
sendUsername()


wait(2)
--// Loop principal
while true do
    task.wait(5)
    TPReturner()
end
