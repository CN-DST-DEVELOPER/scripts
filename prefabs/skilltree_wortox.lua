local SPACER = 40
local TEXT_SPACER = SPACER * 0.75
local LOCK_SPACER = SPACER * 0.85
local SPACER_BOTTOM = 10
local SPACER_SCALES_MIDDLE = 11
local SPACER_SCALES_IN = 11
local SPACER_SCALES_OUT = 11

local ORIGIN_DIST = 175
local ORIGIN_NICE_X, ORIGIN_NICE_Y = -ORIGIN_DIST, SPACER_BOTTOM + SPACER_SCALES_MIDDLE
local ORIGIN_NAUGHTY_X, ORIGIN_NAUGHTY_Y = ORIGIN_DIST, SPACER_BOTTOM + SPACER_SCALES_MIDDLE
local ORIGIN_NEUTRAL_X, ORIGIN_NEUTRAL_Y = 0, SPACER_BOTTOM - 10
local ORIGIN_ALLEGIANCE_X, ORIGIN_ALLEGIANCE_Y = 0, SPACER + SPACER_BOTTOM + LOCK_SPACER * 0.35
local ORIGIN_SCALES_X, ORIGIN_SCALES_Y = 0, SPACER * 2 + LOCK_SPACER * 2.35 + TEXT_SPACER + SPACER_BOTTOM

-- Scales.
local MIN_GAP = SPACER * 0.5 -- Minimum distance away from the center infographic.
local HAND_BAR_LENGTH = 182 - MIN_GAP * 2
local HAND_BAR_HEIGHT = 20
local HAND_BAR_ANGLE_RAW = math.atan2(HAND_BAR_HEIGHT, HAND_BAR_LENGTH)
-- Not using cosine for calculations and will be a skew to force horizontal length requirements.
local HAND_BAR_ANGLE_Y = math.sin(HAND_BAR_ANGLE_RAW)

local ORDERS = { -- Title positions.
    {"nice", {ORIGIN_NICE_X, ORIGIN_NICE_Y - TEXT_SPACER}},
    {"naughty", {ORIGIN_NAUGHTY_X, ORIGIN_NICE_Y - TEXT_SPACER}},
    {"neutral", {ORIGIN_NEUTRAL_X, ORIGIN_NEUTRAL_Y + TEXT_SPACER}},
    {"allegiance", {ORIGIN_ALLEGIANCE_X, ORIGIN_ALLEGIANCE_Y + TEXT_SPACER * 0.9 + LOCK_SPACER * 2}},
}

local function OnTimerDone(inst, data)
    if data then
        if data.name == "wortox_panflute_playing" then
            inst:AddDebuff("wortox_panflute_buff", "wortox_panflute_buff")
        end
    end
end

local function OnDeath(inst, data)
    if inst.components.timer:TimerExists("wortox_panflute_playing") then
        inst.components.timer:PauseTimer("wortox_panflute_playing")
    end
end

local function OnRespawnedFromGhost(inst, data)
    if inst.components.timer:TimerExists("wortox_panflute_playing") then
        inst.components.timer:ResumeTimer("wortox_panflute_playing")
    end
end

local function UpdateSoulJars(item)
    if item.prefab == "wortox_souljar" then
        item:UpdatePercent()
    end
end

local function CloseAndUpdateSoulJars(item, doer)
    if item.prefab == "wortox_souljar" then
        if item.components.container then
            item.components.container:Close(doer)
        end
        UpdateSoulJars(item)
    end
end

local function AllowConsumption_wortox_reviver(item, player)
    if item.prefab == "wortox_reviver" then
        item:SetAllowConsumption(true)
    end
end

local function DisallowConsumption_wortox_reviver(item, player)
    if item.prefab == "wortox_reviver" then
        item:SetAllowConsumption(false)
    end
end

local function LinkUnlinked_wortox_reviver(item, player)
    if item.prefab == "wortox_reviver" then
        item:TryToAttachWortoxID(player)
    end
end

local function Unlink_wortox_reviver(item, player)
    if item.prefab == "wortox_reviver" then
        local linkeditem = item.components.linkeditem
        if linkeditem then
            linkeditem:LinkToOwnerUserID(nil)
        end
    end
end

local function UpdateNabBags(inst)
    local item = inst.components.inventory and inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) or nil
    if item and item.prefab == "wortox_nabbag" then
        item.OnInventoryStateChanged(inst)
    end
end

