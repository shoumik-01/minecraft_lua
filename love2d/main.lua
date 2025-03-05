-- Enhanced Pong Game in LÖVE 2D
-- Author: Shoumik Hasan (with enhancements)
-- Version: 2.0

-- Game states
local GAME_STATE = {
    MENU = 1,
    PLAYING = 2,
    GAME_OVER = 3
}

-- Current game state
local currentState = GAME_STATE.MENU

-- Game window settings
-- WINDOW_WIDTH = 800
-- WINDOW_HEIGHT = 600

-- Paddle settings
PADDLE_WIDTH = 12
PADDLE_HEIGHT = 90
PADDLE_SPEED = 450

-- Ball settings
BALL_SIZE = 12
BALL_SPEED_X = 380
BALL_SPEED_Y = 280
BALL_BASE_SPEED_X = 380 -- To reset after power-up expires

-- Win condition
WIN_SCORE = 5

-- Trail effect settings
MAX_TRAIL_POINTS = 10
trailPoints = {}

-- Power-up box settings
POWER_UP_WIDTH = 90
POWER_UP_HEIGHT = 90
POWER_UP_DURATION = 5 -- in seconds
POWER_UP_SPAWN_CHANCE = 0.005 -- chance per frame to spawn a power-up
powerUpActive = false
powerUpVisible = false
powerUpTimer = 0
powerUpBox = {
    x = 0,
    y = 0,
    width = POWER_UP_WIDTH,
    height = POWER_UP_HEIGHT
}

-- AI settings (for single player)
AI_ENABLED = false
AI_DIFFICULTY = 0.9 -- 0 to 1, higher is harder

-- Initialize paddles, ball, and game state
function love.load()
    love.window.setTitle("Enhanced Pong")
    love.window.setMode(0, 0, { 
        fullscreen = true,
        vsync = 1,
        msaa = 4
    })
    WINDOW_WIDTH, WINDOW_HEIGHT = love.graphics.getDimensions()
    -- Audio support
    sounds = {
        paddleHit = love.audio.newSource("sounds/paddle_hit.wav", "static"),
        wallHit = love.audio.newSource("sounds/wall_hit.wav", "static"),
        score = love.audio.newSource("sounds/score.wav", "static"),
        -- menuSelect = love.audio.newSource("sounds/menu_select.wav", "static"),
        powerUp = love.audio.newSource("sounds/powerup.wav", "static")
    }
    -- Set default font to something larger
    font = love.graphics.newFont(16)
    bigFont = love.graphics.newFont(32)
    menuFont = love.graphics.newFont(64)
    love.graphics.setFont(font)

    resetGame()
end

function resetGame()
    -- Left paddle (Player 1)
    player1 = { x = 20, y = (WINDOW_HEIGHT - PADDLE_HEIGHT) / 2, score = 0 }

    -- Right paddle (Player 2 or AI)
    player2 = { x = WINDOW_WIDTH - 30, y = (WINDOW_HEIGHT - PADDLE_HEIGHT) / 2, score = 0 }

    -- Ball
    ball = {
        x = WINDOW_WIDTH / 2 - BALL_SIZE / 2,
        y = WINDOW_HEIGHT / 2 - BALL_SIZE / 2,
        dx = BALL_SPEED_X,
        dy = BALL_SPEED_Y
    }

    -- Reset trail
    trailPoints = {}
    
    -- Reset power-up
    powerUpActive = false
    powerUpVisible = false
    powerUpTimer = 0
end

-- Handle input events
function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif currentState == GAME_STATE.MENU then
        if key == "1" then
            AI_ENABLED = false
            currentState = GAME_STATE.PLAYING
            resetGame()
        elseif key == "2" then
            AI_ENABLED = true
            currentState = GAME_STATE.PLAYING
            resetGame()
        end
    elseif currentState == GAME_STATE.GAME_OVER then
        if key == "return" or key == "space" then
            currentState = GAME_STATE.MENU
        end
    end
