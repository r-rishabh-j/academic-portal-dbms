/*
 the aim of this file is to setup the schemas and tables,
 create cleanup functions, startup functions and
 populate the tables with some dummy data as well.
 */


/*
 delete all previous schemas, tables and data to start off with a clean database
 */
drop schema if exists
    academic_data,
    course_offerings,
    faculty_actions,
    admin_data,
    student_grades,
    registrations
    cascade;

/*
 create the required schemas which will have tables and some custom dummy data
 */
create schema academic_data; -- for general academic data
create schema admin_data;
create schema faculty_actions;
create schema course_offerings; -- for course offered in the particular semester and year
create schema student_grades; -- for final grades of the student for all the courses taken to generate C.G.P.A.
create schema registrations;
-- will contain information regarding student registration and tickets

-- five departments considered, can be scaled up easily
create table academic_data.departments
(
    dept_name varchar primary key
);

-- stores current 
create table academic_data.semester
(
    semester integer not null,
    year integer not null,
    primary key (semester, year)
);


grant select on academic_data.semester to PUBLIC;

insert into academic_data.departments (dept_name)
values ('cse'), -- computer science and engineering
       ('me'), -- mechanical engineering
       ('ee'), -- civil engineering
       ('ge'), -- general
       ('sc'), -- sciences
       ('hs') -- humanities
;

-- undergraduate curriculum implemented only
create table academic_data.degree
(
    degree varchar primary key,
    program_electives integer,
    open_electives integer
);
insert into academic_data.degree
values ('btech', 6, 18); -- bachelors degree only

create table academic_data.course_catalog
(
    course_code        varchar primary key,
    dept_name          varchar not null,
    credits            real not null,
    credit_structure   varchar not null,
    course_description varchar   default '',
    pre_requisites     varchar[] default '{}',
    foreign key (dept_name) references academic_data.departments (dept_name)
);

-- todo: populate course catalog with dummy data from csv file
create table academic_data.student_info
(
    roll_number  varchar primary key,
    student_name varchar not null,
    department   varchar not null,
    batch_year   integer not null,
    foreign key (department) references academic_data.departments (dept_name),
    foreign key (degree) references academic_data.degree (degree)
);
-- todo: populate student info with dummy list of students from csv file

create table academic_data.faculty_info
(
    faculty_id   varchar primary key,
    faculty_name varchar not null,
    department   varchar not null,
    foreign key (department) references academic_data.departments (dept_name)
);
-- todo: populate faculty info with dummy list of faculties from csv file

-- dept_year
create table academic_data.ug_batches
(
    dept_name varchar,
    batch_year integer,
    adviser_f_id varchar,
    PRIMARY KEY (dept_name, batch_year)
);
-- TODO: populate with some random faculties acting as advisers from available faculties

create table academic_data.timetable_slots
(
    slot_name varchar primary key
);

create function course_offerings.create_registration_table()
returns trigger as
$$
declare
semester integer;
year integer;
f_id varchar;
curr_user varchar;
begin
    select academic_data.semester.semester, academic_data.semester.year from academic_data.semester into semester, year;
    execute('create table registrations.'||new.course_code||'_'||year||'_'||semester||' '||
    '(
        roll_number varchar not null,
        grade integer default 0,
        foreign key(roll_number) references academic_data.student_info
    );');
    select current_user into curr_user;
    foreach f_id in array new.instructors
    loop
        if f_id=curr_user then continue;
        end if;
        execute('grant select, update on registrations.'||new.course_code||'_'||year||'_'||semester||' to '||f_id||';');
    end loop;
    return new;
end;
$$language plpgsql;

create or replace function course_offerings.add_new_semester(academic_year integer, semester_number integer)
    returns void as
$function$
declare
    -- iterator to run through all the faculties' ids
    faculty_cursor cursor for select faculty_id
                              from academic_data.faculty_info;
    declare f_id         academic_data.faculty_info.faculty_id%type;
    declare adviser_f_id academic_data.faculty_info.faculty_id%type;
    student_cursor cursor for select roll_number from academic_data.student_info;
    declare s_rollnumber academic_data.student_info.roll_number%type;
