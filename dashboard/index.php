This will be the new TitanPi Dashboard
<br /><br />
Titan is running on port 8080

<br /><br />

<?php $user_id = '416684403670908928'; ?>

su -c "psql -d titan -c \"INSERT INTO administrators (user_id) VALUES (<?= $user_id ?>);\"" postgres

<hr>

from flask import session

def get_administrators_list():
    their_ids = []
    if "user_id" in session:
        their_ids.append(str(session['user_id']))
    return their_ids
