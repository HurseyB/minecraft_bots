-- ============================================================
--  farmer.lua  |  CC:Tweaked Turtle Crop Farmer
--  Farms carrots (south side) and potatoes (north side)
--  Debug mode ON by default. Set DEBUG = false to silence.
-- ============================================================

local DEBUG = true

-- Internal State
local pos    = { x = 0, y = 0, z = 0 }
local facing = 1  -- 0=North  1=East  2=South  3=West

local FACING_NAME = { [0]="North", [1]="East", [2]="South", [3]="West" }

-- State file for resume after fuel loss
local STATE_FILE = "farmer_state.txt"

-- Seeds for each side
local SEED_EAST = "minecraft:potato"   -- potatoes on east side
local SEED_WEST = "minecraft:carrot"   -- carrots on west side

-- Fully grown age for carrots and potatoes
local MAX_AGE = 7

-- ── Debug helpers ────────────────────────────────────────────

local function dbg(msg)
    if DEBUG then print("[DBG] " .. msg) end
end

local function dbgState(label)
    if DEBUG then
        print(string.format("[DBG] %s | facing=%s(%d) pos=(%d,%d,%d)",
            label, FACING_NAME[facing] or "?", facing,
            pos.x, pos.y, pos.z))
    end
end

-- ── State persistence ────────────────────────────────────────

local function saveState()
    local f = fs.open(STATE_FILE, "w")
    if f then
        f.writeLine(pos.x)
        f.writeLine(pos.y)
        f.writeLine(pos.z)
        f.writeLine(facing)
        f.close()
        dbg("State saved: pos=(" .. pos.x .. "," .. pos.y .. "," .. pos.z .. ") facing=" .. facing)
    else
        print("[WARN] Could not save state file!")
    end
end

local function loadState()
    if not fs.exists(STATE_FILE) then
        dbg("No state file found, starting fresh")
        return false
    end
    local f = fs.open(STATE_FILE, "r")
    if f then
        local x = tonumber(f.readLine())
        local y = tonumber(f.readLine())
        local z = tonumber(f.readLine())
        local fc = tonumber(f.readLine())
        f.close()
        if x and y and z and fc then
            pos.x = x; pos.y = y; pos.z = z; facing = fc
            print("Resumed from saved state:")
            print("  pos=(" .. x .. "," .. y .. "," .. z .. ") facing=" .. FACING_NAME[fc])
            return true
        end
    end
    print("[WARN] State file corrupted, starting fresh")
    return false
end

local function clearState()
    if fs.exists(STATE_FILE) then
        fs.delete(STATE_FILE)
        dbg("State file cleared")
    end
end

-- ── Fuel check ───────────────────────────────────────────────
-- Saves state and halts if out of fuel.
-- Warns if fuel is getting low.

local FUEL_WARN = 50

local function checkFuel()
    local fuel = turtle.getFuelLevel()
    if fuel == "unlimited" then return end
    if fuel <= 0 then
        saveState()
        print("[FUEL] Out of fuel! State saved to: " .. STATE_FILE)
        print("[FUEL] Refuel the turtle then restart the script to resume.")
        error("Out of fuel", 2)
    end
    if fuel < FUEL_WARN then
        print("[FUEL] Low fuel warning: " .. fuel .. " remaining")
        saveState()
    end
end

-- ── setHeading ───────────────────────────────────────────────

local function setHeading(target)
    dbg("setHeading: " .. FACING_NAME[facing] .. " -> " .. FACING_NAME[target])
    local diff = (target - facing) % 4
    if diff == 0 then
        -- already correct
    elseif diff == 1 then
        turtle.turnRight()
        facing = (facing + 1) % 4
    elseif diff == 2 then
        turtle.turnRight()
        turtle.turnRight()
        facing = (facing + 2) % 4
    elseif diff == 3 then
        turtle.turnLeft()
        facing = (facing + 3) % 4
    end
    dbg("setHeading done: now facing " .. FACING_NAME[facing])
end

-- ── move ─────────────────────────────────────────────────────

local function move(dir, blocks)
    for i = 1, blocks do
        checkFuel()
        local success = false
        if     dir == "f" then success = turtle.forward()
        elseif dir == "u" then success = turtle.up()
        elseif dir == "d" then success = turtle.down()
        end

        if success then
            if dir == "f" then
                if     facing == 0 then pos.z = pos.z - 1
                elseif facing == 1 then pos.x = pos.x + 1
                elseif facing == 2 then pos.z = pos.z + 1
                elseif facing == 3 then pos.x = pos.x - 1
                end
            elseif dir == "u" then pos.y = pos.y + 1
            elseif dir == "d" then pos.y = pos.y - 1
            end
            saveState()
            dbg(string.format("move %s %d/%d -> pos=(%d,%d,%d)",
                dir, i, blocks, pos.x, pos.y, pos.z))
        else
            print(string.format("[WARN] move '%s' blocked at step %d/%d | pos=(%d,%d,%d)",
                dir, i, blocks, pos.x, pos.y, pos.z))
        end
    end
end

-- ── descendToGround ──────────────────────────────────────────
-- Moves down repeatedly until turtle.down() fails

local function descendToGround()
    dbg("Descending to ground...")
    while turtle.down() do
        checkFuel()
        pos.y = pos.y - 1
        saveState()
        dbg("Descended, y=" .. pos.y)
    end
    dbg("Hit ground at y=" .. pos.y)
end

-- ── findSeedSlot ─────────────────────────────────────────────
-- Returns the slot number containing the given seed, or nil

