/*1. Populate Clinic Linkage 										
Context: Concept of Clinic Linkage means the patient has to see the oncologist for a clinic appointment on the same date before coming in for 
the infusion appointment 										
Question: Find the list of patient(s) who has/have clinic appointment scheduled on the same date as their infusion appointment. 										
Expected Output: 										
patient_mrn 	appointment_datetime for infusion appt	appointment_datetime for clinic appt	*/
	
/*Step 1 Arranging the data in the required way. Since we are ordering by apppointment_datetime and then department we will always have it 
arranged where clinic time is before or same as  infusion -  This is done by using 'lag', 'partition' and 'order by' statement in select clause*/
		  	
	select patient_mrn
	      ,appointment_datetime as [appointment_datetime for infusion appt]
		  ,lag(appointment_datetime,1) over (partition by patient_mrn  order by patient_mrn, appointment_datetime, department) 
	 	   as [appointment_datetime for clinic appt] --  Department 'LeanTaaS Clinic' will come before 'LeanTaaS Infusion Center' alphabetcically
    	  ,department 
	from [Scheduling].[dbo].[It_appt]
	

-- Step 2 -- Building up on above Query	
	
	
	select patient_mrn
	      ,t.[appointment_datetime for infusion appt]
		  ,t.[appointment_datetime for clinic appt]
	from
		(select patient_mrn
	      ,appointment_datetime as [appointment_datetime for infusion appt]
		  ,lag(appointment_datetime,1) over (partition by patient_mrn  order by patient_mrn, appointment_datetime, department) 
		  as [appointment_datetime for clinic appt] --  Department 'LeanTaaS Clinic' will come before 'LeanTaaS Infusion Center' alphabetically
		  -- since we are ordering by apppointment_datetime and then department we will always have it arranged where clinic time is before infusion
		  ,department 
	from [Scheduling].[dbo].[It_appt])t
	where datediff(year,t.[appointment_datetime for infusion appt], t.[appointment_datetime for clinic appt]) =0   -- year is same
	and datediff(MONTH,t.[appointment_datetime for infusion appt], t.[appointment_datetime for clinic appt]) =0    -- month is same
	and datediff(day,t.[appointment_datetime for infusion appt], t.[appointment_datetime for clinic appt]) = 0     -- day is same
    and datediff(hour,t.[appointment_datetime for infusion appt], t.[appointment_datetime for clinic appt]) <> 0   -- hour is not same
    and datediff(minute,t.[appointment_datetime for infusion appt], t.[appointment_datetime for clinic appt]) <> 0  -- minute is not same
-- below 2 where conditions gives more accuracy
	and t.[appointment_datetime for clinic appt] is not NULL  -- this removes the patient where clinic appointment not there
	and t.[appointment_datetime for infusion appt] is not NULL -- this  removes the patients where infusion appt not there


/*2. Patient Arrival 										
Context: By comparing the CHECKIN time & the time the corresponding appointment is scheduled for, we can understand whether the patient arrived 
earlier or late to the appointment as we refer to Patient Arrival pattern 										
Question: Find the list of patients who checked in between 10 am - 2 pm on 8/26/2018 along with how late/early (in minutes) they have checked in
comparing with their appointment time; order them by degree of earliness/lateness (absolute value). Negative number indicates the
patient checked in earlier & positive number indicates the patient checked in later than the appointment time. 										
Expected Output: 										
patient_mrn 	mins_early_or_late	*/

--Step 1 To find patients checked in between 10 a.m. to 2 p.m.  on 8/26/2018

	select IA.patient_mrn
		  , IA.appointment_datetime
		  ,IAA.activity_datetime
		  ,IAA.[activity ]
	from [Scheduling].[dbo].[It_appt_activity] IAA
	left join [Scheduling].[dbo].[It_appt] IA
	on IA.scheduled_event_ID = IAA.scheduled_event_ID
	where IAA.[activity ] = 'CHECKIN'                         -- filtering by activity status = CHECKIN
	and cast(IAA.activity_datetime as date) = '8/26/2018'     -- on 8/26/2018   
	and datepart(HOUR,[activity_datetime]) >= 10 and DATEPART(HOUR,[activity_datetime]) <= 14      -- between time 10 to 2 


-- Building up on above query

	select t.patient_mrn
		  ,datediff(minute,t.appointment_datetime,t.activity_datetime) as mins_early_or_late
	from
	(
	select  IA.patient_mrn
		   ,IA.appointment_datetime
		   ,IAA.activity_datetime
		   ,IAA.[activity ]   
	from [Scheduling].[dbo].[It_appt_activity] IAA 
	left join [Scheduling].[dbo].[It_appt] IA
	on IA.scheduled_event_ID = IAA.scheduled_event_ID)t
	where t.[activity ] = 'CHECKIN'
	and cast(t.activity_datetime as date) = '8/26/2018'
	and datepart(HOUR,[activity_datetime]) >= 10 and DATEPART(HOUR,[activity_datetime]) <= 14
