import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/transaction_repository.dart';
import 'transaction_event.dart';
import 'transaction_state.dart';

class TransactionBloc extends Bloc<TransactionEvent, TransactionState> {
  final TransactionRepository _repository;

  TransactionBloc({required TransactionRepository repository})
      : _repository = repository,
        super(const TransactionInitial()) {
    on<LoadTransactions>(_onLoadTransactions);
    on<RefreshTransactions>(_onRefreshTransactions);
  }

  Future<void> _onLoadTransactions(
    LoadTransactions event,
    Emitter<TransactionState> emit,
  ) async {
    try {
      emit(const TransactionLoading());
      final transactions = await _repository.fetchTransactions();
      emit(TransactionLoaded(transactions: transactions));
    } catch (e) {
      emit(TransactionError(message: e.toString()));
    }
  }

  Future<void> _onRefreshTransactions(
    RefreshTransactions event,
    Emitter<TransactionState> emit,
  ) async {
    try {
      // If we have existing data, show refreshing state
      if (state is TransactionLoaded) {
        final currentState = state as TransactionLoaded;
        emit(TransactionRefreshing(transactions: currentState.transactions));
      } else {
        emit(const TransactionLoading());
      }

      final transactions = await _repository.fetchTransactions();
      emit(TransactionLoaded(transactions: transactions));
    } catch (e) {
      emit(TransactionError(message: e.toString()));
    }
  }
}
