local UNIQUE_FISH_NEEDED = 16
local REGISTERED_FIND_DECOR_TAGS
local PearlDecorationScore = Class(function(self, inst)
    self.inst = inst
    --
    self.enabled = false

    self.score = 0
    self.tile_score = 0
    self.scoring_radius = nil

    self.tiles_num = TUNING.HERMITCRAB_DECOR_MAX_TILE_SPACE
    self.tiles = nil
    self.cached_coords = { x = - 1, z = - 1 }
    --
    self.force_update = true
    self.update_time = TUNING.HERMITCRAB_DECOR_UPDATE_TIME
    --
    self.tile_scores =
    {
        [WORLD_TILES.SHELLBEACH]    = TUNING.HERMITCRAB_DECOR_TILE_SCORE, -- 100 tiles = 15 points
        [WORLD_TILES.MONKEY_GROUND] = TUNING.HERMITCRAB_DECOR_TILE_SCORE_LOW, -- 100 tiles = 10 points
        [WORLD_TILES.PEBBLEBEACH]   = TUNING.HERMITCRAB_DECOR_TILE_SCORE_LOW, -- 100 tiles = 10 points
    }
    self.tile_scores_count = {}

    self._cache_watertree_coverage = {}

    -- resets every update
    self.unique_decor_scored = {}
    self.unique_trophy_fish = {}
    --

    self.decor_data =
    {
        [PEARL_DECORATION_TYPES.UNIQUE_DECORATION] = {  },
        [PEARL_DECORATION_TYPES.WATER_TREE] = { max_score = TUNING.HERMITCRAB_DECOR_WATER_TREE_SCORE_MAX, },
        [PEARL_DECORATION_TYPES.CRITTER_PET] = {  },
        [PEARL_DECORATION_TYPES.BEE_BOXES] = { max_score = TUNING.HERMITCRAB_DECOR_BEEBOX_SCORE_MAX },
        [PEARL_DECORATION_TYPES.FLOWERS] = { max_score = TUNING.HERMITCRAB_DECOR_FLOWER_SCORE_MAX },
        [PEARL_DECORATION_TYPES.TILES] = { max_score = TUNING.HERMITCRAB_DECOR_TILE_SCORE_MAX },
        [PEARL_DECORATION_TYPES.LVL5_HOUSE] = {  },
        [PEARL_DECORATION_TYPES.LIGHT_POSTS] = { max_score = TUNING.HERMITCRAB_DECOR_LIGHTPOST_SCORE_MAX },
        [PEARL_DECORATION_TYPES.MEAT_RACKS] = { max_score = TUNING.HERMITCRAB_DECOR_MEAT_RACK_SCORE_MAX },
        [PEARL_DECORATION_TYPES.PICKABLE_PLANTS] = { max_score = TUNING.HERMITCRAB_DECOR_PICKABLE_SCORE_MAX },
        [PEARL_DECORATION_TYPES.ORNAMENTS] = { },
        [PEARL_DECORATION_TYPES.FACED_CHAIR] = { max_score = TUNING.HERMITCRAB_DECOR_CHAIR_SCORE_MAX },
        [PEARL_DECORATION_TYPES.TROPHY_FISH] = { },
        [PEARL_DECORATION_TYPES.POTTED_PLANTS] = { max_score = TUNING.HERMITCRAB_DECOR_POTTEDPLANT_SCORE_MAX },
        [PEARL_DECORATION_TYPES.DOCK_POSTS] = { max_score = TUNING.HERMITCRAB_DECOR_DOCKPOST_SCORE_MAX },
        [PEARL_DECORATION_TYPES.DECORATION_TAKER] = { max_score = TUNING.HERMITCRAB_DECOR_TABLE_SCORE_MAX },
        [PEARL_DECORATION_TYPES.FISHING_MARKERS] = { min_score = TUNING.HERMITCRAB_DECOR_FISHING_BLOCKED_SCORE_MIN },
        [PEARL_DECORATION_TYPES.SPAWNER] = { min_score = TUNING.HERMITCRAB_DECOR_SPAWNER_SCORE_MIN },
        [PEARL_DECORATION_TYPES.JUNK] = { min_score = TUNING.HERMITCRAB_DECOR_JUNK_SCORE_MIN },
    }
    self.last_decor_scores = {}
    for decor_key in pairs(self.decor_data) do
        self.last_decor_scores[decor_key] = 0
    end

    self.decor_fns =
    {
        {
            key = PEARL_DECORATION_TYPES.UNIQUE_DECORATION,
            fn = function(ent)
                if self:IsEntityUniqueDecor(ent) then
                    if self.unique_decor_scored[ent.prefab] then
                        return 0 -- In order to not go down the list any further.
                    end
                    self.unique_decor_scored[ent.prefab] = true
                    return TUNING.HERMITCRAB_DECOR_UNIQUE_BOOSTS[ent.prefab]
                end
            end,
        },

        {
            key = PEARL_DECORATION_TYPES.FLOWERS,
            fn = function(ent)
                if self:IsEntityFlower(ent) then
                    return TUNING.HERMITCRAB_DECOR_FLOWER_SCORE
                end
            end,
        },

        {
            key = PEARL_DECORATION_TYPES.BEE_BOXES,
            fn = function(ent)
                if self:IsEntityBeeBox(ent) then
                    return TUNING.HERMITCRAB_DECOR_BEEBOX_SCORE
                end
            end,
        },

        {
            key = PEARL_DECORATION_TYPES.LIGHT_POSTS,
            fn = function(ent)
                if self:IsEntityLightPost(ent) then
                    return ent.Light:IsEnabled() and TUNING.HERMITCRAB_DECOR_LIGHTPOST_ON_SCORE
                        or TUNING.HERMITCRAB_DECOR_LIGHTPOST_SCORE
                end
            end,
        },

        {
            key = PEARL_DECORATION_TYPES.PICKABLE_PLANTS,
            fn = function(ent)
                if self:IsEntityPickableBush(ent) then
                    return TUNING.HERMITCRAB_DECOR_PICKABLE_SCORE
                end
            end,
        },

        {
            key = PEARL_DECORATION_TYPES.MEAT_RACKS,
            fn = function(ent)
                if self:IsEntityMeatRack(ent) then
                    return ent.components.container.numslots * TUNING.HERMITCRAB_DECOR_MEAT_RACK_SCORE
                end
            end,
        },

        {
            key = PEARL_DECORATION_TYPES.FACED_CHAIR,
            fn = function(ent)
                if self:IsEntityFacedChair(ent) then
                    return TUNING.HERMITCRAB_DECOR_CHAIR_SCORE
                end
            end,
        },

        {
            key = PEARL_DECORATION_TYPES.TROPHY_FISH,
            fn = function(ent)
                if self:IsEntityTrophyFish(ent) then
                    local item_data = ent.components.trophyscale:GetItemData()
                    if item_data then
                        local trophy_score = item_data.weight * TUNING.HERMITCRAB_DECOR_TROPHY_SCALE_FISH_SCORE
                        if not self.unique_trophy_fish[item_data.prefab] or trophy_score > self.unique_trophy_fish[item_data.prefab] then
                            self.unique_trophy_fish[item_data.prefab] = trophy_score
                            return trophy_score
                        end
                    end

                    return 0
                end
            end,
        },

        {
            key = PEARL_DECORATION_TYPES.POTTED_PLANTS,
            fn = function(ent)
                if self:IsEntityPottedPlant(ent) then
                    return TUNING.HERMITCRAB_DECOR_POTTEDPLANT_SCORE
                end
            end,
        },

        {
            key = PEARL_DECORATION_TYPES.DOCK_POSTS,
            fn = function(ent)
                if self:IsEntityDockPost(ent) then
                    return TUNING.HERMITCRAB_DECOR_DOCKPOST_SCORE
                end
            end,
        },

        {
            key = PEARL_DECORATION_TYPES.DECORATION_TAKER,
            fn = function(ent)
                if self:IsEntityDecorTaker(ent) then
                    local furnituredecortaker = ent.components.furnituredecortaker
                    return furnituredecortaker.decor_item and TUNING.HERMITCRAB_DECOR_TABLE_ITEM_SCORE
                        or TUNING.HERMITCRAB_DECOR_TABLE_SCORE
                end
            end,
        },

        {
            key = PEARL_DECORATION_TYPES.SPAWNER,
            fn = function(ent)
                if self:IsEntitySpawner(ent) then
                    return ent:HasTag("grave") and TUNING.HERMITCRAB_DECOR_SPAWNER_SCORE_GRAVE
                        or TUNING.HERMITCRAB_DECOR_SPAWNER_SCORE
                end
            end,
        },

        {
            key = PEARL_DECORATION_TYPES.JUNK,
            fn = function(ent)
                if self:IsEntityJunk(ent) then
                    return TUNING.HERMITCRAB_DECOR_JUNK_SCORE
                end
            end,
        },
    }
end)

