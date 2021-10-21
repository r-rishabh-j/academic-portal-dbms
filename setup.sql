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

create table academic_data.course_catalog
(
    course_code        varchar primary key,
    credits            integer not null,
    credit_structure   varchar not null,
    course_description varchar   default '',
    pre_requisites     varchar[] default '{}',
    introduced_on      date    not null
);

create table academic_data.student_info
(
    roll_number  varchar primary key,
    student_name varchar not null,
    department   varchar not null,
    course       varchar not null,
    batch_year   integer not null,
    contact      varchar
);

create function course_offerings.add_new_semester(academic_year integer, semester_number integer) returns void as
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
