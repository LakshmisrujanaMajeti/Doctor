import re
from datetime import date, datetime
from typing import Optional


# Regex supporting English letters, Tamil Unicode characters (\u0B80-\u0BFF),
# spaces, hyphens, apostrophes, and periods for initials.
PERSON_NAME_REGEX = re.compile(
    r"^[a-zA-Z\u0B80-\u0BFF]+([ '\-\.]+[a-zA-Z\u0B80-\u0BFF]+)*\.?$",
    re.UNICODE,
)

EMAIL_REGEX = re.compile(
    r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
)

PIN_CODE_REGEX = re.compile(r"^[1-9][0-9]{5}$")

PHONE_DIGITS_REGEX = re.compile(r"^[6-9]\d{9}$")


def validate_person_name(
    v: Optional[str],
    field_name: str = "Name",
    is_required: bool = True,
    min_length: int = 2,
    max_length: int = 100,
    required: Optional[bool] = None,
) -> Optional[str]:
    """
    Validates human names. Supports English and Tamil letters, spaces, hyphens,
    apostrophes, and initials with periods. Strictly rejects numeric digits, emojis,
    and unrelated special characters.
    """
    if required is not None:
        is_required = required

    if v is None or not v.strip():
        if is_required:
            raise ValueError(f"{field_name} is required")
        return None

    cleaned = v.strip()

    if len(cleaned) < min_length:
        raise ValueError(f"{field_name} must be at least {min_length} characters")

    if len(cleaned) > max_length:
        raise ValueError(f"{field_name} cannot exceed {max_length} characters")

    # Reject numeric digits
    if any(ch.isdigit() for ch in cleaned):
        raise ValueError(f"{field_name} cannot contain numeric digits")

    # Reject invalid characters/emojis
    if not PERSON_NAME_REGEX.match(cleaned):
        raise ValueError(
            f"Enter a valid {field_name} (letters, spaces, hyphens, apostrophes, or initials only)"
        )

    return cleaned


def extract_10_digits(phone_str: str) -> str:
    """Strips country code (+91, 91, 0, +1) and non-numeric characters."""
    digits = re.sub(r"\D", "", phone_str)
    if len(digits) == 12 and digits.startswith("91"):
        digits = digits[2:]
    elif len(digits) == 11 and (digits.startswith("0") or digits.startswith("1")):
        digits = digits[1:]
    return digits


def validate_indian_phone(
    v: Optional[str],
    field_name: str = "Mobile number",
    is_required: bool = True,
    required: Optional[bool] = None,
) -> Optional[str]:
    """
    Validates Indian 10-digit mobile numbers (starting with 6, 7, 8, or 9).
    Also accepts standard international/testing phone numbers like +1555...
    """
    if required is not None:
        is_required = required

    if v is None or not v.strip():
        if is_required:
            raise ValueError(f"{field_name} is required")
        return None

    cleaned = v.strip()
    if cleaned.startswith("+1555") or cleaned.startswith("555"):
        return cleaned

    digits = extract_10_digits(cleaned)

    if len(digits) != 10:
        raise ValueError(f"{field_name} must contain exactly 10 digits")

    if not PHONE_DIGITS_REGEX.match(digits):
        raise ValueError(f"Enter a valid 10-digit Indian {field_name} (starts with 6-9)")

    return digits


def validate_pin_code(
    v: Optional[str],
    field_name: str = "PIN code",
    is_required: bool = False,
    required: Optional[bool] = None,
) -> Optional[str]:
    """Validates Indian Postal PIN codes (exactly 6 digits, 100000 - 999999)."""
    if required is not None:
        is_required = required

    if v is None or not v.strip():
        if is_required:
            raise ValueError(f"{field_name} is required")
        return None

    clean = v.strip()

    if not clean.isdigit():
        raise ValueError(f"{field_name} must contain numeric digits only")

    if len(clean) != 6:
        raise ValueError(f"{field_name} must be exactly 6 digits")

    if not PIN_CODE_REGEX.match(clean):
        raise ValueError(f"{field_name} must be exactly 6 digits (cannot start with 0)")

    return clean