function PearlDecorationScore:IsEnabled()
	return self.enabled
end

function PearlDecorationScore:Enable(on_load)
    if self.enabled then
        return
    end

    self.enabled = true
    self.inst:StartUpdatingComponent(self)

    -- Initialize tags
    if REGISTERED_FIND_DECOR_TAGS == nil then
        REGISTERED_FIND_DECOR_TAGS = TheSim:RegisterFindTags(
            { },
            { "FX", "DECOR", "NOCLICK", "INLIMBO", "player", "outofreach" },
            -- TODO exclude creatures?
            { "inspectable", "dock_woodpost" }
        )
    end

    if self._onterraform == nil then
        self._onterraform = function(_, data)
            local x, y, original_tile, new_tile = data.x, data.y, data.original_tile, data.tile
            if original_tile ~= new_tile then
                if self.tile_scores[original_tile] then
                    if self.tile_scores_count[original_tile] then
                        local newcount = self.tile_scores_count[original_tile] - 1
                        if newcount <= 0 then
                            self.tile_scores_count[original_tile] = nil
                        else
                            self.tile_scores_count[original_tile] = newcount
                        end
                    end
                end

                if self.tile_scores[new_tile] then
                    self.tile_scores_count[new_tile] = (self.tile_scores_count[new_tile] or 0) + 1
                end
            end
        end
        self.inst:ListenForEvent("onterraform", self._onterraform, TheWorld)
    end

    if self._onrelocated == nil then
        self._onrelocated = function(_)
            self._cache_watertree_coverage = {}
            self:ForceUpdate()
        end
        self.inst:ListenForEvent("ms_hermitcrab_relocated", self._onrelocated, TheWorld)
        self.inst:ListenForEvent("teleported", self._onrelocated)
        self.inst:ListenForEvent("teleport_move", self._onrelocated)
    end

    if not on_load then
        self:ForceUpdate()
        self:OnUpdate(0)
        TheWorld:PushEvent("pearldecorationscore_updatestatus")
    else
        self:UpdateOccupiedGrid()
    end
