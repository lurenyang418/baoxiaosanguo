-- Controlled type-60 replacement and seven wounded slots, for area-code evidence.
-- This does not represent the unmodified stage roster.
-- Replay the stage-0 movie while selecting stage 2 in emulated RAM.
-- This is a controlled stage load, not a natural campaign transition.
-- FCEUX_PLAYER_X/Y choose player slot 0's position after stage setup.
-- A at 4200 dismisses the battle-title panel. Start at 6500 and A at
-- 6700 choose whole-army rest after that panel has closed. Extended traces
-- send the same command at 11000/11200 to capture a second enemy phase.
local player_x = tonumber(os.getenv('FCEUX_PLAYER_X') or '9')
local player_y = tonumber(os.getenv('FCEUX_PLAYER_Y') or '10')
local end_frame = tonumber(os.getenv('FCEUX_TRACE_END_FRAME') or '12000')
assert(player_x >= 0 and player_x <= 15)
assert(player_y >= 0 and player_y <= 29)
local output_path = os.getenv('FCEUX_TRACE_OUTPUT') or 'research/evidence/traces/rom_area5_healing_effect.tsv'
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
memory.registerexec(0x9A69, function()
    if frame > 6000 and memory.readbyte(0x66E7 + memory.readbyte(0x6408)) == 23 then
        output:write('AREA_TARGETS frame=' .. frame .. ' count=' .. memory.readbyte(0x6412) .. ' variant=' .. memory.readbyte(0x05CD) .. ' magnitude=' .. memory.readbyte(0x05EB) .. ' range=' .. memory.readbyte(0x670F) .. ' area=' .. memory.readbyte(0x6710) .. ' slots=')
        for i=0,memory.readbyte(0x6412)-1 do output:write(memory.readbyte(0x6409+i) .. ',') end
        output:write('\n'); output:flush()
    end
end)
local effect_done = false
local forced_area = tonumber(os.getenv('FCEUX_AREA_CODE') or '5')
assert(forced_area == 5 or forced_area == 9)
memory.registerexec(0x96C7, function()
    if frame > 6000 and memory.readbyte(0x6408) == 7 and memory.readbyte(0x66E7 + 7) == 23 and memory.readbyte(0x96CB) == 0xAD then
        -- Freeze a known arrangement immediately before the ROM builds its list.
        local layout = {{5,9,6,215},{6,9,7,10},{7,10,7,50},{8,8,7,50},{9,9,8,50},{10,8,6,50},{11,10,8,50}}
        for _, u in ipairs(layout) do
            memory.writebyte(0x64B7+u[1],u[2]); memory.writebyte(0x648F+u[1],u[3])
            memory.writebyte(0x65A7+u[1]*2,u[4]); memory.writebyte(0x65A8+u[1]*2,0)
        end
        if forced_area == 9 then memory.writebyte(0x6710,9) end
        capture('area_setup',0x96C7)
    end
end)
memory.registerexec(0x9B57, function()
    if frame > 6000 and memory.readbyte(0x6408) == 7 and memory.readbyte(0x66E7 + 7) == 23 and memory.readbyte(0x6412) >= 3 then
        capture('area_effect_complete',0x9B57)
        effect_done = true
    end
end)
local previous = ''
for index = 1, end_frame do
    frame = index
    if frame >= 1800 and frame <= 2200 then
        memory.writebyte(0x6400, 2)
    end
    if frame == 3900 then
        memory.writebyte(0x643F + 7, 60)
        memory.writebyte(0x6557 + 14, 210)
        memory.writebyte(0x6558 + 14, 0)
        memory.writebyte(0x6647 + 14, 110)
        memory.writebyte(0x6648 + 14, 0)
        memory.writebyte(0x65F7 + 14, 24)
        memory.writebyte(0x65F8 + 14, 1)
        memory.writebyte(0x6697 + 7, 110)
        memory.writebyte(0x66BF + 7, 3)
        memory.writebyte(0x66E7 + 7, 23)
        memory.writebyte(0x6467 + 7, 21)
        memory.writebyte(0x6711 + 7, 5)
        memory.writebyte(0x6739 + 7, 5)
        memory.writebyte(0x6761 + 7, 3)
        memory.writebyte(0x64B7 + 5, 9); memory.writebyte(0x648F + 5, 6)
        memory.writebyte(0x65A7 + 10, 50); memory.writebyte(0x65A8 + 10, 0)
        memory.writebyte(0x64B7 + 6, 9); memory.writebyte(0x648F + 6, 7)
        memory.writebyte(0x65A7 + 12, 10); memory.writebyte(0x65A8 + 12, 0)
        memory.writebyte(0x64B7 + 7, 10); memory.writebyte(0x648F + 7, 7)
        memory.writebyte(0x65A7 + 14, 50); memory.writebyte(0x65A8 + 14, 0)
        memory.writebyte(0x64B7 + 8, 8); memory.writebyte(0x648F + 8, 7)
        memory.writebyte(0x65A7 + 16, 50); memory.writebyte(0x65A8 + 16, 0)
        memory.writebyte(0x64B7 + 9, 9); memory.writebyte(0x648F + 9, 8)
        memory.writebyte(0x65A7 + 18, 50); memory.writebyte(0x65A8 + 18, 0)
        memory.writebyte(0x64B7 + 10, 8); memory.writebyte(0x648F + 10, 6)
        memory.writebyte(0x65A7 + 20, 50); memory.writebyte(0x65A8 + 20, 0)
        memory.writebyte(0x64B7 + 11, 10); memory.writebyte(0x648F + 11, 8)
        memory.writebyte(0x65A7 + 22, 50); memory.writebyte(0x65A8 + 22, 0)

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
        
        
        joypad.set(1, buttons)
    end
    emu.frameadvance()
    if effect_done then break end
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
