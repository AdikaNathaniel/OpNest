# OpNest backend

Watches the University of Ghana International Programmes Office
[exchange opportunities page](https://ipo.ug.edu.gh/study-abroad/exchange-opportunities),
stores each listing, emails you when a new one is posted, and serves the
listings to the Flutter app.

## Setup

1. `npm install`
2. Copy `.env.example` to `.env` and fill it in.
3. Create a Gmail App Password for `SMTP_PASS`:
   - Turn on 2-Step Verification for your Google account.
   - Go to <https://myaccount.google.com/apppasswords>, create one named "OpNest",
     and paste the 16-character password into `.env`.
   - Your normal Gmail password will not work.
4. `npm run start:dev`
5. Check email works:
   ```
   curl -X POST -H "x-admin-token: <ADMIN_TOKEN>" http://localhost:3000/notifications/test
   ```

## How alerts work

- The page is checked on startup and then on `SYNC_CRON` (every 6 hours by default).
- The first check stores what's already on the page without emailing it, so you
  only hear about postings that appear after that. Set
  `NOTIFY_EXISTING_ON_FIRST_SYNC=true` to get them all on the first run.
- Each new listing gets its own email. If sending fails, it is retried on the
  next check.
- If the page returns no listings at all (usually a layout change), the check
  fails and nothing is marked removed. Watch the logs for `Sync failed`.

The server must keep running for alerts to arrive, so host it somewhere
always-on (a small VPS, Render, Railway, Fly.io) rather than your laptop.

## API

| Method | Path | Notes |
|---|---|---|
| GET | `/opportunities` | Newest first. Query: `status=open\|closed\|unknown\|all`, `level=Undergraduate\|Masters\|PhD`, `country`, `q` (text search). |
| GET | `/opportunities/:id` | One opportunity with its full description. |
| POST | `/sync` | Check the page now. Needs `x-admin-token`. |
| POST | `/notifications/test` | Send a test email. Needs `x-admin-token`. |
| GET | `/health` | Liveness check. |

Each opportunity includes `title`, `country`, `deadline` (YYYY-MM-DD),
`deadlineText`, `levels`, `summary`, `description`, `emails`, `links`,
`status`, `daysLeft` and `isNew` (first seen in the last 14 days).

## Parser

`src/scraper/opportunity-parser.ts` turns the page HTML into listings. The IPO
writes each listing by hand, so fields such as the deadline are read with
patterns and may be missing for unusual wording. `npm test` runs it against a
saved copy of the page in `test/fixtures/`; if the live page changes layout,
save a fresh copy there and update the tests.
