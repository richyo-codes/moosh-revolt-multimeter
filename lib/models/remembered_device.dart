/// A device that has been remembered for auto-connect.
class RememberedDevice {
  final String address;
  final String name;
  final bool autoConnect;
  final DateTime rememberedAt;

  RememberedDevice({
    required this.address,
    required this.name,
    this.autoConnect = true,
    required this.rememberedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'name': name,
      'autoConnect': autoConnect,
      'rememberedAt': rememberedAt.millisecondsSinceEpoch,
    };
  }

  factory RememberedDevice.fromJson(Map<String, dynamic> json) {
    return RememberedDevice(
      address: json['address'] as String,
      name: json['name'] as String,
      autoConnect: json['autoConnect'] as bool? ?? true,
      rememberedAt: DateTime.fromMillisecondsSinceEpoch(
        json['rememberedAt'] as int? ?? 0,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RememberedDevice &&
          runtimeType == other.runtimeType &&
          address == other.address;

  @override
  int get hashCode => address.hashCode;
}
