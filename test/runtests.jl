using Signals
using Base.Test

# Signal creation

# With no elements
s = Signal(1:100)
@test length(s) == 0
@test s.time == 1:100
@test_throws BoundsError s[0]
@test_throws BoundsError s[1]
@test ishomogeneous(s)

# A matrix of 8 channels
s = Signal(1:100, reshape(1:100*8, 100, 8))
@test length(s) == 8
@test s[1] == [1:100]
@test_throws BoundsError s[0]
@test_throws BoundsError s[9]

# A signal with heterogeneous channels
s = Signal(1:100, [1:100], [1.:100.]*2, [big(1):100]*4)
@test length(s) == 3
@test s[1]*4 == s[2]*2 == s[3] == [1:100]*4
@test_throws BoundsError s[0]
@test_throws BoundsError s[4]

# A signal with a group of nested signals (like spikes with snippets)
t1 = (-.2:.025:.8)./1e3
snips = Signal(t1, randn(length(t1), 100))
@test length(snips) == 100
@test length(snips[1]) == length(snips.time) == length(t1)
spikes = Signal(cumsum(rand(100)), snips)
@test length(spikes) == 1
@test spikes[1] === snips

# Ensure we cannot build a signal with bad time vectors
@test_throws ArgumentError Signal([1,2,3,2])
@test_throws ArgumentError Signal([1.,2.,2.])
