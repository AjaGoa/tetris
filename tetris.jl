using GameZero, Random, Colors

# Tetrominos
	I = [
		2 2 2 2 ]

	J = [
		3 3 3;
		3 0 0]

	L = [
		4 4 4;
		0 0 4]

	O = [
		5 5 0;
		5 5 0]

	T = [
		0 6 0;
		6 6 6]

	S = [
		0 7 7;
		7 7 0]

	Z = [	
		1 1 0;
		0 1 1] 

# Konstatny
	BASE = 27
	w = 10
	h = 20
	WIDTH = w*BASE
	HEIGHT = h*BASE
	BACKGROUND = colorant"slateblue1"
    PIECES = (Z, I, J, L, O, T, S) # tuple - static
	COLORS = ("cyan", "blue", "green", "yellow", "hotpink", "red", "orange")
    
    colors = [parse(Colorant, c) for c in COLORS]
    
mutable struct Piece
    #custom data structure: https://www.youtube.com/watch?v=e5_PUNZdDsQ

    pattern::Matrix{Int}
    x::Int	#top left corner
    y::Int
    color::Int
    #axis_L::Int
    #axis_R::Int #axis of rotation
end

mutable struct GameState
    board::Matrix{Int}
    piece::Piece
    next_piece::Piece
    held_piece::Union{Piece, Int}  # allow 0 as initial value
    change_count::Bool
    lines::Int
    level::Int
    speed::Int
    timer::Int
    gameover::Bool
    startscreen::Bool
end

function new_piece()

    idx = rand(1:length(PIECES)) #chosing random position to then choose from PIECES tuple
    return Piece(PIECES[idx], div(w, 2) - 1, 0, idx) #v colors +1 protoze tam je jeste cerna
    #gives Piece of (pattern corresponding to idx, x = horizontal center, y = top, corresponding color)
     
end

function init_game_state()
    return GameState(
        fill(0, h + 1, w),  # board
        new_piece(),        # current piece
        new_piece(),        # next piece
        0,                  # held_piece (none)
        false,              # change_count
        0,                  # lines
        1,                  # level
        20,                 # speed
        0,                  # timer
        false,              # gameover
        true                # startscreen
    )
end

global gs = init_game_state() 

# Drawing functions
    function drawSquare(g::Game, x::Int, y::Int, color)

        r = GameZero.Rect(x*BASE, y*BASE, BASE, BASE)
        GameZero.draw(g.screen, r, color, fill = true)
    end

    function drawBoard(g::Game, board, piece)
        # Draw locked board
        for y in 2:h, x in 1:w 
            # leaving one row empty for info
            if board[y, x] == 0
                C = colorant"black"
            else
                C = colors[board[y, x]]
            end
            drawSquare(g, x - 1, y - 1, C)
        end
    
        # draw current piece over the board (without modifying board)
        if gs.piece !== nothing
            hp, wp = size(piece.pattern)
    
            for i in 1:hp, j in 1:wp
                if piece.pattern[i, j] != 0
                    x = piece.x + j
                    y = piece.y + i
                    if 1 ≤ x ≤ w && 2 ≤ y ≤ h   # only draw inside visible board (start from line 2)
                        if piece.pattern[i, j] == 0
                            C = colorant"black"
                        else
                            C = colors[piece.pattern[i, j]]
                        end
                        drawSquare(g, x - 1, y - 1, C) # - 1 to go from board (1, 1) start indexing to graphics (0, 0 )
                    end
                end
            end
        end
    end
    
    function drawNextPiece(g::Game, next_piece)
        height = 3
        width = (w - 2)*BASE
        
        for x in 1:size(next_piece.pattern, 2), y in 1:size(next_piece.pattern, 1)
            #size(next_piece.pattern, 1) --> # of rows, size(.., 2) --> # of columns
            a, b = size(next_piece.pattern)
            if a > b
                s = div(BASE, a) 
            
            else
                s = div(BASE, b) 
            end
            
            rectH = height + (y-1)*s
            rectW = width + (x-1)*s
            q = GameZero.Rect(rectW, rectH, s, s) 
            
            if next_piece.pattern[y,x] != 0
                GameZero.draw(g.screen, q, colors[next_piece.pattern[y,x]], fill = true)
            end        
        end
    end

    function drawheldPiece(g::Game, held_piece)
        # vykresleni held piece, checknout že nejde podvádět :)   
        if held_piece != 0    
            # nastaveni pozice
            height = 3
            width = (w - 4)*BASE    
            a, b = size(held_piece.pattern)
            if a > b
                s = div(BASE, a) - 1 # - 1 aby se mi to vlezlo do horniho radku
            else
                s = div(BASE, b) - 1
            end
            for x in 1:size(held_piece.pattern, 2), y in 1:size(held_piece.pattern, 1)  
                rectH = height + (y-1)*s
                rectW = width + (x-1)*s
                q = GameZero.Rect(rectW, rectH, s, s) 

                if held_piece.pattern[y,x] != 0
                    GameZero.draw(g.screen, q, colors[held_piece.pattern[y,x]], fill = true)
                end
            end
        end        
    end

