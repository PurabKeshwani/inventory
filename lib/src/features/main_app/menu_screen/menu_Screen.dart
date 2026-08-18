import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inventory/src/features/main_app/menu_screen/DetailScreen.dart';
import 'package:inventory/src/features/main_app/menu_screen/models/transaction_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF4F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xff19335A),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Transaction History',
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(108),
          child: Column(
            children: [
              // Search Input Field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim().toLowerCase();
                      });
                    },
                    style: GoogleFonts.lato(fontSize: 13, color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Search by Member, ID, Transaction or Item...',
                      hintStyle: GoogleFonts.lato(fontSize: 12, color: Colors.grey[500]),
                      prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xff19335A)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ),

              // TabBar Navigation
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  labelColor: const Color(0xff19335A),
                  unselectedLabelColor: Colors.white70,
                  labelStyle: GoogleFonts.montserrat(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  unselectedLabelStyle: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  tabs: const [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.hourglass_top_rounded, size: 16),
                          SizedBox(width: 6),
                          Text('Due Transactions'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_rounded, size: 16),
                          SizedBox(width: 6),
                          Text('All Transactions'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Due Transactions Only
          LazyTransactionListView(
            isDueOnly: true,
            searchQuery: _searchQuery,
          ),
          // Tab 2: All Transactions (Current / Latest at top)
          LazyTransactionListView(
            isDueOnly: false,
            searchQuery: _searchQuery,
          ),
        ],
      ),
    );
  }
}

// Lazy Loading List View with Infinite Scrolling Pagination
class LazyTransactionListView extends StatefulWidget {
  final bool isDueOnly;
  final String searchQuery;

  const LazyTransactionListView({
    super.key,
    required this.isDueOnly,
    required this.searchQuery,
  });

  @override
  State<LazyTransactionListView> createState() =>
      _LazyTransactionListViewState();
}

