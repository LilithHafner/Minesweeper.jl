module Minesweeper

using Gtk
using Cairo: set_font_size, text_extents

export GUI3, Game3, Board2

struct GUI3
    window::GtkWindow
    mines::GtkLabel
    button::GtkButton
    flag::GtkToggleButton
    timer::GtkLabel
    canvas::GtkCanvas
    grid::Matrix{Int8}
end

function dummy_callback(grid, y, x, button)
    grid[y, x] += button ? -1 : 1
end
GUI3(width, height) = GUI3(dummy_callback, width, height)
function GUI3(callback, reset, width, height)
    vbox = GtkBox(:v)

    hbox = GtkBox(:h); push!(vbox, hbox) # construct rather than push
    mines = GtkLabel("Mines: 0"); push!(hbox, mines)
    button = GtkButton("New Game"); push!(hbox, button)
    flag = GtkToggleButton("Flag"); push!(hbox, flag)
    timer = GtkLabel("Time: 0"); push!(hbox, timer)

    grid = fill(Int8(0), height, width)
    canvas = GtkCanvas(); push!(vbox, canvas)
    set_gtk_property!(canvas, :vexpand, true)

    w = Ref(0)
    h = Ref(0)
    function paint_cell(ctx, x, y)
        # 0 = hidden, 1 = flagged, 2 = mine, 3 = blank, 4+ = number of mines around
        # set_source_rgb(ctx, 128, 128, 128)

        x0 = round(Int, (x-1)*w[]/width)
        y0 = round(Int, (y-1)*h[]/height)
        x1 = round(Int, x*w[]/width)
        y1 = round(Int, y*h[]/height)
        set_source_rgb(ctx, 0.7734375, 0.7734375, 0.7734375)
        rectangle(ctx, x0, y0, x1-x0, y1-y0)
        fill(ctx)

        scale = min(w[]/width, h[]/height)
        m1 = max(1, round(Int, min(scale/10, sqrt(scale)*.3)))
        m2 = max(2, round(Int, min(scale/6, sqrt(scale)*.5)))

        g = grid[y, x]
        if g <= 1
            set_source_rgb(ctx, 1, 1, 1)
            rectangle(ctx, x0, y0, m2, y1-y0-m2)
            rectangle(ctx, x0, y0, x1-x0-m2, m2)
            fill(ctx)
            set_source_rgb(ctx, .5, .5, .5)
            rectangle(ctx, x1-m2, y0+m2, m2, y1-y0-m2)
            rectangle(ctx, x0+m2, y1-m2, x1-x0-m2, m2)
            fill(ctx)
            if g == 1
                set_source_rgb(ctx, 1, 0, 0)
                polygon(ctx, [Point(x0+2m2, (y0+y1)/2), Point((x0+x1)/2, y0+2m2), Point(x1-2m2, (y0+y1)/2), Point((x0+x1)/2, y1-2m2)])
                fill(ctx)
            end
        elseif g != 3
            text = g == 2 ? "X" : string(g-3)
            set_font_size(ctx, scale)
            extents = text_extents(ctx, text)
            set_source_rgb(ctx, 0, 0, 0)
            move_to(ctx, (x0+x1)/2-(extents[3]/2 + extents[1]), (y0+y1)/2-(extents[4]/2 + extents[2]))
            Gtk.show_text(ctx, text)
            fill(ctx)
        end
    end

    @guarded draw(canvas) do widget
        ctx = getgc(canvas)
        w[] = Gtk.width(canvas)
        h[] = Gtk.height(canvas)

        # Paint grid
        for x in axes(grid, 2), y in axes(grid, 1)
            paint_cell(ctx, x, y)
        end
    end

    # compute grid cell
    grid_cell(event) = floor(Int, event.x/w[]*width)+1, floor(Int, event.y/h[]*height)+1

    depressed = Ref{Union{Nothing, Tuple{Int, Int}}}(nothing)
    function undepress()
        if depressed[] !== nothing
            x, y = depressed[]
            depressed[] = nothing
            grid[y, x] = 0
            paint_cell(getgc(canvas), x, y)
        end
    end
    function depress(event, flag)
        x, y = grid_cell(event)
        depressed[] === (x,y) && return
        press = checkbounds(Bool, grid, y, x) && grid[y, x] == 0 && !flag
        depressed[] === nothing && !press && return
        undepress()
        if press
            depressed[] = (x, y)
            grid[y, x] = 3
            paint_cell(getgc(canvas), x, y)
        end
        reveal(canvas, true)
    end
    for i in 1:3
        f = @guarded (w,e) -> depress(e, (i != 1) ⊻ get_gtk_property(flag, :active, Bool))
        setproperty!(canvas.mouse, Symbol(:button, i, :press), f)
        setproperty!(canvas.mouse, Symbol(:button, i, :motion), f)
        setproperty!(canvas.mouse, Symbol(:button, i, :release), @guarded (widget, event) -> begin
            must_reveal = depressed[] !== nothing
            undepress()
            x, y = grid_cell(event)
            if checkbounds(Bool, grid, y, x)
                for (y,x) in callback(grid, y, x, (i != 1) ⊻ get_gtk_property(flag, :active, Bool))
                    paint_cell(getgc(canvas), x, y)
                end
                reveal(canvas, true)
            elseif must_reveal
                reveal(canvas, true)
            end
        end)
    end

    function button_clicked_callback(widget)
        println(widget, " was clicked!")
    end

    @guarded signal_connect(button, "clicked") do widget
        reset()
        for x in axes(grid, 2), y in axes(grid, 1)
            paint = grid[y, x] != 0
            grid[y, x] = 0
            paint && paint_cell(getgc(canvas), x, y)
        end
        reveal(canvas, true)
    end

    window = GtkWindow(vbox, "Minesweeper")

    global v = vbox;
    GUI3(window, mines, button, flag, timer, canvas, grid)