--	order by mins_early_or_late  -- ordering not by absolute values. But we won't know since there is no negative number(earliness) in current o/p
	order by abs(datediff(minute,t.appointment_datetime,t.activity_datetime) )  -- ordering by absolute value




/*3. Medication Administration Duration 											
  Context: One missing piece from lt_appt is it does not have the medication activity related timestamp tied back to the corresponding scheduled 
  event. You might notice that it is possible to receive multiple medications in a single scheduled event. We'd like to know the total duration
  each patient was receiving the medication vs the time spent with nurse. In order to know the total medication duration, we'll need to know when 
  the first medication started being administered & the end time of the last medication being done administered. 											

Question a: Find out the time when the first medication started being administered & the end time of the last medication being done administered 
by joining mediation related timestamp from lt_medication_activity to its corresponding scheduled event in lt_appt. 											
Expected Output: 											
department	patient_mrn	encounter_ID	scheduled_event_ID	appointment_datetime	visit_type	treatment	scheduling_resources	
expected_duration	start_datetime_for_1st_med	end_datetime_for_last_med  */
	
-- Step 1  Arranging the data in required format

  select IA.department 
       ,IA.patient_mrn
       ,IMA.encounter_ID
	   ,IA.scheduled_event_ID 
	   ,IA.appointment_datetime
	   ,IA.visit_type
	   ,IA.treatment
	   ,IA.scheduling_resources
	   ,IA.expected_duration
       ,IMA.medication_start_datetime
	   ,IMA.medication_end_datetime
	   ,datediff(MINUTE,IMA.medication_start_datetime,IMA.medication_end_datetime) as medication_duration
	   ,ROW_NUMBER() over (partition by IA.scheduled_event_id order by IA.scheduled_event_id, IMA.[medication_activity_id], IMA.medication_start_datetime) as rownumber -- to get first 2 medications
 from [Scheduling].[dbo].[It_medication_activity] IMA              -- to have administered medications left join done
 left join  [Scheduling].[dbo].[It_appt] IA on IMA.encounter_ID =IA.encounter_ID
 inner join [Scheduling].[dbo].[It_appt_activity] IAA on IA.scheduled_event_ID = IAA.scheduled_event_ID
 where IAA.[activity ] in ('CHECKIN')                                -- to have administered medications we wont involve records where it says canceled
 order by IA.patient_mrn, IA.scheduled_event_ID,medication_start_datetime

	-- Building up on above query

	select distinct t.department
		  ,t.patient_mrn
		  ,t.encounter_ID
		  ,t.scheduled_event_ID
		  ,t.appointment_datetime
		  ,t.visit_type
		  ,t.treatment
		  ,t.scheduling_resources
		  ,t.expected_duration
		  ,min(t.medication_start_datetime) over(partition by t.patient_mrn, t.scheduled_event_ID) as start_datetime_for_1st_med
		  ,max(t.medication_end_datetime) over (partition by t.patient_mrn, t.scheduled_event_ID) as end_datetime_for_last_med
	from
	(select IA.department 
       ,IA.patient_mrn
       ,IMA.encounter_ID
	   ,IA.scheduled_event_ID 
	   ,IA.appointment_datetime
	   ,IA.visit_type
	   ,IA.treatment
	   ,IA.scheduling_resources
	   ,IA.expected_duration
       ,IMA.medication_start_datetime
	   ,IMA.medication_end_datetime
	   ,datediff(MINUTE,IMA.medication_start_datetime,IMA.medication_end_datetime) as medication_duration
	   ,ROW_NUMBER() over (partition by IA.scheduled_event_id order by IA.scheduled_event_id, IMA.[medication_activity_id], IMA.medication_start_datetime) as rownumber -- to get first 2 medications
	 from [Scheduling].[dbo].[It_medication_activity] IMA              -- to have administered medications left join done
	 left join  [Scheduling].[dbo].[It_appt] IA on IMA.encounter_ID =IA.encounter_ID
	 inner join [Scheduling].[dbo].[It_appt_activity] IAA on IA.scheduled_event_ID = IAA.scheduled_event_ID
	 where IAA.[activity ] in ('CHECKIN')                                -- to have administered medications we wont involve records where it says canceled
--	 order by IA.patient_mrn, IA.scheduled_event_ID,medication_start_datetime
	)t
	order by patient_mrn, scheduled_event_ID

 -- extra not sure if this is required - to find total time of medication vs the time spent with nurse.
 -- we will build up on above query.
 -- Note for Scheduled event ID 1006 it is showing 0 because the time is in seconds and this document is not providing the time in seconds
 -- Minute is 0 to receive the Syringe.
	select distinct t.patient_mrn
		  ,t.scheduled_event_ID
		  ,sum(t.medication_duration) over(partition by t.patient_mrn, t.scheduled_event_ID) as time_spent_receiving_medications
		  ,DATEDIFF(MINUTE,t.start_datetime_for_1st_med,t.end_datetime_for_last_med) as total_time	
		  ,(DATEDIFF(MINUTE,t.start_datetime_for_1st_med,t.end_datetime_for_last_med) - sum(t.medication_duration) over(partition by t.patient_mrn, t.scheduled_event_ID)) as time_spent_with_nurse
	from
	(select IA.department 
       ,IA.patient_mrn
       ,IMA.encounter_ID
	   ,IA.scheduled_event_ID 
	   ,IA.appointment_datetime
	   ,IA.visit_type
	   ,IA.treatment
	   ,IA.scheduling_resources
	   ,IA.expected_duration
       ,IMA.medication_start_datetime
	   ,IMA.medication_end_datetime
	   ,datediff(MINUTE,IMA.medication_start_datetime,IMA.medication_end_datetime) as medication_duration
	   ,min(medication_start_datetime) over(partition by IA.patient_mrn, IA.scheduled_event_ID) as start_datetime_for_1st_med
	   ,max(medication_end_datetime) over (partition by IA.patient_mrn, IA.scheduled_event_ID) as end_datetime_for_last_med
	   ,ROW_NUMBER() over (partition by IA.scheduled_event_id order by IA.scheduled_event_id, IMA.[medication_activity_id], IMA.medication_start_datetime) as rownumber -- to get first 2 medications
	 from [Scheduling].[dbo].[It_medication_activity] IMA              -- to have administered medications left join done
	 left join  [Scheduling].[dbo].[It_appt] IA on IMA.encounter_ID =IA.encounter_ID
	 inner join [Scheduling].[dbo].[It_appt_activity] IAA on IA.scheduled_event_ID = IAA.scheduled_event_ID
	 where IAA.[activity ] in ('CHECKIN')                                -- to have administered medications we wont involve records where it says canceled
--	 order by IA.patient_mrn, IA.scheduled_event_ID,medication_start_datetime
	)t
	where t.department in ('LeantaaS Infusion Center') -- we are not considering clinic visit time because that is with provider and not Nurse.
	order by t.patient_mrn, t.scheduled_event_ID



	


