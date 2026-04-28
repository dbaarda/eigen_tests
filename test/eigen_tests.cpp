// #define NOMINMAX
#include <Eigen/Core>
#include <catch2/benchmark/catch_benchmark.hpp>
#include <catch2/catch_test_macros.hpp>
#include <fmt/format.h>

using namespace Eigen;
// using namespace Catch::Matchers;

/*
 * For docs on using catch2;
 *
 * https://catch2-temp.readthedocs.io/en/latest/test-cases-and-sections.html
 */


// Strangely, Eigen doesn't define convenience types for 1x1 matrixes.
using Matrix1f = Eigen::Matrix<float, 1, 1>;
using Matrix1d = Eigen::Matrix<double, 1, 1>;

template<typename Scalar>
using RowMatrixX = Matrix<Scalar, Dynamic, Dynamic, RowMajor>;

using RowMatrixXf = RowMatrixX<float>;
using RowMatrixXd = RowMatrixX<double>;

template<typename Scalar>
using RowMatrix4 = Matrix<Scalar, 4, 4, RowMajor>;

using RowMatrix4f = RowMatrix4<float>;
using RowMatrix4d = RowMatrix4<double>;

template<typename Scalar>
using Matrix8 = Matrix<Scalar, 8, 8, ColMajor>;

using Matrix8f = Matrix8<float>;
using Matrix8d = Matrix8<double>;

template<typename Scalar>
using RowMatrix8 = Matrix<Scalar, 8, 8, RowMajor>;

using RowMatrix8f = RowMatrix8<float>;
using RowMatrix8d = RowMatrix8<double>;

// Helper functions for getting random x,y,z in range 0-(n-3)] for iteration i.
static inline int lcg(int i) {return int((1103515245u*uint32_t(i) + 12345u) & 0x7fffffff); }
static inline Index geti(int i, Index n) {return lcg(i) % n; }

// Helper for getting strides of a Matrix.
//template<typename M, auto O=M::IsRowMajor ? M::ColsAtCompileTime : M::RowsAtCompileTime, auto I=1, bool IsRowMajor=M::IsRowMajor>
template<int O, int I, bool IsRowMajor=false>
struct StridesHelper {
  enum {
    innerStride = I,
    outerStride = O,
    rowStride = IsRowMajor ? O : I,
    colStride = IsRowMajor ? I : O,
  };
  using StrideType=Stride<O, I>;
};
template<typename M>
struct Strides : StridesHelper<M::IsRowMajor ? M::ColsAtCompileTime : M::RowsAtCompileTime, 1, M::IsRowMajor> {};
// Specialization for Maps.
template<typename N, auto MO, auto O, auto I>
struct Strides<Map<N, MO, Stride<O, I>>> : StridesHelper<O, I, N::IsRowMajor> {};

template<typename M>
using StrideType = Strides<M>::StrideType;

template<typename M>
StrideType<M> getStride(const M& m) {
  return StrideType<M>(m.outerStride(), m.innerStride());
}

template<typename M, typename F>
auto MapBlock(F& f, const Index x, const Index y) {
  const Index rs = f.rowStride();
  const Index cs = f.colStride();
  return Map<M, 0, StrideType<F>>(f.data() + (x*rs) + (y*cs), M::RowsAtCompileTime, M::ColsAtCompileTime, getStride(f));
}

template<typename M, typename F>
auto IndexBlock(F& f, Index x, Index y) {
  return f(seqN(x, fix<M::RowsAtCompileTime>), seqN(y, fix<M::ColsAtCompileTime>));
}

template<typename M, typename F>
auto NullaryExprBlock(F& f, Index x0, Index y0) {
  return M::NullaryExpr([&f, x0, y0](const Index x, const Index y) -> auto { return f(x+x0, y+y0); });
}

