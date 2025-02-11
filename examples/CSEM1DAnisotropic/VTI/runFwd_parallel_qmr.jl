#---------------------------------------------------------------------------------
# script to perform 3D EM isotropic/anisotropic forward modeling in parallel mode
#---------------------------------------------------------------------------------

using Distributed
addprocs(2)       # the number of parallel processes

# Adding the parent directory of the EM3DANI package directory to LOAD_PATH,
# you can either use an absolute or a relative path:

#@everywhere push!(LOAD_PATH, "/home/username/code")     # absolute path, for example
@everywhere push!(LOAD_PATH, pwd() * "/../../../..")        # relative path


@everywhere begin

  using Printf
  using EM3DANI.EMFileIO
  using EM3DANI.EMFwdSolver
  using EM3DANI.LinearSolver

  # Setting the number of threads (only useful for the direct solver)
  #ENV["OMP_NUM_THREADS"] = 1
  #ENV["MKL_NUM_THREADS"] = 1
end
#------------------------------------------------------------------------------
# begin timing
totaltime = @elapsed begin

println("Getting started ...")

# Problem type, "csem" or "mt"
probType = "csem"

#----------------------- read data file and model file ------------------------#
# data file
datafile = "0.25Hz_inline_broadside.dat"
@printf("%-60s", "Reading data file $(datafile):")
t = @elapsed emData = readEMData(datafile, probType)
@printf("%8.4f %s\n", t, "seconds.")

# model file
modfile = "canonical1D_vti.mod"
@printf("%-60s", "Reading model file $(modfile):")
t = @elapsed emMesh = readEMModel(modfile, sigAir=1e-8, sigWater=3.3)
@printf("%8.4f %s\n", t, "seconds.")

# Since we are using the secondary-field approach, a reference model need
# to be given
refModel = RefModel(zeros(3), zeros(3))
refModel.sig1D   = [1e-8, 3.3, 1.0]
refModel.depth1D = [-emMesh.origin[3], 0, 1000.]

pids = workers()   # get the ID of worker processes

# Parameter setting for linear solvers
# direct solvers
#lsParm = DirectSolverParm()
#lsParm.solverName = :mumps
#lsParm.solverName = :mklpardiso

# iterative solvers
lsParm = IterativeSolverParm()
lsParm.iterMethod = :qmr
lsParm.tol = 1e-6
lsParm.prec = :aphi

# Calling the parallel forward modeling function
fwdResp, = parsolveEM3DFwd(emMesh, emData, refModel, lsParm, pids)

# Output the result
respfile = "0.25Hz_inline_broadside_QMR_np2-new.resp"
println("Writing out the forward responses ...")
writeEMFwdResp(respfile, emData, fwdResp)


println("=== Finishing forward problem ===")

end  # @elapsed
@printf("%s %10.2f %s\n", "========== Total elapsed time:", totaltime, "seconds. ==========")
