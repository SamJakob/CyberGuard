extension StringExtensions on List<String> {
  String get humanReadableJoin {
    switch (length) {
      case 0:
        return "";
      case 1:
        return first;
      case 2:
        return "$first and $last";
      default:
        // Join with oxford comma.
        return "${take(length - 1).join(", ")}, and $last";
    }
  }
}
