module Signals

import Base: elsize
import ArrayViews: view
import Sparklines: spark

export Signal, ishomogeneous, iscontinuous, channeltypes

include("signal.jl")

end # module
