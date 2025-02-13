-- Credits: KIT
-- Date 14/01/2021

if not TeamOrdering then
	TeamOrdering = class({})
	TeamOrdering.winrates = {}
	TeamOrdering.start_time = 10.0
	TeamOrdering.Radiant = {}
	TeamOrdering.Dire = {}
	TeamOrdering.minimum_level_to_reorder = 25
	TeamOrdering.fixed_winrate_for_rookies = 50
--	TeamOrdering.fixed_winrates_for_uncalibrated = 15
end

-- events

-- This function is ONLY for testing purposes
ListenToGameEvent('game_rules_state_change', function()
	if GameRules:State_Get() == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
		-- ultimate fail-safe in case something goes wrong
		if PARTIES_ALLOWED == false then
			GameRules:SetCustomGameSetupRemainingTime(TeamOrdering.start_time * 2)
		end

		if IsInToolsMode() then
			TeamOrdering:OnPlayersLoaded() -- called when backend connected for public games
		end
	elseif GameRules:State_Get() == DOTA_GAMERULES_STATE_HERO_SELECTION then
		-- Call it here to re-apply players to rightful teams in case a smart boi use shuffle command as lobby leader

		-- causing weird player disconnects and unable to reconnect (sending players in another team but not fully due to being done in hero selection phase?)
--		TeamOrdering:SetTeams_PostCompute()
	end
end, nil)

-- This function is ONLY for public games (triggers when backend successfully gathered every players winrates)
function TeamOrdering:OnPlayersLoaded()
	if PlayerResource:GetPlayerCount() > 3 or IsInToolsMode() then
		-- re-order teams based on winrate with a delay to make sure winrate values are gathered
		GameRules:GetGameModeEntity():SetContextThink(DoUniqueString("anti_stacks_fucker"), function()
			self:ComputeTeamSelection()

			-- fail-safe
			GameRules:GetGameModeEntity():SetContextThink(DoUniqueString("anti_anti_stacks_fucker"), function()
				if PARTIES_ALLOWED == false then
					GameRules:SetCustomGameSetupRemainingTime(self.start_time * 2)
				end

				return nil
			end, self.start_time * 2)

			return nil
		end, 3.0)
	else
		if PARTIES_ALLOWED == false then
			GameRules:SetCustomGameSetupRemainingTime(self.start_time)
		end
	end
end

-- core
function TeamOrdering:ComputeTeamSelection()
--	print("ComputeTeamSelection()")
	local n = PlayerResource:GetPlayerCount()
	local k = PlayerResource:GetPlayerCountForTeam(DOTA_TEAM_GOODGUYS)
	local acceptableWinratesDifference = 1 -- for 10v10 only

	local halfCombinationsNumber = 126 -- generations number is n!/((n-k)!*k!)
--	local winratesBaseArray = {81.0, 77.0, 74.2, 65.1, 54.2, 53.2, 49.9, 43.3, 41.2, 32.8, 41.0, 71.0, 72.2, 62.1, 24.2, 33.2, 19.9, 63.3, 71.2, 92.8}

	if GetMapName() == "imba_10v10" then
		halfCombinationsNumber = 92378
	end

	-- not tested yet
--	if IsInToolsMode() then
--		for i = 0, n - 1 do
--			self.winrates[i] = winratesBaseArray[i + 1]
--		end
--	else
		for i = 0, PlayerResource:GetPlayerCount() - 1 do
			if PlayerResource:IsValidPlayer(i) then
				if api:GetPlayerXPLevel(i) <= self.minimum_level_to_reorder then
					self.winrates[i] = self.fixed_winrate_for_rookies
--					print("Rookie player! Player ID/Name/Winrate:", i, PlayerResource:GetPlayerName(i), self.fixed_winrate_for_rookies)
				else
					local seasonal_winrate = api:GetPlayerSeasonalWinrate(i)
					-- if calibrated
					if type(seasonal_winrate) == "number" then
						self.winrates[i] = seasonal_winrate or 50.00042 -- specific value to notice when winrate couldn't be gathered
--						print("Player ID/Name/Winrate:", i, PlayerResource:GetPlayerName(i), seasonal_winrate)
					else
						self.winrates[i] = api:GetPlayerWinrate(i)
					end
				end
			end
		end