function collisions(piece, board)
    
    for i in 1:size(piece.pattern, 1), j in 1:size(piece.pattern, 2)
        # i - rows, j - columns
        piece.pattern[i, j] == 0 && continue # Skip empty cells in the piece pattern, doesnt neetd to go through everything
        #if piece.pattern[i, j] != 1 # Check if the cell is part of the piece
            #if i, j position part of some piece, empty ones are ignored

            x = piece.x + j
            y = piece.y + i
            # switching into general x, y position

            (x < 1 || x > w || y > h || (y > 0 && board[y, x] != 0)) && return true
            #if left wall collision OR right wall OR floor OR anoher block

                #return true # Collision detected
    end
    return false # No collision
end

function lock_piece(gs::GameState) 

    check = true #to avoid printing another piece after gameover
    gs.change_count = false #reset "A" feature

    for i in 1:size(gs.piece.pattern, 1), j in 1:size(gs.piece.pattern, 2)
        #size(p.pattern, 1) --> # of rows, size(.., 2) --> # of columns

        if gs.piece.pattern[i, j] != 0 && gs.piece.y + i > 0
            #if filled and not above the board then

            if 1 <= gs.piece.y + i <= h && 1 <= gs.piece.x + j <= w
                #if piece doesnt exceed the board 

                gs.board[gs.piece.y + i, gs.piece.x + j] = gs.piece.color  #change: int(p.color)
            #storing color --> occupied place in the grid			
            end
        
        elseif gs.piece.y  <= 1
            check = false
            gs.gameover = true
            play_sound("game_over")
        end
    end

    if check == true
        clear_lines(gs)
        gs.piece, gs.next_piece = gs.next_piece, new_piece() 
    
    end 
end

function clear_lines(gs::GameState)
    #clearing lines
	rows, cols = size(gs.board)

    full_rows = [all(cell != 0 for cell in gs.board[r, :]) for r in 1:rows]
		#detect full rows, gives boolean array

    num_full = count(full_rows)
		#how many full rows
		#do nothning if non detected

    if num_full > 0
        # Remove full rows by shifting down non-full rows
		gs.lines = gs.lines + num_full
        new_board = fill(0, rows, cols)  # Start with an empty board

        # Copy only the remaining rows downward
        new_row_idx = rows
        for r in rows:-1:1  # Start from the bottom and move up
            if !full_rows[r]  # keep non-full rows
                new_board[new_row_idx, :] = gs.board[r, :]
                new_row_idx -= 1
            end
        end
        
        # Update board in-place
        gs.board = new_board
    end
	level_up(gs)
end

function finish(g::Game, board)
	
	for v in 5:10, t in 1:w
		board[v, t] = 6
	end 
    
	over_text_1 = TextActor("GAME OVER!", "comicbd", color = [0, 1, 0, 0])
	over_text_1.pos = (BASE*2, BASE*4)
    
	over_text_2 = TextActor("Level: $(gs.level)", "comicbd", color = [0, 1, 0, 0])
	over_text_2.pos = (BASE*2, BASE*6)

    over_text_3 = TextActor("To play again press ENTER", "comicbd", font_size = 16, color = [0, 1, 0, 0])
    over_text_3.pos = (BASE/2, BASE*8)

    GameZero.draw(over_text_1)
    GameZero.draw(over_text_2)
    GameZero.draw(over_text_3)
