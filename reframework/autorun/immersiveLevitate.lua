-- author : BeerShigachi
-- date : 11 April 2024
-- version: 1.2.0

local re = re
local sdk = sdk

-- CONFIG:
local MAX_ALTITUDE = 6 
local LEVITATE_DURATION = 10 
local FLY_SPEED_MULTIPLIER = 2
local LEVITATE_STAMINA_MULTIPLIER = 0.0005 
local ASCEND_STAMINA_MULTIPLIER = 3
local RE_LEVITATE_INTERVAL = 1.0
local DISABLE_STAMINA_COST = false

local _characterManager
local function GetCharacterManager()
    if not _characterManager then 
        _characterManager = sdk.get_managed_singleton("app.CharacterManager") 
    end
	return _characterManager
end

local _manualPlayerHuman
local function GetManualPlayerHuman()
    if not _manualPlayerHuman then
        local characterManager = GetCharacterManager()
        if characterManager then
            _manualPlayerHuman = characterManager:get_ManualPlayerHuman()
        end
    end
    return _manualPlayerHuman
end

local _manualPlayer
local function GetManualPlayer()
    if not _manualPlayer then
        local characterManager = GetCharacterManager()
        if characterManager then
            _manualPlayer = characterManager:get_ManualPlayer()
        end
    end
    return _manualPlayer
end

local _staminaManager
local function GetStaminaManager()
    if not _staminaManager then
        local manualPlayer = GetManualPlayer()
        if manualPlayer then
            _staminaManager = manualPlayer:get_StaminaManager()
        end
    end
    return _staminaManager
end

local _levitateController
local function GetLevitateController()
    local manualPlayerHuman = GetManualPlayerHuman()
    if manualPlayerHuman then
        if _levitateController == nil then _levitateController = manualPlayerHuman:get_LevitateCtrl() end
    end
    return _levitateController
end

local _humanCommonActionCtrl
local function GetHumanCommonActionCtrl()
    local manualPlayerHuman = GetManualPlayerHuman()
    if manualPlayerHuman then
        if _humanCommonActionCtrl == nil then 
            _humanCommonActionCtrl = manualPlayerHuman:get_HumanCommonActionCtrl()
        end
    end
    return _humanCommonActionCtrl
end

local isInitialized = false
function initializeLevitateParam()
    if isInitialized then return end 
    local levitateCtrl = GetLevitateController();
    if levitateCtrl then
        local leviParams = levitateCtrl:get_field("Param")
        if leviParams then
            leviParams:set_field("MaxHeight", MAX_ALTITUDE)
            leviParams:set_field("MaxKeepSec", LEVITATE_DURATION)
            isInitialized = true
        end
    end
end

local function injectOptFlySpeed(manualPlayerHuman, levitateCtrl)
    if not manualPlayerHuman or not levitateCtrl then return end
    local defaultFlyingSpeed = manualPlayerHuman:get_field("MoveSpeedTypeValueInternal")
    if defaultFlyingSpeed < 0 then return end
    levitateCtrl:set_field("HorizontalSpeed", defaultFlyingSpeed * FLY_SPEED_MULTIPLIER)
end

local function activateReLevitate(humanCommonActionCtrl, levitateCtrl)
    if RE_LEVITATE_INTERVAL > LEVITATE_DURATION then return end
    if not levitateCtrl or not humanCommonActionCtrl then return end
    local timer = levitateCtrl:get_field("TotalTimer")
    if timer < RE_LEVITATE_INTERVAL and levitateCtrl:get_IsActive() then return end
    humanCommonActionCtrl:set_field("<IsEnableLevitate>k__BackingField", true)
end

local function expendStaminaTolevitate(levitateCtrl, staminaManager, isDisabled)
    if isDisabled then return end
    if not levitateCtrl or not staminaManager then return end
    if not levitateCtrl:get_IsActive() then return end
    local max_stamina = staminaManager:get_MaxValue()
    local cost = max_stamina * LEVITATE_STAMINA_MULTIPLIER * -1.0
    local remains = staminaManager:get_RemainingAmount()
    if remains <= 0.0  then 
        levitateCtrl:set_field("<IsActive>k__BackingField", false) 
    end
    if levitateCtrl:get_IsRise() then
        staminaManager:add(cost * ASCEND_STAMINA_MULTIPLIER, false)
    else   
        staminaManager:add(cost, false)
    end
end

function resetScript()
    _characterManager = nil
    _manualPlayerHuman = nil
    _levitateController = nil
    _humanCommonActionCtrl = nil
    _manualPlayerHuman = nil
    _staminaManager = nil
    isInitialized = false
    initializeLevitateParam()
end

local function processDeath(characterManager)
    if not characterManager then return end
    if not characterManager:get_IsManualPlayerDead() then return end
    resetScript()
end

re.on_script_reset(function ()
    initializeLevitateParam()
end)

re.on_frame(function ()
    local levitateCtrl = GetLevitateController()
    local humanCommonActionCtrl = GetHumanCommonActionCtrl()
    local characterManager = GetCharacterManager()
    local manualPlayerHuman = GetManualPlayerHuman()
    local staminaManager = GetStaminaManager()
    initializeLevitateParam()
    injectOptFlySpeed(manualPlayerHuman, levitateCtrl)
    expendStaminaTolevitate(levitateCtrl, staminaManager, DISABLE_STAMINA_COST)
    activateReLevitate(humanCommonActionCtrl, levitateCtrl)
    processDeath(characterManager)
end)