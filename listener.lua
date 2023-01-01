local defaultGateway = ""

args = { ... }

local query = args[1]
local gateway = args[2] or defaultGateway

local function printUsage()
    if defaultGateway == nil or defaultGateway == "" then
        printError("Usage: " .. shell.getRunningProgram() .. " <query> <gateway>")
    else
        printError("Usage: " .. shell.getRunningProgram() .. " <query> [gateway]")
    end
end

if query == nil or query == "" then
    printUsage()
    return
end

if gateway == nil or gateway == "" then
    printUsage()
    return
end

local speaker = peripheral.find("speaker")
if speaker == nil then
    printError("No speaker is attached")
    return
end

if speaker.playAudio == nil then
    printError("Speaker is not playable")
    return
end

local dfpwm = require("cc.audio.dfpwm")
local decoder = dfpwm.make_decoder()

local websocket = http.websocket(gateway)

local buffer = {}
local bufferSize = 0

local transferredSize = 0

local statDelay = 1
local statTimer = os.startTimer(0)

while true do
    local event, paramA, paramB, paramC = os.pullEvent()
    if event == "speaker_audio_empty" then
        local ok = speaker.playAudio(buffer)
        if ok then
            buffer = {}
            local bufferSize = 0
        end
    elseif event == "websocket_message" then
        local chunk = paramB
        local chunkBuffer = decoder(chunk)
        local transferredSize = transferredSize + #chunk
        local bufferSize = bufferSize + #chunk
        for _, v in pairs(chunkBuffer) do
            table.insert(buffer, v)
        end
    elseif event == "timer" then
        if paramA == statTimer then
            statTimer = os.startTimer(statDelay)
            print("Transferred: " .. transferredSize .. " Buffer: " .. bufferSize)
        end
    elseif event == "websocket_success" then
        print("Connected to gateway")
        websocket.send(textutils.serializeJSON({url=query}))
        break
    elseif event == "websocket_closed" then
        print("Connection closed")
        break
    elseif event == "websocket_failure" then
        print("Failed to connect to gateway")
        break
    end
end