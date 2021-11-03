-- check prerequisites requirements
create or replace function check_prerequisites(roll_number varchar, course_id varchar)
returns boolean as
$$
declare
    present boolean;
    requirement varchar;
    course record;
    pre_requisites varchar[];
begin

    select academic_data.course_catalog.pre_requisites
    from academic_data.course_catalog
    where academic_data.course_catalog.course_code = course_id
    into pre_requisites;

    if pre_requisites = '{}'
        then return true; -- no requirement
    end if;

    foreach requirement in array pre_requisites
    loop
        present := false;
        for course in execute ('select * from student_grades.student_' || roll_number || ';')
        loop
            if course.grade != 0 and course.course_code = requirement
                then present = true;  -- requirement completed
            end if;
        end loop;
        if present = false
            then 
            raise notice 'Prerequisite % not found';
           return false;
        end if;
    end loop;
   	raise notice 'Prerequisites found';
    return true;
end;
$$ language plpgsql;

-- check allowed batches
create or replace function check_allowed_batches(roll_num varchar, course_code varchar)
returns boolean as
$$
declare
    current_semester integer;
    current_year integer;
    student_batch varchar;
    allowed_batches varchar[];
    batch varchar;
begin
    select semester, year
    from academic_data.semester
    into current_semester, current_year;

    select batch_year
    from academic_data.student_info
    where academic_data.student_info.roll_number = roll_num
    into student_batch;

    execute(format('select allowed_batches from course_offerings.sem_%s_%s where course_code=''%s'';',
        current_year, current_semester, course_code)) into allowed_batches;

    if allowed_batches is null or allowed_batches='{}' then return true; end if;

    foreach batch in array allowed_batches
    loop
        if batch = student_batch
            then 
            raise notice 'Batch allowed';
           return true;
        end if;
    end loop;

   	raise notice 'Batch not allowed';
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
            then 
            raise notice 'Slot not free';
           return false;
        end if;
    end loop;
	
   	raise notice 'Slot free';
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
            select credits from academic_data.course_catalog where academic_data.course_catalog.course_code = course.course_code into course_cred;
            scored := scored + course_cred * course.grade;
            total_credits := total_credits + course_cred;
        end if;
    end loop;
   
   	IF total_credits=0 THEN RETURN TRUE;END IF;
   
    cgpa := (scored) / total_credits;
    if cgpa >= required
        then 
        raise notice 'CGPA req passed';
       return true;
    ELSE
    	raise notice 'CGPA req failed';
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
   registered record;
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
        then 
        raise notice 'Credit limit satisfied.';
       return true;
    ELSE
    	raise notice 'Credit limit failed.';
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

    if flag = TRUE then 
    	raise notice 'All checks cleared, provisionally registered.';
       return new;
    else
        -- todo: tell reason for failure
 		raise notice 'Registration failed.';
        return null;
    end if;
end;
$trigfunc$;

create or replace procedure register_for_course(course_id text)
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
             '(roll_number, course_code) values (''' || roll_number || ''', ''' || course_id || ''');');
    -- will trigger the check above
end
$func$
