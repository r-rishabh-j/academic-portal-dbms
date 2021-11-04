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
    registrations,
    adviser_actions
    cascade;
   
drop schema if exists ug_curriculum cascade;

/*
 create the required schemas which will have tables and some custom dummy data
 */
create schema academic_data; -- for general academic data
create schema admin_data;
create schema faculty_actions;
create schema adviser_actions;
create schema student_grades; -- for final grades of the student for all the courses taken to generate C.G.P.A.
create schema course_offerings; -- for course offered in the particular semester and year
create schema registrations;
create schema ug_curriculum;


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
INSERT INTO academic_data.semester VALUES(0,0); -- default

insert into academic_data.departments (dept_name)
values ('cse'), -- computer science and engineering
       ('me'), -- mechanical engineering
       ('ee'), -- civil engineering
       ('ge'), -- general
       ('sc'), -- sciences
       ('hs') -- humanities
;

-- undergraduate curriculum implemented only
create table academic_data.degree_info
(
    degree_type varchar primary key,
    program_electives_credits integer,
    open_electives_credits integer
);
insert into academic_data.degree_info
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
    foreign key (department) references academic_data.departments (dept_name)
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

create table academic_data.adviser_info
(
    adviser_id varchar primary key ,
    batch_dept varchar,
    batch_year integer
);
-- dept_year

create table academic_data.ug_batches
(
    dept_name varchar,
    batch_year integer,
    adviser_f_id varchar,
    foreign key(adviser_f_id) REFERENCES academic_data.adviser_info(adviser_id),
    PRIMARY KEY (dept_name, batch_year)
);

create table academic_data.timetable_slots
(
    slot_name varchar primary key
);

insert into academic_data.timetable_slots values(1);
insert into academic_data.timetable_slots values(2);
insert into academic_data.timetable_slots values(3);
insert into academic_data.timetable_slots values(4);
insert into academic_data.timetable_slots values(5);
insert into academic_data.timetable_slots values(6);
insert into academic_data.timetable_slots values(7);


grant usage on schema registrations to public;
grant usage on schema course_offerings to public;
grant select, references on all tables in schema course_offerings to public;
grant usage on schema academic_data to public;
grant select, references on all tables in schema academic_data to public;
grant usage on schema student_grades to public;
grant usage on schema ug_curriculum to public;
grant select on all tables in schema ug_curriculum to public;

create or replace function course_offerings.create_registration_table()
returns trigger as
$$
declare
semester integer;
year integer;
f_id varchar;
curr_user varchar;
BEGIN
	select current_user into curr_user;
	IF curr_user!=NEW.course_coordinator THEN raise notice 'Invalid faculty id';RETURN NULL; END IF;
    select academic_data.semester.semester, academic_data.semester.year from academic_data.semester into semester, year;
    execute('create table registrations.'||new.course_code||'_'||year||'_'||semester||' '||
    '(
        roll_number varchar primary key,
        grade integer default 0,
        foreign key(roll_number) references academic_data.student_info(roll_number)
    );');
    
    foreach f_id in array new.instructors
    loop
        if f_id=curr_user then continue;
        end if;
        execute('grant select, update on registrations.'||new.course_code||'_'||year||'_'||semester||' to '||f_id||' with grant option;');
    end loop;
    return new;
end;
$$language plpgsql;

create or replace function faculty_actions.show_regs(course_id varchar) returns table (roll_number varchar, grade integer)
AS
$f$
DECLARE
	sem integer;
	yr integer;
BEGIN
	SELECT semester, YEAR FROM academic_data.semester INTO sem, yr;
	RETURN query execute(format($d$ SELECT * FROM registrations.%s_%s_%s; $d$, course_id, yr, sem));
END;
$f$ LANGUAGE plpgsql;

------------------------------------------------------------------------------------------------------------------------------------------------
create or replace procedure admin_data.add_new_semester(academic_year integer, semester_number integer)
as
$function$
declare
    -- iterator to run through all the faculties' ids
    faculty_cursor cursor for select faculty_id from academic_data.faculty_info;
    adviser_cursor cursor for select adviser_id from academic_data.adviser_info;
    student_cursor cursor for select roll_number from academic_data.student_info;
    declare f_id         academic_data.faculty_info.faculty_id%type;
    declare adviser_f_id academic_data.adviser_info.adviser_id%type;
    declare s_rollnumber academic_data.student_info.roll_number%type;
begin
    update academic_data.semester set semester=semester_number, year=academic_year where true;
    execute ('create table course_offerings.sem_' || academic_year || '_' || semester_number || ' '||'
            (
                    course_code     varchar primary key,
                    course_coordinator varchar not null, -- tickets to be sent to course coordinator only
                    instructors     varchar[] not null,
                    slot            varchar,
                    allowed_batches varchar[] not null, -- will be combination of batch_year and department: cse_2021
                    cgpa_req        real default 0,
                    foreign key (course_code) references academic_data.course_catalog (course_code)
            );'
        );
    
