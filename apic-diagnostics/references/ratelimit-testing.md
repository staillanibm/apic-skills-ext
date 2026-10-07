# Testing rate limits

- Intervals start on the clock (a 1-minute interval starts at the beginning of each minute). Start the burst at the
  beginning of a minute, otherwise the counter can reset in the middle of the test.
- `scripts/ratelimit_burst.py` implements this procedure (distinct credentials check, start of the minute, redacted output).
- Wake the runtime first with a call without credentials (401), then wait about 10 seconds.
- Plan limit (shared): one application, N+2 calls, expect N times 200 then 429.
- Per-consumer limit: two applications in the same minute. Application A sends max+2 calls (max times 200, then 429).
  Application B then sends max calls: all 200 proves independent counters. If B gets 429 at once, the counter is shared.
- Global cap with both levels: needs more consumers than `plan max / per-consumer max` (three consumers for 10 and 5).
  Verified: two consumers 5 x 200 each, the third 429.
- Check counts, not just status: a refused call must not be counted against the other level (it was not, in the
  verified run).
- Assert in the script that the credentials of each consumer are distinct before reading the result: a reused
  credential makes the last group hit its own per-consumer limit and looks like the global cap.
- A 401 for a consumer that used to work usually means its subscription was deleted in API Manager.
- Write the test as a script that reads the creds file and redacts the client id and secret from any output. Do not
  use `sleep` chains longer than the tool timeout; run the script in the background and read its output file.

Status: verified for plan limit, per-consumer limit and the global cap with three consumers (2026-10-07).
