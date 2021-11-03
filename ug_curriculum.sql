drop schema if exists ug_curriculum;

create schema ug_curriculum;

create or replace function ug_curriculum.create_batch_tables()
returns void as
$$
declare
	ug_batches_cursor cursor for select * from academic_data.ug_batches;
	batch_year integer;
	dept_name varchar;
	rec_batch record;
begin 
	open ug_batches_cursor;
	
	loop
		fetch ug_batches_cursor into rec_batch;
		exit when not found;
		execute('create table ug_curriculum.' || rec_batch.dept_name || '_' || rec_batch.batch_year || 
				' (
					course_code				varchar not null,
					course_description		varchar default '',
					credits					real not null,
					type					varchar not null,
					primary key(course_code)
				);'	
			);
	end loop;

	CLOSE ug_batches_cursor;

	--grant select access to all!
end;
$$ language plpgsql;

--write load from csv, admin_data function

create or replace function is_ready_to_graduate(student_roll_number varchar)
returns boolean
language plpgsql
as
$$
declare
	student_cgpa real := calculate_cgpa(student_roll_number);
	student_batch integer;
	student_dept varchar;
	pe_credits_req real;
	oe_credits_req real;
	pe_credits_done real := 0;
	oe_credits_done real := 0;
	course record;
	req record;
	course_cred real;
	course_type varchar;
	program_core varchar[];
	science_core varchar[];
	present boolean;	-- found is also a keyword

begin 
	--1.check minimum of 5 CGPA
	if student_cgpa < 5 then return false; end if;

	--2.check all core(program and science) courses done
	execute('select batch_year, department from academic_data.student_info where academic_data.student_info.roll_number = "' || student_roll_number || '" ;' ) INTO student_batch, student_dept;

	for req in execute('select * from ug_curriculum.' || student_dept || '_' || student_batch || 'where type = ''PC'' or ''SC'';')
	loop
		present := false;
		for course in execute('select * from student_grades.student_'|| student_roll_number || ';')
		loop
			if course.grade != 0 and course.course_code = req.course_code then 
				present = true;
			end if;
		end loop;
		if present = false then return false; end if;
	end loop;
	
	--3.check elective (program and open) credits against acads limit
	--replace table name as "academic_data.degree_info" and field name as "degree_type"
	select program_electives_credits, open_electives_credits from academic_data.degree_info where degree_type = "btech" into pe_credits_req, oe_credits_req;
	
	for course in execute('select * from student_grades.student_'|| student_roll_number || ';')
	loop
		--check syntax!
		execute('select type, credits from ug_curriculum.' || student_dept || '_' || student_batch || ' where course_code = ''' || course.course_code || ''';' )INTO course_type, course_cred;
		if course.grade != 0 and course_type = "PE" then
			pe_credits_done :=  pe_credits_done + course_cred;
		end if;
		if course.grade != 0 and course_type = "OE" then
			oe_credits_done :=  oe_credits_done + course_cred;
		end if;
	end loop;

	if pe_credits_done < pe_credits_req or oe_credits_done < oe_credits_req then 
		return false;
	end if;
	return true;
end;
$$;



