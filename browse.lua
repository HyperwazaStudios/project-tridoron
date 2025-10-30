local component = require("component")
local event = require("event")
local modem = component.modem
local fs = require("filesystem")
 
modem.open(68) -- DHCP response
modem.open(54) -- DNS + address response
modem.open(81) -- HTTP response
 
-- Parse arguments
local args = {...}
local targetHostname = args[1] or "server"
local forceRequest = false
for i = 2, #args do
  if args[i] == "--force" then
    forceRequest = true
  end
end
 
-- Define cache filename
local filename = targetHostname .. "_response.txt"
 
-- Check cache
if not forceRequest and fs.exists(filename) then
  print("Cached response found: " .. filename)
  print("Use --force to re-request from server.")
  local file = io.open(filename, "r")
  if file then
    local cached = file:read("*a")
    file:close()
    print("Cached content:\n" .. cached)
  end
  return
end
 
-- Step 1: DHCP
local myHostname = "browserClient"
print("Requesting IP via DHCP...")
modem.broadcast(67, "DHCP_DISCOVER", myHostname)
local _, _, _, _, _, dhcpLabel, myIP = event.pull("modem_message")
if dhcpLabel ~= "DHCP_ACK" then
  print("DHCP failed")
  return
end
print("Assigned IP: " .. myIP)
 
-- Step 2: DNS
print("Resolving hostname '" .. targetHostname .. "'...")
modem.broadcast(53, "DNS_QUERY", targetHostname)
local _, _, _, _, _, dnsLabel, serverIP = event.pull("modem_message")
if dnsLabel ~= "DNS_RESPONSE" or serverIP == "NOT_FOUND" then
  print("DNS lookup failed")
  return
end
print("Resolved to IP: " .. serverIP)
 
-- Step 3: Address resolution
print("Resolving modem address for '" .. targetHostname .. "'...")
modem.broadcast(53, "ADDRESS_QUERY", targetHostname)
local _, _, _, _, _, addrLabel, serverModem = event.pull("modem_message")
if addrLabel ~= "ADDRESS_RESPONSE" or serverModem == "NOT_FOUND" then
  print("Modem address lookup failed")
  return
end
print("Resolved modem address: " .. serverModem)
 
-- Step 4: HTTP request
print("Sending HTTP request to " .. serverModem)
modem.send(serverModem, 80, "GET /")
local _, _, _, _, _, httpLabel, response = event.pull("modem_message")
if httpLabel == "HTTP_RESPONSE" then
  print("Received response:\n" .. response)
 
  -- Step 5: Cache response to file
  local file = io.open(filename, "w")
  if file then
    file:write(response)
    file:close()
    print("Response cached to file: " .. filename)
  else
    print("Failed to write response to file")
  end
else
  print("No response from server")
end
