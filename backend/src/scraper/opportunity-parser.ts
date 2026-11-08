import { createHash } from 'node:crypto';
import * as cheerio from 'cheerio';
import type { AnyNode } from 'domhandler';
import { COUNTRIES, COUNTRY_ALIASES } from './countries';

export type StudyLevel = 'Undergraduate' | 'Masters' | 'PhD';

export interface ParsedLink {
  text: string;
  url: string;
}

export interface ParsedOpportunity {
  fingerprint: string;
  title: string;
  country: string | null;
  /** ISO date (YYYY-MM-DD), or null when no deadline could be found. */
  deadline: string | null;
  /** The sentence the deadline was read from, for display and debugging. */
  deadlineText: string | null;
  levels: StudyLevel[];
  summary: string;
  description: string;
  emails: string[];
  links: ParsedLink[];
  /** Order on the page; the IPO appends new postings at the bottom. */
  position: number;
}

// The University of Ghana is the home institution, so "Ghana" appears in
// almost every listing and says nothing about the destination.
const HOME_COUNTRY = 'Ghana';

const MONTHS = [
  'january',
  'february',
  'march',
  'april',
  'may',
  'june',
  'july',
  'august',
  'september',
  'october',
  'november',
  'december',
];
const DATE =
  '((?:jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\\.?\\s+\\d{1,2}(?:st|nd|rd|th)?,?\\s+\\d{4})';

// Tried in order; the first match wins. Covers the phrasings the IPO uses:
// "Application Deadline: December 3, 2025", "on or before March 2, 2026",
// "submit ... by March 12, 2026" and "Candidate applications — From
// September 23 to October 30, 2026".
const DEADLINE_PATTERNS = [
  new RegExp(`deadline\\s*[:\\-–—]?\\s*${DATE}`, 'i'),
  new RegExp(`on or before\\s+${DATE}`, 'i'),
  new RegExp(`\\b(?:submit|send|apply)\\b[^\\n]*?\\bby\\s+${DATE}`, 'i'),
  new RegExp(`\\bapplications?\\b[\\s\\S]{0,60}?\\bto\\s+${DATE}`, 'i'),
];

export function parseOpportunities(html: string): ParsedOpportunity[] {
  const $ = cheerio.load(html);
  const results: ParsedOpportunity[] = [];

  $('.collapsible-header').each((index, header) => {
    const rawTitle = cleanLine($(header).text());
    const body = $(header).siblings('.collapsible-body').first();
    if (!rawTitle || body.length === 0) return;

    const description = toText($, body);
    const { deadline, deadlineText } = findDeadline(description);

    results.push({
      fingerprint: fingerprint(rawTitle, deadlineText ?? description),
      title: toTitleCase(rawTitle),
      country: findCountry(rawTitle, description),
      deadline,
      deadlineText,
      levels: findLevels(description),
      summary: description.split('\n').find((l) => l.length > 40) ?? '',
      description,
      emails: findEmails($, body, description),
      links: findLinks($, body),
      position: index,
    });
  });

  return results;
}

/** Flattens the body HTML into readable text, one block element per line. */
function toText($: cheerio.CheerioAPI, el: cheerio.Cheerio<AnyNode>): string {
  const copy = el.clone();
  copy.find('br').replaceWith('\n');
  copy.find('td, th').each((_, cell) => void $(cell).append('\t'));
  copy
    .find('p, li, tr, div, h1, h2, h3, h4, h5, h6')
    .each((_, block) => void $(block).append('\n'));

  return copy
    .text()
    .split('\n')
    .map((line) =>
      cleanLine(line.replace(/\t+$/, '').replace(/\s*\t\s*/g, ' — ')),
    )
    .filter((line) => line && line !== '•')
    .join('\n');
}

function cleanLine(text: string): string {
  // \s also matches the non-breaking spaces the page is full of.
  return text.replace(/\s+/g, ' ').trim();
}

function findDeadline(text: string) {
  for (const pattern of DEADLINE_PATTERNS) {
    const match = pattern.exec(text);
    if (!match) continue;
    const deadline = toIsoDate(match[1]);
    if (!deadline) continue;
    const line = text.split('\n').find((l) => l.includes(match[1])) ?? match[0];
    return { deadline, deadlineText: line };
  }
  return { deadline: null, deadlineText: null };
}

