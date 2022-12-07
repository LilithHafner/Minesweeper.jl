using Minesweeper
using Documenter

DocMeta.setdocmeta!(Minesweeper, :DocTestSetup, :(using Minesweeper); recursive=true)

makedocs(;
    modules=[Minesweeper],
    authors="Lilith Hafner <Lilith.Hafner@gmail.com> and contributors",
    repo="https://github.com/LilithHafner/Minesweeper.jl/blob/{commit}{path}#{line}",
    sitename="Minesweeper.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://LilithHafner.github.io/Minesweeper.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/LilithHafner/Minesweeper.jl",
    devbranch="main",
)
