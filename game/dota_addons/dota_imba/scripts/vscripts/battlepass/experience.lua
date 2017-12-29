-- Experience System
CustomNetTables:SetTableValue("game_options", "game_count", {value = 0})
XP_level_table = {0,100,200,300,400,500,700,900,1100,1300,1500,1800,2100,2400,2700,3000,3400,3800,4200,4600,5000}
--------------    0  1   2   3   4   5   6   7    8    9   10   11   12   13   14   15   16   17   18   19   20

local bonus = 0
for i = 21 +1, 500 do
	bonus = bonus +25
	XP_level_table[i] = XP_level_table[i-1] + 500 + bonus
end

function GetXPLevelByXp(xp)
	if xp <= 0 then return 0 end

	for k, v in pairs(XP_level_table) do
		if v > xp then
			return k - 1
		end
	end
	return 500
end

function GetXpProgressToNextLevel(xp)
	local level = GetXPLevelByXp(xp)
	local next = level + 1
	local thisXp = XP_level_table[level]
	local nextXp = XP_level_table[next]

	local xpRequiredForThisLevel = nextXp - thisXp
	local xpProgressInThisLevel = xp - thisXp

	return xpProgressInThisLevel / xpRequiredForThisLevel
end

function GetTitleIXP(level)
	if level <= 19 then
		return "Rookie"
	elseif level <= 39 then
		return "Amateur"
	elseif level <= 59 then
		return "Captain"
	elseif level <= 79 then
		return "Warrior"
	elseif level <= 99 then
		return "Commander"
	elseif level <= 119 then
		return "General"
	elseif level <= 139 then
		return "Master"
	elseif level <= 159 then
		return "Epic"
	elseif level <= 179 then
		return "Legendary"
	elseif level <= 199 then
		return "Ancient"
	elseif level <= 299 then
		return "Amphibian "..level-200
	elseif level <= 399 then
		return "Icefrog "..level-300
	else 
		return "Firetoad "..level-400
	end
end

function GetTitleColorIXP(title, js)
	if js == true then
		if title == "Rookie" then
			return "#FFFFFF"
		elseif title == "Amateur" then
			return "#66CC00"
		elseif title == "Captain" then
			return "#4C8BCA"
		elseif title == "Warrior" then
			return "#004C99"
		elseif title == "Commander" then
			return "#985FD1"
		elseif title == "General" then
			return "#460587"
		elseif title == "Master" then
			return "#FA5353"
		elseif title == "Epic" then
			return "#8E0C0C"
		elseif title == "Legendary" then
			return "#EFBC14"
		elseif title == "Ancient" then
			return "#BF950D"
		elseif title == "Amphibian" then
			return "#000066"
		elseif title == "Icefrog" then
			return "#1456EF"
		else -- it's Firetoaaaaaaaaaaad! 
			return "#C75102"
		end
	else
		if title == "Rookie" then
			return {255, 255, 255}
		elseif title == "Amateur" then
			return {102, 204, 0}
		elseif title == "Captain" then
			return {76, 139, 202}
		elseif title == "Warrior" then
			return {0, 76, 153}
		elseif title == "Commander" then
			return {152, 95, 209}
		elseif title == "General" then
			return {70, 5, 135}
		elseif title == "Master" then
			return {250, 83, 83}
		elseif title == "Epic" then
			return {142, 12, 12}
		elseif title == "Legendary" then
			return {239, 188, 20}
		elseif title == "Ancient" then
			return {191, 149, 13}
		elseif title == "Amphibian" then
			return {0, 0, 102}
		elseif title == "Icefrog" then
			return {20, 86, 239}
		else -- it's Firetoaaaaaaaaaaad! 
			return {199, 81, 2}
		end
	end
end

function CountGameIXP()
	if CHEAT_ENABLED == true then
		print("CHEATS: Game will not record xp.")
		return
	else
		Timers:CreateTimer(GAME_COUNT_DELAY, function()
			CustomNetTables:SetTableValue("game_options", "game_count", {value = 1})
		end)
	end
end

