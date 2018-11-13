if GameMode == nil then
	_G.GameMode = class({})
end

-- clientside KV loading
require('addon_init')

-- require('libraries/adv_log')
require('libraries/animations')
require('libraries/keyvalues')
require('libraries/modifiers')
require('libraries/notifications')
require('libraries/player')
require('libraries/player_resource')
require('libraries/projectiles')
require('libraries/rgb_to_hex')
require('libraries/timers')
require('libraries/wearables')

require('internal/gamemode')
require('internal/events')

-- add components below the api
require('components/api/imba')

require('components/abandon')
require('components/battlepass/donator')
require('components/battlepass/experience')
require('components/battlepass/imbattlepass')
require('components/courier/abilities')
require('components/courier/courier')
require('components/gold')
require('components/hero_selection/init')
if IsMutationMap() then
	require('components/mutation/mutation')
end
require('components/runes')
require('components/settings/settings')
require('components/team_selection')

require('events/events')
require('filters')

-- A*-Path-finding logic (RIKI NEEDS THIS FOR HIS BLINK STRIKE)
require('libraries/astar')

-- Use this function as much as possible over the regular Precache (this is Async Precache)
function GameMode:PostLoadPrecache()

end

function GameMode:OnFirstPlayerLoaded()
--	Log:ConfigureFromApi()
--	api.imba.register()

	if GetMapName() ~= Map1v1() and GetMapName() ~= MapOverthrow() then
		_G.ROSHAN_SPAWN_LOC = Entities:FindByClassname(nil, "npc_dota_roshan_spawner"):GetAbsOrigin()
		Entities:FindByClassname(nil, "npc_dota_roshan_spawner"):RemoveSelf()
		if GetMapName() ~= Map1v1() then
			if IMBA_DIRETIDE == true then
				ROSHAN_ENT = CreateUnitByName("npc_diretide_roshan", _G.ROSHAN_SPAWN_LOC, true, nil, nil, DOTA_TEAM_NEUTRALS)
			else
				if IMBA_DIRETIDE_EASTER_EGG == true then
					local easter_egg = CreateUnitByName("npc_dota_diretide_easter_egg", _G.ROSHAN_SPAWN_LOC, true, nil, nil, DOTA_TEAM_NEUTRALS)
					easter_egg:AddNewModifier(easter_egg, nil, "modifier_npc_dialog", {})
				else
					local roshan = CreateUnitByName("npc_dota_roshan", _G.ROSHAN_SPAWN_LOC, true, nil, nil, DOTA_TEAM_NEUTRALS)
					roshan:AddNewModifier(roshan, nil, "modifier_imba_roshan_ai", {})
				end
			end
		end
	end
end

function GameMode:OnAllPlayersLoaded()
	-- Setup filters
--	GameRules:GetGameModeEntity():SetHealingFilter( Dynamic_Wrap(GameMode, "HealingFilter"), self )
	GameRules:GetGameModeEntity():SetExecuteOrderFilter( Dynamic_Wrap(GameMode, "OrderFilter"), self )
	GameRules:GetGameModeEntity():SetDamageFilter( Dynamic_Wrap(GameMode, "DamageFilter"), self )
	GameRules:GetGameModeEntity():SetModifyGoldFilter( Dynamic_Wrap(GameMode, "GoldFilter"), self )
	GameRules:GetGameModeEntity():SetModifyExperienceFilter( Dynamic_Wrap(GameMode, "ExperienceFilter"), self )
	GameRules:GetGameModeEntity():SetModifierGainedFilter( Dynamic_Wrap(GameMode, "ModifierFilter"), self )
	GameRules:GetGameModeEntity():SetItemAddedToInventoryFilter( Dynamic_Wrap(GameMode, "ItemAddedFilter"), self )
	GameRules:GetGameModeEntity():SetBountyRunePickupFilter(Dynamic_Wrap(GameMode, "BountyRuneFilter"), self)
	GameRules:GetGameModeEntity():SetThink( "OnThink", self, 1 )
	GameRules:GetGameModeEntity():SetPauseEnabled(false)
end

-- CAREFUL, FOR REASONS THIS FUNCTION IS ALWAYS CALLED TWICE
function GameMode:InitGameMode()
	self:_InitGameMode()
end

function GameMode:DonatorCompanionJS(event)
	DonatorCompanion(event.ID, event.unit, event.js)
end

function GameMode:DonatorCompanionSkinJS(event)
	DonatorCompanionSkin(event.ID, event.unit, event.skin)
end

-- Set up fountain regen
function GameMode:SetUpFountains()

	local fountainEntities = Entities:FindAllByClassname("ent_dota_fountain")
	for _,fountainEnt in pairs( fountainEntities ) do
		fountainEnt:AddNewModifier( fountainEnt, fountainEnt, "modifier_fountain_aura_lua", {} )
		fountainEnt:AddAbility("imba_fountain_danger_zone"):SetLevel(1)

		-- remove vanilla fountain healing
		if fountainEnt:HasModifier("modifier_fountain_aura") then
			fountainEnt:RemoveModifierByName("modifier_fountain_aura")
			fountainEnt:AddNewModifier(fountainEnt, nil, "modifier_fountain_aura_lua", {})
		end
	end
end

function GameMode:BountyRuneFilter(keys)
	local hero = PlayerResource:GetPlayer(keys.player_id_const):GetAssignedHero()

	if hero:GetUnitName() == "npc_dota_hero_alchemist" then 
		local alchemy_bounty = 0
		if hero:FindAbilityByName("imba_alchemist_goblins_greed") and hero:FindAbilityByName("imba_alchemist_goblins_greed"):GetLevel() > 0 then
			alchemy_bounty = keys.gold_bounty * (hero:FindAbilityByName("imba_alchemist_goblins_greed"):GetSpecialValueFor("bounty_multiplier") / 100)

			-- #7 Talent: Moar gold from bounty runes
			if hero:HasTalent("special_bonus_imba_alchemist_7") then
				alchemy_bounty = (alchemy_bounty * (hero:FindTalentValue("special_bonus_imba_alchemist_7") / 100)) - keys.gold_bounty
			end		

			hero:ModifyGold(alchemy_bounty, false, DOTA_ModifyGold_Unspecified)
			SendOverheadEventMessage(PlayerResource:GetPlayer(hero:GetPlayerOwnerID()), OVERHEAD_ALERT_GOLD, hero, alchemy_bounty, nil)
		end
	end

	local custom_gold_bonus = tonumber(CustomNetTables:GetTableValue("game_options", "bounty_multiplier")["1"])
	local custom_xp_bonus = tonumber(CustomNetTables:GetTableValue("game_options", "exp_multiplier")["1"])

	keys.gold_bounty = keys.gold_bounty * (custom_gold_bonus / 100)
	keys.xp_bounty = keys.xp_bounty * (custom_xp_bonus / 100)

	return true
end
