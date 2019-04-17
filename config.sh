#!/bin/bash
echo "config = {
    # Create an app over here https://discordapp.com/developers/applications/me
    # and fill these fields out
    'client-id': 'Your app client id',
    'client-secret': 'Your discord client secret',
    'bot-token': 'Discord bot token',

    # Rest API in https://developer.paypal.com/developer/applications
    'paypal-client-id': 'Paypal client id',
    'paypal-client-secret': 'Paypal client secret',

    # V2 reCAPTCHA from https://www.google.com/recaptcha/admin
    'recaptcha-site-key': 'reCAPTCHA v2 Site Key',
    'recaptcha-secret-key': 'reCAPTCHA v2 Secret Key',

    # Patreon
    'patreon-client-id': 'Patreon client id',
    'patreon-client-secret': 'Patreon client secret',

    'app-location': '/var/www/Titan/webapp/',
    'app-secret': 'Type something random here, go wild.',

    'database-uri': 'postgresql://titan:titan@localhost/titan',
    'redis-uri': 'redis://',
    'websockets-mode': 'eventlet',
    'engineio-logging': False,

    # https://titanembeds.com/api/webhook/discordbotsorg/vote
    'discordbotsorg-webhook-secret': 'Secret code used in the authorization header for DBL webhook',

    # Sentry.io is used to track and upload errors
    'sentry-dsn': 'Copy the dns string when creating a project on sentry',
    'sentry-js-dsn': 'Same as above, but you can create a seperate sentry project to track the client side js errors',
}
" > /var/www/Titan/webapp/config.py

echo "config = {
    'bot-token': "Discord bot token",
    'database-uri': "postgresql://titan:titan@localhost/titan",
    'redis-uri': "redis://",
    'titan-web-url': "https://titanembeds.com/",
    'titan-web-app-secret': "app secret from the webapp config",
    'discord-bots-org-token': "DiscordBots.org Post Stats Token",
    'bots-discord-pw-token': "bots.discord.pw Post Stats Token",
    'logging-location': "/var/www/Titan/discordbot/titanbot.log",
    "sentry-dsn": "Copy the dns string when creating a project on sentry",
}" > /var/www/Titan/discordbot/config.py
