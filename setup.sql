-- delete all previous schemas, tables and data to start off with a clean database
drop schema if exists
    academic_data,
    course_offerings,
    student_grades
    cascade;

-- create the required schemas with tables and fill them some custom dummy data
create schema academic_data;
create schema course_offerings;
create schema student_grades;

create table academic_data.departments
(
    dept_name varchar primary key
);

insert into academic_data.departments values('cse');

create table academic_data.degree
(
    degree varchar primary key
);

insert into academic_data.degree values('btech');

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

create table academic_data.student_info
(
    roll_number  varchar primary key,
    student_name varchar not null,
    department   varchar not null,
    degree       varchar not null,
    batch_year   integer not null,
    contact      varchar,
    foreign key (department) references academic_data.departments (dept_name),
    foreign key (degree) references academic_data.degree (degree)
);

create table academic_data.faculty_info
(
    faculty_id   varchar primary key,
    faculty_name varchar not null,
    department   varchar not null,
    contact      varchar,
    foreign key (department) references academic_data.departments (dept_name)
);

create or replace function course_offerings.add_new_semester(academic_year integer, semester_number integer) returns void as
$function$
begin
    execute ('create table course_offerings.sem_' || academic_year || '_' || semester_number || '
                (
                    course_code     varchar primary key,
                    instructors     varchar[] not null,
                    slots           varchar[] not null,
                    allowed_batches varchar[] not null,
                    foreign key (course_code) references academic_data.course_catalog (course_code)
                );'
        );
end;
$function$ language plpgsql;

create or replace function create_student(
    roll_number varchar, student_name varchar, department varchar, 
    degree varchar, batch_year integer, contact varchar
    ) 
returns void as
$function$
begin
    insert into academic_data.student_info values (roll_number, student_name, department, degree, batch_year, contact);
    execute ('create table student_grades.' || roll_number || '
                (
                    course_code     varchar not null,
                    semester        integer not null,
                    year            integer not null,
                    grade           varchar not null,
                    foreign key (course_code) references academic_data.course_catalog (course_code)
                );'
        );
end
$function$ language plpgsql;
