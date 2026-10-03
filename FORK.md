# uscreen fork of gethopp/hopp

This file exists only on the `uscreen` branch. The fork is public: no secrets and no
internal hostnames in commits.

## Remotes

| Remote     | Repo           | Purpose                               |
| ---------- | -------------- | ------------------------------------- |
| `origin`   | `uscreen/hopp` | our fork                              |
| `upstream` | `gethopp/hopp` | fetch only, push URL is `DISABLED`    |

Setup after a fresh clone:

```sh
git remote add upstream https://github.com/gethopp/hopp.git
git remote set-url --push upstream DISABLED
git config pull.ff only
git config rerere.enabled true
git config fetch.prune true
```

## Branch model

| Branch          | Base                 | Rules                                                                                      |
| --------------- | -------------------- | ------------------------------------------------------------------------------------------ |
| `main`          | `upstream/main`      | Pure mirror. Fast-forward only, never any commits of our own.                              |
| `uscreen`       | latest upstream tag  | What we run, and the default branch. Internal patches only, as small commits that rebase individually. |
| `feat/<topic>`  | `main`               | One branch per upstream PR. Never contains internal patches.                               |
| `spike/<topic>` | `main`               | Spikes, throwaway.                                                                         |

Deploy releases are tags on `uscreen` named `<upstream-tag>-uscreen.<n>`,
e.g. `v1.0.32-uscreen.1`. `<n>` restarts at 1 for every upstream tag.

GitHub protection: `main` allows no force-push and no deletion, and only org admins can
update it (the sync). `uscreen` cannot be deleted; force-push is allowed (rebase).
Tags matching `v*-uscreen.*` are immutable.

Upstream workflows: GitHub does not run them in the fork until they are enabled once in
the Actions tab. Right after enabling, disable `release.yml`, `publish-backend-image.yml`
and `trigger_prod.yml` (`gh workflow disable <file> -R uscreen/hopp`); only `ci.yml`
should run.

## Language and commit convention

Everything in this repo is written in English: code, comments, docs, commit messages,
PR descriptions.

Conventional Commits as configured in `cliff.toml` (git-cliff): `<type>(<scope>): <description>`,
scope optional, `!` for breaking changes.

Types: `feat`, `fix`, `doc`, `perf`, `refactor`, `style`, `test`, `chore`, `ci`, `revert`.

Commits without a valid type are dropped from the upstream changelog (`filter_unconventional`),
as are `chore(release)`, `chore(deps)`, `chore(pr)` and `chore(pull)`. Always use one of the
types above on `feat/` branches.

## Sync upstream

```sh
scripts/sync-upstream.sh
```

The script runs `git fetch upstream --tags`, fast-forwards `main` to `upstream/main`, and
pushes `main` plus new upstream tags to `origin`. It aborts if `main` contains commits of
our own. By hand:

```sh
git fetch upstream --tags
git switch main
git merge --ff-only upstream/main
git push origin main
git push origin refs/tags/<new-tag>
```

## Rebase uscreen onto a new tag

```sh
scripts/sync-upstream.sh
git switch uscreen
git rebase --onto <new-tag> <old-tag>     # e.g. --onto v1.0.33 v1.0.32
# build and test
git push --force-with-lease origin uscreen
git tag -a <new-tag>-uscreen.1 -m "<new-tag>-uscreen.1"
git push origin <new-tag>-uscreen.1
```

On conflicts:

- Resolve, `git add <files>`, `git rebase --continue`. `rerere` remembers the resolution
  for the next rebase.
- If a patch has landed upstream: `git rebase --skip` and remove it from the list below.
- To back out safely: `git rebase --abort`.
- Never use `--force` without `--with-lease`. The previous state stays reachable through
  the previous deploy tag.

New internal patch without a new upstream tag: commit on `uscreen`, regular push, tag with
`<n>` incremented (`v1.0.32-uscreen.2`).

## Start a new upstream PR

```sh
scripts/sync-upstream.sh
git switch -c feat/<topic> main
# work, commit following the convention
git push -u origin feat/<topic>
gh pr create --repo gethopp/hopp --base main --head uscreen:feat/<topic>
```

Rebase onto current `main` before review (`git rebase main`, then
`git push --force-with-lease`). If we need the feature in production before upstream merges
it, cherry-pick it onto `uscreen` and add it to the list below.

## Internal patches

Same order as `git log <upstream-tag>..uscreen`.

| Commit                                | Reason                                                             | Upstreamable |
| ------------------------------------- | ------------------------------------------------------------------ | ------------ |
| `doc: add FORK.md`                    | Documents the branch model and workflows of this fork.             | no           |
| `chore: add scripts/sync-upstream.sh` | Keeps `main` a fast-forward mirror and propagates upstream tags.   | no           |
