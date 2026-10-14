import 'package:flutter_test/flutter_test.dart';
import 'package:dr_gut/models/diet_plan.dart';
import 'package:dr_gut/models/user_profile.dart';

void main() {
  group('UserProfile Model Tests', () {
    test('serializes and deserializes UserProfile correctly', () {
      const profile = UserProfile(
        name: 'Sarah Connor',
        phone: '9876543210',
        locationName: 'Indiranagar, Bengaluru',
        lat: 12.9716,
        lng: 77.5946,
        disease: 'Thyroid',
        allergies: 'Peanuts',
        dislikes: 'Mushrooms',
        budget: 350,
        planType: 'week',
      );

      final json = profile.toJson();
      final reconstructed = UserProfile.fromJson(json);

      expect(reconstructed.name, equals('Sarah Connor'));
      expect(reconstructed.phone, equals('9876543210'));
      expect(reconstructed.locationName, equals('Indiranagar, Bengaluru'));
      expect(reconstructed.lat, equals(12.9716));
      expect(reconstructed.lng, equals(77.5946));
      expect(reconstructed.disease, equals('Thyroid'));
      expect(reconstructed.allergies, equals('Peanuts'));
      expect(reconstructed.dislikes, equals('Mushrooms'));
      expect(reconstructed.budget, equals(350));
      expect(reconstructed.planType, equals('week'));
    });

    test('handles missing optional fields with defaults in UserProfile', () {
      final json = <String, dynamic>{
        'name': 'John Doe',
        'phone': '1234567890',
        'budget': 250,
      };

      final profile = UserProfile.fromJson(json);
      expect(profile.name, equals('John Doe'));
      expect(profile.phone, equals('1234567890'));
      expect(profile.disease, isEmpty);
      expect(profile.allergies, isEmpty);
      expect(profile.dislikes, isEmpty);
      expect(profile.planType, equals('day'));
    });
  });

  group('DietPlan Model Tests', () {
    test('parses full DietPlan JSON correctly', () {
      final json = {
        'summary': 'Targeting iron and Vitamin D deficiencies with regional foods.',
        'deficiencies': [
          {'name': 'Iron', 'finding': 'Hb 9.8 g/dL (low)'},
          {'name': 'Vitamin D', 'finding': '18 ng/mL (insufficient)'}
        ],
        'days': [
          {
            'day': 'Day 1',
            'meals': [
              {
                'time': 'Breakfast (8:30 AM)',
                'items': 'Ragi porridge with jaggery and boiled egg',
                'why': 'Ragi and egg replenish non-heme & heme iron levels'
              },
              {
                'time': 'Lunch (1:00 PM)',
                'items': 'Spinach dal, brown rice, fresh amla',
                'why': 'Vitamin C in amla boosts iron absorption'
              }
            ]
          }
        ],
        'local_notes': 'All items are readily available at your local weekly market.'
      };

      final plan = DietPlan.fromJson(json);

      expect(plan.summary, contains('iron and Vitamin D'));
      expect(plan.deficiencies.length, equals(2));
      expect(plan.deficiencies.first.name, equals('Iron'));
      expect(plan.deficiencies.first.finding, equals('Hb 9.8 g/dL (low)'));
      expect(plan.days.length, equals(1));
      expect(plan.days.first.day, equals('Day 1'));
      expect(plan.days.first.meals.length, equals(2));
      expect(plan.days.first.meals.first.time, contains('Breakfast'));
      expect(plan.localNotes, contains('local weekly market'));

      final shareText = plan.toShareableText();
      expect(shareText, contains('DR GUT – PERSONALIZED DIET PLAN'));
      expect(shareText, contains('Hb 9.8 g/dL (low)'));
    });

    test('tolerates missing or null fields in DietPlan.fromJson without throwing', () {
      final json = <String, dynamic>{};
      final plan = DietPlan.fromJson(json);

      expect(plan.summary, isNotEmpty);
      expect(plan.deficiencies, isEmpty);
      expect(plan.days, isEmpty);
      expect(plan.localNotes, isNotEmpty);
    });
  });
}
