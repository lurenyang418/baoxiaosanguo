-- Replay research/evidence/movies/fceux_stage00_seven_phases.fm2 from a clean ROM boot.
-- Override player slot 0's world position at frame 3000 to compare AI routes.
-- Example: FCEUX_PLAYER_X=6 FCEUX_PLAYER_Y=21 FCEUX_TRACE_OUTPUT=... fceux ... --loadlua this.lua ROM
local player_x = tonumber(os.getenv('FCEUX_PLAYER_X') or '7')
local player_y = tonumber(os.getenv('FCEUX_PLAYER_Y') or '18')
assert(player_x >= 0 and player_x <= 15, 'FCEUX_PLAYER_X must be 0..15')
assert(player_y >= 0 and player_y <= 29, 'FCEUX_PLAYER_Y must be 0..29')
local output_path = os.getenv('FCEUX_TRACE_OUTPUT') or 'research/evidence/traces/rom_stage00_player_position_trace.tsv'
local output = assert(io.open(output_path, 'w'))
output:write('frame\tslot\tscroll\tplayer_x_y\thp\tenemy_left_x_y\tenemy_right_x_y\n')
FCEU.speedmode('turbo')
local previous = ''
for frame = 1, 17700 do
    if frame == 3000 then
        memory.writebyte(0x64B7, player_x)
        memory.writebyte(0x648F, player_y)
    end
    emu.frameadvance()
    if frame >= 3000 then
        local slot = memory.readbyte(0x6408)
        local hp = memory.readbyte(0x65A7)
        local player_x, player_world_y = memory.readbyte(0x64B7), memory.readbyte(0x648F)
        local left_x, left_y = memory.readbyte(0x64B7 + 4), memory.readbyte(0x648F + 4)
        local right_x, right_y = memory.readbyte(0x64B7 + 5), memory.readbyte(0x648F + 5)
        local signature = string.format('%d:%d:%d,%d:%d,%d:%d,%d',
            slot, hp, left_x, left_y, right_x, right_y, player_x, player_world_y)
        if signature ~= previous or frame % 100 == 0 then
            output:write(string.format('%d\t%d\t%d\t%d,%d\t%d\t%d,%d\t%d,%d\n',
                frame, slot, memory.readbyte(0x6802), player_x, player_world_y,
                hp, left_x, left_y, right_x, right_y))
            output:flush()
            previous = signature
        end
    end
end
output:close()
emu.pause()
