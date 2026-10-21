from typing import List, Dict, Optional, Tuple

# Curated, reliable medicine catalog with forms, dosages, and allergy classes
MEDICINE_CATALOG: List[Dict] = [
    # Analgesics & Antipyretics
    {
        "name": "Paracetamol",
        "category": "Analgesic / Antipyretic",
        "common_forms": ["Tablet", "Syrup", "Injection", "Suppository"],
        "common_dosages": ["650 mg", "500 mg", "250 mg/5ml", "1000 mg IV"],
        "default_route": "Oral",
        "allergy_class": "paracetamol",
    },
    {
        "name": "Ibuprofen",
        "category": "NSAID Analgesic",
        "common_forms": ["Tablet", "Capsule", "Suspension"],
        "common_dosages": ["400 mg", "200 mg", "100 mg/5ml"],
        "default_route": "Oral",
        "allergy_class": "nsaid",
    },
    {
        "name": "Diclofenac",
        "category": "NSAID Analgesic",
        "common_forms": ["Tablet", "Gel", "Injection"],
        "common_dosages": ["50 mg", "75 mg/3ml", "1% Gel"],
        "default_route": "Oral",
        "allergy_class": "nsaid",
    },
    {
        "name": "Aspirin",
        "category": "Antiplatelet / NSAID",
        "common_forms": ["Tablet", "Dispersible Tablet"],
        "common_dosages": ["75 mg", "150 mg", "325 mg"],
        "default_route": "Oral",
        "allergy_class": "aspirin",
    },

    # Antibiotics
    {
        "name": "Amoxicillin",
        "category": "Penicillin Antibiotic",
        "common_forms": ["Capsule", "Syrup", "Tablet"],
        "common_dosages": ["500 mg", "250 mg", "125 mg/5ml"],
        "default_route": "Oral",
        "allergy_class": "penicillin",
    },
    {
        "name": "Augmentin (Amoxicillin + Clavulanate)",
        "category": "Penicillin Antibiotic",
        "common_forms": ["Tablet", "Syrup", "Injection"],
        "common_dosages": ["625 mg", "375 mg", "1.2 g IV"],
        "default_route": "Oral",
        "allergy_class": "penicillin",
    },
    {
        "name": "Co-trimoxazole (Bactrim / Septran)",
        "category": "Sulfonamide Antibacterial",
        "common_forms": ["Tablet", "Syrup", "Suspension"],
        "common_dosages": ["Double Strength (800/160 mg)", "Single Strength (400/80 mg)", "240 mg/5ml"],
        "default_route": "Oral",
        "allergy_class": "sulfa",
    },
    {
        "name": "Azithromycin",
        "category": "Macrolide Antibiotic",
        "common_forms": ["Tablet", "Suspension"],
        "common_dosages": ["500 mg", "250 mg", "200 mg/5ml"],
        "default_route": "Oral",
        "allergy_class": "macrolide",
    },
    {
        "name": "Ciprofloxacin",
        "category": "Fluoroquinolone Antibiotic",
        "common_forms": ["Tablet", "Eye Drops", "IV Infusion"],
        "common_dosages": ["500 mg", "250 mg", "200 mg/100ml IV"],
        "default_route": "Oral",
        "allergy_class": "fluoroquinolone",
    },
    {
        "name": "Cefixime",
        "category": "Cephalosporin Antibiotic",
        "common_forms": ["Tablet", "Syrup"],
        "common_dosages": ["200 mg", "100 mg", "50 mg/5ml"],
        "default_route": "Oral",
        "allergy_class": "cephalosporin",
    },

    # Respiratory & Allergy
    {
        "name": "Cetirizine",
        "category": "Antihistamine",
        "common_forms": ["Tablet", "Syrup"],
        "common_dosages": ["10 mg", "5 mg", "5 mg/5ml"],
        "default_route": "Oral",
        "allergy_class": "antihistamine",
    },
    {
        "name": "Levocetirizine + Montelukast",
        "category": "Antiallergic & Leukotriene Antagonist",
        "common_forms": ["Tablet", "Syrup"],
        "common_dosages": ["5 mg / 10 mg", "2.5 mg / 4 mg"],
        "default_route": "Oral",
        "allergy_class": None,
    },
    {
        "name": "Budesonide + Formoterol",
        "category": "Inhaled Corticosteroid / LABA",
        "common_forms": ["Inhaler", "Rotacaps", "Respules"],
        "common_dosages": ["200/6 mcg", "400/6 mcg", "0.5 mg/2ml"],
        "default_route": "Inhalation",
        "allergy_class": None,
    },
    {
        "name": "Salbutamol",
        "category": "Short-Acting Beta Agonist",
        "common_forms": ["Inhaler", "Syrup", "Respules"],
        "common_dosages": ["100 mcg/puff", "2 mg/5ml", "2.5 mg/2.5ml"],
        "default_route": "Inhalation",
        "allergy_class": None,
    },

    # Gastrointestinal
    {
        "name": "Pantoprazole",
        "category": "Proton Pump Inhibitor",
        "common_forms": ["Tablet", "Injection"],
        "common_dosages": ["40 mg", "20 mg", "40 mg IV"],
        "default_route": "Oral",
        "allergy_class": "ppi",
    },
    {
        "name": "Omeprazole",
        "category": "Proton Pump Inhibitor",
        "common_forms": ["Capsule", "Tablet"],
        "common_dosages": ["20 mg", "40 mg"],
        "default_route": "Oral",
        "allergy_class": "ppi",
    },
    {
        "name": "Ondansetron",
        "category": "Antiemetic",
        "common_forms": ["Tablet", "Syrup", "Injection"],
        "common_dosages": ["4 mg", "8 mg", "2 mg/ml IV"],
        "default_route": "Oral",
        "allergy_class": None,
    },

    # Cardiovascular & Metabolic
    {
        "name": "Telmisartan",
        "category": "Angiotensin Receptor Blocker",
        "common_forms": ["Tablet"],
        "common_dosages": ["40 mg", "20 mg", "80 mg"],
        "default_route": "Oral",
        "allergy_class": "arb",
    },
    {
        "name": "Amlodipine",
        "category": "Calcium Channel Blocker",
        "common_forms": ["Tablet"],
        "common_dosages": ["5 mg", "2.5 mg", "10 mg"],
        "default_route": "Oral",
        "allergy_class": None,
    },
    {
        "name": "Metformin",
        "category": "Biguanide Antidiabetic",
        "common_forms": ["Tablet", "Extended Release"],
        "common_dosages": ["500 mg", "850 mg", "1000 mg SR"],
        "default_route": "Oral",
        "allergy_class": None,
    },
]


