import 'package:flutter/material.dart';

String formatTheoValue(double value) => value.toStringAsFixed(2);

String buildTheoTooltipMessage({
  int? skill,
  int? finishingSkill,
}) {
  if (skill == null || finishingSkill == null) {
    return 'Skillwerte hier nicht verfuegbar';
  }
  return 'Skill: $skill\nFinishing Skill: $finishingSkill';
}

Widget wrapWithTheoTooltip({
  required Widget child,
  int? skill,
  int? finishingSkill,
  String? message,
}) {
  return Tooltip(
    message: message ??
        buildTheoTooltipMessage(
          skill: skill,
          finishingSkill: finishingSkill,
        ),
    waitDuration: const Duration(milliseconds: 250),
    child: child,
  );
}
