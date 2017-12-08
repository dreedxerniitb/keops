// nvcc -std=c++11 -Xcompiler -fPIC -shared -o allconvs.so allconvs.cu
// this produces one shared library with all convolutions for radial kernels, but templated...

#include "GpuConv2D.cu"
#include "CudaScalarRadialKernels.h"

// http://www.parashift.com/c++-faq-lite/separate-template-fn-defn-from-decl.html
#define DECLARE_Conv2D_SCALARRADIAL_EVALS(TYPE,DIMPOINT,DIMVECT,FUN) \
	template int GpuConv2D(ScalarRadialKernel<TYPE,DIMPOINT,DIMVECT,FUN>::sEval, ScalarRadialKernel<TYPE,DIMPOINT,DIMVECT,FUN>, int, int, TYPE*, TYPE*, TYPE*, TYPE*); \
	template int GpuConv2D(ScalarRadialKernel<TYPE,DIMPOINT,DIMVECT,FUN>::sGrad1, ScalarRadialKernel<TYPE,DIMPOINT,DIMVECT,FUN>, int, int, TYPE*, TYPE*, TYPE*, TYPE*, TYPE*); \
	template int GpuConv2D(ScalarRadialKernel<TYPE,DIMPOINT,DIMVECT,FUN>::sGrad, ScalarRadialKernel<TYPE,DIMPOINT,DIMVECT,FUN>, int, int, TYPE*, TYPE*, TYPE*, TYPE*, TYPE*, TYPE*, TYPE*); \
	template int GpuConv2D(ScalarRadialKernel<TYPE,DIMPOINT,DIMVECT,FUN>::sHess, ScalarRadialKernel<TYPE,DIMPOINT,DIMVECT,FUN>, int, int, TYPE*, TYPE*, TYPE*, TYPE*, TYPE*, TYPE*, TYPE*); \
	template int GpuConv2D(ScalarRadialKernel<TYPE,DIMPOINT,DIMVECT,FUN>::sDiff, ScalarRadialKernel<TYPE,DIMPOINT,DIMVECT,FUN>, int, int, TYPE*, TYPE*, TYPE*, TYPE*, TYPE*, TYPE*);

#define DECLARE_Conv2D_SCALARRADIAL_FUNS(TYPE,DIMPOINT,DIMVECT) \
	DECLARE_Conv2D_SCALARRADIAL_EVALS(TYPE,DIMPOINT,DIMVECT,CauchyFunction<TYPE>) \
	DECLARE_Conv2D_SCALARRADIAL_EVALS(TYPE,DIMPOINT,DIMVECT,GaussFunction<TYPE>) \
	DECLARE_Conv2D_SCALARRADIAL_EVALS(TYPE,DIMPOINT,DIMVECT,LaplaceFunction<TYPE>) \
	DECLARE_Conv2D_SCALARRADIAL_EVALS(TYPE,DIMPOINT,DIMVECT,EnergyFunction<TYPE>) \
	DECLARE_Conv2D_SCALARRADIAL_EVALS(TYPE,DIMPOINT,DIMVECT,Sum4CauchyFunction<TYPE>) \
	DECLARE_Conv2D_SCALARRADIAL_EVALS(TYPE,DIMPOINT,DIMVECT,Sum4GaussFunction<TYPE>)

#define DECLARE_Conv2D_SCALARRADIAL_DIMVECT(TYPE,DIMPOINT) \
	DECLARE_Conv2D_SCALARRADIAL_FUNS(TYPE,DIMPOINT,1) \
	DECLARE_Conv2D_SCALARRADIAL_FUNS(TYPE,DIMPOINT,2) \
	DECLARE_Conv2D_SCALARRADIAL_FUNS(TYPE,DIMPOINT,3)

#define DECLARE_Conv2D_SCALARRADIAL_DIMPOINT(TYPE) \
	DECLARE_Conv2D_SCALARRADIAL_DIMVECT(TYPE,1) \
	DECLARE_Conv2D_SCALARRADIAL_DIMVECT(TYPE,2) \
	DECLARE_Conv2D_SCALARRADIAL_DIMVECT(TYPE,3)

DECLARE_Conv2D_SCALARRADIAL_DIMPOINT(float)
DECLARE_Conv2D_SCALARRADIAL_DIMPOINT(double)