begin
    -- assuming academic_year = 2021 and semester_number = 1
    -- will create table course_offerings.sem_2021_1 which will store the courses being offered that semester
    execute ('create table course_offerings.sem_' || academic_year || '_' || semester_number || '
                (
                    course_code     varchar primary key,
                    course_coordinator varchar not null, -- tickets to be sent to course coordinator only
                    instructors     varchar[] not null,
                    slot            varchar,
                    allowed_batches varchar[] not null, -- will be combination of batch_year and department: cse_2021
                    foreign key (course_code) references academic_data.course_catalog (course_code)
                );'
        );
    execute('create trigger course_offerings.trigger_sem_'||academic_year||'_'||semester_number||
    'after insert on course_offerings.sem_' || academic_year || '_' || semester_number ||' for each row execute procedure
    course_offerings.create_registration_table();');
    -- will create table registrations.provisional_course_registrations_2021_1
    -- to be deleted after registration window closes
    -- to store the list of students interest in taking that course in that semester
    -- whether to allow or not depends on various factors and
    -- if accepted, then will be saved to registrations.{course_code}_2021_1
    execute ('create table registrations.provisional_course_registrations_' || academic_year || '_' || semester_number || '
                (   
                    roll_number     varchar not null,
                    course_code     varchar ,
                    foreign key (course_code) references academic_data.course_catalog (course_code),
                    foreign key (roll_number) references academic_data.student_info (roll_number)
                );'
        );

    open student_cursor;
    loop
        fetch student_cursor into s_rollnumber;
        exit when not found;
        execute('grant select on course_offerings.sem_'||academic_year||'_'||semester_number||' to '||s_rollnumber||';');
        execute('grant insert on course_offerings.provisional_course_registrations_'||academic_year||'_'||semester_number||' to '||s_rollnumber||';');
        execute('grant insert on registrations.student_ticket_'||academic_year||'_'||semester_number||' to '||s_rollnumber||';');
    end loop;
    close student_cursor;

    execute('create table admin_data.dean_tickets_'||academic_year||'_'||semester_number||
       ' roll_number varchar not null,
        course_code varchar not null,
        dean_decision boolean,
        faculty_decision boolean,
        adviser_decision boolean,
        foreign key (course_code) references academic_data.course_catalog (course_code),
        foreign key (roll_number) references academic_data.student_info (roll_number)
    ');

    open faculty_cursor;
    loop
        fetch faculty_cursor into f_id;
        exit when not found;
        -- store the tickets for a faculty in that particular semester
        execute ('create table registrations.faculty_ticket_' || f_id || '_' || academic_year || ' ' ||
                 semester_number ||
                 ' (
                     roll_number varchar not null,
                     course_code varchar not null,
                     status boolean,
                     foreign key (course_code) references academic_data.course_catalog (course_code),
                     foreign key (roll_number) references academic_data.student_info (roll_number)
                 )'
            );
        execute('grant select on registrations.student_ticket_'||academic_year||'_'||semester_number||' to '||f_id||';');
        execute('grant all privileges on registrations.faculty_ticket_' || f_id || '_' || academic_year || ' ' ||semester_number ||' to '||f_id||';');
        execute('grant insert on course_offerings.sem_'||academic_year||'_'||semester_number||' to '||f_id||';');
        open student_cursor;
        loop
            fetch student_cursor into s_rollnumber;
            exit when not found;
            execute format('grant insert on registrations.faculty_ticket_'||f_id||'_'||academic_year||' to '||s_rollnumber||';');
        end loop;
        close student_cursor;
        -- check if that faculty is also an adviser
        select academic_data.ug_batches.adviser_f_id from academic_data.ug_batches where f_id = academic_data.ug_batches.adviser_f_id into adviser_f_id;
        if adviser_f_id != '' then
            -- store the tickets for a adviser in that particular semester
            execute ('create table registrations.adviser_ticket_' || f_id || '_' || academic_year || ' ' ||
                     semester_number ||
                     ' (
                         roll_number varchar not null,
                         course_code varchar not null,
                         status boolean,
                         foreign key (course_code) references academic_data.course_catalog (course_code),
                         foreign key (roll_number) references academic_data.student_info (roll_number)
                     )'
                );
            execute('grant all privileges on registrations.adviser_ticket_' || f_id || '_' || academic_year || ' ' ||semester_number ||' to '||f_id||';');
            open student_cursor;
            loop
                fetch student_cursor into s_rollnumber;
                exit when not found;
                execute format('grant insert on registrations.faculty_ticket_'||f_id||'_'||academic_year||' to '||s_rollnumber||';');
            end loop;
            close student_cursor;
        end if;
    end loop;
    close faculty_cursor;

