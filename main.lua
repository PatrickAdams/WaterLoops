import "CoreLibs/graphics"
import "CoreLibs/timer"
import "CoreLibs/math"

local gfx <const> = playdate.graphics
local totalRings = 20
local ringWidth = 40
local ringHeight = 20
local ringThickness = 6
local pegWidth = 10
local minDistance = 80  -- Minimum distance between pegs
local maxPegY = 180  -- Maximum Y position for pegs (3/4 of the screen height)
local leftPadding = 30  -- Padding from the left edge
local rightPadding = 30  -- Padding from the right edge
local topPadding = 30  -- Padding from the top edge
local verticalPegHeight = 40  -- Shortened height for the vertical part of the peg
local horizontalPegHeight = 10  -- Height for the horizontal part of the peg
local rings = {}
local pegs = {}
local gravity = 0.25
local waterResistance = 0.010
local upwardForceBase = 4
local rotationFactor = 1.0
local score = 0
local gameOver = false

-- Function to set up the game
local function setup()
    gameOver = false
    score = 0
    rings = {}
    pegs = {}

    local screenWidth = 400
    local screenHeight = 240
    local pegCount = 4

    -- Generate random peg positions ensuring minimum distance, padding, and varying heights
    local positions = {}
    for i = 1, pegCount do
        local validPosition = false
        local x, y
        while not validPosition do
            validPosition = true
            x = math.random(leftPadding + pegWidth, screenWidth - rightPadding - pegWidth)
            y = math.random(topPadding + verticalPegHeight, maxPegY)

            -- Check distance from other pegs
            for _, pos in ipairs(positions) do
                if math.abs(x - pos.x) < minDistance then
                    validPosition = false
                    break
                end
            end
        end

        table.insert(positions, {x = x, y = y})
    end

    -- Create pegs with T shape
    for _, pos in ipairs(positions) do
        table.insert(pegs, {x = pos.x, y = pos.y, width = pegWidth, stack = 0})
    end

    -- Create rings
    local spacing = screenWidth / totalRings
    for i = 1, totalRings do
        local ring = {
            x = (i - 0.5) * spacing,
            y = 230,
            vx = 0,
            vy = 0,
            angle = math.random() * 360,
            stacked = false
        }
        table.insert(rings, ring)
    end
end

-- Function to update the game state
function playdate.update()
    gfx.clear()

    -- Draw pegs (T shapes)
    for _, peg in ipairs(pegs) do
        -- Draw vertical part of the T
        gfx.fillRect(peg.x - peg.width / 2, peg.y - verticalPegHeight, peg.width, verticalPegHeight)
        -- Draw horizontal part of the T
        gfx.fillRect(peg.x - peg.width, peg.y, peg.width * 2, horizontalPegHeight)
    end

    -- Draw score
    gfx.drawText("Score: " .. score, 320, 10)

    -- Update rings and apply 2D physics
    for i, ring in ipairs(rings) do
        if not ring.stacked then
            -- Apply gravity and resistance
            ring.vy = ring.vy + gravity
            ring.vx = ring.vx * (1 - waterResistance)

            -- Update position
            ring.x = ring.x + ring.vx
            ring.y = ring.y + ring.vy

            -- Rotate the ring based on movement
            ring.angle = ring.angle + (ring.vx + ring.vy) * rotationFactor

            -- Collision detection for scoring
            for _, peg in ipairs(pegs) do
                local pegTopY = peg.y - verticalPegHeight
                local ringInnerRadius = ringWidth / 4

                -- Check if the peg top is within the ring's open center
                if math.abs(ring.x - peg.x) < ringInnerRadius and math.abs(ring.y - pegTopY) < 5 then
                    -- The ring lands on the peg
                    ring.y = pegTopY + ringHeight / 2
                    ring.vx, ring.vy = 0, 0
                    ring.stacked = true
                    peg.stack = peg.stack + 1
                    score = score + 1
                    break
                end
            end

            -- Keep rings within screen bounds
            if ring.x < 0 then ring.x = 0; ring.vx = -ring.vx end
            if ring.x > 400 then ring.x = 400; ring.vx = -ring.vx end
            if ring.y < 0 then ring.y = 0; ring.vy = -ring.vy end
            if ring.y > 240 then ring.y = 240; ring.vy = 0 end

            -- Draw the ring as a thicker rotating oval
            gfx.pushContext()
            gfx.setDrawOffset(ring.x, ring.y)
            drawThickRotatedEllipse(0, 0, ringWidth, ringHeight, ring.angle, ringThickness)
            gfx.setDrawOffset(0, 0)
            gfx.popContext()
        end
    end

    gfx.sprite.update()

    -- Check if game over
    if score >= totalRings then
        gameOver = true
        gfx.drawText("Game Over! Press B to Restart", 80, 100)
    end
end

-- Custom function to draw a thick rotated ellipse (ring)
function drawThickRotatedEllipse(cx, cy, width, height, angle, thickness)
    local cosA = math.cos(math.rad(angle))
    local sinA = math.sin(math.rad(angle))

    -- Draw multiple concentric ellipses to simulate thickness
    for t = 0, thickness do
        local currentWidth = width - t
        local currentHeight = height - t * (height / width)
        local points = {}
        local step = math.pi / 8
        for theta = 0, 2 * math.pi, step do
            local x = currentWidth / 2 * math.cos(theta)
            local y = currentHeight / 2 * math.sin(theta)
            local rx = cosA * x - sinA * y
            local ry = sinA * x + cosA * y
            table.insert(points, {cx + rx, cy + ry})
        end

        -- Draw lines connecting the points
        for i = 1, #points - 1 do
            gfx.drawLine(points[i][1], points[i][2], points[i+1][1], points[i+1][2])
        end
        gfx.drawLine(points[#points][1], points[#points][2], points[1][1], points[1][2])
    end
end

-- Function to handle button presses with height-based force and selective influence
local function shootWater(leftForce, rightForce, area)
    print("Water jet activated!")  -- Debug: confirm function is called

    for i, ring in ipairs(rings) do
        -- Apply force only if the ring is in the relevant area and not stacked
        if not ring.stacked and ((area == "left" and ring.x < 200) or (area == "right" and ring.x >= 200)) then
            local forceFactor = 1 - (ring.y / 240)
            local upwardForce = upwardForceBase + math.random() * 2  -- Increased base upward force

            -- Update velocities
            ring.vy = ring.vy - upwardForce
            ring.vx = ring.vx + leftForce * forceFactor
            ring.vx = ring.vx + rightForce * forceFactor
            ring.angle = ring.angle + (leftForce + rightForce) * rotationFactor  -- Further increase rotation based on force

            print(string.format("Ring %d: vy=%.2f, vx=%.2f, angle=%.2f", i, ring.vy, ring.vx, ring.angle))  -- Debug: print ring velocities and angle
        end
    end
end

function playdate.AButtonDown()
    shootWater(-1.5, 0, "right")  -- Increased leftward force for A button
end

function playdate.upButtonDown()
    shootWater(0, 1.5, "left")  -- Increased rightward force for D-pad up button
end

function playdate.AButtonUp()
    if playdate.buttonIsPressed(playdate.kButtonUp) then
        shootWater(0, 1.5, "left")  -- Balance when both are pressed
    end
end

function playdate.upButtonUp()
    if playdate.buttonIsPressed(playdate.kButtonA) then
        shootWater(-1.5, 0, "right")  -- Balance when both are pressed
    end
end

function playdate.BButtonDown()
    setup()  -- Restart the game
end

setup()
