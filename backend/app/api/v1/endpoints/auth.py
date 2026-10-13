from typing import Optional
from fastapi import APIRouter, Depends, Request, Body
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.responses import success_response
from app.core.dependencies import get_current_user
from app.core.exceptions import BadRequestException
from app.schemas.auth import (
    LoginRequest,
    RefreshTokenRequest,
    RegisterRequest,
    PatientRegisterRequest,
    ForgotPasswordRequest,
    ResetPasswordRequest,
    SendOTPRequest,
    VerifyOTPRequest,
)
from app.schemas.user import UserRead
from app.services.auth_service import AuthService
from app.services.otp_service import OTPService
from app.models.user import User

router = APIRouter()


@router.post("/register", summary="Register User")
def register(request_in: RegisterRequest, db: Session = Depends(get_db)):
    user = AuthService.register_user(
        db=db,
        email=request_in.email,
        password=request_in.password,
        full_name=request_in.full_name,
        role_name=request_in.role_name or "receptionist",
        phone=request_in.phone,
    )
    return success_response(
        data=UserRead.model_validate(user).model_dump(),
        message="User registered successfully",
        status_code=201
    )


@router.post("/register-patient", summary="Self-Registration for Patients (with UHID)")
def register_patient(request_in: PatientRegisterRequest, db: Session = Depends(get_db)):
    user, access_token, refresh_token = AuthService.register_patient_user(
        db=db,
        req=request_in,
    )
    return success_response(
        data={
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer",
            "expires_in": 1800,
            "user": UserRead.model_validate(user).model_dump(),
        },
        message="Patient registered successfully",
        status_code=201
    )


@router.post("/login", summary="Login with Email or Phone Number")
def login(request_in: LoginRequest, request: Request, db: Session = Depends(get_db)):
    ip_address = request.client.host if request.client else None
    user_agent = request.headers.get("user-agent")

    identifier = request_in.identifier or request_in.email or request_in.phone
    if not identifier:
        raise BadRequestException("Please provide an email or phone number to sign in")

    user, access_token, refresh_token = AuthService.authenticate_user(
        db=db,
        identifier=identifier,
        password=request_in.password,
        ip_address=ip_address,
        user_agent=user_agent,
    )

    return success_response(
        data={
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer",
            "expires_in": 1800,
            "user": UserRead.model_validate(user).model_dump(),
        },
        message="Login successful"
    )


@router.post("/refresh", summary="Rotate and Refresh Access Token")
def refresh_token(request_in: RefreshTokenRequest, request: Request, db: Session = Depends(get_db)):
    ip_address = request.client.host if request.client else None
    user_agent = request.headers.get("user-agent")

    user, access_token, new_refresh_token = AuthService.rotate_refresh_token(
        db=db,
        raw_refresh_token=request_in.refresh_token,
        ip_address=ip_address,
        user_agent=user_agent,
    )

    return success_response(
        data={
            "access_token": access_token,
            "refresh_token": new_refresh_token,
            "token_type": "bearer",
            "expires_in": 1800,
            "user": UserRead.model_validate(user).model_dump(),
        },
        message="Token refreshed successfully"
    )


@router.post("/logout", summary="Logout and Revoke Refresh Token Server-Side")
def logout(request_in: Optional[RefreshTokenRequest] = Body(None), db: Session = Depends(get_db)):
    if request_in and request_in.refresh_token:
        AuthService.revoke_refresh_token(db=db, raw_refresh_token=request_in.refresh_token)
    return success_response(message="Logged out successfully")


@router.post("/forgot-password", summary="Initiate Password Recovery")
def forgot_password(request_in: ForgotPasswordRequest, db: Session = Depends(get_db)):
    message, dev_mock_token = AuthService.create_password_reset_token(
        db=db,
        identifier=request_in.identifier
    )
    res_data = {"message": message}
    if dev_mock_token:
        res_data["dev_mock_token"] = dev_mock_token

    return success_response(
        data=res_data,
        message=message
    )


@router.post("/reset-password", summary="Complete Password Reset with Token")
def reset_password(request_in: ResetPasswordRequest, db: Session = Depends(get_db)):
    AuthService.reset_password(
        db=db,
        raw_token=request_in.token,
        new_password=request_in.new_password
    )
    return success_response(message="Password reset successfully. You can now log in.")


@router.post("/otp/send", summary="Request One-Time Password")
def send_otp(request_in: SendOTPRequest, db: Session = Depends(get_db)):
    message, dev_mock_otp = OTPService.send_otp(
        db=db,
        identifier=request_in.identifier,
        purpose=request_in.purpose
    )
    res_data = {"message": message}
    if dev_mock_otp:
        res_data["dev_mock_otp"] = dev_mock_otp

    return success_response(
        data=res_data,
        message=message
    )


@router.post("/otp/verify", summary="Verify One-Time Password")
def verify_otp(request_in: VerifyOTPRequest, db: Session = Depends(get_db)):
    OTPService.verify_otp(
        db=db,
        identifier=request_in.identifier,
        otp=request_in.otp,
        purpose=request_in.purpose
    )
    return success_response(message="OTP verified successfully")


@router.get("/me", summary="Current User Profile")
def get_me(current_user: User = Depends(get_current_user)):
    return success_response(
        data=UserRead.model_validate(current_user).model_dump(),
        message="Current user fetched successfully"
    )
