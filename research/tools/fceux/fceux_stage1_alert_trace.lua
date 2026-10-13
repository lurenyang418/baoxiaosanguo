-- Replay the stage-0 input movie while selecting stage 1 in emulated RAM.
-- This is a controlled stage-1 battle load, not a natural stage transition.
-- Set FCEUX_PLAYER_X/Y and FCEUX_TRACE_OUTPUT for a position comparison.
local player_x = tonumber(os.getenv('FCEUX_PLAYER_X') or '8')
local player_y = tonumber(os.getenv('FCEUX_PLAYER_Y') or '12')
local end_frame = tonumber(os.getenv('FCEUX_TRACE_END_FRAME') or '5400')
assert(player_x >= 0 and player_x <= 15, 'FCEUX_PLAYER_X must be 0..15')
assert(player_y >= 0 and player_y <= 29, 'FCEUX_PLAYER_Y must be 0..29')
assert(end_frame >= 5400, 'FCEUX_TRACE_END_FRAME must be at least 5400')
local output_path = os.getenv('FCEUX_TRACE_OUTPUT') or 'research/evidence/traces/rom_stage01_alert_trace.tsv'
local output = assert(io.open(output_path, 'w'))
output:write('frame\tevent\tslot\tpc\thp0\tplayer0\tgroup2_positions\n')
FCEU.speedmode('turbo')
local frame = 0
local function positions()
    local result = {}
    for slot = 3, 8 do
        result[#result + 1] = string.format('%d:%d,%d', slot,
            memory.readbyte(0x64B7 + slot), memory.readbyte(0x648F + slot))
    end
    return table.concat(result, ' ')
end
local function capture(event, pc)
    if frame < 3500 or frame > end_frame or memory.readbyte(0x6400) ~= 1 then
        return
    end
    output:write(string.format('%d\t%s\t%d\t%04X\t%d\t%d,%d\t%s\n',
        frame, event, memory.readbyte(0x6408), pc, memory.readbyte(0x65A7),
        memory.readbyte(0x64B7), memory.readbyte(0x648F), positions()))
    output:flush()
end
for _, address in ipairs({0xA9A4, 0xAA44, 0xAEDA, 0x8DDC}) do
    local pc = address
    memory.registerexec(pc, function() capture('exec', pc) end)
end
local previous = ''
for index = 1, end_frame do
    frame = index
    if frame >= 1800 and frame <= 2200 then
        memory.writebyte(0x6400, 1)
    end
    if frame == 3000 then
        memory.writebyte(0x64B7, player_x)
        memory.writebyte(0x648F, player_y)
    end
    emu.frameadvance()
    if frame >= 3500 and frame <= end_frame and memory.readbyte(0x6400) == 1 then
        local signature = positions() .. ':' .. memory.readbyte(0x65A7)
        if signature ~= previous then
            capture('state', 0)
            previous = signature
        end
    end
end
output:close()
emu.pause()
