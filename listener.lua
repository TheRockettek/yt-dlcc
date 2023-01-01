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

local buffer = {}
local bufferSize = 0
local bufferBytes = 0

local function dumpBuffer()
    if #buffer > 0 then
        local bufferChunk = buffer[1]
        local ok = speaker.playAudio(bufferChunk)
        if ok then
            table.remove(buffer, 1)
            local bufferSize = bufferSize - 1
            local bufferBytes = bufferBytes - #bufferChunk
        end
    end
end

while true do
    local event, paramA, paramB, paramC = os.pullEvent()
    if event == "speaker_audio_empty" then
        dumpBuffer()
    elseif event == "websocket_message" then
        local chunk =  paramB
        local chunkBuffer = decoder(chunk)
        local transferredSize = transferredSize + #chunk
        local bufferSize = bufferSize + 1
        local bufferBytes = bufferBytes + #chunk

        table.insert(buffer, chunkBuffer)
        print("Transferred: " .. transferredSize)
        dumpBuffer()
    elseif event == "timer" then
        statTimer = os.startTimer(statDelay)
        print("Sz: " .. tostring(bufferSize) .. " Buf:" .. tostring(bufferBytes) .. " Tx:".. tostring(transferredSize))
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