end

function PearlDecorationScore:Disable()
    if not self.enabled then
        return
    end

    self.enabled = false
    self.inst:StopUpdatingComponent(self)

    if self._onterraform ~= nil then
        self.inst:RemoveEventCallback("onterraform", self._onterraform, TheWorld)
        self._onterraform = nil
    end

    if self._onrelocated ~= nil then
        self.inst:RemoveEventCallback("ms_hermitcrab_relocated", self._onrelocated, TheWorld)
        self.inst:RemoveEventCallback("teleported", self._onrelocated)
        self.inst:RemoveEventCallback("teleport_move", self._onrelocated)
        self._onrelocated = nil
    end

    self:ForceUpdate()

    TheWorld:PushEvent("pearldecorationscore_updatestatus")
end

function PearlDecorationScore:ForceUpdate()
    self.force_update = true
end

local HALF_DIAGONAL = (TILE_SCALE * SQRT2) / 2 -- Extra padding
function PearlDecorationScore:UpdateScoringRadius_Internal()
    -- Grab average middle tile
    local tile_count = 0

    local tx, ty = 0, 0
    for index in pairs(self.tiles.grid) do
        local x, y = self.tiles:GetXYFromIndex(index)
        tx = tx + x
        ty = ty + y
        tile_count = tile_count + 1
    end

    tx, ty = math.floor(tx / tile_count), math.floor(ty / tile_count)
    -- Find farthest tile
    local x, y, z = TheWorld.Map:GetTileCenterPoint(tx, ty)
    local maxdsq = -1
    for index in pairs(self.tiles.grid) do
        local gx, gy, gz = TheWorld.Map:GetTileCenterPoint(self.tiles:GetXYFromIndex(index))
        local dsq = distsq(x, z, gx, gz)
	    if dsq > maxdsq then
	    	maxdsq = dsq
	    end
    end
    -- Now set the radius, and add padding.
    self.scoring_radius = math.sqrt(maxdsq) + HALF_DIAGONAL
