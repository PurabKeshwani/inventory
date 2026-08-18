class FineModel {
  final String fineId;
  final String memberId;
  final String? transactionId;
  final String reason;
  final double amount;
  final String status; // 'due' (default), 'pending', 'paid'
  final String? createdBy;
  final String? createdAt;
  final String? paidBy;
  final String? paidAt;
  final String? notes;

  // Enriched fields for the table matching:
  // Name | Mobile Number | Component | Qty | Class | Issue Date | Return Date | Fine
  final String? memberName;
  final String? memberEmail;
  final String? phoneNumber;
  final String? componentName;
  final int? quantity;
  final String? className;
  final String? issueDate;
  final String? returnDate;

  FineModel({
    required this.fineId,
    required this.memberId,
    this.transactionId,
    required this.reason,
    required this.amount,
    this.status = 'due',
    this.createdBy,
    this.createdAt,
    this.paidBy,
    this.paidAt,
    this.notes,
    this.memberName,
    this.memberEmail,
    this.phoneNumber,
    this.componentName,
    this.quantity,
    this.className,
    this.issueDate,
    this.returnDate,
  });

  factory FineModel.fromJson(Map<String, dynamic> json) {
    return FineModel(
      fineId: (json['fine_id'] ?? json['id'] ?? '').toString(),
      memberId: (json['member_id'] ?? '').toString(),
      transactionId: json['transaction_id']?.toString(),
      reason: (json['reason'] ?? 'Late return / Damage').toString(),
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      status: (json['status'] ?? 'due').toString().toLowerCase(),
      createdBy: json['created_by']?.toString(),
      createdAt: json['created_at']?.toString(),
      paidBy: json['paid_by']?.toString(),
      paidAt: json['paid_at']?.toString(),
      notes: json['notes']?.toString(),
      memberName: json['member_name']?.toString() ?? json['name']?.toString(),
      memberEmail: json['member_email']?.toString(),
      phoneNumber: json['phonenumber']?.toString() ?? json['phone_number']?.toString(),
      componentName: json['component_name']?.toString(),
      quantity: int.tryParse(json['quantity']?.toString() ?? '1'),
      className: json['class']?.toString() ?? json['division']?.toString(),
      issueDate: json['issuedate']?.toString(),
      returnDate: json['returndate']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (fineId.isNotEmpty) 'fine_id': fineId,
      'member_id': memberId,
      'transaction_id': transactionId,
      'reason': reason,
      'amount': amount,
      'status': status,
      'created_by': createdBy,
      'created_at': createdAt,
      'paid_by': paidBy,
      'paid_at': paidAt,
      'notes': notes,
    };
  }

  FineModel copyWith({
    String? fineId,
    String? memberId,
    String? transactionId,
    String? reason,
    double? amount,
    String? status,
    String? createdBy,
    String? createdAt,
    String? paidBy,
    String? paidAt,
    String? notes,
    String? memberName,
    String? memberEmail,
    String? phoneNumber,
    String? componentName,
    int? quantity,
    String? className,
    String? issueDate,
    String? returnDate,
  }) {
    return FineModel(
      fineId: fineId ?? this.fineId,
      memberId: memberId ?? this.memberId,
      transactionId: transactionId ?? this.transactionId,
      reason: reason ?? this.reason,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      paidBy: paidBy ?? this.paidBy,
      paidAt: paidAt ?? this.paidAt,
      notes: notes ?? this.notes,
      memberName: memberName ?? this.memberName,
      memberEmail: memberEmail ?? this.memberEmail,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      componentName: componentName ?? this.componentName,
      quantity: quantity ?? this.quantity,
      className: className ?? this.className,
      issueDate: issueDate ?? this.issueDate,
      returnDate: returnDate ?? this.returnDate,
    );
  }

  bool get isPaid => status.toLowerCase() == 'paid';
  bool get isDue => status.toLowerCase() == 'due' || status.toLowerCase() == 'pending';
}
