/*
   This file is part of the libds by b. Charlier and J. Glaunes
*/

#include <stdio.h>
#include <assert.h>
#include <cuda.h>
#include "kernels.cx"
#include "fshape_gpu_dxi.cx"

#define UseCudaOnDoubles USE_DOUBLE_PRECISION

//////////////////////////////////////////////////////
/////////// CPU -> GPU -> CPU routines ///////////////
//////////////////////////////////////////////////////

template <typename TYPE>
int fshape_gpu_dxi(double ooSigmax2,double ooSigmaf2, double ooSigmaXi2,
                   TYPE* x_h, TYPE* y_h,
                   TYPE* f_h, TYPE* g_h,
                   TYPE* alpha_h, TYPE* beta_h,
                   TYPE* gamma_h,
                   int dimPoint, int dimSig, int dimVect, int nx, int ny) {

    // Data on the device.
    TYPE* x_d;
    TYPE* y_d;
    TYPE* f_d;
    TYPE* g_d;
    TYPE* alpha_d;
    TYPE* beta_d;
    TYPE* gamma_d;

    // Allocate arrays on device.
    cudaMalloc((void**)&x_d, sizeof(TYPE)*(nx*dimPoint));
    cudaMalloc((void**)&y_d, sizeof(TYPE)*(ny*dimPoint));
    cudaMalloc((void**)&f_d, sizeof(TYPE)*(nx*dimSig));
    cudaMalloc((void**)&g_d, sizeof(TYPE)*(ny*dimSig));
    cudaMalloc((void**)&alpha_d, sizeof(TYPE)*(nx*dimVect));
    cudaMalloc((void**)&beta_d, sizeof(TYPE)*(ny*dimVect));
    cudaMalloc((void**)&gamma_d, sizeof(TYPE)*nx*dimVect);

    // Send data from host to device.
    cudaMemcpy(x_d, x_h, sizeof(TYPE)*(nx*dimPoint), cudaMemcpyHostToDevice);
    cudaMemcpy(y_d, y_h, sizeof(TYPE)*(ny*dimPoint), cudaMemcpyHostToDevice);
    cudaMemcpy(f_d, f_h, sizeof(TYPE)*(nx*dimSig), cudaMemcpyHostToDevice);
    cudaMemcpy(g_d, g_h, sizeof(TYPE)*(ny*dimSig), cudaMemcpyHostToDevice);
    cudaMemcpy(alpha_d, alpha_h, sizeof(TYPE)*(nx*dimVect), cudaMemcpyHostToDevice);
    cudaMemcpy(beta_d, beta_h, sizeof(TYPE)*(ny*dimVect), cudaMemcpyHostToDevice);

    // Compute on device.
    dim3 blockSize;
    blockSize.x = CUDA_BLOCK_SIZE; // number of threads in each block
    dim3 gridSize;
    gridSize.x =  nx / blockSize.x + (nx%blockSize.x==0 ? 0 : 1);

    if(dimPoint==1 && dimSig==1 && dimVect==1)
        fshape_scp_dxi_OnDevice<TYPE,1,1,1><<<gridSize,blockSize,blockSize.x*(dimVect+dimSig+dimPoint)*sizeof(TYPE)>>>
        (ooSigmax2,ooSigmaf2,ooSigmaXi2, x_d, y_d, f_d, g_d, alpha_d, beta_d, gamma_d, nx, ny);
    else if(dimPoint==3 && dimSig==1 && dimVect==1)
        fshape_scp_dxi_OnDevice<TYPE,3,1,1><<<gridSize,blockSize,blockSize.x*(dimVect+dimSig+dimPoint)*sizeof(TYPE)>>>
        (ooSigmax2,ooSigmaf2,ooSigmaXi2, x_d, y_d, f_d, g_d, alpha_d, beta_d, gamma_d, nx, ny);
    else if(dimPoint==2 && dimSig==1 && dimVect==1)
        fshape_scp_dxi_OnDevice<TYPE,2,1,1><<<gridSize,blockSize,blockSize.x*(dimVect+dimSig+dimPoint)*sizeof(TYPE)>>>
        (ooSigmax2,ooSigmaf2, ooSigmaXi2, x_d, y_d, f_d, g_d, alpha_d, beta_d, gamma_d, nx, ny);
    else if(dimPoint==2 && dimSig==1 && dimVect==2)
        fshape_scp_dxi_OnDevice<TYPE,2,1,2><<<gridSize,blockSize,blockSize.x*(dimVect+dimSig+dimPoint)*sizeof(TYPE)>>>
        (ooSigmax2,ooSigmaf2, ooSigmaXi2, x_d, y_d, f_d, g_d, alpha_d, beta_d, gamma_d, nx, ny);
    else if(dimPoint==3 && dimSig==1 && dimVect==3)
        fshape_scp_dxi_OnDevice<TYPE,3,1,3><<<gridSize,blockSize,blockSize.x*(dimVect+dimSig+dimPoint)*sizeof(TYPE)>>>
        (ooSigmax2,ooSigmaf2, ooSigmaXi2, x_d, y_d, f_d, g_d, alpha_d, beta_d, gamma_d, nx, ny);
    else {
        printf("error: dimensions of kernel not implemented in fshape_scp_dxi");
        cudaFree(x_d);
        cudaFree(y_d);
        cudaFree(f_d);
        cudaFree(g_d);
        cudaFree(alpha_d);
        cudaFree(beta_d);
        cudaFree(gamma_d);
        return(-1);
    }

    // block until the device has completed
    cudaThreadSynchronize();

    // Send data from device to host.
    cudaMemcpy(gamma_h, gamma_d, sizeof(TYPE)*nx*dimVect,cudaMemcpyDeviceToHost);

    // Free memory.
    cudaFree(x_d);
    cudaFree(y_d);
    cudaFree(f_d);
    cudaFree(g_d);
    cudaFree(beta_d);
    cudaFree(gamma_d);
    cudaFree(alpha_d);
    return 0;
}

// Couldn't find a clean way to give a name to an explicit instantiation :-(

#if !(UseCudaOnDoubles)

extern "C" int cudafshape_dxi(double ooSigmax2,double ooSigmaf2, double ooSigmaXi2, float* x_h, float* y_h, float* f_h, float* g_h, float* alpha_h, float* beta_h, float* gamma_h, int dimPoint, int dimSig, int dimVect, int nx, int ny) {
    return fshape_gpu_dxi<float>(ooSigmax2,ooSigmaf2,ooSigmaXi2,x_h,y_h,f_h,g_h,alpha_h,beta_h,gamma_h,dimPoint,dimSig,dimVect,nx,ny);
}

#else

extern "C" int cudafshape_dxi(double ooSigmax2,double ooSigmaf2, double ooSigmaXi2, double* x_h, double* y_h, double* f_h, double* g_h, double* alpha_h, double* beta_h, double* gamma_h, int dimPoint, int dimSig, int dimVect, int nx, int ny) {
    return fshape_gpu_dxi<double>(ooSigmax2,ooSigmaf2,ooSigmaXi2,x_h,y_h,f_h,g_h,alpha_h,beta_h,gamma_h,dimPoint,dimSig,dimVect,nx,ny);
}

#endif


void ExitFcn(void) {
    cudaDeviceReset();
}

