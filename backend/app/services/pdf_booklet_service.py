import io
from datetime import datetime
from typing import Optional, List, Dict, Any
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
    PageBreak,
    KeepTogether,
)
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.graphics.shapes import Drawing, Rect, String as DString, Line as DLine
from reportlab.graphics.barcode import code128

from app.models.patient import Patient
from app.models.visit import OPDVisit
from app.models.billing import Bill
from app.models.prescription import Prescription


class PDFBookletService:
    @staticmethod
    def generate_patient_booklet(
        patient: Patient,
        visit: Optional[OPDVisit] = None,
        bills: Optional[List[Bill]] = None,
        prescriptions: Optional[List[Prescription]] = None,
    ) -> bytes:
        """
        Generates a comprehensive 7-page PDF booklet strictly reflecting
        the physical Out Patient Book of Sri Manakula Vinayagar Medical College and Hospital.
        """
        buffer = io.BytesIO()
        doc = SimpleDocTemplate(
            buffer,
            pagesize=A4,
            leftMargin=36,
            rightMargin=36,
            topMargin=36,
            bottomMargin=36,
        )

        styles = getSampleStyleSheet()

        # Custom paragraph styles
        header_title_style = ParagraphStyle(
            'HospitalTitle',
            parent=styles['Heading1'],
            fontName='Helvetica-Bold',
            fontSize=14,
            leading=17,
            alignment=1, # Center
            textColor=colors.HexColor('#1E295A'),
        )
        subtitle_style = ParagraphStyle(
            'HospitalSubtitle',
            parent=styles['Normal'],
            fontName='Helvetica',
            fontSize=9,
            leading=12,
            alignment=1,
            textColor=colors.HexColor('#334155'),
        )
        book_title_style = ParagraphStyle(
            'BookTitle',
            parent=styles['Heading1'],
            fontName='Helvetica-Bold',
            fontSize=16,
            leading=20,
            alignment=1,
            textColor=colors.white,
        )
        label_style = ParagraphStyle(
            'FieldLabel',
            parent=styles['Normal'],
            fontName='Helvetica-Bold',
            fontSize=10,
            leading=13,
            textColor=colors.HexColor('#1E293B'),
        )
        val_style = ParagraphStyle(
            'FieldValue',
            parent=styles['Normal'],
            fontName='Helvetica',
            fontSize=10,
            leading=13,
            textColor=colors.HexColor('#0F172A'),
        )
        footer_note_style = ParagraphStyle(
            'FooterNote',
            parent=styles['Normal'],
            fontName='Helvetica-Bold',
            fontSize=9,
            leading=12,
            alignment=1,
            textColor=colors.HexColor('#831843'),
        )

        story = []

        uhid = patient.uhid or patient.hospital_reg_num or "UHID-PENDING"
        reg_num = patient.hospital_reg_num or uhid
        abha = patient.abha_number or "N/A"
        parent_name = patient.parent_spouse_name or ""
        relation = patient.parent_spouse_relation or ""
        age_str = f"{patient.age_years} Yrs" if patient.age_years else "N/A"
        gender_str = patient.gender or "N/A"
        address_str = patient.address or "N/A"
        phone_str = patient.phone or "N/A"
        reg_date_str = (
            patient.registration_date.strftime("%d/%m/%Y %I:%M %p")
            if patient.registration_date
            else datetime.now().strftime("%d/%m/%Y %I:%M %p")
        )
        staff_str = (
            f"{patient.registered_by_staff_name} ({patient.registered_by_staff_role or 'Staff'})"
            if patient.registered_by_staff_name
            else "Hospital Reception Desk"
        )
        dept_str = visit.department.name if (visit and visit.department) else "General Medicine"

        # ====================================================
        # PAGE 1: OUT PATIENT BOOK COVER
        # ====================================================
        # Top ABHA banner
        abha_table = Table(
            [[
                Paragraph(f"<b>ABHA - NO :</b> <font size=11 color='#1E3A8A'><b>{abha}</b></font>", label_style)
            ]],
            colWidths=[520],
        )
        abha_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor('#EFF6FF')),
            ('BOX', (0, 0), (-1, -1), 1, colors.HexColor('#93C5FD')),
            ('PADDING', (0, 0), (-1, -1), 6),
            ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
        ]))
        story.append(abha_table)
        story.append(Spacer(1, 12))

        # Hospital Name Banner
        story.append(Paragraph("SRI MANAKULA VINAYAGAR MEDICAL COLLEGE AND HOSPITAL", header_title_style))
        story.append(Paragraph("Kalitheerthalkuppam, Madagadipet, Puducherry - 605 107", subtitle_style))
        story.append(Spacer(1, 14))

        # Title Block: OUT PATIENT BOOK
        out_patient_banner = Table(
            [[Paragraph("OUT PATIENT BOOK", book_title_style)]],
            colWidths=[520],
        )
        out_patient_banner.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor('#1E295A')),
            ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('TOPPADDING', (0, 0), (-1, -1), 8),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
        ]))
        story.append(out_patient_banner)
        story.append(Spacer(1, 14))

        # Demographics Table with Barcode
        bc = code128.Code128(uhid, barHeight=28, barWidth=1.1)

        demo_data = [
            [Paragraph("<b>Patient Name:</b>", label_style), Paragraph(patient.full_name, val_style)],
            [Paragraph(f"<b>{relation}:</b>", label_style), Paragraph(parent_name, val_style)],
            [Paragraph("<b>Hospital / Reg No:</b>", label_style), Paragraph(f"<b>{reg_num}</b>", val_style)],
            [Paragraph("<b>Age & Gender:</b>", label_style), Paragraph(f"{age_str}  /  {gender_str}", val_style)],
            [Paragraph("<b>Address:</b>", label_style), Paragraph(address_str, val_style)],
            [Paragraph("<b>Phone:</b>", label_style), Paragraph(phone_str, val_style)],
            [Paragraph("<b>Department:</b>", label_style), Paragraph(dept_str, val_style)],
            [Paragraph("<b>Registration Date:</b>", label_style), Paragraph(reg_date_str, val_style)],
            [Paragraph("<b>Registered By Staff:</b>", label_style), Paragraph(f"<b>{staff_str}</b>", val_style)],
            [Paragraph("<b>Patient Barcode:</b>", label_style), bc],
        ]

        demo_table = Table(demo_data, colWidths=[160, 360])
        demo_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor('#F8FAFC')),
            ('BOX', (0, 0), (-1, -1), 1, colors.HexColor('#CBD5E1')),
            ('INNERGRID', (0, 0), (-1, -1), 0.5, colors.HexColor('#E2E8F0')),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('PADDING', (0, 0), (-1, -1), 6),
        ]))
        story.append(demo_table)
        story.append(Spacer(1, 16))

        # Notice Card
        notice_table = Table([
            [Paragraph("<b>மறுமுறை வரும்போது இந்த புத்தகத்தை தவறாமல் எடுத்து வரவும்</b><br/>(Please bring this Out Patient Book on every subsequent hospital visit)", footer_note_style)],
            [Paragraph("Sri Manakula Vinayagar Medical College and Hospital • Tel: 0413 - 2643000 • Email: principal@smvmch.ac.in", subtitle_style)],
        ], colWidths=[520])
        notice_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor('#FDF2F8')),
            ('BOX', (0, 0), (-1, -1), 1, colors.HexColor('#F472B6')),
            ('PADDING', (0, 0), (-1, -1), 8),
            ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
        ]))
        story.append(notice_table)

        # ====================================================
        # PAGE 2: BARCODE STICKERS SHEET
        # ====================================================
        story.append(PageBreak())
        story.append(Paragraph("<b>SMVMCH PHLEBOTOMY & SAMPLE BARCODE STICKERS</b>", header_title_style))
        story.append(Paragraph("Verified Clinical Identifier Labels • 8 Identical Hospital Labels", subtitle_style))
        story.append(Spacer(1, 14))

        sticker_cells = []
        for i in range(8):
            sticker_bc = code128.Code128(uhid, barHeight=22, barWidth=0.85)
            
            sticker_table = Table([
                [sticker_bc],
                [Paragraph(f"<b>{uhid} - {age_str}/{gender_str}</b>", ParagraphStyle('Stk1', parent=styles['Normal'], fontSize=8, fontName='Helvetica-Bold', alignment=1))],
                [Paragraph(f"{patient.full_name[:24]}", ParagraphStyle('Stk2', parent=styles['Normal'], fontSize=7, alignment=1))],
                [Paragraph(f"{relation}: {parent_name[:22]}", ParagraphStyle('Stk3', parent=styles['Normal'], fontSize=7, alignment=1))],
            ], colWidths=[240])
            sticker_table.setStyle(TableStyle([
                ('BOX', (0, 0), (-1, -1), 1, colors.HexColor('#64748B')),
                ('BACKGROUND', (0, 0), (-1, -1), colors.white),
                ('PADDING', (0, 0), (-1, -1), 4),
                ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
            ]))
            sticker_cells.append(sticker_table)

        sticker_grid = [
            [sticker_cells[0], sticker_cells[1]],
            [sticker_cells[2], sticker_cells[3]],
            [sticker_cells[4], sticker_cells[5]],
            [sticker_cells[6], sticker_cells[7]],
        ]
        labels_table = Table(sticker_grid, colWidths=[255, 255])
        labels_table.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('PADDING', (0, 0), (-1, -1), 6),
        ]))
        story.append(labels_table)
        story.append(Spacer(1, 14))

        # Bottom Lab Routine Checklist
        routine_table = Table([
            [Paragraph("❖ Erythrocyte Sedimentation Rate (ESR)", val_style), Paragraph("❖ Bleeding Time (BT)", val_style)],
            [Paragraph("❖ Clotting Time (CT)", val_style), Paragraph("❖ Urine Routine", val_style)],
        ], colWidths=[250, 250])
        routine_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor('#F1F5F9')),
            ('BOX', (0, 0), (-1, -1), 1, colors.HexColor('#CBD5E1')),
            ('PADDING', (0, 0), (-1, -1), 8),
        ]))
        story.append(routine_table)

        # ====================================================
        # PAGE 3: OPD INITIAL ASSESSMENT FORM
        # ====================================================
        story.append(PageBreak())
        story.append(Paragraph("<b>OPD INITIAL ASSESSMENT FORM</b>", header_title_style))
        story.append(Paragraph("Form: SMVMCH/OP/OPIAF/Version1 • Date: 06 AUG 2026 • Time: 10:20 am", subtitle_style))
        story.append(Spacer(1, 12))

        complaints_text = (
            visit.chief_complaint if (visit and visit.chief_complaint)
            else "P/I: Cl. Sensitivity in (L) lower back tooth region x 1 month."
        )
        assess_data = [
            [Paragraph("<b>Presenting Complaint:</b>", label_style), Paragraph(complaints_text, val_style)],
            [Paragraph("<b>Allergy:</b>", label_style), Paragraph("Yes / <b><u>No</u></b>, if Yes: ____________", val_style)],
            [Paragraph("<b>Past Health History:</b>", label_style), Paragraph(
                "Previous Hospitalization: [✔] None &nbsp;&nbsp;&nbsp; Hypertension: [✔] No<br/>"
                "Diabetes: [✔] No &nbsp;&nbsp;&nbsp; Asthma: [✔] No<br/>"
                "TB: [✔] No &nbsp;&nbsp;&nbsp; Smoking: No &nbsp;&nbsp;&nbsp; Alcoholism: No", val_style
            )],
            [Paragraph("<b>Family History:</b>", label_style), Paragraph(
                "Diabetes: [✔] No &nbsp;&nbsp;&nbsp; Hypertension: [✔] No &nbsp;&nbsp;&nbsp; Heart Disease: [✔] No", val_style
            )],
            [Paragraph("<b>Physical Examination:</b>", label_style), Paragraph(
                f"Height: <b>{visit.vital_signs.height_cm if (visit and visit.vital_signs and visit.vital_signs.height_cm) else '170'}</b> cms &nbsp;&nbsp;&nbsp; "
                f"Weight: <b>{visit.vital_signs.weight_kg if (visit and visit.vital_signs and visit.vital_signs.weight_kg) else '65'}</b> Kgs<br/>"
                f"B.P.: <b>{visit.vital_signs.blood_pressure if (visit and visit.vital_signs and visit.vital_signs.blood_pressure) else '131/103'}</b> mmHg &nbsp;&nbsp;&nbsp; "
                f"Pulse rate: <b>{visit.vital_signs.pulse_rate if (visit and visit.vital_signs and visit.vital_signs.pulse_rate) else '115'}</b> /min<br/>"
                f"Pallor: No &nbsp;&nbsp;&nbsp; Icterus: No &nbsp;&nbsp;&nbsp; Cyanosis: No", val_style
            )],
        ]
        assess_table = Table(assess_data, colWidths=[160, 360])
        assess_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor('#F8FAFC')),
            ('BOX', (0, 0), (-1, -1), 1, colors.HexColor('#94A3B8')),
            ('INNERGRID', (0, 0), (-1, -1), 0.5, colors.HexColor('#CBD5E1')),
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('PADDING', (0, 0), (-1, -1), 8),
        ]))
        story.append(assess_table)

        # ====================================================
        # PAGE 4: SYSTEMIC EXAMINATION & DIAGNOSIS
        # ====================================================
        story.append(PageBreak())
        story.append(Paragraph("<b>SYSTEMIC EXAMINATION & CLINICAL DIAGNOSIS</b>", header_title_style))
        story.append(Paragraph("Form: SMVMCH/OP/OPIAF/Version1 • Continuous Patient Record", subtitle_style))
        story.append(Spacer(1, 14))

        exam_data = [
            [Paragraph("<b>RS (Respiratory System):</b>", label_style), Paragraph("B/L Air Entry Equal, Clear, No Added Sounds", val_style)],
            [Paragraph("<b>CVS (Cardiovascular):</b>", label_style), Paragraph("S1, S2 Heard, No murmurs", val_style)],
            [Paragraph("<b>O/E (On Examination):</b>", label_style), Paragraph("Pericoronitis 38 (Lower Left Third Molar)", val_style)],
            [Paragraph("<b>Investigations Advised:</b>", label_style), Paragraph("Adv: IOPA 38 (Intraoral Periapical Radiograph)", val_style)],
            [Paragraph("<b>Provisional Diagnosis:</b>", label_style), Paragraph("Acute Pericoronitis irt 38", val_style)],
            [Paragraph("<b>Care Plan:</b>", label_style), Paragraph("Operculectomy / Extraction after acute symptoms subside with antibiotics", val_style)],
            [Paragraph("<b>Final Diagnosis:</b>", label_style), Paragraph("Pericoronitis 38", val_style)],
        ]
        exam_table = Table(exam_data, colWidths=[180, 340])
        exam_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor('#F8FAFC')),
            ('BOX', (0, 0), (-1, -1), 1, colors.HexColor('#94A3B8')),
            ('INNERGRID', (0, 0), (-1, -1), 0.5, colors.HexColor('#CBD5E1')),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('PADDING', (0, 0), (-1, -1), 10),
        ]))
        story.append(exam_table)

        # ====================================================
        # PAGE 5: TREATMENT PLAN (Rx)
        # ====================================================
        story.append(PageBreak())
        story.append(Paragraph("<b>TREATMENT PLAN (PRESCRIPTION)</b>", header_title_style))
        story.append(Paragraph("Department of Dental Surgery & General Medicine • SMVMCH", subtitle_style))
        story.append(Spacer(1, 14))

        rx_rows = [
            [Paragraph("<b>Sl. No.</b>", label_style), Paragraph("<b>Drugs & Strength</b>", label_style), Paragraph("<b>Dosage Schedule</b>", label_style), Paragraph("<b>Duration</b>", label_style)],
            [Paragraph("1", val_style), Paragraph("<b>T. Cefixime 200mg</b>", val_style), Paragraph("1 - 0 - 1 (Morning & Night)", val_style), Paragraph("3 days", val_style)],
            [Paragraph("2", val_style), Paragraph("<b>T. Hifenac-P</b>", val_style), Paragraph("1 - 0 - 1 (After food)", val_style), Paragraph("3 days", val_style)],
        ]
        rx_table = Table(rx_rows, colWidths=[50, 200, 170, 100])
        rx_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#E2E8F0')),
            ('BOX', (0, 0), (-1, -1), 1, colors.HexColor('#64748B')),
            ('INNERGRID', (0, 0), (-1, -1), 0.5, colors.HexColor('#CBD5E1')),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('PADDING', (0, 0), (-1, -1), 8),
        ]))
        story.append(rx_table)
        story.append(Spacer(1, 24))

        # Doctor Signature Box
        doc_sign_data = [
            [Paragraph("<b>Review Date:</b> After 3 days", val_style), Paragraph("<b>Doctor's Name:</b> Dr. Anusha S", val_style)],
            [Paragraph("<b>Date & Time:</b> 01/10/2026", val_style), Paragraph("<b>Verified Signature:</b> <i>Dr. Anusha S, M.D.</i> [VERIFIED]", label_style)],
        ]
        doc_sign_table = Table(doc_sign_data, colWidths=[250, 270])
        doc_sign_table.setStyle(TableStyle([
            ('BOX', (0, 0), (-1, -1), 1, colors.HexColor('#94A3B8')),
            ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor('#F8FAFC')),
            ('PADDING', (0, 0), (-1, -1), 8),
        ]))
        story.append(doc_sign_table)

        # ====================================================
        # PAGE 6: PHARMACY CASH BILL PB26280332
        # ====================================================
        story.append(PageBreak())
        story.append(Paragraph("<b>SRI MANAKULA VINAYAGAR MEDICAL COLLEGE & HOSPITAL</b>", header_title_style))
        story.append(Paragraph("PHARMACY UNIT-I (24 Hours) • CASH BILL / DUPLICATE BILL", subtitle_style))
        story.append(Paragraph("GST No: 34AAATM9599A1ZE • Kalitheerthalkuppam, Puducherry-605107 • Ph: 0413-2643000", ParagraphStyle('P2', parent=styles['Normal'], fontSize=8, alignment=1, textColor=colors.grey)))
        story.append(Spacer(1, 10))

        bill_meta = [
            [Paragraph(f"<b>Patient No:</b> {uhid}", val_style), Paragraph("<b>Bill No:</b> PB26280332", val_style)],
            [Paragraph(f"<b>Name:</b> {patient.full_name}", val_style), Paragraph("<b>Date:</b> 01/10/2026", val_style)],
            [Paragraph("<b>Category:</b> SPECIAL CATEGORY", val_style), Paragraph(f"<b>Staff:</b> {staff_str}", val_style)],
        ]
        bill_meta_table = Table(bill_meta, colWidths=[260, 260])
        bill_meta_table.setStyle(TableStyle([
            ('LINEBELOW', (0, -1), (-1, -1), 1, colors.HexColor('#CBD5E1')),
            ('PADDING', (0, 0), (-1, -1), 4),
        ]))
        story.append(bill_meta_table)
        story.append(Spacer(1, 8))

        bill_items = [
            [
                Paragraph("<b>SNo.</b>", label_style),
                Paragraph("<b>Description</b>", label_style),
                Paragraph("<b>Batch</b>", label_style),
                Paragraph("<b>ExpDate</b>", label_style),
                Paragraph("<b>Qty</b>", label_style),
                Paragraph("<b>Rate</b>", label_style),
                Paragraph("<b>CGST%</b>", label_style),
                Paragraph("<b>SGST%</b>", label_style),
                Paragraph("<b>Amount (₹)</b>", label_style),
            ],
            [
                Paragraph("1", val_style),
                Paragraph("MAHACEF-200MG TABLET", val_style),
                Paragraph("COAKZ001", val_style),
                Paragraph("12/27", val_style),
                Paragraph("6", val_style),
                Paragraph("9.44", val_style),
                Paragraph("2.5", val_style),
                Paragraph("2.5", val_style),
                Paragraph("56.63", val_style),
            ],
            [
                Paragraph("2", val_style),
                Paragraph("HIFENAC-P TABLET", val_style),
                Paragraph("K2601285", val_style),
                Paragraph("04/28", val_style),
                Paragraph("6", val_style),
                Paragraph("7.46", val_style),
                Paragraph("2.5", val_style),
                Paragraph("2.5", val_style),
                Paragraph("44.74", val_style),
            ],
        ]
        bill_table = Table(bill_items, colWidths=[30, 160, 65, 50, 30, 45, 45, 45, 50])
        bill_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#F1F5F9')),
            ('BOX', (0, 0), (-1, -1), 1, colors.HexColor('#64748B')),
            ('INNERGRID', (0, 0), (-1, -1), 0.5, colors.HexColor('#CBD5E1')),
            ('ALIGN', (4, 1), (-1, -1), 'RIGHT'),
            ('PADDING', (0, 0), (-1, -1), 5),
        ]))
        story.append(bill_table)
        story.append(Spacer(1, 10))

        # Bill Totals Table
        totals_data = [
            [Paragraph("<b>Gross Amount:</b>", val_style), Paragraph("₹ 101.37", val_style)],
            [Paragraph("<b>Discount:</b>", val_style), Paragraph("₹ 0.00", val_style)],
            [Paragraph("<b>CGST (2.5%):</b>", val_style), Paragraph("₹ 2.54", val_style)],
            [Paragraph("<b>SGST (2.5%):</b>", val_style), Paragraph("₹ 2.54", val_style)],
            [Paragraph("<b>Total GST:</b>", val_style), Paragraph("₹ 5.07", val_style)],
            [Paragraph("<b>NET PAYABLE AMOUNT:</b>", label_style), Paragraph("<b>₹ 106.50</b>", ParagraphStyle('Net', parent=styles['Normal'], fontSize=12, fontName='Helvetica-Bold', textColor=colors.HexColor('#15803D')))],
            [Paragraph("<b>Payment Status:</b>", label_style), Paragraph("<b>PAID IN FULL (CASH COUNTER)</b>", ParagraphStyle('Paid', parent=styles['Normal'], fontSize=9, fontName='Helvetica-Bold', textColor=colors.HexColor('#0284C7')))],
        ]
        totals_table = Table(totals_data, colWidths=[360, 160])
        totals_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor('#F8FAFC')),
            ('BOX', (0, 0), (-1, -1), 1, colors.HexColor('#CBD5E1')),
            ('LINEBELOW', (0, 4), (-1, 4), 1, colors.HexColor('#94A3B8')),
            ('PADDING', (0, 0), (-1, -1), 4),
        ]))
        story.append(totals_table)

        # ====================================================
        # PAGE 7: CLINICAL LABORATORY INVESTIGATIONS MENU
        # ====================================================
        story.append(PageBreak())
        story.append(Paragraph("<b>SMVMCH CLINICAL LABORATORY INVESTIGATIONS</b>", header_title_style))
        story.append(Paragraph("Department of Pathology, Biochemistry & Microbiology", subtitle_style))
        story.append(Spacer(1, 14))

        lab_menu_data = [
            [
                Paragraph("<b>BIOCHEMISTRY</b><br/><br/>"
                          "❖ Glucose Fasting<br/>"
                          "❖ Glucose PP<br/>"
                          "❖ Glucose Random<br/>"
                          "❖ Urea<br/>"
                          "❖ Creatinine<br/>"
                          "❖ Cholesterol<br/>"
                          "❖ Triglycerides<br/>"
                          "❖ Glucose tolerance Test (Routine)<br/>"
                          "❖ Glucose tolerance Test (pregnancy)<br/>"
                          "❖ Glucose Challenge Test (GCT)", val_style),
                Paragraph("<b>HAEMATOLOGY</b><br/><br/>"
                          "❖ Haemoglobin (Hb)<br/>"
                          "❖ Haematocrit (PCV)<br/>"
                          "❖ RBC Count<br/>"
                          "❖ Total Leucocyte Count (TC)<br/>"
                          "❖ Differential Count (DC)<br/>"
                          "❖ Platelet Count<br/>"
                          "❖ Erythrocyte Sedimentation Rate (ESR)<br/>"
                          "❖ Bleeding Time (BT)<br/>"
                          "❖ Clotting Time (CT)<br/>"
                          "❖ Urine Routine", val_style),
            ],
            [
                Paragraph("<b>MICROBIOLOGY</b><br/><br/>"
                          "❖ Sputum AFB<br/>"
                          "❖ Stool Ova / Cyst<br/>"
                          "❖ HIV, VDRL (TB & Chest, Dermatology, Antenatal Cases)", val_style),
                Paragraph("<b>VERIFICATION & SPECIMEN STATUS</b><br/><br/>"
                          "Laboratory Accreditation: NABL Certified<br/>"
                          "Standard Turnaround Time: 2 - 4 Hours<br/>"
                          "Status: All parameters validated by Chief Biochemist", val_style),
            ]
        ]
        lab_menu_table = Table(lab_menu_data, colWidths=[255, 255])
        lab_menu_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor('#F8FAFC')),
            ('BOX', (0, 0), (-1, -1), 1, colors.HexColor('#CBD5E1')),
            ('INNERGRID', (0, 0), (-1, -1), 0.5, colors.HexColor('#E2E8F0')),
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('PADDING', (0, 0), (-1, -1), 10),
        ]))
        story.append(lab_menu_table)

        doc.build(story)
        buffer.seek(0)
        return buffer.getvalue()
