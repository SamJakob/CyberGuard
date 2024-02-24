/// Whether delays should be simulated when a simulator or emulator is used.
const kSimulatedWaits = false;

enum SimulatedWaitDuration {
  short(0.5), // 0.5 seconds
  medium(3), // 3 seconds
  long(6); // 6 seconds

  final double seconds;
  const SimulatedWaitDuration(this.seconds);
}

Future<void> simulateWait(final SimulatedWaitDuration duration) async {
  return simulateWaitForData(duration, data: null);
}

Future<T> simulateWaitForData<T>(final SimulatedWaitDuration duration,
    {required final T data}) async {
  if (kSimulatedWaits) {
    await Future<void>.delayed(Duration(
      milliseconds: (duration.seconds * 1000).round(),
    ));
  }
  return data;
}
