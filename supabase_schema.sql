-- ========================================================
-- Sri Manakula Vinayagar Medical College and Hospital (SMVMCH)
-- OPD Connect+ Supabase PostgreSQL Production Schema
-- ========================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Table: departments
CREATE TABLE IF NOT EXISTS departments (
	id VARCHAR(36) NOT NULL, 
	name VARCHAR(100) NOT NULL, 
	code VARCHAR(20) NOT NULL, 
	description TEXT, 
	is_active BOOLEAN NOT NULL, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id)
);

-- Table: medicine_inventory
CREATE TABLE IF NOT EXISTS medicine_inventory (
	id VARCHAR(36) NOT NULL, 
	medicine_code VARCHAR(50) NOT NULL, 
	name VARCHAR(150) NOT NULL, 
	generic_name VARCHAR(150), 
	strength VARCHAR(50) NOT NULL, 
	dosage_form VARCHAR(50) NOT NULL, 
	batch_number VARCHAR(50) NOT NULL, 
	expiry_date DATE NOT NULL, 
	available_quantity INTEGER NOT NULL, 
	reorder_level INTEGER NOT NULL, 
	unit_price NUMERIC(10, 2) NOT NULL, 
	is_synthetic_price BOOLEAN NOT NULL, 
	tax_classification VARCHAR(20) NOT NULL, 
	tax_rate_percent NUMERIC(5, 2) NOT NULL, 
	supplier_name VARCHAR(150) NOT NULL, 
	supplier_contact VARCHAR(100), 
	is_active BOOLEAN NOT NULL, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id)
);

-- Table: otp_verifications
CREATE TABLE IF NOT EXISTS otp_verifications (
	id VARCHAR(36) NOT NULL, 
	identifier VARCHAR(255) NOT NULL, 
	otp_hash VARCHAR(64) NOT NULL, 
	expires_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	is_verified BOOLEAN NOT NULL, 
	attempts INTEGER NOT NULL, 
	purpose VARCHAR(50) NOT NULL, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id)
);

-- Table: patients
CREATE TABLE IF NOT EXISTS patients (
	id VARCHAR(36) NOT NULL, 
	uhid VARCHAR(50) NOT NULL, 
	hospital_reg_num VARCHAR(50), 
	abha_number VARCHAR(50), 
	full_name VARCHAR(150) NOT NULL, 
	parent_spouse_name VARCHAR(150), 
	parent_spouse_relation VARCHAR(30), 
	date_of_birth DATE, 
	age_years INTEGER, 
	age_months INTEGER, 
	gender VARCHAR(20) NOT NULL, 
	phone VARCHAR(30) NOT NULL, 
	email VARCHAR(255), 
	address TEXT, 
	city VARCHAR(100), 
	state VARCHAR(100), 
	postal_code VARCHAR(20), 
	blood_group VARCHAR(10), 
	registration_date TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	barcode_value VARCHAR(100), 
	qr_code_data VARCHAR(255), 
	emergency_contact_name VARCHAR(150), 
	emergency_contact_phone VARCHAR(30), 
	emergency_contact_relation VARCHAR(50), 
	registered_by_staff_id VARCHAR(36), 
	registered_by_staff_name VARCHAR(150), 
	registered_by_staff_role VARCHAR(50), 
	guardian_id VARCHAR(36), 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(guardian_id) REFERENCES patients (id) ON DELETE SET NULL
);

-- Table: permissions
CREATE TABLE IF NOT EXISTS permissions (
	id VARCHAR(36) NOT NULL, 
	name VARCHAR(100) NOT NULL, 
	code VARCHAR(100) NOT NULL, 
	description VARCHAR(255), 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	UNIQUE (name)
);

-- Table: roles
CREATE TABLE IF NOT EXISTS roles (
	id VARCHAR(36) NOT NULL, 
	name VARCHAR(50) NOT NULL, 
	description VARCHAR(255), 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id)
);

-- Table: users
CREATE TABLE IF NOT EXISTS users (
	id VARCHAR(36) NOT NULL, 
	email VARCHAR(255) NOT NULL, 
	phone VARCHAR(30), 
	hashed_password VARCHAR(255) NOT NULL, 
	full_name VARCHAR(150) NOT NULL, 
	is_active BOOLEAN NOT NULL, 
	is_verified BOOLEAN NOT NULL, 
	failed_login_attempts INTEGER NOT NULL, 
	locked_until TIMESTAMP WITHOUT TIME ZONE, 
	role_id VARCHAR(36), 
	patient_id VARCHAR(36), 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(role_id) REFERENCES roles (id), 
	FOREIGN KEY(patient_id) REFERENCES patients (id) ON DELETE SET NULL
);

-- Link patients.registered_by_staff_id to users.id (resolving circular foreign key)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_patients_registered_by_staff'
    ) THEN
        ALTER TABLE patients 
        ADD CONSTRAINT fk_patients_registered_by_staff 
        FOREIGN KEY (registered_by_staff_id) REFERENCES users (id) ON DELETE SET NULL;
    END IF;
END $$;

-- Table: audit_logs
CREATE TABLE IF NOT EXISTS audit_logs (
	id VARCHAR(36) NOT NULL, 
	user_id VARCHAR(36), 
	action VARCHAR(100) NOT NULL, 
	entity_type VARCHAR(100) NOT NULL, 
	entity_id VARCHAR(36), 
	ip_address VARCHAR(45), 
	details_json TEXT, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE SET NULL
);

-- Table: doctors
CREATE TABLE IF NOT EXISTS doctors (
	id VARCHAR(36) NOT NULL, 
	user_id VARCHAR(36) NOT NULL, 
	department_id VARCHAR(36) NOT NULL, 
	qualification VARCHAR(150) NOT NULL, 
	specialization VARCHAR(150) NOT NULL, 
	registration_number VARCHAR(50) NOT NULL, 
	room_number VARCHAR(30), 
	consultation_fee VARCHAR(20) NOT NULL, 
	is_available BOOLEAN NOT NULL, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE, 
	FOREIGN KEY(department_id) REFERENCES departments (id)
);

-- Table: password_reset_tokens
CREATE TABLE IF NOT EXISTS password_reset_tokens (
	id VARCHAR(36) NOT NULL, 
	user_id VARCHAR(36) NOT NULL, 
	token_hash VARCHAR(64) NOT NULL, 
	expires_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	is_used BOOLEAN NOT NULL, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
);

-- Table: refresh_token_sessions
CREATE TABLE IF NOT EXISTS refresh_token_sessions (
	id VARCHAR(36) NOT NULL, 
	user_id VARCHAR(36) NOT NULL, 
	token_hash VARCHAR(64) NOT NULL, 
	expires_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	is_revoked BOOLEAN NOT NULL, 
	replaced_by_token_hash VARCHAR(64), 
	ip_address VARCHAR(45), 
	user_agent TEXT, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
);

-- Table: role_permissions
CREATE TABLE IF NOT EXISTS role_permissions (
	role_id VARCHAR(36) NOT NULL, 
	permission_id VARCHAR(36) NOT NULL, 
	PRIMARY KEY (role_id, permission_id), 
	FOREIGN KEY(role_id) REFERENCES roles (id) ON DELETE CASCADE, 
	FOREIGN KEY(permission_id) REFERENCES permissions (id) ON DELETE CASCADE
);

-- Table: stock_movements
CREATE TABLE IF NOT EXISTS stock_movements (
	id VARCHAR(36) NOT NULL, 
	inventory_id VARCHAR(36) NOT NULL, 
	movement_type VARCHAR(30) NOT NULL, 
	quantity INTEGER NOT NULL, 
	balance_after INTEGER NOT NULL, 
	reference_number VARCHAR(60), 
	reason TEXT, 
	performed_by_user_id VARCHAR(36), 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(inventory_id) REFERENCES medicine_inventory (id) ON DELETE CASCADE, 
	FOREIGN KEY(performed_by_user_id) REFERENCES users (id)
);

-- Table: support_tickets
CREATE TABLE IF NOT EXISTS support_tickets (
	id VARCHAR(36) NOT NULL, 
	patient_id VARCHAR(36) NOT NULL, 
	user_id VARCHAR(36), 
	subject VARCHAR(200) NOT NULL, 
	category VARCHAR(50) NOT NULL, 
	priority VARCHAR(20) NOT NULL, 
	message TEXT NOT NULL, 
	status VARCHAR(30) NOT NULL, 
	assigned_to_user_id VARCHAR(36), 
	admin_response TEXT, 
	resolved_at TIMESTAMP WITHOUT TIME ZONE, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(patient_id) REFERENCES patients (id) ON DELETE CASCADE, 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE SET NULL, 
	FOREIGN KEY(assigned_to_user_id) REFERENCES users (id)
);

-- Table: system_configs
CREATE TABLE IF NOT EXISTS system_configs (
	id VARCHAR(36) NOT NULL, 
	config_key VARCHAR(100) NOT NULL, 
	config_value TEXT NOT NULL, 
	category VARCHAR(50) NOT NULL, 
	description VARCHAR(255), 
	updated_by_user_id VARCHAR(36), 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(updated_by_user_id) REFERENCES users (id) ON DELETE SET NULL
);

-- Table: opd_visits
CREATE TABLE IF NOT EXISTS opd_visits (
	id VARCHAR(36) NOT NULL, 
	visit_number VARCHAR(50) NOT NULL, 
	patient_id VARCHAR(36) NOT NULL, 
	doctor_id VARCHAR(36) NOT NULL, 
	department_id VARCHAR(36) NOT NULL, 
	visit_date TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	queue_token INTEGER NOT NULL, 
	triage_priority VARCHAR(20) NOT NULL, 
	status VARCHAR(30) NOT NULL, 
	consultation_fee FLOAT NOT NULL, 
	payment_status VARCHAR(20) NOT NULL, 
	notes TEXT, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(patient_id) REFERENCES patients (id) ON DELETE CASCADE, 
	FOREIGN KEY(doctor_id) REFERENCES doctors (id), 
	FOREIGN KEY(department_id) REFERENCES departments (id)
);

-- Table: bills
CREATE TABLE IF NOT EXISTS bills (
	id VARCHAR(36) NOT NULL, 
	visit_id VARCHAR(36) NOT NULL, 
	patient_id VARCHAR(36) NOT NULL, 
	invoice_number VARCHAR(50) NOT NULL, 
	subtotal NUMERIC(10, 2) NOT NULL, 
	discount_type VARCHAR(20) NOT NULL, 
	discount_rate NUMERIC(5, 2) NOT NULL, 
	discount_amount NUMERIC(10, 2) NOT NULL, 
	discount_reason VARCHAR(150), 
	taxable_amount NUMERIC(10, 2) NOT NULL, 
	cgst_amount NUMERIC(10, 2) NOT NULL, 
	sgst_amount NUMERIC(10, 2) NOT NULL, 
	igst_amount NUMERIC(10, 2) NOT NULL, 
	total_tax_amount NUMERIC(10, 2) NOT NULL, 
	total_amount NUMERIC(10, 2) NOT NULL, 
	net_amount NUMERIC(10, 2) NOT NULL, 
	paid_amount NUMERIC(10, 2) NOT NULL, 
	outstanding_balance NUMERIC(10, 2) NOT NULL, 
	status VARCHAR(30) NOT NULL, 
	payment_status VARCHAR(20) NOT NULL, 
	payment_method VARCHAR(30) NOT NULL, 
	billed_by_user_id VARCHAR(36), 
	billed_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	cancellation_reason TEXT, 
	cancelled_at TIMESTAMP WITHOUT TIME ZONE, 
	notes TEXT, 
	is_synthetic_pricing BOOLEAN NOT NULL, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(visit_id) REFERENCES opd_visits (id) ON DELETE CASCADE, 
	FOREIGN KEY(patient_id) REFERENCES patients (id) ON DELETE CASCADE, 
	FOREIGN KEY(billed_by_user_id) REFERENCES users (id)
);

-- Table: clinical_records
CREATE TABLE IF NOT EXISTS clinical_records (
	id VARCHAR(36) NOT NULL, 
	visit_id VARCHAR(36) NOT NULL, 
	patient_id VARCHAR(36) NOT NULL, 
	doctor_id VARCHAR(36) NOT NULL, 
	presenting_complaint TEXT NOT NULL, 
	history_of_present_illness TEXT, 
	allergies TEXT, 
	past_medical_history TEXT, 
	prior_hospitalization TEXT, 
	hypertension_history TEXT, 
	diabetes_history TEXT, 
	asthma_history TEXT, 
	tuberculosis_history TEXT, 
	smoking_history VARCHAR(100), 
	alcohol_history VARCHAR(100), 
	family_history TEXT, 
	general_examination TEXT, 
	respiratory_examination TEXT, 
	cardiovascular_examination TEXT, 
	gastrointestinal_examination TEXT, 
	cns_examination TEXT, 
	other_examination_findings TEXT, 
	provisional_diagnosis VARCHAR(255), 
	final_diagnosis VARCHAR(255), 
	icd10_code VARCHAR(50), 
	care_plan TEXT, 
	investigations_requested TEXT, 
	dietary_advice TEXT, 
	follow_up_date DATE, 
	referral_department VARCHAR(100), 
	status VARCHAR(20) NOT NULL, 
	version INTEGER NOT NULL, 
	created_by_user_id VARCHAR(36), 
	updated_by_user_id VARCHAR(36), 
	signed_by_user_id VARCHAR(36), 
	signed_at TIMESTAMP WITHOUT TIME ZONE, 
	amendment_reason TEXT, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(visit_id) REFERENCES opd_visits (id) ON DELETE CASCADE, 
	FOREIGN KEY(patient_id) REFERENCES patients (id) ON DELETE CASCADE, 
	FOREIGN KEY(doctor_id) REFERENCES doctors (id), 
	FOREIGN KEY(created_by_user_id) REFERENCES users (id), 
	FOREIGN KEY(updated_by_user_id) REFERENCES users (id), 
	FOREIGN KEY(signed_by_user_id) REFERENCES users (id)
);

-- Table: lab_orders
CREATE TABLE IF NOT EXISTS lab_orders (
	id VARCHAR(36) NOT NULL, 
	order_number VARCHAR(50), 
	visit_id VARCHAR(36) NOT NULL, 
	patient_id VARCHAR(36) NOT NULL, 
	ordered_by_doctor_id VARCHAR(36) NOT NULL, 
	test_name VARCHAR(150) NOT NULL, 
	test_category VARCHAR(50) NOT NULL, 
	status VARCHAR(30) NOT NULL, 
	clinical_indication TEXT, 
	specimen_id VARCHAR(50), 
	specimen_type VARCHAR(80), 
	specimen_status VARCHAR(30) NOT NULL, 
	collected_at TIMESTAMP WITHOUT TIME ZONE, 
	collected_by_name VARCHAR(100), 
	received_at TIMESTAMP WITHOUT TIME ZONE, 
	received_by_name VARCHAR(100), 
	rejection_reason TEXT, 
	is_sensitive BOOLEAN NOT NULL, 
	requires_review BOOLEAN NOT NULL, 
	verified_by_user_id VARCHAR(36), 
	verified_by_name VARCHAR(100), 
	verified_at TIMESTAMP WITHOUT TIME ZONE, 
	verification_notes TEXT, 
	published_to_visit BOOLEAN NOT NULL, 
	ordered_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	completed_at TIMESTAMP WITHOUT TIME ZONE, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(visit_id) REFERENCES opd_visits (id) ON DELETE CASCADE, 
	FOREIGN KEY(patient_id) REFERENCES patients (id) ON DELETE CASCADE, 
	FOREIGN KEY(ordered_by_doctor_id) REFERENCES doctors (id), 
	FOREIGN KEY(verified_by_user_id) REFERENCES users (id)
);

-- Table: medical_documents
CREATE TABLE IF NOT EXISTS medical_documents (
	id VARCHAR(36) NOT NULL, 
	patient_id VARCHAR(36) NOT NULL, 
	visit_id VARCHAR(36), 
	uploaded_by_user_id VARCHAR(36), 
	document_type VARCHAR(50) NOT NULL, 
	file_name VARCHAR(255) NOT NULL, 
	file_path VARCHAR(500) NOT NULL, 
	file_size_bytes INTEGER NOT NULL, 
	mime_type VARCHAR(100) NOT NULL, 
	storage_bucket VARCHAR(100) NOT NULL, 
	is_private BOOLEAN NOT NULL, 
	description TEXT, 
	page_count INTEGER NOT NULL, 
	checksum_sha256 VARCHAR(64), 
	is_verified BOOLEAN NOT NULL, 
	verification_status VARCHAR(30) NOT NULL, 
	verified_by_user_id VARCHAR(36), 
	verified_at TIMESTAMP WITHOUT TIME ZONE, 
	is_deleted BOOLEAN NOT NULL, 
	deleted_at TIMESTAMP WITHOUT TIME ZONE, 
	deleted_by_user_id VARCHAR(36), 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(patient_id) REFERENCES patients (id) ON DELETE CASCADE, 
	FOREIGN KEY(visit_id) REFERENCES opd_visits (id) ON DELETE SET NULL, 
	FOREIGN KEY(uploaded_by_user_id) REFERENCES users (id), 
	FOREIGN KEY(verified_by_user_id) REFERENCES users (id), 
	FOREIGN KEY(deleted_by_user_id) REFERENCES users (id)
);

-- Table: prescriptions
CREATE TABLE IF NOT EXISTS prescriptions (
	id VARCHAR(36) NOT NULL, 
	visit_id VARCHAR(36) NOT NULL, 
	patient_id VARCHAR(36) NOT NULL, 
	doctor_id VARCHAR(36) NOT NULL, 
	status VARCHAR(20) NOT NULL, 
	version INTEGER NOT NULL, 
	notes TEXT, 
	signed_by_user_id VARCHAR(36), 
	signed_at TIMESTAMP WITHOUT TIME ZONE, 
	amendment_reason TEXT, 
	is_ocr_extracted BOOLEAN NOT NULL, 
	is_verified_by_clinician BOOLEAN NOT NULL, 
	allergy_warning_acknowledged BOOLEAN NOT NULL, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(visit_id) REFERENCES opd_visits (id) ON DELETE CASCADE, 
	FOREIGN KEY(patient_id) REFERENCES patients (id) ON DELETE CASCADE, 
	FOREIGN KEY(doctor_id) REFERENCES doctors (id), 
	FOREIGN KEY(signed_by_user_id) REFERENCES users (id)
);

-- Table: vital_signs
CREATE TABLE IF NOT EXISTS vital_signs (
	id VARCHAR(36) NOT NULL, 
	visit_id VARCHAR(36) NOT NULL, 
	recorded_by_user_id VARCHAR(36), 
	systolic_bp INTEGER, 
	diastolic_bp INTEGER, 
	pulse_rate INTEGER, 
	temperature_f FLOAT, 
	spo2_percent FLOAT, 
	respiratory_rate INTEGER, 
	weight_kg FLOAT, 
	height_cm FLOAT, 
	bmi FLOAT, 
	blood_glucose_mg_dl FLOAT, 
	recorded_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	notes TEXT, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(visit_id) REFERENCES opd_visits (id) ON DELETE CASCADE, 
	FOREIGN KEY(recorded_by_user_id) REFERENCES users (id)
);

-- Table: bill_items
CREATE TABLE IF NOT EXISTS bill_items (
	id VARCHAR(36) NOT NULL, 
	bill_id VARCHAR(36) NOT NULL, 
	item_type VARCHAR(30) NOT NULL, 
	item_code VARCHAR(50), 
	description VARCHAR(200) NOT NULL, 
	quantity INTEGER NOT NULL, 
	unit_price NUMERIC(10, 2) NOT NULL, 
	tax_rate_percent NUMERIC(5, 2) NOT NULL, 
	tax_amount NUMERIC(10, 2) NOT NULL, 
	total_price NUMERIC(10, 2) NOT NULL, 
	reference_id VARCHAR(60), 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(bill_id) REFERENCES bills (id) ON DELETE CASCADE
);

-- Table: clinical_amendments
CREATE TABLE IF NOT EXISTS clinical_amendments (
	id VARCHAR(36) NOT NULL, 
	clinical_record_id VARCHAR(36) NOT NULL, 
	amended_by_user_id VARCHAR(36) NOT NULL, 
	amended_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	reason TEXT NOT NULL, 
	previous_snapshot_json TEXT NOT NULL, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(clinical_record_id) REFERENCES clinical_records (id) ON DELETE CASCADE, 
	FOREIGN KEY(amended_by_user_id) REFERENCES users (id)
);

-- Table: document_audit_logs
CREATE TABLE IF NOT EXISTS document_audit_logs (
	id VARCHAR(36) NOT NULL, 
	document_id VARCHAR(36) NOT NULL, 
	user_id VARCHAR(36), 
	action VARCHAR(50) NOT NULL, 
	ip_address VARCHAR(45), 
	user_agent VARCHAR(255), 
	details_json TEXT, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(document_id) REFERENCES medical_documents (id) ON DELETE CASCADE, 
	FOREIGN KEY(user_id) REFERENCES users (id)
);

-- Table: document_ocr_extractions
CREATE TABLE IF NOT EXISTS document_ocr_extractions (
	id VARCHAR(36) NOT NULL, 
	document_id VARCHAR(36) NOT NULL, 
	page_number INTEGER NOT NULL, 
	field_category VARCHAR(50) NOT NULL, 
	field_name VARCHAR(100) NOT NULL, 
	raw_text TEXT NOT NULL, 
	normalized_value TEXT, 
	confidence FLOAT NOT NULL, 
	is_uncertain BOOLEAN NOT NULL, 
	is_handwritten BOOLEAN NOT NULL, 
	bounding_box_json TEXT, 
	verification_status VARCHAR(30) NOT NULL, 
	verified_value TEXT, 
	verified_by_user_id VARCHAR(36), 
	verified_at TIMESTAMP WITHOUT TIME ZONE, 
	rejection_reason TEXT, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(document_id) REFERENCES medical_documents (id) ON DELETE CASCADE, 
	FOREIGN KEY(verified_by_user_id) REFERENCES users (id)
);

-- Table: document_pages
CREATE TABLE IF NOT EXISTS document_pages (
	id VARCHAR(36) NOT NULL, 
	document_id VARCHAR(36) NOT NULL, 
	page_number INTEGER NOT NULL, 
	file_path VARCHAR(500) NOT NULL, 
	file_size_bytes INTEGER NOT NULL, 
	width INTEGER NOT NULL, 
	height INTEGER NOT NULL, 
	rotation_angle INTEGER NOT NULL, 
	has_perspective_correction BOOLEAN NOT NULL, 
	contrast_enhanced BOOLEAN NOT NULL, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(document_id) REFERENCES medical_documents (id) ON DELETE CASCADE
);

-- Table: lab_results
CREATE TABLE IF NOT EXISTS lab_results (
	id VARCHAR(36) NOT NULL, 
	lab_order_id VARCHAR(36) NOT NULL, 
	verified_by_user_id VARCHAR(36), 
	parameter_name VARCHAR(100) NOT NULL, 
	result_value VARCHAR(50) NOT NULL, 
	unit VARCHAR(30), 
	reference_range VARCHAR(100), 
	is_abnormal BOOLEAN NOT NULL, 
	is_critical BOOLEAN NOT NULL, 
	flag VARCHAR(20) NOT NULL, 
	notes TEXT, 
	reported_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	verified_at TIMESTAMP WITHOUT TIME ZONE, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(lab_order_id) REFERENCES lab_orders (id) ON DELETE CASCADE, 
	FOREIGN KEY(verified_by_user_id) REFERENCES users (id)
);

-- Table: payment_transactions
CREATE TABLE IF NOT EXISTS payment_transactions (
	id VARCHAR(36) NOT NULL, 
	receipt_number VARCHAR(50) NOT NULL, 
	bill_id VARCHAR(36) NOT NULL, 
	patient_id VARCHAR(36) NOT NULL, 
	amount NUMERIC(10, 2) NOT NULL, 
	payment_method VARCHAR(30) NOT NULL, 
	payment_status VARCHAR(20) NOT NULL, 
	is_online BOOLEAN NOT NULL, 
	online_provider VARCHAR(50) NOT NULL, 
	gateway_order_id VARCHAR(100), 
	gateway_payment_id VARCHAR(100), 
	idempotency_key VARCHAR(100), 
	verified_at TIMESTAMP WITHOUT TIME ZONE, 
	refund_amount NUMERIC(10, 2) NOT NULL, 
	refund_reason TEXT, 
	refunded_at TIMESTAMP WITHOUT TIME ZONE, 
	notes TEXT, 
	received_by_user_id VARCHAR(36), 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(bill_id) REFERENCES bills (id) ON DELETE CASCADE, 
	FOREIGN KEY(patient_id) REFERENCES patients (id) ON DELETE CASCADE, 
	FOREIGN KEY(received_by_user_id) REFERENCES users (id)
);

-- Table: pharmacy_dispenses
CREATE TABLE IF NOT EXISTS pharmacy_dispenses (
	id VARCHAR(36) NOT NULL, 
	dispense_number VARCHAR(50) NOT NULL, 
	prescription_id VARCHAR(36) NOT NULL, 
	visit_id VARCHAR(36) NOT NULL, 
	patient_id VARCHAR(36) NOT NULL, 
	dispensed_by_user_id VARCHAR(36) NOT NULL, 
	status VARCHAR(20) NOT NULL, 
	total_items_dispensed INTEGER NOT NULL, 
	total_amount NUMERIC(10, 2) NOT NULL, 
	dispensed_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	notes TEXT, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(prescription_id) REFERENCES prescriptions (id) ON DELETE CASCADE, 
	FOREIGN KEY(visit_id) REFERENCES opd_visits (id) ON DELETE CASCADE, 
	FOREIGN KEY(patient_id) REFERENCES patients (id) ON DELETE CASCADE, 
	FOREIGN KEY(dispensed_by_user_id) REFERENCES users (id)
);

-- Table: pharmacy_orders
CREATE TABLE IF NOT EXISTS pharmacy_orders (
	id VARCHAR(36) NOT NULL, 
	prescription_id VARCHAR(36) NOT NULL, 
	dispensed_by_user_id VARCHAR(36), 
	status VARCHAR(30) NOT NULL, 
	total_amount FLOAT NOT NULL, 
	dispensed_at TIMESTAMP WITHOUT TIME ZONE, 
	notes TEXT, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(prescription_id) REFERENCES prescriptions (id) ON DELETE CASCADE, 
	FOREIGN KEY(dispensed_by_user_id) REFERENCES users (id)
);

-- Table: prescription_amendments
CREATE TABLE IF NOT EXISTS prescription_amendments (
	id VARCHAR(36) NOT NULL, 
	prescription_id VARCHAR(36) NOT NULL, 
	amended_by_user_id VARCHAR(36) NOT NULL, 
	amended_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	reason TEXT NOT NULL, 
	previous_snapshot_json TEXT NOT NULL, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(prescription_id) REFERENCES prescriptions (id) ON DELETE CASCADE, 
	FOREIGN KEY(amended_by_user_id) REFERENCES users (id)
);

-- Table: prescription_items
CREATE TABLE IF NOT EXISTS prescription_items (
	id VARCHAR(36) NOT NULL, 
	prescription_id VARCHAR(36) NOT NULL, 
	medicine_name VARCHAR(150) NOT NULL, 
	form VARCHAR(50) NOT NULL, 
	dosage VARCHAR(50) NOT NULL, 
	route VARCHAR(50) NOT NULL, 
	frequency VARCHAR(30) NOT NULL, 
	duration_days INTEGER NOT NULL, 
	quantity INTEGER, 
	timing VARCHAR(50) NOT NULL, 
	instructions TEXT, 
	is_dispensed BOOLEAN NOT NULL, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(prescription_id) REFERENCES prescriptions (id) ON DELETE CASCADE
);

