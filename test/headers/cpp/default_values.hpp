namespace cv
{
  class Range
  {
  public:
    Range();
    Range(int start, int end);
    static Range all();

    int start;
    int end;
  };

  class Mat
  {
  public:
    Mat();
    Mat(const Mat& m, const Range& rowRange, const Range& colRange = Range::all());
  };
}
