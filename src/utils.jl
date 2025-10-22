export generate_docs

using Documenter
using Literate

function generate_index(root::String)
    open(normpath(joinpath(root, "src", "index.md")), write=true) do io
        lines = collect(eachline(normpath(joinpath(root, "..", "README.md"))))
        for line in lines
            if occursin("<!--", line) && occursin("-->", line)
                comment_content = match(r"<!--(.*)-->", line).captures[1]
                write(io, comment_content * "\n")
            else
                write(io, line * "\n")
            end
        end

        in_julia_block = false
        for line in lines
            # skip short julia repl exprs
            if occursin("```julia", line)
                continue
            end

            # replace julia code blocks with @example blocks for Documenter to run
            # to determine correctness and compat with latest version of repo
            if occursin("```julia example", line)
                write(io, "```@example\n")
                in_julia_block = true
            elseif in_julia_block && occursin("```", line)
                write(io, "nothing # hide\n```\n")
                in_julia_block = false
            else
                write(io, line * "\n")
            end
        end
    end
end

function generate_literate(root::String)
    src = normpath(joinpath(root, "src"))
    lit = normpath(joinpath(root, "literate"))

    lit_output = joinpath(src, "generated")

    for (root, _, files) ∈ walkdir(lit), file ∈ files
        splitext(file)[2] == ".jl" || continue
        ipath = joinpath(root, file)
        opath = splitdir(replace(ipath, lit=>lit_output))[1]
        println(ipath)
        println(opath)
        Literate.markdown(ipath, opath)
    end
end

function generate_assets(root::String)
    src = normpath(joinpath(root, "src"))
    assets = normpath(joinpath(root, "..", "assets"))

    assets_output = joinpath(src, "assets")

    cp(assets, assets_output, force=true)
end


function generate_docs(
    root::String,
    package_name::String,
    modules::Union{Module, Vector{Module}},
    pages::Vector;
    make_index=true,
    make_literate=true,
    make_assets=true,
    repo="github.com/harmoniqs/" * package_name * ".jl.git",
    versions=["dev" => "dev", "stable" => "v^", "v#.#"],
    format_kwargs=NamedTuple(),
    makedocs_kwargs=NamedTuple(),
    deploydocs_kwargs=NamedTuple(),
    doctest_setup_meta_args::Dict{Module, Expr} = Dict{Module, Expr}(),
)
    @info "Building Documenter site for " * package_name * ".jl"

    if modules isa Module
        modules = [modules]
    end

    if make_index
        generate_index(root)
    end

    if make_literate
        generate_literate(root)
    end

    if make_assets
        generate_assets(root)
    end

    format = Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        # canonical="",
        edit_link="main",
        assets=String[],
        mathengine = MathJax3(Dict(
            :loader => Dict("load" => ["[tex]/physics"]),
            :tex => Dict(
                "inlineMath" => [["\$","\$"], ["\\(","\\)"]],
                "tags" => "ams",
                "packages" => [
                    "base",
                    "ams",
                    "autoload",
                    "physics"
                ],
                "macros" => Dict(
                    "minimize" => ["\\underset{#1}{\\operatorname{minimize}}", 1],
                )
            ),
        )),
        format_kwargs...,
    )

    # for each mod in modules, make a call to DocMeta.setdocmeta!(module, :DocTestSetup, doctest_setup_meta_args; recursive=true)
    for mod in modules
        if haskey(doctest_setup_meta_args, mod)
            DocMeta.setdocmeta!(mod, :DocTestSetup, doctest_setup_meta_args[mod]; recursive=true)
        end
    end

    makedocs(;
        modules=modules,
        authors="Aaron Trowbridge <aaron.j.trowbridge@gmail.com> and contributors",
        sitename=package_name * ".jl",
        format=format,
        pages=pages,
        pagesonly=true,
        warnonly=true,
        draft=false,
        makedocs_kwargs...,
    )

    deploydocs(;
        repo=repo,
        devbranch="main",
        versions=versions,
        deploydocs_kwargs...,
    )
end
