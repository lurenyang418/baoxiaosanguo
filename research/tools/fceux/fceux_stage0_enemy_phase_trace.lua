-- The trace is read-only with respect to emulated RAM. FCEUX may change its
-- working directory to the ROM folder, so pass an absolute output path.
local output_path = os.getenv('FCEUX_TRACE_OUTPUT') or 'research/evidence/traces/rom_stage00_enemy_phase_trace.tsv'
local output = assert(io.open(output_path, 'w'))
output:write('frame\tselected_slot_6408\tacted_count_6822\tinput_05CF\tframe_counter_05D4\tpositions_slot_x_y\tram_per_slot_67B1_643F_65A7_66E7\n')
FCEU.speedmode('turbo')
local previous = ''
local max_frames = tonumber(os.getenv('FCEUX_TRACE_FRAMES')) or 5200
for frame = 1, max_frames do
    emu.frameadvance()
    local player_count = memory.readbyte(0x6413)
    local ally_count = memory.readbyte(0x6415)
    local enemy_count = memory.readbyte(0x6414)
    if frame >= 2850 and player_count == 3 and ally_count == 0 and enemy_count == 8 then
        local positions = {}
        for slot = 0, player_count + ally_count + enemy_count - 1 do
            positions[#positions + 1] = string.format('%d:%d,%d', slot,
                memory.readbyte(0x64B7 + slot), memory.readbyte(0x648F + slot))
        end
        local signature = table.concat(positions, ' ')
        if signature ~= previous or frame % 100 == 0 then
            local ai = {}
            for slot = 3, 10 do
                ai[#ai + 1] = string.format('%d:%02X,%02X,%02X,%02X', slot,
                    memory.readbyte(0x67B1 + slot), memory.readbyte(0x643F + slot),
                    memory.readbyte(0x65A7 + slot), memory.readbyte(0x66E7 + slot))
            end
            output:write(string.format('%d\t%02X\t%02X\t%02X\t%02X\t%s\t%s\n', frame,
                memory.readbyte(0x6408), memory.readbyte(0x6822),
                memory.readbyte(0x05CF), memory.readbyte(0x05D4), signature, table.concat(ai, ' ')))
            output:flush()
            previous = signature
        end
    end
end
output:close()
emu.pause()
