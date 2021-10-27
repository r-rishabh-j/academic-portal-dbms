create procedure upload_grades(grade_file text, course_name text) as
$function$
declare
semester integer;
year integer;
temp_table_name varchar;
reg_table_name varchar;
begin
    select academic_data.semester.semester, academic_data.semester.year from academic_data.semester into semester, year;
    temp_table_name:='temporary_grade_store_'||course_name||'_'||year||'_'||semester;
    reg_table_name:='registrations.'||course_name||'_'||year||'_'||semester;
    execute(format($tbl$create table %I 
    (
        roll_number varchar,
        grade integer
    );
    $tbl$, temp_table_name));
    -- execute('copy '|| temp_table_name ||' from '''|| grade_file ||''' delimiter '','' csv header;');

    execute(format($dyn$copy %I from %L delimiter ',' csv header;$dyn$), temp_table_name, grade_file);
    execute(format($dyn$update %I set %I.grade=%I.grade from %I where %I.roll_number=%I.roll_number;$dyn$, 
    reg_table_name, reg_table_name, temp_table_name, temp_table_name, reg_table_name, temp_table_name));

    execute format('drop table %I;', temp_table_name);
end;
$function$ language plpgsql;