end

-- Update the game state
function love.update(dt)
    if currentState == GAME_STATE.PLAYING then
        updatePlaying(dt)
    end
end

function updatePlaying(dt)
    -- Player 1 controls (W/S)
    if love.keyboard.isDown("w") then
        player1.y = math.max(0, player1.y - PADDLE_SPEED * dt)
    elseif love.keyboard.isDown("s") then
        player1.y = math.min(WINDOW_HEIGHT - PADDLE_HEIGHT, player1.y + PADDLE_SPEED * dt)
    end

    -- Player 2 controls (Up/Down) or AI
    if not AI_ENABLED then
        if love.keyboard.isDown("up") then
            player2.y = math.max(0, player2.y - PADDLE_SPEED * dt)
        elseif love.keyboard.isDown("down") then
            player2.y = math.min(WINDOW_HEIGHT - PADDLE_HEIGHT, player2.y + PADDLE_SPEED * dt)
        end
    else
        -- AI movement
        updateAI(dt)
    end

    -- Update trail effect (store current ball position)
    table.insert(trailPoints, 1, {x = ball.x, y = ball.y})
    if #trailPoints > MAX_TRAIL_POINTS then
        table.remove(trailPoints)
    end

    -- Ball movement
    ball.x = ball.x + ball.dx * dt
    ball.y = ball.y + ball.dy * dt

    -- Ball collision with top and bottom
    if ball.y <= 0 or ball.y + BALL_SIZE >= WINDOW_HEIGHT then
        ball.dy = -ball.dy
        sounds.wallHit:stop()
        sounds.wallHit:play()
        -- Push the ball away from the wall slightly
        if ball.y <= 0 then
            ball.y = 1  -- Small offset from top wall
        else
            ball.y = WINDOW_HEIGHT - BALL_SIZE - 1  -- Small offset from bottom wall
        end
    end

    -- Ball collision with paddles
    if checkCollision(ball, player1) then
        ball.dx = math.abs(ball.dx) -- Reflect ball to the right
        -- Add a slight angle change based on where the ball hits the paddle
        local paddleCenter = player1.y + PADDLE_HEIGHT / 2
        local ballCenter = ball.y + BALL_SIZE / 2
        local offsetFactor = (ballCenter - paddleCenter) / (PADDLE_HEIGHT / 2)
        ball.dy = ball.dy + offsetFactor * 100
        sounds.paddleHit:stop()  -- Stop any currently playing instance
        sounds.paddleHit:play()
    elseif checkCollision(ball, player2) then
        ball.dx = -math.abs(ball.dx) -- Reflect ball to the left
        -- Add a slight angle change based on where the ball hits the paddle
        local paddleCenter = player2.y + PADDLE_HEIGHT / 2
        local ballCenter = ball.y + BALL_SIZE / 2
        local offsetFactor = (ballCenter - paddleCenter) / (PADDLE_HEIGHT / 2)
        ball.dy = ball.dy + offsetFactor * 100
        sounds.paddleHit:stop()  -- Stop any currently playing instance
        sounds.paddleHit:play()
    end

    -- Ball out of bounds (scoring)
    if ball.x < 0 then
        sounds.score:play()
        player2.score = player2.score + 1
        checkWinCondition()
        resetBall()
    elseif ball.x > WINDOW_WIDTH then
        sounds.score:play()
        player1.score = player1.score + 1
        checkWinCondition()
        resetBall()
    end

    -- Power-up logic
    updatePowerUp(dt)
end