--    execute(format($f$create TABLE $f$));
       
    execute(format($s$grant select on course_offerings.sem_%s_%s to public;$s$, academic_year, semester_number));
    execute('create trigger trigger_sem_'||academic_year||'_'||semester_number||' '||'after insert on course_offerings.sem_' || academic_year || '_' || semester_number
                ||' for each row execute function course_offerings.create_registration_table();');

    execute ('create table registrations.provisional_course_registrations_' || academic_year || '_' || semester_number || ' '||'
                (   
                    roll_number     varchar not null,
                    course_code     varchar,
                    foreign key (course_code) references academic_data.course_catalog (course_code),
                    foreign key (roll_number) references academic_data.student_info (roll_number),
                    primary key (roll_number, course_code)
                );' ||
             'create trigger ensure_valid_registration
                before insert
                on registrations.provisional_course_registrations_' || academic_year || '_' || semester_number || ' '||'
                for each row
             execute function check_register_for_course();'
        );

    execute(format($s$grant select on registrations.provisional_course_registrations_%s_%s to public;$s$, academic_year, semester_number));

    execute('create table registrations.dean_tickets_'||academic_year||'_'||semester_number||' '||
       '(roll_number varchar not null,
        course_code varchar not null,
        dean_decision boolean,
        faculty_decision boolean,
        adviser_decision boolean,
        foreign key (course_code) references academic_data.course_catalog (course_code),
        foreign key (roll_number) references academic_data.student_info (roll_number),
        primary key (roll_number, course_code));
    ');
    open student_cursor;
    loop
        fetch student_cursor into s_rollnumber;
        exit when not found;
        -- execute('grant select on course_offerings.sem_'||academic_year||'_'||semester_number||' to '||s_rollnumber||';');
        execute('grant select, insert on registrations.provisional_course_registrations_'||academic_year||'_'||semester_number||' to '||s_rollnumber||';');
        execute('grant select on registrations.dean_tickets_'||academic_year||'_'||semester_number||' to '||s_rollnumber||';');
    end loop;
    close student_cursor;

    open faculty_cursor;
    loop
        fetch faculty_cursor into f_id;
        exit when not found;
        -- store the tickets for a faculty in that particular semester
        execute(format('grant select on all tables in schema student_grades to %s;', f_id));
        execute('grant select, insert on registrations.provisional_course_registrations_'||academic_year||'_'||semester_number||' to '||f_id||';');
        execute ('create table registrations.faculty_ticket_' || f_id || '_' || academic_year || '_' || semester_number ||' '||
                 '(
                     roll_number varchar not null,
                     course_code varchar not null,
                     status boolean,
                     foreign key (course_code) references academic_data.course_catalog (course_code),
                     foreign key (roll_number) references academic_data.student_info (roll_number),
                     primary key (roll_number, course_code)
                 );'
            );
        execute(format($d$create trigger faculty_ticket_trigger_%s_%s_%s before insert on registrations.faculty_ticket_%s_%s_%s for each row
            execute function check_instructor_match('%s')$d$, f_id, academic_year, semester_number, f_id, academic_year, semester_number, f_id));
        execute('grant all privileges on registrations.faculty_ticket_' || f_id || '_' || academic_year || '_' ||semester_number ||' to '||f_id||';');
        execute('grant insert on course_offerings.sem_'||academic_year||'_'||semester_number||' to '||f_id||';');

        open student_cursor;
        loop
            fetch student_cursor into s_rollnumber;
            exit when not found;
            execute format('grant select, insert on registrations.faculty_ticket_'||f_id||'_'||academic_year||'_' || semester_number ||' to '||s_rollnumber||';');
        end loop;
        close student_cursor;
    end loop;
    close faculty_cursor;

    -- create adviser tables
    open adviser_cursor;
    loop
        fetch adviser_cursor into adviser_f_id;
        exit when not found;
        -- store the tickets for a adviser in that particular semester
        execute ('create table registrations.adviser_ticket_' || adviser_f_id || '_' || academic_year || '_' || semester_number ||
                    ' (
                        roll_number varchar not null,
                        course_code varchar not null,
                        status boolean,
                        foreign key (course_code) references academic_data.course_catalog (course_code),
                        foreign key (roll_number) references academic_data.student_info (roll_number),
                        primary key (roll_number, course_code)
                    );'
            );
        execute(format($d$create trigger adviser_ticket_trigger_%s_%s_%s before insert on registrations.adviser_ticket_%s_%s_%s for each row
            execute function check_adviser_match('%s')$d$, adviser_f_id, academic_year, semester_number, adviser_f_id, academic_year, semester_number, adviser_f_id));
        execute('grant all privileges on registrations.adviser_ticket_' || adviser_f_id || '_' || academic_year || '_' ||semester_number ||' to '||adviser_f_id||';');
        open student_cursor;
        loop
            fetch student_cursor into s_rollnumber;
            exit when not found;
            execute format('grant select, insert on registrations.adviser_ticket_'||adviser_f_id||'_'||academic_year||'_' || semester_number ||' to '||s_rollnumber||';');
        end loop;
        close student_cursor;
    end loop;
    close adviser_cursor;
