// ignore_for_file: unused_local_variable

import 'package:cyberguard/data/struct/inference/graph.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mapping vertices', () {
    test('adding and removing vertices via an edge', () {
      final Graph graph = Graph();

      final Vertex password = Vertex(graph);
      final Vertex googleAccount = Vertex(graph);

      graph.addEdge(from: password, to: googleAccount);
      expect(googleAccount.dependencies, equals({password}));
      expect(password.dependents, equals({googleAccount}));

      // Checking the inverse relation should be empty, because the graph is
      // directed and only a single direction was specified.
      expect(googleAccount.dependents, equals(<Vertex>{}));
      expect(password.dependencies, equals(<Vertex>{}));
    });
  });
}
