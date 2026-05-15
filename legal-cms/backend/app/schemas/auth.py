from pydantic import BaseModel, EmailStr

from app.schemas.user import UserResponse


class LoginSchema(BaseModel):
    email: EmailStr
    password: str


class TokenSchema(BaseModel):
    access_token: str
    token_type: str = "bearer"


class AuthResponseSchema(TokenSchema):
    user: UserResponse
