local addonName, addon = ...
addon = addon or SmartSoulShards or {}
local L = addon.L or (SmartSoulShards and SmartSoulShards.L) or {}

local SSS = CreateFrame("Frame", "SmartSoulShardsFrame", UIParent)

-- ------------------------------------------------------------
-- Constants
-- ------------------------------------------------------------

local POWER_SOUL_SHARDS = Enum and Enum.PowerType and Enum.PowerType.SoulShards or 7
local POWER_SOUL_SHARDS_TOKEN = "SOUL_SHARDS"
local SHARD_COUNT = 5
local COLOR_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local BLACK_BORDER_COLOR = { 0, 0, 0, 1 }
local AFFLICTION_SPEC_ID = 265
local DEMONOLOGY_SPEC_ID = 266
local DESTRUCTION_SPEC_ID = 267
local SPEC_KEYS = {
    [AFFLICTION_SPEC_ID] = "affliction",
    [DEMONOLOGY_SPEC_ID] = "demonology",
    [DESTRUCTION_SPEC_ID] = "destruction",
}
local SPEC_OPTIONS = {
    { key = "affliction", textKey = "SPEC_AFFLICTION" },
    { key = "demonology", textKey = "SPEC_DEMONOLOGY" },
    { key = "destruction", textKey = "SPEC_DESTRUCTION" },
}
local DREADSTALKERS_COST_REDUCTION_TALENT_ID = 1276947
local RUINATION_SPELL_ID = 434635
local DEMONOLOGY_BUILDER_SPELL_IDS = {
    [686] = 1, -- Shadow Bolt
    [434506] = 3, -- Infernal Bolt
    [264178] = 2, -- Demonbolt
    [RUINATION_SPELL_ID] = 1, -- Ruination
    [265187] = 3, -- Summon Demonic Tyrant
}
local DEMONOLOGY_SPENDER_SPELL_IDS = {
    [105174] = 3, -- Hand of Gul'dan
    [104316] = 2, -- Call Dreadstalkers
}
local AFFLICTION_SPENDER_SPELL_IDS = {
    [1259790] = 1, -- Unstable Affliction
    [27243] = 1, -- Seed of Corruption
}
local AFFLICTION_BUILDER_SPELL_IDS = {
    [1257052] = 3, -- Dark Harvest
}
local DESTRUCTION_BUILDER_SPELL_IDS = {
    [29722] = 0.4, -- Incinerate
    [6353] = 1, -- Soul Fire
    [434506] = 2, -- Infernal Bolt
}
local DESTRUCTION_SPENDER_SPELL_IDS = {
    [116858] = 2, -- Chaos Bolt
}

local SHADOW_OF_DEATH_TALENT_ID = 449638
local DOMINION_OF_ARGUS_TALENT_ID = 1276222
local DOMINION_OF_ARGUS_REFUND_WINDOW_SECONDS = 25
local PREDICTION_REFRESH_DELAYS = { 0.05, 0.15, 0.30 }
local WARLOCK_EVENTS = {
    "PLAYER_ENTERING_WORLD",
    "PLAYER_DEAD",
    "FIRST_FRAME_RENDERED",
    "PLAYER_MOUNT_DISPLAY_CHANGED",
    "ZONE_CHANGED",
    "ZONE_CHANGED_INDOORS",
    "ZONE_CHANGED_NEW_AREA",
    "SPELL_UPDATE_USABLE",
    "SPELLS_CHANGED",
    "UNIT_POWER_UPDATE",
    "UNIT_POWER_FREQUENT",
    "UNIT_MAXPOWER",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
    "PLAYER_SPECIALIZATION_CHANGED",
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_SUCCEEDED",
    "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED",
}
local VISIBILITY_REFRESH_EVENTS = {
    FIRST_FRAME_RENDERED = true,
    PLAYER_MOUNT_DISPLAY_CHANGED = true,
    ZONE_CHANGED = true,
    ZONE_CHANGED_INDOORS = true,
    ZONE_CHANGED_NEW_AREA = true,
}
local POWER_EVENTS = {
    UNIT_POWER_UPDATE = true,
    UNIT_POWER_FREQUENT = true,
    UNIT_MAXPOWER = true,
}
local CAST_START_EVENTS = {
    UNIT_SPELLCAST_START = true,
    UNIT_SPELLCAST_CHANNEL_START = true,
}
local CAST_END_EVENTS = {
    UNIT_SPELLCAST_STOP = true,
    UNIT_SPELLCAST_SUCCEEDED = true,
}
local CAST_CANCEL_EVENTS = {
    UNIT_SPELLCAST_FAILED = true,
    UNIT_SPELLCAST_INTERRUPTED = true,
}
local CUSTOM_STATUSBAR_TEXTURES = {
    -- Add bundled textures here after placing the files in the addon folder:
    -- { name = "My Texture", path = "Interface\\AddOns\\SmartSoulShards\\Media\\StatusBars\\MyTexture.tga" },
}

-- ------------------------------------------------------------
-- Defaults and state
-- ------------------------------------------------------------

local defaults = {
    point = "CENTER",
    relativePoint = "CENTER",
    x = 0,
    y = 0,
    layouts = {},

    width = 54,
    height = 28,
    spacing = 1,
    borderSize = 1,
    countFont = "Friz Quadrata TT",
    countFontSize = 20,
    shardTexture = "Solid",

    hideBlizzard = true,
    hideWhileSkyriding = false,
    predictiveText = true,
    predictiveBuildersBySpec = {
        affliction = true,
        demonology = true,
        destruction = true,
    },
    predictiveSpendersBySpec = {
        affliction = true,
        demonology = true,
        destruction = true,
    },

    inactiveColor = { 0.00, 0.00, 0.00, 0.45 },
    soulShardColor = { 0.50, 0.32, 0.55, 1.0 },
    cappedSoulShardColor = { 1.00, 0.60, 0.26, 1.0 },
}

local shards = {}
local shardCountText
local isWarlock = false
local currentSpecID
local currentSpecKey
local talentRankCache = {}
local knownPlayerSpellCache = {}
local cachedShardTextureKey
local cachedShardTexturePath
local castingBuilderShards = 0
local activeBuilderSpellID
local isCastingShardSpender = false
local activeShardSpenderSpellID
local activePredictionSpellID
local pendingShardSpenderCount
local pendingBuilderShardCount
local visibilityRefreshTicker
local apexRefundExpiresAt = 0
local apexRefundTimer
local channelPredictionTicker
local editModeHooksRegistered = false
local libEditModeRegistered = false
local warlockEventsRegistered = false
local RefreshPredictionCastState
local SetEditModeControlsActive
local UpdateShards

-- ------------------------------------------------------------
-- General helpers
-- ------------------------------------------------------------

local function Text(key)
    return L[key] or key
end

local function PrintAddon(message)
    print("|cffb266ffSmart Soul Shards:|r " .. message)
end

local function Clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local function SetPixelSnapping(texture)
    if texture.SetSnapToPixelGrid then
        texture:SetSnapToPixelGrid(true)
    end

    if texture.SetTexelSnappingBias then
        texture:SetTexelSnappingBias(0)
    end
end

local function CopyDefaults(src, dst)
    dst = type(dst) == "table" and dst or {}

    for key, value in pairs(src) do
        if type(value) == "table" then
            dst[key] = CopyDefaults(value, dst[key])
        elseif dst[key] == nil then
            dst[key] = value
        end
    end

    return dst
