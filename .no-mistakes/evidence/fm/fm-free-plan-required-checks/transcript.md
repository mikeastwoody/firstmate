# Live transcript: declared required checks on a plan that hides branch rules

Real bin/fm-pr-merge.sh and bin/fm-park.sh from this worktree, real gh 2.103.3, disposable lab home (bin/fm-lab-home.sh).
gh addresses GH_HOST=github.localhost (declared in the lab's config/github-hosts) over HTTP through a local GitHub API emulator (harness/github_emulator.py).
The emulator answers the branch-rules read with GitHub's real 403 body: 'Upgrade to GitHub Pro or make this repository public to enable this feature.'

## 01-skip-ci-undeclared-merges  (exit 0)
```
$ FM_HOME=/var/folders/t0/8lf233xd7bxcd3x5x09vqgvm0000gn/T/fm-lab.Uyc120 bin/fm-pr-merge.sh task-s1b https://github.localhost/acme/app/pull/22 
# config/github-required-checks:
#   (no config/github-required-checks in the lab home)
verified: https://github.localhost/acme/app/pull/22 is open and mergeable, with every unwaived required check reported and every unwaived check green at head d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1
armed: state/task-s1b.check.sh
verified: https://github.localhost/acme/app/pull/22 is merged (state=MERGED, merged=true, isInMergeQueue=false)
# GitHub requests:
#   POST /graphql query PullRequestByNumber($owner: String!, $repo: String!, $
#   POST /graphql query PullRequestByNumber($owner: String!, $repo: String!, $
#   GET /repos/acme/app/branches/main 
#   GET /repos/acme/app/rules/branches/main?per_page=100 
#   POST /graphql query PullRequest_fields2{WorkflowRun: __type(name: "Workflo
#   POST /graphql query PullRequest_fields{PullRequest: __type(name: "PullRequ
#   POST /graphql query PullRequestByNumber($owner: String!, $repo: String!, $
#   POST /graphql mergePullRequest expectedHeadOid=d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1 SQUASH
#   POST /graphql query($owner:String!,$repo:String!,$number:Int!){repository(
```

## 02-skip-ci-declared-refuses  (exit 1)
```
$ FM_HOME=/var/folders/t0/8lf233xd7bxcd3x5x09vqgvm0000gn/T/fm-lab.Uyc120 bin/fm-pr-merge.sh task-s2 https://github.localhost/acme/app/pull/31 
# config/github-required-checks:
#   # checks this home requires on acme/app
#   github.localhost/acme/app github-actions pull_request build
error: refusing to merge https://github.localhost/acme/app/pull/31
  - declared required check 'build' (github-actions, pull_request) has not reported at head d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1
error: these required checks have not reported: build
armed: state/task-s2.check.sh
# GitHub requests:
#   POST /graphql query PullRequestByNumber($owner: String!, $repo: String!, $
#   POST /graphql query PullRequestByNumber($owner: String!, $repo: String!, $
#   GET /repos/acme/app/branches/main 
#   GET /repos/acme/app/rules/branches/main?per_page=100 
#   GET /repos/acme/app/commits/d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1/check-runs?filter=all&per_page=100 
#   GET /repos/acme/app/actions/runs?head_sha=d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1&per_page=100 
```

## 03-dispatch-undeclared-merges  (exit 0)
```
$ FM_HOME=/var/folders/t0/8lf233xd7bxcd3x5x09vqgvm0000gn/T/fm-lab.Uyc120 bin/fm-pr-merge.sh task-s3 https://github.localhost/acme/app/pull/41 
# config/github-required-checks:
#   (no config/github-required-checks in the lab home)
verified: https://github.localhost/acme/app/pull/41 is open and mergeable, with every unwaived required check reported and every unwaived check green at head d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2
armed: state/task-s3.check.sh
verified: https://github.localhost/acme/app/pull/41 is merged (state=MERGED, merged=true, isInMergeQueue=false)
# GitHub requests:
#   POST /graphql query PullRequestByNumber($owner: String!, $repo: String!, $
#   POST /graphql query PullRequestByNumber($owner: String!, $repo: String!, $
#   GET /repos/acme/app/branches/main 
#   GET /repos/acme/app/rules/branches/main?per_page=100 
#   POST /graphql query PullRequestByNumber($owner: String!, $repo: String!, $
#   POST /graphql mergePullRequest expectedHeadOid=d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2 SQUASH
#   POST /graphql query($owner:String!,$repo:String!,$number:Int!){repository(
```

## 04-dispatch-declared-refuses  (exit 1)
```
$ FM_HOME=/var/folders/t0/8lf233xd7bxcd3x5x09vqgvm0000gn/T/fm-lab.Uyc120 bin/fm-pr-merge.sh task-s4 https://github.localhost/acme/app/pull/51 
# config/github-required-checks:
#   # checks this home requires on acme/app
#   github.localhost/acme/app github-actions pull_request build
error: refusing to merge https://github.localhost/acme/app/pull/51
  - declared required check 'build' (github-actions, pull_request) has not succeeded at head d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2
error: these checks are not green: build
armed: state/task-s4.check.sh
# GitHub requests:
#   POST /graphql query PullRequestByNumber($owner: String!, $repo: String!, $
#   POST /graphql query PullRequestByNumber($owner: String!, $repo: String!, $
#   GET /repos/acme/app/branches/main 
#   GET /repos/acme/app/rules/branches/main?per_page=100 
#   GET /repos/acme/app/commits/d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2/check-runs?filter=all&per_page=100 
#   GET /repos/acme/app/actions/runs?head_sha=d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2&per_page=100 
```

## 05-declared-event-rerun-merges  (exit 0)
```
$ FM_HOME=/var/folders/t0/8lf233xd7bxcd3x5x09vqgvm0000gn/T/fm-lab.Uyc120 bin/fm-pr-merge.sh task-s5 https://github.localhost/acme/app/pull/61 
# config/github-required-checks:
#   # checks this home requires on acme/app
#   github.localhost/acme/app github-actions pull_request build
verified: https://github.localhost/acme/app/pull/61 is open and mergeable, with every unwaived required check reported and every unwaived check green at head d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
armed: state/task-s5.check.sh
verified: https://github.localhost/acme/app/pull/61 is merged (state=MERGED, merged=true, isInMergeQueue=false)
# GitHub requests:
#   POST /graphql query PullRequestByNumber($owner: String!, $repo: String!, $
#   POST /graphql query PullRequestByNumber($owner: String!, $repo: String!, $
#   GET /repos/acme/app/branches/main 
#   GET /repos/acme/app/rules/branches/main?per_page=100 
#   GET /repos/acme/app/commits/d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3/check-runs?filter=all&per_page=100 
#   GET /repos/acme/app/actions/runs?head_sha=d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3&per_page=100 
#   POST /graphql query PullRequestByNumber($owner: String!, $repo: String!, $
#   POST /graphql mergePullRequest expectedHeadOid=d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3 SQUASH
#   POST /graphql query($owner:String!,$repo:String!,$number:Int!){repository(
```

## 06-rules-visible-declaration-ignored  (exit 0)
```
$ FM_HOME=/var/folders/t0/8lf233xd7bxcd3x5x09vqgvm0000gn/T/fm-lab.Uyc120 bin/fm-pr-merge.sh task-s6 https://github.localhost/acme/app/pull/71 
# config/github-required-checks:
#   # checks this home requires on acme/app
#   github.localhost/acme/app github-actions pull_request build
verified: https://github.localhost/acme/app/pull/71 is open and mergeable, with every unwaived required check reported and every unwaived check green at head d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1
armed: state/task-s6.check.sh
verified: https://github.localhost/acme/app/pull/71 is merged (state=MERGED, merged=true, isInMergeQueue=false)
# GitHub requests:
#   POST /graphql query PullRequestByNumber($owner: String!, $repo: String!, $
#   POST /graphql query PullRequestByNumber($owner: String!, $repo: String!, $
#   GET /repos/acme/app/branches/main 
#   GET /repos/acme/app/rules/branches/main?per_page=100 
#   POST /graphql query PullRequestByNumber($owner: String!, $repo: String!, $
#   POST /graphql mergePullRequest expectedHeadOid=d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1 SQUASH
#   POST /graphql query($owner:String!,$repo:String!,$number:Int!){repository(
```

## 07-dash-event-declaration-refused  (exit 1)
```
$ FM_HOME=/var/folders/t0/8lf233xd7bxcd3x5x09vqgvm0000gn/T/fm-lab.Uyc120 bin/fm-pr-merge.sh task-s7 https://github.localhost/acme/app/pull/81 
# config/github-required-checks:
#   github.localhost/acme/app github-actions - build
error: refusing to merge https://github.localhost/acme/app/pull/81
  - line 1 of /var/folders/t0/8lf233xd7bxcd3x5x09vqgvm0000gn/T/fm-lab.Uyc120/config/github-required-checks is not a valid required-check declaration, so a required check that has not reported cannot be ruled out
armed: state/task-s7.check.sh
# GitHub requests:
#   POST /graphql query PullRequestByNumber($owner: String!, $repo: String!, $
#   POST /graphql query PullRequestByNumber($owner: String!, $repo: String!, $
#   GET /repos/acme/app/branches/main 
#   GET /repos/acme/app/rules/branches/main?per_page=100 
```

## 08-malformed-other-repo-line-refuses  (exit 1)
```
$ FM_HOME=/var/folders/t0/8lf233xd7bxcd3x5x09vqgvm0000gn/T/fm-lab.Uyc120 bin/fm-pr-merge.sh task-s8 https://github.localhost/acme/app/pull/91 
# config/github-required-checks:
#   github.localhost/acme/app github-actions pull_request build
#   github.com/other/repo github-actions push
error: refusing to merge https://github.localhost/acme/app/pull/91
  - line 2 of /var/folders/t0/8lf233xd7bxcd3x5x09vqgvm0000gn/T/fm-lab.Uyc120/config/github-required-checks is not a valid required-check declaration, so a required check that has not reported cannot be ruled out
armed: state/task-s8.check.sh
# GitHub requests:
#   POST /graphql query PullRequestByNumber($owner: String!, $repo: String!, $
#   POST /graphql query PullRequestByNumber($owner: String!, $repo: String!, $
#   GET /repos/acme/app/branches/main 
#   GET /repos/acme/app/rules/branches/main?per_page=100 
```

## 09a-away-skip-ci-undeclared-merges  (exit 0)
```
$ FM_HOME=/var/folders/t0/8lf233xd7bxcd3x5x09vqgvm0000gn/T/fm-lab.Uyc120 bin/fm-pr-merge.sh task-s9a https://github.localhost/acme/app/pull/101 
# config/github-required-checks:
#   (no config/github-required-checks in the lab home)
verified: https://github.localhost/acme/app/pull/101 is open and mergeable, with every unwaived required check reported and every unwaived check green at head d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1
armed: state/task-s9a.check.sh
verified: https://github.localhost/acme/app/pull/101 is merged (state=MERGED, merged=true, isInMergeQueue=false)
# GitHub requests:
#   POST /graphql query PullRequestByNumber($owner: String!, $repo: String!, $
#   POST /graphql query PullRequestByNumber($owner: String!, $repo: String!, $
#   GET /repos/acme/app/branches/main 
#   GET /repos/acme/app/rules/branches/main?per_page=100 
#   GET /repos/acme/app/rules/branches/main?per_page=100 
#   POST /graphql query PullRequestByNumber($owner: String!, $repo: String!, $
#   POST /graphql mergePullRequest expectedHeadOid=d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1 SQUASH
#   POST /graphql query($owner:String!,$repo:String!,$number:Int!){repository(
```

## 09b-away-skip-ci-declared-refuses  (exit 1)
```
$ FM_HOME=/var/folders/t0/8lf233xd7bxcd3x5x09vqgvm0000gn/T/fm-lab.Uyc120 bin/fm-pr-merge.sh task-s9b https://github.localhost/acme/app/pull/102 
# config/github-required-checks:
#   # checks this home requires on acme/app
#   github.localhost/acme/app github-actions pull_request build
error: refusing to merge https://github.localhost/acme/app/pull/102
  - declared required check 'build' (github-actions, pull_request) has not reported at head d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1
error: these required checks have not reported: build
armed: state/task-s9b.check.sh
# GitHub requests:
#   POST /graphql query PullRequestByNumber($owner: String!, $repo: String!, $
#   POST /graphql query PullRequestByNumber($owner: String!, $repo: String!, $
#   GET /repos/acme/app/branches/main 
#   GET /repos/acme/app/rules/branches/main?per_page=100 
#   GET /repos/acme/app/commits/d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1/check-runs?filter=all&per_page=100 
#   GET /repos/acme/app/actions/runs?head_sha=d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1&per_page=100 
```

## 09c-away-dispatch-declared-waiver-refused  (exit 2)
```
$ FM_HOME=/var/folders/t0/8lf233xd7bxcd3x5x09vqgvm0000gn/T/fm-lab.Uyc120 bin/fm-pr-merge.sh task-s9c https://github.localhost/acme/app/pull/103 --allow-red build
# config/github-required-checks:
#   # checks this home requires on acme/app
#   github.localhost/acme/app github-actions pull_request build
error: --allow-red is attended-only; while the away-posture record exists the green check is absolute
# GitHub requests:
```

## 10a-park-gate-dispatch-undeclared-clean  (exit 0)
```
$ FM_HOME=/var/folders/t0/8lf233xd7bxcd3x5x09vqgvm0000gn/T/fm-lab.Uyc120 FM_PARK_QUIET_SECS=900 bin/fm-park.sh gate task-s4   # task-s4 records pr=https://github.localhost/acme/app/pull/51
# config/github-required-checks:
#   (no config/github-required-checks in the lab home)
clean head=d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2
# GitHub requests:
#   POST /graphql query($owner:String!,$repo:String!,$number:Int!,$endCursor:S
#   GET /repos/acme/app/branches/main 
#   GET /repos/acme/app/rules/branches/main?per_page=100 
```

## 10b-park-gate-dispatch-declared-unclean  (exit 3)
```
$ FM_HOME=/var/folders/t0/8lf233xd7bxcd3x5x09vqgvm0000gn/T/fm-lab.Uyc120 FM_PARK_QUIET_SECS=900 bin/fm-park.sh gate task-s4   # task-s4 records pr=https://github.localhost/acme/app/pull/51
# config/github-required-checks:
#   # checks this home requires on acme/app
#   github.localhost/acme/app github-actions pull_request build
unclean: required check(s) build have not succeeded on head d2d2d2d2d2d2
# GitHub requests:
#   POST /graphql query($owner:String!,$repo:String!,$number:Int!,$endCursor:S
#   GET /repos/acme/app/branches/main 
#   GET /repos/acme/app/rules/branches/main?per_page=100 
#   GET /repos/acme/app/commits/d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2/check-runs?filter=all&per_page=100 
#   GET /repos/acme/app/actions/runs?head_sha=d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2&per_page=100 
```