end;
$function$ language plpgsql;

create or replace function admin_data.create_student() returns trigger
as
$function$
begin
--     create user roll_number password roll_number;
    execute format('create user %I password %L;', new.roll_number, new.roll_number);
    execute ('create table student_grades.student_' || new.roll_number || '
                (
                    course_code     varchar not null,
                    semester        integer not null,
                    year            integer not null,
                    grade           integer not null default ''0'',
                    foreign key (course_code) references academic_data.course_catalog (course_code)
            );' ||
             'grant select on student_grades.student_' || new.roll_number || ' to ' || new.roll_number || ';'
        );
    execute format('grant select on academic_data.course_catalog to %s;', new.roll_number);
    execute format('grant select on academic_data.student_info to %s;', new.roll_number);
    execute format('grant select on academic_data.faculty_info to %s;', new.roll_number);
    execute format('grant select on academic_data.departments to %s;', new.roll_number);
--
--     grant select on academic_data.course_catalog to new.roll_number;
--     grant select on academic_data.student_info to new.roll_number;
--     grant select on academic_data.faculty_info to new.roll_number;
--     grant select on academic_data.departments to new.roll_number;
    return new;
end;
$function$ language plpgsql;

-- todo: to be added to the dean actions later so that only dean's office creates new students
create trigger generate_student_record
    after insert
    on academic_data.student_info
    for each row
execute procedure admin_data.create_student();

-- creating a faculty
create or replace function admin_data.create_faculty() returns trigger
as
$function$
declare
begin
--     create user faculty_id password faculty_id;
    execute format('create user %I password %L;', new.faculty_id, new.faculty_id);
    execute format('grant select on academic_data.course_catalog to %s;', new.faculty_id);
    execute format('grant select on academic_data.student_info to %s;', new.faculty_id);
    execute format('grant select on academic_data.faculty_info to %s;', new.faculty_id);
    execute format('grant select on academic_data.departments to %s;', new.faculty_id);
    return new;
--     grant select on academic_data.student_info to faculty_id;
--     grant select on academic_data.faculty_info to faculty_id;
--     grant select on academic_data.departments to faculty_id;
end;
$function$ language plpgsql ;

-- todo: to be added to the dean actions later so that only dean's office creates new students
create trigger generate_faculty_record
    after insert
    on academic_data.faculty_info
    for each row
execute function admin_data.create_faculty();

-- get the credit limit for a given roll number
create or replace function get_grades_list(roll_number varchar)
returns table (
    course_code varchar,
    semester    integer,
    year        integer,
    grade       integer
) as
$$
begin
    return query execute(format('select * from student_grades.student_%s', roll_number));
end;
$$ language plpgsql;

create or replace function get_credit_limit(roll_number varchar)
    returns real as
$$
declare
    current_semester    integer;
    current_year        integer;
    course_code         varchar;
    courses_to_consider varchar[];
    credits_taken       real;
begin
    select semester, year from academic_data.semester into current_semester, current_year;
    if current_semester = 2
    then
        -- even semester
        courses_to_consider = array_append(courses_to_consider, (select grades_list.course_code
                                                                 from get_grades_list(roll_number) as grades_list
                                                                 where grades_list.semester = 1
                                                                   and grades_list.year = current_year));
        courses_to_consider = array_append(courses_to_consider, (select grades_list.course_code
                                                                 from get_grades_list(roll_number) as grades_list
                                                                 where grades_list.semester = 2
                                                                   and grades_list.year = current_year - 1));
    else
        -- odd semester
        courses_to_consider = array_append(courses_to_consider, (select grades_list.course_code
                                                                 from get_grades_list(roll_number) as grades_list
                                                                 where grades_list.semester = 1
                                                                   and grades_list.year = current_year - 1));
        courses_to_consider = array_append(courses_to_consider, (select grades_list.course_code
                                                                 from get_grades_list(roll_number) as grades_list
                                                                 where grades_list.semester = 2
                                                                   and grades_list.year = current_year - 1));
    end if;
    credits_taken = 0;
    foreach course_code in array courses_to_consider
        loop
            credits_taken = credits_taken + (select academic_data.course_catalog.credits
                                             where academic_data.course_catalog.course_code = course_code);
        end loop;
    if credits_taken = 0
    then
        return 20;  -- default credit limit
    else
        return (credits_taken * 1.25) / 2; -- calculated credit limit
    end if;
