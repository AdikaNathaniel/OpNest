import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios from 'axios';
import { ParsedOpportunity, parseOpportunities } from './opportunity-parser';

@Injectable()
export class ScraperService {
  constructor(private readonly config: ConfigService) {}

  get sourceUrl(): string {
    return this.config.getOrThrow<string>('SOURCE_URL');
  }

  async fetchOpportunities(): Promise<ParsedOpportunity[]> {
    const { data } = await axios.get<string>(this.sourceUrl, {
      responseType: 'text',
      timeout: 30_000,
      headers: { 'User-Agent': 'OpNest/1.0 (study-abroad opportunity alerts)' },
    });
    const opportunities = parseOpportunities(data);
    // An empty result almost always means the page layout changed, not that
    // every opportunity was withdrawn. Failing here stops the sync from
    // marking everything as removed.
    if (opportunities.length === 0) {
      throw new Error(
        `No opportunities found at ${this.sourceUrl}; the page layout may have changed.`,
      );
    }
    return opportunities;
  }
}
