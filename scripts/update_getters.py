import glob

files_to_update = [
    'frontend/lib/features/visits/screens/opd_queue_screen.dart',
    'frontend/lib/features/visits/widgets/reassign_doctor_dialog.dart',
    'frontend/lib/features/visits/screens/record_vitals_screen.dart',
    'frontend/lib/features/visits/screens/visit_detail_screen.dart',
    'frontend/lib/features/clinical_records/screens/consultation_sheet_screen.dart',
    'frontend/lib/features/billing/widgets/create_bill_dialog.dart'
]

for fn in files_to_update:
    with open(fn, 'r', encoding='utf-8') as f:
        content = f.read()
    orig = content
    content = content.replace("visit.patient?.fullName ?? 'Patient ${visit.visitNumber}'", 'visit.effectivePatientName')
    content = content.replace("visit.patient?.fullName ?? 'Outpatient ${visit.visitNumber}'", 'visit.effectivePatientName')
    content = content.replace("v.patient?.fullName ?? 'Patient ${v.visitNumber}'", 'v.effectivePatientName')
    content = content.replace("visit.patient?.uhid ?? 'UHID Pending'", 'visit.effectivePatientUhid')
    content = content.replace('visit.patient?.uhid ?? "UHID Pending"', 'visit.effectivePatientUhid')
    content = content.replace("v.patient?.uhid ?? 'UHID Pending'", 'v.effectivePatientUhid')
    content = content.replace('v.patient?.uhid ?? "UHID Pending"', 'v.effectivePatientUhid')
    if content != orig:
        with open(fn, 'w', encoding='utf-8', newline='\r\n') as f:
            f.write(content)
        print('Updated:', fn)
print('Done!')
