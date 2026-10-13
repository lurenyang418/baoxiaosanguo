-- Controlled capture of the original ending callback, not a natural stage-19 clear.
-- Run with research/evidence/movies/fceux_stage00_seven_phases.fm2 and the original ROM.
-- At frame 3900, set the completed stage to index 18 and clear the enemy slots.
-- The ROM then increments $6400 to 19 and executes the original ending branch.

local output_path = os.getenv('FCEUX_TRACE_OUTPUT') or 'research/evidence/traces/rom_ending_branch_trace.tsv'
local screenshot_prefix = os.getenv('FCEUX_SCREENSHOT_PREFIX') or '/private/tmp/sangguo_ending'
local end_frame = tonumber(os.getenv('FCEUX_TRACE_END_FRAME') or '15000')
local output = assert(io.open(output_path, 'w'))
output:write('frame\tevent\tstage\tbank_entry_bytes\tmapper_mode\tenemy_count\tgoal_flag\n')
FCEU.speedmode('turbo')

local frame = 0
local function record(event)
    output:write(string.format('%d\t%s\t%d\t%02X%02X%02X\t%02X\t%02X\t%02X\n',
        frame, event, memory.readbyte(0x6400), memory.readbyte(0x8000),
        memory.readbyte(0x8001), memory.readbyte(0x8002), memory.readbyte(0x6407),
        memory.readbyte(0x6814), memory.readbyte(0x6815)))
    output:flush()
end

memory.registerexec(0x8006, function()
    -- Physical PRG bank 42 starts 4C 06 80 and has callback 0 at $8006.
    if memory.readbyte(0x8000) == 0x4C and memory.readbyte(0x8001) == 0x06
        and memory.readbyte(0x8002) == 0x80 then
        record('ending_callback0')
    end
end)

for current_frame = 1, end_frame do
    frame = current_frame
    if frame == 3800 then pcall(movie.stop) end
    if frame == 3900 then
        memory.writebyte(0x6400, 18)
        for slot = 3, 10 do
            memory.writebyte(0x6789 + slot, 0xFF)
            memory.writebyte(0x65A7 + slot * 2, 0)
            memory.writebyte(0x65A8 + slot * 2, 0)
        end
        memory.writebyte(0x6815, 0xFF)
        record('controlled_final_stage_enemy_clear')
    end
    if frame >= 3800 then
        local buttons = {up=false, down=false, left=false, right=false,
            A=false, B=false, start=false, select=false}
        if frame >= 4200 and frame <= 4203 then buttons.A = true end
        for _, press_at in ipairs({6700, 7700, 8700, 9700, 10700, 11700, 12700}) do
            if frame >= press_at and frame <= press_at + 3 then buttons.A = true end
        end
        joypad.set(1, buttons)
    end
    emu.frameadvance()
    if frame % 500 == 0 then record('state') end
    if (frame >= 4100 and frame <= 6300 and frame % 100 == 0)
        or (frame >= 6500 and frame % 500 == 0) then
        local file = assert(io.open(screenshot_prefix .. '.' .. frame .. '.gd', 'wb'))
        file:write(gui.gdscreenshot())
        file:close()
    end
end

record('complete')
output:close()
emu.pause()