end

local function IsPlayerWarlock()
    local _, class = UnitClass("player")
    return class == "WARLOCK"
end

-- ------------------------------------------------------------
-- Frame visibility and positioning
-- ------------------------------------------------------------

local function ApplyPosition()
    local db = SmartSoulShardsDB
    local layoutName
    local lib = addon.LibEditMode

    if lib and lib.GetActiveLayoutName then
        layoutName = lib:GetActiveLayoutName()
    end

    local layout = layoutName and db.layouts and db.layouts[layoutName]
    local point = layout and layout.point or db.point or defaults.point
    local relativePoint = layout and layout.relativePoint or db.relativePoint or point
    local x = layout and layout.x or db.x or defaults.x
    local y = layout and layout.y or db.y or defaults.y

    SSS:ClearAllPoints()
    SSS:SetPoint(point, UIParent, relativePoint, x, y)
end

local function SavePositionForLayout(layoutName, point, x, y)
    local db = SmartSoulShardsDB
    db.point = point
    db.relativePoint = point
    db.x = x
    db.y = y

    if layoutName then
        db.layouts = type(db.layouts) == "table" and db.layouts or {}
        db.layouts[layoutName] = db.layouts[layoutName] or {}
        db.layouts[layoutName].point = point
        db.layouts[layoutName].relativePoint = point
        db.layouts[layoutName].x = x
        db.layouts[layoutName].y = y
    end
end

local function GetActivePositionValue(key)
    local db = SmartSoulShardsDB
    local lib = addon.LibEditMode
    local layoutName = lib and lib.GetActiveLayoutName and lib:GetActiveLayoutName()
    local layout = layoutName and db.layouts and db.layouts[layoutName]

    return layout and layout[key] or db[key] or defaults[key]
end

local function SetActivePositionValue(key, value)
    local db = SmartSoulShardsDB
    local lib = addon.LibEditMode
    local layoutName = lib and lib.GetActiveLayoutName and lib:GetActiveLayoutName()
    local point = GetActivePositionValue("point")
    local x = key == "x" and value or GetActivePositionValue("x")
    local y = key == "y" and value or GetActivePositionValue("y")

    db[key] = value

    if layoutName then
        db.layouts = type(db.layouts) == "table" and db.layouts or {}
        db.layouts[layoutName] = db.layouts[layoutName] or {}
        db.layouts[layoutName].point = point
        db.layouts[layoutName].relativePoint = point
        db.layouts[layoutName].x = x
        db.layouts[layoutName].y = y
    end
end

local function IsEditModeActive()
    local lib = addon.LibEditMode
    if lib and lib.IsInEditMode then
        return lib:IsInEditMode()
    end

    if EditModeManagerFrame then
        if EditModeManagerFrame.IsEditModeActive then
            return EditModeManagerFrame:IsEditModeActive()
        end

        return EditModeManagerFrame:IsShown()
    end

    return false
end

local function ShouldHideForSkyriding()
    if not SmartSoulShardsDB.hideWhileSkyriding then
        return false
    end

    if C_PlayerInfo == nil or C_PlayerInfo.GetGlidingInfo == nil then
        return false
    end

    local _, canGlide = C_PlayerInfo.GetGlidingInfo()
    return canGlide == true
end

local function QueueVisibilityRefresh()
    UpdateShards()

    if visibilityRefreshTicker then
        visibilityRefreshTicker:Cancel()
    end

    if C_Timer then
        visibilityRefreshTicker = C_Timer.NewTicker(0.02, UpdateShards, 25)
    end
end

-- ------------------------------------------------------------
-- Soul shard and spec helpers
-- ------------------------------------------------------------

local function GetColorThreshold(current)
    return Clamp(math.floor(current), 1, SHARD_COUNT)
end

local function GetShardColorData(threshold)
    if threshold >= SHARD_COUNT then
        return SmartSoulShardsDB.cappedSoulShardColor
    end

    return SmartSoulShardsDB.soulShardColor
end

local function DarkenColor(color, amount)
    local multiplier = 1 - Clamp(amount or 0, 0, 1)

    return {
        (color[1] or 1) * multiplier,
        (color[2] or 1) * multiplier,
        (color[3] or 1) * multiplier,
        color[4] or 1,
    }
end

local function ClearTalentRankCache()
    talentRankCache = {}
end

local function ClearKnownPlayerSpellCache()
    knownPlayerSpellCache = {}
end

local function RefreshSpecState()
    local specID

    if GetSpecialization and GetSpecializationInfo then
        local specIndex = GetSpecialization()
        if specIndex then
            specID = GetSpecializationInfo(specIndex)
        end
    end

    if specID ~= currentSpecID then
        currentSpecID = specID
        currentSpecKey = SPEC_KEYS[specID]
        ClearTalentRankCache()
        return true
    end

    return false
end

local function GetDisplayedSoulShards()
    local raw = UnitPower("player", POWER_SOUL_SHARDS, true)
    local maxRaw = UnitPowerMax("player", POWER_SOUL_SHARDS, true)
    local displayMod = UnitPowerDisplayMod(POWER_SOUL_SHARDS)

    if not displayMod or displayMod <= 0 then
        displayMod = 1
    end

    local current = raw / displayMod
    local maximum = maxRaw / displayMod

    if UnitAffectingCombat and not UnitAffectingCombat("player") then
        current = math.floor(current + 0.0001)
    end

    return current, maximum
end

local function GetCurrentSpecID()
    if not currentSpecID then
        RefreshSpecState()
    end

    return currentSpecID
end

local function IsDemonologySpec()
    return GetCurrentSpecID() == DEMONOLOGY_SPEC_ID
end

local function IsAfflictionSpec()
    return GetCurrentSpecID() == AFFLICTION_SPEC_ID
end

local function IsDestructionSpec()
    return GetCurrentSpecID() == DESTRUCTION_SPEC_ID
end

local function GetCurrentSpecKey()
    if not currentSpecKey then
        RefreshSpecState()
    end

    return currentSpecKey
end

local function IsPredictiveSpecSettingEnabled(settings)
    local specKey = GetCurrentSpecKey()
    if not specKey then
        return false
    end

    return settings and settings[specKey] == true
end

local function IsPredictiveBuilderEnabled()
    return IsPredictiveSpecSettingEnabled(SmartSoulShardsDB.predictiveBuildersBySpec)
end

local function IsPredictiveSpenderEnabled()
    return IsPredictiveSpecSettingEnabled(SmartSoulShardsDB.predictiveSpendersBySpec)
end

local function IsKnownPlayerSpell(spellID)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        if Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player then
            return C_SpellBook.IsSpellKnown(spellID, Enum.SpellBookSpellBank.Player)
        end

        return C_SpellBook.IsSpellKnown(spellID)
    end

    -- Old global API IsPlayerSpell is deprecated; if C_SpellBook isn't available,
    -- assume unknown to avoid using deprecated functions.
    return false
end

local function IsCachedKnownPlayerSpell(spellID)
    if knownPlayerSpellCache[spellID] == nil then
        knownPlayerSpellCache[spellID] = IsKnownPlayerSpell(spellID) == true
    end

    return knownPlayerSpellCache[spellID]
