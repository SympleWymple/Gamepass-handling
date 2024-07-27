local GamepassManager = {}
local LoadModule coroutine.wrap(function(...) LoadModule = require(game.ReplicatedStorage.LoadModule) end)()
local MarketplaceService = LoadModule.MarketplaceService
-- | Cache for player gamepass ownership | --
local playerGamepassCache = {}

local GamepassAutomaticOwnership = LoadModule.Settings.GamepassAutomaticOwnership
if GamepassAutomaticOwnership then
	warn("GamepassAutomaticOwnership is ENABLED. ALL DEVS get the passes automatically")
end

function GamepassManager:giveGamepassToPlayer(player, gamepassId)
	local playerUserId = player.userId
	local playerData = LoadModule.DataService:GetData(player)
	if not playerData then
		return
	end
	local playerCache = playerGamepassCache["id-"..player.userId]
	if not playerCache then
		playerGamepassCache["id-"..player.userId] = {}
		playerCache = playerGamepassCache["id-"..player.userId]
	end
	if not LoadModule.Functions.SearchArray(playerCache, gamepassId) then
		table.insert(playerCache, gamepassId)
		LoadModule.Network:Fire("Gamepass Bought", gamepassId)
	end
end

-- | Check if a player owns a specific gamepass | --
function GamepassManager:Owns(player, gamepassId)
	local playerData = LoadModule.DataService:GetData(player)
	if playerData then
		for _, ownedGamepassId in ipairs(playerGamepassCache["id-"..player.userId]) do
			if ownedGamepassId == gamepassId then
				return true
			end
		end
	end
	return false
end

-- | Get the number of gamepasses a player owns | --
function GamepassManager.OwnsAmount(player)
	local count = 0
	for _, gamepassId in ipairs(playerGamepassCache["id-"..player.userId]) do
		if GamepassManager:Owns(player, gamepassId) then
			count = count + 1
		end
	end
	return count
end

-- | Check and update player's gamepass ownership | --
function CheckPlayer(player)
	local userId = player.UserId
	if not LoadModule.DataService:GetData(player) then
		return
	end

	local playerCache = playerGamepassCache["id-" .. userId]
	if not playerCache then
		playerGamepassCache["id-" .. userId] = {}
		playerCache = playerGamepassCache["id-" .. userId]
	end

	for _, gamepass in pairs(LoadModule.Directory.Gamepasses) do
		local gamepassId = gamepass.Id
		if not table.find(playerCache, gamepassId) then
			local ownsGamepass = false
			pcall(function()
				ownsGamepass = MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)
			end)
			if ownsGamepass then
				GamepassManager:giveGamepassToPlayer(player, gamepassId)
				LoadModule.Network:Fire("Gamepass Bought", player, gamepassId)
			end
		end
	end
end


function RemovePlayer(player)
	playerGamepassCache["id-" .. player.UserId] = nil
end


MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamepassId, wasPurchased)
	if player and wasPurchased then
		LoadModule.Network:Fire("Gamepass Bought", player, gamepassId)
	end
end)

LoadModule.Signal.Fired("Player Added"):Connect(function(player)
	CheckPlayer(player)
end)

LoadModule.Network:Bind("Get All Gamepasses").OnInvoke = function(player)
	return playerGamepassCache["id-" .. player.UserId]
end

game.Players.PlayerRemoving:Connect(function(player)
	RemovePlayer(player)
end)

-- | Periodically check all players | --
coroutine.wrap(function()
	while true do
		wait(1)
		for _, player in ipairs(game.Players:GetPlayers()) do
			pcall(function()
				if player then
					CheckPlayer(player)
				end
			end)
		end
	end
end)()

return GamepassManager
