import {
  BadGatewayException,
  BadRequestException,
  Controller,
  Get,
  HttpCode,
  Param,
  ParseIntPipe,
  Post,
  Query,
  ServiceUnavailableException,
  UseGuards,
} from '@nestjs/common';
import { AdminTokenGuard } from '../common/admin-token.guard';
import { MailService } from '../mail/mail.service';
import { OpportunitiesService } from './opportunities.service';
import type { ListQuery } from './opportunities.service';
import { SyncService } from './sync.service';

const STATUSES = ['open', 'closed', 'unknown', 'all'];

@Controller()
export class OpportunitiesController {
  constructor(
    private readonly opportunities: OpportunitiesService,
    private readonly syncService: SyncService,
    private readonly mail: MailService,
  ) {}

  @Get('opportunities')
  async list(@Query() query: ListQuery) {
    if (query.status && !STATUSES.includes(query.status)) {
      throw new BadRequestException(
        `status must be one of ${STATUSES.join(', ')}`,
      );
    }
    const items = await this.opportunities.list(query);
    return {
      items,
      count: items.length,
      lastSyncedAt: await this.syncService.lastSyncedAt(),
    };
  }

  @Get('opportunities/:id')
  get(@Param('id', ParseIntPipe) id: number) {
    return this.opportunities.get(id);
  }

  @Post('sync')
  @HttpCode(200)
  @UseGuards(AdminTokenGuard)
  sync() {
    return this.syncService.sync();
  }

  @Post('notifications/test')
  @HttpCode(200)
  @UseGuards(AdminTokenGuard)
  async testEmail() {
    if (!this.mail.enabled) {
      throw new ServiceUnavailableException(
        'Email is not configured: set SMTP_USER and SMTP_PASS in .env.',
      );
    }
    try {
      await this.mail.sendTest();
    } catch (err) {
      // Surface the SMTP error (e.g. Gmail rejecting the App Password).
      throw new BadGatewayException(
        `Sending failed: ${(err as Error).message}`,
      );
    }
    return { sent: true };
  }
}
