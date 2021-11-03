--create drop_tickets_year_semester(roll_number, course_code) and withdraw_course_year_semester!
--add insert privileges to students, select access to all

--write trigger-function binding statements
create or replace function registrations.check_withdraw_request()
returns trigger 
language plpgsql
as 
$$
declare
	course 				record;
	current_roll_number varchar;
	current_semester 	integer;
    current_year     	integer;
begin 
	--if insert roll number is not the same as the current user roll number
	select current_user into current_roll_number;
	if current_roll_number <> new.roll_number then 
		raise notice 'User roll number and insert roll number do not match!';
		return null;
	end if;

	select semester, year from academic_data.semester into current_semester, current_year;
	for course in execute('select * from registrations.provisional_course_registrations_' || current_year || '_' || current_semester ||';')
	loop
		if course.roll_number = new.roll_number and course.course_code = new.course_code then 
			raise notice 'Withdraw request submitted successfully. ';
			return new;
		end if;
	end loop;
	raise notice 'Matching provisional registration not found.';
	return null;
end
$$;


--write trigger-function binding statements
create or replace function registrations.withdraw_course_request(course_id varchar)
returns void
language plpgsql
as
$$
declare
	current_semester 	integer;
    current_year		integer;
    student_roll_number	varchar;
begin 
	select semester, year from academic_data.semester into current_semester, current_year;
    select current_user into student_roll_number;
    execute ('insert into registrations.withdraw_course_' || current_year || '_' || current_semester ||
             '(roll_number, course_code) values (' || roll_number || ', ' || course_id || ');');
    --trigger will check if such an entry exists in the provisional course reg
end
$$;

CREATE OR replace procedure admin_data.cancel_course_registration()
LANGUAGE plpgsql
AS
$$
DECLARE
	current_year		integer;
	current_semester	integer;
	reg					record;
BEGIN
	select semester, year from academic_data.semester into current_semester, current_year;

	--1. delete entry from provisional course regisration(existance ensured by trigger)
	FOR reg IN execute('select * from registrations.provisional_course_registrations_' || current_year || '_' || current_semester ||';')
	loop
		
	END loop;
	
	--2. delete student entry from final course registration, if exists
END
$$;

--write trigger-function binding statements
create or replace function registrations.check_drop_request()
returns trigger 
language plpgsql
as 
$$
declare
	ticket 				 record;
	current_roll_number  varchar;
	current_semester	 integer;
    current_year    	 integer;
   	coord_id 			 varchar;
   	student_batch 		 integer;
	student_dept 		 varchar;
	adv_id 				 varchar;
begin 
	--if insert roll number is not the same as the current user roll number
	select current_user into current_roll_number;
	if current_roll_number <> new.roll_number then 
		raise notice 'User roll number and request roll number do not match!';
		return null;
	end if;
	
	--check if ticket exists in faculty table and faculty adviser ticket table
	
	--1. get faculty id from course_coordinator from course_offerings

	select semester, year from academic_data.semester into current_semester, current_year;
	execute('select course_coordinator from course_offerings.sem_' || current_year || '_' || current_semester || 'where course_code = "' || new.course_code || '" into ' || coord_id || ';');
	
	for ticket in execute('select * from registrations.faculty_ticket_' || coord_id || '_' || current_year || '_' || current_semester || ';')
	loop
		if ticket.roll_number = new.roll_number and ticket.course_code = new.course_code then 
			raise notice 'Drop request submitted successfully. ';
			return new;
		end if;
	end loop;

	--2. get adviser id from ug_batches(using dept name and year from roll number)

	execute('select batch_year, department from academic_data.student_info where academic_data.student_info.roll_number = "' || student_roll_number || '" into' || student_batch || ',' || student_dept || ';');
	execute('select adviser_f_id from academic_data.ug_batches where dept_name = "' || student_dept || '" and batch_year = "' || student_batch || '" into' || adv_id || ';' );

	for ticket in execute('select * from registrations.adviser_ticket_' || adv_id || '_' || current_year || '_' || current_semester || ';')
	loop
		if ticket.roll_number = new.roll_number and ticket.course_code = new.course_code then 
			raise notice 'Drop request submitted successfully. ';
			return new;
		end if;
	end loop;
	raise notice 'Matching tickets not found.';
	return null;
end
$$;


--write trigger-function binding statements
create or replace function registrations.drop_ticket_request(course_id varchar)
returns void
language plpgsql
as
$$
declare
	current_semester integer;
    current_year     integer;
    student_roll_number      varchar;
begin 
	select semester, year from academic_data.semester into current_semester, current_year;
    select current_user into student_roll_number;
    execute ('insert into registrations.drop_tickets_' || current_year || '_' || current_semester ||
             '(roll_number, course_code) values (' || roll_number || ', ' || course_id || ');');
    --trigger will check if such an entry exists in the faculty(find course_coordinator) and adviser(find from ug_batches) ticket tables
end
$$;