local CUSTOM_FUNCTIONS;CUSTOM_FUNCTIONS = {
    CalculateInclination = function(nice, naughty, affinitytype)
        local diff = nice - naughty
        if affinitytype then
            if diff < 0 then
                diff = diff - 1
            elseif diff > 0 then
                diff = diff + 1
            end
        end
        if math.abs(diff) >= TUNING.SKILLS.WORTOX.TIPPED_BALANCE_THRESHOLD then
            if nice > naughty then
                return "nice"
            else
                return "naughty"
            end
        end
        return nil
    end,
    ShouldResistFn = function(item)
        if not item.components.equippable:IsEquipped() then
            return false
        end

        local owner = item.components.inventoryitem.owner
        if owner and owner.components.skilltreeupdater and owner.components.skilltreeupdater:IsActivated("wortox_allegiance_lunar") then
            if owner.finishportalhoptask ~= nil and owner:TryToPortalHop(1, false) then
                return true
            end
        end

        return false
    end,
    OnResistDamage = function(item, damage, attacker)
        local owner = item.components.inventoryitem:GetGrandOwner() or item
        local fx = SpawnPrefab("wortox_resist_fx")
        local radius = owner:GetPhysicsRadius(0) + .2 + math.random() * .5
        local x, y, z = owner.Transform:GetWorldPosition()
        local theta
        if attacker ~= nil then
            local x1, y1, z1 = attacker.Transform:GetWorldPosition()
            if x ~= x1 or z ~= z1 then
                theta = math.atan2(z - z1, x1 - x) + math.random() * 2 - 1
            end
        end
        if theta == nil then
            theta = math.random() * TWOPI
        end
        fx.Transform:SetPosition(
            x + radius * math.cos(theta),
            math.random(),
            z - radius * math.sin(theta)
        )
    end,
    LunarResists = { -- NOTES(JBK): Keep in sync in armor_skeleton. [ASRPS]
        "_combat",
        "explosive",
        "quakedebris",
        "lunarhaildebris",
        "caveindebris",
        "trapdamage",
        "rock_tree",
    },
    SetupLunarResists = function(item)
        local resistance = item:AddComponent("resistance")
        for _, v in ipairs(CUSTOM_FUNCTIONS.LunarResists) do
            resistance:AddResistance(v)
        end
        resistance:SetShouldResistFn(CUSTOM_FUNCTIONS.ShouldResistFn)
        resistance:SetOnResistDamageFn(CUSTOM_FUNCTIONS.OnResistDamage)
    end,
    TryResetPanfluteTimer = function(inst)
        if inst.components.skilltreeupdater and inst.components.skilltreeupdater:IsActivated("wortox_panflute_playing") then
            if not inst.components.timer:TimerExists("wortox_panflute_playing") then
                inst.components.timer:StartTimer("wortox_panflute_playing", GetRandomWithVariance(TUNING.SKILLS.WORTOX.WORTOX_PANFLUTE_INSPIRATION_WAIT, TUNING.SKILLS.WORTOX.WORTOX_PANFLUTE_INSPIRATION_WAIT_VARIANCE))
            end
            if inst.components.health:IsDead() then
                inst.components.timer:PauseTimer("wortox_panflute_playing")
            end
        end
    end,
    TryPanfluteTimerSetup = function(inst)
        if inst.wortox_needstreeinit then
            return
        end
        if inst.components.skilltreeupdater and inst.components.skilltreeupdater:IsActivated("wortox_panflute_playing") then
            if not inst.components.timer:TimerExists("wortox_panflute_playing") and not inst:HasDebuff("wortox_panflute_buff") then
                inst.components.timer:StartTimer("wortox_panflute_playing", GetRandomWithVariance(TUNING.SKILLS.WORTOX.WORTOX_PANFLUTE_INSPIRATION_WAIT, TUNING.SKILLS.WORTOX.WORTOX_PANFLUTE_INSPIRATION_WAIT_VARIANCE))
            end
            if inst.components.health:IsDead() then
                inst.components.timer:PauseTimer("wortox_panflute_playing")
            end
            inst:ListenForEvent("timerdone", OnTimerDone)
            inst:ListenForEvent("death", OnDeath)
            inst:ListenForEvent("ms_respawnedfromghost", OnRespawnedFromGhost)
        else
            inst.components.timer:StopTimer("wortox_panflute_playing")
            inst:RemoveDebuff("wortox_panflute_buff")
        end
    end,
}

local function UpdateToken(token, diff, instant, nice, MAX_TOKENS, affinitytype)
    if not nice then
        diff = -diff
    end

    local tokenstate = diff > MAX_TOKENS and token.tokenindex == MAX_TOKENS and "overcharged" or diff >= token.tokenindex and "on" or "off"
    if affinitytype and token.tokenindex == 1 then
        tokenstate = affinitytype
        if affinitytype == "lunar" then
            local WORTOX_LUNAR_OFFSET = 0.1
            token:GetAnimState():SetAddColour(WORTOX_LUNAR_OFFSET, WORTOX_LUNAR_OFFSET, WORTOX_LUNAR_OFFSET, 0)
            token:GetAnimState():SetMultColour(1, 1, 1, 1)
        else -- "shadow"
            local WORTOX_SHADOW_MULT = 0.6
            token:GetAnimState():SetAddColour(0, 0, 0, 0)
            token:GetAnimState():SetMultColour(WORTOX_SHADOW_MULT, WORTOX_SHADOW_MULT, WORTOX_SHADOW_MULT, 1)
        end
        token.bar:Hide()
    else
        token:GetAnimState():SetAddColour(0, 0, 0, 0)
        token:GetAnimState():SetMultColour(1, 1, 1, 1)
        token.bar:Show()
    end

    if instant then
        token.tokenstate = tokenstate
    end

    if token.tokenstate ~= tokenstate then
        if tokenstate == "lunar" then
            if token:GetAnimState():IsCurrentAnimation("token_to_on") or token:GetAnimState():IsCurrentAnimation("token_on") then
                token:GetAnimState():PlayAnimation("token_lunar")
            else
                token:GetAnimState():PlayAnimation("token_to_lunar")
                token:GetAnimState():PushAnimation("token_lunar")
            end
        elseif tokenstate == "shadow" then
            if token:GetAnimState():IsCurrentAnimation("token_to_on") or token:GetAnimState():IsCurrentAnimation("token_on") then
                token:GetAnimState():PlayAnimation("token_shadow")
            else
                token:GetAnimState():PlayAnimation("token_to_shadow")
                token:GetAnimState():PushAnimation("token_shadow")
            end
        elseif tokenstate == "overcharged" then
            token:GetAnimState():PlayAnimation("token_on_to_glow")
            token:GetAnimState():PushAnimation("token_glow")
        elseif tokenstate == "on" then
            if token:GetAnimState():IsCurrentAnimation("token_on_to_glow") or token:GetAnimState():IsCurrentAnimation("token_glow") then
                token:GetAnimState():PlayAnimation("token_glow_to_on")
                token:GetAnimState():PushAnimation("token_on")
            else
                token:GetAnimState():PlayAnimation("token_to_on")
                token:GetAnimState():PushAnimation("token_on")
                token.bar:GetAnimState():PlayAnimation(nice and "swish_toleft" or "swish_toright")
            end
        else
            token:GetAnimState():PlayAnimation("token_to_off")
            token:GetAnimState():PushAnimation("token_off")
            token.bar:GetAnimState():PlayAnimation(nice and "swish_toright" or "swish_toleft")
        end
        token.tokenstate = tokenstate
    else
        if tokenstate == "lunar" then
            token:GetAnimState():PlayAnimation("token_lunar")
        elseif tokenstate == "shadow" then
            token:GetAnimState():PlayAnimation("token_shadow")
        elseif tokenstate == "overcharged" then
            token:GetAnimState():PlayAnimation("token_glow")
        elseif tokenstate == "on" then
            token:GetAnimState():PlayAnimation("token_on")
        else
            token:GetAnimState():PlayAnimation("token_off")
        end
    end
