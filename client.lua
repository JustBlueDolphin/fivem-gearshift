local vehicle, previousGear, override = 0, nil, nil
local active, loadingSince, loadFailed = nil, nil, false
local lastPlayed = -10000
local enabled = Config.Enabled
local resolvedProfile, currentPed = nil, nil
local lastLoadRequest = -10000

local function message(text)
    print(('[gearshift] %s'):format(text))
    TriggerEvent('chat:addMessage', { args = { 'Gearshift', text } })
end
local function driverVehicle()
    local ped = PlayerPedId()
    if IsEntityDead(ped) or not IsPedInAnyVehicle(ped, false) then return 0, ped end
    local v = GetVehiclePedIsIn(ped, false)
    local model = GetEntityModel(v)
    if GetPedInVehicleSeat(v, -1) ~= ped or not Config.EnabledClasses[GetVehicleClass(v)]
        or Config.Vehicles[model] == false then return 0, ped end
    return v, ped
end
local function profileFor(v)
    return override or resolvedProfile
end
local function detectHand(v)
    local bone = GetEntityBoneIndexByName(v, 'seat_dside_f')
    if bone ~= -1 then
        local world = GetWorldPositionOfEntityBone(v, bone)
        local seat = GetOffsetFromEntityGivenWorldCoords(v, world.x, world.y, world.z)
        if seat.x > 0.10 then return 'left' end
        if seat.x < -0.10 then return 'right' end
    end
    return Config.FallbackHand
end
local function stopOwnAnimation()
    if active and DoesEntityExist(active.ped) then
        StopAnimTask(active.ped, Config.Dictionary, active.clip, 4.0)
    end
    active = nil
end
local function refresh(v)
    local ped = PlayerPedId()
    if v == vehicle and currentPed == ped then return end
    stopOwnAnimation()
    vehicle, previousGear, override = v, nil, nil
    currentPed, resolvedProfile = ped, nil
    loadingSince, loadFailed = nil, false
    lastLoadRequest = -10000
    lastPlayed = -10000
    if v ~= 0 then
        resolvedProfile = Gearshift.resolve(Config.Default, Config.ClassProfiles[GetVehicleClass(v)],
            Config.Vehicles[GetEntityModel(v)], detectHand(v), GetVehicleHighGear(v))
    end
end
local function ready()
    if HasAnimDictLoaded(Config.Dictionary) then return true end
    if loadFailed then return false end
    if not loadingSince then
        loadingSince = GetGameTimer()
    elseif GetGameTimer() - loadingSince > Config.LoadTimeoutMs then
        loadFailed = true
        message('Could not load gearshift.ycd; check the stream folder. Re-enter the car to retry.')
    end
    if not loadFailed and GetGameTimer() - lastLoadRequest >= 500 then
        RequestAnimDict(Config.Dictionary)
        lastLoadRequest = GetGameTimer()
    end
    return false
end
local function play(direction, gear)
    local v, ped = driverVehicle()
    refresh(v)
    if v == 0 then return false, 'not_driver' end
    if not enabled then return false, 'disabled' end
    if IsPedDoingDriveby(ped) or IsPedRagdoll(ped) or IsControlPressed(0, 75) then
        return false, 'ped_busy'
    end
    local profile = Gearshift.playbackProfile(profileFor(v), gear)
    local clip = Gearshift.clip(profile, direction, gear)
    if not clip then return false, 'invalid_shift_or_profile' end
    if not ready() then return false, 'dictionary_not_loaded' end
    if GetAnimDuration(Config.Dictionary, clip) <= 0 then return false, 'clip_not_found: ' .. clip end
    local now = GetGameTimer()
    if now - lastPlayed < Config.CooldownMs then return false, 'cooldown' end
    stopOwnAnimation()
    -- Native tail arguments are startPhase, phaseControlled, controlFlags,
    -- overrideCloneUpdate (older native docs misleadingly call them playbackRate/lockXYZ).
    -- Start at phase zero; phase 1.0 starts at the END of this one-shot clip.
    -- Control flag 2 disables arm IK for this task without changing global ped IK.
    TaskPlayAnim(ped, Config.Dictionary, clip, 8.0, -8.0,
        Config.Durations[profile.style], 48, 0.0, false, Config.ReleaseArmIK and 2 or 0, false)
    active = { ped = ped, clip = clip,
        untilTime = now + Config.Durations[profile.style] + 150 }
    lastPlayed = now
    return true
end

exports('PlayShift', play)
exports('SetEnabled', function(value)
    if type(value) ~= 'boolean' then return false end
    enabled = value
    if not enabled then stopOwnAnimation() end
    return true
end)

local function diagnose()
    local v = driverVehicle(); refresh(v)
    message(('Resource %s v%s; enabled=%s; dictionary=%s exists=%s loaded=%s'):format(
        GetCurrentResourceName(), GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '?',
        tostring(enabled), Config.Dictionary, tostring(DoesAnimDictExist(Config.Dictionary)),
        tostring(HasAnimDictLoaded(Config.Dictionary))))
    if v == 0 then
        message('Not recognised as a supported vehicle driver. Check seat, class and model exclusions.')
        return
    end
    local p = profileFor(v)
    local clip = Gearshift.clip(p, 'up', 2)
    message(('class=%s gear=%s highGear=%s style=%s hand=%s mode=%s armIKRelease=%s'):format(
        GetVehicleClass(v), GetVehicleCurrentGear(v), GetVehicleHighGear(v), p.style,p.hand,p.mode,
        tostring(Config.ReleaseArmIK)))
    if HasAnimDictLoaded(Config.Dictionary) then
        message(('Test clip %s duration=%.3fs; playing=%s'):format(clip or '?',
            clip and GetAnimDuration(Config.Dictionary, clip) or 0,
            tostring(active ~= nil and IsEntityPlayingAnim(active.ped,Config.Dictionary,active.clip,3))))
    else
        loadingSince, loadFailed, lastLoadRequest = nil, false, -10000
        ready()
        message('Requested dictionary loading. Run /gearshift diagnose again in a few seconds.')
    end
