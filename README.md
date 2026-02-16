# PiccoloDocsTemplate

Simply

```
Pkg.add(url="https://github.com/harmoniqs/PiccoloDocsTemplate.jl", rev="v0.3.0")
Pkg.instantiate()
```

and then add a

```
using MyPackageHere
using PiccoloDocsTemplate

pages = [ ... ]

generate_docs( ... )
```

## usage notes

By default, `make_index=true`, which means the README.md for the package is used to create the index page (for Documenter, via `index.md`). Because of some rendering differences between github and documenter, sometimes we have annotate sections in the README so that our `index.md` file for Documenter is correct.

1. You can hide text from the README, which needs to be included into index.md via html comment blocks. Github will not render the content of these, our `generate_index` function strips out the content inside of the comment, and replaces that entire line with the content like so (view in editor to see text content):

```
<!--This will only show in the index.md in our documentation pages.-->
Here's a sentence that will only be displayed on the Github README <!--It gets replaced by *this* sentence in the index.md.-->
Here's a sentence that will only be displayed on the Github README (and is just deleted from the docs pages) <!---->
Here's a sentence that get's displayed in both places
```

2. Code blocks with julia syntax highlighting *and* marked "example" will be included into our index.md as `@example` blocks, thus being run as example code blocks when building our documentation, and warning at documentation build that the block(s) fail.

(in README)

### example code

```julia example
1 + 1
```

(what gets generated in index.md, nothing at end suppresses output for index pages)
```@example
1 + 1
nothing # hide
```
