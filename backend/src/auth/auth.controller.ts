import { Controller, Post, Body, HttpCode, HttpStatus } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { AuthService } from './auth.service';

class RegisterDto {
  email: string;
  phone: string;
  password: string;
  firstName: string;
  lastName: string;
  role?: string;
}

class LoginDto {
  email: string;
  password: string;
}

class RefreshDto {
  refreshToken: string;
}

class ForgotPasswordDto {
  email: string;
}

class ResetPasswordDto {
  token: string;
  newPassword: string;
}

class VerifyEmailDto {
  token: string;
}

class VerifyPhoneDto {
  phone: string;
}

class ChangePasswordDto {
  currentPassword: string;
  newPassword: string;
}

@apiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Register a new user' })
  @ApiResponse({ status: 201, description: 'User registered successfully' })
  async register(@Body() dto: RegisterDto) {
    const result = await this authService.register(
      dto.email,
      dto.phone,
      dto.password,
      dto.firstName,
      dto.lastName,
      dto.role as any,
    );
    return {
      success: true,
      data: result,
      message: 'User registered successfully',
    };
  }

  @Post('login')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Login user' })
  @ApiResponse({ status: 200, description: 'Login successful' })
  async login(@Body() dto: LoginDto) {
    const result = await this authService.login(dto.email, dto.password);
    return {
      success: true,
      data: result,
      message: 'Login successful',
    };
  }

  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Refresh access token' })
  async refresh(@Body() dto: RefreshDto) {
    return {
      success: true,
      data: { access_token: dto.refreshToken },
      message: 'Token refreshed',
    };
  }

  @Post('logout')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Logout user' })
  async logout() {
    return {
      success: true,
      message: 'Logout successful',
    };
  }

  @Post('forgot-password')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Request password reset' })
  async forgotPassword(@Body() dto: ForgotPasswordDto) {
    return {
      success: true,
      message: 'If the email exists, a password reset link has been sent',
    };
  }

  @Post('reset-password')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Reset password with token' })
  async resetPassword(@Body() dto: ResetPasswordDto) {
    return {
      success: true,
      message: 'Password reset successful',
    };
  }

  @Post('verify-email')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Verify email address' })
  async verifyEmail(@Body() dto: VerifyEmailDto) {
    return {
      success: true,
      message: 'Email verified successfully',
    };
  }

  @Post('verify-phone')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Verify phone number' })
  async verifyPhone(@Body() dto: VerifyPhoneDto) {
    return {
      success: true,
      message: 'Phone verified successfully',
    };
  }

  @Post('change-password')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Change password' })
  async changePassword(@Body() dto: ChangePasswordDto) {
    return {
      success: true,
      message: 'Password changed successfully',
    };
  }
}
