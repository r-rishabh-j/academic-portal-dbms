create or replace function calculate_cgpa(roll_number varchar) returns real as
$fn$
declare
    total_credits real;
    scored        real;
    cgpa          real;
    course_cred   real;
    course        record;
begin
    for course in execute ('select * from student_grades.student_' || roll_number || ';')
    loop
        if course.grade != 0 then
            select credits from academic_data.course_catalog where course_code = course.course_code into course_cred;
            scored := course_cred * course.grade;
            total_credits := total_credits + course_cred;
        end if;
    end loop;
    if total_credits=0 then return 0; end if;
    cgpa := (scored) / total_credits;
    return cgpa;
end;
$fn$ language plpgsql;

create or replace function calculate_cgpa() returns real as
$fn$
declare
    total_credits real;
    scored        real;
    cgpa          real;
    course_cred   real;
    course        record;
    roll_number varchar;
begin
    select current_user into roll_number;
    for course in execute ('select * from student_grades.student_' || roll_number || ';')
    loop
        if course.grade != 0 then
            select credits from academic_data.course_catalog where course_code = course.course_code into course_cred;
            scored := course_cred * course.grade;
            total_credits := total_credits + course_cred;
        end if;
    end loop;
    if total_credits=0 then return 0; end if;
    cgpa := (scored) / total_credits;
    return cgpa;
end;
$fn$ language plpgsql;