end
function PearlDecorationScore:UpdateOccupiedGrid()
    local x, y, z = self.inst.Transform:GetWorldPosition()
    local tx, tz = TheWorld.Map:GetTileCoordsAtPoint(x, y, z)

    if self.cached_coords.x ~= tx or self.cached_coords.z ~= tz then
        self.cached_coords.x = tx
        self.cached_coords.z = tz
        self.tiles = GetHermitCrabOccupiedGrid(tx, tz)
        self.tile_scores_count = {}
        for index in pairs(self.tiles.grid) do
            local x, y = self.tiles:GetXYFromIndex(index)
            local tile = TheWorld.Map:GetTile(x, y)
            if self.tile_scores[tile] then
                self.tile_scores_count[tile] = (self.tile_scores_count[tile] or 0) + 1
            end
        end
        --
        TheWorld:PushEvent("ms_updatepearldecorationscore_tiles")
        --
        self:UpdateScoringRadius_Internal()
    end
end

function PearlDecorationScore:UpdateTileScore()
    local tile_score = 0
    --
    for tile, count in pairs(self.tile_scores_count) do
        tile_score = tile_score + (self.tile_scores[tile] * count)
    end
    --
    self.tile_score = tile_score
end

local WATER_TREE_TILE_RANGE = 5 -- We could use canopyshadows.range, but it's dangerous to use a visual component's value for gameplay logic.
function PearlDecorationScore:GetWaterTreeNumTileCoverage(ent)
    if self._cache_watertree_coverage[ent] == nil then
        local tx, ty = TheWorld.Map:GetTileCoordsAtPoint(ent.Transform:GetWorldPosition())
        local coverage = 0

        for off_x = -WATER_TREE_TILE_RANGE, WATER_TREE_TILE_RANGE do
            for off_y = -WATER_TREE_TILE_RANGE, WATER_TREE_TILE_RANGE do
                if self:IsPointWithin(TheWorld.Map:GetTileCenterPoint(tx + off_x, ty + off_y)) then
                    coverage = coverage + 1
                end
            end
        end

        self._cache_watertree_coverage[ent] = coverage
    end

    return self._cache_watertree_coverage[ent]
end
function PearlDecorationScore:IsEntityWaterTree(ent)
    return ent:HasAnyTag("shadecanopysmall", "shadecanopy")
end
function PearlDecorationScore:IsEntityFlower(ent)
    return ent:HasTag("flower")
end
function PearlDecorationScore:IsEntityBeeBox(ent)
    return ent:HasTag("beebox") and ent.components.workable ~= nil -- Count only built bee boxes, not our inherent one
end
function PearlDecorationScore:IsEntityLightPost(ent)
    return ent:HasTag("hermitcrab_lantern_post") and not ent:HasTag("abandoned")
end
function PearlDecorationScore:IsEntityPickableBush(ent)
    local pickable = ent.components.pickable
    return pickable ~= nil and not pickable.remove_when_picked and ent:HasTag("plant") and not ent:HasTag("thorny")
end
function PearlDecorationScore:IsEntityMeatRack(ent)
    return ent.components.dryingrack ~= nil and not ent:HasTag("abandoned") and ent.components.workable ~= nil -- Count built meat racks.
end
function PearlDecorationScore:IsEntityFacedChair(ent)
    return ent:HasAnyTag("faced_chair", "rocking_chair")
end
function PearlDecorationScore:IsEntityTrophyFish(ent)
    return ent.components.trophyscale and ent.components.trophyscale.type == TROPHYSCALE_TYPES.FISH
