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

