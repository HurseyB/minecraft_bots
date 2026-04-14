-- ============================================================
--  farmer.lua  |  CC:Tweaked Turtle Crop Collector
--  Debug mode is ON by default. Set DEBUG = false to silence.
-- ============================================================

local DEBUG = true

-- Internal State
local pos     = { x = 0, y = 0, z = 0 }
local facing  = 1  -- 0=North  1=East  2=South  3=West

local FACING_NAME = { [0]="North", [1]="East", [2]="South", [3]="West" }

-- ── Debug helpers ────────────────────────────────────────────

local function dbg(msg)
    if DEBUG then
        print("[DBG] " .. msg)
    end
end

local function dbgState(label)
    if DEBUG then
        print(string.format("[DBG] %s | facing=%s(%d) pos=(%d,%d,%d)",
            label,
            FACING_NAME[facing] or "?", facing,
            pos.x, pos.y, pos.z))
    end
end

-- ── setHeading ───────────────────────────────────────────────
--  Turns the turtle to face `target` using the shortest path.

local function setHeading(target)
    dbg("setHeading: " .. FACING_NAME[facing] .. " -> " .. FACING_NAME[target])

    local diff = (target - facing) % 4

    if diff == 0 then
        -- already facing the right way
    elseif diff == 1 then
        turtle.turnRight()
        facing = (facing + 1) % 4
    elseif diff == 2 then
        turtle.turnRight()
        turtle.turnRight()
        facing = (facing + 2) % 4
    elseif diff == 3 then
        -- 3 rights == 1 left; turn left
        turtle.turnLeft()
        facing = (facing + 3) % 4
    end

    dbg("setHeading done: now facing " .. FACING_NAME[facing])
end

-- ── move ─────────────────────────────────────────────────────
--  Moves the turtle and keeps pos in sync.
--  dir: "f" | "u" | "d"

local function move(dir, blocks)
    for i = 1, blocks do
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

            dbg(string.format("move %s %d/%d -> pos=(%d,%d,%d)",
                dir, i, blocks, pos.x, pos.y, pos.z))
        else
            -- Something is blocking the turtle
            print(string.format("[WARN] move '%s' blocked at step %d/%d | pos=(%d,%d,%d)",
                dir, i, blocks, pos.x, pos.y, pos.z))
        end
    end
end

-- ── pullItems ────────────────────────────────────────────────
--  Sucks from the chest in front until empty, keeps only
--  items in `targets`, drops everything else back.

local function pullItems(targets)
    local attempts = 0
    while turtle.suck() and attempts < 64 do
        attempts = attempts + 1
        local data = turtle.getItemDetail()
        local keep = false

        if data then
            for _, name in ipairs(targets) do
                if data.name == name then
                    keep = true
                    break
                end
            end
        end

        if keep then
            dbg("Kept: " .. (data and data.name or "?"))
        else
            turtle.drop()
            dbg("Dropped back: " .. (data and data.name or "?"))
        end
    end
    dbg("pullItems done after " .. attempts .. " pulls")
end

-- ── dropOff ──────────────────────────────────────────────────
--  Drops carrots and potatoes into whatever is in front.

local function dropOff()
    dbg("Starting drop-off")
    for i = 1, 16 do
        turtle.select(i)
        local data = turtle.getItemDetail()
        if data and (data.name:find("carrot") or data.name:find("potato")) then
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
print("Assumed start: facing=" .. FACING_NAME[facing] .. " pos=(0,0,0)")
print("Edit 'facing' at top of script if turtle is placed differently.")

while true do
    dbgState("── Cycle START")

    -- 1. Face West, forward 1
    setHeading(3)
    move("f", 1)
    dbgState("Step 1 done")

    -- 2. Face South, up 3, forward 4
    setHeading(2)
    move("u", 3)
    move("f", 4)
    dbgState("Step 2 done")

    -- 3. Face East, forward 11
    setHeading(1)
    move("f", 11)
    dbgState("Step 3 done")

    -- 4. Face South, forward 13
    setHeading(2)
    move("f", 13)
    dbgState("Step 4 done")

    -- 5. Face North, down 3, pull carrots
    setHeading(0)
    move("d", 3)
    dbgState("Step 5 before pullItems")
    pullItems({ "minecraft:carrot" })

    -- 6. Face East, forward 2
    setHeading(1)
    move("f", 2)
    dbgState("Step 6 done")

    -- 7. Face North, pull potatoes
    setHeading(0)
    dbgState("Step 7 before pullItems")
    pullItems({ "minecraft:potato", "minecraft:poisonous_potato" })

    -- 8. Up 3, forward 13
    move("u", 3)
    move("f", 13)
    dbgState("Step 8 done")

    -- 9. Face West, forward 13
    setHeading(3)
    move("f", 13)
    dbgState("Step 9 done")

    -- 10. Face North, forward 4
    setHeading(0)
    move("f", 4)
    dbgState("Step 10 done")

    -- 11. Down 3, face East, forward 1
    move("d", 3)
    setHeading(1)
    move("f", 1)
    dbgState("Step 11 done")

    -- 12. Drop off
    dropOff()
    dbgState("── Cycle END (should match Cycle START coords)")

    print("Cycle complete. Restarting...")
    print("─────────────────────────────────")
end
