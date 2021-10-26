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
    student_grades,
    registrations
    cascade;

/*
 create the required schemas which will have tables and some custom dummy data
 */
create schema academic_data; -- for general academic data
create schema course_offerings; -- for course offered in the particular semester and year
create schema student_grades; -- for final grades of the student for all the courses taken to generate C.G.P.A.
create schema registrations;
-- will contain information regarding student registration and tickets

-- five departments considered, can be scaled up easily
create table academic_data.departments
(
    dept_name varchar primary key
);
insert into academic_data.departments (dept_name)
values ('cse'), -- computer science and engineering
       ('mcb'), -- mathematics and computing
       ('meb'), -- mechanical engineering
       ('ceb'), -- civil engineering
       ('chb') -- chemical engineering
;

-- undergraduate curriculum implemented only
create table academic_data.degree
(
    degree varchar primary key
);
insert into academic_data.degree
values ('btech'); -- bachelors degree only

create table academic_data.course_catalog
(
    course_code        varchar primary key,
    dept_name          varchar not null,
    credits            integer not null,
    credit_structure   varchar not null,
    course_description varchar   default '',
    pre_requisites     varchar[] default '{}',
    introduced_on      date    not null,
    foreign key (dept_name) references academic_data.departments (dept_name)
);
-- todo: populate course catalog with dummy data from csv file

create table academic_data.student_info
(
    roll_number  varchar primary key,
    student_name varchar not null,
    department   varchar not null,
    batch_year   integer not null,
    degree       varchar default 'btech',
    foreign key (department) references academic_data.departments (dept_name),
    foreign key (degree) references academic_data.degree (degree)
);
-- todo: populate student info with dummy list of students from csv file

create table academic_data.faculty_info
(
    faculty_id   varchar primary key,
    faculty_name varchar not null,
    department   varchar not null,
    contact      varchar,
    foreign key (department) references academic_data.departments (dept_name)
);
-- todo: populate faculty info with dummy list of faculties from csv file

create table academic_data.advisers
(
    faculty_id varchar primary key,
    batches    integer[] default '{}', -- format batch_year, assumed to be of their own department
    foreign key (faculty_id) references academic_data.faculty_info (faculty_id)
);
-- todo: populate with some random faculties acting as advisers from available faculties

create or replace function course_offerings.add_new_semester(academic_year integer, semester_number integer)
    returns void as
$function$
declare
    -- iterator to run through all the faculties' ids
    faculty_cursor cursor for select faculty_id
                              from academic_data.faculty_info;
    declare f_id         academic_data.faculty_info.faculty_id%type;
    declare adviser_f_id academic_data.faculty_info.faculty_id%type;
begin
    -- assuming academic_year = 2021 and semester_number = 1
    -- will create table course_offerings.sem_2021_1 which will store the courses being offered that semester
    execute ('create table course_offerings.sem_' || academic_year || '_' || semester_number || '
                (
                    course_code     varchar primary key,
                    instructors     varchar[] not null,
                    slot            varchar not null,
                    allowed_batches varchar[] not null, -- will be combination of batch_year and department: cse_2021
                    foreign key (course_code) references academic_data.course_catalog (course_code)
                );'
        );
    -- will create table registrations.provisional_course_registrations_2021_1
    -- to be deleted after registration window closes
    -- to store the list of students interest in taking that course in that semester
    -- whether to allow or not depends on various factors and
    -- if accepted, then will be saved to registrations.{course_code}_2021_1
    execute ('create table registrations.provisional_course_registrations_' || academic_year || '_' ||
             semester_number || '
                (   
                    roll_number     varchar not null,
                    course_code     varchar primary key,
                    foreign key (course_code) references academic_data.course_catalog (course_code),
                    foreign key (roll_number) references academic_data.student_info (roll_number)
                );'
        );

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
                     foreign key (course_code) references academic_data.course_catalog (course_code),
                     foreign key (roll_number) references academic_data.student_info (roll_number)
                 )'
            );
        -- check if that faculty is also an adviser
        select f_id from academic_data.advisers where f_id = academic_data.advisers.faculty_id into adviser_f_id;
        if adviser_f_id != '' then
            -- store the tickets for a adviser in that particular semester
            execute ('create table registrations.adviser_ticket_' || f_id || '_' || academic_year || ' ' ||
                     semester_number ||
                     ' (
                         roll_number varchar not null,
                         course_code varchar not null,
                         foreign key (course_code) references academic_data.course_catalog (course_code),
                         foreign key (roll_number) references academic_data.student_info (roll_number)
                     )'
                );
        end if;
    end loop;
    close faculty_cursor;
end;
$function$ language plpgsql;

create or replace procedure create_empty_grade_sheet(roll_number varchar)
    language plpgsql as
$function$
begin
    execute ('create table student_grades.student_' || roll_number || '
                (
                    course_code     varchar not null,
                    semester        integer not null,
                    year            integer not null,
                    grade           varchar not null default ''NA'',
                    foreign key (course_code) references academic_data.course_catalog (course_code)
            );'
        );
end;
$function$;

-- todo: to be added to the dean actions later so that only dean's office creates new students
create trigger add_empty_grade_sheet
    after insert
    on academic_data.student_info
    for each row
execute procedure create_empty_grade_sheet(new.roll_number);
