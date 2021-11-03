create or replace procedure faculty_actions.offer_course(course_name text, instructor_list text[],
                                                         allowed_batches text[], cgpa_lim real)
as
$proc$
declare
    course_row record := null;
    sem        integer;
    yr         integer;
    curr_user  varchar;
begin
    select semester, year from academic_data.semester into sem, yr;
    select current_user into curr_user;
    select * from academic_data.course_catalog where course_code = course_name into course_row;
    if course_row is null then
        raise notice 'Course % does not exist in catalog.',course_name;
        return;
    end if;
    execute (format($d$insert into course_offerings.sem_%s_%s values('%s','%s','%s',null,'%s',%s)$d$, yr,sem, course_name,
                    curr_user, instructor_list, allowed_batches, cgpa_lim));
    raise notice 'Course % offered by faculty %.', course_name, curr_user;
end;
$proc$ language plpgsql;