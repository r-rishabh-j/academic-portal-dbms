create or replace procedure drop_user(username text)
as
$$
declare
    usr_row record;
begin
    execute format('revoke all privileges on schema academic_data from %s;', username);
    execute format('revoke all privileges on schema course_offerings from %s;', username);
    execute format('revoke all privileges on schema faculty_actions from %s;', username);
    execute format('revoke all privileges on schema admin_data from %s;', username);
    execute format('revoke all privileges on schema student_grades from %s;', username);
    execute format('revoke all privileges on schema registrations from %s;', username);
    execute format('revoke all privileges on schema adviser_actions from %s;', username);
    execute format('drop user %s;', username);
end;
$$ language plpgsql;

-- call drop_user('username');
