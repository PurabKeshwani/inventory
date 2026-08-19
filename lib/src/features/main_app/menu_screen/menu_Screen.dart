import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory/src/services/email_reminder_service.dart';
import 'package:inventory/src/utils/theme/theme.dart';
import 'DetailScreen.dart';
import 'models/transaction_model.dart';

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
    final isDark = CAppTheme.isDark(context);
    final accentColor = isDark ? const Color(0xff38BDF8) : const Color(0xff19335A);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xff080E1A) : const Color(0xffF0F4F8),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(134),
        child: AppBar(
          backgroundColor: isDark ? const Color(0xff0F172A) : const Color(0xff19335A),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Transaction History',
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.white),
              tooltip: 'Email Service Settings',
              onPressed: () => EmailReminderService.showEmailConfigDialog(context),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(80),
            child: Column(
              children: [
                // Clean Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xff1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim().toLowerCase();
                        });
                      },
                      style: GoogleFonts.lato(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Search by Member, ID, Transaction or Item...',
                        hintStyle: GoogleFonts.lato(
                          fontSize: 12,
                          color: isDark ? const Color(0xff64748B) : Colors.grey[500],
                        ),
                        prefixIcon: Icon(Icons.search_rounded, size: 18, color: accentColor),
                        suffixIcon: _searchQuery.isNotEmpty
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
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),

                // Top Tabs
                Container(
                  color: isDark ? const Color(0xff0F172A) : const Color(0xff19335A),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: isDark ? const Color(0xff38BDF8) : Colors.white,
                    indicatorWeight: 3,
                    labelColor: isDark ? const Color(0xff38BDF8) : Colors.white,
                    unselectedLabelColor: isDark ? const Color(0xff64748B) : Colors.white60,
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
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: CAppTheme.bgGradient(context),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Due Transactions Only
            LazyTransactionListView(
              isDueOnly: true,
              searchQuery: _searchQuery,
            ),
            // Tab 2: All Transactions
            LazyTransactionListView(
              isDueOnly: false,
              searchQuery: _searchQuery,
            ),
          ],
        ),
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
  final SupabaseClient supabase = Supabase.instance.client;
  final ScrollController _scrollController = ScrollController();

  List<TransactionModel> _transactions = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentOffset = 0;
  final int _pageSize = 25;
  bool _isSendingBulk = false;

  @override
  void initState() {
    super.initState();
    _fetchInitialTransactions();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant LazyTransactionListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery) {
      if (widget.searchQuery.isNotEmpty) {
        _performSearch(widget.searchQuery);
      } else {
        _fetchInitialTransactions();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore &&
        widget.searchQuery.isEmpty) {
      _fetchMoreTransactions();
    }
  }

  Future<void> _fetchInitialTransactions() async {
    setState(() {
      _isLoading = true;
      _currentOffset = 0;
      _hasMore = true;
      _transactions.clear();
    });

    try {
      dynamic query = supabase
          .from('Transactions')
          .select()
          .order('id', ascending: false)
          .range(0, _pageSize - 1);

      final List<dynamic> response = await query;
      final newItems = response
          .map((json) =>
              TransactionModel.fromJson(Map<String, dynamic>.from(json)))
          .toList();

      setState(() {
        if (widget.isDueOnly) {
          _transactions = newItems.where((tx) => !tx.isReturned).toList();
        } else {
          _transactions = newItems;
        }
        _currentOffset = response.length;
        _hasMore = response.length >= _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMoreTransactions() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    try {
      dynamic query = supabase
          .from('Transactions')
          .select()
          .order('id', ascending: false)
          .range(_currentOffset, _currentOffset + _pageSize - 1);

      final List<dynamic> response = await query;
      final newItems = response
          .map((json) =>
              TransactionModel.fromJson(Map<String, dynamic>.from(json)))
          .toList();

      setState(() {
        if (widget.isDueOnly) {
          _transactions.addAll(newItems.where((tx) => !tx.isReturned));
        } else {
          _transactions.addAll(newItems);
        }
        _currentOffset += response.length;
        _hasMore = response.length >= _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final List<dynamic> response = await supabase
          .from('Transactions')
          .select()
          .order('id', ascending: false)
          .limit(100);

      final allResults = response
          .map((json) =>
              TransactionModel.fromJson(Map<String, dynamic>.from(json)))
          .toList();

      final filtered = allResults.where((tx) {
        if (widget.isDueOnly && tx.isReturned) return false;
        final q = query.toLowerCase();
        final matchMember = tx.memberName.toLowerCase().contains(q);
        final matchId = tx.borrowerId.toLowerCase().contains(q);
        final matchTx = tx.transactionId.toLowerCase().contains(q);
        final matchPhone = tx.phoneNumber.toLowerCase().contains(q);
        final matchPackage = tx.packageItems.any((item) =>
            (item['compname']?.toString().toLowerCase().contains(q) ?? false) ||
            (item['name']?.toString().toLowerCase().contains(q) ?? false) ||
            (item['skuid']?.toString().toLowerCase().contains(q) ?? false));

        return matchMember || matchId || matchTx || matchPhone || matchPackage;
      }).toList();

      setState(() {
        _transactions = filtered;
        _isLoading = false;
        _hasMore = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendBulkDueReminders() async {
    final dueList = _transactions.where((tx) => !tx.isReturned).toList();
    if (dueList.isEmpty || _isSendingBulk) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Send Due Reminders to All?',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This will send an automated overdue return email from "isa.vesit@ves.ac.in" to all ${dueList.length} members with currently borrowed components.',
          style: GoogleFonts.lato(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff19335A),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Send to ${dueList.length} Members'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSendingBulk = true);

    int sentCount = 0;
    int failedCount = 0;

    for (final tx in dueList) {
      try {
        final email = await EmailReminderService.resolveMemberEmail(
          memberIdOrEmail: tx.borrowerId,
        );

        if (email != null && email.contains('@')) {
          final compNames = tx.packageItems
              .map((i) => '${i['compname'] ?? i['name'] ?? 'Component'} (Qty: ${i['Quantity'] ?? i['quantity'] ?? 1})')
              .toList();

          await EmailReminderService.sendDueReminderEmail(
            toEmail: email,
            memberName: tx.memberName,
            transactionId: tx.transactionId,
            issueDate: tx.issueDate,
            expectedReturnDate: tx.returnDate ?? 'Immediate',
            componentNames: compNames.isNotEmpty ? compNames : ['Borrowed Hardware Component'],
          );
          sentCount++;
        } else {
          failedCount++;
        }
      } catch (_) {
        failedCount++;
      }
    }

    if (mounted) {
      setState(() => _isSendingBulk = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dispatched $sentCount due reminder emails ($failedCount skipped/failed).'),
          backgroundColor: sentCount > 0 ? const Color(0xff15803D) : Colors.orange[800],
        ),
      );
    }
  }

  Future<void> _sendSingleDueReminder(TransactionModel tx) async {
    final email = await EmailReminderService.resolveMemberEmail(
      memberIdOrEmail: tx.borrowerId,
    );

    if (email == null || !email.contains('@')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No verified email found for ${tx.memberName} (${tx.borrowerId})'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
      return;
    }

    try {
      final compNames = tx.packageItems
          .map((i) => '${i['compname'] ?? i['name'] ?? 'Component'} (Qty: ${i['Quantity'] ?? i['quantity'] ?? 1})')
          .toList();

      await EmailReminderService.sendDueReminderEmail(
        toEmail: email,
        memberName: tx.memberName,
        transactionId: tx.transactionId,
        issueDate: tx.issueDate,
        expectedReturnDate: tx.returnDate ?? 'Immediate',
        componentNames: compNames.isNotEmpty ? compNames : ['Borrowed Hardware Component'],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reminder email sent to $email successfully!'),
            backgroundColor: const Color(0xff15803D),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send email: $e'),
            backgroundColor: Colors.red[700],
            action: SnackBarAction(
              label: 'SETTINGS',
              textColor: Colors.white,
              onPressed: () => EmailReminderService.showEmailConfigDialog(context),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CAppTheme.isDark(context);
    final primaryText = CAppTheme.primaryTextColor(context);
    final secondaryText = CAppTheme.secondaryTextColor(context);
    final accentColor = isDark ? const Color(0xff38BDF8) : const Color(0xff19335A);

    if (_isLoading && _transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 3, color: accentColor),
            const SizedBox(height: 12),
            Text(
              'Loading transaction records...',
              style: GoogleFonts.lato(fontSize: 13, color: secondaryText),
            ),
          ],
        ),
      );
    }

    final displayList = widget.isDueOnly
        ? _transactions.where((tx) => !tx.isReturned).toList()
        : _transactions;

    return Column(
      children: [
        // Top Action Bar for Due Tab
        if (widget.isDueOnly && displayList.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xff0F172A) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xff334155) : const Color(0xffE2EAF4),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange[800]),
                    const SizedBox(width: 8),
                    Text(
                      '${displayList.length} Overdue / Borrowed',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: primaryText,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _isSendingBulk ? null : _sendBulkDueReminders,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xff0284C7) : const Color(0xff19335A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: _isSendingBulk
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, size: 14),
                  label: Text(
                    _isSendingBulk ? 'Sending...' : 'Email All Due',
                    style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],

        Expanded(
          child: displayList.isEmpty
              ? RefreshIndicator(
                  onRefresh: _fetchInitialTransactions,
                  color: accentColor,
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
                              color: secondaryText,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              widget.isDueOnly
                                  ? 'No Due Transactions'
                                  : 'No Transactions Found',
                              style: GoogleFonts.montserrat(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: primaryText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.isDueOnly
                                  ? 'All components have been returned in full!'
                                  : 'No transaction history records available.',
                              style: GoogleFonts.lato(fontSize: 13, color: secondaryText),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchInitialTransactions,
                  color: accentColor,
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    itemCount: displayList.length + (_hasMore && widget.searchQuery.isEmpty ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      if (index == displayList.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                              ),
                            ),
                          ),
                        );
                      }

                      final tx = displayList[index];
                      return TransactionHistoryCard(
                        transaction: tx,
                        onSendEmail: !tx.isReturned ? () => _sendSingleDueReminder(tx) : null,
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
                ),
        ),
      ],
    );
  }
}

// Clean Modern Transaction History Card
class TransactionHistoryCard extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback onTap;
  final VoidCallback? onSendEmail;

  const TransactionHistoryCard({
    super.key,
    required this.transaction,
    required this.onTap,
    this.onSendEmail,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CAppTheme.isDark(context);
    final primaryText = CAppTheme.primaryTextColor(context);
    final secondaryText = CAppTheme.secondaryTextColor(context);
    final accentColor = isDark ? const Color(0xff38BDF8) : const Color(0xff19335A);

    final isReturned = transaction.isReturned;
    final txId = transaction.transactionId;
    final borrowerId = transaction.borrowerId;
    final memberName = transaction.memberName;
    final phoneNumber = transaction.phoneNumber;
    final issueDate = transaction.issueDate;
    final dueDate = transaction.returnDate;

    return Container(
      decoration: CAppTheme.cardDecoration(context, radius: 14),
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
                // Top Row: Transaction ID & Due Status Badge & Email Action
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Transaction ID Chip
                    Row(
                      children: [
                        Icon(Icons.tag_rounded, size: 16, color: accentColor),
                        const SizedBox(width: 4),
                        Text(
                          txId.length > 14 ? '${txId.substring(0, 14)}...' : txId,
                          style: GoogleFonts.robotoMono(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            color: primaryText,
                          ),
                        ),
                      ],
                    ),

                    Row(
                      children: [
                        // Due Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: isReturned
                                ? Colors.green.withValues(alpha: isDark ? 0.2 : 0.12)
                                : Colors.orange.withValues(alpha: isDark ? 0.2 : 0.14),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isReturned ? Colors.green : (isDark ? const Color(0xffFB923C) : Colors.orange[800]!),
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
                                color: isReturned ? (isDark ? const Color(0xff4ADE80) : Colors.green[800]) : (isDark ? const Color(0xffFB923C) : Colors.orange[900]),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isReturned ? 'RETURNED' : 'DUE / ACTIVE',
                                style: GoogleFonts.lato(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: isReturned ? (isDark ? const Color(0xff4ADE80) : Colors.green[800]) : (isDark ? const Color(0xffFB923C) : Colors.orange[900]),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (onSendEmail != null) ...[
                          const SizedBox(width: 6),
                          IconButton(
                            icon: Icon(Icons.mail_outline_rounded, size: 18, color: Colors.orange[800]),
                            tooltip: 'Send Due Reminder Email',
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                            onPressed: onSendEmail,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                Divider(height: 1, color: isDark ? const Color(0xff334155) : const Color(0xffE2EAF4)),
                const SizedBox(height: 10),

                // Borrower Name & Borrower ID
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.person_rounded, size: 18, color: accentColor),
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
                              color: primaryText,
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
                                  color: secondaryText,
                                ),
                              ),
                              if (transaction.division.isNotEmpty) ...[
                                Text(' • ', style: TextStyle(color: secondaryText)),
                                Text(
                                  transaction.division,
                                  style: GoogleFonts.lato(fontSize: 12, color: secondaryText),
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
                        Icon(Icons.phone_rounded, size: 14, color: secondaryText),
                        const SizedBox(width: 6),
                        Text(
                          phoneNumber,
                          style: GoogleFonts.lato(
                            fontSize: 12,
                            color: primaryText,
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
                      Icon(Icons.calendar_today_rounded, size: 13, color: secondaryText),
                      const SizedBox(width: 6),
                      Text(
                        'Issued: $issueDate',
                        style: GoogleFonts.lato(fontSize: 12, color: secondaryText),
                      ),
                      if (dueDate != null && dueDate.isNotEmpty) ...[
                        const SizedBox(width: 14),
                        Icon(Icons.event_repeat_rounded, size: 13, color: secondaryText),
                        const SizedBox(width: 4),
                        Text(
                          isReturned ? 'Returned: $dueDate' : 'Due: $dueDate',
                          style: GoogleFonts.lato(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isReturned ? Colors.green[800] : (isDark ? const Color(0xffFB923C) : Colors.orange[900]),
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
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 5),

                if (transaction.packageItems.isEmpty)
                  Text(
                    'No components listed',
                    style: GoogleFonts.lato(fontSize: 12, color: secondaryText),
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
                          color: accentColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Text(
                          '$cName × $qty ${sku.isNotEmpty ? "($sku)" : ""}',
                          style: GoogleFonts.lato(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: primaryText,
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
