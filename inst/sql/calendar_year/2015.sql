-- Cohort: observation year 2015
-- Everyone under observation at some point in calendar year 2015.
--
-- cohort_start_date = later of 2015-01-01 and the start of the observation period
-- cohort_end_date   = earlier of 2015-12-31 and the end of the observation period
--
-- Each row is one period of observation inside the year, so
-- SUM(cohort_end_date - cohort_start_date + 1) is the person time at risk for the year.

DELETE FROM @target_database_schema.@target_cohort_table
WHERE cohort_definition_id = @target_cohort_id;

INSERT INTO @target_database_schema.@target_cohort_table (cohort_definition_id, subject_id, cohort_start_date, cohort_end_date)
SELECT @target_cohort_id AS cohort_definition_id,
       op.person_id AS subject_id,
       CASE
         WHEN op.observation_period_start_date < DATEFROMPARTS(2015, 1, 1) THEN DATEFROMPARTS(2015, 1, 1)
         ELSE op.observation_period_start_date
       END AS cohort_start_date,
       CASE
         WHEN op.observation_period_end_date > DATEFROMPARTS(2015, 12, 31) THEN DATEFROMPARTS(2015, 12, 31)
         ELSE op.observation_period_end_date
       END AS cohort_end_date
FROM @cdm_database_schema.observation_period op
WHERE op.observation_period_start_date <= DATEFROMPARTS(2015, 12, 31)
  AND op.observation_period_end_date   >= DATEFROMPARTS(2015, 1, 1)
;
