import 'dart:collection';

import 'package:cyberguard/domain/services/inference.dart';

/// A [Pair] is an ordered pair of two objects of the same type, [T]. It is
/// used to represent a directed edge in a [Graph].
class Pair<T> {
  final T first;
  final T second;

  const Pair(this.first, this.second);

  /// Hash code is based on the ordered hash of the two entries.
  @override
  int get hashCode => Object.hash(first, second, true);

  @override
  bool operator ==(final Object other) {
    if (other is Pair<T>) {
      // Simply check both entries.
      return (first == other.first && second == other.second);
    }

    return false;
  }
}

/// A [UnorderedPair] is an unordered pair of two objects of the same type,
/// [T]. It is used to represent an undirected edge in a [Graph].
class UnorderedPair<T> {
  final T first;
  final T second;

  const UnorderedPair(this.first, this.second);

  /// Hash code is based on the unordered hash of the two entries.
  @override
  int get hashCode => Object.hashAllUnordered([first, second]);

  @override
  bool operator ==(final Object other) {
    if (other is UnorderedPair<T>) {
      // Simply check both orderings of the entries.
      return (first == other.first && second == other.second) ||
          (first == other.second && second == other.first);
    }

    return false;
  }
}

/// A [Vertex] is a [Graph] node. The graph stores the edges, whilst the Vertex
/// stores any data associated with the node.
class Vertex {
  /// The graph that owns the vertex. This is assigned when the Vertex is added
  /// to the graph and cleared when it is removed. This enables convenience
  /// methods on the Vertex to access the graph.
  final Graph owner;

  Vertex(this.owner);

  /// Get the dependencies of this [Vertex].
  Set<Vertex> get dependencies => owner._mapping[this] ?? {};

  /// Convenience getter to get the dependencies of this [Vertex] with
  /// comments and a type matching (or extending) the Vertex type.
  Set<CommentedEdge> get commentedDependencies =>
      getCommentedDependencies<Vertex>();

  /// Get the dependencies of this [Vertex] with comments.
  /// Optionally, [T] may be specified to get only the dependencies of type
  /// [T]. See also [commentedDependencies].
  Set<CommentedEdge<T>> getCommentedDependencies<T extends Vertex>() {
    return owner._mapping[this]!
        .map((final Vertex dependency) => CommentedEdge<T>(
              dependency as T,
              this as T,
              owner.getEdgeComment(from: dependency, to: this),
            ))
        .toSet();
  }

  /// Get the dependents on this [Vertex]. (The opposite of the [dependencies],
  /// that is, the [Vertex]es that depend on this [Vertex].)
  Set<Vertex> get dependents => owner._mapping.entries
      .where((final entry) => entry.value.contains(this))
      .map((final entry) => entry.key)
      .toSet();

  /// Convenience getter to recursively get the dependencies of this [Vertex],
  /// by also getting their dependencies, and so on.
  Set<Vertex> get recursiveDependencies {
    final Set<Vertex> visited = {};
    final Queue<Vertex> toCheck = Queue.from(dependencies);

    while (toCheck.isNotEmpty) {
      final Vertex vertex = toCheck.removeFirst();
      if (!visited.contains(vertex)) {
        visited.add(vertex);
        toCheck.addAll(vertex.dependencies);
      }
    }

    return visited;
  }

  /// Convenience getter to recursively get the dependents on this [Vertex],
  /// by also getting their dependents, and so on.
  Set<Vertex> get recursiveDependents {
    final Set<Vertex> visited = {};
    final Queue<Vertex> toCheck = Queue.from(dependents);

    while (toCheck.isNotEmpty) {
      final Vertex vertex = toCheck.removeFirst();
      if (!visited.contains(vertex)) {
        visited.add(vertex);
        toCheck.addAll(vertex.dependents);
      }
    }

    return visited;
  }
}

/// A [CommentedEdge] is an edge in a [Graph] with a comment. This class is
/// used by [Vertex] to provide a convenience method to get the comments for
/// the dependencies of a [Vertex], so some of the vertices may not have
/// comments but calling this a "MaybeCommentedEdge" seemed a little daft.
class CommentedEdge<T extends Vertex> {
  final T from;
  final T to;
  final String? comment;

