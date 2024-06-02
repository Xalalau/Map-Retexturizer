
local Net = {
    sendTab = {},
    receivedTab = {}
}
MR.Net = Net

if SERVER then
    util.AddNetworkString("mr_net_send_string")
end

-- Send huge string
function Net:SendString(str, callbackName, ply)
    local chunksID = util.MD5(str)
    local compressedString = util.Compress(str)

    Net:SendData(chunksID, compressedString, callbackName, ply, true)
end

-- Send huge binary
function Net:SendData(chunksID, data, callbackName, toPly, isCompressedString)
    if (string.sub(callbackName, 1, 3) ~= "NET") then
        print("Net:SendData: The callback must start with 'NET' to be a valid name") -- Improves security
        return
    end

    local chunksSubID = SysTime()

    local totalSize = string.len(data)
    local chunkSize = 64000 -- ~64KB max
    local totalChunks = math.ceil(totalSize / chunkSize)

    -- 3 minutes to remove possible memory leaks
    Net.sendTab[chunksID] = chunksSubID
    timer.Create(chunksID, 180, 1, function()
        Net.sendTab[chunksID] = nil
    end)

    for i = 1, totalChunks, 1 do
        local startByte = chunkSize * (i - 1) + 1
        local remaining = totalSize - (startByte - 1)
        local endByte = remaining < chunkSize and (startByte - 1) + remaining or chunkSize * i
        local chunk = string.sub(data, startByte, endByte)

        timer.Simple(i * 0.1, function()
            if Net.sendTab[chunksID] ~= chunksSubID then return end

            local isLastChunk = i == totalChunks

            net.Start("mr_net_send_string")
            net.WriteString(chunksID)
            net.WriteUInt(Net.sendTab[chunksID], 32)
            net.WriteUInt(#chunk, 16)
            net.WriteData(chunk, #chunk)
            net.WriteBool(isLastChunk)
            net.WriteBool(tobool(isCompressedString))
            if isLastChunk then
                net.WriteString(callbackName)
            else
                net.WriteString("")
            end
            if SERVER then
                if toPly then
                    net.Send(toPly)
                else
                    net.Broadcast()
                end
            else
                net.SendToServer()
            end

            if isLastChunk then
                Net.sendTab[chunksID] = nil
            end
        end)
    end
end

net.Receive("mr_net_send_string", function()
    local chunksID = net.ReadString()
    local chunksSubID = net.ReadUInt(32)
    local len = net.ReadUInt(16)
    local chunk = net.ReadData(len)
    local isLastChunk = net.ReadBool()
    local isCompressedString = net.ReadBool()
    local callbackName = net.ReadString() -- Empty until isLastChunk is true.

    -- Initialize streams or reset overwriten ones
    if not Net.receivedTab[chunksID] or Net.receivedTab[chunksID].chunksSubID ~= chunksSubID then
        Net.receivedTab[chunksID] = {
            chunksSubID = chunksSubID,
            data = ""
        }

        -- 3 minutes to remove possible memory leaks
        timer.Create(chunksID, 180, 1, function()
            Net.receivedTab[chunksID] = nil
        end)
    end

    -- Rebuild the compressed string
    Net.receivedTab[chunksID].data = Net.receivedTab[chunksID].data .. chunk

    -- Finish stream
    if isLastChunk then
        local data = Net.receivedTab[chunksID].data

        if isCompressedString then
            data = util.Decompress(data)
        end

        if (string.sub(callbackName, 1, 3) ~= "NET") then
            print("mr_net_send_string: The callback must start with 'NET' to be a valid name") -- Improves security
            return
        end

        _G[callbackName](data)
    end
end)