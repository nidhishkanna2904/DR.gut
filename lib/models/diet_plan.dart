class Deficiency {
  final String name;
  final String finding;

  const Deficiency({
    required this.name,
    required this.finding,
  });

  factory Deficiency.fromJson(Map<String, dynamic> json) {
    return Deficiency(
      name: json['name'] as String? ?? 'General Finding',
      finding: json['finding'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'finding': finding,
      };
}

/// Body-analysis row from the AI – one per biomarker in the blood report.
class BodyMarker {
  final String marker;
  final String value;
  final String normalRange;
  final String status;   // deficient / low / normal / optimal / elevated / high
  final String emoji;
  final String dietaryTip;

  const BodyMarker({
    required this.marker,
    required this.value,
    required this.normalRange,
    required this.status,
    required this.emoji,
    required this.dietaryTip,
  });

  factory BodyMarker.fromJson(Map<String, dynamic> json) {
    return BodyMarker(
      marker:      json['marker']      as String? ?? 'Unknown',
      value:       json['value']       as String? ?? '-',
      normalRange: json['normal_range'] as String? ?? '-',
      status:      json['status']      as String? ?? 'normal',
      emoji:       json['emoji']       as String? ?? '✅',
      dietaryTip:  json['dietary_tip'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'marker': marker,
        'value': value,
        'normal_range': normalRange,
        'status': status,
        'emoji': emoji,
        'dietary_tip': dietaryTip,
      };
}

/// Macro/vitamin breakdown for a single meal (from AI response).
class MealNutrients {
  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;
  final String keyVitamins;

  const MealNutrients({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
    required this.keyVitamins,
  });

  factory MealNutrients.fromJson(Map<String, dynamic> json) {
    return MealNutrients(
      calories:    (json['calories']    as num?)?.toInt()    ?? 0,
      proteinG:    (json['protein_g']   as num?)?.toDouble() ?? 0,
      carbsG:      (json['carbs_g']     as num?)?.toDouble() ?? 0,
      fatG:        (json['fat_g']       as num?)?.toDouble() ?? 0,
      fiberG:      (json['fiber_g']     as num?)?.toDouble() ?? 0,
      keyVitamins: json['key_vitamins'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'calories': calories,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
        'fiber_g': fiberG,
        'key_vitamins': keyVitamins,
      };
}

class Meal {
  final String time;
  final String items;
  final String why;
  final MealNutrients? nutrients;

  const Meal({
    required this.time,
    required this.items,
    required this.why,
    this.nutrients,
  });

  factory Meal.fromJson(Map<String, dynamic> json) {
    MealNutrients? nutrients;
    if (json['nutrients'] is Map<String, dynamic>) {
      nutrients = MealNutrients.fromJson(json['nutrients'] as Map<String, dynamic>);
    }
    return Meal(
      time:      json['time']  as String? ?? 'Meal',
      items:     json['items'] as String? ?? '',
      why:       json['why']   as String? ?? '',
      nutrients: nutrients,
    );
  }

  Map<String, dynamic> toJson() => {
        'time': time,
        'items': items,
        'why': why,
        if (nutrients != null) 'nutrients': nutrients!.toJson(),
      };
}

class PlanDay {
  final String day;
  final List<Meal> meals;

  const PlanDay({
    required this.day,
    required this.meals,
  });

  factory PlanDay.fromJson(Map<String, dynamic> json) {
    final rawMeals = json['meals'] as List<dynamic>? ?? [];
    return PlanDay(
      day: json['day'] as String? ?? 'Day 1',
      meals: rawMeals
          .whereType<Map<String, dynamic>>()
          .map((m) => Meal.fromJson(m))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'day': day,
        'meals': meals.map((m) => m.toJson()).toList(),
      };
}

class DietPlan {
  final String summary;
  final List<BodyMarker> bodyAnalysis;
  final List<Deficiency> deficiencies;
  final List<PlanDay> days;
  final String localNotes;

  const DietPlan({
    required this.summary,
    this.bodyAnalysis = const [],
    required this.deficiencies,
    required this.days,
    required this.localNotes,
  });

  factory DietPlan.fromJson(Map<String, dynamic> json) {
    final rawDefs    = json['deficiencies']  as List<dynamic>? ?? [];
    final rawDays    = json['days']          as List<dynamic>? ?? [];
    final rawAnalysis = json['body_analysis'] as List<dynamic>? ?? [];

    return DietPlan(
      summary: json['summary'] as String? ?? 'Personalized diet recommendations based on your report.',
      bodyAnalysis: rawAnalysis
          .whereType<Map<String, dynamic>>()
          .map((m) => BodyMarker.fromJson(m))
          .toList(),
      deficiencies: rawDefs
          .whereType<Map<String, dynamic>>()
          .map((d) => Deficiency.fromJson(d))
          .toList(),
      days: rawDays
          .whereType<Map<String, dynamic>>()
          .map((d) => PlanDay.fromJson(d))
          .toList(),
      localNotes: json['local_notes'] as String? ??
          json['localNotes'] as String? ??
          'All recommended ingredients are locally sourced and budget-friendly.',
    );
  }

  Map<String, dynamic> toJson() => {
        'summary': summary,
        'body_analysis': bodyAnalysis.map((m) => m.toJson()).toList(),
        'deficiencies': deficiencies.map((d) => d.toJson()).toList(),
        'days': days.map((d) => d.toJson()).toList(),
        'local_notes': localNotes,
      };

  /// Generates a plain-text exportable summary for sharing / copying.
  String toShareableText() {
    final buffer = StringBuffer();
    buffer.writeln('🌱 DR GUT – PERSONALIZED DIET PLAN');
    buffer.writeln('-----------------------------------');
    buffer.writeln('\n📋 OVERVIEW');
    buffer.writeln(summary);

    if (bodyAnalysis.isNotEmpty) {
      buffer.writeln('\n🧪 BODY ANALYSIS:');
      for (final m in bodyAnalysis) {
        buffer.writeln('${m.emoji} ${m.marker}: ${m.value} (Normal: ${m.normalRange}) — ${m.status.toUpperCase()}');
        if (m.dietaryTip.isNotEmpty) buffer.writeln('   💡 ${m.dietaryTip}');
      }
    }

    if (deficiencies.isNotEmpty) {
      buffer.writeln('\n🩺 BIOMARKER FINDINGS:');
      for (final d in deficiencies) {
        buffer.writeln('• ${d.name}: ${d.finding}');
      }
    }

    buffer.writeln('\n🍽️ MEAL PLAN:');
    for (final day in days) {
      buffer.writeln('\n[${day.day.toUpperCase()}]');
      for (final meal in day.meals) {
        buffer.writeln('${meal.time}: ${meal.items}');
        if (meal.why.isNotEmpty) {
          buffer.writeln('   Why: ${meal.why}');
        }
        if (meal.nutrients != null) {
          final n = meal.nutrients!;
          buffer.writeln('   Nutrition: ${n.calories} kcal | Protein: ${n.proteinG}g | Carbs: ${n.carbsG}g | Fat: ${n.fatG}g | Fiber: ${n.fiberG}g');
          if (n.keyVitamins.isNotEmpty) buffer.writeln('   Vitamins/Minerals: ${n.keyVitamins}');
        }
      }
    }

    if (localNotes.isNotEmpty) {
      buffer.writeln('\n📍 LOCAL & REGIONAL TIPS:');
      buffer.writeln(localNotes);
    }

    buffer.writeln('\n-----------------------------------');
    buffer.writeln('⚠️ General dietary guidance, not medical advice. Consult a doctor or dietitian.');
    return buffer.toString();
  }
}
