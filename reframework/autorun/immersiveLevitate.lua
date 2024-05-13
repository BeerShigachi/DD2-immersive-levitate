-- author : BeerShigachi
-- date : 13 May 2024
-- version: 3.3.1

-- CONFIG:
local MAX_ALTITUDE = 20.0 -- defalut 2.0
local MAX_ALTITUDE_DESCEND = 40.0 -- the height you can descend at once when descending mode.
local LEVITATE_DURATION = 10.0 -- default 2.8
local FLY_SPEED_MULTIPLIER = 2.0 -- set 1.0 for default speed
local HORIZONTAL_ACCELERATION = 3.0 -- default 3.0
local ASCEND_ACCELERATION = 6.0 -- default 4.0
local MAX_ASCEND_SPEED = 10.0 -- defalut 5.0 CAUTION: set this value high without setting ASCEND_ACCELERATION very high results slow speed.
local DESCEND_ACCELERATION = 6.0 -- opposite of  ASCEND_ACCELERATION
local MAX_DESCEND_SPEED = 10.0 -- opposite of MAX_ASCEND_SPEED
local HORIZONTAL_DEACCELERATION = 3.8 -- default 3.8
local LEVITATE_STAMINA_MULTIPLIER = 0.0005
local ASCEND_STAMINA_MULTIPLIER = 3.0
local RE_LEVITATE_INTERVAL = 10.0 -- set lower value like 0.5(so double tap to cancel levitate) if you dont want to flying too fast by spamming jump bottun.
local DISABLE_STAMINA_COST = false
local FALL_DEACCELERATE = 2000.0
local START_FALL_ANIMATION_FRAME_COUNT = 500.0

--[[
Stamina system for re-levitate. 
"Air sprint" means spamming re-levitate within AIR_SPRINT_THRESHOLD.
When you air sprint continuously, the cost of air sprint keeps growing (in a geometric sequence).
RE_LEVITATE_COST is used as base cost for this. To reset the cost, stop air sprinting or land on a terrain.
e.g. Let RE_LEVITATE_COST is 20.0 and COMMON_RATIO is 2.0 then the cost of air sprint grows 20.0 -> 40.0 -> 80.0 -> 160.0
set RE_LEVITATE_COST = 0.0 or AIR_SPRINT_THRESHOLD = 0.0 to diable re-levitate stamina system.
--]]
local AIR_SPRINT_THRESHOLD = 2.0 -- if you re-levitate before x sec pass it is considered as air sprinting.
local RE_LEVITATE_COST = 50.0 -- cost for re-levitate(non air sprint). used as the scale factor in a geometric sequence as well.
local COST_ONLY_AIR_SPRINT = false -- set false to enable stamina cost on non air sprinting re-levitate as well.
local COMMON_RATIO = 1.4 -- higher value to grow the cost quicker. the value between non zero positive(or less than -1.0) to less than 1.0 shrink the cost(who wants that?) 
local SIMPLIFIED = false -- set true to fix RE_LEVITATE_COST i.e. the cost of air sprint won't grow. equivalent to COMMON_RATIO = 1.0
local SAFE_AIR_SPRINT = true -- set true to block (only)air sprint automatically when insufficient stamina remains.

--[[ 
Only to interrupt spamming re-levitate. Recommend to use either this or stamina system for re-levitate.
This can be used with re-levitation stamina system but a bit complecated to find a good balance and can be broken when set wrong
If you use this with re-levitation stamina system the valeus have to be `SPAM_RE_LEVITATE_COOLDOWN < AIR_SPRINT_THRESHOLD`
e.g. SPAM_RE_LEVITATE_COOLDOWN = 0.5, AIR_SPRINT_THRESHOLD = 2.0
--]]
local SPAM_RE_LEVITATE_COOLDOWN = 0.0 -- set 0.0 to disable 

