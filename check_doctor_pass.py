import sys
sys.path.insert(0, 'backend')
import sqlite3
from app.core.security import verify_password

conn = sqlite3.connect('backend/opd_connect.db')
c = conn.cursor()
c.execute('SELECT email, hashed_password FROM users WHERE email = ?', ('pulmonology@smvmch.ac.in',))
r = c.fetchone()
if r:
    print('Found:', r[0])
    print('Doctor@123 check:', verify_password('Doctor@123', r[1]))
    print('Doctor@123456 check:', verify_password('Doctor@123456', r[1]))
else:
    print('User not found!')
conn.close()