end

local function BuildSkillsData(SkillTreeFns)
    local skills = {
        ------------------------------------------------------------------------------------------------------------------------
        -- GENERIC - Not unlockable skills but information boxes the player will be able to hover over for more information.
        ------------------------------------------------------------------------------------------------------------------------
        wortox_inclination_meter = {
            title = STRINGS.SKILLTREE.WORTOX.WORTOX_INCLINATION_METER_TITLE,
            desc = STRINGS.SKILLTREE.WORTOX.WORTOX_INCLINATION_METER_DESC,
            icon = "wortox_scales",
            pos = {ORIGIN_SCALES_X, ORIGIN_SCALES_Y},
            group = "neutral",
            infographic = true,
            root = true,
            defaultfocus = true,
            forced_focus = {
                left = "wortox_inclination_nice",
                right = "wortox_inclination_naughty",
            },
            button_decorations = {
                init = function(button, root, fromfrontend, prefabname, activatedskills)
                    local UIAnim = require("widgets/uianim")
                    local Widget = require("widgets/widget")
                    -- Adjust the xp icon to be symmetric for this tree.
                    local xppos = root.parent.tree.root.xp:GetPosition()
                    xppos.x = 0
                    root.parent.tree.root.xp:SetPosition(xppos:Get())

                    local tokenlayer = button:AddChild(Widget())
                    button.tokenlayer = tokenlayer

                    local nice = SkillTreeFns.CountTags(prefabname, "nice", activatedskills)
                    local naughty = SkillTreeFns.CountTags(prefabname, "naughty", activatedskills)
                    local diff = nice - naughty
                    local affinitytype = activatedskills and (activatedskills["wortox_allegiance_lunar"] and "lunar" or activatedskills["wortox_allegiance_shadow"] and "shadow") or nil
                    if affinitytype then
                        if diff < 0 then
                            diff = diff - 1
                        elseif diff > 0 then
                            diff = diff + 1
                        end
                    end

                    local MAX_TOKENS = TUNING.SKILLS.WORTOX.TIPPED_BALANCE_THRESHOLD
                    local tokens_nice, tokens_naughty = {}, {}
                    button.tokens_nice, button.tokens_naughty = tokens_nice, tokens_naughty
                    local function CreateToken(i, nice)
                        local token = tokenlayer:AddChild(UIAnim())
                        token.tokenindex = i
                        token:GetAnimState():SetBank("wortox_balance")
                        token:GetAnimState():SetBuild("wortox_balance")
                        local xoffset = ((i - 0.5) * HAND_BAR_LENGTH) / MAX_TOKENS + MIN_GAP
                        local yoffset = xoffset * HAND_BAR_ANGLE_Y
                        token:SetPosition(nice and -xoffset or xoffset, yoffset)
                        token:SetScale(0.6)
                        token:SetClickable(false)
                        local bar = button:AddChild(UIAnim())
                        token.bar = bar
                        bar:MoveToBack()
                        bar:GetAnimState():SetBank("wortox_balance")
                        bar:GetAnimState():SetBuild("wortox_balance")
                        bar:SetScale(0.2, 0.15)
                        local baroffsetx = xoffset - (0.5 * HAND_BAR_LENGTH) / MAX_TOKENS
                        local baroffsety = baroffsetx * HAND_BAR_ANGLE_Y
                        local barrotation = HAND_BAR_ANGLE_RAW * RADIANS
                        bar:SetPosition(nice and -baroffsetx or baroffsetx, baroffsety)
                        bar:SetRotation(nice and barrotation or -barrotation)
                        bar:SetClickable(false)
                        UpdateToken(token, diff, true, nice, MAX_TOKENS, affinitytype)
                        return token
                    end
                    for i = 1, MAX_TOKENS do
                        table.insert(tokens_nice, CreateToken(i, true))
                        table.insert(tokens_naughty, CreateToken(i, false))
                    end
                end,
                onskillschanged = function(button, skillname, fromfrontend, prefabname, activatedskills)
                    -- NOTES(JBK): skillname can be nil for respec case.
                    local nice = SkillTreeFns.CountTags(prefabname, "nice", activatedskills)
                    local naughty = SkillTreeFns.CountTags(prefabname, "naughty", activatedskills)
                    local diff = nice - naughty
                    local affinitytype = activatedskills and (activatedskills["wortox_allegiance_lunar"] and "lunar" or activatedskills["wortox_allegiance_shadow"] and "shadow") or nil
                    if affinitytype then
                        if diff < 0 then
                            diff = diff - 1
                        elseif diff > 0 then
                            diff = diff + 1
                        end
                    end

                    local MAX_TOKENS = TUNING.SKILLS.WORTOX.TIPPED_BALANCE_THRESHOLD
                    local instant = activatedskills == nil
                    for i = 1, MAX_TOKENS do
                        if instant then
                            button.tokens_nice[i].tokenstate = nil
                            button.tokens_naughty[i].tokenstate = nil
                        end
                        UpdateToken(button.tokens_nice[i], diff, instant, true, MAX_TOKENS, affinitytype)
                        UpdateToken(button.tokens_naughty[i], diff, instant, false, MAX_TOKENS, affinitytype)
                    end
                end,
            },
        },
        wortox_inclination_nice = {
            title = STRINGS.SKILLTREE.WORTOX.WORTOX_INCLINATION_NICE_TITLE,
            desc = STRINGS.SKILLTREE.WORTOX.WORTOX_INCLINATION_NICE_DESC,
            icon = "wortox_inclination_nice",
            pos = {ORIGIN_SCALES_X - HAND_BAR_LENGTH - LOCK_SPACER, ORIGIN_SCALES_Y + HAND_BAR_HEIGHT + LOCK_SPACER * 0.25},
            group = "neutral",
            tags = {"lock"},
            infographic = true,
            root = true,
            forced_focus = {
                right = "wortox_inclination_meter",
            },
            lock_open = function(prefabname, activatedskills, readonly)
                local nice = SkillTreeFns.CountTags(prefabname, "nice", activatedskills)
                local naughty = SkillTreeFns.CountTags(prefabname, "naughty", activatedskills)
                local affinitytype = activatedskills and (activatedskills["wortox_allegiance_lunar"] and "lunar" or activatedskills["wortox_allegiance_shadow"] and "shadow") or nil
                return CUSTOM_FUNCTIONS.CalculateInclination(nice, naughty, affinitytype) == "nice"
            end,
        },
        wortox_inclination_naughty = {
            title = STRINGS.SKILLTREE.WORTOX.WORTOX_INCLINATION_NAUGHTY_TITLE,
            desc = STRINGS.SKILLTREE.WORTOX.WORTOX_INCLINATION_NAUGHTY_DESC,
            icon = "wortox_inclination_naughty",
            pos = {ORIGIN_SCALES_X + HAND_BAR_LENGTH + LOCK_SPACER, ORIGIN_SCALES_Y + HAND_BAR_HEIGHT + LOCK_SPACER * 0.25},
            group = "neutral",
            tags = {"lock"},
            infographic = true,
            root = true,
            forced_focus = {
                left = "wortox_inclination_meter",
            },
            lock_open = function(prefabname, activatedskills, readonly)
                local nice = SkillTreeFns.CountTags(prefabname, "nice", activatedskills)
                local naughty = SkillTreeFns.CountTags(prefabname, "naughty", activatedskills)
                local affinitytype = activatedskills and (activatedskills["wortox_allegiance_lunar"] and "lunar" or activatedskills["wortox_allegiance_shadow"] and "shadow") or nil
                return CUSTOM_FUNCTIONS.CalculateInclination(nice, naughty, affinitytype) == "naughty"
            end,
        },
        ------------------------------------------------------------------------------------------------------------------------
        -- LOCKS
        ------------------------------------------------------------------------------------------------------------------------
        wortox_lifebringer_lock = {
            desc = STRINGS.SKILLTREE.WORTOX.WORTOX_NICE_LOCK_DESC,
            pos = {ORIGIN_NICE_X - SPACER * 1.25, ORIGIN_NICE_Y + SPACER + LOCK_SPACER + SPACER_SCALES_OUT},
            group = "nice",
            tags = {"lock"},
            root = true,
            lock_open = function(prefabname, activatedskills, readonly)
                return activatedskills and activatedskills["wortox_lifebringer_2"] and SkillTreeFns.CountTags(prefabname, "nice1", activatedskills) > 4
            end,
        },
        wortox_soulprotector_lock = {
            desc = STRINGS.SKILLTREE.WORTOX.WORTOX_NICE_LOCK_DESC,
            pos = {ORIGIN_NICE_X, ORIGIN_NICE_Y + SPACER + LOCK_SPACER},
            group = "nice",
            tags = {"lock"},
            root = true,
            lock_open = function(prefabname, activatedskills, readonly)
                return activatedskills and activatedskills["wortox_soulprotector_2"] and SkillTreeFns.CountTags(prefabname, "nice1", activatedskills) > 4
            end,
        },
        wortox_souldecoy_lock = {
            desc = STRINGS.SKILLTREE.WORTOX.WORTOX_NAUGHTY_LOCK_DESC,
            pos = {ORIGIN_NAUGHTY_X + SPACER * 1.25, ORIGIN_NAUGHTY_Y + SPACER + LOCK_SPACER + SPACER_SCALES_OUT},
            group = "naughty",
            tags = {"lock"},
            root = true,
            lock_open = function(prefabname, activatedskills, readonly)
                return activatedskills and activatedskills["wortox_souldecoy_2"] and SkillTreeFns.CountTags(prefabname, "naughty1", activatedskills) > 4
            end,
        },
        wortox_thief_lock = {
            desc = STRINGS.SKILLTREE.WORTOX.WORTOX_NAUGHTY_LOCK_DESC,
            pos = {ORIGIN_NAUGHTY_X, ORIGIN_NAUGHTY_Y + SPACER + LOCK_SPACER},
            group = "naughty",
            tags = {"lock"},
            root = true,
            lock_open = function(prefabname, activatedskills, readonly)
                return activatedskills and activatedskills["wortox_thief_2"] and SkillTreeFns.CountTags(prefabname, "naughty1", activatedskills) > 4
            end,
        },
        ------------------------------------------------------------------------------------------------------------------------
        -- NICE
        ------------------------------------------------------------------------------------------------------------------------
        wortox_lifebringer_1 = {
            title = STRINGS.SKILLTREE.WORTOX.WORTOX_LIFEBRINGER_1_TITLE,
            desc = STRINGS.SKILLTREE.WORTOX.WORTOX_LIFEBRINGER_1_DESC,
            icon = "wortox_lifebringer_1",
            pos = {ORIGIN_NICE_X - SPACER * 1.25, ORIGIN_NICE_Y + SPACER_SCALES_OUT},
            group = "nice",
            tags = {"nice", "nice1"},
            root = true,
            connects = {
                "wortox_lifebringer_2",
            },
            onactivate = function(inst)
                inst.components.inventory:ForEachItem(LinkUnlinked_wortox_reviver, inst)
            end,
            ondeactivate = function(inst)
                if TheWorld.components.linkeditemmanager then
                    TheWorld.components.linkeditemmanager:ForEachLinkedItemForPlayer(inst, Unlink_wortox_reviver)
                end
            end,
        },
        wortox_lifebringer_2 = {
            title = STRINGS.SKILLTREE.WORTOX.WORTOX_LIFEBRINGER_2_TITLE,
            desc = STRINGS.SKILLTREE.WORTOX.WORTOX_LIFEBRINGER_2_DESC,
            icon = "wortox_lifebringer_2",
            pos = {ORIGIN_NICE_X - SPACER * 1.25, ORIGIN_NICE_Y + SPACER + SPACER_SCALES_OUT},
            group = "nice",
            tags = {"nice", "nice1"},
        },
        wortox_lifebringer_3 = {
            title = STRINGS.SKILLTREE.WORTOX.WORTOX_LIFEBRINGER_3_TITLE,
            desc = STRINGS.SKILLTREE.WORTOX.WORTOX_LIFEBRINGER_3_DESC,
            icon = "wortox_lifebringer_3",
            pos = {ORIGIN_NICE_X - SPACER * 1.25, ORIGIN_NICE_Y + SPACER + LOCK_SPACER * 2 + SPACER_SCALES_OUT},
            group = "nice",
            tags = {"nice"},
            locks = {
                "wortox_lifebringer_lock",
            },
            onactivate = function(inst)
                if TheWorld.components.linkeditemmanager then
                    TheWorld.components.linkeditemmanager:ForEachLinkedItemForPlayer(inst, AllowConsumption_wortox_reviver)
                end
            end,
            ondeactivate = function(inst)
                if TheWorld.components.linkeditemmanager then
                    TheWorld.components.linkeditemmanager:ForEachLinkedItemForPlayer(inst, DisallowConsumption_wortox_reviver)
                end
            end,
        },
        ------------------------------------------------------------------------------------------------------------------------
        wortox_soulprotector_1 = {
            title = STRINGS.SKILLTREE.WORTOX.WORTOX_SOULPROTECTOR_1_TITLE,
            desc = STRINGS.SKILLTREE.WORTOX.WORTOX_SOULPROTECTOR_1_DESC,
            icon = "wortox_soulprotector_1",
            pos = {ORIGIN_NICE_X, ORIGIN_NICE_Y},
            group = "nice",
            tags = {"nice", "nice1"},
            root = true,
            connects = {
                "wortox_soulprotector_2",
            },
        },
        wortox_soulprotector_2 = {
            title = STRINGS.SKILLTREE.WORTOX.WORTOX_SOULPROTECTOR_2_TITLE,
            desc = STRINGS.SKILLTREE.WORTOX.WORTOX_SOULPROTECTOR_2_DESC,
            icon = "wortox_soulprotector_2",
            pos = {ORIGIN_NICE_X, ORIGIN_NICE_Y + SPACER},
            group = "nice",
            tags = {"nice", "nice1"},
        },
        wortox_soulprotector_3 = {
            title = STRINGS.SKILLTREE.WORTOX.WORTOX_SOULPROTECTOR_3_TITLE,
            desc = STRINGS.SKILLTREE.WORTOX.WORTOX_SOULPROTECTOR_3_DESC,
            icon = "wortox_soulprotector_3",
            pos = {ORIGIN_NICE_X, ORIGIN_NICE_Y + SPACER + LOCK_SPACER * 2},
            group = "nice",
            tags = {"nice"},
            locks = {
                "wortox_soulprotector_lock",
            },
            connects = {
                "wortox_soulprotector_4",
            },
        },
        wortox_soulprotector_4 = {
            title = STRINGS.SKILLTREE.WORTOX.WORTOX_SOULPROTECTOR_4_TITLE,
            desc = STRINGS.SKILLTREE.WORTOX.WORTOX_SOULPROTECTOR_4_DESC,
            icon = "wortox_soulprotector_4",
            pos = {ORIGIN_NICE_X, ORIGIN_NICE_Y + SPACER * 2 + LOCK_SPACER * 2},
            group = "nice",
            tags = {"nice"},
        },
        ------------------------------------------------------------------------------------------------------------------------
        wortox_liftedspirits_1 = {
            title = STRINGS.SKILLTREE.WORTOX.WORTOX_LIFTEDSPIRITS_1_TITLE,
            desc = STRINGS.SKILLTREE.WORTOX.WORTOX_LIFTEDSPIRITS_1_DESC,
            icon = "wortox_liftedspirits_1",
            pos = {ORIGIN_NICE_X + SPACER * 1.5, ORIGIN_NICE_Y + SPACER_SCALES_IN},
            group = "nice",
            tags = {"nice", "nice1"},
            root = true,
            connects = {
                "wortox_liftedspirits_2",
            },
        },
        wortox_liftedspirits_2 = {
            title = STRINGS.SKILLTREE.WORTOX.WORTOX_LIFTEDSPIRITS_2_TITLE,
            desc = STRINGS.SKILLTREE.WORTOX.WORTOX_LIFTEDSPIRITS_2_DESC,
            icon = "wortox_liftedspirits_2",
            pos = {ORIGIN_NICE_X + SPACER * 1.5, ORIGIN_NICE_Y + SPACER + SPACER_SCALES_IN},
            group = "nice",
            tags = {"nice", "nice1"},
            connects = {
                "wortox_liftedspirits_3",
                "wortox_liftedspirits_4",
            },
        },
        wortox_liftedspirits_3 = {
            title = STRINGS.SKILLTREE.WORTOX.WORTOX_LIFTEDSPIRITS_3_TITLE,
            desc = STRINGS.SKILLTREE.WORTOX.WORTOX_LIFTEDSPIRITS_3_DESC,
            icon = "wortox_liftedspirits_3",
            pos = {ORIGIN_NICE_X + SPACER * 1.05, ORIGIN_NICE_Y + SPACER * 2 + SPACER_SCALES_IN},
            group = "nice",
            tags = {"nice", "nice1"},
        },
        wortox_liftedspirits_4 = {
            title = STRINGS.SKILLTREE.WORTOX.WORTOX_LIFTEDSPIRITS_4_TITLE,
            desc = STRINGS.SKILLTREE.WORTOX.WORTOX_LIFTEDSPIRITS_4_DESC,
            icon = "wortox_liftedspirits_4",
            pos = {ORIGIN_NICE_X + SPACER * 1.95, ORIGIN_NICE_Y + SPACER * 2 + SPACER_SCALES_IN},
            group = "nice",
            tags = {"nice", "nice1"},
            forced_focus = {
                right = "wortox_allegiance_lunar",
            },
        },
        ------------------------------------------------------------------------------------------------------------------------
        -- NEUTRAL
        ------------------------------------------------------------------------------------------------------------------------
        wortox_panflute_playing = {
            title = STRINGS.SKILLTREE.WORTOX.WORTOX_PANFLUTE_PLAYING_TITLE,
            desc = STRINGS.SKILLTREE.WORTOX.WORTOX_PANFLUTE_PLAYING_DESC,
            icon = "wortox_panflute_playing",
            pos = {ORIGIN_NEUTRAL_X, ORIGIN_NEUTRAL_Y},
            group = "neutral",
            tags = {"neutral", "nice1", "naughty1"},
            root = true,
            connects = {
                "wortox_panflute_soulcaller",
                "wortox_panflute_forget",
            },
            onactivate = function(inst)
                CUSTOM_FUNCTIONS.TryPanfluteTimerSetup(inst)
            end,
            ondeactivate = function(inst)
                inst.components.timer:StopTimer("wortox_panflute_playing")
                inst:RemoveDebuff("wortox_panflute_buff")
                inst:RemoveEventCallback("timerdone", OnTimerDone)
                inst:RemoveEventCallback("death", OnDeath)
                inst:RemoveEventCallback("ms_respawnedfromghost", OnRespawnedFromGhost)
            end,
        },
        wortox_panflute_soulcaller = {
            title = STRINGS.SKILLTREE.WORTOX.WORTOX_PANFLUTE_SOULCALLER_TITLE,
            desc = STRINGS.SKILLTREE.WORTOX.WORTOX_PANFLUTE_SOULCALLER_DESC,
            icon = "wortox_panflute_soulcaller",
            pos = {ORIGIN_NEUTRAL_X - SPACER * 1.25, ORIGIN_NEUTRAL_Y},
            group = "neutral",
            tags = {"neutral", "nice1", "naughty1"},
        },
        wortox_panflute_forget = {
            title = STRINGS.SKILLTREE.WORTOX.WORTOX_PANFLUTE_FORGET_TITLE,
            desc = STRINGS.SKILLTREE.WORTOX.WORTOX_PANFLUTE_FORGET_DESC,
            icon = "wortox_panflute_forget",
            pos = {ORIGIN_NEUTRAL_X + SPACER * 1.25, ORIGIN_NEUTRAL_Y},
            group = "neutral",
            tags = {"neutral", "nice1", "naughty1"},
        },
        ------------------------------------------------------------------------------------------------------------------------
        -- NAUGHTY
        ------------------------------------------------------------------------------------------------------------------------
        wortox_nabbag = {
            title = STRINGS.SKILLTREE.WORTOX.WORTOX_NABBAG_TITLE,
            desc = STRINGS.SKILLTREE.WORTOX.WORTOX_NABBAG_DESC,
            icon = "wortox_nabbag",
            pos = {ORIGIN_NAUGHTY_X - SPACER * 1.5, ORIGIN_NAUGHTY_Y + SPACER_SCALES_IN},
            group = "naughty",
            tags = {"naughty", "naughty1"},
            root = true,
            connects = {
                "wortox_souljar_1",
            },
            onactivate = function(inst)
                inst:AddTag("nabbaguser")
            end,
            ondeactivate = function(inst)
                inst:RemoveTag("nabbaguser")
            end,
        },
        wortox_souljar_1 = {
            title = STRINGS.SKILLTREE.WORTOX.WORTOX_SOULJAR_1_TITLE,
            desc = STRINGS.SKILLTREE.WORTOX.WORTOX_SOULJAR_1_DESC,
            icon = "wortox_souljar_1",
            pos = {ORIGIN_NAUGHTY_X - SPACER * 1.5, ORIGIN_NAUGHTY_Y + SPACER + SPACER_SCALES_IN},
            group = "naughty",
            tags = {"naughty", "naughty1"},
            connects = {
                "wortox_souljar_2",
                "wortox_souljar_3",
            },
            onactivate = function(inst)
                inst.components.inventory:ForEachItem(UpdateSoulJars)
            end,
            ondeactivate = function(inst)
                inst.components.inventory:ForEachItem(CloseAndUpdateSoulJars, inst)
                for container, _ in pairs(inst.components.inventory.opencontainers) do
                    CloseAndUpdateSoulJars(container, inst)
                end
            end,
        },
        wortox_souljar_2 = {
            title = STRINGS.SKILLTREE.WORTOX.WORTOX_SOULJAR_2_TITLE,
            desc = STRINGS.SKILLTREE.WORTOX.WORTOX_SOULJAR_2_DESC,
            icon = "wortox_souljar_2",
            pos = {ORIGIN_NAUGHTY_X - SPACER * 1.95, ORIGIN_NAUGHTY_Y + SPACER * 2 + SPACER_SCALES_IN},
            group = "naughty",
            tags = {"naughty", "naughty1"},
            forced_focus = {
                left = "wortox_allegiance_shadow",
            },
            onactivate = function(inst)
                inst:DoCheckSoulsAdded()
            end,
            ondeactivate = function(inst)
                inst:DoCheckSoulsAdded()
            end,
        },
        wortox_souljar_3 = {
            title = STRINGS.SKILLTREE.WORTOX.WORTOX_SOULJAR_3_TITLE,
            desc = STRINGS.SKILLTREE.WORTOX.WORTOX_SOULJAR_3_DESC,
            icon = "wortox_souljar_3",
            pos = {ORIGIN_NAUGHTY_X - SPACER * 1.05, ORIGIN_NAUGHTY_Y + SPACER * 2 + SPACER_SCALES_IN},
            group = "naughty",
            tags = {"naughty", "naughty1"},
            onactivate = UpdateNabBags,
            ondeactivate = UpdateNabBags,
        },
        ------------------------------------------------------------------------------------------------------------------------
        wortox_thief_1 = {
            title = STRINGS.SKILLTREE.WORTOX.WORTOX_THIEF_1_TITLE,
            desc = STRINGS.SKILLTREE.WORTOX.WORTOX_THIEF_1_DESC,
            icon = "wortox_thief_1",
            pos = {ORIGIN_NAUGHTY_X, ORIGIN_NAUGHTY_Y},
            group = "naughty",
            tags = {"naughty", "naughty1"},
            root = true,
            connects = {
                "wortox_thief_2",
            },
        },
        wortox_thief_2 = {
            title = STRINGS.SKILLTREE.WORTOX.WORTOX_THIEF_2_TITLE,
            desc = STRINGS.SKILLTREE.WORTOX.WORTOX_THIEF_2_DESC,
            icon = "wortox_thief_2",
            pos = {ORIGIN_NAUGHTY_X, ORIGIN_NAUGHTY_Y + SPACER},
            group = "naughty",
            tags = {"naughty", "naughty1"},
        },
        wortox_thief_3 = {
            title = STRINGS.SKILLTREE.WORTOX.WORTOX_THIEF_3_TITLE,
            desc = STRINGS.SKILLTREE.WORTOX.WORTOX_THIEF_3_DESC,
            icon = "wortox_thief_3",
            pos = {ORIGIN_NAUGHTY_X, ORIGIN_NAUGHTY_Y + SPACER + LOCK_SPACER * 2},
            group = "naughty",
            tags = {"naughty"},
            locks = {
                "wortox_thief_lock",
            },
            connects = {
                "wortox_thief_4",
            },
        },
        wortox_thief_4 = {
            title = STRINGS.SKILLTREE.WORTOX.WORTOX_THIEF_4_TITLE,
            desc = STRINGS.SKILLTREE.WORTOX.WORTOX_THIEF_4_DESC,
            icon = "wortox_thief_4",
            pos = {ORIGIN_NAUGHTY_X, ORIGIN_NAUGHTY_Y + SPACER * 2 + LOCK_SPACER * 2},
            group = "naughty",
            tags = {"naughty"},
        },
        ------------------------------------------------------------------------------------------------------------------------
        wortox_souldecoy_1 = {
            title = STRINGS.SKILLTREE.WORTOX.WORTOX_SOULDECOY_1_TITLE,
            desc = STRINGS.SKILLTREE.WORTOX.WORTOX_SOULDECOY_1_DESC,
            icon = "wortox_souldecoy_1",
            pos = {ORIGIN_NAUGHTY_X + SPACER * 1.25, ORIGIN_NAUGHTY_Y + SPACER_SCALES_OUT},
            group = "naughty",
            tags = {"naughty", "naughty1"},
            root = true,
            connects = {
                "wortox_souldecoy_2",
            },
        },
        wortox_souldecoy_2 = {
            title = STRINGS.SKILLTREE.WORTOX.WORTOX_SOULDECOY_2_TITLE,
            desc = STRINGS.SKILLTREE.WORTOX.WORTOX_SOULDECOY_2_DESC,
            icon = "wortox_souldecoy_2",
            pos = {ORIGIN_NAUGHTY_X + SPACER * 1.25, ORIGIN_NAUGHTY_Y + SPACER + SPACER_SCALES_OUT},
            group = "naughty",
            tags = {"naughty", "naughty1"},
        },
        wortox_souldecoy_3 = {
            title = STRINGS.SKILLTREE.WORTOX.WORTOX_SOULDECOY_3_TITLE,
            desc = STRINGS.SKILLTREE.WORTOX.WORTOX_SOULDECOY_3_DESC,
            icon = "wortox_souldecoy_3",
            pos = {ORIGIN_NAUGHTY_X + SPACER * 1.25, ORIGIN_NAUGHTY_Y + SPACER + LOCK_SPACER * 2 + SPACER_SCALES_OUT},
            group = "naughty",
            tags = {"naughty"},
            locks = {
                "wortox_souldecoy_lock",
            },
        },
        ------------------------------------------------------------------------------------------------------------------------
        -- ALLEGIANCE
        ------------------------------------------------------------------------------------------------------------------------
        wortox_allegiance_lunar_lock_1 = SkillTreeFns.MakeCelestialChampionLock(
            {
                pos = {ORIGIN_ALLEGIANCE_X - SPACER * 0.5, ORIGIN_ALLEGIANCE_Y},
            }
        ),
        wortox_allegiance_lunar_lock_2 = SkillTreeFns.MakeNoShadowLock(
            {
                pos = {ORIGIN_ALLEGIANCE_X - SPACER * 0.5, ORIGIN_ALLEGIANCE_Y + LOCK_SPACER},
            }
        ),
        wortox_allegiance_lunar = {
            title = STRINGS.SKILLTREE.WORTOX.WORTOX_ALLEGIANCE_LUNAR_TITLE,
            desc = STRINGS.SKILLTREE.WORTOX.WORTOX_ALLEGIANCE_LUNAR_DESC,
            icon = "wortox_favor_lunar",
            pos = {ORIGIN_ALLEGIANCE_X - SPACER * 0.5, ORIGIN_ALLEGIANCE_Y + LOCK_SPACER * 2},
            group = "allegiance",
            tags = {"lunar_favor", "neutral", "allegiance"},
            locks = {"wortox_allegiance_lunar_lock_1", "wortox_allegiance_lunar_lock_2"},
            onactivate = function(inst)
                inst:AddTag("player_lunar_aligned")
                if inst.components.damagetyperesist ~= nil then
                    inst.components.damagetyperesist:AddResist("lunar_aligned", inst, TUNING.SKILLS.WORTOX.ALLEGIANCE_LUNAR_RESIST, "allegiance_lunar")
                end
                if inst.components.damagetypebonus ~= nil then
                    inst.components.damagetypebonus:AddBonus("shadow_aligned", inst, TUNING.SKILLS.WORTOX.ALLEGIANCE_VS_SHADOW_BONUS, "allegiance_lunar")
                end
            end,
            ondeactivate = function(inst)
                inst:RemoveTag("player_lunar_aligned")
                if inst.components.damagetyperesist ~= nil then
                    inst.components.damagetyperesist:RemoveResist("lunar_aligned", inst, "allegiance_lunar")
                end
                if inst.components.damagetypebonus ~= nil then
                    inst.components.damagetypebonus:RemoveBonus("shadow_aligned", inst, "allegiance_lunar")
                end
            end,
        },
        ------------------------------------------------------------------------------------------------------------------------
        wortox_allegiance_shadow_lock_1 = SkillTreeFns.MakeFuelWeaverLock(
            {
                pos = {ORIGIN_ALLEGIANCE_X + SPACER * 0.5, ORIGIN_ALLEGIANCE_Y},
            }
        ),
        wortox_allegiance_shadow_lock_2 = SkillTreeFns.MakeNoLunarLock(
            {
                pos = {ORIGIN_ALLEGIANCE_X + SPACER * 0.5, ORIGIN_ALLEGIANCE_Y + LOCK_SPACER},
            }
        ),
        wortox_allegiance_shadow = {
            title = STRINGS.SKILLTREE.WORTOX.WORTOX_ALLEGIANCE_SHADOW_TITLE,
            desc = STRINGS.SKILLTREE.WORTOX.WORTOX_ALLEGIANCE_SHADOW_DESC,
            icon = "wortox_favor_shadow",
            pos = {ORIGIN_ALLEGIANCE_X + SPACER * 0.5, ORIGIN_ALLEGIANCE_Y + LOCK_SPACER * 2},
            group = "allegiance",
            tags = {"shadow_favor", "neutral", "allegiance"},
            locks = {"wortox_allegiance_shadow_lock_1", "wortox_allegiance_shadow_lock_2"},
            onactivate = function(inst)
                inst:AddTag("player_shadow_aligned")
                if inst.components.damagetyperesist ~= nil then
                    inst.components.damagetyperesist:AddResist("shadow_aligned", inst, TUNING.SKILLS.WORTOX.ALLEGIANCE_SHADOW_RESIST, "allegiance_shadow")
                end
                if inst.components.damagetypebonus ~= nil then
                    inst.components.damagetypebonus:AddBonus("lunar_aligned", inst, TUNING.SKILLS.WORTOX.ALLEGIANCE_VS_LUNAR_BONUS, "allegiance_shadow")
                end
            end,
            ondeactivate = function(inst)
                inst:RemoveTag("player_shadow_aligned")
                if inst.components.damagetyperesist ~= nil then
                    inst.components.damagetyperesist:RemoveResist("shadow_aligned", inst, "allegiance_shadow")
                end
                if inst.components.damagetypebonus ~= nil then
                    inst.components.damagetypebonus:RemoveBonus("lunar_aligned", inst, "allegiance_shadow")
                end
            end,
        },
    }

    return {
        SKILLS = skills,
        ORDERS = ORDERS,
        --BACKGROUND_SETTINGS = BACKGROUND_SETTINGS,
        CUSTOM_FUNCTIONS = CUSTOM_FUNCTIONS,
    }
end

return BuildSkillsData