end

function start(g::Game)
    
    start_text_1 = TextActor("Instructions:", "comicbd", color = [0, 1, 0, 0], font_size = 18)
    start_text_1.pos = (BASE/2, BASE)
    GameZero.draw(start_text_1)
    
    instructions = [
        "LEFT arrow = move left",
        "RIGHT arrow = move right",
        "DOWN arrow = speed up falling",
        "UP arrow = rotate",
        "SPACE = drop",
        "A = hold",
        "ESC = pause"
        ]
    
    text_actors = [
        TextActor(instr, "comicbd", color=[0, 1, 0, 0], font_size=14)
        for instr in instructions
    ]
    
    for (i, actor) in enumerate(text_actors)
        actor.pos = (BASE/2, BASE * (2 + i)) 
        GameZero.draw(actor)
    end
    
    start_text_1 = TextActor("Press ENTER to Start", "comicbd", color = [0, 1, 0, 0], font_size = 18)
    start_text_1.pos = (BASE/2, BASE*11)
    GameZero.draw(start_text_1)  

end

function rotate_left(piece)
    # common filled place is 1st line, 2nd position
    x, y = size(piece.pattern)
    new_pattern = fill(0, (y, x)) # Create a new pattern with swapped dimensions
    
    for i in 1:x, j in 1:y
        new_pattern[y - j + 1, i] = piece.pattern[i, j]
    end
    piece.pattern = new_pattern
    # just flipped transposed
end

#= function rotate_left(piece)
    next version with square matrix where I fix one center pivot point (added to piece struct) and then eliminate it, but still dont have a way how to redefine the position of the pivot in the new matrix
    x, y = size(piece.pattern)
    M_size = max(x, y)
    new_pattern = fill(1, (M_size, M_size))
    fin_p = fill(1, (y, x))
    
    if M_size % 2 != 0
        center = div(M_size, 2) + 1
        # Rotate counter-clockwise around the center
        for i in 1:x, j in 1:y
            if piece.pattern[i, j] != 1
                new_i = center - (j - center)
                new_j = center + (i - center)
                new_pattern[new_i, new_j] = piece.pattern[i, j]
            end
        end
        full_rows = [all(cell != 1 for cell in new_pattern[r, :]) for r in 1:M_size]
        new_row_idx = M_size
        for r in M_size:-1:1  # Start from the bottom and move up
            if !full_rows[r]  # keep non-full rows
                new_pattern_2[new_row_idx, :] = new_pattern[r, :]
                new_row_idx -= 1
            end
        end

        #stejne akorat pro sloupce    full_rows = [all(cell != 1 for cell in new_pattern[r, :]) for r in 1:M_size]
    else
        # For even sizes, use Julia's built-in rotation
        fin_p = rotr90(piece.pattern)
    end
    
    return new_pattern  # Actually return the rotated pattern
