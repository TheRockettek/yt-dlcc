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

local websocket
http.websocketAsync(gateway)

local transferredSize = 0

local statDelay = 1
local statTimer = os.startTimer(0)

local function dumpBuffer()
    local ok = speaker.playAudio(buffer)
    if ok then
        buffer = {}
        local bufferSize = 0
    end
end

while true do
    local event, paramA, paramB, paramC = os.pullEvent()
    if event == "websocket_message" then
        local chunk =  paramB
        local buffer = decoder(chunk)
        local transferredSize = transferredSize + #chunk
        print("Transferred: " .. transferredSize)

        while not speaker.playAudio(chunkBuffer) do
            os.pullEvent("speaker_audio_empty")
        end
    elseif event == "websocket_success" then
        print("Connected to gateway")
        websocket = paramB
        websocket.send(textutils.serializeJSON({url=query}))
    elseif event == "websocket_closed" then
        print("Connection closed")
        break
    elseif event == "websocket_failure" then
        print("Failed to connect to gateway")
        break
    end
end