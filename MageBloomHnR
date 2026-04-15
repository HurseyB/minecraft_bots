-- Simple Auto-Harvester (Storage on Right)
-- Setup: Face the crop. Place a chest to the RIGHT of the turtle.

local function harvestAndReplant()
    print("Harvesting mature crop...")
    turtle.dig()   -- Harvest
    turtle.place() -- Replant (Assumes seeds/crops are in Slot 1)
end

local function depositItems()
    -- 3. Suck up items dropped on the ground
    turtle.suck()
    
    print("Depositing to chest...")
    -- 4. Turn Right
    turtle.turnRight()
    
    -- 5. Store inventory (keeping Slot 1 for seeds)
    for i = 2, 16 do
        turtle.select(i)
        if turtle.getItemCount() > 0 then
            turtle.drop()
        end
    end
    
    -- Back to Slot 1 and face the crop again
    turtle.select(1)
    turtle.turnLeft()
end

print("Farmer Turtle Active. Press Ctrl+T to stop.")

while true do
    -- 1. Inspect crop
    local success, data = turtle.inspect()
    
    local isMature = false
    if success then
        -- Standard maturity for Wheat/Carrots/Potatoes is age 7
        if data.state and data.state.age == 7 then
            isMature = true
        end
    else
        print("No crop detected! Check placement.")
    end

    -- 2. Logic for harvesting
    if isMature then
        harvestAndReplant()
        -- 3-5. Suck, Turn Right, Store, Turn Left
        depositItems()
    else
        -- 2a. Wait and repeat
        print("Still growing... waiting 30 seconds.")
        sleep(30)
    end
    
    -- 6. Repeat All
end
