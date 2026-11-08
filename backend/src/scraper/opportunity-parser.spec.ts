import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { parseOpportunities } from './opportunity-parser';

// A snapshot of the IPO page taken on 2026-11-02. If the live page changes
// layout, refresh this fixture and update the expectations.
const html = readFileSync(
  join(__dirname, '../../test/fixtures/exchange-opportunities.html'),
  'utf8',
);

describe('parseOpportunities', () => {
  const items = parseOpportunities(html);
  const byTitle = (part: string) => {
    const found = items.find((o) => o.title.toLowerCase().includes(part));
    if (!found) throw new Error(`No opportunity matching "${part}"`);
    return found;
  };

  it('finds every listing with a unique fingerprint', () => {
    expect(items).toHaveLength(17);
    expect(new Set(items.map((o) => o.fingerprint)).size).toBe(17);
  });

  it('reads the "on or before" deadline phrasing', () => {
    expect(byTitle('uppsala').deadline).toBe('2026-09-30');
  });

  it('reads the "Application Deadline:" phrasing', () => {
    expect(byTitle('sciences po').deadline).toBe('2025-12-03');
  });

  it('reads the "submit ... by" phrasing', () => {
    expect(byTitle('potsdam').deadline).toBe('2026-03-12');
  });

  it('reads the end of an application date range', () => {
    expect(byTitle('capes').deadline).toBe('2026-10-30');
  });

  it('leaves the deadline empty when none is stated', () => {
    expect(byTitle('mccall').deadline).toBeNull();
  });

  it('picks the destination country, not the home country', () => {
    expect(byTitle('halic').country).toBe('Turkey');
    expect(byTitle('esslingen').country).toBe('Germany');
    expect(items[items.length - 1].country).toBe('Germany'); // Freiburg, no country in title
  });

  it('detects study levels and contacts', () => {
    const halic = byTitle('halic');
    expect(halic.levels).toEqual(['Undergraduate']);
    expect(halic.emails).toEqual(['sacip@ug.edu.gh', 'arip@ug.edu.gh']);
  });

  it('formats titles for display', () => {
    expect(byTitle('freiburg (alu)').title).toBe(
      'Albert Ludwigs University of Freiburg (ALU), Germany',
    );
    expect(byTitle('mccall').title).toContain('McGill');
  });
});