--	end

	if IsInToolsMode() then
		print(self.winrates)
	end

	local combination = {}

	for i = 0, k - 1 do
		combination[i] = i
	end

	combination[k] = n

	local winratesDifference = nil
	local smallestWinratesDifference = 100 * k -- highest winrates difference possible

	local bestTeamAOrdering = {}
	local bestTeamBOrdering = {}

	for i = 0, halfCombinationsNumber - 1 do
		-- start of operations with combination

		local oppositeCombination = {}

		for j = 0, n - 1 do
			oppositeCombination[j] = j
		end

		oppositeCombination = TableSubtract(oppositeCombination, combination)

		local teamA = CopyArray(combination, k)
		local teamB = CopyArray(oppositeCombination, k)

		winratesDifference = self:CalculateWinratesDifference(teamA, teamB)

		if GetMapName() == "imba_10v10" and winratesDifference < acceptableWinratesDifference then
			smallestWinratesDifference = winratesDifference
			bestTeamAOrdering = CopyArray(teamA, k)
			bestTeamBOrdering = CopyArray(teamB, k)
			break
		end

		if winratesDifference then
--			print("Winrate Diffs:", winratesDifference, smallestWinratesDifference)
			if winratesDifference < smallestWinratesDifference then
				smallestWinratesDifference = winratesDifference
				bestTeamAOrdering = CopyArray(teamA, k)
				bestTeamBOrdering = CopyArray(teamB, k)
			end
		end

		-- end of operations with combination
		local jKeeper = 0

		for j = 0, k do
			jKeeper = j

			if combination[j] + 1 and combination[j + 1] and combination[j] + 1 == combination[j + 1] then
				combination[j] = j
			else
				break
			end
		end

		if jKeeper < k then
			combination[jKeeper] = combination[jKeeper] + 1
		else
			break
		end
	end

--	print("Radiant comp:", bestTeamAOrdering)
--	print("Dire comp:", bestTeamBOrdering)
	self.Radiant = bestTeamAOrdering
	self.Dire = bestTeamBOrdering

	-- Call it here to show team comp to players
	self:SetTeams_PostCompute()
end

function TeamOrdering:CalculateWinratesDifference(teamA, teamB)
	local winrateTeamA = 0
	local winrateTeamB = 0

	for _, playerAIndex in pairs(teamA) do
		if self.winrates[playerAIndex] and type(self.winrates[playerAIndex]) == "number" then
			winrateTeamA = winrateTeamA + self.winrates[playerAIndex]
		end
	end

	for _, playerBIndex in pairs(teamB) do
		if self.winrates[playerBIndex] and type(self.winrates[playerBIndex]) == "number" then
			winrateTeamB = winrateTeamB + self.winrates[playerBIndex]
		end
	end

	-- Say(nil, "Winrate difference between teams: "..math.abs(winrateTeamA - winrateTeamB), false)

	return math.abs(winrateTeamA - winrateTeamB)
end

-- hRadiant and hDire should return both an array of player id's
function TeamOrdering:SetTeams_PostCompute(hRadiant, hDire)
	print("SetTeams_PostCompute():", hRadiant, hDire)

	-- unassign players
	for i = 0, 24 do
		self:SetPlayerTeam(i, DOTA_TEAM_NOTEAM)
	end

	for k, v in pairs(self.Radiant or {}) do
		self:SetPlayerTeam(v, DOTA_TEAM_GOODGUYS)
	end

	for k, v in pairs(self.Dire or {}) do
		self:SetPlayerTeam(v, DOTA_TEAM_BADGUYS)
	end

	if PARTIES_ALLOWED == false then
		GameRules:SetCustomGameSetupRemainingTime(self.start_time)
	end
end

function TeamOrdering:OnPlayerReconnect(iPlayerID)
	local player_team_set = false

	for k, v in pairs(self.Radiant or {}) do
		if v == iPlayerID then
			self:SetPlayerTeam(v, DOTA_TEAM_GOODGUYS)
			player_team_set = true
			break
		end
	end

	if player_team_set == false then
		for k, v in pairs(self.Dire or {}) do
			if v == iPlayerID then
				self:SetPlayerTeam(v, DOTA_TEAM_BADGUYS)
				break
			end
		end
	end
end

function TeamOrdering:SetPlayerTeam(iPlayerID, iTeam)
	if not iPlayerID or not PlayerResource:IsValidPlayer(iPlayerID) then
		print("ERROR: INVALID PLAYER TO SET TEAM!")
		return
	end

	if not iTeam then
		print("EEROR: INVALID TEAM TO SET PLAYER!")
		return
	end

	local player = PlayerResource:GetPlayer(iPlayerID)

	player:SetTeam(iTeam)

	if PlayerResource.GetSelectedHeroEntity and PlayerResource:GetSelectedHeroEntity(iPlayerID) then
		PlayerResource:GetSelectedHeroEntity(iPlayerID):SetTeam(iTeam)
	end

	PlayerResource:SetCustomTeamAssignment(iPlayerID, iTeam)
end