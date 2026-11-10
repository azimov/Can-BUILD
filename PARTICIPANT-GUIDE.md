# Running the Study on Your Data

This guide is for study-a-thon participants. It takes you from a fresh clone to
aggregate results on your own OMOP CDM, in five steps.

You do **not** edit any tracked file. Everything specific to your site lives in
one untracked file, `config.local.yml`.

---

## Before you start

You need:

- **R 4.6.2** — `renv` pins it.
- **Java 17 or newer** — DatabaseConnector 8 fails on Java 8 with
  `NoSuchMethodError: java.nio.ByteBuffer.clear()`.
- **Git** and a terminal (or RStudio).
- Read access to your **OMOP CDM**, and a schema you can **write** to.
- The **JDBC driver** for your database platform.

The study creates cohort tables in your work schema. It never modifies your CDM.

---

## Step 1 — Clone and restore the R environment

```bash
git clone https://github.com/azimov/Can-BUILD.git
cd Can-BUILD
```

Then, in R, from the project root:

```r
renv::restore()
```

This installs the ~285 package versions pinned in `renv.lock`. It takes a while
the first time. **Restart R afterwards.**

> **Read [renv/README.md](renv/README.md) before running `renv::snapshot()`.**
> `renv.lock` pins more than the study scripts `library()` on purpose -
> CohortDiagnostics, OhdsiShinyAppBuilder, OhdsiShinyModules and
> OhdsiReportGenerator are needed for the results app and the report generator,
> which load at run time rather than being `library()`-ed. `StudyPackages.R`
> lists all of them so a snapshot keeps them. You never need to snapshot: just
> use `renv::restore()`.

> If `renv::restore()` asks to install renv itself or seems to hang before R
> starts, install renv into your system library once:
> `install.packages("renv")`, then start R in the project directory again.

---

## Step 2 — Create your database settings

Run the setup script, from the project root:

```r
source("SetupDatabaseSettings.R")
```

It is interactive on purpose: it asks you each value, shows you what it has
found, and prints the whole file it writes so you can read it. Press Enter to
accept the suggested value.

Before asking you anything, the script checks that Java works, because the
database packages talk to your database through Java (17 or newer). If Java is
missing or too old it stops straight away and prints how to fix it, rather than
letting you fill in every answer and fail at the connection test:

```
  Java 1.8.0_472 is too old.
  The database packages need Java 17 or newer.

  To fix this, install a JDK (17 or newer) and point JAVA_HOME at it:

    export JAVA_HOME=/path/to/jdk-17
```

Then start a new R session and run the script again. Nothing is written when
this check fails.

If you run it from a script rather than typing it into a console, it does
nothing and says so - it will not invent settings on your behalf.

| What it asks | Notes |
|---|---|
| Database type | `postgresql`, `sql server`, `oracle`, `snowflake`, … |
| JDBC driver folder | Point at an existing folder, or leave blank and let it download the driver for you |
| Server | `host/database` for PostgreSQL, e.g. `db.example.org/cdm` |
| User / password | The password is **not** written to the file (see below) |
| CDM schema | The schema holding your clinical tables **and** vocabulary |
| Work schema | A schema you can write to; study cohort tables go here |
| Cohort table name | Default `can_build_cohort` |
| Database name | Short label, used as the results folder name |

> **If your vocabulary is in a separate schema**, point `cdmDatabaseSchema` at a
> schema or view layer that exposes both, or ask your DBA for one. The study
> needs `concept`, `concept_ancestor` and `concept_relationship` alongside the
> clinical tables.

### What gets written

`config.local.yml` — which is **gitignored**, so it never leaves your machine:

```yaml
local:
  cdmDatabaseSchema: "my_cdm"
  workDatabaseSchema: "my_scratch"
  cohortTableName: "can_build_cohort"
  databaseName: "MY_SITE"
  minCellCount: 5
  javaHome: "/path/to/java"
  pathToDriver: "/path/to/jdbc"

  connectionDetails: !expr |
    DatabaseConnector::createConnectionDetails(
      dbms = "postgresql",
      server = "db.example.org/cdm",
      user = "my_user",
      password = Sys.getenv("OHDSI_DB_PASSWORD"),
      pathToDriver = "/path/to/jdbc"
    )
```

### Why the password isn't in the file

It is read from the `OHDSI_DB_PASSWORD` environment variable at run time. Set it
in your R session before running the study:

```r
Sys.setenv(OHDSI_DB_PASSWORD = keyring::key_get("ohdsi"))
```

or, in the shell:

```bash
export OHDSI_DB_PASSWORD='...'
```

If you would rather write the password into `config.local.yml` (it is not
committed), replace the `Sys.getenv(...)` call with the literal value. For
passwordless or integrated authentication, delete the password line.

### Doing it by hand

You can skip the script entirely:

```bash
cp config.local.example.yml config.local.yml
$EDITOR config.local.yml
```

Then check it loads:

```r
source("scriptsForStudyDesigner/getStudyConfig.R")
config <- getStudyConfig()
config$cdmDatabaseSchema
```

---

## Step 3 — Check the connection and that your CDM has the data

