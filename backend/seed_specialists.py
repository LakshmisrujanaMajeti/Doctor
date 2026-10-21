import sys
from app.core.database import SessionLocal, Base, engine
from app.models.user import User, Role
from app.models.department import Department
from app.models.doctor import Doctor
from app.core.security import get_password_hash

def seed_specialists():
    db = SessionLocal()
    try:
        doctor_role = db.query(Role).filter(Role.name == "doctor").first()
        if not doctor_role:
            doctor_role = Role(name="doctor", description="Hospital doctor role")
            db.add(doctor_role)
            db.flush()

        depts = [
            ("General Medicine", "MED", "Internal medicine, acute infections, lifestyle disorders"),
            ("Pulmonology", "PULM", "Asthma, chronic cough, COPD, breathing difficulty, wheezing, pneumonia"),
            ("Cardiology", "CARD", "Chest pain, palpitations, hypertension, breathlessness, cardiac evaluation"),
            ("Pediatrics", "PED", "Comprehensive infant, child, and adolescent healthcare"),
            ("Orthopedics", "ORTH", "Bone, joint, spine, and trauma consultations"),
            ("Dermatology", "DERM", "Skin allergy, acne, rashes, eczema, hair loss, psoriasis"),
            ("Endocrinology", "ENDO", "Thyroid disorder, uncontrolled diabetes, hormonal imbalance, metabolic disorder"),
            ("Gastroenterology", "GASTRO", "Acid reflux, GERD, abdominal pain, gastritis, liver disorders, jaundice"),
            ("Neurology", "NEURO", "Migraine, headache, seizures, numbness, tremors, nerve disorders"),
            ("Oncology", "ONCO", "Cancer screening, tumor evaluation, unexplained weight loss, oncology follow-up"),
            ("Nephrology", "NEPH", "Kidney stones, renal failure, pedal edema, proteinuria, CKD"),
            ("Gynecology", "GYN", "Antenatal care (ANC), pregnancy, menstrual issues, PCOS, pelvic pain"),
            ("Dental / Maxillofacial Surgery", "DENT", "Oral, dental, and maxillofacial surgery OPD"),
            ("ENT", "ENT", "Ear, nose, throat and head-neck consultations"),
        ]

        dept_map = {}
        for name, code, desc in depts:
            d = db.query(Department).filter((Department.code == code) | (Department.name == name)).first()
            if not d:
                d = Department(name=name, code=code, description=desc, is_active=True)
                db.add(d)
                db.flush()
            else:
                d.name = name
                d.code = code
                d.description = desc
                db.flush()
            dept_map[name] = d

        specialists = [
            ("doctor@smvmch.ac.in", "Dr. Sarah Chen, MD", "+1555000012", "General Medicine", "General Medicine", "Room 101", "MBBS, MD (General Medicine)", 500.0),
            ("pulmonology@smvmch.ac.in", "Dr. Harish Patel, MD", "+1555000031", "Pulmonology", "Pulmonology", "Room 108", "MBBS, MD (Pulmonary Medicine)", 650.0),
            ("cardiology@smvmch.ac.in", "Dr. R. Venkatesh, DM", "+1555000032", "Cardiology", "Cardiology", "Room 102", "MBBS, MD, DM (Cardiology)", 750.0),
            ("pediatrics@smvmch.ac.in", "Dr. Ananya Roy, MD", "+1555000033", "Pediatrics", "Pediatrics", "Room 103", "MBBS, MD (Pediatrics)", 600.0),
            ("orthopedics@smvmch.ac.in", "Dr. Vikram Mehta, MS", "+1555000034", "Orthopedics", "Orthopedics", "Room 104", "MBBS, MS (Orthopedics)", 700.0),
            ("dermatology@smvmch.ac.in", "Dr. Ananya Rao, MD", "+1555000035", "Dermatology", "Dermatology", "Room 105", "MBBS, MD (DVL)", 600.0),
            ("endocrinology@smvmch.ac.in", "Dr. S. Kulkarni, DM", "+1555000036", "Endocrinology", "Endocrinology", "Room 106", "MBBS, MD, DM (Endocrinology)", 700.0),
            ("gastroenterology@smvmch.ac.in", "Dr. Pradeep Menon, DM", "+1555000037", "Gastroenterology", "Gastroenterology", "Room 107", "MBBS, MD, DM (Gastroenterology)", 750.0),
            ("neurology@smvmch.ac.in", "Dr. Vikram Seth, DM", "+1555000038", "Neurology", "Neurology", "Room 109", "MBBS, MD, DM (Neurology)", 800.0),
            ("oncology@smvmch.ac.in", "Dr. Malini Iyer, MD DM", "+1555000039", "Oncology", "Oncology", "Room 110", "MBBS, MD, DM (Medical Oncology)", 900.0),
            ("nephrology@smvmch.ac.in", "Dr. Gautam Das, DM", "+1555000040", "Nephrology", "Nephrology", "Room 111", "MBBS, MD, DM (Nephrology)", 750.0),
            ("gynecology@smvmch.ac.in", "Dr. Radhika Nair, MS DGO", "+1555000041", "Gynecology", "Gynecology", "Room 112", "MBBS, MS, DGO (Obstetrics & Gynecology)", 600.0),
            ("dental@smvmch.ac.in", "Dr. M. Arunraj, MDS", "+1555000042", "Dental / Maxillofacial Surgery", "Dental Surgery", "Room 113", "BDS, MDS (Oral & Maxillofacial)", 500.0),
            ("ent@smvmch.ac.in", "Dr. Kavita Nair, MS ENT", "+1555000043", "ENT", "ENT / Otorhinolaryngology", "Room 114", "MBBS, MS (ENT)", 550.0),
        ]

        for email, full_name, phone, dept_name, spec, room, qual, fee in specialists:
            user = db.query(User).filter(User.email == email).first()
            if not user:
                user = User(
                    email=email,
                    full_name=full_name,
                    phone=phone,
                    hashed_password=get_password_hash("Doctor@123"),
                    role_id=doctor_role.id,
                    is_active=True,
                    is_verified=True,
                )
                db.add(user)
                db.flush()
            else:
                user.full_name = full_name
                user.hashed_password = get_password_hash("Doctor@123")
                user.is_active = True
                user.role_id = doctor_role.id
                db.flush()

            dept_obj = dept_map.get(dept_name)
            doc = db.query(Doctor).filter(Doctor.user_id == user.id).first()
            if not doc:
                doc = Doctor(
                    user_id=user.id,
                    department_id=dept_obj.id if dept_obj else None,
                    qualification=qual,
                    specialization=spec,
                    registration_number=f"MCI-SMVMCH-{room.replace(' ', '')}",
                    room_number=f"{room}, OPD Block A",
                    consultation_fee=fee,
                    is_available=True,
                )
                db.add(doc)
                db.flush()
            else:
                doc.department_id = dept_obj.id if dept_obj else doc.department_id
                doc.qualification = qual
                doc.specialization = spec
                doc.room_number = f"{room}, OPD Block A"
                doc.consultation_fee = fee
                doc.is_available = True
                db.flush()
            print(f"Doctor seeded: {full_name} ({email}) -> {dept_name} ({room})")

        db.commit()
        print("All specialist doctors seeded successfully!")
    finally:
        db.close()

if __name__ == "__main__":
    seed_specialists()
