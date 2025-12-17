import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pai_app/core/theme/app_colors.dart';
import 'package:pai_app/data/repositories/expense_repository_impl.dart';
import 'package:pai_app/domain/entities/expense_entity.dart';
import 'package:pai_app/domain/failures/expense_failure.dart';
import 'package:pai_app/presentation/pages/expenses/expense_form_page.dart';

class ExpensesListPage extends StatefulWidget {
  const ExpensesListPage({super.key});

  @override
  State<ExpensesListPage> createState() => _ExpensesListPageState();
}

class _ExpensesListPageState extends State<ExpensesListPage> {
  final _repository = ExpenseRepositoryImpl();
  List<ExpenseEntity> _expenses = [];
  bool _isLoading = true;
  ExpenseFailure? _error;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _repository.getExpenses();

    result.fold(
      (failure) {
        setState(() {
          _error = failure;
          _isLoading = false;
        });
      },
      (expenses) {
        setState(() {
          _expenses = expenses;
          _isLoading = false;
          _error = null;
        });
      },
    );
  }

  Future<void> _handleDelete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar gasto'),
        content: const Text('¿Estás seguro de que deseas eliminar este gasto?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await _repository.deleteExpense(id);

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.message),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gasto eliminado exitosamente'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadExpenses();
      },
    );
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 0,
      locale: 'es_CO',
    );
    return formatter.format(amount);
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gastos'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadExpenses,
        child: _buildBody(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).push<ExpenseEntity>(
            MaterialPageRoute(
              builder: (_) => const ExpenseFormPage(),
            ),
          );

          if (result != null) {
            _loadExpenses();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Agregar Gasto'),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                _error!.message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadExpenses,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_expenses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 80,
                color: AppColors.textSecondary.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No tienes gastos aún',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Toca el botón + para agregar tu primer gasto',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _expenses.length,
      itemBuilder: (context, index) {
        final expense = _expenses[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.accent.withOpacity(0.2),
              child: Icon(
                _getCategoryIcon(expense.type),
                color: AppColors.accent,
              ),
            ),
            title: Text(
              expense.type,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Monto: ${_formatCurrency(expense.amount)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
                Text(
                  'Fecha: ${_formatDate(expense.date)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (expense.description != null && expense.description!.isNotEmpty)
                  Text(
                    expense.description!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (expense.receiptUrl != null && expense.receiptUrl!.isNotEmpty)
                  Icon(
                    Icons.image,
                    color: AppColors.accent,
                    size: 20,
                  ),
                const SizedBox(width: 8),
                PopupMenuButton(
                  icon: const Icon(Icons.more_vert),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: const Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('Editar'),
                        ],
                      ),
                      onTap: () async {
                        await Future.delayed(const Duration(milliseconds: 100));
                        if (context.mounted) {
                          final result =
                              await Navigator.of(context).push<ExpenseEntity>(
                            MaterialPageRoute(
                              builder: (_) => ExpenseFormPage(expense: expense),
                            ),
                          );

                          if (result != null && mounted) {
                            _loadExpenses();
                          }
                        }
                      },
                    ),
                    PopupMenuItem(
                      child: const Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Eliminar', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                      onTap: () {
                        _handleDelete(expense.id!);
                      },
                    ),
                  ],
                ),
              ],
            ),
            isThreeLine: expense.description != null && expense.description!.isNotEmpty,
          ),
        );
      },
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Combustible':
        return Icons.local_gas_station;
      case 'Comida':
        return Icons.restaurant;
      case 'Peajes':
        return Icons.toll;
      case 'Hoteles':
        return Icons.hotel;
      case 'Repuestos':
        return Icons.build;
      case 'Arreglos':
        return Icons.settings;
      default:
        return Icons.receipt;
    }
  }
}

