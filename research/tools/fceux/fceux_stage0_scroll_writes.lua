-- Replay research/evidence/movies/fceux_stage00_three_phases.fm2 from a clean ROM boot.
-- Trace screen Y and vertical-scroll writes without changing emulated RAM.
local output_path = os.getenv('FCEUX_TRACE_OUTPUT') or 'research/evidence/traces/rom_stage00_scroll_writes.tsv'
local output = assert(io.open(output_path, 'w'))
output:write('frame\taddress\tvalue\tslot\told_scroll\tscreen_y\told_screen_y\tworld_y_slot5\t05e6\t05f6\n')

local function observed_frame(frame)
    return (frame >= 3990 and frame <= 4090)
        or (frame >= 6140 and frame <= 6230)
        or (frame >= 8150 and frame <= 8230)
end

local function on_write(address, size, value)
    local frame = emu.framecount()
    if not observed_frame(frame) then return end
    output:write(string.format('%d\t%04X\t%02X\t%d\t%d\t%d\t%d\t%d\t%d\t%d\n',
        frame, address, value, memory.readbyte(0x6408),
        memory.readbyte(0x6802), memory.readbyte(0x0618),
        memory.readbyte(0x0619), memory.readbyte(0x648F + 5),
        memory.readbyte(0x05E6), memory.readbyte(0x05F6)))
end

memory.registerwrite(0x6802, on_write)
memory.registerwrite(0x0618, on_write)
memory.registerwrite(0x648F + 5, on_write)
FCEU.speedmode('turbo')
for frame = 1, 8300 do emu.frameadvance() end
output:close()
emu.pause()
