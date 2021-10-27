create or replace procedure load_students(stu_filename text)
as
$$
begin
    copy academic_data.student_info from stu_filename delimiter ',' csv header;    
end;
$$language plpgsql;
create or replace procedure load_faculty(f_filename text)
as
$$
begin
    copy academic_data.faculty_info from f_filename delimiter ',' csv header;    
end;
$$language plpgsql;