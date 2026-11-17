#!/usr/bin/env node
// build-version: the deploy's version stamp, vYY.MM.DD.<daily build number>
// (openspec/changes/build-version). Run by scripts/build-web.sh.
//
//   node scripts/build-version.mjs [--out <file.json>]
//
// Prints the version string on stdout; --out also writes the full record as
// JSON (served as /version.json and /version). Everything is derived from git,
// so rebuilding one commit always gives the same version:
//
// - YY is years since 1970 (2026 -> 56), the Tillandsias scheme
//   (`<years_since_epoch>.<month>.<day>.<build>`, unpadded, e.g. 56.8.31.3).
// - The date is HEAD's committer date, read in the committer's own recorded
//   UTC offset (GitHub records the operator's -08:00 on PR merges).
// - The build number counts the first-parent commits on main that share that
//   date, ending at HEAD: each one is one Workers Builds production build.
// - A build that is not on main is `vYY.MM.DD-dev+<sha>`.
// - When the day's first merge is beyond a shallow clone's history and cannot
//   be fetched, the number is unknown: `vYY.MM.DD.0+<sha>`.
//
// Node rather than Lua: Workers Builds images ship Node (the build already
// runs through npm), not Lua.
import { execFileSync } from 'node:child_process';
import { writeFileSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export const PRODUCTION_BRANCH = 'main';

/** Tillandsias major: years since the Unix epoch (2026 -> 56). */
export function epochMajor(year) {
  return year - 1970;
}

/** The committer-local calendar date of a strict ISO 8601 date (`%cI`). */
export function localDay(iso) {
  const m = /^(\d{4})-(\d{2})-(\d{2})T/.exec(iso);
  if (!m) throw new Error(`not an ISO date: ${iso}`);
  return `${m[1]}-${m[2]}-${m[3]}`;
}

/**
 * The version string. [day] is `YYYY-MM-DD`; [build] is the daily number
 * (0 when unknown); [channel] is `production` or `dev`.
 */
export function formatVersion({ day, build, channel, commit }) {
  const [y, m, d] = day.split('-').map(Number);
  const base = `v${epochMajor(y)}.${m}.${d}`;
  const sha = commit ? `+${commit}` : '';
  if (channel !== 'production') return `${base}-dev${sha}`;
  if (!build) return `${base}.0${sha}`;
  return `${base}.${build}`;
}

/**
 * Counts the leading run of [commits] (newest first, first-parent order,
 * `{iso, root}`) on HEAD's day. `exact` is false when the history ran out
 * before an earlier day or the root commit was reached.
 */
export function countDailyBuilds(commits) {
  if (!commits.length) return { day: null, build: 0, exact: false };
  const day = localDay(commits[0].iso);
  let build = 0;
  for (const c of commits) {
    if (localDay(c.iso) !== day) return { day, build, exact: true };
    build++;
    if (c.root) return { day, build, exact: true };
  }
  return { day, build, exact: false };
}

const WALK = 400;

function git(cwd, args) {
  return execFileSync('git', args, { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();
}

// A shallow clone's oldest commit lists no parents, but it is not a root.
function firstParentLog(cwd, ref) {
  const shallow = isShallow(cwd);
  const out = git(cwd, ['log', '--first-parent', `-n${WALK}`, '--format=%cI%x09%P', ref]);
  return out.split('\n').filter(Boolean).map(line => {
    const [iso, parents = ''] = line.split('\t');
    return { iso, root: !shallow && parents.trim() === '' };
  });
}

function isShallow(cwd) {
  try {
    return git(cwd, ['rev-parse', '--is-shallow-repository']) === 'true';
  } catch {
    return false;
  }
}

/**
 * The full record for the checkout at [cwd]. [env] supplies
 * WORKERS_CI_BRANCH (Cloudflare Workers Builds); without it the checked-out
 * branch decides. [ref] (default HEAD) is the commit being built. [fetch] = false never touches the network.
 */
export function resolveBuildVersion({ cwd = process.cwd(), env = process.env, fetch = true, ref = 'HEAD' } = {}) {
  let commit = '';
  let branch = env.WORKERS_CI_BRANCH || '';
  let counted = { day: null, build: 0, exact: false };
  try {
    commit = git(cwd, ['rev-parse', '--short=8', ref]);
    if (!branch) {
      try {
        branch = git(cwd, ['symbolic-ref', '--short', '-q', 'HEAD']);
      } catch {
        branch = '';
      }
    }
    const production = branch === PRODUCTION_BRANCH;
    counted = countDailyBuilds(firstParentLog(cwd, ref));
    // A shallow clone (Workers Builds may clone shallow): deepen until the
    // day's boundary is visible, a few times at most, then give up safely.
    for (let i = 0; production && fetch && !counted.exact && i < 3 && isShallow(cwd); i++) {
      try {
        git(cwd, ['fetch', '--quiet', `--deepen=${32 << (i * 2)}`, 'origin']);
      } catch {
        break;
      }
      counted = countDailyBuilds(firstParentLog(cwd, ref));
    }
  } catch {
    // Not a git checkout: date the build today (UTC), as an unknown dev build.
  }
  const day = counted.day || new Date().toISOString().slice(0, 10);
  const channel = branch === PRODUCTION_BRANCH ? 'production' : 'dev';
  const build = channel === 'production' && counted.exact ? counted.build : 0;
  return {
    version: formatVersion({ day, build, channel, commit }),
    channel,
    date: day,
    build,
    commit,
    branch,
  };
}

const self = fileURLToPath(import.meta.url);
if (process.argv[1] && resolve(process.argv[1]) === self) {
  const args = process.argv.slice(2);
  const outAt = args.indexOf('--out');
  const record = resolveBuildVersion({ cwd: resolve(dirname(self), '..') });
  if (outAt >= 0) {
    const out = args[outAt + 1];
    mkdirSync(dirname(resolve(out)), { recursive: true });
    writeFileSync(out, `${JSON.stringify(record, null, 2)}\n`);
  }
  process.stdout.write(`${record.version}\n`);
}