end

-- ------------------------------------------------------------
-- Talent and spell prediction rules
-- ------------------------------------------------------------

local function IsDominionOfArgusTalentKnown()
    return IsCachedKnownPlayerSpell(DOMINION_OF_ARGUS_TALENT_ID)
end

local function IsDarkHarvestTalentKnown()
    return IsCachedKnownPlayerSpell(SHADOW_OF_DEATH_TALENT_ID)
end

local function IsShadowOfDeathTalentKnown()
    return IsCachedKnownPlayerSpell(SHADOW_OF_DEATH_TALENT_ID)
end

local function GetTalentRank(spellID)
    local configID = C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
    if talentRankCache[spellID] and talentRankCache[spellID].configID == configID then
        return talentRankCache[spellID].rank
    end

    if not configID
        or not C_Traits
        or not C_Traits.GetConfigInfo
        or not C_Traits.GetTreeNodes
        or not C_Traits.GetNodeInfo
        or not C_Traits.GetEntryInfo
        or not C_Traits.GetDefinitionInfo
    then
        talentRankCache[spellID] = { configID = configID, rank = 0 }
        return 0
    end

    local configInfo = C_Traits.GetConfigInfo(configID)
    if not configInfo or not configInfo.treeIDs then
        talentRankCache[spellID] = { configID = configID, rank = 0 }
        return 0
    end

    local bestRank = 0

    for _, treeID in ipairs(configInfo.treeIDs) do
        local nodes = C_Traits.GetTreeNodes(treeID)
        if nodes then
            for _, nodeID in ipairs(nodes) do
                local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
                if nodeInfo and nodeInfo.entryIDs then
                    for _, entryID in ipairs(nodeInfo.entryIDs) do
                        local entryInfo = C_Traits.GetEntryInfo(configID, entryID)
                        if entryInfo and entryInfo.definitionID then
                            local definitionInfo = C_Traits.GetDefinitionInfo(entryInfo.definitionID)
                            if definitionInfo and definitionInfo.spellID == spellID then
                                local rank = nodeInfo.currentRank or nodeInfo.ranksPurchased or 0
                                bestRank = math.max(bestRank, rank)
                            end
                        end
                    end
                end
            end
        end
    end

    talentRankCache[spellID] = { configID = configID, rank = bestRank }
    return bestRank
end

local function ClearApexRefundWindow()
    apexRefundExpiresAt = 0

    if apexRefundTimer then
        apexRefundTimer:Cancel()
        apexRefundTimer = nil
    end
end

local function IsApexRefundWindowActive()
    if not IsDominionOfArgusTalentKnown() then
        ClearApexRefundWindow()
        return false
    end

    if apexRefundExpiresAt <= 0 then
        return false
    end

    if GetTime() >= apexRefundExpiresAt then
        ClearApexRefundWindow()
        return false
    end

    return true
end

local function StartApexRefundWindow()
    if not IsDominionOfArgusTalentKnown() then
        ClearApexRefundWindow()
        return
    end

    apexRefundExpiresAt = GetTime() + DOMINION_OF_ARGUS_REFUND_WINDOW_SECONDS

    if apexRefundTimer then
        apexRefundTimer:Cancel()
    end

    if C_Timer then
        apexRefundTimer = C_Timer.NewTimer(DOMINION_OF_ARGUS_REFUND_WINDOW_SECONDS, function()
            ClearApexRefundWindow()
            UpdateShards()
        end)
    end

    UpdateShards()
end

local function GetHandOfGuldanPredictedSpendCost()
    local cost = DEMONOLOGY_SPENDER_SPELL_IDS[105174] or 0

    if IsApexRefundWindowActive() then
        return math.max(0, cost - 1)
    end

    return cost
end

local function GetDreadstalkersPredictedSpendCost()
    local cost = DEMONOLOGY_SPENDER_SPELL_IDS[104316] or 0
    local reduction = GetTalentRank(DREADSTALKERS_COST_REDUCTION_TALENT_ID)
    return Clamp(cost - reduction, 0, cost)
end

local function GetShardSpenderCost(spellID)
    if IsDemonologySpec() and DEMONOLOGY_SPENDER_SPELL_IDS[spellID] then
        if spellID == 105174 then -- Hand of Gul'dan
            return GetHandOfGuldanPredictedSpendCost()
        end

        if spellID == 104316 then -- Call Dreadstalkers
            return GetDreadstalkersPredictedSpendCost()
        end

        return DEMONOLOGY_SPENDER_SPELL_IDS[spellID]
    end

    if IsAfflictionSpec() and AFFLICTION_SPENDER_SPELL_IDS[spellID] then
        return AFFLICTION_SPENDER_SPELL_IDS[spellID]
    end

    if IsDestructionSpec() and DESTRUCTION_SPENDER_SPELL_IDS[spellID] then
        return DESTRUCTION_SPENDER_SPELL_IDS[spellID]
    end

    return 0
end

local function GetBuilderShards(spellID)
    if IsDemonologySpec() and DEMONOLOGY_BUILDER_SPELL_IDS[spellID] then
        if spellID == RUINATION_SPELL_ID and not IsApexRefundWindowActive() then -- Ruination
            return 0
        end

        if spellID == 265187 and not IsShadowOfDeathTalentKnown() then -- Summon Demonic Tyrant
            return 0
        end

        return DEMONOLOGY_BUILDER_SPELL_IDS[spellID]
    end

    if IsAfflictionSpec() and AFFLICTION_BUILDER_SPELL_IDS[spellID] then
        if spellID == 1257052 and not IsDarkHarvestTalentKnown() then -- Dark Harvest
            return 0
        end

        return AFFLICTION_BUILDER_SPELL_IDS[spellID]
    end

    if IsDestructionSpec() and DESTRUCTION_BUILDER_SPELL_IDS[spellID] then
        return DESTRUCTION_BUILDER_SPELL_IDS[spellID]
    end

    return 0
end

local function GetDarkHarvestRemainingShards()
    if activeBuilderSpellID ~= 1257052 then -- Dark Harvest
        return castingBuilderShards
    end

    local _, _, _, startTimeMS, endTimeMS, _, _, spellID = UnitChannelInfo("player")
    if spellID ~= 1257052 or not startTimeMS or not endTimeMS or endTimeMS <= startTimeMS then -- Dark Harvest
        return castingBuilderShards
    end

    local progress = Clamp(((GetTime() * 1000) - startTimeMS) / (endTimeMS - startTimeMS), 0, 1)

    if progress >= 2 / 3 then
        return 1
    elseif progress >= 1 / 3 then
        return 2
    end

    return AFFLICTION_BUILDER_SPELL_IDS[1257052] or 0 -- Dark Harvest
end

local function GetPlayerCastingSpellID()
    local spellID

    if UnitCastingInfo then
        spellID = select(9, UnitCastingInfo("player"))
    end

    if not spellID and UnitChannelInfo then
        spellID = select(8, UnitChannelInfo("player"))
    end

    return spellID
end

local function GetCurrentSoulShardValue()
    return GetDisplayedSoulShards()
end

-- ------------------------------------------------------------
-- Cast prediction state
-- ------------------------------------------------------------

local function StopChannelPredictionTicker()
    if channelPredictionTicker then
        channelPredictionTicker:Cancel()
        channelPredictionTicker = nil
    end
