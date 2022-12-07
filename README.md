# Academic Portal DBMS

# Description of features

### Admin/Dean tasks:

- Creating semester: Admin would call admin_data.add_new_semester() to create related tables and grant access to them.
- Loading course offerings: Admin would call load_course_offerings() to fill the course offering tables from the csv file.
- Loading timetable slots: Admin calls load_timetable() to load course timetable for courses.
- Fetching and approving registrations: Admin needs to fetch and approve course registrations by calling admin_data.populate_registrations().
- Fetching and updating tickets: Admin needs to fetch and approve student tickets by calling admin_data.get_tickets() and admin_data.update_ticket().
- Creating users: Admin needs to call admin_data.load_students(), admin_data.load_faculty() or admin_data.load_advisers() with appropriate arguments to load user data from csv file and register them on the database.

### Faculty Tasks:

- Faculty login ID and password is the same as their faculty_id. Faculty ID format is <dept_name>_<4 digit ID>.
- Offering course: Call faculty_actions.offer_course() with appropriate arguments to offer a course in the semester. The faculty who calls the function becomes the course coordinator.
- Approving student tickets: Faculty can view the tickets sent to their respective ticket tables by calling faculty_actions.show_tickets() and change their status by calling faculty_actions.update_ticket() with appropriate arguments.

### Adviser Tasks:

- Adviser login ID and password is the same as their adviser_id. Adviser ID format is adv_<batch_id>.
- Approving student tickets: Advisers can view the tickets sent to their respective ticket tables by calling adviser_actions.show_tickets() and change their status by calling adviser_actions.update_ticket() with appropriate arguments.

### Student Tasks/Functionalities:

- Student login ID and password is the same as their roll number in the format:<branch>_<year>_<4-digit-ID>
- Provisionally register for courses
Insert tickets for faculty advisors and faculty corresponding to the course offering
- Submit drop ticket requests and withdraw course requests to the dean
- View marksheet and calculate CGPA

To register for a course, the register_for_course() wrapper function is called, which executes the following through a matching trigger.

### Pre-course registration checks:

- check_prerequisites(<roll_number>, <course_id>):check if the student has a non zero grade in all the prerequisite courses mentioned in the course catalog for the given course id.
- check_allowed_batches(<roll_number>, <course_id>): check if the batch_year of the student is in the list of allowed batches for the course
- check_time_table_slot(<roll_number>, <course_id>): check if the slot allotted to the course id is not already occupied by the student. 
- check_constraints(<roll_number>, <course_id>): ensure that the student has minimum required cgpa or not
- get_credit_limit(<roll_number>): calculate the credit limit according to the 1.25 rule for the given student roll number.
- check_credit_limit(<roll_number>, <course_id>): check if the credit limit has not been exceeded by the student. If exceeded, then the student needs to generate a ticket.

# Roles and permissions

| Role/User Name | Permissions (on schema/table/functions)|
|--- | --- |
|Dean/admin | Superuser(admin is the dean), all privileges| 
|Student | Insert access on provisional registration table; select access on academic_data schema; select access on ug_curriculum schema; select access student_id_grade; select, insert access on faculty_ticket_table; faculty advisor ticket table; select access on dean ticket table, execute access on public functions.|
|Faculty | select, insert access on course_offering table; all privileges on faculty_ticket, select access on dean_tickets, select access on student_grades schema, registrations schema, academic_data schema, execute access on all functions in faculty_actions schema|
|Faculty Advisor | update access on faculty advisor ticket table, select access on dean tickets, select access on student_grades schema, registrations schema, academic_data schema, execute access on all functions in adviser_actions schema|

# Schemas:

## student:
- calculate_cgpa(<roll_number>): calculate the cgpa of the given roll number
- calculate_cgpa(): calculate the cgpa of the current user
- register_for_course(): Wrapper function to provisionally register for course, executes the following through a matching trigger.
- check_prerequisites(<roll_number>, <course_id>):check if the student has a non zero grade in all the prerequisite courses mentioned in the course catalog for the given course id.
- check_allowed_batches(<roll_number>, <course_id>): check if the batch_year of the student is in the list of allowed batches for the course
- check_time_table_slot(<roll_number>, <course_id>): check if the slot allotted to the course id is not already occupied by the student. 
- check_constraints(<roll_number>, <course_id>): ensure that the student has minimum required cgpa or not
- get_credit_limit(<roll_number>): calculate the credit limit according to the 1.25 rule for the given student roll number.
- check_credit_limit(<roll_number>, <course_id>): check if the credit limit has not been exceeded by the student. If exceeded, then the student needs to generate a ticket.
submit_drop_ticket(): Called by a student to drop a course.
submit_withdraw_course(): Called by a student to withdraw from the course.