```r
source("scriptsForStudyDesigner/getStudyConfig.R")
config <- getStudyConfig()

conn <- DatabaseConnector::connect(config$connectionDetails)
print(DatabaseConnector::querySql(
  conn,
  sprintf("SELECT COUNT(*) AS n FROM %s.person;", config$cdmDatabaseSchema)
))
DatabaseConnector::disconnect(conn)
```

If that returns a count, you are ready. If it errors, the message tells you
which piece is wrong (driver, host, credentials, schema name).

---

## Step 4 — Create the analysis specification

Only needed once, or after a design change — the specification is already in the
repository:

```r
source("scriptsForStudyDesigner/CreateStrategusAnalysisSpecifications.R")
```

It reads the cohorts from `inst/` and writes `inst/analysisSpecifications.json`.
No database connection is needed for this step.

---

## Step 5 — Run the study

```r
source("ExecuteAnalyses.R")
```

This runs three Strategus modules in order:

| Module | What it does | Rough time on 10k patients |
|---|---|---|
| CohortGenerator | Builds the cohorts into your work schema | under a minute |
| CohortDiagnostics | Cohort diagnostics | ~3 minutes |
| Characterization | Baseline characteristics, incidence rates, point prevalence | ~30 minutes |

Progress is printed as each module runs, and you get a summary at the end:

```
✔ CohortGeneratorModule
✔ CohortDiagnosticsModule
✔ CharacterizationModule
```

Results land in `results/<databaseName>/`:

```
results/MY_SITE/
├── CohortGeneratorModule/   cohort counts, inclusion rules
├── CohortDiagnosticsModule/ cohort diagnostics tables
└── CharacterizationModule/
    ├── c_incidence_summary.csv   ← the primary output
    ├── c_target_covariates.csv   baseline characteristics
    ├── c_target_counts.csv
    └── ...
```

### If it fails part-way

Each module is incremental, so re-running `ExecuteAnalyses.R` resumes where it
stopped rather than starting again. To run only one module, uncomment
`modulesToExecute` in `ExecuteAnalyses.R`:

```r
executionSettings <- Strategus::createCdmExecutionSettings(
  ...,
  modulesToExecute = c("CharacterizationModule")
)
```

To start completely afresh, delete the folders under
`strategusInternals/<databaseName>/` and `results/<databaseName>/`, and drop the
cohort tables from your work schema.

---

## Reading the results

`c_incidence_summary.csv` is long-format. Two things to know:

- **`ref_id` distinguishes the two designs**: `1` is the incidence-rate design,
  `2` the point-prevalence design. A `tar_id` of 1 is reused by both, so filter
  on `ref_id`, not `tar_id`.
- **`characterization_target_id` is an internal ID**, not your cohort ID. Join
  through `c_target_settings.csv` to get it back.

```r
library(dplyr); library(readr)
path <- "results/MY_SITE/CharacterizationModule"

incidence <- read_csv(file.path(path, "c_incidence_summary.csv"))
targets   <- read_csv(file.path(path, "c_target_settings.csv"))
outcomes  <- read_csv(file.path(path, "c_outcome_def.csv"))

incidence |>
  filter(ref_id == 1, is.na(age_group_id), is.na(gender_name)) |>  # overall, not a stratum
  left_join(select(targets, characterization_target_id, target_id),
            by = "characterization_target_id") |>
  left_join(select(outcomes, outcome_id, outcome_cohort_definition_id),
            by = "outcome_id") |>
  select(target = target_id, outcome = outcome_cohort_definition_id,
         start_year, persons_at_risk, person_days, outcomes,
         rate_per_100py = incidence_rate_p_100py)
```

Cells smaller than `minCellCount` are masked with `-5`, so your site's small
counts are not disclosed.

---

## Sharing your results

```r
source("ShareResults.R")
```

This zips the aggregate CSVs in `results/<databaseName>/`. Only aggregate results
are included — no patient-level data. Send the ZIP to the study coordinator as
directed.

---

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `NoSuchMethodError: java.nio.ByteBuffer.clear()` | Java 8. The setup script checks for this first; install Java 17+ and set `JAVA_HOME`. |
| `The pathToDriver argument hasn't been specified` | Set `pathToDriver`, or run `DatabaseConnector::downloadJdbcDrivers("<dbms>")`. |
| `You must provide a default configuration` | `config.yml` is missing — you are not in the project root, or the clone is incomplete. |
| `could not find function "getStudyConfig"` | Source `scriptsForStudyDesigner/getStudyConfig.R` first, or run the scripts from the project root. |
| `These target cohort IDs are not in inst/Cohorts.csv` | `inst/` is incomplete; re-clone or restore the cohort assets. |
| R seems to hang at startup | renv is installing itself. Let it finish once; after that under a minute is normal. |
| `roles` / permission errors creating tables | Your work schema is not writable, or the user lacks `CREATE`. |
| Very slow characterization | Expected on large datasets. It is parallelised; raise `maxCores` in `createCdmExecutionSettings()` if you have cores free. |

Raise an issue with the log from `results/<databaseName>/strategus-log.txt`
attached. Do not post credentials or patient-level data.
