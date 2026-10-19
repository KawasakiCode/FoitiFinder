"""The one logger the backend uses.

Its own module so that everything can import it without importing main - which
would be a circular import, because main imports the routers and the routers
import this.
"""

import logging

#NOT a logger of our own: uvicorn configures the root logger, so a named child
#of it inherits uvicorn's formatting and level and its output lands in the same
#place as the request log. getLogger() returns the SAME object every call, so
#this is a name for that logger rather than a new one.
#
#Used for things that must not fail a request but must not vanish either -
#a notification that could not be delivered, a token rejected for a reason the
#client is deliberately not told. NEVER log a token, a handle or an email: the
#log is readable by anyone with dashboard access.
logger = logging.getLogger("foitifinder")