ALLERGY_KEYWORDS_MAP = {
    "sulfa": ["sulfa", "sulfamethoxazole", "sulfonamide", "bactrim", "septran"],
    "penicillin": ["penicillin", "amoxicillin", "ampicillin", "augmentin", "amoxil"],
    "nsaid": ["nsaid", "ibuprofen", "diclofenac", "naproxen", "combiflam"],
    "aspirin": ["aspirin", "salicylate", "ecosprin"],
    "cephalosporin": ["cephalosporin", "cefixime", "ceftriaxone", "cephalexin"],
    "fluoroquinolone": ["ciprofloxacin", "ofloxacin", "levofloxacin", "quinolone"],
}


def check_medication_allergies(patient_allergies: Optional[str], prescribed_medicines: List[str]) -> List[Dict]:
    """
    Evaluates patient allergy notes against prescribed medication list using reliable clinical keyword mapping.
    Never warns when allergy notes indicate NKDA (No known drug allergies).
    """
    if not patient_allergies or not patient_allergies.strip():
        return []

    cleaned_notes = patient_allergies.lower().strip()
    if "nkda" in cleaned_notes or "no known drug" in cleaned_notes or "no drug allergies" in cleaned_notes:
        return []

    warnings = []
    for med_name in prescribed_medicines:
        med_lower = med_name.lower().strip()

        # Find matching medicine catalog entry
        matched_catalog = None
        for item in MEDICINE_CATALOG:
            if item["name"].lower() in med_lower or med_lower in item["name"].lower():
                matched_catalog = item
                break

        allergy_class = matched_catalog.get("allergy_class") if matched_catalog else None

        # 1. Direct name match in patient allergies
        if med_lower in cleaned_notes or (matched_catalog and matched_catalog["name"].lower() in cleaned_notes):
            warnings.append({
                "medicine_name": med_name,
                "allergen": med_name,
                "severity": "HIGH",
                "warning_message": f"CRITICAL ALLERGY ALERT: Patient has documented allergy to '{med_name}'.",
            })
            continue

        # 2. Class match via ALLERGY_KEYWORDS_MAP
        if allergy_class and allergy_class in ALLERGY_KEYWORDS_MAP:
            keywords = ALLERGY_KEYWORDS_MAP[allergy_class]
            if any(k in cleaned_notes for k in keywords):
                warnings.append({
                    "medicine_name": med_name,
                    "allergen": allergy_class.upper(),
                    "severity": "HIGH",
                    "warning_message": f"POTENTIAL ALLERGY INTERACTION: Patient has recorded {allergy_class.upper()} allergy. '{med_name}' contains or belongs to this class.",
                })

    return warnings
