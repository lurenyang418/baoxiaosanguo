-- Replay research/evidence/movies/fceux_stage00_three_phases.fm2 from a clean ROM boot.
-- Observe the two pursuers' movement writes without altering emulated RAM.
local output_path = os.getenv('FCEUX_TRACE_OUTPUT') or 'research/evidence/traces/rom_stage00_move_budget_writes.tsv'
local output = assert(io.open(output_path, 'w'))
output:write('frame\taddress\tvalue\tslot\tx\ty\t05f4\t05f5\t05f6\t05f7\t0616\t0618\n')

local function observed_frame(frame)
    return (frame >= 3990 and frame <= 4090)
        or (frame >= 6140 and frame <= 6230)
        or (frame >= 8150 and frame <= 8230)
end

local function on_write(address, size, value)
    local frame = emu.framecount()
    if not observed_frame(frame) then return end
    local slot = memory.readbyte(0x6408)
    output:write(string.format('%d\t%04X\t%02X\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\n',
        frame, address, value, slot, memory.readbyte(0x64B7 + 5),
        memory.readbyte(0x648F + 5), memory.readbyte(0x05F4),
        memory.readbyte(0x05F5), memory.readbyte(0x05F6),
        memory.readbyte(0x05F7), memory.readbyte(0x0616),
        memory.readbyte(0x0618)))
end

memory.registerwrite(0x05E6, on_write)
memory.registerwrite(0x05F6, on_write)
memory.registerwrite(0x648F + 5, on_write)
FCEU.speedmode('turbo')
for frame = 1, 8300 do emu.frameadvance() end
output:close()
emu.pause()