- Trigger:
check_register_for_course(<course_id>): Facilitates the register_for_course routine by ensuring the above pre-registration checks.

<hr>

## academic_data:

|Table name|Attributes|Description|Permissions|
|---|---|---|---|
|department|dept_name|Contains departments in univ|public select, admin all privileges|
|semester|semester, year|Contains current semester, year. At most one entry will be present in this table.|public select, admin all privileges|
|degree|degree, program_electives, open_electives|Contains the degree and the program elective credit limit and the open elective credit limit.|public select, admin all privileges|
|course_catalog|course_code,dept_name,credits,credit_structure,course_description,pre_requisites|Contains the course catalog|public select, admin all privileges|
|student_info|roll_number,student_name,department,batch_year|Contains all information about the student. Student’s user ID will be the roll_number|Public select, admin all privileges|
|faculty_info|Faculty_id, faculty_name, department|Contains information about faculty|Public select, admin all privileges|
|ug_batches|dept_name,batch_year,adviser_f_id|Contains information about all the batches and their year|Public select, admin all privileges|
|adviser_info|adviser_f_id, batch_dept, batch_year|Contains information about batch advisers|public select, admin all privileges
|timetable_slots|slot_name|stores slot names|public select, admin all privileges

Triggers:

- generate_student_record: calls admin_data.create_student(): Trigger on academic_data.student_info. Creates the student user with appropriate permissions, and creates student_grades.student_<roll_number>.
- generate_faculty_record: calls admin_data.create_faculty(): Trigger on academic_data.student_info. Creates the student user with appropriate permissions, and creates student_grades.faculty_<faculty_id>.

<hr>

## admin_data:

### Routines:

- admin_data.add_new_semester(academic_year, semester_number): Called by admin/dean to add a new semester to the database. In this, the academic_data.semester table is updated with the arguments. Along with this, several tables are created related to this semester. These are mentioned below:
    - course_offerings.sem_<academic_year>_<semester_number>. This table holds details of all the course offerings in the semester.
    - registrations.provisional_course_registrations_<academic_year>_<semester>: This table contains the list of course registration requests from students who qualify all course registrations criteria. 
    - registrations.dean_tickets_<academic_year>_<semester>: Stores tickets collected by dean from faculties and advisers.
- admin_data.populate_registrations(): obtains registration list from provisional registration tables and places them into appropriate course registration tables(registrations.<course_id>_<year>_<semester>).
- registrations.provisional_course_registrations_<year>_<semester> and inserts them into registrations.<course_code>_<year>_<semester> for each course.
- admin_data.get_tickets(): admin/dean calls this function to get tickets raised by students from the faculty tables and the respective advisors.
- admin_data.update_ticket(stu_rollnumber, course, new_status): Stores new_status into ticket for student with stu_rollnumber for course ‘course’. new_status is admin’s decision. If the ticket gets approved by the dean, then the roll number is appended to the registrations table of that course.
- admin_data.load_students(stu_filename text): load data from csv file
- admin_data.load_faculty(f_filename text): load data from csv file
- admin_data.load_advisers(a_filename text): load data from csv file
- admin_data.load_course_offerigs(c_filename text): load course offering data from CSV file.
- admin_data.add_slots(): create temporary table having course_code and slot loaded from a csv file and then add these slots to the course_offerings schema
- admin_data.set_ug_curriculum(department, batch_year): Called by admin/dean to define the ug curriculum for every batch where each unique batch is described by department+batch_year (“cse2021”)
- drop_tickets(course_code, roll_number): The dean will approve drop ticket requests entered by the students in the drop_tickets table and cancel the tickets in the corresponding  faculty and faculty adviser ticket tables.
- withdraw_course(course_code, roll_number): The dean will approve withdraw course requests entered by the students in the withdraw_course table

Triggers:

- generate_student_record: admin_data.create_student(): Trigger is called whenever a student entry is created in academic_data.student_info. A student user is created with an id and password as roll_number.
- generate_faculty_record: admin_data.create_faculty(): Trigger is called whenever a faculty entry is created in academic_data.faculty_info. A faculty user is created with an id and password as faculty_id.
- generate_adviser_record: admin_data.create_adviser(): Trigger is called whenever a adviser entry is created in academic_data.adviser_info. An adviser user is created with an id and password as adviser_f_id.

