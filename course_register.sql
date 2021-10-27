-- check prerequisites requirements
create or replace function check_prerequisites(roll_number varchar, course_code varchar)
returns boolean as
$$
declare
    found boolean;
    requirement varchar;
    pre_requisites varchar[];
begin

    select pre_requisities
    from academic_data.course_catalog
    where academic_data.course_catalog.course_code = course_code
    into pre_requisites;

    if pre_requisites = '{}'
        then return true; -- no requirement
    end if;

    foreach requirement in array pre_requisites
    loop
        found := false;
        for course in execute ('select * from student_grades.student_' || roll_number || ';')
        loop
            if course.grade != 0 and course.course_code = requirement
                then found = true;  -- requirement completed
            end if;
        end loop;
        if found = false
            then return false;
        end if;
    end loop;
end;
$$ language plpgsql;

-- check allowed batches
create or replace function check_allowed_batches(roll_number varchar, course_code varchar)
returns boolean as
$$
declare
    current_semester integer;
    current_year integer;
    student_batch integer;
    allowed_batches varchar[];
    batch varchar;
begin
    select semester, year
    from academic_data.semester
    into current_semester, current_year;

    select batch_year
    from academic_data.student_info
    where academic_data.student_info.roll_number = roll_number
    into student_batch;

    execute(format('select allowed_batches from course_offerings.sem_%s_%s where course_code=''%s'';',
        current_year, current_semester, course_code)) into allowed_batches;

    foreach batch in array allowed_batches
    loop
        if batch = student_batch
            then return true;
        end if;
    end loop;

    return false;
end;
$$ language plpgsql;

-- check if time table slot is free
create or replace function check_time_table_slot(roll_number varchar, course_code varchar)
returns boolean as
$$
declare
    current_semester integer;
    current_year integer;
    slot_required varchar;
    slot_used varchar;
    registered record;
begin
    select semester, year
    from academic_data.semester
    into current_semester, current_year;

    execute(format('select slot from course_offerings.sem_%s_%s where course_code=''%s'';',
        current_year, current_semester, course_code)) into slot_required;

    for registered in execute(format('select * from registrations.provisional_course_registrations_%s_%s where roll_number=''%s'';',
        current_year, current_semester, roll_number))
    loop
        execute(format('select slot from course_offerings.sem_%s_%s where course_code=''%s'';',
            current_year, current_semester, registered.course_code)) into slot_used;
        if slot_used = slot_required
            then return false;
        end if;
    end loop;

    return true;
end;
$$ language plpgsql;

-- check cgpa requirement constraint
create or replace function check_constraint(roll_number varchar, course_code varchar) returns boolean as
$fn$
declare
    current_semester integer;
    current_year integer;
    required      real;
    total_credits real;
    scored        real;
    cgpa          real;
    course_cred   real;
    course        record;
begin
    select semester, year
    from academic_data.semester
    into current_semester, current_year;
    execute(format('select cgpa_req from course_offerings.sem_%s_%s where course_code=''%s'';',
        current_year, current_semester, course_code)) into required;

    total_credits := 0;
    scored := 0;
    for course in execute ('select * from student_grades.student_' || roll_number || ';')
    loop
        if course.grade != 0 then
            select credits from academic_data.course_catalog where course_code = course.course_code into course_cred;
            scored := scored + course_cred * course.grade;
            total_credits := total_credits + course_cred;
        end if;
    end loop;
    cgpa := (scored) / total_credits;

    if cgpa >= required
        then return true;
    else
        return false;
    end if;

end;
$fn$ language plpgsql;

create or replace function check_credit_limit(roll_number varchar, course_code varchar)
returns boolean as
$$
declare
    current_semester integer;
    current_year integer;
    allowed real := get_credit_limit(roll_number);
    taken real := 0;
    credit real;
begin
    select semester, year
    from academic_data.semester
    into current_semester, current_year;

    execute(format('select credits from academic_data.course_catalog where course_code=''%s'';',
            course_code)) into credit;
    taken := taken + credit;

    for registered in execute(format('select * from registrations.provisional_course_registrations_%s_%s where roll_number=''%s'';',
        current_year, current_semester, roll_number))
    loop
        execute(format('select credits from academic_data.course_catalog where course_code=''%s'';',
            registered.course_code)) into credit;
        taken := taken + credit;
    end loop;

    if allowed >= taken
        then return true;
    else
        return false;
    end if;
end;
$$ language plpgsql;

create or replace function check_register_for_course()
    returns trigger
    language plpgsql
as
$trigfunc$
declare
    flag boolean := true;
begin
    -- ensure prerequisites
    flag := flag and check_prerequisites(new.roll_number, new.course_code);
    -- ensure allowed batch
    flag := flag and check_allowed_batches(new.roll_number, new.course_code);
    -- ensure free time table slot
    flag := flag and check_time_table_slot(new.roll_number, new.course_code);
    -- ensure constraint
    flag := flag and check_constraint(new.roll_number, new.course_code);
    -- ensure within credit limit
    flag := flag and check_credit_limit(new.roll_number, new.course_code);

    if flag = true
        then return new;
    else
        -- todo: tell reason for failure
        return null;
    end if;
end;
$trigfunc$;

create or replace function register_for_course(course_id varchar)
    returns void
    language plpgsql
as
$func$
declare
    current_semester integer;
    current_year     integer;
    roll_number      varchar;
begin
    select semester, year from academic_data.semester into current_semester, current_year;
    select current_user into roll_number;
    execute ('insert into registrations.provisional_course_registrations_' || current_year || '_' || current_semester ||
             '(roll_number, course_code) values (' || roll_number || ', ' || course_id || ');');
    -- will trigger the check above
end
$func$