-- Table: pharmacy_dispense_items
CREATE TABLE IF NOT EXISTS pharmacy_dispense_items (
	id VARCHAR(36) NOT NULL, 
	dispense_id VARCHAR(36) NOT NULL, 
	prescription_item_id VARCHAR(36), 
	inventory_id VARCHAR(36) NOT NULL, 
	medicine_name VARCHAR(150) NOT NULL, 
	batch_number VARCHAR(50) NOT NULL, 
	quantity_prescribed INTEGER NOT NULL, 
	quantity_dispensed INTEGER NOT NULL, 
	unit_price NUMERIC(10, 2) NOT NULL, 
	total_price NUMERIC(10, 2) NOT NULL, 
	instructions TEXT, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(dispense_id) REFERENCES pharmacy_dispenses (id) ON DELETE CASCADE, 
	FOREIGN KEY(prescription_item_id) REFERENCES prescription_items (id) ON DELETE SET NULL, 
	FOREIGN KEY(inventory_id) REFERENCES medicine_inventory (id) ON DELETE RESTRICT
);

-- ========================================================
-- 2. ROW LEVEL SECURITY (RLS) POLICIES
-- Ensures mobile devices on any network connect seamlessly
-- ========================================================
ALTER TABLE IF EXISTS departments DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS medicine_inventory DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS otp_verifications DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS patients DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS permissions DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS roles DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS users DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS audit_logs DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS doctors DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS password_reset_tokens DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS refresh_token_sessions DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS role_permissions DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS stock_movements DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS support_tickets DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS system_configs DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS opd_visits DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS bills DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS clinical_records DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS lab_orders DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS medical_documents DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS prescriptions DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS vital_signs DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS bill_items DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS clinical_amendments DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS document_audit_logs DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS document_ocr_extractions DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS document_pages DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS lab_results DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS payment_transactions DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS pharmacy_dispenses DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS pharmacy_orders DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS prescription_amendments DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS prescription_items DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS pharmacy_dispense_items DISABLE ROW LEVEL SECURITY;


-- ========================================================
-- 3. PRODUCTION SEED DATA (Doctors, Staff, Patients, Visits)
-- Idempotent upserts (ON CONFLICT DO UPDATE)
-- ========================================================

