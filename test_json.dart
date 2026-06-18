import 'dart:convert';
void main() {
  var list = [
    {'name': "A'B", 'des': "single'quote"},
    {'name': 'C', 'des': 'another'}
  ];
  var jsonList = list.map((i) => json.encode(i)).toList();
  print("jsonList.toString():");
  print(jsonList.toString());
  print("json.encode(list):");
  print(json.encode(list));
}
