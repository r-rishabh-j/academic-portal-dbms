import pandas as pd
import string
import random
# student
# faculty
# courses
# course_offerings
# timetable slots
# semester_year

def id_generator(size=6, chars=string.ascii_uppercase + string.digits):
    return ''.join(random.choice(chars) for _ in range(size))

def generate_student_data(num_students_per_branch=10, branches = ["cse", "ee", "me"], batches = ['2019', '2018']):
    def generate_batch(num_students_per_branch, years):
        # per branch equal students
        batch = [[],[],[],[]]
        for year in years:
            for branch in branches:
                branch_id = 1
                for student in range(num_students_per_branch):
                    batch[0].append(branch+'_'+year+'_'+format(branch_id,'04d'))
                    branch_id+=1
                    batch[1].append(id_generator(7, string.ascii_uppercase))
                    batch[2].append(branch)
                    batch[3].append(year)
        return batch

    student_data = pd.DataFrame(columns=["roll_number", "name", "department", "batch_year"])
    students = generate_batch(num_students_per_branch, batches)
    student_data['roll_number'] = students[0]
    student_data['name'] = students[1]
    student_data['department'] = students[2]
    student_data['batch_year'] = students[3]
    student_data.to_csv('students.csv', index=False)

branches = ["cse", "ee", "me"]
batches = ['2019', '2018']
def generate_adviser_data(branches, batches):
    adviser_data = pd.DataFrame(columns=['adviser_id', 'batch_dept', 'batch_year'])
    ugbatch_data = pd.DataFrame(columns=['batch_dept', 'batch_year','adviser_id'])
    adv_ids = []
    adv_dept = []
    adv_year = []
    for year in batches:
        for branch in branches:
            adv_ids.append('adv_'+branch+'_'+year)
            adv_dept.append(branch)
            adv_year.append(year)
    adviser_data['adviser_id']=adv_ids 
    adviser_data['batch_dept']=adv_dept
    adviser_data['batch_year']=adv_year
    adviser_data.to_csv('adviser.csv', index=False)
    ugbatch_data['batch_dept']=adv_dept
    ugbatch_data['batch_year']=adv_year
    ugbatch_data['adviser_id']=adv_ids 
    ugbatch_data.to_csv('up_batches.csv', index=False)

generate_student_data(branches=branches,  batches=batches)
generate_adviser_data(branches=branches,  batches=batches)