-- NPCs who can levitate seems like only pawns anyway.
local NPC_MAX_ALTITUDE = 4.0 -- default 2.0
local NPC_LEVITATE_DURATION = 6.0 -- defalut 2.8
local PAWN_FLY_SPEED_MULTIPLIER = 2.0 -- default 1.0
local NPC_HORIZONTAL_ACCELERATION = 3.0 -- defalut 3.0
local NPC_ASCEND_ACCELERATION = 4.0 -- default 4.0
local NPC_MAX_ASCEND_SPEED = 5.0 -- defalut 5.0
local NPC_HORIZONTAL_DEACCELERATION = 3.8 -- default 3.8



-- DO NOT TOUCH AFTER THIS LINE.
if RE_LEVITATE_INTERVAL > LEVITATE_DURATION then
    RE_LEVITATE_INTERVAL = LEVITATE_DURATION
end

if DESCEND_ACCELERATION > 0 then
    DESCEND_ACCELERATION = DESCEND_ACCELERATION * -1
end

if MAX_DESCEND_SPEED > 0 then
    MAX_DESCEND_SPEED = MAX_DESCEND_SPEED * -1
end

local re = re
local sdk = sdk
local _block_levitate = false

local state_holder = {
    previousRequestDash = false,
    descend_mode = false,
    cacheIsAirEvadeEnableInternal = false,
    is_active_fall_guard = false
}

local levitate_params = {
    player = nil,
    npc = nil
}

local timestamps = {
    start_pause = os.clock(),
    last_levitation_start = os.clock()
}

local function detectStateChange(state, cached_states, key)
    if state ~= cached_states[key] then
        cached_states[key] = state
        return true
    else
        return false
    end
end

local function initTable(table_, init_val)
    for k, v in pairs(table_) do
        table_[k] = init_val
    end
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


sdk.hook(sdk.find_type_definition("app.HumanCommonActionController"):get_method("disableAirEvadeAfterUsed()"),
function (args)
    local this = sdk.to_managed_object(args[2])
    if this["IsPlayer"] then
        state_holder.cacheIsAirEvadeEnableInternal = this["IsAirEvadeEnableInternal"]
    end
end)

local scale_factor = RE_LEVITATE_COST
local r = COMMON_RATIO
if SIMPLIFIED then
    r = 1.0
end
local function expendStaminaToReLevitate(stamina_manager, last)
    if os.clock() - last < AIR_SPRINT_THRESHOLD and state_holder.cacheIsAirEvadeEnableInternal == false then
        stamina_manager:add(scale_factor * -1.0, false)
        scale_factor = scale_factor * r
        local remains = stamina_manager:get_RemainingAmount()
        if SAFE_AIR_SPRINT and remains <= scale_factor  then
            _block_levitate = true
        end
    else
        -- reset the base first
        scale_factor = RE_LEVITATE_COST
        if not COST_ONLY_AIR_SPRINT and state_holder.cacheIsAirEvadeEnableInternal == false then
            print("cost normal re-levitate as well")
            stamina_manager:add(scale_factor * -1.0, false)
        end
    end
end

local function activateReLevitate(levitate_controller, human_common_action_ctrl, last)
    local levitating = levitate_controller:get_IsActive()
    local timer = levitate_controller:get_field("TotalTimer")
    if timer < RE_LEVITATE_INTERVAL and levitating then return end
    if os.clock() - last < SPAM_RE_LEVITATE_COOLDOWN or _block_levitate then return end
    human_common_action_ctrl:set_field("<IsEnableLevitate>k__BackingField", true)
end

-- there were too many situations that player stands on a ground. so perhaps checking in update is the best option.
local function resetOnGround(human_common_action_ctrl, last)
    if human_common_action_ctrl["IsAirEvadeEnableInternal"] and state_holder.descend_mode == true then
        levitate_params.player["RiseAccel"] = ASCEND_ACCELERATION
        levitate_params.player["MaxRiseSpeed"] = MAX_ASCEND_SPEED
        levitate_params.player["MaxHeight"] = MAX_ALTITUDE
        state_holder.descend_mode = false
        print("descend_mode", state_holder.descend_mode)
    end
    if human_common_action_ctrl["IsAirEvadeEnableInternal"] and scale_factor ~= RE_LEVITATE_COST then
        scale_factor = RE_LEVITATE_COST
        _block_levitate = false
    elseif not human_common_action_ctrl["IsAirEvadeEnableInternal"] and os.clock() - last > AIR_SPRINT_THRESHOLD then
        _block_levitate = false
    end