end;
$$ language plpgsql;

-- assumed: registrations.coursecode_year_sem tables to be generated by trigger on course_offerings and access granted to the faculty
create or replace function admin_data.populate_registrations() returns void as
$function$
declare
    provisional_reg_cursor refcursor;
    reg_table_row record;
    year integer;
    semester integer;
    prov_reg_name text;
    row record;
    faculty_list varchar[];
begin
    -- iterate or provisional registration and dean ticket table
    select academic_data.semester.semester, academic_data.semester.year from academic_data.semester into semester, year;
    prov_reg_name := 'registrations.provisional_course_registrations_' || year || '_' || semester||' ';

    for row in execute format('select * from %I;', prov_reg_name)
    loop
    execute('insert into registrations.'||row.course_code||'_'||year||'_'||semester||' '||'values('''||row.roll_number||''', 0);'); -- roll_number, grade
    end loop;
end;
$function$ language plpgsql;

-- run to get all tickets
create or replace function admin_data.get_tickets() returns void as
$function$
declare
row record;
f_row record;
adv_id varchar;
sem integer;
yr integer;
st_roll varchar;
st_dept varchar;
st_year integer;
faculty_permission boolean;
advisor_permission boolean;
begin
    select semester, year from academic_data.semester into sem, yr;
    for f_row in execute(format('select * from academic_data.faculty_info;'))
    loop
        for row in execute(format('select * from registrations.faculty_ticket_%s_%s_%s;', f_row.faculty_id, yr, sem))
        loop
            faculty_permission:=row.status;
            execute format('select department, batch_year from academic_data.student_info where roll_number=''%s'';',row.roll_number) into st_dept,st_year;
            select adviser_f_id from academic_data.ug_batches where dept_name=st_dept and batch_year=st_year into adv_id;
            execute format('select status from registrations.adviser_ticket_'||adv_id||'_'||yr||'_'||sem||' where roll_number=''%s'' and course_code=''%s'';',
                row.roll_number,row.course_code) into advisor_permission;
            execute format($d$insert into admin_data.dean_tickets_'||yr||'_'||sem||' values('%s','%s',%s,%s,%s);$d$,row.roll_number, row.course_code, null, faculty_permission, advisor_permission);
        end loop;
    end loop;
end;
$function$ language plpgsql;

-- print faculty's tickets
create or replace function faculty_actions.show_tickets() returns table(roll_number varchar, course_code varchar, status boolean) as
$function$
declare
f_id varchar;
sem integer;
yr integer;
begin
    select current_user into f_id;
    select semester, year from academic_data.semester into sem, year;
    return query execute format($dyn$select * from registrations.faculty_ticket_%s_%s_%s;$dyn$, f_id, yr, sem);
end;
$function$ language plpgsql;

-- to be implemented
create or replace function faculty_actions.update_ticket(stu_rollnumber varchar, course varchar,new_status boolean) returns void as
$function$
declare
f_id varchar;
sem integer;
yr integer;
tbl_name varchar;
begin
    select current_user into f_id;
    select semester, year from academic_data.semester into sem, yr;
    tbl_name:=format('registrations.faculty_ticket_%s_%s_%s', f_id, yr, sem);
    execute format($dyn$update %s set status=%s where course_code='%s' and roll_number='%s';$dyn$, tbl_name,new_status,course,stu_rollnumber);
    raise notice 'Status for % for course % changed to %',stu_rollnumber,course,new_status;
end;
$function$ language plpgsql;

-- used by admin to update
create or replace function admin_data.update_ticket(stu_rollnumber varchar, course varchar,new_status boolean) returns void as
$function$
declare
f_id varchar;
sem integer;
yr integer;
tbl_name varchar;
begin
    select current_user into f_id;
    select semester, year from academic_data.semester into sem, yr;
    tbl_name:=format('admin_data.dean_tickets_%s_%s', yr, sem);
    execute format($dyn$update %s set status=%s where course_code='%s' and roll_number='%s';$dyn$, tbl_name,new_status,course,stu_rollnumber);
    if new_status=true then
        execute format($i$insert into registrations.%s_%s_%s values('%s',0);$i$, stu_rollnumber);
        raise notice 'Admin: Student % registered for course %.',stu_rollnumber,course;
    else
        raise notice 'Admin: Ticket of student % for course % rejected.',stu_rollnumber,course;
    end if;
end;
$function$ language plpgsql;