end

local function RefreshPredictionAndShards()
    RefreshPredictionCastState()
    UpdateShards()
end

local function StartChannelPredictionTicker()
    StopChannelPredictionTicker()

    if C_Timer then
        channelPredictionTicker = C_Timer.NewTicker(0.05, function()
            if activeBuilderSpellID ~= 1257052 then -- Dark Harvest
                StopChannelPredictionTicker()
                return
            end

            RefreshPredictionAndShards()
        end)
    end
end

local function ClearPredictionCastState()
    castingBuilderShards = 0
    activeBuilderSpellID = nil
    isCastingShardSpender = false
    activeShardSpenderSpellID = nil
    activePredictionSpellID = nil
    pendingShardSpenderCount = nil
    pendingBuilderShardCount = nil
    StopChannelPredictionTicker()
end

local function SetPredictionCastState(spellID)
    local builderShards = GetBuilderShards(spellID)
    local spenderCost = GetShardSpenderCost(spellID)
    local isShardSpender = spenderCost > 0

    if builderShards <= 0 and not isShardSpender then
        return
    end

    if isCastingShardSpender and pendingShardSpenderCount and not isShardSpender then
        if GetCurrentSoulShardValue() >= pendingShardSpenderCount then
            return
        end

        ClearPredictionCastState()
    end

    if castingBuilderShards > 0 and pendingBuilderShardCount and isShardSpender then
        if GetCurrentSoulShardValue() <= pendingBuilderShardCount then
            return
        end

        ClearPredictionCastState()
    end

    castingBuilderShards = builderShards
    activeBuilderSpellID = builderShards > 0 and spellID or nil
    isCastingShardSpender = isShardSpender
    activeShardSpenderSpellID = isShardSpender and spellID or nil
    activePredictionSpellID = spellID

    if isCastingShardSpender then
        pendingShardSpenderCount = GetCurrentSoulShardValue()
        pendingBuilderShardCount = nil
    elseif castingBuilderShards > 0 then
        pendingShardSpenderCount = nil
        pendingBuilderShardCount = GetCurrentSoulShardValue()
        if activeBuilderSpellID == 1257052 then -- Dark Harvest
            StartChannelPredictionTicker()
        end
    end
end

RefreshPredictionCastState = function()
    if isCastingShardSpender and pendingShardSpenderCount then
        if GetCurrentSoulShardValue() >= pendingShardSpenderCount then
            return
        end

        ClearPredictionCastState()
    end

    if activeBuilderSpellID == 1257052 and pendingBuilderShardCount then -- Dark Harvest
        local _, _, _, _, _, _, _, spellID = UnitChannelInfo("player")
        if spellID == 1257052 then -- Dark Harvest
            return
        end

        ClearPredictionCastState()
    end

    if castingBuilderShards > 0 and pendingBuilderShardCount then
        if GetCurrentSoulShardValue() <= pendingBuilderShardCount then
            return
        end

        ClearPredictionCastState()
    end

    local spellID = GetPlayerCastingSpellID()

    if spellID then
        SetPredictionCastState(spellID)
    end
end

local function ReconcileStalePredictionCastState()
    local spellID = GetPlayerCastingSpellID()
    local hasPendingSpend = isCastingShardSpender and pendingShardSpenderCount
    local hasPendingBuilder = castingBuilderShards > 0 and pendingBuilderShardCount

    if hasPendingSpend or hasPendingBuilder then
        ClearPredictionCastState()

        if spellID then
            SetPredictionCastState(spellID)
        end

        return
    end

    RefreshPredictionCastState()
end

local function ClearCompletedSpenderPrediction(spellID)
    if not isCastingShardSpender then
        return false
    end

    if spellID and spellID ~= activePredictionSpellID then
        return false
    end

    ClearPredictionCastState()
    UpdateShards()
    return true
end

local function SchedulePredictionRefresh()
    if not C_Timer then
        return
    end

    for _, delay in ipairs(PREDICTION_REFRESH_DELAYS) do
        C_Timer.After(delay, RefreshPredictionAndShards)
    end

    C_Timer.After(0.60, function()
        ReconcileStalePredictionCastState()
        UpdateShards()
    end)
end

-- ------------------------------------------------------------
-- Rendering
-- ------------------------------------------------------------

local function GetCountFontData()
    local selectedFont = SmartSoulShardsDB.countFont

    if type(selectedFont) == "string" and string.sub(selectedFont, 1, 4) == "LSM:" then
        selectedFont = string.sub(selectedFont, 5)
        SmartSoulShardsDB.countFont = selectedFont
    end

    local fontPath = media and media:Fetch("font", selectedFont, true)
    if not fontPath then
        fontPath = media and media:Fetch("font")
    end

    return {
        key = selectedFont,
        text = selectedFont,
        path = fontPath or "Fonts\\FRIZQT__.TTF",
        flags = "OUTLINE",
    }
end

local function RegisterAddonMedia()
    local media = LibStub and LibStub("LibSharedMedia-3.0", true)
    if not media or not media.Register then
        return
    end

    for _, texture in ipairs(CUSTOM_STATUSBAR_TEXTURES) do
        if texture.name and texture.path then
            media:Register("statusbar", texture.name, texture.path)
        end
    end
end

local function ApplyCountTextStyle()
    if not shardCountText then
        return
    end

    local fontData = GetCountFontData()
    shardCountText:SetFont(fontData.path, SmartSoulShardsDB.countFontSize, fontData.flags)
    shardCountText:SetTextColor(1, 1, 1, 1)
end

local function GetShardTexturePath()
    local selectedTexture = SmartSoulShardsDB.shardTexture or defaults.shardTexture
    if selectedTexture == cachedShardTextureKey and cachedShardTexturePath then
        return cachedShardTexturePath
    end

    local media = LibStub and LibStub("LibSharedMedia-3.0", true)

    if type(selectedTexture) == "string" and string.sub(selectedTexture, 1, 4) == "LSM:" then
        selectedTexture = string.sub(selectedTexture, 5)
        SmartSoulShardsDB.shardTexture = selectedTexture
    end

    local texturePath = media and media:Fetch("statusbar", selectedTexture, true)
    if texturePath then
        cachedShardTextureKey = selectedTexture
        cachedShardTexturePath = texturePath
        return texturePath
    end

    if type(selectedTexture) == "string" and selectedTexture ~= "" then
        cachedShardTextureKey = selectedTexture
        cachedShardTexturePath = selectedTexture
        return selectedTexture
    end

    cachedShardTextureKey = selectedTexture
    cachedShardTexturePath = COLOR_TEXTURE
    return COLOR_TEXTURE
end

local function SetTintedTexture(texture, color, alpha)
    local texturePath = GetShardTexturePath()
    if texture.__SmartSoulShardsTexturePath ~= texturePath then
        texture.__SmartSoulShardsTexturePath = texturePath
        texture:SetTexture(texturePath)
    end

    local r = color[1] or 1
    local g = color[2] or 1
    local b = color[3] or 1
    local a = alpha or color[4] or 1

    if texture.__SmartSoulShardsR ~= r
        or texture.__SmartSoulShardsG ~= g
        or texture.__SmartSoulShardsB ~= b
        or texture.__SmartSoulShardsA ~= a
    then
        texture.__SmartSoulShardsR = r
        texture.__SmartSoulShardsG = g
        texture.__SmartSoulShardsB = b
        texture.__SmartSoulShardsA = a
        texture:SetVertexColor(r, g, b, a)
    end
