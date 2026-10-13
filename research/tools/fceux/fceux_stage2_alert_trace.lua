-- Replay the stage-0 movie while selecting stage 2 in emulated RAM.
-- This is a controlled stage load, not a natural campaign transition.
-- FCEUX_PLAYER_X/Y choose player slot 0's position after stage setup.
-- A at 4200 dismisses the battle-title panel. Start at 6500 and A at
-- 6700 choose whole-army rest after that panel has closed. Extended traces
-- send the same command at 11000/11200 to capture a second enemy phase.
local player_x = tonumber(os.getenv('FCEUX_PLAYER_X') or '9')
local player_y = tonumber(os.getenv('FCEUX_PLAYER_Y') or '10')
local end_frame = tonumber(os.getenv('FCEUX_TRACE_END_FRAME') or '10000')
assert(player_x >= 0 and player_x <= 15)
assert(player_y >= 0 and player_y <= 29)
local output_path = os.getenv('FCEUX_TRACE_OUTPUT') or 'research/evidence/traces/rom_stage02_alert_trace.tsv'
local screenshot_prefix = os.getenv('FCEUX_SCREENSHOT_PREFIX')
local wounded_slot = tonumber(os.getenv('FCEUX_WOUNDED_SLOT') or '')
local wounded_hp = tonumber(os.getenv('FCEUX_WOUNDED_HP') or '50')
if wounded_slot then assert(wounded_slot >= 5 and wounded_slot <= 14) end
local output = assert(io.open(output_path, 'w'))
output:write('frame\tevent\tslot\tpc\thp0\tplayer0\tgroup2_positions\tstage\tfirst_state\tfailure\tvictory\tframe_parity\tgroup2_hp\ttarget\ttechnique_variant\n')
FCEU.speedmode('turbo')
local frame = 0
local function positions()
    local result = {}
    for slot = 5, 14 do
        result[#result + 1] = string.format('%d:%d,%d', slot,
            memory.readbyte(0x64B7 + slot), memory.readbyte(0x648F + slot))
    end
    return table.concat(result, ' ')
end
local function hit_points()
    local result = {}
    for slot = 5, 14 do
        result[#result + 1] = string.format('%d:%d', slot,
            memory.readbyte(0x65A7 + slot * 2) + memory.readbyte(0x65A8 + slot * 2) * 256)
    end
    return table.concat(result, ' ')
end
local function capture(event, pc)
    if frame < 3500 or frame > end_frame or (event ~= 'complete' and memory.readbyte(0x6400) ~= 2) then
        return
    end
    output:write(string.format('%d\t%s\t%d\t%04X\t%d\t%d,%d\t%s\t%d\t%d\t%d\t%d\t%d\t%s\t%d\t%d\n',
        frame, event, memory.readbyte(0x6408), pc, memory.readbyte(0x65A7),
        memory.readbyte(0x64B7), memory.readbyte(0x648F), positions(),
        memory.readbyte(0x6400), memory.readbyte(0x6789),
        memory.readbyte(0x6814), memory.readbyte(0x6815), memory.readbyte(0x05D4) % 2,
        hit_points(), memory.readbyte(0x6409), memory.readbyte(0x05CD)))
    output:flush()
end
for _, address in ipairs({0xA9A4, 0xAA44, 0xAB3A, 0xAD30, 0xAE0C, 0xAEDA, 0x8DDC, 0x9312}) do
    local pc = address
    memory.registerexec(pc, function() capture('exec', pc) end)
end
local previous = ''
for index = 1, end_frame do
    frame = index
    if frame >= 1800 and frame <= 2200 then
        memory.writebyte(0x6400, 2)
    end
    if frame == 3900 then
        memory.writebyte(0x64B7, player_x)
        memory.writebyte(0x648F, player_y)
        if wounded_slot then
            memory.writebyte(0x65A7 + wounded_slot * 2, wounded_hp % 256)
            memory.writebyte(0x65A8 + wounded_slot * 2, math.floor(wounded_hp / 256))
        end
    end
    if frame >= 3800 then
        if frame == 3800 then
            capture('movie_stop', 0)
            movie.stop()
        end
        local buttons = {up=false, down=false, left=false, right=false,
            A=false, B=false, start=false, select=false}
        if frame >= 4200 and frame <= 4203 then buttons.A = true end
        if frame >= 6500 and frame <= 6503 then buttons.start = true end
        if frame >= 6700 and frame <= 6703 then buttons.A = true end
        if frame >= 11000 and frame <= 11003 then buttons.start = true end
        if frame >= 11200 and frame <= 11203 then buttons.A = true end
        joypad.set(1, buttons)
    end
    emu.frameadvance()
    if screenshot_prefix and (frame == 4000 or frame == 4500 or frame == end_frame) then
        local screenshot = assert(io.open(screenshot_prefix .. '.' .. frame .. '.gd', 'wb'))
        screenshot:write(gui.gdscreenshot())
        screenshot:close()
    end
    if frame >= 3500 and frame <= end_frame and memory.readbyte(0x6400) == 2 then
        local signature = positions() .. ':' .. hit_points() .. ':' .. memory.readbyte(0x65A7) .. ':' ..
            memory.readbyte(0x6789) .. ':' .. memory.readbyte(0x6814)
        if signature ~= previous then
            capture('state', 0)
            previous = signature
        end
    end
end
capture('complete', 0)
output:close()
emu.pause()
