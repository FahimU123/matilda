import re
from enum import StrEnum


class Command(StrEnum):
    YES = "yes"
    NO = "no"
    ONE = "one"
    TWO = "two"
    THREE = "three"


# Words that look the same on the lips, or that a lip reader commonly returns instead.
_ALIASES: dict[str, Command] = {
    "YES": Command.YES, "YEAH": Command.YES, "YEP": Command.YES, "YA": Command.YES, "OK": Command.YES, "OKAY": Command.YES,
    "NO": Command.NO, "NOPE": Command.NO, "NAH": Command.NO, "KNOW": Command.NO, "NOT": Command.NO,
    "ONE": Command.ONE, "WON": Command.ONE, "FIRST": Command.ONE,
    "TWO": Command.TWO, "TO": Command.TWO, "TOO": Command.TWO, "SECOND": Command.TWO,
    "THREE": Command.THREE, "FREE": Command.THREE, "TREE": Command.THREE, "THIRD": Command.THREE,
}


# Common words that only count when spoken on their own.
_WEAK = {"YA", "OK", "OKAY", "KNOW", "NOT", "WON", "TO", "TOO", "FREE", "TREE"}
MAX_WORDS = 2


def command_for(transcript: str) -> Command | None:
    words = re.findall(r"[A-Z']+", transcript.upper())
    if not words or len(words) > MAX_WORDS:
        return None
    hits = [word for word in words if word in _ALIASES]
    if len(words) > 1 and all(word in _WEAK for word in hits):
        return None
    matches = {_ALIASES[word] for word in hits}
    return matches.pop() if len(matches) == 1 else None