end

local function CreateCountText()
    if shardCountText then
        return shardCountText
    end

    if not shards[3] then
        return nil
    end

    shardCountText = shards[3]:CreateFontString(nil, "OVERLAY")
    ApplyCountTextStyle()
    return shardCountText
end

local function SetShardBorderColor(shard, color)
    if shard.borderColor == color then
        return
    end

    shard.borderColor = color

    for _, line in pairs(shard.borderLines or {}) do
        line:SetColorTexture(unpack(color))
    end
end

local function SetShardBackdropColor(shard, color)
    if shard.backdropColor == color then
        return
    end

    shard.backdropColor = color
    shard:SetBackdropColor(unpack(color))
end

local function SetShardAlpha(shard, alpha)
    if shard.appliedAlpha == alpha then
        return
    end

    shard.appliedAlpha = alpha
    shard:SetAlpha(alpha)
end

local function ApplyShardBaseVisuals(shard)
    local db = SmartSoulShardsDB
    local borderSize = math.max(0, db.borderSize or 0)

    shard:SetBackdrop({
        bgFile = COLOR_TEXTURE,
    })
    shard.backdropColor = nil
    SetShardBackdropColor(shard, db.inactiveColor)

    for _, line in pairs(shard.borderLines or {}) do
        line:SetShown(borderSize > 0)
    end
    shard.borderColor = nil
    SetShardBorderColor(shard, BLACK_BORDER_COLOR)

    if borderSize > 0 and shard.borderLines then
        shard.borderLines.top:ClearAllPoints()
        shard.borderLines.bottom:ClearAllPoints()
        shard.borderLines.left:ClearAllPoints()
        shard.borderLines.right:ClearAllPoints()

        shard.borderLines.top:SetPoint("TOPLEFT", shard, "TOPLEFT", 0, 0)
        shard.borderLines.top:SetPoint("TOPRIGHT", shard, "TOPRIGHT", 0, 0)
        shard.borderLines.top:SetHeight(borderSize)

        shard.borderLines.bottom:SetPoint("BOTTOMLEFT", shard, "BOTTOMLEFT", 0, 0)
        shard.borderLines.bottom:SetPoint("BOTTOMRIGHT", shard, "BOTTOMRIGHT", 0, 0)
        shard.borderLines.bottom:SetHeight(borderSize)

        shard.borderLines.left:SetPoint("TOPLEFT", shard, "TOPLEFT", 0, -borderSize)
        shard.borderLines.left:SetPoint("BOTTOMLEFT", shard, "BOTTOMLEFT", 0, borderSize)
        shard.borderLines.left:SetWidth(borderSize)

        shard.borderLines.right:SetPoint("TOPRIGHT", shard, "TOPRIGHT", 0, -borderSize)
        shard.borderLines.right:SetPoint("BOTTOMRIGHT", shard, "BOTTOMRIGHT", 0, borderSize)
        shard.borderLines.right:SetWidth(borderSize)
    end
end

local function UpdateShardFill(shard, fillAmount, threshold)
    local db = SmartSoulShardsDB
    local border = math.max(0, db.borderSize or 0)

    local innerWidth = math.max(1, db.width - border * 2)
    local innerHeight = math.max(1, db.height - border * 2)

    shard.fill:ClearAllPoints()
    SetTintedTexture(shard.fill, GetShardColorData(threshold))
    shard.fill:SetWidth(math.max(0.01, innerWidth * fillAmount))
    shard.fill:SetHeight(innerHeight)
    shard.fill:SetPoint("LEFT", shard, "LEFT", border, 0)
end

local function UpdateShardPrediction(shard, predictionType, threshold, spanStart, spanEnd)
    if not predictionType then
        shard.prediction:Hide()
        return
    end

    local db = SmartSoulShardsDB
    local border = math.max(0, db.borderSize or 0)
    local innerWidth = math.max(1, db.width - border * 2)
    local innerHeight = math.max(1, db.height - border * 2)

    spanStart = Clamp(spanStart or 0, 0, 1)
    spanEnd = Clamp(spanEnd or 1, 0, 1)

    if spanEnd <= spanStart then
        shard.prediction:Hide()
        return
    end

    shard.prediction:ClearAllPoints()
    shard.prediction:SetSize(math.max(0.01, innerWidth * (spanEnd - spanStart)), innerHeight)
    shard.prediction:SetPoint("LEFT", shard, "LEFT", border + innerWidth * spanStart, 0)

    if predictionType == "SPEND" then
        SetTintedTexture(shard.prediction, { 1, 1, 1, 1 }, 0.45)
    else
        local color = DarkenColor(GetShardColorData(threshold), 0.25)
        SetTintedTexture(shard.prediction, color, 0.8)
    end

    shard.prediction:Show()
end

local function UpdateCountText(current, predictedCount)
    local countText = CreateCountText()
    if not countText then
        return
    end

    local value = Clamp(predictedCount or current, 0, SHARD_COUNT)

    if predictedCount then
        if IsDestructionSpec() then
            countText:SetText("*" .. string.format("%.1f", value) .. "*")
        else
            countText:SetText("*" .. math.floor(value + 0.0001) .. "*")
        end
    elseif IsDestructionSpec() then
        countText:SetText(string.format("%.1f", value))
    else
        countText:SetText(tostring(math.floor(value + 0.0001)))
    end

    countText:Show()
end

local function CreateShard()
    local shard = CreateFrame("Frame", nil, SSS, "BackdropTemplate")
    shard:SetSize(SmartSoulShardsDB.width, SmartSoulShardsDB.height)

    shard.borderLines = {
        top = shard:CreateTexture(nil, "BORDER"),
        bottom = shard:CreateTexture(nil, "BORDER"),
        left = shard:CreateTexture(nil, "BORDER"),
        right = shard:CreateTexture(nil, "BORDER"),
    }

    for _, line in pairs(shard.borderLines) do
        SetPixelSnapping(line)
    end

    shard.fill = shard:CreateTexture(nil, "ARTWORK")
    SetTintedTexture(shard.fill, SmartSoulShardsDB.soulShardColor)

    shard.prediction = shard:CreateTexture(nil, "ARTWORK", nil, 1)
    shard.prediction:Hide()

    ApplyShardBaseVisuals(shard)

    return shard
end

local function LayoutShards()
    local db = SmartSoulShardsDB
    local totalWidth = db.width * SHARD_COUNT + db.spacing * (SHARD_COUNT - 1)
    local totalHeight = db.height

    SSS:SetScale(1.0)

    SSS:SetSize(totalWidth, totalHeight)

    for i = 1, SHARD_COUNT do
        shards[i] = shards[i] or CreateShard()

        local shard = shards[i]
        shard:ClearAllPoints()
        shard:SetSize(db.width, db.height)
        ApplyShardBaseVisuals(shard)

        if i == 1 then
            shard:SetPoint("LEFT", SSS, "LEFT", 0, 0)
        else
            shard:SetPoint("LEFT", shards[i - 1], "RIGHT", db.spacing, 0)
        end
    end

    local countText = CreateCountText()
    if countText then
        countText:ClearAllPoints()
        if shards[3] then
            countText:SetPoint("CENTER", shards[3], "CENTER", 0, 0)
        else
            countText:SetPoint("CENTER", SSS, "CENTER", 0, 0)
        end
        ApplyCountTextStyle()
    end
