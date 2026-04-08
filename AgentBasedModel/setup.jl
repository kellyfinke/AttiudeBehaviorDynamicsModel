import Pkg

println("Activating project in current directory...")
Pkg.activate(@__DIR__)

println("Instantiating dependencies...")
Pkg.instantiate()

println("Precompiling...")
Pkg.precompile()


# --- OPTIONAL: install IJulia globally (to run .ipynb files)---
Pkg.activate()   # activates the default/global environment
Pkg.add("IJulia")
Pkg.build("IJulia")

println("IJulia installed.")

println("Done.")