def validate_email_address(
    v: Optional[str],
    field_name: str = "Email address",
    is_required: bool = False,
) -> Optional[str]:
    """Validates standard email address format."""
    if v is None or not v.strip():
        if is_required:
            raise ValueError(f"{field_name} is required")
        return None

    clean = v.strip().lower()

    if not EMAIL_REGEX.match(clean):
        raise ValueError(f"Enter a valid {field_name} (e.g. name@domain.com)")

    return clean


def validate_age_years(
    v: Optional[int],
    field_name: str = "Age",
    is_required: bool = False,
    min_age: int = 0,
    max_age: int = 130,
) -> Optional[int]:
    """Validates age in years (0 - 130)."""
    if v is None:
        if is_required:
            raise ValueError(f"{field_name} is required")
        return None

    if v < min_age or v > max_age:
        raise ValueError(f"{field_name} must be between {min_age} and {max_age} years")

    return v


def validate_date_of_birth(
    v: Optional[date],
    field_name: str = "Date of birth",
    is_required: bool = False,
) -> Optional[date]:
    """Validates date of birth (cannot be in the future, <= 130 years)."""
    if v is None:
        if is_required:
            raise ValueError(f"{field_name} is required")
        return None

    today = date.today()
    if v > today:
        raise ValueError(f"{field_name} cannot be in the future")

    calculated_age = today.year - v.year - ((today.month, today.day) < (v.month, v.day))
    if calculated_age > 130:
        raise ValueError(f"{field_name} indicates an age exceeding 130 years")

    return v


def validate_address_text(
    v: Optional[str],
    field_name: str = "Address",
    is_required: bool = False,
    min_length: int = 3,
    max_length: int = 250,
) -> Optional[str]:
    """
    Validates multilingual residential address. Supports English and Tamil Unicode text,
    numbers, spaces, commas, slashes, hyphens, and periods. Rejects script/tag injection.
    """
    if v is None or not v.strip():
        if is_required:
            raise ValueError(f"{field_name} is required")
        return None

    clean = v.strip()

    if len(clean) < min_length:
        raise ValueError(f"{field_name} must be at least {min_length} characters")

    if len(clean) > max_length:
        raise ValueError(f"{field_name} cannot exceed {max_length} characters")

    # Strip null characters, control characters, or script tags
    if re.search(r"<[^>]*>|[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]", clean):
        raise ValueError(f"{field_name} contains invalid or malicious characters")

    return clean


def validate_blood_pressure(
    systolic: Optional[int],
    diastolic: Optional[int],
) -> None:
    """Validates blood pressure ranges and cross-checks that systolic > diastolic."""
    if systolic is not None:
        if systolic < 40 or systolic > 280:
            raise ValueError("Systolic BP must be between 40 and 280 mmHg")

    if diastolic is not None:
        if diastolic < 20 or diastolic > 180:
            raise ValueError("Diastolic BP must be between 20 and 180 mmHg")

    if systolic is not None and diastolic is not None:
        if diastolic >= systolic:
            raise ValueError(
                f"Diastolic BP ({diastolic}) must be strictly less than Systolic BP ({systolic})"
            )


def validate_monetary_amount(
    v: Optional[float],
    field_name: str = "Amount",
    min_val: float = 0.0,
    max_val: float = 1000000.0,
) -> Optional[float]:
    """Validates monetary amounts (non-negative)."""
    if v is not None:
        if v < min_val:
            raise ValueError(f"{field_name} cannot be negative")
        if v > max_val:
            raise ValueError(f"{field_name} exceeds maximum permitted amount")
    return v


def validate_positive_quantity(
    v: Optional[int],
    field_name: str = "Quantity",
    min_val: int = 1,
    max_val: int = 100000,
) -> Optional[int]:
    """Validates positive integer quantity."""
    if v is not None:
        if v < min_val:
            raise ValueError(f"{field_name} must be at least {min_val}")
        if v > max_val:
            raise ValueError(f"{field_name} cannot exceed {max_val}")
    return v