local function findSeedSlot(seedName)
    for i = 1, 16 do
        local data = turtle.getItemDetail(i)
        if data and data.name == seedName then
            return i
        end
    end
    return nil
end

-- ── harvestAndReplant ────────────────────────────────────────
-- Checks the crop in front. If fully grown: digs and replants.

local function harvestAndReplant(seedName)
    local ok, data = turtle.inspect()

    if not ok then
        dbg("No block in front, skipping")
        return
    end

    dbg("Inspecting: " .. data.name)

    local isCrop = (data.name == "minecraft:carrots" or data.name == "minecraft:potatoes")
    if not isCrop then
        dbg("Not a crop block, skipping")
        return
    end

    local age = data.state and data.state.age or 0
    dbg("Crop age: " .. age .. " / " .. MAX_AGE)

    if age < MAX_AGE then
        dbg("Not fully grown, skipping")
        return
    end

    dbg("Harvesting!")
    turtle.dig()

    local slot = findSeedSlot(seedName)
    if slot then
        turtle.select(slot)
        turtle.place()
        dbg("Replanted with " .. seedName)
        turtle.select(1)
    else
        print("[WARN] No seeds found for " .. seedName .. " - could not replant!")
    end
end

-- ── dropOff ──────────────────────────────────────────────────
-- Drops carrots and potatoes into whatever is in front

local function dropOff()
    dbg("Starting drop-off")
    for i = 1, 16 do
        turtle.select(i)
        local data = turtle.getItemDetail()
        if data and (data.name == "minecraft:carrot"
                  or data.name == "minecraft:potato"
                  or data.name == "minecraft:poisonous_potato") then
            dbg("Dropping slot " .. i .. ": " .. data.name)
            turtle.drop()
        end
    end
    turtle.select(1)
    dbg("Drop-off complete")
end

-- ════════════════════════════════════════════════════════════
--  MAIN LOOP
-- ════════════════════════════════════════════════════════════

print("Starting farmer. DEBUG=" .. tostring(DEBUG))

local resumed = loadState()
if not resumed then
    print("Fresh start: facing=East pos=(0,0,0)")
else
    print("NOTE: Position restored but script will run from the top of the cycle.")
    print("Move turtle back to home position manually if needed, then restart.")
end

while true do
    dbgState("── Cycle START")

    -- ── Outward Path ─────────────────────────────────────────

    -- 1. Face West, forward 1
    setHeading(3)
    move("f", 1)
    dbgState("Step 1: West 1")

    -- 2. Face South, up 3, forward 4
    setHeading(2)
    move("u", 3)
    move("f", 4)
    dbgState("Step 2: Up 3, South 4")

    -- 3. Face East, forward 12
    setHeading(1)
    move("f", 12)
    dbgState("Step 3: East 12")

    -- 4. Face South, forward 11
    setHeading(2)
    move("f", 11)
    dbgState("Step 4: South 11")

    -- 5. Descend to ground
    descendToGround()
    dbgState("Step 5: at ground level")

    -- ── Farming Pass ─────────────────────────────────────────
    -- At each position: harvest East (potatoes), harvest West
    -- (carrots), then move North. Stop when North is blocked.

    local rowsDone = 0

    while true do
        dbgState("Farm row " .. rowsDone)

        -- East side = potatoes
        setHeading(1)
        harvestAndReplant(SEED_EAST)

        -- West side = carrots
        setHeading(3)
        harvestAndReplant(SEED_WEST)

        -- Try to move North
        setHeading(0)
        local moved = turtle.forward()
        if moved then
            pos.z = pos.z - 1
            rowsDone = rowsDone + 1
            dbg("Moved North, row " .. rowsDone)
        else
            dbg("Can't move North - end of farm rows after " .. rowsDone .. " rows")
            break
        end
    end

    dbgState("Farming pass complete")

    -- ── Return Path ───────────────────────────────────────────
    -- Move South until we can ascend 3 full blocks

    dbg("Searching for clearance to ascend 3 blocks...")
    setHeading(2)

    while true do
        local up1 = turtle.up()
        if up1 then
            pos.y = pos.y + 1
            local up2 = turtle.up()
            if up2 then
                pos.y = pos.y + 1
                local up3 = turtle.up()
                if up3 then
                    pos.y = pos.y + 1
                    dbg("Ascended 3 blocks successfully")
                    break
                else
                    -- Only 2 blocks of clearance, back down and try further South
                    turtle.down(); pos.y = pos.y - 1
                    turtle.down(); pos.y = pos.y - 1
                end
            else
                -- Only 1 block of clearance, back down and try further South
                turtle.down(); pos.y = pos.y - 1
            end
        end

        local moved = turtle.forward()
        if moved then
            pos.z = pos.z + 1
            dbg("Moved South looking for ascent spot, z=" .. pos.z)
        else
            print("[WARN] Blocked moving South during return - check for obstructions!")
            break
        end
    end

    dbgState("Ascended, heading home")

    -- North 11
    setHeading(0)
    move("f", 11)
    dbgState("Return: North 11")

    -- West 12
    setHeading(3)
    move("f", 12)
    dbgState("Return: West 12")

    -- North 4
    setHeading(0)
    move("f", 4)
    dbgState("Return: North 4")

    -- Down 3
    move("d", 3)
    dbgState("Return: Down 3")

    -- East 1 (home, chest in front)
    setHeading(1)
    move("f", 1)
    dbgState("Return: East 1 (home)")

    -- Drop off
    dropOff()
    clearState()

    dbgState("── Cycle END")
    print("Cycle complete. Restarting...")
    print("─────────────────────────────────")
end