end
=# 
#moving functions

    function move_down(gs::GameState)
    
        gs.piece.y += 1
        if collisions(gs.piece, gs.board)
            gs.piece.y -= 1 #return to the last pre-collision position
            lock_piece(gs)
            
        end
    end


    function move_left(gs::GameState)
        gs.piece.x -= 1
        #abreviation on x of move_down
        if collisions(gs.piece, gs.board)
            gs.piece.x += 1
        end
    end

    function move_right(gs::GameState)
        gs.piece.x += 1
        
        if collisions(gs.piece, gs.board)
            gs.piece.x -= 1
        end
    end

    function rotate(gs::GameState)
        new_pattern = rotate_left(gs.piece) #transposed turned
        old_pattern = gs.piece.pattern
        gs.piece.pattern = new_pattern #redefining the current piece.pattern by variables
        
        if collisions(gs.piece, gs.board)
            gs.piece.pattern = old_pattern
            #if collision, preventing the rotation
        end
    end

    function fall(gs)
        #for quick "fall"
        
        while !collisions(gs.piece, gs.board)
            gs.piece.y += 1
            #moving down as long as there are no collisions
        end
        gs.piece.y -= 1 #returns to the last pre-collision position
         
    end

    function hold(gs::GameState)
        
        now_playing = deepcopy(gs.piece) #!! https://www.jlhub.com/julia/manual/en/function/deepcopy
        if gs.change_count == false
            play_sound("retro")
            if gs.held_piece == 0
                gs.held_piece = now_playing 
                gs.piece = new_piece()
        
            else gs.held_piece != 0
                gs.piece, gs.held_piece = gs.held_piece, now_playing
                gs.piece.x = div(w, 2) - 1 
                gs.piece.y = 0 
            end
            gs.change_count = true
        else
            play_sound("access-denied")
        end
    end
 
function on_key_down(g::Game, key)
    global gs
    if gs.startscreen
        if key == 13  # Enter key
            gs.startscreen = false  # Start the game
            play_sound("start_game")
        end
    
    elseif gs.gameover
        if key == 13  # Enter key
            gs = init_game_state()  # Restart the game
            gs.startscreen = false 
            play_sound("applause")
        end
    end 
    
    if key == 27  # Escape key
        gs.startscreen = true  # Go back to the start screen
        gs.gameover = false
    end
    if key == 1073741905
        move_down(gs)
    elseif key == 	1073741904
        move_left(gs)
    elseif key == 1073741903
        move_right(gs)
    elseif key == 1073741906
        #up arrow
        rotate(gs)
    elseif key == 32
        #space
        fall(gs)
        #play_sound("hard_drop")
    elseif key == 97
        #a
        hold(gs)
    end
end

function level_up(gs::GameState)
       
    if gs.lines >= 1
        rest = mod(gs.lines, 2)  
        change = div(gs.lines - rest, 2)
        gs.lines = rest
        #if gs.speed > 0 + change # originally to avoid negative speed and just stay at speed 0, but actually it is not be a problem
            gs.speed = gs.speed - change
        #=else 
            gs.speed = 0
        end=#
        gs.level = gs.level + change
    end
    
end

function update(g::Game)
    global gs
    if gs.startscreen == false       
        if gs.gameover == false
            gs.timer += 1 

            if gs.timer > gs.speed
                move_down(gs)
                gs.timer = 0
            #=
            DeepSeek suggest
            Garbage collection - clean unused data from the memory, doesnt need to run every cycle
            https://www.jlhub.com/julia/manual/en/function/gc
            if rand() < 0.01  # ~1% chance to run GC (example)
                GC.gc()
            end =#
            end	
        end
    end
end

function draw(g::Game)
    global gs
    
    if gs.startscreen
        start(g)

    else
        drawBoard(g, gs.board, gs.piece)
        text_level = TextActor("Level: $(gs.level)", "comicbd", color = [0, 1, 0, 0], font_size = 18)
        text_level.pos = (BASE, 0)
        GameZero.draw(text_level)
        drawNextPiece(g, gs.next_piece)
        drawheldPiece(g, gs.held_piece)
       
        if gs.gameover
            finish(g, gs.board)
            
        end
    end
end

#= 
why not using 0 in shapes? array  start from 1, now added if/else, but that feels slightly ugly
why empty rows/cols? I thought that rotr90 could rotate only square matrices, but that is actually not true
faster collisions checking? fair
own rotate? actually just rewritten rotr90 right now :/
which axis? rotr90 - transposed and "turned" upside down, probably no axis
no symbolic key codes? (g.keyboard.XY for some reason not working for me)
why 0+change? thought it would be problem to have negative speed, but again not true
how did you get sounds? 
rotate left? 
quit? 
what A should do?
instructions how to start?
2.7 GB - dont know what to do with that, maybe by always rewriting the whole board, Im not sure what GC.gc() does - clear the unused old.pattern (and similar things)?
=#