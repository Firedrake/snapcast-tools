# Roger's command-line tool for Snapcast

## In Theory

`snapcast` groups are each tied to a single stream, and can contain
multiple clients. Every client must be in exactly one group.

I think the theory is that the client membership of a group should be
relatively stable (e.g. "all the snapclients I have within earshot of
each other"), and the stream membership should change ("all these
servers are now playing stream B"). (Indeed, a group with no clients
in it doesn't exist.)

This is fiddly. I'd much rather have a free matrix of clients and
streams, and by assigning one client to each group this can be
achieved.

Also I don't care about volume control. I'm playing out of mpd, which
has a volume control; I'm playing into clients, which have a volume
control.

## In Practice

This software is licenced under the GNU General Public License v3.0.
See gpl-3.0.txt for details.

"sp" because it's an allied trade to "mp" which is my command-line mpd
controller (https://github.com/Firedrake/mpd-tools).

Select snapserver hostname with -h or by setting `MPD_HOST`. Port is
set with -p, defaulting to 1705.

- (no parameters)

shows you groups, their assigned streams, and clients in those groups,
one group per line. A <n> indicates non-zero client latency. A "*"
indicates a muted group or client.

- setup

Assign each known client to a group named for that client. (Note that
this won't play well with the official Snapcast client for Android,
which does not display group names, only their assigned streams.)

- LATENCY CLIENT (CLIENT...)

LATENCY is any all-digit parameter. Set the latency value for each
CLIENT.

- STREAM GROUP (GROUP...)

Assign STREAM to each GROUP.

- GROUP CLIENT (CLIENT...)

Move CLIENT(s) into GROUP (which need not exist)

- GROUP/CLIENT (GROUP/CLIENT...) off/on

Mute/unmute GROUP or CLIENT. (If the same name matches both GROUP and
CLIENT, this will be done to GROUP.)

- CLIENT (CLIENT...) forget

Delete CLIENT from the server's list. When the client is restarted, it
will re-register itself.
