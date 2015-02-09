## Signal creation

# With no elements
sig = Signal(1:100)
@test length(sig) == 0
@test isempty(collect(sig))
@test sig.time == 1s:100s
@test samplingfreq(sig) == 1/s
@test samplingrate(sig) == 1s
@test_throws BoundsError sig[0]
@test_throws BoundsError sig[1]

# A matrix of 8 channels
sig = Signal(1:100, reshape(1:100*8, 100, 8))
@test length(sig) == 8
@test sig[1] == [1:100]
@test all([sig[i] == [(1:100)+100*(i-1)] for i=1:length(sig)])
@test length(collect(sig)) == 8
@test_throws BoundsError sig[0]
@test_throws BoundsError sig[9]
sig2 = reshape(sig, 4, 2)
@test collect(sig) == collect(sig2)

sig = Signal(1:100, [1:100 [1.:100.]*2 [1:100]*4])
@test length(sig) == 3
@test sig[1]*4 == sig[2]*2 == sig[3] == [1:100]*4
@test_throws BoundsError sig[0]
@test_throws BoundsError sig[4]

# A Signal with a group of nested Signals (like spikes with snippets)
t1 = (-.2:.025:.8)./1e3
snips = Signal(t1, randn(length(t1), 100))
@test length(snips) == 100
@test length(snips[1]) == length(snips.time) == length(t1)
@test isregular(snips)
@test samplingfreq(snips) == 40_000.0/s
@test samplingrate(snips) == (2.5e-5)s
spikes = Signal(cumsum(rand(100)), snips)
@test length(spikes) == 1
@test spikes[1] == snips
@test !isregular(spikes)

# Ensure we cannot build a Signal with bad time vectors
@test_throws ArgumentError Signal([1,2,3,2])
@test_throws ArgumentError Signal([1.,2.,2.])

## Regularization:
sig = Signal([0:1/100:2pi], [sin, cos])
@test !isregular(sig)
@test isregular(regularize(sig))

# Indexing by vectors returns Signals
sig = Signal(1:100, reshape(1:100*8, 100, 8))
subsig = sig[2:3]
@test length(subsig) == 2
@test subsig[1] == sig[2]
@test subsig[2] == sig[3]
