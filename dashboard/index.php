This will be the new TitanPi Dashboard
<br /><br />
Titan is running on port 8080

<br /><br />

su - postgres
psql
\c titan
INSERT INTO administrators (user_id) VALUES (123456543);
\q

<hr>

from flask import session

def get_administrators_list():
    their_ids = []
    if "user_id" in session:
        their_ids.append(str(session['user_id']))
    return their_ids