end

UpdateShards = function()
    local editModeActive = IsEditModeActive()

    if not isWarlock and not editModeActive then
        if shardCountText then
            shardCountText:Hide()
        end
        SSS:Hide()
        return
    end

    if not editModeActive and ShouldHideForSkyriding() then
        if shardCountText then
            shardCountText:Hide()
        end
        SSS:Hide()
        return
    end

    local current, maximum = GetDisplayedSoulShards()
    maximum = math.floor(maximum + 0.5)

    if maximum <= 0 then
        if editModeActive then
            maximum = SHARD_COUNT
            current = 0
        else
            if shardCountText then
                shardCountText:Hide()
            end
            SSS:Hide()
            return
        end
    end

    local threshold = GetColorThreshold(current)
    local predictedCountTextValue
    local predictedGenerateTotal
    local predictedSpendTotal
    local builderPredictionShards = GetDarkHarvestRemainingShards()
    local predictiveBuildersEnabled = IsPredictiveBuilderEnabled()
    local predictiveSpendersEnabled = IsPredictiveSpenderEnabled()

    if predictiveBuildersEnabled and builderPredictionShards > 0 then
        predictedGenerateTotal = math.min(maximum, current + builderPredictionShards)
        predictedCountTextValue = IsDestructionSpec()
            and predictedGenerateTotal
            or math.min(maximum, math.floor(current) + builderPredictionShards)
    end

    if predictiveSpendersEnabled and isCastingShardSpender then
        local spendCost = GetShardSpenderCost(activeShardSpenderSpellID)
        if spendCost > 0 then
            predictedSpendTotal = math.max(0, current - spendCost)
            predictedCountTextValue = IsDestructionSpec()
                and predictedSpendTotal
                or math.max(0, math.floor(current) - spendCost)
        end
    end

    SSS:Show()
    if not SmartSoulShardsDB.predictiveText then
        predictedCountTextValue = nil
    end

    UpdateCountText(current, predictedCountTextValue)

    for visualIndex = 1, SHARD_COUNT do
        local shard = shards[visualIndex]
        local resourceIndex = visualIndex
        local fillAmount = 0
        local predictionType
        local predictionSpanStart
        local predictionSpanEnd

        if resourceIndex >= 1 and resourceIndex <= maximum then
            fillAmount = Clamp(current - (resourceIndex - 1), 0, 1)
        end

        local isActive = fillAmount > 0

        SetShardBackdropColor(shard, SmartSoulShardsDB.inactiveColor)
        SetShardBorderColor(shard, BLACK_BORDER_COLOR)
        UpdateShardFill(shard, fillAmount, threshold)

        if resourceIndex >= 1 and resourceIndex <= maximum then
            if predictiveSpendersEnabled and predictedSpendTotal then
                local predictedFill = Clamp(predictedSpendTotal - (resourceIndex - 1), 0, 1)
                if fillAmount > predictedFill then
                    predictionType = "SPEND"
                    predictionSpanStart = predictedFill
                    predictionSpanEnd = fillAmount
                end
            elseif predictiveBuildersEnabled and predictedGenerateTotal then
                local predictedFill = Clamp(predictedGenerateTotal - (resourceIndex - 1), 0, 1)
                if predictedFill > fillAmount then
                    predictionType = "GENERATE"
                    predictionSpanStart = fillAmount
                    predictionSpanEnd = predictedFill
                end
            end
        end

        UpdateShardPrediction(
            shard,
            predictionType,
            GetColorThreshold(predictionType == "GENERATE" and resourceIndex - 1 or resourceIndex),
            predictionSpanStart,
            predictionSpanEnd
        )

        if isActive then
            shard.fill:Show()
        else
            shard.fill:Hide()
        end

        SetShardAlpha(shard, visualIndex > maximum and 0.25 or 1)
    end
end

-- ------------------------------------------------------------
-- Blizzard shard frame handling
-- ------------------------------------------------------------

local function ForceHideFrame(frame)
    if not frame then return end

    frame:Hide()
    frame:SetAlpha(0)

    if frame.__SmartSoulShardsHidden then
        return
    end

    frame.__SmartSoulShardsHidden = true

    frame:HookScript("OnShow", function(self)
        if SmartSoulShardsDB and SmartSoulShardsDB.hideBlizzard then
            self:Hide()
            self:SetAlpha(0)
        else
            self:SetAlpha(1)
        end
    end)
end

local function ForEachBlizzardShardFrame(callback)
    local warlockPowerFrame = _G["WarlockPowerFrame"]
    if warlockPowerFrame then
        callback(warlockPowerFrame)
    end

    local playerFrame = _G["PlayerFrame"]
    if playerFrame then
        callback(playerFrame.classPowerBar)
        callback(playerFrame.ClassPowerBar)

        if playerFrame.PlayerFrameContent then
            local content = playerFrame.PlayerFrameContent

            callback(content.classPowerBar)
            callback(content.ClassPowerBar)

            if content.PlayerFrameContentMain then
                callback(content.PlayerFrameContentMain.classPowerBar)
                callback(content.PlayerFrameContentMain.ClassPowerBar)
            end
        end
    end
end

local function RestoreBlizzardShardBar()
    ForEachBlizzardShardFrame(function(frame)
        if frame and frame.__SmartSoulShardsHidden then
            frame:SetAlpha(1)
            frame:Show()
        end
    end)
end

local function HideBlizzardShardBar()
    if not SmartSoulShardsDB.hideBlizzard then
        RestoreBlizzardShardBar()
        return
    end

    ForEachBlizzardShardFrame(ForceHideFrame)
end

-- ------------------------------------------------------------
-- Layout refresh
-- ------------------------------------------------------------

local function SetLocked()
    SSS:SetMovable(false)
    SSS:EnableMouse(false)
    SSS:RegisterForDrag()
    SSS:SetScript("OnDragStart", nil)
    SSS:SetScript("OnDragStop", nil)
end

local function RefreshAll()
    LayoutShards()
    ApplyPosition()
    HideBlizzardShardBar()
    UpdateShards()
end

local function ResetSettings()
    if not isWarlock then
        return
    end

    SmartSoulShardsDB = CopyDefaults(defaults, {})
    SetLocked()
    RefreshAll()
end

local function RegisterWarlockEvents()
    if warlockEventsRegistered then
        return
    end

    warlockEventsRegistered = true

    for _, event in ipairs(WARLOCK_EVENTS) do
        SSS:RegisterEvent(event)
    end
end

local function DisableForNonWarlock()
    isWarlock = false
    ClearApexRefundWindow()
    ClearPredictionCastState()

    if visibilityRefreshTicker then
        visibilityRefreshTicker:Cancel()
        visibilityRefreshTicker = nil
    end

    SSS:UnregisterAllEvents()
    SSS:Hide()

    if shardCountText then
        shardCountText:Hide()
    end
end

-- ------------------------------------------------------------
-- Edit Mode settings
-- ------------------------------------------------------------

local function GetLibEditMode()
    if addon.LibEditMode then
        return addon.LibEditMode
    end

    return LibStub and LibStub("LibEditMode", true)