<hr>

## course_offerings:

|Table name|Attributes|Description|Permissions|
|---|---|---|---|
|course_offerings<year_semester>|course_code, course_coordinator, instructors, slot, allowed_batches, cgpa_req|Stores the list of courses offered for the current semester, year. All fields except the time table slot(which is entered by admin) are inserted by the course_coordinator.|select access to student, insert, update access to faculty, all privileges to dean 


Trigger:
- course_offering.trigger_sem_<academic_year>_<semester_number>: Calls
course_offerings.create_

tion_table. Trigger on course offerings table to create final registration table for the course entered. Grant of select and update is given to course instructors.

<hr>

## student_grades

|Table name|Attributes|Description|Permissions|
|---|---|---|---|
|student_grades.<roll_number>|course_code, semester, year, grade|Stores the list of courses and the grades obtained for each student|select access to student_<roll_number>, select access to faculty, all privileges to dean|


Routine:

- generate_marksheet(): print all the courses taken and the grades received in them. For students, roll number is taken from the username while the dean and faculty can generate for all roll numbers.

## registrations

|Table name|Attributes|Description|Permissions|
|---|---|---|---|
|dean_tickets_<year_semester>|roll_number,course_code,dean_decision,faculty_decision, advisor_decision|Stores tickets of students for course registrations. Dean calls the function admin_data.get_tickets() to fetch the tickets from the faculties and advisors|select access to all, all privileges to dean|
|faculty_tickets_<f_id_year_semeste>|roll_number, course_code, status|Stores tickets corresponding to faculty f_id, inserted by students|select access to all, insert to students, all privileges to faculty f_id, dean
|adviser_tickets_<adviser_f_id_year_semester>|roll_number, course_code, status|Stores tickets corresponding to adviser adviser_id, inserted by students|select access to all, insert to students, all privileges to adviser adviser_ f_id, dean|
|drop_tickets_<year_semester>|roll_number, course_code|Stores the dropl requests for the tickets by the students|select access to all, insert to students, all privileges to dean|
|withdraw_course_<year_semester>|roll_number, course_code|Stores the withdrawal requests for the registrations by the students|select access to all, insert to students, all privileges to dean|
|provisional_course_registrations<year_semester>|roll_number, course_code|Temporary course registrations inserted after checking against pre-course reg constraints|select access to public, insert(after checking through trigger) access to student, all privileges to dean|
|<course_code_year_semester>|roll_number, grade|Stores the valid student registrations corresponding to each course, created and populated by dean, maintained by concerned faculty|Select, update to course instructors. All privileges to dean|

<hr>

## ug_curriculum 

|Table name|Attributes|Description|Permissions|
|---|---|---|---|
|<batch_code>|course_code, type, course_description, credits|For each batch(e.g. cse2020) describes the program cores, program electives, science cores, open electives |select access to all, all privileges to dean|

Routine:
-  is_ready_to_graduate(<roll_number>): compare if all the core courses have been completed and count the number of program and elective credits taken, against the limits specified by the admin. Also call the calculate cgpa function to check for a minimum of 5 CGPA.

<hr>

## faculty_actions: 
Contains functions and procedures that only faculties can execute.

- faculty_actions.show_ticket(): Print the faculty’s tickets.
- faculty_actions.update_ticket(stu_rollnumber, course, new_status): Update the status(boolean) of stu_rollnumber student’s ticket for course ‘course’.
- faculty_actions.upload_grades(grade_file, course_name): Used by faculty to update course course_name student grades from csv file with ‘grade_file’ path.
- faculty_actions.offer_course(course_name, instructor list[ ], allowed_batches[ ], cgpa lim): Faculty calls this function to offer a course course_name with instructor list, allowed batches list and cgpa limit.

<hr>

## adviser_actions: 
Contains functions and procedures that only advisers can execute.

- adviser_actions.show_ticket(): Print the adviser’s tickets.
- adviser_actions.update_ticket(stu_rollnumber, course, new_status): Update the status(boolean) of stu_rollnumber student’s ticket for course ‘course’.



### Note:

1. Admin(superuser) refers to the Dean in our case
2. In the tables with the string ‘year_semester’, it should be interpreted as the numerical value of semester and year in place of the words semester and year.
3. Trigger checks are implemented before insert/update on critical tables to ensure secure access. Most of them have been trivially implemented but not highlighted below.
