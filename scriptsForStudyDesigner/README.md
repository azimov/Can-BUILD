# Design Your Study

These are the steps to design the study and to build the [Strategus](https://github.com/OHDSI/Strategus)
analysis specification that `ExecuteAnalyses.R` runs. They assume you have a
protocol, that your cohorts have been designed and reviewed, and that you have
approval to execute the study.

## Study design in one page

| | |
|---|---|
| Targets | One cohort per calendar year (2015-2024): everyone under observation in that year |
| Outcomes | Placeholder cohorts 101 and 102 until the real outcome cohorts are defined in ATLAS |
| Primary output | Incidence rate per 100 person-years, in each year, overall and by age and gender |
| Modules | CohortGenerator, CohortDiagnostics (outcome cohorts), Characterization (v4) |

There is no estimation (CohortMethod, SelfControlledCaseSeries) and no
prediction (PatientLevelPrediction) in this study.

## Download study assets

`DownloadAssets.R` downloads cohort definitions from ATLAS into `inst/`
(`Cohorts.csv`, `inst/cohorts/*.json`, `inst/sql/sql_server/*.sql`).

It is only needed for the cohorts that live in ATLAS - that is, the outcome
cohorts. The calendar-year cohorts are not ATLAS cohorts: see
[Calendar-year cohorts](#calendar-year-cohorts) below.

To use it:

1. Set `webApiUrl` in `config.yml` to your ATLAS instance.
2. List the cohorts you want in the `cohortsToDownload` table in
   `DownloadAssets.R` (ATLAS cohort ID, local cohort ID, cohort name).
3. Run the script from the project root.

## Calendar-year cohorts

"Everyone under observation in calendar year Y" cannot be expressed as an
ATLAS/Circe cohort definition, so these cohorts are plain SQL:

```text
inst/sql/calendar_year/2015.sql ... inst/sql/calendar_year/2024.sql
```

Each one takes the overlap of every person's `observation_period` with that
year: cohort start is the first day the person was observed in the year, cohort
end is the last. The person-years in those cohorts are the denominators of the
incidence rates.

These cohorts have no Circe JSON, so they are kept out of `inst/Cohorts.csv`
(which `DownloadAssets.R` rewrites) and are built directly with CohortGenerator
by `BuildCalendarYearCohorts.R` before the Strategus run.

To add or remove a year:

1. Copy an existing `inst/sql/calendar_year/<year>.sql` and change the year.
   The file name is the cohort ID.
2. Update `targetYears` in `CreateStrategusAnalysisSpecifications.R`.

## Create the analysis specification

`CreateStrategusAnalysisSpecifications.R` builds the Strategus analysis
specification and writes it to `inst/analysisSpecifications.json`. Run it from
the project root:

```r
source("scriptsForStudyDesigner/CreateStrategusAnalysisSpecifications.R")
```

It contains three things you edit.

### 1. Targets

```r
targetIds <- 2015:2024
```

The cohort IDs of the calendar-year cohorts.

### 2. Outcomes

```r
outcomes <- tibble::tribble(
  ~cohortId, ~cleanWindow,
  101,       365,
  102,       365
)
```

`cohortId` is the outcome cohort ID. `cleanWindow` is the number of days that
must pass between two events before the second one counts as a new event.

**These two cohorts are placeholders** until the real outcome cohorts are
defined in ATLAS. When they are: add them to the `cohortsToDownload` table in
`DownloadAssets.R` and run it (it regenerates `inst/Cohorts.csv` from ATLAS),
then replace the IDs here. The script stops if an outcome ID is missing from
`inst/Cohorts.csv`.

### 3. Time at risk

```r
riskWindowStart <- 1
startAnchor <- "cohort start"
riskWindowEnd <- 0
endAnchor <- "cohort end"
```

For a calendar-year cohort this means "from the day after the person's first
observed day in the year to their last observed day in the year".

## How the settings fit together (Characterization v4)

Characterization v4 no longer takes a long list of module arguments. You build a
few settings objects instead:

- `createStudyPopulationSettings()` says which target cohorts to use and how to
  restrict them (prior observation, age, gender, study dates). This study uses
  no restrictions.
- `createTargetBaselineSettings()` produces the baseline characteristics of each
  target cohort.
- `createCohortIncidenceSettings()` produces the incidence rates, with
  `byAge`, `byGender` and `ageBreaks` controlling the strata.
- `createCharacterizationSettings()` collects the analyses.

The Strategus `CharacterizationModule` then takes that object:

```r
CharacterizationModule$new()$createModuleSpecifications(
  characterizationSettings = characterizationSettings,
  ...
)
```

This requires Strategus >= 1.6.0 (the Characterization module moved into
Strategus in 1.6.0) and Characterization >= 4.0.0.

## Choose Strategus modules

The specification in this repository contains:

- **CohortGeneratorModule** - builds the outcome cohorts (the calendar-year
  cohorts are built before the run, see above).
- **CohortDiagnosticsModule** - cohort diagnostics for the outcome cohorts.
  The calendar-year cohorts are SQL-only, so there is no concept-level content
  to diagnose.
- **CharacterizationModule** - baseline characteristics and incidence rates.

Remove a module from `moduleSpecsList` at the bottom of
`CreateStrategusAnalysisSpecifications.R` if the study does not need it, and
remove its settings block above.

## Test the study

Before distributing the study repository, run it end to end against a test
database. On this machine the local OHDSI Lab is already configured in
`ExecuteAnalyses.R`; see the repository README for the `cdm_vocab` view layer
the lab needs.

Check that:

- `renv::restore()` completes.
- The analysis specification is regenerated after the last design change.
- `ExecuteAnalyses.R` runs all three modules without errors.
- `results/<databaseName>/` contains the Characterization CSVs, in particular
  `c_incidence_summary.csv`, and that the rates look plausible.
- `ShareResults.R` can zip the results.
