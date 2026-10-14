/// A single identified food item from the calorie estimation.
class FoodItem {
  final String name;
  final String portion;
  final int calories;

  const FoodItem({
    required this.name,
    required this.portion,
    required this.calories,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      name: json['name'] as String? ?? 'Unknown food',
      portion: json['portion'] as String? ?? '',
      calories: (json['calories'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'portion': portion,
        'calories': calories,
      };
}

/// Full calorie estimation result returned by the backend.
class CalorieEstimate {
  final List<FoodItem> foodItems;
  final int totalCalories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;
  final String confidence;
  final String mealSummary;
  final String healthTip;

  const CalorieEstimate({
    required this.foodItems,
    required this.totalCalories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.fiberG = 0,
    this.confidence = 'medium',
    this.mealSummary = '',
    this.healthTip = '',
  });

  factory CalorieEstimate.fromJson(Map<String, dynamic> json) {
    final rawItems = json['food_items'] as List<dynamic>? ?? [];
    return CalorieEstimate(
      foodItems: rawItems
          .whereType<Map<String, dynamic>>()
          .map((i) => FoodItem.fromJson(i))
          .toList(),
      totalCalories: (json['total_calories'] as num?)?.toInt() ?? 0,
      proteinG: (json['protein_g'] as num?)?.toDouble() ?? 0,
      carbsG: (json['carbs_g'] as num?)?.toDouble() ?? 0,
      fatG: (json['fat_g'] as num?)?.toDouble() ?? 0,
      fiberG: (json['fiber_g'] as num?)?.toDouble() ?? 0,
      confidence: json['confidence'] as String? ?? 'medium',
      mealSummary: json['meal_summary'] as String? ?? '',
      healthTip: json['health_tip'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'food_items': foodItems.map((i) => i.toJson()).toList(),
        'total_calories': totalCalories,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
        'fiber_g': fiberG,
        'confidence': confidence,
        'meal_summary': mealSummary,
        'health_tip': healthTip,
      };
}
