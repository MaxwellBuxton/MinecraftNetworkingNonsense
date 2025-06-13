nic.open(80)
local testmessage = {protocol = "TEST", action = "GET", test = "ping"}
errorMessage = NetSend("1.1.1.3",80,80,testmessage)
print("sent message "..testmessage.test.."")
print(errorMessage)
local recieveddata = nil
while recieveddata == nil do
    recieveddata = NetRecieve()
end
print("recieved response: "..recieveddata.data.test.."")
