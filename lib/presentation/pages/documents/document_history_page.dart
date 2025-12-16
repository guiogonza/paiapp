import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pai_app/core/theme/app_colors.dart';
import 'package:pai_app/data/repositories/document_repository_impl.dart';
import 'package:pai_app/domain/entities/document_entity.dart';

class DocumentHistoryPage extends StatefulWidget {
  final DocumentEntity currentDocument;

  const DocumentHistoryPage({
    super.key,
    required this.currentDocument,
  });

  @override
  State<DocumentHistoryPage> createState() => _DocumentHistoryPageState();
}

class _DocumentHistoryPageState extends State<DocumentHistoryPage> {
  final _documentRepository = DocumentRepositoryImpl();
  List<DocumentEntity> _historyDocuments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
    });

    final result = await _documentRepository.getDocumentHistory(widget.currentDocument);

    result.fold(
      (failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cargar historial: ${failure.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() {
          _historyDocuments = [];
          _isLoading = false;
        });
      },
      (documents) {
        setState(() {
          _historyDocuments = documents;
          _isLoading = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Historial: ${widget.currentDocument.documentType}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _historyDocuments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay historial disponible',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Este documento no ha sido renovado anteriormente',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _historyDocuments.length + 1, // +1 para el documento actual
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      // Mostrar el documento actual primero
                      return _buildCurrentDocumentCard();
                    }
                    final historyDoc = _historyDocuments[index - 1];
                    return _buildHistoryCard(historyDoc, index - 1);
                  },
                ),
    );
  }

  Widget _buildCurrentDocumentCard() {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final trafficLightColor = widget.currentDocument.trafficLightColor;
    final trafficLightIcon = widget.currentDocument.trafficLightIcon;

    return Card(
      elevation: 2,
      color: AppColors.primary.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppColors.primary,
          width: 2,
        ),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Documento Actual',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.currentDocument.documentType,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Icon(
                  trafficLightIcon,
                  color: trafficLightColor,
                  size: 32,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 20, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  'Expira: ${dateFormat.format(widget.currentDocument.expirationDate)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            if (widget.currentDocument.documentUrl != null && widget.currentDocument.documentUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.image, size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Documento disponible',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.visibility),
                    onPressed: () => _showDocumentImage(widget.currentDocument),
                    tooltip: 'Ver documento',
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(DocumentEntity document, int index) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final createdAt = document.createdAt != null
        ? DateFormat('dd/MM/yyyy').format(document.createdAt!)
        : 'Fecha desconocida';
    final expirationDate = dateFormat.format(document.expirationDate);

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.archive,
                    color: Colors.grey[600],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Versión ${_historyDocuments.length - index}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        document.documentType,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (document.isExpired)
                  Icon(
                    Icons.error,
                    color: Colors.red,
                    size: 24,
                  )
                else
                  Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 24,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            // Fecha de expedición (creación)
            Row(
              children: [
                const Icon(Icons.event, size: 20, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fecha de expedición: $createdAt',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Fecha de expiración
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 20, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Expiraba: $expirationDate',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Imagen del documento (si existe)
            if (document.documentUrl != null && document.documentUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.image, size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Documento disponible',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.visibility),
                    color: AppColors.primary,
                    onPressed: () => _showDocumentImage(document),
                    tooltip: 'Ver documento',
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.image_not_supported, size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    'Sin imagen disponible',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDocumentImage(DocumentEntity document) {
    if (document.documentUrl == null || document.documentUrl!.isEmpty) {
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(document.documentType),
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Expanded(
              child: InteractiveViewer(
                child: Image.network(
                  document.documentUrl!,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Text('Error al cargar la imagen'),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

