local component = require("component")
local event = require("event")
local modem = component.modem
local fs = require("filesystem")

-- IP and hostname management
local ipBase = "192.168.1."
local nextIP = 100
local leaseTable = {}
local dnsTable = {}
local addressTable = {}

-- Register server itself
local serverHostname = "server"
local serverIP = ipBase .. "1"
local serverModemAddress = modem.address
dnsTable[serverHostname] = serverIP
addressTable[serverHostname] = serverModemAddress

-- Open ports
modem.open(67) -- DHCP
modem.open(53) -- DNS + address
modem.open(80) -- HTTP

print("DHCP + DNS + HTTP Server started...")

while true do
  local _, _, senderAddress, port, _, message, payload = event.pull("modem_message")

  -- DHCP
  if port == 67 and message == "DHCP_DISCOVER" then
    local hostname = payload or "client" .. tostring(nextIP)
    if leaseTable[senderAddress] then
      modem.send(senderAddress, 68, "DHCP_ACK", leaseTable[senderAddress])
    else
      local assignedIP = ipBase .. tostring(nextIP)
      nextIP = nextIP + 1
      leaseTable[senderAddress] = assignedIP
      dnsTable[hostname] = assignedIP
      addressTable[hostname] = senderAddress
      print("Assigned IP " .. assignedIP .. " to " .. senderAddress .. " as hostname '" .. hostname .. "'")
      modem.send(senderAddress, 68, "DHCP_ACK", assignedIP)
    end

  -- DNS
  elseif port == 53 and message == "DNS_QUERY" then
    modem.send(senderAddress, 54, "DNS_RESPONSE", dnsTable[payload] or "NOT_FOUND")

  -- Address resolution
  elseif port == 53 and message == "ADDRESS_QUERY" then
    modem.send(senderAddress, 54, "ADDRESS_RESPONSE", addressTable[payload] or "NOT_FOUND")

  -- HTTP
  elseif port == 80 and message == "GET /" then
    print("HTTP request from " .. senderAddress)
    local responseBody = "Welcome to the OpenComputers Web Server!"
    local filePath = "/home/index.txt"
    if fs.exists(filePath) then
      local file = io.open(filePath, "r")
      if file then
        responseBody = file:read("*a")
        file:close()
      else
        responseBody = "Welcome to the Tridoron Server System. This message means you haven't made a index.txt file, or it's not in /home."
      end
    end

    local response = [[
HTTP/1.1 200 OK
Content-Type: text/plain

]] .. responseBody

    modem.send(senderAddress, 81, "HTTP_RESPONSE", response)
  end
end
