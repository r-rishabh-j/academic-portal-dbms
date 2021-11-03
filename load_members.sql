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