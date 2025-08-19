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
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading transactions',
                      style: GoogleFonts.lato(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.message,
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context
                            .read<TransactionBloc>()
                            .add(const LoadTransactions());
                      },
                      child: const Text('Retry'),
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
                      const Icon(
                        Icons.inbox_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No transactions found',
                        style: GoogleFonts.lato(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pull to refresh',
                        style: GoogleFonts.lato(
                          fontSize: 14,
                          color: Colors.grey[500],
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
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.width * 0.7,
          decoration: const BoxDecoration(
            color: Color.fromARGB(39, 5, 168, 244),
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10, left: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        transaction.displayItems,
                        style: GoogleFonts.lato(
                          color: Colors.black,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10, left: 10),
                child: Text(
                  'Member: ${transaction.memberName}',
                  style: GoogleFonts.lato(
                    color: Colors.black,
                    fontSize: 17,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10, left: 10),
                child: Text(
                  'Issued On: ${transaction.issueDate}',
                  style: GoogleFonts.lato(
                    color: Colors.black,
                    fontSize: 17,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10, left: 10),
                child: Text(
                  'Returned On: ${transaction.returnDate ?? 'Not Returned'}',
                  style: GoogleFonts.lato(
                    color: Colors.black,
                    fontSize: 17,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10, left: 10),
                child: Text(
                  'Transaction Id: ${transaction.transactionId}',
                  style: GoogleFonts.lato(
                    color: Colors.black,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