-- Data: roles (8 records)
INSERT INTO roles (id, name, description, created_at, updated_at) VALUES
  ('role_admin', 'admin', 'Full Hospital System Administrator', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('role_doctor', 'doctor', 'Consultant Physician / Specialist', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('role_receptionist', 'receptionist', 'Front Desk Registration & Token Issuer', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('role_pharmacist', 'pharmacist', 'Pharmacy Order Dispenser & Formulary Manager', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('role_lab_tech', 'lab_tech', 'Laboratory Diagnostics & Pathology Technician', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('role_billing', 'billing', 'Billing Counter Cashier & Fee Collector', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('role_nurse', 'nurse', 'Triage & Vitals Assessment Nurse', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('role_patient', 'patient', 'Registered Patient Token & Records Access', '2026-10-15T10:30:00', '2026-10-15T10:30:00')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, created_at = EXCLUDED.created_at, updated_at = EXCLUDED.updated_at;

-- Data: departments (6 records)
INSERT INTO departments (id, name, code, description, is_active, created_at, updated_at) VALUES
  ('dept_med', 'General Medicine', 'MED', 'Adult Internal Medicine, Hypertension, Diabetes, and Infectious Diseases', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('dept_ped', 'Pediatrics', 'PED', 'Neonatal, Child Health, Immunization & Pediatric Care', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('dept_ortho', 'Orthopedics', 'ORTH', 'Bone, Joint, Spine, Fracture Trauma & Sports Injury', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('dept_cardio', 'Cardiology', 'CARD', 'Cardiac Diagnostics, Heart Disease, ECG & Preventive Cardiology', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('dept_ent', 'ENT (Otorhinolaryngology)', 'ENT', 'Ear, Nose, Throat, Sinus, Voice & Hearing Disorders', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('dept_dent', 'Dental & Maxillofacial Surgery', 'DENT', 'Oral Health, Orthodontics, Endodontics & Maxillofacial Care', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, code = EXCLUDED.code, description = EXCLUDED.description, is_active = EXCLUDED.is_active, created_at = EXCLUDED.created_at, updated_at = EXCLUDED.updated_at;

-- Data: users (33 records)
INSERT INTO users (id, email, phone, full_name, hashed_password, role_id, is_active, is_verified, failed_login_attempts, created_at, updated_at) VALUES
  ('usr_admin', 'admin@smvmch.ac.in', '9876543200', 'Hospital Administrator', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_admin', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_doc_med_1', 'dr.sarah.chen@smvmch.ac.in', '9876543101', 'Dr. Sarah Chen, MD', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_doctor', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_doc_med_2', 'dr.rajesh.sundaram@smvmch.ac.in', '9876543102', 'Dr. Rajesh Sundaram, MBBS, MD', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_doctor', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_doc_med_3', 'dr.ananya.sharma@smvmch.ac.in', '9876543103', 'Dr. Ananya Sharma, MD, DNB', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_doctor', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_doc_ped_1', 'dr.priya.balakrishnan@smvmch.ac.in', '9876543104', 'Dr. Priya Balakrishnan, MD (Peds)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_doctor', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_doc_ped_2', 'dr.vikram.rao@smvmch.ac.in', '9876543105', 'Dr. Vikramaditya Rao, DCH, DNB', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_doctor', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_doc_ped_3', 'dr.meera.nambiar@smvmch.ac.in', '9876543106', 'Dr. Meera Nambiar, MBBS, MD', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_doctor', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_doc_ortho_1', 'dr.karthik.subramaniam@smvmch.ac.in', '9876543107', 'Dr. Karthik Subramaniam, MS (Ortho)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_doctor', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_doc_ortho_2', 'dr.david.miller@smvmch.ac.in', '9876543108', 'Dr. David Miller, MD, FRCS', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_doctor', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_doc_ortho_3', 'dr.sanjay.verma@smvmch.ac.in', '9876543109', 'Dr. Sanjay Verma, MS (Ortho)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_doctor', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_doc_cardio_1', 'dr.arvind.swamy@smvmch.ac.in', '9876543110', 'Dr. Arvind Swamy, MD, DM (Cardio)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_doctor', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_doc_cardio_2', 'dr.preethi.venkat@smvmch.ac.in', '9876543111', 'Dr. Preethi Venkat, MBBS, DNB (Cardio)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_doctor', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_doc_cardio_3', 'dr.ramesh.chandran@smvmch.ac.in', '9876543112', 'Dr. Ramesh Chandran, MD, DM, FACC', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_doctor', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_doc_ent_1', 'dr.pooja.deshmukh@smvmch.ac.in', '9876543113', 'Dr. Pooja Deshmukh, MS (ENT)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_doctor', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_doc_ent_2', 'dr.harish.kumar@smvmch.ac.in', '9876543114', 'Dr. Harish Kumar, MBBS, DLO', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_doctor', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_doc_ent_3', 'dr.gautham.menon@smvmch.ac.in', '9876543115', 'Dr. Gautham Menon, MS (ENT)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_doctor', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_doc_dent_1', 'dr.arunraj@smvmch.ac.in', '9876543116', 'Dr. M. Arunraj, MDS (Oral Surg)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_doctor', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_doc_dent_2', 'dr.swathi.reddy@smvmch.ac.in', '9876543117', 'Dr. Swathi Reddy, BDS, MDS (Ortho)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_doctor', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_doc_dent_3', 'dr.kevin.thomas@smvmch.ac.in', '9876543118', 'Dr. Kevin Thomas, MDS (Periodontics)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_doctor', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_rec_1', 'receptionist1@smvmch.ac.in', '9876543210', 'Alice Adams (Reception 1)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_receptionist', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_rec_2', 'receptionist2@smvmch.ac.in', '9876543211', 'Kavitha Raman (Reception 2)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_receptionist', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_pharm_1', 'pharmacist1@smvmch.ac.in', '9876543221', 'Elena Rostova (Lead Pharmacist)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_pharmacist', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_pharm_2', 'pharmacist2@smvmch.ac.in', '9876543222', 'Rahul Sharma (Pharmacist Desk 2)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_pharmacist', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_pharm_3', 'pharmacist3@smvmch.ac.in', '9876543223', 'Deepa Krishnan (Pharmacist Desk 3)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_pharmacist', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_pharm_4', 'pharmacist4@smvmch.ac.in', '9876543224', 'Manoj Kumar (Dispensing Pharmacist)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_pharmacist', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_pharm_5', 'pharmacist5@smvmch.ac.in', '9876543225', 'Sneha Patel (Inventory Pharmacist)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_pharmacist', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_lab_1', 'lab1@smvmch.ac.in', '9876543231', 'Marcus Vance (Senior Lab Tech)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_lab_tech', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_lab_2', 'lab2@smvmch.ac.in', '9876543232', 'Divya Prakash (Biochemist)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_lab_tech', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_lab_3', 'lab3@smvmch.ac.in', '9876543233', 'Sandeep Varma (Hematologist Tech)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_lab_tech', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_bill_1', 'billing1@smvmch.ac.in', '9876543241', 'Rajesh Kumar (Counter 1)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_billing', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_bill_2', 'billing2@smvmch.ac.in', '9876543242', 'Suresh Babu (Counter 2)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_billing', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_bill_3', 'billing3@smvmch.ac.in', '9876543243', 'Lakshmi Narayanan (Counter 3)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_billing', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_bill_4', 'billing4@smvmch.ac.in', '9876543244', 'Anitha Murugan (Counter 4)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_billing', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00')
ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email, phone = EXCLUDED.phone, full_name = EXCLUDED.full_name, hashed_password = EXCLUDED.hashed_password, role_id = EXCLUDED.role_id, is_active = EXCLUDED.is_active, is_verified = EXCLUDED.is_verified, failed_login_attempts = EXCLUDED.failed_login_attempts, created_at = EXCLUDED.created_at, updated_at = EXCLUDED.updated_at;

-- Data: doctors (18 records)
INSERT INTO doctors (id, user_id, department_id, qualification, specialization, registration_number, room_number, consultation_fee, is_available, created_at, updated_at) VALUES
  ('doc_med_1', 'usr_doc_med_1', 'dept_med', 'MBBS, MD (General Medicine)', 'Internal Medicine & Diabetology', 'MCI-TN-48901', 'OPD Room 101, Ground Floor', 500.0, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('doc_med_2', 'usr_doc_med_2', 'dept_med', 'MBBS, MD (Internal Medicine)', 'Geriatrics & Hypertension', 'MCI-TN-51204', 'OPD Room 102, Ground Floor', 500.0, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('doc_med_3', 'usr_doc_med_3', 'dept_med', 'MD, DNB (General Medicine)', 'Infectious Diseases & Critical Care', 'MCI-TN-54329', 'OPD Room 103, Ground Floor', 500.0, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('doc_ped_1', 'usr_doc_ped_1', 'dept_ped', 'MBBS, MD (Pediatrics)', 'Pediatric Pulmonology & Allergy', 'MCI-TN-61002', 'OPD Room 201, 1st Floor', 600.0, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('doc_ped_2', 'usr_doc_ped_2', 'dept_ped', 'DCH, DNB (Pediatrics)', 'Neonatology & Growth Assessment', 'MCI-TN-62187', 'OPD Room 202, 1st Floor', 600.0, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('doc_ped_3', 'usr_doc_ped_3', 'dept_ped', 'MBBS, MD (Pediatrics)', 'Child Nutrition & Immunization', 'MCI-TN-63401', 'OPD Room 203, 1st Floor', 600.0, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('doc_ortho_1', 'usr_doc_ortho_1', 'dept_ortho', 'MS (Orthopedics)', 'Spine & Joint Replacement', 'MCI-TN-71890', 'OPD Room 301, 2nd Floor', 700.0, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('doc_ortho_2', 'usr_doc_ortho_2', 'dept_ortho', 'MD, FRCS (Ortho)', 'Sports Medicine & Arthroscopy', 'MCI-TN-72543', 'OPD Room 302, 2nd Floor', 750.0, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('doc_ortho_3', 'usr_doc_ortho_3', 'dept_ortho', 'MS (Ortho), DNB', 'Trauma & Fracture Reconstruction', 'MCI-TN-73912', 'OPD Room 303, 2nd Floor', 700.0, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('doc_cardio_1', 'usr_doc_cardio_1', 'dept_cardio', 'MD, DM (Cardiology)', 'Interventional Cardiology & Angiography', 'MCI-TN-81098', 'OPD Room 401, 3rd Floor', 900.0, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('doc_cardio_2', 'usr_doc_cardio_2', 'dept_cardio', 'MBBS, DNB (Cardiology)', 'Non-Invasive Cardiology & Echocardiography', 'MCI-TN-82341', 'OPD Room 402, 3rd Floor', 850.0, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('doc_cardio_3', 'usr_doc_cardio_3', 'dept_cardio', 'MD, DM, FACC', 'Heart Failure & Preventive Cardiology', 'MCI-TN-83567', 'OPD Room 403, 3rd Floor', 1000.0, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('doc_ent_1', 'usr_doc_ent_1', 'dept_ent', 'MS (ENT)', 'Endoscopic Sinus Surgery & Rhinology', 'MCI-TN-91045', 'OPD Room 501, 4th Floor', 550.0, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('doc_ent_2', 'usr_doc_ent_2', 'dept_ent', 'MBBS, DLO, DNB (ENT)', 'Otology & Audiology', 'MCI-TN-92189', 'OPD Room 502, 4th Floor', 550.0, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('doc_ent_3', 'usr_doc_ent_3', 'dept_ent', 'MS (ENT)', 'Laryngology & Voice Disorders', 'MCI-TN-93450', 'OPD Room 503, 4th Floor', 600.0, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('doc_dent_1', 'usr_doc_dent_1', 'dept_dent', 'BDS, MDS (Oral & Maxillofacial)', 'Oral Surgery & Dental Implants', 'DCI-TN-31092', 'Dental Clinic 208, Block B', 600.0, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('doc_dent_2', 'usr_doc_dent_2', 'dept_dent', 'BDS, MDS (Orthodontics)', 'Dentofacial Orthopedics & Braces', 'DCI-TN-32145', 'Dental Clinic 209, Block B', 600.0, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('doc_dent_3', 'usr_doc_dent_3', 'dept_dent', 'MDS (Periodontics)', 'Gum Diseases & Aesthetic Dentistry', 'DCI-TN-33410', 'Dental Clinic 210, Block B', 600.0, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00')
ON CONFLICT (id) DO UPDATE SET user_id = EXCLUDED.user_id, department_id = EXCLUDED.department_id, qualification = EXCLUDED.qualification, specialization = EXCLUDED.specialization, registration_number = EXCLUDED.registration_number, room_number = EXCLUDED.room_number, consultation_fee = EXCLUDED.consultation_fee, is_available = EXCLUDED.is_available, created_at = EXCLUDED.created_at, updated_at = EXCLUDED.updated_at;

-- Data: patients (20 records)
INSERT INTO patients (id, uhid, hospital_reg_num, abha_number, full_name, parent_spouse_name, parent_spouse_relation, date_of_birth, age_years, age_months, gender, phone, email, address, city, state, postal_code, blood_group, registration_date, barcode_value, qr_code_data, registered_by_staff_id, registered_by_staff_name, registered_by_staff_role, guardian_id, created_at, updated_at) VALUES
  ('pat_001', 'UHID-2026-00001', 'REG-2026-00001', '8374-4779-99-99', 'Lakshmi Srujana Majeti', 'Majeti Satyanarayana', 'Daughter', '1996-01-15', 30, 0, 'FEMALE', '8374477999', 'lakshmi.srujana.majeti@opdpatient.in', 'Flat 402, Sri Krishna Heights', 'Vijayawada', 'Andhra Pradesh', '520010', 'O+', '2026-10-15T10:30:00', 'BAR-UHID-2026-00001', 'SMVMCH|UHID-2026-00001|REG-2026-00001|Lakshmi Srujana Majeti|O+', 'usr_rec_1', 'Alice Adams (Reception 1)', 'receptionist', NULL, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('pat_002', 'UHID-2026-00002', 'REG-2026-00002', '9876-5432-01-99', 'uday', 'satya', 'Son', '2001-01-15', 25, 0, 'MALE', '9876543201', 'uday@opdpatient.in', 'Door No 14/2, Anna Nagar', 'Puducherry', 'Puducherry', '605001', 'O+', '2026-10-15T10:30:00', 'BAR-UHID-2026-00002', 'SMVMCH|UHID-2026-00002|REG-2026-00002|uday|O+', 'usr_rec_1', 'Alice Adams (Reception 1)', 'receptionist', NULL, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('pat_003', 'UHID-2026-00003', 'REG-2026-00003', '9443-2187-65-99', 'K. Venkatasubramanian', 'Krishnan Iyer', 'Son', '1964-01-15', 62, 0, 'MALE', '9443218765', 'k..venkatasubramanian@opdpatient.in', '72, East Car Street, Chidambaram', 'Cuddalore', 'Tamil Nadu', '608001', 'B+', '2026-10-15T10:30:00', 'BAR-UHID-2026-00003', 'SMVMCH|UHID-2026-00003|REG-2026-00003|K. Venkatasubramanian|B+', 'usr_rec_1', 'Alice Adams (Reception 1)', 'receptionist', NULL, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('pat_004', 'UHID-2026-00004', 'REG-2026-00004', '9840-1234-56-99', 'Sowmya Radhakrishnan', 'Radhakrishnan Nair', 'Wife', '1998-01-15', 28, 0, 'FEMALE', '9840123456', 'sowmya.radhakrishnan@opdpatient.in', 'Plot 18, Lake View Enclave', 'Chennai', 'Tamil Nadu', '600042', 'A+', '2026-10-15T10:30:00', 'BAR-UHID-2026-00004', 'SMVMCH|UHID-2026-00004|REG-2026-00004|Sowmya Radhakrishnan|A+', 'usr_rec_1', 'Alice Adams (Reception 1)', 'receptionist', NULL, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('pat_005', 'UHID-2026-00005', 'REG-2026-00005', '9884-5678-90-99', 'Master Aarav Vignesh', 'Vigneshwaran M', 'Son', '2020-01-15', 6, 0, 'MALE', '9884567890', 'master.aarav.vignesh@opdpatient.in', '22, Gandhi Road', 'Villupuram', 'Tamil Nadu', '605602', 'O+', '2026-10-15T10:30:00', 'BAR-UHID-2026-00005', 'SMVMCH|UHID-2026-00005|REG-2026-00005|Master Aarav Vignesh|O+', 'usr_rec_1', 'Alice Adams (Reception 1)', 'receptionist', NULL, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('pat_006', 'UHID-2026-00006', 'REG-2026-00006', '9444-1238-90-99', 'Meenakshi Sundaram', 'Sundaramurthy Pillai', 'Wife', '1968-01-15', 58, 0, 'FEMALE', '9444123890', 'meenakshi.sundaram@opdpatient.in', '45/A, North Mada Street, Mylapore', 'Chennai', 'Tamil Nadu', '600004', 'AB+', '2026-10-15T10:30:00', 'BAR-UHID-2026-00006', 'SMVMCH|UHID-2026-00006|REG-2026-00006|Meenakshi Sundaram|AB+', 'usr_rec_1', 'Alice Adams (Reception 1)', 'receptionist', NULL, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('pat_007', 'UHID-2026-00007', 'REG-2026-00007', '9789-0123-45-99', 'R. Karthikeyan', 'Ramasamy Gounder', 'Son', '1992-01-15', 34, 0, 'MALE', '9789012345', 'r..karthikeyan@opdpatient.in', '12, Bharathi Street', 'Tindivanam', 'Tamil Nadu', '604001', 'B+', '2026-10-15T10:30:00', 'BAR-UHID-2026-00007', 'SMVMCH|UHID-2026-00007|REG-2026-00007|R. Karthikeyan|B+', 'usr_rec_1', 'Alice Adams (Reception 1)', 'receptionist', NULL, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('pat_008', 'UHID-2026-00008', 'REG-2026-00008', '9940-1237-89-99', 'Baby Ananya Sri', 'Senthil Kumar', 'Daughter', '2023-01-15', 3, 0, 'FEMALE', '9940123789', 'baby.ananya.sri@opdpatient.in', '5/8, Church Street', 'Puducherry', 'Puducherry', '605003', 'A+', '2026-10-15T10:30:00', 'BAR-UHID-2026-00008', 'SMVMCH|UHID-2026-00008|REG-2026-00008|Baby Ananya Sri|A+', 'usr_rec_1', 'Alice Adams (Reception 1)', 'receptionist', NULL, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('pat_009', 'UHID-2026-00009', 'REG-2026-00009', '9841-2345-67-99', 'Farooq Ahmed', 'Abdul Razack', 'Son', '1979-01-15', 47, 0, 'MALE', '9841234567', 'farooq.ahmed@opdpatient.in', '89, Mosque Street, Gorimedu', 'Puducherry', 'Puducherry', '605006', 'O-', '2026-10-15T10:30:00', 'BAR-UHID-2026-00009', 'SMVMCH|UHID-2026-00009|REG-2026-00009|Farooq Ahmed|O-', 'usr_rec_1', 'Alice Adams (Reception 1)', 'receptionist', NULL, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('pat_010', 'UHID-2026-00010', 'REG-2026-00010', '9710-2345-67-99', 'Geetha Govindaraj', 'Govindarajan K', 'Wife', '1984-01-15', 42, 0, 'FEMALE', '9710234567', 'geetha.govindaraj@opdpatient.in', '34, South Street, Cuddalore Old Town', 'Cuddalore', 'Tamil Nadu', '607003', 'B-', '2026-10-15T10:30:00', 'BAR-UHID-2026-00010', 'SMVMCH|UHID-2026-00010|REG-2026-00010|Geetha Govindaraj|B-', 'usr_rec_1', 'Alice Adams (Reception 1)', 'receptionist', NULL, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('pat_011', 'UHID-2026-00011', 'REG-2026-00011', '9884-0123-45-99', 'Pradeep Chandran', 'Chandrasekaran V', 'Son', '1988-01-15', 38, 0, 'MALE', '9884012345', 'pradeep.chandran@opdpatient.in', '101, Beach Road', 'Karaikal', 'Puducherry', '609602', 'A-', '2026-10-15T10:30:00', 'BAR-UHID-2026-00011', 'SMVMCH|UHID-2026-00011|REG-2026-00011|Pradeep Chandran|A-', 'usr_rec_1', 'Alice Adams (Reception 1)', 'receptionist', NULL, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('pat_012', 'UHID-2026-00012', 'REG-2026-00012', '9444-5678-12-99', 'Rukmani Ammal', 'Late Rangasamy', 'Wife', '1955-01-15', 71, 0, 'FEMALE', '9444567812', 'rukmani.ammal@opdpatient.in', '67, Perumal Koil Street', 'Madurantakam', 'Tamil Nadu', '603306', 'O+', '2026-10-15T10:30:00', 'BAR-UHID-2026-00012', 'SMVMCH|UHID-2026-00012|REG-2026-00012|Rukmani Ammal|O+', 'usr_rec_1', 'Alice Adams (Reception 1)', 'receptionist', NULL, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('pat_013', 'UHID-2026-00013', 'REG-2026-00013', '9600-1234-56-99', 'Vasanth Kumar', 'Kumaravel S', 'Son', '2004-01-15', 22, 0, 'MALE', '9600123456', 'vasanth.kumar@opdpatient.in', 'College Road, Lawspet', 'Puducherry', 'Puducherry', '605008', 'AB-', '2026-10-15T10:30:00', 'BAR-UHID-2026-00013', 'SMVMCH|UHID-2026-00013|REG-2026-00013|Vasanth Kumar|AB-', 'usr_rec_1', 'Alice Adams (Reception 1)', 'receptionist', NULL, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('pat_014', 'UHID-2026-00014', 'REG-2026-00014', '9840-5678-12-99', 'Nithya Kalyani', 'Muthukrishnan T', 'Daughter', '1995-01-15', 31, 0, 'FEMALE', '9840567812', 'nithya.kalyani@opdpatient.in', '42, Kamaraj Salai', 'Puducherry', 'Puducherry', '605009', 'A+', '2026-10-15T10:30:00', 'BAR-UHID-2026-00014', 'SMVMCH|UHID-2026-00014|REG-2026-00014|Nithya Kalyani|A+', 'usr_rec_1', 'Alice Adams (Reception 1)', 'receptionist', NULL, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('pat_015', 'UHID-2026-00015', 'REG-2026-00015', '9790-1234-56-99', 'Balaji Narayanan', 'Narayanasamy R', 'Son', '1977-01-15', 49, 0, 'MALE', '9790123456', 'balaji.narayanan@opdpatient.in', '15, Cross Street, Saram', 'Puducherry', 'Puducherry', '605013', 'B+', '2026-10-15T10:30:00', 'BAR-UHID-2026-00015', 'SMVMCH|UHID-2026-00015|REG-2026-00015|Balaji Narayanan|B+', 'usr_rec_1', 'Alice Adams (Reception 1)', 'receptionist', NULL, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('pat_016', 'UHID-2026-00016', 'REG-2026-00016', '9962-1234-56-99', 'Shalini Mohan', 'Mohanraj P', 'Daughter', '2000-01-15', 26, 0, 'FEMALE', '9962123456', 'shalini.mohan@opdpatient.in', '88, Main Road, Neyveli', 'Cuddalore', 'Tamil Nadu', '607803', 'O+', '2026-10-15T10:30:00', 'BAR-UHID-2026-00016', 'SMVMCH|UHID-2026-00016|REG-2026-00016|Shalini Mohan|O+', 'usr_rec_1', 'Alice Adams (Reception 1)', 'receptionist', NULL, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('pat_017', 'UHID-2026-00017', 'REG-2026-00017', '9443-5678-90-99', 'C. Dhandapani', 'Chinnasamy G', 'Son', '1971-01-15', 55, 0, 'MALE', '9443567890', 'c..dhandapani@opdpatient.in', '33, Bazaar Street', 'Panruti', 'Tamil Nadu', '607106', 'A+', '2026-10-15T10:30:00', 'BAR-UHID-2026-00017', 'SMVMCH|UHID-2026-00017|REG-2026-00017|C. Dhandapani|A+', 'usr_rec_1', 'Alice Adams (Reception 1)', 'receptionist', NULL, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('pat_018', 'UHID-2026-00018', 'REG-2026-00018', '9841-9876-54-99', 'Fatima Beevi', 'Late Syed Ibrahim', 'Wife', '1961-01-15', 65, 0, 'FEMALE', '9841987654', 'fatima.beevi@opdpatient.in', '19, New Street, Heritage Town', 'Puducherry', 'Puducherry', '605001', 'B+', '2026-10-15T10:30:00', 'BAR-UHID-2026-00018', 'SMVMCH|UHID-2026-00018|REG-2026-00018|Fatima Beevi|B+', 'usr_rec_1', 'Alice Adams (Reception 1)', 'receptionist', NULL, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('pat_019', 'UHID-2026-00019', 'REG-2026-00019', '9789-5678-90-99', 'G. Senthil Nathan', 'Ganesan P', 'Son', '1985-01-15', 41, 0, 'MALE', '9789567890', 'g..senthil.nathan@opdpatient.in', '51, Extension Colony', 'Kanchipuram', 'Tamil Nadu', '631502', 'O+', '2026-10-15T10:30:00', 'BAR-UHID-2026-00019', 'SMVMCH|UHID-2026-00019|REG-2026-00019|G. Senthil Nathan|O+', 'usr_rec_1', 'Alice Adams (Reception 1)', 'receptionist', NULL, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('pat_020', 'UHID-2026-00020', 'REG-2026-00020', '8555-0272-25-99', 'Dr. Chintha Ravi Prasanth', 'Late C. Subba Rao', 'Son', '1991-01-15', 35, 0, 'MALE', '8555027225', 'dr..chintha.ravi.prasanth@opdpatient.in', 'Flat 204, Executive Enclave', 'Hyderabad', 'Telangana', '500081', 'B+', '2026-10-15T10:30:00', 'BAR-UHID-2026-00020', 'SMVMCH|UHID-2026-00020|REG-2026-00020|Dr. Chintha Ravi Prasanth|B+', 'usr_rec_1', 'Alice Adams (Reception 1)', 'receptionist', NULL, '2026-10-15T10:30:00', '2026-10-15T10:30:00')
ON CONFLICT (id) DO UPDATE SET uhid = EXCLUDED.uhid, hospital_reg_num = EXCLUDED.hospital_reg_num, abha_number = EXCLUDED.abha_number, full_name = EXCLUDED.full_name, parent_spouse_name = EXCLUDED.parent_spouse_name, parent_spouse_relation = EXCLUDED.parent_spouse_relation, date_of_birth = EXCLUDED.date_of_birth, age_years = EXCLUDED.age_years, age_months = EXCLUDED.age_months, gender = EXCLUDED.gender, phone = EXCLUDED.phone, email = EXCLUDED.email, address = EXCLUDED.address, city = EXCLUDED.city, state = EXCLUDED.state, postal_code = EXCLUDED.postal_code, blood_group = EXCLUDED.blood_group, registration_date = EXCLUDED.registration_date, barcode_value = EXCLUDED.barcode_value, qr_code_data = EXCLUDED.qr_code_data, registered_by_staff_id = EXCLUDED.registered_by_staff_id, registered_by_staff_name = EXCLUDED.registered_by_staff_name, registered_by_staff_role = EXCLUDED.registered_by_staff_role, guardian_id = EXCLUDED.guardian_id, created_at = EXCLUDED.created_at, updated_at = EXCLUDED.updated_at;

-- Data: opd_visits (20 records)
INSERT INTO opd_visits (id, visit_number, patient_id, doctor_id, department_id, visit_date, queue_token, triage_priority, status, consultation_fee, payment_status, notes, created_at, updated_at) VALUES
  ('vis_pat_001', 'VIS-20261015-0001', 'pat_001', 'doc_med_1', 'dept_med', '2026-10-15T10:30:00', 1, 'NORMAL', 'IN_CONSULTATION', 500.0, 'PAID', 'Chief Clinical Diagnosis: Type 2 Diabetes Mellitus with Peripheral Neuropathy', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vis_pat_002', 'VIS-20261015-0002', 'pat_002', 'doc_ortho_1', 'dept_ortho', '2026-10-15T10:30:00', 2, 'NORMAL', 'WAITING', 750.0, 'PAID', 'Chief Clinical Diagnosis: Acute Lumbar Muscle Sprain & Sciatica', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vis_pat_003', 'VIS-20261015-0003', 'pat_003', 'doc_cardio_1', 'dept_cardio', '2026-10-15T10:30:00', 3, 'PRIORITY', 'IN_CONSULTATION', 750.0, 'PAID', 'Chief Clinical Diagnosis: Essential Hypertension & CAD (Post-PTCA Follow-up)', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vis_pat_004', 'VIS-20261015-0004', 'pat_004', 'doc_med_2', 'dept_med', '2026-10-15T10:30:00', 4, 'NORMAL', 'WAITING', 500.0, 'PAID', 'Chief Clinical Diagnosis: Antenatal Care 26 Weeks Gestation with Mild Anemia', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vis_pat_005', 'VIS-20261015-0005', 'pat_005', 'doc_ped_1', 'dept_ped', '2026-10-15T10:30:00', 5, 'EMERGENCY', 'TRIAGED', 600.0, 'PAID', 'Chief Clinical Diagnosis: Pediatric Bronchial Asthma with Acute Wheezing', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vis_pat_006', 'VIS-20261015-0006', 'pat_006', 'doc_ortho_2', 'dept_ortho', '2026-10-15T10:30:00', 6, 'NORMAL', 'WAITING', 750.0, 'PAID', 'Chief Clinical Diagnosis: Bilateral Knee Osteoarthritis Grade III', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vis_pat_007', 'VIS-20261015-0007', 'pat_007', 'doc_med_3', 'dept_med', '2026-10-15T10:30:00', 7, 'EMERGENCY', 'TRIAGED', 500.0, 'PAID', 'Chief Clinical Diagnosis: Acute Febrile Illness - Suspected Dengue Fever', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vis_pat_008', 'VIS-20261015-0008', 'pat_008', 'doc_ped_2', 'dept_ped', '2026-10-15T10:30:00', 8, 'PRIORITY', 'WAITING', 600.0, 'PAID', 'Chief Clinical Diagnosis: Acute Otitis Media & Upper Respiratory Infection', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vis_pat_009', 'VIS-20261015-0009', 'pat_009', 'doc_med_1', 'dept_med', '2026-10-15T10:30:00', 9, 'PRIORITY', 'IN_CONSULTATION', 500.0, 'PAID', 'Chief Clinical Diagnosis: Chronic Obstructive Pulmonary Disease (COPD) Grade II', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vis_pat_010', 'VIS-20261015-0010', 'pat_010', 'doc_med_2', 'dept_med', '2026-10-15T10:30:00', 10, 'NORMAL', 'COMPLETED', 500.0, 'PAID', 'Chief Clinical Diagnosis: Hypothyroidism with Dyslipidemia & Weight Gain', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vis_pat_011', 'VIS-20261015-0011', 'pat_011', 'doc_med_3', 'dept_med', '2026-10-15T10:30:00', 11, 'EMERGENCY', 'TRIAGED', 500.0, 'PAID', 'Chief Clinical Diagnosis: Acute Left Ureteric Calculus with Severe Renal Colic', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vis_pat_012', 'VIS-20261015-0012', 'pat_012', 'doc_med_1', 'dept_med', '2026-10-15T10:30:00', 12, 'PRIORITY', 'WAITING', 500.0, 'PAID', 'Chief Clinical Diagnosis: Chronic Kidney Disease Stage 3b & Diabetic Nephropathy', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vis_pat_013', 'VIS-20261015-0013', 'pat_013', 'doc_ortho_3', 'dept_ortho', '2026-10-15T10:30:00', 13, 'PRIORITY', 'WAITING', 750.0, 'PAID', 'Chief Clinical Diagnosis: Right Ankle Inversion Injury / Lateral Ligament Sprain', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vis_pat_014', 'VIS-20261015-0014', 'pat_014', 'doc_med_2', 'dept_med', '2026-10-15T10:30:00', 14, 'NORMAL', 'WAITING', 500.0, 'PAID', 'Chief Clinical Diagnosis: Chronic Migraine with Visual Aura & Photophobia', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vis_pat_015', 'VIS-20261015-0015', 'pat_015', 'doc_med_3', 'dept_med', '2026-10-15T10:30:00', 15, 'NORMAL', 'COMPLETED', 500.0, 'PAID', 'Chief Clinical Diagnosis: Gastroesophageal Reflux Disease (GERD) & Erosive Gastritis', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vis_pat_016', 'VIS-20261015-0016', 'pat_016', 'doc_med_1', 'dept_med', '2026-10-15T10:30:00', 16, 'PRIORITY', 'WAITING', 500.0, 'PAID', 'Chief Clinical Diagnosis: Severe Iron Deficiency Anemia (Hb 7.8 g/dL)', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vis_pat_017', 'VIS-20261015-0017', 'pat_017', 'doc_dent_1', 'dept_dent', '2026-10-15T10:30:00', 17, 'PRIORITY', 'IN_CONSULTATION', 500.0, 'PAID', 'Chief Clinical Diagnosis: Severe Acute Pulpitis & Mandibular 1st Molar Abscess', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vis_pat_018', 'VIS-20261015-0018', 'pat_018', 'doc_med_2', 'dept_med', '2026-10-15T10:30:00', 18, 'NORMAL', 'COMPLETED', 500.0, 'PAID', 'Chief Clinical Diagnosis: Chronic Allergic Contact Dermatitis & Numular Eczema', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vis_pat_019', 'VIS-20261015-0019', 'pat_019', 'doc_ent_1', 'dept_ent', '2026-10-15T10:30:00', 19, 'NORMAL', 'WAITING', 500.0, 'PAID', 'Chief Clinical Diagnosis: Allergic Rhinitis with Chronic Maxillary Sinusitis', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vis_pat_020', 'VIS-20261015-0020', 'pat_020', 'doc_med_3', 'dept_med', '2026-10-15T10:30:00', 20, 'NORMAL', 'COMPLETED', 500.0, 'PAID', 'Chief Clinical Diagnosis: Executive Annual Health Evaluation & Routine Screen', '2026-10-15T10:30:00', '2026-10-15T10:30:00')
ON CONFLICT (id) DO UPDATE SET visit_number = EXCLUDED.visit_number, patient_id = EXCLUDED.patient_id, doctor_id = EXCLUDED.doctor_id, department_id = EXCLUDED.department_id, visit_date = EXCLUDED.visit_date, queue_token = EXCLUDED.queue_token, triage_priority = EXCLUDED.triage_priority, status = EXCLUDED.status, consultation_fee = EXCLUDED.consultation_fee, payment_status = EXCLUDED.payment_status, notes = EXCLUDED.notes, created_at = EXCLUDED.created_at, updated_at = EXCLUDED.updated_at;

-- Data: vital_signs (20 records)
INSERT INTO vital_signs (id, visit_id, systolic_bp, diastolic_bp, pulse_rate, temperature_f, spo2_percent, respiratory_rate, height_cm, weight_kg, bmi, recorded_by_user_id, recorded_at, notes, created_at, updated_at) VALUES
  ('vit_vis_pat_001', 'vis_pat_001', 120, 78, 74, 98.4, 98.0, 18, 165.0, 64.0, 23.5, 'usr_rec_1', '2026-10-15T10:30:00', 'Triage assessment for Type 2 Diabetes Mellitus with Peripheral Neuropathy', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vit_vis_pat_002', 'vis_pat_002', 122, 79, 77, 98.4, 98.0, 18, 165.0, 64.0, 23.5, 'usr_rec_1', '2026-10-15T10:30:00', 'Triage assessment for Acute Lumbar Muscle Sprain & Sciatica', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vit_vis_pat_003', 'vis_pat_003', 124, 80, 80, 98.4, 98.0, 18, 165.0, 64.0, 23.5, 'usr_rec_1', '2026-10-15T10:30:00', 'Triage assessment for Essential Hypertension & CAD (Post-PTCA Follow-up)', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vit_vis_pat_004', 'vis_pat_004', 126, 81, 83, 98.4, 98.0, 18, 165.0, 64.0, 23.5, 'usr_rec_1', '2026-10-15T10:30:00', 'Triage assessment for Antenatal Care 26 Weeks Gestation with Mild Anemia', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vit_vis_pat_005', 'vis_pat_005', 128, 82, 86, 101.8, 94.0, 18, 165.0, 64.0, 23.5, 'usr_rec_1', '2026-10-15T10:30:00', 'Triage assessment for Pediatric Bronchial Asthma with Acute Wheezing', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vit_vis_pat_006', 'vis_pat_006', 130, 83, 89, 98.4, 98.0, 18, 165.0, 64.0, 23.5, 'usr_rec_1', '2026-10-15T10:30:00', 'Triage assessment for Bilateral Knee Osteoarthritis Grade III', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vit_vis_pat_007', 'vis_pat_007', 132, 84, 92, 101.8, 98.0, 18, 165.0, 64.0, 23.5, 'usr_rec_1', '2026-10-15T10:30:00', 'Triage assessment for Acute Febrile Illness - Suspected Dengue Fever', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vit_vis_pat_008', 'vis_pat_008', 134, 85, 95, 98.4, 98.0, 18, 165.0, 64.0, 23.5, 'usr_rec_1', '2026-10-15T10:30:00', 'Triage assessment for Acute Otitis Media & Upper Respiratory Infection', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vit_vis_pat_009', 'vis_pat_009', 136, 86, 98, 98.4, 94.0, 18, 165.0, 64.0, 23.5, 'usr_rec_1', '2026-10-15T10:30:00', 'Triage assessment for Chronic Obstructive Pulmonary Disease (COPD) Grade II', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vit_vis_pat_010', 'vis_pat_010', 138, 87, 76, 98.4, 98.0, 18, 165.0, 64.0, 23.5, 'usr_rec_1', '2026-10-15T10:30:00', 'Triage assessment for Hypothyroidism with Dyslipidemia & Weight Gain', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vit_vis_pat_011', 'vis_pat_011', 140, 88, 79, 101.8, 98.0, 18, 165.0, 64.0, 23.5, 'usr_rec_1', '2026-10-15T10:30:00', 'Triage assessment for Acute Left Ureteric Calculus with Severe Renal Colic', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vit_vis_pat_012', 'vis_pat_012', 142, 89, 82, 98.4, 98.0, 18, 165.0, 64.0, 23.5, 'usr_rec_1', '2026-10-15T10:30:00', 'Triage assessment for Chronic Kidney Disease Stage 3b & Diabetic Nephropathy', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vit_vis_pat_013', 'vis_pat_013', 144, 90, 85, 98.4, 98.0, 18, 165.0, 64.0, 23.5, 'usr_rec_1', '2026-10-15T10:30:00', 'Triage assessment for Right Ankle Inversion Injury / Lateral Ligament Sprain', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vit_vis_pat_014', 'vis_pat_014', 146, 91, 88, 98.4, 98.0, 18, 165.0, 64.0, 23.5, 'usr_rec_1', '2026-10-15T10:30:00', 'Triage assessment for Chronic Migraine with Visual Aura & Photophobia', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vit_vis_pat_015', 'vis_pat_015', 148, 92, 91, 98.4, 98.0, 18, 165.0, 64.0, 23.5, 'usr_rec_1', '2026-10-15T10:30:00', 'Triage assessment for Gastroesophageal Reflux Disease (GERD) & Erosive Gastritis', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vit_vis_pat_016', 'vis_pat_016', 150, 93, 94, 98.4, 98.0, 18, 165.0, 64.0, 23.5, 'usr_rec_1', '2026-10-15T10:30:00', 'Triage assessment for Severe Iron Deficiency Anemia (Hb 7.8 g/dL)', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vit_vis_pat_017', 'vis_pat_017', 152, 94, 97, 98.4, 98.0, 18, 165.0, 64.0, 23.5, 'usr_rec_1', '2026-10-15T10:30:00', 'Triage assessment for Severe Acute Pulpitis & Mandibular 1st Molar Abscess', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vit_vis_pat_018', 'vis_pat_018', 154, 95, 75, 98.4, 98.0, 18, 165.0, 64.0, 23.5, 'usr_rec_1', '2026-10-15T10:30:00', 'Triage assessment for Chronic Allergic Contact Dermatitis & Numular Eczema', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vit_vis_pat_019', 'vis_pat_019', 156, 96, 78, 98.4, 98.0, 18, 165.0, 64.0, 23.5, 'usr_rec_1', '2026-10-15T10:30:00', 'Triage assessment for Allergic Rhinitis with Chronic Maxillary Sinusitis', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vit_vis_pat_020', 'vis_pat_020', 158, 97, 81, 98.4, 98.0, 18, 165.0, 64.0, 23.5, 'usr_rec_1', '2026-10-15T10:30:00', 'Triage assessment for Executive Annual Health Evaluation & Routine Screen', '2026-10-15T10:30:00', '2026-10-15T10:30:00')
ON CONFLICT (id) DO UPDATE SET visit_id = EXCLUDED.visit_id, systolic_bp = EXCLUDED.systolic_bp, diastolic_bp = EXCLUDED.diastolic_bp, pulse_rate = EXCLUDED.pulse_rate, temperature_f = EXCLUDED.temperature_f, spo2_percent = EXCLUDED.spo2_percent, respiratory_rate = EXCLUDED.respiratory_rate, height_cm = EXCLUDED.height_cm, weight_kg = EXCLUDED.weight_kg, bmi = EXCLUDED.bmi, recorded_by_user_id = EXCLUDED.recorded_by_user_id, recorded_at = EXCLUDED.recorded_at, notes = EXCLUDED.notes, created_at = EXCLUDED.created_at, updated_at = EXCLUDED.updated_at;

-- Data: clinical_records (20 records)
INSERT INTO clinical_records (id, visit_id, patient_id, doctor_id, presenting_complaint, history_of_present_illness, general_examination, provisional_diagnosis, final_diagnosis, icd10_code, care_plan, follow_up_date, status, version, created_by_user_id, created_at, updated_at) VALUES
  ('cr_vis_pat_001', 'vis_pat_001', 'pat_001', 'doc_med_1', 'Presents with symptoms of Type 2 Diabetes Mellitus with Peripheral Neuropathy', 'Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. Type 2 Diabetes Mellitus with Peripheral Neuropathy', 'Vitals: BP 120/78, Pulse 74 bpm, SpO2 98.0%.', 'Type 2 Diabetes Mellitus with Peripheral Neuropathy', 'Type 2 Diabetes Mellitus with Peripheral Neuropathy', 'E11.9', 'Initiate medical management for Type 2 Diabetes Mellitus with Peripheral Neuropathy. Review in OPD in 14 days with investigation results.', '2026-10-29', 'COMPLETED', 1, 'usr_doc_med_1', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('cr_vis_pat_002', 'vis_pat_002', 'pat_002', 'doc_ortho_1', 'Presents with symptoms of Acute Lumbar Muscle Sprain & Sciatica', 'Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. Acute Lumbar Muscle Sprain & Sciatica', 'Vitals: BP 122/79, Pulse 77 bpm, SpO2 98.0%.', 'Acute Lumbar Muscle Sprain & Sciatica', 'Acute Lumbar Muscle Sprain & Sciatica', 'M54.5', 'Initiate medical management for Acute Lumbar Muscle Sprain & Sciatica. Review in OPD in 14 days with investigation results.', '2026-10-29', 'COMPLETED', 1, 'usr_doc_ortho_1', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('cr_vis_pat_003', 'vis_pat_003', 'pat_003', 'doc_cardio_1', 'Presents with symptoms of Essential Hypertension & CAD (Post-PTCA Follow-up)', 'Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. Essential Hypertension & CAD (Post-PTCA Follow-up)', 'Vitals: BP 124/80, Pulse 80 bpm, SpO2 98.0%.', 'Essential Hypertension & CAD (Post-PTCA Follow-up)', 'Essential Hypertension & CAD (Post-PTCA Follow-up)', 'I25.1', 'Initiate medical management for Essential Hypertension & CAD (Post-PTCA Follow-up). Review in OPD in 14 days with investigation results.', '2026-10-29', 'COMPLETED', 1, 'usr_doc_cardio_1', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('cr_vis_pat_004', 'vis_pat_004', 'pat_004', 'doc_med_2', 'Presents with symptoms of Antenatal Care 26 Weeks Gestation with Mild Anemia', 'Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. Antenatal Care 26 Weeks Gestation with Mild Anemia', 'Vitals: BP 126/81, Pulse 83 bpm, SpO2 98.0%.', 'Antenatal Care 26 Weeks Gestation with Mild Anemia', 'Antenatal Care 26 Weeks Gestation with Mild Anemia', 'R69', 'Initiate medical management for Antenatal Care 26 Weeks Gestation with Mild Anemia. Review in OPD in 14 days with investigation results.', '2026-10-29', 'COMPLETED', 1, 'usr_doc_med_2', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('cr_vis_pat_005', 'vis_pat_005', 'pat_005', 'doc_ped_1', 'Presents with symptoms of Pediatric Bronchial Asthma with Acute Wheezing', 'Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. Pediatric Bronchial Asthma with Acute Wheezing', 'Vitals: BP 128/82, Pulse 86 bpm, SpO2 94.0%.', 'Pediatric Bronchial Asthma with Acute Wheezing', 'Pediatric Bronchial Asthma with Acute Wheezing', 'R69', 'Initiate medical management for Pediatric Bronchial Asthma with Acute Wheezing. Review in OPD in 14 days with investigation results.', '2026-10-29', 'COMPLETED', 1, 'usr_doc_ped_1', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('cr_vis_pat_006', 'vis_pat_006', 'pat_006', 'doc_ortho_2', 'Presents with symptoms of Bilateral Knee Osteoarthritis Grade III', 'Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. Bilateral Knee Osteoarthritis Grade III', 'Vitals: BP 130/83, Pulse 89 bpm, SpO2 98.0%.', 'Bilateral Knee Osteoarthritis Grade III', 'Bilateral Knee Osteoarthritis Grade III', 'R69', 'Initiate medical management for Bilateral Knee Osteoarthritis Grade III. Review in OPD in 14 days with investigation results.', '2026-10-29', 'COMPLETED', 1, 'usr_doc_ortho_2', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('cr_vis_pat_007', 'vis_pat_007', 'pat_007', 'doc_med_3', 'Presents with symptoms of Acute Febrile Illness - Suspected Dengue Fever', 'Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. Acute Febrile Illness - Suspected Dengue Fever', 'Vitals: BP 132/84, Pulse 92 bpm, SpO2 98.0%.', 'Acute Febrile Illness - Suspected Dengue Fever', 'Acute Febrile Illness - Suspected Dengue Fever', 'R69', 'Initiate medical management for Acute Febrile Illness - Suspected Dengue Fever. Review in OPD in 14 days with investigation results.', '2026-10-29', 'COMPLETED', 1, 'usr_doc_med_3', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('cr_vis_pat_008', 'vis_pat_008', 'pat_008', 'doc_ped_2', 'Presents with symptoms of Acute Otitis Media & Upper Respiratory Infection', 'Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. Acute Otitis Media & Upper Respiratory Infection', 'Vitals: BP 134/85, Pulse 95 bpm, SpO2 98.0%.', 'Acute Otitis Media & Upper Respiratory Infection', 'Acute Otitis Media & Upper Respiratory Infection', 'R69', 'Initiate medical management for Acute Otitis Media & Upper Respiratory Infection. Review in OPD in 14 days with investigation results.', '2026-10-29', 'COMPLETED', 1, 'usr_doc_ped_2', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('cr_vis_pat_009', 'vis_pat_009', 'pat_009', 'doc_med_1', 'Presents with symptoms of Chronic Obstructive Pulmonary Disease (COPD) Grade II', 'Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. Chronic Obstructive Pulmonary Disease (COPD) Grade II', 'Vitals: BP 136/86, Pulse 98 bpm, SpO2 94.0%.', 'Chronic Obstructive Pulmonary Disease (COPD) Grade II', 'Chronic Obstructive Pulmonary Disease (COPD) Grade II', 'R69', 'Initiate medical management for Chronic Obstructive Pulmonary Disease (COPD) Grade II. Review in OPD in 14 days with investigation results.', '2026-10-29', 'COMPLETED', 1, 'usr_doc_med_1', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('cr_vis_pat_010', 'vis_pat_010', 'pat_010', 'doc_med_2', 'Presents with symptoms of Hypothyroidism with Dyslipidemia & Weight Gain', 'Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. Hypothyroidism with Dyslipidemia & Weight Gain', 'Vitals: BP 138/87, Pulse 76 bpm, SpO2 98.0%.', 'Hypothyroidism with Dyslipidemia & Weight Gain', 'Hypothyroidism with Dyslipidemia & Weight Gain', 'R69', 'Initiate medical management for Hypothyroidism with Dyslipidemia & Weight Gain. Review in OPD in 14 days with investigation results.', '2026-10-29', 'COMPLETED', 1, 'usr_doc_med_2', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('cr_vis_pat_011', 'vis_pat_011', 'pat_011', 'doc_med_3', 'Presents with symptoms of Acute Left Ureteric Calculus with Severe Renal Colic', 'Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. Acute Left Ureteric Calculus with Severe Renal Colic', 'Vitals: BP 140/88, Pulse 79 bpm, SpO2 98.0%.', 'Acute Left Ureteric Calculus with Severe Renal Colic', 'Acute Left Ureteric Calculus with Severe Renal Colic', 'R69', 'Initiate medical management for Acute Left Ureteric Calculus with Severe Renal Colic. Review in OPD in 14 days with investigation results.', '2026-10-29', 'COMPLETED', 1, 'usr_doc_med_3', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('cr_vis_pat_012', 'vis_pat_012', 'pat_012', 'doc_med_1', 'Presents with symptoms of Chronic Kidney Disease Stage 3b & Diabetic Nephropathy', 'Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. Chronic Kidney Disease Stage 3b & Diabetic Nephropathy', 'Vitals: BP 142/89, Pulse 82 bpm, SpO2 98.0%.', 'Chronic Kidney Disease Stage 3b & Diabetic Nephropathy', 'Chronic Kidney Disease Stage 3b & Diabetic Nephropathy', 'R69', 'Initiate medical management for Chronic Kidney Disease Stage 3b & Diabetic Nephropathy. Review in OPD in 14 days with investigation results.', '2026-10-29', 'COMPLETED', 1, 'usr_doc_med_1', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('cr_vis_pat_013', 'vis_pat_013', 'pat_013', 'doc_ortho_3', 'Presents with symptoms of Right Ankle Inversion Injury / Lateral Ligament Sprain', 'Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. Right Ankle Inversion Injury / Lateral Ligament Sprain', 'Vitals: BP 144/90, Pulse 85 bpm, SpO2 98.0%.', 'Right Ankle Inversion Injury / Lateral Ligament Sprain', 'Right Ankle Inversion Injury / Lateral Ligament Sprain', 'M54.5', 'Initiate medical management for Right Ankle Inversion Injury / Lateral Ligament Sprain. Review in OPD in 14 days with investigation results.', '2026-10-29', 'COMPLETED', 1, 'usr_doc_ortho_3', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('cr_vis_pat_014', 'vis_pat_014', 'pat_014', 'doc_med_2', 'Presents with symptoms of Chronic Migraine with Visual Aura & Photophobia', 'Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. Chronic Migraine with Visual Aura & Photophobia', 'Vitals: BP 146/91, Pulse 88 bpm, SpO2 98.0%.', 'Chronic Migraine with Visual Aura & Photophobia', 'Chronic Migraine with Visual Aura & Photophobia', 'R69', 'Initiate medical management for Chronic Migraine with Visual Aura & Photophobia. Review in OPD in 14 days with investigation results.', '2026-10-29', 'COMPLETED', 1, 'usr_doc_med_2', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('cr_vis_pat_015', 'vis_pat_015', 'pat_015', 'doc_med_3', 'Presents with symptoms of Gastroesophageal Reflux Disease (GERD) & Erosive Gastritis', 'Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. Gastroesophageal Reflux Disease (GERD) & Erosive Gastritis', 'Vitals: BP 148/92, Pulse 91 bpm, SpO2 98.0%.', 'Gastroesophageal Reflux Disease (GERD) & Erosive Gastritis', 'Gastroesophageal Reflux Disease (GERD) & Erosive Gastritis', 'R69', 'Initiate medical management for Gastroesophageal Reflux Disease (GERD) & Erosive Gastritis. Review in OPD in 14 days with investigation results.', '2026-10-29', 'COMPLETED', 1, 'usr_doc_med_3', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('cr_vis_pat_016', 'vis_pat_016', 'pat_016', 'doc_med_1', 'Presents with symptoms of Severe Iron Deficiency Anemia (Hb 7.8 g/dL)', 'Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. Severe Iron Deficiency Anemia (Hb 7.8 g/dL)', 'Vitals: BP 150/93, Pulse 94 bpm, SpO2 98.0%.', 'Severe Iron Deficiency Anemia (Hb 7.8 g/dL)', 'Severe Iron Deficiency Anemia (Hb 7.8 g/dL)', 'R69', 'Initiate medical management for Severe Iron Deficiency Anemia (Hb 7.8 g/dL). Review in OPD in 14 days with investigation results.', '2026-10-29', 'COMPLETED', 1, 'usr_doc_med_1', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('cr_vis_pat_017', 'vis_pat_017', 'pat_017', 'doc_dent_1', 'Presents with symptoms of Severe Acute Pulpitis & Mandibular 1st Molar Abscess', 'Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. Severe Acute Pulpitis & Mandibular 1st Molar Abscess', 'Vitals: BP 152/94, Pulse 97 bpm, SpO2 98.0%.', 'Severe Acute Pulpitis & Mandibular 1st Molar Abscess', 'Severe Acute Pulpitis & Mandibular 1st Molar Abscess', 'R69', 'Initiate medical management for Severe Acute Pulpitis & Mandibular 1st Molar Abscess. Review in OPD in 14 days with investigation results.', '2026-10-29', 'COMPLETED', 1, 'usr_doc_dent_1', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('cr_vis_pat_018', 'vis_pat_018', 'pat_018', 'doc_med_2', 'Presents with symptoms of Chronic Allergic Contact Dermatitis & Numular Eczema', 'Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. Chronic Allergic Contact Dermatitis & Numular Eczema', 'Vitals: BP 154/95, Pulse 75 bpm, SpO2 98.0%.', 'Chronic Allergic Contact Dermatitis & Numular Eczema', 'Chronic Allergic Contact Dermatitis & Numular Eczema', 'R69', 'Initiate medical management for Chronic Allergic Contact Dermatitis & Numular Eczema. Review in OPD in 14 days with investigation results.', '2026-10-29', 'COMPLETED', 1, 'usr_doc_med_2', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('cr_vis_pat_019', 'vis_pat_019', 'pat_019', 'doc_ent_1', 'Presents with symptoms of Allergic Rhinitis with Chronic Maxillary Sinusitis', 'Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. Allergic Rhinitis with Chronic Maxillary Sinusitis', 'Vitals: BP 156/96, Pulse 78 bpm, SpO2 98.0%.', 'Allergic Rhinitis with Chronic Maxillary Sinusitis', 'Allergic Rhinitis with Chronic Maxillary Sinusitis', 'R69', 'Initiate medical management for Allergic Rhinitis with Chronic Maxillary Sinusitis. Review in OPD in 14 days with investigation results.', '2026-10-29', 'COMPLETED', 1, 'usr_doc_ent_1', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('cr_vis_pat_020', 'vis_pat_020', 'pat_020', 'doc_med_3', 'Presents with symptoms of Executive Annual Health Evaluation & Routine Screen', 'Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. Executive Annual Health Evaluation & Routine Screen', 'Vitals: BP 158/97, Pulse 81 bpm, SpO2 98.0%.', 'Executive Annual Health Evaluation & Routine Screen', 'Executive Annual Health Evaluation & Routine Screen', 'R69', 'Initiate medical management for Executive Annual Health Evaluation & Routine Screen. Review in OPD in 14 days with investigation results.', '2026-10-29', 'COMPLETED', 1, 'usr_doc_med_3', '2026-10-15T10:30:00', '2026-10-15T10:30:00')
ON CONFLICT (id) DO UPDATE SET visit_id = EXCLUDED.visit_id, patient_id = EXCLUDED.patient_id, doctor_id = EXCLUDED.doctor_id, presenting_complaint = EXCLUDED.presenting_complaint, history_of_present_illness = EXCLUDED.history_of_present_illness, general_examination = EXCLUDED.general_examination, provisional_diagnosis = EXCLUDED.provisional_diagnosis, final_diagnosis = EXCLUDED.final_diagnosis, icd10_code = EXCLUDED.icd10_code, care_plan = EXCLUDED.care_plan, follow_up_date = EXCLUDED.follow_up_date, status = EXCLUDED.status, version = EXCLUDED.version, created_by_user_id = EXCLUDED.created_by_user_id, created_at = EXCLUDED.created_at, updated_at = EXCLUDED.updated_at;

-- Data: prescriptions (20 records)
INSERT INTO prescriptions (id, visit_id, patient_id, doctor_id, status, version, notes, is_ocr_extracted, is_verified_by_clinician, allergy_warning_acknowledged, created_at, updated_at) VALUES
  ('rx_vis_pat_001', 'vis_pat_001', 'pat_001', 'doc_med_1', 'ACTIVE', 1, 'Take medications strictly after food. Drink plenty of water.', FALSE, TRUE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rx_vis_pat_002', 'vis_pat_002', 'pat_002', 'doc_ortho_1', 'ACTIVE', 1, 'Take medications strictly after food. Drink plenty of water.', FALSE, TRUE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rx_vis_pat_003', 'vis_pat_003', 'pat_003', 'doc_cardio_1', 'ACTIVE', 1, 'Take medications strictly after food. Drink plenty of water.', FALSE, TRUE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rx_vis_pat_004', 'vis_pat_004', 'pat_004', 'doc_med_2', 'ACTIVE', 1, 'Take medications strictly after food. Drink plenty of water.', FALSE, TRUE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rx_vis_pat_005', 'vis_pat_005', 'pat_005', 'doc_ped_1', 'ACTIVE', 1, 'Take medications strictly after food. Drink plenty of water.', FALSE, TRUE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rx_vis_pat_006', 'vis_pat_006', 'pat_006', 'doc_ortho_2', 'ACTIVE', 1, 'Take medications strictly after food. Drink plenty of water.', FALSE, TRUE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rx_vis_pat_007', 'vis_pat_007', 'pat_007', 'doc_med_3', 'ACTIVE', 1, 'Take medications strictly after food. Drink plenty of water.', FALSE, TRUE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rx_vis_pat_008', 'vis_pat_008', 'pat_008', 'doc_ped_2', 'ACTIVE', 1, 'Take medications strictly after food. Drink plenty of water.', FALSE, TRUE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rx_vis_pat_009', 'vis_pat_009', 'pat_009', 'doc_med_1', 'ACTIVE', 1, 'Take medications strictly after food. Drink plenty of water.', FALSE, TRUE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rx_vis_pat_010', 'vis_pat_010', 'pat_010', 'doc_med_2', 'COMPLETED', 1, 'Take medications strictly after food. Drink plenty of water.', FALSE, TRUE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rx_vis_pat_011', 'vis_pat_011', 'pat_011', 'doc_med_3', 'ACTIVE', 1, 'Take medications strictly after food. Drink plenty of water.', FALSE, TRUE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rx_vis_pat_012', 'vis_pat_012', 'pat_012', 'doc_med_1', 'ACTIVE', 1, 'Take medications strictly after food. Drink plenty of water.', FALSE, TRUE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rx_vis_pat_013', 'vis_pat_013', 'pat_013', 'doc_ortho_3', 'ACTIVE', 1, 'Take medications strictly after food. Drink plenty of water.', FALSE, TRUE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rx_vis_pat_014', 'vis_pat_014', 'pat_014', 'doc_med_2', 'ACTIVE', 1, 'Take medications strictly after food. Drink plenty of water.', FALSE, TRUE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rx_vis_pat_015', 'vis_pat_015', 'pat_015', 'doc_med_3', 'COMPLETED', 1, 'Take medications strictly after food. Drink plenty of water.', FALSE, TRUE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rx_vis_pat_016', 'vis_pat_016', 'pat_016', 'doc_med_1', 'ACTIVE', 1, 'Take medications strictly after food. Drink plenty of water.', FALSE, TRUE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rx_vis_pat_017', 'vis_pat_017', 'pat_017', 'doc_dent_1', 'ACTIVE', 1, 'Take medications strictly after food. Drink plenty of water.', FALSE, TRUE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rx_vis_pat_018', 'vis_pat_018', 'pat_018', 'doc_med_2', 'COMPLETED', 1, 'Take medications strictly after food. Drink plenty of water.', FALSE, TRUE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rx_vis_pat_019', 'vis_pat_019', 'pat_019', 'doc_ent_1', 'ACTIVE', 1, 'Take medications strictly after food. Drink plenty of water.', FALSE, TRUE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rx_vis_pat_020', 'vis_pat_020', 'pat_020', 'doc_med_3', 'COMPLETED', 1, 'Take medications strictly after food. Drink plenty of water.', FALSE, TRUE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00')
ON CONFLICT (id) DO UPDATE SET visit_id = EXCLUDED.visit_id, patient_id = EXCLUDED.patient_id, doctor_id = EXCLUDED.doctor_id, status = EXCLUDED.status, version = EXCLUDED.version, notes = EXCLUDED.notes, is_ocr_extracted = EXCLUDED.is_ocr_extracted, is_verified_by_clinician = EXCLUDED.is_verified_by_clinician, allergy_warning_acknowledged = EXCLUDED.allergy_warning_acknowledged, created_at = EXCLUDED.created_at, updated_at = EXCLUDED.updated_at;

-- Data: prescription_items (40 records)
INSERT INTO prescription_items (id, prescription_id, medicine_name, form, dosage, route, frequency, duration_days, timing, instructions, is_dispensed, created_at, updated_at) VALUES
  ('rxi_vis_pat_001_1', 'rx_vis_pat_001', 'Metformin 500mg', 'Tablet', '500mg', 'ORAL', 'BD', 30, 'AFTER_FOOD', 'Take after meals with warm water', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_001_2', 'rx_vis_pat_001', 'Pantoprazole 40mg', 'Tablet', '40mg', 'ORAL', 'OD', 14, 'BEFORE_FOOD', 'Take morning empty stomach 30 mins before breakfast', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_002_1', 'rx_vis_pat_002', 'Metformin 500mg', 'Tablet', '500mg', 'ORAL', 'BD', 5, 'AFTER_FOOD', 'Take after meals with warm water', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_002_2', 'rx_vis_pat_002', 'Pantoprazole 40mg', 'Tablet', '40mg', 'ORAL', 'OD', 14, 'BEFORE_FOOD', 'Take morning empty stomach 30 mins before breakfast', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_003_1', 'rx_vis_pat_003', 'Metformin 500mg', 'Tablet', '500mg', 'ORAL', 'BD', 30, 'AFTER_FOOD', 'Take after meals with warm water', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_003_2', 'rx_vis_pat_003', 'Pantoprazole 40mg', 'Tablet', '40mg', 'ORAL', 'OD', 14, 'BEFORE_FOOD', 'Take morning empty stomach 30 mins before breakfast', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_004_1', 'rx_vis_pat_004', 'Metformin 500mg', 'Tablet', '500mg', 'ORAL', 'BD', 30, 'AFTER_FOOD', 'Take after meals with warm water', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_004_2', 'rx_vis_pat_004', 'Pantoprazole 40mg', 'Tablet', '40mg', 'ORAL', 'OD', 14, 'BEFORE_FOOD', 'Take morning empty stomach 30 mins before breakfast', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_005_1', 'rx_vis_pat_005', 'Metformin 500mg', 'Tablet', '500mg', 'ORAL', 'BD', 5, 'AFTER_FOOD', 'Take after meals with warm water', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_005_2', 'rx_vis_pat_005', 'Pantoprazole 40mg', 'Tablet', '40mg', 'ORAL', 'OD', 14, 'BEFORE_FOOD', 'Take morning empty stomach 30 mins before breakfast', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_006_1', 'rx_vis_pat_006', 'Metformin 500mg', 'Tablet', '500mg', 'ORAL', 'BD', 30, 'AFTER_FOOD', 'Take after meals with warm water', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_006_2', 'rx_vis_pat_006', 'Pantoprazole 40mg', 'Tablet', '40mg', 'ORAL', 'OD', 14, 'BEFORE_FOOD', 'Take morning empty stomach 30 mins before breakfast', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_007_1', 'rx_vis_pat_007', 'Paracetamol 650mg', 'Tablet', '650mg', 'ORAL', 'TID', 5, 'AFTER_FOOD', 'Take after meals with warm water', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_007_2', 'rx_vis_pat_007', 'Pantoprazole 40mg', 'Tablet', '40mg', 'ORAL', 'OD', 14, 'BEFORE_FOOD', 'Take morning empty stomach 30 mins before breakfast', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_008_1', 'rx_vis_pat_008', 'Metformin 500mg', 'Tablet', '500mg', 'ORAL', 'BD', 5, 'AFTER_FOOD', 'Take after meals with warm water', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_008_2', 'rx_vis_pat_008', 'Pantoprazole 40mg', 'Tablet', '40mg', 'ORAL', 'OD', 14, 'BEFORE_FOOD', 'Take morning empty stomach 30 mins before breakfast', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_009_1', 'rx_vis_pat_009', 'Metformin 500mg', 'Tablet', '500mg', 'ORAL', 'BD', 30, 'AFTER_FOOD', 'Take after meals with warm water', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_009_2', 'rx_vis_pat_009', 'Pantoprazole 40mg', 'Tablet', '40mg', 'ORAL', 'OD', 14, 'BEFORE_FOOD', 'Take morning empty stomach 30 mins before breakfast', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_010_1', 'rx_vis_pat_010', 'Metformin 500mg', 'Tablet', '500mg', 'ORAL', 'BD', 30, 'AFTER_FOOD', 'Take after meals with warm water', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_010_2', 'rx_vis_pat_010', 'Pantoprazole 40mg', 'Tablet', '40mg', 'ORAL', 'OD', 14, 'BEFORE_FOOD', 'Take morning empty stomach 30 mins before breakfast', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_011_1', 'rx_vis_pat_011', 'Metformin 500mg', 'Tablet', '500mg', 'ORAL', 'BD', 5, 'AFTER_FOOD', 'Take after meals with warm water', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_011_2', 'rx_vis_pat_011', 'Pantoprazole 40mg', 'Tablet', '40mg', 'ORAL', 'OD', 14, 'BEFORE_FOOD', 'Take morning empty stomach 30 mins before breakfast', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_012_1', 'rx_vis_pat_012', 'Metformin 500mg', 'Tablet', '500mg', 'ORAL', 'BD', 30, 'AFTER_FOOD', 'Take after meals with warm water', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_012_2', 'rx_vis_pat_012', 'Pantoprazole 40mg', 'Tablet', '40mg', 'ORAL', 'OD', 14, 'BEFORE_FOOD', 'Take morning empty stomach 30 mins before breakfast', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_013_1', 'rx_vis_pat_013', 'Metformin 500mg', 'Tablet', '500mg', 'ORAL', 'BD', 30, 'AFTER_FOOD', 'Take after meals with warm water', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_013_2', 'rx_vis_pat_013', 'Pantoprazole 40mg', 'Tablet', '40mg', 'ORAL', 'OD', 14, 'BEFORE_FOOD', 'Take morning empty stomach 30 mins before breakfast', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_014_1', 'rx_vis_pat_014', 'Metformin 500mg', 'Tablet', '500mg', 'ORAL', 'BD', 30, 'AFTER_FOOD', 'Take after meals with warm water', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_014_2', 'rx_vis_pat_014', 'Pantoprazole 40mg', 'Tablet', '40mg', 'ORAL', 'OD', 14, 'BEFORE_FOOD', 'Take morning empty stomach 30 mins before breakfast', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_015_1', 'rx_vis_pat_015', 'Metformin 500mg', 'Tablet', '500mg', 'ORAL', 'BD', 30, 'AFTER_FOOD', 'Take after meals with warm water', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_015_2', 'rx_vis_pat_015', 'Pantoprazole 40mg', 'Tablet', '40mg', 'ORAL', 'OD', 14, 'BEFORE_FOOD', 'Take morning empty stomach 30 mins before breakfast', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_016_1', 'rx_vis_pat_016', 'Metformin 500mg', 'Tablet', '500mg', 'ORAL', 'BD', 30, 'AFTER_FOOD', 'Take after meals with warm water', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_016_2', 'rx_vis_pat_016', 'Pantoprazole 40mg', 'Tablet', '40mg', 'ORAL', 'OD', 14, 'BEFORE_FOOD', 'Take morning empty stomach 30 mins before breakfast', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_017_1', 'rx_vis_pat_017', 'Metformin 500mg', 'Tablet', '500mg', 'ORAL', 'BD', 5, 'AFTER_FOOD', 'Take after meals with warm water', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_017_2', 'rx_vis_pat_017', 'Pantoprazole 40mg', 'Tablet', '40mg', 'ORAL', 'OD', 14, 'BEFORE_FOOD', 'Take morning empty stomach 30 mins before breakfast', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_018_1', 'rx_vis_pat_018', 'Metformin 500mg', 'Tablet', '500mg', 'ORAL', 'BD', 30, 'AFTER_FOOD', 'Take after meals with warm water', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_018_2', 'rx_vis_pat_018', 'Pantoprazole 40mg', 'Tablet', '40mg', 'ORAL', 'OD', 14, 'BEFORE_FOOD', 'Take morning empty stomach 30 mins before breakfast', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_019_1', 'rx_vis_pat_019', 'Metformin 500mg', 'Tablet', '500mg', 'ORAL', 'BD', 30, 'AFTER_FOOD', 'Take after meals with warm water', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_019_2', 'rx_vis_pat_019', 'Pantoprazole 40mg', 'Tablet', '40mg', 'ORAL', 'OD', 14, 'BEFORE_FOOD', 'Take morning empty stomach 30 mins before breakfast', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_020_1', 'rx_vis_pat_020', 'Metformin 500mg', 'Tablet', '500mg', 'ORAL', 'BD', 30, 'AFTER_FOOD', 'Take after meals with warm water', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_020_2', 'rx_vis_pat_020', 'Pantoprazole 40mg', 'Tablet', '40mg', 'ORAL', 'OD', 14, 'BEFORE_FOOD', 'Take morning empty stomach 30 mins before breakfast', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00')
ON CONFLICT (id) DO UPDATE SET prescription_id = EXCLUDED.prescription_id, medicine_name = EXCLUDED.medicine_name, form = EXCLUDED.form, dosage = EXCLUDED.dosage, route = EXCLUDED.route, frequency = EXCLUDED.frequency, duration_days = EXCLUDED.duration_days, timing = EXCLUDED.timing, instructions = EXCLUDED.instructions, is_dispensed = EXCLUDED.is_dispensed, created_at = EXCLUDED.created_at, updated_at = EXCLUDED.updated_at;

-- Data: lab_orders (10 records)
INSERT INTO lab_orders (id, order_number, visit_id, patient_id, ordered_by_doctor_id, test_name, test_category, status, clinical_indication, specimen_status, is_sensitive, requires_review, published_to_visit, ordered_at, created_at, updated_at) VALUES
  ('lo_vis_pat_001', 'LAB-20261015-001', 'vis_pat_001', 'pat_001', 'doc_med_1', 'Complete Blood Count (CBC)', 'HEMATOLOGY', 'COMPLETED', 'Diagnostic evaluation for Type 2 Diabetes Mellitus with Peripheral Neuropathy', 'COLLECTED', FALSE, FALSE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('lo_vis_pat_002', 'LAB-20261015-002', 'vis_pat_002', 'pat_002', 'doc_ortho_1', 'HbA1c & Fasting Lipid Profile', 'BIOCHEMISTRY', 'COMPLETED', 'Diagnostic evaluation for Acute Lumbar Muscle Sprain & Sciatica', 'COLLECTED', FALSE, FALSE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('lo_vis_pat_003', 'LAB-20261015-003', 'vis_pat_003', 'pat_003', 'doc_cardio_1', 'Complete Blood Count (CBC)', 'HEMATOLOGY', 'COMPLETED', 'Diagnostic evaluation for Essential Hypertension & CAD (Post-PTCA Follow-up)', 'COLLECTED', FALSE, FALSE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('lo_vis_pat_004', 'LAB-20261015-004', 'vis_pat_004', 'pat_004', 'doc_med_2', 'HbA1c & Fasting Lipid Profile', 'BIOCHEMISTRY', 'COMPLETED', 'Diagnostic evaluation for Antenatal Care 26 Weeks Gestation with Mild Anemia', 'COLLECTED', FALSE, FALSE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('lo_vis_pat_005', 'LAB-20261015-005', 'vis_pat_005', 'pat_005', 'doc_ped_1', 'Complete Blood Count (CBC)', 'HEMATOLOGY', 'COMPLETED', 'Diagnostic evaluation for Pediatric Bronchial Asthma with Acute Wheezing', 'COLLECTED', FALSE, FALSE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('lo_vis_pat_006', 'LAB-20261015-006', 'vis_pat_006', 'pat_006', 'doc_ortho_2', 'HbA1c & Fasting Lipid Profile', 'BIOCHEMISTRY', 'ORDERED', 'Diagnostic evaluation for Bilateral Knee Osteoarthritis Grade III', 'COLLECTED', FALSE, FALSE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('lo_vis_pat_007', 'LAB-20261015-007', 'vis_pat_007', 'pat_007', 'doc_med_3', 'Complete Blood Count (CBC)', 'HEMATOLOGY', 'ORDERED', 'Diagnostic evaluation for Acute Febrile Illness - Suspected Dengue Fever', 'COLLECTED', FALSE, FALSE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('lo_vis_pat_008', 'LAB-20261015-008', 'vis_pat_008', 'pat_008', 'doc_ped_2', 'HbA1c & Fasting Lipid Profile', 'BIOCHEMISTRY', 'ORDERED', 'Diagnostic evaluation for Acute Otitis Media & Upper Respiratory Infection', 'COLLECTED', FALSE, FALSE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('lo_vis_pat_009', 'LAB-20261015-009', 'vis_pat_009', 'pat_009', 'doc_med_1', 'Complete Blood Count (CBC)', 'HEMATOLOGY', 'ORDERED', 'Diagnostic evaluation for Chronic Obstructive Pulmonary Disease (COPD) Grade II', 'COLLECTED', FALSE, FALSE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('lo_vis_pat_010', 'LAB-20261015-010', 'vis_pat_010', 'pat_010', 'doc_med_2', 'HbA1c & Fasting Lipid Profile', 'BIOCHEMISTRY', 'ORDERED', 'Diagnostic evaluation for Hypothyroidism with Dyslipidemia & Weight Gain', 'COLLECTED', FALSE, FALSE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00', '2026-10-15T10:30:00')
ON CONFLICT (id) DO UPDATE SET order_number = EXCLUDED.order_number, visit_id = EXCLUDED.visit_id, patient_id = EXCLUDED.patient_id, ordered_by_doctor_id = EXCLUDED.ordered_by_doctor_id, test_name = EXCLUDED.test_name, test_category = EXCLUDED.test_category, status = EXCLUDED.status, clinical_indication = EXCLUDED.clinical_indication, specimen_status = EXCLUDED.specimen_status, is_sensitive = EXCLUDED.is_sensitive, requires_review = EXCLUDED.requires_review, published_to_visit = EXCLUDED.published_to_visit, ordered_at = EXCLUDED.ordered_at, created_at = EXCLUDED.created_at, updated_at = EXCLUDED.updated_at;

-- Data: lab_results (5 records)
INSERT INTO lab_results (id, lab_order_id, parameter_name, result_value, unit, reference_range, is_abnormal, is_critical, flag, notes, reported_at, verified_by_user_id, verified_at, created_at, updated_at) VALUES
  ('lr_lo_vis_pat_001', 'lo_vis_pat_001', 'Hemoglobin (Hb)', '12.8', 'g/dL', '11.5 - 16.0 g/dL', FALSE, FALSE, 'NORMAL', 'Verified by Clinical Pathology Lab', '2026-10-15T10:30:00', 'usr_lab_1', '2026-10-15T10:30:00', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('lr_lo_vis_pat_002', 'lo_vis_pat_002', 'Glycated Hemoglobin (HbA1c)', '7.4', '%', '< 5.7% Normal', TRUE, FALSE, 'HIGH', 'Verified by Clinical Pathology Lab', '2026-10-15T10:30:00', 'usr_lab_1', '2026-10-15T10:30:00', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('lr_lo_vis_pat_003', 'lo_vis_pat_003', 'Hemoglobin (Hb)', '12.8', 'g/dL', '11.5 - 16.0 g/dL', FALSE, FALSE, 'NORMAL', 'Verified by Clinical Pathology Lab', '2026-10-15T10:30:00', 'usr_lab_1', '2026-10-15T10:30:00', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('lr_lo_vis_pat_004', 'lo_vis_pat_004', 'Glycated Hemoglobin (HbA1c)', '7.4', '%', '< 5.7% Normal', TRUE, FALSE, 'HIGH', 'Verified by Clinical Pathology Lab', '2026-10-15T10:30:00', 'usr_lab_1', '2026-10-15T10:30:00', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('lr_lo_vis_pat_005', 'lo_vis_pat_005', 'Hemoglobin (Hb)', '12.8', 'g/dL', '11.5 - 16.0 g/dL', FALSE, FALSE, 'NORMAL', 'Verified by Clinical Pathology Lab', '2026-10-15T10:30:00', 'usr_lab_1', '2026-10-15T10:30:00', '2026-10-15T10:30:00', '2026-10-15T10:30:00')
ON CONFLICT (id) DO UPDATE SET lab_order_id = EXCLUDED.lab_order_id, parameter_name = EXCLUDED.parameter_name, result_value = EXCLUDED.result_value, unit = EXCLUDED.unit, reference_range = EXCLUDED.reference_range, is_abnormal = EXCLUDED.is_abnormal, is_critical = EXCLUDED.is_critical, flag = EXCLUDED.flag, notes = EXCLUDED.notes, reported_at = EXCLUDED.reported_at, verified_by_user_id = EXCLUDED.verified_by_user_id, verified_at = EXCLUDED.verified_at, created_at = EXCLUDED.created_at, updated_at = EXCLUDED.updated_at;

-- Data: bills (20 records)
INSERT INTO bills (id, visit_id, patient_id, invoice_number, subtotal, discount_type, discount_rate, discount_amount, taxable_amount, cgst_amount, sgst_amount, igst_amount, total_tax_amount, total_amount, net_amount, paid_amount, outstanding_balance, status, payment_status, payment_method, billed_by_user_id, billed_at, is_synthetic_pricing, created_at, updated_at) VALUES
  ('bill_vis_pat_001', 'vis_pat_001', 'pat_001', 'INV-20261015-0001', 500.0, 'NONE', 0.0, 0.0, 500.0, 0.0, 0.0, 0.0, 0.0, 500.0, 500.0, 500.0, 0.0, 'PAID', 'PAID', 'CASH', 'usr_bill_1', '2026-10-15T10:30:00', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('bill_vis_pat_002', 'vis_pat_002', 'pat_002', 'INV-20261015-0002', 750.0, 'NONE', 0.0, 0.0, 750.0, 0.0, 0.0, 0.0, 0.0, 750.0, 750.0, 750.0, 0.0, 'PAID', 'PAID', 'CASH', 'usr_bill_1', '2026-10-15T10:30:00', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('bill_vis_pat_003', 'vis_pat_003', 'pat_003', 'INV-20261015-0003', 750.0, 'NONE', 0.0, 0.0, 750.0, 0.0, 0.0, 0.0, 0.0, 750.0, 750.0, 750.0, 0.0, 'PAID', 'PAID', 'CASH', 'usr_bill_1', '2026-10-15T10:30:00', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('bill_vis_pat_004', 'vis_pat_004', 'pat_004', 'INV-20261015-0004', 500.0, 'NONE', 0.0, 0.0, 500.0, 0.0, 0.0, 0.0, 0.0, 500.0, 500.0, 500.0, 0.0, 'PAID', 'PAID', 'CASH', 'usr_bill_1', '2026-10-15T10:30:00', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('bill_vis_pat_005', 'vis_pat_005', 'pat_005', 'INV-20261015-0005', 600.0, 'NONE', 0.0, 0.0, 600.0, 0.0, 0.0, 0.0, 0.0, 600.0, 600.0, 600.0, 0.0, 'PAID', 'PAID', 'CASH', 'usr_bill_1', '2026-10-15T10:30:00', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('bill_vis_pat_006', 'vis_pat_006', 'pat_006', 'INV-20261015-0006', 750.0, 'NONE', 0.0, 0.0, 750.0, 0.0, 0.0, 0.0, 0.0, 750.0, 750.0, 750.0, 0.0, 'PAID', 'PAID', 'CASH', 'usr_bill_1', '2026-10-15T10:30:00', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('bill_vis_pat_007', 'vis_pat_007', 'pat_007', 'INV-20261015-0007', 500.0, 'NONE', 0.0, 0.0, 500.0, 0.0, 0.0, 0.0, 0.0, 500.0, 500.0, 500.0, 0.0, 'PAID', 'PAID', 'CASH', 'usr_bill_1', '2026-10-15T10:30:00', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('bill_vis_pat_008', 'vis_pat_008', 'pat_008', 'INV-20261015-0008', 600.0, 'NONE', 0.0, 0.0, 600.0, 0.0, 0.0, 0.0, 0.0, 600.0, 600.0, 600.0, 0.0, 'PAID', 'PAID', 'CASH', 'usr_bill_1', '2026-10-15T10:30:00', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('bill_vis_pat_009', 'vis_pat_009', 'pat_009', 'INV-20261015-0009', 500.0, 'NONE', 0.0, 0.0, 500.0, 0.0, 0.0, 0.0, 0.0, 500.0, 500.0, 500.0, 0.0, 'PAID', 'PAID', 'CASH', 'usr_bill_1', '2026-10-15T10:30:00', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('bill_vis_pat_010', 'vis_pat_010', 'pat_010', 'INV-20261015-0010', 500.0, 'NONE', 0.0, 0.0, 500.0, 0.0, 0.0, 0.0, 0.0, 500.0, 500.0, 500.0, 0.0, 'PAID', 'PAID', 'CASH', 'usr_bill_1', '2026-10-15T10:30:00', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('bill_vis_pat_011', 'vis_pat_011', 'pat_011', 'INV-20261015-0011', 500.0, 'NONE', 0.0, 0.0, 500.0, 0.0, 0.0, 0.0, 0.0, 500.0, 500.0, 500.0, 0.0, 'PAID', 'PAID', 'CASH', 'usr_bill_1', '2026-10-15T10:30:00', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('bill_vis_pat_012', 'vis_pat_012', 'pat_012', 'INV-20261015-0012', 500.0, 'NONE', 0.0, 0.0, 500.0, 0.0, 0.0, 0.0, 0.0, 500.0, 500.0, 500.0, 0.0, 'PAID', 'PAID', 'CASH', 'usr_bill_1', '2026-10-15T10:30:00', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('bill_vis_pat_013', 'vis_pat_013', 'pat_013', 'INV-20261015-0013', 750.0, 'NONE', 0.0, 0.0, 750.0, 0.0, 0.0, 0.0, 0.0, 750.0, 750.0, 750.0, 0.0, 'PAID', 'PAID', 'CASH', 'usr_bill_1', '2026-10-15T10:30:00', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('bill_vis_pat_014', 'vis_pat_014', 'pat_014', 'INV-20261015-0014', 500.0, 'NONE', 0.0, 0.0, 500.0, 0.0, 0.0, 0.0, 0.0, 500.0, 500.0, 500.0, 0.0, 'PAID', 'PAID', 'CASH', 'usr_bill_1', '2026-10-15T10:30:00', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('bill_vis_pat_015', 'vis_pat_015', 'pat_015', 'INV-20261015-0015', 500.0, 'NONE', 0.0, 0.0, 500.0, 0.0, 0.0, 0.0, 0.0, 500.0, 500.0, 500.0, 0.0, 'PAID', 'PAID', 'CASH', 'usr_bill_1', '2026-10-15T10:30:00', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('bill_vis_pat_016', 'vis_pat_016', 'pat_016', 'INV-20261015-0016', 500.0, 'NONE', 0.0, 0.0, 500.0, 0.0, 0.0, 0.0, 0.0, 500.0, 500.0, 500.0, 0.0, 'PAID', 'PAID', 'CASH', 'usr_bill_1', '2026-10-15T10:30:00', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('bill_vis_pat_017', 'vis_pat_017', 'pat_017', 'INV-20261015-0017', 500.0, 'NONE', 0.0, 0.0, 500.0, 0.0, 0.0, 0.0, 0.0, 500.0, 500.0, 500.0, 0.0, 'PAID', 'PAID', 'CASH', 'usr_bill_1', '2026-10-15T10:30:00', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('bill_vis_pat_018', 'vis_pat_018', 'pat_018', 'INV-20261015-0018', 500.0, 'NONE', 0.0, 0.0, 500.0, 0.0, 0.0, 0.0, 0.0, 500.0, 500.0, 500.0, 0.0, 'PAID', 'PAID', 'CASH', 'usr_bill_1', '2026-10-15T10:30:00', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('bill_vis_pat_019', 'vis_pat_019', 'pat_019', 'INV-20261015-0019', 500.0, 'NONE', 0.0, 0.0, 500.0, 0.0, 0.0, 0.0, 0.0, 500.0, 500.0, 500.0, 0.0, 'PAID', 'PAID', 'CASH', 'usr_bill_1', '2026-10-15T10:30:00', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('bill_vis_pat_020', 'vis_pat_020', 'pat_020', 'INV-20261015-0020', 500.0, 'NONE', 0.0, 0.0, 500.0, 0.0, 0.0, 0.0, 0.0, 500.0, 500.0, 500.0, 0.0, 'PAID', 'PAID', 'CASH', 'usr_bill_1', '2026-10-15T10:30:00', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00')
ON CONFLICT (id) DO UPDATE SET visit_id = EXCLUDED.visit_id, patient_id = EXCLUDED.patient_id, invoice_number = EXCLUDED.invoice_number, subtotal = EXCLUDED.subtotal, discount_type = EXCLUDED.discount_type, discount_rate = EXCLUDED.discount_rate, discount_amount = EXCLUDED.discount_amount, taxable_amount = EXCLUDED.taxable_amount, cgst_amount = EXCLUDED.cgst_amount, sgst_amount = EXCLUDED.sgst_amount, igst_amount = EXCLUDED.igst_amount, total_tax_amount = EXCLUDED.total_tax_amount, total_amount = EXCLUDED.total_amount, net_amount = EXCLUDED.net_amount, paid_amount = EXCLUDED.paid_amount, outstanding_balance = EXCLUDED.outstanding_balance, status = EXCLUDED.status, payment_status = EXCLUDED.payment_status, payment_method = EXCLUDED.payment_method, billed_by_user_id = EXCLUDED.billed_by_user_id, billed_at = EXCLUDED.billed_at, is_synthetic_pricing = EXCLUDED.is_synthetic_pricing, created_at = EXCLUDED.created_at, updated_at = EXCLUDED.updated_at;

-- Data: medicine_inventory (28 records)
INSERT INTO medicine_inventory (id, medicine_code, name, generic_name, strength, dosage_form, batch_number, expiry_date, available_quantity, reorder_level, unit_price, is_synthetic_price, tax_classification, tax_rate_percent, supplier_name, supplier_contact, is_active, created_at, updated_at) VALUES
  ('inv_med_001', 'MED-001', 'Paracetamol 650mg', 'Paracetamol', '650mg', 'Tablet', 'BATCH-2026-A1', '2027-12-31', 450, 50, 2.5, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_002', 'MED-002', 'Metformin 500mg', 'Metformin Hydrochloride', '500mg', 'Tablet', 'BATCH-2026-A2', '2027-12-31', 600, 100, 3.2, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_003', 'MED-003', 'Amlodipine 5mg', 'Amlodipine Besylate', '5mg', 'Tablet', 'BATCH-2026-A3', '2027-12-31', 350, 50, 4.0, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_004', 'MED-004', 'Telmisartan 40mg', 'Telmisartan', '40mg', 'Tablet', 'BATCH-2026-A4', '2027-12-31', 280, 40, 8.5, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_005', 'MED-005', 'Pantoprazole 40mg', 'Pantoprazole Sodium', '40mg', 'Tablet', 'BATCH-2026-A5', '2027-12-31', 500, 60, 6.0, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_006', 'MED-006', 'Amoxicillin + Clavulanic Acid 625mg', 'Amoxicillin Clavulanate', '625mg', 'Tablet', 'BATCH-2026-A6', '2027-12-31', 240, 30, 22.0, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_007', 'MED-007', 'Cetirizine 10mg', 'Cetirizine Dihydrochloride', '10mg', 'Tablet', 'BATCH-2026-A7', '2027-12-31', 400, 50, 3.0, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_008', 'MED-008', 'Azithromycin 500mg', 'Azithromycin Dihydrate', '500mg', 'Tablet', 'BATCH-2026-A8', '2027-12-31', 180, 25, 24.5, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_009', 'MED-009', 'Ciprofloxacin 500mg', 'Ciprofloxacin Hydrochloride', '500mg', 'Tablet', 'BATCH-2026-A9', '2027-12-31', 220, 30, 12.0, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_010', 'MED-010', 'Ibuprofen 400mg', 'Ibuprofen', '400mg', 'Tablet', 'BATCH-2026-B1', '2027-12-31', 320, 40, 3.8, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_011', 'MED-011', 'Omeprazole 20mg', 'Omeprazole Magnesium', '20mg', 'Capsule', 'BATCH-2026-B2', '2027-12-31', 410, 50, 4.5, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_012', 'MED-012', 'Atorvastatin 10mg', 'Atorvastatin Calcium', '10mg', 'Tablet', 'BATCH-2026-B3', '2027-12-31', 290, 40, 9.8, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_013', 'MED-013', 'Levothyroxine 50mcg', 'Levothyroxine Sodium', '50mcg', 'Tablet', 'BATCH-2026-B4', '2027-12-31', 300, 50, 2.2, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_014', 'MED-014', 'Salbutamol Inhaler 100mcg', 'Salbutamol Sulfate', '100mcg/dose', 'Inhaler', 'BATCH-2026-B5', '2027-12-31', 85, 15, 145.0, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_015', 'MED-015', 'Oral Rehydration Salts (ORS)', 'Sodium Chloride / Dextrose', '21.8g', 'Sachet', 'BATCH-2026-B6', '2027-12-31', 500, 100, 18.0, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_016', 'MED-016', 'Ranitidine 150mg', 'Ranitidine Hydrochloride', '150mg', 'Tablet', 'BATCH-2026-B7', '2027-12-31', 250, 40, 2.8, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_017', 'MED-017', 'Losartan Potassium 50mg', 'Losartan Potassium', '50mg', 'Tablet', 'BATCH-2026-B8', '2027-12-31', 210, 30, 6.5, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_018', 'MED-018', 'Hydrochlorothiazide 12.5mg', 'Hydrochlorothiazide', '12.5mg', 'Tablet', 'BATCH-2026-B9', '2027-12-31', 190, 25, 3.5, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_019', 'MED-019', 'Cefixime 200mg', 'Cefixime Trihydrate', '200mg', 'Tablet', 'BATCH-2026-C1', '2027-12-31', 160, 25, 18.5, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_020', 'MED-020', 'Doxycycline 100mg', 'Doxycycline Hyclate', '100mg', 'Capsule', 'BATCH-2026-C2', '2027-12-31', 140, 20, 8.0, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_021', 'MED-021', 'Diclofenac Sodium 50mg', 'Diclofenac Sodium', '50mg', 'Tablet', 'BATCH-2026-C3', '2027-12-31', 380, 50, 4.2, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_022', 'MED-022', 'Tramadol Hydrochloride 50mg', 'Tramadol HCl', '50mg', 'Capsule', 'BATCH-2026-C4', '2027-12-31', 95, 20, 14.0, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_023', 'MED-023', 'Montelukast 10mg', 'Montelukast Sodium', '10mg', 'Tablet', 'BATCH-2026-C5', '2027-12-31', 210, 30, 11.5, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_024', 'MED-024', 'Clopidogrel 75mg', 'Clopidogrel Bisulfate', '75mg', 'Tablet', 'BATCH-2026-C6', '2027-12-31', 175, 25, 15.0, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_025', 'MED-025', 'Insulin Glargine 100 IU/ml', 'Insulin Glargine', '100 IU/ml', 'Vial', 'BATCH-2026-C7', '2027-12-31', 60, 15, 520.0, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_026', 'MED-026', 'Gliclazide 80mg', 'Gliclazide', '80mg', 'Tablet', 'BATCH-2026-C8', '2027-12-31', 220, 30, 7.2, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_027', 'MED-027', 'Ferrous Ascorbate + Folic Acid', 'Iron + Folic Acid', '100mg/1.5mg', 'Tablet', 'BATCH-2026-C9', '2027-12-31', 420, 60, 8.5, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_028', 'MED-028', 'Calcium Carbonate + Vit D3', 'Calcium Carbonate + Cholecalciferol', '500mg/250IU', 'Tablet', 'BATCH-2026-D1', '2027-12-31', 360, 50, 7.0, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00')
ON CONFLICT (id) DO UPDATE SET medicine_code = EXCLUDED.medicine_code, name = EXCLUDED.name, generic_name = EXCLUDED.generic_name, strength = EXCLUDED.strength, dosage_form = EXCLUDED.dosage_form, batch_number = EXCLUDED.batch_number, expiry_date = EXCLUDED.expiry_date, available_quantity = EXCLUDED.available_quantity, reorder_level = EXCLUDED.reorder_level, unit_price = EXCLUDED.unit_price, is_synthetic_price = EXCLUDED.is_synthetic_price, tax_classification = EXCLUDED.tax_classification, tax_rate_percent = EXCLUDED.tax_rate_percent, supplier_name = EXCLUDED.supplier_name, supplier_contact = EXCLUDED.supplier_contact, is_active = EXCLUDED.is_active, created_at = EXCLUDED.created_at, updated_at = EXCLUDED.updated_at;

-- ========================================================
-- 2. ROW LEVEL SECURITY (RLS) POLICIES
-- Ensures mobile devices on any network connect seamlessly
-- ========================================================
ALTER TABLE IF EXISTS departments DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS medicine_inventory DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS otp_verifications DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS patients DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS permissions DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS roles DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS users DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS audit_logs DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS doctors DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS password_reset_tokens DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS refresh_token_sessions DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS role_permissions DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS stock_movements DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS support_tickets DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS system_configs DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS opd_visits DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS bills DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS clinical_records DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS lab_orders DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS medical_documents DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS prescriptions DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS vital_signs DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS bill_items DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS clinical_amendments DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS document_audit_logs DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS document_ocr_extractions DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS document_pages DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS lab_results DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS payment_transactions DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS pharmacy_dispenses DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS pharmacy_orders DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS prescription_amendments DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS prescription_items DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS pharmacy_dispense_items DISABLE ROW LEVEL SECURITY;


-- ========================================================
-- 3. PRODUCTION SEED DATA (Doctors, Staff, Patients, Visits)
-- Idempotent upserts (ON CONFLICT DO UPDATE)
-- ========================================================

-- Data: roles (8 records)
INSERT INTO roles (id, name, description, created_at, updated_at) VALUES
  ('role_admin', 'admin', 'Full Hospital System Administrator', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('role_doctor', 'doctor', 'Consultant Physician / Specialist', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('role_receptionist', 'receptionist', 'Front Desk Registration & Token Issuer', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('role_pharmacist', 'pharmacist', 'Pharmacy Order Dispenser & Formulary Manager', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('role_lab_tech', 'lab_tech', 'Laboratory Diagnostics & Pathology Technician', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('role_billing', 'billing', 'Billing Counter Cashier & Fee Collector', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('role_nurse', 'nurse', 'Triage & Vitals Assessment Nurse', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('role_patient', 'patient', 'Registered Patient Token & Records Access', '2026-10-15T10:30:00', '2026-10-15T10:30:00')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, created_at = EXCLUDED.created_at, updated_at = EXCLUDED.updated_at;

-- Data: departments (6 records)
INSERT INTO departments (id, name, code, description, is_active, created_at, updated_at) VALUES
  ('dept_med', 'General Medicine', 'MED', 'Adult Internal Medicine, Hypertension, Diabetes, and Infectious Diseases', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('dept_ped', 'Pediatrics', 'PED', 'Neonatal, Child Health, Immunization & Pediatric Care', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('dept_ortho', 'Orthopedics', 'ORTH', 'Bone, Joint, Spine, Fracture Trauma & Sports Injury', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('dept_cardio', 'Cardiology', 'CARD', 'Cardiac Diagnostics, Heart Disease, ECG & Preventive Cardiology', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('dept_ent', 'ENT (Otorhinolaryngology)', 'ENT', 'Ear, Nose, Throat, Sinus, Voice & Hearing Disorders', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('dept_dent', 'Dental & Maxillofacial Surgery', 'DENT', 'Oral Health, Orthodontics, Endodontics & Maxillofacial Care', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, code = EXCLUDED.code, description = EXCLUDED.description, is_active = EXCLUDED.is_active, created_at = EXCLUDED.created_at, updated_at = EXCLUDED.updated_at;

-- Data: users (33 records)
INSERT INTO users (id, email, phone, full_name, hashed_password, role_id, is_active, is_verified, failed_login_attempts, created_at, updated_at) VALUES
  ('usr_admin', 'admin@smvmch.ac.in', '9876543200', 'Hospital Administrator', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_admin', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_doc_med_1', 'dr.sarah.chen@smvmch.ac.in', '9876543101', 'Dr. Sarah Chen, MD', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_doctor', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_doc_med_2', 'dr.rajesh.sundaram@smvmch.ac.in', '9876543102', 'Dr. Rajesh Sundaram, MBBS, MD', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_doctor', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_doc_med_3', 'dr.ananya.sharma@smvmch.ac.in', '9876543103', 'Dr. Ananya Sharma, MD, DNB', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_doctor', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_doc_ped_1', 'dr.priya.balakrishnan@smvmch.ac.in', '9876543104', 'Dr. Priya Balakrishnan, MD (Peds)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_doctor', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_doc_ped_2', 'dr.vikram.rao@smvmch.ac.in', '9876543105', 'Dr. Vikramaditya Rao, DCH, DNB', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_doctor', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_doc_ped_3', 'dr.meera.nambiar@smvmch.ac.in', '9876543106', 'Dr. Meera Nambiar, MBBS, MD', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_doctor', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_doc_ortho_1', 'dr.karthik.subramaniam@smvmch.ac.in', '9876543107', 'Dr. Karthik Subramaniam, MS (Ortho)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_doctor', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_doc_ortho_2', 'dr.david.miller@smvmch.ac.in', '9876543108', 'Dr. David Miller, MD, FRCS', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_doctor', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_doc_ortho_3', 'dr.sanjay.verma@smvmch.ac.in', '9876543109', 'Dr. Sanjay Verma, MS (Ortho)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_doctor', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_doc_cardio_1', 'dr.arvind.swamy@smvmch.ac.in', '9876543110', 'Dr. Arvind Swamy, MD, DM (Cardio)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_doctor', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_doc_cardio_2', 'dr.preethi.venkat@smvmch.ac.in', '9876543111', 'Dr. Preethi Venkat, MBBS, DNB (Cardio)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_doctor', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_doc_cardio_3', 'dr.ramesh.chandran@smvmch.ac.in', '9876543112', 'Dr. Ramesh Chandran, MD, DM, FACC', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_doctor', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_doc_ent_1', 'dr.pooja.deshmukh@smvmch.ac.in', '9876543113', 'Dr. Pooja Deshmukh, MS (ENT)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_doctor', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_doc_ent_2', 'dr.harish.kumar@smvmch.ac.in', '9876543114', 'Dr. Harish Kumar, MBBS, DLO', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_doctor', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_doc_ent_3', 'dr.gautham.menon@smvmch.ac.in', '9876543115', 'Dr. Gautham Menon, MS (ENT)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_doctor', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_doc_dent_1', 'dr.arunraj@smvmch.ac.in', '9876543116', 'Dr. M. Arunraj, MDS (Oral Surg)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_doctor', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_doc_dent_2', 'dr.swathi.reddy@smvmch.ac.in', '9876543117', 'Dr. Swathi Reddy, BDS, MDS (Ortho)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_doctor', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_doc_dent_3', 'dr.kevin.thomas@smvmch.ac.in', '9876543118', 'Dr. Kevin Thomas, MDS (Periodontics)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_doctor', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_rec_1', 'receptionist1@smvmch.ac.in', '9876543210', 'Alice Adams (Reception 1)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_receptionist', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_rec_2', 'receptionist2@smvmch.ac.in', '9876543211', 'Kavitha Raman (Reception 2)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_receptionist', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_pharm_1', 'pharmacist1@smvmch.ac.in', '9876543221', 'Elena Rostova (Lead Pharmacist)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_pharmacist', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_pharm_2', 'pharmacist2@smvmch.ac.in', '9876543222', 'Rahul Sharma (Pharmacist Desk 2)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_pharmacist', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_pharm_3', 'pharmacist3@smvmch.ac.in', '9876543223', 'Deepa Krishnan (Pharmacist Desk 3)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_pharmacist', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_pharm_4', 'pharmacist4@smvmch.ac.in', '9876543224', 'Manoj Kumar (Dispensing Pharmacist)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_pharmacist', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_pharm_5', 'pharmacist5@smvmch.ac.in', '9876543225', 'Sneha Patel (Inventory Pharmacist)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_pharmacist', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_lab_1', 'lab1@smvmch.ac.in', '9876543231', 'Marcus Vance (Senior Lab Tech)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_lab_tech', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_lab_2', 'lab2@smvmch.ac.in', '9876543232', 'Divya Prakash (Biochemist)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_lab_tech', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_lab_3', 'lab3@smvmch.ac.in', '9876543233', 'Sandeep Varma (Hematologist Tech)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_lab_tech', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_bill_1', 'billing1@smvmch.ac.in', '9876543241', 'Rajesh Kumar (Counter 1)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_billing', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_bill_2', 'billing2@smvmch.ac.in', '9876543242', 'Suresh Babu (Counter 2)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_billing', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_bill_3', 'billing3@smvmch.ac.in', '9876543243', 'Lakshmi Narayanan (Counter 3)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_billing', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('usr_bill_4', 'billing4@smvmch.ac.in', '9876543244', 'Anitha Murugan (Counter 4)', 'pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f', 'role_billing', TRUE, TRUE, 0, '2026-10-15T10:30:00', '2026-10-15T10:30:00')
ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email, phone = EXCLUDED.phone, full_name = EXCLUDED.full_name, hashed_password = EXCLUDED.hashed_password, role_id = EXCLUDED.role_id, is_active = EXCLUDED.is_active, is_verified = EXCLUDED.is_verified, failed_login_attempts = EXCLUDED.failed_login_attempts, created_at = EXCLUDED.created_at, updated_at = EXCLUDED.updated_at;

-- Data: doctors (18 records)
INSERT INTO doctors (id, user_id, department_id, qualification, specialization, registration_number, room_number, consultation_fee, is_available, created_at, updated_at) VALUES
  ('doc_med_1', 'usr_doc_med_1', 'dept_med', 'MBBS, MD (General Medicine)', 'Internal Medicine & Diabetology', 'MCI-TN-48901', 'OPD Room 101, Ground Floor', 500.0, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('doc_med_2', 'usr_doc_med_2', 'dept_med', 'MBBS, MD (Internal Medicine)', 'Geriatrics & Hypertension', 'MCI-TN-51204', 'OPD Room 102, Ground Floor', 500.0, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('doc_med_3', 'usr_doc_med_3', 'dept_med', 'MD, DNB (General Medicine)', 'Infectious Diseases & Critical Care', 'MCI-TN-54329', 'OPD Room 103, Ground Floor', 500.0, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('doc_ped_1', 'usr_doc_ped_1', 'dept_ped', 'MBBS, MD (Pediatrics)', 'Pediatric Pulmonology & Allergy', 'MCI-TN-61002', 'OPD Room 201, 1st Floor', 600.0, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('doc_ped_2', 'usr_doc_ped_2', 'dept_ped', 'DCH, DNB (Pediatrics)', 'Neonatology & Growth Assessment', 'MCI-TN-62187', 'OPD Room 202, 1st Floor', 600.0, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('doc_ped_3', 'usr_doc_ped_3', 'dept_ped', 'MBBS, MD (Pediatrics)', 'Child Nutrition & Immunization', 'MCI-TN-63401', 'OPD Room 203, 1st Floor', 600.0, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('doc_ortho_1', 'usr_doc_ortho_1', 'dept_ortho', 'MS (Orthopedics)', 'Spine & Joint Replacement', 'MCI-TN-71890', 'OPD Room 301, 2nd Floor', 700.0, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('doc_ortho_2', 'usr_doc_ortho_2', 'dept_ortho', 'MD, FRCS (Ortho)', 'Sports Medicine & Arthroscopy', 'MCI-TN-72543', 'OPD Room 302, 2nd Floor', 750.0, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('doc_ortho_3', 'usr_doc_ortho_3', 'dept_ortho', 'MS (Ortho), DNB', 'Trauma & Fracture Reconstruction', 'MCI-TN-73912', 'OPD Room 303, 2nd Floor', 700.0, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('doc_cardio_1', 'usr_doc_cardio_1', 'dept_cardio', 'MD, DM (Cardiology)', 'Interventional Cardiology & Angiography', 'MCI-TN-81098', 'OPD Room 401, 3rd Floor', 900.0, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('doc_cardio_2', 'usr_doc_cardio_2', 'dept_cardio', 'MBBS, DNB (Cardiology)', 'Non-Invasive Cardiology & Echocardiography', 'MCI-TN-82341', 'OPD Room 402, 3rd Floor', 850.0, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('doc_cardio_3', 'usr_doc_cardio_3', 'dept_cardio', 'MD, DM, FACC', 'Heart Failure & Preventive Cardiology', 'MCI-TN-83567', 'OPD Room 403, 3rd Floor', 1000.0, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('doc_ent_1', 'usr_doc_ent_1', 'dept_ent', 'MS (ENT)', 'Endoscopic Sinus Surgery & Rhinology', 'MCI-TN-91045', 'OPD Room 501, 4th Floor', 550.0, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('doc_ent_2', 'usr_doc_ent_2', 'dept_ent', 'MBBS, DLO, DNB (ENT)', 'Otology & Audiology', 'MCI-TN-92189', 'OPD Room 502, 4th Floor', 550.0, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('doc_ent_3', 'usr_doc_ent_3', 'dept_ent', 'MS (ENT)', 'Laryngology & Voice Disorders', 'MCI-TN-93450', 'OPD Room 503, 4th Floor', 600.0, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('doc_dent_1', 'usr_doc_dent_1', 'dept_dent', 'BDS, MDS (Oral & Maxillofacial)', 'Oral Surgery & Dental Implants', 'DCI-TN-31092', 'Dental Clinic 208, Block B', 600.0, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('doc_dent_2', 'usr_doc_dent_2', 'dept_dent', 'BDS, MDS (Orthodontics)', 'Dentofacial Orthopedics & Braces', 'DCI-TN-32145', 'Dental Clinic 209, Block B', 600.0, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('doc_dent_3', 'usr_doc_dent_3', 'dept_dent', 'MDS (Periodontics)', 'Gum Diseases & Aesthetic Dentistry', 'DCI-TN-33410', 'Dental Clinic 210, Block B', 600.0, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00')
ON CONFLICT (id) DO UPDATE SET user_id = EXCLUDED.user_id, department_id = EXCLUDED.department_id, qualification = EXCLUDED.qualification, specialization = EXCLUDED.specialization, registration_number = EXCLUDED.registration_number, room_number = EXCLUDED.room_number, consultation_fee = EXCLUDED.consultation_fee, is_available = EXCLUDED.is_available, created_at = EXCLUDED.created_at, updated_at = EXCLUDED.updated_at;

-- Data: patients (20 records)
INSERT INTO patients (id, uhid, hospital_reg_num, abha_number, full_name, parent_spouse_name, parent_spouse_relation, date_of_birth, age_years, age_months, gender, phone, email, address, city, state, postal_code, blood_group, registration_date, barcode_value, qr_code_data, registered_by_staff_id, registered_by_staff_name, registered_by_staff_role, guardian_id, created_at, updated_at) VALUES
  ('pat_001', 'UHID-2026-00001', 'REG-2026-00001', '8374-4779-99-99', 'Lakshmi Srujana Majeti', 'Majeti Satyanarayana', 'Daughter', '1996-01-15', 30, 0, 'FEMALE', '8374477999', 'lakshmi.srujana.majeti@opdpatient.in', 'Flat 402, Sri Krishna Heights', 'Vijayawada', 'Andhra Pradesh', '520010', 'O+', '2026-10-15T10:30:00', 'BAR-UHID-2026-00001', 'SMVMCH|UHID-2026-00001|REG-2026-00001|Lakshmi Srujana Majeti|O+', 'usr_rec_1', 'Alice Adams (Reception 1)', 'receptionist', NULL, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('pat_002', 'UHID-2026-00002', 'REG-2026-00002', '9876-5432-01-99', 'uday', 'satya', 'Son', '2001-01-15', 25, 0, 'MALE', '9876543201', 'uday@opdpatient.in', 'Door No 14/2, Anna Nagar', 'Puducherry', 'Puducherry', '605001', 'O+', '2026-10-15T10:30:00', 'BAR-UHID-2026-00002', 'SMVMCH|UHID-2026-00002|REG-2026-00002|uday|O+', 'usr_rec_1', 'Alice Adams (Reception 1)', 'receptionist', NULL, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('pat_003', 'UHID-2026-00003', 'REG-2026-00003', '9443-2187-65-99', 'K. Venkatasubramanian', 'Krishnan Iyer', 'Son', '1964-01-15', 62, 0, 'MALE', '9443218765', 'k..venkatasubramanian@opdpatient.in', '72, East Car Street, Chidambaram', 'Cuddalore', 'Tamil Nadu', '608001', 'B+', '2026-10-15T10:30:00', 'BAR-UHID-2026-00003', 'SMVMCH|UHID-2026-00003|REG-2026-00003|K. Venkatasubramanian|B+', 'usr_rec_1', 'Alice Adams (Reception 1)', 'receptionist', NULL, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('pat_004', 'UHID-2026-00004', 'REG-2026-00004', '9840-1234-56-99', 'Sowmya Radhakrishnan', 'Radhakrishnan Nair', 'Wife', '1998-01-15', 28, 0, 'FEMALE', '9840123456', 'sowmya.radhakrishnan@opdpatient.in', 'Plot 18, Lake View Enclave', 'Chennai', 'Tamil Nadu', '600042', 'A+', '2026-10-15T10:30:00', 'BAR-UHID-2026-00004', 'SMVMCH|UHID-2026-00004|REG-2026-00004|Sowmya Radhakrishnan|A+', 'usr_rec_1', 'Alice Adams (Reception 1)', 'receptionist', NULL, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('pat_005', 'UHID-2026-00005', 'REG-2026-00005', '9884-5678-90-99', 'Master Aarav Vignesh', 'Vigneshwaran M', 'Son', '2020-01-15', 6, 0, 'MALE', '9884567890', 'master.aarav.vignesh@opdpatient.in', '22, Gandhi Road', 'Villupuram', 'Tamil Nadu', '605602', 'O+', '2026-10-15T10:30:00', 'BAR-UHID-2026-00005', 'SMVMCH|UHID-2026-00005|REG-2026-00005|Master Aarav Vignesh|O+', 'usr_rec_1', 'Alice Adams (Reception 1)', 'receptionist', NULL, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('pat_006', 'UHID-2026-00006', 'REG-2026-00006', '9444-1238-90-99', 'Meenakshi Sundaram', 'Sundaramurthy Pillai', 'Wife', '1968-01-15', 58, 0, 'FEMALE', '9444123890', 'meenakshi.sundaram@opdpatient.in', '45/A, North Mada Street, Mylapore', 'Chennai', 'Tamil Nadu', '600004', 'AB+', '2026-10-15T10:30:00', 'BAR-UHID-2026-00006', 'SMVMCH|UHID-2026-00006|REG-2026-00006|Meenakshi Sundaram|AB+', 'usr_rec_1', 'Alice Adams (Reception 1)', 'receptionist', NULL, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('pat_007', 'UHID-2026-00007', 'REG-2026-00007', '9789-0123-45-99', 'R. Karthikeyan', 'Ramasamy Gounder', 'Son', '1992-01-15', 34, 0, 'MALE', '9789012345', 'r..karthikeyan@opdpatient.in', '12, Bharathi Street', 'Tindivanam', 'Tamil Nadu', '604001', 'B+', '2026-10-15T10:30:00', 'BAR-UHID-2026-00007', 'SMVMCH|UHID-2026-00007|REG-2026-00007|R. Karthikeyan|B+', 'usr_rec_1', 'Alice Adams (Reception 1)', 'receptionist', NULL, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('pat_008', 'UHID-2026-00008', 'REG-2026-00008', '9940-1237-89-99', 'Baby Ananya Sri', 'Senthil Kumar', 'Daughter', '2023-01-15', 3, 0, 'FEMALE', '9940123789', 'baby.ananya.sri@opdpatient.in', '5/8, Church Street', 'Puducherry', 'Puducherry', '605003', 'A+', '2026-10-15T10:30:00', 'BAR-UHID-2026-00008', 'SMVMCH|UHID-2026-00008|REG-2026-00008|Baby Ananya Sri|A+', 'usr_rec_1', 'Alice Adams (Reception 1)', 'receptionist', NULL, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('pat_009', 'UHID-2026-00009', 'REG-2026-00009', '9841-2345-67-99', 'Farooq Ahmed', 'Abdul Razack', 'Son', '1979-01-15', 47, 0, 'MALE', '9841234567', 'farooq.ahmed@opdpatient.in', '89, Mosque Street, Gorimedu', 'Puducherry', 'Puducherry', '605006', 'O-', '2026-10-15T10:30:00', 'BAR-UHID-2026-00009', 'SMVMCH|UHID-2026-00009|REG-2026-00009|Farooq Ahmed|O-', 'usr_rec_1', 'Alice Adams (Reception 1)', 'receptionist', NULL, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('pat_010', 'UHID-2026-00010', 'REG-2026-00010', '9710-2345-67-99', 'Geetha Govindaraj', 'Govindarajan K', 'Wife', '1984-01-15', 42, 0, 'FEMALE', '9710234567', 'geetha.govindaraj@opdpatient.in', '34, South Street, Cuddalore Old Town', 'Cuddalore', 'Tamil Nadu', '607003', 'B-', '2026-10-15T10:30:00', 'BAR-UHID-2026-00010', 'SMVMCH|UHID-2026-00010|REG-2026-00010|Geetha Govindaraj|B-', 'usr_rec_1', 'Alice Adams (Reception 1)', 'receptionist', NULL, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('pat_011', 'UHID-2026-00011', 'REG-2026-00011', '9884-0123-45-99', 'Pradeep Chandran', 'Chandrasekaran V', 'Son', '1988-01-15', 38, 0, 'MALE', '9884012345', 'pradeep.chandran@opdpatient.in', '101, Beach Road', 'Karaikal', 'Puducherry', '609602', 'A-', '2026-10-15T10:30:00', 'BAR-UHID-2026-00011', 'SMVMCH|UHID-2026-00011|REG-2026-00011|Pradeep Chandran|A-', 'usr_rec_1', 'Alice Adams (Reception 1)', 'receptionist', NULL, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('pat_012', 'UHID-2026-00012', 'REG-2026-00012', '9444-5678-12-99', 'Rukmani Ammal', 'Late Rangasamy', 'Wife', '1955-01-15', 71, 0, 'FEMALE', '9444567812', 'rukmani.ammal@opdpatient.in', '67, Perumal Koil Street', 'Madurantakam', 'Tamil Nadu', '603306', 'O+', '2026-10-15T10:30:00', 'BAR-UHID-2026-00012', 'SMVMCH|UHID-2026-00012|REG-2026-00012|Rukmani Ammal|O+', 'usr_rec_1', 'Alice Adams (Reception 1)', 'receptionist', NULL, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('pat_013', 'UHID-2026-00013', 'REG-2026-00013', '9600-1234-56-99', 'Vasanth Kumar', 'Kumaravel S', 'Son', '2004-01-15', 22, 0, 'MALE', '9600123456', 'vasanth.kumar@opdpatient.in', 'College Road, Lawspet', 'Puducherry', 'Puducherry', '605008', 'AB-', '2026-10-15T10:30:00', 'BAR-UHID-2026-00013', 'SMVMCH|UHID-2026-00013|REG-2026-00013|Vasanth Kumar|AB-', 'usr_rec_1', 'Alice Adams (Reception 1)', 'receptionist', NULL, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('pat_014', 'UHID-2026-00014', 'REG-2026-00014', '9840-5678-12-99', 'Nithya Kalyani', 'Muthukrishnan T', 'Daughter', '1995-01-15', 31, 0, 'FEMALE', '9840567812', 'nithya.kalyani@opdpatient.in', '42, Kamaraj Salai', 'Puducherry', 'Puducherry', '605009', 'A+', '2026-10-15T10:30:00', 'BAR-UHID-2026-00014', 'SMVMCH|UHID-2026-00014|REG-2026-00014|Nithya Kalyani|A+', 'usr_rec_1', 'Alice Adams (Reception 1)', 'receptionist', NULL, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('pat_015', 'UHID-2026-00015', 'REG-2026-00015', '9790-1234-56-99', 'Balaji Narayanan', 'Narayanasamy R', 'Son', '1977-01-15', 49, 0, 'MALE', '9790123456', 'balaji.narayanan@opdpatient.in', '15, Cross Street, Saram', 'Puducherry', 'Puducherry', '605013', 'B+', '2026-10-15T10:30:00', 'BAR-UHID-2026-00015', 'SMVMCH|UHID-2026-00015|REG-2026-00015|Balaji Narayanan|B+', 'usr_rec_1', 'Alice Adams (Reception 1)', 'receptionist', NULL, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('pat_016', 'UHID-2026-00016', 'REG-2026-00016', '9962-1234-56-99', 'Shalini Mohan', 'Mohanraj P', 'Daughter', '2000-01-15', 26, 0, 'FEMALE', '9962123456', 'shalini.mohan@opdpatient.in', '88, Main Road, Neyveli', 'Cuddalore', 'Tamil Nadu', '607803', 'O+', '2026-10-15T10:30:00', 'BAR-UHID-2026-00016', 'SMVMCH|UHID-2026-00016|REG-2026-00016|Shalini Mohan|O+', 'usr_rec_1', 'Alice Adams (Reception 1)', 'receptionist', NULL, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('pat_017', 'UHID-2026-00017', 'REG-2026-00017', '9443-5678-90-99', 'C. Dhandapani', 'Chinnasamy G', 'Son', '1971-01-15', 55, 0, 'MALE', '9443567890', 'c..dhandapani@opdpatient.in', '33, Bazaar Street', 'Panruti', 'Tamil Nadu', '607106', 'A+', '2026-10-15T10:30:00', 'BAR-UHID-2026-00017', 'SMVMCH|UHID-2026-00017|REG-2026-00017|C. Dhandapani|A+', 'usr_rec_1', 'Alice Adams (Reception 1)', 'receptionist', NULL, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('pat_018', 'UHID-2026-00018', 'REG-2026-00018', '9841-9876-54-99', 'Fatima Beevi', 'Late Syed Ibrahim', 'Wife', '1961-01-15', 65, 0, 'FEMALE', '9841987654', 'fatima.beevi@opdpatient.in', '19, New Street, Heritage Town', 'Puducherry', 'Puducherry', '605001', 'B+', '2026-10-15T10:30:00', 'BAR-UHID-2026-00018', 'SMVMCH|UHID-2026-00018|REG-2026-00018|Fatima Beevi|B+', 'usr_rec_1', 'Alice Adams (Reception 1)', 'receptionist', NULL, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('pat_019', 'UHID-2026-00019', 'REG-2026-00019', '9789-5678-90-99', 'G. Senthil Nathan', 'Ganesan P', 'Son', '1985-01-15', 41, 0, 'MALE', '9789567890', 'g..senthil.nathan@opdpatient.in', '51, Extension Colony', 'Kanchipuram', 'Tamil Nadu', '631502', 'O+', '2026-10-15T10:30:00', 'BAR-UHID-2026-00019', 'SMVMCH|UHID-2026-00019|REG-2026-00019|G. Senthil Nathan|O+', 'usr_rec_1', 'Alice Adams (Reception 1)', 'receptionist', NULL, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('pat_020', 'UHID-2026-00020', 'REG-2026-00020', '8555-0272-25-99', 'Dr. Chintha Ravi Prasanth', 'Late C. Subba Rao', 'Son', '1991-01-15', 35, 0, 'MALE', '8555027225', 'dr..chintha.ravi.prasanth@opdpatient.in', 'Flat 204, Executive Enclave', 'Hyderabad', 'Telangana', '500081', 'B+', '2026-10-15T10:30:00', 'BAR-UHID-2026-00020', 'SMVMCH|UHID-2026-00020|REG-2026-00020|Dr. Chintha Ravi Prasanth|B+', 'usr_rec_1', 'Alice Adams (Reception 1)', 'receptionist', NULL, '2026-10-15T10:30:00', '2026-10-15T10:30:00')
ON CONFLICT (id) DO UPDATE SET uhid = EXCLUDED.uhid, hospital_reg_num = EXCLUDED.hospital_reg_num, abha_number = EXCLUDED.abha_number, full_name = EXCLUDED.full_name, parent_spouse_name = EXCLUDED.parent_spouse_name, parent_spouse_relation = EXCLUDED.parent_spouse_relation, date_of_birth = EXCLUDED.date_of_birth, age_years = EXCLUDED.age_years, age_months = EXCLUDED.age_months, gender = EXCLUDED.gender, phone = EXCLUDED.phone, email = EXCLUDED.email, address = EXCLUDED.address, city = EXCLUDED.city, state = EXCLUDED.state, postal_code = EXCLUDED.postal_code, blood_group = EXCLUDED.blood_group, registration_date = EXCLUDED.registration_date, barcode_value = EXCLUDED.barcode_value, qr_code_data = EXCLUDED.qr_code_data, registered_by_staff_id = EXCLUDED.registered_by_staff_id, registered_by_staff_name = EXCLUDED.registered_by_staff_name, registered_by_staff_role = EXCLUDED.registered_by_staff_role, guardian_id = EXCLUDED.guardian_id, created_at = EXCLUDED.created_at, updated_at = EXCLUDED.updated_at;

-- Data: opd_visits (20 records)
INSERT INTO opd_visits (id, visit_number, patient_id, doctor_id, department_id, visit_date, queue_token, triage_priority, status, consultation_fee, payment_status, notes, created_at, updated_at) VALUES
  ('vis_pat_001', 'SMVMCH1510260001', 'pat_001', 'doc_med_1', 'dept_med', '2026-10-15T10:30:00', 1, 'NORMAL', 'IN_CONSULTATION', 500.0, 'PAID', 'Chief Clinical Diagnosis: Type 2 Diabetes Mellitus with Peripheral Neuropathy', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vis_pat_002', 'SMVMCH1510260002', 'pat_002', 'doc_ortho_1', 'dept_ortho', '2026-10-15T10:30:00', 2, 'NORMAL', 'WAITING', 750.0, 'PAID', 'Chief Clinical Diagnosis: Acute Lumbar Muscle Sprain & Sciatica', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vis_pat_003', 'SMVMCH1510260003', 'pat_003', 'doc_cardio_1', 'dept_cardio', '2026-10-15T10:30:00', 3, 'PRIORITY', 'IN_CONSULTATION', 750.0, 'PAID', 'Chief Clinical Diagnosis: Essential Hypertension & CAD (Post-PTCA Follow-up)', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vis_pat_004', 'SMVMCH1510260004', 'pat_004', 'doc_med_2', 'dept_med', '2026-10-15T10:30:00', 4, 'NORMAL', 'WAITING', 500.0, 'PAID', 'Chief Clinical Diagnosis: Antenatal Care 26 Weeks Gestation with Mild Anemia', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vis_pat_005', 'SMVMCH1510260005', 'pat_005', 'doc_ped_1', 'dept_ped', '2026-10-15T10:30:00', 5, 'EMERGENCY', 'TRIAGED', 600.0, 'PAID', 'Chief Clinical Diagnosis: Pediatric Bronchial Asthma with Acute Wheezing', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vis_pat_006', 'SMVMCH1510260006', 'pat_006', 'doc_ortho_2', 'dept_ortho', '2026-10-15T10:30:00', 6, 'NORMAL', 'WAITING', 750.0, 'PAID', 'Chief Clinical Diagnosis: Bilateral Knee Osteoarthritis Grade III', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vis_pat_007', 'SMVMCH1510260007', 'pat_007', 'doc_med_3', 'dept_med', '2026-10-15T10:30:00', 7, 'EMERGENCY', 'TRIAGED', 500.0, 'PAID', 'Chief Clinical Diagnosis: Acute Febrile Illness - Suspected Dengue Fever', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vis_pat_008', 'SMVMCH1510260008', 'pat_008', 'doc_ped_2', 'dept_ped', '2026-10-15T10:30:00', 8, 'PRIORITY', 'WAITING', 600.0, 'PAID', 'Chief Clinical Diagnosis: Acute Otitis Media & Upper Respiratory Infection', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vis_pat_009', 'SMVMCH1510260009', 'pat_009', 'doc_med_1', 'dept_med', '2026-10-15T10:30:00', 9, 'PRIORITY', 'IN_CONSULTATION', 500.0, 'PAID', 'Chief Clinical Diagnosis: Chronic Obstructive Pulmonary Disease (COPD) Grade II', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vis_pat_010', 'SMVMCH1510260010', 'pat_010', 'doc_med_2', 'dept_med', '2026-10-15T10:30:00', 10, 'NORMAL', 'COMPLETED', 500.0, 'PAID', 'Chief Clinical Diagnosis: Hypothyroidism with Dyslipidemia & Weight Gain', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vis_pat_011', 'SMVMCH1510260011', 'pat_011', 'doc_med_3', 'dept_med', '2026-10-15T10:30:00', 11, 'EMERGENCY', 'TRIAGED', 500.0, 'PAID', 'Chief Clinical Diagnosis: Acute Left Ureteric Calculus with Severe Renal Colic', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vis_pat_012', 'SMVMCH1510260012', 'pat_012', 'doc_med_1', 'dept_med', '2026-10-15T10:30:00', 12, 'PRIORITY', 'WAITING', 500.0, 'PAID', 'Chief Clinical Diagnosis: Chronic Kidney Disease Stage 3b & Diabetic Nephropathy', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vis_pat_013', 'SMVMCH1510260013', 'pat_013', 'doc_ortho_3', 'dept_ortho', '2026-10-15T10:30:00', 13, 'PRIORITY', 'WAITING', 750.0, 'PAID', 'Chief Clinical Diagnosis: Right Ankle Inversion Injury / Lateral Ligament Sprain', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vis_pat_014', 'SMVMCH1510260014', 'pat_014', 'doc_med_2', 'dept_med', '2026-10-15T10:30:00', 14, 'NORMAL', 'WAITING', 500.0, 'PAID', 'Chief Clinical Diagnosis: Chronic Migraine with Visual Aura & Photophobia', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vis_pat_015', 'SMVMCH1510260015', 'pat_015', 'doc_med_3', 'dept_med', '2026-10-15T10:30:00', 15, 'NORMAL', 'COMPLETED', 500.0, 'PAID', 'Chief Clinical Diagnosis: Gastroesophageal Reflux Disease (GERD) & Erosive Gastritis', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vis_pat_016', 'SMVMCH1510260016', 'pat_016', 'doc_med_1', 'dept_med', '2026-10-15T10:30:00', 16, 'PRIORITY', 'WAITING', 500.0, 'PAID', 'Chief Clinical Diagnosis: Severe Iron Deficiency Anemia (Hb 7.8 g/dL)', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vis_pat_017', 'SMVMCH1510260017', 'pat_017', 'doc_dent_1', 'dept_dent', '2026-10-15T10:30:00', 17, 'PRIORITY', 'IN_CONSULTATION', 500.0, 'PAID', 'Chief Clinical Diagnosis: Severe Acute Pulpitis & Mandibular 1st Molar Abscess', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vis_pat_018', 'SMVMCH1510260018', 'pat_018', 'doc_med_2', 'dept_med', '2026-10-15T10:30:00', 18, 'NORMAL', 'COMPLETED', 500.0, 'PAID', 'Chief Clinical Diagnosis: Chronic Allergic Contact Dermatitis & Numular Eczema', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vis_pat_019', 'SMVMCH1510260019', 'pat_019', 'doc_ent_1', 'dept_ent', '2026-10-15T10:30:00', 19, 'NORMAL', 'WAITING', 500.0, 'PAID', 'Chief Clinical Diagnosis: Allergic Rhinitis with Chronic Maxillary Sinusitis', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vis_pat_020', 'SMVMCH1510260020', 'pat_020', 'doc_med_3', 'dept_med', '2026-10-15T10:30:00', 20, 'NORMAL', 'COMPLETED', 500.0, 'PAID', 'Chief Clinical Diagnosis: Executive Annual Health Evaluation & Routine Screen', '2026-10-15T10:30:00', '2026-10-15T10:30:00')
ON CONFLICT (id) DO UPDATE SET visit_number = EXCLUDED.visit_number, patient_id = EXCLUDED.patient_id, doctor_id = EXCLUDED.doctor_id, department_id = EXCLUDED.department_id, visit_date = EXCLUDED.visit_date, queue_token = EXCLUDED.queue_token, triage_priority = EXCLUDED.triage_priority, status = EXCLUDED.status, consultation_fee = EXCLUDED.consultation_fee, payment_status = EXCLUDED.payment_status, notes = EXCLUDED.notes, created_at = EXCLUDED.created_at, updated_at = EXCLUDED.updated_at;

-- Data: vital_signs (20 records)
INSERT INTO vital_signs (id, visit_id, systolic_bp, diastolic_bp, pulse_rate, temperature_f, spo2_percent, respiratory_rate, height_cm, weight_kg, bmi, recorded_by_user_id, recorded_at, notes, created_at, updated_at) VALUES
  ('vit_vis_pat_001', 'vis_pat_001', 120, 78, 74, 98.4, 98.0, 18, 165.0, 64.0, 23.5, 'usr_rec_1', '2026-10-15T10:30:00', 'Triage assessment for Type 2 Diabetes Mellitus with Peripheral Neuropathy', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vit_vis_pat_002', 'vis_pat_002', 122, 79, 77, 98.4, 98.0, 18, 165.0, 64.0, 23.5, 'usr_rec_1', '2026-10-15T10:30:00', 'Triage assessment for Acute Lumbar Muscle Sprain & Sciatica', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vit_vis_pat_003', 'vis_pat_003', 124, 80, 80, 98.4, 98.0, 18, 165.0, 64.0, 23.5, 'usr_rec_1', '2026-10-15T10:30:00', 'Triage assessment for Essential Hypertension & CAD (Post-PTCA Follow-up)', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vit_vis_pat_004', 'vis_pat_004', 126, 81, 83, 98.4, 98.0, 18, 165.0, 64.0, 23.5, 'usr_rec_1', '2026-10-15T10:30:00', 'Triage assessment for Antenatal Care 26 Weeks Gestation with Mild Anemia', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vit_vis_pat_005', 'vis_pat_005', 128, 82, 86, 101.8, 94.0, 18, 165.0, 64.0, 23.5, 'usr_rec_1', '2026-10-15T10:30:00', 'Triage assessment for Pediatric Bronchial Asthma with Acute Wheezing', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vit_vis_pat_006', 'vis_pat_006', 130, 83, 89, 98.4, 98.0, 18, 165.0, 64.0, 23.5, 'usr_rec_1', '2026-10-15T10:30:00', 'Triage assessment for Bilateral Knee Osteoarthritis Grade III', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vit_vis_pat_007', 'vis_pat_007', 132, 84, 92, 101.8, 98.0, 18, 165.0, 64.0, 23.5, 'usr_rec_1', '2026-10-15T10:30:00', 'Triage assessment for Acute Febrile Illness - Suspected Dengue Fever', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vit_vis_pat_008', 'vis_pat_008', 134, 85, 95, 98.4, 98.0, 18, 165.0, 64.0, 23.5, 'usr_rec_1', '2026-10-15T10:30:00', 'Triage assessment for Acute Otitis Media & Upper Respiratory Infection', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vit_vis_pat_009', 'vis_pat_009', 136, 86, 98, 98.4, 94.0, 18, 165.0, 64.0, 23.5, 'usr_rec_1', '2026-10-15T10:30:00', 'Triage assessment for Chronic Obstructive Pulmonary Disease (COPD) Grade II', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vit_vis_pat_010', 'vis_pat_010', 138, 87, 76, 98.4, 98.0, 18, 165.0, 64.0, 23.5, 'usr_rec_1', '2026-10-15T10:30:00', 'Triage assessment for Hypothyroidism with Dyslipidemia & Weight Gain', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vit_vis_pat_011', 'vis_pat_011', 140, 88, 79, 101.8, 98.0, 18, 165.0, 64.0, 23.5, 'usr_rec_1', '2026-10-15T10:30:00', 'Triage assessment for Acute Left Ureteric Calculus with Severe Renal Colic', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vit_vis_pat_012', 'vis_pat_012', 142, 89, 82, 98.4, 98.0, 18, 165.0, 64.0, 23.5, 'usr_rec_1', '2026-10-15T10:30:00', 'Triage assessment for Chronic Kidney Disease Stage 3b & Diabetic Nephropathy', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vit_vis_pat_013', 'vis_pat_013', 144, 90, 85, 98.4, 98.0, 18, 165.0, 64.0, 23.5, 'usr_rec_1', '2026-10-15T10:30:00', 'Triage assessment for Right Ankle Inversion Injury / Lateral Ligament Sprain', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vit_vis_pat_014', 'vis_pat_014', 146, 91, 88, 98.4, 98.0, 18, 165.0, 64.0, 23.5, 'usr_rec_1', '2026-10-15T10:30:00', 'Triage assessment for Chronic Migraine with Visual Aura & Photophobia', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vit_vis_pat_015', 'vis_pat_015', 148, 92, 91, 98.4, 98.0, 18, 165.0, 64.0, 23.5, 'usr_rec_1', '2026-10-15T10:30:00', 'Triage assessment for Gastroesophageal Reflux Disease (GERD) & Erosive Gastritis', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vit_vis_pat_016', 'vis_pat_016', 150, 93, 94, 98.4, 98.0, 18, 165.0, 64.0, 23.5, 'usr_rec_1', '2026-10-15T10:30:00', 'Triage assessment for Severe Iron Deficiency Anemia (Hb 7.8 g/dL)', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vit_vis_pat_017', 'vis_pat_017', 152, 94, 97, 98.4, 98.0, 18, 165.0, 64.0, 23.5, 'usr_rec_1', '2026-10-15T10:30:00', 'Triage assessment for Severe Acute Pulpitis & Mandibular 1st Molar Abscess', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vit_vis_pat_018', 'vis_pat_018', 154, 95, 75, 98.4, 98.0, 18, 165.0, 64.0, 23.5, 'usr_rec_1', '2026-10-15T10:30:00', 'Triage assessment for Chronic Allergic Contact Dermatitis & Numular Eczema', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vit_vis_pat_019', 'vis_pat_019', 156, 96, 78, 98.4, 98.0, 18, 165.0, 64.0, 23.5, 'usr_rec_1', '2026-10-15T10:30:00', 'Triage assessment for Allergic Rhinitis with Chronic Maxillary Sinusitis', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('vit_vis_pat_020', 'vis_pat_020', 158, 97, 81, 98.4, 98.0, 18, 165.0, 64.0, 23.5, 'usr_rec_1', '2026-10-15T10:30:00', 'Triage assessment for Executive Annual Health Evaluation & Routine Screen', '2026-10-15T10:30:00', '2026-10-15T10:30:00')
ON CONFLICT (id) DO UPDATE SET visit_id = EXCLUDED.visit_id, systolic_bp = EXCLUDED.systolic_bp, diastolic_bp = EXCLUDED.diastolic_bp, pulse_rate = EXCLUDED.pulse_rate, temperature_f = EXCLUDED.temperature_f, spo2_percent = EXCLUDED.spo2_percent, respiratory_rate = EXCLUDED.respiratory_rate, height_cm = EXCLUDED.height_cm, weight_kg = EXCLUDED.weight_kg, bmi = EXCLUDED.bmi, recorded_by_user_id = EXCLUDED.recorded_by_user_id, recorded_at = EXCLUDED.recorded_at, notes = EXCLUDED.notes, created_at = EXCLUDED.created_at, updated_at = EXCLUDED.updated_at;

-- Data: clinical_records (20 records)
INSERT INTO clinical_records (id, visit_id, patient_id, doctor_id, presenting_complaint, history_of_present_illness, general_examination, provisional_diagnosis, final_diagnosis, icd10_code, care_plan, follow_up_date, status, version, created_by_user_id, created_at, updated_at) VALUES
  ('cr_vis_pat_001', 'vis_pat_001', 'pat_001', 'doc_med_1', 'Presents with symptoms of Type 2 Diabetes Mellitus with Peripheral Neuropathy', 'Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. Type 2 Diabetes Mellitus with Peripheral Neuropathy', 'Vitals: BP 120/78, Pulse 74 bpm, SpO2 98.0%.', 'Type 2 Diabetes Mellitus with Peripheral Neuropathy', 'Type 2 Diabetes Mellitus with Peripheral Neuropathy', 'E11.9', 'Initiate medical management for Type 2 Diabetes Mellitus with Peripheral Neuropathy. Review in OPD in 14 days with investigation results.', '2026-10-29', 'COMPLETED', 1, 'usr_doc_med_1', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('cr_vis_pat_002', 'vis_pat_002', 'pat_002', 'doc_ortho_1', 'Presents with symptoms of Acute Lumbar Muscle Sprain & Sciatica', 'Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. Acute Lumbar Muscle Sprain & Sciatica', 'Vitals: BP 122/79, Pulse 77 bpm, SpO2 98.0%.', 'Acute Lumbar Muscle Sprain & Sciatica', 'Acute Lumbar Muscle Sprain & Sciatica', 'M54.5', 'Initiate medical management for Acute Lumbar Muscle Sprain & Sciatica. Review in OPD in 14 days with investigation results.', '2026-10-29', 'COMPLETED', 1, 'usr_doc_ortho_1', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('cr_vis_pat_003', 'vis_pat_003', 'pat_003', 'doc_cardio_1', 'Presents with symptoms of Essential Hypertension & CAD (Post-PTCA Follow-up)', 'Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. Essential Hypertension & CAD (Post-PTCA Follow-up)', 'Vitals: BP 124/80, Pulse 80 bpm, SpO2 98.0%.', 'Essential Hypertension & CAD (Post-PTCA Follow-up)', 'Essential Hypertension & CAD (Post-PTCA Follow-up)', 'I25.1', 'Initiate medical management for Essential Hypertension & CAD (Post-PTCA Follow-up). Review in OPD in 14 days with investigation results.', '2026-10-29', 'COMPLETED', 1, 'usr_doc_cardio_1', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('cr_vis_pat_004', 'vis_pat_004', 'pat_004', 'doc_med_2', 'Presents with symptoms of Antenatal Care 26 Weeks Gestation with Mild Anemia', 'Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. Antenatal Care 26 Weeks Gestation with Mild Anemia', 'Vitals: BP 126/81, Pulse 83 bpm, SpO2 98.0%.', 'Antenatal Care 26 Weeks Gestation with Mild Anemia', 'Antenatal Care 26 Weeks Gestation with Mild Anemia', 'R69', 'Initiate medical management for Antenatal Care 26 Weeks Gestation with Mild Anemia. Review in OPD in 14 days with investigation results.', '2026-10-29', 'COMPLETED', 1, 'usr_doc_med_2', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('cr_vis_pat_005', 'vis_pat_005', 'pat_005', 'doc_ped_1', 'Presents with symptoms of Pediatric Bronchial Asthma with Acute Wheezing', 'Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. Pediatric Bronchial Asthma with Acute Wheezing', 'Vitals: BP 128/82, Pulse 86 bpm, SpO2 94.0%.', 'Pediatric Bronchial Asthma with Acute Wheezing', 'Pediatric Bronchial Asthma with Acute Wheezing', 'R69', 'Initiate medical management for Pediatric Bronchial Asthma with Acute Wheezing. Review in OPD in 14 days with investigation results.', '2026-10-29', 'COMPLETED', 1, 'usr_doc_ped_1', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('cr_vis_pat_006', 'vis_pat_006', 'pat_006', 'doc_ortho_2', 'Presents with symptoms of Bilateral Knee Osteoarthritis Grade III', 'Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. Bilateral Knee Osteoarthritis Grade III', 'Vitals: BP 130/83, Pulse 89 bpm, SpO2 98.0%.', 'Bilateral Knee Osteoarthritis Grade III', 'Bilateral Knee Osteoarthritis Grade III', 'R69', 'Initiate medical management for Bilateral Knee Osteoarthritis Grade III. Review in OPD in 14 days with investigation results.', '2026-10-29', 'COMPLETED', 1, 'usr_doc_ortho_2', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('cr_vis_pat_007', 'vis_pat_007', 'pat_007', 'doc_med_3', 'Presents with symptoms of Acute Febrile Illness - Suspected Dengue Fever', 'Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. Acute Febrile Illness - Suspected Dengue Fever', 'Vitals: BP 132/84, Pulse 92 bpm, SpO2 98.0%.', 'Acute Febrile Illness - Suspected Dengue Fever', 'Acute Febrile Illness - Suspected Dengue Fever', 'R69', 'Initiate medical management for Acute Febrile Illness - Suspected Dengue Fever. Review in OPD in 14 days with investigation results.', '2026-10-29', 'COMPLETED', 1, 'usr_doc_med_3', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('cr_vis_pat_008', 'vis_pat_008', 'pat_008', 'doc_ped_2', 'Presents with symptoms of Acute Otitis Media & Upper Respiratory Infection', 'Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. Acute Otitis Media & Upper Respiratory Infection', 'Vitals: BP 134/85, Pulse 95 bpm, SpO2 98.0%.', 'Acute Otitis Media & Upper Respiratory Infection', 'Acute Otitis Media & Upper Respiratory Infection', 'R69', 'Initiate medical management for Acute Otitis Media & Upper Respiratory Infection. Review in OPD in 14 days with investigation results.', '2026-10-29', 'COMPLETED', 1, 'usr_doc_ped_2', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('cr_vis_pat_009', 'vis_pat_009', 'pat_009', 'doc_med_1', 'Presents with symptoms of Chronic Obstructive Pulmonary Disease (COPD) Grade II', 'Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. Chronic Obstructive Pulmonary Disease (COPD) Grade II', 'Vitals: BP 136/86, Pulse 98 bpm, SpO2 94.0%.', 'Chronic Obstructive Pulmonary Disease (COPD) Grade II', 'Chronic Obstructive Pulmonary Disease (COPD) Grade II', 'R69', 'Initiate medical management for Chronic Obstructive Pulmonary Disease (COPD) Grade II. Review in OPD in 14 days with investigation results.', '2026-10-29', 'COMPLETED', 1, 'usr_doc_med_1', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('cr_vis_pat_010', 'vis_pat_010', 'pat_010', 'doc_med_2', 'Presents with symptoms of Hypothyroidism with Dyslipidemia & Weight Gain', 'Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. Hypothyroidism with Dyslipidemia & Weight Gain', 'Vitals: BP 138/87, Pulse 76 bpm, SpO2 98.0%.', 'Hypothyroidism with Dyslipidemia & Weight Gain', 'Hypothyroidism with Dyslipidemia & Weight Gain', 'R69', 'Initiate medical management for Hypothyroidism with Dyslipidemia & Weight Gain. Review in OPD in 14 days with investigation results.', '2026-10-29', 'COMPLETED', 1, 'usr_doc_med_2', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('cr_vis_pat_011', 'vis_pat_011', 'pat_011', 'doc_med_3', 'Presents with symptoms of Acute Left Ureteric Calculus with Severe Renal Colic', 'Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. Acute Left Ureteric Calculus with Severe Renal Colic', 'Vitals: BP 140/88, Pulse 79 bpm, SpO2 98.0%.', 'Acute Left Ureteric Calculus with Severe Renal Colic', 'Acute Left Ureteric Calculus with Severe Renal Colic', 'R69', 'Initiate medical management for Acute Left Ureteric Calculus with Severe Renal Colic. Review in OPD in 14 days with investigation results.', '2026-10-29', 'COMPLETED', 1, 'usr_doc_med_3', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('cr_vis_pat_012', 'vis_pat_012', 'pat_012', 'doc_med_1', 'Presents with symptoms of Chronic Kidney Disease Stage 3b & Diabetic Nephropathy', 'Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. Chronic Kidney Disease Stage 3b & Diabetic Nephropathy', 'Vitals: BP 142/89, Pulse 82 bpm, SpO2 98.0%.', 'Chronic Kidney Disease Stage 3b & Diabetic Nephropathy', 'Chronic Kidney Disease Stage 3b & Diabetic Nephropathy', 'R69', 'Initiate medical management for Chronic Kidney Disease Stage 3b & Diabetic Nephropathy. Review in OPD in 14 days with investigation results.', '2026-10-29', 'COMPLETED', 1, 'usr_doc_med_1', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('cr_vis_pat_013', 'vis_pat_013', 'pat_013', 'doc_ortho_3', 'Presents with symptoms of Right Ankle Inversion Injury / Lateral Ligament Sprain', 'Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. Right Ankle Inversion Injury / Lateral Ligament Sprain', 'Vitals: BP 144/90, Pulse 85 bpm, SpO2 98.0%.', 'Right Ankle Inversion Injury / Lateral Ligament Sprain', 'Right Ankle Inversion Injury / Lateral Ligament Sprain', 'M54.5', 'Initiate medical management for Right Ankle Inversion Injury / Lateral Ligament Sprain. Review in OPD in 14 days with investigation results.', '2026-10-29', 'COMPLETED', 1, 'usr_doc_ortho_3', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('cr_vis_pat_014', 'vis_pat_014', 'pat_014', 'doc_med_2', 'Presents with symptoms of Chronic Migraine with Visual Aura & Photophobia', 'Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. Chronic Migraine with Visual Aura & Photophobia', 'Vitals: BP 146/91, Pulse 88 bpm, SpO2 98.0%.', 'Chronic Migraine with Visual Aura & Photophobia', 'Chronic Migraine with Visual Aura & Photophobia', 'R69', 'Initiate medical management for Chronic Migraine with Visual Aura & Photophobia. Review in OPD in 14 days with investigation results.', '2026-10-29', 'COMPLETED', 1, 'usr_doc_med_2', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('cr_vis_pat_015', 'vis_pat_015', 'pat_015', 'doc_med_3', 'Presents with symptoms of Gastroesophageal Reflux Disease (GERD) & Erosive Gastritis', 'Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. Gastroesophageal Reflux Disease (GERD) & Erosive Gastritis', 'Vitals: BP 148/92, Pulse 91 bpm, SpO2 98.0%.', 'Gastroesophageal Reflux Disease (GERD) & Erosive Gastritis', 'Gastroesophageal Reflux Disease (GERD) & Erosive Gastritis', 'R69', 'Initiate medical management for Gastroesophageal Reflux Disease (GERD) & Erosive Gastritis. Review in OPD in 14 days with investigation results.', '2026-10-29', 'COMPLETED', 1, 'usr_doc_med_3', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('cr_vis_pat_016', 'vis_pat_016', 'pat_016', 'doc_med_1', 'Presents with symptoms of Severe Iron Deficiency Anemia (Hb 7.8 g/dL)', 'Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. Severe Iron Deficiency Anemia (Hb 7.8 g/dL)', 'Vitals: BP 150/93, Pulse 94 bpm, SpO2 98.0%.', 'Severe Iron Deficiency Anemia (Hb 7.8 g/dL)', 'Severe Iron Deficiency Anemia (Hb 7.8 g/dL)', 'R69', 'Initiate medical management for Severe Iron Deficiency Anemia (Hb 7.8 g/dL). Review in OPD in 14 days with investigation results.', '2026-10-29', 'COMPLETED', 1, 'usr_doc_med_1', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('cr_vis_pat_017', 'vis_pat_017', 'pat_017', 'doc_dent_1', 'Presents with symptoms of Severe Acute Pulpitis & Mandibular 1st Molar Abscess', 'Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. Severe Acute Pulpitis & Mandibular 1st Molar Abscess', 'Vitals: BP 152/94, Pulse 97 bpm, SpO2 98.0%.', 'Severe Acute Pulpitis & Mandibular 1st Molar Abscess', 'Severe Acute Pulpitis & Mandibular 1st Molar Abscess', 'R69', 'Initiate medical management for Severe Acute Pulpitis & Mandibular 1st Molar Abscess. Review in OPD in 14 days with investigation results.', '2026-10-29', 'COMPLETED', 1, 'usr_doc_dent_1', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('cr_vis_pat_018', 'vis_pat_018', 'pat_018', 'doc_med_2', 'Presents with symptoms of Chronic Allergic Contact Dermatitis & Numular Eczema', 'Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. Chronic Allergic Contact Dermatitis & Numular Eczema', 'Vitals: BP 154/95, Pulse 75 bpm, SpO2 98.0%.', 'Chronic Allergic Contact Dermatitis & Numular Eczema', 'Chronic Allergic Contact Dermatitis & Numular Eczema', 'R69', 'Initiate medical management for Chronic Allergic Contact Dermatitis & Numular Eczema. Review in OPD in 14 days with investigation results.', '2026-10-29', 'COMPLETED', 1, 'usr_doc_med_2', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('cr_vis_pat_019', 'vis_pat_019', 'pat_019', 'doc_ent_1', 'Presents with symptoms of Allergic Rhinitis with Chronic Maxillary Sinusitis', 'Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. Allergic Rhinitis with Chronic Maxillary Sinusitis', 'Vitals: BP 156/96, Pulse 78 bpm, SpO2 98.0%.', 'Allergic Rhinitis with Chronic Maxillary Sinusitis', 'Allergic Rhinitis with Chronic Maxillary Sinusitis', 'R69', 'Initiate medical management for Allergic Rhinitis with Chronic Maxillary Sinusitis. Review in OPD in 14 days with investigation results.', '2026-10-29', 'COMPLETED', 1, 'usr_doc_ent_1', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('cr_vis_pat_020', 'vis_pat_020', 'pat_020', 'doc_med_3', 'Presents with symptoms of Executive Annual Health Evaluation & Routine Screen', 'Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. Executive Annual Health Evaluation & Routine Screen', 'Vitals: BP 158/97, Pulse 81 bpm, SpO2 98.0%.', 'Executive Annual Health Evaluation & Routine Screen', 'Executive Annual Health Evaluation & Routine Screen', 'R69', 'Initiate medical management for Executive Annual Health Evaluation & Routine Screen. Review in OPD in 14 days with investigation results.', '2026-10-29', 'COMPLETED', 1, 'usr_doc_med_3', '2026-10-15T10:30:00', '2026-10-15T10:30:00')
ON CONFLICT (id) DO UPDATE SET visit_id = EXCLUDED.visit_id, patient_id = EXCLUDED.patient_id, doctor_id = EXCLUDED.doctor_id, presenting_complaint = EXCLUDED.presenting_complaint, history_of_present_illness = EXCLUDED.history_of_present_illness, general_examination = EXCLUDED.general_examination, provisional_diagnosis = EXCLUDED.provisional_diagnosis, final_diagnosis = EXCLUDED.final_diagnosis, icd10_code = EXCLUDED.icd10_code, care_plan = EXCLUDED.care_plan, follow_up_date = EXCLUDED.follow_up_date, status = EXCLUDED.status, version = EXCLUDED.version, created_by_user_id = EXCLUDED.created_by_user_id, created_at = EXCLUDED.created_at, updated_at = EXCLUDED.updated_at;

-- Data: prescriptions (20 records)
INSERT INTO prescriptions (id, visit_id, patient_id, doctor_id, status, version, notes, is_ocr_extracted, is_verified_by_clinician, allergy_warning_acknowledged, created_at, updated_at) VALUES
  ('rx_vis_pat_001', 'vis_pat_001', 'pat_001', 'doc_med_1', 'ACTIVE', 1, 'Take medications strictly after food. Drink plenty of water.', FALSE, TRUE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rx_vis_pat_002', 'vis_pat_002', 'pat_002', 'doc_ortho_1', 'ACTIVE', 1, 'Take medications strictly after food. Drink plenty of water.', FALSE, TRUE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rx_vis_pat_003', 'vis_pat_003', 'pat_003', 'doc_cardio_1', 'ACTIVE', 1, 'Take medications strictly after food. Drink plenty of water.', FALSE, TRUE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rx_vis_pat_004', 'vis_pat_004', 'pat_004', 'doc_med_2', 'ACTIVE', 1, 'Take medications strictly after food. Drink plenty of water.', FALSE, TRUE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rx_vis_pat_005', 'vis_pat_005', 'pat_005', 'doc_ped_1', 'ACTIVE', 1, 'Take medications strictly after food. Drink plenty of water.', FALSE, TRUE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rx_vis_pat_006', 'vis_pat_006', 'pat_006', 'doc_ortho_2', 'ACTIVE', 1, 'Take medications strictly after food. Drink plenty of water.', FALSE, TRUE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rx_vis_pat_007', 'vis_pat_007', 'pat_007', 'doc_med_3', 'ACTIVE', 1, 'Take medications strictly after food. Drink plenty of water.', FALSE, TRUE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rx_vis_pat_008', 'vis_pat_008', 'pat_008', 'doc_ped_2', 'ACTIVE', 1, 'Take medications strictly after food. Drink plenty of water.', FALSE, TRUE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rx_vis_pat_009', 'vis_pat_009', 'pat_009', 'doc_med_1', 'ACTIVE', 1, 'Take medications strictly after food. Drink plenty of water.', FALSE, TRUE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rx_vis_pat_010', 'vis_pat_010', 'pat_010', 'doc_med_2', 'COMPLETED', 1, 'Take medications strictly after food. Drink plenty of water.', FALSE, TRUE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rx_vis_pat_011', 'vis_pat_011', 'pat_011', 'doc_med_3', 'ACTIVE', 1, 'Take medications strictly after food. Drink plenty of water.', FALSE, TRUE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rx_vis_pat_012', 'vis_pat_012', 'pat_012', 'doc_med_1', 'ACTIVE', 1, 'Take medications strictly after food. Drink plenty of water.', FALSE, TRUE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rx_vis_pat_013', 'vis_pat_013', 'pat_013', 'doc_ortho_3', 'ACTIVE', 1, 'Take medications strictly after food. Drink plenty of water.', FALSE, TRUE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rx_vis_pat_014', 'vis_pat_014', 'pat_014', 'doc_med_2', 'ACTIVE', 1, 'Take medications strictly after food. Drink plenty of water.', FALSE, TRUE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rx_vis_pat_015', 'vis_pat_015', 'pat_015', 'doc_med_3', 'COMPLETED', 1, 'Take medications strictly after food. Drink plenty of water.', FALSE, TRUE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rx_vis_pat_016', 'vis_pat_016', 'pat_016', 'doc_med_1', 'ACTIVE', 1, 'Take medications strictly after food. Drink plenty of water.', FALSE, TRUE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rx_vis_pat_017', 'vis_pat_017', 'pat_017', 'doc_dent_1', 'ACTIVE', 1, 'Take medications strictly after food. Drink plenty of water.', FALSE, TRUE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rx_vis_pat_018', 'vis_pat_018', 'pat_018', 'doc_med_2', 'COMPLETED', 1, 'Take medications strictly after food. Drink plenty of water.', FALSE, TRUE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rx_vis_pat_019', 'vis_pat_019', 'pat_019', 'doc_ent_1', 'ACTIVE', 1, 'Take medications strictly after food. Drink plenty of water.', FALSE, TRUE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rx_vis_pat_020', 'vis_pat_020', 'pat_020', 'doc_med_3', 'COMPLETED', 1, 'Take medications strictly after food. Drink plenty of water.', FALSE, TRUE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00')
ON CONFLICT (id) DO UPDATE SET visit_id = EXCLUDED.visit_id, patient_id = EXCLUDED.patient_id, doctor_id = EXCLUDED.doctor_id, status = EXCLUDED.status, version = EXCLUDED.version, notes = EXCLUDED.notes, is_ocr_extracted = EXCLUDED.is_ocr_extracted, is_verified_by_clinician = EXCLUDED.is_verified_by_clinician, allergy_warning_acknowledged = EXCLUDED.allergy_warning_acknowledged, created_at = EXCLUDED.created_at, updated_at = EXCLUDED.updated_at;

-- Data: prescription_items (40 records)
INSERT INTO prescription_items (id, prescription_id, medicine_name, form, dosage, route, frequency, duration_days, timing, instructions, is_dispensed, created_at, updated_at) VALUES
  ('rxi_vis_pat_001_1', 'rx_vis_pat_001', 'Metformin 500mg', 'Tablet', '500mg', 'ORAL', 'BD', 30, 'AFTER_FOOD', 'Take after meals with warm water', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_001_2', 'rx_vis_pat_001', 'Pantoprazole 40mg', 'Tablet', '40mg', 'ORAL', 'OD', 14, 'BEFORE_FOOD', 'Take morning empty stomach 30 mins before breakfast', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_002_1', 'rx_vis_pat_002', 'Metformin 500mg', 'Tablet', '500mg', 'ORAL', 'BD', 5, 'AFTER_FOOD', 'Take after meals with warm water', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_002_2', 'rx_vis_pat_002', 'Pantoprazole 40mg', 'Tablet', '40mg', 'ORAL', 'OD', 14, 'BEFORE_FOOD', 'Take morning empty stomach 30 mins before breakfast', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_003_1', 'rx_vis_pat_003', 'Metformin 500mg', 'Tablet', '500mg', 'ORAL', 'BD', 30, 'AFTER_FOOD', 'Take after meals with warm water', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_003_2', 'rx_vis_pat_003', 'Pantoprazole 40mg', 'Tablet', '40mg', 'ORAL', 'OD', 14, 'BEFORE_FOOD', 'Take morning empty stomach 30 mins before breakfast', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_004_1', 'rx_vis_pat_004', 'Metformin 500mg', 'Tablet', '500mg', 'ORAL', 'BD', 30, 'AFTER_FOOD', 'Take after meals with warm water', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_004_2', 'rx_vis_pat_004', 'Pantoprazole 40mg', 'Tablet', '40mg', 'ORAL', 'OD', 14, 'BEFORE_FOOD', 'Take morning empty stomach 30 mins before breakfast', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_005_1', 'rx_vis_pat_005', 'Metformin 500mg', 'Tablet', '500mg', 'ORAL', 'BD', 5, 'AFTER_FOOD', 'Take after meals with warm water', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_005_2', 'rx_vis_pat_005', 'Pantoprazole 40mg', 'Tablet', '40mg', 'ORAL', 'OD', 14, 'BEFORE_FOOD', 'Take morning empty stomach 30 mins before breakfast', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_006_1', 'rx_vis_pat_006', 'Metformin 500mg', 'Tablet', '500mg', 'ORAL', 'BD', 30, 'AFTER_FOOD', 'Take after meals with warm water', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_006_2', 'rx_vis_pat_006', 'Pantoprazole 40mg', 'Tablet', '40mg', 'ORAL', 'OD', 14, 'BEFORE_FOOD', 'Take morning empty stomach 30 mins before breakfast', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_007_1', 'rx_vis_pat_007', 'Paracetamol 650mg', 'Tablet', '650mg', 'ORAL', 'TID', 5, 'AFTER_FOOD', 'Take after meals with warm water', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_007_2', 'rx_vis_pat_007', 'Pantoprazole 40mg', 'Tablet', '40mg', 'ORAL', 'OD', 14, 'BEFORE_FOOD', 'Take morning empty stomach 30 mins before breakfast', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_008_1', 'rx_vis_pat_008', 'Metformin 500mg', 'Tablet', '500mg', 'ORAL', 'BD', 5, 'AFTER_FOOD', 'Take after meals with warm water', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_008_2', 'rx_vis_pat_008', 'Pantoprazole 40mg', 'Tablet', '40mg', 'ORAL', 'OD', 14, 'BEFORE_FOOD', 'Take morning empty stomach 30 mins before breakfast', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_009_1', 'rx_vis_pat_009', 'Metformin 500mg', 'Tablet', '500mg', 'ORAL', 'BD', 30, 'AFTER_FOOD', 'Take after meals with warm water', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_009_2', 'rx_vis_pat_009', 'Pantoprazole 40mg', 'Tablet', '40mg', 'ORAL', 'OD', 14, 'BEFORE_FOOD', 'Take morning empty stomach 30 mins before breakfast', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_010_1', 'rx_vis_pat_010', 'Metformin 500mg', 'Tablet', '500mg', 'ORAL', 'BD', 30, 'AFTER_FOOD', 'Take after meals with warm water', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_010_2', 'rx_vis_pat_010', 'Pantoprazole 40mg', 'Tablet', '40mg', 'ORAL', 'OD', 14, 'BEFORE_FOOD', 'Take morning empty stomach 30 mins before breakfast', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_011_1', 'rx_vis_pat_011', 'Metformin 500mg', 'Tablet', '500mg', 'ORAL', 'BD', 5, 'AFTER_FOOD', 'Take after meals with warm water', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_011_2', 'rx_vis_pat_011', 'Pantoprazole 40mg', 'Tablet', '40mg', 'ORAL', 'OD', 14, 'BEFORE_FOOD', 'Take morning empty stomach 30 mins before breakfast', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_012_1', 'rx_vis_pat_012', 'Metformin 500mg', 'Tablet', '500mg', 'ORAL', 'BD', 30, 'AFTER_FOOD', 'Take after meals with warm water', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_012_2', 'rx_vis_pat_012', 'Pantoprazole 40mg', 'Tablet', '40mg', 'ORAL', 'OD', 14, 'BEFORE_FOOD', 'Take morning empty stomach 30 mins before breakfast', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_013_1', 'rx_vis_pat_013', 'Metformin 500mg', 'Tablet', '500mg', 'ORAL', 'BD', 30, 'AFTER_FOOD', 'Take after meals with warm water', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_013_2', 'rx_vis_pat_013', 'Pantoprazole 40mg', 'Tablet', '40mg', 'ORAL', 'OD', 14, 'BEFORE_FOOD', 'Take morning empty stomach 30 mins before breakfast', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_014_1', 'rx_vis_pat_014', 'Metformin 500mg', 'Tablet', '500mg', 'ORAL', 'BD', 30, 'AFTER_FOOD', 'Take after meals with warm water', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_014_2', 'rx_vis_pat_014', 'Pantoprazole 40mg', 'Tablet', '40mg', 'ORAL', 'OD', 14, 'BEFORE_FOOD', 'Take morning empty stomach 30 mins before breakfast', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_015_1', 'rx_vis_pat_015', 'Metformin 500mg', 'Tablet', '500mg', 'ORAL', 'BD', 30, 'AFTER_FOOD', 'Take after meals with warm water', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_015_2', 'rx_vis_pat_015', 'Pantoprazole 40mg', 'Tablet', '40mg', 'ORAL', 'OD', 14, 'BEFORE_FOOD', 'Take morning empty stomach 30 mins before breakfast', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_016_1', 'rx_vis_pat_016', 'Metformin 500mg', 'Tablet', '500mg', 'ORAL', 'BD', 30, 'AFTER_FOOD', 'Take after meals with warm water', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_016_2', 'rx_vis_pat_016', 'Pantoprazole 40mg', 'Tablet', '40mg', 'ORAL', 'OD', 14, 'BEFORE_FOOD', 'Take morning empty stomach 30 mins before breakfast', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_017_1', 'rx_vis_pat_017', 'Metformin 500mg', 'Tablet', '500mg', 'ORAL', 'BD', 5, 'AFTER_FOOD', 'Take after meals with warm water', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_017_2', 'rx_vis_pat_017', 'Pantoprazole 40mg', 'Tablet', '40mg', 'ORAL', 'OD', 14, 'BEFORE_FOOD', 'Take morning empty stomach 30 mins before breakfast', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_018_1', 'rx_vis_pat_018', 'Metformin 500mg', 'Tablet', '500mg', 'ORAL', 'BD', 30, 'AFTER_FOOD', 'Take after meals with warm water', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_018_2', 'rx_vis_pat_018', 'Pantoprazole 40mg', 'Tablet', '40mg', 'ORAL', 'OD', 14, 'BEFORE_FOOD', 'Take morning empty stomach 30 mins before breakfast', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_019_1', 'rx_vis_pat_019', 'Metformin 500mg', 'Tablet', '500mg', 'ORAL', 'BD', 30, 'AFTER_FOOD', 'Take after meals with warm water', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_019_2', 'rx_vis_pat_019', 'Pantoprazole 40mg', 'Tablet', '40mg', 'ORAL', 'OD', 14, 'BEFORE_FOOD', 'Take morning empty stomach 30 mins before breakfast', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_020_1', 'rx_vis_pat_020', 'Metformin 500mg', 'Tablet', '500mg', 'ORAL', 'BD', 30, 'AFTER_FOOD', 'Take after meals with warm water', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('rxi_vis_pat_020_2', 'rx_vis_pat_020', 'Pantoprazole 40mg', 'Tablet', '40mg', 'ORAL', 'OD', 14, 'BEFORE_FOOD', 'Take morning empty stomach 30 mins before breakfast', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00')
ON CONFLICT (id) DO UPDATE SET prescription_id = EXCLUDED.prescription_id, medicine_name = EXCLUDED.medicine_name, form = EXCLUDED.form, dosage = EXCLUDED.dosage, route = EXCLUDED.route, frequency = EXCLUDED.frequency, duration_days = EXCLUDED.duration_days, timing = EXCLUDED.timing, instructions = EXCLUDED.instructions, is_dispensed = EXCLUDED.is_dispensed, created_at = EXCLUDED.created_at, updated_at = EXCLUDED.updated_at;

-- Data: lab_orders (10 records)
INSERT INTO lab_orders (id, order_number, visit_id, patient_id, ordered_by_doctor_id, test_name, test_category, status, clinical_indication, specimen_status, is_sensitive, requires_review, published_to_visit, ordered_at, created_at, updated_at) VALUES
  ('lo_vis_pat_001', 'LAB-20261015-001', 'vis_pat_001', 'pat_001', 'doc_med_1', 'Complete Blood Count (CBC)', 'HEMATOLOGY', 'COMPLETED', 'Diagnostic evaluation for Type 2 Diabetes Mellitus with Peripheral Neuropathy', 'COLLECTED', FALSE, FALSE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('lo_vis_pat_002', 'LAB-20261015-002', 'vis_pat_002', 'pat_002', 'doc_ortho_1', 'HbA1c & Fasting Lipid Profile', 'BIOCHEMISTRY', 'COMPLETED', 'Diagnostic evaluation for Acute Lumbar Muscle Sprain & Sciatica', 'COLLECTED', FALSE, FALSE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('lo_vis_pat_003', 'LAB-20261015-003', 'vis_pat_003', 'pat_003', 'doc_cardio_1', 'Complete Blood Count (CBC)', 'HEMATOLOGY', 'COMPLETED', 'Diagnostic evaluation for Essential Hypertension & CAD (Post-PTCA Follow-up)', 'COLLECTED', FALSE, FALSE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('lo_vis_pat_004', 'LAB-20261015-004', 'vis_pat_004', 'pat_004', 'doc_med_2', 'HbA1c & Fasting Lipid Profile', 'BIOCHEMISTRY', 'COMPLETED', 'Diagnostic evaluation for Antenatal Care 26 Weeks Gestation with Mild Anemia', 'COLLECTED', FALSE, FALSE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('lo_vis_pat_005', 'LAB-20261015-005', 'vis_pat_005', 'pat_005', 'doc_ped_1', 'Complete Blood Count (CBC)', 'HEMATOLOGY', 'COMPLETED', 'Diagnostic evaluation for Pediatric Bronchial Asthma with Acute Wheezing', 'COLLECTED', FALSE, FALSE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('lo_vis_pat_006', 'LAB-20261015-006', 'vis_pat_006', 'pat_006', 'doc_ortho_2', 'HbA1c & Fasting Lipid Profile', 'BIOCHEMISTRY', 'ORDERED', 'Diagnostic evaluation for Bilateral Knee Osteoarthritis Grade III', 'COLLECTED', FALSE, FALSE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('lo_vis_pat_007', 'LAB-20261015-007', 'vis_pat_007', 'pat_007', 'doc_med_3', 'Complete Blood Count (CBC)', 'HEMATOLOGY', 'ORDERED', 'Diagnostic evaluation for Acute Febrile Illness - Suspected Dengue Fever', 'COLLECTED', FALSE, FALSE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('lo_vis_pat_008', 'LAB-20261015-008', 'vis_pat_008', 'pat_008', 'doc_ped_2', 'HbA1c & Fasting Lipid Profile', 'BIOCHEMISTRY', 'ORDERED', 'Diagnostic evaluation for Acute Otitis Media & Upper Respiratory Infection', 'COLLECTED', FALSE, FALSE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('lo_vis_pat_009', 'LAB-20261015-009', 'vis_pat_009', 'pat_009', 'doc_med_1', 'Complete Blood Count (CBC)', 'HEMATOLOGY', 'ORDERED', 'Diagnostic evaluation for Chronic Obstructive Pulmonary Disease (COPD) Grade II', 'COLLECTED', FALSE, FALSE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('lo_vis_pat_010', 'LAB-20261015-010', 'vis_pat_010', 'pat_010', 'doc_med_2', 'HbA1c & Fasting Lipid Profile', 'BIOCHEMISTRY', 'ORDERED', 'Diagnostic evaluation for Hypothyroidism with Dyslipidemia & Weight Gain', 'COLLECTED', FALSE, FALSE, TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00', '2026-10-15T10:30:00')
ON CONFLICT (id) DO UPDATE SET order_number = EXCLUDED.order_number, visit_id = EXCLUDED.visit_id, patient_id = EXCLUDED.patient_id, ordered_by_doctor_id = EXCLUDED.ordered_by_doctor_id, test_name = EXCLUDED.test_name, test_category = EXCLUDED.test_category, status = EXCLUDED.status, clinical_indication = EXCLUDED.clinical_indication, specimen_status = EXCLUDED.specimen_status, is_sensitive = EXCLUDED.is_sensitive, requires_review = EXCLUDED.requires_review, published_to_visit = EXCLUDED.published_to_visit, ordered_at = EXCLUDED.ordered_at, created_at = EXCLUDED.created_at, updated_at = EXCLUDED.updated_at;

-- Data: lab_results (5 records)
INSERT INTO lab_results (id, lab_order_id, parameter_name, result_value, unit, reference_range, is_abnormal, is_critical, flag, notes, reported_at, verified_by_user_id, verified_at, created_at, updated_at) VALUES
  ('lr_lo_vis_pat_001', 'lo_vis_pat_001', 'Hemoglobin (Hb)', '12.8', 'g/dL', '11.5 - 16.0 g/dL', FALSE, FALSE, 'NORMAL', 'Verified by Clinical Pathology Lab', '2026-10-15T10:30:00', 'usr_lab_1', '2026-10-15T10:30:00', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('lr_lo_vis_pat_002', 'lo_vis_pat_002', 'Glycated Hemoglobin (HbA1c)', '7.4', '%', '< 5.7% Normal', TRUE, FALSE, 'HIGH', 'Verified by Clinical Pathology Lab', '2026-10-15T10:30:00', 'usr_lab_1', '2026-10-15T10:30:00', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('lr_lo_vis_pat_003', 'lo_vis_pat_003', 'Hemoglobin (Hb)', '12.8', 'g/dL', '11.5 - 16.0 g/dL', FALSE, FALSE, 'NORMAL', 'Verified by Clinical Pathology Lab', '2026-10-15T10:30:00', 'usr_lab_1', '2026-10-15T10:30:00', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('lr_lo_vis_pat_004', 'lo_vis_pat_004', 'Glycated Hemoglobin (HbA1c)', '7.4', '%', '< 5.7% Normal', TRUE, FALSE, 'HIGH', 'Verified by Clinical Pathology Lab', '2026-10-15T10:30:00', 'usr_lab_1', '2026-10-15T10:30:00', '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('lr_lo_vis_pat_005', 'lo_vis_pat_005', 'Hemoglobin (Hb)', '12.8', 'g/dL', '11.5 - 16.0 g/dL', FALSE, FALSE, 'NORMAL', 'Verified by Clinical Pathology Lab', '2026-10-15T10:30:00', 'usr_lab_1', '2026-10-15T10:30:00', '2026-10-15T10:30:00', '2026-10-15T10:30:00')
ON CONFLICT (id) DO UPDATE SET lab_order_id = EXCLUDED.lab_order_id, parameter_name = EXCLUDED.parameter_name, result_value = EXCLUDED.result_value, unit = EXCLUDED.unit, reference_range = EXCLUDED.reference_range, is_abnormal = EXCLUDED.is_abnormal, is_critical = EXCLUDED.is_critical, flag = EXCLUDED.flag, notes = EXCLUDED.notes, reported_at = EXCLUDED.reported_at, verified_by_user_id = EXCLUDED.verified_by_user_id, verified_at = EXCLUDED.verified_at, created_at = EXCLUDED.created_at, updated_at = EXCLUDED.updated_at;

-- Data: bills (20 records)
INSERT INTO bills (id, visit_id, patient_id, invoice_number, subtotal, discount_type, discount_rate, discount_amount, taxable_amount, cgst_amount, sgst_amount, igst_amount, total_tax_amount, total_amount, net_amount, paid_amount, outstanding_balance, status, payment_status, payment_method, billed_by_user_id, billed_at, is_synthetic_pricing, created_at, updated_at) VALUES
  ('bill_vis_pat_001', 'vis_pat_001', 'pat_001', 'INV-20261015-0001', 500.0, 'NONE', 0.0, 0.0, 500.0, 0.0, 0.0, 0.0, 0.0, 500.0, 500.0, 500.0, 0.0, 'PAID', 'PAID', 'CASH', 'usr_bill_1', '2026-10-15T10:30:00', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('bill_vis_pat_002', 'vis_pat_002', 'pat_002', 'INV-20261015-0002', 750.0, 'NONE', 0.0, 0.0, 750.0, 0.0, 0.0, 0.0, 0.0, 750.0, 750.0, 750.0, 0.0, 'PAID', 'PAID', 'CASH', 'usr_bill_1', '2026-10-15T10:30:00', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('bill_vis_pat_003', 'vis_pat_003', 'pat_003', 'INV-20261015-0003', 750.0, 'NONE', 0.0, 0.0, 750.0, 0.0, 0.0, 0.0, 0.0, 750.0, 750.0, 750.0, 0.0, 'PAID', 'PAID', 'CASH', 'usr_bill_1', '2026-10-15T10:30:00', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('bill_vis_pat_004', 'vis_pat_004', 'pat_004', 'INV-20261015-0004', 500.0, 'NONE', 0.0, 0.0, 500.0, 0.0, 0.0, 0.0, 0.0, 500.0, 500.0, 500.0, 0.0, 'PAID', 'PAID', 'CASH', 'usr_bill_1', '2026-10-15T10:30:00', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('bill_vis_pat_005', 'vis_pat_005', 'pat_005', 'INV-20261015-0005', 600.0, 'NONE', 0.0, 0.0, 600.0, 0.0, 0.0, 0.0, 0.0, 600.0, 600.0, 600.0, 0.0, 'PAID', 'PAID', 'CASH', 'usr_bill_1', '2026-10-15T10:30:00', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('bill_vis_pat_006', 'vis_pat_006', 'pat_006', 'INV-20261015-0006', 750.0, 'NONE', 0.0, 0.0, 750.0, 0.0, 0.0, 0.0, 0.0, 750.0, 750.0, 750.0, 0.0, 'PAID', 'PAID', 'CASH', 'usr_bill_1', '2026-10-15T10:30:00', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('bill_vis_pat_007', 'vis_pat_007', 'pat_007', 'INV-20261015-0007', 500.0, 'NONE', 0.0, 0.0, 500.0, 0.0, 0.0, 0.0, 0.0, 500.0, 500.0, 500.0, 0.0, 'PAID', 'PAID', 'CASH', 'usr_bill_1', '2026-10-15T10:30:00', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('bill_vis_pat_008', 'vis_pat_008', 'pat_008', 'INV-20261015-0008', 600.0, 'NONE', 0.0, 0.0, 600.0, 0.0, 0.0, 0.0, 0.0, 600.0, 600.0, 600.0, 0.0, 'PAID', 'PAID', 'CASH', 'usr_bill_1', '2026-10-15T10:30:00', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('bill_vis_pat_009', 'vis_pat_009', 'pat_009', 'INV-20261015-0009', 500.0, 'NONE', 0.0, 0.0, 500.0, 0.0, 0.0, 0.0, 0.0, 500.0, 500.0, 500.0, 0.0, 'PAID', 'PAID', 'CASH', 'usr_bill_1', '2026-10-15T10:30:00', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('bill_vis_pat_010', 'vis_pat_010', 'pat_010', 'INV-20261015-0010', 500.0, 'NONE', 0.0, 0.0, 500.0, 0.0, 0.0, 0.0, 0.0, 500.0, 500.0, 500.0, 0.0, 'PAID', 'PAID', 'CASH', 'usr_bill_1', '2026-10-15T10:30:00', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('bill_vis_pat_011', 'vis_pat_011', 'pat_011', 'INV-20261015-0011', 500.0, 'NONE', 0.0, 0.0, 500.0, 0.0, 0.0, 0.0, 0.0, 500.0, 500.0, 500.0, 0.0, 'PAID', 'PAID', 'CASH', 'usr_bill_1', '2026-10-15T10:30:00', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('bill_vis_pat_012', 'vis_pat_012', 'pat_012', 'INV-20261015-0012', 500.0, 'NONE', 0.0, 0.0, 500.0, 0.0, 0.0, 0.0, 0.0, 500.0, 500.0, 500.0, 0.0, 'PAID', 'PAID', 'CASH', 'usr_bill_1', '2026-10-15T10:30:00', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('bill_vis_pat_013', 'vis_pat_013', 'pat_013', 'INV-20261015-0013', 750.0, 'NONE', 0.0, 0.0, 750.0, 0.0, 0.0, 0.0, 0.0, 750.0, 750.0, 750.0, 0.0, 'PAID', 'PAID', 'CASH', 'usr_bill_1', '2026-10-15T10:30:00', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('bill_vis_pat_014', 'vis_pat_014', 'pat_014', 'INV-20261015-0014', 500.0, 'NONE', 0.0, 0.0, 500.0, 0.0, 0.0, 0.0, 0.0, 500.0, 500.0, 500.0, 0.0, 'PAID', 'PAID', 'CASH', 'usr_bill_1', '2026-10-15T10:30:00', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('bill_vis_pat_015', 'vis_pat_015', 'pat_015', 'INV-20261015-0015', 500.0, 'NONE', 0.0, 0.0, 500.0, 0.0, 0.0, 0.0, 0.0, 500.0, 500.0, 500.0, 0.0, 'PAID', 'PAID', 'CASH', 'usr_bill_1', '2026-10-15T10:30:00', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('bill_vis_pat_016', 'vis_pat_016', 'pat_016', 'INV-20261015-0016', 500.0, 'NONE', 0.0, 0.0, 500.0, 0.0, 0.0, 0.0, 0.0, 500.0, 500.0, 500.0, 0.0, 'PAID', 'PAID', 'CASH', 'usr_bill_1', '2026-10-15T10:30:00', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('bill_vis_pat_017', 'vis_pat_017', 'pat_017', 'INV-20261015-0017', 500.0, 'NONE', 0.0, 0.0, 500.0, 0.0, 0.0, 0.0, 0.0, 500.0, 500.0, 500.0, 0.0, 'PAID', 'PAID', 'CASH', 'usr_bill_1', '2026-10-15T10:30:00', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('bill_vis_pat_018', 'vis_pat_018', 'pat_018', 'INV-20261015-0018', 500.0, 'NONE', 0.0, 0.0, 500.0, 0.0, 0.0, 0.0, 0.0, 500.0, 500.0, 500.0, 0.0, 'PAID', 'PAID', 'CASH', 'usr_bill_1', '2026-10-15T10:30:00', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('bill_vis_pat_019', 'vis_pat_019', 'pat_019', 'INV-20261015-0019', 500.0, 'NONE', 0.0, 0.0, 500.0, 0.0, 0.0, 0.0, 0.0, 500.0, 500.0, 500.0, 0.0, 'PAID', 'PAID', 'CASH', 'usr_bill_1', '2026-10-15T10:30:00', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('bill_vis_pat_020', 'vis_pat_020', 'pat_020', 'INV-20261015-0020', 500.0, 'NONE', 0.0, 0.0, 500.0, 0.0, 0.0, 0.0, 0.0, 500.0, 500.0, 500.0, 0.0, 'PAID', 'PAID', 'CASH', 'usr_bill_1', '2026-10-15T10:30:00', FALSE, '2026-10-15T10:30:00', '2026-10-15T10:30:00')
ON CONFLICT (id) DO UPDATE SET visit_id = EXCLUDED.visit_id, patient_id = EXCLUDED.patient_id, invoice_number = EXCLUDED.invoice_number, subtotal = EXCLUDED.subtotal, discount_type = EXCLUDED.discount_type, discount_rate = EXCLUDED.discount_rate, discount_amount = EXCLUDED.discount_amount, taxable_amount = EXCLUDED.taxable_amount, cgst_amount = EXCLUDED.cgst_amount, sgst_amount = EXCLUDED.sgst_amount, igst_amount = EXCLUDED.igst_amount, total_tax_amount = EXCLUDED.total_tax_amount, total_amount = EXCLUDED.total_amount, net_amount = EXCLUDED.net_amount, paid_amount = EXCLUDED.paid_amount, outstanding_balance = EXCLUDED.outstanding_balance, status = EXCLUDED.status, payment_status = EXCLUDED.payment_status, payment_method = EXCLUDED.payment_method, billed_by_user_id = EXCLUDED.billed_by_user_id, billed_at = EXCLUDED.billed_at, is_synthetic_pricing = EXCLUDED.is_synthetic_pricing, created_at = EXCLUDED.created_at, updated_at = EXCLUDED.updated_at;

-- Data: medicine_inventory (28 records)
INSERT INTO medicine_inventory (id, medicine_code, name, generic_name, strength, dosage_form, batch_number, expiry_date, available_quantity, reorder_level, unit_price, is_synthetic_price, tax_classification, tax_rate_percent, supplier_name, supplier_contact, is_active, created_at, updated_at) VALUES
  ('inv_med_001', 'MED-001', 'Paracetamol 650mg', 'Paracetamol', '650mg', 'Tablet', 'BATCH-2026-A1', '2027-12-31', 450, 50, 2.5, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_002', 'MED-002', 'Metformin 500mg', 'Metformin Hydrochloride', '500mg', 'Tablet', 'BATCH-2026-A2', '2027-12-31', 600, 100, 3.2, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_003', 'MED-003', 'Amlodipine 5mg', 'Amlodipine Besylate', '5mg', 'Tablet', 'BATCH-2026-A3', '2027-12-31', 350, 50, 4.0, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_004', 'MED-004', 'Telmisartan 40mg', 'Telmisartan', '40mg', 'Tablet', 'BATCH-2026-A4', '2027-12-31', 280, 40, 8.5, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_005', 'MED-005', 'Pantoprazole 40mg', 'Pantoprazole Sodium', '40mg', 'Tablet', 'BATCH-2026-A5', '2027-12-31', 500, 60, 6.0, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_006', 'MED-006', 'Amoxicillin + Clavulanic Acid 625mg', 'Amoxicillin Clavulanate', '625mg', 'Tablet', 'BATCH-2026-A6', '2027-12-31', 240, 30, 22.0, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_007', 'MED-007', 'Cetirizine 10mg', 'Cetirizine Dihydrochloride', '10mg', 'Tablet', 'BATCH-2026-A7', '2027-12-31', 400, 50, 3.0, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_008', 'MED-008', 'Azithromycin 500mg', 'Azithromycin Dihydrate', '500mg', 'Tablet', 'BATCH-2026-A8', '2027-12-31', 180, 25, 24.5, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_009', 'MED-009', 'Ciprofloxacin 500mg', 'Ciprofloxacin Hydrochloride', '500mg', 'Tablet', 'BATCH-2026-A9', '2027-12-31', 220, 30, 12.0, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_010', 'MED-010', 'Ibuprofen 400mg', 'Ibuprofen', '400mg', 'Tablet', 'BATCH-2026-B1', '2027-12-31', 320, 40, 3.8, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_011', 'MED-011', 'Omeprazole 20mg', 'Omeprazole Magnesium', '20mg', 'Capsule', 'BATCH-2026-B2', '2027-12-31', 410, 50, 4.5, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_012', 'MED-012', 'Atorvastatin 10mg', 'Atorvastatin Calcium', '10mg', 'Tablet', 'BATCH-2026-B3', '2027-12-31', 290, 40, 9.8, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_013', 'MED-013', 'Levothyroxine 50mcg', 'Levothyroxine Sodium', '50mcg', 'Tablet', 'BATCH-2026-B4', '2027-12-31', 300, 50, 2.2, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_014', 'MED-014', 'Salbutamol Inhaler 100mcg', 'Salbutamol Sulfate', '100mcg/dose', 'Inhaler', 'BATCH-2026-B5', '2027-12-31', 85, 15, 145.0, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_015', 'MED-015', 'Oral Rehydration Salts (ORS)', 'Sodium Chloride / Dextrose', '21.8g', 'Sachet', 'BATCH-2026-B6', '2027-12-31', 500, 100, 18.0, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_016', 'MED-016', 'Ranitidine 150mg', 'Ranitidine Hydrochloride', '150mg', 'Tablet', 'BATCH-2026-B7', '2027-12-31', 250, 40, 2.8, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_017', 'MED-017', 'Losartan Potassium 50mg', 'Losartan Potassium', '50mg', 'Tablet', 'BATCH-2026-B8', '2027-12-31', 210, 30, 6.5, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_018', 'MED-018', 'Hydrochlorothiazide 12.5mg', 'Hydrochlorothiazide', '12.5mg', 'Tablet', 'BATCH-2026-B9', '2027-12-31', 190, 25, 3.5, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_019', 'MED-019', 'Cefixime 200mg', 'Cefixime Trihydrate', '200mg', 'Tablet', 'BATCH-2026-C1', '2027-12-31', 160, 25, 18.5, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_020', 'MED-020', 'Doxycycline 100mg', 'Doxycycline Hyclate', '100mg', 'Capsule', 'BATCH-2026-C2', '2027-12-31', 140, 20, 8.0, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_021', 'MED-021', 'Diclofenac Sodium 50mg', 'Diclofenac Sodium', '50mg', 'Tablet', 'BATCH-2026-C3', '2027-12-31', 380, 50, 4.2, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_022', 'MED-022', 'Tramadol Hydrochloride 50mg', 'Tramadol HCl', '50mg', 'Capsule', 'BATCH-2026-C4', '2027-12-31', 95, 20, 14.0, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_023', 'MED-023', 'Montelukast 10mg', 'Montelukast Sodium', '10mg', 'Tablet', 'BATCH-2026-C5', '2027-12-31', 210, 30, 11.5, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_024', 'MED-024', 'Clopidogrel 75mg', 'Clopidogrel Bisulfate', '75mg', 'Tablet', 'BATCH-2026-C6', '2027-12-31', 175, 25, 15.0, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_025', 'MED-025', 'Insulin Glargine 100 IU/ml', 'Insulin Glargine', '100 IU/ml', 'Vial', 'BATCH-2026-C7', '2027-12-31', 60, 15, 520.0, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_026', 'MED-026', 'Gliclazide 80mg', 'Gliclazide', '80mg', 'Tablet', 'BATCH-2026-C8', '2027-12-31', 220, 30, 7.2, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_027', 'MED-027', 'Ferrous Ascorbate + Folic Acid', 'Iron + Folic Acid', '100mg/1.5mg', 'Tablet', 'BATCH-2026-C9', '2027-12-31', 420, 60, 8.5, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00'),
  ('inv_med_028', 'MED-028', 'Calcium Carbonate + Vit D3', 'Calcium Carbonate + Cholecalciferol', '500mg/250IU', 'Tablet', 'BATCH-2026-D1', '2027-12-31', 360, 50, 7.0, FALSE, 'GST_5', 5.0, 'SMVMCH Central Pharmacy Depot', 'depot@smvmch.ac.in', TRUE, '2026-10-15T10:30:00', '2026-10-15T10:30:00')
ON CONFLICT (id) DO UPDATE SET medicine_code = EXCLUDED.medicine_code, name = EXCLUDED.name, generic_name = EXCLUDED.generic_name, strength = EXCLUDED.strength, dosage_form = EXCLUDED.dosage_form, batch_number = EXCLUDED.batch_number, expiry_date = EXCLUDED.expiry_date, available_quantity = EXCLUDED.available_quantity, reorder_level = EXCLUDED.reorder_level, unit_price = EXCLUDED.unit_price, is_synthetic_price = EXCLUDED.is_synthetic_price, tax_classification = EXCLUDED.tax_classification, tax_rate_percent = EXCLUDED.tax_rate_percent, supplier_name = EXCLUDED.supplier_name, supplier_contact = EXCLUDED.supplier_contact, is_active = EXCLUDED.is_active, created_at = EXCLUDED.created_at, updated_at = EXCLUDED.updated_at;
