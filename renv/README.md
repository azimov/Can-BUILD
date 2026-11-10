# renv

**Snapshot only after the study package manifest is in place.**

`renv.lock` is the HADES-wide lock file. It deliberately pins many more packages
than this study's R scripts `library()`, including the ones needed to run the
results Shiny app and the report generator:

- CohortDiagnostics
- OhdsiShinyAppBuilder
- OhdsiShinyModules
- OhdsiReportGenerator
- ResultModelManager

`renv::snapshot()` records only the packages it can see the code using. Because
the study's dependencies are loaded indirectly (Strategus loads its modules at
run time, the Shiny app is a separate entry point), a snapshot taken without
help drops the lock file to a single package and silently removes everything
above. The resulting lock file still installs, so the damage only shows when
someone opens the app.

**`StudyPackages.R`, in the project root, prevents this.** It lists every package
the study pack needs, as plain `library()` calls with a comment on each. renv
finds dependencies by scanning for `library(pkg)` and `pkg::fun`, so those names
are visible to the snapshot. Verified: `renv::dependencies()` reports 40
dependencies from that file alone, and every one of them matches an entry in
`renv.lock`.

Do not wrap the calls in `if (FALSE)` or a string: renv skips anything it
considers dead code, which makes the whole file invisible again.

## What to use instead

| Task | Command |
|---|---|
| Install the pinned environment | `renv::restore()` |
| Check status | `renv::status()` |
| Add one package on purpose | `renv::install("pkg"); renv::record("pkg@version")` |

`renv::record()` adds or updates a single entry in the lock file without
recomputing it from the code, which is what you want here.

## Why the lock file is explicit

`renv/settings.json` sets `"snapshot.type": "explicit"`, meaning `renv::restore()`
installs exactly what the lock file lists rather than deriving it from the
project's `.R` files. This is what makes it safe to keep the Shiny/report
packages in an environment the study scripts never reference directly.
