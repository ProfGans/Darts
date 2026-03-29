import 'career_models.dart';

class CareerTemplate {
  const CareerTemplate({
    required this.id,
    required this.name,
    this.participantMode = CareerParticipantMode.cpuOnly,
    this.playerProfileId,
    this.replaceWeakestPlayerWithHuman = false,
    this.careerTagDefinitions = const <CareerTagDefinition>[],
    this.seasonTagRules = const <CareerSeasonTagRule>[],
    required this.rankings,
    required this.calendar,
  });

  final String id;
  final String name;
  final CareerParticipantMode participantMode;
  final String? playerProfileId;
  final bool replaceWeakestPlayerWithHuman;
  final List<CareerTagDefinition> careerTagDefinitions;
  final List<CareerSeasonTagRule> seasonTagRules;
  final List<CareerRankingDefinition> rankings;
  final List<CareerCalendarItem> calendar;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'careerTagDefinitions':
          careerTagDefinitions.map((entry) => entry.toJson()).toList(),
      'seasonTagRules': seasonTagRules.map((entry) => entry.toJson()).toList(),
      'rankings': rankings.map((entry) => entry.toJson()).toList(),
      'calendar': calendar.map((entry) => entry.toJson()).toList(),
    };
  }

  static CareerTemplate fromJson(Map<String, dynamic> json) {
    return CareerTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      participantMode: CareerParticipantMode.values.byName(
        json['participantMode'] as String? ?? CareerParticipantMode.cpuOnly.name,
      ),
      playerProfileId: json['playerProfileId'] as String?,
      replaceWeakestPlayerWithHuman:
          json['replaceWeakestPlayerWithHuman'] as bool? ?? false,
      careerTagDefinitions:
          (json['careerTagDefinitions'] as List<dynamic>? ?? const <dynamic>[])
              .map(
                (entry) => CareerTagDefinition.fromJson(
                  (entry as Map).cast<String, dynamic>(),
                ),
              )
              .toList(),
      seasonTagRules:
          (json['seasonTagRules'] as List<dynamic>? ?? const <dynamic>[])
              .map(
                (entry) => CareerSeasonTagRule.fromJson(
                  (entry as Map).cast<String, dynamic>(),
                ),
              )
              .toList(),
      rankings: (json['rankings'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (entry) => CareerRankingDefinition.fromJson(
              (entry as Map).cast<String, dynamic>(),
            ),
          )
          .toList(),
      calendar: (json['calendar'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (entry) => CareerCalendarItem.fromJson(
              (entry as Map).cast<String, dynamic>(),
            ),
          )
          .toList(),
    );
  }
}
