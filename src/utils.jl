export generate_docs

using Documenter
using Literate

function add_draft_to_meta(str::String)
    draft_meta_string = """
    # ```@meta
    # Draft = true
    # ```

    """

    return draft_meta_string * str
end

function generate_index(root::String)
    open(normpath(joinpath(root, "src", "index.md")), write = true) do io
        lines = collect(eachline(normpath(joinpath(root, "..", "README.md"))))

        for (i, line) in enumerate(lines)
            if occursin("<!--", line) && occursin("-->", line)
                comment_content = match(r"<!--(.*)-->", line).captures[1]
                lines[i] = comment_content
            else
                lines[i] = line
            end
        end

        in_julia_block = false
        for (i, line) in enumerate(lines)
            # skip short julia repl exprs
            if occursin("```julia", line)
                lines[i] = line
            end

            # replace julia code blocks with @example blocks for Documenter to run
            # to determine correctness and compat with latest version of repo
            if occursin("```julia example", line)
                lines[i] = "```@example"
                in_julia_block = true
            elseif in_julia_block && occursin("```", line)
                lines[i] = "nothing # hide\n```"
                in_julia_block = false
            else
                lines[i] = line
            end
        end

        write(io, join(lines, "\n"))
    end
end

function generate_literate(
    root::String;
    draft_pages::Vector = String[],
    literate_kwargs::NamedTuple = NamedTuple(),
)
    src = normpath(joinpath(root, "src"))
    lit = normpath(joinpath(root, "literate"))

    lit_output = joinpath(src, "generated")

    for (root, _, files) ∈ walkdir(lit), file ∈ files
        splitext(file)[2] == ".jl" || continue
        ipath = joinpath(root, file)
        opath = splitdir(replace(ipath, lit => lit_output))[1]
        if file in draft_pages
            Literate.markdown(
                ipath,
                opath;
                preprocess = add_draft_to_meta,
                literate_kwargs...,
            )
        else
            Literate.markdown(ipath, opath; literate_kwargs...)
        end
    end
end

function generate_assets(root::String)
    src = normpath(joinpath(root, "src"))
    assets = normpath(joinpath(root, "..", "assets"))

    assets_output = joinpath(src, "assets")

    cp(assets, assets_output, force = true)
end


"""
    _mask_cached_solve!(build_dir)

Walk HTML files in `build_dir` and replace `cached_solve!` with `solve!`,
stripping the cache name argument so end users see clean API calls.
Skips `lib.html` (API reference) where `cached_solve!` should remain documented.
"""
function _mask_cached_solve!(build_dir::String)
    for (root, _, files) in walkdir(build_dir)
        for file in files
            endswith(file, ".html") || continue
            path = joinpath(root, file)

            # Skip API reference — cached_solve! is a real exported function
            endswith(path, "lib.html") && continue

            content = read(path, String)
            original = content

            # 1. Rename function
            content = replace(content, "cached_solve!" => "solve!")

            # 2. Strip name arg — single-line: solve!(var, "name"; → solve!(var;
            #    Handles HTML-entity quotes (&quot;, &#34;) and raw quotes
            content = replace(
                content,
                r"solve!\((\w+),\s*(?:&quot;|&#34;|\")[^\"&]*(?:&quot;|&#34;|\")\s*;" =>
                    s"solve!(\1;",
            )

            # 3. Strip name arg — single-line no kwargs: solve!(var, "name") → solve!(var)
            content = replace(
                content,
                r"solve!\((\w+),\s*(?:&quot;|&#34;|\")[^\"&]*(?:&quot;|&#34;|\")\s*\)" =>
                    s"solve!(\1)",
            )

            # 4. Strip name arg — multi-line: var,\n    "name"; → var;
            content = replace(
                content,
                r"(\w+),\s*\n(\s*)(?:&quot;|&#34;|\")[^\"&\n]*(?:&quot;|&#34;|\")\s*;" =>
                    s"\1;",
            )

            content != original && write(path, content)
        end
    end
end


function generate_docs(
    root::String,
    package_name::String,
    modules::Union{Module,Vector{Module}},
    pages::Vector;
    make_index = true,
    make_literate = true,
    make_assets = true,
    literate_draft_pages::Vector = String[],    # must be a subset of literate pages inside of `src/literate`
    literate_kwargs::NamedTuple = NamedTuple(),    # kwargs passed to Literate.markdown (e.g. execute=false)
    repo = "github.com/harmoniqs/" * package_name * ".jl.git",
    versions = ["stable" => "v^", "v#.#", "dev" => "dev"],
    format_kwargs = NamedTuple(),
    makedocs_kwargs = NamedTuple(),
    deploydocs_kwargs = NamedTuple(),
    doctest_setup_meta_args::Dict{Module,Expr} = Dict{Module,Expr}(),
    mask_cached_solve::Bool = false,
)
    @info "Building Documenter site for " * package_name * ".jl"

    if modules isa Module
        modules = [modules]
    end

    if make_index
        generate_index(root)
    end

    if make_literate
        generate_literate(
            root,
            draft_pages = literate_draft_pages,
            literate_kwargs = literate_kwargs,
        )
    end

    if make_assets
        generate_assets(root)
    end

    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        # canonical="",
        edit_link = "main",
        assets = String[],
        mathengine = MathJax3(
            Dict(
                :loader => Dict("load" => ["[tex]/physics"]),
                :tex => Dict(
                    "inlineMath" => [["\$", "\$"], ["\\(", "\\)"]],
                    "tags" => "ams",
                    "packages" => ["base", "ams", "autoload", "physics"],
                    "macros" => Dict(
                        "minimize" => ["\\underset{#1}{\\operatorname{minimize}}", 1],
                    ),
                ),
            ),
        ),
        format_kwargs...,
    )

    # for each mod in modules, make a call to DocMeta.setdocmeta!(module, :DocTestSetup, doctest_setup_meta_args; recursive=true)
    for mod in modules
        if haskey(doctest_setup_meta_args, mod)
            DocMeta.setdocmeta!(
                mod,
                :DocTestSetup,
                doctest_setup_meta_args[mod];
                recursive = true,
            )
        end
    end

    makedocs(;
        modules = modules,
        authors = "Aaron Trowbridge <aaron.j.trowbridge@gmail.com> and contributors",
        sitename = package_name * ".jl",
        format = format,
        pages = pages,
        pagesonly = true,
        warnonly = true,
        draft = false,
        makedocs_kwargs...,
    )

    if mask_cached_solve
        _mask_cached_solve!(joinpath(root, "build"))
    end

    # Documenter.jl only deploys for push, workflow_dispatch, or schedule events.
    # TagBot triggers docs via repository_dispatch, which Documenter rejects.
    # Override the event name so versioned docs actually deploy.
    if get(ENV, "GITHUB_EVENT_NAME", "") == "repository_dispatch"
        ENV["GITHUB_EVENT_NAME"] = "push"
    end

    deploydocs(; repo = repo, devbranch = "main", versions = versions, deploydocs_kwargs...)
end
