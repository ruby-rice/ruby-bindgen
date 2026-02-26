// =============================================================================
// Test method_mappings — based on opencv-ruby manual naming fixes
// =============================================================================

namespace cv
{

// VideoCapture::grab is bool with no params, so heuristic says "grab?"
// But it's not a predicate — it grabs a frame. method_mappings overrides to "grab".
class VideoCapture
{
public:
  bool grab();
  bool retrieve(int flag);
};

// MatSize::operator() returns an int, not element access.
// Default mapping: "call". method_mappings overrides to "to_size".
class MatSize
{
public:
  int operator()() const;
};

// Mat::operator() is element/ROI access — should be "[]" not "call".
// UMat same pattern.
class Mat
{
public:
  int operator()(int i) const;
  int operator()(int i, int j) const;
};

class UMat
{
public:
  int operator()(int i) const;
};

// =============================================================================
// Test type_mappings — based on OpenCV Matx naming convention
// Matx<unsigned char, 2, 1> generates "MatxUnsignedChar21" by default.
// OpenCV convention is "Matx21b". Regex type_mapping fixes this.
// =============================================================================

template<typename T, int Rows, int Cols>
class Matx
{
public:
  Matx();
  T operator()(int i, int j) const;
};

typedef Matx<unsigned char, 2, 1> MatxUChar21;
typedef Matx<unsigned char, 3, 1> MatxUChar31;
typedef Matx<short, 2, 1> MatxShort21;
typedef Matx<int, 4, 1> MatxInt41;

} // namespace cv
