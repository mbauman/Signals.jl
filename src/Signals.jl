module Signals

# Functions Signals extend
import Base: elsize
import ArrayViews: view
import Sparklines: spark
import Grid: interp

export Signal,
       RegularSignal,
       regularize,
       isregular,
       ishomogeneous,
       channeltypes,
       interp

include("signal.jl")
include("interpolation.jl")

end # module
