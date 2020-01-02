#include <stdio.h>
#include <iostream>
#include <assert.h>
#include <cuda.h>

#include "core/pack/Pack.h"
#include "core/pack/GetInds.h"
#include "core/pack/GetDims.h"
#include "core/utils/CudaErrorCheck.cu"
#include "core/utils/CudaSizes.h"

#include "core/mapreduce/GpuConv1D.h"

namespace keops {

struct GpuConv1D_FromHost {
  
  template<typename TYPE, class FUN>
  static int Eval_(FUN fun, int nx, int ny, TYPE **px_h, TYPE **py_h, TYPE **pp_h) {
    
    typedef typename FUN::DIMSX DIMSX;
    typedef typename FUN::DIMSY DIMSY;
    typedef typename FUN::DIMSP DIMSP;
    const int DIMX = DIMSX::SUM;
    const int DIMY = DIMSY::SUM;
    const int DIMP = DIMSP::SUM;
    const int DIMOUT = FUN::DIM; // dimension of output variable
    const int DIMFOUT = DIMSX::FIRST;     // DIMFOUT is dimension of output variable of inner function
    const int SIZEI = DIMSX::SIZE;
    const int SIZEJ = DIMSY::SIZE;
    const int SIZEP = DIMSP::SIZE;
    
    // pointers to device data
    TYPE *x_d, *y_d, *param_d;
    
    // device arrays of pointers to device data
    TYPE **px_d, **py_d, **pp_d;
    
    // single cudaMalloc
    void **p_data;
    CudaSafeCall(cudaMalloc((void **) &p_data,
                            sizeof(TYPE *) * (SIZEI + SIZEJ + SIZEP)
                            + sizeof(TYPE) * (DIMP + nx * (DIMX - DIMFOUT + DIMOUT) + ny * DIMY)));
    
    TYPE **p_data_a = (TYPE **) p_data;
    px_d = p_data_a;
    p_data_a += SIZEI;
    py_d = p_data_a;
    p_data_a += SIZEJ;
    pp_d = p_data_a;
    p_data_a += SIZEP;
    TYPE *p_data_b = (TYPE *) p_data_a;
    param_d = p_data_b;
    p_data_b += DIMP;
    x_d = p_data_b;
    p_data_b += nx * (DIMX - DIMFOUT + DIMOUT);
    y_d = p_data_b;
    
    // host arrays of pointers to device data
    TYPE *phx_d[SIZEI];
    TYPE *phy_d[SIZEJ];
    TYPE *php_d[SIZEP];
    
    int nvals;
    // if DIMSP is empty (i.e. no parameter), nvals = -1 which could result in a segfault
    if (SIZEP > 0) {
      php_d[0] = param_d;
      nvals = DIMSP::VAL(0);
      CudaSafeCall(cudaMemcpy(php_d[0], pp_h[0], sizeof(TYPE) * nvals, cudaMemcpyHostToDevice));
      
      for (int k = 1; k < SIZEP; k++) {
        php_d[k] = php_d[k - 1] + nvals;
        nvals = DIMSP::VAL(k);
        CudaSafeCall(cudaMemcpy(php_d[k], pp_h[k], sizeof(TYPE) * nvals, cudaMemcpyHostToDevice));
      }
    }
    
    phx_d[0] = x_d;
    nvals = nx * DIMOUT;
    for (int k = 1; k < SIZEI; k++) {
      phx_d[k] = phx_d[k - 1] + nvals;
      nvals = nx * DIMSX::VAL(k);
      CudaSafeCall(cudaMemcpy(phx_d[k], px_h[k], sizeof(TYPE) * nvals, cudaMemcpyHostToDevice));
    }
    
    // if DIMSY is empty (i.e. no Vj variable), nvals = -1 which could result in a segfault
    if (SIZEJ > 0) {
      phy_d[0] = y_d;
      nvals = ny * DIMSY::VAL(0);
      CudaSafeCall(cudaMemcpy(phy_d[0], py_h[0], sizeof(TYPE) * nvals, cudaMemcpyHostToDevice));
      
      for (int k = 1; k < SIZEJ; k++) {
        phy_d[k] = phy_d[k - 1] + nvals;
        nvals = ny * (int) DIMSY::VAL(k);
        CudaSafeCall(cudaMemcpy(phy_d[k], py_h[k], sizeof(TYPE) * nvals, cudaMemcpyHostToDevice));
      }
    }
    
    // copy arrays of pointers
    CudaSafeCall(cudaMemcpy(pp_d, php_d, SIZEP * sizeof(TYPE *), cudaMemcpyHostToDevice));
    CudaSafeCall(cudaMemcpy(px_d, phx_d, SIZEI * sizeof(TYPE *), cudaMemcpyHostToDevice));
    CudaSafeCall(cudaMemcpy(py_d, phy_d, SIZEJ * sizeof(TYPE *), cudaMemcpyHostToDevice));
    
    // Compute on device : grid and block are both 1d
    int dev = -1;
    CudaSafeCall(cudaGetDevice(&dev));
    
    dim3 blockSize;
    
    SetGpuProps(dev);
    
    // warning : blockSize.x was previously set to CUDA_BLOCK_SIZE; currently CUDA_BLOCK_SIZE value is used as a bound.
    blockSize.x = ::std::min(CUDA_BLOCK_SIZE,
                             ::std::min(maxThreadsPerBlock, (int) (sharedMemPerBlock / ::std::max(1, (int) (DIMY * sizeof(TYPE)))))); // number of threads in each block
    
    dim3 gridSize;
    gridSize.x = nx / blockSize.x + (nx % blockSize.x == 0 ? 0 : 1);
    
    // Size of the SharedData : blockSize.x*(DIMY)*sizeof(TYPE)
    GpuConv1DOnDevice<TYPE> << < gridSize, blockSize, blockSize.x * (DIMY) * sizeof(TYPE) >>
                                                      > (fun, nx, ny, px_d, py_d, pp_d);
    
    // block until the device has completed
    CudaSafeCall(cudaDeviceSynchronize());
    CudaCheckError();
    
    // Send data from device to host.
    CudaSafeCall(cudaMemcpy(*px_h, x_d, sizeof(TYPE) * (nx * DIMOUT), cudaMemcpyDeviceToHost));
    
    // Free memory.
    CudaSafeCall(cudaFree(p_data));
    
    return 0;
  }

// and use getlist to enroll them into "pointers arrays" px and py.
  template<typename TYPE, class FUN, typename... Args>
  static int Eval(FUN fun, int nx, int ny, int device_id, TYPE *x1_h, Args... args) {
    
    if (device_id != -1)
      CudaSafeCall(cudaSetDevice(device_id));
    
    typedef typename FUN::VARSI VARSI;
    typedef typename FUN::VARSJ VARSJ;
    typedef typename FUN::VARSP VARSP;
    
    const int SIZEI = VARSI::SIZE + 1;
    const int SIZEJ = VARSJ::SIZE;
    const int SIZEP = VARSP::SIZE;
    
    using DIMSX = GetDims<VARSI>;
    using DIMSY = GetDims<VARSJ>;
    using DIMSP = GetDims<VARSP>;
    
    using INDSI = GetInds<VARSI>;
    using INDSJ = GetInds<VARSJ>;
    using INDSP = GetInds<VARSP>;
    
    TYPE *px_h[SIZEI];
    TYPE *py_h[SIZEJ];
    TYPE *pp_h[SIZEP];
    
    px_h[0] = x1_h;
    getlist<INDSI>(px_h + 1, args...);
    getlist<INDSJ>(py_h, args...);
    getlist<INDSP>(pp_h, args...);
    
    return Eval_(fun, nx, ny, px_h, py_h, pp_h);
    
  }

// same without the device_id argument
  template<typename TYPE, class FUN, typename... Args>
  static int Eval(FUN fun, int nx, int ny, TYPE *x1_h, Args... args) {
    return Eval(fun, nx, ny, -1, x1_h, args...);
  }

// Idem, but with args given as an array of arrays, instead of an explicit list of arrays
  template<typename TYPE, class FUN>
  static int Eval(FUN fun, int nx, int ny, TYPE *x1_h, TYPE **args, int device_id = -1) {
    
    // We set the GPU device on which computations will be performed
    if (device_id != -1)
      CudaSafeCall(cudaSetDevice(device_id));
    
    typedef typename FUN::VARSI VARSI;
    typedef typename FUN::VARSJ VARSJ;
    typedef typename FUN::VARSP VARSP;
    
    const int SIZEI = VARSI::SIZE + 1;
    const int SIZEJ = VARSJ::SIZE;
    const int SIZEP = VARSP::SIZE;
    
    using DIMSX = GetDims<VARSI>;
    using DIMSY = GetDims<VARSJ>;
    using DIMSP = GetDims<VARSP>;
    
    using INDSI = GetInds<VARSI>;
    using INDSJ = GetInds<VARSJ>;
    using INDSP = GetInds<VARSP>;
    
    TYPE *px_h[SIZEI];
    TYPE *py_h[SIZEJ];
    TYPE *pp_h[SIZEP];
    
    px_h[0] = x1_h;
    for (int i = 1; i < SIZEI; i++)
      px_h[i] = args[INDSI::VAL(i - 1)];
    for (int i = 0; i < SIZEJ; i++)
      py_h[i] = args[INDSJ::VAL(i)];
    for (int i = 0; i < SIZEP; i++)
      pp_h[i] = args[INDSP::VAL(i)];
    
    return Eval_(fun, nx, ny, px_h, py_h, pp_h);
    
  }
  
};


extern "C" int GpuReduc1D_FromHost(int nx, int ny, __TYPE__ *gamma, __TYPE__ **args, int device_id = -1) {
  return Eval< F, GpuConv1D_FromHost >::Run(nx, ny, gamma, args, device_id);
}

}