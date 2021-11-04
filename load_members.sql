create or replace procedure admin_data.load_students(stu_filename text)
as
$$
begin
    execute format('copy academic_data.student_info from ''%s'' delimiter '','' csv header;', stu_filename);
end;
$$ language plpgsql;

create or replace procedure admin_data.load_faculty(f_filename text)
as
$$
begin
    execute format('copy academic_data.faculty_info from ''%s'' delimiter '','' csv header;', f_filename);
end;
$$ language plpgsql;

create or replace procedure admin_data.load_advisers(a_filename text)
as
$$
begin
    execute format('copy academic_data.adviser_info from ''%s'' delimiter '','' csv header;', a_filename);
end;
$$ language plpgsql;

call admin_data.load_students('C:\MyData\IIT-Study\3rd Year\Assignments\CS301\Project\academic-portal-dbms\students.csv');
call admin_data.load_faculty('C:\MyData\IIT-Study\3rd Year\Assignments\CS301\Project\academic-portal-dbms\faculty_info.csv');
call admin_data.load_advisers('C:\MyData\IIT-Study\3rd Year\Assignments\CS301\Project\academic-portal-dbms\adviser.csv');

create or replace procedure admin_data.upload_batches(filep text)
as 
$f$
begin 
	execute format('copy academic_data.ug_batches from ''%s'' delimiter '','' csv header;', filep);
end;
$f$language plpgsql;

call admin_data.upload_batches('C:\Users\risha\Desktop\Assignments\CS301\Project\academic-portal-dbms\ug_batches.csv');
call admin_data.upload_catalog('C:\Users\risha\Desktop\Assignments\CS301\Project\academic-portal-dbms\COURSE_CATALOG - Sheet1.csv');
CALL ug_curriculum.create_batch_tables();
CALL ug_curriculum.upload_curriculum('C:\Users\risha\Desktop\Assignments\CS301\Project\academic-portal-dbms\UG_curriculum_2019 - CSE.csv','cse',2019);
CALL ug_curriculum.upload_curriculum('C:\Users\risha\Desktop\Assignments\CS301\Project\academic-portal-dbms\UG_curriculum_2018 - CSE.csv','cse',2018);




