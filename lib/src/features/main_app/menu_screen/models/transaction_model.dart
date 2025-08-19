import 'package:equatable/equatable.dart';

class TransactionModel extends Equatable {
  final String memberName;
  final List<dynamic> packageItems;
  final String issueDate;
  final String? returnDate;
  final String transactionId;
  final String division;
  final int phoneNumber;
  final String? profileImageUrl;

  const TransactionModel({
    required this.memberName,
    required this.packageItems,
    required this.issueDate,
    this.returnDate,
    required this.transactionId,
    required this.division,
    required this.phoneNumber,
    this.profileImageUrl,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      memberName: (json['name'] ?? '').toString(),
      packageItems: json['package'] ?? [],
      issueDate: (json['issuedate'] ?? '').toString(),
      returnDate: json['returndate']?.toString(),
      transactionId: (json['transaction_id'] ?? '').toString(),
      division: (json['class'] ?? '').toString(),
      phoneNumber: int.tryParse(json['phonenumber']?.toString() ?? '0') ?? 0,
      profileImageUrl: null, // Will be set separately
    );
  }

  TransactionModel copyWith({
    String? memberName,
    List<dynamic>? packageItems,
    String? issueDate,
    String? returnDate,
    String? transactionId,
    String? division,
    int? phoneNumber,
    String? profileImageUrl,
  }) {
    return TransactionModel(
      memberName: memberName ?? this.memberName,
      packageItems: packageItems ?? this.packageItems,
      issueDate: issueDate ?? this.issueDate,
      returnDate: returnDate ?? this.returnDate,
      transactionId: transactionId ?? this.transactionId,
      division: division ?? this.division,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }

  List<String> get itemNames {
    return packageItems
        .map<String>((item) => item['compname'].toString())
        .toList();
  }

  String get displayItems {
    if (itemNames.isEmpty) return 'No items';
    if (itemNames.length == 1) return itemNames[0];
    return '${itemNames[0]}, ${itemNames[1]}...';
  }

  @override
  List<Object?> get props => [
        memberName,
        packageItems,
        issueDate,
        returnDate,
        transactionId,
        division,
        phoneNumber,
        profileImageUrl,
      ];
}
