// ignore_for_file: unused_local_variable

import 'package:cyberguard/data/struct/inference/graph.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mapping vertices', () {
    test('adding and removing vertices', () {
      final Graph graph = Graph();

      final Vertex password = Vertex(graph);
      final Vertex googleAccount = Vertex(graph);

      graph.addEdge(from: password, to: googleAccount);
      expect(googleAccount.dependencies, equals({password}));
      expect(password.dependents, equals({googleAccount}));
    });
  });
}
