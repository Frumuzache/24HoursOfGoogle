import 'dart:async';
import 'dart:math';

class HeartRateService {
  // Simulates a stream of BPM data
  Stream<int> getHeartRateStream() async* {
    final random = Random();
    while (true) {
      await Future.delayed(const Duration(seconds: 2));
      // Generates a BPM between 60 and 120
      yield 60 + random.nextInt(65); 
    }
  }
}