-- Replay research/evidence/movies/fceux_stage00_seven_phases.fm2 from a clean ROM boot.
-- The first RAM value is the first player's HP low byte.
local output_path = os.getenv('FCEUX_TRACE_OUTPUT') or 'research/evidence/traces/rom_stage00_seven_phase_hp_trace.tsv'
local output = assert(io.open(output_path, 'w'))
output:write('frame\tslot\tscroll\tram_65A7_65A8_65A9\tenemy_y\n')
FCEU.speedmode('turbo')
local previous = ''
for frame = 1, 17700 do
    emu.frameadvance()
    if frame >= 11500 then
        local hp = string.format('%d,%d,%d', memory.readbyte(0x65A7),
            memory.readbyte(0x65A8), memory.readbyte(0x65A9))
        local slot = memory.readbyte(0x6408)
        local left_y = memory.readbyte(0x648F + 4)
        local right_y = memory.readbyte(0x648F + 5)
        local signature = hp .. ':' .. slot .. ':' .. left_y .. ':' .. right_y
        if signature ~= previous or frame % 100 == 0 then
            output:write(string.format('%d\t%d\t%d\t%s\t%d,%d\n', frame,
                slot, memory.readbyte(0x6802), hp, left_y, right_y))
            output:flush()
            previous = signature
        end
    end
end
output:close()
emu.pause()
