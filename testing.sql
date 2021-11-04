-- run setup.sqp
-- run load_members
-- add course_catalog
-- add new semester imp!!
-- load course_offerings

-- copy academic_data.course_catalog to 'C:\Users\risha\Desktop\dump.csv' with (format csv, header);
admin:

call admin_data.add_new_semester(2021,1);
call admin_data.upload_catalog('C:\Users\risha\Desktop\Assignments\CS301\Project\academic-portal-dbms\UG_curriculum_2019 - CSE.csv')
