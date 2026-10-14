class UserProfile {
  final String name;
  final String phone;
  final String locationName;
  final double lat;
  final double lng;
  final String disease;
  final String allergies;
  final String dislikes;
  final int budget;
  final String planType; // 'day' or 'week'
  final double? heightCm;   // height in centimetres
  final double? weightKg;   // weight always stored in kg
  final String weightUnit;  // 'kg' or 'lbs' — user's preferred display unit

  const UserProfile({
    required this.name,
    required this.phone,
    required this.locationName,
    required this.lat,
    required this.lng,
    this.disease = '',
    this.allergies = '',
    this.dislikes = '',
    required this.budget,
    this.planType = 'day',
    this.heightCm,
    this.weightKg,
    this.weightUnit = 'kg',
  });

  UserProfile copyWith({
    String? name,
    String? phone,
    String? locationName,
    double? lat,
    double? lng,
    String? disease,
    String? allergies,
    String? dislikes,
    int? budget,
    String? planType,
    double? heightCm,
    double? weightKg,
    String? weightUnit,
  }) {
    return UserProfile(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      locationName: locationName ?? this.locationName,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      disease: disease ?? this.disease,
      allergies: allergies ?? this.allergies,
      dislikes: dislikes ?? this.dislikes,
      budget: budget ?? this.budget,
      planType: planType ?? this.planType,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      weightUnit: weightUnit ?? this.weightUnit,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'locationName': locationName,
      'lat': lat,
      'lng': lng,
      'disease': disease,
      'allergies': allergies,
      'dislikes': dislikes,
      'budget': budget,
      'planType': planType,
      'heightCm': heightCm,
      'weightKg': weightKg,
      'weightUnit': weightUnit,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      locationName: json['locationName'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      disease: json['disease'] as String? ?? '',
      allergies: json['allergies'] as String? ?? '',
      dislikes: json['dislikes'] as String? ?? '',
      budget: (json['budget'] as num?)?.toInt() ?? 200,
      planType: json['planType'] as String? ?? 'day',
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      weightUnit: json['weightUnit'] as String? ?? 'kg',
    );
  }
}
