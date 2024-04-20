-- author : BeerShigachi
-- date : 13 April 2024
-- version: 1.3.0

-- CONFIG:
local MAX_ALTITUDE = 6.0
local LEVITATE_DURATION = 10.0
local FLY_SPEED_MULTIPLIER = 2.0
local LEVITATE_STAMINA_MULTIPLIER = 0.0005
local ASCEND_STAMINA_MULTIPLIER = 3.0
local RE_LEVITATE_INTERVAL = 10.0
local DISABLE_STAMINA_COST = false
local FALL_DEACCELERATE = 1000.0

if RE_LEVITATE_INTERVAL > LEVITATE_DURATION then
    RE_LEVITATE_INTERVAL = LEVITATE_DURATION
end

local FRAME_HIGH_FALL = 500.0
local CALLCEL_FALL_THRESHOLD = 500.0
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

local _human_param
local function GetHumanParam()
    if not _human_param then
        local characterManager = GetCharacterManager()
        if characterManager then
            _human_param = characterManager:get_HumanParam()
        end
    end
    return _human_param
end

local _human_action_param
local function GetHumanActionParam()
    if not _human_action_param then
        local human_param = GetHumanParam()
        print("human param", human_param)
        if human_param then
            _human_action_param = human_param:get_Action()
        end
    end
    return _human_action_param
end

local _fall_param
local function GetFallParam()
    if not _fall_param then
        local human_action_param = GetHumanActionParam()
        print('human action param', human_action_param)
        if human_action_param then
            _fall_param = human_action_param:get_FallParamProp()
        end
    end
    return _fall_param
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

local function updateOptFlySpeed()
    if not _manualPlayerHuman then _manualPlayerHuman = GetManualPlayerHuman() end
    if not _levitateController then _levitateController = GetLevitateController() end
    if not _manualPlayerHuman or not _levitateController then return end
    local defaultFlyingSpeed = _manualPlayerHuman:get_field("MoveSpeedTypeValueInternal")
    if defaultFlyingSpeed < 0 then return end
    _levitateController:set_field("HorizontalSpeed", defaultFlyingSpeed * FLY_SPEED_MULTIPLIER)
end

local function activateReLevitate()
    if RE_LEVITATE_INTERVAL > LEVITATE_DURATION then return end
    if not _levitateController then _levitateController = GetLevitateController() end
    if not _humanCommonActionCtrl then _humanCommonActionCtrl = GetHumanCommonActionCtrl() end
    if not _levitateController or not _humanCommonActionCtrl then return end
    local timer = _levitateController:get_field("TotalTimer")
    if timer < RE_LEVITATE_INTERVAL and _levitateController:get_IsActive() then return end
    _humanCommonActionCtrl:set_field("<IsEnableLevitate>k__BackingField", true)
end

local function expendStaminaTolevitate()
    if DISABLE_STAMINA_COST then return end
    if not _levitateController then _levitateController = GetLevitateController() end
    if not _staminaManager then _staminaManager = GetStaminaManager() end
    if not _levitateController or not _staminaManager then return end
    if not _levitateController:get_IsActive() then return end
    local max_stamina = _staminaManager:get_MaxValue()
    local cost = max_stamina * LEVITATE_STAMINA_MULTIPLIER * -1.0
    local remains = _staminaManager:get_RemainingAmount()
    if remains <= 0.0  then
        _levitateController:set_field("<IsActive>k__BackingField", false)
    end
    if _levitateController:get_IsRise() then
        _staminaManager:add(cost * ASCEND_STAMINA_MULTIPLIER, false)
    else
        _staminaManager:add(cost, false)
    end
end

local function set_fall_param()
    local fall_param = GetFallParam()
    print("fall_param", fall_param)
    if fall_param then
        fall_param:set_field("InterpFrameHighFall", FRAME_HIGH_FALL)
        fall_param:set_field("FrameEnableCancel", CALLCEL_FALL_THRESHOLD)

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
    param:set_field("FallDeccel", FALL_DEACCELERATE)
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

local function init_()
    _characterManager = nil
    _manualPlayerHuman = nil
    _levitateController = nil
    _humanCommonActionCtrl = nil
    _manualPlayer = nil
    _staminaManager = nil
    wrapped_init = function ()
        return init_levitate_param()
    end
    set_fall_param()
end

wrapped_init = function ()
    return init_levitate_param()
end

sdk.hook(
    sdk.find_type_definition("app.GuiManager"):get_method("OnChangeSceneType"),
    function() end,
    function(rtval)
        init_()
        return rtval
    end
)

-- try app.LevitateController.Parameter..ctor()
sdk.hook(sdk.find_type_definition("app.LevitateController"):get_method("get_IsRise"),
    dummy_hook,
    function (...)
        wrapped_init()
        return ...
    end)

re.on_frame(function ()
    updateOptFlySpeed()
    expendStaminaTolevitate()
    activateReLevitate()
end)