SCENARIO("Benchmark matrix multiplications", "[Eigen][MatrixMult][!benchmark]")
{
  GIVEN("Two random Matrix4d's in static, dynamic, ColMajor, and RowMajor layout")
  {
    Index n = 4;
    Matrix4d AColMaj4d = Matrix4d::Random();
    Matrix4d BColMaj4d = Matrix4d::Random();
    RowMatrix4d ARowMaj4d = AColMaj4d;
    RowMatrix4d BRowMaj4d = BColMaj4d;
    RowMatrixXd AColMajXd = AColMaj4d;
    RowMatrixXd BColMajXd = BColMaj4d;
    RowMatrixXd ARowMajXd = AColMaj4d;
    RowMatrixXd BRowMajXd = BColMaj4d;
    REQUIRE(ARowMaj4d == AColMaj4d);
    REQUIRE(BRowMaj4d == BColMaj4d);
    REQUIRE( ARowMaj4d.IsRowMajor );
    REQUIRE( BRowMaj4d.IsRowMajor );
    REQUIRE( ! AColMaj4d.IsRowMajor );
    REQUIRE( ! BColMaj4d.IsRowMajor );
    THEN("benchmark 4x4 multiplies")
    {
      BENCHMARK(fmt::format("ColMaj{}d * ColMaj{}d", n, n)) { return (AColMaj4d * BColMaj4d).eval(); };
      BENCHMARK(fmt::format("ColMaj{}d * RowMaj{}d", n, n)) { return (AColMaj4d * BRowMaj4d).eval(); };
      BENCHMARK(fmt::format("RowMaj{}d * ColMaj{}d", n, n)) { return (ARowMaj4d * BColMaj4d).eval(); };
      BENCHMARK(fmt::format("RowMaj{}d * RowMaj{}d", n, n)) { return (ARowMaj4d * BRowMaj4d).eval(); };
      BENCHMARK(fmt::format("ColMajXd * ColMajXd")) { return (AColMajXd * BColMajXd).eval(); };
      BENCHMARK(fmt::format("ColMajXd * RowMajXd")) { return (AColMajXd * BRowMajXd).eval(); };
      BENCHMARK(fmt::format("RowMajXd * ColMajXd")) { return (ARowMajXd * BColMajXd).eval(); };
      BENCHMARK(fmt::format("RowMajXd * RowMajXd")) { return (ARowMajXd * BRowMajXd).eval(); };
    };
  };
  GIVEN("Two random Matrix8d's in static, dynamic, ColMajor, and RowMajor layout")
  {
    Index n = 8;
    Matrix8d AColMaj8d = Matrix8d::Random();
    Matrix8d BColMaj8d = Matrix8d::Random();
    RowMatrix8d ARowMaj8d = AColMaj8d;
    RowMatrix8d BRowMaj8d = BColMaj8d;
    RowMatrixXd AColMajXd = AColMaj8d;
    RowMatrixXd BColMajXd = BColMaj8d;
    RowMatrixXd ARowMajXd = AColMaj8d;
    RowMatrixXd BRowMajXd = BColMaj8d;
    REQUIRE(ARowMaj8d == AColMaj8d);
    REQUIRE(BRowMaj8d == BColMaj8d);
    REQUIRE( ARowMaj8d.IsRowMajor );
    REQUIRE( BRowMaj8d.IsRowMajor );
    REQUIRE( ! AColMaj8d.IsRowMajor );
    REQUIRE( ! BColMaj8d.IsRowMajor );
    THEN("benchmark 8x8 multiplies")
    {
      BENCHMARK(fmt::format("ColMaj{}d x ColMaj{}d", n, n)) { return (AColMaj8d * BColMaj8d).eval(); };
      BENCHMARK(fmt::format("ColMaj{}d x RowMaj{}d", n, n)) { return (AColMaj8d * BRowMaj8d).eval(); };
      BENCHMARK(fmt::format("RowMaj{}d x ColMaj{}d", n, n)) { return (ARowMaj8d * BColMaj8d).eval(); };
      BENCHMARK(fmt::format("RowMaj{}d x RowMaj{}d", n, n)) { return (ARowMaj8d * BRowMaj8d).eval(); };
      BENCHMARK(fmt::format("ColMajXd * ColMajXd")) { return (AColMajXd * BColMajXd).eval(); };
      BENCHMARK(fmt::format("ColMajXd * RowMajXd")) { return (AColMajXd * BRowMajXd).eval(); };
      BENCHMARK(fmt::format("RowMajXd * ColMajXd")) { return (ARowMajXd * BColMajXd).eval(); };
      BENCHMARK(fmt::format("RowMajXd * RowMajXd")) { return (ARowMajXd * BRowMajXd).eval(); };
    };
  };
  GIVEN("Random F=MatrixXf(200,200) and A=Matrix4f.")
  {
    Index N = 200;
    Index n = 4;
    MatrixXf F = MatrixXf::Random(200,200);
    Matrix4f A = Matrix4f::Random();
    CHECK(F.block<4,4>(10,11) == MapBlock<Matrix4f>(F, 10, 11) );
    CHECK(F.block<4,4>(10,11) == IndexBlock<Matrix4f>(F, 10, 11) );
    CHECK(F.block<4,4>(10,11) == NullaryExprBlock<Matrix4f>(F, 10, 11) );
    THEN("benchmark getting a 4x4 window and mult")
    {
      BENCHMARK("F.block<4,4>(x,y) * A", i) {
        const Index x = geti(i, N-n);
        const Index y = geti(i+1,N-n);
        return (F.block<4,4>(x,y) * A).eval();
      };
      BENCHMARK("MapBlock<Matrix4f>(F,x,y) * A", i) {
        const Index x = geti(i, N-n);
        const Index y = geti(i+1,N-n);
        return (MapBlock<Matrix4f>(F,x,y) * A).eval();
      };
      BENCHMARK("IndexBlock<Matrix4f>(F,x,y) * A", i) {
        const Index x = geti(i, N-n);
        const Index y = geti(i+1,N-n);
        return (IndexBlock<Matrix4f>(F,x,y) * A).eval();
      };
      BENCHMARK("NullaryExprBlock<Matrix4f>(F,x,y) * A", i) {
        const Index x = geti(i, N-n);
        const Index y = geti(i+1,N-n);
        return (NullaryExprBlock<Matrix4f>(F,x,y) * A).eval();
      };
    };
  };
  GIVEN("Random F=MatrixXf(200,200) and A=Matrix8f.")
  {
    Index N = 200;
    Index n = 8;
    MatrixXf F = MatrixXf::Random(200,200);
    Matrix8f A = Matrix8f::Random();
    CHECK(F.block<8,8>(10,11) == MapBlock<Matrix8f>(F, 10, 11) );
    CHECK(F.block<8,8>(10,11) == IndexBlock<Matrix8f>(F, 10, 11) );
    CHECK(F.block<8,8>(10,11) == NullaryExprBlock<Matrix8f>(F, 10, 11) );
    THEN("benchmark getting a 8x8 window and mult")
    {
      BENCHMARK("F.block<8,8>(x,y) * A", i) {
        Index x = geti(i, N-n);
        Index y = geti(i+1,N-n);
        return (F.block<8,8>(x,y) * A).eval();
      };
      BENCHMARK("MapBlock<Matrix8f>(F,x,y) * A", i) {
        Index x = geti(i, N-n);
        Index y = geti(i+1,N-n);
        return (MapBlock<Matrix8f>(F,x,y) * A).eval();
      };
      BENCHMARK("IndexBlock<Matrix8f>(F,x,y) * A", i) {
        Index x = geti(i, N-n);
        Index y = geti(i+1,N-n);
        return (IndexBlock<Matrix8f>(F,x,y) * A).eval();
      };
      BENCHMARK("NullaryExprBlock<Matrix8f>(F,x,y) * A", i) {
        Index x = geti(i, N-n);
        Index y = geti(i+1,N-n);
        return (NullaryExprBlock<Matrix8f>(F,x,y) * A).eval();
      };
    };
  };
};
