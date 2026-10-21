import sqlite3

conn = sqlite3.connect('opd_connect.db')
cur = conn.cursor()

# Get Pulmonology department and doctor
cur.execute("""
    SELECT d.id, doc.id, u.full_name, u.email 
    FROM departments d 
    JOIN doctors doc ON doc.department_id = d.id 
    JOIN users u ON doc.user_id = u.id 
    WHERE u.email = 'pulmonology@smvmch.ac.in'
""")
row = cur.fetchone()
print("Found Pulmonology:", row)
dept_id, doc_id, doc_name, email = row

# Update Uday's visit
cur.execute("""
    UPDATE opd_visits 
    SET department_id = ?, doctor_id = ?
    WHERE patient_id IN (SELECT id FROM patients WHERE full_name = 'Uday')
""", (dept_id, doc_id))
conn.commit()

# Verify
cur.execute("""
    SELECT v.id, v.visit_number, p.full_name, d.name, u.full_name, u.email 
    FROM opd_visits v 
    JOIN patients p ON v.patient_id = p.id 
    LEFT JOIN departments d ON v.department_id = d.id 
    LEFT JOIN doctors doc ON v.doctor_id = doc.id 
    LEFT JOIN users u ON doc.user_id = u.id 
    WHERE p.full_name = 'Uday'
""")
print("Updated visit:", cur.fetchone())
conn.close()
