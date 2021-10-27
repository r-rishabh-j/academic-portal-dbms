create or replace function check_register_for_course()
    returns trigger
    language plpgsql
as
$trigfunc$
declare
    current_semester    integer;
    current_year        integer;
    roll_number         varchar;
    course_id           varchar;
    prerequisites_list  varchar[];
    batches             varchar[];
    student_batch       integer;
    check_batch         integer := 0;
    check_prerequisites integer := 0;
    batch               integer;
    course              varchar;
    grades_list         table
                        (
                            course_code varchar,
                            semester    integer,
                            year        integer,
                            grade       integer
                        );

begin
    select semester from academic_data.semester into current_semester;
    select year from academic_data.semester into current_year;
    select new.roll_namber into roll_number;
    select new.course_code into course_id;
    select batch_year from academic_data.student_info where academic_data.student_info.roll_number = roll_number;


    select pre_requisites
    from academic_data.course_catalog
    where academic_data.course_catalog.course_code = course_id
    into prerequisites_list;
    execute ('select allowed_batches from course_offerings.sem_' || current_year || '_' || current_semester ||
             ' into ' || batches || ' where course_code=' || course_id || ';');
    execute ('select * from student_grades.student_' || roll_number || ' into grades_list;');

    foreach batch in array batches
        loop
            if batch = batch_year then
                check_batch = 1;
            end if;
        end loop;

    if check_batch = 1 then
        foreach course in array prerequisites_list
            loop
                exit when course = '';
                if course not in (select grades_list.course_code from grades_list) then
                    return null;
                end if;
            end loop;
    else
--raise notice 'Insert into provisional registration failed';
        return null;
    end if;

    return new;


--execute('insert into registrations.provisional_course_registrations_' || current_year || '_' || current_semester||'(roll_number, course_code) values ('||roll_number||', '||course_id||');');

end;
$trigfunc$;


-- write execute('create trigger registrations.check_provisional_insert_'||)

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
    select semester from academic_data.semester into current_semester;
    select year from academic_data.semester into current_year;
    select user into roll_number;
    execute ('insert into registrations.provisional_course_registrations_' || current_year || '_' || current_semester ||
             '(roll_number, course_code) values (' || roll_number || ', ' || course_id || ');');
end
$func$