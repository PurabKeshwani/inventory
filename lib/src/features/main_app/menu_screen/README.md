# Menu Screen with BLoC State Management

This implementation uses BLoC (Business Logic Component) pattern for better state management and performance.

## Architecture

```
menu_screen/
├── bloc/
│   ├── transaction_bloc.dart     # Main BLoC logic
│   ├── transaction_event.dart    # Events
│   ├── transaction_state.dart    # States
│   └── bloc.dart                 # Barrel file
├── models/
│   └── transaction_model.dart    # Data model
├── repositories/
│   └── transaction_repository.dart # Data layer
├── menu_Screen.dart              # UI layer
└── README.md                     # This file
```

## Benefits

1. **Better Performance**: 
   - Caching of data
   - Efficient rebuilds only when state changes
   - Background data loading

2. **Better Error Handling**:
   - Proper error states
   - Retry functionality
   - Loading indicators

3. **Better UX**:
   - Pull-to-refresh functionality
   - Loading states
   - Empty states

4. **Maintainable Code**:
   - Separation of concerns
   - Testable business logic
   - Type-safe state management

## Usage

The MenuScreen now automatically handles:
- Loading transactions on first load
- Refreshing data when pulled down
- Error handling with retry option
- Empty state display

## States

- `TransactionInitial`: Initial state
- `TransactionLoading`: Loading data for first time
- `TransactionRefreshing`: Refreshing existing data
- `TransactionLoaded`: Data loaded successfully
- `TransactionError`: Error occurred

## Events

- `LoadTransactions`: Load transactions initially
- `RefreshTransactions`: Refresh existing transactions

## Migration Notes

The legacy `fetcheddata` class is maintained for backward compatibility with `DetailScreen`. When updating `DetailScreen`, you can remove this class and use `TransactionModel` directly.