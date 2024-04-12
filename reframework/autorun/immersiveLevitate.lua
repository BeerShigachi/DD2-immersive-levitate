-- author : BeerShigachi
-- date : 11 April 2024
-- version: 1.2.0

-- CONFIG:
local MAX_ALTITUDE = 6
local LEVITATE_DURATION = 10
local FLY_SPEED_MULTIPLIER = 2
local LEVITATE_STAMINA_MULTIPLIER = 0.0005
local ASCEND_STAMINA_MULTIPLIER = 3
local RE_LEVITATE_INTERVAL = 1.0
local DISABLE_STAMINA_COST = false

local re = re
local sdk = sdk

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
            if not _staminaManager then
                local temp_player_ = sdk.get_managed_singleton("app.CharacterManager"):get_ManualPlayer()
                if temp_player_ then
                    _staminaManager = temp_player_:get_StaminaManager()
                end
            end
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

local function dummy_hook()
end

local function wrapped_init()
end

local function get_levitate_param_obj()
    local _levitate_ctrl = GetLevitateController()
    local _levitate_param
        if  _levitate_ctrl then
            _levitate_param = _levitate_ctrl:get_field("Param")
        end
    return _levitate_param
end

local function set_levitate_param_inner(param)
    param:set_field("MaxHeight", MAX_ALTITUDE)
    param:set_field("MaxKeepSec", LEVITATE_DURATION)
end

local function init_levitate_param()
    local _levitate_param = get_levitate_param_obj()
    if _levitate_param then
        set_levitate_param_inner(_levitate_param)
        wrapped_init = function ()
            return dummy_hook()
        end
    end
end

function ResetScript(...)
    _characterManager = nil
    _manualPlayerHuman = nil
    _levitateController = nil
    _humanCommonActionCtrl = nil
    _manualPlayerHuman = nil
    _staminaManager = nil
    wrapped_init = function ()
        return init_levitate_param()
    end
    return ...
end

wrapped_init = function ()
    return init_levitate_param()
end

sdk.hook(sdk.find_type_definition("app.Player"):get_method(".ctor"), dummy_hook, ResetScript)


sdk.hook(sdk.find_type_definition("app.LevitateController"):get_method("get_IsRise"),
    dummy_hook,
    function (...)
        wrapped_init()
        return ...
    end)

re.on_frame(function ()
    local levitateCtrl = GetLevitateController()
    local humanCommonActionCtrl = GetHumanCommonActionCtrl()
    local manualPlayerHuman = GetManualPlayerHuman()
    local staminaManager = GetStaminaManager()
    injectOptFlySpeed(manualPlayerHuman, levitateCtrl)
    expendStaminaTolevitate(levitateCtrl, staminaManager, DISABLE_STAMINA_COST)
    activateReLevitate(humanCommonActionCtrl, levitateCtrl)
end)