  /// Returns true if this [CommentedEdge] has a comment. Otherwise, false.
  bool get hasComment => comment != null;

  const CommentedEdge(this.from, this.to, this.comment);
}

/// Implements a graph data structure in Dart. This is a directed graph, where
/// dependencies of a [Vertex] point to the [Vertex] itself.
class Graph<T extends Vertex> {
  /// The mapping of [Vertex]es to their dependencies.
  /// This is the reverse of the logical mapping which is that a [Vertex] has
  /// dependencies pointing into it.
  /// That is, logically a source (e.g., an access method) will point into a
  /// sink (e.g., an account), however here we store the account (sink) as the
  /// key and its dependencies (the access methods, sources) as the value.
  final Map<T, Set<T>> _mapping = {};

  /// A set of comments for a given mapping. This allows for a reason to be
  /// provided for a mapping. This is mapped in the same direction as
  /// [_mapping], that is, from the sink to the source, so you can expect to
  /// see a [Pair] with ordering `[to, from]` as opposed to `[from, to]`. (That
  /// is, `[sink, source]` as opposed to `[source, sink]`.)
  final Map<Pair<T>, String> _mappingComments = {};

  /// Get the distinct set of vertices in the graph.
  Set<T> get vertices => _mapping.entries
      .map((final entry) => <T>{entry.key, ...entry.value})
      .expand((final element) => element)
      .toSet();

  /// Searches for a [Vertex] that matches the given [test] function.
  /// Returns the [Vertex] if found, otherwise null.
  T? vertexWhere(final bool Function(T vertex) test) =>
      verticesWhere(test).singleOrNull;

  /// Searches for a list of [Vertex]es that matches the given [test] function.
  /// Returns a set of distinct [Vertex]es if found, otherwise an empty set.
  Set<T> verticesWhere(final bool Function(T vertex) test) =>
      vertices.where(test).toSet();

  /// Convenience method to check if one vertex can access another vertex.
  bool canReach({
    required final Vertex from,
    required final Vertex to,
  }) {
    // Record the set of visited nodes.
    final Set<Vertex> visited = {};
    // Use a queue to perform a breadth-first search of to's dependencies.
    final Queue<Vertex> queue = Queue.from(to.dependencies);

    // While there are nodes to search...
    while (queue.isNotEmpty) {
      // Get the next node to check.
      final Vertex current = queue.removeFirst();

      // If the current node is 'from', then from must be reachable from to.
      if (current == from) {
        return true;
      }

      // Otherwise, if the current node isn't one we've checked, add it to the
      // visited set and add its dependencies to the queue.
      if (!visited.contains(current)) {
        visited.add(current);
        queue.addAll(current.dependencies);
      }
    }

    return false;
  }

  /// Convenience method to check if one vertex can access another vertex,
  /// but also returns the journey taken to get there.
  /// If [generateEdgeComment] is specified, then it will be used to generate
  /// a comment for each edge in the journey (where a comment doesn't already
  /// exist).
  List<String>? journey({
    required final T from,
    required final T to,
    final String? Function(T from, T to)? generateEdgeComment,
  }) {
    // Move from the 'from' vertex to the 'to' vertex to its dependencies, and
    // record the journey taken to get there.
    // Use a direct trail (in which all edges are distinct) to avoid cycles.

    final Set<Vertex> visited = {};
    final Queue<(Vertex, List<Vertex>)> queue = Queue.from([
      (to, [to])
    ]);

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();

      if (current.$1 == from) {
        final path = current.$2.reversed.toList();

        final journey = <String>[];

        for (int i = 1; i < path.length; i++) {
          final stepFrom = path[i - 1] as T;
          final stepTo = path[i] as T;

          if (hasEdgeComment(from: stepFrom, to: stepTo)) {
            journey.add(getEdgeComment(from: stepFrom, to: stepTo)!);
          } else if (generateEdgeComment != null) {
            final comment = generateEdgeComment(stepFrom, stepTo);
            if (comment != null) {
              journey.add(comment);
            }
          }
        }

        return journey;
      }

      if (!visited.contains(current.$1)) {
        visited.add(current.$1);
        queue.addAll(current.$1.dependencies
            .map((final dependency) => (
                  dependency,
                  [...current.$2, dependency],
                ))
            .toList());
      }
    }

