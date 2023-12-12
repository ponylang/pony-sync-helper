#!/usr/bin/python3
# pylint: disable=C0103
# pylint: disable=C0114

from datetime import datetime
import sys
import zulip

messages = []
current_message = ""
for line in sys.stdin.readlines():
    if len(current_message) + len(line) <= 7000:
        current_message += line + "\n"
    else:
        # We have a decent chunk of content to post at this point.
        # We are now looking for the next repository to start a new message.
        # We don't want to break during a repository as it messes up the
        # markdown formatting of the message in Zulip.
        if line.startswith("**ponylang/"):
            messages.append(current_message)
            current_message = line + "\n"
        else:
            current_message += line + "\n"

# add the final message in to messages
messages.append(current_message)

# set up topic with today's date
msg_date = datetime.today().strftime('%Y-%m-%d')
msg_topic = "Good first issues as of " + msg_date

zulip_client = zulip.Client()
for message in messages:
    request = {
        "type": "stream",
        "to": "contribute to Pony",
        "topic": msg_topic,
        "content": message
    }
    result = zulip_client.send_message(request)
