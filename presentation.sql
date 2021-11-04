call admin_data.add_new_semester(2021,1);
CALL admin_data.upload_offerings('C:\Users\risha\Desktop\Assignments\CS301\Project\academic-portal-dbms\course_offerings - Sheet1.csv');
call admin_data.upload_timetable('C:\Users\risha\Desktop\Assignments\CS301\Project\academic-portal-dbms\Time_Table_year_semester - course_code, slot.csv');

-- student registers

call admin_data.populate_registrations();

--tickets
call raise_ticket('cs302');

call faculty_actions.update_ticket('cse_2019_0001','cs302',true);

call admin_data.update_ticket('cse_2019_0001', 'cs302', true);

--
update academic_data.degree_info set program_electives_credits=4;

update academic_data.degree_info set open_electives_credits=3;



-----
 call faculty_actions.offer_course('cs305','{"cse_0004","cse_0005"}','{}',9.5);

