import 'package:flutter/material.dart';

class OperatingHours {
  final bool isOpen;
  final TimeOfDay? openTime;
  final TimeOfDay? closeTime;

  OperatingHours({
    this.isOpen = false,
    this.openTime,
    this.closeTime,
  });

  Map<String, dynamic> toJson() => {
    'isOpen': isOpen,
    'openTime': openTime != null ? '${openTime!.hour}:${openTime!.minute}' : null,
    'closeTime': closeTime != null ? '${closeTime!.hour}:${closeTime!.minute}' : null,
  };
}