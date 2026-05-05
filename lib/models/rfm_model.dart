import 'package:flutter/material.dart';

class RFMSegment {
  final String name;
  final int count;
  final double pct;
  final Color color;

  RFMSegment({
    required this.name,
    required this.count,
    required this.pct,
    required this.color,
  });

  static Color getColorForSegment(String segmentName) {
    switch (segmentName) {
      case 'Khách hàng tinh hoa':
        return const Color(0xFF534AB7);
      case 'Khách hàng thân thiết':
        return const Color(0xFF0F6E56);
      case 'Khách hàng tiềm năng':
        return const Color(0xFF854F0B);
      case 'Khách hàng mới':
        return const Color(0xFF185FA5);
      case 'Khách hàng rủi ro':
        return const Color(0xFF993C1D);
      case 'Khách hàng ngủ đông':
        return const Color(0xFF5F5E5A);
      default:
        return Colors.grey;
    }
  }
}

class CustomerRFM {
  final String memberId;
  final int r;
  final int f;
  final int m;
  final String score;
  final String segment;

  CustomerRFM({
    required this.memberId,
    required this.r,
    required this.f,
    required this.m,
    required this.score,
    required this.segment,
  });
}
