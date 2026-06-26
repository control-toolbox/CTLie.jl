# to run the documentation generation: julia --project=. docs/make.jl
# to serve the documentation (option 1 — handles clean URLs natively):
#   npx serve docs/build/1 --listen 5173
# to serve the documentation (option 2 — Julia only):
#   julia --project=docs -e 'using LiveServer; LiveServer.serve(dir="docs/build/1", single_page=true)'
pushfirst!(LOAD_PATH, joinpath(@__DIR__))
pushfirst!(LOAD_PATH, joinpath(@__DIR__, ".."))

using Documenter
using DocumenterVitepress
using DocumenterInterLinks
using CTLie
using CTBase
using Markdown
using MarkdownAST: MarkdownAST

# trigger AD backend extension (needed for @example blocks calling ad/Poisson/∂ₜ)
using ForwardDiff
using DifferentiationInterface

# ═══════════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════════
draft = false # Draft mode: if true, @example blocks in markdown are not executed

# ═══════════════════════════════════════════════════════════════════════════════
# Cross-package links (InterLinks)
# ═══════════════════════════════════════════════════════════════════════════════
links = InterLinks(
    "CTBase" => (
        "https://control-toolbox.org/CTBase.jl/stable/",
        "https://control-toolbox.org/CTBase.jl/stable/objects.inv",
        joinpath(@__DIR__, "inventories", "CTBase.toml"),
    ),
)

# ═══════════════════════════════════════════════════════════════════════════════
# Docstrings from external packages / API reference manager
# ═══════════════════════════════════════════════════════════════════════════════
const DocumenterReference = Base.get_extension(CTBase, :DocumenterReference)

if !isnothing(DocumenterReference)
    DocumenterReference.reset_config!()
end

# ═══════════════════════════════════════════════════════════════════════════════
# Repository configuration
# ═══════════════════════════════════════════════════════════════════════════════
repo_url = "github.com/control-toolbox/CTLie.jl"
src_dir = abspath(joinpath(@__DIR__, "..", "src"))

# Include the API reference manager
include("api_reference.jl")

# ═══════════════════════════════════════════════════════════════════════════════
# Build documentation
# ═══════════════════════════════════════════════════════════════════════════════

with_api_reference(src_dir) do api_pages
    return makedocs(;
        draft=draft,
        remotes=nothing, # Disable remote links. Needed for DocumenterReference
        # external_cross_references: the published CTBase inventory is stable (0.24);
        # CTLie targets unreleased CTBase 0.25, so @extref links resolve once 0.25 ships.
        warnonly=[:cross_references, :external_cross_references],
        sitename="CTLie.jl",
        format=DocumenterVitepress.MarkdownVitepress(;
            repo=repo_url,
            devbranch="main",
            devurl="dev",
            sidebar_drawer=true,
        ),
        pages=[
            "Introduction" => "index.md",
            "Hamiltonian lift" => "lift.md",
            "Lie derivative & bracket" => "lie_derivative_bracket.md",
            "Poisson bracket" => "poisson.md",
            "Partial time derivative" => "time_derivative.md",
            "The @Lie macro" => "lie_macro.md",
            "Limitations & configuration" => "limitations.md",
            "API Reference" => api_pages,
        ],
        plugins=[links],
    )
end

# ═══════════════════════════════════════════════════════════════════════════════
# Deploy documentation to GitHub Pages
# ═══════════════════════════════════════════════════════════════════════════════
DocumenterVitepress.deploydocs(;
    repo=repo_url * ".git", devbranch="main", push_preview=true
)
