CREATE TABLE #Codesets (
  codeset_id int NOT NULL,
  concept_id bigint NOT NULL
)
;



UPDATE STATISTICS #Codesets;


SELECT event_id, person_id, start_date, end_date, op_start_date, op_end_date, visit_occurrence_id
INTO #qualified_events
FROM 
(
  select pe.event_id, pe.person_id, pe.start_date, pe.end_date, pe.op_start_date, pe.op_end_date, row_number() over (partition by pe.person_id order by pe.start_date ASC) as ordinal, cast(pe.visit_occurrence_id as bigint) as visit_occurrence_id
  FROM (-- Begin Primary Events
select P.ordinal as event_id, P.person_id, P.start_date, P.end_date, op_start_date, op_end_date, cast(P.visit_occurrence_id as bigint) as visit_occurrence_id
FROM
(
  select E.person_id, E.start_date, E.end_date,
         row_number() OVER (PARTITION BY E.person_id ORDER BY E.sort_date ASC, E.event_id) ordinal,
         OP.observation_period_start_date as op_start_date, OP.observation_period_end_date as op_end_date, cast(E.visit_occurrence_id as bigint) as visit_occurrence_id
  FROM 
  (
  -- Begin Observation Period Criteria
select C.person_id, C.observation_period_id as event_id, DATEFROMPARTS(2016, 4, 1) as start_date, DATEFROMPARTS(2016, 4, 1) as end_date,
       CAST(NULL as bigint) as visit_occurrence_id, C.start_date as sort_date

from 
(
  select op.person_id,op.observation_period_id,op.period_type_concept_id,op.observation_period_start_date as start_date, op.observation_period_end_date as end_date , row_number() over (PARTITION BY op.person_id ORDER BY op.observation_period_start_date) as ordinal
  FROM @cdm_database_schema.OBSERVATION_PERIOD op
) C

WHERE C.start_date <= DATEFROMPARTS(2016, 4, 1) and C.end_date >= DATEFROMPARTS(2016, 4, 1)
AND C.start_date <= DATEFROMPARTS(2016, 4, 1) and C.end_date >= DATEFROMPARTS(2016, 4, 1)
-- End Observation Period Criteria

UNION ALL
-- Begin Observation Period Criteria
select C.person_id, C.observation_period_id as event_id, DATEFROMPARTS(2017, 4, 1) as start_date, DATEFROMPARTS(2017, 4, 1) as end_date,
       CAST(NULL as bigint) as visit_occurrence_id, C.start_date as sort_date

from 
(
  select op.person_id,op.observation_period_id,op.period_type_concept_id,op.observation_period_start_date as start_date, op.observation_period_end_date as end_date , row_number() over (PARTITION BY op.person_id ORDER BY op.observation_period_start_date) as ordinal
  FROM @cdm_database_schema.OBSERVATION_PERIOD op
) C

WHERE C.start_date <= DATEFROMPARTS(2017, 4, 1) and C.end_date >= DATEFROMPARTS(2017, 4, 1)
AND C.start_date <= DATEFROMPARTS(2017, 4, 1) and C.end_date >= DATEFROMPARTS(2017, 4, 1)
-- End Observation Period Criteria

UNION ALL
-- Begin Observation Period Criteria
select C.person_id, C.observation_period_id as event_id, DATEFROMPARTS(2018, 4, 1) as start_date, DATEFROMPARTS(2018, 4, 1) as end_date,
       CAST(NULL as bigint) as visit_occurrence_id, C.start_date as sort_date

from 
(
  select op.person_id,op.observation_period_id,op.period_type_concept_id,op.observation_period_start_date as start_date, op.observation_period_end_date as end_date , row_number() over (PARTITION BY op.person_id ORDER BY op.observation_period_start_date) as ordinal
  FROM @cdm_database_schema.OBSERVATION_PERIOD op
) C

WHERE C.start_date <= DATEFROMPARTS(2018, 4, 1) and C.end_date >= DATEFROMPARTS(2018, 4, 1)
AND C.start_date <= DATEFROMPARTS(2018, 4, 1) and C.end_date >= DATEFROMPARTS(2018, 4, 1)
-- End Observation Period Criteria

UNION ALL
-- Begin Observation Period Criteria
select C.person_id, C.observation_period_id as event_id, DATEFROMPARTS(2019, 4, 1) as start_date, DATEFROMPARTS(2019, 4, 1) as end_date,
       CAST(NULL as bigint) as visit_occurrence_id, C.start_date as sort_date

from 
(
  select op.person_id,op.observation_period_id,op.period_type_concept_id,op.observation_period_start_date as start_date, op.observation_period_end_date as end_date , row_number() over (PARTITION BY op.person_id ORDER BY op.observation_period_start_date) as ordinal
  FROM @cdm_database_schema.OBSERVATION_PERIOD op
) C

WHERE C.start_date <= DATEFROMPARTS(2019, 4, 1) and C.end_date >= DATEFROMPARTS(2019, 4, 1)
AND C.start_date <= DATEFROMPARTS(2019, 4, 1) and C.end_date >= DATEFROMPARTS(2019, 4, 1)
-- End Observation Period Criteria

UNION ALL
-- Begin Observation Period Criteria
select C.person_id, C.observation_period_id as event_id, DATEFROMPARTS(2020, 4, 1) as start_date, DATEFROMPARTS(2020, 4, 1) as end_date,
       CAST(NULL as bigint) as visit_occurrence_id, C.start_date as sort_date

from 
(
  select op.person_id,op.observation_period_id,op.period_type_concept_id,op.observation_period_start_date as start_date, op.observation_period_end_date as end_date , row_number() over (PARTITION BY op.person_id ORDER BY op.observation_period_start_date) as ordinal
  FROM @cdm_database_schema.OBSERVATION_PERIOD op
) C

WHERE C.start_date <= DATEFROMPARTS(2020, 4, 1) and C.end_date >= DATEFROMPARTS(2020, 4, 1)
AND C.start_date <= DATEFROMPARTS(2020, 4, 1) and C.end_date >= DATEFROMPARTS(2020, 4, 1)
-- End Observation Period Criteria

UNION ALL
-- Begin Observation Period Criteria
select C.person_id, C.observation_period_id as event_id, DATEFROMPARTS(2021, 4, 1) as start_date, DATEFROMPARTS(2021, 4, 1) as end_date,
       CAST(NULL as bigint) as visit_occurrence_id, C.start_date as sort_date

from 
(
  select op.person_id,op.observation_period_id,op.period_type_concept_id,op.observation_period_start_date as start_date, op.observation_period_end_date as end_date , row_number() over (PARTITION BY op.person_id ORDER BY op.observation_period_start_date) as ordinal
  FROM @cdm_database_schema.OBSERVATION_PERIOD op
) C

WHERE C.start_date <= DATEFROMPARTS(2021, 4, 1) and C.end_date >= DATEFROMPARTS(2021, 4, 1)
AND C.start_date <= DATEFROMPARTS(2021, 4, 1) and C.end_date >= DATEFROMPARTS(2021, 4, 1)
-- End Observation Period Criteria

UNION ALL
-- Begin Observation Period Criteria
select C.person_id, C.observation_period_id as event_id, DATEFROMPARTS(2022, 4, 1) as start_date, DATEFROMPARTS(2022, 4, 1) as end_date,
       CAST(NULL as bigint) as visit_occurrence_id, C.start_date as sort_date

from 
(
  select op.person_id,op.observation_period_id,op.period_type_concept_id,op.observation_period_start_date as start_date, op.observation_period_end_date as end_date , row_number() over (PARTITION BY op.person_id ORDER BY op.observation_period_start_date) as ordinal
  FROM @cdm_database_schema.OBSERVATION_PERIOD op
) C

WHERE C.start_date <= DATEFROMPARTS(2022, 4, 1) and C.end_date >= DATEFROMPARTS(2022, 4, 1)
AND C.start_date <= DATEFROMPARTS(2022, 4, 1) and C.end_date >= DATEFROMPARTS(2022, 4, 1)
-- End Observation Period Criteria

UNION ALL
-- Begin Observation Period Criteria
select C.person_id, C.observation_period_id as event_id, DATEFROMPARTS(2023, 4, 1) as start_date, DATEFROMPARTS(2023, 4, 1) as end_date,
       CAST(NULL as bigint) as visit_occurrence_id, C.start_date as sort_date

from 
(
  select op.person_id,op.observation_period_id,op.period_type_concept_id,op.observation_period_start_date as start_date, op.observation_period_end_date as end_date , row_number() over (PARTITION BY op.person_id ORDER BY op.observation_period_start_date) as ordinal
  FROM @cdm_database_schema.OBSERVATION_PERIOD op
) C

WHERE C.start_date <= DATEFROMPARTS(2023, 4, 1) and C.end_date >= DATEFROMPARTS(2023, 4, 1)
AND C.start_date <= DATEFROMPARTS(2023, 4, 1) and C.end_date >= DATEFROMPARTS(2023, 4, 1)
-- End Observation Period Criteria

UNION ALL
-- Begin Observation Period Criteria
select C.person_id, C.observation_period_id as event_id, DATEFROMPARTS(2024, 4, 1) as start_date, DATEFROMPARTS(2024, 4, 1) as end_date,
       CAST(NULL as bigint) as visit_occurrence_id, C.start_date as sort_date

from 
(
  select op.person_id,op.observation_period_id,op.period_type_concept_id,op.observation_period_start_date as start_date, op.observation_period_end_date as end_date , row_number() over (PARTITION BY op.person_id ORDER BY op.observation_period_start_date) as ordinal
  FROM @cdm_database_schema.OBSERVATION_PERIOD op
) C

WHERE C.start_date <= DATEFROMPARTS(2024, 4, 1) and C.end_date >= DATEFROMPARTS(2024, 4, 1)
AND C.start_date <= DATEFROMPARTS(2024, 4, 1) and C.end_date >= DATEFROMPARTS(2024, 4, 1)
-- End Observation Period Criteria

UNION ALL
-- Begin Observation Period Criteria
select C.person_id, C.observation_period_id as event_id, DATEFROMPARTS(2025, 4, 1) as start_date, DATEFROMPARTS(2025, 4, 1) as end_date,
       CAST(NULL as bigint) as visit_occurrence_id, C.start_date as sort_date

from 
(
  select op.person_id,op.observation_period_id,op.period_type_concept_id,op.observation_period_start_date as start_date, op.observation_period_end_date as end_date , row_number() over (PARTITION BY op.person_id ORDER BY op.observation_period_start_date) as ordinal
  FROM @cdm_database_schema.OBSERVATION_PERIOD op
) C

WHERE C.start_date <= DATEFROMPARTS(2025, 4, 1) and C.end_date >= DATEFROMPARTS(2025, 4, 1)
AND C.start_date <= DATEFROMPARTS(2025, 4, 1) and C.end_date >= DATEFROMPARTS(2025, 4, 1)
-- End Observation Period Criteria

UNION ALL
-- Begin Observation Period Criteria
select C.person_id, C.observation_period_id as event_id, DATEFROMPARTS(2026, 4, 1) as start_date, DATEFROMPARTS(2026, 4, 1) as end_date,
       CAST(NULL as bigint) as visit_occurrence_id, C.start_date as sort_date

from 
(
  select op.person_id,op.observation_period_id,op.period_type_concept_id,op.observation_period_start_date as start_date, op.observation_period_end_date as end_date , row_number() over (PARTITION BY op.person_id ORDER BY op.observation_period_start_date) as ordinal
  FROM @cdm_database_schema.OBSERVATION_PERIOD op
) C

WHERE C.start_date <= DATEFROMPARTS(2026, 4, 1) and C.end_date >= DATEFROMPARTS(2026, 4, 1)
AND C.start_date <= DATEFROMPARTS(2026, 4, 1) and C.end_date >= DATEFROMPARTS(2026, 4, 1)
-- End Observation Period Criteria

  ) E
	JOIN @cdm_database_schema.observation_period OP on E.person_id = OP.person_id and E.start_date >=  OP.observation_period_start_date and E.start_date <= op.observation_period_end_date
  WHERE DATEADD(day,365,OP.OBSERVATION_PERIOD_START_DATE) <= E.START_DATE AND DATEADD(day,0,E.START_DATE) <= OP.OBSERVATION_PERIOD_END_DATE
) P

-- End Primary Events
) pe
  
) QE