end
function PearlDecorationScore:IsEntityPottedPlant(ent)
    return ent:HasTag("pottedplant")
end
function PearlDecorationScore:IsEntityDockPost(ent)
    return ent:HasTag("dock_woodpost")
end
function PearlDecorationScore:IsEntityDecorTaker(ent)
    return ent.components.furnituredecortaker ~= nil
end
local JUNK_ONEOF_TAGS = { "junk_pile", "_inventoryitem", "heavy" }
local JUNK_CANT_TAGS = { "singingshell", "frozen", "vase", "INLIMBO", "farm_plant_killjoy" }
function PearlDecorationScore:IsEntityJunk(ent)
    local furnituredecor = ent.components.furnituredecor
    if furnituredecor and furnituredecor.on_furniture then
        return false
    end

    if ent.brain then -- This is a creature, ignore it, we take it into account elsewhere.
        return false
    end

    return ent:HasAnyTag(JUNK_ONEOF_TAGS) and not ent:HasAnyTag(JUNK_CANT_TAGS)
end
local EXCLUDE_CHILDSPAWNER_TAGS = { "beebox", "catcoonden", "oceanshoalspawner", "_equippable" } -- These are okay to have around Pearl
function PearlDecorationScore:IsEntitySpawner(ent)
    return (ent.components.childspawner or ent.components.spawner)
        and not ent:HasAnyTag(EXCLUDE_CHILDSPAWNER_TAGS)
end
function PearlDecorationScore:IsEntityUniqueDecor(ent)
    return TUNING.HERMITCRAB_DECOR_UNIQUE_BOOSTS[ent.prefab] 
        and not (ent.components.burnable ~= nil and ent.components.burnable:IsBurning() or ent:HasTag("burnt"))
        and not ent:HasTag("abandoned")
end

function PearlDecorationScore:IsEntityWithin(ent)
    return self:IsPointWithin(ent.Transform:GetWorldPosition())
end

local OVERHANG = 0.166
function PearlDecorationScore:IsPointWithin(x, y, z, ignore_overhang)
    if not self.enabled then
        return false
    end

    if y == nil and z == nil then
        x, y, z = x:Get()
    end
    local tcx, tcy, tcz = TheWorld.Map:GetTileCenterPoint(x, 0, z)
    local tx, ty = TheWorld.Map:GetTileCoordsAtPoint(x, 0, z)
    local actual_tile = TheWorld.Map:GetTile(tx, ty)

    -- Handle overhang case
    if not ignore_overhang and not TileGroupManager:IsLandTile(actual_tile) then
		local xpercent = (tcx - x) / TILE_SCALE
		local ypercent = (tcz - z) / TILE_SCALE

		local x_min = xpercent > OVERHANG and -1 or 0
		local x_max = xpercent < -OVERHANG and 1 or 0
		local y_min = ypercent > OVERHANG and -1 or 0
		local y_max = ypercent < -OVERHANG and 1 or 0

        for offx = x_min, x_max do
            for offy = y_min, y_max do
                local ptx, pty = tx + offx, ty + offy
                local tile = TheWorld.Map:GetTile(ptx, pty)
                if TileGroupManager:IsLandTile(tile) then
                    return self.tiles:GetDataAtPoint(ptx, pty)
                end
            end
        end
    end

    return self.tiles:GetDataAtPoint(tx, ty)
