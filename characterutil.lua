-- Utility functions for loading character data (portraits, avatars, etc).

require("dlcsupport")


-- Load the oval portrait for input character into the input widget.
--
-- Returns whether the oval portrait atlas was found.
-- character is something like 'wilson'
-- skin is something like 'wilson_formal'
function SetSkinnedOvalPortraitTexture(image_widget, character, skin)
    if IsPrefabSkinned(character) or character == "random" then --"random" hack, yuck
        local portrait_name = GetPortraitNameForItem(skin)
        if softresolvefilepath("bigportraits/"..portrait_name..".xml") then
            -- Try to load the oval and fall back to the unskinned shield if it's stored here.
            image_widget:SetTexture("bigportraits/"..portrait_name..".xml", portrait_name.."_oval.tex", character.."_none.tex")
            return true
        else
            print("ERROR! ", portrait_name, "is not a valid portrait file for", character, skin )
        end
    else
        -- No skinnable oval portrait. Load the shield portrait instead.
        image_widget:SetTexture("bigportraits/"..character..".xml", character..".tex")
        return false
    end
end

-- Like SetSkinnedOvalPortraitTexture but with default skin.
--
-- character is something like 'wilson'
function SetOvalPortraitTexture(image_widget, character)
    if IsPrefabSkinned(character) or character == "random" then --"random" hack, yuck
        return SetSkinnedOvalPortraitTexture(image_widget, character, character .."_none")
    else
        image_widget:SetTexture("bigportraits/"..character..".xml", character..".tex")
        return false
    end
end

-- Load the oval portrait for input character into the input widget.
-- Returns whether the oval portrait atlas was found.
function SetHeroNameTexture_Grey(image_widget, character)
    local hero_atlas = "images/names_"..character..".xml"
    if softresolvefilepath(hero_atlas) then
        image_widget:SetTexture(hero_atlas, character..".tex")
        -- SetTexture may still fail if the texture doesn't exist.
        return true
    end
end

-- Load the oval portrait for input character into the input widget.
-- Returns whether the oval portrait atlas was found.
function SetHeroNameTexture_Gold(image_widget, character)
    local loc_suffix = LOC.GetNamesImageSuffix()
    local hero_atlas = "images/names_gold" .. loc_suffix .. "_" .. character..".xml"
    if softresolvefilepath(hero_atlas) then
        image_widget:SetTexture(hero_atlas, character..".tex")
        -- SetTexture may still fail if the texture doesn't exist.
        return true
    else
      -- Mod characters aren't likely to have gold, so fall back to grey.
      return SetHeroNameTexture_Grey(image_widget, character)
    end
end

-- Load the avatar image for input character into the input widget.
--
-- Avatars are images of character's heads.
-- Returns the atlas and texture.
-- character is something like 'wilson'
-- NOTE: Currently unused, leaving it here for mod support.
function GetCharacterAvatarTextureLocation(character)
    local avatar_location = "images/avatars.xml"
    -- Random isn't a real character, but we treat it like one for display purposes.
    if character == "random" or table.contains(DST_CHARACTERLIST, character) then
        -- Normal flow. Nothing special.
    elseif table.contains(MODCHARACTERLIST, character) then
        local mod_location = MOD_AVATAR_LOCATIONS[character] or MOD_AVATAR_LOCATIONS["Default"]
        avatar_location = string.format("%savatar_%s.xml", mod_location, character)
    else
        -- A valid name is probably a mod character that didn't register itself in MODCHARACTERLIST.
        local has_name = character ~= nil and character ~= ""
        if has_name then
            character = "mod"
        else
            character = "unknown"
        end
    end
    return avatar_location, string.format("avatar_%s.tex", character)
end

-- Get title for character.
--
-- character is something like 'wilson'
-- skin is something like 'wilson_formal'
function GetCharacterTitle(character, skin)
    if skin and skin ~= "" then
        return GetSkinName(skin)
    end
    return STRINGS.CHARACTER_TITLES[character]
end


local function tchelper(first, rest)
  return first:upper()..rest:lower()
end

function GetKilledByFromMorgueRow(data)
    if data.killed_by == nil then
        return ""
    elseif data.pk then
        --If it's a PK, then don't do any remapping or reformatting on the player's name
        return data.killed_by
    end

    local killed_by =
        (data.killed_by == "nil" and ((data.character == "waxwell" or data.character == "winona") and "charlie" or "darkness")) or
        (data.killed_by == "unknown" and "shenanigans") or
        (data.killed_by == "moose" and ((data.morgue_random or math.random()) < .5 and "moose1" or "moose2")) or
        data.killed_by

    killed_by = STRINGS.NAMES[string.upper(killed_by)] or STRINGS.NAMES.SHENANIGANS

    return killed_by:gsub("(%a)([%w_']*)", tchelper)
end

function GetUniquePotentialCharacterStartingInventoryItems(character, with_bonus_items)
    local inv_item_list = (TUNING.GAMEMODE_STARTING_ITEMS[TheNet:GetServerGameMode()] or TUNING.GAMEMODE_STARTING_ITEMS.DEFAULT)[string.upper(character)]
    if inv_item_list then
        -- NOTES(JBK): Do a shallowcopy to not edit the base starting items tables from TUNING.
        inv_item_list = shallowcopy(inv_item_list)
    else
        inv_item_list = {}
    end

    if with_bonus_items then
        -- NOTES(JBK): Seasonal items could be added onto from mods iterate always and make it static by ordering alphabetically.
        for _, season in orderedPairs(SEASONS) do
            local extra_item_list = TUNING.EXTRA_STARTING_ITEMS[season]
            if extra_item_list then
                for _, v in ipairs(extra_item_list) do
                    table.insert(inv_item_list, v)
                end
            end
            local seasonal_item_list = TUNING.SEASONAL_STARTING_ITEMS[season]
            if seasonal_item_list then
                for _, v in ipairs(seasonal_item_list) do
                    table.insert(inv_item_list, v)
                end
            end
        end
    end

    -- NOTES(JBK): Remove duplicates we only want single instances.
    local inv_item_list_no_dupes, inv_item_list_unique = {}, {}
    for _, v in ipairs(inv_item_list) do
        if inv_item_list_unique[v] == nil then
            inv_item_list_unique[v] = true
            table.insert(inv_item_list_no_dupes, v)
        end
    end
    inv_item_list = inv_item_list_no_dupes

    return inv_item_list
end

