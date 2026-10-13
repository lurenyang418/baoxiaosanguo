-- Read-only FCEUX helper. Snapshot battle-related RAM as tracked values change.
local output_path = "research/evidence/traces/fceux_battle_ram_snapshot.txt"

local function b(address)
    return memory.readbyte(address)
end

local function hex(value)
    return string.format("%02X", value)
end

local write_events = {}

local function trace_watch_write(address, size, value)
    local input_code = b(0x05CF)
    if input_code ~= 0 or address == 0x6802 then
        write_events[#write_events + 1] = string.format(
            "%05d:$%04X<-$%02X(input=$%02X)",
            emu.framecount(), address, value, input_code)
    end
end

local function write_snapshot()
    local stage = b(0x6400)
    local player_count = b(0x6413)
    local group1_count = b(0x6415)
    local group2_count = b(0x6414)
    local roster_count = b(0x6813)
    local rows = {
        "frame=" .. emu.framecount(),
        "stage=$" .. hex(stage),
        "battle_player_count=$" .. hex(player_count),
        "group1_count=$" .. hex(group1_count),
        "group2_count=$" .. hex(group2_count),
        "roster_count=$" .. hex(roster_count),
        "horizontal_state_6801_6802=$" .. hex(b(0x6801)) .. ",$" .. hex(b(0x6802)),
        "movement_check_mode_05cc=$" .. hex(b(0x05CC)),
        "movement_budget_05e6=$" .. hex(b(0x05E6)),
        "input_code_05cf=$" .. hex(b(0x05CF)),
        "selected_unit_slot_6408=$" .. hex(b(0x6408)),
        "ram_060a_060b=$" .. hex(b(0x060A)) .. ",$" .. hex(b(0x060B)),
        "coordinate_bytes_0616_0617_0618_0619=$" .. hex(b(0x0616)) .. ",$" ..
            hex(b(0x0617)) .. ",$" .. hex(b(0x0618)) .. ",$" .. hex(b(0x0619)),
        "coordinate_write_events=" .. table.concat(write_events, ";"),
    }

    local indices, types = {}, {}
    for i = 0, math.min(roster_count, 32) - 1 do
        local roster_index = b(0x6807 + i)
        indices[#indices + 1] = hex(roster_index)
        types[#types + 1] = hex(b(0x651B + roster_index))
    end
    rows[#rows + 1] = "roster_indices=" .. table.concat(indices, ",")
    rows[#rows + 1] = "roster_type_ids=" .. table.concat(types, ",")

    local positions = {}
    local slot_count = math.min(player_count + group1_count + group2_count, 64)
    for i = 0, slot_count - 1 do
        positions[#positions + 1] = string.format("%02X:%02X,%02X", i,
            b(0x648F + i), b(0x64B7 + i))
    end
    rows[#rows + 1] = "unit_positions(slot:y,x)=" .. table.concat(positions, " ")

    local file = io.open(output_path, "w")
    if file then
        file:write(table.concat(rows, "\n"), "\n")
        file:close()
    end
end

local previous_signature = nil
memory.registerwrite(0x0616, 4, trace_watch_write)
memory.registerwrite(0x6802, trace_watch_write)
emu.registerafter(function()
    local stage, count = b(0x6400), b(0x6813)
    local signature = string.format("%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X",
        stage, count, b(0x6413), b(0x6415), b(0x6414),
        b(0x6801), b(0x6802), b(0x05CC), b(0x05E6),
        b(0x060A), b(0x060B), b(0x0616), b(0x0618),
        b(0x0617), b(0x0619), b(0x05CF), b(0x6408))
    for i = 0, math.min(count, 32) - 1 do
        local roster_index = b(0x6807 + i)
        signature = signature .. hex(roster_index) .. hex(b(0x651B + roster_index))
    end
    local slot_count = math.min(b(0x6413) + b(0x6415) + b(0x6414), 64)
    for i = 0, slot_count - 1 do
        signature = signature .. hex(b(0x648F + i)) .. hex(b(0x64B7 + i))
    end
    if stage < 19 and (signature ~= previous_signature or #write_events > 0) then
        previous_signature = signature
        write_snapshot()
    end
    write_events = {}
end)
