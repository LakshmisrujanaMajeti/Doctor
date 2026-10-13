import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opd_connect/core/network/dio_client.dart';
import 'package:opd_connect/features/documents/models/document_models.dart';
import 'package:opd_connect/features/documents/repositories/document_repository.dart';

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return DocumentRepository(dioClient);
});

final patientDocumentsProvider = FutureProvider.family<List<MedicalDocumentModel>, String>((ref, patientId) async {
  final repository = ref.watch(documentRepositoryProvider);
  return repository.getDocumentsByPatient(patientId);
});

final documentDetailProvider = FutureProvider.family<MedicalDocumentModel, String>((ref, documentId) async {
  final repository = ref.watch(documentRepositoryProvider);
  return repository.getDocument(documentId);
});

final documentOcrFieldsProvider = FutureProvider.family<List<DocumentOcrFieldModel>, String>((ref, documentId) async {
  final repository = ref.watch(documentRepositoryProvider);
  return repository.getOcrFields(documentId);
});

final documentAuditLogsProvider = FutureProvider.family<List<DocumentAuditLogModel>, String>((ref, documentId) async {
  final repository = ref.watch(documentRepositoryProvider);
  return repository.getDocumentAuditLogs(documentId);
});
