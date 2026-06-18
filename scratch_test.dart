void main() {
  final double? w = double.tryParse('NaN');
  final double? h = double.tryParse('NaN');
  print('w is $w');
  print('h is $h');
  
  if (w == null || h == null) {
    print('One of them is null');
    return;
  }
  
  final bool comp = (w <= 0.0 || h <= 0.0);
  print('comp (w <= 0.0 || h <= 0.0): $comp');
  
  double ratio = h / w;
  print('ratio: $ratio');
  
  if (ratio > 1.5) ratio = 1.5;
  if (ratio < 0.5) ratio = 0.5;
  print('final ratio: $ratio');
}