end;
$function$ language plpgsql;
------------------------------------------------------------------------------------------------------------------------------------------------
create or replace FUNCTION show_prov_reg() returns
table(roll_number varchar, course_code varchar) AS
$f$
DECLARE
	sem integer;
	yr integer;
BEGIN
	SELECT semester, YEAR FROM academic_data.semester INTO sem, yr;
	RETURN query execute(format($s$ SELECT * FROM registrations.provisional_course_registrations_%s_%s;$s$, yr,sem));
END;
$f$ LANGUAGE plpgsql;

create or replace FUNCTION show_offerings() returns
table(course_code varchar, course_coordinator varchar, instructors varchar[],
slot varchar, allowed_batches varchar[], cgpa_req real) AS
$f$
DECLARE
	sem integer;
	yr integer;
BEGIN
	SELECT semester, YEAR FROM academic_data.semester INTO sem, yr;
	RETURN query execute(format($s$ SELECT * FROM course_offerings.sem_%s_%s;$s$, yr,sem));
END;
$f$ LANGUAGE plpgsql;

create or replace FUNCTION show_catalog() returns
table(course_code varchar, dept_name varchar, credits real,
credit_structure varchar, course_description varchar, pre_requisites varchar[]) AS
$f$
BEGIN
	RETURN query SELECT * FROM academic_data.course_catalog;
END;
$f$ LANGUAGE plpgsql;

------------------------------------------------------------------------------------------------------------------------------------------------
create or replace function admin_data.create_student() returns trigger
as
$function$
declare
pswd varchar:='123';
begin
--     create user roll_number password roll_number;

    execute format('drop user if exists %I;', new.roll_number);
    execute format('create user %I password %L;', new.roll_number, pswd);
    execute ('create table student_grades.student_' || new.roll_number || ' '||'
                (
                    course_code     varchar not null,
                    semester        integer not null,
                    year            integer not null,
                    grade           integer not null default ''0'',
                    foreign key (course_code) references academic_data.course_catalog (course_code),
                    primary key(course_code, semester, year)
            );' ||
             'grant select on student_grades.student_' || new.roll_number || ' to ' || new.roll_number || ';'
        );
    return new;
end;
$function$ language plpgsql;
create trigger generate_student_record
    after insert
    on academic_data.student_info
    for each row
execute function admin_data.create_student();
------------------------------------------------------------------------------------------------------------------------------------------------
-- creating a faculty
create or replace function admin_data.create_faculty() returns trigger
as
$function$
declare
pswd varchar:='123';
begin
    --  create user faculty_id password faculty_id;
    execute format('drop user if exists %I;', new.faculty_id);
    execute format('create user %I password %L;', new.faculty_id, pswd);
    execute format('grant usage on schema faculty_actions to %s;', new.faculty_id);
   
    execute format('grant pg_read_server_files to %s;', new.faculty_id);
   	execute format('grant pg_write_server_files to %s;', new.faculty_id);
    execute format('grant execute on all functions in schema faculty_actions to %s;', new.faculty_id);
    execute format('grant execute on all procedures in schema faculty_actions to %s;', new.faculty_id);
    execute format('grant execute on all functions in schema course_offerings to %s;', new.faculty_id);
    execute format('grant execute on all procedures in schema course_offerings to %s;', new.faculty_id);
    execute format('grant create on schema registrations to %s;', new.faculty_id);
    execute format('grant select on all tables in schema student_grades to %s;', new.faculty_id);
    return new;
end;
$function$ language plpgsql ;

create trigger generate_faculty_record
    after insert
    on academic_data.faculty_info
    for each row
execute function admin_data.create_faculty();
------------------------------------------------------------------------------------------------------------------------------------------------
-- creating a faculty
create or replace function admin_data.create_adviser() returns trigger
as
$function$
declare
pswd varchar:='123';
begin
--     create user faculty_id password faculty_id;
    execute format('drop user if exists %I;', new.adviser_id);
    execute format('create user %I password %L;', new.adviser_id, pswd);
    execute format('grant usage on schema adviser_actions to %s;', new.adviser_id);
    execute format('grant execute on all procedures in schema adviser_actions to %s;', new.adviser_id);
    execute format('grant execute on all functions in schema adviser_actions to %s;', new.adviser_id);
    execute format('grant select on all tables in schema student_grades to %s;', new.adviser_id);
    return new;
end;
$function$ language plpgsql ;

