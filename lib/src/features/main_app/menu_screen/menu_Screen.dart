import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inventory/src/features/main_app/menu_screen/DetailScreen.dart';
import 'package:inventory/src/features/main_app/menu_screen/bloc/bloc.dart';
import 'package:inventory/src/features/main_app/menu_screen/models/transaction_model.dart';
import 'package:inventory/src/features/main_app/menu_screen/repositories/transaction_repository.dart';

// Legacy class for backward compatibility with DetailScreen
class fetcheddata {
  String MemberName;
  List<dynamic> packageitems;
  String issueDate;
  String? ReturnDate;
  String transaction_id;
  String div;
  int phonenumber;
  String? profileImageUrl;

  fetcheddata({
    required this.MemberName,
    required this.packageitems,
    required this.issueDate,
    this.ReturnDate,
    required this.transaction_id,
    required this.div,
    required this.phonenumber,
    this.profileImageUrl,
  });

  // Factory constructor to create from TransactionModel
  factory fetcheddata.fromTransactionModel(TransactionModel model) {
    return fetcheddata(
      MemberName: model.memberName,
      packageitems: model.packageItems,
      issueDate: model.issueDate,
      ReturnDate: model.returnDate,
      transaction_id: model.transactionId,
      div: model.division,
      phonenumber: model.phoneNumber,
      profileImageUrl: model.profileImageUrl,
    );
  }
}

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TransactionBloc(
        repository: TransactionRepository(),
      )..add(const LoadTransactions()),
      child: const MenuScreenView(),
    );
  }
}

class MenuScreenView extends StatelessWidget {
  const MenuScreenView({super.key});

  void _onItemTap(BuildContext context, TransactionModel transaction) {
    // Convert to legacy format for DetailScreen compatibility
    final fetchedComp = fetcheddata.fromTransactionModel(transaction);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailScreen(fetchedcomp: fetchedComp),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 154, 210, 255),
              Color.fromARGB(255, 213, 245, 252),
              Color.fromARGB(255, 242, 254, 255),
            ],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
        ),
        child: BlocBuilder<TransactionBloc, TransactionState>(
          builder: (context, state) {
            if (state is TransactionLoading) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              );
            }

            if (state is TransactionError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 80,
                      color: Color(0xff19335A).withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error Loading Transactions',
                      style: GoogleFonts.lato(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff19335A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        state.message,
                        style: GoogleFonts.lato(
                          fontSize: 14,
                          color: Color(0xff19335A).withOpacity(0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xff19335A),
                            Color(0xff19335A).withOpacity(0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xff19335A).withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            context
                                .read<TransactionBloc>()
                                .add(const LoadTransactions());
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            child: Text(
                              'Retry',
                              style: GoogleFonts.lato(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            if (state is TransactionLoaded || state is TransactionRefreshing) {
              final transactions = state is TransactionLoaded
                  ? state.transactions
                  : (state as TransactionRefreshing).transactions;

              if (transactions.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 80,
                        color: Color(0xff19335A).withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Transactions',
                        style: GoogleFonts.lato(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff19335A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You don\'t have any transactions yet.',
                        style: GoogleFonts.lato(
                          fontSize: 14,
                          color: Color(0xff19335A).withOpacity(0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Pull to refresh',
                        style: GoogleFonts.lato(
                          fontSize: 12,
                          color: Color(0xff19335A).withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  context
                      .read<TransactionBloc>()
                      .add(const RefreshTransactions());
                },
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: transactions.length,
                        itemBuilder: (ctx, index) {
                          final transaction = transactions[index];
                          return _TransactionCard(
                            transaction: transaction,
                            onTap: () => _onItemTap(context, transaction),
                          );
                        },
                      ),
                    ),
                    if (state is TransactionRefreshing)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 4,
                          child: const LinearProgressIndicator(
                            backgroundColor: Colors.transparent,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.blue),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback onTap;

  const _TransactionCard({
    required this.transaction,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Extract component names for display
    final List<String> componentNames = transaction.packageItems
        .map<String>((item) => item['compname'] ?? 'Unknown Component')
        .toList();

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
          width: MediaQuery.of(context).size.width,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                offset: const Offset(0, 4),
                blurRadius: 12,
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                offset: const Offset(0, 2),
                blurRadius: 4,
                spreadRadius: 0,
              ),
            ],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Color(0xff19335A).withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with component chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: componentNames.take(3).map((component) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Color(0xff19335A).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Color(0xff19335A).withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        component,
                        style: GoogleFonts.lato(
                          color: Color(0xff19335A),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }).toList()
                    ..addAll(componentNames.length > 3
                        ? [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.orange.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '+${componentNames.length - 3} more',
                                style: GoogleFonts.lato(
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ]
                        : []),
                ),
                const SizedBox(height: 16),

                // Member info
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 18,
                      color: Color(0xff19335A).withOpacity(0.7),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        transaction.memberName,
                        style: GoogleFonts.lato(
                          color: Color(0xff19335A),
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Date info row
                Row(
                  children: [
                    // Issue date
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                            color: Color(0xff19335A).withOpacity(0.6),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Issued',
                                  style: GoogleFonts.lato(
                                    color: Color(0xff19335A).withOpacity(0.6),
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  transaction.issueDate,
                                  style: GoogleFonts.lato(
                                    color: Color(0xff19335A),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Return date
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            transaction.returnDate != null &&
                                    transaction.returnDate != 'Not Returned'
                                ? Icons.check_circle_outline
                                : Icons.schedule_outlined,
                            size: 16,
                            color: transaction.returnDate != null &&
                                    transaction.returnDate != 'Not Returned'
                                ? Colors.green.shade600
                                : Colors.orange.shade600,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Return',
                                  style: GoogleFonts.lato(
                                    color: Color(0xff19335A).withOpacity(0.6),
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  transaction.returnDate ?? 'Pending',
                                  style: GoogleFonts.lato(
                                    color: transaction.returnDate != null &&
                                            transaction.returnDate !=
                                                'Not Returned'
                                        ? Colors.green.shade600
                                        : Colors.orange.shade600,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Transaction ID
                Row(
                  children: [
                    Icon(
                      Icons.receipt_outlined,
                      size: 16,
                      color: Color(0xff19335A).withOpacity(0.6),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'ID: ${transaction.transactionId}',
                        style: GoogleFonts.lato(
                          color: Color(0xff19335A).withOpacity(0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
