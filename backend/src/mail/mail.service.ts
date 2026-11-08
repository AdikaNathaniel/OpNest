import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { lookup } from 'node:dns/promises';
import { createTransport, Transporter } from 'nodemailer';
import { Opportunity } from '../opportunities/opportunity.entity';

@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);
  private readonly smtp: {
    host: string;
    port: number;
    user: string;
    pass: string;
  } | null;

  constructor(private readonly config: ConfigService) {
    const user = config.get<string>('SMTP_USER');
    const pass = config.get<string>('SMTP_PASS');
    if (!user || !pass) {
      this.logger.warn(
        'SMTP_USER/SMTP_PASS not set; email alerts are disabled.',
      );
      this.smtp = null;
      return;
    }
    this.smtp = {
      host: config.get<string>('SMTP_HOST', 'smtp-relay.brevo.com'),
      port: Number(config.get('SMTP_PORT', 2525)),
      user,
      pass,
    };
  }

  get enabled(): boolean {
    return this.smtp !== null;
  }

  /**
   * Nodemailer resolves hostnames with its own DNS queries (dns.resolve4),
   * which time out on some networks where the OS resolver works fine. So the
   * host is resolved here with the OS resolver and nodemailer gets the IP,
   * with the real hostname kept for TLS certificate checks.
   */
  private async createTransporter(): Promise<Transporter> {
    const { host, port, user, pass } = this.smtp!;
    const { address } = await lookup(host, { family: 4 });
    return createTransport({
      host: address,
      port,
      secure: port === 465,
      auth: { user, pass },
      tls: { servername: host },
    });
  }

  async sendOpportunity(opportunity: Opportunity): Promise<void> {
    const deadline = opportunity.deadline
      ? formatDate(opportunity.deadline)
      : 'Not stated';
    await this.send(
      `New study-abroad opportunity: ${opportunity.title}`,
      renderOpportunity(opportunity, deadline),
    );
  }

  async sendTest(): Promise<void> {
    await this.send(
      'OpNest test email',
      '<p>Your OpNest email alerts are set up correctly. New opportunities will arrive here.</p>',
    );
  }

  private async send(subject: string, html: string): Promise<void> {
    if (!this.smtp) {
      throw new Error('Email is not configured: set SMTP_USER and SMTP_PASS.');
    }
    // With relays like Brevo, SMTP_USER is a login, not a mailbox, so the
    // sender and default recipient come from MAIL_FROM when it is set.
    const fromAddress =
      this.config.get<string>('MAIL_FROM') ||
      this.config.getOrThrow<string>('SMTP_USER');
    const fromName = this.config.get<string>('MAIL_FROM_NAME') || 'OpNest';
    const message = {
      from: { name: fromName, address: fromAddress },
      to: this.config.get<string>('MAIL_TO') || fromAddress,
      subject,
      html,
    };
    // Network blips are common; retry a few times before the caller gives up
    // (the sync also retries unsent alerts on its next run).
    const attempts = 3;
    for (let i = 1; ; i++) {
      try {
        const transporter = await this.createTransporter();
        await transporter.sendMail(message);
        return;
      } catch (err) {
        if (i >= attempts) throw err;
        this.logger.warn(
          `Send attempt ${i} failed (${(err as Error).message}); retrying.`,
        );
        await new Promise((r) => setTimeout(r, 2000 * i));
      }
    }
  }
}

function renderOpportunity(o: Opportunity, deadline: string): string {
  const rows = [
    ['Country', o.country ?? 'Not stated'],
    ['Deadline', deadline],
    ['Level', o.levels.length ? o.levels.join(', ') : 'Not stated'],
  ]
    .map(
      ([label, value]) =>
        `<tr><td style="padding:4px 12px 4px 0;color:#666">${label}</td><td style="padding:4px 0"><strong>${escapeHtml(value)}</strong></td></tr>`,
    )
    .join('');
  const contacts = o.emails.length
    ? `<p><strong>Contacts:</strong> ${o.emails.map((e) => `<a href="mailto:${escapeHtml(e)}">${escapeHtml(e)}</a>`).join(', ')}</p>`
    : '';

  return `
<div style="font-family:Arial,sans-serif;max-width:640px;color:#222">
  <h2 style="margin:0 0 12px">${escapeHtml(o.title)}</h2>
  <table style="border-collapse:collapse;margin-bottom:16px">${rows}</table>
  <div style="white-space:pre-line;line-height:1.5">${escapeHtml(o.description)}</div>
  ${contacts}
  <p><a href="${escapeHtml(o.sourceUrl)}">View on the UG International Programmes Office page</a></p>
  <p style="color:#999;font-size:12px">Sent by OpNest. Details are extracted automatically; check the original page before applying.</p>
</div>`;
}

function formatDate(iso: string): string {
  return new Date(`${iso}T00:00:00Z`).toLocaleDateString('en-GB', {
    day: 'numeric',
    month: 'long',
    year: 'numeric',
    timeZone: 'UTC',
  });
}

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}
