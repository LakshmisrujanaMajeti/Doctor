class ApiEndpoints {
  // Health
  static const String health = '/health';

  // Auth
  static const String register = '/auth/register';
  static const String registerPatient = '/auth/register-patient';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String sendOtp = '/auth/otp/send';
  static const String verifyOtp = '/auth/otp/verify';

  // Patients
  static const String patients = '/patients';
  static const String checkDuplicate = '/patients/check-duplicate';
  static String patientById(String id) => '/patients/$id';
  static String patientByUhid(String uhid) => '/patients/uhid/$uhid';
  static String patientByReg(String reg) => '/patients/reg/$reg';
  static String patientByBarcode(String barcode) => '/patients/barcode/$barcode';
  static String patientDownloadBooklet(String patientId) => '/patients/$patientId/download-booklet';
  static String patientDownloadByReg(String regId) => '/patients/download-by-reg/$regId';

  // Departments & Doctors
  static const String departments = '/departments';
  static const String doctors = '/doctors';
  static String doctorById(String id) => '/doctors/$id';
  static const String doctorMyDashboard = '/doctors/me/dashboard';
  static String doctorDashboard(String id) => '/doctors/$id/dashboard';

  // Visits & Triage & Consultation Context
  static const String visits = '/visits';
  static String visitById(String id) => '/visits/$id';
  static String visitVitals(String id) => '/visits/$id/vitals';
  static String consultationContext(String visitId) => '/visits/$visitId/consultation-context';

  // Clinical Records (OPD Booklet sheet)
  static const String clinicalRecords = '/clinical-records';
  static String clinicalRecordById(String id) => '/clinical-records/$id';
  static String clinicalRecordByVisit(String visitId) => '/clinical-records/visit/$visitId';
  static String signClinicalRecord(String id) => '/clinical-records/$id/sign';
  static String amendClinicalRecord(String id) => '/clinical-records/$id/amend';
  static String clinicalAmendments(String id) => '/clinical-records/$id/amendments';

  // Prescriptions & Medicines & Safety
  static const String prescriptions = '/prescriptions';
  static String prescriptionsByVisit(String visitId) => '/prescriptions/visit/$visitId';
  static const String medicineSearch = '/prescriptions/medicines';
  static const String checkAllergies = '/prescriptions/check-allergies';
  static String signPrescription(String id) => '/prescriptions/$id/sign';
  static String amendPrescription(String id) => '/prescriptions/$id/amend';
  static String cancelPrescription(String id) => '/prescriptions/$id/cancel';

  // Laboratory
  static const String labOrders = '/laboratory/orders';
  static const String labCatalogue = '/laboratory/catalogue';
  static const String labDashboardStats = '/laboratory/dashboard-stats';
  static const String labResults = '/laboratory/results';
  static String labOrdersByVisit(String visitId) => '/laboratory/visit/$visitId';
  static String labOrderById(String id) => '/laboratory/orders/$id';
  static String labOrderCollect(String id) => '/laboratory/orders/$id/collect';
  static String labOrderReceive(String id) => '/laboratory/orders/$id/receive';
  static String labOrderReject(String id) => '/laboratory/orders/$id/reject';
  static String labOrderResults(String id) => '/laboratory/orders/$id/results';
  static String labOrderVerify(String id) => '/laboratory/orders/$id/verify';
  static String labOrderReport(String id) => '/laboratory/orders/$id/report';

  // Pharmacy
  static const String pharmacyOrders = '/pharmacy/orders';
  static String dispensePharmacyOrder(String id) => '/pharmacy/orders/$id/dispense';
  static const String pharmacyInventory = '/pharmacy/inventory';
  static const String pharmacyInventoryStats = '/pharmacy/inventory/stats';
  static const String pharmacyInventoryReceive = '/pharmacy/inventory/receive';
  static const String pharmacyInventoryAdjust = '/pharmacy/inventory/adjust';
  static const String pharmacyMovements = '/pharmacy/inventory/movements';
  static const String pharmacyPrescriptions = '/pharmacy/prescriptions';
  static const String pharmacyDispense = '/pharmacy/dispense';
  static const String pharmacyDispenses = '/pharmacy/dispenses';
  static String pharmacyDispenseById(String id) => '/pharmacy/dispenses/$id';

  // Billing
  static const String bills = '/billing';
  static String billById(String id) => '/billing/$id';
  static String billsByVisit(String visitId) => '/billing/visit/$visitId';
  static const String billingServicesCatalogue = '/billing/services-catalogue';
  static String billingPayments(String billId) => '/billing/$billId/payments';
  static const String billingPaymentCallback = '/billing/payments/callback';
  static String billingRefund(String billId) => '/billing/$billId/refund';
  static String billingCancel(String billId) => '/billing/$billId/cancel';
  static String billingReceipt(String billId) => '/billing/$billId/receipt';

  // Documents & OCR
  static const String uploadDocument = '/documents/upload';
  static String documentsByPatient(String patientId) => '/documents/patient/$patientId';
  static String documentById(String id) => '/documents/$id';
  static String documentDownload(String id) => '/documents/$id/download';
  static String documentSignedUrl(String id) => '/documents/$id/signed-url';
  static String documentPreview(String token) => '/documents/preview/$token';
  static String documentOcrExtract(String id) => '/documents/$id/ocr/extract';
  static String documentOcr(String id) => '/documents/$id/ocr';
  static String documentVerifyField(String docId, String extractionId) => '/documents/$docId/ocr/$extractionId/verify';
  static String documentVerifyAll(String id) => '/documents/$id/verify-all';
  static String documentApplyToVisit(String id) => '/documents/$id/apply-to-visit';
  static String documentAuditLogs(String id) => '/documents/$id/audit-logs';
  static const String barcodeGenerate = '/documents/barcode/generate';
  static const String barcodeScan = '/documents/barcode/scan';

  // Admin
  static const String adminStats = '/admin/stats';
  static const String adminDashboardSummary = '/admin/dashboard-summary';
  static const String auditLogs = '/admin/audit-logs';
  static const String adminUsers = '/admin/users';
  static String adminUserById(String id) => '/admin/users/$id';
  static String adminUserStatus(String id) => '/admin/users/$id/status';
  static String adminUserRole(String id) => '/admin/users/$id/role';
  static const String adminRoles = '/admin/roles';
  static const String adminDepartments = '/admin/departments';
  static String adminDepartmentToggle(String id) => '/admin/departments/$id/toggle';
  static const String adminServices = '/admin/services';
  static const String adminTestCatalogue = '/admin/test-catalogue';
  static const String adminMedicineCatalogue = '/admin/medicine-catalogue';
  static String adminMedicineById(String id) => '/admin/medicine-catalogue/$id';
  static const String adminReportRegistrations = '/admin/reports/registrations';
  static const String adminReportBilling = '/admin/reports/billing';
  static const String adminSupportTickets = '/admin/support-tickets';
  static String adminSupportTicketRespond(String id) => '/admin/support-tickets/$id/respond';
  static const String adminSystemConfig = '/admin/system-config';
  static const String adminBackupGuidance = '/admin/backup-guidance';
  static const String adminBackupExport = '/admin/backup/export';

  // Patient Portal
  static const String patientPortalProfile = '/patient-portal/profile';
  static const String patientPortalDependents = '/patient-portal/dependents';
  static const String patientPortalVisits = '/patient-portal/visits';
  static const String patientPortalAppointments = '/patient-portal/appointments';
  static const String patientPortalPrescriptions = '/patient-portal/prescriptions';
  static const String patientPortalLabReports = '/patient-portal/lab-reports';
  static const String patientPortalDocuments = '/patient-portal/documents';
  static const String patientPortalBills = '/patient-portal/bills';
  static const String patientPortalSupport = '/patient-portal/support';
}