function toIsoDate(text: string): string | null {
  const match = /([a-z]+)\.?\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{4})/i.exec(
    text,
  );
  if (!match) return null;
  const month = MONTHS.findIndex((m) =>
    m.startsWith(match[1].toLowerCase().slice(0, 3)),
  );
  const day = Number(match[2]);
  if (month < 0 || day < 1 || day > 31) return null;
  return `${match[3]}-${String(month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
}

/**
 * Prefers a country named in the title. When the title names several (the
 * page has "HALIC UNIVERSITY, TURKEY, LATVIA") or none, the one mentioned
 * most often in the description wins.
 */
function findCountry(title: string, description: string): string | null {
  const inTitle = countriesIn(title);
  if (inTitle.length === 1) return inTitle[0];

  const counts = new Map<string, number>();
  for (const country of countriesIn(description, true)) {
    counts.set(country, (counts.get(country) ?? 0) + 1);
  }
  const candidates = inTitle.length > 0 ? inTitle : [...counts.keys()];
  const best = candidates.sort(
    (a, b) => (counts.get(b) ?? 0) - (counts.get(a) ?? 0),
  )[0];
  return best ?? null;
}

function countriesIn(text: string, allOccurrences = false): string[] {
  const found: string[] = [];
  for (const name of COUNTRIES) {
    const pattern = new RegExp(`\\b${name}\\b`, 'gi');
    const hits = text.match(pattern)?.length ?? 0;
    const canonical = COUNTRY_ALIASES[name.toLowerCase()] ?? name;
    if (hits === 0 || canonical === HOME_COUNTRY) continue;
    for (let i = 0; i < (allOccurrences ? hits : 1); i++) found.push(canonical);
  }
  return allOccurrences ? found : [...new Set(found)];
}

function findLevels(text: string): StudyLevel[] {
  const levels: StudyLevel[] = [];
  if (/undergraduate|bachelor|\bBA\b/i.test(text)) levels.push('Undergraduate');
  if (/mphil|master|\bMA\b|\bMSc\b/i.test(text)) levels.push('Masters');
  if (/\bph\.?d\b|doctoral|doctorate/i.test(text)) levels.push('PhD');
  return levels;
}

function findEmails(
  $: cheerio.CheerioAPI,
  body: cheerio.Cheerio<AnyNode>,
  text: string,
): string[] {
  const fromLinks = body
    .find('a[href^="mailto:"]')
    .map((_, a) => ($(a).attr('href') ?? '').replace(/^mailto:/i, ''))
    .get();
  const fromText = text.match(/[\w.+-]+@[\w-]+(?:\.[\w-]+)+/g) ?? [];
  return [
    ...new Set([...fromLinks, ...fromText].map((e) => e.trim().toLowerCase())),
  ].filter(Boolean);
}

function findLinks(
  $: cheerio.CheerioAPI,
  body: cheerio.Cheerio<AnyNode>,
): ParsedLink[] {
  const links = new Map<string, ParsedLink>();
  body.find('a[href^="http"]').each((_, a) => {
    const url = ($(a).attr('href') ?? '').trim();
    // The page has some email addresses mislinked as "http://name@ug.edu.gh".
    if (!url || links.has(url) || /^https?:\/\/[^/]*@/i.test(url)) return;
    links.set(url, { text: cleanLine($(a).text()) || url, url });
  });
  return [...links.values()];
}

/**
 * Identifies an opportunity across syncs. The deadline line is included so
 * that a re-posted call for the same university (e.g. Freiburg, which appears
 * once per semester) counts as new.
 */
function fingerprint(rawTitle: string, discriminator: string): string {
  const key = `${rawTitle.toLowerCase()}|${cleanLine(discriminator).toLowerCase().slice(0, 200)}`;
  return createHash('sha256').update(key).digest('hex');
}

const SMALL_WORDS = new Set([
  'of',
  'at',
  'in',
  'and',
  'de',
  'la',
  'the',
  'for',
]);
const ACRONYMS = new Set(['capes', 'pec-pg', 'daad', 'usa', 'uk']);

function toTitleCase(text: string): string {
  return text
    .split(' ')
    .map((word, i) => {
      if (/^\(.+\),?$/.test(word)) return word; // acronyms like "(ALU)"
      const lower = word.toLowerCase();
      const bare = lower.replace(/[^\p{L}-]/gu, '');
      if (ACRONYMS.has(bare)) return word.toUpperCase();
      if (i > 0 && SMALL_WORDS.has(lower)) return lower;
      return lower
        .replace(
          /(^|-)(\p{L})/gu,
          (_, sep: string, c: string) => sep + c.toUpperCase(),
        )
        .replace(/^Mc(\p{L})/u, (_, c: string) => 'Mc' + c.toUpperCase());
    })
    .join(' ');
}
