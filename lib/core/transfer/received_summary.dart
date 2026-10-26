import 'dart:convert';

class OperationShift {
  OperationShift(this.date, this.shift);
  final DateTime date;
  final String shift;

  factory OperationShift.at(DateTime localTime) {
    final day = DateTime(localTime.year, localTime.month, localTime.day);
    return OperationShift(
      localTime.hour < 6 ? DateTime(day.year, day.month, day.day - 1) : day,
      localTime.hour >= 6 && localTime.hour < 18 ? 'DIA' : 'NOCHE',
    );
  }

  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static String normalize(String value) =>
      value.trim().toUpperCase().replaceAll('Í', 'I');
}

class ReceivedOperation {
  ReceivedOperation(this.row, this.payload);
  final Map<String, Object?> row;
  final Map<String, dynamic> payload;

  static ReceivedOperation? read(Map<String, Object?> row) {
    if (row['direction'] != 'inbox') return null;
    try {
      final payload = jsonDecode(row['payload'] as String);
      if (payload is! Map<String, dynamic>) return null;
      return ReceivedOperation(row, payload);
    } catch (_) {
      return null;
    }
  }

  bool matches(DateTime date, String shift) =>
      '${payload['fecha']}'.split('T').first == OperationShift.dateKey(date) &&
      (shift == 'TODOS' ||
          OperationShift.normalize('${payload['turno']}') == shift);
}
