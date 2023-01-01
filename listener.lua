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

local chunkOrder = 0

local function dumpBuffer()
    if #buffer > 0 then
        local bufferChunk = buffer[1]
        local chunkBuffer = decoder(bufferChunk.data)
        local ok = speaker.playAudio(chunkBuffer)
        if ok then
            print("Queued chunk " .. bufferChunk.order)
            table.remove(buffer, 1)
            bufferSize = bufferSize - 1
            bufferBytes = bufferBytes - #bufferChunk

            sleep(0)
            dumpBuffer()
        end
    end
end

while true do
    local event, paramA, paramB, paramC = os.pullEvent()
    if event == "speaker_audio_empty" then
        dumpBuffer()
    elseif event == "websocket_message" then
        bufferSize = bufferSize + 1
        transferredSize = transferredSize + #paramB
        bufferBytes = bufferBytes + #paramB
        chunkOrder = chunkOrder + 1

        print("Recv " .. chunkOrder .. " " .. #paramB)
        table.insert(buffer, {order=chunkOrder, data=paramB})
    elseif event == "timer" then
        statTimer = os.startTimer(statDelay)
        print("Sz: " .. tostring(bufferSize) .. " Buf:" .. tostring(bufferBytes) .. " Tx:".. tostring(transferredSize))
        dumpBuffer()
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

print("Emptying buffer...")
while bufferSize > 0 do
    dumpBuffer()
    sleep(0)
end