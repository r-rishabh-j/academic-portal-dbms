create or replace procedure admin_data.load_students(stu_filename text)
as
$$
begin
    execute format('copy academic_data.student_info from ''%s'' delimiter '','' csv header;', stu_filename);
--     copy academic_data.student_info from stu_filename delimiter ',' csv header;
end;
$$ language plpgsql;

create or replace procedure admin_data.load_faculty(f_filename text)
as
$$
begin
    execute format('copy academic_data.faculty_info from ''%s'' delimiter '','' csv header;', f_filename);
--     copy academic_data.faculty_info from f_filename delimiter ',' csv header;
end;
$$ language plpgsql;