end
function PearlDecorationScore:OnUpdate(dt)
    if self.force_update or self.update_time <= 0 then
        ---
        self:UpdateOccupiedGrid()
        ---
        local x, y, z = self.inst.Transform:GetWorldPosition()
        local ents = TheSim:FindEntities_Registered(x, y, z, self.scoring_radius, REGISTERED_FIND_DECOR_TAGS)
		local iswintersfeast = IsSpecialEventActive(SPECIAL_EVENTS.WINTERS_FEAST)
        --
        local decor_scores = {}
        for decor_key in pairs(self.decor_data) do
            decor_scores[decor_key] = 0
        end

        local decor_points = 0
        local function AddDecorPoints(key, points)
            decor_scores[key] = decor_scores[key] + points
            decor_points = decor_points + points
        end
        --
        self:UpdateTileScore()
        AddDecorPoints(PEARL_DECORATION_TYPES.TILES, self.tile_score)
        --
        for k, v in ipairs(ents) do
			if v == self.inst then
				if iswintersfeast then
					local skin_build = v:GetSkinBuild()
					if skin_build and string.sub(skin_build, -5) == "_yule" then
						AddDecorPoints(PEARL_DECORATION_TYPES.UNIQUE_DECORATION, TUNING.HERMITCRAB_DECOR_WINTER_BONUS_SCORE)
					end
				end
			elseif self:IsEntityWithin(v) then
                for i, data in ipairs(self.decor_fns) do
                    local decor_data = self.decor_data[data.key]
                    if (decor_data.min_score == nil or decor_scores[data.key] > decor_data.min_score)
                        and (decor_data.max_score == nil or decor_scores[data.key] < decor_data.max_score) then
                        local points = data.fn(v)
                        if points then
                            if decor_data.min_score and decor_scores[data.key] + points < decor_data.min_score then
                                points = decor_data.min_score + -decor_scores[data.key]
                            elseif decor_data.max_score and decor_scores[data.key] + points > decor_data.max_score then
                                points = decor_data.max_score - decor_scores[data.key]
                            end

							if iswintersfeast then
								local skin_build = v:GetSkinBuild()
								if skin_build and string.sub(skin_build, -5) == "_yule" then
									AddDecorPoints(data.key, TUNING.HERMITCRAB_DECOR_WINTER_BONUS_SCORE)
								end
							end

                            AddDecorPoints(data.key, points)
                            break
                        end
                    end
                end
            elseif self:IsEntityWaterTree(v) then -- Special case.
                local coverage = self:GetWaterTreeNumTileCoverage(v)
                if coverage >= TUNING.HERMITCRAB_DECOR_WATER_TREE_TILE_COVERAGE_MIN then
                    AddDecorPoints(PEARL_DECORATION_TYPES.WATER_TREE, TUNING.HERMITCRAB_DECOR_WATER_TREE_SCORE)
                end
            end
        end

		-- Check for hanging ornaments on the house
		if self.inst.components.container then
			-- Base score once we've upgraded to decoratable (tier 5) house
			AddDecorPoints(PEARL_DECORATION_TYPES.LVL5_HOUSE, TUNING.HERMITCRAB_DECOR_LVL5_HOUSE)

			local num, num_winter, num_wagstaff = 0, 0, 0
			self.inst.components.container:ForEachItem(function(item)
				if not item:HasTag("hermithouse_laundry") then
					if item:HasTag("wagstaff_item") then
						num_wagstaff = num_wagstaff + 1
					elseif iswintersfeast and item:HasTag("hermithouse_winter_ornament") then
						num_winter = num_winter + 1
					else
						num = num + 1
					end
				end
			end)
			AddDecorPoints(PEARL_DECORATION_TYPES.ORNAMENTS, num_wagstaff * TUNING.HERMITCRAB_DECOR_WAGSTAFF_ORNAMENT_SCORE)
			AddDecorPoints(PEARL_DECORATION_TYPES.ORNAMENTS, num_winter * TUNING.HERMITCRAB_DECOR_WINTER_ORNAMENT_SCORE)
			AddDecorPoints(PEARL_DECORATION_TYPES.ORNAMENTS, num * TUNING.HERMITCRAB_DECOR_ORNAMENT_SCORE)
		end

        local hermitcrab = self.inst.components.spawner and self.inst.components.spawner.child
        if hermitcrab and hermitcrab.components.petleash then
            for pet in pairs(hermitcrab.components.petleash:GetPets()) do
                if pet:HasTag("critter") then
                    AddDecorPoints(PEARL_DECORATION_TYPES.CRITTER_PET, TUNING.HERMITCRAB_DECOR_CRITTER_PET_SCORE)
                end
            end
        end

        -- You collected every fish, what a super star!
        if GetTableSize(self.unique_trophy_fish) >= UNIQUE_FISH_NEEDED then
            self.collected_all_fish = true
            AddDecorPoints(PEARL_DECORATION_TYPES.TROPHY_FISH, TUNING.HERMITCRAB_DECOR_ALL_FISH_SCORE)
        end

        -- Check if our fishing markers are covered, we don't like that.
        for k, v in ipairs(TheWorld.components.hermitcrab_relocation_manager:GetPearlsFishingMarkers()) do
            if not TheWorld.Map:IsOceanAtPoint(v.Transform:GetWorldPosition()) then
                AddDecorPoints(PEARL_DECORATION_TYPES.FISHING_MARKERS, TUNING.HERMITCRAB_DECOR_FISHING_BLOCKED_SCORE)
            end
        end
        --
        self.last_decor_scores = decor_scores
        TheWorld:PushEvent("pearldecorationscore_evaluatescores", { home = self.inst })
        self:SetScore(decor_points)

        self.force_update = false
        self.update_time = TUNING.HERMITCRAB_DECOR_UPDATE_TIME
        self.unique_decor_scored = {}
        self.unique_trophy_fish = {}
    end

    self.update_time = self.update_time - dt
