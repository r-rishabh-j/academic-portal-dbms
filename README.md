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

### Note:

1. Admin(superuser) refers to the Dean in our case
2. In the tables with the string ‘year_semester’, it should be interpreted as the numerical value of semester and year in place of the words semester and year.
3. Trigger checks are implemented before insert/update on critical tables to ensure secure access. Most of them have been trivially implemented but not highlighted below.
