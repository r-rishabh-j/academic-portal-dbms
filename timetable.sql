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
    execute (format($d$copy admin_data.temp_timetable_slots from '%s' delimiter ',' csv header;$d$), file);

    for course_slot in select * from admin_data.temp_timetable_slots
        loop
            execute (format($d$update course_offerings.sem_%s_%s set slot='%s' where course_code='%s';$d$, yr, sem,
                            course_slot.slot, course_slot.course_code));
        end loop;

    drop table admin_data.temp_timetable_slots;
end;
$f$