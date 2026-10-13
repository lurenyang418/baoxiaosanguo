-- Trace bank-2 movement code while replaying research/evidence/movies/fceux_stage00_seven_phases.fm2.
-- This intentionally changes only player slot 0's X/Y at frame 3000.
-- Set FCEUX_PLAYER_X, FCEUX_PLAYER_Y, and FCEUX_TRACE_OUTPUT before launching FCEUX.
local player_x = tonumber(os.getenv('FCEUX_PLAYER_X') or '6')
local player_y = tonumber(os.getenv('FCEUX_PLAYER_Y') or '21')
assert(player_x >= 0 and player_x <= 15, 'FCEUX_PLAYER_X must be 0..15')
assert(player_y >= 0 and player_y <= 29, 'FCEUX_PLAYER_Y must be 0..29')
local output_path = os.getenv('FCEUX_TRACE_OUTPUT') or 'research/evidence/traces/rom_stage00_route_pc_trace.tsv'
local output = assert(io.open(output_path, 'w'))
output:write('frame\tpc\tslot\tscroll\tflags\tdx\tdy\tdir\tmove\tscreen_x\tscreen_y\tleft\tright\n')
FCEU.speedmode('turbo')
local frame = 0
local count = 0
for address = 0xAEDA, 0xB4AC do
    local pc = address
    memory.registerexec(pc, function()
        if frame >= 10150 and frame <= 10300 then
            local slot = memory.readbyte(0x6408)
            if slot == 4 or slot == 5 then
                count = count + 1
                if count <= 20000 then
                    output:write(string.format('%d\t%04X\t%d\t%d\t%02X\t%02X\t%02X\t%02X\t%02X\t%02X\t%02X\t%d,%d\t%d,%d\n',
                        frame, pc, slot, memory.readbyte(0x6802), memory.readbyte(0x05F4),
                        memory.readbyte(0x05F5), memory.readbyte(0x05F6), memory.readbyte(0x05CF),
                        memory.readbyte(0x05E4), memory.readbyte(0x0616), memory.readbyte(0x0618),
                        memory.readbyte(0x64B7 + 4), memory.readbyte(0x648F + 4),
                        memory.readbyte(0x64B7 + 5), memory.readbyte(0x648F + 5)))
                end
            end
        end
    end)
end
for index = 1, 10400 do
    frame = index
    if frame == 3000 then
        memory.writebyte(0x64B7, player_x)
        memory.writebyte(0x648F, player_y)
    end
    emu.frameadvance()
end
output:close()
emu.pause()
