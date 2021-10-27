import csv
import random
import string

fields = ['Faculty_ID', 'Faculty_name', 'Department']
departments = ['cse', 'me', 'ee']

rows = []
num_rows = 100 
faculty_id = 1

for i in range(num_rows):
    record = []
    branch = random.choice(departments)
    record.append(branch + '_' + format(faculty_id, '04d'))
    faculty_id += 1
    record.append(''.join(random.choice(string.ascii_uppercase) for _ in range(8)))
    record.append(branch)
    rows.append(record)

with open('faculty_info.csv', 'w', newline = '') as csvfile:
    csvwriter = csv.writer(csvfile)
    csvwriter.writerow(fields)
    csvwriter.writerows(rows)
