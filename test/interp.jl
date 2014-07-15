# Test interpolation

# RegularSignal -> RegularSignal
t = 0:0.25:10
sig = signal(t, [t])
ti = .8s:.8s:8s
si = interp(sig, ti)
@test_approx_eq si[1] [float(x) for x in ti]

# IrregularSignal -> RegularSignal
t = [0.01, 0.09, 0.14, 0.16, 0.22, 0.24, 0.31, 0.41, 0.45, 0.46, 0.52, 0.56, 0.6, 0.64, 0.67, 0.74, 0.78, 0.82, 0.88, 0.93]
sig = signal([t],[t],2*[t],-[t])
ti = .1s:.1s:.9s
si = interp(sig,ti)
@test_approx_eq si[1] [float(x) for x in ti]
@test_approx_eq si[2] 2*[float(x) for x in ti]
@test_approx_eq si[3] -[float(x) for x in ti]

# Test interpolating a ContinuousView
sig = signal([t], [t 2t -t])
si = interp(sig,ti)
@test_approx_eq si[1] [float(x) for x in ti]
@test_approx_eq si[2] 2*[float(x) for x in ti]
@test_approx_eq si[3] -[float(x) for x in ti]
