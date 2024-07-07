-- Open the wireless modem on the right side
rednet.open("right")

-- Infinite loop to keep asking for messages to broadcast
while true do
    print("Enter a message to broadcast:")
    local message = read()
    rednet.broadcast(message)
    print("Message sent: "..message)
end
