import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, Repository } from 'typeorm';
import { Opportunity } from './opportunity.entity';

export type OpportunityStatus = 'open' | 'closed' | 'unknown';

export interface ListQuery {
  status?: OpportunityStatus | 'all';
  level?: string;
  country?: string;
  q?: string;
}

export type OpportunityView = Omit<Opportunity, 'fingerprint'> & {
  status: OpportunityStatus;
  daysLeft: number | null;
  isNew: boolean;
};

const NEW_FOR_DAYS = 14;
const DAY_MS = 86_400_000;

@Injectable()
export class OpportunitiesService {
  constructor(
    @InjectRepository(Opportunity)
    private readonly repo: Repository<Opportunity>,
  ) {}

  async list(query: ListQuery): Promise<OpportunityView[]> {
    // Newest postings sit at the bottom of the IPO page, hence position DESC.
    const rows = await this.repo.find({
      where: { removedAt: IsNull() },
      order: { position: 'DESC' },
    });
    const q = query.q?.trim().toLowerCase();

    return rows
      .map(toView)
      .filter(
        (o) =>
          !query.status || query.status === 'all' || o.status === query.status,
      )
      .filter(
        (o) =>
          !query.level ||
          o.levels.some((l) => l.toLowerCase() === query.level!.toLowerCase()),
      )
      .filter(
        (o) =>
          !query.country ||
          o.country?.toLowerCase() === query.country.toLowerCase(),
      )
      .filter(
        (o) =>
          !q ||
          o.title.toLowerCase().includes(q) ||
          o.description.toLowerCase().includes(q),
      );
  }

  async get(id: number): Promise<OpportunityView> {
    const row = await this.repo.findOneBy({ id });
    if (!row) throw new NotFoundException(`Opportunity ${id} not found`);
    return toView(row);
  }
}

function toView(o: Opportunity): OpportunityView {
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  const { fingerprint, ...rest } = o;
  const daysLeft = o.deadline ? daysUntil(o.deadline) : null;
  return {
    ...rest,
    status: daysLeft === null ? 'unknown' : daysLeft >= 0 ? 'open' : 'closed',
    daysLeft,
    isNew: Date.now() - o.firstSeenAt.getTime() < NEW_FOR_DAYS * DAY_MS,
  };
}

/** Whole days from today (UTC) to the deadline; 0 means it closes today. */
function daysUntil(iso: string): number {
  const today = new Date();
  const todayUtc = Date.UTC(
    today.getUTCFullYear(),
    today.getUTCMonth(),
    today.getUTCDate(),
  );
  return Math.round((Date.parse(`${iso}T00:00:00Z`) - todayUtc) / DAY_MS);
}