end

local function expendStaminaTolevitate(levitate_controller, stamina_manager)
    local max_stamina = stamina_manager:get_MaxValue()
    local cost = max_stamina * LEVITATE_STAMINA_MULTIPLIER * -1.0
    local remains = stamina_manager:get_RemainingAmount()
    if remains <= 0.0 then
        levitate_controller:set_field("<IsActive>k__BackingField", false)
        _block_levitate = true
        return
    end
    if levitate_controller:get_IsRise() then
        stamina_manager:add(cost * ASCEND_STAMINA_MULTIPLIER, false)
    else
        stamina_manager:add(cost, false)
    end
end


sdk.hook(sdk.find_type_definition("app.Job01FallGuard"):get_method("start(via.behaviortree.ActionArg)"),
function (args)
    local storage = thread.get_hook_storage()
    storage["this"] = sdk.to_managed_object(args[2])
end,
function (rtval)
    local this = thread.get_hook_storage()["this"]
    if this["Human"] == _manualPlayerHuman then
        state_holder.is_active_fall_guard = true
    end
    return rtval
end)

sdk.hook(sdk.find_type_definition("app.Job01FallGuard"):get_method("end(via.behaviortree.ActionArg)"),
function (args)
    local storage = thread.get_hook_storage()
    storage["this"] = sdk.to_managed_object(args[2])
end,
function (rtval)
    local this = thread.get_hook_storage()["this"]
    if this["Human"] == _manualPlayerHuman then
        state_holder.is_active_fall_guard = false
    end
    return rtval
end)

local function updateEvasionFlag()
    if state_holder.is_active_fall_guard == false then
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


sdk.hook(sdk.find_type_definition("app.LevitateAction"):get_method("start(via.behaviortree.ActionArg)"),
function (args)
    local storage = thread.get_hook_storage()
    storage["this"] = sdk.to_managed_object(args[2])
end,
function (rtval)
    local this_human = thread.get_hook_storage()["this"]["Human"]
    local this_param = this_human["<LevitateCtrl>k__BackingField"]["Param"]
    if this_human == _manualPlayerHuman then
        if levitate_params.player == nil then
            levitate_params.player = sdk.create_instance("app.LevitateController.Parameter"):add_ref()
            levitate_params.player["HorizontalMaxSpeed"] = this_param["HorizontalMaxSpeed"]
            levitate_params.player["HorizontalSpeedRatio"] = this_param["HorizontalSpeedRatio"]
            levitate_params.player["MaxHeight"] = MAX_ALTITUDE
            levitate_params.player["MaxKeepSec"] = LEVITATE_DURATION
            levitate_params.player["HorizontalAccel"] = HORIZONTAL_ACCELERATION
            levitate_params.player["FallDeccel"] = FALL_DEACCELERATE
            levitate_params.player["RiseAccel"] = ASCEND_ACCELERATION
            levitate_params.player["MaxRiseSpeed"] = MAX_ASCEND_SPEED
            levitate_params.player["HorizontalDeccel"] = HORIZONTAL_DEACCELERATION
        end
        this_human["<LevitateCtrl>k__BackingField"]["Param"] = levitate_params.player
    else
        if levitate_params.npc == nil then
            levitate_params.npc = sdk.create_instance("app.LevitateController.Parameter"):add_ref()
            levitate_params.npc["HorizontalMaxSpeed"] = this_param["HorizontalMaxSpeed"]
            levitate_params.npc["HorizontalSpeedRatio"] = this_param["HorizontalSpeedRatio"]
            levitate_params.npc["MaxHeight"] = NPC_MAX_ALTITUDE
            levitate_params.npc["MaxKeepSec"] = NPC_LEVITATE_DURATION
            levitate_params.npc["HorizontalAccel"] = NPC_HORIZONTAL_ACCELERATION
            levitate_params.npc["FallDeccel"] = FALL_DEACCELERATE
            levitate_params.npc["RiseAccel"] = NPC_ASCEND_ACCELERATION
            levitate_params.npc["MaxRiseSpeed"] = NPC_MAX_ASCEND_SPEED
            levitate_params.npc["HorizontalDeccel"] = NPC_HORIZONTAL_DEACCELERATION
        end
        this_human["<LevitateCtrl>k__BackingField"]["Param"] = levitate_params.npc
    end
    return rtval
end)


