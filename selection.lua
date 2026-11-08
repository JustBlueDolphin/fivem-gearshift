-- Pure selection logic, also used by the offline tests.
Gearshift = {}
function Gearshift.resolve(defaults, classProfile, modelProfile, detectedHand, highGear)
    local result = {}
    for _, source in ipairs({ defaults, classProfile or {}, modelProfile or {} }) do
        for key, value in pairs(source) do result[key] = value end
    end
    if result.hand == 'auto' then result.hand = detectedHand end
    if result.style == 'hpattern' and highGear > 6
        and not (modelProfile and modelProfile.style) then
        result.style = Config.HighGearStyle
    end
    return result
end
function Gearshift.playbackProfile(profile, gear)
    if profile.style == 'hpattern' and type(gear) == 'number' and gear % 1 == 0
        and gear > 6 and Config.ExtraGearStyle then
        return { style = Config.ExtraGearStyle, hand = profile.hand, mode = profile.mode }
    end
    return profile
end
function Gearshift.validProfile(p)
    return type(p) == 'table'
        and (p.style == 'hpattern' or p.style == 'sequential' or p.style == 'paddle')
        and (p.hand == 'left' or p.hand == 'right')
        and (p.mode == 'auto' or p.mode == 'external')
end
function Gearshift.clip(profile, direction, gear)
    if not Gearshift.validProfile(profile) then return nil end
    if direction ~= 'up' and direction ~= 'down' then return nil end
    if profile.style == 'hpattern' then
        local suffix
        if gear == 'r' or gear == 'n' then suffix = gear
        elseif type(gear) == 'number' and gear % 1 == 0 and gear >= 1 and gear <= 6 then
            suffix = tostring(gear)
        end
        if not suffix then return nil end
        return 'hpattern_' .. profile.hand .. '_' .. suffix
    elseif profile.style == 'sequential' then
        return 'sequential_' .. profile.hand .. '_' .. direction
    end
    return 'paddle_' .. (direction == 'up' and 'right' or 'left') .. '_pull'
end