-- todo: to be added to the dean actions later so that only dean's office creates new students
create trigger generate_adviser_record
    after insert
    on academic_data.adviser_info
    for each row
execute function admin_data.create_adviser();

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
    return query execute(format('select * from student_grades.student_%s;', roll_number));
end;
$$ language plpgsql;

-- obtain credit limit
create or replace function get_credit_limit(roll_number varchar)
    returns real as
$$
declare
    current_semester    integer;
    current_year        integer;
    course_id         varchar;
    courses_to_consider varchar[];
    credits_taken       real;
    b1 boolean:=FALSE;
   b2 boolean:=FALSE;
begin
    select semester, year from academic_data.semester into current_semester, current_year;
    if current_semester = 2
    then
        -- even semester
    	for course_id in select grades_list.course_code from get_grades_list(roll_number) as grades_list
                                                                 where grades_list.semester = 1
                                                                   and grades_list.year = current_year
        loop 
        	b1:=TRUE;
        	courses_to_consider=array_append(courses_to_consider, course_id); 
        end loop;
       
       for course_id in select grades_list.course_code from get_grades_list(roll_number) as grades_list
                                                                 where grades_list.semester = 2
                                                                   and grades_list.year = current_year-1
        loop 
        	b2:=TRUE;
        	courses_to_consider=array_append(courses_to_consider, course_id); 
        end loop;
--        courses_to_consider = array_append(courses_to_consider, (select grades_list.course_code
--                                                                 from get_grades_list(roll_number) as grades_list
--                                                                 where grades_list.semester = 1
--                                                                   and grades_list.year = current_year));
--        courses_to_consider = array_append(courses_to_consider, (select grades_list.course_code
--                                                                 from get_grades_list(roll_number) as grades_list
--                                                                 where grades_list.semester = 2
--                                                                   and grades_list.year = current_year - 1));
    else
        -- odd semester
    	for course_id in select grades_list.course_code from get_grades_list(roll_number) as grades_list
                                                                 where grades_list.semester = 1
                                                                   and grades_list.year = current_year-1
        loop 
        	b1:=TRUE;
        	courses_to_consider=array_append(courses_to_consider, course_id); 
        end loop;
       
       for course_id in select grades_list.course_code from get_grades_list(roll_number) as grades_list
                                                                 where grades_list.semester = 2
                                                                   and grades_list.year = current_year-1
        loop 
        	b2:=TRUE;
        	courses_to_consider=array_append(courses_to_consider, course_id); 
        end loop;
--        courses_to_consider = array_append(courses_to_consider, (select grades_list.course_code
--                                                                 from get_grades_list(roll_number) as grades_list
--                                                                 where grades_list.semester = 1
--                                                                   and grades_list.year = current_year - 1));
--        courses_to_consider = array_append(courses_to_consider, (select grades_list.course_code
--                                                                 from get_grades_list(roll_number) as grades_list
--                                                                 where grades_list.semester = 2
--                                                                   and grades_list.year = current_year - 1));
    end if;
    credits_taken = 0;
    if courses_to_consider is not null then
    foreach course_id in array courses_to_consider
        loop
        	if course_id is null then continue;end if;
        	raise notice 'course: %',course_id;
            credits_taken = credits_taken + (select academic_data.course_catalog.credits FROM academic_data.course_catalog
                                             where academic_data.course_catalog.course_code = course_id);
        end loop;
    end if;
    if credits_taken = 0
    then
        return 20;  -- default credit limit
    ELSE
    	IF b1=TRUE AND b2=TRUE then
        return (credits_taken * 1.25) / 2; -- calculated credit LIMIT
        ELSE
        return (credits_taken * 1.25);
       END IF;
    end if;
end;
$$ language plpgsql;

------------------------------------------------------------------------------------------------------------------------------------------------
-- assumed: registrations.coursecode_year_sem tables to be generated by trigger on course_offerings and access granted to the faculty
create or replace procedure admin_data.populate_registrations() as
$function$
declare
    provisional_reg_cursor refcursor;
    reg_table_row record;
    year integer;
    semester integer;
    prov_reg_name text;
    row record;
    faculty_list varchar[];
   stu_exists record;
