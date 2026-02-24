import { Controller, Post, Body, Request } from '@nestjs/common';
import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';
import { SendCodeDto } from './dto/send-code.dto';
import { QueryRealPersonDto } from './dto/query-real-person.dto';
import { Public } from './public.decorator';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Public()
  @Post('login')
  async login(@Body() loginDto: LoginDto) {
    return this.authService.login(loginDto);
  }

  @Public()
  @Post('send-code')
  async sendCode(@Body() sendCodeDto: SendCodeDto) {
    return this.authService.sendCode(sendCodeDto.phoneNumber);
  }

  @Post('real-name/initialize')
  async initializeRealName(@Request() req) {
    return this.authService.initializeRealPersonAuth(req.user.userId);
  }

  @Post('real-name/query')
  async queryRealName(@Request() req, @Body() body: QueryRealPersonDto) {
    return this.authService.queryRealPersonAuth(req.user.userId, body.certifyId);
  }
}
