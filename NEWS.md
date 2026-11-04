Can-BUILD 1.0.0
===============
- Re-scope the study to incidence rates by calendar year, computed with the HADES
  Characterization package (v4 settings API).
- `CreateStrategusAnalysisSpecifications.R` now builds Characterization v4 settings
  objects (`createStudyPopulationSettings`, `createTargetBaselineSettings`,
  `createCohortIncidenceSettings`, `createCharacterizationSettings`) and passes them
  to `CharacterizationModule$createModuleSpecifications(characterizationSettings = ...)`.
  This requires Strategus >= 1.6.0 and Characterization >= 4.0.0.
- Remove CohortMethod and SelfControlledCaseSeries (and the unused CohortIncidence
  module, whose output Characterization now provides) together with their settings
  (`tcis`, `sccsTimeAtRisks`, `plpTimeAtRisks`, sizing parameters) and the negative
  control and covariate-exclusion assets that only served estimation.
- Remove the target-comparator-indication-subgroup machinery and all cohort
  subsetting, including the "above/below the line" split of the script.
- Replace the cohorts with placeholder cohorts downloaded from the OHDSI demo
  ATLAS (targets 1 new users of ACE inhibitors and 2 new users of ARBs, outcome
  3 first observed cough). Every cohort in the study now comes from ATLAS
  through `DownloadAssets.R`; there is no custom cohort SQL.
- Report incidence rates by calendar year (`byYear = TRUE`) since the target
  cohorts are not themselves calendar-year cohorts yet.
- Point `ExecuteAnalyses.R` at the local OHDSI Lab and document the `cdm_vocab`
  view layer the lab needs.

StrategusStudyRepoTemplate 2.0.3
===============
- Fix check for duplicated cohort IDs in `scriptsForStudyDesigner/CreateStrategusAnalysisSpecifications.R`
- Add better logging for upload

StrategusStudyRepoTemplate 2.0.2
===============
- Revise `ExecuteAnalyses.R` to avoid error when uncommenting the `modulesToExecute` parameter (#30)

StrategusStudyRepoTemplate 2.0.1
===============
- Move Characterization package to develop branch to address issue with character length problem.

StrategusStudyRepoTemplate 2.0.0
===============
- Reorganize project template and update to use 2026Q1 HADES-wide lock file (#28)

StrategusStudyRepoTemplate 1.1.1
===============
- Revise sample study to reduce execution time (#18)

StrategusStudyRepoTemplate 1.1.0
===============

- Adds a new sample study (T: ACE inhibitors, C:Diuretics, I: Hypertensive Disorder, O: AMI, Angioedema) to use for testing this template at OHDSI network sites.
- Update `renv.lock` to capture updated HADES/DARWIN packages
- Add new TCIS script for creating analysis specification
- Use the Characterization module default settings for features (#7)

StrategusStudyRepoTemplate 1.0.0
===============

- Established this repository to aid the OHDSI community in using Strategus v1.0 for conducting network studies.
- Created [documentation](UsintThisTemplate.md) to describe how to design and distribute a Strategus network study (#4). This documentation also links to the Save our Sisyphus challenge resources that further detail OHDSI network study process. (#4)
- The `renv.lock` file only contains tagged releases of all packages (#1)
- This study template repo also includes Python dependencies which are restored via the `renv` package (#2)
- `renv.lock` contains the dependencies necessary to launch a OHDSI Shiny App Results Viewer (#3)