function updateAI(dt)
    local targetY = ball.y + BALL_SIZE / 2 - PADDLE_HEIGHT / 2
    
    -- Add some "thinking" delay based on difficulty
    if ball.dx > 0 then -- Only move when ball is coming towards AI
        -- Add some imperfection to the AI
        local reactionOffset = (1 - AI_DIFFICULTY) * 100
        targetY = targetY + math.random(-reactionOffset, reactionOffset)
        
        -- Move towards the target position
        local moveSpeed = PADDLE_SPEED * AI_DIFFICULTY
        if player2.y + PADDLE_HEIGHT / 2 < targetY then
            player2.y = math.min(WINDOW_HEIGHT - PADDLE_HEIGHT, player2.y + moveSpeed * dt)
        else
            player2.y = math.max(0, player2.y - moveSpeed * dt)
        end
    end
end

function updatePowerUp(dt)
    -- Random chance to spawn a power-up if none is active
    if not powerUpVisible and not powerUpActive and math.random() < POWER_UP_SPAWN_CHANCE then
        spawnPowerUp()
    end
    
    -- Check if ball collides with power-up
    if powerUpVisible and checkCollisionWithPowerUp() then
        activatePowerUp()
    end
    
    -- Update power-up timer if active
    if powerUpActive then
        powerUpTimer = powerUpTimer - dt
        if powerUpTimer <= 0 then
            deactivatePowerUp()
        end
    end
end

function spawnPowerUp()
    powerUpBox.x = WINDOW_WIDTH / 2 - POWER_UP_WIDTH / 2
    powerUpBox.y = WINDOW_HEIGHT / 2 - POWER_UP_HEIGHT / 2
    powerUpVisible = true
end

function checkCollisionWithPowerUp()
    return ball.x < powerUpBox.x + powerUpBox.width and
           ball.x + BALL_SIZE > powerUpBox.x and
           ball.y < powerUpBox.y + powerUpBox.height and
           ball.y + BALL_SIZE > powerUpBox.y
end

function activatePowerUp()
    sounds.powerUp:play()
    powerUpVisible = false
    powerUpActive = true
    powerUpTimer = POWER_UP_DURATION
    
    -- Double the ball speed
    ball.dx = ball.dx * 2
    ball.dy = ball.dy * 2
end

function deactivatePowerUp()
    powerUpActive = false
    
    -- Reset ball speed to normal
    ball.dx = ball.dx / 2
    ball.dy = ball.dy / 2
end

function checkWinCondition()
    if player1.score >= WIN_SCORE or player2.score >= WIN_SCORE then
        currentState = GAME_STATE.GAME_OVER
    end
end

-- Draw the game
function love.draw()
    if currentState == GAME_STATE.MENU then
        drawMenu()
    elseif currentState == GAME_STATE.PLAYING then
        drawGame()
    elseif currentState == GAME_STATE.GAME_OVER then
        drawGameOver()
    end
end

function drawMenu()
    love.graphics.setFont(menuFont)
    love.graphics.printf("PONG", 0, WINDOW_HEIGHT / 4, WINDOW_WIDTH, "center")
    
    love.graphics.setFont(bigFont)
    love.graphics.printf("Press 1 for Two Player Mode", 0, WINDOW_HEIGHT / 2, WINDOW_WIDTH, "center")
    love.graphics.printf("Press 2 for Single Player Mode", 0, WINDOW_HEIGHT / 2 + 50, WINDOW_WIDTH, "center")
    
    love.graphics.setFont(font)
    love.graphics.printf("Player 1: W/S to move", 0, WINDOW_HEIGHT - 100, WINDOW_WIDTH, "center")
    love.graphics.printf("Player 2: Up/Down to move", 0, WINDOW_HEIGHT - 75, WINDOW_WIDTH, "center")
    love.graphics.printf("Press ESC to quit", 0, WINDOW_HEIGHT - 50, WINDOW_WIDTH, "center")
end

