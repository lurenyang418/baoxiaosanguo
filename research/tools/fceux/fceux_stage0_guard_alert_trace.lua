-- Replay research/evidence/movies/fceux_stage00_seven_phases.fm2 from a clean ROM boot.
-- Set FCEUX_PLAYER_X/Y and FCEUX_TRACE_OUTPUT to inspect the first enemy phase.
local player_x = tonumber(os.getenv('FCEUX_PLAYER_X') or '7')
local player_y = tonumber(os.getenv('FCEUX_PLAYER_Y') or '11')
local end_frame = tonumber(os.getenv('FCEUX_TRACE_END_FRAME') or '5300')
assert(player_x >= 0 and player_x <= 15, 'FCEUX_PLAYER_X must be 0..15')
assert(player_y >= 0 and player_y <= 29, 'FCEUX_PLAYER_Y must be 0..29')
assert(end_frame >= 4000, 'FCEUX_TRACE_END_FRAME must be at least 4000')
local output_path = os.getenv('FCEUX_TRACE_OUTPUT') or 'research/evidence/traces/rom_stage00_guard_alert_trace.tsv'
local output = assert(io.open(output_path, 'w'))
output:write('frame\tpc\tslot\ttarget\thp\tplayer\tacting\tscroll\n')
FCEU.speedmode('turbo')
local frame = 0
for _, address in ipairs({0xA9A4, 0xA9F1, 0xAA44, 0xAEBE, 0x8DDC, 0xAE0C, 0xAD30, 0xAEDA}) do
    local pc = address
    memory.registerexec(pc, function()
        if frame >= 4000 and frame <= end_frame then
            local slot = memory.readbyte(0x6408)
            output:write(string.format('%d\t%04X\t%d\t%d\t%d\t%d,%d\t%d,%d\t%d\n',
                frame, pc, slot, memory.readbyte(0x6409), memory.readbyte(0x65A7),
                memory.readbyte(0x64B7), memory.readbyte(0x648F),
                memory.readbyte(0x64B7 + slot), memory.readbyte(0x648F + slot),
                memory.readbyte(0x6802)))
            output:flush()
        end
    end)
end
for index = 1, end_frame do
    frame = index
    if frame == 3000 then
        memory.writebyte(0x64B7, player_x)
        memory.writebyte(0x648F, player_y)
    end
    emu.frameadvance()
end
output:close()
emu.pause()
