# leetcode-daily-redirect

Visit your GitHub Pages URL → land on `leetcode.com/problems/<today's-daily-challenge>/` instantly.

## How it works

GitHub Pages only serves static files — there's no server to hit LeetCode's API at the
moment you load the page. So instead of fetching the problem in your browser (which also
runs into CORS, since `leetcode.com/graphql` isn't set up to answer requests from other
sites' JavaScript), a **GitHub Actions workflow runs once a day**, asks LeetCode's API
(server-to-server, no CORS involved) what today's daily challenge is, and rewrites
`index.html` with a redirect baked directly into the page. Pages just serves that static
file. Your browser never has to talk to LeetCode's API at all — the page already knows
where to send you the instant it loads (via a `<meta refresh>`, a `location.replace()`
in a script tag, and a manual link, in that order of precedence).

```
.github/workflows/update-daily-challenge.yml   → runs daily at 00:05 UTC + on push + manually
scripts/sync-daily-challenge.sh                → fetches today's challenge, rebuilds index.html
template.html                                  → the page design (source of truth)
index.html                                     → generated output; this is what Pages serves
```

## Setup

1. **Create a repo** (public — GitHub Pages on private repos needs a paid plan) and add
   these files, keeping the folder structure intact (the workflow file must stay under
   `.github/workflows/`).
2. **Push to `main`.** The workflow is set to also run on push, so this triggers the
   first sync automatically — within about a minute `index.html` will be rewritten with
   today's real challenge.
3. **Enable Pages:** repo → Settings → Pages → Source: "Deploy from a branch" → Branch
   `main`, folder `/ (root)` → Save.
4. Visit `https://<your-username>.github.io/<repo-name>/`. Check the Actions tab if you
   want to confirm the first run succeeded before you do.

Nothing else to configure — the workflow requests its own `contents: write` permission,
so it can commit the daily update without you touching repo-wide Action settings.

## Customizing

- **Look and feel:** edit `template.html` (colors are CSS variables at the top of the
  `<style>` block). `scripts/sync-daily-challenge.sh` fills in the `__TOKEN__` placeholders
  and writes the result to `index.html` — don't hand-edit `index.html` directly, it gets
  overwritten on the next sync.
- **Schedule:** change the cron line in the workflow file. `00:05 UTC` gives a small buffer
  after LeetCode's `00:00 UTC` daily rollover.
- **Manual re-run:** Actions tab → "Update daily LeetCode redirect" → "Run workflow".

## Troubleshooting

- **First visit shows "Not synced yet":** the push-triggered run hasn't finished. Check
  the Actions tab; it usually takes well under a minute.
- **Workflow run fails at the fetch step:** LeetCode occasionally rate-limits or blocks
  automated requests, including from shared CI IP ranges. The script is written to leave
  `index.html` untouched on any failure (bad HTTP status, unexpected response shape), so
  the page never breaks — it just keeps yesterday's link until a run succeeds. Re-run it
  manually via `workflow_dispatch`, or check the run's log output for the raw response.
- **Push succeeded but nothing changed:** the commit step only pushes when the generated
  `index.html` actually differs, so "nothing to commit" in the log is expected on a
  no-op run (e.g., you re-ran it the same day).

## A caveat

The GraphQL query and response shape here (`leetcode.com/graphql`, `questionOfToday` /
`activeDailyCodingChallengeQuestion`) are based on how several existing open-source
LeetCode tools call this endpoint — LeetCode doesn't publish official API docs. I
wasn't able to hit `leetcode.com` directly from my own sandbox to run a live end-to-end
test (network is restricted to package registries there), so I validated the script's
parsing/templating logic against a mocked response instead. Worth confirming the first
real run in your Actions tab looks right — if LeetCode has changed the schema, paste the
error log back and I'll help fix it.
