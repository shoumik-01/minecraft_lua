-- Open the wireless modem on the right side
rednet.open("right")

print("Waiting for messages...")

-- Infinite loop to keep receiving messages
while true do
    local senderId, message = rednet.receive() -- Receive a message
    print("Received message from ID "..senderId..": "..message)
end
