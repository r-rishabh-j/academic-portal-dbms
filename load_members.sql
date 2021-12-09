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

call admin_data.load_students('path');
call admin_data.load_faculty('path');
call admin_data.load_advisers('path');

create or replace procedure admin_data.upload_batches(filep text)
as 
$f$
begin 
	execute format('copy academic_data.ug_batches from ''%s'' delimiter '','' csv header;', filep);
end;
$f$language plpgsql;

call admin_data.upload_batches('path');
call admin_data.upload_catalog('path');
CALL ug_curriculum.create_batch_tables();
CALL ug_curriculum.upload_curriculum('path','cse',2019);
CALL ug_curriculum.upload_curriculum('path','cse',2018);




