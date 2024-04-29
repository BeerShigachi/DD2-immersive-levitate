-- author : BeerShigachi
-- date : 29 April 2024
-- version: 3.0.2

-- CONFIG:
local MAX_ALTITUDE = 6.0
local LEVITATE_DURATION = 10.0
local FLY_SPEED_MULTIPLIER = 2.0
local LEVITATE_STAMINA_MULTIPLIER = 0.0005
local ASCEND_STAMINA_MULTIPLIER = 3.0
local RE_LEVITATE_INTERVAL = 10.0
local DISABLE_STAMINA_COST = false
local FALL_DEACCELERATE = 2000.0
local START_FALL_ANIMATION_FRAME_COUNT = 500.0
local NPC_MAX_ALTITUDE = 5.0
local NPC_LEVITATE_DURATION = 6.0

if RE_LEVITATE_INTERVAL > LEVITATE_DURATION then
    RE_LEVITATE_INTERVAL = LEVITATE_DURATION
end


local re = re
local sdk = sdk

local _pause_manager
local function GetPauseManager()
    if not _pause_manager then
        _pause_manager = sdk.get_managed_singleton("app.PauseManager")
    end
    return _pause_manager
end

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

local _player
local function GetManualPlayerPlayer()
    if not _player then
        local characterManager = GetCharacterManager()
        if characterManager then
            _player = characterManager:get_ManualPlayerPlayer()
        end
    end
    return _player
end

local _player_chara
local function GetManualPlayer()
    if not _player_chara then
        local characterManager = GetCharacterManager()
        if characterManager then
            _player_chara = characterManager:get_ManualPlayer()
        end
    end
    return _player_chara
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
        if human_action_param then
            _fall_param = human_action_param:get_FallParamProp()
        end
    end
    return _fall_param
end

local _free_fall_controller
local function GetFreeFallController()
    if not _free_fall_controller then
        local player_chara = GetManualPlayer()
        if player_chara then
            _free_fall_controller = player_chara:get_FreeFallCtrl()
        end
    end
    return _free_fall_controller
end

local _player_input_processor
local function GetPlayerInputProcessor()
    if not _player_input_processor then
        local player = GetManualPlayerPlayer()
        if player then
            _player_input_processor = player:get_field("InputProcessor")
        end
    end
    return _player_input_processor
end

local _player_track
local function GetPlayerTrack()
    if not _player_track then
        local player_input = GetPlayerInputProcessor()
        if player_input then
            _player_track = player_input:get_field("<PlayerTrack>k__BackingField")
        end
    end
    return _player_track
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
    if not _pause_manager then _pause_manager = GetPauseManager() end
    if _pause_manager:isPausedAny() then return end
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

local is_active_fall_guard = false
local args_fall_guard_start
sdk.hook(sdk.find_type_definition("app.Job01FallGuard"):get_method("start(via.behaviortree.ActionArg)"),
function (args)
    args_fall_guard_start = args

end,
function (rtval)
    local this_chara = sdk.to_managed_object(args_fall_guard_start[2]):get_field("Human"):get_field("<Chara>k__BackingField")
    if this_chara == _player_chara then
        is_active_fall_guard = true
    end
    return rtval
end)

local _caller_fall_guard
sdk.hook(sdk.find_type_definition("app.Job01FallGuard"):get_method("end(via.behaviortree.ActionArg)"),
function (args)
    _caller_fall_guard = sdk.to_managed_object(args[2]):get_field("Human"):get_field("<Chara>k__BackingField")
end,
function (rtval)
    if _caller_fall_guard == _player_chara then
        is_active_fall_guard = false
    end
    return rtval
end)


local function updateEvasionFlag()
    if _player_chara == nil then return end
    if is_active_fall_guard == false then
        if not _player_track then _player_track = GetPlayerTrack() end
        if not _free_fall_controller then _free_fall_controller = GetFreeFallController() end
        if _player_track and _free_fall_controller then
            if _free_fall_controller:get_IsActive() then
                _player_track:set_field("Evasion", true)
                _player_track:set_field("EvasionBuffer", true)
            end
        end
    end
end

local function set_fall_param()
    local fall_param = GetFallParam()
    if fall_param then
        fall_param:set_field("InterpFrameHighFall", START_FALL_ANIMATION_FRAME_COUNT)
    end
end

local function create_levitate_param(altidude, duration, origin)
    local param = sdk.find_type_definition("app.LevitateController.Parameter"):create_instance()
    param:set_field("MaxHeight", altidude)
    param:set_field("MaxKeepSec", duration)
    param:set_field("HorizontalAccel", origin["HorizontalAccel"])
    param:set_field("HorizontalMaxSpeed", origin["HorizontalMaxSpeed"])
    param:set_field("HorizontalSpeedRatio", origin["HorizontalSpeedRatio"])
    param:set_field("FallDeccel", FALL_DEACCELERATE)
    param:set_field("RiseAccel", 4.0)
    param:set_field("MaxRiseSpeed", 5.0)
    param:set_field("HorizontalDeccel", 3.8)
    return param
end

local function init_()
    _pause_manager = nil
    _characterManager = nil
    _player = nil
    _player_input_processor = nil
    _player_track = nil
    _free_fall_controller = nil
    _manualPlayerHuman = nil
    _levitateController = nil
    _humanCommonActionCtrl = nil
    _player_chara = nil
    _staminaManager = nil
    set_fall_param()
end

init_()

sdk.hook(
    sdk.find_type_definition("app.GuiManager"):get_method("OnChangeSceneType"),
    function() end,
    function(rtval)
        init_()
        return rtval
    end
)

local function set_new_levitate_param(human, cache, altidude, duration, origin_param)
    if cache == nil then
        cache = create_levitate_param(altidude, duration, origin_param)
        human["<LevitateCtrl>k__BackingField"]["Param"] = cache
    else
        human["<LevitateCtrl>k__BackingField"]["Param"] = cache
    end
end

local args_
local player_param_cache
local npc_param_cache
sdk.hook(sdk.find_type_definition("app.LevitateAction"):get_method("start(via.behaviortree.ActionArg)"),
function (args)
    args_ = args
end,
function (rtval)
    local this_human = sdk.to_managed_object(args_[2])["Human"]
    local this_param = this_human["<LevitateCtrl>k__BackingField"]["Param"]
    if this_human == _manualPlayerHuman then
        set_new_levitate_param(this_human, player_param_cache, MAX_ALTITUDE, LEVITATE_DURATION, this_param)
    else
        set_new_levitate_param(this_human, npc_param_cache, NPC_MAX_ALTITUDE, NPC_LEVITATE_DURATION, this_param)
    end
    return rtval
end)

-- perhaps use these hook when applying stamina system to npcs.
--app.LevitateAction.update(via.behaviortree.ActionArg)
--app.LevitateAction.updateLevitate()
re.on_frame(function ()
    updateOptFlySpeed()
    expendStaminaTolevitate()
    activateReLevitate()
    updateEvasionFlag()
end)