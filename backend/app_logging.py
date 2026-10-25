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


#RENDER POLLS /health, OFTEN, FOREVER. It is the service's health check path,
#so the platform calls it every few seconds to decide whether the process is
#alive - and every one of those lands in uvicorn's access log, which buries
#the requests somebody actually cares about under a wall of identical lines.
#
#Only the successful ones are dropped. A /health that answers anything other
#than 200 means the process is in trouble and is exactly what should survive
#in the log.
#
#MATCHED ON THE PATH ARGUMENT, not on the formatted line: uvicorn passes the
#request as %s arguments, so a substring search over the whole message would
#also silence a request from a client whose address happened to contain the
#word, and would break the day the format string changes.
class _QuietHealthChecks(logging.Filter):
    def filter(self, record: logging.LogRecord) -> bool:
        args = record.args
        if isinstance(args, tuple) and len(args) >= 5:
            path, status = args[2], args[4]
            if isinstance(path, str) and path.split("?")[0] == "/health":
                return status != 200
        return True


logging.getLogger("uvicorn.access").addFilter(_QuietHealthChecks())