begin
    -- iterate or provisional registration and dean ticket table
    select academic_data.semester.semester, academic_data.semester.year from academic_data.semester into semester, year;
    prov_reg_name := 'registrations.provisional_course_registrations_' || year || '_' || semester||' ';

    for row in execute format('select * from %s;', prov_reg_name)
    loop
    	execute(format($d$select * FROM registrations.%s_%s_%s WHERE roll_number='%s';$d$, ROW.course_code, YEAR, semester, ROW.roll_number)) INTO stu_exists;
    	IF stu_exists is NULL then
    	execute('insert into registrations.'||row.course_code||'_'||year||'_'||semester||' '||'values('''||row.roll_number||''', 0);'); -- roll_number, grade
   		END IF;
    	end loop;
end;
$function$ language plpgsql;

------------------------------------------------------------------------------------------------------------------------------------------------
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
            execute format($d$insert into registrations.dean_tickets_%s_%s values('%s','%s',null,%L,%L);$d$,yr, sem, row.roll_number, row.course_code, faculty_permission, advisor_permission);
        end loop;
    end loop;
end;
$function$ language plpgsql;

create or replace function admin_data.show_tickets() returns table(roll_number varchar,
        course_code varchar,
        dean_decision boolean,
        faculty_decision boolean,
        adviser_decision boolean) as
$function$
declare
sem integer;
yr integer;
begin
    select semester, year from academic_data.semester into sem, yr;
    return query execute format($dyn$select * from registrations.dean_tickets_%s_%s;$dyn$, yr, sem);
end;
$function$ language plpgsql;
------------------------------------------------------------------------------------------------------------------------------------------------
-- used by admin to update tickets
create or replace procedure admin_data.update_ticket(stu_rollnumber varchar, course varchar,new_status boolean) as
$function$
declare
f_id varchar;
sem integer;
yr integer;
tbl_name varchar;
begin
    select current_user into f_id;
    select semester, year from academic_data.semester into sem, yr;
    tbl_name:=format('registrations.dean_tickets_%s_%s', yr, sem);
    execute format($dyn$update %s set dean_decision=%L where course_code='%s' and roll_number='%s';$dyn$, tbl_name,new_status,course,stu_rollnumber);
    if new_status=true then
        execute format($i$insert into registrations.%s_%s_%s values('%s',0);$i$, course, yr, sem, stu_rollnumber);
        raise notice 'Admin: Student % registered for course %.',stu_rollnumber, course;
    else
        raise notice 'Admin: Ticket of student % for course % rejected.',stu_rollnumber, course;
    end if;
end;
$function$ language plpgsql;
------------------------------------------------------------------------------------------------------------------------------------------------
-- print faculty's tickets
create or replace function faculty_actions.show_tickets() returns table(roll_number varchar, course_code varchar, status boolean) as
$function$
declare
f_id varchar;
sem integer;
yr integer;
begin
    select current_user into f_id;
    select semester, year from academic_data.semester into sem, yr;
    return query execute format($dyn$select * from registrations.faculty_ticket_%s_%s_%s;$dyn$, f_id, yr, sem);
end;
$function$ language plpgsql;

-- used by faculty to update student's tickets
create or replace procedure faculty_actions.update_ticket(stu_rollnumber varchar, course varchar,new_status boolean) as
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
    execute format($dyn$update %s set status=%L where course_code='%s' and roll_number='%s';$dyn$, tbl_name,new_status,course,stu_rollnumber);
    raise notice 'Status for % for course % changed to %',stu_rollnumber,course,new_status;
end;
$function$ language plpgsql;
------------------------------------------------------------------------------------------------------------------------------------------------
create or replace function adviser_actions.show_tickets() returns table(roll_number varchar, course_code varchar, status boolean) as
$function$
declare
adv_id varchar;
sem integer;
yr integer;
begin
    select current_user into adv_id;
    select semester, year from academic_data.semester into sem, yr;
    return query execute format($dyn$select * from registrations.adviser_ticket_%s_%s_%s;$dyn$, adv_id, yr, sem);
end;
$function$ language plpgsql;

-- used by adviser to update student's tickets
create or replace procedure adviser_actions.update_ticket(stu_rollnumber varchar, course varchar, new_status boolean) as
$function$
declare
adv_id varchar;
sem integer;
yr integer;
tbl_name varchar;
begin
    select current_user into adv_id;
    select semester, year from academic_data.semester into sem, yr;
    tbl_name:=format('registrations.adviser_ticket_%s_%s_%s', adv_id, yr, sem);
    execute format($dyn$update %s set status=%L where course_code='%s' and roll_number='%s';$dyn$, tbl_name, new_status, course, stu_rollnumber);
    raise notice 'Status for % for course % changed to %',stu_rollnumber,course,new_status;
end;
$function$ language plpgsql;
------------------------------------------------------------------------------------------------------------------------------------------------
create or replace function calculate_cgpa(roll_number varchar) returns real as
$fn$
declare
    total_credits real:=0;
    scored        real:=0;
    cgpa          real:=0;
    course_cred   real:=0;
    course        record;
begin
    for course in execute ('select * from student_grades.student_' || roll_number || ';')
    loop
        if course.grade != 0 then
            select credits from academic_data.course_catalog where academic_data.course_catalog.course_code = course.course_code into course_cred;
            scored := scored+course_cred * course.grade;
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
    total_credits real:=0;
    scored        real:=0;
    cgpa          real:=0;
    course_cred   real:=0;
    course        record;
    roll_number varchar;
begin
    select current_user into roll_number;
    for course in execute ('select * from student_grades.student_' || roll_number || ';')
    loop
        if course.grade != 0 then
            select credits from academic_data.course_catalog where academic_data.course_catalog.course_code = course.course_code into course_cred;
            scored := scored+course_cred * course.grade;
            total_credits := total_credits + course_cred;
        end if;
    end loop;
   if total_credits=0 then return 0; end if;
    cgpa := (scored) / total_credits;
    return cgpa;
end;
$fn$ language plpgsql;
------------------------------------------------------------------------------------------------------------------------------------------------
-- check if the faculty is offering that course or not
create or replace function check_instructor_match()
    returns trigger as
$$
declare
    student_id varchar;
    coordinator_id varchar;
    f_id varchar;
    sem integer;
    yr integer;
begin
    new.status:=null; -- protection
    f_id = tg_argv[0];
    select current_user into student_id;
    if student_id!=new.roll_number then raise notice 'Invalid roll_number'; return null; end if;
    select semester, year from academic_data.semester into sem, yr;
    execute format($e$select course_coordinator from course_offerings.sem_%s_%s where course_code='%s';$e$,yr,sem,new.course_code) into coordinator_id;
    if coordinator_id is null then raise notice 'Invalid course id'; return null; end if;
    if f_id!=coordinator_id then
        raise notice 'Faculty % is not the course coordinator for course %. Kindly send the ticket to the right instructor.',f_id,new.course_id;
        return null;
    end if;
   raise notice 'Ticket sent to faculty %', f_id;
    return new;
end;
$$ language plpgsql;

-- check if that faculty is the adviser or not
create or replace function check_adviser_match()
    returns trigger as
$$
declare
    student_id varchar;
    adv_id varchar;
    advid varchar; -- for argv
    sem integer;
    yr integer;
begin
    new.status:=null; -- protection
    advid:=tg_argv[0];
    select current_user into student_id;
    if student_id!=new.roll_number then raise notice 'Not your roll_number.'; return null; end if;
    select semester, year from academic_data.semester into sem, yr;

    select adviser_id from academic_data.adviser_info, academic_data.student_info where academic_data.adviser_info.batch_year=academic_data.student_info.batch_year
    and academic_data.adviser_info.batch_dept=academic_data.student_info.department into adv_id;

    if advid!=adv_id then raise notice 'Ticket sent to wrong adviser'; return null; end if;
    raise notice 'Ticket sent to faculty %', advid;
    return new;
end;
$$ language plpgsql;

-- to be used by student, no argument needed
create or replace function generate_student_transcript() returns
table(course_code varchar, semester integer, year integer, grade integer)
as
$f$
declare
    student_id varchar;
begin
    select current_user into student_id;
    raise notice 'Transcript for student %', student_id;
    return query execute(format($d$select * from student_grades.student_%s;$d$, student_id));
end;
$f$language plpgsql;

create or replace function generate_student_transcript(student_id varchar) returns
table(course_code varchar, semester integer, year integer, grade integer)
as
$f$
begin
    raise notice 'Transcript for student %', student_id;
    return query execute(format($d$select * from student_grades.student_%s;$d$, student_id));
end;
$f$language plpgsql;

create or replace procedure admin_data.upload_timetable(file text)
as
$f$
declare
    sem         integer;
    yr          integer;
    course_slot record;
begin
    select semester, year from academic_data.semester into sem, yr;
    create table admin_data.temp_timetable_slots
    (
        course_code varchar,
        slot        varchar
    );
    execute (format($d$copy admin_data.temp_timetable_slots from '%s' delimiter ',' csv header;$d$, file));

    for course_slot in select * from admin_data.temp_timetable_slots
        loop
            execute (format($d$update course_offerings.sem_%s_%s set slot='%s' where course_code='%s';$d$, yr, sem,
                            course_slot.slot, course_slot.course_code));
        end loop;

    drop table admin_data.temp_timetable_slots;
end;
$f$language plpgsql;

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

create or replace procedure faculty_actions.upload_grades(course_name text, grade_file text) as
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
    execute (format($tbl$create table %s
    (
        roll_number varchar,
        grade integer
    );
    $tbl$, temp_table_name));
    -- execute('copy '|| temp_table_name ||' from '''|| grade_file ||''' delimiter '','' csv header;');

    execute (format($dyn$copy %s from '%s' delimiter ',' csv header;$dyn$, temp_table_name, grade_file));
    execute (format($dyn$update %s set grade=%s.grade from %s where %s.roll_number=%s.roll_number;$dyn$, reg_table_name, temp_table_name, temp_table_name, reg_table_name, temp_table_name));

    execute format('drop table %s;', temp_table_name);
end;
$function$ language plpgsql;
---------------------------------------------------------------------------------------------------------------------------
create or replace procedure faculty_actions.update_grade(roll_number text, course text, grade integer)
as
$f$
DECLARE
    sem INTEGER;
    yr INTEGER;
begin
    select semester, year from academic_data.semester into sem, yr;
    EXECUTE(format($d$update registrations.%s_%s_%s set grade=%s where roll_number='%s';$d$, course, yr, sem, grade, roll_number));
    raise notice 'Grade for student % for course % updated to %', roll_number, course, grade;
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
   	grade_record record;
begin
    select semester, year from academic_data.semester into sem, yr;
    for course_offering in execute(format($d$select course_code from course_offerings.sem_%s_%s;$d$,yr,sem))
    loop
        for student in execute(format($d$select * from registrations.%s_%s_%s;$d$,course_offering.course_code, yr, sem))
        loop
        	execute(format($d$select * from student_grades.student_%s where course_code='%s' and semester=%s and year=%s;$d$, student.roll_number, course_offering.course_code, sem, yr)) into grade_record;
        	if grade_record is null then
            	execute(format($d$insert into student_grades.student_%s values('%s', %s, %s, %s);$d$,student.roll_number, course_offering.course_code, sem, yr, student.grade ));
            else
 				execute(format($d$update student_grades.student_%s set grade=%s where course_code='%s' and semester=%s and year=%s;$d$, student.roll_number, student.grade, course_offering.course_code, sem, yr));
            end if;
 			raise notice 'Student % given % grade in course %.', student.roll_number, student.grade, course_offering.course_code;
        end loop;
    end loop;
end;
$f$ language plpgsql;
----------------------------------------------------------------------------------------------------------------------------
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
---------------------------------------------------------------------------------------------------------------------------------------
create or replace procedure faculty_actions.dump_grades(course_code text, dump_path text)
as
$d$
declare
sem integer; 
yr integer;
begin
    select semester, year from academic_data.semester into sem, yr;
    execute(format($s$copy registrations.%s_%s_%s to '%s' with (format csv, header);$s$, course_code, yr, sem, dump_path));
    raise notice 'Registration file for course % dumped at %', course_code, dump_path;
end;
$d$language plpgsql;

----------------------------------------------------------------------------------------------------------------------------------------
create or replace procedure ug_curriculum.create_batch_tables()
as
$$
declare
	ug_batches_cursor cursor for select * from academic_data.ug_batches;
	batch_year integer;
	dept_name varchar;
	rec_batch record;
begin 
	open ug_batches_cursor;
	
	loop
		fetch ug_batches_cursor into rec_batch;
		exit when not found;
		execute('create table ug_curriculum.' || rec_batch.dept_name || '_' || rec_batch.batch_year || ' '||
				'(
					course_code				varchar not null,
					course_description		varchar default '''',
					credits					real not null,
					type					varchar not null,
					primary key(course_code)
				);'	
			);
	end loop;
	grant select on all tables in schema ug_curriculum to public;
	CLOSE ug_batches_cursor;