end
exports('GetProfile', function()
    local v = driverVehicle(); refresh(v)
    if v == 0 then return nil end
    local p = profileFor(v)
    return { style = p.style, hand = p.hand, mode = p.mode, enabled = enabled }
end)
exports('SetProfile', function(style, hand, mode)
    local v = driverVehicle()
    refresh(v)
    local candidate = { style = style, hand = hand, mode = mode or 'external' }
    if v == 0 or not Gearshift.validProfile(candidate) then return false end
    stopOwnAnimation()
    override = candidate
    previousGear = GetVehicleCurrentGear(v)
    return true
end)
exports('ResetProfile', function()
    stopOwnAnimation(); override = nil
    previousGear = vehicle ~= 0 and GetVehicleCurrentGear(vehicle) or nil
end)

CreateThread(function()
    while true do
        local v, ped = driverVehicle()
        refresh(v)
        if v ~= 0 then
            if enabled then ready() end
            local gear = GetVehicleCurrentGear(v)
            local profile = profileFor(v)
            -- GTA gear 0 cannot reliably distinguish a manual neutral selection.
            -- Automatic mode intentionally animates forward gear changes only.
            if enabled and Gearshift.validProfile(profile) and profile.mode == 'auto'
                and previousGear and previousGear > 0 and gear > 0 and gear ~= previousGear then
                play(gear > previousGear and 'up' or 'down', gear)
            end
            previousGear = gear
            if active and (GetGameTimer() > active.untilTime or IsPedDoingDriveby(ped) or IsPedRagdoll(ped)
                or IsControlPressed(0, 75)) then stopOwnAnimation() end
        end
        Wait(v ~= 0 and Config.PollMs or 300)
    end
end)

RegisterCommand('gearshift', function(_, args)
    local value = args[1] or 'status'
    if value == 'on' or value == 'off' then
        enabled = value == 'on'
        if not enabled then stopOwnAnimation() end
        message('Animations ' .. (enabled and 'enabled.' or 'disabled.'))
    elseif value == 'diagnose' then diagnose()
    elseif value == 'status' then
        local v = driverVehicle(); refresh(v)
        local p = v ~= 0 and profileFor(v) or nil
        message(('Animations %s. %s'):format(enabled and 'on' or 'off', p
            and ('Style %s, hand %s, mode %s.'):format(p.style, p.hand, p.mode)
            or 'Enter a supported road vehicle as driver.'))
    else message('/gearshift on|off|status|diagnose') end
end, false)

if Config.TestCommands then
    RegisterCommand('shiftstyle', function(_, args)
        local v = driverVehicle(); refresh(v)
        if args[1] == 'reset' then
            stopOwnAnimation(); override = nil; message('Vehicle defaults restored.'); return
        end
        local p = { style = args[1], hand = args[2] or (v ~= 0 and profileFor(v).hand or Config.FallbackHand), mode = args[3] or 'auto' }
        if v == 0 or not Gearshift.validProfile(p) then
            message('As driver: /shiftstyle hpattern|sequential|paddle left|right auto|external'); return
        end
        stopOwnAnimation(); override = p; previousGear = GetVehicleCurrentGear(v)
        message(('Style %s, shifter hand %s, mode %s'):format(p.style,p.hand,p.mode))
    end, false)
    RegisterCommand('shifttest', function(_, args)
        CreateThread(function()
            local v, ped = driverVehicle(); refresh(v)
            if v == 0 then message('Preview not played: not_driver'); return end
            local start = GetGameTimer()
            loadingSince, loadFailed, lastLoadRequest = nil, false, -10000
            while not ready() and GetGameTimer() - start <= Config.LoadTimeoutMs do
                local currentVehicle, currentActor = driverVehicle()
                if currentVehicle ~= v or currentActor ~= ped then
                    message('Preview cancelled: driver/vehicle changed.'); return
                end
                Wait(50)
            end
            local currentVehicle, currentActor = driverVehicle()
            if currentVehicle ~= v or currentActor ~= ped then
                message('Preview cancelled: driver/vehicle changed.'); return
            end
            local ok, reason = play(args[1] or 'up', tonumber(args[2]) or args[2] or 2)
            if not ok then message('Preview not played: ' .. reason); return end
            local attempt = active
            Wait(100)
            if active ~= attempt then message('Preview interrupted before the playback check.'); return end
            message(('Playback check: %s playing=%s time=%.3f'):format(attempt.clip,
                tostring(IsEntityPlayingAnim(ped, Config.Dictionary, attempt.clip, 3)),
                GetEntityAnimCurrentTime(ped, Config.Dictionary, attempt.clip)))
        end)
    end, false)
end
AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    stopOwnAnimation()
    RemoveAnimDict(Config.Dictionary)
end)
print(('[gearshift] v%s client loaded; use /gearshift diagnose in F8 or chat.'):format(
    GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '?'))
