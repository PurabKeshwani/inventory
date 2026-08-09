class ComponentPopularity {
  final String name;
  final String skuid;
  final int totalIssued;

  ComponentPopularity({
    required this.name,
    required this.skuid,
    required this.totalIssued,
  });
}

class CategoryStock {
  final String category;
  final int totalStock;
  final int currentlyIssued;

  CategoryStock({
    required this.category,
    required this.totalStock,
    required this.currentlyIssued,
  });

  int get available => (totalStock - currentlyIssued).clamp(0, totalStock == 0 ? 0 : totalStock);
}

class AnalyticsSummary {
  final int totalIssuedLast30Days;
  final int totalReturnedLast30Days;
  final int activeIssuesNow;
  final int uniqueMembersServedLast30Days;
  final List<ComponentPopularity> topComponents;
  final List<CategoryStock> categoryStock;
  final Map<DateTime, int> dailyIssueCounts;

  AnalyticsSummary({
    required this.totalIssuedLast30Days,
    required this.totalReturnedLast30Days,
    required this.activeIssuesNow,
    required this.uniqueMembersServedLast30Days,
    required this.topComponents,
    required this.categoryStock,
    required this.dailyIssueCounts,
  });
}
