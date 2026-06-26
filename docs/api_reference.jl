# ==============================================================================
# CTLie API Reference Manager
#
# Generates the API reference page via CTBase.automatic_reference_documentation
# for the single top-level CTLie module. The generated .md file is cleaned up
# after the build.
#
# The file list below mirrors the actual source tree under `src/`. Keep it in
# sync when files are added/removed/renamed, otherwise docstrings silently drop
# out of the reference and internal `@ref` links break.
# ==============================================================================

"""
    generate_api_reference(src_dir::String)

Generate the API reference documentation for CTLie. Returns the list of pages.
"""
function generate_api_reference(src_dir::String)
    # Helper to build absolute paths
    src(files...) = [abspath(joinpath(src_dir, f)) for f in files]

    EXCLUDE_BASE = Symbol[:include, :eval]

    pages = [
        CTBase.automatic_reference_documentation(;
            subdirectory="api",
            primary_modules=[
                CTLie => src(
                    "CTLie.jl",
                    "default.jl",
                    "ad.jl",
                    "ad_types.jl",
                    "lift.jl",
                    "poisson.jl",
                    "time_derivative.jl",
                    "lie_macro.jl",
                ),
            ],
            exclude=EXCLUDE_BASE,
            public=true,
            private=true,
            title="CTLie",
            title_in_menu="CTLie",
            filename="api_ctlie",
        ),
    ]

    return pages
end

"""
    with_api_reference(f::Function, src_dir::String)

Generate the API reference, execute `f(pages)`, then clean up generated `.md` files.
"""
function with_api_reference(f::Function, src_dir::String)
    pages = generate_api_reference(src_dir)
    try
        f(pages)
    finally
        docs_src = abspath(joinpath(@__DIR__, "src"))
        _cleanup_pages(docs_src, pages)
    end
end

function _cleanup_pages(docs_src::String, pages)
    for p in pages
        content = last(p)
        if content isa AbstractString
            fname = endswith(content, ".md") ? content : content * ".md"
            full_path = joinpath(docs_src, fname)
            if isfile(full_path)
                rm(full_path)
            end
        elseif content isa Vector
            _cleanup_pages(docs_src, content)
        end
    end
end