end

local function GetEditModeSettingType(kind)
    local lib = GetLibEditMode()

    if lib and lib.SettingType and lib.SettingType[kind] then
        return lib.SettingType[kind]
    end

    return Enum.EditModeSettingDisplayType[kind]
end

local function CreateColorFromTable(color)
    return CreateColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
end

local function SetColorTable(colorTable, color)
    local r, g, b, a = color:GetRGBA()
    colorTable[1] = r
    colorTable[2] = g
    colorTable[3] = b
    colorTable[4] = a or 1
end

local function CreateLibEditModeCheckbox(name, defaultValue, getter, setter)
    return {
        name = name,
        kind = GetEditModeSettingType("Checkbox"),
        default = defaultValue,
        get = function()
            return getter()
        end,
        set = function(_, value)
            if getter() ~= value then
                setter(value)
                RefreshAll()
                QueueVisibilityRefresh()
            end
        end,
    }
end

local function CreateLibEditModeSlider(name, defaultValue, minValue, maxValue, step, getter, setter)
    step = 1

    return {
        name = name,
        kind = GetEditModeSettingType("Slider"),
        default = defaultValue,
        get = function()
            return math.floor((getter() or defaultValue) + 0.5)
        end,
        set = function(_, value)
            value = math.floor((tonumber(value) or defaultValue) + 0.5)

            if getter() ~= value then
                setter(value)
                RefreshAll()
            end
        end,
        minValue = minValue,
        maxValue = maxValue,
        valueStep = step,
    }
end

local function CreateLibEditModeColor(lib, name, defaultColor, colorGetter)
    return {
        name = name,
        kind = lib.SettingType.ColorPicker,
        default = CreateColorFromTable(defaultColor),
        hasOpacity = true,
        get = function()
            return CreateColorFromTable(colorGetter())
        end,
        set = function(_, color)
            SetColorTable(colorGetter(), color)
            RefreshAll()
        end,
    }
end

local function GetCountFontValues()
    local values = {}

    local media = LibStub and LibStub("LibSharedMedia-3.0", true)
    if media and media.List then
        local fonts = media:List("font") or {}
        table.sort(fonts)

        for _, fontName in ipairs(fonts) do
            table.insert(values, {
                text = fontName,
                value = fontName,
            })
        end
    end

    return values
end

local function GetShardTextureValues()
    local values = {}

    local media = LibStub and LibStub("LibSharedMedia-3.0", true)
    if media and media.List then
        local textures = media:List("statusbar") or {}
        table.sort(textures)

        for _, textureName in ipairs(textures) do
            local texturePath = media:Fetch("statusbar", textureName, true)
            local text = textureName

            if texturePath then
                text = "|T" .. texturePath .. ":14:64:0:0|t " .. textureName
            end

            table.insert(values, {
                text = text,
                value = textureName,
            })
        end
    end

    return values
end

local function GetSpecDropdownValues()
    local values = {}

    for _, specData in ipairs(SPEC_OPTIONS) do
        table.insert(values, {
            text = Text(specData.textKey),
            value = specData.key,
        })
    end

    return values
end

local function GetEnabledPredictiveSpecValues(settings)
    local values = {}

    for _, specData in ipairs(SPEC_OPTIONS) do
        if settings and settings[specData.key] then
            table.insert(values, specData.key)
        end
    end

    return values
end

local function TogglePredictiveSpecSetting(settings, specKey)
    settings[specKey] = not settings[specKey]
end

local function SetPredictiveSpecSettingsFromValues(settings, values)
    for _, specData in ipairs(SPEC_OPTIONS) do
        settings[specData.key] = false
    end

    for _, specKey in ipairs(values or {}) do
        settings[specKey] = true
    end
end

local function CreatePredictiveSpecDropdown(name, settingsGetter, defaultSettings)
    return {
        name = name,
        kind = GetEditModeSettingType("Dropdown"),
        multiple = true,
        default = GetEnabledPredictiveSpecValues(defaultSettings),
        values = GetSpecDropdownValues,
        get = function()
            return GetEnabledPredictiveSpecValues(settingsGetter())
        end,
        set = function(_, specKey)
            if type(specKey) == "table" then
                SetPredictiveSpecSettingsFromValues(settingsGetter(), specKey)
            else
                TogglePredictiveSpecSetting(settingsGetter(), specKey)
            end
            RefreshAll()
        end,
    }
end

local function RegisterLibEditModeIntegration()
    if not isWarlock then
        return false
    end

    if libEditModeRegistered then
        return true
    end

    local lib = GetLibEditMode()
    if not lib then
        return false
    end

    lib:RegisterCallback("enter", function()
        SetEditModeControlsActive(true)
        UpdateShards()
    end)

    lib:RegisterCallback("exit", function()
        SetEditModeControlsActive(false)
    end)

    lib:RegisterCallback("layout", function()
        ApplyPosition()
        UpdateShards()
    end)

    lib:AddFrame(SSS, function(_, layoutName, point, x, y)
        SavePositionForLayout(layoutName, point, x, y)
        UpdateShards()
    end, {
        point = defaults.point,
        x = defaults.x,
        y = defaults.y,
    }, Text("ADDON_NAME"))

    local settings = {
        { name = Text("SECTION_LAYOUT"), kind = lib.SettingType.Divider },
        CreateLibEditModeCheckbox(Text("HIDE_BLIZZARD_BAR"), defaults.hideBlizzard,
            function() return SmartSoulShardsDB.hideBlizzard end,
            function(value) SmartSoulShardsDB.hideBlizzard = value end
        ),
        CreateLibEditModeCheckbox(Text("HIDE_WHILE_SKYRIDING"), defaults.hideWhileSkyriding,
            function() return SmartSoulShardsDB.hideWhileSkyriding end,
            function(value) SmartSoulShardsDB.hideWhileSkyriding = value end
        ),
        CreatePredictiveSpecDropdown(Text("PREDICTIVE_BUILDERS"),
            function() return SmartSoulShardsDB.predictiveBuildersBySpec end,
            defaults.predictiveBuildersBySpec
        ),
        CreatePredictiveSpecDropdown(Text("PREDICTIVE_SPENDERS"),
            function() return SmartSoulShardsDB.predictiveSpendersBySpec end,
            defaults.predictiveSpendersBySpec
        ),
        CreateLibEditModeCheckbox(Text("PREDICTIVE_TEXT"), defaults.predictiveText,
            function() return SmartSoulShardsDB.predictiveText end,
            function(value) SmartSoulShardsDB.predictiveText = value end
        ),
        CreateLibEditModeSlider(Text("POSITION_X"), defaults.x, -3000, 3000, 1,
            function() return GetActivePositionValue("x") end,
            function(value) SetActivePositionValue("x", value) end
        ),
        CreateLibEditModeSlider(Text("POSITION_Y"), defaults.y, -3000, 3000, 1,
            function() return GetActivePositionValue("y") end,
            function(value) SetActivePositionValue("y", value) end
        ),
        CreateLibEditModeSlider(Text("SEGMENT_WIDTH"), defaults.width, 10, 100, 1,
            function() return SmartSoulShardsDB.width end,
            function(value) SmartSoulShardsDB.width = value end
        ),
        CreateLibEditModeSlider(Text("SEGMENT_HEIGHT"), defaults.height, 8, 80, 1,
            function() return SmartSoulShardsDB.height end,
            function(value) SmartSoulShardsDB.height = value end
        ),
        CreateLibEditModeSlider(Text("SPACING"), defaults.spacing, 0, 30, 1,
            function() return SmartSoulShardsDB.spacing end,
            function(value) SmartSoulShardsDB.spacing = value end
        ),
        CreateLibEditModeSlider(Text("BORDER_SIZE"), defaults.borderSize, 0, 6, 1,
            function() return SmartSoulShardsDB.borderSize end,
            function(value) SmartSoulShardsDB.borderSize = value end
        ),
        {
            name = Text("SHARD_TEXTURE"),
            kind = GetEditModeSettingType("Dropdown"),
            default = defaults.shardTexture,
            values = GetShardTextureValues,
            height = 240,
            get = function()
                return SmartSoulShardsDB.shardTexture
            end,
            set = function(_, value)
                if SmartSoulShardsDB.shardTexture ~= value then
                    SmartSoulShardsDB.shardTexture = value
                    RefreshAll()
                end
            end,
        },
        { name = Text("SECTION_TEXT"), kind = lib.SettingType.Divider },
        {
            name = Text("COUNT_FONT"),
            kind = GetEditModeSettingType("Dropdown"),
            default = defaults.countFont,
            values = GetCountFontValues,
            height = 240,
            get = function()
                return SmartSoulShardsDB.countFont
            end,
            set = function(_, value)
                if SmartSoulShardsDB.countFont ~= value then
                    SmartSoulShardsDB.countFont = value
                    RefreshAll()
                end
            end,
        },
        CreateLibEditModeSlider(Text("COUNT_FONT_SIZE"), defaults.countFontSize, 8, 40, 1,
            function() return SmartSoulShardsDB.countFontSize end,
            function(value) SmartSoulShardsDB.countFontSize = value end
        ),
        { name = Text("SECTION_COLORS"), kind = lib.SettingType.Divider },
        CreateLibEditModeColor(lib, Text("INACTIVE_COLOR"), defaults.inactiveColor,
            function() return SmartSoulShardsDB.inactiveColor end
        ),
        CreateLibEditModeColor(lib, Text("SOUL_SHARD_COLOR"), defaults.soulShardColor,
            function() return SmartSoulShardsDB.soulShardColor end
        ),
        CreateLibEditModeColor(lib, Text("CAPPED_SOUL_SHARD_COLOR"), defaults.cappedSoulShardColor,
            function() return SmartSoulShardsDB.cappedSoulShardColor end
        ),
    }

    lib:AddFrameSettings(SSS, settings)
    libEditModeRegistered = true
    return true