function GetPlayerInfoIXP() -- yet it has too much useless loops, format later
if api_preloaded.players == nil then return end
local level = {}
local current_xp_in_level = {}
local max_xp = {}

	for ID = 0, PlayerResource:GetPlayerCount() -1 do
		local global_xp = GetStatsForPlayer(ID).xp
		level[ID] = 0

		for i = 1, #XP_level_table do
			if global_xp > XP_level_table[i] then
				if global_xp > XP_level_table[#XP_level_table] then -- if max level
					level[ID] = #XP_level_table
					current_xp_in_level[ID] = XP_level_table[level[ID]] - XP_level_table[level[ID]-1]
					max_xp[ID] = XP_level_table[level[ID]] - XP_level_table[level[ID]-1]
				else
					level[ID] = i
					current_xp_in_level[ID] = 0
					current_xp_in_level[ID] = global_xp - XP_level_table[i]
					max_xp[ID] = XP_level_table[level[ID]+1] - XP_level_table[level[ID]]
				end
			end
		end

		CustomNetTables:SetTableValue("player_table", tostring(ID),
		{
			XP = current_xp_in_level[ID],
			MaxXP = max_xp[ID],
			Lvl = level[ID], -- add +1 only on the HUD else you are level 0 at the first level
			title = GetTitleIXP(level[ID]),
			title_color = GetTitleColorIXP(GetTitleIXP(level[ID]), true),
			IMR_5v5 = GetStatsForPlayer(ID).imr_5v5,
			IMR_10v10 = GetStatsForPlayer(ID).imr_10v10,
			XP_change = 0,
			IMR_5v5_change = 0,
		})
	end
	GetTopPlayersIXP()
	GetTopPlayersIMR()
end

function GetTopPlayersIXP()
if api_preloaded.topxpusers == nil then return end
local level = {}
local current_xp_in_level = {}
local max_xp = {}

	for _, top_user in pairs(api_preloaded.topxpusers) do
		local global_xp = top_user.xp
		level[top_user.rank] = 0

		for i = 1, #XP_level_table do
			if global_xp > XP_level_table[i] then
				if global_xp > XP_level_table[#XP_level_table] then -- if max level
					level[top_user.rank] = #XP_level_table
					current_xp_in_level[top_user.rank] = XP_level_table[level[top_user.rank]] - XP_level_table[level[top_user.rank]]
					max_xp[top_user.rank] = XP_level_table[level[top_user.rank]] - XP_level_table[level[top_user.rank]]
				else
					level[top_user.rank] = i +1
					current_xp_in_level[top_user.rank] = 0
					current_xp_in_level[top_user.rank] = global_xp - XP_level_table[i]
					max_xp[top_user.rank] = XP_level_table[level[top_user.rank]+1] - XP_level_table[level[top_user.rank]]
				end
			end
		end

		CustomNetTables:SetTableValue("top_xp", tostring(top_user.rank),
		{
			SteamID64 = top_user.steamid,
			XP = current_xp_in_level[top_user.rank],
			MaxXP = max_xp[top_user.rank],
			Lvl = level[top_user.rank],
			title = GetTitleIXP(level[top_user.rank]),
			title_color = GetTitleColorIXP(GetTitleIXP(level[top_user.rank]), true),
			IMR_5v5 = top_user.imr_5v5,
		})
	end
end

function GetTopPlayersIMR()
if api_preloaded.topimrusers == nil then return end
local level = {}
local current_xp_in_level = {}
local max_xp = {}

	for _, top_user in pairs(api_preloaded.topimrusers) do
		local global_xp = top_user.xp
		level[top_user.rank] = 0

		for i = 1, #XP_level_table do
			if global_xp > XP_level_table[i] then
				if global_xp > XP_level_table[#XP_level_table] then -- if max level
					level[top_user.rank] = #XP_level_table
					current_xp_in_level[top_user.rank] = XP_level_table[level[top_user.rank]] - XP_level_table[level[top_user.rank]]
					max_xp[top_user.rank] = XP_level_table[level[top_user.rank]] - XP_level_table[level[top_user.rank]]
				else
					level[top_user.rank] = i +1 -- transform level 0 into level 1
					current_xp_in_level[top_user.rank] = 0
					current_xp_in_level[top_user.rank] = global_xp - XP_level_table[i]
					max_xp[top_user.rank] = XP_level_table[level[top_user.rank]+1] - XP_level_table[level[top_user.rank]]
				end
			end
		end

		CustomNetTables:SetTableValue("top_imr_5v5", tostring(top_user.rank),
		{
			SteamID64 = top_user.steamid,
			XP = current_xp_in_level[top_user.rank],
			MaxXP = max_xp[top_user.rank],
			Lvl = level[top_user.rank],
			title = GetTitleIXP(level[top_user.rank]),
			title_color = GetTitleColorIXP(GetTitleIXP(level[top_user.rank]), true),
			IMR_5v5 = top_user.imr_5v5,
		})
	end
end
