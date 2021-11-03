create or replace procedure faculty_actions.upload_grades(grade_file text, course_name text) as
$function$
declare
    semester        integer;
    year            integer;
    temp_table_name varchar;
    reg_table_name  varchar;
begin
    select academic_data.semester.semester, academic_data.semester.year from academic_data.semester into semester, year;
    temp_table_name := 'temporary_grade_store_' || course_name || '_' || year || '_' || semester;
    reg_table_name := 'registrations.' || course_name || '_' || year || '_' || semester;
    execute (format($tbl$create table %I
    (
        roll_number varchar,
        grade integer
    );
    $tbl$, temp_table_name));

    execute (format($dyn$copy %s from '%s' delimiter ',' csv header;$dyn$), temp_table_name, grade_file);
    execute (format($dyn$update %s set %s.grade=%s.grade from %s where %s.roll_number=%s.roll_number;$dyn$,
                    reg_table_name, reg_table_name, temp_table_name, temp_table_name, reg_table_name, temp_table_name));

    execute format('drop table %s;', temp_table_name);
end;
$function$ language plpgsql;

create or replace procedure faculty_actions.update_grade(roll_number text, course text, grade integer)
as
$f$
begin

end;
$f$ language plpgsql;

create or replace procedure admin_data.release_grades()
as
$f$
declare
    sem integer;
    yr integer;
    course_offering record;
    student record;
begin
    select semester, year from academic_data.semester into sem, yr;
    for course_offering in execute(format($d$select course_code from course_offerings.sem_%s_%s;$d$,yr,sem))
    loop
        for student in execute(format($d$select * from registrations.%s_%s_%s;$d$,course_offering.course_code, yr, sem))
        loop
            execute(format($d$update student_grades.student_%s set grade=%s where course_code='%s' and semester=%s and year=%s;$d$, student.roll_number, student.grade, course_offering.course_code, sem, yr));
            raise notice 'Student % given % grade in course %.', student.roll_number, student.grade, course_offering.course_code;
        end loop;
    end loop;
end;
$f$ language plpgsql;

create or replace procedure admin_data.release_grades(sem integer, yr integer)
as
$f$
declare
    course_offering record;
    student record;
begin
    for course_offering in execute(format($d$select course_code from course_offerings.sem_%s_%s;$d$,yr,sem))
    loop
        for student in execute(format($d$select * from registrations.%s_%s_%s;$d$,course_offering.course_code, yr, sem))
        loop
            execute(format($d$update student_grades.student_%s set grade=%s where course_code='%s' and semester=%s and year=%s;$d$, student.roll_number, student.grade, course_offering.course_code, sem, yr));
            raise notice 'Student % given % grade in course %.', student.roll_number, student.grade, course_offering.course_code;
        end loop;
    end loop;
end;
$f$ language plpgsql;