end;
$$ language plpgsql;

--write load from csv, admin_data function

create or replace function is_ready_to_graduate(student_roll_number varchar)
returns boolean
language plpgsql
as
$$
declare
	student_cgpa real := calculate_cgpa(student_roll_number);
	student_batch integer;
	student_dept varchar;
	pe_credits_req real;
	oe_credits_req real;
	pe_credits_done real := 0;
	oe_credits_done real := 0;
	course record;
	req record;
	course_cred real;
	course_type varchar;
	program_core varchar[];
	science_core varchar[];
	present boolean;	-- found is also a keyword

begin 
	--1.check minimum of 5 CGPA
	if student_cgpa < 5 then raise notice 'Not ready to graduate. CGPA <5';return false; end if;

	--2.check all core(program and science) courses done
	execute('select batch_year, department from academic_data.student_info where academic_data.student_info.roll_number = ''' || student_roll_number || ''' ;' ) INTO student_batch, student_dept;

	for req in execute('select * from ug_curriculum.' || student_dept || '_' || student_batch || ' where type = ''PC'' or type =''SC'';')
	loop
		present := false;
		for course in execute('select * from student_grades.student_'|| student_roll_number || ';')
		loop
			if course.grade != 0 and course.course_code = req.course_code then 
				present = true;
			end if;
		end loop;
		if present = false THEN raise notice 'Not ready to graduate. PC or SC not completed'; return false; end if;
	end loop;
	
	--3.check elective (program and open) credits against acads limit
	--replace table name as "academic_data.degree_info" and field name as "degree_type"
	select program_electives_credits, open_electives_credits from academic_data.degree_info where degree_type = 'btech' into pe_credits_req, oe_credits_req;
	
	for course in execute('select * from student_grades.student_'|| student_roll_number || ';')
	loop
		--check syntax!
		execute('select type, credits from ug_curriculum.' || student_dept || '_' || student_batch || ' where course_code = ''' || course.course_code || ''';' )INTO course_type, course_cred;
		if course.grade != 0 and course_type = 'PE' then
			pe_credits_done :=  pe_credits_done + course_cred;
		end if;
		if course.grade != 0 and course_type = 'OE' then
			oe_credits_done :=  oe_credits_done + course_cred;
		end if;
	end loop;

	if pe_credits_done < pe_credits_req or oe_credits_done < oe_credits_req then 
        raise notice 'Not ready to graduate';
		return false;
	end if;
        raise notice 'Ready to graduate !';
	return true;
end;
$$;

create or replace procedure ug_curriculum.upload_curriculum(filep text, dept varchar, year integer)
as  
$f$
begin 
	execute(format($d$copy ug_curriculum.%s_%s from '%s' delimiter ',' csv header;$d$, dept, year, filep));
end;
$f$language plpgsql;

----------------------------------------------------------------------------------------------------------------------------------------------

create or replace procedure admin_data.upload_offerings(filep text)
as 
$f$
declare
sem integer;
yr integer;
begin 
	select semester, year from academic_data.semester into sem, yr;
	execute(format($d$copy course_offerings.sem_%s_%s from '%s' delimiter ',' csv header;$d$, yr, sem, filep));
end;
$f$language plpgsql;

create or replace procedure admin_data.upload_catalog(filep text)
as 
$f$
declare
sem integer;
yr integer;
begin 
	execute(format($d$copy academic_data.course_catalog from '%s' delimiter ',' csv header;$d$,filep));
end;
$f$language plpgsql;

---------------------------------------------------------------------------------------------------------------------------------------
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

    if pre_requisites = '{}' or pre_requisites is null
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
            raise notice 'Prerequisite % not found', requirement;
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
   
--    execute(format($d$select course_code from course_offerings.sem_%s_%s where course_code='%s';$d$, current_year, current_semester, course_code)) into course;
--   	
--   if course is null then raise notice 'Course not offered this semester.';return false;end if;
   
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
	allowed := get_credit_limit(roll_number);
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
	
   raise notice 'allowed: %, taken: %',allowed, taken;
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
   	curr_user varchar;
   	student_batch integer;
   	student_dept varchar;
   	check_course record;
   current_year integer;
  current_semester integer;
begin
    -- ensure prerequisites
	SELECT current_user INTO curr_user;
	select semester, year from academic_data.semester into current_semester, current_year;
	IF curr_user!=NEW.roll_number THEN raise notice 'Permission denied. Invalid roll_number'; RETURN NULL; END IF;

	execute('select batch_year, department from academic_data.student_info where academic_data.student_info.roll_number = ''' || curr_user || ''' ;' ) INTO student_batch, student_dept;
	
	execute(format($d$select course_code from course_offerings.sem_%s_%s where course_code='%s';$d$, current_year, current_semester, new.course_code)) into check_course;
   	
   	if check_course is null then raise notice 'Course not offered this semester.';return null;end if;

	execute(format($d$select course_code from ug_curriculum.%s_%s where course_code='%s';$d$, student_dept, student_batch, new.course_code)) into check_course;
	if check_course is null then
	raise notice 'Course not in UG Curriculum';
		RETURN NULL; 
	END IF;
--	IF NEW.course_code NOT IN execute('select course_code from ug_curriculum.' || student_dept || '_' || student_batch || ';') THEN 
--		raise notice 'Course not in UG Curriculum'
--		RETURN NULL; 
--	END IF;
	

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
end;
$func$;

CREATE OR replace PROCEDURE raise_ticket(course_id text)
LANGUAGE plpgsql
AS
$$
DECLARE
	curr_user varchar;
	current_semester 	integer;
    current_year     	integer;
   	coord_id			varchar;
   	student_batch 		 integer;
	student_dept 		 varchar;
	adv_id 				 varchar;
BEGIN
	SELECT current_user INTO curr_user;
	select semester, year from academic_data.semester into current_semester, current_year;

	--insert in course coordinator and adviser ticket table
	execute('select course_coordinator from course_offerings.sem_' || current_year || '_' || current_semester || ' where course_code = ''' || course_id || ''';') INTO coord_id;
	EXECUTE('insert into registrations.faculty_ticket_' || coord_id || '_' || current_year || '_' || current_semester ||
             ' values (''' || curr_user || ''', ''' || course_id || ''', NULL);');
            
    --insert in adviser_table
    execute('select batch_year, department from academic_data.student_info where academic_data.student_info.roll_number = ''' || curr_user || ''';') INTO student_batch, student_dept;
	execute('select adviser_f_id from academic_data.ug_batches where dept_name = ''' || student_dept || ''' and batch_year = ''' || student_batch || ''';') INTO adv_id;
	EXECUTE('insert into registrations.adviser_ticket_' || adv_id || '_' || current_year || '_' || current_semester ||
             ' values (''' || curr_user || ''', ''' || course_id || ''', NULL);');
END;
$$;