end
function PearlDecorationScore:LongUpdate(dt)
    if self.enabled and self.update_time then
        self.update_time = self.update_time - dt
    end
end

function PearlDecorationScore:GetLastDecorScore(key)
    return self.last_decor_scores and self.last_decor_scores[key]
end

function PearlDecorationScore:GetLastDecorScorePercentToMax(key)
    local score = self.last_decor_scores and self.last_decor_scores[key]
    local data = self.decor_data[key]
    if data.max_score then
        return score and score / data.max_score
    end
end

function PearlDecorationScore:GetLastDecorScorePercentToMin(key)
    local score = self.last_decor_scores and self.last_decor_scores[key]
    local data = self.decor_data[key]
    if data.min_score then
        return score and score / data.min_score
    end
end

function PearlDecorationScore:GetDecorScoreLevel(key, reverse)
    if reverse then
        local perc = self:GetLastDecorScorePercentToMin(key) or 0
        return perc >= .67 and "HIGH"
            or perc >= .34 and "MED"
            or perc >= .1 and "LOW"
            or nil
    else
        local perc = self:GetLastDecorScorePercentToMax(key) or 0
        return perc >= .67 and "HIGH"
            or perc >= .34 and "MED"
            or "LOW"
    end
end

function PearlDecorationScore:SetScore(score)
    local old_score = self.score
    self.score = math.clamp(score, 0, TUNING.HERMITCRAB_DECOR_MAX_SCORE)
    if old_score ~= self.score then
        TheWorld:PushEvent("pearldecorationscore_updatescore", { home = self.inst, score = self.score })
    end
end

function PearlDecorationScore:GetScore()
    return self.score
end

function PearlDecorationScore:OnSave()
    return (self.enabled ~= false or self.score > 0) and { enabled = self.enabled, score = self.score }
end

function PearlDecorationScore:OnLoad(data)
    if data.enabled then
        self:Enable(true)
    end
    if data.score then
        self:SetScore(data.score)
    end
end

function PearlDecorationScore:LoadPostPass(newents, data)
    if data.enabled then
        TheWorld:PushEvent("pearldecorationscore_updatestatus")
    end
    if data.score then
        TheWorld:PushEvent("pearldecorationscore_updatescore", { home = self.inst, score = self.score })
    end
end

function PearlDecorationScore:OnRemoveFromEntity()
    self:Disable()
end

function PearlDecorationScore:OnRemoveEntity()
	if not self._removing_for_construction then
		self:Disable()
	end
end

function PearlDecorationScore:FlagForConstructionRemoval()
	self._removing_for_construction = true
end

function PearlDecorationScore:OnEntityWake()
    if self.enabled then
        self.inst:StartUpdatingComponent(self)
    end
end

function PearlDecorationScore:OnEntitySleep()
    self.inst:StopUpdatingComponent(self)
end

function PearlDecorationScore:GetDebugString()
    return string.format("enabled: %s, score: %2.2f", tostring(self.enabled), self.score)
end

return PearlDecorationScore