;

--- Inclusion Rule Inserts

create table #inclusion_events (inclusion_rule_id bigint,
	person_id bigint,
	event_id bigint
);

select event_id, person_id, start_date, end_date, op_start_date, op_end_date
into #included_events
FROM (
  SELECT event_id, person_id, start_date, end_date, op_start_date, op_end_date, row_number() over (partition by person_id order by start_date ASC) as ordinal
  from
  (
    select Q.event_id, Q.person_id, Q.start_date, Q.end_date, Q.op_start_date, Q.op_end_date, SUM(coalesce(POWER(cast(2 as bigint), I.inclusion_rule_id), 0)) as inclusion_rule_mask
    from #qualified_events Q
    LEFT JOIN #inclusion_events I on I.person_id = Q.person_id and I.event_id = Q.event_id
    GROUP BY Q.event_id, Q.person_id, Q.start_date, Q.end_date, Q.op_start_date, Q.op_end_date
  ) MG -- matching groups

) Results

;



-- generate cohort periods into #final_cohort
select person_id, start_date, end_date
INTO #cohort_rows
from ( -- first_ends
	select F.person_id, F.start_date, F.end_date
	FROM (
	  select I.event_id, I.person_id, I.start_date, CE.end_date, row_number() over (partition by I.person_id, I.event_id order by CE.end_date) as ordinal
	  from #included_events I
	  join ( -- cohort_ends
-- cohort exit dates
-- By default, cohort exit at the event's op end date
select event_id, person_id, op_end_date as end_date from #included_events
UNION ALL
-- Censor Events
select i.event_id, i.person_id, MIN(c.start_date) as end_date
FROM #included_events i
JOIN
(
-- Begin Observation Period Criteria
select C.person_id, C.observation_period_id as event_id, DATEFROMPARTS(2017, 3, 31) as start_date, DATEFROMPARTS(2017, 3, 31) as end_date,
       CAST(NULL as bigint) as visit_occurrence_id, C.start_date as sort_date

from 
(
  select op.person_id,op.observation_period_id,op.period_type_concept_id,op.observation_period_start_date as start_date, op.observation_period_end_date as end_date , row_number() over (PARTITION BY op.person_id ORDER BY op.observation_period_start_date) as ordinal
  FROM @cdm_database_schema.OBSERVATION_PERIOD op
) C

WHERE C.start_date <= DATEFROMPARTS(2017, 3, 31) and C.end_date >= DATEFROMPARTS(2017, 3, 31)
AND C.start_date <= DATEFROMPARTS(2017, 3, 31) and C.end_date >= DATEFROMPARTS(2017, 3, 31)
-- End Observation Period Criteria

) C on C.person_id = I.person_id and C.start_date >= I.start_date and C.START_DATE <= I.op_end_date
GROUP BY i.event_id, i.person_id

UNION ALL
select i.event_id, i.person_id, MIN(c.start_date) as end_date
FROM #included_events i
JOIN
(
-- Begin Observation Period Criteria
select C.person_id, C.observation_period_id as event_id, DATEFROMPARTS(2018, 3, 31) as start_date, DATEFROMPARTS(2018, 3, 31) as end_date,
       CAST(NULL as bigint) as visit_occurrence_id, C.start_date as sort_date

from 
(
  select op.person_id,op.observation_period_id,op.period_type_concept_id,op.observation_period_start_date as start_date, op.observation_period_end_date as end_date , row_number() over (PARTITION BY op.person_id ORDER BY op.observation_period_start_date) as ordinal
  FROM @cdm_database_schema.OBSERVATION_PERIOD op
) C

WHERE C.start_date <= DATEFROMPARTS(2018, 3, 31) and C.end_date >= DATEFROMPARTS(2018, 3, 31)
AND C.start_date <= DATEFROMPARTS(2018, 3, 31) and C.end_date >= DATEFROMPARTS(2018, 3, 31)
-- End Observation Period Criteria

) C on C.person_id = I.person_id and C.start_date >= I.start_date and C.START_DATE <= I.op_end_date
GROUP BY i.event_id, i.person_id

UNION ALL
select i.event_id, i.person_id, MIN(c.start_date) as end_date
FROM #included_events i
JOIN
(
-- Begin Observation Period Criteria
select C.person_id, C.observation_period_id as event_id, DATEFROMPARTS(2019, 3, 31) as start_date, DATEFROMPARTS(2019, 3, 31) as end_date,
       CAST(NULL as bigint) as visit_occurrence_id, C.start_date as sort_date

from 
(
  select op.person_id,op.observation_period_id,op.period_type_concept_id,op.observation_period_start_date as start_date, op.observation_period_end_date as end_date , row_number() over (PARTITION BY op.person_id ORDER BY op.observation_period_start_date) as ordinal
  FROM @cdm_database_schema.OBSERVATION_PERIOD op
) C

WHERE C.start_date <= DATEFROMPARTS(2019, 3, 31) and C.end_date >= DATEFROMPARTS(2019, 3, 31)
AND C.start_date <= DATEFROMPARTS(2019, 3, 31) and C.end_date >= DATEFROMPARTS(2019, 3, 31)
-- End Observation Period Criteria

) C on C.person_id = I.person_id and C.start_date >= I.start_date and C.START_DATE <= I.op_end_date
GROUP BY i.event_id, i.person_id

UNION ALL
select i.event_id, i.person_id, MIN(c.start_date) as end_date
FROM #included_events i
JOIN
(
-- Begin Observation Period Criteria
select C.person_id, C.observation_period_id as event_id, DATEFROMPARTS(2020, 3, 31) as start_date, DATEFROMPARTS(2020, 3, 31) as end_date,
       CAST(NULL as bigint) as visit_occurrence_id, C.start_date as sort_date

from 
(
  select op.person_id,op.observation_period_id,op.period_type_concept_id,op.observation_period_start_date as start_date, op.observation_period_end_date as end_date , row_number() over (PARTITION BY op.person_id ORDER BY op.observation_period_start_date) as ordinal
  FROM @cdm_database_schema.OBSERVATION_PERIOD op
) C

WHERE C.start_date <= DATEFROMPARTS(2020, 3, 31) and C.end_date >= DATEFROMPARTS(2020, 3, 31)
AND C.start_date <= DATEFROMPARTS(2020, 3, 31) and C.end_date >= DATEFROMPARTS(2020, 3, 31)
-- End Observation Period Criteria

) C on C.person_id = I.person_id and C.start_date >= I.start_date and C.START_DATE <= I.op_end_date
GROUP BY i.event_id, i.person_id

UNION ALL
select i.event_id, i.person_id, MIN(c.start_date) as end_date
FROM #included_events i
JOIN
(
-- Begin Observation Period Criteria
select C.person_id, C.observation_period_id as event_id, DATEFROMPARTS(2021, 3, 31) as start_date, DATEFROMPARTS(2021, 3, 31) as end_date,
       CAST(NULL as bigint) as visit_occurrence_id, C.start_date as sort_date

from 
(
  select op.person_id,op.observation_period_id,op.period_type_concept_id,op.observation_period_start_date as start_date, op.observation_period_end_date as end_date , row_number() over (PARTITION BY op.person_id ORDER BY op.observation_period_start_date) as ordinal
  FROM @cdm_database_schema.OBSERVATION_PERIOD op
) C

WHERE C.start_date <= DATEFROMPARTS(2021, 3, 31) and C.end_date >= DATEFROMPARTS(2021, 3, 31)
AND C.start_date <= DATEFROMPARTS(2021, 3, 31) and C.end_date >= DATEFROMPARTS(2021, 3, 31)
-- End Observation Period Criteria

) C on C.person_id = I.person_id and C.start_date >= I.start_date and C.START_DATE <= I.op_end_date
GROUP BY i.event_id, i.person_id

UNION ALL
select i.event_id, i.person_id, MIN(c.start_date) as end_date
FROM #included_events i
JOIN
(
-- Begin Observation Period Criteria
select C.person_id, C.observation_period_id as event_id, DATEFROMPARTS(2022, 3, 31) as start_date, DATEFROMPARTS(2022, 3, 31) as end_date,
       CAST(NULL as bigint) as visit_occurrence_id, C.start_date as sort_date

from 
(
  select op.person_id,op.observation_period_id,op.period_type_concept_id,op.observation_period_start_date as start_date, op.observation_period_end_date as end_date , row_number() over (PARTITION BY op.person_id ORDER BY op.observation_period_start_date) as ordinal
  FROM @cdm_database_schema.OBSERVATION_PERIOD op
) C

WHERE C.start_date <= DATEFROMPARTS(2022, 3, 31) and C.end_date >= DATEFROMPARTS(2022, 3, 31)
AND C.start_date <= DATEFROMPARTS(2022, 3, 31) and C.end_date >= DATEFROMPARTS(2022, 3, 31)
-- End Observation Period Criteria

) C on C.person_id = I.person_id and C.start_date >= I.start_date and C.START_DATE <= I.op_end_date
GROUP BY i.event_id, i.person_id

UNION ALL
select i.event_id, i.person_id, MIN(c.start_date) as end_date
FROM #included_events i
JOIN
(
-- Begin Observation Period Criteria
select C.person_id, C.observation_period_id as event_id, DATEFROMPARTS(2023, 3, 31) as start_date, DATEFROMPARTS(2023, 3, 31) as end_date,
       CAST(NULL as bigint) as visit_occurrence_id, C.start_date as sort_date

from 
(
  select op.person_id,op.observation_period_id,op.period_type_concept_id,op.observation_period_start_date as start_date, op.observation_period_end_date as end_date , row_number() over (PARTITION BY op.person_id ORDER BY op.observation_period_start_date) as ordinal
  FROM @cdm_database_schema.OBSERVATION_PERIOD op
) C

WHERE C.start_date <= DATEFROMPARTS(2023, 3, 31) and C.end_date >= DATEFROMPARTS(2023, 3, 31)
AND C.start_date <= DATEFROMPARTS(2023, 3, 31) and C.end_date >= DATEFROMPARTS(2023, 3, 31)
-- End Observation Period Criteria

) C on C.person_id = I.person_id and C.start_date >= I.start_date and C.START_DATE <= I.op_end_date
GROUP BY i.event_id, i.person_id

UNION ALL
select i.event_id, i.person_id, MIN(c.start_date) as end_date
FROM #included_events i
JOIN
(
-- Begin Observation Period Criteria
select C.person_id, C.observation_period_id as event_id, DATEFROMPARTS(2024, 3, 31) as start_date, DATEFROMPARTS(2024, 3, 31) as end_date,
       CAST(NULL as bigint) as visit_occurrence_id, C.start_date as sort_date

from 
(
  select op.person_id,op.observation_period_id,op.period_type_concept_id,op.observation_period_start_date as start_date, op.observation_period_end_date as end_date , row_number() over (PARTITION BY op.person_id ORDER BY op.observation_period_start_date) as ordinal
  FROM @cdm_database_schema.OBSERVATION_PERIOD op
) C

WHERE C.start_date <= DATEFROMPARTS(2024, 3, 31) and C.end_date >= DATEFROMPARTS(2024, 3, 31)
AND C.start_date <= DATEFROMPARTS(2024, 3, 31) and C.end_date >= DATEFROMPARTS(2024, 3, 31)
-- End Observation Period Criteria

) C on C.person_id = I.person_id and C.start_date >= I.start_date and C.START_DATE <= I.op_end_date
GROUP BY i.event_id, i.person_id

UNION ALL
select i.event_id, i.person_id, MIN(c.start_date) as end_date
FROM #included_events i
JOIN
(
-- Begin Observation Period Criteria
select C.person_id, C.observation_period_id as event_id, DATEFROMPARTS(2025, 3, 31) as start_date, DATEFROMPARTS(2025, 3, 31) as end_date,
       CAST(NULL as bigint) as visit_occurrence_id, C.start_date as sort_date

from 
(
  select op.person_id,op.observation_period_id,op.period_type_concept_id,op.observation_period_start_date as start_date, op.observation_period_end_date as end_date , row_number() over (PARTITION BY op.person_id ORDER BY op.observation_period_start_date) as ordinal
  FROM @cdm_database_schema.OBSERVATION_PERIOD op
) C

WHERE C.start_date <= DATEFROMPARTS(2025, 3, 31) and C.end_date >= DATEFROMPARTS(2025, 3, 31)
AND C.start_date <= DATEFROMPARTS(2025, 3, 31) and C.end_date >= DATEFROMPARTS(2025, 3, 31)
-- End Observation Period Criteria

) C on C.person_id = I.person_id and C.start_date >= I.start_date and C.START_DATE <= I.op_end_date
GROUP BY i.event_id, i.person_id

UNION ALL
select i.event_id, i.person_id, MIN(c.start_date) as end_date
FROM #included_events i
JOIN
(
-- Begin Observation Period Criteria
select C.person_id, C.observation_period_id as event_id, DATEFROMPARTS(2026, 3, 31) as start_date, DATEFROMPARTS(2026, 3, 31) as end_date,
       CAST(NULL as bigint) as visit_occurrence_id, C.start_date as sort_date

from 
(
  select op.person_id,op.observation_period_id,op.period_type_concept_id,op.observation_period_start_date as start_date, op.observation_period_end_date as end_date , row_number() over (PARTITION BY op.person_id ORDER BY op.observation_period_start_date) as ordinal
  FROM @cdm_database_schema.OBSERVATION_PERIOD op
) C

WHERE C.start_date <= DATEFROMPARTS(2026, 3, 31) and C.end_date >= DATEFROMPARTS(2026, 3, 31)
AND C.start_date <= DATEFROMPARTS(2026, 3, 31) and C.end_date >= DATEFROMPARTS(2026, 3, 31)
-- End Observation Period Criteria

) C on C.person_id = I.person_id and C.start_date >= I.start_date and C.START_DATE <= I.op_end_date
GROUP BY i.event_id, i.person_id

UNION ALL
select i.event_id, i.person_id, MIN(c.start_date) as end_date
FROM #included_events i
JOIN
(
-- Begin Observation Period Criteria
select C.person_id, C.observation_period_id as event_id, DATEFROMPARTS(2027, 3, 31) as start_date, DATEFROMPARTS(2027, 3, 31) as end_date,
       CAST(NULL as bigint) as visit_occurrence_id, C.start_date as sort_date

from 
(
  select op.person_id,op.observation_period_id,op.period_type_concept_id,op.observation_period_start_date as start_date, op.observation_period_end_date as end_date , row_number() over (PARTITION BY op.person_id ORDER BY op.observation_period_start_date) as ordinal
  FROM @cdm_database_schema.OBSERVATION_PERIOD op
) C

WHERE C.start_date <= DATEFROMPARTS(2027, 3, 31) and C.end_date >= DATEFROMPARTS(2027, 3, 31)
AND C.start_date <= DATEFROMPARTS(2027, 3, 31) and C.end_date >= DATEFROMPARTS(2027, 3, 31)
-- End Observation Period Criteria

) C on C.person_id = I.person_id and C.start_date >= I.start_date and C.START_DATE <= I.op_end_date
GROUP BY i.event_id, i.person_id


    ) CE on I.event_id = CE.event_id and I.person_id = CE.person_id and CE.end_date >= I.start_date
	) F
	WHERE F.ordinal = 1
) FE;

