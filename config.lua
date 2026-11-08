Config = {}
Config.Dictionary = 'gearshift'
Config.Default = { style = 'hpattern', hand = 'auto', mode = 'auto' }
Config.Enabled = true
-- Seated car animations: cars, SUVs, vans, buses, trucks and open-wheel cars.
-- Bike, boat, aircraft and train poses need separate animation assets.
Config.EnabledClasses = {
    [0]=true, [1]=true, [2]=true, [3]=true, [4]=true, [5]=true, [6]=true,
    [7]=true, [9]=true, [10]=true, [11]=true, [12]=true, [17]=true,
    [18]=true, [19]=true, [20]=true, [22]=true,
}
-- These are animation defaults, not authoritative transmission specifications.
Config.ClassProfiles = {
    [6] = { style = 'sequential' }, -- Sports
    [7] = { style = 'paddle' },     -- Super
    [22] = { style = 'paddle' },    -- Open wheel
}
Config.HighGearStyle = 'sequential' -- Automatic H-pattern profiles with >6 gears
Config.ExtraGearStyle = 'sequential' -- Explicit H-pattern profiles shifting above 6
Config.FallbackHand = 'right' -- Missing/central driver-seat bone
-- hand is the shifter hand, not the driver's seat side.
-- mode: 'auto' observes GTA gears; 'external' uses the PlayShift export only.
Config.Vehicles = {
    -- Set a model to false to disable its animations.
    -- [joaat('your_car')] = false,
    -- Partial overrides inherit defaults: { style = 'paddle' } is sufficient.
    -- [joaat('sultan')] = { style = 'hpattern', hand = 'right', mode = 'auto' },
    -- [joaat('your_rhd_car')] = { style = 'sequential', hand = 'left', mode = 'external' },
    -- [joaat('your_supercar')] = { style = 'paddle', hand = 'right', mode = 'auto' },
}
Config.PollMs = 25
Config.CooldownMs = 120
Config.LoadTimeoutMs = 10000
-- Disable arm IK through this animation task's control flags only.
Config.ReleaseArmIK = true
Config.TestCommands = true
-- Matches the half-speed clip rates baked into stream/gearshift.ycd.
Config.Durations = { hpattern = 1600, sequential = 920, paddle = 440 }