    return null;
  }

  /// Assigns a comment to a directed mapping.
  void setEdgeComment({
    required final T from,
    required final T to,
    required final String comment,
  }) =>
      _mappingComments[Pair(to, from)] = comment;

  bool hasEdgeComment({
    required final T from,
    required final T to,
  }) =>
      _mappingComments.containsKey(Pair(to, from));

  /// Gets the comment for a directed mapping.
  String? getEdgeComment({
    required final T from,
    required final T to,
  }) =>
      _mappingComments[Pair(to, from)];

  /// Deletes a comment for a directed mapping (returning the comment if there
  /// was one).
  String? deleteEdgeComment({
    required final T from,
    required final T to,
  }) =>
      _mappingComments.remove(Pair(to, from));

  /// Assigns a comment to multiple directed mappings at once. (Convenience
  /// method to call [setEdgeComment]).
  void setEdgeComments({
    required final Set<T> from,
    required final T to,
    required final String comment,
  }) {
    for (var vertex in from) {
      setEdgeComment(from: vertex, to: to, comment: comment);
    }
  }

  void deleteEdgeComments({
    required final Set<T> from,
    required final T to,
  }) {
    for (var vertex in from) {
      deleteEdgeComment(from: vertex, to: to);
    }
  }

  /// Adds an edge from a source [Vertex] to a sink [Vertex].
  /// This is a convenience alias for [addEdges].
  void addEdge({
    required final T from,
    required final T to,
    final String? comment,
  }) =>
      addEdges(from: {from}, to: to, comment: comment);

  /// Adds edges from a source [Vertex] to a set of sink [Vertex]es.
  /// This exposes a logical mapping of a source (e.g., an access method) to a
  /// sink (e.g., an account) for clarity.
  /// If specified, the [comment] will be applied to each edge. Otherwise,
  /// if [commentGenerator] is specified, it will be used to generate a comment
  /// for each edge. If neither is specified, no comment will be added.
  /// Note that [comment] overrides [commentGenerator] if it is specified.
  void addEdges({
    required final Set<T> from,
    required final T to,
    final String? comment,
    final String? Function(T from, T to)? commentGenerator,
  }) {
    // If the graph does not contain the source vertex, add it.
    if (!_mapping.containsKey(to)) {
      _mapping[to] = {};
    }

    // Then, map the vertices.
    _mapping[to]!.addAll(from);
    if (comment != null) {
      setEdgeComments(from: from, to: to, comment: comment);
    } else {
      if (commentGenerator != null) {
        for (final fromNode in from) {
          final generatedComment = commentGenerator(fromNode, to);
          if (generatedComment != null) {
            setEdgeComment(from: fromNode, to: to, comment: generatedComment);
          }
        }
      }
    }
  }

  /// Removes an edge from a source [Vertex] to a sink [Vertex].
  /// This is a convenience alias for [removeEdges].
  /// See [addEdges] for more information.
  void removeEdge(final T from, final T to) => removeEdges({from}, to);

  /// Removes edges from a source [Vertex] each entry in set of sink
  /// [Vertex]es.
  void removeEdges(final Set<T> from, final T to) {
    // If the graph doesn't contain the source vertex, do nothing.
    if (!_mapping.containsKey(to)) return;

    // Otherwise, remove the edges.
    _mapping[to]!.removeAll(from);

    // ...and their comments.
    deleteEdgeComments(from: from, to: to);

    // ...additionally clearing the sink vertex if it has no dependencies.
    if (_mapping[to]!.isEmpty) {
      _mapping.remove(to);
    }
  }

  @override
  String toString() {
    List<String> resultLines = [];
    for (final entry in _mapping.entries) {
      for (final source in entry.value) {
        String comment = hasEdgeComment(from: source, to: entry.key)
            ? " (COMMENT: ${getEdgeComment(from: source, to: entry.key)})"
            : "";
        resultLines.add('$source -> ${entry.key}$comment');
      }
    }
    return resultLines.join('\n');
  }
}
