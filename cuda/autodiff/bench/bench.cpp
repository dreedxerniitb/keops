#include <cuda.h>
#include <vector>
#include <algorithm>
#include <benchmark/benchmark.h>

// use manual timing for GPU based functions
#include <chrono>
#include <ctime>

using namespace std;

/////////////////////////////////////////////////////////////////////////////////////
//                      The function to be benchmarked                            //
/////////////////////////////////////////////////////////////////////////////////////

// Some convenient functions
__TYPE__ __TYPE__rand() {
    return ((__TYPE__)rand())/RAND_MAX-.5;    // random value between -.5 and .5
}

template < class V > void fillrandom(V& v) {
    generate(v.begin(), v.end(), __TYPE__rand);    // fills vector with random values
}

// Signature of the generic function:
extern "C" int GpuConv2D(__TYPE__*, int, int, __TYPE__*, __TYPE__**);

void main_generic_2D(int Nx) {

    int Ny= Nx /2 ;

    int dimPoint = 3;
    int dimVect = 4;

    vector<__TYPE__> vf(Nx*dimPoint);
    fillrandom(vf);
    __TYPE__ *f = vf.data();

    vector<__TYPE__> vx(Nx*dimPoint);
    fillrandom(vx);
    __TYPE__ *x = vx.data();

    vector<__TYPE__> vy(Ny*dimPoint);
    fillrandom(vy);
    __TYPE__ *y = vy.data();

    vector<__TYPE__> vu(Nx*dimVect);
    fillrandom(vu);
    __TYPE__ *u = vu.data();

    vector<__TYPE__> vv(Ny*dimVect);
    fillrandom(vv);
    __TYPE__ *v = vv.data();

    std::vector<__TYPE__> vb(Ny*3);
    fillrandom(vb);
    __TYPE__ *b = vb.data();

    // wrap variables
    vector<__TYPE__*> vargs(5);
    vargs[0]=x;
    vargs[1]=y;
    vargs[2]=u;
    vargs[3]=v;
    vargs[4]=b;
    __TYPE__ **args = vargs.data();

    __TYPE__ params[1];
    __TYPE__ Sigma = 1;
    params[0] = 1.0/(Sigma*Sigma);

    GpuConv2D(params, Nx, Ny, f, args);

}

// Signature of the generic function:
extern "C" int GpuConv1D(__TYPE__*, int, int, __TYPE__*, __TYPE__**);

void main_generic_1D(int Nx) {

    int Ny= Nx /2 ;

    int dimPoint = 3;
    int dimVect = 4;

    vector<__TYPE__> vf(Nx*dimPoint);
    fillrandom(vf);
    __TYPE__ *f = vf.data();

    vector<__TYPE__> vx(Nx*dimPoint);
    fillrandom(vx);
    __TYPE__ *x = vx.data();

    vector<__TYPE__> vy(Ny*dimPoint);
    fillrandom(vy);
    __TYPE__ *y = vy.data();

    vector<__TYPE__> vu(Nx*dimVect);
    fillrandom(vu);
    __TYPE__ *u = vu.data();

    vector<__TYPE__> vv(Ny*dimVect);
    fillrandom(vv);
    __TYPE__ *v = vv.data();

    std::vector<__TYPE__> vb(Ny*3);
    fillrandom(vb);
    __TYPE__ *b = vb.data();

    // wrap variables
    vector<__TYPE__*> vargs(5);
    vargs[0]=x;
    vargs[1]=y;
    vargs[2]=u;
    vargs[3]=v;
    vargs[4]=b;
    __TYPE__ **args = vargs.data();

    __TYPE__ params[1];
    __TYPE__ Sigma = 1;
    params[0] = 1.0/(Sigma*Sigma);

    GpuConv1D(params, Nx, Ny, f, args);

}

//extern "C" int GaussGpuGrad1Conv(__TYPE__ ooSigma2, __TYPE__* alpha_h, __TYPE__* x_h, __TYPE__* y_h, __TYPE__* beta_h, __TYPE__* gamma_h, int dimPoint, int dimVect, int nx, int ny) ;

void main_specific(int Nx) {

    int Ny= Nx /2 ;

    int dimPoint = 3;
    int dimVect = 3;

    vector<__TYPE__> vf(Nx*dimPoint);
    fillrandom(vf);
    __TYPE__ *f = vf.data();

    vector<__TYPE__> vx(Nx*dimPoint);
    fillrandom(vx);
    __TYPE__ *x = vx.data();

    vector<__TYPE__> vy(Ny*dimPoint);
    fillrandom(vy);
    __TYPE__ *y = vy.data();

    vector<__TYPE__> vu(Nx*dimVect);
    fillrandom(vu);
    __TYPE__ *u = vu.data();

    vector<__TYPE__> vv(Ny*dimVect);
    fillrandom(vv);
    __TYPE__ *v = vv.data();

    __TYPE__ Sigma = 1;

    //GaussGpuGrad1Conv(1.0/(Sigma*Sigma), u, x, y, v, f, 3,3,Nx,Ny);

}





/////////////////////////////////////////////////////////////////////////////////////
//                          Call the benchmark                                     //
/////////////////////////////////////////////////////////////////////////////////////


// The zeroth benchmark : simply to avoid warm up the GPU...
static void BM_dummy(benchmark::State& state) {
    for (auto _ : state)
        main_generic_2D(1000);
}
BENCHMARK(BM_dummy);// Register the function as a benchmark


// A first Benchmark:
static void cuda_specific(benchmark::State& state) {
    int Nx = state.range(0);

    for (auto _ : state) {
        auto start = chrono::high_resolution_clock::now();
        //----------- the function to be benchmarked ------------//
        main_specific(Nx);
        //------------------------------------------------------//
        auto end   = chrono::high_resolution_clock::now();

        auto elapsed_seconds = chrono::duration_cast<chrono::duration<double>>( end - start);
        state.SetIterationTime(elapsed_seconds.count());
    }
}
// set range of the parameter to be tested : [ 8, 64, 512, 4k, 8k ]
BENCHMARK(cuda_specific)->Range(8, 8<<10)->UseManualTime();// Register the function as a benchmark

// A second one:
static void cuda_generic_2D(benchmark::State& state) {
    int Nx = state.range(0);

    for (auto _ : state) {
        auto start = chrono::high_resolution_clock::now();
        //----------- the function to be benchmarked ------------//
        main_generic_2D(Nx);
        //------------------------------------------------------//
        auto end   = chrono::high_resolution_clock::now();

        auto elapsed_seconds = chrono::duration_cast<chrono::duration<double>>( end - start);
        state.SetIterationTime(elapsed_seconds.count());
    }
}
// set range of the parameter to be tested : [ 8, 64, 512, 4k, 8k ]
BENCHMARK(cuda_generic_2D)->Range(8, 8<<10)->UseManualTime();// Register the function as a benchmark

// A third one:
static void cuda_generic_1D(benchmark::State& state) {
    int Nx = state.range(0);

    for (auto _ : state) {
        auto start = chrono::high_resolution_clock::now();
        //----------- the function to be benchmarked ------------//
        main_generic_1D(Nx);
        //------------------------------------------------------//
        auto end   = chrono::high_resolution_clock::now();

        auto elapsed_seconds = chrono::duration_cast<chrono::duration<double>>( end - start);
        state.SetIterationTime(elapsed_seconds.count());
    }
}
// set range of the parameter to be tested : [ 8, 64, 512, 4k, 8k ]
BENCHMARK(cuda_generic_1D)->Range(8, 8<<10)->UseManualTime();// Register the function as a benchmark

BENCHMARK_MAIN();// generate the benchmarks