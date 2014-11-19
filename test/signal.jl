## Signal creation

# With no elements
sig = signal(1:100)
@test length(sig) == 0
@test sig.time == 1s:100s
@test samplingfreq(sig) == 1/s
@test samplingrate(sig) == 1s
@test_throws BoundsError sig[0]
@test_throws BoundsError sig[1]
@test ishomogeneous(sig)

# A matrix of 8 channels
sig = signal(1:100, reshape(1:100*8, 100, 8))
@test length(sig) == 8
@test ishomogeneous(sig)
@test sig[1] == [1:100]
@test_throws BoundsError sig[0]
@test_throws BoundsError sig[9]

# A signal with heterogeneous channels
sig = signal(1:100, [1:100], [1.:100.]*2, [big(1):100]*4)
@test length(sig) == 3
@test !ishomogeneous(sig)
@test sig[1]*4 == sig[2]*2 == sig[3] == [1:100]*4
@test_throws BoundsError sig[0]
@test_throws BoundsError sig[4]

# A signal with a group of nested signals (like spikes with snippets)
t1 = (-.2:.025:.8)./1e3
snips = signal(t1, randn(length(t1), 100))
@test length(snips) == 100
@test length(snips[1]) == length(snips.time) == length(t1)
@test isregular(snips) && ishomogeneous(snips)
@test samplingfreq(snips) == 40_000.0/s
@test samplingrate(snips) == (2.5e-5)s
spikes = signal(cumsum(rand(100)), snips)
@test length(spikes) == 1
@test spikes[1] === snips
@test !isregular(spikes) && ishomogeneous(spikes)

# Ensure we cannot build a signal with bad time vectors
@test_throws ArgumentError signal([1,2,3,2])
@test_throws ArgumentError signal([1.,2.,2.])

## Regularization:
sig = signal([0:1/100:2pi], (sin, cos))
@test !isregular(sig)
@test isregular(regularize(sig))

# Indexing by vectors returns Signals
sig = signal(1:100, reshape(1:100*8, 100, 8))
subsig = sig[2:3]
@test length(subsig) == 2
@test subsig[1] == sig[2]
@test subsig[2] == sig[3]