--Question b: Find out the top 3 scheduled event with the longest duration in terms of medication being administered, only consider the first 2 medications 
--being administered; 
--display the duration for such scheduled event; order from long duration to short. If two scheduled event share the same duration,
--order by scheduled_event_ID in ascending order. If there are gaps between 2 medication being administrated, do not include such gap in the total duration. 											
--Expected Output: 											
--	scheduled_event_ID 	total_duration_for_1st_2_meds

-- Step 1 Arranging the data in required format 

select  IA.patient_mrn
       ,IA.scheduled_event_ID 
       ,IMA.encounter_ID
       ,IMA.medication_start_datetime
	   ,IMA.medication_end_datetime
	   ,datediff(MINUTE,IMA.medication_start_datetime,IMA.medication_end_datetime) as medication_duration
	   , ROW_NUMBER() over (partition by IA.scheduled_event_id order by IA.scheduled_event_id, IMA.[medication_activity_id], IMA.medication_start_datetime) as rownumber -- to get first 2 medications
 from [Scheduling].[dbo].[It_medication_activity] IMA              -- to have administered medications left join done
 left join  [Scheduling].[dbo].[It_appt] IA on IMA.encounter_ID =IA.encounter_ID
 inner join [Scheduling].[dbo].[It_appt_activity] IAA on IA.scheduled_event_ID = IAA.scheduled_event_ID
 where IAA.[activity ] in ('CHECKIN')                                -- to have administered medications we wont involve records where it says canceled
 order by IA.patient_mrn, IA.scheduled_event_ID,medication_start_datetime


 -- Building up on above query

     select top 3 t.scheduled_event_ID 
		   ,sum(medication_duration) as total_duration_for_1st_2_meds -- sum of each medication duration so the gap in duration between them is automatically removed
	 from
	 (select  IA.patient_mrn
		   ,IA.scheduled_event_ID 
		   ,IMA.encounter_ID
		   ,IMA.medication_start_datetime
		   ,IMA.medication_end_datetime
		   ,datediff(MINUTE,IMA.medication_start_datetime,IMA.medication_end_datetime) as medication_duration
		   , ROW_NUMBER() over (partition by IA.scheduled_event_id order by IA.scheduled_event_id, IMA.[medication_activity_id], IMA.medication_start_datetime) as rownumber -- to get first 2 medications
	 from [Scheduling].[dbo].[It_medication_activity] IMA              -- to haveall administered medications left join is done
	 left join  [Scheduling].[dbo].[It_appt] IA on IMA.encounter_ID =IA.encounter_ID
	 inner join [Scheduling].[dbo].[It_appt_activity] IAA on IA.scheduled_event_ID = IAA.scheduled_event_ID
	 where IAA.[activity ] in ('CHECKIN')      -- to have administered medications we will consider records where it says CHECKIN only
	 )t                            -- We don't want records with Canceled or NOSHOW. 2 records have that status and they are filtered out.  
	 where t.rownumber in(1,2)
	 group by t.scheduled_event_ID
	 order by total_duration_for_1st_2_meds desc,t.scheduled_event_ID asc