class _LazyTransactionListViewState extends State<LazyTransactionListView> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ScrollController _scrollController = ScrollController();

  final int _pageSize = 20;
  int _currentOffset = 0;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  List<TransactionModel> _transactions = [];

  @override
  void initState() {
    super.initState();
    _fetchInitialTransactions();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 250 &&
        !_isLoadingMore &&
        _hasMore &&
        !_isLoadingInitial) {
      _fetchMoreTransactions();
    }
  }

  // Fetch first page
  Future<void> _fetchInitialTransactions() async {
    setState(() {
      _isLoadingInitial = true;
      _currentOffset = 0;
      _hasMore = true;
      _transactions = [];
    });

    try {
      final fetched = await _queryDatabase(offset: 0, limit: _pageSize);
      if (mounted) {
        setState(() {
          _transactions = fetched;
          _currentOffset = fetched.length;
          _hasMore = fetched.length >= _pageSize;
          _isLoadingInitial = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingInitial = false;
        });
      }
    }
  }

  // Fetch next page
  Future<void> _fetchMoreTransactions() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final fetched =
          await _queryDatabase(offset: _currentOffset, limit: _pageSize);
      if (mounted) {
        setState(() {
          _transactions.addAll(fetched);
          _currentOffset += fetched.length;
          _hasMore = fetched.length >= _pageSize;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  // Database query with range and order (latest first) with resilient fallback
  Future<List<TransactionModel>> _queryDatabase({
    required int offset,
    required int limit,
  }) async {
    dynamic response;

    // 1. Try ordering by created_at with range
    try {
      var query = _supabase.from('Transactions').select();
      if (widget.isDueOnly) {
        query = query.neq('status', 'Returned');
      }
      response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
    } catch (_) {
      // 2. Fallback: Query range without created_at ordering
      try {
        var query = _supabase.from('Transactions').select();
        if (widget.isDueOnly) {
          query = query.neq('status', 'Returned');
        }
        response = await query.range(offset, offset + limit - 1);
      } catch (_) {
        // 3. Fallback: Full select
        var query = _supabase.from('Transactions').select();
        if (widget.isDueOnly) {
          query = query.neq('status', 'Returned');
        }
        response = await query;
      }
    }

    final list = response as List<dynamic>;
    final mapped = list
        .map((item) =>
            TransactionModel.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();

    // In-memory sort latest first using issue date or transaction ID
    mapped.sort((a, b) {
      final aDate = _parseDate(a.issueDate);
      final bDate = _parseDate(b.issueDate);
      if (aDate != null && bDate != null) {
        return bDate.compareTo(aDate);
      }
      return b.transactionId.compareTo(a.transactionId);
    });

    return mapped;
  }

  DateTime? _parseDate(String? d) {
    if (d == null || d.isEmpty) return null;
    try {
      final parts = d.split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (_) {}
    return null;
  }

  List<TransactionModel> get _filteredTransactions {
    if (widget.searchQuery.isEmpty) return _transactions;
    final q = widget.searchQuery;
    return _transactions.where((tx) {
      final name = tx.memberName.toLowerCase();
      final id = tx.borrowerId.toLowerCase();
      final txId = tx.transactionId.toLowerCase();
      final phone = tx.phoneNumber.toLowerCase();
      final items = tx.displayItemsSummary.toLowerCase();

      return name.contains(q) ||
          id.contains(q) ||
          txId.contains(q) ||
          phone.contains(q) ||
          items.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingInitial) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xff19335A)),
        ),
      );
    }

    final displayList = _filteredTransactions;

    if (displayList.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchInitialTransactions,
        color: const Color(0xff19335A),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
            Center(
              child: Column(
                children: [
                  Icon(
                    widget.isDueOnly
                        ? Icons.check_circle_outline_rounded
                        : Icons.receipt_long_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.isDueOnly
                        ? 'No Due Transactions'
                        : 'No Transactions Found',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.isDueOnly
                        ? 'All components have been returned in full!'
                        : 'No transaction history records available.',
                    style: GoogleFonts.lato(fontSize: 13, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchInitialTransactions,
      color: const Color(0xff19335A),
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        itemCount: displayList.length + (_hasMore && widget.searchQuery.isEmpty ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == displayList.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xff19335A)),
                  ),
                ),
              ),
            );
          }

          final tx = displayList[index];
          return TransactionHistoryCard(
            transaction: tx,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DetailScreen(transaction: tx),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Clean Modern Transaction History Card
class TransactionHistoryCard extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback onTap;

  const TransactionHistoryCard({
    super.key,
    required this.transaction,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isReturned = transaction.isReturned;
    final txId = transaction.transactionId;
    final borrowerId = transaction.borrowerId;
    final memberName = transaction.memberName;
    final phoneNumber = transaction.phoneNumber;
    final issueDate = transaction.issueDate;
    final dueDate = transaction.returnDate;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isReturned
              ? Colors.green.withValues(alpha: 0.3)
              : const Color(0xff19335A).withValues(alpha: 0.15),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Transaction ID & Due Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Transaction ID Chip
                    Row(
                      children: [
                        const Icon(Icons.tag_rounded, size: 16, color: Color(0xff19335A)),
                        const SizedBox(width: 4),
                        Text(
                          txId.length > 16 ? '${txId.substring(0, 16)}...' : txId,
                          style: GoogleFonts.robotoMono(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: const Color(0xff19335A),
                          ),
                        ),
                      ],
                    ),

                    // Due Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: isReturned
                            ? Colors.green.withValues(alpha: 0.12)
                            : Colors.orange.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isReturned ? Colors.green : Colors.orange[800]!,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isReturned
                                ? Icons.check_circle_rounded
                                : Icons.hourglass_top_rounded,
                            size: 12,
                            color: isReturned ? Colors.green[800] : Colors.orange[900],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isReturned ? 'RETURNED' : 'DUE / ACTIVE',
                            style: GoogleFonts.lato(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: isReturned ? Colors.green[800] : Colors.orange[900],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // Borrower Name & Borrower ID
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xff19335A).withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_rounded, size: 18, color: Color(0xff19335A)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            memberName,
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xff19335A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                'Borrower ID: ${borrowerId.isNotEmpty ? borrowerId : "N/A"}',
                                style: GoogleFonts.lato(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                              if (transaction.division.isNotEmpty) ...[
                                Text(' • ', style: TextStyle(color: Colors.grey[400])),
                                Text(
                                  transaction.division,
                                  style: GoogleFonts.lato(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Member Phone Number
                if (phoneNumber.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 4.0, bottom: 6.0),
                    child: Row(
                      children: [
                        Icon(Icons.phone_rounded, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(
                          phoneNumber,
                          style: GoogleFonts.lato(
                            fontSize: 12,
                            color: Colors.grey[800],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Issued Date & Due Date Row
                Padding(
                  padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 13, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        'Issued: $issueDate',
                        style: GoogleFonts.lato(fontSize: 12, color: Colors.grey[700]),
                      ),
                      if (dueDate != null && dueDate.isNotEmpty) ...[
                        const SizedBox(width: 14),
                        Icon(Icons.event_repeat_rounded, size: 13, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          isReturned ? 'Returned: $dueDate' : 'Due: $dueDate',
                          style: GoogleFonts.lato(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isReturned ? Colors.green[800] : Colors.orange[900],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Component Names Chips
                Text(
                  'Components:',
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xff19335A),
                  ),
                ),
                const SizedBox(height: 5),

                if (transaction.packageItems.isEmpty)
                  Text(
                    'No components listed',
                    style: GoogleFonts.lato(fontSize: 12, color: Colors.grey[500]),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: transaction.packageItems.map((item) {
                      final cName = item['compname'] ?? item['name'] ?? 'Component';
                      final qty = item['Quantity'] ?? item['quantity'] ?? '1';
                      final sku = item['skuid']?.toString() ?? '';

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xff19335A).withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xff19335A).withValues(alpha: 0.12),
                          ),
                        ),
                        child: Text(
                          '$cName × $qty ${sku.isNotEmpty ? "($sku)" : ""}',
                          style: GoogleFonts.lato(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xff19335A),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
