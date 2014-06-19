using Signals
using Base.Test

# Signal creation

# With no elements
s = Signal(1:100)
@test length(s) == 0
@test s.time == 1:100
@test_throws BoundsError s[0]
@test_throws BoundsError s[1]

# A matrix of 8 channels
s = Signal(1:100, reshape(1:100*8, 100, 8))
@assert length(s) == 8
@assert s[1] == [1:100]
@test_throws BoundsError s[0]
@test_throws BoundsError s[9]

# A signal with heterogeneous channels
s = Signal(1:100, [1:100], [1.:100.]*2, [big(1):100]*4)
@assert length(s) == 3
@assert s[1]*4 == s[2]*2 == s[3] == [1:100]*4
@test_throws BoundsError s[0]
@test_throws BoundsError s[4]