end

SetEditModeControlsActive = function(active)
    if active then
        SSS:Show()
    else
        SetLocked()
    end

    UpdateShards()
end

local function RegisterEditModeHooks()
    if not isWarlock then
        return
    end

    if RegisterLibEditModeIntegration() then
        return
    end

    if editModeHooksRegistered or not EditModeManagerFrame then
        return
    end

    editModeHooksRegistered = true

    EditModeManagerFrame:HookScript("OnShow", function()
        SetEditModeControlsActive(true)
        UpdateShards()
    end)

    EditModeManagerFrame:HookScript("OnHide", function()
        SetEditModeControlsActive(false)
    end)

    if EditModeManagerFrame:IsShown() then
        SetEditModeControlsActive(true)
    end
end



-- ------------------------------------------------------------
-- Events
-- ------------------------------------------------------------

SSS:RegisterEvent("ADDON_LOADED")
SSS:RegisterEvent("PLAYER_LOGIN")

SSS:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon ~= addonName then return end
        return
    end

    if event == "PLAYER_LOGIN" then
        if not IsPlayerWarlock() then
            DisableForNonWarlock()
            return
        end

        isWarlock = true
        SmartSoulShardsDB = CopyDefaults(defaults, SmartSoulShardsDB)
        RefreshSpecState()
        ClearKnownPlayerSpellCache()
        ClearTalentRankCache()
        RegisterAddonMedia()
        RegisterWarlockEvents()
        LayoutShards()
        ApplyPosition()
        SetLocked()
        RegisterEditModeHooks()

        if EventUtil and EventUtil.ContinueOnAddOnLoaded then
            EventUtil.ContinueOnAddOnLoaded("Blizzard_EditMode", RegisterEditModeHooks)
        elseif C_Timer then
            C_Timer.After(1, RegisterEditModeHooks)
        end

        HideBlizzardShardBar()
        UpdateShards()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        RefreshSpecState()
        ClearKnownPlayerSpellCache()
        HideBlizzardShardBar()
        QueueVisibilityRefresh()
        return
    end

    if event == "PLAYER_DEAD" then
        ClearApexRefundWindow()
        ClearPredictionCastState()
        UpdateShards()
        return
    end

    if event == "SPELL_UPDATE_USABLE" then
        UpdateShards()
        return
    end

    if VISIBILITY_REFRESH_EVENTS[event] then
        QueueVisibilityRefresh()
        return
    end

    if POWER_EVENTS[event] then
        local unit, powerType = ...
        if unit == "player" and (not powerType or powerType == POWER_SOUL_SHARDS_TOKEN) then
            RefreshPredictionAndShards()
        end
        return
    end

    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        RefreshPredictionAndShards()
        return
    end

    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        local unit = ...
        if unit == "player" then
            RefreshSpecState()
            ClearKnownPlayerSpellCache()
            ClearTalentRankCache()
            ClearPredictionCastState()
            ClearApexRefundWindow()
            HideBlizzardShardBar()
            UpdateShards()
        end
        return
    end

    if event == "SPELLS_CHANGED" then
        RefreshSpecState()
        ClearKnownPlayerSpellCache()
        ClearTalentRankCache()
        if not IsDominionOfArgusTalentKnown() then
            ClearApexRefundWindow()
        end
        if activeBuilderSpellID == 1257052 and not IsDarkHarvestTalentKnown() then -- Dark Harvest
            ClearPredictionCastState()
        end
        UpdateShards()
        return
    end

    if CAST_START_EVENTS[event] then
        local unit, _, spellID = ...
        if unit == "player" then
            spellID = GetPlayerCastingSpellID() or spellID
            SetPredictionCastState(spellID)
            UpdateShards()
        end
        return
    end

    if event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        local unit = ...
        if unit == "player" then
            RefreshPredictionAndShards()
        end
        return
    end

    if event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        local unit, _, spellID = ...
        if unit == "player" and (not spellID or spellID == activePredictionSpellID) then
            ClearPredictionCastState()
            UpdateShards()
        end
        return
    end

    if CAST_END_EVENTS[event] then
        local unit, _, spellID = ...
        if unit == "player" then
            if event == "UNIT_SPELLCAST_SUCCEEDED" and spellID == 265187 then -- Summon Demonic Tyrant
                StartApexRefundWindow()
            end

            if ClearCompletedSpenderPrediction(spellID) then
                return
            end

            SchedulePredictionRefresh()
        end
        return
    end

    if CAST_CANCEL_EVENTS[event] then
        local unit, _, spellID = ...
        if unit == "player" and spellID == activePredictionSpellID then
            ClearPredictionCastState()
            UpdateShards()
        end
    end
end)