function drawGame()
    -- Draw center line
    for y = 0, WINDOW_HEIGHT, 30 do
        love.graphics.rectangle("fill", WINDOW_WIDTH / 2 - 2, y, 4, 15)
    end
    
    -- Draw ball trail
    for i, point in ipairs(trailPoints) do
        local alpha = 1 - (i / #trailPoints)
        love.graphics.setColor(1, 1, 1, alpha * 0.5)
        local size = BALL_SIZE * (1 - (i / #trailPoints) * 0.5)
        love.graphics.rectangle("fill", point.x + (BALL_SIZE - size) / 2, point.y + (BALL_SIZE - size) / 2, size, size)
    end
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Draw paddles
    love.graphics.rectangle("fill", player1.x, player1.y, PADDLE_WIDTH, PADDLE_HEIGHT)
    love.graphics.rectangle("fill", player2.x, player2.y, PADDLE_WIDTH, PADDLE_HEIGHT)

    -- Draw ball
    love.graphics.rectangle("fill", ball.x, ball.y, BALL_SIZE, BALL_SIZE)

    -- Draw power-up box if visible
    if powerUpVisible then
        love.graphics.setColor(1, 0.3, 0.3, 1) -- Red color for power-up
        love.graphics.rectangle("fill", powerUpBox.x, powerUpBox.y, powerUpBox.width, powerUpBox.height)
        love.graphics.setColor(1, 1, 1, 1) -- Reset color
    end
    
    -- Draw power-up indicator if active
    if powerUpActive then
        love.graphics.setColor(1, 0.3, 0.3, 1)
        love.graphics.printf("SPEED BOOST: " .. math.ceil(powerUpTimer), 0, 50, WINDOW_WIDTH, "center")
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- Draw scores in the top corners
    love.graphics.setFont(bigFont)
    love.graphics.print("Player 1: " .. player1.score, 50, 20)
    love.graphics.print("Player 2: " .. player2.score, WINDOW_WIDTH - 200, 20)
    
    -- Reset font
    love.graphics.setFont(font)
    
    -- Draw game mode indicator
    local gameMode = AI_ENABLED and "Single Player" or "Two Players"
    love.graphics.printf(gameMode, 0, 20, WINDOW_WIDTH, "center")
    
    -- Draw first to win indicator in bottom left corner
    love.graphics.print("First to " .. WIN_SCORE .. " wins!", 20, WINDOW_HEIGHT - 30)
end

function drawGameOver()
    love.graphics.setFont(menuFont)
    love.graphics.printf("GAME OVER", 0, WINDOW_HEIGHT / 4, WINDOW_WIDTH, "center")
    
    love.graphics.setFont(bigFont)
    local winner = player1.score >= WIN_SCORE and "Player 1" or "Player 2"
    if AI_ENABLED and winner == "Player 2" then
        winner = "Computer"
    end
    love.graphics.printf(winner .. " Wins!", 0, WINDOW_HEIGHT / 2, WINDOW_WIDTH, "center")
    
    love.graphics.setFont(font)
    love.graphics.printf("Final Score: " .. player1.score .. " - " .. player2.score, 0, WINDOW_HEIGHT / 2 + 50, WINDOW_WIDTH, "center")
    love.graphics.printf("Press ENTER to return to menu", 0, WINDOW_HEIGHT - 50, WINDOW_WIDTH, "center")
end

-- Check if ball collides with a paddle
function checkCollision(b, p)
    return b.x < p.x + PADDLE_WIDTH and
           b.x + BALL_SIZE > p.x and
           b.y < p.y + PADDLE_HEIGHT and
           b.y + BALL_SIZE > p.y
end

-- Reset ball to center
function resetBall()
    ball.x = WINDOW_WIDTH / 2 - BALL_SIZE / 2
    ball.y = WINDOW_HEIGHT / 2 - BALL_SIZE / 2
    ball.dx = BALL_SPEED_X * (math.random(2) == 1 and 1 or -1) -- Randomize direction
    ball.dy = BALL_SPEED_Y * (math.random(2) == 1 and 1 or -1)
    
    -- Reset trail
    trailPoints = {}
    
    -- Reset any active power-ups
    powerUpActive = false
    powerUpVisible = false
end