select person_id, min(start_date) as start_date, end_date
into #final_cohort
from ( --cteEnds
	SELECT
		 c.person_id
		, c.start_date
		, MIN(ed.end_date) AS end_date
	FROM #cohort_rows c
	JOIN ( -- cteEndDates
    SELECT
      person_id
      , DATEADD(day,-1 * 0, event_date)  as end_date
    FROM
    (
      SELECT
        person_id
        , event_date
        , event_type
        , SUM(event_type) OVER (PARTITION BY person_id ORDER BY event_date, event_type ROWS UNBOUNDED PRECEDING) AS interval_status
      FROM
      (
        SELECT
          person_id
          , start_date AS event_date
          , -1 AS event_type
        FROM #cohort_rows

        UNION ALL


        SELECT
          person_id
          , DATEADD(day,0,end_date) as end_date
          , 1 AS event_type
        FROM #cohort_rows
      ) RAWDATA
    ) e
    WHERE interval_status = 0
  ) ed ON c.person_id = ed.person_id AND ed.end_date >= c.start_date
	GROUP BY c.person_id, c.start_date
) e
group by person_id, end_date
;

DELETE FROM @target_database_schema.@target_cohort_table where cohort_definition_id = @target_cohort_id;
INSERT INTO @target_database_schema.@target_cohort_table (cohort_definition_id, subject_id, cohort_start_date, cohort_end_date)
select @target_cohort_id as cohort_definition_id, person_id, start_date, end_date 
FROM #final_cohort CO
;


-- BEGIN: Censored Stats

delete from @results_database_schema.cohort_censor_stats where cohort_definition_id = @target_cohort_id;

-- END: Censored Stats





TRUNCATE TABLE #cohort_rows;
DROP TABLE #cohort_rows;

TRUNCATE TABLE #final_cohort;
DROP TABLE #final_cohort;

TRUNCATE TABLE #inclusion_events;
DROP TABLE #inclusion_events;

TRUNCATE TABLE #qualified_events;
DROP TABLE #qualified_events;

TRUNCATE TABLE #included_events;
DROP TABLE #included_events;

TRUNCATE TABLE #Codesets;
DROP TABLE #Codesets;
