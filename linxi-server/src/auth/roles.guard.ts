import { Injectable, CanActivate, ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Role } from '@prisma/client';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<Role[]>('roles', [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!requiredRoles) {
      return true;
    }
    const { user } = context.switchToHttp().getRequest();
    // User object is attached by JwtStrategy
    // We need to ensure user.role is available in JWT payload or fetched from DB if not in JWT
    // For simplicity, let's assume we will put role in JWT or fetch it here.
    // However, fetching here adds latency. Best practice: put role in JWT.
    // But earlier implementation of login didn't include role. 
    // We should update AuthService.login to include role.
    
    return requiredRoles.some((role) => user.role === role);
  }
}