end

Base.display(gui::GUI3) = showall(gui.window)

struct Board2
    mines::BitMatrix
    start_time::Base.RefValue{Float64}
end

function unsafe_popoulate!(array, count)
    array .= false
    while count > 0
        i = rand(eachindex(array))
        count -= !array[i]
        array[i] = true
    end
    array
end

function reset!(b::Board2, num_mines = count(b.mines))
    if 2num_mines ≤ length(b.mines)
        unsafe_popoulate!(b.mines, num_mines)
    else
        unsafe_popoulate!(b.mines, length(b.mines) - num_mines)
        b.mines .⊻= true
    end
    b.start_time[] = time()
    b
end

function Board2(width, height, num_mines)
    1 ≤ width || throw(ArgumentError("width must be positive"))
    1 ≤ height || throw(ArgumentError("height must be positive"))
    0 ≤ num_mines || throw(ArgumentError("num_mines must be non-negative"))
    num_mines ≤ width*height || throw(ArgumentError("Too many mines"))

    b = Board2(BitMatrix(undef, width, height), Ref(0.0))
    reset!(b, num_mines)
end

struct Game3
    board::Board2
    gui::GUI3
    gameover::Base.RefValue{Bool}
end

function Game3(width, height, num_mines)
    board = Board2(width, height, num_mines)
    gameover = Ref(false)

    function reset()
        reset!(board)
        gameover[]=false
    end

    try_reveal_neighbors(grid, y, x) = try_reveal_neighbors!(Tuple{Int, Int}[], grid, y, x)
    function try_reveal_neighbors!(revealed, grid, y, x)
        for y in max(firstindex(axes(grid, 1)),y-1):min(lastindex(axes(grid, 1)),y+1), x in max(firstindex(axes(grid, 2)),x-1):min(lastindex(axes(grid, 2)),x+1)
            try_reveal!(revealed, grid, y, x)
        end
        revealed
    end

    try_reveal(grid, y, x) = try_reveal!(Tuple{Int, Int}[], grid, y, x)
    function try_reveal!(revealed, grid, y, x)
        g = grid[y, x]
        if g == 0
            push!(revealed, (y, x))
            if board.mines[y, x]
                grid[y, x] = 2
                gameover[] = true
            else
                neighbors = sum(board.mines[max(begin,y-1):min(end,y+1), max(begin,x-1):min(end,x+1)])
                grid[y, x] = 3 + neighbors
                neighbors == 0 && try_reveal_neighbors!(revealed, grid, y, x)
            end
        end
        revealed
    end

    gui = GUI3(reset, width, height) do grid, y, x, flag
        gameover[] && return Tuple{Int, Int}[]
        g = grid[y, x]
        if flag
            if g ∈ (0,1)
                grid[y, x] = 1-g
                [(y,x)]
            else
                Tuple{Int, Int}[]
            end
        elseif !flag
            if 4 ≤ g ≤ 10
                neighbors = count(==(1), grid[max(begin,y-1):min(end,y+1), max(begin,x-1):min(end,x+1)])
                if neighbors == g-3
                    try_reveal_neighbors(grid, y, x)
                else
                    Tuple{Int, Int}[]
                end
            else
                try_reveal(grid, y, x)
            end
        end
    end
    Game3(board, gui, gameover)
end

Base.display(game::Game3) = showall(game.gui.window)

end