sdk.hook(sdk.find_type_definition("app.LevitateController"):get_method("start(via.vec3)"),
function (args)
    local this_transform = sdk.to_managed_object(args[2])["Trans"]
    if this_transform == _player_chara["<Transform>k__BackingField"] then
        expendStaminaToReLevitate(_player_stamina_manager, timestamps.last_levitation_start)
        timestamps.last_levitation_start = os.clock()
    end
end
)


sdk.hook(sdk.find_type_definition("app.PauseManager"):get_method("requestPause(System.Boolean, app.PauseManager.PauseType, System.String, System.Action)"),
function (args)
    local pause = (sdk.to_int64(args[3]) & 1) == 1
    if pause then
        timestamps.start_pause = os.clock()
    else
        local elapsed_pause_time = os.clock() - timestamps.start_pause
        timestamps.last_levitation_start = timestamps.last_levitation_start + elapsed_pause_time
    end
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


sdk.hook(sdk.find_type_definition("app.PlayerInputProcessor"):get_method("update()"),
function (args)
    local this = sdk.to_managed_object(args[2])
    local request = this["RequestDash"]
    if detectStateChange(request, state_holder, "previousRequestDash") then
        if request and _player_human_common_action_ctrl["IsAirEvadeEnableInternal"] == false then
            if state_holder.descend_mode then
                _player_levitate_controller["UpDownMode"] = 3
                levitate_params.player["RiseAccel"] = ASCEND_ACCELERATION
                levitate_params.player["MaxRiseSpeed"] = MAX_ASCEND_SPEED
                levitate_params.player["MaxHeight"] = MAX_ALTITUDE
                state_holder.descend_mode = false
                print("descend mode", state_holder.descend_mode)
            else
                _player_levitate_controller["UpDownMode"] = 3
                levitate_params.player["RiseAccel"] = DESCEND_ACCELERATION
                levitate_params.player["MaxRiseSpeed"] = MAX_DESCEND_SPEED
                levitate_params.player["MaxHeight"] = MAX_ALTITUDE_DESCEND
                state_holder.descend_mode = true
                print("descend mode", state_holder.descend_mode)
            end
        end
    end
end)

sdk.hook(sdk.find_type_definition("app.Player"):get_method("lateUpdate()"),
    function ()
        resetOnGround(_player_human_common_action_ctrl, timestamps.last_levitation_start) -- could do in requestLanding?
        updateEvasionFlag()
        updateOptFlySpeed(_player_levitate_controller, _manualPlayerHuman["MoveSpeedTypeValueInternal"], FLY_SPEED_MULTIPLIER)
        activateReLevitate(_player_levitate_controller, _player_human_common_action_ctrl, timestamps.last_levitation_start)
    end)

sdk.hook(sdk.find_type_definition("app.Pawn"):get_method("onLateUpdate()"),
    function (args)
        local this_pawn_human = sdk.to_managed_object(args[2])["<CachedHuman>k__BackingField"]
        -- pawns never levitate in the mid air.
        -- if this_pawn_human:get_HumanCommonActionCtrl():get_field("<IsEnableLevitate>k__BackingField") == false then
        --     print(this_pawn_human:get_HumanCommonActionCtrl(), "not able to re levitate now")
        --     this_pawn_human:get_HumanCommonActionCtrl():set_field("<IsEnableLevitate>k__BackingField", true)
        -- end
        updateOptFlySpeed(this_pawn_human:get_LevitateCtrl(), this_pawn_human["MoveSpeedTypeValueInternal"], PAWN_FLY_SPEED_MULTIPLIER)
    end)

local function init_()
    initTable(state_holder, false)
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
    _player_track = GetPlayerTrack()
    _free_fall_controller = nil
    _free_fall_controller = GetFreeFallController()
    _block_levitate = false
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
