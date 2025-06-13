nic.open(80)
local testpacket = nil
while testpacket == nil do
    testpacket = NetRecieve()
end
print("recived packet "..testpacket.data.test.."")
local testmessage = {protocol = "TEST", action = "POST", test = "pong"}
errorMessage =  NetSend(testpacket.sourceIP,testpacket.targetPort,80,testmessage)
print(errorMessage)