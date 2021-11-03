--create drop_tickets_year_semester(roll_number, course_code) and withdraw_course_year_semester!
--add insert privileges to students, select access to all

--write trigger-function binding statements
create or replace function registrations.check_withdraw_request()
returns trigger 
language plpgsql
as 
$$
declare
	course record;
	current_roll_number varchar;
	current_semester integer;
    current_year     integer;
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
			raise notice 'Drop request submitted successfully. '
			return new;
		end if;
	end loop;
	raise notice 'Matching provisional registration not found.'
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
	current_semester integer;
    current_year     integer;
    student_roll_number      varchar;
begin 
	select semester, year from academic_data.semester into current_semester, current_year;
    select current_user into student_roll_number;
    execute ('insert into registrations.withdraw_course_' || current_year || '_' || current_semester ||
             '(roll_number, course_code) values (' || roll_number || ', ' || course_id || ');');
    --trigger will check if such an entry exists in the provisional course reg
end
$$;


