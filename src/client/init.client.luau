--!strict
-- Client bootstrap: Init then Start, same lifecycle discipline as the server.

local Network = require(script.controllers.NetworkController)
local UI = require(script.controllers.UIController)

Network.Init()
UI.Init()
UI.Start(Network)

print("[MUTATE] client initialized")
