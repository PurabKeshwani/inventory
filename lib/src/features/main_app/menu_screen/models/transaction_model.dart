import 'dart:convert';
import 'package:equatable/equatable.dart';

class TransactionModel extends Equatable {
  final String transactionId;
  final String borrowerId;
  final String memberName;
  final String division;
  final String phoneNumber;
  final List<Map<String, dynamic>> packageItems;
  final String issueDate;
  final String? returnDate;
  final String status;
  final String? profileImageUrl;
  final String? issuedBy;

  const TransactionModel({
    required this.transactionId,
    required this.borrowerId,
    required this.memberName,
    required this.division,
    required this.phoneNumber,
    required this.packageItems,
    required this.issueDate,
    this.returnDate,
    required this.status,
    this.profileImageUrl,
    this.issuedBy,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    // Safely parse packageItems whether it's String, List, or null
    List<Map<String, dynamic>> parsedPackage = [];
    var rawPackage = json['package'];
    if (rawPackage is String) {
      try {
        final decoded = jsonDecode(rawPackage);
        if (decoded is List) {
          parsedPackage = decoded
              .map((item) => Map<String, dynamic>.from(item is Map ? item : {}))
              .toList();
        }
      } catch (_) {}
    } else if (rawPackage is List) {
      parsedPackage = rawPackage
          .map((item) => Map<String, dynamic>.from(item is Map ? item : {}))
          .toList();
    }

    return TransactionModel(
      transactionId: (json['transaction_id'] ?? '').toString(),
      borrowerId: (json['id'] ?? '').toString(),
      memberName: (json['name'] ?? 'Unknown Member').toString(),
      division: (json['class'] ?? 'N/A').toString(),
      phoneNumber: (json['phonenumber'] ?? '').toString(),
      packageItems: parsedPackage,
      issueDate: (json['issuedate'] ?? '').toString(),
      returnDate: json['returndate']?.toString(),
      status: (json['status'] ?? 'Issued').toString(),
      issuedBy: json['issuedby']?.toString(),
      profileImageUrl: json['profile_image_url']?.toString(),
    );
  }

  bool get isReturned {
    final normalized = status.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return normalized == 'returned' ||
        normalized == 'return' ||
        normalized == 'returned to inventory' ||
        normalized == 'closed';
  }

  bool get isDue => !isReturned;

  List<String> get componentNames {
    return packageItems.map<String>((item) {
      final name = item['compname'] ?? item['name'] ?? 'Component';
      final qty = item['Quantity'] ?? item['quantity'] ?? '1';
      return '$name × $qty';
    }).toList();
  }

  String get displayItemsSummary {
    if (componentNames.isEmpty) return 'No components listed';
    return componentNames.join(', ');
  }

  TransactionModel copyWith({
    String? transactionId,
    String? borrowerId,
    String? memberName,
    String? division,
    String? phoneNumber,
    List<Map<String, dynamic>>? packageItems,
    String? issueDate,
    String? returnDate,
    String? status,
    String? profileImageUrl,
    String? issuedBy,
  }) {
    return TransactionModel(
      transactionId: transactionId ?? this.transactionId,
      borrowerId: borrowerId ?? this.borrowerId,
      memberName: memberName ?? this.memberName,
      division: division ?? this.division,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      packageItems: packageItems ?? this.packageItems,
      issueDate: issueDate ?? this.issueDate,
      returnDate: returnDate ?? this.returnDate,
      status: status ?? this.status,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      issuedBy: issuedBy ?? this.issuedBy,
    );
  }

  @override
  List<Object?> get props => [
        transactionId,
        borrowerId,
        memberName,
        division,
        phoneNumber,
        packageItems,
        issueDate,
        returnDate,
        status,
        profileImageUrl,
      ];
}
