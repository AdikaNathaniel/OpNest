import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { timingSafeEqual } from 'node:crypto';
import type { Request } from 'express';

/**
 * Protects endpoints that scrape the source site or send email. Requests must
 * carry `x-admin-token` matching ADMIN_TOKEN; with no ADMIN_TOKEN configured,
 * these endpoints are closed.
 */
@Injectable()
export class AdminTokenGuard implements CanActivate {
  constructor(private readonly config: ConfigService) {}

  canActivate(context: ExecutionContext): boolean {
    const expected = this.config.get<string>('ADMIN_TOKEN');
    const given = context
      .switchToHttp()
      .getRequest<Request>()
      .header('x-admin-token');
    if (!expected || !given || !safeEqual(given, expected)) {
      throw new UnauthorizedException(
        'Missing or invalid x-admin-token header',
      );
    }
    return true;
  }
}

function safeEqual(a: string, b: string): boolean {
  const left = Buffer.from(a);
  const right = Buffer.from(b);
  return left.length === right.length && timingSafeEqual(left, right);
}
