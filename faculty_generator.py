import csv
import random
import string

fields = ['Faculty_ID', 'Faculty_name', 'Department', 'Contact']
departments = ['cse', 'me', 'ee']

rows = []
num_rows = 100 

for i in range(num_rows):
    record = []
    record.append(random.choice(departments) + ''.join(random.choice(string.digits) for _ in range(4)))
    record.append(''.join(random.choice(string.ascii_uppercase) for _ in range(8)))
    record.append(random.choice(departments))
    record.append(''.join(random.choice(string.digits) for _ in range(10)))
    rows.append(record)

with open('faculty_info.csv', 'w') as csvfile:
    csvwriter = csv.writer(csvfile)
    csvwriter.writerow(fields)
    csvwriter.writerows(rows)
