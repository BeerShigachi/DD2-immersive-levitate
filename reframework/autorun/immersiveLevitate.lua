-- author : BeerShigachi
-- date : 29 April 2024
-- version: 3.0.4

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
local NPC_MAX_ALTITUDE = 4.0
local NPC_LEVITATE_DURATION = 6.0
local PAWN_FLY_SPEED_MULTIPLIER = 2.0

if RE_LEVITATE_INTERVAL > LEVITATE_DURATION then
    RE_LEVITATE_INTERVAL = LEVITATE_DURATION
end


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

local _player_stamina_manager
local function GetPlayerStaminaManager()
    if _player_stamina_manager == nil then
        local chara = GetManualPlayer()
        if chara then
            _player_stamina_manager = chara:get_StaminaManager()
        end
    end
    return _player_stamina_manager
end

local _player_levitate_controller
local function GetPlayerLevitateController()
    local manualPlayerHuman = GetManualPlayerHuman()
    if manualPlayerHuman then
        if _player_levitate_controller == nil then 
            _player_levitate_controller = manualPlayerHuman:get_LevitateCtrl()
        end
    end
    return _player_levitate_controller
end

local _player_human_common_action_ctrl
local function GetPlayerHumanCommonActionCtrl()
    local manualPlayerHuman = GetManualPlayerHuman()
    if manualPlayerHuman then
        if _player_human_common_action_ctrl == nil then
            _player_human_common_action_ctrl = manualPlayerHuman:get_HumanCommonActionCtrl()
        end
    end
    return _player_human_common_action_ctrl
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

local function updateOptFlySpeed(levitate_controller, default_fly_velocity, multiplier)
    if not levitate_controller:get_IsActive() or default_fly_velocity < 0 then return end
    levitate_controller:set_field("HorizontalSpeed", default_fly_velocity * multiplier)
end

local function activateReLevitate(levitate_controller, human_common_action_ctrl)
    local timer = levitate_controller:get_field("TotalTimer")
    if timer < RE_LEVITATE_INTERVAL and levitate_controller:get_IsActive() then return end
    human_common_action_ctrl:set_field("<IsEnableLevitate>k__BackingField", true)
end

local function expendStaminaTolevitate(levitate_controller, stamina_manager)
    if not levitate_controller:get_IsActive() then return end -- TODO delete.
    local max_stamina = stamina_manager:get_MaxValue()
    local cost = max_stamina * LEVITATE_STAMINA_MULTIPLIER * -1.0
    local remains = stamina_manager:get_RemainingAmount()
    if remains <= 0.0  then
        stamina_manager:set_field("<IsActive>k__BackingField", false)
    end
    if levitate_controller:get_IsRise() then -- todo maybe other function to hook
        stamina_manager:add(cost * ASCEND_STAMINA_MULTIPLIER, false)
    else
        stamina_manager:add(cost, false)
    end
end

local is_active_fall_guard = false
local args_fall_guard_start
sdk.hook(sdk.find_type_definition("app.Job01FallGuard"):get_method("start(via.behaviortree.ActionArg)"),
function (args)
    args_fall_guard_start = args

end,
function (rtval)
    if sdk.to_managed_object(args_fall_guard_start[2]):get_field("Human") == _manualPlayerHuman then
        is_active_fall_guard = true
    end
    return rtval
end)

local _args_fall_guard_end
sdk.hook(sdk.find_type_definition("app.Job01FallGuard"):get_method("end(via.behaviortree.ActionArg)"),
function (args)
    _args_fall_guard_end = args
end,
function (rtval)
    if sdk.to_managed_object(_args_fall_guard_end[2]):get_field("Human") == _manualPlayerHuman then
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

sdk.hook(sdk.find_type_definition("app.LevitateAction"):get_method("updateLevitate()"),
    function (args)
        if DISABLE_STAMINA_COST then return end
        local this_human = sdk.to_managed_object(args[2])["Human"]
        if this_human == _manualPlayerHuman then
            if _player_levitate_controller and _player_stamina_manager then
                expendStaminaTolevitate(_player_levitate_controller, _player_stamina_manager)
            end
        end
    end)

-- non player character does not re levitate with vanilla AI
-- sdk.hook(sdk.find_type_definition("app.LevitateAction"):get_method("end(via.behaviortree.ActionArg)"),
--     function (args)
--         local this_human = sdk.to_managed_object(args[2])["Human"]
--         if this_human ~= _manualPlayerHuman then
--             this_human:get_HumanCommonActionCtrl():set_field("<IsEnableLevitate>k__BackingField", true)
--             print("do pawns re levitate?")
--         end
--     end)

sdk.hook(sdk.find_type_definition("app.Player"):get_method("lateUpdate()"),
    function ()
        updateOptFlySpeed(_player_levitate_controller, _manualPlayerHuman["MoveSpeedTypeValueInternal"], FLY_SPEED_MULTIPLIER)
        activateReLevitate(_player_levitate_controller, _player_human_common_action_ctrl)
    end)

-- pawns never levitate in the mid air.
sdk.hook(sdk.find_type_definition("app.Pawn"):get_method("onLateUpdate()"),
    function (args)
        local this_pawn_human = sdk.to_managed_object(args[2])["<CachedHuman>k__BackingField"]
        updateOptFlySpeed(this_pawn_human:get_LevitateCtrl(), this_pawn_human["MoveSpeedTypeValueInternal"], PAWN_FLY_SPEED_MULTIPLIER)
    end)

re.on_frame(function ()
    updateEvasionFlag()
end)

local function init_()
    _characterManager = nil
    _player_chara = nil
    _player_chara = GetManualPlayer()
    _manualPlayerHuman = nil
    _manualPlayerHuman = GetManualPlayerHuman()
    _player_stamina_manager = nil
    _player_stamina_manager = GetPlayerStaminaManager()
    _player_levitate_controller = nil
    _player_levitate_controller = GetPlayerLevitateController()
    _player_human_common_action_ctrl = nil
    _player_human_common_action_ctrl = GetPlayerHumanCommonActionCtrl()
    _player = nil
    _player_input_processor = nil
    _player_track = nil
    _free_fall_controller = nil
    set_fall_param()
end

init_()

re.on_script_reset(function ()
    init_()
end)

sdk.hook(
    sdk.find_type_definition("app.GuiManager"):get_method("OnChangeSceneType"),
    function() end,
    function(rtval)
        init_()
        return rtval
    end
)