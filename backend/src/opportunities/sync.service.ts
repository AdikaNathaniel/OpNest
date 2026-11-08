import { Injectable, Logger, OnApplicationBootstrap } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { SchedulerRegistry } from '@nestjs/schedule';
import { InjectRepository } from '@nestjs/typeorm';
import { CronJob } from 'cron';
import { IsNull, Not, Repository } from 'typeorm';
import { MailService } from '../mail/mail.service';
import { ScraperService } from '../scraper/scraper.service';
import { Opportunity } from './opportunity.entity';

export interface SyncResult {
  found: number;
  created: number;
  removed: number;
  notified: number;
  notifyErrors: number;
}

@Injectable()
export class SyncService implements OnApplicationBootstrap {
  private readonly logger = new Logger(SyncService.name);
  private running: Promise<SyncResult> | null = null;

  constructor(
    @InjectRepository(Opportunity)
    private readonly repo: Repository<Opportunity>,
    private readonly scraper: ScraperService,
    private readonly mail: MailService,
    private readonly config: ConfigService,
    private readonly scheduler: SchedulerRegistry,
  ) {}

  onApplicationBootstrap() {
    const cron = this.config.get<string>('SYNC_CRON', '*/30 * * * *');
    const job = CronJob.from({
      cronTime: cron,
      onTick: () => void this.syncSafely(),
      start: true,
    });
    this.scheduler.addCronJob('sync-opportunities', job);
    this.logger.log(`Checking for opportunities on schedule "${cron}".`);

    if (this.config.get('SYNC_ON_STARTUP', 'true') === 'true') {
      void this.syncSafely();
    }
  }

  /** Runs a sync, or joins the one already in progress. */
  sync(): Promise<SyncResult> {
    this.running ??= this.doSync().finally(() => (this.running = null));
    return this.running;
  }

  private async syncSafely() {
    try {
      const r = await this.sync();
      this.logger.log(
        `Sync done: ${r.found} on page, ${r.created} new, ${r.removed} removed, ${r.notified} emailed.`,
      );
    } catch (err) {
      this.logger.error(`Sync failed: ${(err as Error).message}`);
    }
  }

  private async doSync(): Promise<SyncResult> {
    const parsed = await this.scraper.fetchOpportunities();
    const now = new Date();
    // On the very first sync the database is empty, so everything on the page
    // would look new. Unless asked otherwise, store those silently and only
    // email what gets posted from now on.
    const isFirstSync = (await this.repo.count()) === 0;
    const notifyExisting =
      this.config.get('NOTIFY_EXISTING_ON_FIRST_SYNC', 'false') === 'true';

    const existing = await this.repo.find();
    const byFingerprint = new Map(existing.map((o) => [o.fingerprint, o]));
    let created = 0;

    for (const p of parsed) {
      const row = byFingerprint.get(p.fingerprint);
      if (row) {
        Object.assign(row, p, { lastSeenAt: now, removedAt: null });
        await this.repo.save(row);
        continue;
      }
      await this.repo.save(
        this.repo.create({
          ...p,
          sourceUrl: this.scraper.sourceUrl,
          lastSeenAt: now,
          removedAt: null,
          notifiedAt: isFirstSync && !notifyExisting ? now : null,
        }),
      );
      created++;
    }

    const seen = new Set(parsed.map((p) => p.fingerprint));
    const gone = existing.filter(
      (o) => !seen.has(o.fingerprint) && o.removedAt === null,
    );
    for (const o of gone) o.removedAt = now;
    await this.repo.save(gone);

    const { notified, notifyErrors } = await this.notifyPending();
    return {
      found: parsed.length,
      created,
      removed: gone.length,
      notified,
      notifyErrors,
    };
  }

  /**
   * Emails every live opportunity that hasn't been sent yet. A failed send
   * leaves notifiedAt empty, so it is retried on the next sync.
   */
  private async notifyPending() {
    if (!this.mail.enabled) return { notified: 0, notifyErrors: 0 };
    const pending = await this.repo.find({
      where: { notifiedAt: IsNull(), removedAt: IsNull() },
      order: { position: 'ASC' },
    });
    let notified = 0;
    let notifyErrors = 0;
    for (const o of pending) {
      try {
        await this.mail.sendOpportunity(o);
        o.notifiedAt = new Date();
        await this.repo.save(o);
        notified++;
      } catch (err) {
        notifyErrors++;
        this.logger.error(
          `Email for "${o.title}" failed: ${(err as Error).message}`,
        );
      }
    }
    return { notified, notifyErrors };
  }

  async lastSyncedAt(): Promise<Date | null> {
    const latest = await this.repo.findOne({
      where: { lastSeenAt: Not(IsNull()) },
      order: { lastSeenAt: 'DESC' },
    });
    return latest?.lastSeenAt ?? null;
  }
}
